# 01 — Research analysis

Research by Claude for Deovandski, November 7, 2026. Later decisions (chapter 02) supersede parts of this chapter; those spots are marked.

## Executive summary

The game is feasible as a small Godot 4.7 project where Claude agents write nearly all of the code, data and text and produce first-pass placeholder art. The real gaps are polished frame-by-frame animation and music. The hard calendar gate is Google Play's 12-tester, 14-day closed test for new personal accounts.

- **The market gap is real.** Free Android fishing games are dominated by free-to-play titles with ads, pay-to-win upgrades or idle mechanics. A free, offline, no-ads, skill-based fishing game with a real world behind it has few direct competitors.
- **Short active sessions fit the data.** Median mobile game sessions run 5 to 6 minutes. Design each loop to end naturally in 3 to 5 minutes.
- **The lore already contains a fishing game.** Sanbi is a fishing kingdom with canon fish (Sanbi, Fihi, Ptaina), a legendary fish (the True Sanbi King), a currency ladder (Pearl to Sapphire) and a travel system (circles) that map onto progression and travel cost.
- **Stack:** Godot 4.7 + GDScript, Android SDK, OpenJDK 17, Git, Claude Code.
- **Publishing:** $25 one-time Play Console fee, target Android 16 (API 36), and either 12 testers for 14 days on a personal account or an organization account under Wizard Deo Solutions.

## Market scan

The genre is big but crowded at the free-to-play end and thin at the "free, fair, skill-based, offline" end, which is where this game sits.

