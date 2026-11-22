# Instructions for Claude agents

This repo is **Sinoi the Fisherman**: an open-source, active, touch-first pixel-art fishing game in Godot 4.7 (GDScript), set in the #HusbandOutWorld world. Deovandski Skibinski Junior is the technical architect; agents work under his direction. Commit directly to `main` only when he asks; otherwise propose changes.

## Read before changing things

- `docs/white-paper/` — design decisions. Treat "decided" items as settled.
- `docs/art/illustrator-brief.md` — sprite sizes, canvases, tags, naming, folders. Placeholder art must follow it so final art drops in.
- `docs/SAVE_FORMAT.md` — the JSON save contract.
- Lore: `Deovandski/Vraki-West-March-Campaign-D-D` (World Lore summaries) and `Deovandski/HusbandOutWorld`. The series wins over anything here.

## Hard rules

- **Active play only:** no idle progress, no offline earnings, no energy timers, no gacha, no ads, no in-app purchases. No seasons, no day/night cycle.
- **Never commit secrets:** keystores, `export_credentials.cfg`, passwords, service-account JSON, `.env`. CI builds debug APKs only.
- **Touch first:** every interaction must work with touch; the fight box uses at most 2 fingers (index + middle of one hand) and must also work one-handed at the start. Mouse emulates one finger for testing.
- **Pixel rules:** base resolution 180 x 320 portrait, `canvas_items` stretch, integer scale, aspect `expand`, Nearest filtering. Draw at 1x.
- **Saves:** any change to save data bumps `SaveManager.VERSION`, adds a `_migrate()` step, updates `docs/SAVE_FORMAT.md` and the tests. Until alpha the format can change freely; heading into beta we prepare to lock it for 1.0 (policy in `docs/SAVE_FORMAT.md`).
- **Fish names:** real fish, translated into two languages, chopped and joined (tuna: *maguro* + *atum* = Magatum). Canon fish (Sanbi, Fihi, Ptaina, True Sanbi King) keep their names.
- **Never remove, rename or edit `site/google0c08003a2b869d98.html`:** it's the Google Search Console verification file. Google re-checks it, and removing it un-verifies the site.
- Keep the support text and Amazon link (`https://www.amazon.com/dp/B0BT5XM4QC`) wherever the credits appear.

## Nudge the lore, don't dump it

In-game lore (journal teasers, notices, descriptions) should make curious players want more, then point them to the series' website (`lore_link` in `game/data/fish.json`, https://husbandoutworld.com/).
- Keep it to a line or two: a hook, a name, a hint. Never a summary of the story.
- Facts come from the series and the World Lore (`Deovandski/HusbandOutWorld`, `Deovandski/Vraki-West-March-Campaign-D-D`); the series wins. New fish get flavour tied to canon places, not new canon.
- No spoilers from unreleased story notes. When unsure whether something may be revealed, ask Deo.

## Keep the white paper's record of ideas

During the research phase, every idea gets recorded, including the ones that don't make the cut.
- Add a row to `docs/white-paper/05-ideas-log.md` whenever an idea is proposed, kept, cut, replaced or changed: date, idea, who raised it, status, **why**, and where it's described.
- Record the reason, not just the result. If you worked the reason out yourself, mark it *(inferred)*. If you can't infer why, write **Why: ask Deo** and ask Deovandski, then fill in his answer.
- Keep the chapters in step: a decision belongs in its chapter, and a prototype's results go back into the chapter that describes it.

## Website pictures are clickable

On the website (`site/`, not the game), every picture opens bigger when pressed, in the one photo viewer (`site/photo-viewer.js`, `site/photo-viewer.css`, and the `<dialog id="photo-viewer">` in `site/index.html`). It's the same standard as Deovandski/Deovandski, Deovandski-repo-template, HusbandOutWorld and Vraki-West-March-Campaign-D-D.
- Any `<img>` with alt text opens by itself, and so does a link straight to an image file. Give screenshots and art real alt text; `alt=""` means decorative, and those don't open.
- The viewer shows the date under the caption when it knows one: `data-date="YYYY-MM-DD"` on the picture, or a `YYYY-MM-DD` at the start of its file name.
- Opt out with `data-no-zoom`. A new page in `site/` that shows pictures loads the viewer the same way `index.html` does.

## Website pages for AI readers

A new page in `site/` also needs: an entry in `site/sitemap.xml` and `site/llms.txt` (both hand-written), an entry in `PAGES` in `tools/build_llms_full.py`, and in its head a `<meta name="description">`, `<link rel="canonical">`, `<link rel="alternate" type="text/markdown" href="llms.txt">` and the sitemap link. See `docs/BUILDING.md`.

## Commands

```
godot --headless --path game --import                                   # first run / after adding assets
godot --headless --path game -s res://tests/test_save_manager.gd        # tests (must pass)
godot --headless --path game -s res://tests/test_fight_modes.gd
godot --headless --path game -s res://tests/test_fish_fights.gd
mkdir -p site/play && godot --headless --path game --export-release "Web" ../site/play/index.html && python3 tools/web_postexport.py site/play
python3 tools/build_llms_full.py site                                   # after the export
```

CI: `.github/workflows/pages.yml` (tests + web export as an installable PWA + Pages), `.github/workflows/android.yml` (debug APK artifact).

## Style

GDScript with tabs, typed variables where practical, `snake_case` files and functions, one responsibility per script. Data (fish, gear, regions, fares) goes in data files, not code. Plain, short docs.
