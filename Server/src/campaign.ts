// The campaign's board: how far each player's road has reached and the stars won on it, and
// who is sitting at each table of the map right now.
//
// Taken on trust like the weekly challenge: the post is signed, so it is only ever about the
// player who sent it, but the stars are what the app says. Both numbers only climb, so a
// second phone or a reinstall cannot walk a player backwards.
//
// A player's face is drawn by the app from three cosmetic ids it already knows: the seat
// mark, the livery and the cornice. The Worker checks their shape and never their meaning.

import { invalidFriends } from "./presence.ts";

/** Thirty tables, three stars each. Mirrors Campaign.swift. */
export const STAGES = 30;
export const MAX_STARS = STAGES * 3;
/** Faces sent per table; the map shows these and a count of the rest. */
export const FACES_PER_STAGE = 3;
export const BOARD_SIZE = 50;

/** "medalGold", "iride", "onde": a raw value of one of the app's cosmetic enums. */
const COSMETIC = /^[A-Za-z0-9]{1,32}$/;

export interface Progress {
  stage: number;
  stars: number;
  mark: string | null;
  livery: string | null;
  cornice: string | null;
}

export interface Player {
  id: string;
  name: string;
}

export interface BoardRow extends Progress {
  id: string;
  name: string;
}

export interface Face {
  id: string;
  name: string;
  mark: string | null;
  livery: string | null;
  cornice: string | null;
  friend: boolean;
}

export interface StageFaces {
  stage: number;
  /** Everyone at this table but the reader, which can be more than `faces` holds. */
  count: number;
  faces: Face[];
}

export interface Place {
  played: number;
  rank: number | null;
  percentile: number | null;
}

type Fields = Record<string, unknown>;

function isCosmetic(value: unknown): boolean {
  return value == null || (typeof value === "string" && COSMETIC.test(value));
}

/** Why a progress post is refused, or null when its shape is sound. */
export function invalidProgress(body: unknown): string | null {
  if (body == null || typeof body !== "object") return "bad body";
  const { stage, stars, mark, livery, cornice } = body as Fields;
  if (!Number.isInteger(stage) || (stage as number) < 1 || (stage as number) > STAGES) return "bad stage";
  if (!Number.isInteger(stars) || (stars as number) < 0 || (stars as number) > MAX_STARS) return "bad stars";
  // Stars are won at tables already reached, three at most each.
  if ((stars as number) > (stage as number) * 3) return "more stars than tables";
  if (![mark, livery, cornice].every(isCosmetic)) return "bad look";
  return null;
}

/** The fields kept from a post that passed `invalidProgress`. */
export function progressOf(body: unknown): Progress {
  const fields = body as Fields;
  const text = (value: unknown) => (typeof value === "string" ? value : null);
  return { stage: fields.stage as number, stars: fields.stars as number, mark: text(fields.mark),
    livery: text(fields.livery), cornice: text(fields.cornice) };
}

/** Why a board or faces request is refused: a friend list, and a player id if any. */
export function invalidLookup(body: unknown, friendsRequired: boolean): string | null {
  if (body == null || typeof body !== "object") return "bad body";
  const { player, friends } = body as Fields;
  if (friends !== undefined || friendsRequired) {
    const problem = invalidFriends(friends);
    if (problem) return problem;
  }
  if (player != null && invalidFriends([player])) return "bad player";
  return null;
}

// MARK: Writing

/** Stores a player's progress, climbing only, and answers with their place. The player row
 *  itself is the caller's to write. */
export async function recordProgress(db: D1Database, playerID: string, progress: Progress, now = new Date()): Promise<Place> {
  await db.prepare(
    `INSERT INTO campaign_progress (player_id, stage, stars, mark, livery, cornice, updated_at)
     VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
     ON CONFLICT(player_id) DO UPDATE SET
       stage = MAX(campaign_progress.stage, excluded.stage),
       stars = MAX(campaign_progress.stars, excluded.stars),
       mark = excluded.mark, livery = excluded.livery, cornice = excluded.cornice,
       -- Moved only when the road moved, so a tie goes to whoever got there first.
       updated_at = CASE WHEN excluded.stage > campaign_progress.stage OR excluded.stars > campaign_progress.stars
                         THEN excluded.updated_at ELSE campaign_progress.updated_at END`,
  ).bind(playerID, progress.stage, progress.stars, progress.mark, progress.livery, progress.cornice, now.toISOString()).run();
  return placeOf(db, playerID);
}

// MARK: The board

const ROW = `c.player_id AS id, p.name, c.stage, c.stars, c.mark, c.livery, c.cornice`;
const ORDER = `c.stars DESC, c.stage DESC, c.updated_at ASC`;

