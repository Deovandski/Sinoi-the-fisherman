#!/usr/bin/env python3
"""Write site/stats.json: facts about this build for the "Stats for nerds" page (site/debug/, #22).

    python3 tools/build_stats.py site     # after the web export and build_llms_full.py (CI runs it)

The page reads this file so the browser never has to work these out:
    code   which commit and pull request the build came from, when, and with which tools
    site   pages, files and size of what gets deployed
    game   name and version (game/project.godot), Godot version and renderer, the web
           export under play/ (size, files, export date, cache version), save format, content
    i18n   how much of each website translation is done (tools/i18n.py, by words)
Commit, branch, pull request and repository are left out when the repo is private
(GitHub Actions says so in its event file); a local build reads them from git.
Ported from Deovandski/Deovandski-repo-template tools/stats.ts. stats.json is not
committed (.gitignore): it describes one build. See "Stats for nerds" in CLAUDE.md.
"""
import datetime
import json
import os
import pathlib
import platform
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
RENDERERS = {"gl_compatibility": "GL Compatibility", "mobile": "Mobile", "forward_plus": "Forward+"}


def read_json(path):
    try:
        return json.loads(pathlib.Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None


def git(*args):
    try:
        out = subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True, check=True).stdout.strip()
        return out or None
    except (OSError, subprocess.CalledProcessError):
        return None


