-- Coupons: a code the house hands out, worth a reward to every player who enters it, once
-- each. `schema.sql` has both tables, so a fresh database needs nothing from here.
--
-- Run once:  wrangler d1 execute scopa --remote --file migrations/009-coupons.sql
--
-- Safe to run again. The coupons themselves are made with Tools/coupons.sh.
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

-- Keyed on the coupon and the player, so a player takes each coupon once and may take as
-- many different ones as there are. `device` is the phone that asked, so a reply lost on
-- the way back can be paid again there, where the purse's own key stops it paying twice.
CREATE TABLE IF NOT EXISTS coupon_uses (
  code         TEXT NOT NULL REFERENCES coupons(code),
  player_id    TEXT NOT NULL,
  player_name  TEXT NOT NULL,
  device       TEXT,
  used_at      TEXT NOT NULL,
  PRIMARY KEY (code, player_id)
);
