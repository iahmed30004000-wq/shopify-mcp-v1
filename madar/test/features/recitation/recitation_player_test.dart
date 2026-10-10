import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/core/quran/quran_audio.dart';
import 'package:madar/core/sound/prayer_mute.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/recitation/application/recitation_player.dart';
import 'package:madar/features/recitation/data/local_files.dart';
import 'package:madar/features/recitation/data/recitation_engine.dart';
import 'package:madar/features/recitation/domain/recitation_settings.dart';
import 'package:madar/features/recitation/domain/recitation_state.dart';
import 'package:madar/features/recitation/domain/reciters.dart';

import 'recitation_fakes.dart';

class _Local implements LocalRecitationFiles {
  final Set<String> have = {};
  int prepared = 0;
  @override
  Future<void> prepare() async => prepared++;
  @override
  File? localFile(Reciter reciter, AyahRef ayah, {bool basmala = false}) {
    final key = basmala ? 'basmala' : '$ayah';
    return have.contains(key) ? File('/offline/${reciter.folder}/$key.mp3') : null;
  }
}

AyahRange r(int s1, int a1, int s2, int a2) => AyahRange(AyahRef(s1, a1), AyahRef(s2, a2));

void main() {
  late FakeEngine engine;
  late int engines;
  late FakeFocus focus;
  late _Local local;
  late RecordingLogger logger;
  late SilentSoundService sound;
  late PrayerMuteController mute;
  late FakeMediaSession media;
  late FakeBackground background;
  late DateTime now;
  late RecitationSettings settings;
  late RecitationPlayer player;

  RecitationPlayer make({int window = 24, int lookahead = 6}) => RecitationPlayer(
    engineFactory: () {
      engines++;
      return engine;
    },
    loadSettings: () async => settings,
    focus: focus,
    localFiles: local,
    logger: logger,
    background: background,
    prayerMute: mute,
    clock: () => now,
    windowSize: window,
    lookahead: lookahead,
  );

  setUp(() {
    engine = FakeEngine();
    engines = 0;
    focus = FakeFocus();
    local = _Local();
    logger = RecordingLogger();
    sound = SilentSoundService();
    mute = PrayerMuteController(sound);
    media = FakeMediaSession();
    background = FakeBackground(media);
    now = DateTime(2026, 9, 28, 20, 0);
    settings = const RecitationSettings(reciterId: 'husary.mujawwad');
    player = make();
  });

  tearDown(() {
    player.dispose();
    mute.dispose();
  });

  test('constructing touches nothing; the first play creates the engine', () async {
    await settle();
    expect(engines, 0);
    expect(background.starts, 0);
    expect(focus.configured, 0);
    expect(player.value, QuranPlayback.idle);
    await player.play(r(112, 1, 112, 4));
    await settle();
    expect(engines, 1);
    expect(focus.configured, 1);
    expect(local.prepared, 1);
    expect(background.starts, 1);
    expect(engine.calls, containsAllInOrder(['speed:1.0', 'set:5@0+0', 'play']));
  });

  test('playlist: basmala then ayat, streamed from everyayah or from downloads', () async {
    local.have.addAll(['112:2', 'basmala']);
    await player.play(r(112, 1, 112, 3));
    await settle();
    expect(engine.sources, [
      const EngineSource.file('/offline/Husary_128kbps_Mujawwad/basmala.mp3'),
      EngineSource.url(Uri.parse('https://everyayah.com/data/Husary_128kbps_Mujawwad/112001.mp3')),
      const EngineSource.file('/offline/Husary_128kbps_Mujawwad/112:2.mp3'),
      EngineSource.url(Uri.parse('https://everyayah.com/data/Husary_128kbps_Mujawwad/112003.mp3')),
    ]);
    expect(player.state.localFile, isTrue);
  });

  test('no counts mean the user defaults; explicit repeats are taken as asked', () async {
    settings = const RecitationSettings(repeatAyah: 3, repeatRange: 2, gapSeconds: 2);
    await player.play(r(114, 1, 114, 2));
    await settle();
    expect(player.state.ayahPasses, 3);
    expect(player.state.rangePasses, 2);
    expect(engine.sources.where((s) => s.silence != null), isNotEmpty);
    await player.play(r(114, 1, 114, 2), repeatAyah: 5);
    await settle();
    expect(player.state.ayahPasses, 5);
    expect(player.state.rangePasses, 1);
  });

  // Review finding: an explicit "once" (Hifz "listen ×1") could not be told
  // from "the user's defaults", so it repeated the ayat as the recitation
  // settings say – or looped the passage until stopped.
  test('an explicit single pass is taken as asked, not as the user defaults', () async {
    settings = const RecitationSettings(repeatAyah: 3, repeatRange: 0);
    final QuranAudio audio = player;
    await audio.play(r(114, 1, 114, 2), repeatAyah: 1);
    await settle();
    expect(player.state.ayahPasses, 1);
    expect(player.state.rangePasses, 1);
    await audio.play(r(114, 1, 114, 2));
    await settle();
    expect(player.state.ayahPasses, 3, reason: 'no counts: the user defaults');
    expect(player.state.rangePasses, 0);
  });

  test('state stream: loading → playing, then every ayah and repetition, then idle', () async {
    final seen = <QuranPlayback>[];
    final sub = player.playback.listen(seen.add);
    await settle();
    await player.play(r(114, 1, 114, 2), repeatAyah: 2);
    await settle();
    engine.finishCurrent(); // basmala → 114:1 #1
    await settle();
    engine.finishCurrent(); // → 114:1 #2
    await settle();
    engine.finishCurrent(); // → 114:2 #1
    await settle();
    engine.finishCurrent(); // → 114:2 #2
    await settle();
    engine.finishCurrent(); // completed
    await settle();
    await sub.cancel();
    String d(QuranPlayback p) => p.isIdle
        ? 'idle'
        : '${p.current}${p.basmala ? 'b' : ''} ${p.ayahPass}/${p.ayahPasses} ${p.playing ? 'play' : 'stop'}${p.loading ? ' load' : ''}';
    expect(seen.map(d).toList(), [
      'idle',
      '114:1b 1/2 stop load',
      '114:1b 1/2 play',
      '114:1 1/2 play',
      '114:1 2/2 play',
      '114:2 1/2 play',
      '114:2 2/2 play',
      'idle',
    ]);
    expect(engine.calls.last, 'stop');
  });

  test('long queues are fed to the engine in windows', () async {
    player.dispose();
    player = make(window: 5, lookahead: 2);
    await player.play(r(2, 1, 2, 20));
    await settle();
    expect(engine.sources, hasLength(5));
    for (var i = 0; i < 3; i++) {
      engine.finishCurrent();
      await settle();
    }
    expect(engine.calls, contains('add:5'));
    expect(engine.sources, hasLength(10));
    expect(player.value.current, const AyahRef(2, 3));
    // Jumping beyond the loaded window reloads from there.
    await player.seekToAyah(const AyahRef(2, 18));
    await settle();
    expect(engine.calls.where((c) => c.startsWith('set:')), hasLength(2));
    expect(player.value.current, const AyahRef(2, 18));
    expect(
      engine.sources.first,
      EngineSource.url(Uri.parse('https://everyayah.com/data/Husary_128kbps_Mujawwad/002018.mp3')),
    );
  });

  test('next skips repetitions; previous restarts the ayah, then goes back', () async {
    await player.play(r(114, 1, 114, 3), repeatAyah: 3);
    await settle();
    engine.finishCurrent(); // 114:1 #1
    await settle();
    await player.next();
    await settle();
    expect(player.value.current, const AyahRef(114, 2));
    expect(player.value.ayahPass, 1);
    engine.finishCurrent(); // 114:2 #2
    await settle();
    await player.previous();
    await settle();
    expect(player.value.current, const AyahRef(114, 2));
    expect(player.value.ayahPass, 1);
    await player.previous();
    await settle();
    expect(player.value.current, const AyahRef(114, 1));
    expect(player.value.basmala, isTrue);
  });

  test('changing repeats keeps the place', () async {
    await player.play(r(114, 1, 114, 3), repeatAyah: 2);
    await settle();
    engine.finishCurrent();
    engine.finishCurrent(); // 114:1 #2
    await settle();
    expect(player.value.ayahPass, 2);
    engine.pos = const Duration(seconds: 3);
    await player.setRepeats(repeatAyah: 5);
    await settle();
    expect(player.value.current, const AyahRef(114, 1));
    expect(player.value.ayahPass, 2);
    expect(player.value.ayahPasses, 5);
    expect(engine.calls.last, 'play');
    expect(engine.calls, contains('set:14@0+3000'), reason: 'from 114:1 #2 on, at the same position');
  });

  test('the adhan (prayer mute) pauses; it never resumes by itself', () async {
    await player.play(r(18, 1, 18, 10));
    await settle();
    expect(player.state.playing, isTrue);
    expect(mute.reasons, ['quran recitation'], reason: 'reciting silences the ambient bed and games');
    final adhan = mute.acquire('adhan quiet');
    await settle();
    expect(player.state.playing, isFalse);
    expect(player.state.pausedBy, RecitationPause.prayer);
    expect(engine.calls.last, 'pause');
    expect(mute.reasons, ['adhan quiet']);
    adhan.release();
    await settle();
    expect(player.state.playing, isFalse, reason: 'resume only when the user asks');
    await player.resume();
    await settle();
    expect(player.state.playing, isTrue);
    expect(player.state.pausedBy, isNull);
  });

  test('a prayer mute already on does not stop a recitation the user starts', () async {
    final quiet = mute.acquire('adhan quiet');
    await player.play(r(1, 1, 1, 7));
    await settle();
    expect(player.state.playing, isTrue);
    quiet.release();
  });

  test('a transient interruption resumes, unless the adhan came meanwhile', () async {
    await player.play(r(36, 1, 36, 5));
    await settle();
    focus.interruptionsCtrl.add((begin: true, transient: true));
    await settle();
    expect(player.state.pausedBy, RecitationPause.interruption);
    focus.interruptionsCtrl.add((begin: false, transient: true));
    await settle();
    expect(player.state.playing, isTrue);

    focus.interruptionsCtrl.add((begin: true, transient: true));
    await settle();
    final lease = mute.acquire('adhan screen');
    await settle();
    focus.interruptionsCtrl.add((begin: false, transient: true));
    await settle();
    expect(player.state.playing, isFalse);
    expect(player.state.pausedBy, RecitationPause.prayer);
    lease.release();
  });

  test('headphones unplugged pause', () async {
    await player.play(r(36, 1, 36, 5));
    await settle();
    focus.noisyCtrl.add(null);
    await settle();
    expect(player.state.pausedBy, RecitationPause.noisy);
  });

  test('sleep after this ayah', () async {
    await player.play(r(114, 1, 114, 6));
    await settle();
    engine.finishCurrent(); // 114:1
    await settle();
    player.setSleepAfterAyah();
    engine.finishCurrent(); // 114:2 starts → pause
    await settle();
    expect(player.state.playing, isFalse);
    expect(player.state.pausedBy, RecitationPause.sleepTimer);
    expect(player.state.sleep, isNull);
  });

  test('sleep timer pauses after the chosen time', () async {
    await player.play(r(114, 1, 114, 6));
    await settle();
    player.setSleepTimer(const Duration(minutes: 15));
    expect(player.state.sleep?.at, now.add(const Duration(minutes: 15)));
    player.setSleepTimer(null);
    expect(player.state.sleep, isNull);
    player.setSleepTimer(const Duration(milliseconds: 20));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await settle();
    expect(player.state.playing, isFalse);
    expect(player.state.pausedBy, RecitationPause.sleepTimer);
    expect(player.state.sleep, isNull);
  });

  test('errors: streaming failures read as network, 404 as not found; retry reloads', () async {
    await player.play(r(2, 1, 2, 3));
    await settle();
    engine.failAt(0, 'Source error: Unable to connect');
    await settle();
    expect(player.state.error, RecitationError.network);
    expect(player.state.pausedBy, RecitationPause.error);
    expect(player.value.playing, isFalse);
    await player.resume();
    await settle();
    expect(player.state.error, isNull);
    expect(player.state.playing, isTrue);
    engine.failAt(0, 'Response code: 404');
    await settle();
    expect(player.state.error, RecitationError.notFound);

    engine.failNextLoad = const SocketException('no route');
    await player.play(r(3, 1, 3, 2));
    await settle();
    expect(player.state.error, RecitationError.network);
  });

  test('listening is logged once, with real listening time', () async {
    await player.play(r(67, 1, 67, 4));
    await settle();
    now = now.add(const Duration(seconds: 20));
    engine.finishCurrent(); // 67:1
    await settle();
    now = now.add(const Duration(seconds: 25));
    await player.pause();
    await settle();
    now = now.add(const Duration(minutes: 2)); // paused: not counted
    await player.resume();
    await settle();
    engine.finishCurrent(); // 67:2
    await settle();
    now = now.add(const Duration(seconds: 15));
    await player.stop();
    await settle();
    expect(logger.logged, hasLength(1));
    final s = logger.logged.single;
    expect(s.listened, const Duration(seconds: 60));
    expect(s.first, const AyahRef(67, 1));
    expect(s.last, const AyahRef(67, 2));
    expect(s.ayat, 2);
    expect(s.reciterId, 'husary.mujawwad');
  });

  test('a long session is logged in parts', () async {
    await player.play(r(2, 1, 2, 10));
    await settle();
    now = now.add(const Duration(minutes: 12));
    engine.finishCurrent(); // basmala → 2:1
    await settle();
    now = now.add(const Duration(minutes: 12));
    engine.finishCurrent(); // 2:2 – 24 min heard: a part is logged
    await settle();
    expect(logger.logged, hasLength(1));
    expect(logger.logged.single.listened, const Duration(minutes: 24));
    expect(logger.logged.single.last, const AyahRef(2, 1));
    now = now.add(const Duration(minutes: 1));
    await player.stop();
    await settle();
    expect(logger.logged, hasLength(2));
    expect(logger.logged.last.first, const AyahRef(2, 2));
    expect(logger.logged.last.listened, const Duration(minutes: 1));
  });

  test('previews and short taps are not logged', () async {
    await player.playSample(Reciters.minshawiMujawwad);
    await settle();
    expect(player.isSampleOf(Reciters.minshawiMujawwad), isTrue);
    expect(player.state.reciter, Reciters.minshawiMujawwad);
    now = now.add(const Duration(minutes: 1));
    engine.finishCurrent();
    await settle();
    await player.stop();
    await player.play(r(1, 1, 1, 7));
    await settle();
    now = now.add(const Duration(seconds: 5));
    await player.stop();
    expect(logger.logged, isEmpty);
  });

  test('media session: title, controls and removal on stop', () async {
    await player.play(r(2, 255, 2, 256));
    await settle();
    expect(player.state.background, isTrue);
    final info = media.updates.whereType<Object>().last;
    expect(info, isNotNull);
    expect(media.updates.last!.title, 'Surah 2 · 255');
    expect(media.updates.last!.reciter, 'Mahmoud Khalil al-Husary');
    await media.controls!.pause();
    await settle();
    expect(player.state.playing, isFalse);
    await media.controls!.resume();
    await settle();
    expect(player.state.playing, isTrue);
    await media.controls!.next();
    await settle();
    expect(player.value.current, const AyahRef(2, 256));
    await media.controls!.stop();
    await settle();
    expect(media.updates.last, isNull);
    expect(player.value, QuranPlayback.idle);
    expect(mute.reasons, isEmpty);
  });

  test('switching reciter keeps the ayah and reloads', () async {
    await player.play(r(114, 1, 114, 6));
    await settle();
    engine.finishCurrent();
    engine.finishCurrent(); // 114:2
    await settle();
    await player.setReciter(Reciters.alafasy);
    await settle();
    expect(player.value.current, const AyahRef(114, 2));
    expect(player.value.reciterId, 'alafasy');
    expect(engine.sources.first, EngineSource.url(Uri.parse('https://everyayah.com/data/Alafasy_128kbps/114002.mp3')));
  });
}
