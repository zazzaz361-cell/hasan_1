-- Daily restaurant-local order numbering and staff-only processed-order deletion.

alter table public.orders
  add column if not exists order_date date;

with numbered_orders as (
  select
    id,
    (created_at at time zone 'Asia/Baghdad')::date as local_order_date,
    row_number() over (
      partition by (created_at at time zone 'Asia/Baghdad')::date
      order by created_at, id
    )::bigint as daily_order_number
  from public.orders
)
update public.orders as orders
set order_date = numbered_orders.local_order_date,
    order_number = numbered_orders.daily_order_number
from numbered_orders
where orders.id = numbered_orders.id
  and orders.order_date is null;

alter table public.orders
  alter column order_date set not null,
  alter column order_number drop identity if exists;

create table if not exists public.order_daily_counters (
  order_date date primary key,
  last_number bigint not null check (last_number > 0)
);

revoke all on public.order_daily_counters from public, anon, authenticated;
alter table public.order_daily_counters enable row level security;

insert into public.order_daily_counters (order_date, last_number)
select order_date, max(order_number)
from public.orders
group by order_date
on conflict (order_date) do update
set last_number = greatest(
  public.order_daily_counters.last_number,
  excluded.last_number
);

create unique index if not exists orders_order_date_number_uidx
  on public.orders (order_date, order_number);

create or replace function public.assign_daily_order_number()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_order_date date;
  v_order_number bigint;
begin
  v_order_date := (new.created_at at time zone 'Asia/Baghdad')::date;

  insert into public.order_daily_counters (order_date, last_number)
  values (v_order_date, 1)
  on conflict (order_date) do update
    set last_number = public.order_daily_counters.last_number + 1
  returning last_number into v_order_number;

  new.order_date := v_order_date;
  new.order_number := v_order_number;
  return new;
end;
$$;

revoke all on function public.assign_daily_order_number() from public;

drop trigger if exists orders_assign_daily_order_number on public.orders;
create trigger orders_assign_daily_order_number
  before insert on public.orders
  for each row execute function public.assign_daily_order_number();

create or replace function public.delete_processed_order(p_order_id uuid)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_deleted_id uuid;
begin
  if not public.is_staff() then
    raise exception 'not_authorized';
  end if;

  delete from public.orders
  where id = p_order_id
    and status in ('CONFIRMED', 'PREPARING', 'READY', 'COMPLETED', 'CANCELLED')
  returning id into v_deleted_id;

  if v_deleted_id is null then
    raise exception 'order_not_deletable';
  end if;

  return v_deleted_id;
end;
$$;

create or replace function public.delete_processed_orders()
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_deleted_ids jsonb;
begin
  if not public.is_staff() then
    raise exception 'not_authorized';
  end if;

  with deleted_orders as (
    delete from public.orders
    where status in ('CONFIRMED', 'PREPARING', 'READY', 'COMPLETED', 'CANCELLED')
    returning id
  )
  select coalesce(jsonb_agg(id), '[]'::jsonb)
  into v_deleted_ids
  from deleted_orders;

  return v_deleted_ids;
end;
$$;

revoke all on function public.delete_processed_order(uuid) from public;
revoke all on function public.delete_processed_orders() from public;
revoke execute on function public.delete_processed_order(uuid) from anon;
revoke execute on function public.delete_processed_orders() from anon;
grant execute on function public.delete_processed_order(uuid) to authenticated;
grant execute on function public.delete_processed_orders() to authenticated;
