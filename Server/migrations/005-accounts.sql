-- One account across a player's devices, for a database created before them. `schema.sql`
-- has both tables in their final shape, so a fresh database needs nothing from here.
--
-- Run once:  wrangler d1 execute scopa --remote --file migrations/005-accounts.sql
--
-- Safe to run twice: everything here is IF NOT EXISTS. Nothing is backfilled, and there is
-- nothing to backfill — until a device syncs, the account it would have is the one on that
-- device, which is exactly what the first sync hands over.

CREATE TABLE IF NOT EXISTS profiles (
  player_id  TEXT PRIMARY KEY REFERENCES players(id),
  rev        INTEGER NOT NULL DEFAULT 0,
  profile    TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS ledger_entries (
  seq        INTEGER PRIMARY KEY AUTOINCREMENT,
  player_id  TEXT NOT NULL REFERENCES players(id),
  key        TEXT NOT NULL,
  entry      TEXT NOT NULL,
  added_at   TEXT NOT NULL,
  UNIQUE (player_id, key)
);

CREATE INDEX IF NOT EXISTS ledger_entries_by_player ON ledger_entries (player_id, seq);
