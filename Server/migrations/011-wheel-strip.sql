-- The wheel's strip: the last day's turns, read off every player's ledger. `schema.sql` has
-- the index, so a fresh database needs nothing from here.
--
-- Run once:  wrangler d1 execute scopa --remote --file migrations/011-wheel-strip.sql
--
-- Safe to run again.
CREATE INDEX IF NOT EXISTS ledger_entries_by_added ON ledger_entries (added_at);
