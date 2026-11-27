#!/usr/bin/env python3
"""Translations of the website, written ahead of time and kept in i18n/<lang>/ (#2).

A port of HusbandOutWorld's tools/i18n.py (the same store format, hashing and
rules) for this site's plain HTML pages. English stays the source: the pages in
site/ are written in English, and `build` writes a translated copy of each one
at site/<lang>/<page> during the deploy (not committed).

How it works
- Each English page is split into segments: every element that holds text
  directly (a paragraph, heading, list item, button, label, option, caption, ...)
  plus a few attributes (alt, title, aria-label, placeholder) and the page
  description. Each segment is keyed by a short hash of its English HTML.
- A segment's translation is looked up by that hash. One with no translation
  stays in English, marked lang="en", so a half-translated language still works.
- English that doesn't change keeps its hash, so it's never translated twice:
  only new or edited segments show up in `todo`.
- Anything with translate="no" (or inside it) is left alone: the debug terminal,
  language names, code. <script>, <style>, <svg>, <code>, <pre> and <noscript>
  are never translated.

Store layout (i18n/<lang>/)
  meta.json          the language's name, <html lang>, direction and the banner
  glossary.json      how names and recurring terms are written (read by whoever translates)
  _shared.json       segments on more than one page (header, Settings, footer)
  pages/<page>.json  everything else: {"<hash>": {"en": "<English HTML>", "t": "<translation>"}}

Command line
  python3 tools/i18n.py status                     what's translated, per language
  python3 tools/i18n.py todo --lang ja [--page index.html] [--max-words 6000] > work.json
                                                   only the segments still to translate
  python3 tools/i18n.py apply work.json            save the "t" fields of a work file
  python3 tools/i18n.py prune                      drop translations whose English is gone
  python3 tools/i18n.py build site                 write site/<lang>/ for every language (CI)
After `apply` or `prune`, run python3 tools/sync_site.py: it updates the language
links in each English page's head (search engines and the auto-select read them).
"""
import argparse
import hashlib
import html
import json
import os
import posixpath
import re
import sys
from collections import Counter

from lxml import html as LH

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SITE = os.path.join(ROOT, "site")
STORE = os.path.join(ROOT, "i18n")
SITE_URL = "https://deovandski.github.io/Sinoi-the-fisherman/"
# Languages in menu order (issue #2). Each needs i18n/<code>/meta.json.
LANGUAGES = ["zh", "ja", "pt", "es", "ar", "ko"]
# English pages that get translated copies. /play/ is the game itself (one copy only).
PAGES = ["index.html", "privacy.html", "debug/index.html"]
# Pages kept out of search: no language links for them.
NOINDEX = {"debug/index.html"}

SKIP_TAGS = {"script", "style", "svg", "noscript", "template", "code", "pre", "textarea"}
ATTRS = ("alt", "title", "aria-label", "placeholder")
INDEX_COVERAGE = 0.9   # a language version is offered (auto-select, search engines) once this much is translated
LETTER = re.compile(r"[^\W\d_]")
URL_ATTRS = ("href", "src")


# ---------------------------------------------------------------- store

def norm(s):
    """Whitespace and quote style don't change a segment's meaning, so they don't change its hash."""
    s = s.replace("’", "'").replace("‘", "'").replace("“", '"').replace("”", '"')
    return re.sub(r"\s+", " ", s).strip()


def seg_hash(en_html):
    return hashlib.sha1(norm(en_html).encode("utf-8")).hexdigest()[:12]


def load_meta(code):
    p = os.path.join(STORE, code, "meta.json")
    return json.load(open(p, encoding="utf-8")) if os.path.exists(p) else {}


def codes():
    return [c for c in LANGUAGES if os.path.exists(os.path.join(STORE, c, "meta.json"))]


