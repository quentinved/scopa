import { test } from "node:test";
import assert from "node:assert/strict";
import { standing, points, change, apply, seasonOf, seasonEnd, resetForSeason, houseChange, streakAfter, streakBonus, HOUSE_WIN, HOUSE_LOSS, HOUSE_GAMES_PER_DAY } from "../src/ranking.ts";

test("a rating reads as a league and a division", () => {
  assert.equal(standing(0).title, "Bronze III");
  assert.equal(standing(250).title, "Bronze I");
  assert.equal(standing(300).title, "Silver III");
  assert.equal(standing(5000).title, "Maestro I");
  assert.equal(standing(420).progress, 20);
});

test("wins pay by who was beaten, matching the Swift side", () => {
  assert.equal(points(true, 2, 2), 30);
  assert.equal(points(true, 0, 2), 20);
  assert.equal(points(true, -3, 2), 5);
  assert.equal(points(false, 0, 2), -12);
  assert.equal(points(false, 0, 0), -6);
  assert.equal(points(false, -1, 3), -20);
});

test("a league reached is a floor", () => {
  const up = apply(20, 290, 0);
  assert.deepEqual(up, { rating: 310, floor: 300 });
  assert.deepEqual(apply(-50, up.rating, up.floor), { rating: 300, floor: 300 });
});

test("a winner collects from every loser, capped", () => {
  assert.equal(change(100, [100, 100, 100], true, null), 40);
  assert.equal(change(100, [400], false, 400), -2);
});

test("five even wins are a division, matching the Swift side", () => {
  let { rating, floor } = { rating: 600, floor: 600 };
  for (let i = 0; i < 5; i++) ({ rating, floor } = apply(change(rating, [rating], true, null), rating, floor));
  assert.equal(rating, 700);
  assert.equal(standing(rating).title, "Gold II");
});

test("a run pays on top of the table, and ends on a loss", () => {
  assert.equal(streakBonus(0), 0);
  assert.equal(streakBonus(1), 2);
  assert.equal(streakBonus(4), 8);
  assert.equal(streakBonus(5), 10);
  assert.equal(streakBonus(40), 10);
  // Paid over the table's own cap, and only to the winner.
  assert.equal(change(100, [100, 100, 100], true, null, 3), 46);
  assert.equal(change(100, [400], false, 400, 3), -2);
  assert.equal(streakAfter(true, 4), 5);
  assert.equal(streakAfter(false, 9), 0);
});

test("a season is a month, and it ends at the top of the next one", () => {
  assert.equal(seasonOf(new Date("2026-09-15T22:10:00Z")), "2026-09");
  assert.equal(seasonOf(new Date("2026-12-31T23:59:59Z")), "2026-12");
  assert.equal(seasonEnd("2026-09"), "2026-10-01T00:00:00.000Z");
  assert.equal(seasonEnd("2026-12"), "2027-01-01T00:00:00.000Z");
});

test("a season gives the divisions back and keeps the league", () => {
  // Gold I with 40 into the division comes back as Gold III, on Gold's floor.
  assert.deepEqual(resetForSeason(840), { rating: 600, floor: 600 });
  assert.equal(standing(resetForSeason(840).rating).title, "Gold III");
  // Bronze has nowhere to fall to.
  assert.deepEqual(resetForSeason(120), { rating: 0, floor: 0 });
});

test("the house pays a win in full and a loss a fifth of it", () => {
  assert.equal(houseChange(true), HOUSE_WIN);
  assert.equal(houseChange(false), HOUSE_LOSS);
  // A win off the house is worth an even table, so playing alone climbs; the ration of
  // HOUSE_GAMES_PER_DAY is what holds it, not the price.
  assert.ok(HOUSE_WIN >= points(true, 0, 2));
  // Losing to it costs far less than losing to a real player of your own league.
  assert.ok(HOUSE_LOSS > points(false, 0, 2));
  // And it cannot take a player below the floor of the league they have reached.
  assert.deepEqual(apply(HOUSE_LOSS, 600, 600), { rating: 600, floor: 600 });
  // A day of the house, won out, is two and a half divisions and no more.
  assert.equal(HOUSE_WIN * HOUSE_GAMES_PER_DAY, 250);
});
