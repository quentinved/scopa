-- Win streaks, for a database created before them. `schema.sql` has the column in its
-- final shape, so a fresh database needs nothing from here.
--
-- Run once:  wrangler d1 execute scopa --remote --file migrations/004-streaks.sql
--
-- The ALTER fails if it has already run, which is the intended catch: the column is
-- there and there is nothing else in this file. Everybody starts on no run, which is
-- right — a run is something the ladder watched happen.
ALTER TABLE ratings ADD COLUMN streak INTEGER NOT NULL DEFAULT 0;
