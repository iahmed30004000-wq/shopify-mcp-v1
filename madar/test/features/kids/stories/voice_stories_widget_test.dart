import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/kids/core/kids_section.dart';
import 'package:madar/features/kids/stories/domain/voice_story.dart';
import 'package:madar/features/kids/stories/presentation/parent_corner_screen.dart';
import 'package:madar/features/kids/stories/presentation/voice_stories_screen.dart';
import 'package:madar/features/kids/stories/stories.dart';

import '../../../helpers/screenshot_harness.dart' show loadMadarFonts;
import 'voice_fakes.dart';

const _root = MemoryVoiceFiles.root;

/// A phone that already holds two recorded stories and an empty one.
Phone _phoneWithStories() {
  final phone = Phone();
  final stories = [
    const VoiceStory(id: 'a', title: 'حكاية قبل النوم', narrator: 'بصوت بابا', fileName: 'a.m4a', durationMs: 200000),
    const VoiceStory(id: 'b', title: 'حكاية الفانوس', colorIndex: 1, fileName: 'b.m4a', durationMs: 300000),
    const VoiceStory(id: 'c', title: 'لسا ما انسجلت'),
  ];
  phone.kv.data['kids.voice_stories'] = encodeVoiceStories(stories);
  phone.files.files.addAll(['$_root/a.m4a', '$_root/b.m4a']);
  return phone;
}