def iso(ts: float) -> str:
    return datetime.datetime.fromtimestamp(ts, datetime.timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def godot_version():
    v = os.environ.get("GODOT_VERSION")
    if v:
        return v
    try:
        out = subprocess.run(["godot", "--version"], capture_output=True, text=True, timeout=20).stdout.strip()
        return re.match(r"[\d.]+", out).group(0).rstrip(".") if out else None
    except (OSError, subprocess.SubprocessError, AttributeError):
        return None


def code_facts():
    env = os.environ
    ci = env.get("GITHUB_ACTIONS") == "true"
    event = read_json(env["GITHUB_EVENT_PATH"]) if env.get("GITHUB_EVENT_PATH") else None
    event = event or {}
    private = (event.get("repository") or {}).get("private") is not False if ci else False  # unknown in CI counts as private
    head = event.get("head_commit") or {}
    commit = env.get("GITHUB_SHA") or git("rev-parse", "HEAD")
    message = head.get("message") or git("log", "-1", "--format=%B")
    subject = message.split("\n")[0] if message else None
    # "Merge pull request #18 from …" (merge) or "Title (#18)" (squash); on a pull_request run, the event has it.
    pr = (event.get("pull_request") or {}).get("number")
    if not pr and subject:
        m = re.search(r"Merge pull request #(\d+)", subject) or re.search(r"\(#(\d+)\)\s*$", subject)
        pr = int(m.group(1)) if m else None
    remote = git("config", "--get", "remote.origin.url") or ""
    m = re.search(r"github\.com[/:]([^/]+/[^/]+?)(\.git)?$", remote)
    repo = env.get("GITHUB_REPOSITORY") or (m.group(1) if m else None)
    repo_url = f"{env.get('GITHUB_SERVER_URL') or 'https://github.com'}/{repo}" if repo else None
    run_id = env.get("GITHUB_RUN_ID")
    code = {
        "builtAt": iso(datetime.datetime.now(datetime.timezone.utc).timestamp()),
        "builtBy": "GitHub Actions" if ci else "local build",
        "public": (not private) if ci else None,
        "run": int(env["GITHUB_RUN_NUMBER"]) if ci and env.get("GITHUB_RUN_NUMBER") else None,
        "runUrl": f"{repo_url}/actions/runs/{run_id}" if ci and not private and repo_url and run_id else None,
        "tools": {"python": platform.python_version(), "godot": godot_version()},
    }
    if not private:
        code.update({
            "repo": repo,
            "repoUrl": repo_url,
            "branch": env.get("GITHUB_HEAD_REF") or env.get("GITHUB_REF_NAME") or git("rev-parse", "--abbrev-ref", "HEAD"),
            "commit": commit,
            "commitUrl": f"{repo_url}/commit/{commit}" if repo_url and commit else None,
            "commitDate": head.get("timestamp") or git("log", "-1", "--format=%cI"),
            "commitSubject": subject,
            "pr": pr,
            "prUrl": f"{repo_url}/pull/{pr}" if repo_url and pr else None,
        })
    return code


def tally(folder: pathlib.Path):
    files, size, by_type = 0, 0, {}
    for f in sorted(folder.rglob("*")):
        if not f.is_file() or f.name == "stats.json":
            continue
        n = f.stat().st_size
        files += 1
        size += n
        ext = f.suffix[1:].lower() or "(none)"
        t = by_type.setdefault(ext, {"files": 0, "bytes": 0})
        t["files"] += 1
        t["bytes"] += n
    return files, size, dict(sorted(by_type.items(), key=lambda kv: -kv[1]["bytes"]))


def site_facts(site: pathlib.Path):
    """Pages, files and size. The translated copies (site/<lang>/) count once built."""
    sitemap = (site / "sitemap.xml").read_text(encoding="utf-8") if (site / "sitemap.xml").exists() else ""
    locs = re.findall(r"<loc>([^<]+)</loc>", sitemap)
    files, size, by_type = tally(site)
    return {
        "url": locs[0].rstrip("/") if locs else None,
        "pages": len(locs),
        "htmlFiles": by_type.get("html", {}).get("files", 0),
        "files": files,
        "bytes": size,
        "byType": by_type,
    }


def game_facts(site: pathlib.Path):
    project = (ROOT / "game/project.godot").read_text(encoding="utf-8")
    setting = lambda key: (re.search(r'^%s="([^"]*)"' % re.escape(key), project, re.M) or [None, None])[1]
    save = (ROOT / "game/scripts/autoload/save_manager.gd").read_text(encoding="utf-8")
    save_version = re.search(r"^const VERSION\s*:?=\s*(\d+)", save, re.M)
    fish = (read_json(ROOT / "game/data/fish.json") or {}).get("fish") or {}
    modes = (read_json(ROOT / "game/data/fight_modes.json") or {}).get("modes") or []
    game = {
        "name": setting("config/name"),
        "version": setting("config/version"),
        "godot": godot_version(),
        "renderer": RENDERERS.get(setting("renderer/rendering_method") or "", setting("renderer/rendering_method")),
        "saveFormat": int(save_version.group(1)) if save_version else None,
        "fish": len(fish),
        "fightModes": len(modes),
        "web": None,
    }
    play = site / "play"
    if (play / "index.html").exists():
        files, size, _ = tally(play)
        worker = play / "index.service.worker.js"
        cache = re.search(r"CACHE_VERSION = '([^']*)'", worker.read_text(encoding="utf-8")) if worker.exists() else None
        cache_version = cache.group(1) if cache else None
        # Godot's cache version starts with the export time (Unix seconds); else the newest file in play/.
        stamp = re.match(r"(\d{9,})", cache_version or "")
        exported = int(stamp.group(1)) if stamp else max(f.stat().st_mtime for f in play.iterdir() if f.is_file())
        game["web"] = {"files": files, "bytes": size, "exportedAt": iso(exported), "cacheVersion": cache_version}
    return game


def main() -> None:
    site = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ROOT / "site")
    if not (site / "index.html").exists():
        sys.exit(f"{site} has no index.html: pass the site folder.")
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import i18n  # tools/i18n.py (needs lxml)
    stats = {"code": code_facts(), "site": site_facts(site), "game": game_facts(site), "i18n": i18n.language_stats(site)}
    (site / "stats.json").write_text(json.dumps(stats, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    c, s, g = stats["code"], stats["site"], stats["game"]
    print(f"stats.json: {c['builtBy']}"
          + (f" @ {c['commit'][:7]}" if c.get("commit") else "")
          + (f" (PR #{c['pr']})" if c.get("pr") else "")
          + f" · {s['files']} files, {s['bytes'] / 1048576:.1f} MB"
          + (f" · web build {g['web']['bytes'] / 1048576:.1f} MB" if g["web"] else " · no web build"))


if __name__ == "__main__":
    main()
