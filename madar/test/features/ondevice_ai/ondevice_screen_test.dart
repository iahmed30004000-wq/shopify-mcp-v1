// Settings › «الذكاء على الجوال»: what this phone can run and why, the three
// ways with the active one marked, his choice, the optional model files, and
// the two promises. Arabic and English, 320 dp, text scale 1.3, 48 dp targets.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/repositories/key_value_repository.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/ondevice_ai/data/model_download_manager.dart';
import 'package:madar/features/ondevice_ai/data/ondevice_providers.dart';
import 'package:madar/features/ondevice_ai/domain/model_catalog.dart';
import 'package:madar/features/ondevice_ai/domain/model_path.dart';
import 'package:madar/features/ondevice_ai/presentation/ondevice_settings_screen.dart';
import 'package:madar/features/reading/data/chunked_downloader.dart';
import 'package:madar/features/reading/data/download_ports.dart';
import 'package:madar/features/reading/domain/download_plan.dart';

import '../../core/i18n/text_scan.dart';
import '../ai_chat/ai_chat_harness.dart';
import '../reading/data/support/reading_fakes.dart';
import 'support/ondevice_fakes.dart';

typedef _S = OnDeviceSettingsScreen;

/// Everything the screen's providers need, as fakes.
class ScreenEnv {
  ScreenEnv({DeviceCapabilities? caps}) : probe = FakeProbe(caps ?? capableCaps());

  final FakeProbe probe;
  final FakeAuthGate auth = FakeAuthGate();
  final MemoryModelSink sink = MemoryModelSink();
  final FakeDownloadStateStore store = FakeDownloadStateStore();
  final FakeFreeSpaceProbe space = FakeFreeSpaceProbe(1 << 30);
  final FakeConnectivityProbe net = FakeConnectivityProbe();
  late final FakeRangeHttpClient http = FakeRangeHttpClient(content);
  final content = sampleBytes(50);

  late final ModelCatalogEntry verified = ModelCatalogEntry(
    id: 'test-org/test-model',
    displayName: 'Test model',
    kind: ModelKind.language,
    license: 'Apache-2.0',
    sourcePage: 'https://example.com',
    notes: '',
    sizeBytes: content.length,
    sha256: hashOf(content),
    downloadUrl: 'https://example.com/m.bin',
    unverified: false,
  );

  ModelDownloadManager manager() => ModelDownloadManager(
    auth: auth,
    store: store,
    sink: sink,
    planner: const DownloadPlanner(partSizeBytes: 16),
    newDownloader: () => ChunkedDownloader(
      client: http,
      store: store,
      space: space,
      sink: sink,
      connectivity: net,
      delay: (_) async {},
      config: const DownloaderConfig(reserveBytes: 0),
    ),
  );
}

