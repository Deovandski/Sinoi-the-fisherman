/*
 * "Stats for nerds" (debug/, #22): fills every [data-v] value of the terminal in debug/index.html, then starts
 * the typing (terminal-screen.js). Ported from Deovandski/Deovandski-repo-template src/scripts/debug.ts.
 * Build facts come from ../stats.json (tools/build_stats.py, run in CI after the web export); the rest is what
 * this browser tells the page. Nothing is saved or sent anywhere: the only requests are stats.json itself (once,
 * plus three timed HEAD requests for "Ping"). A browser that doesn't share something shows "n/a".
 * After the typing ends, a few values keep updating (clock, uptime, frame rate, JS heap, viewport, online).
 * Languages: how much of each translation is done (tools/i18n.py, counted by words), and this page's language.
 * To add a line: a .term-row with data-v="key" in index.html, then set('key', …) below ("Stats for nerds" in CLAUDE.md).
 */
(function () {
  'use strict';
  var root = document.documentElement;
  // stats.json sits at the site root, one folder up from this script (also from a translated copy of the page).
  var STATS = new URL('../stats.json', (document.currentScript && document.currentScript.src) || location.href).href;
  var term = document.querySelector('.debug-terminal');
  function word(k) {
    var el = document.querySelector('.debug-words [data-k="' + k + '"]');
    return el ? el.textContent : k;
  }
  var NA = word('na');

  // ---------------------------------------------------------------- formatting
  function bytes(n) {
    if (n == null || !isFinite(n)) return NA;
    var u = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    while (n >= 1024 && i < u.length - 1) { n /= 1024; i++; }
    return n.toFixed(i && n < 10 ? 1 : 0) + ' ' + u[i];
  }
  function ms(n) { return n == null || !isFinite(n) || n < 0 ? NA : Math.round(n) + ' ms'; }
  function when(iso) { return iso ? new Date(iso).toLocaleString('en-CA', { hour12: false }).replace(',', '') : NA; }
  function yesNo(b) { return word(b ? 'yes' : 'no'); }
  function plural(n, one, many) { return n + ' ' + (n === 1 ? one : many); }
  function bar(pct, width) {
    width = width || 12;
    var full = Math.round((pct / 100) * width);
    return '[' + '█'.repeat(full) + '░'.repeat(width - full) + ']';
  }

  /** Put text (or a link) in a value. */
  function set(key, text, href) {
    var el = term && term.querySelector('[data-v="' + key + '"]');
    if (!el) return;
    if (href) {
      var a = document.createElement('a');
      a.href = href;
      a.rel = 'noopener';
      a.textContent = text;
      el.replaceChildren(a);
    } else el.textContent = text;
  }
  function timeout(p, t) {
    return Promise.race([
      Promise.resolve(p).catch(function () { return null; }),
      new Promise(function (r) { setTimeout(function () { r(null); }, t || 1500); }),
    ]);
  }
  function attempt(fn) { try { return fn(); } catch (e) { return Promise.reject(e); } }

  // ---------------------------------------------------------------- code, site, game (stats.json)
  async function fromStats() {
    var res = await timeout(fetch(STATS, { cache: 'no-cache' }));
    var stats = res && res.ok ? await res.json().catch(function () { return null; }) : null;
    if (!stats) {
      ['repo', 'visibility', 'build', 'builtAt', 'branch', 'commit', 'commitDate', 'pr', 'run', 'tools',
        'siteUrl', 'pages', 'deployed', 'types', 'game', 'engine', 'renderer', 'webBuild', 'exported',
        'cacheVersion', 'saveFormat', 'content', 'i18nSummary'].forEach(function (k) { set(k, k === 'repo' ? word('noStats') : NA); });
      return;
    }
    var code = stats.code, site = stats.site, game = stats.game;
    if (code.repo) set('repo', code.repo, code.repoUrl); else set('repo', NA);
    set('visibility', code.public === null ? word('local') : word(code.public ? 'public' : 'private'));
    set('build', code.run ? '#' + code.run + ' · ' + code.builtBy : code.builtBy, code.runUrl);
    set('builtAt', when(code.builtAt));
    set('branch', code.branch || NA);
    set('commit', code.commit ? (code.commit.slice(0, 7) + ' ' + (code.commitSubject || '')).trim() : NA, code.commitUrl);
    set('commitDate', when(code.commitDate));
    set('pr', code.pr ? '#' + code.pr : NA, code.prUrl);
    set('run', code.run ? '#' + code.run : NA, code.runUrl);
    var tools = Object.keys(code.tools || {}).filter(function (k) { return code.tools[k]; })
      .map(function (k) { return k + ' ' + String(code.tools[k]).replace(/^v/, ''); });
    set('tools', tools.length ? tools.join(' · ') : NA);

    set('siteUrl', site.url || NA, site.url);
    set('pages', plural(site.pages, 'page', 'pages') + ' in sitemap.xml · ' + plural(site.htmlFiles, 'HTML file', 'HTML files'));
    set('deployed', site.files + ' files · ' + bytes(site.bytes));
    set('types', Object.keys(site.byType).slice(0, 4).map(function (ext) { return ext + ' ' + bytes(site.byType[ext].bytes); }).join(' · ') || NA);

    set('game', (game.name || NA) + (game.version ? ' v' + game.version : ''));
    set('engine', game.godot ? 'Godot ' + game.godot : NA);
    set('renderer', game.renderer || NA);
    set('saveFormat', game.saveFormat != null ? 'version ' + game.saveFormat : NA);
    set('content', plural(game.fish, 'fish', 'fish') + ' · ' + plural(game.fightModes, 'fight mode', 'fight modes'));
    var web = game.web;
    if (web) {
      set('webBuild', bytes(web.bytes) + ' · ' + plural(web.files, 'file', 'files') + ' under play/', '../play/');
      set('exported', when(web.exportedAt));
      set('cacheVersion', web.cacheVersion || NA);
    } else ['webBuild', 'exported', 'cacheVersion'].forEach(function (k) { set(k, word('noGame')); });

    var i18n = stats.i18n;
    if (!i18n) { set('i18nSummary', NA); return; }
    var e = i18n.english;
    set('i18nSummary', 'English: ' + plural(e.pages, 'page', 'pages') + ' · ' + e.segments + ' segments · ' +
      e.words.toLocaleString('en') + ' words · offered at ' + Math.round(i18n.indexCoverage * 100) + '%');
    var marker = term.querySelector('[data-langs-list]');
    var here = document.documentElement.getAttribute('data-lang') || 'en';
    i18n.languages.forEach(function (l) {
      var row = document.createElement('div');
      row.className = 'term-row';
      var k = document.createElement('span');
      k.className = 'term-k';
      k.textContent = l.code + ' ' + l.name;
      var v = document.createElement('span');
      v.className = 'term-v';
      var b = document.createElement('span');
      b.className = 'term-bar';
      b.textContent = bar(l.percent) + ' ' + l.percent.toFixed(1).padStart(5) + '%';
      v.append(b, ' ' + l.segments + '/' + e.segments + ' seg · ' + l.pagesReady + '/' + e.pages + ' ' + word('ready'));
      if (l.percent < 50) b.classList.add('term-dim');
      if (l.code === here) { row.classList.add('term-hi'); v.append(' ' + word('current')); }
      row.append(k, v);
      marker.before(row);
    });
  }

  // ---------------------------------------------------------------- this page and the browser
  function webgl() {
    try {
      var gl = document.createElement('canvas').getContext('webgl');
      if (!gl) return NA;
      var ext = gl.getExtension('WEBGL_debug_renderer_info');
      return String(ext ? gl.getParameter(ext.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER));
    } catch (e) { return NA; }
  }
  function storageSummary(get) {
    try {
      var s = get();
      if (!s) return NA;
      var size = 0, keys = [];
      for (var i = 0; i < s.length; i++) { var k = s.key(i); keys.push(k); size += k.length + (s.getItem(k) || '').length; }
      return keys.length ? plural(keys.length, 'key', 'keys') + ' · ' + bytes(size * 2) + ' · ' + keys.join(', ') : word('none');
    } catch (e) { return NA; }
  }
  function browserName() {
    var data = navigator.userAgentData;
    var b = data && data.brands ? data.brands.filter(function (x) { return !/not.?a.?brand/i.test(x.brand); }) : null;
    if (b && b.length) return b.map(function (x) { return x.brand + ' ' + x.version; }).join(' · ');
    var m = navigator.userAgent.match(/(Firefox|Edg|OPR|SamsungBrowser|Chrome|Version)\/([\d.]+)/);
    if (!m) return NA;
    var name = m[1] === 'Version' ? 'Safari' : m[1] === 'Edg' ? 'Edge' : m[1] === 'OPR' ? 'Opera' : m[1];
    return name + ' ' + m[2];
  }

  async function fromBrowser() {
    function mq(q) { return matchMedia(q).matches; }
    var data = navigator.userAgentData;
    set('path', location.pathname);
    set('pageLang', root.lang + (root.dir === 'rtl' ? ' (right to left)' : ''));
    set('display', word(mq('(display-mode: standalone)') || mq('(display-mode: fullscreen)') || navigator.standalone ? 'standalone' : 'tab'));

    set('browser', browserName());
    set('platform', ((data && data.platform) || navigator.platform || NA) + (data && data.mobile ? ' (mobile)' : ''));
    set('ua', navigator.userAgent);
    set('cpu', navigator.hardwareConcurrency ? navigator.hardwareConcurrency + ' logical cores' : NA);
    set('deviceMemory', navigator.deviceMemory ? '≥ ' + navigator.deviceMemory + ' GB (rounded by the browser)' : NA);
    var cookies = document.cookie ? document.cookie.split(';').map(function (c) { return c.split('=')[0].trim(); }) : [];
    set('cookies', (navigator.cookieEnabled ? 'enabled' : 'blocked') + ' · ' + (cookies.length ? cookies.join(', ') : 'none set by this site'));
    set('local', storageSummary(function () { return localStorage; }));
    set('session', storageSummary(function () { return sessionStorage; }));
    set('screen', screen.width + '×' + screen.height + ' · ' + screen.colorDepth + '-bit colour' + (screen.orientation ? ' · ' + screen.orientation.type : ''));
    set('dpr', devicePixelRatio + '×');
    set('scheme', (mq('(prefers-color-scheme: dark)') ? 'dark' : 'light') + (mq('(prefers-contrast: more)') ? ' · more contrast' : ''));
    set('motion', word(mq('(prefers-reduced-motion: reduce)') ? 'reduce' : 'full'));
    set('input', (mq('(pointer: coarse)') ? 'touch' : mq('(pointer: fine)') ? 'mouse' : NA) + (navigator.maxTouchPoints ? ' · ' + navigator.maxTouchPoints + ' touch points' : ''));
    set('gpu', webgl());
    set('webgpu', yesNo(!!navigator.gpu));
    var tz = Intl.DateTimeFormat().resolvedOptions();
    var off = -new Date().getTimezoneOffset() / 60;
    set('tz', tz.timeZone + ' (UTC' + (off >= 0 ? '+' : '') + off + ') · ' + tz.locale);
    set('langs', (navigator.languages || [navigator.language]).join(', '));
    set('secure', yesNo(isSecureContext));
    set('isolated', yesNo(!!window.crossOriginIsolated));

    var c = navigator.connection;
    set('connection', c ? [c.type, c.effectiveType].filter(Boolean).join(' · ') || NA : NA);
    set('downlink', c && c.downlink != null ? c.downlink + ' Mbps (estimate)' : NA);
    set('rtt', c && c.rtt != null ? c.rtt + ' ms (estimate)' : NA);
    set('saveData', c && c.saveData != null ? yesNo(c.saveData) : NA);

    var st = navigator.storage;
    var est = await timeout(attempt(function () { return st.estimate(); }));
    var persisted = await timeout(attempt(function () { return st.persisted(); }));
    set('storage', est ? bytes(est.usage) + ' used of ' + bytes(est.quota) + (persisted != null ? ' · persistent: ' + yesNo(persisted) : '') : NA);

    // The offline worker belongs to the game (scope play/), so list every worker this site has.
    if (!('serviceWorker' in navigator)) set('sw', word('noWorker'));
    else {
      var regs = (await timeout(navigator.serviceWorker.getRegistrations())) || [];
      set('sw', regs.length ? regs.map(function (r) {
        var mine = navigator.serviceWorker.controller && r.active && navigator.serviceWorker.controller.scriptURL === r.active.scriptURL;
        return word(mine ? 'controlled' : 'notControlled') + ' · scope ' + new URL(r.scope).pathname;
      }).join(' · ') : word('none'));
    }
    if ('caches' in window) {
      var names = (await timeout(caches.keys())) || [];
      var counts = await Promise.all(names.map(async function (n) {
        var keys = await timeout(caches.open(n).then(function (cache) { return cache.keys(); }));
        return keys ? keys.length : 0;
      }));
      set('caches', names.length ? names.map(function (n, i) { return n + ': ' + plural(counts[i], 'file', 'files'); }).join(' · ') : word('none'));
    } else set('caches', NA);
    // IndexedDB: where the browser version of the game keeps its save (Godot's user:// folder).
    if (window.indexedDB && indexedDB.databases) {
      var dbs = (await timeout(indexedDB.databases())) || null;
      set('idb', dbs ? (dbs.length ? dbs.map(function (d) { return d.name; }).join(', ') : word('none')) : NA);
    } else set('idb', NA);

    var bat = navigator.getBattery ? await timeout(navigator.getBattery()) : null;
    set('battery', bat ? Math.round(bat.level * 100) + '% · ' + word(bat.charging ? 'charging' : 'unplugged') : NA);
  }

  // ---------------------------------------------------------------- network and performance
  function observed(type) {
    var got = [];
    try {
      var o = new PerformanceObserver(function () {});
      o.observe({ type: type, buffered: true });
      got = o.takeRecords();
      o.disconnect();
    } catch (e) { /* not supported */ }
    return got;
  }

  async function fromNetwork() {
    var nt = performance.getEntriesByType('navigation')[0];
    if (nt) {
      set('protocol', nt.nextHopProtocol || NA);
      set('servedFrom', word(nt.workerStart > 0 && nt.transferSize === 0 ? 'worker' : nt.transferSize === 0 ? 'memcache' : 'network'));
      set('dns', ms(nt.domainLookupEnd - nt.domainLookupStart));
      set('connect', ms(nt.connectEnd - nt.connectStart));
      set('tls', nt.secureConnectionStart > 0 ? ms(nt.connectEnd - nt.secureConnectionStart) : NA);
      set('ttfb', ms(nt.responseStart - nt.startTime));
      set('download', ms(nt.responseEnd - nt.responseStart));
      set('domReady', ms(nt.domContentLoadedEventEnd - nt.startTime));
      set('load', nt.loadEventEnd ? ms(nt.loadEventEnd - nt.startTime) : NA);
      set('transfer', bytes(nt.transferSize) + ' over the wire · ' + bytes(nt.decodedBodySize) + ' HTML');
    } else ['protocol', 'servedFrom', 'dns', 'connect', 'tls', 'ttfb', 'download', 'domReady', 'load', 'transfer'].forEach(function (k) { set(k, NA); });
    var res = performance.getEntriesByType('resource');
    set('resources', plural(res.length, 'file', 'files') + ' · ' + bytes(res.reduce(function (n, r) { return n + (r.transferSize || 0); }, 0)) + ' over the wire');
    set('nodes', document.getElementsByTagName('*').length + ' elements');
    // On a fast load the first paint comes just after "load": give it a few frames.
    for (var f = 0; f < 30 && !performance.getEntriesByName('first-contentful-paint').length; f++) {
      await new Promise(function (r) { requestAnimationFrame(function () { setTimeout(r, 16); }); });
    }
    var fcp = performance.getEntriesByName('first-contentful-paint')[0];
    set('fcp', ms(fcp && fcp.startTime));
    var lcp = observed('largest-contentful-paint').pop();
    set('lcp', ms(lcp && lcp.startTime));
    var shifts = observed('layout-shift');
    var types = (window.PerformanceObserver && PerformanceObserver.supportedEntryTypes) || [];
    set('cls', shifts.length || types.indexOf('layout-shift') >= 0
      ? shifts.filter(function (s) { return !s.hadRecentInput; }).reduce(function (n, s) { return n + s.value; }, 0).toFixed(3) : NA);

    // Ping: three HEAD requests for stats.json, straight to the server (no-store skips every cache).
    var times = [];
    var headers = null;
    for (var i = 0; i < 3; i++) {
      var t0 = performance.now();
      var r = await timeout(fetch(STATS + '?ping=' + Date.now(), { method: 'HEAD', cache: 'no-store' }), 3000);
      if (!r) break;
      times.push(performance.now() - t0);
      headers = headers || r.headers;
    }
    set('ping', times.length ? 'min ' + ms(Math.min.apply(null, times)) + ' · avg ' + ms(times.reduce(function (a, b) { return a + b; }, 0) / times.length) + ' (' + times.length + ' HEAD requests)' : NA);
    function h(name) { return headers ? headers.get(name) : null; }
    set('server', h('server') || NA);
    set('cdn', h('x-served-by') || h('via') || NA);
    set('cdnCache', [h('x-cache'), h('cache-control'), h('age') ? 'age ' + h('age') + 's' : null].filter(Boolean).join(' · ') || NA);
  }

  // ---------------------------------------------------------------- live values
  var frameCount = 0;
  var fps = 0;
  function countFrames() { frameCount++; requestAnimationFrame(countFrames); }
  function live() {
    var heap = performance.memory;
    set('heap', heap ? bytes(heap.usedJSHeapSize) + ' used · ' + bytes(heap.totalJSHeapSize) + ' allocated · ' + bytes(heap.jsHeapSizeLimit) + ' limit' : NA);
    set('viewport', innerWidth + '×' + innerHeight);
    set('clock', new Date().toLocaleString('en-CA', { hour12: false }).replace(',', ''));
    var s = Math.floor(performance.now() / 1000);
    set('uptime', Math.floor(s / 60) + 'm ' + String(s % 60).padStart(2, '0') + 's on this page');
    set('fps', fps ? fps + ' fps' : 'measuring');
    set('online', word(navigator.onLine ? 'online' : 'offline'));
  }

  async function main() {
    set('now', when(new Date().toISOString()));
    set('memtest', navigator.deviceMemory ? navigator.deviceMemory * 1024 * 1024 + 'K' : '640K');
    live();
    requestAnimationFrame(countFrames);
    await Promise.all([fromStats(), fromBrowser(), timeout(fromNetwork(), 2500)]);
    live();
    // Anything a slow browser API didn't answer in time.
    term.querySelectorAll('[data-v]').forEach(function (el) { if (el.textContent === '...') el.textContent = NA; });
    term.addEventListener('terminal:done', function () {
      setInterval(function () { fps = frameCount; frameCount = 0; live(); }, 1000);
    }, { once: true });
    term.dispatchEvent(new CustomEvent('terminal:start'));
  }

  function go() { main().catch(function (e) { console.warn('Stats for nerds:', e); term.dispatchEvent(new CustomEvent('terminal:start')); }); }
  if (document.readyState === 'complete') go();
  else addEventListener('load', function () { setTimeout(go); }, { once: true }); // after load ends, so "Load" has its time
})();
