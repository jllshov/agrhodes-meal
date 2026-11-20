-- Visitor meals, part 3: room numbers instead of resident names.
-- Visitors now type the ROOM they are visiting. Resident names are no longer collected,
-- and every name saved so far is erased (old visits stay as counts, with no name and no room).
--
-- Run once in the meal (Zone Defense) Supabase project → SQL Editor, right after the
-- page update is live. Safe to run again.

-- 1. Erase saved names, then remove the column.
alter table visitor_meals add column if not exists room_number text;
do $$
begin
  if exists (select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'visitor_meals' and column_name = 'resident_name') then
    alter table visitor_meals alter column resident_name drop not null;
    alter table visitor_meals drop constraint if exists visitor_meals_resident_name_check;
    update visitor_meals set resident_name = null where resident_name is not null;
    alter table visitor_meals drop column resident_name;
  end if;
end $$;
alter table visitor_meals drop constraint if exists visitor_meals_room_number_check;
alter table visitor_meals add constraint visitor_meals_room_number_check
  check (room_number is null or (room_number ~ '^[A-Z0-9-]{1,10}$' and room_number ~ '[0-9]'));

-- 2. Add a visit by room number. Returns 'ok', 'wrong_code', 'locked', 'unknown_room' or 'invalid'.
--    The room must be an active resident room in that building (Zone Defense room list).
--    If a building has no rooms loaded yet, any well-formed room number is accepted.
drop function if exists add_visitor_meal(uuid, text, integer, text);
create or replace function add_visitor_meal(p_facility uuid, p_room text, p_party integer, p_code text)
returns text language plpgsql volatile security definer set search_path = public as $$
declare
  v_room text := upper(regexp_replace(coalesce(p_room, ''), '\s+', '', 'g'));
begin
  if p_facility is null or not exists (select 1 from visitor_code_secrets where facility_id = p_facility) then return 'invalid'; end if;
  -- A room number must contain a digit, so a typed name can never be saved as a "room".
  if v_room !~ '^[A-Z0-9-]{1,10}$' or v_room !~ '[0-9]' or p_party is null or p_party < 1 or p_party > 20 then return 'invalid'; end if;
  if (select count(*) from visitor_code_attempts
       where facility_id = p_facility and not ok and at > now() - interval '10 minutes') >= 20 then
    return 'locked';
  end if;
  if btrim(coalesce(p_code, '')) is distinct from visitor_code_for(p_facility, (now() at time zone 'America/New_York')::date) then
    insert into visitor_code_attempts (facility_id, ok) values (p_facility, false);
    return 'wrong_code';
  end if;
  if exists (select 1 from room_qr_codes r
              where r.facility_id = p_facility and r.is_active and r.location_type = 'room' and r.room_number is not null)
     and not exists (select 1 from room_qr_codes r
                      where r.facility_id = p_facility and r.is_active and r.location_type = 'room'
                        and upper(regexp_replace(r.room_number::text, '\s+', '', 'g')) = v_room) then
    return 'unknown_room';
  end if;
  insert into visitor_code_attempts (facility_id, ok) values (p_facility, true);
  insert into visitor_meals (facility_id, room_number, party_size) values (p_facility, v_room, p_party);
  return 'ok';
end;
$$;
revoke all on function add_visitor_meal(uuid, text, integer, text) from public;
grant execute on function add_visitor_meal(uuid, text, integer, text) to anon, authenticated;

-- 3. Unusual patterns, numbers only. "same_meal" = a room with more than one visitor ticket at one meal.
--    (The old "same name on 5+ days" check is gone: daily family visits are normal.)
create or replace function visitor_meal_flags(p_facility uuid, p_from date, p_to date)
returns table (kind text, day date, meal text, n integer)
language sql stable security definer set search_path = public as $$
  with rng as (
    select (p_from::timestamp at time zone 'America/New_York') as t0,
           ((least(p_to, p_from + 400) + 1)::timestamp at time zone 'America/New_York') as t1
  ),
  v as (
    select (m.created_at at time zone 'America/New_York') as local_at, m.room_number, m.party_size
      from visitor_meals m, rng
     where m.facility_id = p_facility and m.created_at >= rng.t0 and m.created_at < rng.t1
  ),
  vm as (
    select local_at::date as day,
           case when local_at::time < time '10:30' then 'breakfast' when local_at::time < time '16:00' then 'lunch' else 'dinner' end as meal,
           local_at::time as t, room_number, party_size
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
    from (select day, meal, room_number from vm where room_number is not null
           group by day, meal, room_number having count(*) > 1) x
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
  order by 2 desc nulls first, 1;
$$;
revoke all on function visitor_meal_flags(uuid, date, date) from public;
grant execute on function visitor_meal_flags(uuid, date, date) to anon, authenticated;

-- 4. Check (should return resident_name_column = 0):
select count(*) as resident_name_column
  from information_schema.columns
 where table_schema = 'public' and table_name = 'visitor_meals' and column_name = 'resident_name';
