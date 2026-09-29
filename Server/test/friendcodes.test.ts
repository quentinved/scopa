import { test } from "node:test";
import assert from "node:assert/strict";
import { giftOf, MAX_CODE_LENGTH, normaliseFriendCode } from "../src/friendcodes.ts";

test("a code is forgiven the way a name is", () => {
  assert.equal(normaliseFriendCode("romane"), "ROMANE");
  assert.equal(normaliseFriendCode("  Loïc "), "LOIC");
  assert.equal(normaliseFriendCode("lau-rence"), "LAURENCE");
  assert.equal(normaliseFriendCode("TIM 2"), "TIM2");
});

test("what could not be a code is empty", () => {
  assert.equal(normaliseFriendCode(""), "");
  assert.equal(normaliseFriendCode("!!!"), "");
  assert.equal(normaliseFriendCode(undefined), "");
  assert.equal(normaliseFriendCode(42), "");
  assert.equal(normaliseFriendCode("A".repeat(MAX_CODE_LENGTH + 1)), "");
});

test("a gift carries only what the app knows how to hand over", () => {
  assert.deepEqual(giftOf({ code: "TIM", owner: "Tim", pack: "reliquia", denari: 0 }),
    { owner: "Tim", pack: "reliquia", denari: 0 });
  assert.deepEqual(giftOf({ code: "HUGO", owner: "Hugo", pack: null, denari: 500 }),
    { owner: "Hugo", pack: null, denari: 500 });
  assert.deepEqual(giftOf({ code: "X", owner: "X", pack: "legendary", denari: -5 }),
    { owner: "X", pack: null, denari: 0 });
});
