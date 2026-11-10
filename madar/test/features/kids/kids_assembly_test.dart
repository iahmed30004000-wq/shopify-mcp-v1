// «مدار الصغار» assembled: every section is listed, the religious ones stay
// dark, and the parent check a section asks for is the real PIN gate that
// answers yes or no without leaving kids mode.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/kids/kids.dart';
import 'package:madar/features/kids/stories/stories.dart' show kidsParentAskProvider;

import '../../helpers/test_app.dart';
import 'shell/kids_test_utils.dart';

/// The kids harness plus the real «are you the parent?» check from kids.dart.
Future<TestApp> _pumpWithRealParentCheck(WidgetTester tester, KidsHarness h) => pumpMadarApp(
  tester,
  settings: const AppSettings(onboarded: true, languageCode: 'ar'),
  overrides: [...h.overrides, kidsParentAskProvider.overrideWith((ref) => () => kidsAskParent(ref))],
);

void main() {
  const religiousIds = {'juz_amma', 'prayer_wudu', 'prophet_stories', 'manners', 'kids_adhkar'};

  test('twelve sections, unique ids, and exactly the five religious ones are marked religious', () {
    final ids = kidsAllSections.map((s) => s.id).toList();
    expect(ids.toSet(), hasLength(ids.length), reason: 'ids are unique');
    expect(kidsAllSections, hasLength(12));
    final religious = kidsAllSections.where((s) => s.religious).map((s) => s.id).toSet();
    expect(religious, hasLength(5));
    for (final s in kidsAllSections.where((s) => !s.religious)) {
      expect(s.id, isNot(anyOf(religiousIds)), reason: '${s.id} is not religious');
    }
  });

  test('with the religious flag off, a child sees seven sections and none of the five', () {
    final container = ProviderContainer(overrides: kidsOverrides());
    addTearDown(container.dispose);
    final visible = container.read(visibleKidsSectionsProvider);
    expect(visible, hasLength(7));
    expect(visible.any((s) => s.religious), isFalse);
    final orders = visible.map((s) => s.order).toList();
    expect([...orders]..sort(), orders, reason: 'in order');
  });

  testWidgets('the kids home shows the seven titles and no religious one', (tester) async {
    final h = await KidsHarness.create(initial: KidsHarness.on(), sections: kidsAllSections);
    await pumpKids(tester, h);
    for (final s in kidsAllSections) {
      expect(find.byKey(ValueKey('kids-tile-${s.id}')), s.religious ? findsNothing : findsOneWidget, reason: s.id);
    }
  });

  group('the parent check inside a section', () {
    testWidgets('the right PIN answers yes and kids mode stays on', (tester) async {
      final h = await KidsHarness.create(initial: KidsHarness.on(), sections: kidsAllSections, pin: '2580');
      final app = await _pumpWithRealParentCheck(tester, h);
      final context = tester.element(find.byKey(const ValueKey('kids-home')));
      final ask = ProviderScope.containerOf(context).read(kidsParentAskProvider);
      final answer = ask();
      await tester.pump(const Duration(milliseconds: 300));
      await typeKidsPin(tester, '2580');
      await tester.pump(const Duration(milliseconds: 400));
      expect(await answer, isTrue);
      expect(pathOf(app), startsWith('/kids'), reason: 'still inside');
      expect(h.store.state.on, isTrue, reason: 'kids mode untouched');
    });

    testWidgets('a wrong PIN does not pass; going back answers no', (tester) async {
      final h = await KidsHarness.create(initial: KidsHarness.on(), sections: kidsAllSections, pin: '2580');
      await _pumpWithRealParentCheck(tester, h);
      final context = tester.element(find.byKey(const ValueKey('kids-home')));
      final ask = ProviderScope.containerOf(context).read(kidsParentAskProvider);
      var done = false;
      bool? result;
      unawaited(ask().then((v) {
        done = true;
        result = v;
      }));
      await tester.pump(const Duration(milliseconds: 300));
      await typeKidsPin(tester, '1111');
      expect(done, isFalse, reason: 'a wrong PIN leaves the question open');
      final l = lookupL10n(const Locale('ar'));
      await tester.tap(find.text(l.kidsShellGateBack));
      await tester.pump(const Duration(milliseconds: 400));
      expect(done, isTrue);
      expect(result, isFalse);
      expect(h.store.state.on, isTrue);
    });
  });
}
