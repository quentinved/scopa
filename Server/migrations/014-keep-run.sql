-- Keeping a run with an ad, for a database created before it. `schema.sql` has the columns
-- in their final shape, so a fresh database needs nothing from here.
--
-- Run once, before deploying the Worker that keeps runs:
--   wrangler d1 execute scopa --remote --file migrations/014-keep-run.sql
--
-- The first ALTER fails if it has already run, which is the intended catch: the columns are
-- there and there is nothing else in this file. Nobody starts with a run to keep, which is
-- right — only a loss the ladder watched can leave one.
ALTER TABLE ratings ADD COLUMN broken_run INTEGER NOT NULL DEFAULT 0;
ALTER TABLE ratings ADD COLUMN broken_game TEXT;
ALTER TABLE ratings ADD COLUMN run_kept INTEGER NOT NULL DEFAULT 0;
