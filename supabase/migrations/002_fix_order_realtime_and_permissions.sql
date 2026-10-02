-- Idempotent re-assertion of order permissions + realtime, and a staff diagnostics RPC.
-- Safe to run on a database that already applied 001.

-- RPC execute permissions: customers (anon) create orders only through create_order.
revoke all on function public.create_order(text, text, int, text, text, text, jsonb) from public;
grant execute on function public.create_order(text, text, int, text, text, text, jsonb)
  to anon, authenticated;
grant execute on function public.is_staff() to anon, authenticated;

-- Staff read access (RLS also requires is_staff()).
grant select on public.orders, public.order_items, public.staff_profiles to authenticated;
grant update (status, updated_at) on public.orders to authenticated;
grant select on public.categories, public.products to anon, authenticated;

drop policy if exists orders_staff_read on public.orders;
create policy orders_staff_read on public.orders
  for select to authenticated using (public.is_staff());

drop policy if exists order_items_staff_read on public.order_items;
create policy order_items_staff_read on public.order_items
  for select to authenticated using (public.is_staff());

-- Realtime publication for orders (no-op if already present).
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'orders'
  ) then
    alter publication supabase_realtime add table public.orders;
  end if;
end $$;

-- Staff-only health check: shows what the database sees for the signed-in user.
create or replace function public.dari_diagnostics()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select case when public.is_staff() then jsonb_build_object(
    'uid', auth.uid(),
    'is_staff', true,
    'orders_in_realtime', exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'orders'
    ),
    'orders', (select count(*) from public.orders),
    'order_items', (select count(*) from public.order_items),
    'products', (select count(*) from public.products)
  ) else jsonb_build_object('uid', auth.uid(), 'is_staff', false) end;
$$;

revoke all on function public.dari_diagnostics() from public;
grant execute on function public.dari_diagnostics() to authenticated;
