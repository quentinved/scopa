-- Cards given between friends: a spare out of one album and into another, one a day. See
-- gifts.ts. `schema.sql` has the table, so a fresh database needs nothing from here.
--
-- Run once, before deploying the Worker that sends them:
--   wrangler d1 execute scopa --remote --file migrations/013-card-gifts.sql
--
-- Safe to run again: everything here is IF NOT EXISTS, and there is nothing to backfill.
CREATE TABLE IF NOT EXISTS card_gifts (
  id            TEXT PRIMARY KEY,                    -- the phone's own id, so a retry is the same gift
  sender_id     TEXT NOT NULL REFERENCES players(id),
  sender_name   TEXT NOT NULL,                       -- as the friend is told who it came from
  recipient_id  TEXT NOT NULL REFERENCES players(id),
  card          TEXT NOT NULL CHECK (card <> '7d'),  -- "7c"; never the settebello
  day           TEXT NOT NULL,                       -- the sender's own day
  sent_at       TEXT NOT NULL,
  collected_at  TEXT,                                -- set once the friend's phone has it
  UNIQUE (sender_id, day)
);

CREATE INDEX IF NOT EXISTS card_gifts_waiting ON card_gifts (recipient_id, collected_at, sent_at);
