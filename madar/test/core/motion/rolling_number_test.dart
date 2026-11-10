import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:madar/core/motion/rolling_number.dart';

import 'motion_test_utils.dart';

/// Glyphs currently fully shown (opaque, not the hidden sizing glyph).
String _shown(WidgetTester tester) {
  final elements = find.descendant(of: find.byType(RollingNumber), matching: find.byType(Text)).evaluate();
  final buffer = StringBuffer();
  for (final e in elements) {
    if (e.findAncestorWidgetOfExactType<Visibility>() != null) continue;
    final t = e.widget as Text;
    final color = t.style?.color;
    if (color != null && color.a > 0.99) buffer.write(t.data);
  }
  return buffer.toString();
}

String _arabic(num v) {
  const digits = '٠١٢٣٤٥٦٧٨٩';
  return v.toStringAsFixed(0).split('').map((c) {
    final d = int.tryParse(c);
    return d == null ? c : digits[d];
  }).join();
}

void main() {
  group('RollingDigits', () {
    test('parses Western, Arabic-Indic and Persian digits; drops bidi marks', () {
      final g = RollingDigits.parse('‎-1,2٣۴');
      expect(g.map((e) => e.toString()).join(), '-1,2٣۴');
      expect(g[0].isDigit, isFalse);
      expect(g[1].digit, 1);
      expect(g[1].zero, 0x30);
      expect(g[4].digit, 3);
      expect(g[4].zero, 0x660);
      expect(g[5].digit, 4);
      expect(g[5].zero, 0x6F0);
      expect(g[4].glyphOf(9), '٩');
    });

    test('next strip position rolls in the value direction', () {
      expect(RollingDigits.nextPosition(9, 0, up: true), 10);
      expect(RollingDigits.nextPosition(19.4, 1, up: true), 21);
      expect(RollingDigits.nextPosition(21, 1, up: true), 21);
      expect(RollingDigits.nextPosition(21, 9, up: false), 19);
      expect(RollingDigits.nextPosition(0, 9, up: false), -1);
      expect(RollingDigits.nextPosition(3, 3, up: false), 3);
    });

    test('split gives the shown digit, the next one and the fraction', () {
      expect(RollingDigits.split(19.25), (9, 0, 0.25));
      expect(RollingDigits.split(-1), (9, 0, 0.0));
    });
  });

  group('RollingNumber', () {
    testWidgets('rolls to the new value and exposes it to semantics', (tester) async {
      Widget build(num v) => motionApp(
        Scaffold(
          body: Center(
            child: RollingNumber(value: v, style: const TextStyle(fontSize: 24)),
          ),
        ),
      );
      await tester.pumpWidget(build(19));
      expect(_shown(tester), '19');
      expect(find.bySemanticsLabel('19'), findsOneWidget);

      await tester.pumpWidget(build(21));
      await tester.pump(const Duration(milliseconds: 40));
      expect(_shown(tester), isNot('21'), reason: 'mid-roll');
      await tester.pumpAndSettle();
      expect(_shown(tester), '21');
      expect(find.bySemanticsLabel('21'), findsOneWidget);
    });

    testWidgets('grows and shrinks its columns', (tester) async {
      Widget build(num v) => motionApp(
        Scaffold(
          body: Center(child: RollingNumber(value: v)),
        ),
      );
      await tester.pumpWidget(build(99));
      await tester.pumpWidget(build(100));
      await tester.pumpAndSettle();
      expect(_shown(tester), '100');
      await tester.pumpWidget(build(7));
      await tester.pumpAndSettle();
      expect(_shown(tester), '7');
    });

    testWidgets('retargets mid-flight', (tester) async {
      Widget build(num v) => motionApp(
        Scaffold(
          body: Center(child: RollingNumber(value: v)),
        ),
      );
      await tester.pumpWidget(build(0));
      await tester.pumpWidget(build(5));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(build(8));
      await tester.pumpAndSettle();
      expect(_shown(tester), '8');
    });

    testWidgets('Arabic-Indic digits through a formatter', (tester) async {
      Widget build(num v) => motionApp(
        Scaffold(
          body: Center(
            child: RollingNumber(value: v, formatter: _arabic),
          ),
        ),
      );
      await tester.pumpWidget(build(12));
      expect(_shown(tester), '١٢');
      await tester.pumpWidget(build(30));
      await tester.pumpAndSettle();
      expect(_shown(tester), '٣٠');
    });

    testWidgets('works with intl NumberFormat (grouping, fraction)', (tester) async {
      final f = NumberFormat.decimalPatternDigits(locale: 'en', decimalDigits: 1);
      Widget build(num v) => motionApp(
        Scaffold(
          body: Center(
            child: RollingNumber(value: v, formatter: f.format),
          ),
        ),
      );
      await tester.pumpWidget(build(1234.5));
      expect(_shown(tester), '1,234.5');
      await tester.pumpWidget(build(1240.0));
      await tester.pumpAndSettle();
      expect(_shown(tester), '1,240.0');
    });

    testWidgets('from: rolls up on first build', (tester) async {
      await tester.pumpWidget(motionApp(const Scaffold(body: Center(child: RollingNumber(from: 0, value: 42)))));
      await tester.pump(const Duration(milliseconds: 30));
      expect(_shown(tester), isNot('42'));
      await tester.pumpAndSettle();
      expect(_shown(tester), '42');
    });

    testWidgets('reduced motion changes instantly', (tester) async {
      Widget build(num v) => motionApp(
        reduced: true,
        Scaffold(
          body: Center(child: RollingNumber(value: v)),
        ),
      );
      await tester.pumpWidget(build(3));
      await tester.pumpWidget(build(8));
      await tester.pump();
      expect(_shown(tester), '8');
    });

    testWidgets('lays digits out left-to-right even in RTL', (tester) async {
      await tester.pumpWidget(
        motionApp(
          direction: TextDirection.rtl,
          const Scaffold(body: Center(child: RollingNumber(value: 12))),
        ),
      );
      final one = tester.getCenter(find.text('1').last);
      final two = tester.getCenter(find.text('2').last);
      expect(one.dx, lessThan(two.dx));
    });
  });
}
