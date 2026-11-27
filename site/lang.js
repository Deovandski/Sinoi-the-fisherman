/*
 * Languages (#2): opens the visitor's language on their first visit, and remembers a choice made in Settings.
 * Load it first in <head>, not deferred, so the switch happens before the English page paints:
 *   <script src="lang.js"></script>        (from a page in a folder: ../lang.js)
 * The ready languages come from <meta name="site-langs" content="ja pt ..."> (written by tools/sync_site.py from
 * tools/i18n.py: only languages translated enough for this page). Translated pages carry <html data-lang="ja">.
 * The choice is kept in this browser only (localStorage "sinoi-site"), never sent anywhere (PRIVACY.md).
 * Same rules as HusbandOutWorld's language auto-select: a saved choice wins; otherwise the first browser language
 * that is English or ready; English pages only, so a visitor who picks English stays there.
 * window.sinoiLang.go(code) switches the current page to another language (settings.js uses it).
 */
(function () {
  'use strict';
  var KEY = 'sinoi-site';
  var d = document.documentElement;
  var script = document.currentScript;
  var root = script ? new URL('./', script.src).pathname : '/';   // the site root, where lang.js lives
  var here = d.getAttribute('data-lang') || 'en';

  function load() { try { return JSON.parse(localStorage.getItem(KEY) || '{}') || {}; } catch (e) { return {}; } }
  function save(patch) {
    var s = load();
    for (var k in patch) s[k] = patch[k];
    try { localStorage.setItem(KEY, JSON.stringify(s)); } catch (e) { /* private mode: lasts for this page only */ }
  }
  /** This page's address in another language: /root/ja/privacy.html <-> /root/privacy.html */
  function href(code) {
    var path = location.pathname.indexOf(root) === 0 ? location.pathname.slice(root.length) : location.pathname.replace(/^\//, '');
    if (here !== 'en' && path.indexOf(here + '/') === 0) path = path.slice(here.length + 1);
    else if (here !== 'en' && path === here) path = '';
    return root + (code === 'en' ? '' : code + '/') + path + location.search + location.hash;
  }
  function go(code) {
    save({ lang: code });
    if (code !== here) location.href = href(code);
  }
  window.sinoiLang = { here: here, go: go, href: href };

  if (here !== 'en') return;
  var meta = document.querySelector('meta[name="site-langs"]');
  var ready = meta ? meta.content.split(/\s+/).filter(Boolean) : [];
  if (!ready.length) return;
  var want = load().lang;
  var wanted = navigator.languages || [navigator.language || ''];
  for (var i = 0; i < wanted.length && !want; i++) {
    var c = String(wanted[i]).toLowerCase().split('-')[0];
    if (c === 'en' || ready.indexOf(c) >= 0) want = c;
  }
  if (want && want !== 'en' && ready.indexOf(want) >= 0) location.replace(href(want));
})();
