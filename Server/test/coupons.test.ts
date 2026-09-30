import { test } from "node:test";
import assert from "node:assert/strict";
import type { CouponRow } from "../src/coupons.ts";
import { deviceOf, isOver, MAX_PACKS, normaliseCoupon, redeemCoupon, rewardOf } from "../src/coupons.ts";
import { memoryD1 } from "./memory-d1.ts";

const NOW = new Date("2026-10-01T12:00:00Z");
const ANNA = { id: "G:anna", name: "Anna", device: "phone-a" };
const BRUNO = { id: "G:bruno", name: "Bruno", device: "phone-b" };

function row(overrides: Partial<CouponRow> = {}): CouponRow {
  return { code: "NATALE", denari: 500, packs: "velluto", items: "felt.notte", max_uses: null,
    expires_at: null, disabled_at: null, ...overrides };
}

/** The real schema, then the migration on top of it, which must be safe to run again. */
function database(...coupons: string[]): D1Database {
  const db = memoryD1("schema.sql", "migrations/009-coupons.sql");
  for (const values of coupons) {
    void db.prepare(`INSERT INTO coupons (code, denari, packs, items, max_uses, expires_at, disabled_at, note, created_at)
                     VALUES ${values}`).run();
  }
  return db;
}

test("a coupon is typed and forgiven like a friend code", () => {
  assert.equal(normaliseCoupon(" natale-2026 "), "NATALE2026");
  assert.equal(normaliseCoupon("Café"), "CAFE");
  assert.equal(normaliseCoupon(""), "");
  assert.equal(normaliseCoupon(7), "");
});

test("a reward carries only what the app knows how to hand over", () => {
  assert.deepEqual(rewardOf(row({ packs: "velluto, reliquia,legendary", items: "felt.notte,felt.notte,wand.magic,cheer.oro" })),
    { code: "NATALE", denari: 500, packs: ["velluto", "reliquia"], items: ["felt.notte", "cheer.oro"] });
  assert.deepEqual(rewardOf(row({ denari: -5, packs: null, items: "" })), { code: "NATALE", denari: 0, packs: [], items: [] });
  assert.equal(rewardOf(row({ packs: Array(MAX_PACKS + 3).fill("bottega").join(",") })).packs.length, MAX_PACKS);
});

test("a coupon is over after its last instant, or when taken off by hand", () => {
  assert.equal(isOver(row(), NOW), false);
  assert.equal(isOver(row({ expires_at: "2026-10-01T12:00:00Z" }), NOW), false);
  assert.equal(isOver(row({ expires_at: "2026-10-01T11:59:59Z" }), NOW), true);
  assert.equal(isOver(row({ disabled_at: "2026-09-30T00:00:00Z" }), NOW), true);
  assert.equal(isOver(row({ expires_at: "soon" }), NOW), true);
});

test("a device id is a short string or nothing", () => {
  assert.equal(deviceOf("5F0C-11"), "5F0C-11");
  assert.equal(deviceOf(""), null);
  assert.equal(deviceOf(42), null);
  assert.equal(deviceOf("x".repeat(65)), null);
});

test("each player takes a coupon once, and as many different coupons as there are", async () => {
  const db = database(`('NATALE', 500, 'velluto', 'felt.notte', NULL, NULL, NULL, 'xmas', '2026-09-30')`,
    `('PASQUA', 0, 'forziere', '', NULL, NULL, NULL, NULL, '2026-09-30')`);
  const first = await redeemCoupon(db, "NATALE", ANNA, NOW);
  assert.deepEqual(first, { status: 200, body: { code: "NATALE", denari: 500, packs: ["velluto"], items: ["felt.notte"] } });
  assert.equal((await redeemCoupon(db, "PASQUA", ANNA, NOW)).status, 200);
  assert.equal((await redeemCoupon(db, "NATALE", BRUNO, NOW)).status, 200);
  const again = await redeemCoupon(db, "NATALE", ANNA, NOW);
  assert.equal(again.status, 409);
  assert.equal(again.body.error, "already redeemed");
});

test("the reward rides along with a refusal only to the phone that took it", async () => {
  const db = database(`('NATALE', 500, '', '', NULL, NULL, NULL, NULL, '2026-09-30')`);
  await redeemCoupon(db, "NATALE", ANNA, NOW);
  assert.deepEqual((await redeemCoupon(db, "NATALE", ANNA, NOW)).body,
    { error: "already redeemed", code: "NATALE", denari: 500, packs: [], items: [] });
  assert.deepEqual((await redeemCoupon(db, "NATALE", { ...ANNA, device: "ipad" }, NOW)).body,
    { error: "already redeemed", code: "NATALE" });
  assert.deepEqual((await redeemCoupon(db, "NATALE", { ...ANNA, device: null }, NOW)).body,
    { error: "already redeemed", code: "NATALE" });
});

test("every refusal says which it is", async () => {
  const db = database(`('OLD', 100, '', '', NULL, '2026-09-01T23:59:59Z', NULL, NULL, '2026-08-01')`,
    `('OFF', 100, '', '', NULL, NULL, '2026-09-30T08:00:00Z', NULL, '2026-08-01')`,
    `('ONE', 100, '', '', 1, NULL, NULL, NULL, '2026-08-01')`);
  assert.deepEqual(await redeemCoupon(db, "NOPE", ANNA, NOW), { status: 404, body: { error: "unknown code" } });
  assert.deepEqual(await redeemCoupon(db, "OLD", ANNA, NOW), { status: 410, body: { error: "expired" } });
  assert.deepEqual(await redeemCoupon(db, "OFF", ANNA, NOW), { status: 410, body: { error: "expired" } });
  assert.equal((await redeemCoupon(db, "ONE", ANNA, NOW)).status, 200);
  assert.deepEqual(await redeemCoupon(db, "ONE", BRUNO, NOW), { status: 410, body: { error: "used up" } });
  // Anna took the last one herself, which is the thing worth telling her.
  assert.equal((await redeemCoupon(db, "ONE", ANNA, NOW)).body.error, "already redeemed");
});

test("a coupon taken before it ran out still answers as taken", async () => {
  const db = database(`('NATALE', 100, '', '', NULL, '2026-10-01T00:00:00Z', NULL, NULL, '2026-09-01')`);
  assert.equal((await redeemCoupon(db, "NATALE", ANNA, new Date("2026-09-30T00:00:00Z"))).status, 200);
  assert.equal((await redeemCoupon(db, "NATALE", ANNA, NOW)).body.error, "already redeemed");
  assert.equal((await redeemCoupon(db, "NATALE", BRUNO, NOW)).body.error, "expired");
});

test("the table refuses a coupon worth nothing", async () => {
  const db = memoryD1("schema.sql");
  await assert.rejects(() => db.prepare(`INSERT INTO coupons (code, created_at) VALUES ('EMPTY', '2026-09-30')`).run());
});
