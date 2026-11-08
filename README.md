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

- a title screen with a placeholder **Cast** button that adds random catches;
- a **fight-box touch test**: interactive pad, shadow pad, two-finger tracking and a catch meter;
- **JSON save export and import** on the web (download / file picker) and on Android (system file picker, with a clipboard fallback);
- automatic local saving (browser storage on the web, private app storage on Android).

## Repository layout

```
game/                 Godot 4.7 project (GDScript)
  scenes/             scenes (.tscn)
  scripts/            game scripts; scripts/autoload/save_manager.gd handles saves
  tests/              headless tests, run in CI
site/                 the website (GitHub Pages); CI adds the web build at site/play/game/
docs/
  white-paper/        research and design direction (the white paper in progress)
  art/                illustrator brief: sprite sizes, animation, Godot export rules
  BUILDING.md         how to build, test and sign the web and Android versions
  SAVE_FORMAT.md      the JSON save format
.github/workflows/    web build + Pages deploy, Android debug APK
```

## Build and run

You need [Godot 4.7](https://godotengine.org) (standard build, not .NET).

- **Run:** open `game/project.godot` in Godot and press F5.
- **Test:** `godot --headless --path game -s res://tests/test_save_manager.gd`
- **Web build:** `godot --headless --path game --export-release "Web" ../build/web/index.html`, then serve `build/web/` with any static server.
- **Android:** see [docs/BUILDING.md](docs/BUILDING.md) for the Android SDK, JDK 17 and signing setup. Every push to `main` also builds a debug APK (Actions tab > *Android debug build* > Artifacts).

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
