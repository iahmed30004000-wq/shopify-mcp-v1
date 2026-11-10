// Part 15, step A: the proofs that are about the WHOLE frame, not one class.
//  * no network on an on-device path (the transport assertion Part 2 uses:
//    a recording AiTransport with nothing queued, plus a dart:io HttpClient
//    factory that fails the test if anything creates a client);
//  * the app is fully usable without the model (the daily chat's offline
//    parser needs nothing from this feature, and nothing in day_chat or
//    ai_chat imports it);
//  * the provider wiring is safe by default: the bridge.
import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/features/ai_chat/ai_chat.dart' show aiTransportProvider;
import 'package:madar/features/day_chat/day_chat.dart';
import 'package:madar/features/ondevice_ai/data/ondevice_providers.dart';
import 'package:madar/features/ondevice_ai/domain/model_path.dart';
import 'package:madar/features/ondevice_ai/domain/model_router.dart';
import 'package:madar/features/ondevice_ai/domain/on_device_model.dart';
import 'package:madar/features/ondevice_ai/domain/religious_guard.dart';

import '../ai_chat/ai_chat_fakes.dart';
import 'support/ondevice_fakes.dart';

/// Fails the test the moment anything in the process creates an HTTP client.
class _NoHttp extends HttpOverrides {
  int created = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    created++;
    throw StateError('an on-device path created an HttpClient');
  }
}

String _read(String path) => File(path).readAsStringSync();

List<File> _dartFiles(String dir) => [
  for (final f in Directory(dir).listSync(recursive: true))
    if (f is File && f.path.endsWith('.dart')) f,
];

