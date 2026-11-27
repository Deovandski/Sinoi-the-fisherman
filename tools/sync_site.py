#!/usr/bin/env python3
"""Keep the website's shared pieces in step with their one source.

    python3 tools/sync_site.py          # rewrite the pieces in site/*.html
    python3 tools/sync_site.py --check  # exit 1 if any piece is out of date (CI)

Each piece sits between markers in the page:
    <!-- one-source:NAME -->  ...  <!-- /one-source:NAME -->
and is rebuilt from:
    header       tools/site_parts/header.html (every page): the top bar, the
                 gear and the Settings dialog (Language, App, Stats for nerds);
                 the language list comes from i18n/<lang>/meta.json
    languages    in each page's <head>: which translations are ready (for
                 lang.js) and, on indexed pages, hreflang links for search
                 engines, worked out by tools/i18n.py from i18n/<lang>/
    footer       tools/site_parts/footer.html (every page)
    install-app  tools/site_parts/install-app.html: the Install app button,
                 also in the Settings App row (landing page)
    support      game/data/credits.json, the support text and links the game's
                 title screen shows too (landing page)
    description  "description" in game/data/credits.json: the landing page's
                 meta description and link preview (og:description)
    hero         the same "description": the landing page's hero paragraph
    privacy      PRIVACY.md, the privacy policy (privacy page), rendered by
                 markdown_html(): headings, paragraphs, lists, bold, links,
                 inline code and HTML comments (dropped)
Outside the pages it also writes "description" into the summary line of
site/llms.txt (the "> " line under the title) and "tagline" into
config/description in game/project.godot.
Pieces are written without indentation; each one is indented like its
opening marker. In a piece, {root} is the way back to the site root from that
page ("./" or "../") and {home} the landing page before a #link ("" on the
landing page itself, so its links stay in-page).
See CLAUDE.md, "One source".
"""
import html
import json
import os
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SITE = ROOT / "site"
# Every page with shared pieces, and its {root}: the way back to site/.
PAGES = {"index.html": "./", "privacy.html": "./", "debug/index.html": "../"}
PARTS = ROOT / "tools/site_parts"


def part(name: str) -> str:
    return (PARTS / name).read_text(encoding="utf-8").rstrip("\n")


def indent(text: str, by: str) -> str:
    return "\n".join(by + line if line.strip() else line for line in text.split("\n"))


def credits() -> dict:
    return json.loads((ROOT / "game/data/credits.json").read_text(encoding="utf-8"))


def i18n():
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import i18n as module  # tools/i18n.py (needs lxml)
    return module


def language_options() -> str:
    tools = i18n()
    options = ['<option value="en" lang="en">English</option>']
    for code in tools.codes():
        meta = tools.load_meta(code)
        options.append(f'<option value="{code}" lang="{html.escape(meta.get("html_lang", code))}">{html.escape(meta.get("name", code))}</option>')
    return "\n".join(options)


def piece_header() -> str:
    text = part("header.html")
    for line in text.split("\n"):
        if line.strip() == "{language_options}":
            text = text.replace(line, indent(language_options(), line[: len(line) - len(line.lstrip())]))
    for line in text.split("\n"):
        if line.strip() == "{install_app}":
            text = text.replace(line, indent(part("install-app.html"), line[: len(line) - len(line.lstrip())]))
    return text


def piece_footer() -> str:
    return part("footer.html")


def piece_install_app() -> str:
    return part("install-app.html")


def piece_support() -> str:
    c = credits()
    links = c["links"]
    return "\n".join([
        '<div class="support">',
        f'  <p>{html.escape(c["support_text"], quote=False)}</p>',
        '  <div class="actions">',
        f'    <a class="btn" href="{html.escape(links["amazon"])}">eBooks on Amazon</a>',
        f'    <a class="btn" href="{html.escape(links["world_lore"])}">Host a West March campaign</a>',
        "  </div>",
        "</div>",
    ])


def inline(text: str) -> str:
    """**bold**, `code` and [links](url) in one line of Markdown, HTML-escaped."""
    parts = re.split(r"(`[^`]+`)", text)
    out = []
    for part in parts:
        if part.startswith("`") and part.endswith("`") and len(part) > 1:
            out.append(f"<code>{html.escape(part[1:-1], quote=False)}</code>")
            continue
        s = html.escape(part, quote=False)
        s = re.sub(r"\[([^\]]+)\]\(([^)\s]+)\)", lambda m: f'<a href="{html.escape(m.group(2))}">{m.group(1)}</a>', s)
        s = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", s)
        out.append(s)
    return "".join(out)


