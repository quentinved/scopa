// The Scopa ladder Worker: daily and weekly boards, ranked play, tables and a few pages.
//
// Every write to the ladder is signed by Game Center, so a result is only recorded for
// the player who made it. The app works without this Worker.

import { Identity, IdentityError, verifyIdentity, VerifyOptions } from "./gamecenter.ts";
import { apply, change, houseChange, HOUSE_GAMES_PER_DAY, HOUSE_LOSS, HOUSE_WIN, resetForSeason, seasonEnd, seasonOf, standing as leagueStanding, streakAfter, streakBonus } from "./ranking.ts";
import { privacyPage } from "./privacy.ts";
import { supportPage } from "./support.ts";
import { invitePage, siteAssociation } from "./invite.ts";
import { cursor, invalidLedger, invalidProfile, LedgerPost, MAX_LEDGER_PAGE } from "./profile.ts";
import { isCode, makeCode, normaliseCode, Room } from "./room.ts";
import { BEAT_SECONDS, fingerprint, friendSet, invalidFriends, WINDOW_SECONDS } from "./presence.ts";

export { Room };

export interface Env {
  DB: D1Database;
  BUNDLE_ID: string;
  MAX_SIGNATURE_AGE_SECONDS: string;
  /// One Durable Object per open table. See room.ts.
  ROOMS: DurableObjectNamespace;
}

const DAY = /^\d{4}-\d{2}-\d{2}$/;
/** "2026-W37", built by the app from the player's own calendar. */
const WEEK = /^\d{4}-W\d{2}$/;
const SEASON = /^\d{4}-\d{2}$/;
const GAME_ID = /^[0-9A-Fa-f-]{36}$/;
const LEADERBOARD_SIZE = 50;

// MARK: - Routing

interface Call {
  request: Request;
  url: URL;
  env: Env;
  /** The capture groups of the matched path, in order. */
  params: string[];
}

interface Route {
  /** An HTTP method, or "*" for any. */
  method: string;
  path: RegExp;
  handle: (call: Call) => Promise<Response> | Response;
}

// Paths are matched with empty segments dropped, so a trailing slash is tolerated.
const routes: Route[] = [
  { method: "POST", path: /^\/v1\/daily$/, handle: ({ request, env }) => postDaily(request, env) },
  { method: "GET", path: /^\/v1\/daily\/([^/]+)$/, handle: ({ url, env, params: [day] }) => getDaily(day, url.searchParams.get("player"), env) },
  { method: "POST", path: /^\/v1\/weekly$/, handle: ({ request, env }) => postWeekly(request, env) },
  { method: "GET", path: /^\/v1\/weekly\/([^/]+)$/, handle: ({ url, env, params: [week] }) => getWeekly(week, url.searchParams.get("player"), env) },
  { method: "POST", path: /^\/v1\/ranked\/claim$/, handle: ({ request, env }) => claimSeason(request, env) },
  { method: "POST", path: /^\/v1\/ranked\/house$/, handle: ({ request, env }) => postHouseGame(request, env) },
  { method: "POST", path: /^\/v1\/ranked$/, handle: ({ request, env }) => postRanked(request, env) },
  { method: "GET", path: /^\/v1\/players\/([^/]+)\/rank$/, handle: async ({ env, params: [id] }) => json(await rankOf(decodeURIComponent(id), env)) },
  { method: "POST", path: /^\/v1\/profile\/read$/, handle: ({ request, env }) => readProfile(request, env) },
  { method: "POST", path: /^\/v1\/profile\/write$/, handle: ({ request, env }) => writeProfile(request, env) },
  { method: "GET", path: /^\/v1\/online$/, handle: ({ env }) => getOnline(env) },
  { method: "POST", path: /^\/v1\/presence$/, handle: ({ request, env }) => postPresence(request, env) },
  { method: "POST", path: /^\/v1\/presence\/leave$/, handle: ({ request, env }) => leavePresence(request, env) },
  { method: "GET", path: /^\/v1\/health$/, handle: () => json({ ok: true }) },
  // Tables are not signed: they work for players who never signed in to Game Center.
  { method: "POST", path: /^\/v1\/rooms$/, handle: ({ request, url, env }) => openRoom(request, url, env) },
  { method: "*", path: /^\/v1\/rooms\/([^/]+)(?:\/([^/]+))?/, handle: ({ request, url, env, params: [code, leaf] }) => room(request, url, code, leaf, env) },
  // Universal links: the file iOS reads to trust the domain, and the page for everyone else.
  { method: "GET", path: /^\/\.well-known\/apple-app-site-association$/, handle: () => siteAssociation() },
  { method: "GET", path: /^\/j(?:\/([^/]+))?/, handle: ({ params: [code] }) => invitePage(normaliseCode(code ?? "")) },
  // AdMob and App Store Connect both need public URLs for these.
  { method: "GET", path: /^\/privacy$/, handle: () => privacyPage() },
  { method: "GET", path: /^\/support$/, handle: () => supportPage() },
];

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const path = "/" + url.pathname.split("/").filter(Boolean).join("/");
    try {
      for (const route of routes) {
        if (route.method !== "*" && route.method !== request.method) continue;
        const match = route.path.exec(path);
        if (match) return await route.handle({ request, url, env, params: match.slice(1) });
      }
      return json({ error: "not found" }, 404);
    } catch (error) {
      if (error instanceof IdentityError) return json({ error: error.message }, 401);
      console.error(error);
      return json({ error: "something went wrong" }, 500);
    }
  },
};

