-- The season's board, for a database created before it. `schema.sql` has the index, so a
-- fresh database needs nothing from here.
--
-- Run once:  wrangler d1 execute scopa --remote --file migrations/007-ranked-board.sql
--
-- Safe to run again. The board reads without it, one scan of the ratings per look.
CREATE INDEX IF NOT EXISTS ratings_by_season ON ratings (season, rating DESC, wins DESC, updated_at ASC);
