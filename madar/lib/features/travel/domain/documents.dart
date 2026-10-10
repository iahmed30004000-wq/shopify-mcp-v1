import 'package:flutter/foundation.dart';

import '../../prayer/domain/cities.dart' show CityText;
import 'trip_timeline.dart';

/// What a travel document is, read from its name (the table stores only a
/// name): picks the icon and the passport validity rule.
enum TravelDocKind {
  passport,
  visa,
  licence,
  id,
  insurance,
  other;

  /// Keyword guess from [name] (Arabic or English, any letter variant).
  static TravelDocKind infer(String name) {
    final n = CityText.fold(name);
    bool has(List<String> words) => words.any(n.contains);
    if (has(const ['passport', 'جواز', 'باسبور'])) return TravelDocKind.passport;
    if (has(const ['visa', 'تاشيره', 'فيزا', 'اقامه', 'residence', 'permit'])) return TravelDocKind.visa;
    if (has(const ['licen', 'رخصه', 'driving', 'قياده'])) return TravelDocKind.licence;
    if (has(const ['insurance', 'تامين'])) return TravelDocKind.insurance;
    if (has(const ['هويه', 'identity', 'national']) || (n.contains('بطاقه') && has(const ['شخصيه', 'وطنيه']))) {
      return TravelDocKind.id;
    }
    if (n == 'id' || n.startsWith('id ') || n.endsWith(' id') || n.contains(' id ')) return TravelDocKind.id;
    return TravelDocKind.other;
  }
}

/// How close a document is to its expiry.
enum ExpiryState {
  /// No expiry date recorded.
  none,
  ok,

  /// Inside its reminder period (`remindDaysBefore`).
  soon,

  /// Expires today.
  today,
  expired,
}

@immutable
class DocumentExpiry {
  const DocumentExpiry(this.state, [this.daysLeft]);

  /// [expiry] seen from [today] (calendar days; a passport expiring on the
  /// 7th has "10 days" left all day on the 27th of the month before).
  factory DocumentExpiry.of({DateTime? expiry, required int remindDaysBefore, required DateTime today}) {
    if (expiry == null) return const DocumentExpiry(ExpiryState.none);
    final days = TravelDates.daysBetween(today, expiry);
    final state = days < 0
        ? ExpiryState.expired
        : days == 0
        ? ExpiryState.today
        : days <= remindDaysBefore
        ? ExpiryState.soon
        : ExpiryState.ok;
    return DocumentExpiry(state, days);
  }

  final ExpiryState state;

  /// Calendar days until expiry (negative once expired; null without a date).
  final int? daysLeft;

  /// Worth flagging (soon, today or expired).
  bool get needsAttention => state == ExpiryState.soon || state == ExpiryState.today || state == ExpiryState.expired;

  @override
  bool operator ==(Object other) => other is DocumentExpiry && other.state == state && other.daysLeft == daysLeft;

  @override
  int get hashCode => Object.hash(state, daysLeft);

  @override
  String toString() => 'DocumentExpiry($state, $daysLeft)';
}

/// The fields of a document the checks need (a row adapter).
@immutable
class DocFacts {
  const DocFacts({
    required this.id,
    required this.name,
    this.expiry,
    this.remindDaysBefore = 30,
    this.notes,
    this.holder,
    this.number,
  });

  final String id;
  final String name;
  final DateTime? expiry;
  final int remindDaysBefore;
  final String? notes;
  final String? holder;
  final String? number;

  TravelDocKind get kind => TravelDocKind.infer(name);
}

/// The fields of a trip the checks need.
@immutable
class TripFacts {
  const TripFacts({required this.id, required this.destination, this.country, this.start, this.end});

  final String id;
  final String destination;
  final String? country;
  final DateTime? start;
  final DateTime? end;
}

/// How a document clashes with a trip.
enum DocumentConflict {
  /// Expired – or expires – before the departure day.
  beforeTrip,

  /// Expires on one of the trip's days.
  duringTrip,

  /// A passport that expires within [TravelDocumentChecks.passportValidityMonths]
  /// months of the return (many countries refuse entry on one).
  validityShort;

  /// Most serious first.
  int get severity => switch (this) {
    DocumentConflict.beforeTrip => 3,
    DocumentConflict.duringTrip => 2,
    DocumentConflict.validityShort => 1,
  };
}

