#!/usr/bin/env python3
"""Finish Godot's web (PWA) export so the game installs cleanly and works offline.

Run after every web export:
    python3 tools/web_postexport.py site/play

1. Manifest: Godot 4.7 writes name, start_url, display, orientation,
   background_color and icons. This adds a short home-screen name, a stable
   id and scope, a description and the theme color.
2. Service worker: Godot's worker only pre-caches the small files at install
   time; the engine (.wasm) and game data (.pck) are cached the next time
   they're fetched through the worker, which means the game only works offline
   after a *second* online visit. This makes the install step cache them too,
   so one online visit is enough.
3. Service worker: Godot caches the page as "index.html", so opening the
   folder URL (/play/) with no signal found nothing and failed. Navigations
   now fall back to the cached index.html.
4. Landing page: writes site/manifest.webmanifest, the same app as seen from
   the site root, so "Install" also works from the landing page. Both
   manifests share one id and one scope (the whole site), so installing from
   either page gives the same app, which opens straight into the game.
"""
import json
import pathlib
import sys

# The id is resolved against the site's origin (deovandski.github.io), which
# other Deovandski sites share, so it must be specific to this game. Never
# change it once players have installed the app: a new id is a new app.
APP_ID = "/Sinoi-the-fisherman/"

MANIFEST_EXTRA = {
    "short_name": "Sinoi",
    "id": APP_ID,
    # The app covers the whole site (landing page + game), so the landing
    # page can offer the install and links between them stay in the app.
    "scope": "../",
    "description": "An active, touch-first pixel-art fishing game set in the world of #HusbandOutWorld.",
    "theme_color": "#10243a",
    "lang": "en",
    "categories": ["games"],
}

SW_PATCHES = [
    # (what Godot writes, what we want, why)
    ("cache.addAll(CACHED_FILES)", "cache.addAll(FULL_CACHE)",
     "install pre-caches the full game (wasm + pck)"),
    ("let cached = await cache.match(event.request);",
     "let cached = (await cache.match(event.request)) || (isNavigate ? await cache.match(CACHED_FILES[0]) : undefined);",
     "folder URL (/play/) falls back to the cached index.html"),
]


def patch_manifest(path: pathlib.Path) -> dict:
    manifest = json.loads(path.read_text(encoding="utf-8"))
    manifest.update(MANIFEST_EXTRA)
    path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"manifest: {', '.join(sorted(manifest))}")
    return manifest


def write_site_manifest(play_manifest: dict, play_dir: pathlib.Path) -> None:
    """Same app, with URLs relative to the site root instead of /play/."""
    prefix = play_dir.name + "/"
    site = dict(play_manifest)
    site["start_url"] = prefix + play_manifest["start_url"].removeprefix("./")
    site["scope"] = "./"
    site["icons"] = [dict(icon, src=prefix + icon["src"]) for icon in play_manifest["icons"]]
    out = play_dir.parent / "manifest.webmanifest"
    out.write_text(json.dumps(site, indent=2) + "\n", encoding="utf-8")
    print(f"site manifest: {out} (start_url {site['start_url']})")


def patch_service_worker(path: pathlib.Path) -> None:
    text = path.read_text(encoding="utf-8")
    for before, after, why in SW_PATCHES:
        if after in text:
            print(f"service worker: already patched ({why})")
            continue
        if text.count(before) != 1:
            sys.exit(f"service worker: expected one '{before}' in {path}; Godot's template changed, update this script")
        text = text.replace(before, after)
        print(f"service worker: {why}")
    path.write_text(text, encoding="utf-8")


def main(folder: str) -> None:
    base = pathlib.Path(folder)
    manifest = patch_manifest(base / "index.manifest.json")
    write_site_manifest(manifest, base)
    patch_service_worker(base / "index.service.worker.js")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
