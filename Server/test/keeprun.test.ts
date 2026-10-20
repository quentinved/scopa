// Keeping a run with an ad, end to end through the Worker's own routes: games go in as the
// phones report them, over the real schema, and the rank answer is read back.
import { test } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { createSign, randomBytes, randomUUID } from "node:crypto";
import { mkdtempSync, readFileSync } from "node:fs";
import { register } from "node:module";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { Env } from "../src/index.ts";
import { signedPayload } from "../src/gamecenter.ts";
import { KEEPABLE_RUN, streakBonus } from "../src/ranking.ts";
import { memoryD1 } from "./memory-d1.ts";

// The Durable Objects need the Workers runtime, which node has not got, and nothing here
// opens one: the room gets an empty base class and the queue is left out altogether.
register(`data:text/javascript,${encodeURIComponent(`
  const stubs = {
    "cloudflare:workers": "export class DurableObject {}",
    "./queue.ts": "export class RankedQueue {}",
  };
  export async function resolve(specifier, context, next) {
    if (!(specifier in stubs)) return next(specifier, context);
    return { url: "data:text/javascript," + encodeURIComponent(stubs[specifier]), shortCircuit: true };
  }`)}`);
const { default: worker } = await import("../src/index.ts");

// Signed as Game Center signs, with a certificate made here and fetched in place of Apple's.
// See gamecenter.test.ts.
const BUNDLE_ID = "com.quentinvedrenne.scopa";
const dir = mkdtempSync(join(tmpdir(), "scopa-keep-"));
execFileSync("openssl", ["req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", join(dir, "key.pem"), "-out", join(dir, "cert.der"),
  "-outform", "DER", "-days", "2", "-subj", "/CN=test", "-sha256"], { stdio: "ignore" });
const privateKey = readFileSync(join(dir, "key.pem"), "utf8");
const certificate = readFileSync(join(dir, "cert.der"));
globalThis.fetch = async () => new Response(certificate);

const ANNA = "G:anna";
const BRUNO = "G:bruno";

interface Rank {
  rating: number;
  games: number;
  wins: number;
  streak: number;
  streakBonus: number;
  keepableRun: { gameID: string; run: number } | null;
  lastChange: number | null;
}

function identity(player: string) {
  const timestamp = Date.now();
  const salt = randomBytes(8);
  const signer = createSign("RSA-SHA256");
  signer.update(signedPayload(player, BUNDLE_ID, timestamp, salt));
  return {
    gamePlayerID: player,
    bundleID: BUNDLE_ID,
    publicKeyURL: "https://static.gc.apple.com/public-key/gc-prod-4.cer",
    signature: signer.sign(privateKey).toString("base64"),
    salt: salt.toString("base64"),
    timestamp,
    displayName: player.slice(2),
  };
}

function ladder(): Env {
  return { DB: memoryD1("schema.sql"), BUNDLE_ID, MAX_SIGNATURE_AGE_SECONDS: "3600" } as Env;
}

function call(env: Env, path: string, body?: unknown): Promise<Response> {
  const init = body === undefined ? {} : { method: "POST", body: JSON.stringify(body) };
  return worker.fetch(new Request(`https://ladder.test${path}`, init), env);
}

async function rank(env: Env, player = ANNA): Promise<Rank> {
  return (await call(env, `/v1/players/${encodeURIComponent(player)}/rank`)).json();
}

async function keep(env: Env, gameID: string, player = ANNA): Promise<Rank> {
  return (await call(env, "/v1/ranked/keep-run", { gameID, identity: identity(player) })).json();
}

/** A game against the house, as the one phone reports it. */
async function house(env: Env, won: boolean, player = ANNA): Promise<{ gameID: string; rank: Rank }> {
  const gameID = randomUUID();
  const response = await call(env, "/v1/ranked/house", { gameID, won, identity: identity(player) });
  return { gameID, rank: await response.json() };
}

async function wins(env: Env, count: number): Promise<void> {
  for (let i = 0; i < count; i++) await house(env, true);
}

/** A game between people, reported by both phones, which settles it at once. */
async function people(env: Env, winner: string, loser: string): Promise<string> {
  const gameID = randomUUID();
  const players = [winner, loser];
  for (const reporter of players) await call(env, "/v1/ranked", { gameID, players, winnerID: winner, identity: identity(reporter) });
  return gameID;
}

