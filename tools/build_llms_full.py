#!/usr/bin/env python3
"""Build site/llms-full.txt: the text of every website page in one plain file.

Run at deploy time, after the web export (pages.yml does it), so the file
never goes stale:
    python3 tools/build_llms_full.py site

Reads the pages listed in PAGES, keeps headings, paragraphs, list items and
links (made absolute), and drops navigation, scripts, styles, the photo
viewer, the game canvas and anything marked aria-hidden. The Play page is the Godot export, which has no
readable text, so it contributes its title, description and <noscript> line.
"""
import html.parser
import pathlib
import sys
import urllib.parse

SITE_URL = "https://deovandski.github.io/Sinoi-the-fisherman/"

# (file under site/, public URL path). Add a page here and in sitemap.xml.
PAGES = [
    ("index.html", ""),
    ("play/index.html", "play/"),
    ("privacy.html", "privacy.html"),
]

SKIP_TAGS = {"script", "style", "nav", "dialog", "canvas", "svg", "template", "button"}
BLOCK_TAGS = {"p", "li", "h1", "h2", "h3", "h4", "footer", "section", "div", "noscript", "figcaption", "td", "th"}


class PageText(html.parser.HTMLParser):
    def __init__(self, page_url: str) -> None:
        super().__init__(convert_charrefs=True)
        self.page_url = page_url
        self.title = ""
        self.description = ""
        self.lines: list[str] = []
        self._buf: list[str] = []
        self._skip = 0
        self._skip_tag = ""
        self._in_title = False
        self._in_head = False
        self._link: str | None = None
        self._link_text: list[str] = []
        self._prefix = ""

    # -- helpers --------------------------------------------------------------
    def _flush(self) -> None:
        text = " ".join("".join(self._buf).split())
        if text:
            self.lines.append(self._prefix + text)
        self._buf = []
        self._prefix = ""

    def _write(self, text: str) -> None:
        if self._link is not None:
            self._link_text.append(text)
        else:
            self._buf.append(text)

    # -- parser events ----------------------------------------------------------
    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == "head":
            self._in_head = True
        if tag == "title":
            self._in_title = True
        if tag == "meta" and a.get("name") == "description":
            self.description = a.get("content", "")
        if self._in_head:
            return
        if self._skip:
            if tag == self._skip_tag:
                self._skip += 1  # same tag nested inside the skipped one
            return
        if tag in SKIP_TAGS or a.get("aria-hidden") == "true":
            self._skip, self._skip_tag = 1, tag
            return
        if tag in BLOCK_TAGS:
            self._flush()
            if tag in {"h1", "h2", "h3", "h4"}:
                self._prefix = "#" * (int(tag[1]) + 1) + " "
            elif tag == "li":
                self._prefix = "- "
        elif tag == "br":
            self._buf.append(" ")
        elif tag == "a" and a.get("href"):
            self._link = urllib.parse.urljoin(self.page_url, a["href"])
            self._link_text = []
        elif tag == "img" and a.get("alt"):
            self._write(f"[Picture: {a['alt']}]")

    def handle_endtag(self, tag):
        if tag == "head":
            self._in_head = False
        if tag == "title":
            self._in_title = False
        if self._in_head:
            return
        if self._skip:
            if tag == self._skip_tag:
                self._skip -= 1
            return
        if tag == "a" and self._link is not None:
            text = " ".join("".join(self._link_text).split())
            link, self._link = self._link, None
            if text:
                self._buf.append(f"[{text}]({link})")
        elif tag in BLOCK_TAGS:
            self._flush()

    def handle_data(self, data):
        if self._in_title:
            self.title += data
            return
        if self._in_head or self._skip:
            return
        self._write(data)

    def close(self):
        super().close()
        self._flush()


def page_markdown(site: pathlib.Path, file: str, path: str) -> str:
    url = SITE_URL + path
    parser = PageText(url)
    parser.feed((site / file).read_text(encoding="utf-8"))
    parser.close()
    out = [f"# {' '.join(parser.title.split())}", "", f"URL: {url}"]
    if parser.description:
        out += ["", f"> {parser.description}"]
    body = [line for line in parser.lines if line.strip()]
    if body:
        out += [""] + "\n\n".join(body).split("\n")
    return "\n".join(out)


def main(folder: str) -> None:
    site = pathlib.Path(folder)
    parts = [
        "# Sinoi the Fisherman — full site text",
        "",
        f"> All pages of {SITE_URL} as plain text, generated at deploy time. "
        "Index: " + SITE_URL + "llms.txt",
    ]
    for file, path in PAGES:
        if not (site / file).exists():
            sys.exit(f"missing {site / file}: export the web build first")
        parts += ["", "---", "", page_markdown(site, file, path)]
    out = site / "llms-full.txt"
    out.write_text("\n".join(parts) + "\n", encoding="utf-8")
    print(f"wrote {out} ({out.stat().st_size} bytes, {len(PAGES)} pages)")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
