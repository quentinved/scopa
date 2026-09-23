// Which of a player's friends have Scopa open right now.
//
// A heartbeat, not a session: the app checks in about once a minute while it is in front,
// and a player counts as here until a little over two beats have gone by without one. No
// socket is held open for it, so a phone left in a drawer costs nothing and simply drops off.
//
// Being seen is mutual and opt-in on both ends. A player is shown to somebody only if their
// own last heartbeat named that somebody as a friend — so an id picked up elsewhere and sent
// here is answered with nothing, and turning the setting off in the app (which stops the
// heartbeat and posts `leave`) takes a player off every list at once.

/** How long a heartbeat keeps a player counted. The app beats every `BEAT_SECONDS`. */
export const WINDOW_SECONDS = 150;
export const BEAT_SECONDS = 60;
/** Game Center friend lists are small. Anything past this is not a friend list. */
export const MAX_FRIENDS = 200;
const MAX_ID_LENGTH = 100;

export function invalidFriends(friends: unknown): string | null {
  if (!Array.isArray(friends)) return "bad friends";
  if (friends.length > MAX_FRIENDS) return "too many friends";
  for (const id of friends) {
    if (typeof id !== "string" || !id || id.length > MAX_ID_LENGTH) return "bad friend id";
  }
  return null;
}

/** The list as a set: no repeats, in a fixed order, and never the player themselves. */
export function friendSet(friends: string[], self: string): string[] {
  return [...new Set(friends)].filter((id) => id !== self).sort();
}

/** A fingerprint of the list, so a heartbeat whose friends have not changed rewrites nothing. */
export async function fingerprint(friends: string[]): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(friends.join("\n")));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}
