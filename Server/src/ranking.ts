// The league maths, mirrored from Ranking.swift in ScopaCore. Change one, change both.

export const POINTS_PER_DIVISION = 100;
export const DIVISIONS_PER_LEAGUE = 3;
export const LEAGUES = ["Bronze", "Silver", "Gold", "Platinum", "Diamond", "Maestro"] as const;
export const TOP = LEAGUES.length * DIVISIONS_PER_LEAGUE * POINTS_PER_DIVISION - 1;

export interface Standing {
  league: number;
  division: number;
  progress: number;
  step: number;
  title: string;
}

export function standing(rating: number): Standing {
  const clamped = Math.min(Math.max(rating, 0), TOP);
  const step = Math.floor(clamped / POINTS_PER_DIVISION);
  const league = Math.min(Math.floor(step / DIVISIONS_PER_LEAGUE), LEAGUES.length - 1);
  const division = DIVISIONS_PER_LEAGUE - (step % DIVISIONS_PER_LEAGUE);
  return { league, division, progress: clamped % POINTS_PER_DIVISION, step, title: `${LEAGUES[league]} ${["I", "II", "III"][division - 1]}` };
}

export function floorOf(league: number): number {
  return league * DIVISIONS_PER_LEAGUE * POINTS_PER_DIVISION;
}

/// An even table pays 20, which sets the pace of the whole ladder: a division is five
/// wins, a league fifteen.
export function points(won: boolean, opponentAbove: number, league: number): number {
  if (won) return opponentAbove >= 1 ? 30 : opponentAbove === 0 ? 20 : opponentAbove === -1 ? 12 : 5;
  const loss = opponentAbove >= 1 ? -5 : opponentAbove === 0 ? -12 : -20;
  return league <= 1 ? Math.trunc(loss / 2) : loss;
}

/// The most one table of any size pays, before the run on top of it.
export const TABLE_CAP = 40;

/// A winner collects from each loser, capped, and the run they are on is paid on top of
/// that cap. `streak` is how many wins in a row stood *before* this game.
export function change(rating: number, others: number[], won: boolean, winner: number | null, streak = 0): number {
  const mine = standing(rating);
  if (won) {
    const gained = others.reduce((sum, r) => sum + points(true, standing(r).step - mine.step, mine.league), 0);
    return Math.min(gained, TABLE_CAP) + streakBonus(streak);
  }
  if (winner == null) return 0;
  return points(false, standing(winner).step - mine.step, mine.league);
}

// MARK: Runs

/// Every win in a row past the first adds this much.
export const STREAK_STEP = 2;
/// Where a run stops paying more, so a long one is a bonus and not a ladder of its own.
export const STREAK_CAP = 10;

/// What a win is worth over the table itself, given the wins already standing in a row
/// behind it. Nothing for the first win of a run, STREAK_CAP from the sixth on.
export function streakBonus(wins: number): number {
  return Math.min(Math.max(wins, 0) * STREAK_STEP, STREAK_CAP);
}

/// The run after one result: a win lengthens it, a loss ends it.
export function streakAfter(won: boolean, streak: number): number {
  return won ? Math.max(streak, 0) + 1 : 0;
}

export function apply(delta: number, rating: number, floor: number): { rating: number; floor: number } {
  const next = Math.min(Math.max(rating + delta, floor), TOP);
  return { rating: next, floor: Math.max(floor, floorOf(standing(next).league)) };
}

// MARK: The house

/// A house win pays in full and a house loss a fifth of it, so an evening alone climbs; the
/// ration below is the brake, not the price. It neither lengthens a run nor ends one — a run
/// is something people take off each other. See Ranking.swift.
export const HOUSE_WIN = 25;
export const HOUSE_LOSS = -5;
/// House games past this many a day pay nothing, which caps the house at +250 a day.
export const HOUSE_GAMES_PER_DAY = 10;

export function houseChange(won: boolean): number {
  return won ? HOUSE_WIN : HOUSE_LOSS;
}

// MARK: Seasons

/// A season is a calendar month in UTC: "2026-09". Both sides derive it from the date,
/// so an offline phone still knows which season a game belongs to.
export function seasonOf(date: Date): string {
  return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, "0")}`;
}

/// The first instant of the following season, when the ladder resets.
export function seasonEnd(season: string): string {
  const [year, month] = season.split("-").map(Number);
  return new Date(Date.UTC(month === 12 ? year + 1 : year, month === 12 ? 0 : month, 1)).toISOString();
}

/// Where a season leaves a player: the bottom of the league they finished in, with that
/// league as the floor. Leagues are kept, divisions are given back.
export function resetForSeason(rating: number): { rating: number; floor: number } {
  const at = floorOf(standing(rating).league);
  return { rating: at, floor: at };
}
