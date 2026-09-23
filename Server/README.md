# Scopa ladder

One Cloudflare Worker and one D1 database. It records how everybody did on the daily
deal and answers "where do I stand today?". The app works without it; with it, the
lobby card can say "#12 of 340".

Nothing here costs anything at Scopa's scale: the free tiers cover about a hundred
thousand requests a day, and a daily deal is one request.

## Deploy (first time)

```sh
npm install -g wrangler@latest          # the machine has an old 2.x
cd Server
wrangler login
wrangler d1 create scopa                # copy the database_id into wrangler.toml
wrangler d1 execute scopa --remote --file schema.sql
wrangler deploy                         # prints https://scopa-ladder.<you>.workers.dev
```

Tables need a Durable Object, which the first `wrangler deploy` after this creates from the
migration in `wrangler.toml`. They are SQLite-backed, which is the kind the free plan
gives, and wrangler must be 3.x or newer to understand `new_sqlite_classes`.

Then set `Ladder.baseURL` in the app (Scopa/Game/Ladder.swift) to that URL.

## The house

Ranked is a table of four: whoever the eight-second search finds, and the house in the chairs
left over — one real opponent leaves two house seats, nobody leaves three. Only real players
are rated; the house is scenery the ladder never hears about.

What decides the price is not whether the house is at the table, since it always is, but
whether two phones can hold each other to the result. A real player on each side is settled by
both reports and paid the full ladder rates. Everything else — a table you were left alone at,
and a duo, whose two friends share a side and can be beaten only by the house — is a house
game: 25 a win, 5 a loss, and ten a day counted at all. House games never build a win streak
or break one; a streak is something taken off people.
`migrations/002-house-games.sql` adds the table that counts them.

## Leagues and runs

An even table pays 20, so a division is five wins and a league fifteen; a table of any size
is capped at 40. On top of that a run pays 2 for every win in a row past the first, up to
10, and one loss to a real player ends it. `ratings.streak` holds it, and
`migrations/004-streaks.sql` adds the column. A season's reset gives it back with the
divisions.

## Seasons

A season is a calendar month in UTC. A rating carries the season it belongs to; the first
read or write in a new month puts what the player finished with into `season_finishes` and
brings the rating back to the bottom of the league they reached: leagues are kept,
divisions are given back. The app hands the player their denari for that finish and posts
`/v1/ranked/claim` so nothing pays twice.

A database created before seasons needs one migration:

```sh
wrangler d1 execute scopa --remote --file migrations/001-seasons.sql
```

Rows already in `ratings` carry no season, and adopt the current one without being reset:
the month seasons ship is nobody's season to lose.

## The account

A player's phone and their iPad are the same player. What travels is their preferences and
the cosmetics they are wearing, the counters behind their achievements and level, their
album, the week's challenge, and their purse. What does not: `deviceID`, which is a device's
own name for itself; the ladder's cached answers, which are re-asked anyway; and the guards
that stop a finished game being counted twice, which are a record of what one device has
already done.

Keyed on the Game Center `gamePlayerID`, the same id the ladder keys on, and **not** on
iCloud. Since iOS 16 the two can be different accounts, and the one a player recognises as
themselves in a game is the name on the board. It also means the account works for a player
whose devices are on different Apple Accounts, which iCloud syncing could not do.

The Worker never looks inside either half. Merging a profile means knowing what a felt is
and what a win is worth, and that knowledge lives in the app — writing it here as well would
be a second place for the economy to be wrong. So the split is:

- **The profile** is one opaque JSON blob with a revision. A write names the revision it was
  merged from and is refused with `409` if that is no longer current; the answer to a `409`
  carries everything needed to merge again and retry. The merge itself is
  `Packages/Scopa/Sources/ScopaProfile`, which is commutative and idempotent on every field
  so that syncing twice means syncing once — preferences by the later clock, counters by the
  larger, collections by union.
- **The purse** is a ledger of keyed entries and needs no revisions at all. Every entry names
  itself, so two devices writing at once is a union: `INSERT OR IGNORE` on
  `(player_id, key)`. A device reads forward from the last `seq` it saw. This is what
  `LedgerEntry.key` was always for.

`migrations/005-accounts.sql` adds both tables.

