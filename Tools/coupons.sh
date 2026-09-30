#!/bin/sh
# Coupons on the Worker's D1: making them, and how many people took each one.
#
#   ./Tools/coupons.sh create NATALE --denari 500 --pack velluto --pack reliquia \
#         --item felt.notte --uses 100 --expires 2026-12-31 --note "Christmas post"
#   ./Tools/coupons.sh list                   every coupon, how many took it, whether it works
#   ./Tools/coupons.sh who NATALE             who took a coupon, and when
#   ./Tools/coupons.sh disable NATALE         stop it now; players are told it has expired
#   ./Tools/coupons.sh enable NATALE          undo that
#   ./Tools/coupons.sh items                  every cosmetic id --item accepts
#
# A reward is any mix of denari, packs (mazzetto bottega velluto reliquia scrigno forziere,
# one per --pack, left waiting in the album) and cosmetics by catalogue id (one per --item),
# at most ten of each. Every player takes a coupon once. --uses caps how many players may,
# --expires is the last day it works (UTC; or a full time, 2026-12-31T18:00:00Z), and the
# note is for this list only. Players type the code in the shop, under "Have a code?";
# case, spaces and accents are forgiven, so NATALE is also "Natale".
#
# Nothing that changes how the cards fall can be handed out, only what the shop and the album
# already give. The app drops an item it does not sell (a house default, a streak's felt, an
# album's prize) rather than skip the way it is earned.
#
# Talks to the live database, so it needs wrangler signed in (`npx wrangler@4 login`) or
# CLOUDFLARE_API_TOKEN set, and migrations/009-coupons.sql run once first. `--local`
# anywhere uses the local one `wrangler dev` runs on instead, and `--local=DIR` a throwaway
# one kept in DIR. `--yes` skips the question before a coupon is written.
set -e
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root/Server"

where=--remote persist='' yes=''
for arg do
    shift
    case $arg in
        --local) where=--local ;;
        --local=*) where=--local persist=${arg#--local=} ;;
        --yes) yes=1 ;;
        *) set -- "$@" "$arg" ;;
    esac
done

d1() {
    if [ -n "$persist" ]; then
        npx --yes wrangler@4 d1 execute scopa --local --persist-to "$persist" "$@"
    else
        npx --yes wrangler@4 d1 execute scopa "$where" "$@"
    fi
}

fail() { echo "$*" >&2; exit 64; }

# Single quotes doubled, so a note like "Nonna's day" is text and not SQL.
quote() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/''/g")"; }

# Upper case, spaces and dashes dropped: what the Worker would make of it anyway.
code_of() {
    code=$(printf '%s' "$1" | tr 'a-z' 'A-Z' | tr -d ' -')
    case $code in
        '' | *[!A-Z0-9]*) fail "A code is letters and digits, like NATALE, not '$1'." ;;
    esac
    [ ${#code} -le 24 ] || fail "A code is 24 characters at most."
    printf '%s' "$code"
}

whole() {
    case $2 in
        '' | 0* | *[!0-9]*) fail "$1 takes a whole number above zero, not '$2'." ;;
    esac
}

# The raw values an enum in Scopa/Design declares: its four-space `case` lines, with a
# `= "raw"` standing in for the name where there is one.
raw_values() {
    grep -E '^    case [a-zA-Z]' "$root/Scopa/Design/$1.swift" | sed -E 's/^    case //; s|//.*||' |
        tr ',' '\n' | sed -E 's/^ +//; s/ +$//; s/^[A-Za-z0-9]+ *= *"([^"]*)"$/\1/' | grep -v '^$'
}

# Every catalogue id the app's source declares, shelf by shelf. Read from the source rather
# than kept here, so a felt added to the app is a felt a coupon can give.
known_items() {
    for shelf in deck:CardStyle skin:CardTheme felt:TableFelt tapis:Tapis cornice:Cornice \
                 back:CardBackPattern companion:Companion livery:SeatLivery flourish:Flourish cheer:Cheer; do
        raw_values "${shelf#*:}" | sed "s/^/${shelf%%:*}./"
    done
    # Only the marks on sale: the rest are earned, and a coupon is not a way round that.
    grep 'static let forSale' "$root/Scopa/Design/SeatMark.swift" | grep -oE '\.[a-zA-Z]+' | sed 's/^\./mark./'
    grep -oE '"reactions\.[a-z]+"' "$root/Scopa/Shop/Cosmetics.swift" | tr -d '"'
}

# "2026-12-31" is the whole of that day in UTC. Refused if it is not a real time, or has passed.
expiry_of() {
    node -e '
        const text = process.argv[1];
        const day = /^\d{4}-\d{2}-\d{2}$/.test(text);
        const time = day ? new Date(text + "T23:59:59Z") : new Date(text);
        const real = day ? time.toISOString().startsWith(text) : /^\d{4}-\d{2}-\d{2}T[\d:.]+Z$/.test(text) && !isNaN(time);
        if (!real) { console.error(`--expires takes a day like 2026-12-31 or a UTC time, not "${text}".`); process.exit(64); }
        if (time <= new Date()) { console.error(`${text} has already passed.`); process.exit(64); }
        console.log(time.toISOString().replace(/\.\d{3}Z$/, "Z"));
    ' "$1"
}

