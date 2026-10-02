import 'package:meta/meta.dart';

import '../../../core/quran/ayah.dart';

/// How the reader lays the text out.
enum QuranReaderMode {
  /// The Madani mushaf's 604 pages, swiped right-to-left.
  mushaf,

  /// One sura as a list of ayah cards (optionally with a translation).
  list,
}

/// Where tajweed colours come from.
enum TajweedSource {
  /// The bundled, offline annotations (always available).
  bundled,

  /// Quran.com's tajweed text where it has been downloaded; bundled otherwise.
  quranCom,
}

/// Reader settings, stored in KeyValues under [storageKey].
@immutable
class QuranReaderPrefs {
  const QuranReaderPrefs({
    this.mode = QuranReaderMode.mushaf,
    this.fontSize = defaultFontSize,
    this.tajweed = true,
    this.translation = false,
    this.translationId = sahihInternational,
    this.tajweedSource = TajweedSource.bundled,
  });

  factory QuranReaderPrefs.fromJson(Object? json) {
    if (json is! Map) return const QuranReaderPrefs();
    T pick<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.firstWhere((v) => v.name == name, orElse: () => fallback);
    final size = json['fontSize'];
    return QuranReaderPrefs(
      mode: pick(QuranReaderMode.values, json['mode'], QuranReaderMode.mushaf),
      fontSize: size is num ? clampFontSize(size.toDouble()) : defaultFontSize,
      tajweed: json['tajweed'] is bool ? json['tajweed']! as bool : true,
      translation: json['translation'] is bool ? json['translation']! as bool : false,
      translationId: json['translationId'] is int ? json['translationId']! as int : sahihInternational,
      tajweedSource: pick(TajweedSource.values, json['tajweedSource'], TajweedSource.bundled),
    );
  }

  static const String storageKey = 'quran.reader';

  /// Quran.com resource id of Saheeh International (English).
  static const int sahihInternational = 20;

  static const double minFontSize = 18;
  static const double maxFontSize = 44;
  static const double defaultFontSize = 25;
  static const double fontStep = 2;

  static double clampFontSize(double v) => v.clamp(minFontSize, maxFontSize).toDouble();

  final QuranReaderMode mode;

  /// Quran text size in logical pixels.
  final double fontSize;
  final bool tajweed;

  /// Show the translation under each ayah (list mode).
  final bool translation;
  final int translationId;
  final TajweedSource tajweedSource;

  QuranReaderPrefs copyWith({
    QuranReaderMode? mode,
    double? fontSize,
    bool? tajweed,
    bool? translation,
    int? translationId,
    TajweedSource? tajweedSource,
  }) => QuranReaderPrefs(
    mode: mode ?? this.mode,
    fontSize: fontSize == null ? this.fontSize : clampFontSize(fontSize),
    tajweed: tajweed ?? this.tajweed,
    translation: translation ?? this.translation,
    translationId: translationId ?? this.translationId,
    tajweedSource: tajweedSource ?? this.tajweedSource,
  );

  Map<String, Object?> toJson() => {
    'mode': mode.name,
    'fontSize': fontSize,
    'tajweed': tajweed,
    'translation': translation,
    'translationId': translationId,
    'tajweedSource': tajweedSource.name,
  };

  @override
  bool operator ==(Object other) =>
      other is QuranReaderPrefs &&
      other.mode == mode &&
      other.fontSize == fontSize &&
      other.tajweed == tajweed &&
      other.translation == translation &&
      other.translationId == translationId &&
      other.tajweedSource == tajweedSource;

  @override
  int get hashCode => Object.hash(mode, fontSize, tajweed, translation, translationId, tajweedSource);
}

/// Where the reader was last: stored under [storageKey].
@immutable
class QuranLastRead {
  const QuranLastRead({required this.ref, required this.page, required this.at, required this.mode});

  static QuranLastRead? fromJson(Object? json) {
    if (json is! Map) return null;
    final s = json['surah'];
    final a = json['ayah'];
    final p = json['page'];
    final at = json['at'];
    if (s is! int || a is! int || p is! int || s < 1 || s > 114 || a < 1 || p < 1 || p > 604) return null;
    return QuranLastRead(
      ref: AyahRef(s, a),
      page: p,
      at: at is String ? DateTime.tryParse(at) ?? DateTime(2000) : DateTime(2000),
      mode: json['mode'] == QuranReaderMode.list.name ? QuranReaderMode.list : QuranReaderMode.mushaf,
    );
  }

  static const String storageKey = 'quran.lastRead';

  final AyahRef ref;
  final int page;
  final DateTime at;
  final QuranReaderMode mode;

  Map<String, Object?> toJson() => {
    'surah': ref.surah,
    'ayah': ref.ayah,
    'page': page,
    'at': at.toIso8601String(),
    'mode': mode.name,
  };

  @override
  bool operator ==(Object other) =>
      other is QuranLastRead && other.ref == ref && other.page == page && other.at == at && other.mode == mode;

  @override
  int get hashCode => Object.hash(ref, page, at, mode);
}