def shard_files(code):
    base = os.path.join(STORE, code)
    out = [os.path.join(base, "_shared.json")]
    pages = os.path.join(base, "pages")
    if os.path.isdir(pages):
        out += sorted(os.path.join(pages, f) for f in os.listdir(pages) if f.endswith(".json"))
    return [p for p in out if os.path.exists(p)]


def load_store(code):
    """hash -> translated HTML, from every shard of one language."""
    out = {}
    for p in shard_files(code):
        for h, v in json.load(open(p, encoding="utf-8")).items():
            if isinstance(v, dict) and v.get("t"):
                out[h] = v["t"]
    return out


def page_shard(page):
    """'index.html' -> pages/index.json, 'debug/index.html' -> pages/debug.json"""
    slug = page[: -len("/index.html")] if page.endswith("/index.html") else page[: -len(".html")]
    return os.path.join("pages", slug.replace("/", "-") + ".json")


# ---------------------------------------------------------------- segments

def inner_html(el):
    return (html.escape(el.text, quote=False) if el.text else "") + "".join(
        LH.tostring(c, encoding="unicode", with_tail=True) for c in el)


def set_inner_html(el, frag_html):
    for c in list(el):
        el.remove(c)
    try:
        frag = LH.fragment_fromstring(frag_html, create_parent="div")
    except Exception:
        el.text = frag_html
        return
    el.text = frag.text
    for c in list(frag):
        el.append(c)


def has_direct_text(el):
    """Text right inside the element (not only in its children). Separators like " · " don't count."""
    if el.text and LETTER.search(el.text):
        return True
    return any(c.tail and LETTER.search(c.tail) for c in el)


def skipped(el):
    return not isinstance(el.tag, str) or el.tag in SKIP_TAGS or el.get("translate") == "no" or el.tag in ("link", "meta")


REL_ATTR = re.compile(r'\b(href|src)="([^"]*)"')


def is_relative(url):
    return bool(url) and not re.match(r"^([a-z][a-z0-9+.-]*:|//|#|/|~/)", url, re.I)


def to_canon(frag, page):
    """Links inside a segment, written from the site root ("~/privacy.html"), so the same header or footer has
    the same hash on every page, wherever the page sits."""
    def fix(m):
        url = m.group(2)
        if not is_relative(url):
            return m.group(0)
        path, rest = re.match(r"^([^?#]*)(.*)$", url).groups()
        target = posixpath.normpath(posixpath.join(posixpath.dirname(page), path or "."))
        target = "" if target == "." else target
        slash = "/" if (path.endswith("/") or path in ("", ".", "./")) and target else ""
        return f'{m.group(1)}="~/{target}{slash}{rest}"'
    return REL_ATTR.sub(fix, frag)


def from_canon(frag, page):
    """The other way: "~/privacy.html" back to a link relative to `page`."""
    def fix(m):
        url = m.group(2)
        if not url.startswith("~/"):
            return m.group(0)
        path, rest = re.match(r"^([^?#]*)(.*)$", url[2:]).groups()
        rel = posixpath.relpath(path or ".", posixpath.dirname(page) or ".")
        if path.endswith("/") or path == "":
            rel = "./" if rel == "." else rel.rstrip("/") + "/"
        return f'{m.group(1)}="{rel}{rest}"'
    return REL_ATTR.sub(fix, frag)


def segments(doc, page):
    """Yield (element, attribute or None, English text/HTML) for every translatable piece of a page. Links inside
    the HTML are written from the site root (to_canon)."""
    def walk(el):
        if skipped(el):
            return
        for a in ATTRS:
            v = el.get(a)
            if v and LETTER.search(v):
                yield el, a, v
        if el.tag not in ("html", "head", "body") and has_direct_text(el):
            if LETTER.search(el.text_content() or ""):
                yield el, None, to_canon(inner_html(el), page)
            return  # attributes of descendants are part of this element's HTML
        for c in el:
            yield from walk(c)
    head = doc.find("head")
    if head is not None:
        for m in head.iter("meta"):
            if (m.get("name") == "description" or m.get("property") in ("og:title", "og:description")) and m.get("content"):
                yield m, "content", m.get("content")
    yield from walk(doc)


