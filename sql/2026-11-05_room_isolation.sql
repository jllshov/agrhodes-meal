-- Isolation rooms: the infection nurse marks rooms in Nursiao; Zone Defense
-- shows them on the room QR page and managers check them on their round.
-- Run once in the Zone Defense (meal) Supabase project → SQL Editor. Safe to run again.

create table if not exists room_isolation (
  id            uuid primary key default gen_random_uuid(),
  facility_id   uuid not null references facilities(id),
  qr_identifier text not null,
  room_number   text,                      -- room number only, never a resident name
  precaution    text not null check (precaution in ('ebp', 'contact', 'contact_enteric', 'droplet', 'airborne')),
  started_at    timestamptz not null default now(),
  started_by    text,
  is_active     boolean not null default true,
  ended_at      timestamptz,
  ended_by      text,
  updated_at    timestamptz not null default now()
);
-- One active isolation per room.
create unique index if not exists room_isolation_one_active on room_isolation (facility_id, qr_identifier) where is_active;
create index if not exists room_isolation_open_idx on room_isolation (facility_id, is_active);

alter table room_isolation enable row level security;
drop policy if exists room_isolation_pages on room_isolation;
create policy room_isolation_pages on room_isolation for all to anon, authenticated using (true) with check (true);
grant select, insert, update on room_isolation to anon, authenticated;

-- The manager's isolation answers on a room round.
alter table zone_rounds add column if not exists iso_precaution text;
alter table zone_rounds add column if not exists iso_sign text;
alter table zone_rounds add column if not exists iso_ppe text;
alter table zone_rounds add column if not exists iso_equipment text;
alter table zone_rounds add column if not exists iso_door text;
