-- Games against the house, counted so the ladder can pay for the first few a day.
-- `schema.sql` has this table in its final shape, so a fresh database needs nothing here.
--
-- Run once:  wrangler d1 execute scopa --remote --file migrations/002-house-games.sql

CREATE TABLE IF NOT EXISTS house_games (
  player_id TEXT NOT NULL REFERENCES players(id),
  day       TEXT NOT NULL,
  count     INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (player_id, day)
);