### What it costs to be wrong

Two devices that each play a game while apart come back with one game between them rather
than two: counters merge by the larger. It errs downwards, and for a count of wins that is
the right way round. Packs waiting to be opened go the other way — they are spent, not
collected, so they take the latest word rather than the largest. Merging those by the larger
would hand back a pack already opened on the other device, and a pack opened twice is its
cards, its denari and whatever it turned up off the shelves, twice. Losing a pack is the
side to be wrong on.

Denari are never wrong either way, because the ledger dedupes.

- `POST /v1/profile/read` — `{since, identity}`. Returns `{rev, profile, ledger, since, more}`.
- `POST /v1/profile/write` — `{rev, profile, ledger, since, identity}`. `profile` may be null
  to write only the ledger. Returns the same shape, or `409` with it when `rev` is stale.

## Test locally

```sh
npm test            # verifies the Game Center signature path with a locally made certificate
wrangler dev        # runs the Worker on localhost with a local D1
```

## Routes

- `POST /v1/daily` — a day's result plus a Game Center identity signature. Refused unless
  the signature verifies for this bundle id. One result per player per day; a second is
  ignored, not replaced. Returns the player's standing.
- `GET /v1/daily/<day>?player=<gamePlayerID>` — the top fifty and, if asked, that player's rank.
- `POST /v1/ranked/house` — a ranked game against the house, which only one phone can ever
  report. Taken on trust: +25 a win, −5 a loss, and only the first ten a day counted at all,
  so the day is what limits it rather than the price.
- `POST /v1/ranked/claim` — a finished season marked as paid, signed like the rest. The
  denari live on the phone; this is the tick that stops a second phone paying them again.
- `GET /v1/health`

### Tables

A table two friends meet at, kept here rather than by Game Center. One Durable Object per
open table, hibernating, so a room waiting for somebody to arrive costs nothing. Nothing
is signed, so a room works for players who have never signed in to Game Center, and across
a build from Xcode and a build from TestFlight, which Game Center does not.

- `POST /v1/rooms` — `{host, name, capacity}`. Returns `{code, link}`. The code is four
  characters of an alphabet with no O/0 and no I/1, because it gets read down the phone.
- `GET /v1/rooms/<code>` — `{open, host, seated, capacity, players}`, or 404. What the join
  screen asks before it commits, so a mistyped code is answered rather than spun on.
- `GET /v1/rooms/<code>/socket?player=&name=` — the web socket the game runs over. Frames
  up are `{to, data}` where `to` is `all`, `host` or `p:<player id>`; frames down are
  `{type: "welcome" | "relay" | "joined" | "left", …}`. `data` is one of the app's
  envelopes, as a string. The Worker never opens it: the rules of Scopa live in the app.

Rooms are swept thirty minutes after the last person leaves, and twelve hours after they
were opened whatever is happening in them.

### Invitations

- `GET /.well-known/apple-app-site-association` — the file iOS reads to let Scopa open our
  links. Must be served from the same domain as the links, unsigned, with no redirect.
- `GET /j/<code>` — the page behind an invitation link. On an iPhone with Scopa installed
  iOS opens the app instead and nobody sees it; it is what everybody else gets.

Both need the domain in the app's Associated Domains entitlement
(`Scopa/Scopa.entitlements`) and the team id in `src/invite.ts` to match the real one.
There is no App Store link on the page until the id is pasted into `APP_STORE` there.

## Trust

The signature is Apple's, made on the device by Game Center, over
`playerID + bundleID + timestamp + salt`. The Worker fetches Apple's certificate from the
`publicKeyURL` in the request (only `*.apple.com` over https is accepted), pulls the
public key out of it, and verifies. Signatures older than an hour are refused. The
score itself is still what the app says it is: a modified app could post a false margin.
Stopping that means replaying the recorded game on the server, which is the next step
if it ever matters, and the `GameRecord` the app already keeps is exactly what it needs.

## What comes after

The same Worker is where mirror-match results, wager escrow between strangers and a
friends graph would live. Each is a table and a route; nothing here has to change.

The relay is also where a ranked queue would run: two people who both want a game are a
room the Worker can make for them, without both having to be searching in the same second.
