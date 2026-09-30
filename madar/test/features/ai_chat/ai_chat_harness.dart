// Test harness for the AI chat: the real theme, localisations, digit and
// motion scopes over an in-memory database, a silent sound engine,
// in-memory secure storage, a scripted AI provider (or a fake HTTP
// transport under the real providers) and a fake summary picker.
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/encryption.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/motion/motion_kit.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/ai_chat/ai_chat.dart';
import 'package:madar/features/data/data.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_chat_fakes.dart';

class AiHaptics implements HapticsService {
  final List<Haptic> fired = [];
  @override
  bool enabled = true;
  @override
  void fire(Haptic haptic) => fired.add(haptic);
}

final DateTime aiTestNow = DateTime(2026, 9, 30, 10, 30);

/// A fixed summary the fake picker "approves".
const String aiTestSummary = '''# Madar summary – 2026-09-30

A personal summary the user chose to share.

## Faith

- Prayers logged: 34/35 in the last 7 days

## Money

- Budget: 62% of the month spent''';

/// What the fake picker does when opened.
class FakePicker {
  FakePicker({this.result = aiTestSummary});

  /// Returned markdown (null = the user dismissed the preview).
  String? result;
  final List<bool> calls = [];

  Future<String?> call(BuildContext context, {required bool andSend}) async {
    calls.add(andSend);
    return result;
  }
}

class AiTestEnv {
  AiTestEnv(this.db, this.secrets, this.picker, this.anthropic, this.openai, this.transport, this.prefs);

  final MadarDatabase db;
  final MemorySecretStore secrets;
  final FakePicker picker;
  final FakeAiProvider anthropic;
  final FakeAiProvider openai;

  /// Set when the real providers run over a fake transport.
  final FakeTransport? transport;
  final SharedPreferences prefs;
}

MadarDatabase aiTestDatabase() =>
    MadarDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));

Future<(Widget, AiTestEnv)> buildAiApp(
  WidgetTester tester, {
  required Widget home,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('en'),
  bool reducedMotion = false,
  Map<String, String> keys = const {},
  FakePicker? picker,
  FakeTransport? transport,
  bool realPicker = false,
  Future<void> Function(MadarDatabase db)? beforePump,
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
  final db = aiTestDatabase();
  await tester.runAsync(() => db.customSelect('SELECT 1').get());
  addTearDown(() => tester.runAsync(db.close));
  if (beforePump != null) await tester.runAsync(() => beforePump(db));
  final sound = SilentSoundService();
  final haptics = AiHaptics();
  Fx.install(FeedbackService(sound, haptics));
  final secrets = MemorySecretStore(keys);
  final (registry, anthropic, openai) = fakeRegistry();
  final pick = picker ?? FakePicker();
  var ids = 0;
  final env = AiTestEnv(db, secrets, pick, anthropic, openai, transport, prefs);
  final arabic = locale.languageCode == 'ar';
  final app = ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      soundServiceProvider.overrideWithValue(sound),
      hapticsServiceProvider.overrideWithValue(haptics),
      databaseProvider.overrideWithValue(db),
      aiSecretStoreProvider.overrideWithValue(secrets),
      if (transport != null)
        aiTransportProvider.overrideWithValue(transport)
      else
        aiProviderRegistryProvider.overrideWithValue(registry),
      if (!realPicker) aiContextPickerProvider.overrideWithValue(pick.call),
      aiClockProvider.overrideWithValue(() => aiTestNow),
      aiIdProvider.overrideWithValue(() => 'id-${ids++}'),
      dataClockProvider.overrideWithValue(() => DateTime(2026, 9, 30, 10)),
      ...overrides,
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildMadarTheme(theme, arabic: arabic),
      locale: locale,
      supportedLocales: L10n.supportedLocales,
      localizationsDelegates: L10n.localizationsDelegates,
      builder: (context, child) => MadarFormatScope(
        digits: DigitStyle.auto,
        child: MotionScope(reduced: reducedMotion, child: CelebrationOverlay(child: child!)),
      ),
      home: home,
    ),
  );
  return (app, env);
}

/// Lets real asynchronous work (database) progress between frames.
Future<void> settleAsync(WidgetTester tester, {int rounds = 10}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Pumps [n] 50 ms frames.
Future<void> frames(WidgetTester tester, [int n = 16]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Phone-sized surface.
void usePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(412, 915) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}
