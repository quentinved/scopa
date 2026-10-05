import { test } from "node:test";
import assert from "node:assert/strict";
import { JACKPOT_DENARI, prizeOf, STRIP_SIZE, wheelStrip } from "../src/wheel.ts";
import { memoryD1 } from "./memory-d1.ts";

const NOW = new Date("2026-10-04T12:00:00Z");
const ago = (hours: number) => new Date(NOW.getTime() - hours * 3_600_000).toISOString().replace(/\.\d{3}Z$/, "Z");

/** The real schema, then the migration on top of it, which must be safe to run again. */
async function database(...names: string[]): Promise<D1Database> {
  const db = memoryD1("schema.sql", "migrations/011-wheel-strip.sql");
  for (const name of names) {
    await db.prepare(`INSERT INTO players (id, name, first_seen, last_seen) VALUES (?1, ?2, '2026-10-01', '2026-10-01')`)
      .bind(`G:${name}`, name).run();
  }
  return db;
}

/** One ledger row as AccountSync writes it, the entry encoded the way Swift encodes it. */
async function entry(db: D1Database, name: string, key: string, amount: number, reason: object, hoursAgo: number, syncedHoursAgo = hoursAgo) {
  const json = JSON.stringify({ key, date: ago(hoursAgo), amount, reason });
  await db.prepare(`INSERT INTO ledger_entries (player_id, key, entry, added_at) VALUES (?1, ?2, ?3, ?4)`)
    .bind(`G:${name}`, key, json, ago(syncedHoursAgo)).run();
}

async function turn(db: D1Database, name: string, day: string, amount: number, hoursAgo: number, item?: string, syncedHoursAgo = hoursAgo) {
  await entry(db, name, `wheel/${day}`, amount, { granted: { _0: "wheel" } }, hoursAgo, syncedHoursAgo);
  if (item) await entry(db, name, `wheel/${day}/item`, 0, { bought: { _0: item } }, hoursAgo, syncedHoursAgo);
}

test("a turn's prize is read off what it paid", () => {
  assert.deepEqual(prizeOf(75, null), { kind: "denari", denari: 75 });
  assert.deepEqual(prizeOf(JACKPOT_DENARI, null), { kind: "jackpot" });
  assert.deepEqual(prizeOf(0, null), { kind: "pack" });
  assert.deepEqual(prizeOf(0, "seat.sail"), { kind: "item", item: "seat.sail" });
});

test("the strip is the last day's turns, newest first, the reader left out", async () => {
  const db = await database("me", "ada", "bea", "cleo");
  await turn(db, "ada", "2026-10-04", 50, 1);
  await turn(db, "bea", "2026-10-04", 0, 2, "seat.sail");
  await turn(db, "cleo", "2026-10-04", 0, 3);
  await turn(db, "me", "2026-10-04", 100, 0.5);
  await turn(db, "ada", "2026-10-02", 250, 40);
  const strip = await wheelStrip(db, "G:me", [], NOW);
  assert.deepEqual(strip.turns.map((t) => [t.name, t.prize]), [
    ["ada", { kind: "denari", denari: 50 }],
    ["bea", { kind: "item", item: "seat.sail" }],
    ["cleo", { kind: "pack" }],
  ]);
  assert.equal(strip.turns[0].at, ago(1));
});

test("friends come first, then everyone else", async () => {
  const db = await database("me", "ada", "bea");
  await turn(db, "ada", "2026-10-04", 25, 1);
  await turn(db, "bea", "2026-10-04", 75, 6);
  const strip = await wheelStrip(db, "G:me", ["G:bea", "G:me"], NOW);
  assert.deepEqual(strip.turns.map((t) => [t.name, t.friend]), [["bea", true], ["ada", false]]);
});

test("old turns a device only just synced are not today's", async () => {
  const db = await database("ada");
  await turn(db, "ada", "2026-09-20", 150, 24 * 14, undefined, 0.1);
  assert.deepEqual((await wheelStrip(db, null, [], NOW)).turns, []);
});

test("debug turns and other grants stay off the strip", async () => {
  const db = await database("ada");
  await entry(db, "ada", "wheel/2026-10-04/debug/1234", 2_500, { granted: { _0: "wheel" } }, 1);
  await entry(db, "ada", "gift/thanks", 500, { granted: { _0: "gift" } }, 1);
  assert.deepEqual(await wheelStrip(db, null, [], NOW), { turns: [], jackpotsThisWeek: 0 });
});

test("the week's jackpots are counted, and the strip is capped", async () => {
  const names = Array.from({ length: STRIP_SIZE + 3 }, (_, n) => `p${n}`);
  const db = await database(...names);
  for (const [n, name] of names.entries()) await turn(db, name, "2026-10-04", 25, n * 0.5 + 0.1);
  await turn(db, "p0", "2026-10-01", JACKPOT_DENARI, 24 * 3);
  await turn(db, "p1", "2026-09-20", JACKPOT_DENARI, 24 * 14);
  const strip = await wheelStrip(db, null, [], NOW);
  assert.equal(strip.turns.length, STRIP_SIZE);
  assert.equal(strip.jackpotsThisWeek, 1);
});
