import { test } from "node:test";
import assert from "node:assert/strict";
import { collectGifts, cardGiftOf, invalidGift, invalidTaken, isNearToday, MAX_TAKEN, sendGift } from "../src/gifts.ts";
import { memoryD1 } from "./memory-d1.ts";

const NOW = new Date("2026-10-12T09:00:00Z");
const ANNA = { id: "G:anna", name: "Anna" };
const BRUNO = { id: "G:bruno", name: "Bruno" };
const ID_1 = "6f1c2a8e-0000-4000-8000-000000000001";
const ID_2 = "6f1c2a8e-0000-4000-8000-000000000002";

function gift(overrides: Record<string, string> = {}) {
  return cardGiftOf({ id: ID_1, to: BRUNO.id, card: "7c", day: "2026-10-12", ...overrides });
}

/** The real schema, then the migration on top of it, which must be safe to run again. */
function database(): D1Database {
  const db = memoryD1("schema.sql", "migrations/013-card-gifts.sql");
  for (const player of [ANNA, BRUNO, { id: "G:carla", name: "Carla" }]) {
    void db.prepare(`INSERT INTO players (id, name, first_seen, last_seen) VALUES (?1, ?2, ?3, ?3)`)
      .bind(player.id, player.name, "2026-10-01").run();
  }
  return db;
}

test("a gift is a known card, never the settebello, from a phone's own id", () => {
  assert.equal(invalidGift({ id: ID_1, to: "G:bruno", card: "10b", day: "2026-10-12" }), null);
  assert.equal(invalidGift({ id: ID_1, to: "G:bruno", card: "7d", day: "2026-10-12" }), "not the settebello");
  assert.equal(invalidGift({ id: ID_1, to: "G:bruno", card: "11c", day: "2026-10-12" }), "bad card");
  assert.equal(invalidGift({ id: ID_1, to: "G:bruno", card: "7x", day: "2026-10-12" }), "bad card");
  assert.equal(invalidGift({ id: "one", to: "G:bruno", card: "7c", day: "2026-10-12" }), "bad id");
  assert.equal(invalidGift({ id: ID_1, to: "", card: "7c", day: "2026-10-12" }), "bad friend");
  assert.equal(invalidGift({ id: ID_1, to: "G:bruno", card: "7c", day: "today" }), "bad day");
  assert.equal(invalidGift(null), "bad gift");
});

test("the sender's day may be a time zone either side of the Worker's", () => {
  assert.equal(isNearToday("2026-10-12", NOW), true);
  assert.equal(isNearToday("2026-10-11", NOW), true);
  assert.equal(isNearToday("2026-10-13", NOW), true);
  assert.equal(isNearToday("2026-10-14", NOW), false);
  assert.equal(isNearToday("2026-10-09", NOW), false);
});

test("collected ids are a short list of gift ids", () => {
  assert.equal(invalidTaken(undefined), null);
  assert.equal(invalidTaken([ID_1]), null);
  assert.equal(invalidTaken(["nope"]), "bad taken");
  assert.equal(invalidTaken(Array(MAX_TAKEN + 1).fill(ID_1)), "bad taken");
});

test("a card goes to a friend once, and the same gift again is answered the same", async () => {
  const db = database();
  assert.deepEqual(await sendGift(db, ANNA, gift(), NOW), { status: 200, body: { id: ID_1, card: "7c", fresh: true } });
  assert.deepEqual(await sendGift(db, ANNA, gift(), NOW), { status: 200, body: { id: ID_1, card: "7c", fresh: false } });
  assert.deepEqual(await sendGift(db, ANNA, gift({ id: ID_1.toUpperCase() }), NOW),
    { status: 200, body: { id: ID_1, card: "7c", fresh: false } });
});

test("one card a day per sender, whoever it is for", async () => {
  const db = database();
  await sendGift(db, ANNA, gift(), NOW);
  const second = await sendGift(db, ANNA, gift({ id: ID_2, to: "G:carla" }), NOW);
  assert.deepEqual(second, { status: 429, body: { error: "one a day" } });
  assert.equal((await sendGift(db, ANNA, gift({ id: ID_2, day: "2026-10-13" }), NOW)).status, 200);
  assert.equal((await sendGift(db, BRUNO, gift({ id: "6f1c2a8e-0000-4000-8000-000000000003", to: ANNA.id }), NOW)).status, 200);
});

test("a gift needs somebody to go to", async () => {
  const db = database();
  assert.deepEqual(await sendGift(db, ANNA, gift({ to: "G:nobody" }), NOW), { status: 404, body: { error: "unknown player" } });
  assert.deepEqual(await sendGift(db, ANNA, gift({ to: ANNA.id }), NOW), { status: 400, body: { error: "not to yourself" } });
  assert.deepEqual(await sendGift(db, ANNA, gift({ day: "2026-10-01" }), NOW), { status: 400, body: { error: "bad day" } });
  // Nothing was written by any of them, so today's gift is still to give.
  assert.equal((await sendGift(db, ANNA, gift(), NOW)).status, 200);
});

test("another player's gift id is not theirs to reuse", async () => {
  const db = database();
  await sendGift(db, ANNA, gift(), NOW);
  assert.deepEqual(await sendGift(db, BRUNO, gift({ to: ANNA.id }), NOW), { status: 409, body: { error: "taken id" } });
});

test("a gift waits for its friend until their phone says it has it", async () => {
  const db = database();
  await sendGift(db, ANNA, gift(), NOW);
  const waiting = await collectGifts(db, BRUNO.id, [], NOW);
  assert.deepEqual(waiting.body.gifts, [{ id: ID_1, from: "Anna", card: "7c", sentAt: NOW.toISOString() }]);
  // Asked again before saying so, it is handed over again.
  assert.equal(((await collectGifts(db, BRUNO.id, [], NOW)).body.gifts as unknown[]).length, 1);
  assert.deepEqual((await collectGifts(db, BRUNO.id, [ID_1.toUpperCase()], NOW)).body.gifts, []);
});

test("only the friend it is for can collect it, or put it away", async () => {
  const db = database();
  await sendGift(db, ANNA, gift(), NOW);
  assert.deepEqual((await collectGifts(db, "G:carla", [ID_1], NOW)).body.gifts, []);
  assert.deepEqual((await collectGifts(db, ANNA.id, [ID_1], NOW)).body.gifts, []);
  assert.equal(((await collectGifts(db, BRUNO.id, [], NOW)).body.gifts as unknown[]).length, 1);
});