void tall(WidgetTester tester, {double width = 412, double scale = 1}) {
  tester.view.physicalSize = Size(width, 4200) * 2;
  tester.view.devicePixelRatio = 2;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<(AiTestEnv, ScreenEnv)> pump(
  WidgetTester tester, {
  String lang = 'ar',
  DeviceCapabilities? caps,
  bool realCatalog = true,
  double width = 412,
  double scale = 1,
  void Function(ScreenEnv env)? setUp,
}) async {
  tall(tester, width: width, scale: scale);
  final env = ScreenEnv(caps: caps);
  setUp?.call(env);
  final manager = env.manager();
  final overrides = <Override>[
    onDeviceProbeProvider.overrideWithValue(env.probe),
    modelDownloadManagerProvider.overrideWithValue(manager),
    if (!realCatalog) modelCatalogProvider.overrideWithValue([env.verified]),
  ];
  final (app, ai) = await buildAiApp(
    tester,
    home: const OnDeviceSettingsScreen(),
    locale: Locale(lang),
    outsideAllowed: false,
    overrides: overrides,
  );
  addTearDown(manager.dispose);
  await tester.pumpWidget(app);
  await settleAsync(tester);
  await frames(tester, 10);
  return (ai, env);
}

L10n _l(String lang) => lookupL10n(Locale(lang));

Future<dynamic> _storedPrefs(WidgetTester tester, AiTestEnv ai) =>
    tester.runAsync(() => KeyValueRepository(ai.db).getJson(PathPrefs.storageKey));

void main() {
  group('the capability section', () {
    testWidgets('[ar] a phone with AICore: the plain sentence, AICore marked, Arabic digits', (tester) async {
      await pump(tester);
      final l = _l('ar');
      expect(find.text('جوالك بيقدر يشغّل الموديل بنفسه عبر نظام أندرويد.'), findsOneWidget);
      expect(find.text(l.ondeviceReasonAicore), findsOneWidget);
      expect(find.byKey(_S.activeMark(ModelPath.aicore)), findsOneWidget);
      expect(find.byKey(_S.activeMark(ModelPath.inAppEngine)), findsNothing);
      expect(find.byKey(_S.activeMark(ModelPath.bridge)), findsNothing);
      // The phone's own numbers, in the owner's digits.
      expect(find.text(l.ondeviceFactAndroidValue('٣٦')), findsOneWidget);
      expect(find.text(l.ondeviceFactMemoryValue('٨', '١٦')), findsOneWidget);
      // Model names and licences are Latin proper names (Gemma E2B, Apache-2.0):
      // a Western digit is fine there, never inside Arabic text.
      expect(paintedStrings(tester).where((s) => westernDigit.hasMatch(s) && !latinLetter.hasMatch(s)), isEmpty);
    });

    testWidgets('«يلزم قياس على الجوال» is shown until a real engine is plugged in', (tester) async {
      await pump(tester);
      expect(find.byKey(_S.measureNote), findsOneWidget);
      expect(find.textContaining('يلزم قياس على الجوال'), findsOneWidget);
    });

    testWidgets('[ar] low storage: the exact sentence with both numbers, and the bridge is used', (tester) async {
      await pump(
        tester,
        caps: capableCaps(aicore: const FeatureProbe.unsupported(), freeGb: 1),
      );
      expect(find.text('رح نستعمل الجسر اللي بيعمل نسخ ولصق.'), findsOneWidget);
      // On the card and on the engine's own row.
      expect(find.textContaining('ما في مساحة كفاية: بدك ٣ جيجا فاضية وعندك ١ جيجا.'), findsWidgets);
      expect(find.byKey(_S.activeMark(ModelPath.bridge)), findsOneWidget);
      expect(find.textContaining('مش ممكن هلأ'), findsWidgets);
    });

    testWidgets('[ar] too little memory names both sizes', (tester) async {
      await pump(
        tester,
        caps: capableCaps(aicore: const FeatureProbe.unsupported(), totalGb: 4, weightsInstalled: true),
      );
      expect(find.textContaining('ذاكرة الجوال صغيرة: بدنا ٦ جيجا وعندك ٤ جيجا.'), findsWidgets);
    });

    testWidgets('[en] the same phone in English, Western digits only', (tester) async {
      await pump(tester, lang: 'en', caps: capableCaps(aicore: const FeatureProbe.unsupported(), freeGb: 1));
      expect(find.text('We will use the bridge, which works by copy and paste.'), findsOneWidget);
      expect(find.textContaining('Not enough space: you need 3 GB free and you have 1 GB.'), findsWidgets);
      expect(paintedStrings(tester).where(easternDigit.hasMatch), isEmpty);
    });

    testWidgets('the probe says nothing at all (step A today): the bridge, and nothing breaks', (tester) async {
      await pump(tester, caps: const DeviceCapabilities.unknown());
      expect(find.byKey(_S.activeMark(ModelPath.bridge)), findsOneWidget);
      expect(find.text(_l('ar').ondeviceReasonBridge), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('all three ways are listed, each with its own line', (tester) async {
      await pump(tester);
      for (final p in ModelPath.values) {
        expect(find.byKey(_S.pathTile(p)), findsOneWidget);
      }
      expect(find.text(_l('ar').ondevicePathAicore), findsWidgets);
      expect(find.text(_l('ar').ondevicePathEngine), findsWidgets);
      expect(find.text(_l('ar').ondevicePathBridge), findsWidgets);
    });

    testWidgets('«افحص من جديد» asks the phone again', (tester) async {
      final (_, env) = await pump(tester);
      final before = env.probe.calls;
      env.probe.caps = capableCaps(aicore: const FeatureProbe.unsupported());
      await tester.tap(find.byKey(_S.recheckButton));
      await settleAsync(tester);
      await frames(tester, 6);
      expect(env.probe.calls, greaterThan(before));
      expect(find.byKey(_S.activeMark(ModelPath.aicore)), findsNothing);
    });
  });

  group('his choice', () {
    testWidgets('automatic is the default; picking the bridge is stored and marked', (tester) async {
      final (ai, _) = await pump(tester);
      final l = _l('ar');
      expect(await _storedPrefs(tester, ai), isNull, reason: 'a fresh install stores nothing');
      expect(find.byKey(_S.activeMark(ModelPath.aicore)), findsOneWidget);

      await tester.tap(find.descendant(of: find.byKey(_S.choiceRow), matching: find.text(l.ondeviceChoiceBridge)));
      await settleAsync(tester);
      await frames(tester, 8);
      expect(find.byKey(_S.activeMark(ModelPath.bridge)), findsOneWidget);
      expect(find.byKey(_S.activeMark(ModelPath.aicore)), findsNothing);
      expect(find.text(l.ondeviceReasonForced), findsOneWidget);
      expect((await _storedPrefs(tester, ai) as Map)['forced'], 'bridge');

      await tester.tap(find.descendant(of: find.byKey(_S.choiceRow), matching: find.text(l.ondeviceChoiceAuto)));
      await settleAsync(tester);
      await frames(tester, 8);
      expect(find.byKey(_S.activeMark(ModelPath.aicore)), findsOneWidget);
      expect((await _storedPrefs(tester, ai) as Map).containsKey('forced'), isFalse);
    });

    testWidgets('forcing a way the phone cannot run says so and uses the automatic pick', (tester) async {
      await pump(tester, caps: capableCaps(aicore: const FeatureProbe.unsupported()));
      final l = _l('ar');
      await tester.tap(find.descendant(of: find.byKey(_S.choiceRow), matching: find.text(l.ondeviceChoiceAicore)));
      await settleAsync(tester);
      await frames(tester, 8);
      expect(find.text(l.ondeviceReasonForcedBlocked), findsOneWidget);
      expect(find.text(l.ondeviceBlockAicoreUnsupported), findsWidgets);
      expect(find.byKey(_S.activeMark(ModelPath.aicore)), findsNothing);
    });

    testWidgets('the Wi-Fi switch is on by default, and turning it off is stored', (tester) async {
      final (ai, _) = await pump(tester);
      final l = _l('ar');
      expect(tester.widget<MadarSwitch>(find.byKey(_S.wifiSwitch)).value, isTrue);
      expect(find.text(l.ondeviceDownloadWifi), findsWidgets);
      await tester.tap(find.byKey(_S.wifiSwitch));
      await settleAsync(tester);
      await frames(tester, 8);
      expect(tester.widget<MadarSwitch>(find.byKey(_S.wifiSwitch)).value, isFalse);
      expect(find.text(l.ondeviceDownloadWifi), findsNothing);
      expect(find.text(l.ondeviceDownload), findsWidgets);
      expect((await _storedPrefs(tester, ai) as Map)['wifiOnly'], isFalse);
    });
  });

  group('the model files (optional)', () {
    testWidgets('the placeholder entries are shown as such and cannot be downloaded', (tester) async {
      final (_, env) = await pump(tester);
      final l = _l('ar');
      for (final e in ModelCatalog.entries) {
        expect(find.byKey(_S.modelCard(e.id)), findsOneWidget);
        final button = tester.widget<MadarButton>(find.byKey(_S.downloadButton(e.id)));
        expect(button.onPressed, isNull, reason: '${e.id} is unverified');
      }
      expect(find.text(l.ondeviceModelUnverified), findsNWidgets(2));
      expect(find.text(l.ondeviceModelsNote), findsOneWidget, reason: 'the app works without them');
      await tester.tap(find.byKey(_S.downloadButton(ModelCatalog.recitationId)), warnIfMissed: false);
      await frames(tester, 4);
      expect(env.auth.asked, 0);
      expect(env.http.totalRequests, 0);
    });

    testWidgets('a verified model: fingerprint, progress, installed, then removed', (tester) async {
      final (_, env) = await pump(tester, realCatalog: false);
      final id = env.verified.id;
      final l = _l('ar');
      expect(find.byKey(_S.removeButton(id)), findsNothing);

      await tester.tap(find.byKey(_S.downloadButton(id)));
      await settleAsync(tester);
      await frames(tester, 12);
      expect(env.auth.asked, 1, reason: 'the fingerprint comes first');
      expect(find.text(l.ondeviceInstalled), findsOneWidget);
      expect(find.byKey(_S.removeButton(id)), findsOneWidget);
      expect(find.byKey(_S.downloadButton(id)), findsNothing);
      expect(env.sink.files[id], env.content, reason: 'the whole file, verified');

      await tester.tap(find.byKey(_S.removeButton(id)));
      await frames(tester, 8);
      expect(find.text(l.ondeviceRemoveConfirmTitle), findsOneWidget);
      await tester.tap(find.text(l.ondeviceRemove).last);
      await settleAsync(tester);
      await frames(tester, 10);
      expect(env.sink.files, isEmpty);
      expect(find.byKey(_S.downloadButton(id)), findsOneWidget);
      expect(find.text(l.ondeviceRemoved), findsOneWidget);
    });

    testWidgets('cancelling a running download shows progress, then stops and clears it', (tester) async {
      final (_, env) = await pump(tester, realCatalog: false);
      final id = env.verified.id;
      final l = _l('ar');
      // Hold the first part so the download is visibly "in progress".
      final gate = Completer<void>();
      env.http.beforeRange = (start, end) => start == 0 ? gate.future : null;

      await tester.tap(find.byKey(_S.downloadButton(id)));
      await settleAsync(tester);
      await frames(tester, 6);
      expect(find.byKey(_S.progressBar(id)), findsOneWidget);
      expect(find.byKey(_S.cancelButton(id)), findsOneWidget);
      expect(find.byKey(_S.downloadButton(id)), findsNothing);

      await tester.tap(find.byKey(_S.cancelButton(id)));
      await frames(tester, 2);
      gate.complete();
      await settleAsync(tester);
      await frames(tester, 10);
      expect(find.byKey(_S.progressBar(id)), findsNothing);
      expect(find.byKey(_S.downloadButton(id)), findsOneWidget);
      expect(find.text(l.ondeviceInstalled), findsNothing);
      expect(env.sink.files, isEmpty);
      expect(env.sink.parts, isEmpty);
    });

    testWidgets('a refused fingerprint says why, and nothing is downloaded', (tester) async {
      final (_, env) = await pump(tester, realCatalog: false, setUp: (e) => e.auth.allow = false);
      await tester.tap(find.byKey(_S.downloadButton(env.verified.id)));
      await settleAsync(tester);
      await frames(tester, 8);
      expect(find.text(_l('ar').ondeviceRefusedAuth), findsOneWidget);
      expect(env.http.totalRequests, 0);
    });

    testWidgets('on mobile data, Wi-Fi only waits and says so', (tester) async {
      final (_, env) = await pump(tester, realCatalog: false, setUp: (e) => e.net.kind = NetworkKind.cellular);
      await tester.tap(find.byKey(_S.downloadButton(env.verified.id)));
      await settleAsync(tester);
      await frames(tester, 10);
      expect(find.text(_l('ar').ondevicePausedWifi), findsOneWidget);
      expect(env.http.totalRequests, 0);
    });
  });

  group('the promises', () {
    testWidgets('nothing leaves the phone, and no religious rulings: both lines, in both languages', (tester) async {
      await pump(tester);
      expect(find.byKey(_S.privacyLocal), findsOneWidget);
      expect(find.byKey(_S.privacyReligious), findsOneWidget);
      expect(find.textContaining('ما بيطلع أي شي من جوالك'), findsOneWidget);
      expect(find.textContaining('ما بيعطي فتوى'), findsOneWidget);
    });

    testWidgets('[en]', (tester) async {
      await pump(tester, lang: 'en');
      expect(find.textContaining('nothing leaves it'), findsOneWidget);
      expect(find.textContaining('never gives a religious ruling'), findsOneWidget);
    });
  });

  for (final lang in ['ar', 'en']) {
    group('[$lang] layout', () {
      testWidgets('320 dp wide at text scale 1.3: no overflow, scrolled end to end', (tester) async {
        await pump(tester, lang: lang, width: 320, scale: 1.3, caps: capableCaps(aicore: const FeatureProbe.unsupported(), freeGb: 1));
        await frames(tester, 6);
        expect(tester.takeException(), isNull);
        final scrollable = find.byType(Scrollable).first;
        await tester.drag(scrollable, const Offset(0, -2000), warnIfMissed: false);
        await frames(tester, 6);
        expect(tester.takeException(), isNull);
      });

      testWidgets('with a verified model on screen too, still no overflow at 320 dp / 1.3', (tester) async {
        await pump(tester, lang: lang, width: 320, scale: 1.3, realCatalog: false);
        expect(tester.takeException(), isNull);
      });

      testWidgets('48 dp targets and a label on every tappable', (tester) async {
        final handle = tester.ensureSemantics();
        await pump(tester, lang: lang, width: 320, scale: 1.3);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    });
  }
}
