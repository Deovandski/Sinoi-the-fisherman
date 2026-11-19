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
"""
import json
import pathlib
import sys

MANIFEST_EXTRA = {
    "short_name": "Sinoi",
    "id": "./",
    "scope": "./",
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


def patch_manifest(path: pathlib.Path) -> None:
    manifest = json.loads(path.read_text(encoding="utf-8"))
    for key, value in MANIFEST_EXTRA.items():
        manifest.setdefault(key, value)
    path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"manifest: {', '.join(sorted(manifest))}")


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
    patch_manifest(base / "index.manifest.json")
    patch_service_worker(base / "index.service.worker.js")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
