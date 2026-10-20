import { test } from "node:test";
import assert from "node:assert/strict";
import { invalidFollow, invalidSeek, Line, PAIRED_MS, STALE_MS } from "../src/rankedline.ts";

function pairUp(line: Line, now: number) {
  line.seek("a", "Ada", "1v1", now);
  line.seek("b", "Bea", "2v2", now + 1000);
  const match = line.match("b");
  assert.ok(match);
  line.settle(match, "ABCD", now + 1000);
  return match;
}

test("two players searching meet, whatever their format", () => {
  const line = new Line();
  assert.equal(line.seek("a", "Ada", "1v1", 0).searching, 0);
  assert.equal(line.match("a"), null);
  assert.equal(line.seek("b", "Bea", "2v2", 1000).searching, 1);
  const match = line.match("b");
  assert.equal(match?.host.player, "a");
  assert.equal(match?.guest.player, "b");
});

test("the one who waited longer deals, in their format", () => {
  const line = new Line();
  pairUp(line, 0);
  const forGuest = line.seek("b", "Bea", "2v2", 2000).pairing;
  const forHost = line.seek("a", "Ada", "1v1", 2000).pairing;
  assert.deepEqual(forGuest, { code: "ABCD", host: "a", format: "1v1", opponent: "Ada" });
  assert.deepEqual(forHost, { code: "ABCD", host: "a", format: "1v1", opponent: "Bea" });
});

test("a pairing is not told before its room is open", () => {
  const line = new Line();
  line.seek("a", "Ada", "1v1", 0);
  line.seek("b", "Bea", "1v1", 0);
  line.match("b");
  assert.equal(line.seek("a", "Ada", "1v1", 500).pairing, undefined);
  assert.equal(line.seek("a", "Ada", "1v1", 500).searching, 0);
});

test("the same format is preferred over a longer wait", () => {
  const line = new Line();
  line.seek("a", "Ada", "2v2", 0);
  line.seek("b", "Bea", "1v1", 100);
  line.seek("c", "Cal", "1v1", 200);
  assert.equal(line.match("c")?.host.player, "b");
});

test("a phone that stops asking drops out", () => {
  const line = new Line();
  line.seek("a", "Ada", "1v1", 0);
  assert.equal(line.seek("b", "Bea", "1v1", STALE_MS + 1).searching, 0);
  assert.equal(line.match("b"), null);
});

test("a room that would not open puts both back in the line", () => {
  const line = new Line();
  line.seek("a", "Ada", "1v1", 0);
  line.seek("b", "Bea", "1v1", 0);
  line.unmatch(line.match("b")!);
  assert.equal(line.seek("a", "Ada", "1v1", 100).searching, 1);
  assert.ok(line.match("a"));
});

test("leaving before the partner hears of it frees the partner", () => {
  const line = new Line();
  pairUp(line, 0);
  line.leave("a");
  const answer = line.seek("b", "Bea", "2v2", 2000);
  assert.equal(answer.pairing, undefined);
  assert.ok(line.seek("c", "Cal", "2v2", 2100) && line.match("c"));
});

test("leaving after the partner was told leaves the partner seated", () => {
  const line = new Line();
  pairUp(line, 0);
  line.seek("b", "Bea", "2v2", 1500);
  line.leave("a");
  assert.equal(line.seek("b", "Bea", "2v2", 2000).pairing?.code, "ABCD");
});

test("a pairing is forgotten after a while", () => {
  const line = new Line();
  pairUp(line, 0);
  line.seek("c", "Cal", "1v1", 1000 + PAIRED_MS + 1);
  assert.equal(line.size(), 1);
});

test("a search is checked before it joins", () => {
  assert.equal(invalidSeek({ player: "gc:1", name: "Ada", format: "1v1" }), null);
  assert.equal(invalidSeek({ player: "", name: "Ada", format: "1v1" }), "bad player");
  assert.equal(invalidSeek({ player: "gc:1", name: " ", format: "1v1" }), "no name");
  assert.equal(invalidSeek({ player: "gc:1", name: "Ada", format: "3v3" }), "bad format");
  assert.equal(invalidSeek({ player: 7, name: "Ada", format: "1v1" }), "bad player");
});

test("leaving while the room opens puts the partner back in the line", () => {
  const line = new Line();
  line.seek("a", "Ada", "1v1", 0);
  line.seek("b", "Bea", "1v1", 0);
  const match = line.match("b")!;
  line.leave("a");
  assert.equal(line.settle(match, "ABCD", 100), false);
  assert.equal(line.seek("b", "Bea", "1v1", 200).pairing, undefined);
  line.seek("c", "Cal", "1v1", 300);
  assert.equal(line.match("c")?.host.player, "b");
});

test("a new search on the same phone never inherits the last one's pairing", () => {
  const line = new Line();
  line.seek("a", "Ada", "1v1", 0, "s1");
  line.seek("b", "Bea", "1v1", 0, "t1");
  line.settle(line.match("b")!, "ABCD", 0);
  assert.equal(line.seek("a", "Ada", "1v1", 1000, "s1").pairing?.code, "ABCD");
  line.seek("b", "Bea", "1v1", 1000, "t1");
  const fresh = line.seek("a", "Ada", "1v1", 2000, "s2");
  assert.equal(fresh.pairing, undefined);
  assert.equal(line.match("a"), null);
});

