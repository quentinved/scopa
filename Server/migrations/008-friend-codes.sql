-- Friend codes: one per friend of the house, worth a gift to whoever enters it, once per
-- player. `schema.sql` has both tables, so a fresh database needs nothing from here.
--
-- Run once:  wrangler d1 execute scopa --remote --file migrations/008-friend-codes.sql
--
-- Safe to run again. The codes themselves are added with Tools/friend-codes.sh, so the
-- friends' names stay out of the repository.
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
