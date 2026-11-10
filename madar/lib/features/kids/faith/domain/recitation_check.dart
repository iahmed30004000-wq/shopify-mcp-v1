// The kid-level recitation check: pure rules, no engine.
//
// The recognition engine arrives in a later part; this file is the contract it
// plugs into and the rule that protects the child from its doubt:
//
//  * a hearing below [kidsRecitationThreshold] is NEVER a mistake: the child is
//    told «ما سمعت منيح، عيد», nothing is marked wrong, nothing is logged, no
//    streak is touched and no failed attempt is counted (the state below has no
//    attempts field at all, so there is nothing to escalate);
//  * a confident hearing earns one star.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/kids_section.dart' show kidsStarAwardProvider;

/// What the engine heard.
class KidsRecitationResult {
  const KidsRecitationResult({required this.confidence, this.wordsHeard = const []});

  /// 0..1. NaN and out-of-range values count as "not sure".
  final double confidence;
  final List<String> wordsHeard;
}

/// The recognition engine (a later part implements it, on the device only).
abstract interface class KidsRecitationChecker {
  /// Listens to the child saying [expectedText] and reports what it heard.
  Future<KidsRecitationResult> listen({required String expectedText});
}

/// The engine. Null until a later part provides it: the screen then shows the
/// calm «قريبًا» instead of a microphone that does nothing.
final kidsRecitationCheckerProvider = Provider<KidsRecitationChecker?>((ref) => null);

/// Below this the engine is "not sure". Deliberately generous to the child.
const double kidsRecitationThreshold = 0.6;

enum KidsRecitationPhase { idle, listening, tryAgain, wellDone }

/// A hearing, judged. Two outcomes only: there is no "wrong".
KidsRecitationPhase judgeKidsRecitation(KidsRecitationResult r, {double threshold = kidsRecitationThreshold}) {
  final c = r.confidence;
  if (c.isNaN || c < threshold) return KidsRecitationPhase.tryAgain;
  return KidsRecitationPhase.wellDone;
}

/// ('surah:ayah' used as the star's reason, the ayah text the child recites).
typedef KidsRecitationTarget = (String, String);

/// One ayah's check. State is just the phase: nothing counts attempts.
class KidsRecitationController extends Notifier<KidsRecitationPhase> {
  KidsRecitationController(this.target);

  final KidsRecitationTarget target;
  String get ayahKey => target.$1;
  String get expectedText => target.$2;

  bool _awarded = false;

  @override
  KidsRecitationPhase build() => KidsRecitationPhase.idle;

  /// Tap on the microphone (or on «عيد», which is the same thing).
  Future<void> listen() async {
    final checker = ref.read(kidsRecitationCheckerProvider);
    if (checker == null || state == KidsRecitationPhase.listening) return;
    state = KidsRecitationPhase.listening;
    KidsRecitationPhase next;
    try {
      next = judgeKidsRecitation(await checker.listen(expectedText: expectedText));
    } on Object {
      // No microphone, a call interrupted it ...: still just "again", never an error.
      next = KidsRecitationPhase.tryAgain;
    }
    state = next;
    if (next == KidsRecitationPhase.wellDone && !_awarded) {
      // One star per ayah per visit: stars are a collection, not a farm.
      _awarded = true;
      await ref.read(kidsStarAwardProvider)('kids_recitation:$ayahKey');
    }
  }
}

final kidsRecitationControllerProvider =
    NotifierProvider.autoDispose.family<KidsRecitationController, KidsRecitationPhase, KidsRecitationTarget>(
      KidsRecitationController.new,
    );
