/// The ranked queue: whoever is searching for a ranked game alone, paired the moment a second
/// player arrives, and seated together at a room on this Worker.
///
/// Game Center's matchmaker was the only way two strangers met before. It cannot be watched,
/// it splits players by build (TestFlight, App Store and Xcode never meet), and two phones
/// that tapped seconds apart often missed each other. Here every search is one line, so two
/// people searching at the same time always meet, whatever their league, format or build.

export type Format = "1v1" | "2v2";
export const FORMATS: readonly Format[] = ["1v1", "2v2"];

/// The app asks about every 1.5 s. A phone that stops asking is gone after this.
export const STALE_MS = 8_000;
/// A pairing is kept this long so a late poll still learns where to sit.
export const PAIRED_MS = 30_000;
const MAX_ID_LENGTH = 100;

export interface Pairing {
  code: string;
  /// The player id that deals. The one who waited longer.
  host: string;
  /// The host's format, which both phones play.
  format: Format;
  opponent: string;
}

type State = "waiting" | "pending" | "paired";

export interface Seeker {
  player: string;
  /// One id per search on the phone, so a new search starts fresh.
  search: string;
  name: string;
  format: Format;
  since: number;
  seen: number;
  state: State;
  partner?: string;
  pairing?: Pairing;
  pairedAt?: number;
  delivered?: boolean;
}

export interface SeekAnswer {
  /// Other players waiting right now, any format.
  searching: number;
  pairing?: Pairing;
}

export interface Match {
  host: Seeker;
  guest: Seeker;
}

/// The queue itself, with no I/O, so it can be tested on its own.
export class Line {
  private seekers = new Map<string, Seeker>();

  /// Records a poll, and answers with the pairing once its room is open.
  seek(player: string, name: string, format: Format, now: number, search = ""): SeekAnswer {
    this.prune(now);
    if (this.seekers.get(player)?.search !== search) this.leave(player);
    const known = this.seekers.get(player);
    if (known) {
      known.seen = now;
      if (known.state === "waiting") {
        known.format = format;
        known.name = name;
      }
    } else {
      this.seekers.set(player, { player, search, name, format, since: now, seen: now, state: "waiting" });
    }
    const me = this.seekers.get(player)!;
    if (me.state === "paired") me.delivered = true;
    return { searching: this.waitingBesides(player), pairing: me.state === "paired" ? me.pairing : undefined };
  }

  /// Reserves a partner for a waiting player: same format first, then anyone, oldest first.
  match(player: string): Match | null {
    const me = this.seekers.get(player);
    if (!me || me.state !== "waiting") return null;
    const others = [...this.seekers.values()]
      .filter((other) => other.player !== player && other.state === "waiting")
      .sort((a, b) => Number(b.format === me.format) - Number(a.format === me.format) || a.since - b.since);
    const partner = others[0];
    if (!partner) return null;
    const [host, guest] = partner.since <= me.since ? [partner, me] : [me, partner];
    for (const seeker of [host, guest]) seeker.state = "pending";
    host.partner = guest.player;
    guest.partner = host.player;
    return { host, guest };
  }

  /// The room is open: both players are told where to sit on their next poll. False when
  /// one of them left while it was opening, which puts the other back in the line.
  settle(match: Match, code: string, now: number): boolean {
    const { host, guest } = match;
    const reserved = (seeker: Seeker, other: Seeker) =>
      this.seekers.get(seeker.player) === seeker && seeker.state === "pending" && seeker.partner === other.player;
    if (!reserved(host, guest) || !reserved(guest, host)) {
      if (reserved(host, guest)) this.release(host);
      if (reserved(guest, host)) this.release(guest);
      return false;
    }
    const format = host.format;
    host.pairing = { code, host: host.player, format, opponent: guest.name };
    guest.pairing = { code, host: host.player, format, opponent: host.name };
    for (const seeker of [host, guest]) {
      seeker.state = "paired";
      seeker.pairedAt = now;
      seeker.delivered = false;
    }
    return true;
  }

  /// The room could not be opened: both go back to waiting.
  unmatch(match: Match): void {
    for (const seeker of [match.host, match.guest]) this.release(seeker);
  }

  /// A player who stopped searching. A partner who has not heard of the pairing yet waits on.
  leave(player: string): void {
    const me = this.seekers.get(player);
    if (!me) return;
    this.seekers.delete(player);
    const partner = me.partner ? this.seekers.get(me.partner) : undefined;
    if (partner && !partner.delivered) this.release(partner);
  }

  size(): number {
    return this.seekers.size;
  }

  private release(seeker: Seeker): void {
    seeker.state = "waiting";
    seeker.partner = undefined;
    seeker.pairing = undefined;
    seeker.pairedAt = undefined;
    seeker.delivered = undefined;
  }

  private waitingBesides(player: string): number {
    let count = 0;
    for (const seeker of this.seekers.values()) if (seeker.player !== player && seeker.state === "waiting") count++;
    return count;
  }

  private prune(now: number): void {
    for (const seeker of [...this.seekers.values()]) {
      const expired = seeker.state === "paired"
        ? now - (seeker.pairedAt ?? now) > PAIRED_MS
        : now - seeker.seen > STALE_MS;
      if (expired) this.leave(seeker.player);
    }
  }
}

export interface SeekBody {
  player?: unknown;
  search?: unknown;
  name?: unknown;
  format?: unknown;
}

export function invalidSeek(body: SeekBody): string | null {
  if (typeof body?.player !== "string" || !body.player.trim() || body.player.length > MAX_ID_LENGTH) return "bad player";
  if (typeof body.name !== "string" || !body.name.trim()) return "no name";
  if (!FORMATS.includes(body.format as Format)) return "bad format";
  if (body.search !== undefined && (typeof body.search !== "string" || body.search.length > MAX_ID_LENGTH)) return "bad search";
  return null;
}
