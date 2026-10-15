// Runs Madar's page scripts (GameScripts) in Node against a minimal page
// model, to check what the hush can and cannot reach. Skipped when Node is
// not installed.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/saved_games/player/game_scripts.dart';

/// A page model: documents, frames, media elements (in the DOM or not),
/// Web Audio contexts (running without a gesture, as in a WebView main
/// frame) and the user-activation flag.
const String _harness = r'''
'use strict';
const vm = require('vm');
const fs = require('fs');
const S = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));

function page(opts) {
  opts = opts || {};
  class Event { constructor(type) { this.type = type; this.target = null; } }
  class Target {
    constructor() { this._l = {}; }
    addEventListener(t, f) { (this._l[t] = this._l[t] || []).push(f); }
    removeEventListener() {}
    dispatchEvent(e) { (this._l[e.type] || []).forEach((f) => f.call(this, e)); return true; }
  }
  // As in browsers, `hidden` / `visibilityState` are getters on the prototype.
  class Document extends Target {
    get hidden() { return false; }
    get visibilityState() { return 'visible'; }
  }
  const doc = new Document();
  class HTMLMediaElement extends Target {
    constructor(tag) { super(); this.tagName = tag; this.paused = true; this.muted = false; this.loop = false; this.inDom = false; }
    play() {
      this.paused = false;
      const e = new Event('play'); e.target = this;
      if (this.inDom) doc.dispatchEvent(e);
      this.dispatchEvent(e);
      return Promise.resolve();
    }
    pause() { this.paused = true; }
  }
  class HTMLAudioElement extends HTMLMediaElement { constructor() { super('AUDIO'); } }
  class HTMLVideoElement extends HTMLMediaElement { constructor() { super('VIDEO'); } }
  function Audio() { return new HTMLAudioElement(); }
  Audio.prototype = HTMLAudioElement.prototype;
  class AudioNode { constructor(ctx) { this.context = ctx; } connect(n) { return n; } }
  class AudioScheduledSourceNode extends AudioNode { start() { this.playing = true; } }
  class AudioBufferSourceNode extends AudioScheduledSourceNode {}
  class BaseAudioContext {
    constructor() { this.state = 'running'; }
    resume() { this.state = 'running'; return Promise.resolve(); }
    suspend() { this.state = 'suspended'; return Promise.resolve(); }
    createBufferSource() { return new AudioBufferSourceNode(this); }
    get destination() { return new AudioNode(this); }
  }
  class AudioContext extends BaseAudioContext {}
  doc.readyState = opts.loading ? 'loading' : 'complete';
  doc.scriptCount = opts.loading ? 0 : 2;
  doc.els = [];
  doc.getElementsByTagName = (t) => ({ length: t === 'script' ? doc.scriptCount : 0 });
  doc.querySelectorAll = (sel) =>
    sel === '*' ? doc.els.slice() : doc.els.filter((e) => e.tagName === 'AUDIO' || e.tagName === 'VIDEO');
  doc.createElement = (tag) => (tag === 'video' ? new HTMLVideoElement() : new HTMLAudioElement());
  doc.body = { appendChild: (e) => { e.inDom = true; doc.els.push(e); return e; } };
  const g = {
    Event, HTMLMediaElement, HTMLAudioElement, HTMLVideoElement, Audio, AudioNode, AudioScheduledSourceNode,
    AudioBufferSourceNode, BaseAudioContext, AudioContext, document: doc,
    navigator: { userActivation: { hasBeenActive: !!opts.activated } },
    frames: [], Promise, Reflect, Object, JSON, Array, Error, Math, String,
  };
  g.window = g;
  g.self = g;
  if (opts.sealedFrame) g.frames = [{ get document() { throw new Error('cross-origin'); }, frames: [] }];
  vm.createContext(g);
  const run = (code) => vm.runInContext(code, g);
  const parse = (code) => { const r = run(code); try { return JSON.parse(r); } catch (e) { return r; } };
  return { g, doc, run, parse };
}

const out = {};

// A. The game started Web Audio at load, before Madar's tracker ran.
{
  const p = page();
  p.run('window.ctx = new AudioContext(); var s = ctx.createBufferSource(); s.connect(ctx.destination); s.start();');
  p.run(S.track);
  out.lateCtx = { hush: p.parse(S.hushStrict), ctx: p.g.ctx.state };
}

// B. Game music in a detached `new Audio()` (never added to the DOM).
{
  const p = page();
  p.run(S.track);
  p.run('window.music = new Audio("m.mp3"); music.loop = true; music.play();');
  out.detached = { hush: p.parse(S.hushStrict), paused: p.g.music.paused, muted: p.g.music.muted };
  p.run(S.unhush);
  out.detachedAfter = { paused: p.g.music.paused, muted: p.g.music.muted };
}

// C. The page starts new sound while the prayer hush is on.
{
  const p = page();
  p.run(S.track);
  p.run(S.hushStrict);
  p.run('window.sfx = new Audio("s.mp3"); sfx.play(); window.c2 = new AudioContext(); c2.resume();');
  out.duringHush = { sfxPaused: p.g.sfx.paused, sfxMuted: p.g.sfx.muted, c2: p.g.c2.state };
}

// D. The tracker ran before any page script (installed at page start).
{
  const p = page({ loading: true });
  const track = p.parse(S.track);
  p.doc.readyState = 'interactive';
  p.doc.scriptCount = 2;
  p.run('window.ctx = new AudioContext(); window.el = document.createElement("audio"); document.body.appendChild(el); el.play();');
  out.early = { track, hush: p.parse(S.hushStrict), ctx: p.g.ctx.state, elPaused: p.g.el.paused };
  p.run(S.unhush);
  out.earlyAfter = { ctx: p.g.ctx.state, elPaused: p.g.el.paused };
}

// E. A cross-origin frame (e.g. a Claude artifact's sandbox).
{
  const p = page({ sealedFrame: true, loading: true });
  p.run(S.track);
  out.sealed = p.parse(S.hushStrict);
}

// F. A DOM element the browser started by itself (autoplay attribute).
{
  const p = page();
  p.run(S.track);
  p.run('window.bg = document.createElement("audio"); document.body.appendChild(bg);');
  p.g.bg.paused = false;
  p.run(S.hushStrict);
  out.autoplay = { paused: p.g.bg.paused, muted: p.g.bg.muted };
}

// G. The page is told it is hidden, and visible again afterwards.
{
  const p = page({ loading: true });
  p.run(S.track);
  p.run('window.seen = []; document.addEventListener("visibilitychange", function () { seen.push(document.visibilityState); });');
  p.run(S.hushStrict);
  p.run(S.unhush);
  out.visibility = p.g.seen;
}

console.log(JSON.stringify(out));
''';

