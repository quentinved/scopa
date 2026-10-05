// The day's wheel as everyone else turned it: who won what in the last day, friends first,
// and how often the gran premio has come up this week.
//
// Nothing is posted for this. A turn is paid into the purse under "wheel/<day>", and the
// purse already travels to `ledger_entries`, so the prize is read back off the ledger:
// 2,500 denari is the jackpot, nothing at all is a pack, a "wheel/<day>/item" beside it is
// something off the shop's shelves, and any other amount is just that many denari. Builds
// that predate this are on the strip as soon as they sync.

/** Turns handed back. The sheet shows them all. */
export const STRIP_SIZE = 10;
/** Mirrors DailyWheel.jackpotDenari. */
export const JACKPOT_DENARI = 2_500;

const DAY_MS = 86_400_000;
/** A turn's own day key, never a debug build's "wheel/<day>/debug/<uuid>". */
const TURN_KEY = "wheel/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]";

export type Prize =
  | { kind: "denari"; denari: number }
  | { kind: "pack" }
  | { kind: "item"; item: string }
  | { kind: "jackpot" };

export interface Turn {
  id: string;
  name: string;
  prize: Prize;
  /** When it was turned, as the phone wrote it. */
  at: string;
  friend: boolean;
}

export interface Strip {
  turns: Turn[];
  jackpotsThisWeek: number;
}

interface TurnRow {
  id: string;
  name: string;
  amount: number | null;
  item: string | null;
  at: string;
}

/** What a turn paid, from its grant and the item entry beside it, if any. */
export function prizeOf(amount: number | null, item: string | null): Prize {
  if (item) return { kind: "item", item };
  if (amount === JACKPOT_DENARI) return { kind: "jackpot" };
  if (!amount) return { kind: "pack" };
  return { kind: "denari", denari: amount };
}

/** The ledger writes dates to the second, so the bounds are written the same way. */
function stamp(date: Date): string {
  return date.toISOString().replace(/\.\d{3}Z$/, "Z");
}

/** The turns since `since`, newest first. `added_at` bounds the scan to recent rows; the
 *  turn's own date keeps out old turns a device only just synced. */
function turnsSince(since: Date): string {
  // A day's slack on `added_at`: a turn taken offline can arrive later than it was turned.
  return `
    FROM ledger_entries g JOIN players p ON p.id = g.player_id
    LEFT JOIN ledger_entries i ON i.player_id = g.player_id AND i.key = g.key || '/item'
    WHERE g.added_at > '${stamp(new Date(since.getTime() - DAY_MS))}'
      AND g.key GLOB '${TURN_KEY}'
      AND json_extract(g.entry, '$.date') > '${stamp(since)}'`;
}

const TURN = `g.player_id AS id, p.name, json_extract(g.entry, '$.amount') AS amount,
  json_extract(i.entry, '$.reason.bought._0') AS item, json_extract(g.entry, '$.date') AS at`;

/** The last day's turns, the reader left out: friends' first, then everyone's, newest first
 *  within each. */
export async function wheelStrip(db: D1Database, playerID: string | null, friends: string[], now = new Date()): Promise<Strip> {
  const known = [...new Set(friends)].filter((id) => id !== playerID);
  const since = turnsSince(new Date(now.getTime() - DAY_MS));
  const ours = await db.prepare(
    `SELECT ${TURN} ${since} AND g.player_id IN (SELECT value FROM json_each(?1)) ORDER BY at DESC LIMIT ${STRIP_SIZE}`,
  ).bind(JSON.stringify(known)).all<TurnRow>();
  const others = await db.prepare(
    `SELECT ${TURN} ${since} AND g.player_id NOT IN (SELECT value FROM json_each(?1)) ORDER BY at DESC LIMIT ${STRIP_SIZE}`,
  ).bind(JSON.stringify([...known, ...(playerID ? [playerID] : [])])).all<TurnRow>();
  const jackpots = await db.prepare(
    `SELECT COUNT(*) AS n ${turnsSince(new Date(now.getTime() - 7 * DAY_MS))} AND json_extract(g.entry, '$.amount') = ?1`,
  ).bind(JACKPOT_DENARI).first<{ n: number }>();
  return {
    turns: [...turns(ours.results, true), ...turns(others.results, false)].slice(0, STRIP_SIZE),
    jackpotsThisWeek: jackpots?.n ?? 0,
  };
}

function turns(rows: TurnRow[], friend: boolean): Turn[] {
  return rows.map(({ id, name, amount, item, at }) => ({ id, name, prize: prizeOf(amount, item), at, friend }));
}
