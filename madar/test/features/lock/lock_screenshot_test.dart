@Tags(['screenshot'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/tokens.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/lock/presentation/lock_door.dart';
import 'package:madar/features/lock/presentation/lock_gate_host.dart';
import 'package:madar/features/lock/presentation/lock_screen.dart';
import 'package:madar/features/lock/presentation/security_settings.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/orbit/render/astrolabe/astrolabe_shaders.dart';

import '../../helpers/screenshot_harness.dart';
import 'lock_test_utils.dart';

const _dir = 'phase2/lock';

/// A stand-in for the app behind the lock.
class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CosmosBackdrop(
        seed: 0.2,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('مَدار', style: Theme.of(context).textTheme.displaySmall!.copyWith(color: t.gold)),
                const SizedBox(height: 24),
                for (var i = 0; i < 4; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GlassCard(
                      child: SizedBox(height: 48, child: Center(child: Text('•' * (i + 3)))),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<Widget> _app(
  WidgetTester tester,
  LockFixture fx, {
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  Widget? home,
  bool host = true,
  Color? customAccent,
}) async {
  await tester.runAsync(AstrolabePrograms.load);
  final prefs = await settingsPrefs(
    tester,
    AppSettings(onboarded: true, themeId: theme, languageCode: locale.languageCode),
  );
  return lockTestApp(
    prefs: prefs,
    overrides: fx.overrides,
    theme: theme,
    locale: locale,
    customAccent: customAccent,
    home: home ?? const _Home(),
    builder: host ? (context, child) => LockGateHost(child: child!) : null,
  );
}

String _d(String digit, {bool arabic = true}) => arabic ? Digits.toArabicIndic(digit) : digit;

Future<void> _typePin(WidgetTester tester, String pin, {bool arabic = true}) async {
  for (final c in pin.split('')) {
    await tester.tap(find.text(_d(c, arabic: arabic)).last);
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _pumpFor(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 20) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder, {int maxMs = 4000}) async {
  for (var t = 0; t < maxMs && finder.evaluate().isEmpty; t += 20) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(finder, findsWidgets);
}

/// Writes the boundary under [key] now (mid-animation frames).
Future<void> _snap(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.625);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File('screenshots/$name.png')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Offset _dialCenter(WidgetTester tester) => tester.getCenter(find.byType(LockScreen)) - const Offset(0, 40);

void main() {
  testWidgets('hold idle – ar lapis', (tester) async {
    final fx = await LockFixture.configured();
    await captureScreen(tester, await _app(tester, fx), '$_dir/lock_hold_idle_ar_lapis');
  });

  testWidgets('hold idle – en pearl', (tester) async {
    final fx = await LockFixture.configured();
    await captureScreen(
      tester,
      await _app(tester, fx, theme: MadarThemeId.pearl, locale: const Locale('en')),
      '$_dir/lock_hold_idle_en_pearl',
    );
  });

  testWidgets('reading the fingerprint – ar desert', (tester) async {
    final fx = await LockFixture.configured();
    fx.bio.holdPrompt = true;
    await captureScreen(
      tester,
      await _app(tester, fx, theme: MadarThemeId.desert),
      '$_dir/lock_reading_ar_desert',
      beforeCapture: (tester) async {
        final g = await tester.startGesture(_dialCenter(tester));
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        await g.up();
      },
    );
  });

  testWidgets('holding – ar lapis', (tester) async {
    final fx = await LockFixture.configured();
    await captureScreen(
      tester,
      await _app(tester, fx),
      '$_dir/lock_holding_ar_lapis',
      beforeCapture: (tester) async {
        await tester.startGesture(_dialCenter(tester));
        await tester.pump(const Duration(milliseconds: 100));
      },
    );
  });

  testWidgets('reading the fingerprint – en aurora', (tester) async {
    final fx = await LockFixture.configured();
    fx.bio.holdPrompt = true;
    await captureScreen(
      tester,
      await _app(tester, fx, theme: MadarThemeId.aurora, locale: const Locale('en')),
      '$_dir/lock_reading_en_aurora',
      beforeCapture: (tester) async {
        final g = await tester.startGesture(_dialCenter(tester));
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        await g.up();
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      },
    );
  });

  testWidgets('pin – en pearl', (tester) async {
    final fx = await LockFixture.configured(biometrics: false);
    await captureScreen(
      tester,
      await _app(tester, fx, theme: MadarThemeId.pearl, locale: const Locale('en')),
      '$_dir/lock_pin_en_pearl',
      beforeCapture: (tester) => _typePin(tester, '25', arabic: false),
    );
  });

  testWidgets('pin with fingerprint key – ar pearl', (tester) async {
    final fx = await LockFixture.configured();
    await captureScreen(
      tester,
      await _app(tester, fx, theme: MadarThemeId.pearl),
      '$_dir/lock_pin_ar_pearl',
      beforeCapture: (tester) async {
        await tester.tap(find.text('استخدم الرمز'));
        await tester.pump(const Duration(milliseconds: 600));
        await _typePin(tester, '258');
      },
    );
  });

  testWidgets('pin with a custom accent – ar lapis', (tester) async {
    final fx = await LockFixture.configured(biometrics: false);
    await captureScreen(
      tester,
      // A user-picked accent (Settings › Appearance › accent colour).
      await _app(tester, fx, customAccent: const Color(0xFFE0607E)),
      '$_dir/lock_pin_ar_lapis_custom_accent',
      beforeCapture: (tester) => _typePin(tester, '258'),
    );
  });

  testWidgets('wrong pin – ar emerald', (tester) async {
    final fx = await LockFixture.configured(biometrics: false);
    await captureScreen(
      tester,
      await _app(tester, fx, theme: MadarThemeId.emerald),
      '$_dir/lock_pin_wrong_ar_emerald',
      beforeCapture: (tester) => _typePin(tester, '1111'),
    );
  });

  testWidgets('locked out – ar desert', (tester) async {
    final now = DateTime(2026, 9, 28, 21, 40);
    final fx = await LockFixture.configured(
      biometrics: false,
      failures: 5,
      lockedUntil: now.add(const Duration(seconds: 27)),
      now: now,
    );
    await captureScreen(tester, await _app(tester, fx, theme: MadarThemeId.desert), '$_dir/lock_lockedout_ar_desert');
  });

  testWidgets('forgot pin – ar aurora', (tester) async {
    final fx = await LockFixture.configured();
    await captureScreen(
      tester,
      await _app(tester, fx, theme: MadarThemeId.aurora),
      '$_dir/lock_forgot_ar_aurora',
      beforeCapture: (tester) async {
        await tester.tap(find.text('استخدم الرمز'));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.tap(find.text('نسيت الرمز؟'));
        await tester.pump(const Duration(milliseconds: 100));
      },
    );
  });

  testWidgets('forgot pin without fingerprint – en lapis', (tester) async {
    final fx = await LockFixture.configured(biometrics: false);
    await captureScreen(
      tester,
      await _app(tester, fx, locale: const Locale('en')),
      '$_dir/lock_forgot_en_lapis',
      beforeCapture: (tester) async {
        await tester.tap(find.text('Forgot PIN?'));
        await tester.pump(const Duration(milliseconds: 100));
      },
    );
  });

  testWidgets('new pin after fingerprint – en lapis', (tester) async {
    final fx = await LockFixture.configured();
    await captureScreen(
      tester,
      await _app(tester, fx, locale: const Locale('en')),
      '$_dir/lock_newpin_en_lapis',
      beforeCapture: (tester) async {
        await tester.tap(find.text('Use PIN'));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.tap(find.text('Forgot PIN?'));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.tap(find.text('Confirm with fingerprint'));
        await tester.pump(const Duration(milliseconds: 600));
        await _typePin(tester, '97', arabic: false);
      },
    );
  });

  testWidgets('new pin after fingerprint – ar pearl', (tester) async {
    final fx = await LockFixture.configured();
    await captureScreen(
      tester,
      await _app(tester, fx, theme: MadarThemeId.pearl),
      '$_dir/lock_newpin_ar_pearl',
      beforeCapture: (tester) async {
        await tester.tap(find.text('استخدم الرمز'));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.tap(find.text('نسيت الرمز؟'));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.tap(find.text('تحقّق بالبصمة'));
        await tester.pump(const Duration(milliseconds: 600));
        await _typePin(tester, '97');
      },
    );
  });

  testWidgets('PIN check sheet during a lockout – ar pearl', (tester) async {
    final now = DateTime(2026, 9, 28, 21, 40);
    final fx = await LockFixture.configured(
      biometrics: false,
      failures: 6,
      lockedUntil: now.add(const Duration(seconds: 48)),
      now: now,
    );
    await captureScreen(
      tester,
      await _app(tester, fx, home: const _SettingsPage(), host: false, theme: MadarThemeId.pearl),
      '$_dir/pin_sheet_verify_lockedout_ar_pearl',
      beforeCapture: (tester) async {
        await tester.tap(find.byWidgetPredicate((w) => w is MadarSwitch && w.semanticLabel == 'قفل التطبيق'));
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      },
    );
  });

  testWidgets('unlock sequence – ar lapis', (tester) async {
    final fx = await LockFixture.configured(biometrics: false);
    final key = GlobalKey();
    await captureScreen(
      tester,
      RepaintBoundary(key: key, child: await _app(tester, fx)),
      '$_dir/lock_unlock_revealed_ar_lapis',
      beforeCapture: (tester) async {
        await _typePin(tester, '2580');
        await _pumpUntil(tester, find.text('أهلًا بعودتك'));
        await _pumpFor(tester, 900);
        await _snap(tester, key, '$_dir/lock_unlock_ignite_ar_lapis');
        await _pumpUntil(tester, find.byType(LockDoor));
        await _pumpFor(tester, 260);
        await _snap(tester, key, '$_dir/lock_unlock_door_a_ar_lapis');
        await _pumpFor(tester, 220);
        await _snap(tester, key, '$_dir/lock_unlock_door_b_ar_lapis');
      },
    );
  });

  testWidgets('privacy shield – ar lapis', (tester) async {
    final fx = await LockFixture.configured();
    await captureScreen(
      tester,
      await _app(tester, fx, home: const PrivacyShield(), host: false),
      '$_dir/lock_shield_ar_lapis',
    );
  });

  testWidgets('assembly frames – ar lapis', (tester) async {
    final fx = await LockFixture.configured();
    await captureScreen(
      tester,
      await _app(
        tester,
        fx,
        host: false,
        home: const Material(type: MaterialType.transparency, child: LockScreen(initialProgress: 0.62)),
      ),
      '$_dir/lock_assembly_062_ar_lapis',
    );
  });

  testWidgets('security settings (armed) – ar lapis', (tester) async {
    final fx = await LockFixture.configured();
    await captureScreen(
      tester,
      await _app(tester, fx, home: const _SettingsPage(), host: false),
      '$_dir/security_armed_ar_lapis',
    );
  });

  testWidgets('security settings (fresh) – en pearl', (tester) async {
    final fx = LockFixture.empty();
    await captureScreen(
      tester,
      await _app(
        tester,
        fx,
        home: const _SettingsPage(),
        host: false,
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
      ),
      '$_dir/security_fresh_en_pearl',
    );
  });

  testWidgets('choose a PIN sheet – ar emerald', (tester) async {
    final fx = LockFixture.empty();
    await captureScreen(
      tester,
      await _app(tester, fx, home: const _SettingsPage(), host: false, theme: MadarThemeId.emerald),
      '$_dir/pin_sheet_create_ar_emerald',
      beforeCapture: (tester) async {
        await tester.tap(find.byWidgetPredicate((w) => w is MadarSwitch && w.semanticLabel == 'قفل التطبيق'));
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        await _typePin(tester, '25');
      },
    );
  });

  testWidgets('fingerprint offer – en lapis', (tester) async {
    final fx = LockFixture.empty();
    await captureScreen(
      tester,
      await _app(tester, fx, home: const _SettingsPage(), host: false, locale: const Locale('en')),
      '$_dir/pin_sheet_bio_offer_en_lapis',
      beforeCapture: (tester) async {
        await tester.tap(find.byWidgetPredicate((w) => w is MadarSwitch && w.semanticLabel == 'App lock'));
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        await _typePin(tester, '2580', arabic: false);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.byIcon(Icons.check_rounded));
        await tester.pump(const Duration(milliseconds: 300));
        await _typePin(tester, '2580', arabic: false);
        await tester.pump(const Duration(milliseconds: 400));
      },
    );
  });
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage();

  @override
  Widget build(BuildContext context) => MadarScaffold(
    title: L10n.of(context).settingsTitle,
    body: const SingleChildScrollView(
      padding: EdgeInsetsDirectional.symmetric(horizontal: 20),
      child: SecuritySettingsSection(),
    ),
  );
}
