-- ============================================================
-- REC LIVESTOCK & AGRO FARMS — Order integrity
--
-- Safe to run after the existing migrations. It replaces the order
-- validation/reservation functions, adds one audited stock function,
-- adds customer status notifications and tightens one RLS policy.
-- No tables, columns, or rows are dropped.
--
-- Fixes:
--   1. Delivery fees are read from delivery_zones, never trusted
--      from the browser. Pickup orders are always free.
--   2. Hidden, farm-only, sold-out and below-MOQ products cannot
--      be ordered.
--   3. Stock is decremented atomically and cannot go below zero,
--      so concurrent orders cannot oversell the same item.
--   4. Pickup station name/address are copied from pickup_stations,
--      not from the client.
--   5. Signed-in customers can only attach their own customers row
--      to an order; guest orders must leave customer_id null.
--   6. Status changes create a notification for the customer who owns
--      the order (requires update-admin-console.sql).
--   7. Admin stock edits go through one audited function instead of
--      overwriting products.stock_quantity directly.
--
-- Apply in Supabase SQL Editor:
--   schema.sql -> update-admin-console.sql -> update-role-manager-seller.sql
--   -> update-role-based-access.sql -> update-egg-sizes.sql
--   -> update-reviews-editing.sql -> update-remove-sample-testimonials.sql
--   -> update-ops-access.sql -> update-security-hardening.sql
--   -> update-order-integrity.sql -> update-business-location.sql
-- ============================================================

create or replace function public.log_order_movements()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  it jsonb;
  pid uuid;
  qty int;
  new_stock int;
  new_batch uuid;
  product_name text;
begin
  if new.items is not null and jsonb_array_length(new.items) > 0 then
    for it in select jsonb_array_elements(new.items) loop
      pid := case when it->>'product_id' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        then (it->>'product_id')::uuid else null end;
      continue when pid is null;
      qty := coalesce((it->>'quantity')::int, 0);
      if qty > 0 then
        update public.products
          set stock_quantity = stock_quantity - qty,
              updated_at = now()
          where id = pid
            and stock_quantity >= qty
          returning stock_quantity into new_stock;
        if not found then
          select name into product_name from public.products where id = pid;
          raise exception 'Insufficient stock for %', coalesce(product_name, pid::text)
            using errcode = 'check_violation';
        end if;
        select id into new_batch
          from public.product_batches
          where product_id = pid
            and status = 'available'
            and available_quantity > 0
          order by created_at
          limit 1;
        if new_batch is not null then
          update public.product_batches
            set available_quantity = greatest(0, available_quantity - qty),
                updated_at = now()
            where id = new_batch;
        end if;
        insert into public.inventory_movements (product_id, batch_id, change, quantity_after, reason, reference)
        values (pid, new_batch, -qty, new_stock, 'Order reservation', new.order_number);
      end if;
    end loop;
  end if;
  return new;
end;
$$;

create or replace function public.validate_order_amounts()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  it               jsonb;
  new_it           jsonb;
  items            jsonb := '[]'::jsonb;
  pid              uuid;
  qty              int;
  price            numeric(12,2);
  line             numeric(12,2);
  subtotal         numeric(12,2) := 0;
  product_name     text;
  is_active        boolean;
  is_online        boolean;
  availability     text;
  moq              int;
  method           text := coalesce(new.fulfillment_method, 'delivery');
  station_name     text;
  station_address  text;
  zone_fee         numeric(12,2);