// MARK: - Shared pieces

function verifyOptions(env: Env): VerifyOptions {
  return { bundleID: env.BUNDLE_ID, maxAgeSeconds: Number(env.MAX_SIGNATURE_AGE_SECONDS || 3600) };
}

function displayName(identity: Identity): string {
  return (identity.displayName ?? "").slice(0, 40) || "Player";
}

/** Creates the player row or refreshes its name and last_seen. */
function upsertPlayer(env: Env, id: string, name: string, now: string): D1PreparedStatement {
  return env.DB.prepare(
    `INSERT INTO players (id, name, first_seen, last_seen) VALUES (?1, ?2, ?3, ?3)
     ON CONFLICT(id) DO UPDATE SET name = excluded.name, last_seen = excluded.last_seen`,
  ).bind(id, name, now);
}

/** `streak` is the run as it stands *after* this game: a house game passes its own back
 *  unchanged, since the house neither lengthens a run nor ends one. */
function upsertRating(env: Env, id: string, next: { rating: number; floor: number }, won: boolean, now: string, season: string, streak: number): D1PreparedStatement {
  return env.DB.prepare(
    `INSERT INTO ratings (player_id, rating, floor, games, wins, season, streak, updated_at) VALUES (?1, ?2, ?3, 1, ?4, ?6, ?7, ?5)
     ON CONFLICT(player_id) DO UPDATE SET rating = ?2, floor = ?3, games = games + 1, wins = wins + ?4, season = ?6, streak = ?7, updated_at = ?5`,
  ).bind(id, next.rating, next.floor, won ? 1 : 0, now, season, streak);
}

async function currentRating(playerID: string, env: Env): Promise<{ rating: number; floor: number; streak: number }> {
  const row = await env.DB.prepare(`SELECT rating, floor, streak FROM ratings WHERE player_id = ?1`).bind(playerID)
    .first<{ rating: number; floor: number; streak: number }>();
  return { rating: row?.rating ?? 0, floor: row?.floor ?? 0, streak: row?.streak ?? 0 };
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
}

// MARK: - Online

/// The lobby adds a house figure of its own, so only real players are counted here.
const ONLINE_WINDOW_MINUTES = 10;

async function getOnline(env: Env): Promise<Response> {
  const since = new Date(Date.now() - ONLINE_WINDOW_MINUTES * 60_000).toISOString();
  const row = await env.DB.prepare(`SELECT COUNT(*) AS n FROM players WHERE last_seen >= ?1`)
    .bind(since)
    .first<{ n: number }>();
  return json({ online: row?.n ?? 0 });
}

// MARK: - Friends online

interface PresencePost {
  identity: Identity;
  /** The `gamePlayerID` of every Game Center friend the app can see. */
  friends: string[];
}

/** A heartbeat: this player is here, these are their friends. Answers with the friends who
 *  are here too and who count this player as a friend in return. */
async function postPresence(request: Request, env: Env): Promise<Response> {
  const body = (await request.json()) as PresencePost;
  if (!body.identity?.gamePlayerID) return json({ error: "no identity" }, 400);
  const problem = invalidFriends(body.friends);
  if (problem) return json({ error: problem }, 400);
  await verifyIdentity(body.identity, verifyOptions(env));

  const playerID = body.identity.gamePlayerID;
  const friends = friendSet(body.friends, playerID);
  const key = await fingerprint(friends);
  const now = new Date();
  const stored = await env.DB.prepare(`SELECT friends_key FROM presence WHERE player_id = ?1`)
    .bind(playerID).first<{ friends_key: string }>();

  const writes = [
    upsertPlayer(env, playerID, displayName(body.identity), now.toISOString()),
    env.DB.prepare(
      `INSERT INTO presence (player_id, seen_at, friends_key) VALUES (?1, ?2, ?3)
       ON CONFLICT(player_id) DO UPDATE SET seen_at = excluded.seen_at, friends_key = excluded.friends_key`,
    ).bind(playerID, now.toISOString(), key),
  ];
  if (stored?.friends_key !== key) {
    writes.push(env.DB.prepare(`DELETE FROM presence_friends WHERE player_id = ?1`).bind(playerID));
    for (const friend of friends) {
      writes.push(env.DB.prepare(`INSERT OR IGNORE INTO presence_friends (player_id, friend_id) VALUES (?1, ?2)`)
        .bind(playerID, friend));
    }
  }
  await env.DB.batch(writes);

  // Both directions: they named this player in their last beat, and this player named them
  // in this one.
  const since = new Date(now.getTime() - WINDOW_SECONDS * 1000).toISOString();
  const { results } = await env.DB.prepare(
    `SELECT pl.id AS id, pl.name AS name
       FROM presence_friends theirs
       JOIN presence_friends mine ON mine.player_id = ?1 AND mine.friend_id = theirs.player_id
       JOIN presence p ON p.player_id = theirs.player_id
       JOIN players pl ON pl.id = theirs.player_id
      WHERE theirs.friend_id = ?1 AND p.seen_at >= ?2`,
  ).bind(playerID, since).all<{ id: string; name: string }>();
  return json({ online: results, every: BEAT_SECONDS });
}

