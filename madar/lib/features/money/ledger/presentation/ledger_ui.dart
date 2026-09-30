import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/domain/budget_math.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../data/ledger_providers.dart';
import '../domain/ledger_book.dart';
import '../domain/ledger_format.dart';
import '../domain/ledger_links.dart';
import '../domain/ledger_models.dart';
import '../domain/tx_draft.dart';

/// Localised labels of the ledger.
extension LedgerLabels on L10n {
  String kind(TxKind k) => switch (k) {
    TxKind.expense => ledgerKindExpense,
    TxKind.income => ledgerKindIncome,
    TxKind.transfer => ledgerKindTransfer,
    TxKind.adjustment => ledgerKindAdjustment,
  };

  String walletKind(WalletKind k) => switch (k) {
    WalletKind.personal => ledgerPersonal,
    WalletKind.business => ledgerBusiness,
  };

  String draftError(TxDraftError e) => switch (e) {
    TxDraftError.noWallet => ledgerErrNoWallet,
    TxDraftError.noAmount => ledgerErrNoAmount,
    TxDraftError.noDestination => ledgerErrNoDestination,
    TxDraftError.sameWallet => ledgerErrSameWallet,
    TxDraftError.noRate => ledgerErrNoRate,
    TxDraftError.noChange => ledgerErrNoChange,
  };

  /// Where a linked entry comes from ("Savings jar", "Debt", …).
  String link(LedgerLink k) => switch (k) {
    LedgerLink.jar => ledgerLinkJar,
    LedgerLink.debt => ledgerLinkDebt,
    LedgerLink.obligation => ledgerLinkObligation,
  };

  /// The menu action opening a linked entry's owner.
  String openLink(LedgerLink k) => switch (k) {
    LedgerLink.jar => ledgerOpenJar,
    LedgerLink.debt => ledgerOpenDebt,
    LedgerLink.obligation => ledgerOpenObligation,
  };

  /// A tag as shown: the goals package's system tags in the UI language,
  /// the user's own tags as typed.
  String tag(String tag) {
    final link = LedgerLinks.ofTag(tag);
    return link == null ? tag : this.link(link);
  }

  /// The note field's example for [kind].
  String noteHint(TxKind kind) => switch (kind) {
    TxKind.expense => ledgerNoteHint,
    TxKind.income => ledgerNoteHintIncome,
    TxKind.transfer => ledgerNoteHintTransfer,
    TxKind.adjustment => ledgerNoteHintAdjust,
  };
}

/// Dates and periods in ledger wording.
extension LedgerDates on MadarFormatter {
  /// "Today", "Yesterday", "Monday, September 28" (+ year when not this
  /// year).
  String day(L10n l, DateTime day, DateTime today) {
    final d = DateTime(day.year, day.month, day.day);
    final t = DateTime(today.year, today.month, today.day);
    if (d == t) return l.ledgerToday;
    if (d == DateTime(t.year, t.month, t.day - 1)) return l.ledgerYesterday;
    if (d.year != t.year) return formatDate(d, style: MadarDateStyle.medium);
    return formatDate(d, style: MadarDateStyle.weekdayDayMonth);
  }

  /// "September 2026" / "Sep 26 – Oct 2".
  String window(L10n l, BudgetWindow w) {
    if (w.period == BudgetPeriod.monthly) return monthYear(w.start);
    final last = DateTime(w.end.year, w.end.month, w.end.day - 1);
    return l.ledgerRangeLabel(
      formatDate(w.start, style: MadarDateStyle.dayMonth),
      formatDate(last, style: MadarDateStyle.dayMonth),
    );
  }

  DateFormat _pattern(DateFormat Function(String locale) build) {
    try {
      return build(languageCode);
    } catch (_) {
      return build('en');
    }
  }

  /// "September 2026" / "سبتمبر ٢٠٢٦".
  String monthYear(DateTime d) => localizeDigits(_pattern((l) => DateFormat.yMMMM(l)).format(d));

  /// Short month name for chart axes ("Sep" / "سبتمبر").
  String monthShort(DateTime d) => localizeDigits(_pattern((l) => DateFormat.MMM(l)).format(d));
}

