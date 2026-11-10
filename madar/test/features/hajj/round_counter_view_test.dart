import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/hajj/hajj.dart';

final _ar = lookupL10n(const Locale('ar'));
final _en = lookupL10n(const Locale('en'));

String _d(int n) => Digits.toArabicIndic('$n');

class _Mono {
  Duration now = Duration.zero;
  Duration call() => now;
}

class _Host {
  _Host({String? saved}) : store = MemoryRoundCounterStore(saved);

  final MemoryRoundCounterStore store;
  final _Mono mono = _Mono();
  final List<RoundFeedback> feedback = [];
  final List<bool> awake = [];
  int _id = 0;

  Widget app({
    String locale = 'ar',
    double textScale = 1.0,
    bool reducedMotion = false,
    MadarThemeId theme = MadarThemeId.lapis,
    RoundKind kind = RoundKind.tawaf,
    Key? key,
  }) {
    return MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      theme: buildMadarTheme(theme, arabic: locale == 'ar'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reducedMotion,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: SafeArea(
          child: RoundCounterView(
            key: key,
            store: store,
            initialKind: kind,
            monotonic: mono.call,
            newId: () => 'v${_id++}',
            onFeedback: feedback.add,
            keepAwake: awake.add,
          ),
        ),
      ),
    );
  }
}

Finder _tapArea(L10n l) => find.text(l.hajjCounterTapArea);

