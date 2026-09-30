// Friend codes: a code each friend of the house hands out, worth a gift to whoever enters
// it. A player uses one code in their life, so the count behind a code is how many people
// that friend brought to the table.
//
// A code is a name, typed rather than read down the phone, so it is forgiven the way a name
// is: case, spaces, dashes and accents do not matter, and "Loïc" is LOIC.

export const MAX_CODE_LENGTH = 24;

/** The pack tiers the app knows. Anything else is dropped rather than sent. */
export const PACKS = new Set(["mazzetto", "bottega", "velluto", "reliquia", "scrigno", "forziere"]);

export interface FriendCodeRow {
  code: string;
  owner: string;
  pack: string | null;
  denari: number;
}

/** What the app is told to hand over. */
export interface Gift {
  owner: string;
  pack: string | null;
  denari: number;
}

/** Upper case, accents folded, letters and digits only. Empty when it could not be a code. */
export function normaliseFriendCode(value: unknown): string {
  if (typeof value !== "string") return "";
  const code = value.normalize("NFD").replace(/\p{Mn}/gu, "").toUpperCase().replace(/[^A-Z0-9]/g, "");
  return code.length <= MAX_CODE_LENGTH ? code : "";
}

export function giftOf(row: FriendCodeRow): Gift {
  const pack = row.pack && PACKS.has(row.pack) ? row.pack : null;
  const denari = Number.isInteger(row.denari) && row.denari > 0 ? row.denari : 0;
  return { owner: row.owner, pack, denari };
}
