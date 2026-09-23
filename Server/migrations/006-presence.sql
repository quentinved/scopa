-- Friends online, for a database created before it. `schema.sql` has both tables in their
-- final shape, so a fresh database needs nothing from here.
--
-- Run once:  wrangler d1 execute scopa --remote --file migrations/006-presence.sql
--
-- Safe to run twice: everything here is IF NOT EXISTS, and nothing needs backfilling --
-- nobody is online until their app checks in.

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
