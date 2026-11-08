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

## Web build

```
godot --headless --path game --export-release "Web" ../build/web/index.html
cd build/web && python3 -m http.server 8000                        # open http://localhost:8000
```

- The `Web` preset is **single-threaded** (`variant/thread_support=false`), so it runs on GitHub Pages and any static host without special headers.
- CI exports into `site/play/game/`; `site/play/index.html` frames it in a portrait stage. Locally exported files under `build/` and `site/play/game/` are ignored by git.
- The engine download is about 10 MB gzipped; the first load can take a few seconds on phones.

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
