import 'dart:ui' show Locale;

import 'package:intl/date_symbol_data_local.dart';

import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/settings/app_settings.dart' show DigitStyle;
import 'widget_kind.dart';

/// Every text a home-screen widget shows, in the app's language and digit
/// style (the widget follows the app, not the phone's language): built in
/// Dart and written into the snapshot, so Android only places strings.
class WidgetTexts {
  WidgetTexts(this.l, this.fmt);

  /// Texts outside the widget tree: loads intl's date symbols first
  /// (compiled in, synchronous).
  factory WidgetTexts.forLanguage(String languageCode, {DigitStyle digits = DigitStyle.auto}) {
    _ensureDateSymbols();
    final lang = languageCode == 'en' ? 'en' : 'ar';
    return WidgetTexts(lookupL10n(Locale(lang)), MadarFormatter(languageCode: lang, digits: digits));
  }

  static bool _dateSymbols = false;

  static void _ensureDateSymbols() {
    if (_dateSymbols) return;
    _dateSymbols = true;
    initializeDateFormatting();
  }

  final L10n l;
  final MadarFormatter fmt;

  String get languageCode => fmt.languageCode;
  bool get arabic => fmt.isArabic;

  String title(MadarWidgetKind kind) => switch (kind) {
    MadarWidgetKind.prayer => l.widgetsPrayerName,
    MadarWidgetKind.meds => l.widgetsMedsName,
    MadarWidgetKind.tasks => l.widgetsTasksName,
    MadarWidgetKind.budget => l.widgetsBudgetName,
  };

  String get stale => l.widgetsStale;

  /// "٢/٥" / "2/5".
  String fraction(int done, int total) => l.widgetsFraction(fmt.formatInt(done), fmt.formatInt(total));

  /// A pluralised message whose number intl formatted in its own digits,
  /// converted to the app's digits.
  String digits(String text) => fmt.localizeDigits(text);

  /// A user-entered name kept in one piece inside a sentence (a Latin drug
  /// name in an Arabic line never reorders its neighbours).
  String name(String text) => fmt.isolate(text.trim());

  /// The state dots of a counts-only widget: ● for each done item, ○ for
  /// each open one ("● ● ○"); null for none or more than [maxDots].
  static String? dots(int done, int total) {
    if (total <= 0 || total > maxDots) return null;
    final d = done.clamp(0, total);
    return [for (var i = 0; i < total; i++) i < d ? '●' : '○'].join(' ');
  }

  static const int maxDots = 10;
}
