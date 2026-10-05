-- The campaign's board. `schema.sql` has the table, so a fresh database needs nothing from here.
--
-- Run once:  wrangler d1 execute scopa --remote --file migrations/010-campaign.sql
--
-- Safe to run again.
CREATE TABLE IF NOT EXISTS campaign_progress (
  player_id  TEXT PRIMARY KEY REFERENCES players(id),
  stage      INTEGER NOT NULL CHECK (stage BETWEEN 1 AND 30),   -- the table the road has reached
  stars      INTEGER NOT NULL CHECK (stars BETWEEN 0 AND 90),
  mark       TEXT,                                              -- the seat mark worn, null for the initial
  livery     TEXT,                                              -- the seat colour, null for the table's own
  cornice    TEXT,                                              -- the ring round the mark, null for none
  updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS campaign_by_stars ON campaign_progress (stars DESC, stage DESC, updated_at ASC);
CREATE INDEX IF NOT EXISTS campaign_by_stage ON campaign_progress (stage, updated_at DESC);