/** Off every list at once: the setting was turned off, or the player signed out. */
async function leavePresence(request: Request, env: Env): Promise<Response> {
  const body = (await request.json()) as { identity: Identity };
  if (!body.identity?.gamePlayerID) return json({ error: "no identity" }, 400);
  await verifyIdentity(body.identity, verifyOptions(env));
  const playerID = body.identity.gamePlayerID;
  await env.DB.batch([
    env.DB.prepare(`DELETE FROM presence_friends WHERE player_id = ?1`).bind(playerID),
    env.DB.prepare(`DELETE FROM presence WHERE player_id = ?1`).bind(playerID),
  ]);
  return json({ ok: true });
}

// MARK: - Tables

/// Retries on a clash. Codes are four letters of a 32-letter alphabet, so it is rare.
const CODE_ATTEMPTS = 5;

interface OpenRoom {
  /// The host's player id as the app knows it, not a Game Center id.
  host: string;
  name: string;
  capacity?: number;
}

async function openRoom(request: Request, url: URL, env: Env): Promise<Response> {
  const body = (await request.json()) as OpenRoom;
  const host = (body?.host ?? "").trim();
  const name = (body?.name ?? "").trim();
  if (!host || host.length > 100) return json({ error: "bad host" }, 400);
  if (!name) return json({ error: "no name" }, 400);
  for (let attempt = 0; attempt < CODE_ATTEMPTS; attempt++) {
    const code = makeCode();
    const stub = env.ROOMS.get(env.ROOMS.idFromName(code));
    const opened = await stub.fetch("https://room/open", {
      method: "POST",
      body: JSON.stringify({ code, host, hostName: name, capacity: body.capacity }),
    });
    if (opened.ok) return json({ code, link: `${url.origin}/j/${code}` });
    // 409 means the code is taken. Anything else is a real failure.
    if (opened.status !== 409) return opened;
  }
  return json({ error: "could not open a table" }, 503);
}

/// The join screen's status check and the socket the game runs over.
async function room(request: Request, url: URL, raw: string, leaf: string | undefined, env: Env): Promise<Response> {
  const code = normaliseCode(raw);
  // A malformed code is refused here rather than by waking a Durable Object for it.
  if (!isCode(code)) return json({ error: "no such table" }, 404);
  const stub = env.ROOMS.get(env.ROOMS.idFromName(code));
  if (leaf === "socket" && request.method === "GET") {
    return stub.fetch(new Request(`https://room/socket?${url.searchParams}`, request));
  }
  if (!leaf && request.method === "GET") return stub.fetch("https://room/status");
  return json({ error: "not found" }, 404);
}

// MARK: - The daily deal

interface DailyPost {
  day: string;
  mine: number;
  theirs: number;
  scope: number;
  accuracy?: number | null;
  identity: Identity;
}

function invalidDaily(body: DailyPost): string | null {
  if (!DAY.test(body.day ?? "")) return "bad day";
  for (const field of [body.mine, body.theirs, body.scope]) {
    if (!Number.isInteger(field) || field < 0 || field > 40) return "bad score";
  }
  if (body.accuracy != null && (!Number.isInteger(body.accuracy) || body.accuracy < 0 || body.accuracy > 100)) {
    return "bad accuracy";
  }
  if (!body.identity?.gamePlayerID) return "no identity";
  return null;
}

async function postDaily(request: Request, env: Env): Promise<Response> {
  const body = (await request.json()) as DailyPost;
  const problem = invalidDaily(body);
  if (problem) return json({ error: problem }, 400);
  await verifyIdentity(body.identity, verifyOptions(env));

  const playerID = body.identity.gamePlayerID;
  const now = new Date().toISOString();
  const margin = body.mine - body.theirs;
  await env.DB.batch([
    upsertPlayer(env, playerID, displayName(body.identity), now),
    env.DB.prepare(
      `INSERT OR IGNORE INTO daily_results (day, player_id, margin, mine, theirs, scope, accuracy, played_at)
       VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)`,
    ).bind(body.day, playerID, margin, body.mine, body.theirs, body.scope, body.accuracy ?? null, now),
  ]);
  return json(await standing(body.day, playerID, env));
}

