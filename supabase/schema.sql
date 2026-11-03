-- ============================================================
-- REC LIVESTOCK & AGRO FARMS — PostgreSQL Schema (Supabase)
-- Safe to run on a fresh Supabase project (idempotent).
-- Run in this order: schema.sql  →  seed.sql
-- ============================================================

-- ---------- Extensions ----------
create extension if not exists "pgcrypto";

-- ============================================================
-- 1. TABLES
-- ============================================================

-- profiles: one row per auth user (customer or admin)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone text,
  avatar_url text,
  role text not null default 'customer' check (role in ('customer','admin')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- categories
create table if not exists public.categories (
  id bigint generated always as identity primary key,
  name text not null,
  slug text not null unique,
  description text,
  image text,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

-- products
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  category_id bigint references public.categories(id) on delete set null,
  name text not null,
  slug text unique,
  description text,
  price numeric(12,2) not null default 0,
  unit text default 'each',
  image_url text,
  gallery jsonb default '[]'::jsonb,
  stock_quantity int not null default 0,
  minimum_order_quantity int not null default 1,
  online_orderable boolean not null default true,
  featured boolean not null default false,
  active boolean not null default true,
  -- livestock attributes (nullable)
  breed text,
  age text,
  sex text,
  weight text,
  delivery_info text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- size grading (e.g. Large / Medium / Small for eggs)
alter table public.products
  add column if not exists size text;

-- livestock availability on existing products (idempotent)
alter table if exists public.products add column if not exists availability_status text default 'in_stock'
  check (availability_status in ('in_stock','preorder','date','sold_out'));
alter table if exists public.products add column if not exists available_from date;
alter table if exists public.products add column if not exists farm_location text;
alter table if exists public.products add column if not exists pickup_available boolean default true;
alter table if exists public.products add column if not exists delivery_available boolean default true;

-- inventory (stock thresholds per product)
create table if not exists public.inventory (
  id bigint generated always as identity primary key,
  product_id uuid not null unique references public.products(id) on delete cascade,
  min_stock int not null default 5,
  updated_at timestamptz not null default now()
);

-- customers (created on checkout / account creation)
create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique references auth.users(id) on delete set null,
  full_name text not null,
  phone text,
  email text,
  created_at timestamptz not null default now()
);

-- orders
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text unique,
  customer_id uuid references public.customers(id) on delete set null,
  full_name text not null,
  phone text not null,
  email text,
  state text,
  lga text,
  delivery_address text,
  notes text,
  status text not null default 'pending'
    check (status in ('pending','confirmed','processing','ready','out for delivery','completed','cancelled')),
  payment_status text not null default 'unpaid'
    check (payment_status in ('unpaid','paid','refunded')),
  subtotal numeric(12,2) not null default 0,
  delivery_fee numeric(12,2) not null default 0,
  total numeric(12,2) not null default 0,
  items jsonb default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- payment details on existing orders (idempotent)
alter table if exists public.orders add column if not exists payment_method text
  check (payment_method in ('paystack','transfer','pay_on_delivery','manual'));
alter table if exists public.orders add column if not exists payment_reference text;
alter table if exists public.orders add column if not exists paid_at timestamptz;
alter table if exists public.orders add column if not exists amount_paid numeric(12,2) default 0;

-- fulfillment method: delivery (default) or pickup at a station (idempotent)
alter table if exists public.orders add column if not exists fulfillment_method text not null default 'delivery'
  check (fulfillment_method in ('delivery','pickup'));
alter table if exists public.orders add column if not exists pickup_station_id bigint;
alter table if exists public.orders add column if not exists pickup_station_name text;
alter table if exists public.orders add column if not exists pickup_station_address text;

-- order_items (structured copy of order lines)
create table if not exists public.order_items (
  id bigint generated always as identity primary key,
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  name text not null,
  quantity int not null default 1,
  unit_price numeric(12,2) not null default 0,
  subtotal numeric(12,2) not null default 0
);

-- delivery zones
create table if not exists public.delivery_zones (
  id bigint generated always as identity primary key,
  state text not null,
  lga text,
  delivery_fee numeric(12,2) not null default 0,
  estimated_days int,
  active boolean not null default true,
  special_notes text,
  created_at timestamptz not null default now()
);

-- pickup stations (customers select one at checkout instead of delivery)
create table if not exists public.pickup_stations (
  id bigint generated always as identity primary key,
  name text not null unique,
  state text not null,
  city text,
  address text not null,
  contact_phone text,
  operating_hours text,
  pickup_fee numeric(12,2) not null default 0,
  notes text,
  active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_pickup_active on public.pickup_stations(active);
create index if not exists idx_pickup_state on public.pickup_stations(state);

-- idempotent: existing installs get the pickup fee column too
alter table if exists public.pickup_stations add column if not exists pickup_fee numeric(12,2) not null default 0;

-- product batches (poultry = 'REC-<BREED>-YYYY-<seq>')
create table if not exists public.product_batches (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  batch_number text not null,
  breed text,
  hatch_date date,
  total_quantity int not null default 0,
  available_quantity int not null default 0,
  status text not null default 'available'
    check (status in ('available','preorder','sold_out')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_batches_product on public.product_batches(product_id);

-- bulk quote / product enquiry requests (from product pages)
create table if not exists public.bulk_quote_requests (
  id uuid primary key default gen_random_uuid(),
  product_id uuid references public.products(id) on delete set null,
  product_name text,
  name text not null,
  phone text not null,
  email text,
  quantity int not null default 1,
  preferred_date date,
  location text,
  requirements text,
  source text not null default 'quote' check (source in ('quote','enquiry')),
  status text not null default 'new' check (status in ('new','responded','closed')),
  created_at timestamptz not null default now()
);
create index if not exists idx_quotes_status on public.bulk_quote_requests(status);
create index if not exists idx_quotes_created on public.bulk_quote_requests(created_at desc);

-- inventory movement history
create table if not exists public.inventory_movements (
  id bigint generated always as identity primary key,
  product_id uuid not null references public.products(id) on delete cascade,
  batch_id uuid references public.product_batches(id) on delete set null,
  change int not null,
  quantity_after int,
  reason text,
  reference text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists idx_movements_product on public.inventory_movements(product_id, created_at desc);

-- idempotent fix for databases created before the FK pointed at auth.users
alter table public.inventory_movements drop constraint if exists inventory_movements_created_by_fkey;
alter table public.inventory_movements add constraint inventory_movements_created_by_fkey
  foreign key (created_by) references auth.users(id) on delete set null;

-- site settings (single row)
create table if not exists public.site_settings (
  id bigint primary key default 1 check (id = 1),
  business_name text default 'REC Livestock & Agro Farms Enterprises',
  motto text default 'Growing Excellence, Feeding the Future.',
  phone text default '+234 813 504 2997',
  whatsapp text default '+2347071850599',
  email text default 'reclivestockagrofarms@gmail.com',
  address text default 'Lagos, Nigeria',
  delivery_note text default 'We deliver across all 36 states of Nigeria and the FCT.',
  logo_url text,
  hero_image text,
  about_image text,
  social_whatsapp text,
  social_facebook text,
  social_instagram text,
  social_tiktok text,
  social_youtube text,
  social_telegram text,
  website text,
  whatsapp_channel text,
  whatsapp_group text,
  telegram_channel text,
  telegram_group text,
  updated_at timestamptz not null default now()
);

alter table public.site_settings add column if not exists website text;
alter table public.site_settings add column if not exists whatsapp_channel text;
alter table public.site_settings add column if not exists whatsapp_group text;
alter table public.site_settings add column if not exists telegram_channel text;
alter table public.site_settings add column if not exists telegram_group text;

-- testimonials
create table if not exists public.testimonials (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  location text,
  message text not null,
  photo_url text,
  rating int not null default 5 check (rating between 1 and 5),
  sample boolean not null default false,
  published boolean not null default false,
  created_at timestamptz not null default now()
);

-- blog posts
create table if not exists public.blog_posts (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  excerpt text,
  content text,
  image text,
  category text,
  author text default 'REC Farm Team',
  published boolean not null default false,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- contact messages
create table if not exists public.contact_messages (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  email text,
  phone text,
  subject text,
  message text not null,
  handled boolean not null default false,
  created_at timestamptz not null default now()
);

-- favorites
create table if not exists public.favorites (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, product_id)
);

-- product_reviews: customer ratings & comments, moderated by admin.
-- Reviews are NOT published automatically — admin must set approved = true.
create table if not exists public.product_reviews (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  author_name text not null,
  rating int not null default 5 check (rating between 1 and 5),
  comment text not null,
  approved boolean not null default false,
  featured boolean not null default false,
  created_at timestamptz not null default now()
);

-- customers may edit their own review; stamp the last edit time.
alter table public.product_reviews
  add column if not exists updated_at timestamptz not null default now();

-- ============================================================
-- 2. INDEXES
-- ============================================================
create index if not exists idx_products_category on public.products(category_id);
create index if not exists idx_products_active on public.products(active);
create index if not exists idx_products_featured on public.products(featured);
create index if not exists idx_products_online on public.products(online_orderable);
create index if not exists idx_orders_number on public.orders(order_number);
create index if not exists idx_orders_status on public.orders(status);
create index if not exists idx_orders_customer on public.orders(customer_id);
create index if not exists idx_order_items_order on public.order_items(order_id);
create index if not exists idx_delivery_state on public.delivery_zones(state);
create unique index if not exists idx_delivery_state_unique on public.delivery_zones(state);
create index if not exists idx_blog_published on public.blog_posts(published);
create index if not exists idx_testimonials_published on public.testimonials(published);
create index if not exists idx_contact_created on public.contact_messages(created_at);
create index if not exists idx_reviews_product on public.product_reviews(product_id);
create index if not exists idx_reviews_approved on public.product_reviews(approved);
create index if not exists idx_reviews_featured on public.product_reviews(featured);
create index if not exists idx_reviews_created on public.product_reviews(created_at);
create index if not exists idx_reviews_user on public.product_reviews(user_id);
-- one review per customer per product (enforced even under races)
create unique index if not exists idx_reviews_product_user on public.product_reviews(product_id, user_id);

-- ============================================================
-- 3. TRIGGERS & FUNCTIONS
-- ============================================================

-- updated_at maintenance
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_products_updated on public.products;
create trigger trg_products_updated before update on public.products
  for each row execute function public.set_updated_at();

drop trigger if exists trg_orders_updated on public.orders;
create trigger trg_orders_updated before update on public.orders
  for each row execute function public.set_updated_at();

drop trigger if exists trg_profiles_updated on public.profiles;
create trigger trg_profiles_updated before update on public.profiles
  for each row execute function public.set_updated_at();

drop trigger if exists trg_blog_updated on public.blog_posts;
create trigger trg_blog_updated before update on public.blog_posts
  for each row execute function public.set_updated_at();

-- is_admin(): SECURITY DEFINER avoids recursive RLS on profiles
create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

-- auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, phone, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    coalesce(new.raw_user_meta_data->>'phone', ''),
    'customer'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- prevent non-admins from changing their own role
--
-- The "profiles_update_own_or_admin" policy lets a user UPDATE their own row,
-- so without this trigger any signed-up customer could set role='admin' on
-- themselves. The trigger is therefore load-bearing.
--
-- It must not, however, block the creation of the very first admin. An earlier
-- version required is_admin(), which is false for everyone until an admin
-- exists -- so the only way to promote the first admin was to disable this
-- trigger, which is a bootstrap deadlock.
--
-- A role change is permitted for exactly three identities:
--   1. an existing admin              -> public.is_admin()
--   2. the SQL editor / Supabase Studio -> session_user in (postgres, supabase_admin)
--   3. the service_role key (server side) -> current_user = 'service_role'
-- A regular authenticated browser session is none of these, so the escalation
-- path stays closed with no bootstrap window.
create or replace function public.protect_profile_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'UPDATE' and new.role is distinct from old.role then
    if public.is_admin() then
      return new;
    end if;
    if session_user in ('postgres', 'supabase_admin') then
      return new;
    end if;
    if current_user = 'service_role' then
      return new;
    end if;
    raise exception 'You cannot change your own role';
  end if;
  return new;
end;
$$;

drop trigger if exists protect_profile_role on public.profiles;
create trigger protect_profile_role before update on public.profiles
  for each row execute function public.protect_profile_role();

-- order number: REC-YYYY-XXXXXXXX (random; seq kept for legacy orders)
create sequence if not exists public.order_number_seq start 1;

create or replace function public.assign_order_number()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.order_number is null or new.order_number = '' then
    -- random suffix (not sequential) so references cannot be enumerated
    new.order_number = 'REC-' || to_char(now(), 'YYYY') || '-' ||
      upper(substring(md5(random()::text || clock_timestamp()::text) from 1 for 8));
  end if;
  return new;
end;
$$;

drop trigger if exists trg_assign_order_number on public.orders;
create trigger trg_assign_order_number before insert on public.orders
  for each row execute function public.assign_order_number();

-- keep order_items in sync when jsonb items are provided
create or replace function public.sync_order_items()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  it jsonb;
begin
  if new.items is not null and jsonb_array_length(new.items) > 0 then
    delete from public.order_items where order_id = new.id;
    for it in select jsonb_array_elements(new.items) loop
      insert into public.order_items (order_id, product_id, name, quantity, unit_price, subtotal)
      values (
        new.id,
        case when it->>'product_id' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
          then (it->>'product_id')::uuid else null end,
        coalesce(it->>'name','Item'),
        coalesce((it->>'quantity')::int, 1),
        coalesce((it->>'unit_price')::numeric, coalesce((it->>'price')::numeric, 0)),
        coalesce((it->>'subtotal')::numeric,
          coalesce((it->>'quantity')::int, 1) * coalesce((it->>'unit_price')::numeric, coalesce((it->>'price')::numeric, 0)))
      );
    end loop;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_sync_order_items on public.orders;
create trigger trg_sync_order_items
  after insert or update of items on public.orders
  for each row execute function public.sync_order_items();

-- reserve stock when an order is placed and log inventory movements
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

drop trigger if exists trg_log_order_movements on public.orders;
create trigger trg_log_order_movements after insert on public.orders
  for each row execute function public.log_order_movements();

-- never trust client-supplied prices: recompute each line from products.price,
-- then the subtotal and total, before the row is written. This closes the
-- "checkout with a tampered cart" underpayment hole.
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

drop trigger if exists trg_validate_order_amounts on public.orders;
create trigger trg_validate_order_amounts before insert on public.orders
  for each row execute function public.validate_order_amounts();

-- restore stock / batch availability when an order is cancelled
create or replace function public.restock_on_cancel()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  it jsonb;
  pid uuid;
  qty int;
  new_stock int;
  new_batch uuid;
begin
  if new.status = 'cancelled' and old.status is distinct from 'cancelled' and new.items is not null then
    for it in select jsonb_array_elements(new.items) loop
      pid := case when it->>'product_id' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        then (it->>'product_id')::uuid else null end;
      qty := coalesce((it->>'quantity')::int, 0);
      continue when pid is null or qty <= 0;
      update public.products
        set stock_quantity = stock_quantity + qty,
            updated_at = now()
        where id = pid
        returning stock_quantity into new_stock;
      select id into new_batch
        from public.product_batches
        where product_id = pid and status = 'available'
        order by created_at limit 1;
      if new_batch is not null then
        update public.product_batches
          set available_quantity = available_quantity + qty,
              updated_at = now()
          where id = new_batch;
      end if;
      insert into public.inventory_movements (product_id, batch_id, change, quantity_after, reason, reference)
      values (pid, new_batch, qty, new_stock, 'Order cancelled — stock restored', new.order_number);
    end loop;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_restock_on_cancel on public.orders;
create trigger trg_restock_on_cancel after update of status on public.orders
  for each row execute function public.restock_on_cancel();

-- guest order tracking RPC (returns limited fields only)
create or replace function public.track_order(p_reference text)
returns table (
  order_number text,
  status text,
  payment_status text,
  total numeric,
  state text,
  lga text,
  fulfillment_method text,
  pickup_station_name text,
  pickup_station_address text,
  created_at timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  select o.order_number, o.status, o.payment_status, o.total, o.state, o.lga,
         o.fulfillment_method, o.pickup_station_name, o.pickup_station_address,
         o.created_at
  from public.orders o
  where upper(o.order_number) = upper(p_reference)
  limit 1;
$$;

-- inventory status helper
create or replace view public.inventory_status
with (security_invoker = on) as
select
  p.id as product_id,
  p.name,
  p.stock_quantity,
  coalesce(i.min_stock, 5) as min_stock,
  case
    when p.stock_quantity <= 0 then 'Out of Stock'
    when p.stock_quantity <= coalesce(i.min_stock, 5) then 'Low Stock'
    else 'In Stock'
  end as status
from public.products p
left join public.inventory i on i.product_id = p.id;

-- aggregate rating per product (approved reviews only)
create or replace view public.product_rating_stats
with (security_invoker = on) as
select
  r.product_id,
  count(*) as review_count,
  round(avg(r.rating)::numeric, 1) as average_rating
from public.product_reviews r
where r.approved = true
group by r.product_id;

-- ensure inventory row exists for each product
create or replace function public.ensure_inventory()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  insert into public.inventory (product_id) values (new.id)
  on conflict (product_id) do nothing;
  return new;
end;
$$;

drop trigger if exists trg_ensure_inventory on public.products;
create trigger trg_ensure_inventory after insert on public.products
  for each row execute function public.ensure_inventory();

-- stamp updated_at on every review edit (owner edits and admin moderation)
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_reviews_touch on public.product_reviews;
create trigger trg_reviews_touch before update on public.product_reviews
  for each row execute function public.touch_updated_at();

-- ============================================================
-- 4. ROW LEVEL SECURITY
-- ============================================================
alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.inventory enable row level security;
alter table public.customers enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.delivery_zones enable row level security;
alter table if exists public.pickup_stations enable row level security;
alter table public.site_settings enable row level security;
alter table public.testimonials enable row level security;
alter table public.blog_posts enable row level security;
alter table public.contact_messages enable row level security;
alter table public.favorites enable row level security;
alter table public.product_reviews enable row level security;
alter table if exists public.product_batches enable row level security;
alter table if exists public.bulk_quote_requests enable row level security;
alter table if exists public.inventory_movements enable row level security;

-- profiles
drop policy if exists "profiles_select_own_or_admin" on public.profiles;
create policy "profiles_select_own_or_admin" on public.profiles
  for select using (auth.uid() = id or public.is_admin());

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles
  for insert with check (auth.uid() = id);

drop policy if exists "profiles_update_own_or_admin" on public.profiles;
create policy "profiles_update_own_or_admin" on public.profiles
  for update using (auth.uid() = id or public.is_admin())
  with check (auth.uid() = id or public.is_admin());

drop policy if exists "profiles_admin_delete" on public.profiles;
create policy "profiles_admin_delete" on public.profiles
  for delete using (public.is_admin());

-- categories: public read, admin write
drop policy if exists "categories_public_read" on public.categories;
create policy "categories_public_read" on public.categories
  for select using (true);

drop policy if exists "categories_admin_write" on public.categories;
create policy "categories_admin_write" on public.categories
  for all using (public.is_admin()) with check (public.is_admin());

-- products: anyone reads active; admin reads all / writes
drop policy if exists "products_public_read" on public.products;
create policy "products_public_read" on public.products
  for select using (active = true or public.is_admin());

drop policy if exists "products_admin_write" on public.products;
create policy "products_admin_write" on public.products
  for all using (public.is_admin()) with check (public.is_admin());

-- inventory: public read, admin write
drop policy if exists "inventory_public_read" on public.inventory;
create policy "inventory_public_read" on public.inventory for select using (true);
drop policy if exists "inventory_admin_write" on public.inventory;
create policy "inventory_admin_write" on public.inventory
  for all using (public.is_admin()) with check (public.is_admin());

-- customers: own rows + admin; anyone may create on checkout
drop policy if exists "customers_insert_any" on public.customers;
create policy "customers_insert_any" on public.customers
  for insert with check (true);

drop policy if exists "customers_select_own_or_admin" on public.customers;
create policy "customers_select_own_or_admin" on public.customers
  for select using (auth.uid() = user_id or public.is_admin());

drop policy if exists "customers_update_own_or_admin" on public.customers;
create policy "customers_update_own_or_admin" on public.customers
  for update using (auth.uid() = user_id or public.is_admin())
  with check (auth.uid() = user_id or public.is_admin());

-- orders: checkout creates orders (anon ok); customers read own; admin reads/updates all
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

drop policy if exists "orders_select_own_or_admin" on public.orders;
create policy "orders_select_own_or_admin" on public.orders
  for select using (
    public.is_admin()
    or (customer_id is not null
        and exists (select 1 from public.customers c
                    where c.id = orders.customer_id and c.user_id = auth.uid()))
  );

drop policy if exists "orders_update_admin" on public.orders;
create policy "orders_update_admin" on public.orders
  for update using (public.is_admin()) with check (public.is_admin());

drop policy if exists "orders_delete_admin" on public.orders;
create policy "orders_delete_admin" on public.orders
  for delete using (public.is_admin());

-- order_items: admin only (customers see order.items jsonb)
drop policy if exists "order_items_admin_read" on public.order_items;
create policy "order_items_admin_read" on public.order_items
  for select using (public.is_admin());

-- delivery zones: public read active, admin write
drop policy if exists "delivery_public_read" on public.delivery_zones;
create policy "delivery_public_read" on public.delivery_zones
  for select using (active = true or public.is_admin());

drop policy if exists "delivery_admin_write" on public.delivery_zones;
create policy "delivery_admin_write" on public.delivery_zones
  for all using (public.is_admin()) with check (public.is_admin());

-- pickup stations: public read active, admin write
drop policy if exists "pickup_public_read" on public.pickup_stations;
create policy "pickup_public_read" on public.pickup_stations
  for select using (active = true or public.is_admin());

drop policy if exists "pickup_admin_write" on public.pickup_stations;
create policy "pickup_admin_write" on public.pickup_stations
  for all using (public.is_admin()) with check (public.is_admin());

-- site settings: public read, admin write
drop policy if exists "settings_public_read" on public.site_settings;
create policy "settings_public_read" on public.site_settings
  for select using (true);

drop policy if exists "settings_admin_write" on public.site_settings;
create policy "settings_admin_write" on public.site_settings
  for all using (public.is_admin()) with check (public.is_admin());

-- testimonials: public reads published; admin manages
drop policy if exists "testimonials_public_read" on public.testimonials;
create policy "testimonials_public_read" on public.testimonials
  for select using (published = true or public.is_admin());

drop policy if exists "testimonials_admin_write" on public.testimonials;
create policy "testimonials_admin_write" on public.testimonials
  for all using (public.is_admin()) with check (public.is_admin());

-- blog: public reads published; admin manages
drop policy if exists "blog_public_read" on public.blog_posts;
create policy "blog_public_read" on public.blog_posts
  for select using (published = true or public.is_admin());

drop policy if exists "blog_admin_write" on public.blog_posts;
create policy "blog_admin_write" on public.blog_posts
  for all using (public.is_admin()) with check (public.is_admin());

-- contact messages: anyone may send; only admin reads
drop policy if exists "contact_insert_any" on public.contact_messages;
create policy "contact_insert_any" on public.contact_messages
  for insert with check (true);

drop policy if exists "contact_admin_read" on public.contact_messages;
create policy "contact_admin_read" on public.contact_messages
  for select using (public.is_admin());

drop policy if exists "contact_admin_update" on public.contact_messages;
create policy "contact_admin_update" on public.contact_messages
  for update using (public.is_admin()) with check (public.is_admin());

drop policy if exists "contact_admin_delete" on public.contact_messages;
create policy "contact_admin_delete" on public.contact_messages
  for delete using (public.is_admin());

-- favorites
drop policy if exists "favorites_own" on public.favorites;
create policy "favorites_own" on public.favorites
  for all using (auth.uid() = user_id or public.is_admin())
  with check (auth.uid() = user_id or public.is_admin());

-- product_reviews: anyone reads approved; admins moderate all; a
-- signed-in customer may submit a review (goes to moderation) and
-- may delete or edit their own submission. An owner edit must reset
-- approved to false, so an edited review re-enters moderation —
-- approve/feature stays admin-only so customers cannot self-publish.
drop policy if exists "reviews_public_read" on public.product_reviews;
create policy "reviews_public_read" on public.product_reviews
  for select using (approved = true or public.is_admin());

drop policy if exists "reviews_insert_own" on public.product_reviews;
create policy "reviews_insert_own" on public.product_reviews
  for insert with check (
    (auth.uid() = user_id and approved = false) or public.is_admin()
  );

drop policy if exists "reviews_update_admin" on public.product_reviews;
drop policy if exists "reviews_update_own_or_admin" on public.product_reviews;
create policy "reviews_update_own_or_admin" on public.product_reviews
  for update using (public.is_admin() or auth.uid() = user_id)
  with check (
    public.is_admin()
    or (auth.uid() = user_id and approved = false)
  );

drop policy if exists "reviews_delete_own_or_admin" on public.product_reviews;
create policy "reviews_delete_own_or_admin" on public.product_reviews
  for delete using (auth.uid() = user_id or public.is_admin());

-- product batches: public reads batches for active products; admin writes
drop policy if exists "batches_public_read" on public.product_batches;
create policy "batches_public_read" on public.product_batches
  for select using (
    public.is_admin()
    or exists (
      select 1 from public.products p
      where p.id = product_batches.product_id and p.active = true
    )
  );

drop policy if exists "batches_admin_write" on public.product_batches;
create policy "batches_admin_write" on public.product_batches
  for all using (public.is_admin()) with check (public.is_admin());

-- bulk quote requests: anyone may submit; only admins read / manage
drop policy if exists "quotes_insert_any" on public.bulk_quote_requests;
create policy "quotes_insert_any" on public.bulk_quote_requests
  for insert with check (true);

drop policy if exists "quotes_admin_all" on public.bulk_quote_requests;
create policy "quotes_admin_all" on public.bulk_quote_requests
  for all using (public.is_admin()) with check (public.is_admin());

-- inventory movements: admin only (public sees live stock via products)
drop policy if exists "movements_admin_read" on public.inventory_movements;
create policy "movements_admin_read" on public.inventory_movements
  for select using (public.is_admin());

drop policy if exists "movements_admin_write" on public.inventory_movements;
create policy "movements_admin_write" on public.inventory_movements
  for all using (public.is_admin()) with check (public.is_admin());

-- ============================================================
-- 5. STORAGE (product images, farm photos, logo)
-- ============================================================
insert into storage.buckets (id, name, public)
values ('rec-media', 'rec-media', true)
on conflict (id) do nothing;

drop policy if exists "rec_media_public_read" on storage.objects;
create policy "rec_media_public_read" on storage.objects
  for select using (bucket_id = 'rec-media');

drop policy if exists "rec_media_admin_insert" on storage.objects;
create policy "rec_media_admin_insert" on storage.objects
  for insert with check (bucket_id = 'rec-media' and public.is_admin());

drop policy if exists "rec_media_admin_update" on storage.objects;
create policy "rec_media_admin_update" on storage.objects
  for update using (bucket_id = 'rec-media' and public.is_admin());

drop policy if exists "rec_media_admin_delete" on storage.objects;
create policy "rec_media_admin_delete" on storage.objects
  for delete using (bucket_id = 'rec-media' and public.is_admin());

-- ============================================================
-- NOTES
-- ============================================================
-- * Public website uses the ANON key only. All writes are gated by RLS.
-- * Never expose the service_role key in HTML/JS/GitHub/Vercel client env.
-- * Create your first admin in Supabase Studio -> Authentication -> Users
--   (add the user; the handle_new_user trigger creates the profile row as
--   role='customer'), then promote them from the SQL Editor:
--
--     update public.profiles
--     set role = 'admin', full_name = 'Farm Admin'
--     where id = (select id from auth.users where email = 'you@example.com');
--
--   Note: public.profiles has NO email column -- join through auth.users.
--   Running this from the SQL editor is allowed by protect_profile_role
--   (session_user = postgres); you do NOT need to disable the trigger.
-- * Optional Vercel server functions may use the service key ONLY server-side.