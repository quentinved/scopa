// Exercises the verification path end to end without Apple: a certificate and key made
// here, a signature made the way Game Center makes one, checked by the Worker's own code.
// Run with `npm test` (Node 22.6 or later runs TypeScript directly).
import { test } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createSign, createPublicKey } from "node:crypto";
import { verifyIdentity, signedPayload, subjectPublicKeyInfo, IdentityError } from "../src/gamecenter.ts";

const dir = mkdtempSync(join(tmpdir(), "scopa-gc-"));
const keyPath = join(dir, "key.pem");
const certPath = join(dir, "cert.der");
execFileSync("openssl", ["req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", keyPath, "-out", certPath,
  "-outform", "DER", "-days", "2", "-subj", "/CN=test", "-sha256"], { stdio: "ignore" });
const privateKey = readFileSync(keyPath, "utf8");
const certificate = new Uint8Array(readFileSync(certPath));

const bundleID = "com.quentinvedrenne.scopa";
const now = 1_800_000_000_000; // ms
const salt = new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8]);

function sign(playerID: string, timestamp: number): string {
  const signer = createSign("RSA-SHA256");
  signer.update(signedPayload(playerID, bundleID, timestamp, salt));
  return signer.sign(privateKey).toString("base64");
}

function identity(overrides: Partial<Parameters<typeof verifyIdentity>[0]> = {}) {
  return {
    gamePlayerID: "A:_abc123",
    teamPlayerID: "T:_def456",
    bundleID,
    publicKeyURL: "https://static.gc.apple.com/public-key/gc-prod-4.cer",
    signature: sign("T:_def456", now),
    salt: Buffer.from(salt).toString("base64"),
    timestamp: now,
    ...overrides,
  };
}

const options = {
  bundleID,
  maxAgeSeconds: 3600,
  now: () => now + 60_000,
  fetchCertificate: async () => certificate.buffer.slice(certificate.byteOffset, certificate.byteOffset + certificate.byteLength),
};

test("the public key pulled out of the certificate is the certificate's key", () => {
  const spki = subjectPublicKeyInfo(certificate);
  const fromNode = createPublicKey(privateKey).export({ type: "spki", format: "der" });
  assert.deepEqual(Buffer.from(spki), fromNode);
});

test("a signature over the team player id verifies", async () => {
  await verifyIdentity(identity(), options);
});

test("a signature over the game player id verifies too", async () => {
  await verifyIdentity(identity({ signature: sign("A:_abc123", now) }), options);
});

test("a signature for another player is refused", async () => {
  await assert.rejects(verifyIdentity(identity({ signature: sign("T:_someone_else", now) }), options), IdentityError);
});

test("a stale signature is refused", async () => {
  const old = now - 2 * 3600 * 1000;
  await assert.rejects(verifyIdentity(identity({ signature: sign("T:_def456", old), timestamp: old }), options), IdentityError);
});

test("a certificate that is not apple's is refused before fetching", async () => {
  await assert.rejects(
    verifyIdentity(identity({ publicKeyURL: "https://evil.example.com/key.cer" }), options),
    /apple\.com/,
  );
});

test("the wrong bundle id is refused", async () => {
  await assert.rejects(verifyIdentity(identity(), { ...options, bundleID: "com.other.app" }), /bundle/);
});
