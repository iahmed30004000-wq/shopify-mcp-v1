import 'package:flutter/foundation.dart';

import '../../../core/db/database.dart';
import '../../../core/domain/enums.dart';
import 'birthdays.dart';
import 'contact_stats.dart';
import 'rhythm.dart';

/// The relation suggestions (stored as these keys; anything else the user
/// types is stored – and shown – as written).
abstract final class FamilyRelations {
  static const List<String> keys = [
    'father',
    'mother',
    'wife',
    'husband',
    'son',
    'daughter',
    'brother',
    'sister',
    'grandfather',
    'grandmother',
    'uncle',
    'maternalUncle',
    'aunt',
    'maternalAunt',
    'inLaw',
    'relative',
    'friend',
    'colleague',
    'partner',
    'neighbour',
    'teacher',
  ];

  static bool isKey(String? value) => value != null && keys.contains(value);
}

/// What the person sheet returns.
@immutable
class PersonDraft {
  const PersonDraft({
    required this.name,
    this.relation,
    this.rhythmDays,
    this.phone,
    this.birthday,
    this.notes,
    this.color,
    this.showAsMoon = true,
    this.lastContact,
  });

  final String name;

  /// A [FamilyRelations] key or free text.
  final String? relation;
  final int? rhythmDays;
  final String? phone;

  /// Calendar day; year [Birthdays.unknownYear] when the year is unknown.
  final DateTime? birthday;
  final String? notes;
  final int? color;
  final bool showAsMoon;

  /// Only when adding: when the user last reached out (seeds the rhythm; no
  /// contact log is written).
  final DateTime? lastContact;

  factory PersonDraft.of(PersonRow p) => PersonDraft(
    name: p.name,
    relation: p.relation,
    rhythmDays: p.rhythmDays,
    phone: p.phone,
    birthday: p.birthday,
    notes: p.notes,
    color: p.color,
    showAsMoon: p.showAsMoon,
  );

  static String? _clean(String? s) {
    final t = s?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  /// Trimmed copy (empty texts become null, the rhythm is normalised).
  PersonDraft normalized() => PersonDraft(
    name: name.trim(),
    relation: _clean(relation),
    rhythmDays: RhythmEngine.normalizeRhythm(rhythmDays),
    phone: _clean(phone),
    birthday: birthday == null ? null : CalendarDays.dayOf(birthday!),
    notes: _clean(notes),
    color: color,
    showAsMoon: showAsMoon,
    lastContact: lastContact,
  );

  bool get isValid => name.trim().isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is PersonDraft &&
      other.name == name &&
      other.relation == relation &&
      other.rhythmDays == rhythmDays &&
      other.phone == phone &&
      other.birthday == birthday &&
      other.notes == notes &&
      other.color == color &&
      other.showAsMoon == showAsMoon &&
      other.lastContact == lastContact;

  @override
  int get hashCode => Object.hash(name, relation, rhythmDays, phone, birthday, notes, color, showAsMoon, lastContact);
}

/// What the "contacted" sheet returns.
@immutable
class ContactDraft {
  const ContactDraft({required this.channel, required this.at, this.note});

  final ContactChannel channel;
  final DateTime at;
  final String? note;

  @override
  bool operator ==(Object other) =>
      other is ContactDraft && other.channel == channel && other.at == at && other.note == note;

  @override
  int get hashCode => Object.hash(channel, at, note);
}

enum FamilySortMode { urgency, manual }

/// The Family preferences (stored encrypted under [storageKey]).
@immutable
class FamilySettings {
  const FamilySettings({
    this.digestEnabled = true,
    this.digestMinutes = defaultDigestMinutes,
    this.birthdaysEnabled = true,
    this.birthdayMinutes = defaultBirthdayMinutes,
    this.sortMode = FamilySortMode.urgency,
  });

  static const String storageKey = 'family.settings';

  /// 20:00 – after Maghrib most evenings, a calm time to call.
  static const int defaultDigestMinutes = 20 * 60;
  static const int defaultBirthdayMinutes = 9 * 60;

  final bool digestEnabled;

  /// Minutes after midnight.
  final int digestMinutes;
  final bool birthdaysEnabled;
  final int birthdayMinutes;
  final FamilySortMode sortMode;

  FamilySettings copyWith({
    bool? digestEnabled,
    int? digestMinutes,
    bool? birthdaysEnabled,
    int? birthdayMinutes,
    FamilySortMode? sortMode,
  }) => FamilySettings(
    digestEnabled: digestEnabled ?? this.digestEnabled,
    digestMinutes: digestMinutes ?? this.digestMinutes,
    birthdaysEnabled: birthdaysEnabled ?? this.birthdaysEnabled,
    birthdayMinutes: birthdayMinutes ?? this.birthdayMinutes,
    sortMode: sortMode ?? this.sortMode,
  );

