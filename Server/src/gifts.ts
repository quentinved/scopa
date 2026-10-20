// Cards given between friends: one spare out of one album and into another, a card a day.
//
// The phone names a gift with its own id before sending it, so a reply lost on the way back
// is answered the same way the second time and the card leaves the sender's album once. The
// friend's phone collects it on its next launch, and it is marked collected only once that
// phone says it has it: a reply lost there is collected again, and the phone's own ledger
// key stops the card arriving twice.
//
// The Worker checks the card's shape and the rules a gift is held to. Whether the sender
// really had a spare it cannot know, any more than it knows what is in an album.

/** Cards one player may give in a day, by their own calendar. */
export const PER_DAY = 1;
/** Ids handed back as collected in one call. */
export const MAX_TAKEN = 50;
/** Gifts handed over in one answer. The rest wait for the next. */
export const MAX_WAITING = 20;

const GIFT_ID = /^[0-9A-Fa-f-]{36}$/;
const PLAYER_ID = /^.{1,100}$/;
/** "7c": a rank from 1 to 10 and a suit's Italian initial, as the app writes a card. */
const CARD = /^(10|[1-9])[dcsb]$/;
const DAY = /^\d{4}-\d{2}-\d{2}$/;
/** The seven of coins is found, never given. */
export const SETTEBELLO = "7d";

export interface Gift {
  id: string;
  /** The friend's Game Center id. */
  to: string;
  card: string;
  /** The sender's own day, which is what one a day counts by. */
  day: string;
}

export interface Sender {
  id: string;
  name: string;
}

/** A status and a body, for the route to send as it is. */
export interface Answer {
  status: number;
  body: Record<string, unknown>;
}

/** What is wrong with a gift as it arrives, or null. */
export function invalidGift(body: unknown): string | null {
  const gift = body as Partial<Record<keyof Gift, unknown>> | null;
  if (!gift || typeof gift !== "object") return "bad gift";
  if (typeof gift.id !== "string" || !GIFT_ID.test(gift.id)) return "bad id";
  if (typeof gift.to !== "string" || !PLAYER_ID.test(gift.to)) return "bad friend";
  if (typeof gift.card !== "string" || !CARD.test(gift.card)) return "bad card";
  if (gift.card === SETTEBELLO) return "not the settebello";
  if (typeof gift.day !== "string" || !DAY.test(gift.day)) return "bad day";
  return null;
}

export function cardGiftOf(body: Gift): Gift {
  return { id: body.id.toLowerCase(), to: body.to, card: body.card, day: body.day };
}

/** Within a day of the Worker's own date, which is as far apart as two time zones get. */
export function isNearToday(day: string, now: Date): boolean {
  const asked = Date.parse(`${day}T12:00:00Z`);
  if (Number.isNaN(asked)) return false;
  return Math.abs(asked - now.getTime()) <= 36 * 3600 * 1000;
}

/** What a list of collected ids is wrong with, or null. Missing is an empty list. */
export function invalidTaken(taken: unknown): string | null {
  if (taken === undefined || taken === null) return null;
  if (!Array.isArray(taken) || taken.length > MAX_TAKEN) return "bad taken";
  return taken.every((id) => typeof id === "string" && GIFT_ID.test(id)) ? null : "bad taken";
}

// One statement, so two taps on two phones cannot both be today's gift.
const SEND = `
  INSERT INTO card_gifts (id, sender_id, sender_name, recipient_id, card, day, sent_at)
  SELECT ?1, ?2, ?3, ?4, ?5, ?6, ?7
   WHERE NOT EXISTS (SELECT 1 FROM card_gifts WHERE sender_id = ?2 AND day = ?6)
  ON CONFLICT (id) DO NOTHING`;

/// Sends one card. `fresh` is false for a gift the Worker already had, which the phone takes
/// as sent all the same: it is the answer the first try would have had.
export async function sendGift(db: D1Database, sender: Sender, gift: Gift, now = new Date()): Promise<Answer> {
  const earlier = await senderOf(db, gift.id);
  if (earlier !== undefined) return earlier === sender.id ? sent(gift, false) : refused(409, "taken id");
  if (gift.to === sender.id) return refused(400, "not to yourself");
  if (!isNearToday(gift.day, now)) return refused(400, "bad day");
  const friend = await db.prepare(`SELECT id FROM players WHERE id = ?1`).bind(gift.to).first();
  if (!friend) return refused(404, "unknown player");

  const written = await db.prepare(SEND)
    .bind(gift.id, sender.id, sender.name, gift.to, gift.card, gift.day, now.toISOString())
    .run().catch(() => ({ meta: { changes: 0 } }));
  if (written.meta.changes > 0) return sent(gift, true);
  // Nothing written: this same gift landed a moment ago, or today's went to somebody else.
  return (await senderOf(db, gift.id)) === sender.id ? sent(gift, false) : refused(429, "one a day");
}

/// Puts away what the phone says it has, then hands over what is still waiting, oldest first.
export async function collectGifts(db: D1Database, playerID: string, taken: string[], now = new Date()): Promise<Answer> {
  if (taken.length) {
    await db.prepare(
      `UPDATE card_gifts SET collected_at = ?3
        WHERE recipient_id = ?1 AND collected_at IS NULL
          AND id IN (SELECT lower(value) FROM json_each(?2))`,
    ).bind(playerID, JSON.stringify(taken), now.toISOString()).run();
  }
  const { results } = await db.prepare(
    `SELECT id, sender_name, card, sent_at FROM card_gifts
      WHERE recipient_id = ?1 AND collected_at IS NULL
      ORDER BY sent_at, id LIMIT ${MAX_WAITING}`,
  ).bind(playerID).all<{ id: string; sender_name: string; card: string; sent_at: string }>();
  const gifts = results.map((row) => ({ id: row.id, from: row.sender_name, card: row.card, sentAt: row.sent_at }));
  return { status: 200, body: { gifts } };
}

async function senderOf(db: D1Database, id: string): Promise<string | undefined> {
  const row = await db.prepare(`SELECT sender_id FROM card_gifts WHERE id = ?1`).bind(id).first<{ sender_id: string }>();
  return row ? row.sender_id : undefined;
}

function sent(gift: Gift, fresh: boolean): Answer {
  return { status: 200, body: { id: gift.id, card: gift.card, fresh } };
}

function refused(status: number, error: string): Answer {
  return { status, body: { error } };
}
