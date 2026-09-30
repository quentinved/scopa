// Coupons: a code the house hands out, worth a reward to every player who enters it, once
// each. Unlike a friend code a player may take as many different coupons as there are, so
// the count behind a coupon is how many people took it up.
//
// Typed and forgiven like a friend code. A reward is any mix of denari, packs left waiting
// in the album, and things off the shop's shelves by catalogue id. The Worker checks the
// shape of each; what a felt is, and whether it can be handed over, the app decides.

import { normaliseFriendCode, PACKS } from "./friendcodes.ts";

/** Same alphabet, same forgiveness: one field in the app takes either kind of code. */
export const normaliseCoupon = normaliseFriendCode;

/** More than this is a typo in the script rather than a gift. */
export const MAX_PACKS = 10;
export const MAX_ITEMS = 10;
export const MAX_DEVICE_LENGTH = 64;

/** "felt.notte": a shelf the shop sells from, a dot, and a name. */
const ITEM = /^(deck|skin|felt|tapis|mark|cornice|back|companion|livery|flourish|cheer|reactions)\.[A-Za-z0-9]+$/;

export interface CouponRow {
  code: string;
  denari: number;
  packs: string | null;
  items: string | null;
  max_uses: number | null;
  expires_at: string | null;
  disabled_at: string | null;
}

/** What the app is told to hand over. */
export interface Reward {
  code: string;
  denari: number;
  packs: string[];
  items: string[];
}

export interface Redeemer {
  id: string;
  name: string;
  /** The phone that asked, as it names itself. Null when it did not say. */
  device: string | null;
}

/** A status and a body, for the route to send as it is. */
export interface Answer {
  status: number;
  body: Record<string, unknown>;
}

function list(value: string | null): string[] {
  return (value ?? "").split(",").map((part) => part.trim()).filter(Boolean);
}

/** Only what the app knows how to hand over: known tiers, well-formed ids, whole denari. */
export function rewardOf(row: CouponRow): Reward {
  const denari = Number.isInteger(row.denari) && row.denari > 0 ? row.denari : 0;
  const packs = list(row.packs).filter((pack) => PACKS.has(pack)).slice(0, MAX_PACKS);
  const items = [...new Set(list(row.items).filter((item) => ITEM.test(item)))].slice(0, MAX_ITEMS);
  return { code: row.code, denari, packs, items };
}

/** Past its last instant, or taken off by hand. Both are over, and say so the same way. */
export function isOver(row: CouponRow, now: Date): boolean {
  if (row.disabled_at) return true;
  if (!row.expires_at) return false;
  const last = Date.parse(row.expires_at);
  return Number.isNaN(last) || now.getTime() > last;
}

/** A device id as it arrives: a short string, or nothing. */
export function deviceOf(value: unknown): string | null {
  return typeof value === "string" && value && value.length <= MAX_DEVICE_LENGTH ? value : null;
}

// One statement, so the last use of a capped coupon cannot go to two people at once.
const TAKE = `
  INSERT INTO coupon_uses (code, player_id, player_name, device, used_at)
  SELECT c.code, ?2, ?3, ?4, ?5 FROM coupons c
   WHERE c.code = ?1
     AND (c.max_uses IS NULL OR (SELECT COUNT(*) FROM coupon_uses u WHERE u.code = c.code) < c.max_uses)
  ON CONFLICT (code, player_id) DO NOTHING`;

/// Takes one use of a coupon for a player. Already taken is answered before over or used up:
/// what the player did themselves is the thing worth telling them.
export async function redeemCoupon(db: D1Database, code: string, player: Redeemer, now = new Date()): Promise<Answer> {
  const row = await db.prepare(
    `SELECT code, denari, packs, items, max_uses, expires_at, disabled_at FROM coupons WHERE code = ?1`,
  ).bind(code).first<CouponRow>();
  if (!row) return { status: 404, body: { error: "unknown code" } };
  const earlier = await deviceThatTook(db, code, player.id);
  if (earlier !== undefined) return alreadyTaken(row, earlier, player);
  if (isOver(row, now)) return { status: 410, body: { error: "expired" } };

  const taken = await db.prepare(TAKE).bind(code, player.id, player.name, player.device, now.toISOString()).run();
  if (taken.meta.changes > 0) return { status: 200, body: { ...rewardOf(row) } };
  // Nothing written: the last use went a moment ago, or this player's other tap got there first.
  const raced = await deviceThatTook(db, code, player.id);
  return raced !== undefined ? alreadyTaken(row, raced, player) : { status: 410, body: { error: "used up" } };
}

/** Undefined when this player has not taken the coupon; the device they took it on if so. */
async function deviceThatTook(db: D1Database, code: string, playerID: string): Promise<string | null | undefined> {
  const use = await db.prepare(`SELECT device FROM coupon_uses WHERE code = ?1 AND player_id = ?2`)
    .bind(code, playerID).first<{ device: string | null }>();
  return use ? use.device : undefined;
}

/// The reward rides along only to the phone that took it, which may never have heard the
/// first answer. Its purse is keyed on the coupon, so a second payment there is nothing;
/// on any other phone it would be a second pack.
function alreadyTaken(row: CouponRow, device: string | null, player: Redeemer): Answer {
  const again = device !== null && device === player.device;
  return { status: 409, body: { error: "already redeemed", ...(again ? rewardOf(row) : { code: row.code }) } };
}
