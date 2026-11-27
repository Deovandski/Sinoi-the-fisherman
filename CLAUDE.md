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

## One source

Anything shown in two places (the same text, widget or game on two pages, or in the game and on the website) comes from one source, never a pasted copy. If a copy really has to stay, say why in the PR and get Deo's OK.
- Credits, support text, links and the game's descriptions: `game/data/credits.json`. The game reads it; `tools/web_postexport.py` uses the `tagline` for the play page and manifest; `tools/sync_site.py` writes the landing page's support block, the `description` into the landing page's meta description, link preview and hero paragraph and the summary line of `site/llms.txt`, and the `tagline` into `config/description` in `game/project.godot`.
- Website header (top bar, gear and Settings dialog with the language list), footer and the Install app block: `tools/site_parts/` (`header.html`, `footer.html`, `install-app.html`), written into every page in `PAGES` of `tools/sync_site.py`. In a piece, `{root}` is the way back to the site root (`./` or `../`) and `{home}` the landing page before a `#link`. Edit pieces between `<!-- one-source:NAME -->` markers only through their source, then run `python3 tools/sync_site.py` (CI runs `--check`).
- The privacy policy: `PRIVACY.md`. `tools/sync_site.py` renders it into `site/privacy.html` (a small Markdown subset: headings, paragraphs, `- ` lists, bold, links, inline code). Edit the Markdown, never the page. Keep its wording as it is when you can: each changed paragraph needs translating again.
- Fish, modes and currency: `game/data/*.json`. `site/llms-full.txt` is generated from the pages. `site/llms.txt` (except its "> " summary line, from `credits.json`) and `site/sitemap.xml` stay hand-written and change with the pages.
- One copy of the game: the website's `/play/` is the only web build.

## Fresh after every deploy

The game's offline worker is network first (`tools/web_postexport.py`): pages and game files come from the network with `cache: 'no-cache'`, and the saved copy is used only offline. Keep it that way. A file may be served saved-copy-first only if its name changes with every build. After touching the worker or the export, run `python3 tools/check_fresh_deploy.py site` (CI runs it too).

## Nudge the lore, don't dump it

In-game lore (journal teasers, notices, descriptions) should make curious players want more, then point them to the series' website (`links.series` in `game/data/credits.json`, https://husbandoutworld.com/).
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

## Translations

