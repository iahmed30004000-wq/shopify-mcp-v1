/// The AI-ready Markdown summary: named sections that can each be included
/// or left out, and the options the user picked (persisted in the encrypted
/// database, never outside it). Pure Dart.
library;

import 'dart:convert';

import 'package:meta/meta.dart';

/// The sections of the summary, in document order.
enum SummarySectionId { profile, faith, health, money, family, work, growth, body, travel, custom }

/// Profile basics the user chose to share (all off by default).
@immutable
class SummaryProfileOptions {
  const SummaryProfileOptions({
    this.city = false,
    this.timeZone = false,
    this.currency = false,
    this.language = false,
    this.aboutMe = '',
  });

  final bool city;
  final bool timeZone;
  final bool currency;
  final bool language;

  /// A short note the user typed (age, context …); empty = none.
  final String aboutMe;

  bool get isEmpty => !city && !timeZone && !currency && !language && aboutMe.trim().isEmpty;

  SummaryProfileOptions copyWith({bool? city, bool? timeZone, bool? currency, bool? language, String? aboutMe}) =>
      SummaryProfileOptions(
        city: city ?? this.city,
        timeZone: timeZone ?? this.timeZone,
        currency: currency ?? this.currency,
        language: language ?? this.language,
        aboutMe: aboutMe ?? this.aboutMe,
      );

  Map<String, Object?> toJson() => {
    'city': city,
    'timeZone': timeZone,
    'currency': currency,
    'language': language,
    if (aboutMe.trim().isNotEmpty) 'aboutMe': aboutMe,
  };

  static SummaryProfileOptions fromJson(Object? json) {
    if (json is! Map) return const SummaryProfileOptions();
    bool b(String k) => json[k] == true;
    final about = json['aboutMe'];
    return SummaryProfileOptions(
      city: b('city'),
      timeZone: b('timeZone'),
      currency: b('currency'),
      language: b('language'),
      aboutMe: about is String ? about : '',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SummaryProfileOptions &&
      other.city == city &&
      other.timeZone == timeZone &&
      other.currency == currency &&
      other.language == language &&
      other.aboutMe == aboutMe;

  @override
  int get hashCode => Object.hash(city, timeZone, currency, language, aboutMe);
}

/// Which sections go out, plus the profile choices.
@immutable
class AiSummaryOptions {
  const AiSummaryOptions({this.included = defaultIncluded, this.profile = const SummaryProfileOptions()});

  /// `key_values` key of the stored choices.
  static const String storageKey = 'data.aiSummary';

  /// Everything except the profile, which is opt-in.
  static const Set<SummarySectionId> defaultIncluded = {
    SummarySectionId.faith,
    SummarySectionId.health,
    SummarySectionId.money,
    SummarySectionId.family,
    SummarySectionId.work,
    SummarySectionId.growth,
    SummarySectionId.body,
    SummarySectionId.travel,
    SummarySectionId.custom,
  };

  final Set<SummarySectionId> included;
  final SummaryProfileOptions profile;

  AiSummaryOptions toggle(SummarySectionId id, bool on) =>
      AiSummaryOptions(included: on ? {...included, id} : ({...included}..remove(id)), profile: profile);

  AiSummaryOptions withProfile(SummaryProfileOptions p) => AiSummaryOptions(included: included, profile: p);

  Map<String, Object?> toJson() => {
    'included': [
      for (final s in SummarySectionId.values)
        if (included.contains(s)) s.name,
    ],
    'profile': profile.toJson(),
  };

  static AiSummaryOptions fromJson(Object? json) {
    if (json is! Map) return const AiSummaryOptions();
    final raw = json['included'];
    final included = raw is List
        ? {
            for (final s in SummarySectionId.values)
              if (raw.contains(s.name)) s,
          }
        : defaultIncluded;
    return AiSummaryOptions(included: included, profile: SummaryProfileOptions.fromJson(json['profile']));
  }

  @override
  bool operator ==(Object other) =>
      other is AiSummaryOptions && other.profile == profile && _sameSet(other.included, included);

  static bool _sameSet(Set<Object> a, Set<Object> b) => a.length == b.length && a.containsAll(b);

  @override
  int get hashCode => Object.hash(Object.hashAllUnordered(included), profile);
}

/// One section of the summary.
@immutable
class SummarySection {
  const SummarySection({required this.id, required this.title, required this.body, required this.isEmpty});

  final SummarySectionId id;

  /// Localised heading (without `##`).
  final String title;

  /// Markdown under the heading (no trailing newline); for an empty
  /// section, the "no data" line.
  final String body;

  /// No data to share: left out of [AiSummary.compose].
  final bool isEmpty;

  String get markdown => '## $title\n\n$body';
}

/// A built summary: the document header and every section.
@immutable
class AiSummary {
  const AiSummary({required this.heading, required this.preamble, required this.sections});

  /// `# …` line text (without `#`).
  final String heading;

  /// One line under the heading.
  final String preamble;
  final List<SummarySection> sections;

  SummarySection section(SummarySectionId id) => sections.firstWhere((s) => s.id == id);

  /// Sections that are [included] and hold data, in document order.
  List<SummarySection> selected(Set<SummarySectionId> included) => [
    for (final s in sections)
      if (included.contains(s.id) && !s.isEmpty) s,
  ];

  /// The Markdown document with the [included] sections (empty sections
  /// are always left out). Deterministic: same data + options → same text.
  String compose(Set<SummarySectionId> included) {
    final b = StringBuffer('# $heading\n\n$preamble\n');
    for (final s in selected(included)) {
      b.write('\n${s.markdown}\n');
    }
    return b.toString();
  }

  /// UTF-8 size of [text] in bytes.
  static int byteSize(String text) => utf8.encode(text).length;

  /// Rough token count for a language model: ~4 Latin characters or ~2
  /// Arabic characters per token. An estimate for the size hint only.
  static int estimateTokens(String text) {
    var ascii = 0, other = 0;
    for (final c in text.runes) {
      if (c < 0x80) {
        ascii++;
      } else {
        other++;
      }
    }
    return (ascii / 4 + other / 2).ceil();
  }
}