def text_words(s):
    return len(re.sub(r"<[^>]+>", " ", s).split())


def read_page(site, page):
    return open(os.path.join(site, page), encoding="utf-8").read()


def inventory(site=SITE):
    """hash -> {en, words, pages[]} over every English page."""
    segs = {}
    for page in PAGES:
        doc = LH.document_fromstring(read_page(site, page))
        for _el, _attr, en in segments(doc, page):
            h = seg_hash(en)
            s = segs.setdefault(h, {"en": en, "words": text_words(en), "pages": []})
            if page not in s["pages"]:
                s["pages"].append(page)
    return segs


def coverage(segs, store, page):
    total = done = 0
    for h, s in segs.items():
        if page in s["pages"]:
            w = s["words"] or 1
            total += w
            done += w if h in store else 0
    return done / total if total else 1.0


def ready_languages(page, site=SITE):
    """Languages translated enough to offer for this page."""
    segs = inventory(site)
    return [c for c in codes() if coverage(segs, load_store(c), page) >= INDEX_COVERAGE]


# ---------------------------------------------------------------- pages

def page_url(page, code=None):
    """'index.html' -> the page's address, in English or in a language."""
    path = page[: -len("index.html")] if page.endswith("index.html") else page
    return SITE_URL + (f"{code}/" if code else "") + path


def alternates(page, site=SITE):
    """<head> lines for an English page: language links for search engines and the ready list for lang.js."""
    ready = ready_languages(page, site)
    lines = [f'<meta name="site-langs" content="{" ".join(ready)}">']
    if ready and page not in NOINDEX:
        lines.append(f'<link rel="alternate" hreflang="en" href="{page_url(page)}">')
        lines.append(f'<link rel="alternate" hreflang="x-default" href="{page_url(page)}">')
        for c in ready:
            lines.append(f'<link rel="alternate" hreflang="{load_meta(c).get("html_lang", c)}" href="{page_url(page, c)}">')
    return "\n".join(lines)


def page_target(path):
    """Normalise a site path to the page it opens: '' and 'x/' -> 'index.html' and 'x/index.html'."""
    if path in ("", "."):
        return "index.html"
    if path.endswith("/"):
        return path + "index.html"
    return path


def rewrite_url(url, page, code):
    """A relative link on the English page `page`, rewritten for its copy at <code>/<page>: links to translated
    pages stay inside the language, everything else (the game, styles, pictures, files) points at the one copy."""
    if not url or re.match(r"^([a-z][a-z0-9+.-]*:|//|#|/)", url, re.I):
        return url
    m = re.match(r"^([^?#]*)(.*)$", url)
    path, rest = m.group(1), m.group(2)
    if path == "":
        return url
    target = posixpath.normpath(posixpath.join(posixpath.dirname(page), path))
    target = "" if target == "." else target
    is_dir = path.endswith("/") or path in (".", "./")
    full = page_target(target + "/" if is_dir and target else target)
    here = posixpath.dirname(f"{code}/{page}")
    if full in PAGES:
        dest = f"{code}/{target}" if target else code
        rel = posixpath.relpath(dest, here)
    else:
        rel = posixpath.relpath(target or ".", here)
    if is_dir:
        rel = (rel.rstrip("/") + "/") if rel != "." else "./"
    return rel + rest