void main() {
  final quranStandIn = QuranVerseIndex.fromSurahs([
    ['سماء زرقاء وبحر عميق جدا ونجوم بعيدة'],
  ]);

  late Directory tmp;
  setUpAll(() => tmp = Directory.systemTemp.createTempSync('madar-ondevice-wiring-'));
  tearDownAll(() => tmp.deleteSync(recursive: true));

  MadarDatabase memoryDb() => MadarDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));

  ProviderContainer container({
    required DeviceCapabilities caps,
    Map<ModelPath, OnDeviceModel>? models,
    FakeTransport? transport,
  }) {
    final db = memoryDb();
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        modelStorageRootProvider.overrideWithValue(() async => tmp),
        onDeviceProbeProvider.overrideWithValue(FakeProbe(caps)),
        quranVerseIndexProvider.overrideWith((ref) async => quranStandIn),
        if (models != null) onDeviceModelsProvider.overrideWithValue(models),
        if (transport != null) aiTransportProvider.overrideWithValue(transport),
      ],
    );
    addTearDown(() async {
      c.dispose();
      await db.close();
    });
    return c;
  }

  group('no network on an on-device path', () {
    test('AICore and the in-app engine answer without one HTTP request or one HttpClient', () async {
      final transport = FakeTransport(); // nothing queued: any send() would throw
      final no = _NoHttp();
      await HttpOverrides.runWithHttpOverrides(() async {
        for (final path in [ModelPath.aicore, ModelPath.inAppEngine]) {
          final model = FakeOnDeviceModel(path: path, tokens: ['Today ', 'you walked.']);
          final c = container(
            caps: capableCaps(
              aicore: path == ModelPath.aicore ? const FeatureProbe.available() : const FeatureProbe.unsupported(),
              weightsInstalled: true,
            ),
            models: {path: model},
            transport: transport,
          );
          expect(await c.read(pathChoiceProvider.future).then((v) => v.path), path);
          final router = await c.read(modelRouterProvider.future);
          final out = await router.run(const ModelRequest(instructions: 'rules', input: 'my day'));
          expect(out, isA<Answered>(), reason: path.name);
          expect(model.requests, hasLength(1));
        }
        // Every way a request could be refused or fall back, too.
        final failing = FakeOnDeviceModel(
          tokens: ['a'],
          failAfter: 1,
          failure: const ModelFailure(ModelFailureKind.outOfMemory),
        );
        final c = container(caps: capableCaps(), models: {ModelPath.aicore: failing}, transport: transport);
        await c.read(pathChoiceProvider.future);
        final router = await c.read(modelRouterProvider.future);
        expect(await router.run(const ModelRequest(instructions: 'r', input: 'i')), isA<UseBridge>());
      }, no);
      expect(transport.requests, isEmpty, reason: 'the AI chat transport was never used');
      expect(no.created, 0, reason: 'no HttpClient was ever created');
    });

    test('the inference code does not even import a network client (source scan)', () {
      final offenders = <String>[];
      final bannedFragments = [
        'HttpClient',
        'package:http/',
        'dart:html',
        'WebSocket',
        'Socket.connect',
        'ai_chat/data/transport.dart',
        'AiTransport',
        'model_http.dart',
        'quran_com_client',
      ];
      for (final f in _dartFiles('lib/features/ondevice_ai')) {
        final name = f.path.split('/lib/features/ondevice_ai/').last.split('lib/features/ondevice_ai/').last;
        // The only network code is the weights downloader's ranged GET, and
        // the one file that wires it to the manager.
        if (name.endsWith('data/model_http.dart') || name.endsWith('data/ondevice_providers.dart')) continue;
        final text = _read(f.path);
        for (final b in bannedFragments) {
          if (text.contains(b)) offenders.add('$name uses $b');
        }
      }
      expect(offenders, isEmpty);
    });

    test('model_http.dart is imported only by the providers that wire the download', () {
      final importers = [
        for (final f in _dartFiles('lib'))
          if (!f.path.endsWith('model_http.dart') && _read(f.path).contains('model_http.dart')) f.path,
      ];
      expect(importers.length, 1);
      expect(importers.single, endsWith('ondevice_ai/data/ondevice_providers.dart'));
    });

    test('the router, the guard and the model interface never import dart:io at all', () {
      for (final n in ['model_router.dart', 'religious_guard.dart', 'on_device_model.dart', 'capability_check.dart']) {
        expect(_read('lib/features/ondevice_ai/domain/$n'), isNot(contains('dart:io')), reason: n);
      }
    });
  });

  group('the app is fully usable without the model', () {
    test('nothing in the daily chat or the AI chat imports the on-device feature (Part 7 is unchanged)', () {
      for (final dir in ['lib/features/day_chat', 'lib/features/ai_chat', 'lib/features/ai_bridge']) {
        for (final f in _dartFiles(dir)) {
          expect(_read(f.path), isNot(contains('ondevice_ai')), reason: f.path);
        }
      }
    });

    test('the offline parser is the first reader and needs nothing: a line is read with the model absent', () {
      final reading = DayChatReader(baseCurrency: 'JOD').read(
        'صرفت ٥ دنانير قهوة',
        now: DateTime(2026, 11, 10, 20),
        day: DateTime(2026, 11, 10),
      );
      expect(reading.pieces.map((p) => p.kind), contains(DayChatKind.expense));
      expect(reading.hasUnread, isFalse);
      // What it cannot read stays «unread» - it is not silently handed to a model.
      final odd = DayChatReader().read('زقزقة عصفور على الغصن', now: DateTime(2026, 11, 10, 20), day: DateTime(2026, 11, 10));
      expect(odd.pieces, isNotEmpty);
    });

    test('the day summary is built with no model and no probe', () {
      final summary = DaySummaryBuilder().build(DaySummaryInput(day: DateTime(2026, 11, 10), now: DateTime(2026, 11, 10, 21)));
      expect(summary.isEmpty, isTrue);
    });

    test('with the real step-A wiring (stub engines) every request ends at the bridge, never an error', () async {
      final c = container(caps: capableCaps()); // AICore "available" but only the stub engine exists
      expect(await c.read(pathChoiceProvider.future).then((v) => v.path), ModelPath.aicore);
      final router = await c.read(modelRouterProvider.future);
      final out = await router.run(const ModelRequest(instructions: 'r', input: 'i'));
      expect(out, isA<UseBridge>());
      expect((out as UseBridge).reason, BridgeReason.modelNotReady);
    });
  });

  group('the provider wiring is safe by default', () {
    test('while the phone has not answered yet the active path is the bridge', () {
      final c = container(caps: capableCaps());
      expect(c.read(activeModelPathProvider), ModelPath.bridge);
    });

    test('once it answered: AICore; the stub phone of step A: the bridge; the owner forcing the bridge: the bridge', () async {
      var c = container(caps: capableCaps());
      await c.read(pathChoiceProvider.future);
      expect(c.read(activeModelPathProvider), ModelPath.aicore);

      c = container(caps: const DeviceCapabilities(aicore: FeatureProbe.unsupported(), engine: FeatureProbe.unsupported()));
      await c.read(pathChoiceProvider.future);
      expect(c.read(activeModelPathProvider), ModelPath.bridge);

      c = container(caps: capableCaps());
      await c.read(onDevicePrefsProvider.future);
      await c.read(onDevicePrefsProvider.notifier).change((s) => s.copyWith(forced: ModelPath.bridge));
      await c.read(pathChoiceProvider.future);
      expect(c.read(activeModelPathProvider), ModelPath.bridge);
    });

    test('a probe that throws leaves the bridge as the active path', () async {
      final db = memoryDb();
      final c = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          modelStorageRootProvider.overrideWithValue(() async => tmp),
          onDeviceProbeProvider.overrideWithValue(_ThrowingProbe()),
        ],
      );
      addTearDown(() async {
        c.dispose();
        await db.close();
      });
      await expectLater(c.read(pathChoiceProvider.future), throwsA(isA<StateError>()));
      expect(c.read(activeModelPathProvider), ModelPath.bridge);
    });

    test('the router is only built when the Quran text is there: fails closed', () async {
      final db = memoryDb();
      final c = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          modelStorageRootProvider.overrideWithValue(() async => tmp),
          onDeviceProbeProvider.overrideWithValue(FakeProbe(capableCaps())),
          quranVerseIndexProvider.overrideWith((ref) async => throw StateError('no quran')),
        ],
      );
      addTearDown(() async {
        c.dispose();
        await db.close();
      });
      await expectLater(c.read(modelRouterProvider.future), throwsA(isA<StateError>()));
    });
  });
}

class _ThrowingProbe extends FakeProbe {
  _ThrowingProbe() : super(capableCaps());

  @override
  Future<DeviceCapabilities> probe() async => throw StateError('native crash');
}