Future<Map<String, Object?>> _runHarness() async {
  final dir = await Directory.systemTemp.createTemp('madar_game_scripts');
  try {
    final scripts = File('${dir.path}/scripts.json');
    await scripts.writeAsString(
      jsonEncode({
        'track': GameScripts.trackAudio,
        'hushStrict': GameScripts.hush(pause: true, hide: true),
        'unhush': GameScripts.unhush,
      }),
    );
    final harness = File('${dir.path}/harness.js');
    await harness.writeAsString(_harness);
    final r = await Process.run('node', [harness.path, scripts.path]);
    if (r.exitCode != 0) fail('node failed: ${r.stderr}');
    return (jsonDecode((r.stdout as String).trim()) as Map).cast<String, Object?>();
  } finally {
    await dir.delete(recursive: true);
  }
}

bool _hasNode() {
  try {
    return Process.runSync('node', ['--version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

void main() {
  final skip = _hasNode() ? false : 'Node.js is not installed';

  late Map<String, Object?> out;
  setUpAll(() async {
    if (skip == false) out = await _runHarness();
  });

  Map<String, Object?> at(String key) => (out[key]! as Map).cast<String, Object?>();

  test('Web Audio started before the tracker is reported as out of reach (blind)', () {
    final a = at('lateCtx');
    expect(a['ctx'], 'running', reason: 'nothing on the page can reach that context');
    expect((a['hush']! as Map)['blind'], isTrue, reason: 'so the prayer hush must not claim silence');
  }, skip: skip);

  test('detached game music (new Audio()) is paused and muted, and resumes after', () {
    final b = at('detached');
    expect(b['paused'], isTrue);
    expect(b['muted'], isTrue);
    final after = at('detachedAfter');
    expect(after['paused'], isFalse);
    expect(after['muted'], isFalse);
  }, skip: skip);

  test('sound the page starts during the prayer hush stays silent', () {
    final c = at('duringHush');
    expect(c['sfxPaused'], isTrue);
    expect(c['c2'], 'suspended');
  }, skip: skip);

  test('tracked from the first script: every source is reached in place, then restored', () {
    final d = at('early');
    expect(d['track'], {'early': true});
    expect((d['hush']! as Map)['blind'], isFalse);
    expect((d['hush']! as Map)['sealed'], 0);
    expect(d['ctx'], 'suspended');
    expect(d['elPaused'], isTrue);
    final after = at('earlyAfter');
    expect(after['ctx'], 'running');
    expect(after['elPaused'], isFalse);
  }, skip: skip);

  test('a cross-origin frame is counted as sealed', () {
    expect((out['sealed']! as Map)['sealed'], 1);
  }, skip: skip);

  test('media the browser autoplays in the page is paused too', () {
    expect(at('autoplay')['paused'], isTrue);
  }, skip: skip);

  test('the page is told it is hidden during the hush and visible after', () {
    expect(out['visibility'], ['hidden', 'visible']);
  }, skip: skip);
}
