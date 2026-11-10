import 'package:flutter/widgets.dart';

import '../../../core/domain/money.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../domain/list_money.dart';
import '../domain/record_list.dart';

/// Every string and number the list screens show: counts in the user's
/// digits, prices in the list's own currency with that currency's
/// decimals, and his own words bidi-isolated so Arabic and a Latin brand
/// name never swap places.
@immutable
class ListTexts {
  const ListTexts(this.l, this.fmt, {this.currencies = ListCurrencies.fallback});

  factory ListTexts.of(BuildContext context, [ListCurrencies currencies = ListCurrencies.fallback]) =>
      ListTexts(L10n.of(context), MadarFormatter.of(context), currencies: currencies);

  final L10n l;
  final MadarFormatter fmt;
  final ListCurrencies currencies;

  MoneyDigits get _digits => fmt.arabicIndic ? MoneyDigits.arabicIndic : MoneyDigits.western;

  /// A name he typed, isolated so its own punctuation stays with it.
  String name(String? text) => BidiIsolate.isolate((text ?? '').trim());

  String n(int value) => fmt.formatInt(value);

  /// A quantity in his digits, without trailing zeros («١٫٥», «٢»).
  String quantity(double value) => fmt.formatNumber(value, maxDecimals: 3);

  /// «٢ كيلو» – a quantity with his own unit word (just the number when he
  /// gave no unit).
  String amountOf(double? quantity, String? unit) {
    final u = unit?.trim();
    if (quantity == null || quantity <= 0) return u == null || u.isEmpty ? '' : BidiIsolate.isolate(u);
    final q = this.quantity(quantity);
    return u == null || u.isEmpty ? q : BidiIsolate.isolate('$q $u');
  }

  /// `١٢٫٥٠٠ د.أ` in the list's currency (the base when it has none).
  String money(int milli, [String? listCurrency]) {
    final code = currencies.of(listCurrency);
    return BidiIsolate.isolate(
      Money(milli, code).format(
        locale: fmt.languageCode,
        digits: _digits,
        decimals: currencies.decimalsOf(code),
        symbol: currencies.customSymbol(code),
      ),
    );
  }

  /// «٢ من ٥».
  String progress(ListTotals t) => fmt.localizeDigits(l.listsProgress(n(t.done), n(t.total)));

  /// «٣ أغراض» – a count of items in his digits (ICU plurals format
  /// numbers with intl's own `ar` data, which writes Western digits).
  String items(int count) => fmt.localizeDigits(l.listsItemsCount(count));

  /// «قائمتين» – a count of lists in his digits.
  String lists(int count) => fmt.localizeDigits(l.listsListsCount(count));

  /// «باقي ٣ أغراض» – what is left, in his digits.
  String remaining(int count) => fmt.localizeDigits(l.listsRemainingCount(count));

  /// «٣ أغراض — ٨٫٠٠٠ د.أ» – the posting preview, in his digits.
  String postSummary(int count, String amount) => fmt.localizeDigits(l.listsPostSummary(count, amount));

  /// What the list says under its name: everything done, what is left, or
  /// that it is empty.
  String status(ListTotals t) => switch (t) {
    ListTotals(isEmpty: true) => l.listsItemsEmptyTitle,
    ListTotals(complete: true) => l.listsAllDone,
    _ => remaining(t.remaining),
  };

  /// The line of one item under its title: how much, and what it costs.
  String itemMeta(ListLine line, [String? listCurrency]) {
    final total = line.totalMilli;
    final quantity = amountOf(line.quantity, line.unit);
    return [
      if (quantity.isNotEmpty) quantity,
      if (total != null) money(total, listCurrency),
    ].join(l.commonFactSeparator);
  }

  /// The whole item as one sentence, for TalkBack.
  String itemLabel(ListLine line, [String? listCurrency]) {
    final meta = itemMeta(line, listCurrency);
    return [
      name(line.title),
      if (meta.isNotEmpty) meta,
      line.done ? l.listsTickedToast : l.listsNothingTicked,
    ].join(', ');
  }
}
