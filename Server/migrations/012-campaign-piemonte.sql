-- Piemonte joins the campaign as region II, so the road is thirty-six tables and every table
-- from Napoli on sits six further along. Renumbers the board so each row still names the
-- table it did, and widens the checks to 36 tables and 108 stars.
--
-- Run once, with the app release that brings Piemonte:
--   wrangler d1 execute scopa --remote --file migrations/012-campaign-piemonte.sql
--
-- Safe to run again: `campaign_road` remembers the renumbering, and `schema.sql` starts a
-- fresh database already counted in thirty-six.
CREATE TABLE IF NOT EXISTS campaign_road (tables INTEGER PRIMARY KEY);

DROP TABLE IF EXISTS campaign_progress_next;
CREATE TABLE campaign_progress_next (
  player_id  TEXT PRIMARY KEY REFERENCES players(id),
  stage      INTEGER NOT NULL CHECK (stage BETWEEN 1 AND 36),
  stars      INTEGER NOT NULL CHECK (stars BETWEEN 0 AND 108),
  mark       TEXT,
  livery     TEXT,
  cornice    TEXT,
  updated_at TEXT NOT NULL
);

-- Liguria's six keep their numbers; anything past them moves behind Piemonte's six.
INSERT INTO campaign_progress_next (player_id, stage, stars, mark, livery, cornice, updated_at)
SELECT player_id,
       CASE WHEN stage > 6 AND NOT EXISTS (SELECT 1 FROM campaign_road WHERE tables = 36) THEN stage + 6 ELSE stage END,
       stars, mark, livery, cornice, updated_at
FROM campaign_progress;

DROP TABLE campaign_progress;
ALTER TABLE campaign_progress_next RENAME TO campaign_progress;

CREATE INDEX IF NOT EXISTS campaign_by_stars ON campaign_progress (stars DESC, stage DESC, updated_at ASC);
CREATE INDEX IF NOT EXISTS campaign_by_stage ON campaign_progress (stage, updated_at DESC);

INSERT OR IGNORE INTO campaign_road (tables) VALUES (36);
