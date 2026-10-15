/// The only scripts Madar ever runs inside a game page. They are Madar's
/// own, fixed text (no data from the page or the user is interpolated
/// except boolean flags), they expose NOTHING to the page (no bridge back to
/// the app: Madar never adds a JavaScript channel) and they touch only the
/// page's own media, audio contexts and – on explicit request – its own
/// storage.
abstract final class GameScripts {
  /// Installs Madar's audio tracker into a window (idempotent), shared by
  /// [trackAudio] and [hush]. State lives in one read-only `__madar` object:
  ///
  /// * `early` – installed before any of the page's scripts ran, so every
  ///   sound source the page makes passes through the patches below;
  /// * `ctx` / `media` – the Web Audio contexts and media elements seen
  ///   (media includes detached `new Audio()` elements, which no DOM query
  ///   finds);
  /// * `muted` / `paused` – the hush in force: a context created or resumed
  ///   while muted stays suspended, a media element played while muted
  ///   plays muted – or, while paused (prayer, background), not at all.
  static const String _tracker = r'''
function __madarTrack(win) {
  var doc = win.document;
  if (win.__madar) return win.__madar;
  var scripts = 1;
  try { scripts = doc.getElementsByTagName('script').length; } catch (e) {}
  var st = { early: doc.readyState === 'loading' && scripts === 0, ctx: [], media: [], muted: false, paused: false };
  try { Object.defineProperty(win, '__madar', { value: st }); } catch (e) { return null; }
  var P = win.Promise;
  function remember(list, item) {
    if (item && list.indexOf(item) < 0) {
      list.push(item);
      if (list.length > 256) list.shift();
    }
  }
  function hushCtx(ctx) {
    if (!ctx || ctx.__madarHushed || typeof ctx.suspend !== 'function') return false;
    ctx.__madarHushed = { running: ctx.state === 'running' };
    if (ctx.state === 'running') {
      try { var s = ctx.suspend(); if (s && s.catch) s.catch(function () {}); } catch (e) {}
    }
    return true;
  }
  function noteCtx(ctx) {
    if (!ctx || typeof ctx.suspend !== 'function') return;
    if (win.OfflineAudioContext && ctx instanceof win.OfflineAudioContext) return;
    remember(st.ctx, ctx);
    if (st.muted) hushCtx(ctx);
  }
  function hushMedia(el) {
    if (!el) return;
    if (!el.__madarHushed) el.__madarHushed = { paused: el.paused, muted: el.muted };
    el.muted = true;
    if (st.paused && !el.paused) { try { el.pause(); } catch (e) {} }
  }
  st.remember = remember;
  st.hushCtx = hushCtx;
  st.hushMedia = hushMedia;
  function patch(Cls, name, before) {
    var proto = Cls && Cls.prototype;
    var orig = proto && proto[name];
    if (typeof orig !== 'function' || orig.__madarPatched) return;
    var fn = function () {
      var r;
      try { r = before(this); } catch (e) {}
      return r !== undefined ? r : orig.apply(this, arguments);
    };
    fn.__madarPatched = true;
    try { proto[name] = fn; } catch (e) {}
  }
  var ctors = ['BaseAudioContext', 'AudioContext', 'webkitAudioContext'];
  for (var i = 0; i < ctors.length; i++) {
    patch(win[ctors[i]], 'resume', function (ctx) {
      noteCtx(ctx);
      if (ctx.__madarHushed) { ctx.__madarHushed.running = true; return P.resolve(); }
    });
  }
  ['AudioContext', 'webkitAudioContext'].forEach(function (name) {
    var Base = win[name];
    if (!Base || Base.__madarWrapped) return;
    var Wrapped = function () {
      var ctx = Reflect.construct(Base, arguments, new.target || Base);
      noteCtx(ctx);
      return ctx;
    };
    Wrapped.prototype = Base.prototype;
    Wrapped.__madarWrapped = true;
    try { Object.setPrototypeOf(Wrapped, Base); } catch (e) {}
    win[name] = Wrapped;
  });
  patch(win.AudioScheduledSourceNode, 'start', function (node) { noteCtx(node.context); });
  patch(win.AudioNode, 'connect', function (node) { noteCtx(node.context); });
  patch(win.HTMLMediaElement, 'play', function (el) {
    remember(st.media, el);
    if (!st.muted) return;
    hushMedia(el);
    if (st.paused) {
      // Looping music resumes after the hush; one-off sounds are dropped.
      if (el.loop) el.__madarHushed.paused = false;
      return P.resolve();
    }
  });
  // Media the browser starts by itself (autoplay) in the page.
  try {
    doc.addEventListener('play', function (e) {
      var el = e && e.target;
      if (!el || !st.muted) return;
      remember(st.media, el);
      hushMedia(el);
    }, true);
  } catch (e) {}
  return st;
}
''';

