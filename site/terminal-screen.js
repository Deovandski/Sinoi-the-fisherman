/*
 * TerminalScreen: an old-school computer terminal (green phosphor on black, amber headings) that types its text
 * out one character at a time, fast, the way old PCs filled the screen.
 * Ported from Deovandski/Deovandski-repo-template src/components/reusable/TerminalScreen.astro
 * (Deovandski-repo-template#19) to plain JavaScript for this static site (#22). Built for "Stats for nerds" (/debug/).
 *
 * Usage:
 *   <link rel="stylesheet" href="terminal-screen.css">
 *   <script src="terminal-screen.js" defer></script>
 *   ...
 *   <div class="terminal" role="region" dir="ltr" aria-label="Build details" data-terminal data-duration="2000">
 *     <div class="terminal__bar" aria-hidden="true" translate="no">       <!-- optional title bar -->
 *       <span class="terminal__dots"><i></i><i></i><i></i></span><span class="terminal__title">sysinfo</span>
 *     </div>
 *     <div class="terminal__screen" translate="no" tabindex="0">
 *       <div class="term-h">== CODE ==</div>
 *       <div class="term-row"><span class="term-k">Commit</span><span class="term-v">abc1234</span></div>
 *       <div class="term-gap"></div>
 *       <span class="terminal__cursor" aria-hidden="true"></span>
 *     </div>
 *   </div>
 *
 * Options (data attributes on [data-terminal]):
 *   data-duration  about how long the whole text takes to type, in ms (default 1800); long texts type more per frame
 *   data-wait      don't start by itself: wait for a `terminal:start` event on the element (fill in values first)
 *
 * Content: each child of .terminal__screen (except the cursor) is one line, revealed in order; its text is typed.
 * Classes: .term-h (amber heading), .term-row (key and value columns) with .term-k and .term-v, .term-dim, .term-hi,
 * .term-amber, .term-warn (red), .term-gap (empty line), .term-bar (a bar made of characters), .term-pre (keeps
 * spaces). Links keep working.
 * Events (on the element): `terminal:start` (types it, again if already typed), `terminal:done` (typing ended).
 * Click, tap or press any key while it types to show everything at once. Reduced-motion visitors get it all at
 * once, with no blinking cursor. While typing, aria-busy="true" tells screen readers to wait for the full text.
 * Always left to right (dir="ltr") and translate="no": it is machine output, like code.
 * Self-contained: no imports, works several times on a page. Theming is in terminal-screen.css.
 */
(function () {
  'use strict';
  var reduce = window.matchMedia('(prefers-reduced-motion: reduce)');

  function setup(root) {
    if (root.__terminal) return;
    root.__terminal = true;
    var screen = root.querySelector('.terminal__screen');
    var cursor = screen.querySelector('.terminal__cursor');
    if (!cursor) {
      cursor = document.createElement('span');
      cursor.className = 'terminal__cursor';
      cursor.setAttribute('aria-hidden', 'true');
      screen.append(cursor);
    }
    var stop = null;

    function start() {
      if (stop) stop();
      var lines = Array.prototype.filter.call(screen.children, function (el) { return el !== cursor; });
      // Every text node of every line, with its full text kept aside.
      var texts = lines.map(function (line) {
        var w = document.createTreeWalker(line, NodeFilter.SHOW_TEXT);
        var nodes = [];
        for (var n = w.nextNode(); n; n = w.nextNode()) nodes.push({ node: n, full: n.data });
        return nodes;
      });
      var all = [].concat.apply([], texts);
      var total = all.reduce(function (sum, t) { return sum + t.full.length; }, 0);
      function finish() {
        all.forEach(function (t) { t.node.data = t.full; });
        lines.forEach(function (l) { l.removeAttribute('data-term-hidden'); });
        screen.append(cursor);
        root.removeAttribute('data-typing');
        root.removeAttribute('aria-busy');
        stop = null;
        root.dispatchEvent(new CustomEvent('terminal:done'));
      }
      if (reduce.matches || total === 0) return finish();

      root.setAttribute('data-typing', '');
      root.setAttribute('aria-busy', 'true');
      all.forEach(function (t) { t.node.data = ''; });
      lines.forEach(function (l) { l.setAttribute('data-term-hidden', ''); });
      var duration = Number(root.dataset.duration) || 1800;
      var line = 0, node = 0, raf = 0, budget = 0;
      var last = performance.now();
      var perMs = Math.max(total / duration, 0.06);
      function step(now) {
        budget += (now - last) * perMs;
        last = now;
        while (budget >= 1 && line < lines.length) {
          lines[line].removeAttribute('data-term-hidden');
          var t = texts[line][node];
          if (!t) { line++; node = 0; continue; } // a line with no (more) text: next line
          var take = Math.min(Math.floor(budget), t.full.length - t.node.data.length);
          t.node.data = t.full.slice(0, t.node.data.length + take);
          budget -= take;
          t.node.after(cursor);
          if (t.node.data.length === t.full.length) node++;
        }
        if (line >= lines.length) return finish();
        raf = requestAnimationFrame(step);
      }
      raf = requestAnimationFrame(step);
      stop = function () { cancelAnimationFrame(raf); finish(); };
    }

    // Show everything at once: click, tap or any key while it types.
    function skip() { if (root.hasAttribute('data-typing') && stop) stop(); }
    screen.addEventListener('click', skip);
    window.addEventListener('keydown', function (e) { if (!e.metaKey && !e.ctrlKey && !e.altKey) skip(); });
    root.addEventListener('terminal:start', start);
    if (!root.hasAttribute('data-wait')) start();
  }

  function setupAll() { document.querySelectorAll('[data-terminal]').forEach(setup); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', setupAll);
  else setupAll();
})();
