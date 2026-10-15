// Helpers for i18n audits: the strings actually laid out on screen.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every string on stage: [RichText] (all [Text]s end up here) and editable
/// text. Offstage subtrees are skipped; semantics-only labels are not text.
List<String> paintedStrings(WidgetTester tester) => [
  for (final e in find.byType(RichText).evaluate())
    (e.widget as RichText).text.toPlainText(includeSemanticsLabels: false, includePlaceholders: false),
  for (final e in find.byType(EditableText).evaluate()) (e.widget as EditableText).controller.text,
];

final RegExp westernDigit = RegExp('[0-9]');
final RegExp easternDigit = RegExp('[٠-٩۰-۹]');
final RegExp arabicLetter = RegExp('[ء-ي]');
final RegExp latinLetter = RegExp('[A-Za-z]');

/// Pumps a few frames without waiting for never-ending animations.
Future<void> pumpFrames(WidgetTester tester, {Duration total = const Duration(milliseconds: 1200)}) async {
  for (var t = Duration.zero; t < total; t += const Duration(milliseconds: 100)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