Future<void> _pump(
  WidgetTester tester,
  Phone phone,
  Widget home, {
  bool parentSaysYes = false,
  double scale = 1,
  Size size = const Size(360, 780),
  Locale locale = const Locale('ar'),
}) async {
  await tester.runAsync(loadMadarFonts);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...phone.overrides(),
        kidsParentAskProvider.overrideWithValue(() async => parentSaysYes),
        kidsStarCountProvider.overrideWithValue(24),
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: L10n.supportedLocales,
        localizationsDelegates: L10n.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: home,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  group('the child\'s player', () {
    testWidgets('empty: it teaches what this is, and the parent corner is locked until the gate says yes', (
      tester,
    ) async {
      await _pump(tester, Phone(), const VoiceStoriesScreen());
      expect(find.text('ما في حكايات لسا'), findsOneWidget);
      expect(find.textContaining('بدون إنترنت'), findsOneWidget);
      await tester.tap(find.text('ركن الأهل'));
      await tester.pumpAndSettle();
      expect(find.byType(ParentCornerScreen), findsNothing, reason: 'the gate answered no');
    });

    testWidgets('the gate saying yes opens the parent corner', (tester) async {
      await _pump(tester, Phone(), const VoiceStoriesScreen(), parentSaysYes: true);
      await tester.tap(find.text('ركن الأهل'));
      await tester.pumpAndSettle();
      expect(find.byType(ParentCornerScreen), findsOneWidget);
      expect(find.text('حكاياتي بصوتي'), findsOneWidget);
    });

    testWidgets('it lists only recorded stories, shows the parent\'s tag, and plays offline', (tester) async {
      final phone = _phoneWithStories();
      await _pump(tester, phone, const VoiceStoriesScreen());
      expect(find.text('حكاية قبل النوم'), findsWidgets);
      expect(find.text('حكاية الفانوس'), findsOneWidget);
      expect(find.text('لسا ما انسجلت'), findsNothing, reason: 'no recording yet: the child never sees it');
      expect(find.text('بصوت بابا'), findsOneWidget, reason: 'the tag is the text the parent typed');
      expect(find.text('٤ دقايق'), findsNothing);
      expect(find.text('٣ دقايق'), findsOneWidget);

      await scrollTo(tester, find.text('حكاية الفانوس'), find.byType(SingleChildScrollView).first);
      await tester.tap(find.text('حكاية الفانوس'));
      await tester.pump();
      await tester.pump();
      expect(phone.player.loaded, '$_root/b.m4a');
      expect(phone.player.isPlaying, isTrue);
    });

    testWidgets('play/pause and next work from the big buttons', (tester) async {
      final phone = _phoneWithStories();
      await _pump(tester, phone, const VoiceStoriesScreen());
      await tester.tap(find.bySemanticsLabel('شغّل').first);
      await tester.pump();
      await tester.pump();
      expect(phone.player.loaded, '$_root/a.m4a');
      await tester.tap(find.bySemanticsLabel('الحكاية التالية'));
      await tester.pump();
      await tester.pump();
      expect(phone.player.loaded, '$_root/b.m4a');
    });

    testWidgets('a file that cannot be played says so calmly', (tester) async {
      final phone = _phoneWithStories()..player.loadThrows = true;
      await _pump(tester, phone, const VoiceStoriesScreen());
      await scrollTo(tester, find.text('حكاية الفانوس'), find.byType(SingleChildScrollView).first);
      await tester.tap(find.text('حكاية الفانوس'));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('ما قدرنا نشغّل'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final locale in [const Locale('ar'), const Locale('en')]) {
      testWidgets('text scale 1.3 at 320 dp, ${locale.languageCode}: no overflow', (tester) async {
        final phone = _phoneWithStories();
        await _pump(tester, phone, const VoiceStoriesScreen(), scale: 1.3, size: const Size(320, 640), locale: locale);
        expect(tester.takeException(), isNull);
        await scrollTo(tester, find.text('حكاية الفانوس'), find.byType(SingleChildScrollView).first);
        await tester.tap(find.text('حكاية الفانوس'));
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('the parent corner', () {
    testWidgets('record flow with the fake microphone', (tester) async {
      final phone = Phone();
      await _pump(tester, phone, const ParentCornerScreen());
      await tester.tap(find.text('حكاية جديدة'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'حكاية السفر');
      await tester.pump();
      await tester.tap(find.text('احفظ'));
      await tester.pumpAndSettle();
      expect(find.text('حكاية السفر'), findsOneWidget);
      expect(find.text('فاضية'), findsOneWidget);

      await tester.tap(find.text('سجّل بصوتك'));
      await tester.pump();
      await tester.pump();
      expect(find.text('قيد التسجيل'), findsOneWidget);
      expect(find.text('وقّف واحفظ'), findsOneWidget);
      expect(phone.recorder.recordingTo, '$_root/s1.rec.m4a');

      phone.recorder.level.add(0.6);
      phone.now = phone.now.add(const Duration(seconds: 48));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('٠:٤٨'), findsOneWidget, reason: 'the timer, in the screen\'s digits');

      await tester.tap(find.text('وقّف واحفظ'));
      await tester.pump();
      await tester.pump();
      expect(find.text('انحفظ التسجيل.'), findsOneWidget);
      expect(find.text('سجّل من جديد'), findsOneWidget);
      expect(find.text('احذف'), findsOneWidget);
      expect(phone.files.files, {'$_root/s1.m4a'});

      // Play from the corner.
      await tester.tap(find.text('شغّل'));
      await tester.pump();
      await tester.pump();
      expect(phone.player.loaded, '$_root/s1.m4a');

      // Delete, with a question first.
      await tester.tap(find.text('احذف'));
      await tester.pumpAndSettle();
      expect(find.textContaining('بدك تحذف'), findsOneWidget);
      await tester.tap(find.text('خلّيها'));
      await tester.pumpAndSettle();
      expect(find.text('حكاية السفر'), findsOneWidget, reason: 'kept');
      await tester.tap(find.text('احذف'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.text('احذف')));
      await tester.pumpAndSettle();
      expect(find.text('حكاية السفر'), findsNothing);
      expect(phone.files.files, isEmpty);
    });

    testWidgets('permission denied: a calm message, the screen still works', (tester) async {
      final phone = _phoneWithStories();
      phone.recorder.permission = false;
      await _pump(tester, phone, const ParentCornerScreen());
      await scrollTo(tester, find.text('سجّل بصوتك'), find.byType(ListView));
      await tester.tap(find.text('سجّل بصوتك'));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('المايك مش مسموح'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a phone call during recording: it ends cleanly and says what was kept', (tester) async {
      final phone = _phoneWithStories();
      await _pump(tester, phone, const ParentCornerScreen());
      await scrollTo(tester, find.text('سجّل بصوتك'), find.byType(ListView));
      await tester.tap(find.text('سجّل بصوتك'));
      await tester.pump();
      await tester.pump();
      phone.now = phone.now.add(const Duration(seconds: 20));
      phone.recorder.interrupt.add(null);
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('اجتك مكالمة'), findsWidgets);
      expect(find.text('قيد التسجيل'), findsNothing);
      expect(phone.files.files, contains('$_root/c.m4a'));
    });

    testWidgets('re-record keeps the old recording until the new one is saved', (tester) async {
      final phone = _phoneWithStories();
      await _pump(tester, phone, const ParentCornerScreen());
      await tester.tap(find.text('سجّل من جديد').first);
      await tester.pump();
      await tester.pump();
      expect(phone.files.files, containsAll(['$_root/a.m4a', '$_root/a.rec.m4a']));
      await tester.tap(find.text('ألغِ'));
      await tester.pump();
      await tester.pump();
      expect(phone.files.files, contains('$_root/a.m4a'));
      expect(phone.files.files, isNot(contains('$_root/a.rec.m4a')));
    });

    for (final locale in [const Locale('ar'), const Locale('en')]) {
      testWidgets('text scale 1.3 at 320 dp, ${locale.languageCode}: no overflow', (tester) async {
        final phone = _phoneWithStories();
        await _pump(tester, phone, const ParentCornerScreen(), scale: 1.3, size: const Size(320, 640), locale: locale);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byIcon(Icons.edit_rounded).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  test('the sections the shell lists', () {
    expect(voiceStoriesSection.id, 'voice_stories');
    expect(interactiveStorySection.id, 'interactive_story');
    expect(voiceStoriesSection.religious, isFalse);
    expect(interactiveStorySection.religious, isFalse);
  });
}