test("a failed settle never undoes a partner's newer pairing", () => {
  const line = new Line();
  line.seek("a", "Ada", "1v1", 0);
  line.seek("b", "Bea", "1v1", 0);
  const first = line.match("b")!;
  line.leave("a");
  line.seek("c", "Cal", "1v1", 100);
  const second = line.match("c")!;
  assert.ok(line.settle(second, "WXYZ", 200));
  assert.equal(line.settle(first, "ABCD", 300), false);
  assert.equal(line.seek("b", "Bea", "1v1", 400).pairing?.code, "WXYZ");
});

const cal = { player: "c2", name: "Cal" };
const dee = { player: "d2", name: "Dee" };

/// A leader in the line with its teammate following, as both phones of a new pair are.
function seekAsPair(line: Line, leader: string, name: string, teammate: { player: string; name: string }, now: number) {
  line.seek(leader, name, "duo", now, "", teammate);
  line.follow(teammate.player, leader, now);
  return line.seek(leader, name, "duo", now, "", teammate);
}

function pairOfPairs(line: Line, now: number) {
  seekAsPair(line, "a", "Ada", cal, now);
  seekAsPair(line, "b", "Bea", dee, now + 1000);
  const match = line.match("b");
  assert.ok(match);
  assert.ok(line.settle(match, "WXYZ", now + 1000));
  return match;
}

test("a pair only meets a pair, and a solo never meets one", () => {
  const line = new Line();
  seekAsPair(line, "a", "Ada", cal, 0);
  assert.equal(line.seek("s", "Sol", "1v1", 100).searching, 0);
  assert.equal(line.match("s"), null);
  assert.equal(line.match("a"), null);
  assert.equal(seekAsPair(line, "b", "Bea", dee, 200).searching, 1);
  const match = line.match("b");
  assert.equal(match?.host.player, "a");
  assert.equal(match?.guest.player, "b");
  assert.equal(line.seek("t", "Tom", "2v2", 300).searching, 1);
  assert.equal(line.match("t")?.guest.player, "t");
});

test("the pair that waited longer hosts, and each hears the whole other side", () => {
  const line = new Line();
  pairOfPairs(line, 0);
  assert.deepEqual(line.seek("a", "Ada", "duo", 2000, "", cal).pairing,
                   { code: "WXYZ", host: "a", format: "duo", opponent: "Bea", opponents: ["Bea", "Dee"] });
  assert.deepEqual(line.seek("b", "Bea", "duo", 2000, "", dee).pairing,
                   { code: "WXYZ", host: "a", format: "duo", opponent: "Ada", opponents: ["Ada", "Cal"] });
});

test("the teammate follows its leader, and hears the pairing only after the leader has", () => {
  const line = new Line();
  line.seek("a", "Ada", "duo", 0, "", cal);
  assert.deepEqual(line.follow("c2", "a", 100), { searching: 0, inLine: true, pairing: undefined });
  seekAsPair(line, "b", "Bea", dee, 500);
  assert.equal(line.follow("c2", "a", 600).searching, 1);
  line.settle(line.match("b")!, "WXYZ", 1000);
  assert.equal(line.follow("c2", "a", 1100).pairing, undefined);
  const leaders = line.seek("a", "Ada", "duo", 1200, "", cal).pairing;
  assert.deepEqual(line.follow("c2", "a", 1300).pairing, leaders);
  assert.equal(line.follow("d2", "b", 1300).pairing, undefined);
});

test("only the named teammate can follow a leader", () => {
  const line = new Line();
  line.seek("a", "Ada", "duo", 0, "", cal);
  assert.deepEqual(line.follow("x", "a", 100), { searching: 0, inLine: false });
  assert.deepEqual(line.follow("c2", "nobody", 100), { searching: 0, inLine: false });
});

test("a leader who takes the house before hearing of a pairing frees the other pair", () => {
  const line = new Line();
  pairOfPairs(line, 0);
  line.leave("a");
  assert.deepEqual(line.follow("c2", "a", 1500), { searching: 0, inLine: false });
  assert.equal(line.seek("b", "Bea", "duo", 1600, "", dee).pairing, undefined);
  assert.equal(line.follow("d2", "b", 1700).inLine, true);
  seekAsPair(line, "e", "Eve", { player: "f2", name: "Fay" }, 1800);
  assert.equal(line.match("e")?.host.player, "b");
});

test("a pair whose teammate never follows, as on an older app, is never paired", () => {
  const line = new Line();
  line.seek("a", "Ada", "duo", 0, "", cal);
  assert.equal(seekAsPair(line, "b", "Bea", dee, 100).searching, 0);
  assert.equal(line.match("b"), null);
  assert.equal(line.match("a"), null);
  line.follow("c2", "a", 200);
  assert.equal(line.match("a")?.guest.player, "b");
});

test("a leader who stops asking takes the follower's search with them", () => {
  const line = new Line();
  line.seek("a", "Ada", "duo", 0, "", cal);
  assert.equal(line.follow("c2", "a", STALE_MS + 1).inLine, false);
});

test("a duo's search is checked before it joins", () => {
  const duo = { player: "gc:1", name: "Ada", format: "duo" };
  assert.equal(invalidSeek({ ...duo, teammate: "gc:2", teammateName: "Cal" }), null);
  assert.equal(invalidSeek(duo), "bad teammate");
  assert.equal(invalidSeek({ ...duo, teammate: "gc:1", teammateName: "Cal" }), "bad teammate");
  assert.equal(invalidSeek({ ...duo, teammate: "gc:2", teammateName: " " }), "no teammate name");
  assert.equal(invalidFollow({ player: "gc:2", leader: "gc:1" }), null);
  assert.equal(invalidFollow({ player: "gc:2" }), "bad leader");
  assert.equal(invalidFollow({ player: "gc:2", leader: "gc:2" }), "bad leader");
});
