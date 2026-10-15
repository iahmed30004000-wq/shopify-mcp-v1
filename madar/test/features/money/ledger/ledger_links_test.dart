import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/money/ledger/domain/ledger_links.dart';
import 'package:madar/features/money/ledger/domain/ledger_models.dart';

LedgerTx _tx(String id, {List<String> tags = const [], TxKind kind = TxKind.adjustment}) =>
    LedgerTx(id: id, walletId: 'w', kind: kind, amountMilli: -1000, date: DateTime(2026, 9, 28), tags: tags);

void main() {
  test('ids of the goals package are recognised, the user\'s own are not', () {
    expect(LedgerLinks.of(_tx('jar-tx-m1')), LedgerLink.jar);
    expect(LedgerLinks.of(_tx('debt-tx-p9')), LedgerLink.debt);
    expect(LedgerLinks.of(_tx('ob-tx-p2', kind: TxKind.expense)), LedgerLink.obligation);
    expect(LedgerLinks.of(_tx('3f2a-uuid')), isNull);
    // A bare prefix is not a link.
    expect(LedgerLinks.ofId('jar-tx-'), isNull);
    expect(LedgerLinks.isLinked(_tx('my-jar-tx-1')), isFalse);
  });

  test('a debt opened through a wallet is protected too; its source is the debt', () {
    final opening = _tx('debt-open-tx-d7');
    expect(LedgerLinks.of(opening), LedgerLink.debt);
    expect(LedgerLinks.isLinked(opening), isTrue);
    expect(LedgerLinks.isDebtOpening(opening), isTrue);
    expect(LedgerLinks.sourceId(opening), 'd7');
    expect(LedgerLinks.isDebtOpening(_tx('debt-tx-p1')), isFalse);
    expect(LedgerLinks.ofId('debt-open-tx-'), isNull);
  });

  test('the other half\'s id', () {
    expect(LedgerLinks.sourceId(_tx('jar-tx-m1')), 'm1');
    expect(LedgerLinks.sourceId(_tx('ob-tx-abc-def')), 'abc-def');
    expect(LedgerLinks.sourceId(_tx('plain')), isNull);
  });

  test('system tags: recognised case-insensitively; the own one is hidden on a linked row', () {
    expect(LedgerLinks.ofTag('jar'), LedgerLink.jar);
    expect(LedgerLinks.ofTag(' Debt '), LedgerLink.debt);
    expect(LedgerLinks.ofTag('obligation'), LedgerLink.obligation);
    expect(LedgerLinks.ofTag('family'), isNull);
    expect(LedgerLinks.visibleTags(_tx('jar-tx-1', tags: ['jar', 'travel'])), ['travel']);
    // The user's own entry keeps every tag.
    expect(LedgerLinks.visibleTags(_tx('t1', tags: ['jar', 'travel'])), ['jar', 'travel']);
  });
}
