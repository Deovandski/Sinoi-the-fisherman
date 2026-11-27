/*
 * Settings: the gear (top right of every page) opens the Settings dialog.
 * Ported from Deovandski/Deovandski-repo-template src/scripts/settings.ts (#22).
 * The markup is tools/site_parts/header.html, written into every page by tools/sync_site.py.
 * The × is a submit button in a method="dialog" form, so it closes the dialog with no script; Esc closes it too.
 * A tap on the dimmed backdrop also closes it (touch first).
 */
(function () {
  'use strict';
  var gear = document.getElementById('gear');
  var dialog = document.getElementById('site-settings');
  if (!gear || !dialog || typeof dialog.showModal !== 'function') return;
  gear.addEventListener('click', function () { dialog.showModal(); });
  dialog.addEventListener('click', function (e) {
    if (e.target !== dialog) return; // a tap inside the panel lands on its children
    var r = dialog.getBoundingClientRect();
    var inside = e.clientX >= r.left && e.clientX <= r.right && e.clientY >= r.top && e.clientY <= r.bottom;
    if (!inside) dialog.close();
  });
})();
