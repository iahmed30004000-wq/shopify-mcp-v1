/// The only scripts Madar ever runs inside a game page. They are Madar's
/// own, fixed text (no data from the page or the user is interpolated
/// except boolean flags), they expose NOTHING to the page (no bridge back to
/// the app: Madar never adds a JavaScript channel) and they touch only the
/// page's own media, audio contexts and – on explicit request – its own
/// storage.
abstract final class GameScripts {
  /// Installed after each page load: remembers the Web Audio contexts the
  /// game creates (in its own and same-origin frames) so they can be
  /// suspended while muted. A context created while muted starts suspended.
  static const String trackAudio = r'''
(function () {
  function patch(win) {
    try {
      if (!win.__madarCtx) {
        win.__madarCtx = [];
        ['AudioContext', 'webkitAudioContext'].forEach(function (name) {
          var Base = win[name];
          if (!Base || Base.__madarWrapped) return;
          var Wrapped = function () {
            var ctx = Reflect.construct(Base, arguments, new.target || Base);
            win.__madarCtx.push(ctx);
            if (win.__madarMuted) { try { hushCtx(ctx); } catch (e) {} }
            return ctx;
          };
          Wrapped.prototype = Base.prototype;
          Wrapped.__madarWrapped = true;
          try { Object.setPrototypeOf(Wrapped, Base); } catch (e) {}
          win[name] = Wrapped;
        });
      }
      for (var i = 0; i < win.frames.length; i++) patch(win.frames[i]);
    } catch (e) { /* a cross-origin frame: out of reach */ }
  }
  function hushCtx(ctx) {
    if (ctx.__madarHushed) return;
    ctx.__madarHushed = { running: ctx.state === 'running', resume: ctx.resume };
    ctx.resume = function () { return Promise.resolve(); };
    if (ctx.state === 'running') ctx.suspend();
  }
  window.__madarHushCtx = hushCtx;
  patch(window);
  return 'ok';
})()''';

  /// Silences the page. Returns JSON `{"sealed": n, "media": n, "ctx": n}`
  /// where `sealed` counts cross-origin frames it could not reach.
  ///
  /// [pause] also pauses playing media (prayer / background); [hide] makes
  /// the page believe it is hidden (`visibilitychange`), which most games
  /// answer by pausing themselves.
  static String hush({required bool pause, required bool hide}) =>
      '''
(function () {
  var PAUSE = ${pause ? 'true' : 'false'}, HIDE = ${hide ? 'true' : 'false'};
  var out = { sealed: 0, media: 0, ctx: 0 };
  function hushCtx(ctx) {
    if (ctx.__madarHushed) return;
    ctx.__madarHushed = { running: ctx.state === 'running', resume: ctx.resume };
    ctx.resume = function () { return Promise.resolve(); };
    if (ctx.state === 'running') ctx.suspend();
    out.ctx++;
  }
  function visit(win) {
    var doc;
    try { doc = win.document; if (!doc) return; } catch (e) { out.sealed++; return; }
    try {
      win.__madarMuted = true;
      var els = doc.querySelectorAll('audio, video');
      for (var i = 0; i < els.length; i++) {
        var el = els[i];
        if (!el.__madarHushed) el.__madarHushed = { paused: el.paused, muted: el.muted };
        el.muted = true;
        if (PAUSE && !el.paused) { try { el.pause(); } catch (e) {} }
        out.media++;
      }
      var list = win.__madarCtx || [];
      for (var j = 0; j < list.length; j++) { try { hushCtx(list[j]); } catch (e) {} }
      if (HIDE && !doc.__madarHidden) {
        doc.__madarHidden = true;
        Object.defineProperty(doc, 'hidden', { configurable: true, get: function () { return true; } });
        Object.defineProperty(doc, 'visibilityState', { configurable: true, get: function () { return 'hidden'; } });
        doc.dispatchEvent(new Event('visibilitychange'));
      }
    } catch (e) {}
    try { for (var k = 0; k < win.frames.length; k++) visit(win.frames[k]); } catch (e) { out.sealed++; }
  }
  visit(window);
  return JSON.stringify(out);
})()''';

  /// Undoes [hush]: media, contexts and visibility return to the state they
  /// had before (media the game had paused stay paused).
  static const String unhush = r'''
(function () {
  function visit(win) {
    var doc;
    try { doc = win.document; if (!doc) return; } catch (e) { return; }
    try {
      win.__madarMuted = false;
      if (doc.__madarHidden) {
        delete doc.hidden;
        delete doc.visibilityState;
        doc.__madarHidden = false;
        doc.dispatchEvent(new Event('visibilitychange'));
      }
      var els = doc.querySelectorAll('audio, video');
      for (var i = 0; i < els.length; i++) {
        var el = els[i], was = el.__madarHushed;
        if (!was) continue;
        el.__madarHushed = null;
        el.muted = was.muted;
        if (!was.paused && el.paused) { try { var p = el.play(); if (p && p.catch) p.catch(function () {}); } catch (e) {} }
      }
      var list = win.__madarCtx || [];
      for (var j = 0; j < list.length; j++) {
        var ctx = list[j], st = ctx.__madarHushed;
        if (!st) continue;
        ctx.__madarHushed = null;
        ctx.resume = st.resume;
        if (st.running) { try { ctx.resume(); } catch (e) {} }
      }
    } catch (e) {}
    try { for (var k = 0; k < win.frames.length; k++) visit(win.frames[k]); } catch (e) {}
  }
  visit(window);
  return 'ok';
})()''';

  /// Marker the clear-data page sets when it has finished.
  static const String clearedProbe = "String(window.__madarCleared || '')";

  /// A tiny local page loaded AT the game's origin (as its base URL, no
  /// network) that deletes that origin's storage: local/session storage,
  /// IndexedDB, Cache Storage, service workers and the cookies scripts can
  /// see. HttpOnly cookies are out of a page's reach ("Clear data of all
  /// games" removes those).
  static const String clearSiteDataPage = r'''<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"></head>
<body style="background:#000">
<script>
(async function () {
  try { localStorage.clear(); } catch (e) {}
  try { sessionStorage.clear(); } catch (e) {}
  try {
    if (window.indexedDB && indexedDB.databases) {
      var dbs = await indexedDB.databases();
      await Promise.all(dbs.map(function (d) {
        return new Promise(function (done) {
          try {
            var q = indexedDB.deleteDatabase(d.name);
            q.onsuccess = q.onerror = q.onblocked = function () { done(); };
          } catch (e) { done(); }
        });
      }));
    }
  } catch (e) {}
  try {
    if (window.caches) {
      var keys = await caches.keys();
      await Promise.all(keys.map(function (k) { return caches.delete(k); }));
    }
  } catch (e) {}
  try {
    if (navigator.serviceWorker && navigator.serviceWorker.getRegistrations) {
      var regs = await navigator.serviceWorker.getRegistrations();
      await Promise.all(regs.map(function (r) { return r.unregister(); }));
    }
  } catch (e) {}
  try {
    var host = location.hostname, parts = host.split('.'), domains = [''];
    for (var i = 0; i < parts.length - 1; i++) domains.push('; domain=' + parts.slice(i).join('.'));
    document.cookie.split(';').forEach(function (c) {
      var name = c.split('=')[0].trim();
      if (!name) return;
      domains.forEach(function (d) {
        document.cookie = name + '=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/' + d;
      });
    });
  } catch (e) {}
  window.__madarCleared = 'done';
})();
</script>
</body></html>''';

  /// Shown in place of a game unloaded for prayer (guaranteed silence).
  static const String restPage = '<!doctype html><html><body style="background:#000"></body></html>';
}