create() {
    code=$(code_of "$1"); shift
    denari=0 packs='' items='' uses=NULL expires='' note=''
    while [ $# -gt 0 ]; do
        [ $# -ge 2 ] || fail "$1 needs a value."
        case $1 in
            --denari) whole "$1" "$2"; [ "$2" -le 1000000 ] || fail "$2 denari looks like a typo."; denari=$2 ;;
            --pack) tier_of "$2"; packs=${packs:+$packs,}$2 ;;
            --item) item_of "$2"; case ",$items," in *",$2,"*) ;; *) items=${items:+$items,}$2 ;; esac ;;
            --uses) whole "$1" "$2"; uses=$2 ;;
            --expires) expires=$(expiry_of "$2") || exit 64 ;;
            --note) note=$2 ;;
            *) fail "Unknown option $1. Run $0 help." ;;
        esac
        shift 2
    done
    [ "$denari" -gt 0 ] || [ -n "$packs$items" ] || fail "A coupon has to be worth something: --denari, --pack or --item."
    count "$packs" pack; count "$items" item
    describe
    unclaimed
    ask
    d1 --command "INSERT INTO coupons (code, denari, packs, items, max_uses, expires_at, note, created_at)
        VALUES ('$code', $denari, '$packs', '$items', $uses, $(sql_text "$expires"), $(sql_text "$note"),
                strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))"
    echo "Players type $code in the shop, under \"Have a code?\"."
}

tier_of() {
    case $1 in
        mazzetto | bottega | velluto | reliquia | scrigno | forziere) ;;
        *) fail "No pack tier '$1': mazzetto bottega velluto reliquia scrigno forziere." ;;
    esac
}

item_of() {
    known_items | grep -qxF "$1" || fail "No cosmetic '$1' in the app. $0 items lists them."
}

count() {
    [ "$(printf '%s' "$1" | tr ',' '\n' | grep -c .)" -le 10 ] || fail "Ten ${2}s at most."
}

sql_text() { if [ -z "$1" ]; then echo NULL; else quote "$1"; fi; }

describe() {
    echo "Coupon $code, on the ${persist:+throwaway }${where#--} database:"
    [ "$denari" -eq 0 ] || echo "  $denari denari"
    [ -z "$packs" ] || echo "  packs: $(echo "$packs" | sed 's/,/, /g')"
    [ -z "$items" ] || echo "  items: $(echo "$items" | sed 's/,/, /g')"
    [ "$uses" = NULL ] && echo "  any number of players" || echo "  $uses players at most"
    [ -z "$expires" ] && echo "  never expires" || echo "  works until $expires"
    [ -z "$note" ] || echo "  note: $note"
}

# A coupon named like a friend code would hide it: the shop tries coupons first.
unclaimed() {
    taken=$(d1 --json --command "SELECT (SELECT COUNT(*) FROM coupons WHERE code = '$code')
                                      + (SELECT COUNT(*) FROM friend_codes WHERE code = '$code') AS n" |
        tr -d ' \n' | sed -nE 's/.*"n":([0-9]+).*/\1/p')
    [ -n "$taken" ] || fail "Could not read the database. Has migrations/009-coupons.sql been run?"
    [ "$taken" -eq 0 ] || fail "$code is already a coupon or a friend's code."
}

ask() {
    [ -z "$yes" ] && [ -t 0 ] || return 0
    printf 'Write it? [y/N] '
    read -r answer
    case $answer in y | Y | yes) ;; *) echo "Nothing written."; exit 1 ;; esac
}

case ${1:-list} in
    list)
        d1 --command "SELECT c.code,
                TRIM(CASE WHEN c.denari > 0 THEN c.denari || ' denari ' ELSE '' END
                     || REPLACE(c.packs, ',', ' ') || ' ' || REPLACE(c.items, ',', ' ')) AS reward,
                COUNT(u.player_id) || COALESCE('/' || c.max_uses, '') AS taken,
                CASE WHEN c.disabled_at IS NOT NULL THEN 'disabled'
                     WHEN c.expires_at < strftime('%Y-%m-%dT%H:%M:%SZ', 'now') THEN 'expired'
                     WHEN COUNT(u.player_id) >= c.max_uses THEN 'used up'
                     ELSE 'live' END AS state,
                COALESCE(c.expires_at, '') AS until, COALESCE(c.note, '') AS note
            FROM coupons c LEFT JOIN coupon_uses u ON u.code = c.code
            GROUP BY c.code ORDER BY c.created_at DESC" ;;
    create)
        case $2 in '' | -*) fail "usage: $0 create CODE [--denari N] [--pack TIER]... [--item ID]... [--uses N] [--expires DAY] [--note TEXT]" ;; esac
        shift; create "$@" ;;
    who)
        code=$(code_of "$2")
        d1 --command "SELECT player_name, used_at FROM coupon_uses WHERE code = '$code' ORDER BY used_at" ;;
    disable)
        code=$(code_of "$2")
        d1 --command "UPDATE coupons SET disabled_at = strftime('%Y-%m-%dT%H:%M:%SZ', 'now') WHERE code = '$code';
                      SELECT code, disabled_at FROM coupons WHERE code = '$code'" ;;
    enable)
        code=$(code_of "$2")
        d1 --command "UPDATE coupons SET disabled_at = NULL WHERE code = '$code';
                      SELECT code, disabled_at FROM coupons WHERE code = '$code'" ;;
    items)
        known_items ;;
    *)
        awk 'NR > 1 && !/^#/ { exit } NR > 1 { sub(/^# ?/, ""); print }' "$root/Tools/coupons.sh"
        exit 64 ;;
esac