The website is translated into Chinese (Simplified), Japanese, Portuguese (Brazil), Spanish (Spain), Arabic and Korean, ahead of time, in `i18n/<lang>/`. The game's strings are ready for translation (`game/i18n/messages.pot`); its `.po` files come later (#2). English is the source of both.
- **Edit English only.** Never hold back an English change for translations: changed text shows in English on the translated pages (marked `lang="en"`) until the next batch. Don't hand-edit the stores to keep up with an English edit unless asked.
- **Game strings go through `tr()`.** Every player-visible string in `game/scripts/` is a literal inside `tr("…")` (format after: `tr("Caught %d") % n`), `tr_n("%d fish", "%d fish", n)` for counts, or `TranslationServer.translate("…")` in static functions. Data the game shows (fish names, regions, lore, mode names and hints, quality and ball names) is passed through `tr()` where it's shown, and `tools/game_pot.py` reads it from `game/data/`. After changing strings run `python3 tools/game_pot.py` (CI runs `--check`). The test reports testers copy (`ui/results_text.gd`) stay English. No text baked into art; leave UI room for text about 30% longer than English; all text uses the project's default font, so CJK and Arabic fallbacks can be added in one place.
- **Website text** needs nothing special: every element with text in `site/index.html`, `site/privacy.html` and `site/debug/index.html` is a segment, keyed by a hash of its English. `translate="no"` keeps something in English (language names, the debug terminal, code). A new page that should be translated goes in `PAGES` of `tools/i18n.py`.
- **When asked to translate:** for each language run `python3 tools/i18n.py todo --lang <lang> > work.json`, fill each `"t"`, then `python3 tools/i18n.py apply work.json`. Then `python3 tools/i18n.py prune` and `python3 tools/sync_site.py` (it updates which languages each page offers) and commit `i18n/` and `site/`. `python3 tools/i18n.py status` shows what's left. CI builds `site/<lang>/` at deploy (`tools/i18n.py build site`, not committed) and never blocks on missing translations.
- **Translation rules:** names, places, coins and canon fish are written by sound in zh/ja/ko/ar and kept as in English in pt/es, as `i18n/<lang>/glossary.json` spells them (world names come from HusbandOutWorld's glossaries; the series wins). "Sinoi the Fisherman", the series title and real names stay in English (`keep_as_is`). The currency "balls" uses each language's own word for ball (issue #2). Keep every HTML tag, link (`~/…` is the site root), number, `{placeholder}` and `%d`/`%s` exactly; translate only visible text. Game buttons the pages mention (*Export save*) stay in English until the game is translated.
- **Languages on the site:** the Settings menu has the language list (names from `i18n/<lang>/meta.json`), `site/lang.js` opens the visitor's browser language on a first visit and remembers a choice made in Settings (localStorage, in `PRIVACY.md`), and every translated page has the AI-translation banner from `meta.json` with a link back to English. A language is offered (auto-select, `hreflang`) once a page is 90% translated. Check layout changes in Arabic too: it runs right to left, so use `margin-inline-start` and friends, not left/right.
- **Adding a language:** `i18n/<code>/meta.json` and `glossary.json` (copy the series' spellings from HusbandOutWorld), add the code to `LANGUAGES` in `tools/i18n.py`, `site/sitemap.xml`, `site/llms.txt` and `.gitignore`, then translate.

## Stats for nerds (debug page)

Settings (the gear, top right of every page) › **DEBUG** opens `site/debug/`: a terminal that types out build, game, browser, network and page-speed facts. Nothing is saved or sent; it only asks the site for `stats.json` (privacy paragraph in `PRIVACY.md`, which also feeds `site/privacy.html`).
- Where things live: the page `site/debug/index.html`; its script `site/debug/debug.js`; the terminal `site/terminal-screen.js` + `.css` (reusable); build facts `site/stats.json`, written by `python3 tools/build_stats.py site` in CI after the export (not committed). Ported from Deovandski-repo-template (#19 there).
- **To add a line:** add `<div class="term-row"><span class="term-k">Label</span><span class="term-v" data-v="key">...</span></div>` under its `== SECTION ==` heading in `site/debug/index.html`, then `set('key', text)` in `site/debug/debug.js`. If it's a build fact, add it to `tools/build_stats.py` and read it in `fromStats()`. Every value must fill in: show `n/a` when the browser won't say, never leave `...`.
- Kept out of search on purpose: `noindex, nofollow`, and **not** in `sitemap.xml`, `llms.txt` or `build_llms_full.py` (the exception to "Website pages for AI readers"; CI checks it). Commit, branch, PR and repo are left out of `stats.json` when the repo is private.
- The Languages section shows how much of each translation is done (from `tools/i18n.py`, via `stats.json`). Words the script writes live in the page's hidden `.debug-words` block.

## Commands

```
godot --headless --path game --import                                   # first run / after adding assets
godot --headless --path game -s res://tests/test_save_manager.gd        # tests (must pass)
godot --headless --path game -s res://tests/test_fight_modes.gd
godot --headless --path game -s res://tests/test_fish_fights.gd
mkdir -p site/play && godot --headless --path game --export-release "Web" ../site/play/index.html && python3 tools/web_postexport.py site/play
python3 tools/build_llms_full.py site                                   # after the export
python3 tools/build_stats.py site                                       # after the export: stats.json for the debug page
python3 tools/check_fresh_deploy.py site                                # fake deploy: fresh page/script, offline (needs playwright + Chrome)
python3 tools/sync_site.py                                              # after editing credits.json, PRIVACY.md, tools/site_parts/ or i18n/
python3 tools/game_pot.py                                               # after changing game strings (tr()) or shown data
python3 tools/i18n.py status                                            # translations: what's left (todo / apply / prune / build)
```

CI: `.github/workflows/pages.yml` (tests + web export as an installable PWA + Pages), `.github/workflows/android.yml` (debug APK artifact).

## Style

GDScript with tabs, typed variables where practical, `snake_case` files and functions, one responsibility per script. Data (fish, gear, regions, fares) goes in data files, not code. Plain, short docs.
