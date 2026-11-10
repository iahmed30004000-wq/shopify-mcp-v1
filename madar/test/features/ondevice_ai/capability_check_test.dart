// Part 15: which of the three ways a phone gets, and why. Pure Dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/ondevice_ai/domain/capability_check.dart';
import 'package:madar/features/ondevice_ai/domain/model_path.dart';

import 'support/ondevice_fakes.dart';

PathChoice choose(DeviceCapabilities c, {PathPrefs prefs = const PathPrefs(), CapabilityThresholds? t}) =>
    CapabilityCheck.choose(c, prefs, thresholds: t ?? const CapabilityThresholds());

void main() {
  group('the automatic order: AICore, then the engine in the app, then the bridge', () {
    test('a phone with AICore gets AICore, and says so', () {
      final c = choose(capableCaps());
      expect(c.path, ModelPath.aicore);
      expect(c.reason.code, PathReasonCode.aicoreReady);
      expect(c.canRun(ModelPath.aicore), isTrue);
      expect(c.blocks[ModelPath.bridge], isNull, reason: 'the bridge is never blocked');
    });

    test('without AICore, a capable phone with the weights gets the engine in the app', () {
      final c = choose(capableCaps(aicore: const FeatureProbe.unsupported(), weightsInstalled: true));
      expect(c.path, ModelPath.inAppEngine);
      expect(c.reason.code, PathReasonCode.engineReady);
      expect(c.blocks[ModelPath.aicore]?.code, BlockCode.aicoreUnsupported);
    });

    test('without AICore and without the weights: the bridge, and the reason names the missing weights', () {
      final c = choose(capableCaps(aicore: const FeatureProbe.unsupported()));
      expect(c.path, ModelPath.bridge);
      expect(c.reason.code, PathReasonCode.bridgeOnly);
      expect(c.reason.blocker?.code, BlockCode.weightsMissing);
    });

    test('neither probe is available: the bridge, the engine probe is the headline', () {
      final c = choose(
        capableCaps(aicore: const FeatureProbe.unsupported(), engine: const FeatureProbe.unsupported()),
      );
      expect(c.path, ModelPath.bridge);
      expect(c.reason.blocker?.code, BlockCode.engineUnsupported);
    });

    test('the stub phone of step A (both unsupported, real numbers) gets the bridge', () {
      final c = choose(
        const DeviceCapabilities(
          sdkInt: 36,
          totalRamBytes: 12 * gib,
          availableRamBytes: 6 * gib,
          freeStorageBytes: 80 * gib,
          aicore: FeatureProbe.unsupported(),
          engine: FeatureProbe.unsupported(),
        ),
      );
      expect(c.path, ModelPath.bridge);
    });
  });

  group('memory, storage, battery, heat', () {
    test('too little memory in total: the engine can never run, even when forced', () {
      final caps = capableCaps(aicore: const FeatureProbe.unsupported(), totalGb: 4, weightsInstalled: true);
      final c = choose(caps);
      expect(c.path, ModelPath.bridge);
      final b = c.blocks[ModelPath.inAppEngine]!;
      expect(b.code, BlockCode.ramTooLow);
      expect(b.hard, isTrue);
      expect(b.needed, 6 * gib);
      expect(b.have, 4 * gib);

      final forced = choose(caps, prefs: const PathPrefs(forced: ModelPath.inAppEngine));
      expect(forced.path, ModelPath.bridge, reason: 'a hard blocker beats his choice');
      expect(forced.reason.code, PathReasonCode.userForcedBlocked);
      expect(forced.reason.blocker?.code, BlockCode.ramTooLow);
    });

    test('memory busy right now is soft: automatic skips the engine, a forced choice keeps it', () {
      final caps = capableCaps(
        aicore: const FeatureProbe.unsupported(),
        availableGb: 1,
        weightsInstalled: true,
      );
      final auto = choose(caps);
      expect(auto.path, ModelPath.bridge);
      expect(auto.reason.blocker?.code, BlockCode.ramBusy);
      expect(auto.reason.blocker?.hard, isFalse);

      final forced = choose(caps, prefs: const PathPrefs(forced: ModelPath.inAppEngine));
      expect(forced.path, ModelPath.inAppEngine);
      expect(forced.reason.code, PathReasonCode.userForced);
    });

    test('low storage: the message carries both numbers (need 3 GB, have 1 GB)', () {
      final c = choose(capableCaps(aicore: const FeatureProbe.unsupported(), freeGb: 1));
      expect(c.path, ModelPath.bridge);
      final b = c.reason.blocker!;
      expect(b.code, BlockCode.storageLow);
      expect(b.needed, 3 * gib);
      expect(b.have, 1 * gib);
    });

    test('storage does not matter once the weights are on the phone', () {
      final c = choose(capableCaps(aicore: const FeatureProbe.unsupported(), freeGb: 0, weightsInstalled: true));
      expect(c.path, ModelPath.inAppEngine);
    });

    test('battery saver: automatic uses the bridge even where AICore exists; forcing AICore wins', () {
      final caps = capableCaps(batterySaver: true);
      final auto = choose(caps);
      expect(auto.path, ModelPath.bridge);
      expect(auto.reason.blocker?.code, BlockCode.batterySaver);

      final forced = choose(caps, prefs: const PathPrefs(forced: ModelPath.aicore));
      expect(forced.path, ModelPath.aicore);
      expect(forced.reason.code, PathReasonCode.userForced);
    });

    test('thermal throttling: warm is soft, hot is hard', () {
      final warm = capableCaps(thermal: ThermalState.moderate);
      expect(choose(warm).path, ModelPath.bridge);
      expect(choose(warm).reason.blocker?.code, BlockCode.thermal);
      expect(choose(warm, prefs: const PathPrefs(forced: ModelPath.aicore)).path, ModelPath.aicore);

      final hot = capableCaps(thermal: ThermalState.severe);
      expect(choose(hot).path, ModelPath.bridge);
      final forcedHot = choose(hot, prefs: const PathPrefs(forced: ModelPath.aicore));
      expect(forcedHot.path, ModelPath.bridge, reason: 'never run a model on a phone that is overheating');
      expect(forcedHot.reason.code, PathReasonCode.userForcedBlocked);

      expect(choose(capableCaps(thermal: ThermalState.light)).path, ModelPath.aicore, reason: 'light is fine');
    });

    test('Android older than the engine\'s minimum', () {
      final c = choose(capableCaps(aicore: const FeatureProbe.unsupported(), sdkInt: 24, weightsInstalled: true));
      expect(c.blocks[ModelPath.inAppEngine]?.code, BlockCode.sdkTooLow);
      expect(c.blocks[ModelPath.inAppEngine]?.needed, 26);
      expect(c.blocks[ModelPath.inAppEngine]?.have, 24);
    });
  });

  group('the user forcing a path', () {
    test('forcing the bridge always works, even on a phone that could run a model', () {
      final c = choose(capableCaps(), prefs: const PathPrefs(forced: ModelPath.bridge));
      expect(c.path, ModelPath.bridge);
      expect(c.reason.code, PathReasonCode.userForced);
    });

    test('forcing AICore on a phone without it falls back to the automatic pick, saying why', () {
      final c = choose(
        capableCaps(aicore: const FeatureProbe.unsupported(), weightsInstalled: true),
        prefs: const PathPrefs(forced: ModelPath.aicore),
      );
      expect(c.path, ModelPath.inAppEngine, reason: 'the automatic order, not the bridge, when the engine can run');
      expect(c.reason.code, PathReasonCode.userForcedBlocked);
      expect(c.reason.forced, ModelPath.aicore);
      expect(c.reason.blocker?.code, BlockCode.aicoreUnsupported);
    });

    test('forcing the engine with no weights is refused until they are downloaded', () {
      final c = choose(capableCaps(), prefs: const PathPrefs(forced: ModelPath.inAppEngine));
      expect(c.path, ModelPath.aicore);
      expect(c.reason.code, PathReasonCode.userForcedBlocked);
      expect(c.reason.blocker?.code, BlockCode.weightsMissing);
    });
  });

  group('feature-detect, pin, never assume', () {
    test('an unknown AICore probe downgrades, it never counts as available', () {
      final c = choose(capableCaps(aicore: const FeatureProbe.unknown()));
      expect(c.path, ModelPath.bridge);
      expect(c.blocks[ModelPath.aicore]?.code, BlockCode.aicoreUnknown);
    });

    test('a version we did not pin downgrades (a developer preview that changed)', () {
      const t = CapabilityThresholds(knownAiCoreVersions: {'preview-1'});
      final measured = choose(capableCaps(aicore: const FeatureProbe.available(version: 'preview-1')), t: t);
      expect(measured.path, ModelPath.aicore);
      final changed = choose(capableCaps(aicore: const FeatureProbe.available(version: 'preview-2')), t: t);
      expect(changed.path, ModelPath.bridge);
      expect(changed.blocks[ModelPath.aicore]?.code, BlockCode.aicoreChanged);
      final unversioned = choose(capableCaps(aicore: const FeatureProbe.available()), t: t);
      expect(unversioned.blocks[ModelPath.aicore]?.code, BlockCode.aicoreChanged, reason: 'no version is not a pinned one');
    });

    test('numbers the phone did not give are not read as "enough"', () {
      const caps = DeviceCapabilities(aicore: FeatureProbe.unsupported(), engine: FeatureProbe.available());
      final c = choose(caps);
      expect(c.path, ModelPath.bridge);
      expect(c.blocks[ModelPath.inAppEngine]?.code, BlockCode.numbersUnknown);
    });

    test('a phone with no answer at all gets the bridge and nothing throws', () {
      final c = choose(const DeviceCapabilities.unknown());
      expect(c.path, ModelPath.bridge);
      expect(c.blocks[ModelPath.aicore]?.code, BlockCode.aicoreUnknown);
      expect(c.blocks[ModelPath.inAppEngine]?.code, BlockCode.engineUnknown);
    });

    test('unknown thermal state is not treated as hot', () {
      expect(choose(capableCaps(thermal: ThermalState.unknown)).path, ModelPath.aicore);
    });

    test('probe words that are not exactly known read as unknown', () {
      expect(ProbeStatus.parse('available'), ProbeStatus.available);
      expect(ProbeStatus.parse('unsupported'), ProbeStatus.unsupported);
      for (final raw in <Object?>['Available', 'maybe', '', 1, true, null, 'available ']) {
        expect(ProbeStatus.parse(raw), ProbeStatus.unknown, reason: '$raw');
      }
    });

    test('Android thermal codes fold, and strangers are unknown', () {
      expect(ThermalState.fromAndroid(0), ThermalState.none);
      expect(ThermalState.fromAndroid(2), ThermalState.moderate);
      expect(ThermalState.fromAndroid(3), ThermalState.severe);
      expect(ThermalState.fromAndroid(5), ThermalState.critical);
      expect(ThermalState.fromAndroid(-1), ThermalState.unknown);
      expect(ThermalState.fromAndroid('hot'), ThermalState.unknown);
      expect(ThermalState.fromAndroid(null), ThermalState.unknown);
    });
  });

  group('his stored choice', () {
    test('round-trips, and anything unreadable reads as the defaults', () {
      const p = PathPrefs(forced: ModelPath.inAppEngine, wifiOnly: false);
      expect(PathPrefs.fromJson(p.toJson()), p);
      expect(PathPrefs.fromJson(null), const PathPrefs());
      expect(PathPrefs.fromJson('x'), const PathPrefs());
      expect(PathPrefs.fromJson({'forced': 'warp-drive', 'wifiOnly': 'yes'}), const PathPrefs());
      expect(const PathPrefs().wifiOnly, isTrue, reason: 'Wi-Fi only by default');
      expect(const PathPrefs().forced, isNull, reason: 'automatic by default');
    });
  });
}