async function getDaily(day: string, playerID: string | null, env: Env): Promise<Response> {
  if (!DAY.test(day)) return json({ error: "bad day" }, 400);
  const top = await env.DB.prepare(
    `SELECT r.player_id AS id, p.name, r.margin, r.mine, r.theirs, r.scope, r.accuracy
     FROM daily_results r JOIN players p ON p.id = r.player_id
     WHERE r.day = ?1
     ORDER BY r.margin DESC, r.accuracy DESC, r.played_at ASC
     LIMIT ${LEADERBOARD_SIZE}`,
  ).bind(day).all();
  const you = playerID ? await standing(day, playerID, env) : null;
  return json({ day, top: top.results, you });
}

/** One player's rank on a day, among everyone who played it. */
async function standing(day: string, playerID: string, env: Env) {
  const mine = await env.DB.prepare(`SELECT margin, accuracy, played_at FROM daily_results WHERE day = ?1 AND player_id = ?2`)
    .bind(day, playerID)
    .first<{ margin: number; accuracy: number | null; played_at: string }>();
  const total = await env.DB.prepare(`SELECT COUNT(*) AS n FROM daily_results WHERE day = ?1`).bind(day).first<{ n: number }>();
  if (!mine) return { day, played: total?.n ?? 0, rank: null };
  const ahead = await env.DB.prepare(
    `SELECT COUNT(*) AS n FROM daily_results
     WHERE day = ?1 AND (margin > ?2 OR (margin = ?2 AND COALESCE(accuracy, -1) > COALESCE(?3, -1))
        OR (margin = ?2 AND COALESCE(accuracy, -1) = COALESCE(?3, -1) AND played_at < ?4))`,
  ).bind(day, mine.margin, mine.accuracy, mine.played_at).first<{ n: number }>();
  const played = total?.n ?? 1;
  const rank = (ahead?.n ?? 0) + 1;
  return { day, played, rank, percentile: Math.round(((played - rank) / Math.max(played - 1, 1)) * 100) };
}

// MARK: - The weekly challenge

interface WeeklyPost {
  week: string;
  /** Progress towards the goal. Only ever climbs, see postWeekly. */
  count: number;
  /** The week's target, stored so a board can be read without recomputing it. */
  goal: number;
  identity: Identity;
}

function invalidWeekly(body: WeeklyPost): string | null {
  if (!WEEK.test(body.week ?? "")) return "bad week";
  for (const field of [body.count, body.goal]) {
    if (!Number.isInteger(field) || field < 0 || field > 10_000) return "bad count";
  }
  if (!body.identity?.gamePlayerID) return "no identity";
  return null;
}

/** Posted as the player plays, so unfinished weeks still show on the board. The count is
 *  clamped upwards: a second phone, an offline spell or a reinstall must not walk it back. */
async function postWeekly(request: Request, env: Env): Promise<Response> {
  const body = (await request.json()) as WeeklyPost;
  const problem = invalidWeekly(body);
  if (problem) return json({ error: problem }, 400);
  await verifyIdentity(body.identity, verifyOptions(env));

  const playerID = body.identity.gamePlayerID;
  const now = new Date().toISOString();
  const finished = body.goal > 0 && body.count >= body.goal ? 1 : 0;
  await env.DB.batch([
    upsertPlayer(env, playerID, displayName(body.identity), now),
    env.DB.prepare(
      `INSERT INTO weekly_results (week, player_id, count, goal, finished, first_at, updated_at)
       VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?6)
       ON CONFLICT(week, player_id) DO UPDATE SET
         count = MAX(weekly_results.count, excluded.count),
         goal = excluded.goal,
         finished = MAX(weekly_results.finished, excluded.finished),
         -- Only moved when the count moved, so the tie-break stays "who got here first".
         updated_at = CASE WHEN excluded.count > weekly_results.count
                           THEN excluded.updated_at ELSE weekly_results.updated_at END`,
    ).bind(body.week, playerID, body.count, body.goal, finished, now),
  ]);
  return json(await weeklyStanding(body.week, playerID, env));
}

async function getWeekly(week: string, playerID: string | null, env: Env): Promise<Response> {
  if (!WEEK.test(week)) return json({ error: "bad week" }, 400);
  const top = await env.DB.prepare(
    `SELECT r.player_id AS id, p.name, r.count, r.goal, r.finished
     FROM weekly_results r JOIN players p ON p.id = r.player_id
     WHERE r.week = ?1
     ORDER BY r.count DESC, r.finished DESC, r.updated_at ASC
     LIMIT ${LEADERBOARD_SIZE}`,
  ).bind(week).all<{ id: string; name: string; count: number; goal: number; finished: number }>();
  // SQLite has no booleans: `finished` comes back 0 or 1, and a row forwarded untouched puts
  // a number on the wire where the app reads a flag — which made one finisher on the board
  // enough to blank the whole page. `weeklyStanding` below has always converted; this did
  // not, and an empty board hid it.
  const rows = top.results.map((row) => ({ ...row, finished: row.finished === 1 }));
  const you = playerID ? await weeklyStanding(week, playerID, env) : null;
  return json({ week, top: rows, you });
}

