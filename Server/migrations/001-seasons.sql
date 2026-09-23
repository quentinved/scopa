-- Seasons, for a database created before them. `schema.sql` has the same two things in
-- their final shape, so a fresh database needs nothing from here.
--
-- Run once:  wrangler d1 execute scopa --remote --file migrations/001-seasons.sql
--
-- The ALTER fails if it has already run, which is the intended catch: the column is
-- there and the rest of this file is a no-op.
ALTER TABLE ratings ADD COLUMN season TEXT NOT NULL DEFAULT '';

CREATE TABLE IF NOT EXISTS season_finishes (
  season      TEXT NOT NULL,
  player_id   TEXT NOT NULL REFERENCES players(id),
  rating      INTEGER NOT NULL,
  games       INTEGER NOT NULL DEFAULT 0,
  wins        INTEGER NOT NULL DEFAULT 0,
  claimed     INTEGER NOT NULL DEFAULT 0,
  finished_at TEXT NOT NULL,
  PRIMARY KEY (season, player_id)
);

CREATE INDEX IF NOT EXISTS season_finishes_owed ON season_finishes (player_id, claimed, season DESC);