def markdown_html(text: str) -> str:
    """The small Markdown subset PRIVACY.md uses, as the privacy page's HTML: "# " is the page's <h2>, "## " an <h3>,
    "- " list items, other lines paragraphs. The first paragraph is the lede and "Last updated …" is muted."""
    text = re.sub(r"<!--.*?-->", "", text, flags=re.S)
    out, para, items = [], [], []

    def flush():
        if para:
            body = inline(" ".join(para))
            cls = ' class="lede"' if not any(line.startswith("<p") for line in out) else (
                ' class="muted"' if para[0].startswith("Last updated") else "")
            out.append(f"<p{cls}>{body}</p>")
            para.clear()
        if items:
            out.append('<ul class="plain">')
            out.extend(f"  <li>{inline(i)}</li>" for i in items)
            out.append("</ul>")
            items.clear()

    for line in text.split("\n"):
        s = line.strip()
        if not s:
            flush()
        elif s.startswith("## "):
            flush()
            out += ["", f"<h3>{inline(s[3:])}</h3>"]
        elif s.startswith("# "):
            flush()
            out.append(f"<h2>{inline(s[2:])}</h2>")
        elif s.startswith("- "):
            if para:
                flush()
            items.append(s[2:])
        elif items:
            items[-1] += " " + s
        else:
            para.append(s)
    flush()
    return "\n".join(out)


def piece_description() -> str:
    d = html.escape(credits()["description"])
    return f'<meta name="description" content="{d}">\n<meta property="og:description" content="{d}">'


def piece_hero() -> str:
    return f'<p class="lead">{html.escape(credits()["description"], quote=False)}</p>'


def other_files() -> list:
    """(path, regex for the line, the line it should be) for one-source lines outside the pages."""
    c = credits()
    tagline = c["tagline"].replace("\\", "\\\\").replace('"', '\\"')
    return [
        (ROOT / "site/llms.txt", re.compile(r"^> .*$", re.M), "> " + c["description"]),
        (ROOT / "game/project.godot", re.compile(r'^config/description=".*"$', re.M), f'config/description="{tagline}"'),
    ]


def piece_privacy() -> str:
    return markdown_html((ROOT / "PRIVACY.md").read_text(encoding="utf-8"))


PIECES = {"header": piece_header, "footer": piece_footer, "install-app": piece_install_app, "support": piece_support,
          "privacy": piece_privacy, "description": piece_description, "hero": piece_hero, "languages": None}
# The languages piece counts translated text on the pages as written, so it goes in a second pass.
PASSES = [[n for n in PIECES if n != "languages"], ["languages"]]


def sync(text: str, page: str, names: list) -> tuple[str, list[str]]:
    changed = []
    root = PAGES[page]
    home = "" if page == "index.html" else root
    for name in names:
        pattern = re.compile(r"^([ \t]*)(<!-- one-source:%s .*?-->\n)(.*?)(\n[ \t]*<!-- /one-source:%s -->)" % (re.escape(name), re.escape(name)), re.S | re.M)
        match = pattern.search(text)
        if not match:
            continue
        built = i18n().alternates(page) if name == "languages" else PIECES[name]()
        wanted = indent(built.replace("{root}", root).replace("{home}", home), match.group(1))
        if match.group(3) != wanted:
            text = text[:match.start(3)] + wanted + text[match.end(3):]
            changed.append(f"{page}: {name}")
    return text, changed


def main() -> None:
    check = "--check" in sys.argv[1:]
    stale = []
    for names in PASSES:
        for page in PAGES:
            path = SITE / page
            text, changed = sync(path.read_text(encoding="utf-8"), page, names)
            stale += changed
            if changed and not check:
                path.write_text(text, encoding="utf-8")
    for path, pattern, wanted in other_files():
        text = path.read_text(encoding="utf-8")
        m = pattern.search(text)
        if not m:
            sys.exit(f"{path.relative_to(ROOT)}: no line matching {pattern.pattern}")
        if m.group(0) != wanted:
            stale.append(f"{path.relative_to(ROOT)}: description")
            if not check:
                path.write_text(text[:m.start()] + wanted + text[m.end():], encoding="utf-8")
    for item in stale:
        print(("out of date: " if check else "updated: ") + item)
    if check and stale:
        sys.exit("Run python3 tools/sync_site.py and commit the result.")
    if not stale:
        print("site: shared pieces are up to date")


if __name__ == "__main__":
    main()
