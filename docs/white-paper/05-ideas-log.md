# 05 — Ideas log

Every idea raised during the research phase, whether it made the cut, and **why**. Agents add a row whenever an idea is proposed, kept, cut or changed (see the rule in [CLAUDE.md](../../CLAUDE.md)). Reasons marked *(inferred)* were worked out by Claude, not stated by Deovandski; he confirms or corrects them. When the reason can't be inferred, the row says **Why: ask Deo** until he answers.

Status: **Kept** (in the design), **Cut** (rejected), **Testing** (prototype exists, waiting for playtests), **Open** (not decided), **Replaced** (superseded by another row).

| Date | Idea | From | Status | Why | Where |
| --- | --- | --- | --- | --- | --- |
| 2026-11-07 | Base the fishing on Stardew Valley's minigame, taken further | Deo | Kept | The loop centres on the catch, and some fish are truly hard to land | [02](02-design-direction.md) |
| 2026-11-07 | Seasons | Brief | Cut | "For the sake of not going too crazy": scope | [README](README.md) |
| 2026-11-07 | Day/night cycle | Brief | Cut | Same reason as seasons: scope | [README](README.md) |
| 2026-11-07 | Idle progress, offline earnings, energy timers | Brief | Cut | Active play is the core pillar: short sessions with full attention | [02](02-design-direction.md) |
| 2026-11-07 | Ads and in-app purchases | Brief | Cut | Free game; only a credits banner pointing to the eBooks and the World Lore | [README](README.md) |
| 2026-11-07 | New fish named by translating a real fish into two languages, chopping and joining | Deo | Kept | Real fish keep it grounded; the names feel new and fit the world *(inferred)* | [CLAUDE.md](../../CLAUDE.md) |
| 2026-11-07 | Random nudge mechanic (Winga notices: a run elsewhere, a bounty, a storm, a Ptaina scrambling the compass) | Brief, Claude | Open | Pushes players to act and travel; event list not written yet | [01](01-research-analysis.md) |
| 2026-11-07 | Travel costs money | Brief | Open | Exact fares wait for the West March travel map; placeholder proposal: circles × 5 pearls | [01](01-research-analysis.md) |
| 2026-11-07 | Pixel art in the style of Stardew Valley, 180 × 320 base resolution | Brief | Kept | The look Deo asked for; small base size keeps art affordable *(inferred)* | [illustrator brief](../art/illustrator-brief.md) |
| 2026-11-07 | Godot 4 as the engine | Claude | Kept | Free, open source, exports to Android and the web from one project | [01](01-research-analysis.md) |
| 2026-11-08 | Clash of Critters as a model | Deo | Cut | Too gacha, and actual play isn't varied enough; its loop centres on collecting | [02](02-design-direction.md) |
| 2026-11-08 | Stardew's single vertical bar | Stardew | Replaced | Replaced by the 2D fight box so paths can run horizontally and diagonally and use two fingers | [02](02-design-direction.md) |
| 2026-11-08 | Horizontal and diagonal sliders | Deo | Kept | Folded into the fight box as path shapes | [02](02-design-direction.md) |
| 2026-11-08 | Fight box as a trackpad with osu!-style slides, taps, releases and flicks | Deo | Kept | Varied, active input with room for multi-finger play | [02](02-design-direction.md) |
| 2026-11-08 | osu! and Project Diva as inspiration | Deo | Kept | For the fight input and the forgiveness settings; mechanics only, never names or assets | [02](02-design-direction.md) |
| 2026-11-08 | One finger at the start, up to two (index + middle of one hand) | Deo | Kept | Easy start; the second finger is the late-game skill | [02](02-design-direction.md) |
| 2026-11-08 | Two hands and tablets | Deo | Kept | Allowed and supported, never required. Tablets because a bigger screen adds little extra work: about the same as supporting a touch-screen laptop (Deo, 2026-11-22) | [02](02-design-direction.md) |
| 2026-11-08 | Portrait orientation | Claude, Deo | Kept | One-handed play on a phone held normally *(inferred)* | [01](01-research-analysis.md) |
| 2026-11-08 | Two pads: real pad below, shadow pad above | Deo | Kept | Fingers cover the real pad, so the player watches the shadow | [02](02-design-direction.md) |
| 2026-11-08 | Timing-forgiveness settings with a warning ("Use this for accessibility, not to cheese the game!...") | Deo | Kept | Accessibility; hard fish should be beaten with bait and tackle, not settings | [02](02-design-direction.md) |
| 2026-11-08 | Stardew's bait and tackle system | Deo | Kept | Without seasons or day/night, bait and region decide which fish bite and tackle sets difficulty | [02](02-design-direction.md) |
| 2026-11-08 | Lore fish as pattern twists (Sanbi decoys, Ptaina stun, Fihi shocks) | Claude | Open | Proposal; Hookset's X decoy is a first test of the Sanbi idea | [02](02-design-direction.md), [04](04-fight-box-modes.md) |
| 2026-11-08 | AI placeholder art, then the illustrator draws over it | Deo | Kept | Lets the game be built before final art; placeholders follow the brief so final art drops in | [03](03-plan-and-roles.md) |
| 2026-11-08 | Dedicated test phone for the illustrator | Deo | Kept | Developer mode and USB debugging weaken a phone's security, so not her main phone | [03](03-plan-and-roles.md) |
| 2026-11-08 | Open source (MIT code, CC BY-NC-SA docs) | Deo | Kept | A technical portfolio for Deo, and the project itself is free advertising for the #HusbandOutWorld series (Deo, 2026-11-22) | [03](03-plan-and-roles.md) |
| 2026-11-08 | Local saves with JSON export and import | Deo | Kept | Players can move or back up saves with no account or server | [SAVE_FORMAT](../SAVE_FORMAT.md) |
| 2026-11-08 | One Godot project for the web and Android builds | Deo | Kept | One codebase; the website build lets anyone try it with no install | [BUILDING](../BUILDING.md) |
| 2026-11-08 | Support banner always on vs. on a credits screen | Claude | Open | An always-on banner may make Google Play label the game "Contains ads" | [01](01-research-analysis.md) |
| 2026-11-08 | Installable web app (PWA) with offline play | Deo (issue #4) | Kept | Play the browser build like an app, even with no signal | [BUILDING](../BUILDING.md) |
| 2026-11-21 | Carousel of fight-box modes on the touch test | Deo (issue #1) | Kept | Try many modes side by side and rank them from easy to hard | [04](04-fight-box-modes.md) |
| 2026-11-21 | Slide Guide (the first touch-test prototype) | Deo | Testing | Baseline the other modes are compared against | [04](04-fight-box-modes.md) |
| 2026-11-21 | Hold Hop (press, hold, lift, hop; timing punished more than aim) | Deo | Testing | Ranking pending playtests. Claude added a closing ring to time the press; Deo will check it in playtests (2026-11-22) | [04](04-fight-box-modes.md) |
| 2026-11-21 | Twin Drift (index + middle each keep a moving square, varying speed) | Deo | Testing | Ranking pending playtests | [04](04-fight-box-modes.md) |
| 2026-11-21 | Beat Notes (osu! / Project Diva rhythm, notes shown ahead) | Deo | Testing | Ranking pending playtests | [04](04-fight-box-modes.md) |
| 2026-11-21 | Tap Tempo (faster, slower, rhythm; position doesn't matter) | Deo | Testing | Ranking pending playtests. Rhythm as call and response (the fish taps a bar, you repeat it): confirmed by Deo (2026-11-22) | [04](04-fight-box-modes.md) |
| 2026-11-21 | Flip, as Claude read it (boxes swap and turn upside down every few seconds) | Deo, Claude | Replaced | Not what Deo meant: "less of a flip, more 'you lost the ref box'". Replaced by Lost Ref | [04](04-fight-box-modes.md) |
| 2026-11-22 | Lost Ref (boxes pulse, bottom box goes out red with an arrow up, play in the top box only; then the top flashes yellow, arrow down, a second in the bottom box with no reference, then normal) | Deo | Testing | The challenge Deo wants is losing the reference box, so the player has no second box to read | [04](04-fight-box-modes.md) |
| 2026-11-21 | Shake the phone, rub fallback without a sensor | Deo | Testing | Ranking pending playtests | [04](04-fight-box-modes.md) |
| 2026-11-21 | Reel Spin (circle to reel, ease off on runs) | Claude | Testing | The "spin" from the mechanic vocabulary; a reel is the most fishing-like gesture | [04](04-fight-box-modes.md) |
| 2026-11-21 | Hookset (flick on the ring the way the arrow points; X = don't) | Claude | Testing | The "flick" from the mechanic vocabulary, as the bite; tests the Sanbi decoy idea | [04](04-fight-box-modes.md) |
| 2026-11-21 | Tilt steering as a main input | Claude | Cut | Research found touch performs best and tilt only comes close; motion stays a side flavour (Shake) | [04](04-fight-box-modes.md) |
| 2026-11-21 | Save the testers' "How hard?" ratings | Claude | Kept | Deo said go ahead (2026-11-22): ratings and results now add up over sessions (save format v2) | [04](04-fight-box-modes.md), [SAVE_FORMAT](../SAVE_FORMAT.md) |
| 2026-11-21 | On-screen difficulty guess per mode (1–5) | Claude | Replaced | Replaced by the difficulty slider: a mode isn't one difficulty, each can be easy or hard (Deo, 2026-11-22) | [04](04-fight-box-modes.md) |
| 2026-11-22 | Difficulty slider under the carousel (0 easy to 10 hard); every mode has `[easy, hard]` tuning | Deo | Kept | Each mode can be easy or hard, so difficulty can later be set per fish | [04](04-fight-box-modes.md#difficulty) |
| 2026-11-22 | Each fish sets its own difficulty per mode; tackle can lower it | Deo, Claude | Open | Follows from the slider; Deo's direction ("adjust those settings per fish later"), details to design | [04](04-fight-box-modes.md) |
| 2026-11-22 | Save format policy: change freely until alpha, prepare to lock it for 1.0 heading into beta | Deo | Kept | No players' progress to protect before alpha *(inferred)*; 1.0 players need saves that keep working | [SAVE_FORMAT](../SAVE_FORMAT.md) |
| 2026-11-21 | Fights as sequences of mode segments; tackle edits the tuning numbers | Claude | Open | Proposal; depends on which modes survive playtests | [04](04-fight-box-modes.md) |
| 2026-11-22 | Fish test screen replaces the "Cast (placeholder)" button | Deo (issue #16) | Kept | Test every fish the way the fight-box test tests every mode | [06](06-fish-fights.md) |
| 2026-11-22 | Every fish fights in sections; each section is one mode with a difficulty range | Deo (issue #16) | Testing | Lets simple fish have one section and harder fish chain several, each tuned per fish | [06](06-fish-fights.md) |
| 2026-11-22 | Difficulty climbs through a section's range as its segment fills | Claude | Kept | The fish fights harder as it tires; Deo: it makes sense from a UX perspective | [06](06-fish-fights.md) |
| 2026-11-22 | Bell-curve difficulty (peaks mid-section, eases back), chosen per fish | Deo | Kept | Some fish should burn out instead of climbing; set per fish with `curve` | [06](06-fish-fights.md) |
| 2026-11-22 | Strong sections carry over: a head start for the next section, scaled by accuracy | Deo | Kept | Rewards good play right away (dopamine) and makes streaks easier to keep while chasing harder fish | [06](06-fish-fights.md) |
| 2026-11-22 | Catch streak in the fish test, kept across fish | Deo, Claude | Testing | Deo's goal: accumulate streaks and chase harder fish. Whether a streak earns anything is open | [06](06-fish-fights.md) |
| 2026-11-22 | No difficulty slider on the fish test | Deo | Kept | Difficulty is set per fish, in the data | [06](06-fish-fights.md) |
| 2026-11-22 | Drop-downs instead of carousels on both test screens | Deo | Kept | During prototyping, screen space is kept free for the tooling and debugging that playtests will add (Deo) | [04](04-fight-box-modes.md), [06](06-fish-fights.md) |
| 2026-11-22 | "How hard?" 1–5 rating boxes | Claude | Cut | The difficulty slider does the work (Deo); catch time, losses and accuracy measure difficulty | [04](04-fight-box-modes.md) |
| 2026-11-22 | Fish-test catches add the fish and pearls to the save | Claude | Kept | Keeps what the Cast placeholder proved: catches and pearls flowing into the save *(inferred)* | [06](06-fish-fights.md) |
