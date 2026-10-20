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

// The album travels inside the profile as card codes: the first volume's bare ("7d"), every
// later one's behind its name ("maiolica/7d"), Oro's as "oro/7d" and Perla's as "perla/7d".
// Each new volume is forty more codes, which the Worker never reads, so all it has to do is
// still fit.
const CARDS = ["d", "c", "s", "b"].flatMap((suit) => Array.from({ length: 10 }, (_, rank) => `${rank + 1}${suit}`));
const VOLUMES = ["", "napoli/", "pergamena/", "notturna/", "maiolica/", "mosaico/", "carnevale/", "intarsio/", "merletto/",
  "tarocchi/", "oro/", "perla/"];

test("every volume full of spares, Oro and Perla too, fits a profile many times over", () => {
  const album = Object.fromEntries(VOLUMES.flatMap((volume) => CARDS.map((card) => [`${volume}${card}`, 99])));
  const paidSuits = VOLUMES.flatMap((volume) => ["coins", "cups", "swords", "clubs", "deck"].map((suit) => `${volume}${suit}`));
  const profile = { album, paidSuits, paidDeck: true };
  assert.equal(invalidProfile(profile), null);
  // Seven times over: Perla's forty codes took the full album past an eighth of the limit.
  assert.ok(JSON.stringify(profile).length * 7 < MAX_PROFILE_BYTES);
});

test("the later volumes' ledger keys name themselves like the others'", () => {
  const keys = [
    "album/maiolica/song.faenza",
    "album/maiolica/deck.maiolica",
    "album/mosaico/cornice.tessere",
    "album/mosaico/deck.mosaico",
    "album/carnevale/reactions.maschere",
    "album/carnevale/skin.veneziana",
    "album/intarsio/tapis.cubi",
    "album/intarsio/deck.intarsio",
    "album/merletto/livery.trina",
    "album/merletto/deck.merletto",
    "album/merletto/skin.buranella",
    "album/tarocchi/deck.tarocchi",
    "album/tarocchi/skin.milanese",
    "album/out/mosaico/7d/gift/2026-10-17/6f1c2a8e-0000-4000-8000-000000000002",
    "album/out/maiolica/10b/gift/2026-10-16/6f1c2a8e-0000-4000-8000-000000000001",
  ];
  assert.equal(invalidLedger(keys.map((key) => ({ key, entry: { amount: 0 } }))), null);
});
