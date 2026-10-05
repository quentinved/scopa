import { test } from "node:test";
import assert from "node:assert/strict";
import { invalidSeek, Line, PAIRED_MS, STALE_MS } from "../src/rankedline.ts";

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