/** One player's rank on a week, by the same ordering the board uses. */
async function weeklyStanding(week: string, playerID: string, env: Env) {
  const mine = await env.DB.prepare(
    `SELECT count, goal, finished, updated_at FROM weekly_results WHERE week = ?1 AND player_id = ?2`,
  ).bind(week, playerID).first<{ count: number; goal: number; finished: number; updated_at: string }>();
  const total = await env.DB.prepare(`SELECT COUNT(*) AS n FROM weekly_results WHERE week = ?1`)
    .bind(week)
    .first<{ n: number }>();
  const played = total?.n ?? 0;
  if (!mine) return { week, played, rank: null, count: 0, goal: 0, finished: false };
  const ahead = await env.DB.prepare(
    `SELECT COUNT(*) AS n FROM weekly_results
     WHERE week = ?1 AND (count > ?2 OR (count = ?2 AND updated_at < ?3))`,
  ).bind(week, mine.count, mine.updated_at).first<{ n: number }>();
  return {
    week,
    played,
    rank: (ahead?.n ?? 0) + 1,
    count: mine.count,
    goal: mine.goal,
    finished: mine.finished === 1,
  };
}

// MARK: - Ranked

interface RankedPost {
  gameID: string;
  /** Every human at the table, by gamePlayerID. Bots are not sent. */
  players: string[];
  /** The winner, from a build that predates sides. */
  winnerID: string;
  /** Everyone on the winning side: one player solo, two in a duo. */
  winnerIDs?: string[];
  identity: Identity;
}

/** The winning side as stored: sorted ids joined with "+", so two phones reporting the
 *  same game write the same string. */
function winnerKey(body: RankedPost): string | null {
  const winners = [...new Set(body.winnerIDs?.length ? body.winnerIDs : [body.winnerID])].sort();
  if (winners.length === 0 || winners.length >= body.players.length) return null;
  if (!winners.every((id) => body.players.includes(id))) return null;
  return winners.join("+");
}

const LONE_REPORT_AGE_MS = 10 * 60 * 1000;

async function postRanked(request: Request, env: Env): Promise<Response> {
  const body = (await request.json()) as RankedPost;
  if (!GAME_ID.test(body.gameID ?? "")) return json({ error: "bad game id" }, 400);
  if (!Array.isArray(body.players) || body.players.length < 2 || body.players.length > 4) return json({ error: "bad players" }, 400);
  const winners = winnerKey(body);
  if (!winners) return json({ error: "winner not at the table" }, 400);
  if (!body.identity?.gamePlayerID || !body.players.includes(body.identity.gamePlayerID)) return json({ error: "reporter not at the table" }, 400);
  await verifyIdentity(body.identity, verifyOptions(env));

  const reporter = body.identity.gamePlayerID;
  const now = new Date().toISOString();
  const players = [...new Set(body.players)].sort();
  await env.DB.batch([
    upsertPlayer(env, reporter, displayName(body.identity), now),
    env.DB.prepare(
      `INSERT OR IGNORE INTO ranked_reports (game_id, reporter_id, players, winner_id, reported_at) VALUES (?1, ?2, ?3, ?4, ?5)`,
    ).bind(body.gameID, reporter, JSON.stringify(players), winners, now),
  ]);
  await settleGame(body.gameID, env);
  return json(await rankOf(reporter, env));
}

// MARK: The house

interface HousePost {
  gameID: string;
  won: boolean;
  identity: Identity;
}

/// A ranked game against the house, reported by one phone and taken on trust: HOUSE_WIN
/// for a win, HOUSE_LOSS for a loss, and only the first HOUSE_GAMES_PER_DAY of a day count.
async function postHouseGame(request: Request, env: Env): Promise<Response> {
  const body = (await request.json()) as HousePost;
  if (!GAME_ID.test(body.gameID ?? "")) return json({ error: "bad game id" }, 400);
  if (typeof body.won !== "boolean") return json({ error: "bad result" }, 400);
  await verifyIdentity(body.identity, verifyOptions(env));

  const playerID = body.identity.gamePlayerID;
  const now = new Date();
  await upsertPlayer(env, playerID, displayName(body.identity), now.toISOString()).run();
  if (!(await houseGameApplied(body.gameID, playerID, env))) {
    await applyHouseGame(body, playerID, now, env);
  }
  return json(await rankOf(playerID, env));
}

/// Checked per player, not per game: both friends in a duo report one game id and each
/// is paid once.
async function houseGameApplied(gameID: string, playerID: string, env: Env): Promise<boolean> {
  const applied = await env.DB.prepare(`SELECT changes FROM ranked_games WHERE game_id = ?1`)
    .bind(gameID).first<{ changes: string }>();
  return !!applied && playerID in (JSON.parse(applied.changes) as Record<string, number>);
}

