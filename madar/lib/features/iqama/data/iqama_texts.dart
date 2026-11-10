import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/settings/app_settings.dart';
import '../../adhan/domain/adhan_slot.dart';
import '../../adhan/domain/adhan_sound.dart';

/// Localised iqama texts (notifications, channels, the settings screen)
/// with numbers in the user's digit style and prayer times on the
/// location's clock – the adhan's [AdhanTexts] pattern, for «الإقامة».
///
/// It is built outside the widget tree too (the background isolate writes
/// its notices in the language the notification was written in), so it
/// never reads a [BuildContext].
class IqamaTexts {
  IqamaTexts(this.l10n, this.fmt, {DateTime Function(DateTime instant)? wallClock, this.clock24h = false})
    : _wallClock = wallClock ?? ((t) => t.toLocal()) {
    _ensureDateSymbols();
  }

  static bool _dateSymbols = false;

  static void _ensureDateSymbols() {
    if (_dateSymbols) return;
    _dateSymbols = true;
    initializeDateFormatting();
  }

  factory IqamaTexts.forLanguage(
    String languageCode, {
    DigitStyle digits = DigitStyle.auto,
    DateTime Function(DateTime instant)? wallClock,
    bool clock24h = false,
  }) => IqamaTexts(
    lookupL10n(Locale(languageCode == 'ar' ? 'ar' : 'en')),
    MadarFormatter(languageCode: languageCode, digits: digits),
    wallClock: wallClock,
    clock24h: clock24h,
  );

  final L10n l10n;
  final MadarFormatter fmt;
  final DateTime Function(DateTime instant) _wallClock;
  final bool clock24h;

  String prayer(AdhanSlot s) => switch (s) {
    AdhanSlot.fajr => l10n.prayerFajr,
    AdhanSlot.sunrise => l10n.prayerSunrise,
    AdhanSlot.dhuhr => l10n.prayerDhuhr,
    AdhanSlot.asr => l10n.prayerAsr,
    AdhanSlot.maghrib => l10n.prayerMaghrib,
    AdhanSlot.isha => l10n.prayerIsha,
  };

  /// A prayer time on the location's clock (`٦:٣١ م`, `18:31`).
  String time(DateTime instant) {
    final t = _wallClock(instant);
    if (!clock24h) return fmt.formatTime(t);
    return fmt.localizeDigits(DateFormat('HH:mm', 'en').format(t));
  }

  /// `١٥ دقيقة` / `15 minutes` (the adhan's own plural).
  String minutes(int m) => fmt.localizeDigits(l10n.adhanMinutes(m));

  /// `١٥ د` / `15 min`.
  String minutesShort(int m) => l10n.adhanMinutesShort(fmt.formatInt(m));

  String toneName(TanbihTone t) => switch (t) {
    TanbihTone.dawn => l10n.adhanToneDawn,
    TanbihTone.brass => l10n.adhanToneBrass,
    TanbihTone.bowl => l10n.adhanToneBowl,
    TanbihTone.chime => l10n.adhanToneChime,
    TanbihTone.sunrise => l10n.adhanToneSunrise,
  };

  /// Display name of a sound (a recording's own name).
  String soundName(AdhanSoundRef ref, {CustomMuezzin? muezzin}) => switch (ref.kind) {
    AdhanSoundKind.tone => toneName(ref.tone!),
    AdhanSoundKind.file => muezzin?.name ?? l10n.adhanMuezzinMissing,
    AdhanSoundKind.silent => l10n.adhanSilent,
  };

  // Notifications -----------------------------------------------------------

  /// «قامت الصلاة».
  String get title => l10n.iqamaNotifTitle;
  String get snoozeTitle => l10n.iqamaNotifSnoozeTitle;
  String body(AdhanSlot slot, DateTime prayerAt) => l10n.iqamaNotifBody(prayer(slot), time(prayerAt));
  String get prayedAction => l10n.iqamaActionPrayed;
  String get laterAction => l10n.iqamaActionLater;

  String alreadyTitle(AdhanSlot slot) => l10n.iqamaAlreadyTitle(prayer(slot));
  String get alreadyBody => l10n.iqamaAlreadyBody;
  String get failedTitle => l10n.iqamaFailedTitle;
  String get failedBody => l10n.iqamaFailedBody;

  String channel(String soundName) => l10n.iqamaChannel(soundName);
  String get channelDescription => l10n.iqamaChannelHint;

  /// The channel group is the adhan's: «الصلاة والأذان» holds both.
  String get channelGroup => l10n.adhanChannelGroup;

  /// What one prayer's iqama is called (row switch, sheet, the centre).
  String label(AdhanSlot slot) => l10n.iqamaPrayerLabel(prayer(slot));

  /// `بعد الأذان بـ١٥ دقيقة` / `with the adhan`.
  String delay(int m) => m == 0 ? l10n.iqamaWithAdhan : l10n.iqamaAfterAdhan(minutes(m));
}
