// One player's account, kept so their phone and their iPad are the same account.
//
// Two things travel, and they are kept apart because they merge by different rules.
//
// The profile is one opaque JSON blob — preferences, counters, the album — and the Worker
// never looks inside it. Merging it means knowing what a felt is and what a win is worth,
// and that knowledge lives in the app. Writing it here as well would be a second place for
// the economy to be wrong. What the Worker does instead is refuse a write built on a
// revision that is no longer current, which is all the app needs to merge safely: the
// loser pulls what it missed, folds it in, and tries again.
//
// The purse is a ledger of keyed entries, and it needs no revisions at all. Every entry
// names itself, so two devices writing at once is a union. A device reads forward from the
// last `seq` it saw.

/** Refused rather than stored. Generous — this is a card game's preferences, not a document. */
export const MAX_PROFILE_BYTES = 64 * 1024;
/** Entries accepted in one write. A device pushes what it has not pushed yet, so a long
 *  spell offline comes back over several calls rather than in one huge one. */
export const MAX_LEDGER_BATCH = 500;
/** Entries handed back in one read, for the same reason. */
export const MAX_LEDGER_PAGE = 500;
export const MAX_ENTRY_BYTES = 4 * 1024;

export interface StoredProfile {
  rev: number;
  /** The blob as the app wrote it, parsed only so it can be handed straight back. */
  profile: unknown;
}

export interface LedgerRow {
  seq: number;
  key: string;
  entry: string;
}

/** One entry as the app sends it: its dedupe key, and the entry itself, untouched. */
export interface LedgerPost {
  key: string;
  entry: unknown;
}

export function invalidProfile(profile: unknown): string | null {
  if (profile === undefined || profile === null) return null;
  if (typeof profile !== "object" || Array.isArray(profile)) return "bad profile";
  if (JSON.stringify(profile).length > MAX_PROFILE_BYTES) return "profile too large";
  return null;
}

export function invalidLedger(entries: unknown): string | null {
  if (entries === undefined || entries === null) return null;
  if (!Array.isArray(entries)) return "bad ledger";
  if (entries.length > MAX_LEDGER_BATCH) return "too many entries";
  for (const row of entries as LedgerPost[]) {
    if (!row || typeof row.key !== "string" || !row.key || row.key.length > 200) return "bad entry key";
    if (row.entry === undefined) return "bad entry";
    if (JSON.stringify(row.entry).length > MAX_ENTRY_BYTES) return "entry too large";
  }
  return null;
}

/** A cursor as it arrives: anything that is not a whole number starts from the beginning. */
export function cursor(since: unknown): number {
  return Number.isInteger(since) && (since as number) >= 0 ? (since as number) : 0;
}