async function applyHouseGame(body: HousePost, playerID: string, now: Date, env: Env): Promise<void> {
  const stamp = now.toISOString();
  const day = stamp.slice(0, 10);
  await rollover(playerID, env);
  const counted = await houseGamesOn(day, playerID, env);
  const { rating, floor, streak } = await currentRating(playerID, env);
  // Past the day's allowance the game still counts as played but moves nothing.
  const delta = counted >= HOUSE_GAMES_PER_DAY ? 0 : houseChange(body.won);
  const next = apply(delta, rating, floor);
  await env.DB.batch([
    // The run is written back as it was: the house cannot build one or break one.
    upsertRating(env, playerID, next, body.won, stamp, seasonOf(now), streak),
    env.DB.prepare(
      `INSERT INTO house_games (player_id, day, count) VALUES (?1, ?2, 1)
       ON CONFLICT(player_id, day) DO UPDATE SET count = count + 1`,
    ).bind(playerID, day),
    // json_patch rather than IGNORE, so both halves of a duo land in the one row.
    env.DB.prepare(
      `INSERT INTO ranked_games (game_id, applied_at, changes) VALUES (?1, ?2, ?3)
       ON CONFLICT(game_id) DO UPDATE SET changes = json_patch(changes, ?3)`,
    ).bind(body.gameID, stamp, JSON.stringify({ [playerID]: next.rating - rating })),
  ]);
}

async function houseGamesOn(day: string, playerID: string, env: Env): Promise<number> {
  const row = await env.DB.prepare(`SELECT count FROM house_games WHERE player_id = ?1 AND day = ?2`)
    .bind(playerID, day).first<{ count: number }>();
  return row?.count ?? 0;
}

// MARK: Settling

interface Report {
  reporter_id: string;
  players: string;
  winner_id: string;
  reported_at: string;
}

interface Story {
  count: number;
  players: string[];
  winner: string;
  first: string;
}

/** Applies a game once its reports agree, or once a lone report has stood long enough. */
async function settleGame(gameID: string, env: Env): Promise<void> {
  const done = await env.DB.prepare(`SELECT 1 FROM ranked_games WHERE game_id = ?1`).bind(gameID).first();
  if (done) return;
  const reports = (await env.DB.prepare(`SELECT reporter_id, players, winner_id, reported_at FROM ranked_reports WHERE game_id = ?1`)
    .bind(gameID).all<Report>()).results;
  const story = settledStory(reports);
  if (story) await applyStory(gameID, story, env);
}

/** The agreed result: two matching reports settle it at once, one settles it after
 *  LONE_REPORT_AGE_MS, and a tie settles nothing. */
function settledStory(reports: Report[]): Story | null {
  if (reports.length === 0) return null;
  const stories = new Map<string, Story>();
  for (const r of reports) {
    const key = `${r.players}|${r.winner_id}`;
    const story = stories.get(key) ?? { count: 0, players: JSON.parse(r.players), winner: r.winner_id, first: r.reported_at };
    story.count += 1;
    if (r.reported_at < story.first) story.first = r.reported_at;
    stories.set(key, story);
  }
  const best = [...stories.values()].sort((a, b) => b.count - a.count)[0];
  const stoodAlone = Date.now() - Date.parse(best.first) > LONE_REPORT_AGE_MS;
  if (best.count < 2 && !stoodAlone) return null;
  const contested = [...stories.values()].some((s) => s !== best && s.count >= best.count);
  return contested ? null : best;
}

async function applyStory(gameID: string, story: Story, env: Env): Promise<void> {
  const now = new Date().toISOString();
  const season = seasonOf(new Date());
  // Settle everyone into the current season first, so the game lands on this season's rating.
  for (const id of story.players) await rollover(id, env);
  const ratings = await Promise.all(story.players.map(async (id) => ({ id, ...(await currentRating(id, env)) })));
  // Losers are measured against the winning side's average. Winners collect from every loser, capped.
  const winnerIDs = story.winner.split("+");
  const winnerRatings = ratings.filter((r) => winnerIDs.includes(r.id)).map((r) => r.rating);
  const winnerRating = winnerRatings.length ? Math.round(winnerRatings.reduce((a, b) => a + b, 0) / winnerRatings.length) : 0;
  const changes: Record<string, number> = {};
  const statements = ratings.map((me) => {
    const won = winnerIDs.includes(me.id);
    const others = ratings.filter((r) => r.id !== me.id && winnerIDs.includes(r.id) !== won).map((r) => r.rating);
    const next = apply(change(me.rating, others, won, winnerRating, me.streak), me.rating, me.floor);
    changes[me.id] = next.rating - me.rating;
    return upsertRating(env, me.id, next, won, now, season, streakAfter(won, me.streak));
  });
  statements.push(env.DB.prepare(`INSERT OR IGNORE INTO ranked_games (game_id, applied_at, changes) VALUES (?1, ?2, ?3)`).bind(gameID, now, JSON.stringify(changes)));
  await env.DB.batch(statements);
}

// MARK: Where a player stands