begin
  if new.items is null or jsonb_typeof(new.items) <> 'array'
     or jsonb_array_length(new.items) = 0 then
    raise exception 'Order must contain at least one item';
  end if;

  if method not in ('delivery', 'pickup') then
    raise exception 'Invalid fulfillment method';
  end if;

  for it in select jsonb_array_elements(new.items) loop
    qty := coalesce((it->>'quantity')::int, 0);
    if qty <= 0 then
      raise exception 'Invalid item quantity';
    end if;

    pid := case
      when it->>'product_id' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        then (it->>'product_id')::uuid
      else null end;
    if pid is null then
      raise exception 'Order line is missing a valid product';
    end if;

    select p.price,
           p.name,
           p.active,
           p.online_orderable,
           coalesce(p.availability_status, 'in_stock'),
           greatest(coalesce(p.minimum_order_quantity, 1), 1)
      into price, product_name, is_active, is_online, availability, moq
      from public.products p
      where p.id = pid;

    if not found then
      raise exception 'Order line references an unknown product';
    end if;
    if not is_active then
      raise exception 'Product % is not available', product_name;
    end if;
    if not is_online then
      raise exception 'Product % is only available at the farm', product_name;
    end if;
    if availability = 'sold_out' then
      raise exception 'Product % is sold out', product_name;
    end if;
    if qty < moq then
      raise exception 'Minimum order for % is %', product_name, moq;
    end if;

    line := price * qty;
    new_it := it || jsonb_build_object('unit_price', price, 'subtotal', line);
    items := items || new_it;
    subtotal := subtotal + line;
  end loop;

  new.items := items;
  new.subtotal := subtotal;

  if method = 'pickup' then
    if new.pickup_station_id is null then
      raise exception 'A pickup station is required';
    end if;
    select s.name, s.address
      into station_name, station_address
      from public.pickup_stations s
      where s.id = new.pickup_station_id
        and s.active = true;
    if not found then
      raise exception 'The selected pickup station is unavailable';
    end if;
    new.pickup_station_name := station_name;
    new.pickup_station_address := station_address;
    new.state := null;
    new.lga := null;
    new.delivery_address := null;
    new.delivery_fee := 0;
  else
    if btrim(coalesce(new.state, '')) = '' then
      raise exception 'A delivery state is required';
    end if;
    if length(btrim(coalesce(new.delivery_address, ''))) < 5 then
      raise exception 'A delivery address is required';
    end if;
    select z.delivery_fee
      into zone_fee
      from public.delivery_zones z
      where z.active = true
        and z.state = new.state
        and (z.lga is null or z.lga = '' or z.lga = new.lga)
      order by (z.lga is not null and z.lga <> '') desc, z.id
      limit 1;
    if not found then
      raise exception 'Delivery is not available to % yet', new.state;
    end if;
    new.delivery_fee := zone_fee;
    new.pickup_station_id := null;
    new.pickup_station_name := null;
    new.pickup_station_address := null;
  end if;

  new.fulfillment_method := method;
  new.total := subtotal + coalesce(new.delivery_fee, 0);
  return new;
end;
$$;

create or replace function public.adjust_stock(
  p_product_id uuid,
  p_new_quantity int,
  p_reason text default 'Manual stock adjustment'
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_old    int;
  v_change int;
begin
  if not (public.is_admin() or public.has_permission('inventory')) then
    raise exception 'Not authorised to adjust stock' using errcode = '42501';
  end if;
  if p_new_quantity is null or p_new_quantity < 0 then
    raise exception 'Enter a valid stock quantity';
  end if;

  select stock_quantity into v_old
    from public.products
    where id = p_product_id
    for update;
  if not found then
    raise exception 'Product not found';
  end if;

  v_change := p_new_quantity - coalesce(v_old, 0);
  if v_change = 0 then
    return v_old;
  end if;

  update public.products
    set stock_quantity = p_new_quantity,
        updated_at = now()
    where id = p_product_id;

  insert into public.inventory_movements
    (product_id, change, quantity_after, reason, created_by)
  values
    (p_product_id, v_change, p_new_quantity,
     coalesce(nullif(btrim(p_reason), ''), 'Manual stock adjustment'), auth.uid());

  return p_new_quantity;
end;
$$;

revoke all on function public.adjust_stock(uuid, int, text) from public;
grant execute on function public.adjust_stock(uuid, int, text) to authenticated;

create or replace function public.notify_customer_order_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user  uuid;
  v_title text;
  v_body  text;
begin
  if new.customer_id is null then
    return new;
  end if;
  select c.user_id into v_user from public.customers c where c.id = new.customer_id;
  if v_user is null then
    return new;
  end if;

  v_title := case new.status
    when 'confirmed'       then 'Order confirmed'
    when 'processing'      then 'Order processing'
    when 'ready'           then 'Order ready'
    when 'out for delivery' then 'Order out for delivery'
    when 'completed'       then 'Order completed'
    when 'cancelled'       then 'Order cancelled'
    else 'Order updated'
  end;
  v_body := 'Order ' || coalesce(new.order_number, '') || ' is now ' || replace(new.status, '_', ' ') || '.';

  insert into public.notifications (audience, user_id, kind, title, body, link)
  values ('customer', v_user, 'order', v_title, v_body, '/pages/account.html');
  return new;
end;
$$;

revoke all on function public.notify_customer_order_status() from public;

drop trigger if exists trg_customer_order_status on public.orders;
create trigger trg_customer_order_status
  after update of status on public.orders
  for each row
  when (old.status is distinct from new.status)
  execute function public.notify_customer_order_status();

drop policy if exists "orders_insert_checkout" on public.orders;
create policy "orders_insert_checkout" on public.orders
  for insert with check (
    status = 'pending'
    and payment_status = 'unpaid'
    and paid_at is null
    and payment_reference is null
    and coalesce(amount_paid, 0) = 0
    and (
      customer_id is null
      or exists (
        select 1 from public.customers c
        where c.id = orders.customer_id and c.user_id = auth.uid()
      )
    )
  );
