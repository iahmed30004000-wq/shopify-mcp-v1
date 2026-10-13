// Visual critic pass for the lists (Part 3b): the real screens with the
// real fonts and shaders, in Arabic and English, across Lapis, Pearl and
// Aurora, plus text scale 1.3. PNGs land in madar/screenshots/lists/.
//
//   flutter test --tags screenshot test/features/lists/lists_screenshot_test.dart
@Tags(['screenshot'])
@Timeout(Duration(minutes: 20))
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/features/lists/lists.dart';
import 'package:madar/features/money/budget/budget.dart';
import 'package:madar/features/money/budget/presentation/shopping_post_bar.dart';

import '../../helpers/screenshot_harness.dart';
import 'lists_harness.dart';

const _dir = 'lists';

void main() {
  Future<void> shot(
    WidgetTester tester,
    String name,
    Widget Function(String? listId) home, {
    MadarThemeId theme = MadarThemeId.lapis,
    Locale locale = const Locale('ar'),
    ListsSeed seed = ListsSeed.shopping,
    double textScale = 1,
    Future<void> Function(WidgetTester tester)? beforeCapture,
  }) async {
    final (app, _) = await buildListsApp(
      tester,
      home: home,
      theme: theme,
      locale: locale,
      seed: seed,
      textScale: textScale,
    );
    await captureScreen(
      tester,
      app,
      '$_dir/$name',
      beforeCapture: (tester) async {
        for (var i = 0; i < 6; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
          await tester.pump(const Duration(milliseconds: 50));
        }
        if (beforeCapture != null) await beforeCapture(tester);
      },
    );
  }

  /// A list the way the router composes it for a budget envelope: the
  /// shared screen with Money's post bar underneath.
  Widget Function(String? id) shoppingScreen() =>
      (id) => ListScreen(listId: id ?? 'none', bottomBar: ShoppingPostBar(listId: id ?? 'none'));

  /// A list of any other host: the plain shared screen.
  Widget Function(String? id) plainScreen() => (id) => ListScreen(listId: id ?? 'none');

  /// Every list he has, the way the router composes `/lists`.
  Widget Function(String? id) allScreen() => (_) => AllListsScreen(onOpenList: (_, _) {});

  Widget Function(String? id) hostScreen(ListHost host) =>
      (_) => HostListsScreen(host: host, onOpenList: (_, _) {});

  // -------------------------------------------------- the host's lists ----

  testWidgets('an envelope with two lists – Arabic, Lapis', (tester) async {
    await shot(tester, 'host_ar_lapis', hostScreen(listsEnvelope), seed: ListsSeed.twoLists);
  });

  testWidgets('an envelope with two lists – English, Pearl', (tester) async {
    await shot(
      tester,
      'host_en_pearl',
      hostScreen(listsEnvelope),
      seed: ListsSeed.twoLists,
      theme: MadarThemeId.pearl,
      locale: const Locale('en'),
    );
  });

  testWidgets('a fresh envelope, nothing yet – Arabic, Aurora', (tester) async {
    await shot(
      tester,
      'host_empty_ar_aurora',
      hostScreen(listsEnvelope),
      seed: ListsSeed.empty,
      theme: MadarThemeId.aurora,
    );
  });

  testWidgets('an envelope with two lists – text scale 1.3, Arabic, Lapis', (tester) async {
    await shot(
      tester,
      'host_ar_lapis_scale130',
      hostScreen(listsEnvelope),
      seed: ListsSeed.twoLists,
      textScale: 1.3,
    );
  });

  // ------------------------------------------------- the shopping list ----

  testWidgets('the shopping list at home – Arabic, Lapis', (tester) async {
    await shot(tester, 'shopping_ar_lapis', shoppingScreen());
  });

  testWidgets('the shopping list in the shop, ready to post – Arabic, Lapis', (tester) async {
    await shot(tester, 'shopped_ar_lapis', shoppingScreen(), seed: ListsSeed.shopped);
  });

  testWidgets('the shopping list in the shop – English, Pearl', (tester) async {
    await shot(
      tester,
      'shopped_en_pearl',
      shoppingScreen(),
      seed: ListsSeed.shopped,
      theme: MadarThemeId.pearl,
      locale: const Locale('en'),
    );
  });

  testWidgets('a posted list – Arabic, Aurora', (tester) async {
    await shot(tester, 'posted_ar_aurora', shoppingScreen(), seed: ListsSeed.posted, theme: MadarThemeId.aurora);
  });

  testWidgets('the shopping list in the shop – text scale 1.3, Arabic, Pearl', (tester) async {
    await shot(
      tester,
      'shopped_ar_pearl_scale130',
      shoppingScreen(),
      seed: ListsSeed.shopped,
      theme: MadarThemeId.pearl,
      textScale: 1.3,
    );
  });

  testWidgets('the shopping list – text scale 1.3, English, Aurora', (tester) async {
    await shot(
      tester,
      'shopped_en_aurora_scale130',
      shoppingScreen(),
      seed: ListsSeed.shopped,
      theme: MadarThemeId.aurora,
      locale: const Locale('en'),
      textScale: 1.3,
    );
  });

  testWidgets('a brand-new, empty list – Arabic, Pearl', (tester) async {
    await shot(tester, 'items_empty_ar_pearl', shoppingScreen(), seed: ListsSeed.newList, theme: MadarThemeId.pearl);
  });

  testWidgets('a list that is gone – English, Lapis', (tester) async {
    await shot(tester, 'gone_en_lapis', plainScreen(), seed: ListsSeed.empty, locale: const Locale('en'));
  });

  // ------------------------------------------------ all of his lists ----

  testWidgets('every list, grouped by its record – Arabic, Lapis', (tester) async {
    await shot(tester, 'all_ar_lapis', allScreen(), seed: ListsSeed.manyHosts);
  });

  testWidgets('every list, grouped by its record – English, Aurora', (tester) async {
    await shot(
      tester,
      'all_en_aurora',
      allScreen(),
      seed: ListsSeed.manyHosts,
      theme: MadarThemeId.aurora,
      locale: const Locale('en'),
    );
  });

  testWidgets('no lists at all – text scale 1.3, Arabic, Pearl', (tester) async {
    await shot(
      tester,
      'all_empty_ar_pearl_scale130',
      allScreen(),
      seed: ListsSeed.empty,
      theme: MadarThemeId.pearl,
      textScale: 1.3,
    );
  });

  // ------------------------------------------- where he reaches it from ----

  testWidgets('the budget row carries the list it hangs on – Arabic, Lapis', (tester) async {
    await shot(
      tester,
      'budget_row_ar_lapis',
      (_) => const BudgetScreen(animateBackdrop: false),
      seed: ListsSeed.twoLists,
    );
  });

  // --------------------------------------------------- the trip's list ----

  testWidgets('the packing list on a trip – Arabic, Lapis', (tester) async {
    await shot(tester, 'trip_ar_lapis', plainScreen(), seed: ListsSeed.trip);
  });

  testWidgets('the packing list on a trip – English, Aurora', (tester) async {
    await shot(
      tester,
      'trip_en_aurora',
      plainScreen(),
      seed: ListsSeed.trip,
      theme: MadarThemeId.aurora,
      locale: const Locale('en'),
    );
  });
}