/// Palette, tones and icons of the ledger – all derived from theme tokens.
abstract final class LedgerStyle {
  /// Distinct category colours derived from the theme's accent (hue steps
  /// at a lightness readable on the theme's surfaces).
  static List<Color> categorical(MadarTokens t) {
    final base = HSLColor.fromColor(t.accent);
    final dark = t.isDark;
    const steps = [0.0, 160.0, 205.0, 55.0, 285.0, 330.0, 105.0, 245.0];
    return [
      t.accent,
      for (final s in steps.skip(1))
        HSLColor.fromAHSL(1, (base.hue + s) % 360, (dark ? 0.62 : 0.55).clamp(0, 1), dark ? 0.70 : 0.36).toColor(),
    ];
  }

  static Color categoryAt(MadarTokens t, int i) {
    final p = categorical(t);
    return p[i % p.length];
  }

  /// A wallet's colour: the user's, else the palette by position.
  static Color wallet(MadarTokens t, LedgerWallet w, int index) =>
      w.color != null ? Color(w.color!) : categoryAt(t, index);

  /// A budget item's colour: the user's, else the palette by position.
  static Color budgetItem(MadarTokens t, BudgetItemLook? look, int index) =>
      look?.color != null ? Color(look!.color!) : categoryAt(t, index);

  static Color kind(MadarTokens t, TxKind k) => switch (k) {
    TxKind.expense => t.textPrimary,
    TxKind.income => t.success,
    TxKind.transfer => t.info,
    TxKind.adjustment => t.warning,
  };

  static IconData kindIcon(TxKind k) => switch (k) {
    TxKind.expense => Icons.arrow_outward_rounded,
    TxKind.income => Icons.south_west_rounded,
    TxKind.transfer => Icons.swap_horiz_rounded,
    TxKind.adjustment => Icons.tune_rounded,
  };

  static IconData walletIcon(LedgerWallet w) =>
      InteractionIcons.curated[w.icon] ??
      (w.isBusiness ? Icons.storefront_rounded : Icons.account_balance_wallet_rounded);

  static IconData? budgetIcon(BudgetItemLook? look) => InteractionIcons.curated[look?.icon];

  static IconData linkIcon(LedgerLink k) => switch (k) {
    LedgerLink.jar => Icons.savings_rounded,
    LedgerLink.debt => Icons.handshake_rounded,
    LedgerLink.obligation => Icons.event_repeat_rounded,
  };

  /// Tabular numerals for amounts.
  static TextStyle amount(MadarTokens t, {double size = 15, Color? color, FontWeight weight = FontWeight.w600}) =>
      MadarTypography.numerals(t, size: size, color: color).copyWith(fontWeight: weight, height: 1.25);
}

/// A formatted amount of money (tabular figures, RTL-safe).
class MoneyLabel extends StatelessWidget {
  const MoneyLabel({
    super.key,
    required this.milli,
    required this.currency,
    this.book,
    this.sign = SignDisplay.auto,
    this.style,
    this.color,
    this.size = 15,
    this.weight = FontWeight.w600,
    this.trimZeros = false,
    this.textAlign,
  });

  final int milli;
  final String currency;
  final LedgerBook? book;
  final SignDisplay sign;
  final TextStyle? style;
  final Color? color;
  final double size;
  final FontWeight weight;
  final bool trimZeros;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = ledgerFormatOf(context, book).amount(milli, currency, sign: sign, trimZeros: trimZeros);
    return Text(
      text,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.fade,
      textAlign: textAlign,
      style: style ?? LedgerStyle.amount(t, size: size, color: color, weight: weight),
    );
  }
}

/// A round glass medallion with an icon.
class LedgerMedallion extends StatelessWidget {
  const LedgerMedallion({super.key, required this.icon, required this.color, this.size = 40});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: t.isDark ? 0.30 : 0.18),
            color.withValues(alpha: t.isDark ? 0.08 : 0.05),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: t.isDark ? 0.55 : 0.45), width: 0.9),
      ),
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}

/// The text colour of a signed amount.
Color signedColor(MadarTokens t, int milli, {bool neutralNegative = true}) {
  if (milli > 0) return t.success;
  if (milli < 0) return neutralNegative ? t.textPrimary : t.danger;
  return t.textSecondary;
}
