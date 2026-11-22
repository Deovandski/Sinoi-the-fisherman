#!/usr/bin/env python3
"""Keep the website's shared pieces in step with their one source.

    python3 tools/sync_site.py          # rewrite the pieces in site/*.html
    python3 tools/sync_site.py --check  # exit 1 if any piece is out of date (CI)

Each piece sits between markers in the page:
    <!-- one-source:NAME -->  ...  <!-- /one-source:NAME -->
and is rebuilt from:
    footer   tools/site_parts/footer.html (every page)
    support  game/data/credits.json, the support text and links the game's
             title screen shows too (landing page)
See CLAUDE.md, "One source".
"""
import html
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SITE = ROOT / "site"
PAGES = ["index.html", "privacy.html"]


def credits() -> dict:
    return json.loads((ROOT / "game/data/credits.json").read_text(encoding="utf-8"))


def piece_footer() -> str:
    return (ROOT / "tools/site_parts/footer.html").read_text(encoding="utf-8").rstrip("\n")


def piece_support() -> str:
    c = credits()
    links = c["links"]
    return "\n".join([
        '    <div class="support">',
        f'      <p>{html.escape(c["support_text"], quote=False)}</p>',
        '      <div class="actions">',
        f'        <a class="btn" href="{html.escape(links["amazon"])}">eBooks on Amazon</a>',
        f'        <a class="btn" href="{html.escape(links["world_lore"])}">Host a West March campaign</a>',
        "      </div>",
        "    </div>",
    ])


PIECES = {"footer": piece_footer, "support": piece_support}


def sync(text: str, page: str) -> tuple[str, list[str]]:
    changed = []
    for name, build in PIECES.items():
        pattern = re.compile(r"(<!-- one-source:%s .*?-->\n)(.*?)(\n[ \t]*<!-- /one-source:%s -->)" % (name, name), re.S)
        match = pattern.search(text)
        if not match:
            continue
        wanted = build()
        if match.group(2) != wanted:
            text = text[:match.start(2)] + wanted + text[match.end(2):]
            changed.append(f"{page}: {name}")
    return text, changed


def main() -> None:
    check = "--check" in sys.argv[1:]
    stale = []
    for page in PAGES:
        path = SITE / page
        text, changed = sync(path.read_text(encoding="utf-8"), page)
        stale += changed
        if changed and not check:
            path.write_text(text, encoding="utf-8")
    for item in stale:
        print(("out of date: " if check else "updated: ") + item)
    if check and stale:
        sys.exit("Run python3 tools/sync_site.py and commit the result.")
    if not stale:
        print("site: shared pieces are up to date")


if __name__ == "__main__":
    main()