/// Taps the big area after letting enough monotonic time pass.
Future<void> _tap(WidgetTester tester, _Host h, L10n l) async {
  h.mono.now += const Duration(seconds: 1);
  await tester.tap(_tapArea(l));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Arabic: starts at round 1; each tap moves on with Arabic-Indic digits; haptics fire', (tester) async {
    final h = _Host();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    expect(find.text(_ar.hajjCounterRoundOf(_d(1), _d(7))), findsOneWidget);
    expect(find.text(_ar.hajjCounterSaved), findsOneWidget);

    await _tap(tester, h, _ar);
    expect(find.text(_ar.hajjCounterRoundOf(_d(2), _d(7))), findsOneWidget);
    await _tap(tester, h, _ar);
    await _tap(tester, h, _ar);
    expect(find.text('الشوط ${_d(4)} من ${_d(7)}'), findsOneWidget);
    expect(h.feedback, [RoundFeedback.counted, RoundFeedback.counted, RoundFeedback.counted]);
    // Saved after every tap, as text on the "disk".
    expect(h.store.writes, isNotEmpty);
    expect(h.awake.last, isTrue);
  });

  testWidgets('English texts', (tester) async {
    final h = _Host();
    await tester.pumpWidget(h.app(locale: 'en'));
    await tester.pumpAndSettle();
    expect(find.text('Round 1 of 7'), findsOneWidget);
    expect(find.text('Tawaf'), findsOneWidget);
    await _tap(tester, h, _en);
    expect(find.text('Round 2 of 7'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('Correct by hand'), findsOneWidget);
  });

  testWidgets('a double tap inside the debounce counts once', (tester) async {
    final h = _Host();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    h.mono.now = const Duration(seconds: 10);
    await tester.tap(_tapArea(_ar));
    h.mono.now += const Duration(milliseconds: 300);
    await tester.tap(_tapArea(_ar));
    await tester.pumpAndSettle();
    expect(find.text(_ar.hajjCounterRoundOf(_d(2), _d(7))), findsOneWidget);
    expect(h.feedback, hasLength(1));
  });

  testWidgets('seven taps complete; the tap area is gone, an 8th tap changes nothing; start another works', (
    tester,
  ) async {
    final h = _Host();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    for (var i = 0; i < 7; i++) {
      await _tap(tester, h, _ar);
    }
    expect(find.text(_ar.hajjCounterCompleteTawaf), findsOneWidget);
    expect(find.text(_ar.hajjCounterCountOf(_d(7), _d(7))), findsOneWidget);
    expect(_tapArea(_ar), findsNothing);
    expect(h.feedback.last, RoundFeedback.completed);
    expect(h.awake.last, isFalse);
    final before = h.store.writes.length;
    // Tapping where the area was does nothing.
    await tester.tap(find.byIcon(Icons.check_circle_rounded));
    await tester.tap(find.text(_ar.hajjCounterCompleteTawaf));
    await tester.pumpAndSettle();
    expect(h.store.writes.length, before);

    await tester.tap(find.text(_ar.hajjCounterStartAnotherTawaf));
    await tester.pumpAndSettle();
    expect(find.text(_ar.hajjCounterRoundOf(_d(1), _d(7))), findsOneWidget);
    expect(h.awake.last, isTrue);
    await _tap(tester, h, _ar);
    expect(find.text(_ar.hajjCounterRoundOf(_d(2), _d(7))), findsOneWidget);
    final saved = RoundCounter.fromJson((await h.store.read()));
    expect(saved.sessions, hasLength(2));
  });

  testWidgets('the sa\'i shows which end he is walking toward', (tester) async {
    final h = _Host();
    await tester.pumpWidget(h.app(kind: RoundKind.sai));
    await tester.pumpAndSettle();
    expect(find.text(_ar.hajjCounterHeadingMarwa), findsOneWidget);
    await _tap(tester, h, _ar);
    expect(find.text(_ar.hajjCounterHeadingSafa), findsOneWidget);
    await _tap(tester, h, _ar);
    expect(find.text(_ar.hajjCounterHeadingMarwa), findsOneWidget);
  });

  testWidgets('undo takes back a tap; it is off at the start', (tester) async {
    final h = _Host();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    final undo = find.widgetWithText(TextButton, _ar.hajjCounterUndo);
    expect(tester.widget<TextButton>(undo).onPressed, isNull);
    await _tap(tester, h, _ar);
    await _tap(tester, h, _ar);
    await tester.tap(undo);
    await tester.pumpAndSettle();
    expect(find.text(_ar.hajjCounterRoundOf(_d(2), _d(7))), findsOneWidget);
  });

  testWidgets('manual correction sheet sets the round', (tester) async {
    final h = _Host();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tester.tap(find.text(_ar.hajjCounterCorrect));
    await tester.pumpAndSettle();
    expect(find.text(_ar.hajjCounterCorrectTitle), findsOneWidget);
    for (var n = 1; n <= 7; n++) {
      expect(find.text(_d(n)), findsOneWidget);
    }
    expect(find.text(_d(8)), findsNothing);
    await tester.tap(find.text(_d(5)));
    await tester.pumpAndSettle();
    expect(find.text(_ar.hajjCounterRoundOf(_d(5), _d(7))), findsOneWidget);
  });

  testWidgets('pause ignores taps, resume counts again', (tester) async {
    final h = _Host();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tester.tap(find.text(_ar.hajjCounterPause));
    await tester.pumpAndSettle();
    expect(find.text(_ar.hajjCounterPausedBanner), findsOneWidget);
    h.mono.now += const Duration(seconds: 5);
    await tester.tap(find.text(_ar.hajjCounterPausedBanner));
    await tester.pumpAndSettle();
    expect(find.text(_ar.hajjCounterRoundOf(_d(1), _d(7))), findsOneWidget);
    await tester.tap(find.text(_ar.hajjCounterResume));
    await tester.pumpAndSettle();
    await _tap(tester, h, _ar);
    expect(find.text(_ar.hajjCounterRoundOf(_d(2), _d(7))), findsOneWidget);
  });

  testWidgets('kill mid-round and relaunch: the same round, and the same screen after a restart', (tester) async {
    final h = _Host();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await _tap(tester, h, _ar);
    }
    // The process dies: the whole tree goes away without any goodbye.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    final relaunched = _Host(saved: h.store.text);
    await tester.pumpWidget(relaunched.app());
    await tester.pumpAndSettle();
    expect(find.text(_ar.hajjCounterRoundOf(_d(4), _d(7))), findsOneWidget);
    await _tap(tester, relaunched, _ar);
    expect(find.text(_ar.hajjCounterRoundOf(_d(5), _d(7))), findsOneWidget);
  });

  testWidgets('the kind can be switched only before the first tap', (tester) async {
    final h = _Host();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tester.tap(find.text(_ar.hajjCounterKindSai));
    await tester.pumpAndSettle();
    expect(find.text(_ar.hajjCounterHeadingMarwa), findsOneWidget);
    await _tap(tester, h, _ar);
    final chip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, _ar.hajjCounterKindTawaf));
    expect(chip.onSelected, isNull);
  });

  testWidgets('the tap area is the lower two thirds of the screen', (tester) async {
    final h = _Host();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    final screen = tester.getRect(find.byType(Scaffold));
    final area = tester.getRect(find.ancestor(of: _tapArea(_ar), matching: find.byType(DecoratedBox)).first);
    expect(area.height, greaterThan(screen.height * 0.55));
    expect(area.bottom, greaterThan(screen.bottom - 40));
    expect(area.width, greaterThan(screen.width * 0.85));
  });

  testWidgets('a new round is announced: one live region carries the number and the direction', (tester) async {
    final handle = tester.ensureSemantics();
    final h = _Host();
    await tester.pumpWidget(h.app(kind: RoundKind.sai));
    await tester.pumpAndSettle();
    SemanticsNode live() {
      final node = tester.getSemantics(find.bySemanticsLabel(RegExp('^${RegExp.escape(_ar.hajjCounterRoundOf(_d(1), _d(7)))}')));
      return node;
    }

    expect(live().flagsCollection.isLiveRegion, isTrue);
    expect(live().label, _ar.hajjCounterAnnounce(_ar.hajjCounterRoundOf(_d(1), _d(7)), _ar.hajjCounterHeadingMarwa));
    await _tap(tester, h, _ar);
    final next = tester.getSemantics(find.bySemanticsLabel(RegExp('^${RegExp.escape(_ar.hajjCounterRoundOf(_d(2), _d(7)))}')));
    expect(next.flagsCollection.isLiveRegion, isTrue);
    expect(next.label, contains(_ar.hajjCounterHeadingSafa));
    // The big area is a labelled button with a hint.
    final area = tester.getSemantics(find.bySemanticsLabel(_ar.hajjCounterTapArea));
    expect(area.flagsCollection.isButton, isTrue);
    expect(area.hint, _ar.hajjCounterTapHint);
    handle.dispose();
  });

  for (final locale in ['ar', 'en']) {
    for (final theme in [MadarThemeId.lapis, MadarThemeId.pearl]) {
      testWidgets('text scale 1.3 on a small phone, $locale / ${theme.name}: no overflow, in every state', (tester) async {
        tester.view.physicalSize = const Size(320 * 3, 568 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        final h = _Host();
        final l = locale == 'ar' ? _ar : _en;
        await tester.pumpWidget(h.app(locale: locale, textScale: 1.3, theme: theme, kind: RoundKind.sai));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await _tap(tester, h, l);
        await tester.tap(find.text(l.hajjCounterPause));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(l.hajjCounterResume));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l.hajjCounterCorrect));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(locale == 'ar' ? _d(7) : '7'));
        await tester.pumpAndSettle();
        await _tap(tester, h, l);
        expect(find.text(l.hajjCounterCompleteSai), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('every control is at least 48 dp', (tester) async {
    final h = _Host();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    for (final label in [_ar.hajjCounterUndo, _ar.hajjCounterCorrect, _ar.hajjCounterPause]) {
      final size = tester.getSize(find.widgetWithText(TextButton, label));
      expect(size.height, greaterThanOrEqualTo(48), reason: label);
      expect(size.width, greaterThanOrEqualTo(48), reason: label);
    }
    for (final chip in find.byType(ChoiceChip).evaluate()) {
      expect(tester.getSize(find.byWidget(chip.widget)).height, greaterThanOrEqualTo(32));
    }
  });

  testWidgets('RTL in Arabic and LTR in English', (tester) async {
    final h = _Host();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    expect(Directionality.of(tester.element(_tapArea(_ar))), TextDirection.rtl);
    await tester.pumpWidget(h.app(locale: 'en'));
    await tester.pumpAndSettle();
    expect(Directionality.of(tester.element(_tapArea(_en))), TextDirection.ltr);
  });

  testWidgets('reduced motion: the number changes with no animation left running', (tester) async {
    final h = _Host();
    await tester.pumpWidget(h.app(reducedMotion: true));
    await tester.pumpAndSettle();
    h.mono.now += const Duration(seconds: 1);
    await tester.tap(_tapArea(_ar));
    await tester.pump();
    expect(find.text(_ar.hajjCounterRoundOf(_d(2), _d(7))), findsOneWidget);
    expect(find.text(_ar.hajjCounterRoundOf(_d(1), _d(7))), findsNothing);
  });

  testWidgets('a failing screen wake lock or a failing save never breaks counting', (tester) async {
    final h = _Host();
    h.store.failWrites = true;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        theme: buildMadarTheme(MadarThemeId.lapis, arabic: true),
        home: Scaffold(
          body: RoundCounterView(
            store: h.store,
            monotonic: h.mono.call,
            keepAwake: (_) => throw StateError('no wake lock'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _tap(tester, h, _ar);
    expect(find.text(_ar.hajjCounterRoundOf(_d(2), _d(7))), findsOneWidget);
    expect(find.text(_ar.hajjCounterNotSaved), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving the screen releases the wake lock', (tester) async {
    final h = _Host();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    expect(h.awake.last, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(h.awake.last, isFalse);
  });
}