def translate_page(text, page, code, meta, store, ready):
    """English page HTML -> (translated page HTML, coverage 0..1)."""
    doc = LH.document_fromstring(text)
    total = done = 0
    for el, attr, en in list(segments(doc, page)):
        w = text_words(en) or 1
        total += w
        t = store.get(seg_hash(en))
        if not t:
            if attr is None:
                el.set("lang", "en")  # still English: say so (screen readers, and left to right inside Arabic)
                if meta.get("dir") == "rtl":
                    el.set("dir", "ltr")
            continue
        done += w
        if attr:
            el.set(attr, t)
        else:
            set_inner_html(el, from_canon(t, page))
    for el in doc.iter():
        if not isinstance(el.tag, str):
            continue
        if el.tag == "meta" and el.get("property") == "og:image" and el.get("content"):
            el.set("content", rewrite_url(el.get("content"), page, code))
        for a in URL_ATTRS:
            v = el.get(a)
            if v:
                el.set(a, rewrite_url(v, page, code))
    root = doc.getroottree().getroot()
    root.set("lang", meta.get("html_lang", code))
    root.set("dir", meta.get("dir", "ltr"))
    root.set("data-lang", code)
    head = doc.find("head")
    cov = (done / total) if total else 1.0
    for link in list(head.iter("link")):
        if link.get("rel") == "canonical":
            link.set("href", page_url(page, code))
        if link.get("rel") == "alternate" and link.get("hreflang"):
            head.remove(link)  # the English page's language links; rebuilt below
    if page not in NOINDEX and code in ready:
        head.append(LH.fragment_fromstring(f'<link rel="alternate" hreflang="x-default" href="{page_url(page)}">'))
        for c in ["en"] + ready:
            hreflang = "en" if c == "en" else load_meta(c).get("html_lang", c)
            head.append(LH.fragment_fromstring(f'<link rel="alternate" hreflang="{hreflang}" href="{page_url(page, None if c == "en" else c)}">'))
    elif page not in NOINDEX and head.find(".//meta[@name='robots']") is None:
        head.append(LH.fragment_fromstring('<meta name="robots" content="noindex">'))  # not translated enough yet
    # the AI-translation banner, right under the top bar
    top = doc.find(".//header")
    if top is not None and meta.get("banner"):
        back = posixpath.relpath(page_target(page), posixpath.dirname(f"{code}/{page}"))
        if back.endswith("index.html"):
            back = back[: -len("index.html")] or "./"
        banner = LH.fragment_fromstring(
            f'<div class="i18n-banner" role="note">{html.escape(meta["banner"], quote=False)} '
            f'<a href="{back}" data-lang-switch="en" hreflang="en" lang="en" translate="no">'
            f'{html.escape(meta.get("english", "English"))}</a></div>')
        top.addnext(banner)
    out = LH.tostring(doc, encoding="unicode", method="html", doctype="<!doctype html>")
    return out, cov


# ---------------------------------------------------------------- command line

def language_stats(site=SITE):
    """How much of each language is translated, by words, for stats.json ("Stats for nerds")."""
    segs = inventory(site)
    words = sum(s["words"] for s in segs.values())
    out = []
    for code in codes():
        st, meta = load_store(code), load_meta(code)
        done = [s for h, s in segs.items() if h in st]
        out.append({"code": code, "name": meta.get("name", code), "dir": meta.get("dir", "ltr"),
                    "percent": round(1000 * sum(s["words"] for s in done) / max(1, words)) / 10,
                    "segments": len(done),
                    "pagesReady": sum(1 for p in PAGES if coverage(segs, st, p) >= INDEX_COVERAGE)})
    return {"english": {"pages": len(PAGES), "segments": len(segs), "words": words},
            "indexCoverage": INDEX_COVERAGE, "languages": out}


def cmd_status(a):
    segs = inventory()
    words = sum(s["words"] for s in segs.values())
    print(f"English: {len(PAGES)} pages, {len(segs)} segments, {words:,} words")
    for code in codes():
        st = load_store(code)
        done = sum(s["words"] for h, s in segs.items() if h in st)
        waiting = sum(1 for h in segs if h not in st)
        per_page = " · ".join(f"{p} {100 * coverage(segs, st, p):.0f}%" for p in PAGES)
        print(f"{code}: {100 * done / max(1, words):.0f}% · {waiting} segments waiting · {per_page}")


