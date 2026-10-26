// Gran Maestro through the Worker's own routes: a build that sends the ladder header is told
// the points and the place past Maestro I, and a build that does not is told the ladder as
// 1.4 knows it, capped at Maestro I.
import { test } from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import type { Env } from "../src/index.ts";
import { LADDER_HEADER } from "../src/granmaestro.ts";
import { CAMPIONE_POINTS, CAMPIONI, floorOf, GRAN_MAESTRO, GRAND_FLOOR, GRAND_HOUSE_LOSS, GRAND_HOUSE_WIN, HOUSE_WIN, seasonOf, standing } from "../src/ranking.ts";
import { call, identity, ladder } from "./worker.ts";

const NEW = { [LADDER_HEADER]: "2" };
const SEASON = seasonOf(new Date());

/** A player on the ladder, written straight into it. `at` orders a dead heat: earlier first. */
async function seat(env: Env, id: string, rating: number, options: { wins?: number; games?: number; season?: string; at?: string } = {}) {
  const { wins = 10, games = 20, season = SEASON, at = "2026-01-01T00:00:00.000Z" } = options;
  await env.DB.prepare(`INSERT INTO players (id, name, first_seen, last_seen) VALUES (?1, ?2, ?3, ?3)`).bind(id, id.slice(2), at).run();
  await env.DB.prepare(
    `INSERT INTO ratings (player_id, rating, floor, games, wins, season, streak, updated_at) VALUES (?1, ?2, ?3, ?4, ?5, ?6, 0, ?7)`,
  ).bind(id, rating, floorOf(standing(rating, true).league), games, wins, season, at).run();
}

async function rank(env: Env, player: string, headers: Record<string, string> = {}) {
  return (await call(env, `/v1/players/${encodeURIComponent(player)}/rank`, undefined, headers)).json();
}

async function board(env: Env, query: string, headers: Record<string, string> = NEW) {
  return (await call(env, `/v1/ranked/board?${query}`, undefined, headers)).json();
}

test("a build without the header is told Maestro I, as 1.4 always was", async () => {
  const env = ladder();
  await seat(env, "G:anna", GRAND_FLOOR + 340);
  const old = await rank(env, "G:anna");
  assert.equal(old.standing.title, "Maestro I");
  assert.equal(old.standing.league, 5);
  assert.equal(old.standing.progress, 99);
  assert.equal("grand" in old, false);
  const rows = (await board(env, "player=G:anna", {})).top;
  assert.equal(rows[0].standing.title, "Maestro I");
  assert.equal("place" in rows[0], false);
});

test("a build with the header is told Gran Maestro, its points and its place", async () => {
  const env = ladder();
  await seat(env, "G:anna", GRAND_FLOOR + 340, { wins: 12 });
  await seat(env, "G:bruno", GRAND_FLOOR + 900);
  await seat(env, "G:carla", GRAND_FLOOR - 50);
  const anna = await rank(env, "G:anna", NEW);
  assert.equal(anna.standing.league, GRAN_MAESTRO);
  assert.equal(anna.standing.title, "Gran Maestro");
  assert.equal(anna.standing.progress, 340);
  assert.deepEqual(anna.grand, { points: 340, place: 2, campione: true });
  // Below Gran Maestro there is nothing to place.
  const carla = await rank(env, "G:carla", NEW);
  assert.equal(carla.standing.title, "Maestro I");
  assert.equal(carla.grand, null);
});

test("Campione is the top ten, and only from three hundred points", async () => {
  const env = ladder();
  for (let i = 0; i < CAMPIONI + 1; i++) await seat(env, `G:p${i}`, GRAND_FLOOR + 2_000 - i * 10);
  await seat(env, "G:early", GRAND_FLOOR + CAMPIONE_POINTS - 1, { games: 30 });
  assert.deepEqual((await rank(env, `G:p${CAMPIONI - 1}`, NEW)).grand, { points: 2_000 - (CAMPIONI - 1) * 10, place: CAMPIONI, campione: true });
  assert.equal((await rank(env, `G:p${CAMPIONI}`, NEW)).grand.campione, false);

  const empty = ladder();
  await seat(empty, "G:first", GRAND_FLOOR + CAMPIONE_POINTS - 1);
  assert.deepEqual((await rank(empty, "G:first", NEW)).grand, { points: CAMPIONE_POINTS - 1, place: 1, campione: false });
});

test("a dead heat goes to whoever got there first, as on the board", async () => {
  const env = ladder();
  await seat(env, "G:later", GRAND_FLOOR + 400, { at: "2026-01-02T00:00:00.000Z" });
  await seat(env, "G:sooner", GRAND_FLOOR + 400, { at: "2026-01-01T00:00:00.000Z" });
  assert.equal((await rank(env, "G:sooner", NEW)).grand.place, 1);
  assert.equal((await rank(env, "G:later", NEW)).grand.place, 2);
});

