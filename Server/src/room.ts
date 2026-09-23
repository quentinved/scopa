/// A table two friends can meet at, kept here rather than by Game Center, which only
/// seats people searching in the same instant. A room lives from when the host opens it
/// until everybody has gone, and its four-letter code can be read out loud.
///
/// The relay never looks inside a message: envelopes are opaque strings here, so the
/// rules of Scopa stay in the app.

import { DurableObject } from "cloudflare:workers";

/// No 0/O and no 1/I: a code is read out loud as often as it is typed.
const ALPHABET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";
const CODE_LENGTH = 4;

/// A room is gone after this whether or not anybody said goodbye.
const ROOM_LIFETIME_MS = 12 * 60 * 60 * 1000;
/// An empty room is swept this long after the last person left, so a brief signal drop
/// does not close the table.
const EMPTY_GRACE_MS = 30 * 60 * 1000;
const SWEEP_INTERVAL_MS = 10 * 60 * 1000;

const MAX_SEATS = 4;
const MAX_MESSAGE_BYTES = 64 * 1024;
/// Per socket, averaged over RATE_WINDOW_MS. A turn of Scopa is a handful of messages.
const MAX_MESSAGES_PER_SECOND = 40;
const RATE_WINDOW_MS = 5000;

/// `WebSocket.OPEN`. The constant is not on the global in every runtime version.
const OPEN = 1;

export interface RoomRecord {
  code: string;
  /// The player id of whoever opened it. They deal.
  host: string;
  hostName: string;
  capacity: number;
  openedAt: number;
}

interface Seat {
  id: string;
  name: string;
}

/// What the app sends up: a sealed message for somebody.
interface Outbound {
  /// "all", "host", or "p:<player id>".
  to: string;
  /// One `Envelope`, JSON, as the app encodes it. Never parsed here.
  data: string;
}

export function makeCode(): string {
  const bytes = new Uint8Array(CODE_LENGTH);
  crypto.getRandomValues(bytes);
  let code = "";
  for (const byte of bytes) code += ALPHABET[byte % ALPHABET.length];
  return code;
}

/// Whether a string could be a code at all, so a typo is refused before a Durable
/// Object is woken for it.
export function isCode(value: string): boolean {
  if (value.length !== CODE_LENGTH) return false;
  for (const character of value) if (!ALPHABET.includes(character)) return false;
  return true;
}

/// Forgives spacing, dashes and lower case. A character outside the alphabet is dropped,
/// which makes the code invalid rather than matching a different table.
export function normaliseCode(value: string): string {
  let code = "";
  for (const character of value.toUpperCase()) {
    if (ALPHABET.includes(character)) code += character;
  }
  return code.slice(0, CODE_LENGTH);
}