def cmd_todo(a):
    segs = inventory()
    st = load_store(a.lang)
    items, budget = [], a.max_words or 10 ** 9
    for h, s in segs.items():
        if h in st or (a.page and a.page not in s["pages"]):
            continue
        if items and s["words"] > budget:
            break
        budget -= s["words"]
        items.append({"h": h, "page": s["pages"][0], "en": s["en"], "t": ""})
    json.dump({"lang": a.lang, "glossary": f"i18n/{a.lang}/glossary.json",
               "rules": 'Translate "en" into "t". Keep every HTML tag and attribute exactly (only translate visible text and '
                        'alt/title text). Write names as glossary.json says. Leave "t" empty to skip.',
               "items": items}, sys.stdout, ensure_ascii=False, indent=1)
    sys.stdout.write("\n")
    print(f"{len(items)} segments, {sum(text_words(i['en']) for i in items):,} words", file=sys.stderr)


def tag_shape(s):
    return Counter(re.findall(r"<(/?[a-z0-9]+)", s or ""))


def write_shard(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(dict(sorted(data.items())), f, ensure_ascii=False, indent=1)
        f.write("\n")


def cmd_apply(a):
    segs = inventory()
    work = json.load(open(a.file, encoding="utf-8"))
    code = work["lang"]
    base = os.path.join(STORE, code)
    shards, saved, warned = {}, 0, 0
    for it in work["items"]:
        t = (it.get("t") or "").strip()
        if not t:
            continue
        h = it["h"]
        if tag_shape(t) != tag_shape(it["en"]):
            print(f'warning: {h} ({it["page"]}): the HTML tags differ from the English; check it', file=sys.stderr)
            warned += 1
        s = segs.get(h, {"pages": [it["page"]]})
        rel = "_shared.json" if len(s["pages"]) > 1 else page_shard(s["pages"][0])
        path = os.path.join(base, rel)
        if path not in shards:
            shards[path] = json.load(open(path, encoding="utf-8")) if os.path.exists(path) else {}
        shards[path][h] = {"en": it["en"], "t": t}
        saved += 1
    for path, data in shards.items():
        write_shard(path, data)
    print(f"{code}: saved {saved} translations into {len(shards)} files" + (f", {warned} to check" if warned else ""))


def cmd_prune(a):
    segs = inventory()
    for code in codes():
        dropped = 0
        for path in shard_files(code):
            data = json.load(open(path, encoding="utf-8"))
            keep = {h: v for h, v in data.items() if h in segs}
            dropped += len(data) - len(keep)
            if len(keep) != len(data):
                if keep:
                    write_shard(path, keep)
                else:
                    os.remove(path)
        print(f"{code}: dropped {dropped} translations of English that no longer exists")


def cmd_build(a):
    site = a.site
    segs = inventory(site)
    stores = {c: load_store(c) for c in codes()}
    for page in PAGES:
        ready = [c for c in codes() if coverage(segs, stores[c], page) >= INDEX_COVERAGE]
        for code in codes():
            if coverage(segs, stores[code], page) == 0:
                print(f"{code}/{page}: nothing translated yet, skipped")
                continue
            out, cov = translate_page(read_page(site, page), page, code, load_meta(code), stores[code], ready)
            path = os.path.join(site, code, page)
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w", encoding="utf-8") as f:
                f.write(out)
            print(f"{code}/{page}: {100 * cov:.0f}% translated")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("status")
    t = sub.add_parser("todo")
    t.add_argument("--lang", required=True)
    t.add_argument("--max-words", type=int)
    t.add_argument("--page")
    p = sub.add_parser("apply")
    p.add_argument("file")
    sub.add_parser("prune")
    b = sub.add_parser("build")
    b.add_argument("site", nargs="?", default=SITE)
    a = ap.parse_args()
    {"status": cmd_status, "todo": cmd_todo, "apply": cmd_apply, "prune": cmd_prune, "build": cmd_build}[a.cmd](a)


if __name__ == "__main__":
    main()
