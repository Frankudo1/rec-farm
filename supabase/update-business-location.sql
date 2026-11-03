-- ============================================================
-- REC LIVESTOCK & AGRO FARMS — Business location correction
--
-- Owner confirmed the public business location is Lagos, Nigeria.
-- The live site_settings row currently says Abuja, so this migration
-- corrects the single settings row without touching any other data.
--
-- Safe to run more than once. No tables, columns or rows are dropped.
--
-- Apply in Supabase SQL Editor after the existing migration chain:
--   update-order-integrity.sql -> update-business-location.sql
-- ============================================================

begin;

insert into public.site_settings (id, address)
values (1, 'Lagos, Nigeria')
on conflict (id) do update
set address = excluded.address,
    updated_at = now();

commit;
