-- Visitor meals: family members eating with a resident scan the meal QR sign,
-- type the resident's name and how many people are eating. The meal is free.
-- Run once in the meal (Zone Defense) Supabase project → SQL Editor. Safe to run again.
--
-- Privacy: the meal pages use the public key, so this table is ADD-ONLY for them.
-- Nobody can read the resident names back through the app; reports use
-- visitor_meal_counts(), which returns only numbers (visits and people per day and meal).

create table if not exists visitor_meals (
  id            uuid primary key default gen_random_uuid(),
  facility_id   uuid not null references facilities(id),
  resident_name text not null check (char_length(btrim(resident_name)) between 2 and 80),
  party_size    integer not null check (party_size between 1 and 20),
  created_at    timestamptz not null default now()
);
create index if not exists visitor_meals_day_idx on visitor_meals (facility_id, created_at);

alter table visitor_meals enable row level security;
drop policy if exists visitor_meals_add on visitor_meals;
create policy visitor_meals_add on visitor_meals for insert to anon, authenticated with check (true);
-- No select / update / delete policy: the public key can only add a visit.
revoke all on visitor_meals from anon, authenticated;
grant insert (facility_id, resident_name, party_size) on visitor_meals to anon, authenticated;

-- Counts only (no names). Meal is worked out from the time (Eastern):
-- breakfast before 10:30 am, lunch until 4:00 pm, dinner after that.
-- p_facility null = every building. At most 400 days per call.
create or replace function visitor_meal_counts(p_facility uuid, p_from date, p_to date)
returns table (facility_id uuid, day date, meal text, visits integer, people integer)
language sql
stable
security definer
set search_path = public
as $$
  with v as (
    select m.facility_id,
           (m.created_at at time zone 'America/New_York') as local_at,
           m.party_size
      from visitor_meals m
     where (p_facility is null or m.facility_id = p_facility)
       and m.created_at >= (p_from::timestamp at time zone 'America/New_York')
       and m.created_at <  ((least(p_to, p_from + 400) + 1)::timestamp at time zone 'America/New_York')
  )
  select v.facility_id,
         v.local_at::date as day,
         case when v.local_at::time < time '10:30' then 'breakfast'
              when v.local_at::time < time '16:00' then 'lunch'
              else 'dinner' end as meal,
         count(*)::integer as visits,
         sum(v.party_size)::integer as people
    from v
   group by 1, 2, 3
   order by 2, 1, 3;
$$;
revoke all on function visitor_meal_counts(uuid, date, date) from public;
grant execute on function visitor_meal_counts(uuid, date, date) to anon, authenticated;
