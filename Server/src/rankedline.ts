/// The ranked queue: whoever is searching for a ranked game alone, paired the moment a second
/// player arrives, and seated together at a room on this Worker.
///
/// Game Center's matchmaker was the only way two strangers met before. It cannot be watched,
/// it splits players by build (TestFlight, App Store and Xcode never meet), and two phones
/// that tapped seconds apart often missed each other. Here every search is one line, so two
/// people searching at the same time always meet, whatever their league, format or build.
///
/// A duo searches as one: the phone that invited seeks with its teammate named, and the
/// teammate's phone follows that search rather than joining the line. Pairs only meet pairs.

export type Format = "1v1" | "2v2" | "duo";
export const FORMATS: readonly Format[] = ["1v1", "2v2", "duo"];

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
  /// A duo's whole other side: their leader, then their teammate. Absent for a solo pairing.
  opponents?: string[];
}

/// The friend a duo's leader searches with.
export interface Teammate {
  player: string;
  name: string;
}

type State = "waiting" | "pending" | "paired";

export interface Seeker {
  player: string;
  /// One id per search on the phone, so a new search starts fresh.
  search: string;
  name: string;
  format: Format;
  /// Set for a duo, whose second phone follows this search.
  teammate?: Teammate;
  /// The teammate's phone has followed this search. A pair is only paired once it has, so a
  /// teammate on an older app, which never follows, is never stranded at a room.
  followed?: boolean;
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

/// What a duo's second phone hears when it follows its leader's search.
export interface FollowAnswer extends SeekAnswer {
  /// Whether the leader is in the line with this phone as its teammate.
  inLine: boolean;
}

export interface Match {
  host: Seeker;
  guest: Seeker;
}

/// A pair only meets a pair whose teammate is following, a solo only a solo, and nobody meets
/// their own teammate.
function meets(a: Seeker, b: Seeker): boolean {
  if ((a.format === "duo") !== (b.format === "duo")) return false;
  if (a.format === "duo" && !(a.followed && b.followed)) return false;
  const players = (seeker: Seeker) => [seeker.player, seeker.teammate?.player].filter(Boolean);
  return !players(a).some((player) => players(b).includes(player));
}

/// The queue itself, with no I/O, so it can be tested on its own.
export class Line {
  private seekers = new Map<string, Seeker>();

  /// Records a poll, and answers with the pairing once its room is open.
  seek(player: string, name: string, format: Format, now: number, search = "", teammate?: Teammate): SeekAnswer {
    this.prune(now);
    if (this.seekers.get(player)?.search !== search) this.leave(player);
    const known = this.seekers.get(player);
    if (known) {
      known.seen = now;
      if (known.state === "waiting") {
        known.format = format;
        known.name = name;
        if (known.teammate?.player !== teammate?.player) known.followed = undefined;
        known.teammate = teammate;
      }
    } else {
      this.seekers.set(player, { player, search, name, format, teammate, since: now, seen: now, state: "waiting" });
    }
    const me = this.seekers.get(player)!;
    if (me.state === "paired") me.delivered = true;
    return { searching: this.waitingBesides(player), pairing: me.state === "paired" ? me.pairing : undefined };
  }

  /// The teammate's poll: the leader's search, and its pairing once the leader has heard of it,
  /// so a leader who takes the house instead is never followed to a room.
  follow(player: string, leader: string, now: number): FollowAnswer {
    this.prune(now);
    const lead = this.seekers.get(leader);
    if (!lead || lead.teammate?.player !== player) return { searching: 0, inLine: false };
    lead.followed = true;
    const told = lead.state === "paired" && lead.delivered;
    return { searching: this.waitingBesides(leader), inLine: true, pairing: told ? lead.pairing : undefined };
  }

  /// Reserves a partner for a waiting player: same format first, then anyone, oldest first.
  /// A duo is reserved another duo, never a player alone.
  match(player: string): Match | null {
    const me = this.seekers.get(player);
    if (!me || me.state !== "waiting") return null;
    const others = [...this.seekers.values()]
      .filter((other) => other.player !== player && other.state === "waiting" && meets(me, other))
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
    host.pairing = { code, host: host.player, format, opponent: guest.name, ...sideOf(guest) };
    guest.pairing = { code, host: host.player, format, opponent: host.name, ...sideOf(host) };
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

  /// Others waiting who could be paired with this player: pairs for a pair, solos for a solo.
  private waitingBesides(player: string): number {
    const me = this.seekers.get(player);
    let count = 0;
    for (const seeker of this.seekers.values()) {
      if (seeker.player !== player && seeker.state === "waiting" && (!me || meets(me, seeker))) count++;
    }
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

/// The names a duo's leader reads out for the other side.
function sideOf(seeker: Seeker): { opponents?: string[] } {
  return seeker.teammate ? { opponents: [seeker.name, seeker.teammate.name] } : {};
}

export interface SeekBody {
  player?: unknown;
  search?: unknown;
  name?: unknown;
  format?: unknown;
  /// A duo's teammate: their player id and name.
  teammate?: unknown;
  teammateName?: unknown;
}

export interface FollowBody {
  player?: unknown;
  leader?: unknown;
}

function isID(value: unknown): value is string {
  return typeof value === "string" && value.trim() !== "" && value.length <= MAX_ID_LENGTH;
}

export function invalidSeek(body: SeekBody): string | null {
  if (!isID(body?.player)) return "bad player";
  if (typeof body.name !== "string" || !body.name.trim()) return "no name";
  if (!FORMATS.includes(body.format as Format)) return "bad format";
  if (body.search !== undefined && (typeof body.search !== "string" || body.search.length > MAX_ID_LENGTH)) return "bad search";
  if (body.format === "duo") {
    if (!isID(body.teammate) || body.teammate === body.player) return "bad teammate";
    if (typeof body.teammateName !== "string" || !body.teammateName.trim()) return "no teammate name";
  }
  return null;
}

export function invalidFollow(body: FollowBody): string | null {
  if (!isID(body?.player)) return "bad player";
  if (!isID(body.leader) || body.leader === body.player) return "bad leader";
  return null;
}
