#!/bin/sh
# Friend codes on the Worker's D1: how many people used each one, and adding new ones.
#
#   ./Tools/friend-codes.sh                          uses per code, most first
#   ./Tools/friend-codes.sh who ROMANE               who used a code, and when
#   ./Tools/friend-codes.sh add ROMANE Romane        a new code, worth a reliquia pack
#   ./Tools/friend-codes.sh add HUGO Hugo 1000       worth 1000 denari instead
#   ./Tools/friend-codes.sh gift HUGO forziere       change what a code is worth
#
# A gift is a pack tier (mazzetto bottega velluto reliquia scrigno forziere) or a number of
# denari. Codes are the owner's name in capitals: the app folds accents and case, so a
# friend typing "Loïc" reaches LOIC.
#
# Needs wrangler signed in to the Cloudflare account the Worker is on (`npx wrangler@4
# login`), or CLOUDFLARE_API_TOKEN set. Run migrations/008-friend-codes.sql once first.
set -e
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root/Server"

d1() { npx --yes wrangler@4 d1 execute scopa --remote --command "$1"; }

# Single quotes doubled, so a name like O'Neil is text and not SQL.
quote() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/''/g")"; }

code_of() {
    case $1 in
        '' | *[!A-Z0-9]*) echo "A code is capital letters and digits, like ROMANE." >&2; exit 64 ;;
    esac
    printf '%s' "$1"
}

# A gift as the two columns it fills: "'reliquia', 0" for a tier, "NULL, 1000" for denari.
gift_of() {
    case $1 in
        mazzetto | bottega | velluto | reliquia | scrigno | forziere) printf "'%s', 0" "$1" ;;
        '' | 0 | *[!0-9]*) echo "A gift is a pack tier or a number of denari, not '$1'." >&2; exit 64 ;;
        *) printf "NULL, %s" "$1" ;;
    esac
}

case ${1:-list} in
    list)
        d1 "SELECT c.code, c.owner, COALESCE(c.pack, c.denari || ' denari') AS gift,
                   COUNT(u.player_id) AS uses, MAX(u.used_at) AS last_used
            FROM friend_codes c LEFT JOIN friend_code_uses u ON u.code = c.code
            GROUP BY c.code ORDER BY uses DESC, c.owner" ;;
    who)
        code=$(code_of "$2")
        d1 "SELECT player_name, used_at FROM friend_code_uses WHERE code = '$code' ORDER BY used_at" ;;
    add)
        code=$(code_of "$2")
        [ -n "$3" ] || { echo "usage: $0 add CODE Name [gift]" >&2; exit 64; }
        gift=$(gift_of "${4:-reliquia}")
        d1 "INSERT INTO friend_codes (code, owner, pack, denari, created_at)
            VALUES ('$code', $(quote "$3"), $gift, strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))" ;;
    gift)
        code=$(code_of "$2")
        gift=$(gift_of "$3")
        d1 "UPDATE friend_codes SET (pack, denari) = ($gift) WHERE code = '$code'" ;;
    *)
        sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
        exit 64 ;;
esac
