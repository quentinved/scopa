// Gran Maestro's board: where each Gran Maestro is placed this season, and its Campioni.
//
// Past Maestro I the ladder counts points with no top (see ranking.ts), so its last tier is a
// place rather than a rung. Gran Maestri are ordered as the season's board orders everyone:
// rating, then wins, then whoever got there first. They are always the top of that board, so a
// Gran Maestro's place there is the same number as their place among Gran Maestri.

import { GRAND_FLOOR, isCampione, standing } from "./ranking.ts";

/** Sent by every build that knows Gran Maestro. 1.4 and earlier send nothing and know six
 *  leagues, so they are told the ladder as it was, capped at Maestro I. */
export const LADDER_HEADER = "X-Scopa-Ladder";

export function knowsGrand(request: Request): boolean {
  return Number(request.headers.get(LADDER_HEADER) ?? 0) >= 2;
}

/** Gran Maestro's own board is longer than the season's: it is the whole point of the tier. */
export const GRAND_BOARD_SIZE = 100;

export interface Grand {
  points: number;
  place: number | null;
  campione: boolean;
}

/** A Gran Maestro's points and place, or null below Gran Maestro. */
export function grandOf(rating: number, place: number | null): Grand | null {
  if (rating < GRAND_FLOOR) return null;
  const points = rating - GRAND_FLOOR;
  return { points, place, campione: isCampione(place, points) };
}

export interface BoardRow {
  id: string;
  name: string;
  rating: number;
  games: number;
  wins: number;
}

/** A board row as a build that knows Gran Maestro reads it: the standing past Maestro I, and
 *  for a Gran Maestro its place and whether that place is a Campione's. */
export function grandRow(row: BoardRow, place: number | null) {
  const grand = grandOf(row.rating, place);
  return { ...row, standing: standing(row.rating, true), ...(grand ? { place: grand.place, campione: grand.campione } : {}) };
}

interface Mine {
  rating: number;
  wins: number;
  games: number;
  season: string | null;
  updated_at: string;
}

async function mine(db: D1Database, playerID: string): Promise<Mine | null> {
  return db.prepare(`SELECT rating, wins, games, season, updated_at FROM ratings WHERE player_id = ?1`)
    .bind(playerID).first<Mine>();
}

/** One player's place among this season's Gran Maestri, by the board's own order. Null for
 *  anyone below Gran Maestro, and for a Gran Maestro who has not played this season yet. */
async function placeOf(db: D1Database, season: string, row: Mine | null): Promise<number | null> {
  if (!row || row.season !== season || row.games === 0 || row.rating < GRAND_FLOOR) return null;
  // Everyone ahead on rating is a Gran Maestro too, so this counts Gran Maestri only.
  const ahead = await db.prepare(
    `SELECT COUNT(*) AS n FROM ratings
     WHERE season = ?1 AND games > 0 AND (rating > ?2 OR (rating = ?2 AND wins > ?3)
        OR (rating = ?2 AND wins = ?3 AND updated_at < ?4))`,
  ).bind(season, row.rating, row.wins, row.updated_at).first<{ n: number }>();
  return (ahead?.n ?? 0) + 1;
}

/** Where a player stands in Gran Maestro now, for the rank answer. Null below it. */
export async function liveGrand(db: D1Database, season: string, playerID: string, rating: number): Promise<Grand | null> {
  if (rating < GRAND_FLOOR) return null;
  return grandOf(rating, await placeOf(db, season, await mine(db, playerID)));
}

/** Where a finished season left a Gran Maestro. Rollover is lazy, so that season's board is
 *  the finishes stored so far and the rows nobody has rolled over yet. A finish does not keep
 *  when its last game was, so a dead heat on rating and wins shares the place. */
export async function finishedGrand(db: D1Database, playerID: string,
                                    owed: { season: string; rating: number; games: number; wins: number }): Promise<Grand | null> {
  if (owed.rating < GRAND_FLOOR) return null;
  if (owed.games === 0) return grandOf(owed.rating, null);
  const ahead = await db.prepare(
    `SELECT COUNT(*) AS n FROM (
       SELECT player_id, rating, wins FROM season_finishes WHERE season = ?1 AND games > 0
       UNION ALL
       SELECT player_id, rating, wins FROM ratings WHERE season = ?1 AND games > 0
     ) WHERE player_id != ?2 AND (rating > ?3 OR (rating = ?3 AND wins > ?4))`,
  ).bind(owed.season, playerID, owed.rating, owed.wins).first<{ n: number }>();
  return grandOf(owed.rating, (ahead?.n ?? 0) + 1);
}

/** This season's Gran Maestri, best first, each with its place. */
export async function grandBoard(db: D1Database, season: string, playerID: string | null) {
  const top = await db.prepare(
    `SELECT r.player_id AS id, p.name, r.rating, r.games, r.wins
     FROM ratings r JOIN players p ON p.id = r.player_id
     WHERE r.season = ?1 AND r.games > 0 AND r.rating >= ?2
     ORDER BY r.rating DESC, r.wins DESC, r.updated_at ASC
     LIMIT ${GRAND_BOARD_SIZE}`,
  ).bind(season, GRAND_FLOOR).all<BoardRow>();
  const rows = top.results.map((row, index) => grandRow(row, index + 1));
  if (!playerID) return { top: rows, you: null };
  const total = await db.prepare(`SELECT COUNT(*) AS n FROM ratings WHERE season = ?1 AND games > 0 AND rating >= ?2`)
    .bind(season, GRAND_FLOOR).first<{ n: number }>();
  const rank = await placeOf(db, season, await mine(db, playerID));
  return { top: rows, you: { season, played: total?.n ?? 0, rank } };
}

/** The places of the Gran Maestri among these ids, for a board not ordered like theirs. */
export async function grandPlaces(db: D1Database, season: string, ids: string[]): Promise<Map<string, number>> {
  const placed = await db.prepare(
    `SELECT id, place FROM (
       SELECT player_id AS id, ROW_NUMBER() OVER (ORDER BY rating DESC, wins DESC, updated_at ASC) AS place
       FROM ratings WHERE season = ?1 AND games > 0 AND rating >= ?2
     ) WHERE id IN (SELECT value FROM json_each(?3))`,
  ).bind(season, GRAND_FLOOR, JSON.stringify(ids)).all<{ id: string; place: number }>();
  return new Map(placed.results.map((row) => [row.id, row.place]));
}
