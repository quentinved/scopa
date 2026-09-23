import { test } from "node:test";
import assert from "node:assert/strict";
import { cursor, invalidLedger, invalidProfile, MAX_ENTRY_BYTES, MAX_LEDGER_BATCH, MAX_PROFILE_BYTES } from "../src/profile.ts";

test("a profile is an object or nothing at all", () => {
  assert.equal(invalidProfile({ settings: {} }), null);
  // Nothing to store is a read, not a bad write.
  assert.equal(invalidProfile(undefined), null);
  assert.equal(invalidProfile(null), null);
  assert.equal(invalidProfile([1, 2]), "bad profile");
  assert.equal(invalidProfile("wine"), "bad profile");
  assert.equal(invalidProfile(7), "bad profile");
});

test("a profile past the cap is refused rather than stored", () => {
  const big = { note: "x".repeat(MAX_PROFILE_BYTES) };
  assert.equal(invalidProfile(big), "profile too large");
});

test("every ledger entry has to name itself", () => {
  assert.equal(invalidLedger([{ key: "buy/felt.wine", entry: { amount: -40 } }]), null);
  assert.equal(invalidLedger([]), null);
  assert.equal(invalidLedger(undefined), null);
  assert.equal(invalidLedger([{ key: "", entry: {} }]), "bad entry key");
  assert.equal(invalidLedger([{ entry: {} }]), "bad entry key");
  assert.equal(invalidLedger([{ key: "k" }]), "bad entry");
  assert.equal(invalidLedger("nope"), "bad ledger");
});

test("a batch and an entry both have a ceiling", () => {
  const one = { key: "k", entry: {} };
  assert.equal(invalidLedger(Array.from({ length: MAX_LEDGER_BATCH }, () => one)), null);
  assert.equal(invalidLedger(Array.from({ length: MAX_LEDGER_BATCH + 1 }, () => one)), "too many entries");
  assert.equal(invalidLedger([{ key: "k", entry: { note: "x".repeat(MAX_ENTRY_BYTES) } }]), "entry too large");
});

test("a cursor that is not a row number starts from the beginning", () => {
  assert.equal(cursor(42), 42);
  assert.equal(cursor(0), 0);
  assert.equal(cursor(undefined), 0);
  assert.equal(cursor(-1), 0);
  assert.equal(cursor("12"), 0);
  assert.equal(cursor(1.5), 0);
});
