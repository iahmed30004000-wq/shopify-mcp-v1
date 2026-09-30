import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/money/hub/money_links.dart';
import 'package:madar/features/orbit/domain/orbit_moons.dart';
import 'package:madar/features/orbit/presentation/planet/record_open.dart';

void main() {
  const dad = OrbitMoon(
    planetKey: 'family',
    refTable: 'people',
    refId: 'p1',
    label: 'Dad',
    color: Color(0xFFE0A060),
    kind: MoonKind.rocky,
    score: 0.2,
    size: 1,
    seed: 0.3,
  );

  test('a reason opens its moon or its task; other records are not buttons', () {
    expect(RecordOpener.canOpen('people', 'p1', const [dad]), isTrue);
    expect(RecordOpener.canOpen('tasks', 't1', const []), isTrue);
    expect(RecordOpener.canOpen('budgets', 'b1', const [dad]), isFalse);
    expect(RecordOpener.canOpen('people', 'p2', const [dad]), isFalse, reason: 'a hidden / missing moon');
    expect(RecordOpener.canOpen(null, null, const [dad]), isFalse);
  });

  test('a Health record opens its screen (a reason about several doses too)', () {
    expect(RecordOpener.canOpen('medications', 'm1', const [dad]), isTrue);
    expect(RecordOpener.canOpen('medications', null, const []), isTrue, reason: 'doses of several medications');
    expect(RecordOpener.canOpen('lab_tests', 'l1', const []), isTrue);
    expect(RecordOpener.canOpen('habits', 'h1', const [], planetKey: 'health'), isTrue);
    expect(RecordOpener.canOpen('habits', 'h1', const [], planetKey: 'growth'), isFalse, reason: "another world's habit");
    expect(RecordOpener.healthLocation('medications:m1'), '/meds');
    expect(RecordOpener.healthLocation('medications'), '/meds');
    expect(RecordOpener.healthLocation('appointments:a1'), '/record/appointments?highlight=a1');
    expect(RecordOpener.healthLocation('lab_tests:l 1'), '/record/lab/l%201');
    expect(RecordOpener.healthLocation('people:p1'), isNull);
  });

  test('a Money record opens its screen or sheet (a reason about a whole table too)', () {
    expect(RecordOpener.canOpen('debts', 'd1', const []), isTrue);
    expect(RecordOpener.canOpen('obligations', 'o1', const [], planetKey: 'money'), isTrue);
    expect(RecordOpener.canOpen('jars', 'j1', const [], planetKey: 'money'), isTrue);
    expect(RecordOpener.canOpen('budget_items', 'b1', const [], planetKey: 'money'), isTrue);
    expect(RecordOpener.canOpen('transactions', null, const [], planetKey: 'money'), isTrue, reason: 'stale entries');
    expect(RecordOpener.moneyTarget('debts:d1'), const MoneyDebtTarget('d1'));
    expect(RecordOpener.moneyTarget('obligations:o:1'), const MoneyObligationTarget('o:1'));
    expect(RecordOpener.moneyTarget('jars:j 1'), const MoneyRouteTarget('/goals/jar/j%201'));
    expect(RecordOpener.moneyTarget('budget_items:b1'), const MoneyRouteTarget('/budget?tab=spending'));
    expect(RecordOpener.moneyTarget('transactions'), const MoneyRouteTarget('/ledger'));
    expect(RecordOpener.moneyTarget('wallets:w1'), const MoneyRouteTarget('/ledger/wallet/w1'));
    expect(RecordOpener.moneyTarget('people:p1'), isNull);
  });

  test('item ids split into table and id (ids may contain colons)', () {
    expect(RecordOpener.parse('tasks:abc'), ('tasks', 'abc'));
    expect(RecordOpener.parse('custom_modules:a:b'), ('custom_modules', 'a:b'));
    expect(RecordOpener.parse('tasks:'), isNull);
    expect(RecordOpener.parse(':x'), isNull);
    expect(RecordOpener.moonOf('people:p1', const [dad]), dad);
  });
}
