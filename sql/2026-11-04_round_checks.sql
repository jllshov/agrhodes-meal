-- Manager Checks: extra items managers check on their Zone Defense rounds.
-- Run once in the Zone Defense (meal) Supabase project → SQL Editor.
-- Safe to run again.

create table if not exists round_checks (
  id            uuid primary key default gen_random_uuid(),
  facility_id   uuid not null references facilities(id),
  scope         text not null check (scope in ('asset', 'building')),
  asset_id      uuid references room_assets(id),
  qr_identifier text,                       -- the asset's room (null for building-wide)
  label         text not null check (char_length(label) between 1 and 120),
  details       text check (details is null or char_length(details) <= 500),
  repeat        boolean not null default false,  -- false = one time, true = every round
  dept          text not null default 'Maintenance',
  created_by    text,
  created_at    timestamptz not null default now(),
  is_active     boolean not null default true,
  closed_at     timestamptz,
  closed_by     text,
  check (scope = 'building' or (asset_id is not null and qr_identifier is not null))
);
create index if not exists round_checks_open_idx on round_checks (facility_id, is_active);
create index if not exists round_checks_room_idx on round_checks (facility_id, qr_identifier);

create table if not exists round_check_results (
  id            uuid primary key default gen_random_uuid(),
  check_id      uuid not null references round_checks(id) on delete cascade,
  facility_id   uuid not null references facilities(id),
  qr_identifier text not null,
  round_id      uuid references zone_rounds(id) on delete set null,
  result        text not null check (result in ('pass', 'fail')),
  note          text,
  checked_by    text,
  checked_at    timestamptz not null default now()
);
create index if not exists round_check_results_check_idx on round_check_results (check_id, qr_identifier);

-- Same access as the other Zone Defense tables: the pages read and write with the site key.
alter table round_checks enable row level security;
alter table round_check_results enable row level security;
drop policy if exists round_checks_pages on round_checks;
create policy round_checks_pages on round_checks for all to anon, authenticated using (true) with check (true);
drop policy if exists round_check_results_pages on round_check_results;
create policy round_check_results_pages on round_check_results for all to anon, authenticated using (true) with check (true);
grant select, insert, update on round_checks, round_check_results to anon, authenticated;