| Game | Model | Style | Why it matters |
| --- | --- | --- | --- |
| [Fishing Clash](https://appgoblin.info/apps/com.tensquaregames.letsfish2) | Free, IAP + ads | 3D realistic, PvP | Genre leader: about 144.6M installs and 3.7M monthly users (AppGoblin estimate). Proves demand, not our niche. |
| [Let's Fish](https://marlvel.ai/api/llm/apps/simulation/let-s-fish-fishing-simulator) | Freemium | Illustrated sim, PvP | Top complaint is pay-to-win; top request is an offline mode. We give both away by design. |
| [Tiny Fishing](https://gamebrain.co/game/tiny-fishing) | Free + ads | Minimal upgrade loop | Liked for graphics, disliked for monetization; runs out of depth in about 3 hours. |
| [Fishing Life](https://m-apps.qoo-app.com/en-US/app/9361) | Free | Calm sim | Removed ad billboards and an offerwall: players push back on ads in calm games. |
| [DREDGE](https://dredge.wiki.gg/wiki/DREDGE_(mobile)) | Premium | Story-driven horror fishing | On Android since Feb 27, 2025. A fish-sell-upgrade-explore loop works on phones. |
| [Pixel Fishing Quest](https://alternativeto.net/software/pixel-fishing-quest/about), [River Legends](https://skich.app/games/river-legends-a-fly-fishing-a-2) | Indie, pixel art | Pixel fishing | Closest in look; small audiences; no lore world or deep active minigame. |
| Idle fishing games (e.g. [Fish Away](https://appgoblin.info/apps/6787988987)) | Free, IAP + ads | Idle | A sub-genre we deliberately avoid. |
| Clash of Critters | Gacha | Collection | Rejected as a model (chapter 02): too gacha, loop centers on collecting. |

**Session length:** GameAnalytics' 2025 benchmarks put the [median mobile session at 5 to 6 minutes and the top tier at 8 to 9](https://gameindustrylibrary.com/documents/gameanalytics-mobile-gaming-benchmarks-2025/read?page=11). Adjust reports longer averages with a different method, so design for 3 to 5 minute loops that can chain.

**What we can't compete on:** marketing spend and live events. Discovery leans on readers of the series, the West March D&D community and Play Store search.

## What the #HusbandOutWorld lore gives the game

Sources: [Vraki West March Campaign World Lore](https://github.com/Deovandski/Vraki-West-March-Campaign-D-D) and the [#HusbandOutWorld repo](https://github.com/Deovandski/HusbandOutWorld).

| Spot | Water | Canon fish / hazard |
| --- | --- | --- |
| Sanbi Dockyard and Old Wharf | Ocean, east coast | **Sanbi** fish: tuna-like, migraines via radio waves, sheds fake lips and tails as decoys; a strong fisher lands two a day. Daily Safe Fishing Prayer. |
| Sanbi deep water | Open sea | **True Sanbi King**: the giant fish that made a pact with one family. End-game legendary. |
| Fostwater | Harbor | Water glows where salt and fresh mix: a "night look" without a day/night cycle. |
| Deltacross | Great lake crossing | Ferry hub (2 pearls per person). Beginner lake near Forway. |
| Lukewarm Lake | Buhraies-dug lake | Giant **Fihi** (platypus-eel, elemental shocks) that eat people. |
| Flatland lake, Abandoned Docker | Desert oasis lake | Fihi that learned to eat people. |
| Sweetlake | Frontier lake | Sweet Sting giant bees; black honey as a bait idea. |
| Endlessfog and Endlessboil | Rainy island, boiling lake | Heat-resistant fish. |
| Triangle and coastal boats | Sea and islands | **Ptaina**: glowing purple head, ultrasonic stuns, scrambles compasses. |
| Cruro swamps | Swamp | Crocus alligators; Cruros barter (not treaty citizens). |
| End Lake ("the Shitter") | Forway sewage lake | Comic junk-fishing spot. |

**Systems to borrow**

- **Currency:** balls. Pearl (base), Amethyst = 50 pearls, Aquamarine = 500, Sapphire = 5,000.
- **Rags to riches:** Fisherman is a Tier I (poorest) profession in canon.
- **Travel by circles:** each circle is 1 to 3 days. Canon fares: merchant boat about 5 pearls per person per circle, Deltacross ferry 2 per person, Waterfall elevator 20 per person. Placeholder travel cost = circles x fare until the travel map is done.
- **Abilities:** nari gels (Water Breath, made from fish gills, is a ready dive ability).
- **Random nudge:** Winga mail notices (a fish run elsewhere, a bounty, a storm, a Ptaina scrambling the compass).

**Watch-outs:** the series is adult and crude (affects the Play content rating); both lore repos are CC BY-NC-SA 4.0 with Deovandski as copyright holder; Sinoi is a new character; the main repo includes unreleased story notes (decide what the game may reveal).

## Core loop (from research; fight input superseded by chapter 02)

Open the app at your last spot, cast, hook, fight, collect, repeat until the bag is full, then sell, upgrade and maybe travel. A small early bag (about 6 slots) makes a session about 3 to 5 minutes. The bag check is the natural stopping point.

- Progression: gear tiers bought with balls (rod, line, reel, bait, tackle, bag); rank badges Pearl to Sapphire unlock regions; nari gel abilities; a fish journal with sizes and perfect-catch stars.
- Fish names: tuna (*maguro* + *atum*) = **Magatum**; carp (*Karpfen* + *koi*) = **Karkoi**; catfish (*bagre* + *namazu*) = **Bagnazu**.
- Scope: vertical slice = 1 region, about 12 fish, 1 legendary, shop and journal. Version 1 = 5 to 6 regions, about 50 fish, 5 legendaries.
- *Superseded:* the original gesture table (swipe to cast, Stardew vertical bar, swipe for runs) is replaced by the **fight box** in chapter 02.

## What Claude can build, and what needs other help

| Area | Claude agents | Needs a person or tool |
| --- | --- | --- |
| Game code (GDScript) | All systems: fight box, fish behavior, shop, travel, events, saves, menus | Feel must be judged and tuned on real phones |
| Design data and balance | Fish tables, prices, gear curves | Sign-off on difficulty |
| Writing | Fish names, journal entries, Winga notices, store listing | Approval of anything that becomes canon |
| Static pixel art | Placeholder icons, UI, tiles via palette-locked scripts or AI tools | Final art by the illustrator |
| Simple motion | Tweens, shaders, particles | — |
| Character animation | Rough placeholder frames | The illustrator |
| Sound effects | Procedural retro SFX | Optional polish |
| Music | Basic chiptune loops | A composer or CC0 music |
| Build and install | Exports, signing, adb install with Claude Code on the PC | Phone setup |
| Publishing | Store text, data safety and content rating answers | Play Console account, ID verification, testers |

## Engine and tech stack

Godot 4.7 with GDScript: free, no royalties, built for 2D pixel games, plain-text scenes and scripts, one project for Android and web. [Godot 4.7 shipped in June 2026](https://playingtux.com/en/articles/2026/06/godot-47-released/); its Android template [targets API 36](https://forum.godotengine.org/t/how-to-target-latest-android-sdk/142631); single-threaded web export (the default since 4.3) runs on GitHub Pages without special headers.

Alternatives considered: Unity (heavier, more binary project data), Defold (small community), Flutter + Flame (app-like), native Kotlin/libGDX (most hand-written code).

Architecture notes: portrait 180 x 320 base resolution with integer scaling; all fish, gear, regions, fares and events in data files; fully offline, local saves, no analytics or ad SDKs; minimum Android 7.0 (API 24).

## PC software

| Software | Why | Cost |
| --- | --- | --- |
| Godot 4.7.x (standard, not .NET) | Engine and editor | Free |
| OpenJDK 17 (Temurin) | Android export ([Godot docs](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html)) | Free |
| Android Studio SDK Manager | platform-tools (adb), build-tools 35.0.1, platforms 35 and 36, command-line tools | Free |
| Git + GitHub | Version history, collaboration with agents | Free |
| [Claude Code](https://code.claude.com/docs/en/setup) | Agents edit the project, export, install to phones | Claude plan |
| scrcpy | Mirror and record the phone screen | Free |
| Aseprite (or LibreSprite) | Pixel art and animation | $19.99 / free |
| Audacity, jsfxr/ChipTone, BeepBox | Audio | Free |

Phone setup: Settings > About phone > tap Build number 7 times; Developer options > USB debugging (and Wireless debugging); accept the computer's prompt; `adb devices`; Godot's one-click deploy.

## Publishing on Google Play

| Requirement | What it means | Source |
| --- | --- | --- |
| Developer account | $25 one-time, government ID and card in your legal name | [Google](https://support.google.com/googleplay/android-developer/answer/6112435) |
| Closed test (personal accounts made after Nov 13, 2023) | 12 testers opted in for 14 continuous days before production; recruit 20 | [Google](https://support.google.com/googleplay/android-developer/answer/14151465) |
| Production access review | Usually within 7 days; a rejection restarts the test | [GoodBarber guide](https://www.goodbarber.com/help/goodbarber-takes-care-gbtc-publication-service-r80/gbtc-android-personal-google-play-developer-account-a429/) |
| Organization account | Exempt from the closed test; needs a D-U-N-S number | [Choicely](https://www.choicely.com/blog/google-play-12-tester-rule) |
| Target API level | Android 16 (API 36) since Aug 31, 2026; rises every August | [Google](https://support.google.com/googleplay/android-developer/answer/11926878) |
| Format and signing | AAB signed with a release keystore; back it up | [Godot docs](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html) |
| Ads declaration | Google counts banners promoting your own products as house ads; an always-on Amazon banner likely needs "Contains ads" unless it lives on a credits/support screen | [Forum quoting Google's examples](https://www.ghisler.ch/board/viewtopic.php?p=302433) |
| Data safety | Offline, no SDKs = no data collected | Play Console |
| Developer verification | Required for sideloading in 4 countries from Sept 2026, globally in 2027; Play distribution is covered by the Play account | [Android Authority](https://www.androidauthority.com/android-sideloading-changes-timeline-3679204/) |

## Decisions

| # | Decision | Status |
| --- | --- | --- |
| 1 | Engine | **Decided:** Godot 4.7 |
| 2 | Play account type | Open: personal (12 testers x 14 days) or organization (Wizard Deo Solutions, D-U-N-S) |
| 3 | Support banner placement | Open: always-on banner (likely "Contains ads") or credits/support screen. The pre-production build shows it on the title screen. |
| 4 | Orientation and hands | **Decided:** portrait; one finger at the start, up to two (index + middle); tablets supported (chapter 02) |
| 5 | Tone and content rating | Open |
| 6 | Who Sinoi is | Open (new character) |
| 7 | Art pipeline | **Decided:** AI placeholders, final art by the illustrator drawn over them (chapter 03) |
| 8 | Music | Open |
| 9 | Placeholder travel fares | Proposed: circles x 5 pearls, in one data table |
| 10 | Saves | **Decided:** local saves with JSON export/import (see [SAVE_FORMAT.md](../SAVE_FORMAT.md)) |
| 11 | Spoiler limits | Open |
| 12 | Source code | **Decided:** open source |
| 13 | Android package name | Proposed: `com.wizarddeo.sinoithefisherman` (permanent after the first Play upload) |

## Risks

| Risk | Mitigation |
| --- | --- |
| Fight box feels bad on touch | Prototype it first on real phones (a touch test is already in the pre-production build) |
| Inconsistent art across AI placeholders and final art | Lock palette and pixel scale early; placeholders follow the brief |
| Testers drop out mid-test | Recruit 20 from readers, friends and the West March group |
| Scope creep | Ship the 1-region slice to testers before region 2 |
| Annual API bump | Upgrade Godot each summer |
| Lost release keystore | Two offline backups plus a password manager |
