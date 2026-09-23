-- Players are keyed on the Game Center gamePlayerID, which is the same id the app signs
-- its envelopes with ("gc:" + gamePlayerID) and stable across every game we ship.
CREATE TABLE IF NOT EXISTS players (
  id          TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  first_seen  TEXT NOT NULL,
  last_seen   TEXT NOT NULL
);

-- One row per player per day. The margin is what the ladder ranks by. A second post for
-- the same day is refused rather than replacing the first.
CREATE TABLE IF NOT EXISTS daily_results (
  day        TEXT NOT NULL,
  player_id  TEXT NOT NULL REFERENCES players(id),
  margin     INTEGER NOT NULL,
  mine       INTEGER NOT NULL,
  theirs     INTEGER NOT NULL,
  scope      INTEGER NOT NULL DEFAULT 0,
  accuracy   INTEGER,
  played_at  TEXT NOT NULL,
  PRIMARY KEY (day, player_id)
);

CREATE INDEX IF NOT EXISTS daily_results_by_day ON daily_results (day, margin DESC, accuracy DESC, played_at ASC);

-- Ranked play. One row per player. The floor is the lowest a season lets them fall to.
CREATE TABLE IF NOT EXISTS ratings (
  player_id  TEXT PRIMARY KEY REFERENCES players(id),
  rating     INTEGER NOT NULL DEFAULT 0,
  floor      INTEGER NOT NULL DEFAULT 0,
  games      INTEGER NOT NULL DEFAULT 0,
  wins       INTEGER NOT NULL DEFAULT 0,
  -- The season this rating belongs to, "2026-09". An older one is put away in
  -- season_finishes and reset on the next read or write. Empty predates seasons.
  season     TEXT NOT NULL DEFAULT '',
  -- Ranked wins standing in a row. Lengthened by a win over people, ended by a loss to
  -- them, untouched by the house, and given back with the divisions at a season's end.
  streak     INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL
);

-- What a player finished a season with, so the app can pay for it. `claimed` is set once
-- they have been paid, so a second phone cannot pay for it again.
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

-- Every phone at a ranked table reports the result. It is applied once two reports agree
-- on the winner and the players, or one report has stood alone for ten minutes.
CREATE TABLE IF NOT EXISTS ranked_reports (
  game_id     TEXT NOT NULL,
  reporter_id TEXT NOT NULL,
  players     TEXT NOT NULL,   -- JSON array of gamePlayerIDs, sorted
  winner_id   TEXT NOT NULL,
  reported_at TEXT NOT NULL,
  PRIMARY KEY (game_id, reporter_id)
);

-- Games against the house counted for a player on a day. Only the first few are paid.
-- See HOUSE_GAMES_PER_DAY.
CREATE TABLE IF NOT EXISTS house_games (
  player_id TEXT NOT NULL REFERENCES players(id),
  day       TEXT NOT NULL,
  count     INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (player_id, day)
);

CREATE TABLE IF NOT EXISTS ranked_games (
  game_id    TEXT PRIMARY KEY,
  applied_at TEXT NOT NULL,
  changes    TEXT NOT NULL     -- JSON {playerID: delta}
);

-- One row per player per week. Unlike the daily deal the row is updated as the week goes
-- on, and the count only ever climbs, so an out-of-order post cannot walk it backwards.
-- `goal` is that week's target, stored so a board can be read back without recomputing it.
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

-- Finished first ranks above finished later, and both above unfinished. Within a group
-- the count decides.
CREATE INDEX IF NOT EXISTS weekly_results_by_week
  ON weekly_results (week, count DESC, finished DESC, updated_at ASC);

-- One player's account as it travels between their devices: preferences, the cosmetics in
-- use, the counters and the album. Stored as one opaque JSON blob, because the merge lives
-- in the app where the economy is and there is nothing to gain from writing it twice.
--
-- `rev` is what keeps two devices from clobbering each other: a write names the revision it
-- was built from and is refused if that is no longer current, so the loser re-merges and
-- tries again rather than overwriting.
CREATE TABLE IF NOT EXISTS profiles (
  player_id  TEXT PRIMARY KEY REFERENCES players(id),
  rev        INTEGER NOT NULL DEFAULT 0,
  profile    TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

-- The purse: one row per ledger entry, keyed by the entry's own dedupe key. No revisions
-- and no conflicts — a ledger is append-only and every entry names itself, so two devices
-- writing at once is a union and nothing more.
--
-- `seq` is what a device reads forward from. A timestamp would not do: two entries written
-- in the same millisecond would make a cursor either skip one or never get past them.
CREATE TABLE IF NOT EXISTS ledger_entries (
  seq        INTEGER PRIMARY KEY AUTOINCREMENT,
  player_id  TEXT NOT NULL REFERENCES players(id),
  key        TEXT NOT NULL,
  entry      TEXT NOT NULL,   -- the LedgerEntry exactly as the app encodes it
  added_at   TEXT NOT NULL,
  UNIQUE (player_id, key)
);

CREATE INDEX IF NOT EXISTS ledger_entries_by_player ON ledger_entries (player_id, seq);

-- Which friends have Scopa open. One row per player who has it open, or had it lately: a
-- heartbeat refreshes `seen_at`, and `friends_key` fingerprints the list below so a beat
-- that names the same friends as the last one rewrites nothing. See presence.ts.
CREATE TABLE IF NOT EXISTS presence (
  player_id    TEXT PRIMARY KEY REFERENCES players(id),
  seen_at      TEXT NOT NULL,
  friends_key  TEXT NOT NULL
);

-- The friends a player named in their last heartbeat. A player is shown only to the people
-- on their own list, which is what makes being seen mutual.
CREATE TABLE IF NOT EXISTS presence_friends (
  player_id  TEXT NOT NULL REFERENCES players(id),
  friend_id  TEXT NOT NULL,
  PRIMARY KEY (player_id, friend_id)
);

CREATE INDEX IF NOT EXISTS presence_friends_by_friend ON presence_friends (friend_id, player_id);
