import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/widgets/widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const spec = MiniAstrolabeSpec(
    fajr: 0.19,
    sunrise: 0.26,
    dhuhr: 0.52,
    asr: 0.64,
    maghrib: 0.78,
    isha: 0.83,
    next: 2,
  );

  WidgetBuild build({String headline = 'العصر', MiniAstrolabeSpec s = spec}) => WidgetBuild(
    WidgetSnapshot(
      kind: MadarWidgetKind.prayer,
      languageCode: 'ar',
      private: true,
      title: 'الصلاة القادمة',
      until: DateTime(2026, 10, 3),
      stale: 'افتح مدار',
      pages: [WidgetPage(from: null, headline: headline, image: 'astro_asr')],
    ),
    images: {'astro_asr': s},
  );

  group('WidgetBridge', () {
    late FakeWidgetPlatform platform;
    late List<(MiniAstrolabeSpec, bool)> rendered;
    late WidgetBridge bridge;
    setUp(() {
      platform = FakeWidgetPlatform(installed: {MadarWidgetKind.prayer});
      rendered = [];
      bridge = WidgetBridge(
        platform,
        renderImage: (s, {required dark}) async {
          rendered.add((s, dark));
          return Uint8List.fromList([dark ? 1 : 0]);
        },
      );
    });

    test('publishes the JSON with the light and dark images', () async {
      expect(await bridge.push(build()), isTrue);
      expect(platform.published, hasLength(1));
      final p = platform.published.single;
      expect(p.kind, MadarWidgetKind.prayer);
      expect(WidgetSnapshot.decode(p.json)!.pages.single.headline, 'العصر');
      expect(p.images!.keys, unorderedEquals(['astro_asr_light', 'astro_asr_dark']));
      expect(p.images!['astro_asr_dark'], [1]);
      expect(rendered, [(spec, false), (spec, true)]);
    });

    test('writes nothing when nothing changed; only the JSON when the images are the same', () async {
      await bridge.push(build());
      expect(await bridge.push(build()), isFalse);
      expect(platform.published, hasLength(1));
      expect(await bridge.push(build(headline: 'المغرب')), isTrue);
      expect(platform.published, hasLength(2));
      expect(platform.published.last.images, isNull, reason: 'images kept');
      expect(rendered, hasLength(2));
    });

    test('re-renders when a drawing changes', () async {
      await bridge.push(build());
      final moved = const MiniAstrolabeSpec(
        fajr: 0.19,
        sunrise: 0.26,
        dhuhr: 0.52,
        asr: 0.64,
        maghrib: 0.78,
        isha: 0.83,
        next: 3,
      );
      expect(await bridge.push(build(s: moved)), isTrue);
      expect(platform.published.last.images, isNotNull);
      expect(rendered.last, (moved, true));
    });

    test('forget / forgetAll write everything again; clearAll clears Android too', () async {
      await bridge.push(build());
      bridge.forget(MadarWidgetKind.prayer);
      expect(await bridge.push(build()), isTrue);
      bridge.forgetAll();
      expect(await bridge.push(build()), isTrue);
      await bridge.clearAll();
      expect(platform.clears, 1);
      expect(platform.stored, isEmpty);
      expect(await bridge.push(build()), isTrue);
      await bridge.remove(MadarWidgetKind.prayer);
      expect(platform.removed, [MadarWidgetKind.prayer]);
      expect(await bridge.push(build()), isTrue);
    });
  });

  group('MethodChannelWidgetPlatform', () {
    const channel = MethodChannel(MethodChannelWidgetPlatform.channelName);
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late List<MethodCall> calls;
    late MethodChannelWidgetPlatform platform;

    setUp(() {
      calls = [];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return switch (call.method) {
          'installed' => ['meds', 'weather', 'prayer'],
          'takeLaunch' => '/meds',
          'publish' => true,
          _ => null,
        };
      });
      platform = MethodChannelWidgetPlatform();
    });

    tearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      platform.dispose();
    });

    test('speaks the channel protocol', () async {
      expect(await platform.installed(), {MadarWidgetKind.meds, MadarWidgetKind.prayer});
      await platform.publish(MadarWidgetKind.meds, '{"v":1}', images: {'x_light': Uint8List.fromList([1, 2])});
      await platform.publish(MadarWidgetKind.tasks, '{}');
      await platform.remove(MadarWidgetKind.budget);
      await platform.clearAll();
      expect(await platform.takeLaunch(), '/meds');
      expect([for (final c in calls) c.method], ['installed', 'publish', 'publish', 'remove', 'clearAll', 'takeLaunch']);
      final publish = calls[1].arguments as Map;
      expect(publish['kind'], 'meds');
      expect(publish['json'], '{"v":1}');
      expect((publish['images'] as Map)['x_light'], [1, 2]);
      expect((calls[2].arguments as Map)['images'], isNull);
      expect(calls[3].arguments, {'kind': 'budget'});
    });

    test('Android\'s calls arrive as events', () async {
      final events = <WidgetPlatformEvent>[];
      final sub = platform.events.listen(events.add);
      for (final m in ['changed', 'launch', 'unknown']) {
        await messenger.handlePlatformMessage(
          MethodChannelWidgetPlatform.channelName,
          const StandardMethodCodec().encodeMethodCall(MethodCall(m)),
          (_) {},
        );
      }
      await Future<void>.delayed(Duration.zero);
      expect(events, [WidgetPlatformEvent.changed, WidgetPlatformEvent.launch]);
      await sub.cancel();
    });

    test('off Android nothing is installed and nothing throws', () async {
      messenger.setMockMethodCallHandler(channel, null);
      expect(await platform.installed(), isEmpty);
      await platform.publish(MadarWidgetKind.meds, '{}');
      await platform.clearAll();
      expect(await platform.takeLaunch(), isNull);
      await clearWidgetData();
    });
  });
}
