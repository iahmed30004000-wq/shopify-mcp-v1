import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/settings/app_settings.dart';
import '../domain/adhan_slot.dart';
import '../domain/adhan_sound.dart';

/// Localised adhan texts (notifications, channels, screens) with numbers in
/// the user's digit style and prayer times on the location's clock.
class AdhanTexts {
  AdhanTexts(this.l10n, this.fmt, {DateTime Function(DateTime instant)? wallClock, this.clock24h = false})
    : _wallClock = wallClock ?? ((t) => t.toLocal()) {
    _ensureDateSymbols();
  }

  static bool _dateSymbols = false;

  /// Notification texts are built outside the widget tree (and possibly
  /// before the app's localisations load intl's date symbols): load them –
  /// synchronously, they are compiled in.
  static void _ensureDateSymbols() {
    if (_dateSymbols) return;
    _dateSymbols = true;
    initializeDateFormatting();
  }

  factory AdhanTexts.forLanguage(
    String languageCode, {
    DigitStyle digits = DigitStyle.auto,
    DateTime Function(DateTime instant)? wallClock,
    bool clock24h = false,
  }) => AdhanTexts(
    lookupL10n(Locale(languageCode == 'ar' ? 'ar' : 'en')),
    MadarFormatter(languageCode: languageCode, digits: digits),
    wallClock: wallClock,
    clock24h: clock24h,
  );

  final L10n l10n;
  final MadarFormatter fmt;
  final DateTime Function(DateTime instant) _wallClock;

  /// Prayer times on a 24-hour clock (the prayer settings' choice).
  final bool clock24h;

  /// The prayer's name in the UI language.
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

  /// `١٠ دقائق` / `10 minutes`.
  String minutes(int m) => fmt.localizeDigits(l10n.adhanMinutes(m));

  /// `١٠ د` / `10 min`.
  String minutesShort(int m) => l10n.adhanMinutesShort(fmt.formatInt(m));

  String toneName(TanbihTone t) => switch (t) {
    TanbihTone.dawn => l10n.adhanToneDawn,
    TanbihTone.brass => l10n.adhanToneBrass,
    TanbihTone.bowl => l10n.adhanToneBowl,
    TanbihTone.chime => l10n.adhanToneChime,
    TanbihTone.sunrise => l10n.adhanToneSunrise,
  };

  String toneDescription(TanbihTone t) => switch (t) {
    TanbihTone.dawn => l10n.adhanToneDawnHint,
    TanbihTone.brass => l10n.adhanToneBrassHint,
    TanbihTone.bowl => l10n.adhanToneBowlHint,
    TanbihTone.chime || TanbihTone.sunrise => l10n.adhanToneChimeHint,
  };

  /// Display name of a sound (a recording's own name).
  String soundName(AdhanSoundRef ref, {CustomMuezzin? muezzin}) => switch (ref.kind) {
    AdhanSoundKind.tone => toneName(ref.tone!),
    AdhanSoundKind.file => muezzin?.name ?? l10n.adhanMuezzinMissing,
    AdhanSoundKind.silent => l10n.adhanSilent,
  };

  // Notifications -----------------------------------------------------------

  String callTitle(AdhanSlot s) => l10n.adhanNotifCallTitle(prayer(s));
  String callBody(DateTime prayerAt) => l10n.adhanNotifCallBody(time(prayerAt));
  String preTitle(AdhanSlot s, int minutesBefore) => l10n.adhanNotifPreTitle(prayer(s), minutes(minutesBefore));
  String preBody(DateTime prayerAt) => l10n.adhanNotifPreBody(time(prayerAt));
  String sunriseTitle(int minutesBefore) =>
      minutesBefore <= 0 ? l10n.adhanNotifSunriseTitle : l10n.adhanNotifSunriseSoonTitle(minutes(minutesBefore));
  String sunriseBody(int minutesBefore, DateTime sunriseAt) =>
      minutesBefore <= 0 ? l10n.adhanNotifSunriseBody : l10n.adhanNotifSunriseSoonBody(time(sunriseAt));
  String testTitle(AdhanSlot s) => l10n.adhanNotifTestTitle(prayer(s));
  String get testBody => l10n.adhanNotifTestBody;
  String get stopAction => l10n.adhanStop;

  String channelCall(String soundName) => l10n.adhanChannelCall(soundName);
  String get channelCallDescription => l10n.adhanChannelCallHint;
  String get channelReminder => l10n.adhanChannelReminder;
  String get channelSunrise => l10n.adhanChannelSunrise;
  String get channelGroup => l10n.adhanChannelGroup;
}