async function rankOf(playerID: string, env: Env) {
  await rollover(playerID, env);
  await settlePending(playerID, env);

  const row = await env.DB.prepare(`SELECT rating, floor, games, wins, streak FROM ratings WHERE player_id = ?1`).bind(playerID)
    .first<{ rating: number; floor: number; games: number; wins: number; streak: number }>();
  const rating = row?.rating ?? 0;
  const streak = row?.streak ?? 0;
  const last = await lastChange(playerID, env);
  const today = new Date().toISOString().slice(0, 10);
  const season = seasonOf(new Date());
  return {
    playerID,
    rating,
    games: row?.games ?? 0,
    wins: row?.wins ?? 0,
    standing: leagueStanding(rating),
    // The run standing now, and what the next win would add for it.
    streak,
    streakBonus: streakBonus(streak),
    lastChange: last.change,
    // Which game the change came from, so a phone can tell this answer from the last one.
    lastGameID: last.gameID,
    house: { playedToday: await houseGamesOn(today, playerID, env), perDay: HOUSE_GAMES_PER_DAY, win: HOUSE_WIN, loss: HOUSE_LOSS },
    season,
    seasonEndsAt: seasonEnd(season),
    finish: await owedFinish(playerID, env),
  };
}

/** A lone report may have come of age since anyone last looked. */
async function settlePending(playerID: string, env: Env): Promise<void> {
  const pending = (await env.DB.prepare(
    `SELECT DISTINCT r.game_id FROM ranked_reports r LEFT JOIN ranked_games g ON g.game_id = r.game_id
     WHERE g.game_id IS NULL AND r.players LIKE ?1`,
  ).bind(`%${playerID}%`).all<{ game_id: string }>()).results;
  for (const p of pending) await settleGame(p.game_id, env);
}

async function lastChange(playerID: string, env: Env): Promise<{ change: number | null; gameID: string | null }> {
  const last = await env.DB.prepare(
    `SELECT game_id, changes FROM ranked_games WHERE changes LIKE ?1 ORDER BY applied_at DESC LIMIT 1`,
  ).bind(`%"${playerID}"%`).first<{ game_id: string; changes: string }>();
  if (!last) return { change: null, gameID: null };
  return { change: (JSON.parse(last.changes) as Record<string, number>)[playerID] ?? null, gameID: last.game_id };
}

/** The most recent unpaid season finish, one at a time however many were missed. */
async function owedFinish(playerID: string, env: Env) {
  const owed = await env.DB.prepare(
    `SELECT season, rating, games, wins FROM season_finishes WHERE player_id = ?1 AND claimed = 0 ORDER BY season DESC LIMIT 1`,
  ).bind(playerID).first<{ season: string; rating: number; games: number; wins: number }>();
  if (!owed) return null;
  return { season: owed.season, rating: owed.rating, games: owed.games, wins: owed.wins, standing: leagueStanding(owed.rating) };
}

/// Moves a player into the current season: the finish is stored and the rating drops to
/// the floor of the league they reached. A row with no season adopts the current one.
async function rollover(playerID: string, env: Env): Promise<void> {
  const row = await env.DB.prepare(`SELECT rating, floor, games, wins, season FROM ratings WHERE player_id = ?1`)
    .bind(playerID).first<{ rating: number; floor: number; games: number; wins: number; season: string | null }>();
  if (!row) return;
  const season = seasonOf(new Date());
  if (row.season === season) return;
  if (!row.season) {
    await env.DB.prepare(`UPDATE ratings SET season = ?2 WHERE player_id = ?1`).bind(playerID, season).run();
    return;
  }
  const next = resetForSeason(row.rating);
  await env.DB.batch([
    env.DB.prepare(
      `INSERT OR IGNORE INTO season_finishes (season, player_id, rating, games, wins, claimed, finished_at)
       VALUES (?1, ?2, ?3, ?4, ?5, 0, ?6)`,
    ).bind(row.season, playerID, row.rating, row.games, row.wins, new Date().toISOString()),
    env.DB.prepare(
      `UPDATE ratings SET rating = ?2, floor = ?3, games = 0, wins = 0, streak = 0, season = ?4 WHERE player_id = ?1`,
    ).bind(playerID, next.rating, next.floor, season),
  ]);
}

/// Marks a finished season as paid, so a second phone cannot pay for it again.
async function claimSeason(request: Request, env: Env): Promise<Response> {
  const body = (await request.json()) as { season: string; identity: Identity };
  if (!SEASON.test(body.season ?? "")) return json({ error: "bad season" }, 400);
  await verifyIdentity(body.identity, verifyOptions(env));
  await env.DB.prepare(`UPDATE season_finishes SET claimed = 1 WHERE player_id = ?1 AND season = ?2`)
    .bind(body.identity.gamePlayerID, body.season).run();
  return json(await rankOf(body.identity.gamePlayerID, env));
}

// MARK: - The account

/// What one player's devices share: the profile blob, and the purse as a ledger. See
/// profile.ts for why the two are kept apart and why the Worker never reads inside either.