/** As if the player's last game had been in a season long gone; the next read rolls them over. */
async function lastSeason(env: Env, player = ANNA): Promise<void> {
  await env.DB.prepare(`UPDATE ratings SET season = '2000-01' WHERE player_id = ?1`).bind(player).run();
}

test("a loss that ends a run of three leaves it to keep, and keeping it leaves the loss standing", async () => {
  const env = ladder();
  for (let i = 0; i < 3; i++) await people(env, ANNA, BRUNO);
  const lost = await people(env, BRUNO, ANNA);
  const broken = await rank(env);
  assert.equal(broken.streak, 0);
  assert.deepEqual(broken.keepableRun, { gameID: lost, run: 3 });
  assert.ok(broken.lastChange! < 0);
  // The winner had no run to lose.
  assert.equal((await rank(env, BRUNO)).keepableRun, null);

  const kept = await keep(env, lost);
  assert.equal(kept.streak, 3);
  assert.equal(kept.streakBonus, streakBonus(3));
  assert.equal(kept.keepableRun, null);
  // Only the run comes back: the loss is still a loss, and still cost what it cost.
  assert.equal(kept.rating, broken.rating);
  assert.equal(kept.lastChange, broken.lastChange);
  assert.deepEqual([kept.games, kept.wins], [4, 3]);
});

test("a run too short to keep is not offered", async () => {
  const env = ladder();
  await wins(env, KEEPABLE_RUN - 1);
  const { gameID, rank: after } = await house(env, false);
  assert.equal(after.keepableRun, null);
  assert.equal((await keep(env, gameID)).streak, 0);
});

test("keeping a run asks for the game that broke it, signed", async () => {
  const env = ladder();
  await wins(env, 3);
  const { gameID } = await house(env, false);
  assert.equal((await call(env, "/v1/ranked/keep-run", { gameID: "nope", identity: identity(ANNA) })).status, 400);
  const forged = { ...identity(ANNA), gamePlayerID: BRUNO };
  assert.equal((await call(env, "/v1/ranked/keep-run", { gameID, identity: forged })).status, 401);
  const elsewhere = await keep(env, randomUUID());
  assert.equal(elsewhere.streak, 0);
  assert.equal(elsewhere.keepableRun?.run, 3);
});

test("the next game closes the window, won or lost", async () => {
  const env = ladder();
  await wins(env, 3);
  const first = (await house(env, false)).gameID;
  assert.equal((await house(env, true)).rank.keepableRun, null);
  assert.equal((await keep(env, first)).streak, 1);

  await wins(env, 2);
  const second = (await house(env, false)).gameID;
  assert.equal((await house(env, false)).rank.keepableRun, null);
  assert.equal((await keep(env, second)).streak, 0);
});

test("a run is kept once: broken again it is gone, and the next run starts afresh", async () => {
  const env = ladder();
  await wins(env, 2);
  assert.equal((await keep(env, (await house(env, false)).gameID)).streak, 2);
  await wins(env, 1);
  const again = await house(env, false);
  assert.equal(again.rank.streak, 0);
  assert.equal(again.rank.keepableRun, null);
  assert.equal((await keep(env, again.gameID)).streak, 0);

  await wins(env, 2);
  const fresh = await house(env, false);
  assert.deepEqual(fresh.rank.keepableRun, { gameID: fresh.gameID, run: 2 });
  assert.equal((await keep(env, fresh.gameID)).streak, 2);
});

test("keeping twice keeps once", async () => {
  const env = ladder();
  await wins(env, 3);
  const { gameID } = await house(env, false);
  const once = await keep(env, gameID);
  assert.equal(once.streak, 3);
  assert.deepEqual(await keep(env, gameID), once);
  // Nor does it reach back once the kept run has moved on.
  await wins(env, 1);
  assert.equal((await keep(env, gameID)).streak, 4);
});

test("a new season takes a run to keep with it", async () => {
  const env = ladder();
  await wins(env, 3);
  const { gameID } = await house(env, false);
  await lastSeason(env);
  const after = await rank(env);
  assert.equal(after.keepableRun, null);
  assert.equal(after.streak, 0);
  assert.equal((await keep(env, gameID)).streak, 0);
});

test("a run kept last season does not spend this season's keep", async () => {
  const env = ladder();
  await wins(env, 2);
  await keep(env, (await house(env, false)).gameID);
  await lastSeason(env);
  assert.equal((await rank(env)).streak, 0);

  await wins(env, 2);
  const lost = await house(env, false);
  assert.deepEqual(lost.rank.keepableRun, { gameID: lost.gameID, run: 2 });
});
