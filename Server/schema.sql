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

-- The season's board: this season's players, highest first. See getRankedBoard.
CREATE INDEX IF NOT EXISTS ratings_by_season ON ratings (season, rating DESC, wins DESC, updated_at ASC);

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
-- The wheel's strip reads the last day's turns across every player. See wheel.ts.
CREATE INDEX IF NOT EXISTS ledger_entries_by_added ON ledger_entries (added_at);

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

-- Friend codes: one per friend of the house, worth a gift to whoever enters it. Added with
-- Tools/friend-codes.sh rather than here, so the friends' names stay out of the repository.
CREATE TABLE IF NOT EXISTS friend_codes (
  code        TEXT PRIMARY KEY,   -- "ROMANE": upper case, letters and digits only
  owner       TEXT NOT NULL,      -- who hands it out, as the app names them
  pack        TEXT CHECK (pack IS NULL OR pack IN ('mazzetto', 'bottega', 'velluto', 'reliquia', 'scrigno', 'forziere')),
  denari      INTEGER NOT NULL DEFAULT 0 CHECK (denari >= 0),
  created_at  TEXT NOT NULL,
  CHECK (pack IS NOT NULL OR denari > 0)
);

-- Keyed on the player, so a player uses one code in their life, whoever's it was.
CREATE TABLE IF NOT EXISTS friend_code_uses (
  player_id   TEXT PRIMARY KEY,
  code        TEXT NOT NULL REFERENCES friend_codes(code),
  player_name TEXT NOT NULL,
  used_at     TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS friend_code_uses_by_code ON friend_code_uses (code, used_at);

-- Coupons: a code the house hands out, worth a reward to every player who enters it, once
-- each. Made with Tools/coupons.sh. A reward is any mix of denari, packs left waiting in
-- the album, and things off the shop's shelves by catalogue id.
CREATE TABLE IF NOT EXISTS coupons (
  code         TEXT PRIMARY KEY,           -- "NATALE": upper case, letters and digits only
  denari       INTEGER NOT NULL DEFAULT 0 CHECK (denari >= 0),
  packs        TEXT NOT NULL DEFAULT '',   -- "velluto,reliquia": one pack per tier named
  items        TEXT NOT NULL DEFAULT '',   -- "felt.notte,cheer.oro": shop catalogue ids
  max_uses     INTEGER CHECK (max_uses IS NULL OR max_uses > 0),
  expires_at   TEXT,                       -- the last instant it works, ISO 8601 in UTC
  disabled_at  TEXT,                       -- taken off by hand; answers as expired
  note         TEXT,                       -- for whoever reads the list, never sent
  created_at   TEXT NOT NULL,
  CHECK (denari > 0 OR packs != '' OR items != '')
);

-- Once per coupon per player. `device` is the phone that asked, so a lost reply can be
-- paid again there, where the purse's own key stops it paying twice.
CREATE TABLE IF NOT EXISTS coupon_uses (
  code         TEXT NOT NULL REFERENCES coupons(code),
  player_id    TEXT NOT NULL,
  player_name  TEXT NOT NULL,
  device       TEXT,
  used_at      TEXT NOT NULL,
  PRIMARY KEY (code, player_id)
);

-- The campaign's board: where each player's road has reached, and the stars won on it. Both
-- only climb. The mark, livery and cornice are what the map draws their face with. See campaign.ts.
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
