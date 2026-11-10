import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/motion/motion.dart';

import '../../core/kids_section.dart';
import '../../rewards/presentation/play_kit.dart';
import '../application/story_providers.dart';
import '../application/voice_providers.dart' show kidsParentAskProvider;
import '../domain/little_star_story.dart';
import '../domain/sound_detector.dart';
import '../domain/story_runner.dart';
import '../domain/story_script.dart';
import 'story_stage.dart';

enum _Mic { unknown, ready, unavailable }

/// «قصة تفاعلية» (design 09c): the story moves and now and then asks the child
/// to say a word. There is no speech recognition yet, so the story goes on
/// when the microphone hears any sound, or when the child presses «ما بقدر
/// أحكي هلأ». The screen never claims to have understood the word.
class InteractiveStoryScreen extends ConsumerStatefulWidget {
  const InteractiveStoryScreen({super.key, this.script = littleStarStory});

  final StoryScript script;

  @override
  ConsumerState<InteractiveStoryScreen> createState() => _InteractiveStoryScreenState();
}

class _InteractiveStoryScreenState extends ConsumerState<InteractiveStoryScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final StoryRunner _runner = StoryRunner(widget.script);
  late final AnimationController _move = AnimationController(vsync: this);
  late final AnimationController _ambient = AnimationController(vsync: this, duration: const Duration(seconds: 3));
  final SoundDetector _detector = SoundDetector();
  final ValueNotifier<double> _level = ValueNotifier<double>(0);

  StreamSubscription<double>? _levelSub;
  _Mic _mic = _Mic.unknown;
  bool _listening = false;
  bool _lowPower = false;
  bool? _gotStar;
  bool _awarded = false;
  bool _started = false;
  int _slowFrames = 0;
  int _frames = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _move.addStatusListener((s) {
      if (s == AnimationStatus.completed) _motionDone();
    });
    unawaited(_checkMic());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = context.reducedMotion;
    if (reduced) {
      _ambient
        ..stop()
        ..value = 0.5;
    } else if (!_ambient.isAnimating) {
      _ambient.repeat();
    }
    if (!_started) {
      _started = true;
      // After the first frame: a still (reduced-motion) beat finishes at once,
      // and that must not happen while the tree is being built.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startBeat();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _levelSub?.cancel();
    _move.dispose();
    _ambient.dispose();
    _level.dispose();
    super.dispose();
  }

  // A weak GPU: when a third of the last frames were slow, the trail, the glow
  // and most twinkles are dropped (the story itself still works).
  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      _frames++;
      if (t.totalSpan > const Duration(milliseconds: 24)) _slowFrames++;
    }
    if (!_lowPower && _frames >= 40 && _slowFrames * 3 > _frames) {
      if (mounted) setState(() => _lowPower = true);
    }
    if (_frames >= 120) {
      _frames = 0;
      _slowFrames = 0;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The microphone and the story stop when the app is not in front.
    if (state != AppLifecycleState.resumed) {
      unawaited(_stopListening());
      _move.stop();
      _ambient.stop();
    } else {
      if (!context.reducedMotion) _ambient.repeat();
      if (_runner.phase == StoryPhase.moving) {
        _move.forward();
      } else if (_runner.isAskingToSay) {
        unawaited(_beginListening());
      }
    }
  }

  Future<void> _checkMic() async {
    try {
      final ok = await ref.read(soundMeterProvider).hasPermission();
      if (mounted) setState(() => _mic = ok ? _Mic.ready : _Mic.unavailable);
    } on Object {
      if (mounted) setState(() => _mic = _Mic.unavailable);
    }
  }

  // ---- the story's flow ----

  void _startBeat() {
    final reduced = context.reducedMotion;
    _move.duration = reduced ? Duration.zero : Duration(milliseconds: _runner.beat.motionMs);
    _move.forward(from: 0);
  }

  void _motionDone() {
    if (!mounted || _runner.phase != StoryPhase.moving) return;
    setState(_runner.motionDone);
    if (_runner.isAskingToSay) {
      unawaited(_beginListening());
    } else if (_runner.isFinished) {
      unawaited(_award());
    }
  }

  Future<void> _beginListening() async {
    if (_listening || !_runner.isAskingToSay) return;
    if (_mic == _Mic.unknown) await _checkMic();
    if (!mounted || _mic != _Mic.ready || !_runner.isAskingToSay || _listening) return;
    final meter = ref.read(soundMeterProvider);
    final clock = ref.read(storyClockProvider);
    _detector.reset();
    try {
      _listening = true;
      await meter.start();
      _levelSub = meter.levels.listen((v) {
        _level.value = v;
        if (_detector.update(v, clock())) _heard();
      });
    } on Object {
      _listening = false;
      if (mounted) setState(() => _mic = _Mic.unavailable);
    }
  }

  Future<void> _stopListening() async {
    if (!_listening) return;
    _listening = false;
    final meter = ref.read(soundMeterProvider);
    final sub = _levelSub;
    _levelSub = null;
    // Not awaited: the subscription is gone either way, and the microphone is
    // what must be stopped.
    unawaited(sub?.cancel());
    if (mounted) _level.value = 0;
    try {
      await meter.stop();
    } on Object {
      // The meter is disposed with the screen anyway.
    }
  }

  void _heard() {
    unawaited(_stopListening());
    if (!mounted) return;
    setState(_runner.soundHeard);
    _startBeat();
  }

  void _skip() {
    unawaited(_stopListening());
    setState(_runner.skipSay);
    _startBeat();
  }

  void _next() {
    setState(_runner.next);
    _startBeat();
  }

  void _replayBeat() {
    unawaited(_stopListening());
    setState(_runner.replayBeat);
    _startBeat();
  }

  void _restart() {
    unawaited(_stopListening());
    setState(() {
      _runner.restart();
      _gotStar = null;
      _awarded = false;
    });
    _startBeat();
  }

  Future<void> _award() async {
    final reason = widget.script.starReason;
    if (_awarded || reason == null) return;
    _awarded = true;
    final before = ref.read(kidsStarCountProvider);
    await ref.read(kidsStarAwardProvider)(reason);
    if (!mounted) return;
    setState(() => _gotStar = ref.read(kidsStarCountProvider) > before);
  }

  Future<void> _parentEnablesMic() async {
    if (!await ref.read(kidsParentAskProvider)() || !mounted) return;
    final ok = await ref.read(soundMeterProvider).hasPermission(request: true);
    if (!mounted) return;
    setState(() => _mic = ok ? _Mic.ready : _Mic.unavailable);
    if (ok) unawaited(_beginListening());
  }

  // ---- the screen ----

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final beat = _runner.beat;
    final height = MediaQuery.sizeOf(context).height;
    return Scaffold(
      backgroundColor: KidsColors.night900,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            PlayHeader(title: widget.script.title.of(lang), dark: true),
            _Dots(count: widget.script.beats.length, index: _runner.beatIndex),
            const SizedBox(height: 6),
            Expanded(
              child: Semantics(
                label: l.kidsPlayStoryStageLabel,
                image: true,
                child: StoryStage(beat: beat, move: _move, ambient: _ambient, lowPower: _lowPower),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: height * 0.62),
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: KidsColors.paper,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: _runner.isFinished ? SingleChildScrollView(child: _finished(l)) : _panel(l, lang, beat),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The words scroll if they are long; the buttons stay where the child's
  /// thumb expects them.
  Widget _panel(L10n l, String lang, StoryBeat beat) {
    final say = beat.say;
    final asking = _runner.isAskingToSay && say != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: Text(
              beat.narration.of(lang),
              textAlign: TextAlign.center,
              style: KidsText.body.copyWith(fontSize: 21, height: 1.7),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (asking) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MicOrb(level: _level, listening: _listening && _mic == _Mic.ready),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  l.kidsPlaySayWord(say.word.of(lang)),
                  textAlign: TextAlign.center,
                  style: KidsText.display.copyWith(color: KidsColors.rose700),
                ),
              ),
            ],
          ),
          if (_mic == _Mic.unavailable) ...[
            const SizedBox(height: 4),
            Text(l.kidsPlayMicOff, textAlign: TextAlign.center, style: KidsText.small),
            TextButton.icon(
              style: TextButton.styleFrom(minimumSize: const Size(64, 64), foregroundColor: KidsColors.night700),
              onPressed: _parentEnablesMic,
              icon: const Icon(Icons.lock_rounded),
              label: Text(l.kidsPlayParentMic, style: KidsText.small.copyWith(fontWeight: FontWeight.w700)),
            ),
          ],
          const SizedBox(height: 4),
          BigPlayButton(
            key: const ValueKey('story-skip'),
            label: l.kidsPlaySkipSay,
            background: KidsColors.sand,
            onPressed: _skip,
          ),
        ] else if (_runner.phase == StoryPhase.readyToContinue)
          Row(
            children: [
              RoundPlayButton(icon: Icons.replay_rounded, tooltip: l.kidsPlayReplayBeat, onPressed: _replayBeat),
              const SizedBox(width: 12),
              Expanded(
                child: BigPlayButton(
                  key: const ValueKey('story-next'),
                  label: l.kidsPlayNextBeat,
                  icon: Directionality.of(context) == TextDirection.rtl
                      ? Icons.arrow_back_rounded
                      : Icons.arrow_forward_rounded,
                  height: 76,
                  onPressed: _next,
                ),
              ),
            ],
          )
        else
          const SizedBox(height: 76),
      ],
    );
  }

  Widget _finished(L10n l) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Center(child: KhatamStarIcon(size: 72)),
      const SizedBox(height: 8),
      Text(l.kidsPlayTheEnd, textAlign: TextAlign.center, style: KidsText.display),
      if (_gotStar != null)
        Text(
          _gotStar! ? l.kidsPlayNewStar : l.kidsPlayStarAlreadyToday,
          textAlign: TextAlign.center,
          style: KidsText.body,
        ),
      const SizedBox(height: 16),
      BigPlayButton(label: l.kidsPlayReadAgain, icon: Icons.replay_rounded, onPressed: _restart),
      const SizedBox(height: 10),
      BigPlayButton(
        label: l.kidsPlayDone,
        background: KidsColors.teal500,
        foreground: Colors.white,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    ],
  );
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});
  final int count, index;

  @override
  Widget build(BuildContext context) => Semantics(
    label: L10n.of(context).kidsPlayBeatOf(kidsNumber(context, index + 1), kidsNumber(context, count)),
    excludeSemantics: true,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == index ? 36 : 14,
            height: 14,
            decoration: BoxDecoration(
              color: i == index
                  ? KidsColors.sun500
                  : i < index
                  ? KidsColors.teal200
                  : KidsColors.night300.withValues(alpha: .35),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
      ],
    ),
  );
}

/// The microphone button. It is not a button to press: it shows that the app
/// is listening and swells a little with the sound it hears.
class _MicOrb extends StatelessWidget {
  const _MicOrb({required this.level, required this.listening});

  final ValueListenable<double> level;
  final bool listening;

  @override
  Widget build(BuildContext context) {
    final reduced = context.reducedMotion;
    return ExcludeSemantics(
      child: SizedBox(
        width: 104,
        height: 104,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ValueListenableBuilder<double>(
              valueListenable: level,
              builder: (context, v, _) => Container(
                width: 84 + (reduced || !listening ? 0 : v * 20),
                height: 84 + (reduced || !listening ? 0 : v * 20),
                decoration: BoxDecoration(shape: BoxShape.circle, color: KidsColors.rose300.withValues(alpha: .45)),
              ),
            ),
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [KidsColors.rose300, KidsColors.rose500],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: .6), width: 2),
              ),
              child: Icon(listening ? Icons.mic_rounded : Icons.mic_off_rounded, size: 38, color: KidsColors.night900),
            ),
          ],
        ),
      ),
    );
  }
}
