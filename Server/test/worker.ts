// The Worker's own routes over the real schema, for tests that go end to end: a fresh ladder,
// a call into it, and a Game Center signature made here. See keeprun.test.ts, which grew this.
import { execFileSync } from "node:child_process";
import { createSign, randomBytes } from "node:crypto";
import { mkdtempSync, readFileSync } from "node:fs";
import { register } from "node:module";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { Env } from "../src/index.ts";
import { signedPayload } from "../src/gamecenter.ts";
import { memoryD1 } from "./memory-d1.ts";

// The Durable Objects need the Workers runtime, which node has not got, and nothing here
// opens one: the room gets an empty base class and the queue is left out altogether.
register(`data:text/javascript,${encodeURIComponent(`
  const stubs = {
    "cloudflare:workers": "export class DurableObject {}",
    "./queue.ts": "export class RankedQueue {}",
  };
  export async function resolve(specifier, context, next) {
    if (!(specifier in stubs)) return next(specifier, context);
    return { url: "data:text/javascript," + encodeURIComponent(stubs[specifier]), shortCircuit: true };
  }`)}`);
const { default: worker } = await import("../src/index.ts");

// Signed as Game Center signs, with a certificate made here and fetched in place of Apple's.
const BUNDLE_ID = "com.quentinvedrenne.scopa";
const dir = mkdtempSync(join(tmpdir(), "scopa-worker-"));
execFileSync("openssl", ["req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", join(dir, "key.pem"), "-out", join(dir, "cert.der"),
  "-outform", "DER", "-days", "2", "-subj", "/CN=test", "-sha256"], { stdio: "ignore" });
const privateKey = readFileSync(join(dir, "key.pem"), "utf8");
const certificate = readFileSync(join(dir, "cert.der"));
globalThis.fetch = async () => new Response(certificate);

export function identity(player: string) {
  const timestamp = Date.now();
  const salt = randomBytes(8);
  const signer = createSign("RSA-SHA256");
  signer.update(signedPayload(player, BUNDLE_ID, timestamp, salt));
  return {
    gamePlayerID: player,
    bundleID: BUNDLE_ID,
    publicKeyURL: "https://static.gc.apple.com/public-key/gc-prod-4.cer",
    signature: signer.sign(privateKey).toString("base64"),
    salt: salt.toString("base64"),
    timestamp,
    displayName: player.slice(2),
  };
}

export function ladder(): Env {
  return { DB: memoryD1("schema.sql"), BUNDLE_ID, MAX_SIGNATURE_AGE_SECONDS: "3600" } as Env;
}

/** A GET, or a POST with a body, optionally carrying request headers. */
export function call(env: Env, path: string, body?: unknown, headers: Record<string, string> = {}): Promise<Response> {
  const init = body === undefined ? { headers } : { method: "POST", body: JSON.stringify(body), headers };
  return worker.fetch(new Request(`https://ladder.test${path}`, init), env);
}
