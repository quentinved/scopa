# Scopa

[![CI](../../actions/workflows/ci.yml/badge.svg)](../../actions/workflows/ci.yml)

An iOS take on the Italian card game Scopa: play against the phone, pass it around a
table, connect nearby phones, or play friends and strangers online with a ranked ladder.
Swift 6, SwiftUI, iOS 17, with the game logic in dependency-free Swift packages and a
small Cloudflare Worker for the online parts.

<p align="center">
  <img src="Docs/screenshots/1-table.png" width="180" alt="The table mid-game">
  <img src="Docs/screenshots/2-coach.png" width="180" alt="The coach explaining a move">
  <img src="Docs/screenshots/4-ranked.png" width="180" alt="Ranked play and the league">
  <img src="Docs/screenshots/6-shop.png" width="180" alt="The cosmetics shop">
</p>

## What it does

- Classic rules for two, three or four players, with teams at four.
- Three bot levels. Every level sees only what a player in that chair would see; the hard
  one samples the unseen cards and plays the round out.
- A coach that explains moves as they happen, and a post-game review that grades every move.
- Local play: hot-seat on one phone, or nearby phones over Multipeer Connectivity.
- Online play over Game Center, plus four-letter room codes for tables that wait for a
  friend to arrive.
- A daily deal everyone plays on the same cards, weekly challenges, and a monthly ranked
  season with leagues and divisions.
- Denari, an in-game currency earned by playing, spent on card styles, cloths and
  reactions. No real-money purchases.
- Twelve Game Center achievements, three languages (English, French, Italian), and all
  music and sound effects synthesised from code.

## Layout

```
Scopa/                 App shell: screens, design system, audio, ads, shop
Packages/Scopa/        Swift packages, no UIKit or SwiftUI
  ScopaCore/Domain       Cards, rules, scoring, bots, search, coach, review
  ScopaCore/Application  Host coordinator, guest client, table updates, transport port
  ScopaRewards           Denari ledger, purse, stakes, shop items
  ScopaMultipeer         GameTransport over Multipeer Connectivity
  ScopaGameCenter        GameTransport over GKMatch, identity, achievements
  ScopaRelay             GameTransport over WebSocket rooms on the Worker
Server/                Cloudflare Worker + D1: ladder, daily deal, rooms, identity checks
Tools/                 Build script, sound synthesis, icon and achievement renderers,
                       App Store Connect uploads
```

The packages follow a hexagonal layout. `ScopaCore/Domain` is pure functions over value
types: `Rules` validates and applies a move, `Scoring` settles a round, `Search` is the
hard bot. `ScopaCore/Application` runs a table: a `HostCoordinator` owns the authoritative
`GameState` and sends each seat its own `PlayerView`, and a `GuestClient` mirrors one seat.
Both talk through the `GameTransport` port, so the same coordinator drives a hot-seat
game, a Multipeer game, a Game Center match and a relay room. The app in `Scopa/` only
ever sees `TableUpdate` values.

The Worker verifies Game Center signatures itself, so a result is only ever recorded for
the player who made it. The app works fully offline; the Worker only adds comparison.

## Building

Open `Scopa.xcodeproj` and run the `Scopa` scheme, or from the command line:

```sh
./Tools/dev.sh build                             # compile
./Tools/dev.sh run -noGameCenter -denari 99999   # build, install, launch on the simulator
./Tools/dev.sh shot out.png 12 -shop             # the above, then a screenshot
```

`dev.sh` serialises builds and simulator use behind a lock, so several sessions on one
machine queue instead of colliding, and shares one DerivedData so builds stay incremental.

Launch arguments such as `-noGameCenter`, `-denari`, `-shop` and `-autoPlay` are read
by `Scopa/Game/DebugLaunch.swift` and only exist in debug builds.

## Tests

```sh
cd Packages/Scopa && swift test     # rules, bots, coach, review, networking, rewards
cd Server && npm test               # ranking, seasons, identity verification
```

The bot tests deal the same cards to two levels and check the stronger one wins more, so a
handful of hands is enough to show a real edge rather than a lucky shuffle. The network
tests run a host and several guests over an in-process loopback transport. Both suites run
on every push, along with a build of the app, through the workflow in `.github/workflows`.

## Licence

The source is published to be read, not reused: see [LICENSE](LICENSE).

## Server

One Worker, one D1 database, one Durable Object class for rooms. See
[Server/README.md](Server/README.md) for deploy steps. Apple API keys for the store
tooling are read from `ASC_KEY`, `ASC_KEY_ID` and `ASC_ISSUER_ID` and never stored in
the repo.
