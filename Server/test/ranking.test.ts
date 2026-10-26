import { test } from "node:test";
import assert from "node:assert/strict";
import { standing, points, change, apply, floorOf, seasonOf, seasonEnd, resetForSeason, houseChange, houseStakes, isCampione, streakAfter, streakBonus, HOUSE_WIN, HOUSE_LOSS, HOUSE_GAMES_PER_DAY, GRAND_FLOOR, GRAND_STEP, GRAND_HOUSE_WIN, GRAND_HOUSE_LOSS } from "../src/ranking.ts";

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
  // A day of the house, won out, is about five divisions and no more, the run included.
  assert.equal(HOUSE_GAMES_PER_DAY, 15);
  let day = 0;
  for (let streak = 0; streak < HOUSE_GAMES_PER_DAY; streak++) day += houseChange(true, streak);
  assert.equal(day, 495);
});

test("a house win pays the run on top, and a house loss ends it", () => {
  assert.equal(houseChange(true, 0), HOUSE_WIN);
  assert.equal(houseChange(true, 3), HOUSE_WIN + streakBonus(3));
  assert.equal(houseChange(false, 5), HOUSE_LOSS);
  assert.equal(streakAfter(false, 5), 0);
});

// MARK: Gran Maestro

test("past Maestro I the points have no top, for a build that knows Gran Maestro", () => {
  assert.equal(standing(GRAND_FLOOR - 1, true).title, "Maestro I");
  const gran = standing(GRAND_FLOOR + 340, true);
  assert.equal(gran.title, "Gran Maestro");
  assert.equal(gran.league, 6);
  assert.equal(gran.progress, 340);
  assert.equal(gran.step, GRAND_STEP);
  assert.equal(standing(GRAND_FLOOR + 12_000, true).progress, 12_000);
});

test("a build from before Gran Maestro still reads Maestro I at the top", () => {
  const old = standing(GRAND_FLOOR + 340);
  assert.equal(old.title, "Maestro I");
  assert.equal(old.league, 5);
  assert.equal(old.progress, 99);
});

test("the ladder climbs into Gran Maestro and keeps it as a floor", () => {
  const next = apply(25, GRAND_FLOOR - 10, floorOf(5));
  assert.equal(next.rating, GRAND_FLOOR + 15);
  assert.equal(next.floor, GRAND_FLOOR);
  assert.equal(apply(-50, next.rating, next.floor).rating, GRAND_FLOOR);
  assert.deepEqual(resetForSeason(GRAND_FLOOR + 900), { rating: GRAND_FLOOR, floor: GRAND_FLOOR });
});

test("Gran Maestro is one step above Maestro I at a table of people", () => {
  assert.equal(change(GRAND_FLOOR - 1, [GRAND_FLOOR + 400], true, null), 30);
  assert.equal(change(GRAND_FLOOR + 400, [GRAND_FLOOR + 10], true, null), 20);
});

test("the house pays less and costs more in Gran Maestro", () => {
  assert.deepEqual(houseStakes(GRAND_FLOOR - 1), { win: HOUSE_WIN, loss: HOUSE_LOSS });
  assert.deepEqual(houseStakes(GRAND_FLOOR), { win: GRAND_HOUSE_WIN, loss: GRAND_HOUSE_LOSS });
  assert.equal(houseChange(true, 3, GRAND_FLOOR), GRAND_HOUSE_WIN + streakBonus(3));
  assert.equal(houseChange(false, 0, GRAND_FLOOR + 80), GRAND_HOUSE_LOSS);
});

test("Campioni are the top ten with three hundred points", () => {
  assert.ok(isCampione(1, 300));
  assert.ok(isCampione(10, 1200));
  assert.ok(!isCampione(11, 1200));
  assert.ok(!isCampione(1, 299));
  assert.ok(!isCampione(null, 900));
});
