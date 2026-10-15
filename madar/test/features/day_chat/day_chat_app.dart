// Harness for Part 7's chat screen: the **real** Madar app (router, gates,
// app lock, quick-add handler) over an in-memory database holding only the
// handful of his own names the reader needs, a frozen day, and an AI
// transport that is recorded and never expected to be asked.
//
// Nothing in here is real data of his: the app ships none, and a fresh
// install opens an empty chat.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show AsyncValue;
import 'package:madar/app/app_gate.dart' show databaseUnlockProvider;
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/encryption.dart' show MemorySecretStore;
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/providers.dart' show databaseProvider;
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/ai_chat/ai_chat.dart' show aiSecretStoreProvider, aiTransportProvider;
import 'package:madar/features/custom_modules/custom_modules.dart';
import 'package:madar/features/data/data.dart' show RecordingDataFileBridge, dataFileBridgeProvider;
import 'package:madar/features/day_chat/day_chat.dart';

import '../ai_chat/ai_chat_fakes.dart' show FakeTransport;
import '../lock/lock_test_utils.dart';
import '../../helpers/test_app.dart';

/// Wednesday 14 October 2026, 20:30 – after Isha, so the prayer day is
/// still the 14th (the same moment step 1's round-trip test uses).
final DateTime dayChatNow = DateTime(2026, 10, 14, 20, 30);
final DateTime dayChatToday = DateTime(2026, 10, 14);

/// The one line he types in most of these tests: five facts at once.
const String fiveFacts = 'صرفت ٥ دنانير قهوة، صليت العصر بالمسجد، تمرين صدر ٤×١٢، وجع الركبة ٦، شربت كاسة مي';

/// His own names the reader recognises (a tracker, a food, an exercise, a
/// person, one open task) – and nothing else.
Future<void> seedDayChat(MadarDatabase db) async {
  final repos = Repositories(db);
  await CustomModulesService(repos, clock: () => dayChatNow).createModule(
    const ModuleDefinition(
      id: '',
      name: 'سكر الدم',
      colorArgb: 0xFF112233,
      planetKey: 'health',
      fields: [ModuleField(id: 'f1', label: 'القراءة', type: FieldType.number, min: 40, max: 500)],
    ),
  );
  await repos.foods.insert(FoodsCompanion.insert(name: 'منسف', unit: Value('طبق'), defaultPortion: Value(1)));
  await repos.exercises.insert(ExercisesCompanion.insert(name: 'صدر'));
  await repos.people.insert(PeopleCompanion.insert(name: 'رنا'));
  await repos.tasks.insert(TasksCompanion.insert(title: 'تقرير الشغل', window: Value(PrayerWindow.dhuhr)));
}

/// A chat screen on the tree, with the recorded transport beside it.
class DayChatApp {
  DayChatApp(this.app, this.transport);

  final TestApp app;

  /// Every HTTPS request the AI chat's one transport was asked for. The
  /// chat must never add to it – see `day_chat_screen_test.dart`.
  final FakeTransport transport;

  Repositories get repos => app.repos;

  /// The database the app is running on (its own, or the one it was handed).
  MadarDatabase get db => app.container.read(databaseProvider);
}

/// Nothing may reach a real socket, a real share sheet or the phone's
/// secure storage from a chat test.
List<Override> dayChatOverrides(FakeTransport transport) => [
  aiTransportProvider.overrideWithValue(transport),
  aiSecretStoreProvider.overrideWithValue(MemorySecretStore()),
  dataFileBridgeProvider.overrideWithValue(RecordingDataFileBridge()),
  ...LockFixture.empty().overrides,
];

/// Pumps the whole app at the daily chat.
///
/// Pass [on] to open the app over a database that is already there – that
/// is what a restart is: the same data, a brand new app.
Future<DayChatApp> pumpDayChat(
  WidgetTester tester, {
  String lang = 'ar',
  String? location,
  bool seed = true,
  MadarDatabase? on,
  Future<void> Function(MadarDatabase db)? beforePump,
}) async {
  final transport = FakeTransport();
  // A real restart: tear the whole tree down first, or `pumpWidget` would
  // update the identical tree in place and every State (the scroll
  // position, the screen's own edits) would quietly survive – which is the
  // opposite of what a restart test is for.
  if (on != null) {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }
  final app = await pumpMadarApp(
    tester,
    settings: AppSettings(onboarded: true, languageCode: lang),
    initialLocation: location ?? AppRoutes.dayChat,
    now: dayChatNow,
    database: on == null,
    overrides: [
      if (on != null) databaseUnlockProvider.overrideWithValue(AsyncValue.data(on)),
      ...dayChatOverrides(transport),
    ],
    beforePump: (db) async {
      if (seed) await seedDayChat(db);
      if (beforePump != null) await beforePump(db);
    },
  );
  return DayChatApp(app, transport);
}