/** The top of the board, most stars first and the furthest road breaking a tie. */
export async function campaignBoard(db: D1Database, playerID: string | null): Promise<{ top: BoardRow[]; you: Place | null }> {
  const top = await db.prepare(
    `SELECT ${ROW} FROM campaign_progress c JOIN players p ON p.id = c.player_id ORDER BY ${ORDER} LIMIT ${BOARD_SIZE}`,
  ).all<BoardRow>();
  return { top: top.results, you: playerID ? await placeOf(db, playerID) : null };
}

/** The board among one player's friends, with the player on it too. */
export async function friendsCampaignBoard(db: D1Database, playerID: string | null, friends: string[]): Promise<{ top: BoardRow[]; you: Place | null }> {
  const ids = [...new Set([...friends, ...(playerID ? [playerID] : [])])];
  const top = await db.prepare(
    `SELECT ${ROW} FROM campaign_progress c JOIN players p ON p.id = c.player_id
     WHERE c.player_id IN (SELECT value FROM json_each(?1)) ORDER BY ${ORDER}`,
  ).bind(JSON.stringify(ids)).all<BoardRow>();
  const at = top.results.findIndex((row) => row.id === playerID);
  const you = playerID ? { played: top.results.length, rank: at >= 0 ? at + 1 : null, percentile: null } : null;
  return { top: top.results, you };
}

/** One player's place on the whole board, by the board's own ordering. */
export async function placeOf(db: D1Database, playerID: string): Promise<Place> {
  const total = await db.prepare(`SELECT COUNT(*) AS n FROM campaign_progress`).first<{ n: number }>();
  const played = total?.n ?? 0;
  const mine = await db.prepare(`SELECT stage, stars, updated_at FROM campaign_progress WHERE player_id = ?1`)
    .bind(playerID).first<{ stage: number; stars: number; updated_at: string }>();
  if (!mine) return { played, rank: null, percentile: null };
  const ahead = await db.prepare(
    `SELECT COUNT(*) AS n FROM campaign_progress
     WHERE stars > ?1 OR (stars = ?1 AND stage > ?2) OR (stars = ?1 AND stage = ?2 AND updated_at < ?3)`,
  ).bind(mine.stars, mine.stage, mine.updated_at).first<{ n: number }>();
  const rank = (ahead?.n ?? 0) + 1;
  return { played, rank, percentile: Math.round(((played - rank) / Math.max(played - 1, 1)) * 100) };
}

// MARK: Faces on the map

const FACE = `c.stage, c.player_id AS id, p.name, c.mark, c.livery, c.cornice`;

type FaceRow = Omit<Face, "friend"> & { stage: number };

/** Who sits at each table, the reader left out: friends first, then the latest to arrive.
 *  Only tables with somebody at them are listed. */
export async function stageFaces(db: D1Database, playerID: string | null, friends: string[]): Promise<StageFaces[]> {
  const known = [...new Set(friends)].filter((id) => id !== playerID);
  const counts = await db.prepare(
    `SELECT stage, COUNT(*) AS n FROM campaign_progress WHERE player_id != ?1 GROUP BY stage ORDER BY stage`,
  ).bind(playerID ?? "").all<{ stage: number; n: number }>();
  const ours = await db.prepare(
    `SELECT ${FACE} FROM campaign_progress c JOIN players p ON p.id = c.player_id
     WHERE c.player_id IN (SELECT value FROM json_each(?1)) ORDER BY c.updated_at DESC`,
  ).bind(JSON.stringify(known)).all<FaceRow>();
  const others = await db.prepare(
    `SELECT stage, id, name, mark, livery, cornice FROM (
       SELECT ${FACE}, ROW_NUMBER() OVER (PARTITION BY c.stage ORDER BY c.updated_at DESC) AS place
       FROM campaign_progress c JOIN players p ON p.id = c.player_id
       WHERE c.player_id NOT IN (SELECT value FROM json_each(?1))
     ) WHERE place <= ?2`,
  ).bind(JSON.stringify([...known, ...(playerID ? [playerID] : [])]), FACES_PER_STAGE).all<FaceRow>();
  return counts.results.map(({ stage, n }) => ({
    stage,
    count: n,
    faces: [...faces(ours.results, stage, true), ...faces(others.results, stage, false)].slice(0, FACES_PER_STAGE),
  }));
}

function faces(rows: FaceRow[], stage: number, friend: boolean): Face[] {
  return rows.filter((row) => row.stage === stage)
    .map(({ id, name, mark, livery, cornice }) => ({ id, name, mark, livery, cornice, friend }));
}