test("a Gran Maestro carried into a season with no game yet has points but no place", async () => {
  const env = ladder();
  await seat(env, "G:anna", GRAND_FLOOR, { games: 0, wins: 0 });
  assert.deepEqual((await rank(env, "G:anna", NEW)).grand, { points: 0, place: null, campione: false });
});

test("Gran Maestro's own board lists only Gran Maestri, placed, with the reader's place", async () => {
  const env = ladder();
  await seat(env, "G:anna", GRAND_FLOOR + 340);
  await seat(env, "G:bruno", GRAND_FLOOR + 120);
  await seat(env, "G:carla", GRAND_FLOOR - 50);
  await seat(env, "G:dario", GRAND_FLOOR + 999, { season: "2000-01" });
  const grand = await board(env, "tier=grand&player=G:bruno");
  assert.deepEqual(grand.top.map((row: { id: string }) => row.id), ["G:anna", "G:bruno"]);
  assert.deepEqual(grand.top.map((row: { place: number; campione: boolean }) => [row.place, row.campione]), [[1, true], [2, false]]);
  assert.equal(grand.top[0].standing.title, "Gran Maestro");
  assert.deepEqual(grand.you, { season: SEASON, played: 2, rank: 2 });
  assert.equal((await board(env, "tier=grand&player=G:carla")).you.rank, null);
});

test("the season's boards place their Gran Maestri too, the friends' by the whole season", async () => {
  const env = ladder();
  await seat(env, "G:anna", GRAND_FLOOR + 600);
  await seat(env, "G:bruno", GRAND_FLOOR + 320);
  await seat(env, "G:carla", 900);
  const everyone = (await board(env, "player=G:carla")).top;
  assert.deepEqual(everyone.map((row: { place?: number }) => row.place), [1, 2, undefined]);
  assert.equal(everyone[2].standing.title, "Platinum III");

  const friends = await (await call(env, "/v1/ranked/board/friends", { player: "G:carla", friends: ["G:bruno"] }, NEW)).json();
  assert.deepEqual(friends.top.map((row: { id: string; place?: number }) => [row.id, row.place]), [["G:bruno", 2], ["G:carla", undefined]]);
  assert.equal(friends.top[0].campione, true);
  const old = await (await call(env, "/v1/ranked/board/friends", { player: "G:carla", friends: ["G:bruno"] })).json();
  assert.equal(old.top[0].standing.title, "Maestro I");
  assert.equal("place" in old.top[0], false);
});

test("a finished season carries its final place, from finishes and rows not rolled over yet", async () => {
  const env = ladder();
  await seat(env, "G:anna", GRAND_FLOOR + 500, { season: "2000-01" });
  await seat(env, "G:bruno", GRAND_FLOOR + 800, { season: "2000-01" });
  await seat(env, "G:carla", GRAND_FLOOR + 900, { season: "2000-01" });
  // Carla's next look puts her season away first; Bruno has not been back since.
  await rank(env, "G:carla", NEW);
  const anna = await rank(env, "G:anna", NEW);
  assert.equal(anna.rating, GRAND_FLOOR);
  assert.equal(anna.finish.standing.title, "Gran Maestro");
  assert.deepEqual(anna.finish.grand, { points: 500, place: 3, campione: true });
  const old = await rank(env, "G:bruno");
  assert.equal(old.finish.standing.title, "Maestro I");
  assert.equal("grand" in old.finish, false);
});

test("a house game in Gran Maestro pays fifteen and costs ten, and the answer quotes it", async () => {
  const env = ladder();
  await seat(env, "G:anna", GRAND_FLOOR + 100);
  const win = await (await call(env, "/v1/ranked/house", { gameID: randomUUID(), won: true, identity: identity("G:anna") }, NEW)).json();
  assert.equal(win.lastChange, GRAND_HOUSE_WIN);
  assert.deepEqual([win.house.win, win.house.loss], [GRAND_HOUSE_WIN, GRAND_HOUSE_LOSS]);
  assert.equal(win.grand.points, 100 + GRAND_HOUSE_WIN);
  // An old build is paid the same, since the Worker settles it, and told it as Maestro I.
  const loss = await (await call(env, "/v1/ranked/house", { gameID: randomUUID(), won: false, identity: identity("G:anna") })).json();
  assert.equal(loss.lastChange, GRAND_HOUSE_LOSS);
  assert.equal(loss.standing.title, "Maestro I");
  assert.equal("grand" in loss, false);

  await seat(env, "G:bruno", GRAND_FLOOR - 10);
  const climb = await (await call(env, "/v1/ranked/house", { gameID: randomUUID(), won: true, identity: identity("G:bruno") }, NEW)).json();
  assert.equal(climb.rating, GRAND_FLOOR - 10 + HOUSE_WIN);
  assert.equal(climb.standing.title, "Gran Maestro");
  assert.deepEqual([climb.house.win, climb.house.loss], [GRAND_HOUSE_WIN, GRAND_HOUSE_LOSS]);
});
