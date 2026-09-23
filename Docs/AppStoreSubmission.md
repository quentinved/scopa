# App Store submission — Scopa Bella 1.0

`Tools/push-metadata.sh` fills most of the listing. This file covers the rest: what the
script pushes, and every field it cannot reach, with the answer to give.

## 0. Blockers before submitting

- [ ] **Deploy the updated privacy policy and support page** (`cd Server && npm run deploy`).
  Both now cover the synced copy of the game (profile, album, denari ledger), code-word
  tables relayed through the Worker, the weekly challenge and the ranked extras. They are
  dated 23 September 2026. Check https://scopa-ladder.quentin-vedrenne.workers.dev/privacy
  after the deploy.
- [ ] **Archive a Release build and play it once.** `dev.sh` and CI build Debug only, so an
  `#if DEBUG` leak shows up only here (test ad units, debug launch flags, consent reset).

## 1. Pushed by `Tools/push-metadata.sh`

Run with `ASC_KEY=../key/"App Store Connect Auth Key.p8" ASC_KEY_ID=… ASC_ISSUER_ID=… SCOPA_CONTACT_PHONE=+33… Tools/push-metadata.sh`.

| Field | Value |
|---|---|
| Name / subtitle / promo text / keywords / description | `Tools/StoreMetadata/copy.swift` (en-US, fr-FR, it) |
| Category | Games, then Card and Board |
| Privacy policy URL | https://scopa-ladder.quentin-vedrenne.workers.dev/privacy |
| Support URL | https://scopa-ladder.quentin-vedrenne.workers.dev/support |
| Copyright | 2026 Quentin Vedrenne |
| Release | Automatically after approval |
| Age rating questionnaire | Simulated gambling: infrequent/mild; advertising: yes; everything else none/no |
| Review contact | Quentin Vedrenne, contact@quentinvedrenne.com, phone from `SCOPA_CONTACT_PHONE` (**required by Apple**) |
| Sign-in required | No |
| Review notes | `Tools/StoreMetadata/main.swift`, "What review needs to know" |

`whatsNew` stays empty: Apple refuses it on a first version.

## 2. Filled by hand in App Store Connect

### App Privacy (App → App Privacy → Get started)

"Do you or your third-party partners collect data from this app?" → **Yes**.

**Collected by us** (the ladder Worker, only when signed in to Game Center). All three are
Linked to the user: Yes. Used for tracking: No. Purpose: App Functionality.

| Category → Type | What it is |
|---|---|
| Identifiers → User ID | Game Center `gamePlayerID` |
| Contact Info → Name | the Game Center alias (declared as Name in `PrivacyInfo.xcprivacy`, so keep it matching) |
| User Content → Gameplay Content | daily/weekly/ranked results, rating, and the synced profile, album and purse |

**Collected by Google AdMob.** These follow Google's AdMob disclosure guide. Re-check that
page on the day you fill this in, because Google revises it.

| Category → Type | Purposes | Linked | Tracking |
|---|---|---|---|
| Identifiers → Device ID (IDFA) | Third-party advertising, Analytics | No | **Yes** |
| Location → Coarse Location (from IP) | Third-party advertising, Analytics | No | Yes |
| Usage Data → Product Interaction | Third-party advertising, Analytics | No | Yes |
| Usage Data → Advertising Data | Third-party advertising, Analytics | No | Yes |
| Diagnostics → Crash Data / Performance Data / Other Diagnostic Data | Analytics | No | No |

Answering Tracking = Yes for anything makes ATT mandatory, and the app already shows the
prompt before any ad request (`Scopa/Ads/AdsConsent.swift`).

Not collected: code-word table traffic (relayed in real time, not kept) and Nearby
(device to device).

### Pricing and Availability

- [ ] Price: **Free** (tier 0)
- [ ] Availability: all countries and regions (or at least France, Italy, Belgium,
      Switzerland, the US and the UK)
- [ ] Pre-order: off

### App Information

- [ ] **Content rights**: "Does your app contain, show, or access third-party content?"
      Answer **No** only if every deck design (Napoli, Piacenza, Bergamo, Pergamena, Riviera)
      is our own drawing. Ads do not count here.
- [ ] **EU Digital Services Act trader status** (Business → or App Information). The app
      earns money from ads, so this is a trader account. That publishes an address, phone
      and email on the EU product page. Needed for any EU storefront.
- [ ] Age rating: check that the computed rating (the script prints it) is what you expect,
      probably 12+ because of simulated gambling.

### Version 1.0 page

- [ ] **Build**: upload `dist/Scopa.ipa` (Transporter or `xcrun altool`) and select it.
      Export compliance is already answered by `ITSAppUsesNonExemptEncryption = NO`.
- [ ] **Screenshots**: 6.9" iPhone and 13" iPad (the target is universal, so iPad is
      required) × 3 languages: `Tools/push-screenshots.sh`.
- [ ] **Game Center**: turn on the Game Center section on the version and **add the
      achievements and leaderboards** (`Tools/seed-achievements.sh` creates them). On a first
      release they are not live until they are attached to the version.
- [ ] App icon comes from the build.
- [ ] Marketing URL (optional): leave empty.
- [ ] Accessibility Nutrition Labels (optional): skip for 1.0.

### Before pressing "Add for Review"

- [ ] AdMob console: app linked to its App Store listing once it goes live, and the
      `app-ads.txt` served at the developer website domain.
- [ ] Privacy policy fixed (section 0) and privacy label matches it.
- [ ] Release build played through once: Quick game, one pack, one rewarded ad, the consent
      form (use an EU VPN or the debug geography).