@immutable
class TripDocumentWarning {
  const TripDocumentWarning({required this.doc, required this.trip, required this.conflict});

  final DocFacts doc;
  final TripFacts trip;
  final DocumentConflict conflict;

  @override
  bool operator ==(Object other) =>
      other is TripDocumentWarning && other.doc.id == doc.id && other.trip.id == trip.id && other.conflict == conflict;

  @override
  int get hashCode => Object.hash(doc.id, trip.id, conflict);

  @override
  String toString() => 'TripDocumentWarning(${doc.name} × ${trip.destination}: $conflict)';
}

/// Document ↔ trip checks and ordering (pure).
abstract final class TravelDocumentChecks {
  /// Passports should stay valid this long after the return.
  static const passportValidityMonths = 6;

  /// Documents by expiry: soonest first, undated last, then by name.
  static List<T> sortByExpiry<T>(List<T> docs, {required DateTime? Function(T) expiryOf, String Function(T)? nameOf}) {
    final out = List<T>.of(docs);
    out.sort((a, b) {
      final ea = expiryOf(a), eb = expiryOf(b);
      if (ea == null && eb == null) {
        return nameOf == null ? 0 : nameOf(a).compareTo(nameOf(b));
      }
      if (ea == null) return 1;
      if (eb == null) return -1;
      final c = ea.compareTo(eb);
      return c != 0 || nameOf == null ? c : nameOf(a).compareTo(nameOf(b));
    });
    return out;
  }

  /// Whether [doc] matters for [trip]: every document does, except a visa
  /// (or residence permit) that names another place – a visa for one
  /// country says nothing about a trip to another. A visa naming no place
  /// is checked against every trip.
  static bool concerns(DocFacts doc, TripFacts trip) {
    if (doc.kind != TravelDocKind.visa) return true;
    // Whole words only: the country code "SA" must not match "vi-sa".
    final hay = ' ${CityText.words(CityText.fold('${doc.name} ${doc.notes ?? ''}')).join(' ')} ';
    for (final place in [trip.destination, ?trip.country]) {
      final words = CityText.words(CityText.fold(place));
      if (words.isEmpty || words.join().length < 2) continue;
      if (hay.contains(' ${words.join(' ')} ')) return true;
    }
    return !_namesAPlace(doc);
  }

  /// A visa's name is more than the word "visa" (e.g. «تأشيرة تركيا»).
  static bool _namesAPlace(DocFacts doc) {
    const generic = {'visa', 'تاشيره', 'فيزا', 'اقامه', 'residence', 'permit', 'e', 'evisa', 'دخول', 'entry'};
    final words = CityText.words(CityText.fold(doc.name));
    return words.any((w) => !generic.contains(w) && w.length > 1);
  }

  /// The conflict between [doc] and [trip], if any.
  static DocumentConflict? conflictOf(DocFacts doc, TripFacts trip) {
    final expiry = doc.expiry;
    final start = trip.start ?? trip.end;
    if (expiry == null || start == null) return null;
    if (!concerns(doc, trip)) return null;
    var end = trip.end ?? start;
    if (TravelDates.daysBetween(start, end) < 0) end = start;
    if (TravelDates.daysBetween(start, expiry) < 0) return DocumentConflict.beforeTrip;
    if (TravelDates.daysBetween(expiry, end) >= 0) return DocumentConflict.duringTrip;
    if (doc.kind == TravelDocKind.passport) {
      final limit = DateTime(end.year, end.month + passportValidityMonths, end.day);
      if (TravelDates.daysBetween(expiry, limit) > 0) return DocumentConflict.validityShort;
    }
    return null;
  }

  /// Every warning for [trip], most serious first.
  static List<TripDocumentWarning> forTrip(TripFacts trip, Iterable<DocFacts> docs) {
    final out = [
      for (final d in docs)
        if (conflictOf(d, trip) case final c?) TripDocumentWarning(doc: d, trip: trip, conflict: c),
    ];
    out.sort((a, b) => b.conflict.severity.compareTo(a.conflict.severity));
    return out;
  }

  /// Warnings for every trip still ahead or under way (the caller passes
  /// only those), in trip order then severity.
  static List<TripDocumentWarning> forTrips(Iterable<TripFacts> trips, Iterable<DocFacts> docs) => [
    for (final t in trips) ...forTrip(t, docs),
  ];
}