  Map<String, Object?> toJson() => {
    'digest': digestEnabled,
    'digestAt': digestMinutes,
    'birthdays': birthdaysEnabled,
    'birthdayAt': birthdayMinutes,
    'sort': sortMode.name,
  };

  static int _minutes(Object? v, int fallback) => v is int && v >= 0 && v < 24 * 60 ? v : fallback;

  factory FamilySettings.fromJson(Object? json) {
    if (json is! Map) return const FamilySettings();
    return FamilySettings(
      digestEnabled: json['digest'] is bool ? json['digest'] as bool : true,
      digestMinutes: _minutes(json['digestAt'], defaultDigestMinutes),
      birthdaysEnabled: json['birthdays'] is bool ? json['birthdays'] as bool : true,
      birthdayMinutes: _minutes(json['birthdayAt'], defaultBirthdayMinutes),
      sortMode: FamilySortMode.values.where((m) => m.name == json['sort']).firstOrNull ?? FamilySortMode.urgency,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FamilySettings &&
      other.digestEnabled == digestEnabled &&
      other.digestMinutes == digestMinutes &&
      other.birthdaysEnabled == birthdaysEnabled &&
      other.birthdayMinutes == birthdayMinutes &&
      other.sortMode == sortMode;

  @override
  int get hashCode => Object.hash(digestEnabled, digestMinutes, birthdaysEnabled, birthdayMinutes, sortMode);
}

/// A person with everything the lists show, evaluated at one moment.
@immutable
class PersonView {
  const PersonView({required this.row, required this.rhythm, this.birthday, this.lastChannel, this.contactCount = 0});

  final PersonRow row;
  final RhythmState rhythm;
  final BirthdayInfo? birthday;

  /// The channel of the latest logged contact.
  final ContactChannel? lastChannel;
  final int contactCount;

  String get id => row.id;
  String get name => row.name;
  String? get relation => row.relation;
  String? get phone => row.phone;
  bool get hasPhone => (row.phone ?? '').trim().isNotEmpty;

  /// Builds the view of [row] from its logs.
  factory PersonView.build(PersonRow row, Iterable<ContactPoint> logs, DateTime now) {
    final past = logs.where((l) => !l.at.isAfter(now)).toList();
    ContactPoint? latest;
    for (final l in past) {
      if (latest == null || l.at.isAfter(latest.at)) latest = l;
    }
    final last = RhythmEngine.effectiveLastContact(
      stored: row.lastContact,
      logs: [for (final l in past) l.at],
      now: now,
    );
    return PersonView(
      row: row,
      rhythm: RhythmEngine.evaluate(rhythmDays: row.rhythmDays, lastContact: last, createdAt: row.createdAt, now: now),
      birthday: Birthdays.next(row.birthday, now),
      lastChannel: latest?.channel,
      contactCount: past.length,
    );
  }
}

/// Everyone, evaluated at [now]: the Family screen's and card's model.
@immutable
class FamilyOverview {
  const FamilyOverview({required this.people, required this.now});

  /// People in their manual order.
  final List<PersonView> people;
  final DateTime now;

  static FamilyOverview build(
    List<PersonRow> rows,
    Iterable<({String personId, ContactPoint point})> logs,
    DateTime now,
  ) {
    final byPerson = <String, List<ContactPoint>>{};
    for (final l in logs) {
      (byPerson[l.personId] ??= []).add(l.point);
    }
    return FamilyOverview(
      people: [for (final r in rows) PersonView.build(r, byPerson[r.id] ?? const [], now)],
      now: now,
    );
  }

  bool get isEmpty => people.isEmpty;

  List<PersonView> get byUrgency => RhythmEngine.byUrgency(people, (p) => p.rhythm);

  Map<FamilyGroup, List<PersonView>> get groups => RhythmEngine.group(people, (p) => p.rhythm);

  /// Due today or overdue, most urgent first.
  List<PersonView> get due => [
    for (final p in byUrgency)
      if (p.rhythm.isDue) p,
  ];

  int get withRhythm => people.where((p) => p.rhythm.hasRhythm).length;

  /// People with a rhythm who are not overdue.
  int get inTouch => people.where((p) => p.rhythm.hasRhythm && p.rhythm.status != RhythmStatus.overdue).length;

  /// Share of people with a rhythm who are not overdue (null if none).
  double? get inTouchShare => withRhythm == 0 ? null : inTouch / withRhythm;

  /// Birthdays within [withinDays] days, soonest first.
  List<PersonView> upcomingBirthdays({int withinDays = 30}) {
    final list = people.where((p) => p.birthday != null && p.birthday!.daysUntil <= withinDays).toList()
      ..sort((a, b) => a.birthday!.daysUntil.compareTo(b.birthday!.daysUntil));
    return list;
  }

  PersonView? byId(String id) => people.where((p) => p.id == id).firstOrNull;
}
