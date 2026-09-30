@Tags(['screenshot'])
@Timeout(Duration(minutes: 30))
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/tokens.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/features/notification_center/notification_center.dart';

import '../../helpers/screenshot_harness.dart';
import 'nc_harness.dart';

const _dir = 'notifications';

/// Opens a sheet over an empty page once the first frame is up.
class _SheetHost extends ConsumerStatefulWidget {
  const _SheetHost(this.open);

  final Future<void> Function(BuildContext context, WidgetRef ref) open;

  @override
  ConsumerState<_SheetHost> createState() => _SheetHostState();
}

class _SheetHostState extends ConsumerState<_SheetHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(widget.open(context, ref)));
  }

  @override
  Widget build(BuildContext context) => const MadarScaffold(title: '', body: SizedBox.shrink());
}

/// A home-panel stand-in with the bell in its app bar.
class _BellPage extends StatelessWidget {
  const _BellPage();

  @override
  Widget build(BuildContext context) => const MadarScaffold(
    title: 'مَدار',
    actions: [NotificationBell()],
    body: Padding(
      padding: EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.l, Space.gutter, 0),
      child: Row(
        children: [
          NotificationBell(variant: MadarButtonVariant.secondary),
          SizedBox(width: Space.l),
          NotificationBell(variant: MadarButtonVariant.primary, size: MadarButtonSize.large),
        ],
      ),
    ),
  );
}

void main() {
  Future<void> shot(
    WidgetTester tester,
    String name,
    Widget home, {
    MadarThemeId theme = MadarThemeId.lapis,
    Locale locale = const Locale('ar'),
    bool seed = true,
    Future<void> Function(WidgetTester tester)? beforeCapture,
  }) async {
    final (app, _) = await buildNcApp(
      tester,
      home: home,
      theme: theme,
      locale: locale,
      groupSettings: ncGroupSettings,
      seed: seed ? (env) => seedWeek(env, lang: locale.languageCode) : null,
    );
    await captureScreen(tester, app, '$_dir/$name', beforeCapture: beforeCapture);
  }

  const upcoming = NotificationCenterScreen(initialTab: CenterTab.upcoming);
  const recent = NotificationCenterScreen(initialTab: CenterTab.recent);

  testWidgets('upcoming, Arabic, Lapis', (tester) async {
    await shot(tester, 'upcoming_ar_lapis', upcoming);
  });

  testWidgets('recent, Arabic, Lapis', (tester) async {
    await shot(tester, 'recent_ar_lapis', recent);
  });

  testWidgets('upcoming, English, Pearl', (tester) async {
    await shot(tester, 'upcoming_en_pearl', upcoming, theme: MadarThemeId.pearl, locale: const Locale('en'));
  });

  testWidgets('recent, English, Pearl', (tester) async {
    await shot(tester, 'recent_en_pearl', recent, theme: MadarThemeId.pearl, locale: const Locale('en'));
  });

  testWidgets('recent, Arabic, Emerald', (tester) async {
    await shot(tester, 'recent_ar_emerald', recent, theme: MadarThemeId.emerald);
  });

  testWidgets('upcoming scrolled, Arabic, Desert', (tester) async {
    await shot(
      tester,
      'upcoming_scrolled_ar_desert',
      upcoming,
      theme: MadarThemeId.desert,
      beforeCapture: (tester) => tester.drag(find.text('أذان العصر'), const Offset(0, -700), warnIfMissed: false),
    );
  });

  testWidgets('recent, English, Aurora', (tester) async {
    await shot(tester, 'recent_en_aurora', recent, theme: MadarThemeId.aurora, locale: const Locale('en'));
  });

  testWidgets('empty, Arabic, Lapis', (tester) async {
    await shot(tester, 'empty_upcoming_ar_lapis', upcoming, seed: false);
  });

  testWidgets('empty recent, English, Pearl', (tester) async {
    await shot(
      tester,
      'empty_recent_en_pearl',
      recent,
      seed: false,
      theme: MadarThemeId.pearl,
      locale: const Locale('en'),
    );
  });

  testWidgets('settings sheet, Arabic, Lapis', (tester) async {
    await shot(tester, 'settings_sheet_ar_lapis', _SheetHost((c, ref) => showNotificationSettingsSheet(c, ref)));
  });

  testWidgets('settings sheet, English, Pearl', (tester) async {
    await shot(
      tester,
      'settings_sheet_en_pearl',
      _SheetHost((c, ref) => showNotificationSettingsSheet(c, ref)),
      theme: MadarThemeId.pearl,
      locale: const Locale('en'),
    );
  });

  testWidgets('mute sheet, English, Lapis', (tester) async {
    await shot(
      tester,
      'mute_sheet_en_lapis',
      _SheetHost((c, ref) => CenterActions.pickMute(c, ref, NotificationGroup.medications)),
      locale: const Locale('en'),
    );
  });

  testWidgets('long-press menu, Arabic, Lapis', (tester) async {
    await shot(
      tester,
      'menu_ar_lapis',
      recent,
      beforeCapture: (tester) async {
        await tester.longPress(find.byType(NotificationRow).at(1));
      },
    );
  });

  testWidgets('bell, Arabic, Lapis', (tester) async {
    await shot(tester, 'bell_ar_lapis', const _BellPage());
  });
}