/// Lets the database and the reader finish, bounded by the round trips it
/// is really waiting for and not by a fixed number of frames.
Future<void> dayChatUntil(
  WidgetTester tester,
  String what,
  bool Function() ready, {
  int roundTrips = 60,
}) async {
  for (var i = 0; i < roundTrips && !ready(); i++) {
    for (var f = 0; f < 3; f++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
  }
  expect(ready(), isTrue, reason: 'waited for $what');
}

/// Types [line] into the chat's box and taps send. Nothing of his is
/// written by this: it only reads the line into cards.
///
/// Waits for the reading itself, not for a number of widgets: the chat is a
/// lazy list, so only the cards that fit on the screen are ever built.
Future<List<DayChatPiece>> sendLine(
  WidgetTester tester,
  DayChatApp app,
  String line, {
  int expectPieces = 1,
}) async {
  final before = readings(app).length;
  await tester.enterText(find.byKey(const ValueKey('dayChat.input')), line);
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('dayChat.send')));
  await dayChatUntil(
    tester,
    'the reading of «$line»',
    () => readings(app).length > before && readings(app).last.pieces.length >= expectPieces,
  );
  return readings(app).last.pieces;
}

/// Every line of the day as the chat has read it (his words plus the pieces
/// they became) – the model behind the cards.
List<DayChatReading> readings(DayChatApp app, {DateTime? day}) =>
    app.app.container.read(dayChatReadingsProvider(day ?? dayChatToday)).value ?? const [];

/// What he has decided, as the chat stored it.
DayChatDay? storedDay(DayChatApp app, {DateTime? day}) =>
    app.app.container.read(dayChatDayProvider(day ?? dayChatToday)).value;

/// The cards that are **built** right now (a lazy list builds only what
/// fits on the screen – scroll with [reveal] for the rest).
List<DayChatPieceCard> cards(WidgetTester tester) =>
    tester.widgetList<DayChatPieceCard>(find.byType(DayChatPieceCard)).toList();

/// The card of the one piece of [kind] (fails when there is not exactly
/// one).
DayChatPieceCard cardOf(WidgetTester tester, DayChatKind kind) {
  final found = [
    for (final c in cards(tester))
      if (c.piece.kind == kind) c,
  ];
  expect(found, hasLength(1), reason: 'one $kind card');
  return found.single;
}

/// The chat's own words, read off a screen that is on the tree – so a test
/// asserts the sentence `DayChatTexts` writes and never a hand-made one.
DayChatTexts chatTexts(WidgetTester tester) => DayChatTexts.of(tester.element(find.byType(DayChatScreen)));

L10n chatL10n(String lang) => lookupL10n(Locale(lang));

/// Brings [finder] onto the screen (the chat is a lazy list with the box
/// pinned under it) and leaves it where a tap lands.
Future<void> reveal(WidgetTester tester, Finder finder) async {
  final chat = find.byKey(const ValueKey('dayChat.list'));
  final list = find.descendant(of: chat, matching: find.byType(Scrollable));
  // The chat shows a loader (and no list at all) until the day has been
  // read: wait for the thing being scrolled, not for a number of frames.
  await dayChatUntil(tester, 'the chat list', () => list.evaluate().isNotEmpty);
  // Then for the card itself: it may simply not have been built yet, and
  // dragging a list that is still arriving loses the scrollable mid-drag.
  if (!await waitFor(tester, () => finder.evaluate().isNotEmpty, rounds: 30)) {
    await tester.scrollUntilVisible(finder, 240, scrollable: list.first);
  }
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 80));
  // Keep it clear of the bottom of the screen: the box he types into and
  // the undo toasts stacked above it live there, and a tap on a button
  // underneath them never reaches it (exactly as it would not on his
  // phone).
  const clearance = 260.0;
  final screen = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  final rect = tester.getRect(finder);
  if (rect.bottom > screen - clearance) {
    await tester.drag(list.first, Offset(0, -(rect.bottom - (screen - clearance))));
    await tester.pump(const Duration(milliseconds: 80));
  }
}

/// Pumps until [ready] holds and says whether it did – for the places where
/// "not yet" is an answer and not a failure.
Future<bool> waitFor(WidgetTester tester, bool Function() ready, {int rounds = 30}) async {
  for (var i = 0; i < rounds && !ready(); i++) {
    for (var f = 0; f < 3; f++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
  }
  return ready();
}

/// Taps a card's own button («سجّلها», «عدّلها» …), scrolling to it first.
Future<void> tapCardButton(WidgetTester tester, String action, String pieceId) async {
  final finder = find.byKey(ValueKey('dayChat.$action.$pieceId'));
  await reveal(tester, finder);
  await tester.tap(finder);
  await tester.pump();
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}
