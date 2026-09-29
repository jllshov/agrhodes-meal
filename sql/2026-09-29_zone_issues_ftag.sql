-- Stores the CMS F-Tag / K-Tag a failed checklist item maps to (see ftags.js).
-- Run once in the Supabase SQL editor. Safe to re-run.
alter table public.zone_issues add column if not exists ftag text;

create index if not exists zone_issues_facility_ftag_idx
  on public.zone_issues (facility_id, ftag)
  where ftag is not null;
