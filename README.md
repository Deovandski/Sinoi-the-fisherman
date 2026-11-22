# Sinoi the Fisherman

An active, touch-first pixel-art fishing game set in the world of the [#HusbandOutWorld](https://github.com/Deovandski/HusbandOutWorld) series. Free, no ads, no in-app purchases, and open source.

**Website and browser version:** https://deovandski.github.io/Sinoi-the-fisherman/ · **Status:** pre-production, production starts Q1 2027

> **Made for touch screens.** The game is designed first for Android phones and tablets, and later fights need up to two fingers at once. The browser version works with a mouse for testing, but a mouse can only act as one finger.

## What the game is

- **Short, full-attention sessions.** Play for a few minutes, then put it down. No idle progress, no timers, no gacha: every catch is earned by playing.
- **The fight box.** Fish are fought on a small trackpad-like box: trace the fish, tap and release on cue, flick against runs, spin to reel, and later use two fingers (index and middle). A shadow copy above the box shows what your fingers cover. Inspired by Stardew Valley's fishing and by rhythm games such as osu!.
- **Bait and tackle.** Like Stardew Valley, the right bait decides what bites and the right tackle is how you beat the hardest fish. Timing-forgiveness settings exist for accessibility, not as the way to win.
- **The world of Vraki.** Regions, fish and hazards from canon lore: the docks of Sanbi, the man-eating Fihi of Lukewarm Lake, the Ptaina of the deep and the legendary True Sanbi King. Lore summaries live in the [Vraki West March Campaign](https://github.com/Deovandski/Vraki-West-March-Campaign-D-D).
- **One Godot project, two builds.** Godot 4.7 exports both the Android app and the browser version on the website.

## What's in this build

The current build is a pre-production shell that proves the pipeline:

- a **fish test**: pick any fish in the game from a drop-down and fight it. Each fish fights in one or more **sections** (a segmented meter); each section is a fight-box mode with its own difficulty range. Catches add the fish and its pearls to the save (see [chapter 06](docs/white-paper/06-fish-fights.md));
- a **fight-box playground** with nine modes to try and rank (Slide Guide, Shake, Tap Tempo, Reel Spin, Hookset, Hold Hop, Lost Ref, Beat Notes, Twin Drift), picked from a drop-down at the top. A **difficulty slider** (0 easy to 10 hard) sets how hard each mode plays. Each has an interactive pad, a shadow pad, a catch meter, results kept in the save, and a **Copy** button that puts your results on the clipboard to send back (see [chapter 04](docs/white-paper/04-fight-box-modes.md));
- **JSON save export and import** on the web (download / file picker) and on Android (system file picker, with a clipboard fallback);
- automatic local saving (browser storage on the web, private app storage on Android);
- **install as an app** from the browser (a PWA): it opens straight into the game, works with no signal after the first load, and offers an in-game button when a new version is ready.

## Repository layout

```
game/                 Godot 4.7 project (GDScript)
  scenes/             scenes (.tscn)
  data/               data files (fight_modes.json: fight-box modes and tuning; fish.json: every fish and its sections)
  scripts/            game scripts; scripts/autoload/save_manager.gd handles saves,
                      scripts/fight/ holds the fight-box modes
  tests/              headless tests, run in CI
site/                 the website (GitHub Pages); CI exports the game into site/play/ (installable app)
  google0c08003a2b869d98.html  Google Search Console verification: never remove or edit it
docs/
  white-paper/        research and design direction (the white paper in progress)
  art/                illustrator brief: sprite sizes, animation, Godot export rules
  BUILDING.md         how to build, test and sign the web and Android versions
  SAVE_FORMAT.md      the JSON save format
tools/                web_postexport.py: finishes the PWA export (manifest, offline cache)
.github/workflows/    web build + Pages deploy, Android debug APK
```

## Build and run

You need [Godot 4.7](https://godotengine.org) (standard build, not .NET).

- **Run:** open `game/project.godot` in Godot and press F5.
- **Test:** `godot --headless --path game -s res://tests/test_save_manager.gd`
- **Web build:** `mkdir -p site/play && godot --headless --path game --export-release "Web" ../site/play/index.html && python3 tools/web_postexport.py site/play`, then serve `site/` with any static server.
- **Android:** see [docs/BUILDING.md](docs/BUILDING.md) for the Android SDK, JDK 17 and signing setup. Every push to `main` also builds a debug APK (Actions tab > *Android debug build* > Artifacts).

### Google Search Console file

`site/google0c08003a2b869d98.html` proves to Google Search Console that this site is ours. **Never remove, rename or edit it.** Google re-checks it, and if it's gone the site stops being verified. CI fails the deploy if it's missing.

## Documentation

- [White paper (in progress)](docs/white-paper/README.md): market research, lore mapping, the fight box, bait and tackle, plan and roles.
- [Illustrator brief](docs/art/illustrator-brief.md): what to draw, at what size, and how to deliver it to Godot.
- [Building](docs/BUILDING.md) · [Save format](docs/SAVE_FORMAT.md) · [Contributing](CONTRIBUTING.md)

## Who makes it

Directed by Deovandski Skibinski Junior, author of #HusbandOutWorld and CEO/Founder of Wizard Deo Solutions, as technical architect. The code and docs are built with Claude agents under his direction ([AI disclosure](AI-DISCLOSURE.md)); final art is by the project's illustrator.

## Support

Brought to you by Deovandski, author of the #HusbandOutWorld series and CEO/Founder of Wizard Deo Solutions. Have fun! If you want to support me, buy the [eBooks on Amazon](https://www.amazon.com/dp/B0BT5XM4QC), or host a [West March D&D campaign](https://github.com/Deovandski/Vraki-West-March-Campaign-D-D) using the World Lore.

## License

- Game code: [MIT](LICENSE).
- Docs and original game content (art, fish designs, writing): CC BY-NC-SA 4.0, the same license as the #HusbandOutWorld source files. See [LICENSE](LICENSE) for what isn't covered, trademarks and permissions.
- [Privacy](PRIVACY.md) · [Security](SECURITY.md)
