-- Zone Defense: "No Signs of Pests" on the resident room round.
-- Room rounds save each answer in its own zone_rounds column, so the new
-- question needs one. Run once in the Supabase SQL editor (safe to re-run).
--
-- Until this runs, round.html saves the round without the pest answer and the
-- pest sighting still becomes a Pest Control problem, so nothing is lost.
-- Nursing stations, offices, bathrooms, cleanings and EOC areas store answers
-- as JSON (eoc_scores) and need no change.

alter table zone_rounds add column if not exists no_pests text;

-- Optional, from 2026-09-29 (not run yet): keep the F-Tag on each problem.
-- alter table zone_issues add column if not exists ftag text;
