-- Visitor meals, part 2: keep employees from using the free visitor meal.
--   1. A 4-digit visitor code that changes every day (front desk gives it to families).
--      The database checks the code, so the page can't be skipped.
--      20 wrong codes in 10 minutes at a building = no codes accepted there for 10 minutes.
--   2. (The page blocks phones used for an employee check-in; no SQL needed.)
--   3. visitor_meal_flags(): unusual patterns, numbers only (no resident names).
-- Run once in the meal (Zone Defense) Supabase project → SQL Editor, AFTER
-- 2026-11-12_visitor_meals.sql. Safe to run again. Merge the page change right after.

-- One random secret per building; today's code is worked out from it. Nobody can read it.
create table if not exists visitor_code_secrets (
  facility_id uuid primary key references facilities(id),
  secret      text not null default replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', ''),
  created_at  timestamptz not null default now()
);
alter table visitor_code_secrets enable row level security;
revoke all on visitor_code_secrets from anon, authenticated;
insert into visitor_code_secrets (facility_id) select id from facilities on conflict (facility_id) do nothing;

-- Every code typed on the visitor screen (right or wrong), for the lockout and the flags.
create table if not exists visitor_code_attempts (
  id          bigserial primary key,
  facility_id uuid not null references facilities(id),
  ok          boolean not null,
  at          timestamptz not null default now()
);
create index if not exists visitor_code_attempts_idx on visitor_code_attempts (facility_id, at);
alter table visitor_code_attempts enable row level security;
revoke all on visitor_code_attempts from anon, authenticated;

-- Visits can now only be added through add_visitor_meal() (which checks the code).
drop policy if exists visitor_meals_add on visitor_meals;
revoke all on visitor_meals from anon, authenticated;

-- The code for a building on a day (internal).
create or replace function visitor_code_for(p_facility uuid, p_day date)
returns text language sql stable security definer set search_path = public as $$
  select lpad(((('x' || substr(md5(s.secret || ':' || p_day::text), 1, 8))::bit(32)::bigint & 2147483647) % 10000)::text, 4, '0')
    from visitor_code_secrets s where s.facility_id = p_facility;
$$;
revoke all on function visitor_code_for(uuid, date) from public, anon, authenticated;

-- Today's and tomorrow's code (Eastern dates), for the Meal Admin page.
create or replace function visitor_code_today(p_facility uuid)
returns table (today text, tomorrow text) language sql stable security definer set search_path = public as $$
  select visitor_code_for(p_facility, (now() at time zone 'America/New_York')::date),
         visitor_code_for(p_facility, (now() at time zone 'America/New_York')::date + 1);
$$;
revoke all on function visitor_code_today(uuid) from public;
grant execute on function visitor_code_today(uuid) to anon, authenticated;

-- Add a visit. Returns 'ok', 'wrong_code', 'locked' or 'invalid'.
create or replace function add_visitor_meal(p_facility uuid, p_resident text, p_party integer, p_code text)
returns text language plpgsql volatile security definer set search_path = public as $$
declare
  v_name text := regexp_replace(btrim(coalesce(p_resident, '')), '\s+', ' ', 'g');
begin
  if p_facility is null or not exists (select 1 from visitor_code_secrets where facility_id = p_facility) then return 'invalid'; end if;
  if char_length(v_name) < 2 or char_length(v_name) > 80 or p_party is null or p_party < 1 or p_party > 20 then return 'invalid'; end if;
  if (select count(*) from visitor_code_attempts
       where facility_id = p_facility and not ok and at > now() - interval '10 minutes') >= 20 then
    return 'locked';
  end if;
  if btrim(coalesce(p_code, '')) is distinct from visitor_code_for(p_facility, (now() at time zone 'America/New_York')::date) then
    insert into visitor_code_attempts (facility_id, ok) values (p_facility, false);
    return 'wrong_code';
  end if;
  insert into visitor_code_attempts (facility_id, ok) values (p_facility, true);
  insert into visitor_meals (facility_id, resident_name, party_size) values (p_facility, v_name, p_party);
  return 'ok';
end;
$$;
revoke all on function add_visitor_meal(uuid, text, integer, text) from public;
grant execute on function add_visitor_meal(uuid, text, integer, text) to anon, authenticated;

-- Unusual patterns between two dates, numbers only. kind:
--   wrong_codes   wrong visitor codes typed that day (3 or more)
--   same_meal     resident names on more than one ticket at the same meal that day
--   shift_change  tickets at shift change (6:30-7:30 am, 2:30-3:30 pm, 6:30-7:30 pm)
--   spike         a day with more than double the usual visitor meals (10 or more)
--   frequent      resident names used on 5 or more different days in the dates chosen
create or replace function visitor_meal_flags(p_facility uuid, p_from date, p_to date)
returns table (kind text, day date, meal text, n integer)
language sql stable security definer set search_path = public as $$
  with rng as (
    select (p_from::timestamp at time zone 'America/New_York') as t0,
           ((least(p_to, p_from + 400) + 1)::timestamp at time zone 'America/New_York') as t1
  ),
  v as (
    select (m.created_at at time zone 'America/New_York') as local_at,
           lower(regexp_replace(btrim(m.resident_name), '\s+', ' ', 'g')) as who,
           m.party_size
      from visitor_meals m, rng
     where m.facility_id = p_facility and m.created_at >= rng.t0 and m.created_at < rng.t1
  ),
  vm as (
    select local_at::date as day,
           case when local_at::time < time '10:30' then 'breakfast' when local_at::time < time '16:00' then 'lunch' else 'dinner' end as meal,
           local_at::time as t, who, party_size
      from v
  ),
  per_day as (select day, sum(party_size) as people from vm group by day),
  avg_day as (select avg(people) as a from per_day)
  select 'wrong_codes', (a.at at time zone 'America/New_York')::date, null::text, count(*)::integer
    from visitor_code_attempts a, rng
   where a.facility_id = p_facility and not a.ok and a.at >= rng.t0 and a.at < rng.t1
   group by 2 having count(*) >= 3
  union all
  select 'same_meal', day, meal, count(*)::integer
    from (select day, meal, who from vm group by day, meal, who having count(*) > 1) x
   group by day, meal
  union all
  select 'shift_change', day, null, count(*)::integer
    from vm
   where t between time '06:30' and time '07:30' or t between time '14:30' and time '15:30' or t between time '18:30' and time '19:30'
   group by day
  union all
  select 'spike', p.day, null, p.people::integer
    from per_day p, avg_day
   where (select count(*) from per_day) >= 5 and p.people >= 10 and p.people > 2 * avg_day.a
  union all
  select 'frequent', null, null, count(*)::integer
    from (select who from vm group by who having count(distinct day) >= 5) f
  having count(*) > 0
  order by 2 desc nulls first, 1;
$$;
revoke all on function visitor_meal_flags(uuid, date, date) from public;
grant execute on function visitor_meal_flags(uuid, date, date) to anon, authenticated;
