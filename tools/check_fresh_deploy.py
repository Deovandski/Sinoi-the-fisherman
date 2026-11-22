#!/usr/bin/env python3
"""Fake-deploy check for the web build's offline worker (issue #18).

After an export and the post-export step:
    python3 tools/check_fresh_deploy.py site [--chrome /usr/bin/google-chrome]

It copies site/ to a temp folder, serves it like GitHub Pages does (browsers
may keep files for 10 minutes), installs the game's service worker in a fresh
headless Chrome, then "deploys": changes play/index.html, play/index.js and
the worker's CACHE_VERSION (as every real export does). It checks that:
  1. the first visit after the deploy runs the new page and script;
  2. once the browser updates the worker, the saved copies are the new ones;
  3. the game still opens offline;
  4. the landing page isn't controlled by the game's worker.
Prints a table and exits 1 if any check fails. Needs Python Playwright
(pip install playwright) and Chrome or Chromium.
"""
import argparse
import asyncio
import functools
import http.server
import pathlib
import re
import shutil
import sys
import tempfile
import threading

MARK = "__sinoiDeploy"


class PagesLikeHandler(http.server.SimpleHTTPRequestHandler):
    """max-age=600 and Last-Modified, like GitHub Pages."""

    def end_headers(self):
        self.send_header("Cache-Control", "max-age=600")
        super().end_headers()

    def log_message(self, *args):
        pass


def fake_deploy(play: pathlib.Path) -> None:
    html = (play / "index.html").read_text(encoding="utf-8")
    html = html.replace("</head>", '<meta name="sinoi-deploy" content="2"></head>', 1)
    # A real export renames the script too (index.js?v=<new CACHE_VERSION>).
    html = re.sub(r'src="index\.js\?v=([^"]*)"', r'src="index.js?v=\1-deploy2"', html, count=1)
    (play / "index.html").write_text(html, encoding="utf-8")
    with open(play / "index.js", "a", encoding="utf-8") as f:
        f.write(f"\n;self.{MARK} = 2;\n")
    sw = (play / "index.service.worker.js").read_text(encoding="utf-8")
    (play / "index.service.worker.js").write_text(
        re.sub(r"const CACHE_VERSION = '([^']*)';", r"const CACHE_VERSION = '\1-deploy2';", sw, count=1), encoding="utf-8")


STATE_JS = """async () => {
    const saved = [];
    for (const key of await caches.keys()) {
        const r = await (await caches.open(key)).match('index.js');
        saved.push(r ? (await r.text()).includes('MARK') : null);
    }
    return {
        page: document.querySelector('meta[name="sinoi-deploy"]') ? 2 : 1,
        script: self.MARK || 1,
        saved_new: saved.length > 0 && saved.every((v) => v === true),
        caches: saved.length,
        controlled: !!navigator.serviceWorker.controller,
        engine: typeof Engine !== 'undefined',
    };
}""".replace("MARK", MARK)


async def run(base: str, play: pathlib.Path, chrome: str, profile: str) -> list:
    from playwright.async_api import async_playwright
    rows = []
    async with async_playwright() as p:
        ctx = await p.chromium.launch_persistent_context(profile, executable_path=chrome, args=[
            "--no-sandbox", "--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"])
        page = ctx.pages[0]

        async def visit(label: str, wait=6000):
            await page.goto(base + "play/")
            await page.wait_for_timeout(wait)
            rows.append((label, await page.evaluate(STATE_JS)))

        await page.goto(base + "play/")
        await page.wait_for_timeout(9000)   # worker installs; Godot reloads once
        await visit("before the deploy")
        fake_deploy(play)
        await visit("1st visit after the deploy")
        await page.evaluate("navigator.serviceWorker.getRegistration().then((r) => r.update())")
        await page.wait_for_timeout(9000)
        await visit("after the worker updates")
        await ctx.set_offline(True)
        await visit("offline")
        await ctx.set_offline(False)
        await page.goto(base)
        await page.wait_for_timeout(1500)
        rows.append(("landing page", {"controlled": await page.evaluate("!!navigator.serviceWorker.controller")}))
        await ctx.close()
    return rows


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("site")
    parser.add_argument("--chrome", default="/usr/bin/google-chrome")
    args = parser.parse_args()
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="sinoi-deploy-"))
    site = tmp / "root" / "Sinoi-the-fisherman"
    shutil.copytree(args.site, site)
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(PagesLikeHandler, directory=str(tmp / "root")))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    base = f"http://127.0.0.1:{server.server_address[1]}/Sinoi-the-fisherman/"
    try:
        rows = asyncio.run(run(base, site / "play", args.chrome, str(tmp / "profile")))
    finally:
        server.shutdown()
        shutil.rmtree(tmp, ignore_errors=True)
    state = dict(rows)
    checks = [
        ("1st visit after a deploy runs the new page", state["1st visit after the deploy"]["page"] == 2),
        ("1st visit after a deploy runs the new script", state["1st visit after the deploy"]["script"] == 2),
        ("after the worker updates, saved copies are new", state["after the worker updates"]["saved_new"]),
        ("offline: the new game still opens", state["offline"]["engine"] and state["offline"]["script"] == 2),
        ("landing page isn't controlled by the game's worker", not state["landing page"]["controlled"]),
    ]
    print("| Step | Page | Script | Saved copies new | Controlled |")
    print("| --- | --- | --- | --- | --- |")
    for label, s in rows:
        if "page" in s:
            print(f"| {label} | v{s['page']} | v{s['script']} | {'yes' if s['saved_new'] else 'no'} ({s['caches']} cache) | {'yes' if s['controlled'] else 'no'} |")
        else:
            print(f"| {label} | | | | {'yes' if s['controlled'] else 'no'} |")
    print()
    for label, ok in checks:
        print(("PASS " if ok else "FAIL ") + label)
    if not all(ok for _, ok in checks):
        sys.exit(1)


if __name__ == "__main__":
    main()
