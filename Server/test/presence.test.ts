import { test } from "node:test";
import assert from "node:assert/strict";
import { fingerprint, friendSet, invalidFriends, MAX_FRIENDS } from "../src/presence.ts";

test("a friend list is a list of ids, and not a long one", () => {
  assert.equal(invalidFriends(["A:1", "A:2"]), null);
  assert.equal(invalidFriends([]), null);
  assert.equal(invalidFriends(undefined), "bad friends");
  assert.equal(invalidFriends("A:1"), "bad friends");
  assert.equal(invalidFriends([""]), "bad friend id");
  assert.equal(invalidFriends([7]), "bad friend id");
  assert.equal(invalidFriends(["x".repeat(101)]), "bad friend id");
  assert.equal(invalidFriends(Array.from({ length: MAX_FRIENDS + 1 }, (_, i) => `A:${i}`)), "too many friends");
});

test("the list is a set, in order, without the player in it", () => {
  assert.deepEqual(friendSet(["B", "A", "B", "me"], "me"), ["A", "B"]);
});

test("the same friends in any order are the same fingerprint", async () => {
  const one = await fingerprint(friendSet(["B", "A"], "me"));
  const two = await fingerprint(friendSet(["A", "B", "A"], "me"));
  assert.equal(one, two);
  assert.notEqual(one, await fingerprint(friendSet(["A"], "me")));
});
