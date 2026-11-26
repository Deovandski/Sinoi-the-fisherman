/*
 * InstallApp: an "Install app" button for an installable site (PWA).
 * Ported from Deovandski/Deovandski src/components/reusable/InstallApp.astro
 * (Deovandski/Deovandski#293) to plain JavaScript for this static site (#20).
 *
 * It shows the button only when the browser can install the site right now
 * (Chrome, Edge, Samsung Internet keep a `beforeinstallprompt` offer), and
 * otherwise a short line on how to get there:
 *   - Android: links opened from WhatsApp, Instagram or Gmail land in a built-in
 *     viewer with no install option, so: "Open this page in Chrome ... Install app";
 *   - iPhone/iPad: "Share, then Add to Home Screen";
 *   - anywhere else: which browsers can install it.
 * Inside the installed app it says so; right after installing, where to find it.
 *
 * Usage (load this script in <head>, not deferred, so it catches an early offer):
 *   <link rel="stylesheet" href="install-app.css">
 *   <script src="install-app.js"></script>
 *   ...
 *   <div class="install-app" data-install-app>
 *     <span class="install-app__strings" hidden>
 *       <span data-k="installed">You're using the installed app.</span>
 *       <span data-k="done">Installed! Open it from your home screen or app list.</span>
 *       <span data-k="android">No install button? Open this page in Chrome (⋮ → Open in Chrome), then ⋮ → Install app.</span>
 *       <span data-k="ios">On iPhone or iPad: tap Share, then Add to Home Screen.</span>
 *       <span data-k="other">To install it, open this page in Chrome, Edge or Samsung Internet. On iPhone or iPad: Share, then Add to Home Screen.</span>
 *     </span>
 *     <button type="button" class="install-app__btn" hidden>Install app</button>
 *     <p class="install-app__note" aria-live="polite"></p>
 *   </div>
 *
 * Every word lives in the page (the button text and the hidden strings), so a
 * translated page translates it too. Nothing is stored. Works several times on
 * one page. A real button, and the note is read out when it changes.
 * Theming: --install-accent (button background), --install-ink (button text),
 * --install-muted (note text).
 */
(function () {
  'use strict';
  // Keep the browser's install offer, even if it fires before the page is parsed.
  if (!window.__installAppPrompt) {
    window.__installAppPrompt = { event: null };
    window.addEventListener('beforeinstallprompt', function (e) {
      e.preventDefault(); // show our button instead of the browser's mini-bar
      window.__installAppPrompt.event = e;
      document.dispatchEvent(new CustomEvent('install-app:ready'));
    });
  }

  function standalone() {
    return window.matchMedia('(display-mode: standalone)').matches ||
      window.matchMedia('(display-mode: fullscreen)').matches ||
      window.navigator.standalone === true;
  }

  var ua = navigator.userAgent;
  var ios = /iPhone|iPad|iPod/.test(ua) || (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1);
  var android = /Android/.test(ua);

  function setup(root) {
    if (root.__installApp) return;
    root.__installApp = true;
    var btn = root.querySelector('.install-app__btn');
    var note = root.querySelector('.install-app__note');
    if (!btn || !note) return;
    function msg(k) {
      var el = root.querySelector('.install-app__strings [data-k="' + k + '"]');
      return el ? el.textContent : '';
    }
    // The button when the browser can install the site now, otherwise how to get there.
    function show() {
      if (standalone()) {
        btn.hidden = true;
        note.textContent = msg('installed');
      } else if (window.__installAppPrompt.event) {
        btn.hidden = false;
        note.textContent = '';
      } else {
        btn.hidden = true;
        note.textContent = msg(ios ? 'ios' : android ? 'android' : 'other');
      }
    }
    btn.addEventListener('click', function () {
      var e = window.__installAppPrompt.event;
      if (!e) { show(); return; }
      window.__installAppPrompt.event = null; // an offer can only be used once
      e.prompt();
      e.userChoice.then(function (choice) {
        if (choice && choice.outcome === 'accepted') {
          btn.hidden = true;
          note.textContent = msg('done');
        } else {
          show();
        }
      });
    });
    document.addEventListener('install-app:ready', show);
    window.addEventListener('appinstalled', function () {
      btn.hidden = true;
      note.textContent = msg('done');
    });
    show();
  }

  function init() {
    document.querySelectorAll('[data-install-app]').forEach(setup);
  }
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
