// Verifies that a request comes from the Game Center player it claims to.
//
// Apple's certificate is fetched from `publicKeyURL`, the public key pulled out of it,
// and the signature checked over (player id + bundle id + timestamp + salt).

export interface Identity {
  /** Stable across every game from this developer. What the ladder keys on. */
  gamePlayerID: string;
  /** Scoped to the team. Apple signs one of the two, so both are tried. */
  teamPlayerID?: string;
  bundleID: string;
  publicKeyURL: string;
  /** Base64. */
  signature: string;
  /** Base64. */
  salt: string;
  /** Seconds or milliseconds since 1970, as Game Center gave it. */
  timestamp: number;
  displayName?: string;
}

export interface VerifyOptions {
  bundleID: string;
  maxAgeSeconds: number;
  now?: () => number;
  fetchCertificate?: (url: string) => Promise<ArrayBuffer>;
}

export class IdentityError extends Error {}

export async function verifyIdentity(identity: Identity, options: VerifyOptions): Promise<void> {
  if (identity.bundleID !== options.bundleID) throw new IdentityError("wrong bundle id");
  const url = new URL(identity.publicKeyURL);
  if (url.protocol !== "https:" || !url.hostname.endsWith(".apple.com")) {
    throw new IdentityError("certificate must come from apple.com");
  }
  checkAge(identity.timestamp, options);

  const certificate = await (options.fetchCertificate ?? fetchCertificate)(identity.publicKeyURL);
  const key = await importPublicKey(certificate);
  const signature = base64ToBytes(identity.signature);
  const salt = base64ToBytes(identity.salt);
  const candidates = [identity.teamPlayerID, identity.gamePlayerID].filter((id): id is string => !!id);
  for (const playerID of candidates) {
    const payload = signedPayload(playerID, identity.bundleID, identity.timestamp, salt);
    if (await crypto.subtle.verify("RSASSA-PKCS1-v1_5", key, signature, payload)) return;
  }
  throw new IdentityError("signature does not verify");
}

/** Game Center gives the timestamp in milliseconds. Seconds are accepted too. */
function checkAge(timestamp: number, options: VerifyOptions): void {
  const nowSeconds = (options.now ?? (() => Date.now()))() / 1000;
  const timestampSeconds = timestamp > 1e11 ? timestamp / 1000 : timestamp;
  if (Math.abs(nowSeconds - timestampSeconds) > options.maxAgeSeconds) throw new IdentityError("signature too old");
}

function importPublicKey(certificate: ArrayBuffer): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    "spki",
    subjectPublicKeyInfo(new Uint8Array(certificate)),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"],
  );
}

/** player id, bundle id, timestamp as a big-endian 64-bit integer, then the salt. */
export function signedPayload(playerID: string, bundleID: string, timestamp: number, salt: Uint8Array): Uint8Array {
  const encoder = new TextEncoder();
  const player = encoder.encode(playerID);
  const bundle = encoder.encode(bundleID);
  const stamp = new Uint8Array(8);
  new DataView(stamp.buffer).setBigUint64(0, BigInt(Math.trunc(timestamp)), false);
  const out = new Uint8Array(player.length + bundle.length + 8 + salt.length);
  out.set(player, 0);
  out.set(bundle, player.length);
  out.set(stamp, player.length + bundle.length);
  out.set(salt, player.length + bundle.length + 8);
  return out;
}

async function fetchCertificate(url: string): Promise<ArrayBuffer> {
  const response = await fetch(url, { cf: { cacheTtl: 86400, cacheEverything: true } } as RequestInit);
  if (!response.ok) throw new IdentityError("could not fetch certificate");
  return response.arrayBuffer();
}

export function base64ToBytes(text: string): Uint8Array {
  const binary = atob(text.replace(/-/g, "+").replace(/_/g, "/"));
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

// MARK: - Just enough ASN.1 to find the public key in an X.509 certificate
//
//   Certificate ::= SEQUENCE {
//     tbsCertificate SEQUENCE {
//       [0] version OPTIONAL, serialNumber, signature, issuer, validity, subject,
//       subjectPublicKeyInfo, ...
//     }, ...
//   }
// The SPKI element, header included, is what WebCrypto's "spki" import takes.

interface Element {
  tag: number;
  start: number; // where the header starts
  contentStart: number;
  end: number; // one past the content
}

function readElement(bytes: Uint8Array, at: number): Element {
  if (at >= bytes.length) throw new IdentityError("truncated certificate");
  const tag = bytes[at];
  let cursor = at + 1;
  let length = bytes[cursor++];
  if (length & 0x80) {
    const count = length & 0x7f;
    if (count === 0 || count > 4) throw new IdentityError("unsupported length");
    length = 0;
    for (let i = 0; i < count; i++) length = (length << 8) | bytes[cursor++];
  }
  const end = cursor + length;
  if (end > bytes.length) throw new IdentityError("truncated certificate");
  return { tag, start: at, contentStart: cursor, end };
}

function children(bytes: Uint8Array, parent: Element): Element[] {
  const list: Element[] = [];
  let cursor = parent.contentStart;
  while (cursor < parent.end) {
    const child = readElement(bytes, cursor);
    list.push(child);
    cursor = child.end;
  }
  return list;
}

export function subjectPublicKeyInfo(der: Uint8Array): Uint8Array {
  const certificate = readElement(der, 0);
  if (certificate.tag !== 0x30) throw new IdentityError("not a certificate");
  const tbs = children(der, certificate)[0];
  if (!tbs || tbs.tag !== 0x30) throw new IdentityError("not a certificate");
  const fields = children(der, tbs);
  // An explicit version is tagged [0]. Without it the serial number comes first.
  const offset = fields[0]?.tag === 0xa0 ? 1 : 0;
  const spki = fields[offset + 5];
  if (!spki || spki.tag !== 0x30) throw new IdentityError("no public key in certificate");
  return der.slice(spki.start, spki.end);
}
