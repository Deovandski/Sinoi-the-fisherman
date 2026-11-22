# Building Sinoi the Fisherman

One Godot 4.7 project (`game/`) builds both versions:

| Version | Preset | Output | Made by |
| --- | --- | --- | --- |
| Browser | `Web` | `index.html` + `.wasm` + `.pck` | CI on every push to `main` (deployed to GitHub Pages), or locally |
| Android (testing) | `Android`, debug | debug-signed `.apk` | CI artifact on every push to `main`, or locally |
| Android (Google Play) | `Android`, release, Gradle + AAB | release-signed `.aab` | Locally only, with the private release keystore |

## Tools

- [Godot 4.7.x](https://godotengine.org) standard build (not .NET), plus its export templates (Editor > Manage Export Templates > Download).
- For Android: OpenJDK 17 (e.g. Eclipse Temurin) and the Android SDK (Android Studio's SDK Manager: platform-tools, build-tools 35.0.1, platform 35 and 36, command-line tools). In Godot: Editor > Editor Settings > Export > Android, set the Java SDK and Android SDK paths.

## Run and test

```
godot --path game                                                  # open the editor
godot --headless --path game --import                              # import assets (first run)
godot --headless --path game -s res://tests/test_save_manager.gd   # tests; exit code 1 on failure
```

## Web build (installable app)

```
mkdir -p site/play
godot --headless --path game --export-release "Web" ../site/play/index.html
python3 tools/web_postexport.py site/play
cd site && python3 -m http.server 8000                             # open http://localhost:8000/play/
```

- The `Web` preset is **single-threaded** (`variant/thread_support=false`), so it runs on GitHub Pages and any static host without special headers.
- It's a **PWA** (Progressive Web App): Godot writes `index.manifest.json`, `index.service.worker.js`, `index.offline.html` and the 144, 180 and 512 px icons from `game/web/`. Options: fullscreen, portrait, theme `#10243a`, offline page `game/web/offline.html`. `game/web/` has a `.gdignore`, so Godot doesn't import those files as game assets.
- `tools/web_postexport.py` must run after every export. It:
  - adds the short name, id, scope, description and theme color to the manifest;
  - writes `site/manifest.webmanifest`, the same app seen from the landing page, so *Install* works on `/` as well as `/play/`. Both share the id `/Sinoi-the-fisherman/` and the whole site as scope, so either page installs the same app, which opens into the game. **Never change the id**: a new id makes installed players' app a different app;
  - makes the service worker **network first** (issue #18): the page and every game file are fetched with `cache: 'no-cache'` (a cheap "not modified" when nothing changed), and the saved copy is used only offline (or, for the page, after 4 seconds). One online visit still caches the whole game, and the `/play/` folder URL works offline;
  - loads `index.js` as `index.js?v=<CACHE_VERSION>`, so a new page never runs the browser's in-memory copy of an old script;
  - takes the play page's meta description, the manifest description and the `<noscript>` text from `game/data/credits.json`.
- **Updates:** every export gets a new `CACHE_VERSION` (Godot stamps the time). The first visit after a deploy runs the new game, because pages and game files come from the network first. The new worker takes over at once and drops the old saved copies. Nothing progresses while the app is closed; only the files are cached. (Workers installed before issue #18 were cache first: on those, the title screen's *New version ready: tap to update* button appears once, then never again.)
- **Fake-deploy check:** `python3 tools/check_fresh_deploy.py site` (after the export) serves the site like GitHub Pages, installs the worker in headless Chrome, changes the page, the script and the worker, and checks the first visit picks them up, the saved copies update, offline still works and the landing page isn't controlled by the game's worker. CI runs it on every build; it needs `pip install playwright` and Chrome.
- The worker's scope is `play/` only: the landing page and `privacy.html` are plain pages. GitHub Pages lets browsers keep any page for up to 10 minutes, which we can't change.
- `site/play/` and `site/manifest.webmanifest` are generated (by CI or locally) and ignored by git.
- The engine download is about 10 MB gzipped; the first load can take a few seconds on phones.

### Shared pieces (one source)

- The landing page's support block and every page's footer are rebuilt from one source by `python3 tools/sync_site.py`: the support text and links from `game/data/credits.json` (the same file the game's title screen reads), the footer from `tools/site_parts/footer.html`. The pieces sit between `<!-- one-source:NAME -->` markers; don't edit them in the page. CI fails if they're out of date (`--check`).

### Pages for AI readers and search engines

- `site/llms.txt` (an index in the [llms.txt](https://llmstxt.org/) format) and `site/sitemap.xml` are **hand-written**. Update both when a page is added to `site/` or a doc moves.
- `site/llms-full.txt` is **generated** at deploy time by `tools/build_llms_full.py` from the pages listed in its `PAGES` list (text only: no navigation, scripts or photo viewer). Add new pages to that list. Locally: `python3 tools/build_llms_full.py site` after the web export.
- Every page's head carries `<link rel="canonical">`, `<link rel="alternate" type="text/markdown" href="llms.txt">` and the sitemap link; the Play page gets them from the Web preset's `html/head_include`, and `tools/web_postexport.py` adds its meta description and replaces Godot's bare `<noscript>` line with a description and a link home.
- A project site's own `robots.txt` is ignored (crawlers only read the domain root), so the sitemap has to be submitted by hand: Bing Webmaster Tools and Google Search Console.

### Testing the PWA

- Chrome DevTools > Application > Manifest at `/` and at `/play/`: no installability errors, and the same *Computed App ID*.
- Load `/play/` once online, then turn the connection off (DevTools > Network > Offline) and reload: the game must start.
- Install it (browser menu > *Install app* / *Add to Home screen*) and check the fight-box touch test with two fingers.

## Android debug build (test phones)

Godot creates a debug keystore automatically the first time you export. With a phone in developer mode and USB debugging on:

- One click: the Android button in the editor's top-right toolbar builds and installs on the connected phone.
- Command line: `godot --headless --path game --export-debug "Android" ../build/android/sinoi-debug.apk`, then `adb install -r build/android/sinoi-debug.apk`.
- From CI: Actions > *Android debug build* > latest run > Artifacts > `sinoi-the-fisherman-debug-apk`. Unzip and install with `adb install -r`.

Debug builds can't be uploaded to Google Play.

## Android release build (Google Play)

Release signing happens **only on the maintainer's machine**. The release keystore and its passwords must never be committed or added to CI unless as encrypted GitHub secrets, decided deliberately.

1. Create the release keystore once and back it up in two offline places plus a password manager (losing it blocks future updates):
   ```
   keytool -genkeypair -v -keystore ~/keys/sinoi-release.keystore -alias sinoi -keyalg RSA -keysize 2048 -validity 10000
   ```
2. In the Android preset, enable **Gradle build** (Project > Install Android Build Template) and set the export format to **AAB**. The installed `game/android/` folder is ignored by git.
3. Provide the keystore through environment variables (preferred) instead of typing it into the preset:
   ```
   export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=~/keys/sinoi-release.keystore
   export GODOT_ANDROID_KEYSTORE_RELEASE_USER=sinoi
   export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=...
   godot --headless --path game --export-release "Android" ../build/android/sinoi.aab
   ```
   If you enter them in the editor instead, Godot stores them in `game/.godot/export_credentials.cfg`, which is ignored by git. Check `git status` before committing anyway.
4. Google Play requires new apps and updates to target **Android 16 (API 36)** since August 31, 2026; Godot 4.7's template targets API 36. The requirement rises every August.

## Package name

The Android package name is `com.wizarddeo.sinoithefisherman` (in `game/export_presets.cfg`). It becomes permanent once the app is uploaded to Google Play, so confirm it before the first upload.
