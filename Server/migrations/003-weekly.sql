-- The week's board, for a database created before the weekly challenge existed.
-- `schema.sql` has the same two things in their final shape, so a fresh database needs
-- nothing from here.
--
-- Run once:  wrangler d1 execute scopa --remote --file migrations/003-weekly.sql
--
-- Without this table every `v1/weekly` request throws, which the Worker answers as a 500:
-- the board could not be read and nothing any phone posted could be written. The daily
-- ladder and the ranked ladder were unaffected, which is why only the week looked broken.

CREATE TABLE IF NOT EXISTS weekly_results (
  week       TEXT NOT NULL,
  player_id  TEXT NOT NULL REFERENCES players(id),
  count      INTEGER NOT NULL DEFAULT 0,
  goal       INTEGER NOT NULL DEFAULT 0,
  finished   INTEGER NOT NULL DEFAULT 0,
  first_at   TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (week, player_id)
);

CREATE INDEX IF NOT EXISTS weekly_results_by_week
  ON weekly_results (week, count DESC, finished DESC, updated_at ASC);
