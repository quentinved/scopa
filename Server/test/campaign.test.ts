import { test } from "node:test";
import assert from "node:assert/strict";
import { campaignBoard, FACES_PER_STAGE, friendsCampaignBoard, invalidLookup, invalidProgress, progressOf, recordProgress, stageFaces } from "../src/campaign.ts";
import { memoryD1 } from "./memory-d1.ts";

const DAY = new Date("2026-10-03T12:00:00Z");
const later = (minutes: number) => new Date(DAY.getTime() + minutes * 60_000);

/** The real schema, then the migration on top of it, which must be safe to run again. */
async function database(...names: string[]): Promise<D1Database> {
  const db = memoryD1("schema.sql", "migrations/010-campaign.sql");
  for (const name of names) {
    await db.prepare(`INSERT INTO players (id, name, first_seen, last_seen) VALUES (?1, ?2, '2026-10-01', '2026-10-01')`)
      .bind(`G:${name}`, name).run();
  }
  return db;
}

function progress(stage: number, stars: number, mark: string | null = null) {
  return { stage, stars, mark, livery: null, cornice: null };
}

test("a progress post is a table reached and the stars won before it", () => {
  assert.equal(invalidProgress({ stage: 9, stars: 20, mark: "medalGold", livery: "iride", cornice: null }), null);
  assert.equal(invalidProgress({ stage: 1, stars: 0 }), null);
  assert.equal(invalidProgress(null), "bad body");
  assert.equal(invalidProgress({ stage: 0, stars: 0 }), "bad stage");
  assert.equal(invalidProgress({ stage: 31, stars: 0 }), "bad stage");
  assert.equal(invalidProgress({ stage: "9", stars: 0 }), "bad stage");
  assert.equal(invalidProgress({ stage: 4, stars: -1 }), "bad stars");
  assert.equal(invalidProgress({ stage: 4, stars: 2.5 }), "bad stars");
  assert.equal(invalidProgress({ stage: 2, stars: 7 }), "more stars than tables");
  assert.equal(invalidProgress({ stage: 2, stars: 3, mark: "<script>" }), "bad look");
  assert.equal(invalidProgress({ stage: 2, stars: 3, livery: 7 }), "bad look");
  assert.equal(invalidProgress({ stage: 2, stars: 3, cornice: "x".repeat(33) }), "bad look");
});

test("only the known fields are kept", () => {
  assert.deepEqual(progressOf({ stage: 3, stars: 5, mark: "sail", extra: "drop me" }),
    { stage: 3, stars: 5, mark: "sail", livery: null, cornice: null });
});

test("a lookup takes a friend list and a player id, each checked", () => {
  assert.equal(invalidLookup({ player: "G:a", friends: ["G:b"] }, true), null);
  assert.equal(invalidLookup({ player: "G:a" }, false), null);
  assert.equal(invalidLookup({ player: "G:a" }, true), "bad friends");
  assert.equal(invalidLookup({ player: 5, friends: [] }, true), "bad player");
  assert.equal(invalidLookup({ friends: [""] }, false), "bad friend id");
  assert.equal(invalidLookup("nope", false), "bad body");
});

test("progress only climbs, and the look follows the latest post", async () => {
  const db = await database("anna");
  await recordProgress(db, "G:anna", progress(9, 20, "sail"), DAY);
  await recordProgress(db, "G:anna", progress(4, 8, "crown"), later(5));
  const { top } = await campaignBoard(db, null);
  assert.equal(top[0].stage, 9);
  assert.equal(top[0].stars, 20);
  assert.equal(top[0].mark, "crown");
});

test("the board ranks by stars, then the furthest road, then who got there first", async () => {
  const db = await database("anna", "bruno", "carla", "dario");
  await recordProgress(db, "G:anna", progress(10, 25), DAY);
  await recordProgress(db, "G:bruno", progress(12, 25), later(1));
  await recordProgress(db, "G:carla", progress(10, 25), later(2));
  const place = await recordProgress(db, "G:dario", progress(20, 40), later(3));
  const { top, you } = await campaignBoard(db, "G:carla");
  assert.deepEqual(top.map((row) => row.name), ["dario", "bruno", "anna", "carla"]);
  assert.deepEqual(you, { played: 4, rank: 4, percentile: 0 });
  assert.deepEqual(place, { played: 4, rank: 1, percentile: 100 });
  assert.deepEqual((await campaignBoard(db, "G:nobody")).you, { played: 4, rank: null, percentile: null });
});

test("the friends' board holds the friends and the reader, nobody else", async () => {
  const db = await database("anna", "bruno", "carla");
  await recordProgress(db, "G:anna", progress(5, 10), DAY);
  await recordProgress(db, "G:bruno", progress(8, 20), DAY);
  await recordProgress(db, "G:carla", progress(30, 90), DAY);
  const { top, you } = await friendsCampaignBoard(db, "G:anna", ["G:bruno", "G:stranger"]);
  assert.deepEqual(top.map((row) => row.name), ["bruno", "anna"]);
  assert.deepEqual(you, { played: 2, rank: 2, percentile: null });
});

test("each table shows friends first, then the latest to arrive, and counts the rest", async () => {
  const names = ["me", "f1", "o1", "o2", "o3", "o4", "o5"];
  const db = await database(...names);
  await recordProgress(db, "G:me", progress(6, 12), DAY);
  await recordProgress(db, "G:f1", progress(6, 10), DAY);
  for (const [index, name] of ["o1", "o2", "o3", "o4"].entries()) {
    await recordProgress(db, `G:${name}`, progress(6, 10), later(index + 1));
  }
  await recordProgress(db, "G:o5", progress(2, 3), DAY);
  const stages = await stageFaces(db, "G:me", ["G:f1", "G:me"]);
  assert.deepEqual(stages.map((s) => s.stage), [2, 6]);
  const six = stages[1];
  // The reader is not a face at their own table, nor counted.
  assert.equal(six.count, 5);
  assert.equal(six.faces.length, FACES_PER_STAGE);
  assert.deepEqual(six.faces.map((f) => [f.name, f.friend]), [["f1", true], ["o4", false], ["o3", false]]);
  assert.deepEqual(stages[0].faces.map((f) => f.name), ["o5"]);
});

test("without a reader or friends every table still has its faces", async () => {
  const db = await database("anna", "bruno");
  await recordProgress(db, "G:anna", progress(1, 0), DAY);
  await recordProgress(db, "G:bruno", progress(1, 0), later(1));
  const [one] = await stageFaces(db, null, []);
  assert.equal(one.count, 2);
  assert.deepEqual(one.faces.map((f) => f.name), ["bruno", "anna"]);
});
