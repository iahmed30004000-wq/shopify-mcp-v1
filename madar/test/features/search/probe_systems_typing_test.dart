// Probe (systems lens): rapid typing on the global search screen. Kept in
// its own file: the framework error it detects leaves the element tree
// broken, which would spoil any test run after it in the same file.
// FAILS while the problem exists. (Same error: type «pharmacy», wait
// 120 ms, tap ×, type «zzqx» within 10 ms.)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'search_harness.dart';

void main() {
  testWidgets('rapid typing: a letter, backspace, the letter again – no framework error', (tester) async {
    await pumpSearchApp(tester, locale: const Locale('en'));
    // Three keystrokes 60 ms apart (inside the screen's 220 ms cross-fade).
    await tester.enterText(find.byType(TextField), 'p');
    await tester.pump(const Duration(milliseconds: 60));
    await tester.enterText(find.byType(TextField), '');
    await tester.pump(const Duration(milliseconds: 60));
    await tester.enterText(find.byType(TextField), 'p');
    await tester.pump(const Duration(milliseconds: 60));
    final error = tester.takeException();
    expect(error, isNull, reason: '$error');
    await settle(tester);
  });
}
