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
- **Saves:** any change to save data bumps `SaveManager.VERSION`, adds a `_migrate()` step, updates `docs/SAVE_FORMAT.md` and the tests.
- **Fish names:** real fish, translated into two languages, chopped and joined (tuna: *maguro* + *atum* = Magatum). Canon fish (Sanbi, Fihi, Ptaina, True Sanbi King) keep their names.
- Keep the support text and Amazon link (`https://www.amazon.com/dp/B0BT5XM4QC`) wherever the credits appear.

## Commands

```
godot --headless --path game --import                                   # first run / after adding assets
godot --headless --path game -s res://tests/test_save_manager.gd        # tests (must pass)
godot --headless --path game --export-release "Web" ../build/web/index.html
```

CI: `.github/workflows/pages.yml` (tests + web export + Pages), `.github/workflows/android.yml` (debug APK artifact).

## Style

GDScript with tabs, typed variables where practical, `snake_case` files and functions, one responsibility per script. Data (fish, gear, regions, fares) goes in data files, not code. Plain, short docs.