export class Room extends DurableObject {
  /// Cleared whenever the instance is evicted, which is as long as a rate limit needs.
  private recent = new Map<string, number[]>();
  /// The record never changes once the table is open, so it is read from storage once.
  private cached?: RoomRecord;

  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    switch (url.pathname) {
      case "/open":
        return this.open(await request.json());
      case "/status":
        return this.status();
      case "/socket":
        return this.socket(request, url);
      default:
        return json({ error: "not found" }, 404);
    }
  }

  /// Opens the room once. A code that is already somebody's table is refused with 409
  /// and the Worker tries another.
  private async open(body: unknown): Promise<Response> {
    const wanted = body as Partial<RoomRecord>;
    if (!wanted.code || !wanted.host || !wanted.hostName) return json({ error: "bad room" }, 400);
    const existing = await this.record();
    if (existing) return json({ error: "taken" }, 409);
    const record: RoomRecord = {
      code: wanted.code,
      host: wanted.host,
      hostName: wanted.hostName.slice(0, 40),
      capacity: clamp(wanted.capacity ?? MAX_SEATS, 2, MAX_SEATS),
      openedAt: Date.now(),
    };
    await this.ctx.storage.put("room", record);
    // Empty from this moment, so a room opened and never sat at is swept with the rest.
    await this.ctx.storage.put("emptySince", record.openedAt);
    await this.ctx.storage.setAlarm(Date.now() + SWEEP_INTERVAL_MS);
    return json({ code: record.code });
  }

  /// What the join screen shows before it commits.
  private async status(): Promise<Response> {
    const record = await this.record();
    if (!record) return json({ open: false }, 404);
    const seated = this.seats();
    return json({
      open: true,
      host: record.hostName,
      seated: seated.length,
      capacity: record.capacity,
      players: seated.map((seat) => seat.name),
    });
  }

  private async socket(request: Request, url: URL): Promise<Response> {
    if (request.headers.get("upgrade") !== "websocket") return json({ error: "expected a websocket" }, 426);
    const record = await this.record();
    if (!record) return json({ error: "no such table" }, 404);

    const player = (url.searchParams.get("player") ?? "").slice(0, 100);
    const name = (url.searchParams.get("name") ?? "").slice(0, 40) || "Someone";
    if (!player) return json({ error: "no player" }, 400);

    // A player who is already here is reconnecting. Their old socket is the stale one.
    for (const stale of this.ctx.getWebSockets(player)) stale.close(1000, "replaced");

    const others = this.seats().filter((seat) => seat.id !== player);
    if (others.length + 1 > record.capacity) return json({ error: "table is full" }, 409);

    const pair = new WebSocketPair();
    const [client, server] = [pair[0], pair[1]];
    // Tagged by player id so a directed message can find them, and hibernating, so an
    // empty room costs nothing.
    this.ctx.acceptWebSocket(server, [player]);
    server.serializeAttachment({ id: player, name } satisfies Seat);
    server.send(JSON.stringify({ type: "welcome", you: player, host: record.host, capacity: record.capacity, present: others }));
    this.tell({ type: "joined", player, name }, player);
    await this.ctx.storage.delete("emptySince");
    return new Response(null, { status: 101, webSocket: client });
  }

  async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer): Promise<void> {
    const seat = ws.deserializeAttachment() as Seat | null;
    if (!seat) return;
    if (typeof message !== "string" || message.length > MAX_MESSAGE_BYTES) return;
    if (!this.allow(seat.id)) return;
    const outbound = parseOutbound(message);
    if (!outbound) return;

    const record = await this.record();
    if (!record) return;
    const relay = JSON.stringify({ type: "relay", from: seat.id, data: outbound.data });

    if (outbound.to === "all") {
      for (const other of this.ctx.getWebSockets()) {
        const who = other.deserializeAttachment() as Seat | null;
        if (who && who.id !== seat.id) safeSend(other, relay);
      }
      return;
    }
    const target = outbound.to === "host" ? record.host : outbound.to.replace(/^p:/, "");
    if (target === seat.id) return;
    for (const other of this.ctx.getWebSockets(target)) safeSend(other, relay);
  }

  async webSocketClose(ws: WebSocket): Promise<void> {
    this.departed(ws);
  }

  async webSocketError(ws: WebSocket): Promise<void> {
    this.departed(ws);
  }

  /// Takes down a room nobody has been in for a while, or one that has been up all day.
  async alarm(): Promise<void> {
    const record = await this.record();
    if (!record) return;
    const emptySince = await this.ctx.storage.get<number>("emptySince");
    const stale = Date.now() - record.openedAt > ROOM_LIFETIME_MS;
    const abandoned = emptySince !== undefined && Date.now() - emptySince > EMPTY_GRACE_MS;
    if (stale || abandoned) {
      for (const ws of this.ctx.getWebSockets()) ws.close(1000, "table closed");
      await this.ctx.storage.deleteAll();
      this.cached = undefined;
      return;
    }
    await this.ctx.storage.setAlarm(Date.now() + SWEEP_INTERVAL_MS);
  }

  private departed(ws: WebSocket): void {
    const seat = ws.deserializeAttachment() as Seat | null;
    if (!seat) return;
    const live = this.ctx.getWebSockets().filter((other) => other !== ws && other.readyState === OPEN);
    // A reconnect closes the old socket just after the new one arrived. That is not a departure.
    if (live.some((other) => (other.deserializeAttachment() as Seat | null)?.id === seat.id)) return;
    this.tell({ type: "left", player: seat.id }, seat.id);
    this.recent.delete(seat.id);
    if (live.length === 0) void this.ctx.storage.put("emptySince", Date.now());
  }

  /// Sends a control frame to everybody but `except`.
  private tell(payload: Record<string, unknown>, except?: string): void {
    const text = JSON.stringify(payload);
    for (const ws of this.ctx.getWebSockets()) {
      const seat = ws.deserializeAttachment() as Seat | null;
      if (seat && seat.id !== except) safeSend(ws, text);
    }
  }

  private seats(): Seat[] {
    const seen = new Map<string, Seat>();
    for (const ws of this.ctx.getWebSockets()) {
      const seat = ws.deserializeAttachment() as Seat | null;
      if (seat) seen.set(seat.id, seat);
    }
    return [...seen.values()];
  }

  private async record(): Promise<RoomRecord | undefined> {
    const record = this.cached ?? (await this.ctx.storage.get<RoomRecord>("room"));
    if (!record) return undefined;
    if (Date.now() - record.openedAt > ROOM_LIFETIME_MS) {
      this.cached = undefined;
      return undefined;
    }
    this.cached = record;
    return record;
  }

  private allow(player: string): boolean {
    const now = Date.now();
    const stamps = (this.recent.get(player) ?? []).filter((at) => now - at < RATE_WINDOW_MS);
    if (stamps.length >= (MAX_MESSAGES_PER_SECOND * RATE_WINDOW_MS) / 1000) return false;
    stamps.push(now);
    this.recent.set(player, stamps);
    return true;
  }
}

function parseOutbound(message: string): Outbound | null {
  let outbound: Outbound;
  try {
    outbound = JSON.parse(message) as Outbound;
  } catch {
    return null;
  }
  if (typeof outbound?.data !== "string" || typeof outbound?.to !== "string") return null;
  return outbound;
}

/// Sending on a socket that closed in between throws. One player dropping must not stop
/// the others being told.
function safeSend(ws: WebSocket, text: string): void {
  try {
    ws.send(text);
  } catch {
    // Their close event is already on its way.
  }
}

function clamp(value: number, low: number, high: number): number {
  return Math.min(high, Math.max(low, Math.round(value)));
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}