  /// Installs the tracker in the page and its same-origin frames. Run when
  /// a page starts (to be in place before the page's own scripts) and again
  /// when it has finished. Returns JSON `{"early": bool}` for the top page.
  static const String trackAudio =
      '(function () {\n$_tracker'
      r'''
  var early = false;
  function visit(win, top) {
    try { if (!win.document) return; } catch (e) { return; }
    try {
      var st = __madarTrack(win);
      if (top) early = !!(st && st.early);
    } catch (e) {}
    try { for (var i = 0; i < win.frames.length; i++) visit(win.frames[i], false); } catch (e) {}
  }
  visit(window, true);
  return '{"early":' + (early ? 'true' : 'false') + '}';
})()''';

  /// Silences the page. Returns JSON
  /// `{"sealed": n, "blind": bool, "media": n, "ctx": n}`: `sealed` counts
  /// cross-origin frames it could not reach, `blind` is true when some
  /// window was tracked only after its scripts ran (sound it made before is
  /// out of reach).
  ///
  /// [pause] also pauses playing media and refuses new sound (prayer /
  /// background); [hide] makes the page believe it is hidden
  /// (`visibilitychange`), which most games answer by pausing themselves.
  static String hush({required bool pause, required bool hide}) =>
      '(function () {\n'
      '  var PAUSE = ${pause ? 'true' : 'false'}, HIDE = ${hide ? 'true' : 'false'};\n'
      '$_tracker'
      r'''
  var sealed = 0, blind = false, media = 0, ctxs = 0;
  function mediaOf(doc) {
    var out = [];
    try {
      var list = doc.querySelectorAll('audio, video');
      for (var i = 0; i < list.length; i++) out.push(list[i]);
      // Open shadow roots (web components), bounded.
      var all = doc.querySelectorAll('*');
      for (var j = 0; j < all.length && j < 4000; j++) {
        var root = all[j].shadowRoot;
        if (!root) continue;
        var inner = root.querySelectorAll('audio, video');
        for (var k = 0; k < inner.length; k++) out.push(inner[k]);
      }
    } catch (e) {}
    return out;
  }
  function visit(win) {
    var doc;
    try { doc = win.document; if (!doc) return; } catch (e) { sealed++; return; }
    try {
      var st = __madarTrack(win);
      if (!st) {
        blind = true;
      } else {
        if (!st.early) blind = true;
        st.muted = true;
        st.paused = PAUSE;
        var found = mediaOf(doc);
        for (var i = 0; i < found.length; i++) st.remember(st.media, found[i]);
        for (var m = 0; m < st.media.length; m++) st.hushMedia(st.media[m]);
        media += st.media.length;
        for (var c = 0; c < st.ctx.length; c++) st.hushCtx(st.ctx[c]);
        ctxs += st.ctx.length;
        if (HIDE && !doc.__madarHidden) {
          doc.__madarHidden = true;
          Object.defineProperty(doc, 'hidden', { configurable: true, get: function () { return true; } });
          Object.defineProperty(doc, 'visibilityState', { configurable: true, get: function () { return 'hidden'; } });
          doc.dispatchEvent(new Event('visibilitychange'));
        }
      }
    } catch (e) { blind = true; }
    try { for (var f = 0; f < win.frames.length; f++) visit(win.frames[f]); } catch (e) { sealed++; }
  }
  visit(window);
  return '{"sealed":' + sealed + ',"blind":' + (blind ? 'true' : 'false') + ',"media":' + media + ',"ctx":' + ctxs + '}';
})()''';

  /// Undoes [hush]: media, contexts and visibility return to the state they
  /// had before (media the game had paused stay paused).
  static const String unhush = r'''
(function () {
  function visit(win) {
    var doc;
    try { doc = win.document; if (!doc) return; } catch (e) { return; }
    try {
      var st = win.__madar;
      if (st) { st.muted = false; st.paused = false; }
      if (doc.__madarHidden) {
        delete doc.hidden;
        delete doc.visibilityState;
        doc.__madarHidden = false;
        doc.dispatchEvent(new Event('visibilitychange'));
      }
      var els = [];
      if (st) els = st.media.slice();
      var list = doc.querySelectorAll('audio, video');
      for (var i = 0; i < list.length; i++) if (els.indexOf(list[i]) < 0) els.push(list[i]);
      for (var m = 0; m < els.length; m++) {
        var el = els[m], was = el.__madarHushed;
        if (!was) continue;
        el.__madarHushed = null;
        el.muted = was.muted;
        if (!was.paused && el.paused) { try { var p = el.play(); if (p && p.catch) p.catch(function () {}); } catch (e) {} }
      }
      var ctxs = st ? st.ctx : [];
      for (var c = 0; c < ctxs.length; c++) {
        var ctx = ctxs[c], s = ctx.__madarHushed;
        if (!s) continue;
        ctx.__madarHushed = null;
        if (s.running) { try { var r = ctx.resume(); if (r && r.catch) r.catch(function () {}); } catch (e) {} }
      }
    } catch (e) {}
    try { for (var f = 0; f < win.frames.length; f++) visit(win.frames[f]); } catch (e) {}
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
