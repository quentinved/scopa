-- The campaign's second road: Toscana, Puglia, Sardegna and Lombardia after Roma, so the road
-- is sixty tables. They are added at its end and every row keeps the number it has, so this
-- only widens the checks to 60 tables and 180 stars, which SQLite does by building the table
-- again.
--
-- Run once, after 012, and before deploying the Worker that counts in sixty (which goes out
-- before the app release that brings the second road):
--   wrangler d1 execute scopa --remote --file migrations/015-campaign-second-road.sql
--
-- Safe to run again, and `schema.sql` starts a fresh database already counted in sixty. Do not
-- run 012 after it: 012 builds the table with the old checks of 36 again.
DROP TABLE IF EXISTS campaign_progress_next;
CREATE TABLE campaign_progress_next (
  player_id  TEXT PRIMARY KEY REFERENCES players(id),
  stage      INTEGER NOT NULL CHECK (stage BETWEEN 1 AND 60),
  stars      INTEGER NOT NULL CHECK (stars BETWEEN 0 AND 180),
  mark       TEXT,
  livery     TEXT,
  cornice    TEXT,
  updated_at TEXT NOT NULL
);

INSERT INTO campaign_progress_next (player_id, stage, stars, mark, livery, cornice, updated_at)
SELECT player_id, stage, stars, mark, livery, cornice, updated_at FROM campaign_progress;

DROP TABLE campaign_progress;
ALTER TABLE campaign_progress_next RENAME TO campaign_progress;

CREATE INDEX IF NOT EXISTS campaign_by_stars ON campaign_progress (stars DESC, stage DESC, updated_at ASC);
CREATE INDEX IF NOT EXISTS campaign_by_stage ON campaign_progress (stage, updated_at DESC);

INSERT OR IGNORE INTO campaign_road (tables) VALUES (60);