interface ProfileRead {
  /** The last ledger row this device has taken in. Missing or 0 reads from the start. */
  since?: number;
  identity: Identity;
}

interface ProfileWrite extends ProfileRead {
  /** The revision the profile being sent was merged from. 0 from a device that has never
   *  seen this account, which lands only if there is nothing there yet. */
  rev: number;
  profile?: unknown;
  ledger?: LedgerPost[];
}

async function readProfile(request: Request, env: Env): Promise<Response> {
  const body = (await request.json()) as ProfileRead;
  if (!body.identity?.gamePlayerID) return json({ error: "no identity" }, 400);
  await verifyIdentity(body.identity, verifyOptions(env));

  const playerID = body.identity.gamePlayerID;
  await upsertPlayer(env, playerID, displayName(body.identity), new Date().toISOString()).run();
  return json(await accountOf(playerID, cursor(body.since), env));
}

async function writeProfile(request: Request, env: Env): Promise<Response> {
  const body = (await request.json()) as ProfileWrite;
  if (!body.identity?.gamePlayerID) return json({ error: "no identity" }, 400);
  if (!Number.isInteger(body.rev) || body.rev < 0) return json({ error: "bad rev" }, 400);
  const problem = invalidProfile(body.profile) ?? invalidLedger(body.ledger);
  if (problem) return json({ error: problem }, 400);
  await verifyIdentity(body.identity, verifyOptions(env));

  const playerID = body.identity.gamePlayerID;
  const now = new Date().toISOString();
  await upsertPlayer(env, playerID, displayName(body.identity), now).run();

  // The ledger goes first and on its own. It cannot conflict, so there is no reason for a
  // refused profile write to hold a player's denari back.
  if (body.ledger?.length) await appendLedger(playerID, body.ledger, now, env);

  if (body.profile != null && !(await storeProfile(playerID, body.rev, body.profile, now, env))) {
    // Another device wrote first. The answer carries everything needed to merge again, so
    // the retry is one more call rather than two.
    return json({ error: "stale", ...(await accountOf(playerID, cursor(body.since), env)) }, 409);
  }
  return json(await accountOf(playerID, cursor(body.since), env));
}

/** The account as a device needs it: the profile, its revision, and whatever the ledger has
 *  gained since this device last read it. */
async function accountOf(playerID: string, since: number, env: Env) {
  const row = await env.DB.prepare(`SELECT rev, profile FROM profiles WHERE player_id = ?1`)
    .bind(playerID).first<{ rev: number; profile: string }>();
  const rows = (await env.DB.prepare(
    `SELECT seq, entry FROM ledger_entries WHERE player_id = ?1 AND seq > ?2 ORDER BY seq LIMIT ${MAX_LEDGER_PAGE}`,
  ).bind(playerID, since).all<{ seq: number; entry: string }>()).results;
  return {
    rev: row?.rev ?? 0,
    profile: row ? JSON.parse(row.profile) : null,
    ledger: rows.map((r) => JSON.parse(r.entry)),
    // Where to read on from, and whether there is more waiting right now.
    since: rows.length ? rows[rows.length - 1].seq : since,
    more: rows.length === MAX_LEDGER_PAGE,
  };
}

/// D1 takes a batch at a time rather than an unbounded one, and a device coming back from
/// a long spell offline has plenty to say.
const LEDGER_CHUNK = 100;

async function appendLedger(playerID: string, entries: LedgerPost[], now: string, env: Env): Promise<void> {
  for (let at = 0; at < entries.length; at += LEDGER_CHUNK) {
    await env.DB.batch(
      entries.slice(at, at + LEDGER_CHUNK).map((row) =>
        env.DB.prepare(
          `INSERT OR IGNORE INTO ledger_entries (player_id, key, entry, added_at) VALUES (?1, ?2, ?3, ?4)`,
        ).bind(playerID, row.key, JSON.stringify(row.entry), now),
      ),
    );
  }
}

/** Stores the profile if the revision it was built from is still the current one, and says
 *  whether it landed. False means another device wrote in the meantime. */
async function storeProfile(playerID: string, rev: number, profile: unknown, now: string, env: Env): Promise<boolean> {
  const blob = JSON.stringify(profile);
  // A stored profile is always at rev 1 or above, so rev 0 can only mean "I have never seen
  // this account" — and it lands only if that is still true.
  const written = rev === 0
    ? await env.DB.prepare(
        `INSERT INTO profiles (player_id, rev, profile, updated_at) VALUES (?1, 1, ?2, ?3)
         ON CONFLICT(player_id) DO NOTHING`,
      ).bind(playerID, blob, now).run()
    : await env.DB.prepare(
        `UPDATE profiles SET rev = rev + 1, profile = ?2, updated_at = ?3 WHERE player_id = ?1 AND rev = ?4`,
      ).bind(playerID, blob, now, rev).run();
  return (written.meta.changes ?? 0) > 0;
}
