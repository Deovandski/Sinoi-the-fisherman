/*
 * Settings: the gear (top right of every page) opens the Settings dialog.
 * Ported from Deovandski/Deovandski-repo-template src/scripts/settings.ts (#22).
 * The markup is tools/site_parts/header.html, written into every page by tools/sync_site.py.
 * The × is a submit button in a method="dialog" form, so it closes the dialog with no script; Esc closes it too.
 * A tap on the dimmed backdrop also closes it (touch first).
 * Language: the drop-down and the banner's "English" link switch the page through lang.js.
 */
(function () {
  'use strict';
  var gear = document.getElementById('gear');
  var dialog = document.getElementById('site-settings');
  if (!gear || !dialog || typeof dialog.showModal !== 'function') return;
  gear.addEventListener('click', function () { dialog.showModal(); });
  // Language (lang.js does the switching and remembers the choice).
  var lang = window.sinoiLang;
  var pick = dialog.querySelector('[data-setting="lang"]');
  if (pick && lang) {
    pick.value = lang.here;
    pick.addEventListener('change', function () { lang.go(pick.value); });
  }
  document.addEventListener('click', function (e) {
    var a = e.target.closest && e.target.closest('[data-lang-switch]');
    if (a && lang) { e.preventDefault(); lang.go(a.getAttribute('data-lang-switch')); }
  });
  dialog.addEventListener('click', function (e) {
    if (e.target !== dialog) return; // a tap inside the panel lands on its children
    var r = dialog.getBoundingClientRect();
    var inside = e.clientX >= r.left && e.clientX <= r.right && e.clientY >= r.top && e.clientY <= r.bottom;
    if (!inside) dialog.close();
  });
})();
