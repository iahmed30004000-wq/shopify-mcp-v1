import 'package:flutter/foundation.dart';

import '../../../core/db/database.dart';
import '../../../core/domain/enums.dart';
import '../../prayer/domain/cities.dart';
import 'destination_prayer.dart';
import 'documents.dart';
import 'packing.dart';
import 'trip_timeline.dart';

/// A trip as the screens show it: its row, the status in force (dates or a
/// manual choice), the list it belongs in, its countdown and packing.
@immutable
class TripView {
  const TripView({
    required this.row,
    required this.status,
    required this.manual,
    required this.phase,
    required this.countdown,
    required this.packing,
    required this.place,
  });

  /// Builds the view of [row] at [now]. [place] is resolved by the caller
  /// (the city list loads asynchronously); its zone decides the
  /// destination's calendar.
  factory TripView.of(
    TripRow row, {
    required DateTime now,
    required bool manual,
    PackingProgress packing = PackingProgress.empty,
    TripPlace? place,
  }) {
    final timeline = TripTimeline(start: row.startDate, end: row.endDate);
    final today = TravelToday.at(now, zone: place?.zone);
    final status = timeline.effective(stored: row.status, manual: manual, today: today);
    return TripView(
      row: row,
      status: status,
      manual: manual,
      phase: timeline.phaseOf(status),
      countdown: timeline.countdown(status, today),
      packing: packing,
      place: place,
    );
  }

  final TripRow row;
  final TripStatus status;

  /// The status was chosen by hand (not derived from the dates).
  final bool manual;
  final TripPhase phase;
  final TripCountdown countdown;
  final PackingProgress packing;
  final TripPlace? place;

  String get id => row.id;

  TripTimeline get timeline => TripTimeline(start: row.startDate, end: row.endDate);

  TripFacts get facts =>
      TripFacts(id: row.id, destination: row.destination, country: row.country, start: row.startDate, end: row.endDate);

  /// The destination's name in [languageCode]: a listed city's own name in
  /// that language unless the user renamed it.
  String displayName(String languageCode) {
    final c = place?.city;
    if (c != null && (row.destination == c.nameAr || row.destination == c.nameEn)) return c.name(languageCode);
    return row.destination;
  }

  /// The country's name in [languageCode] (a stored ISO code is looked up in
  /// [cities]; free text is shown as typed).
  String? countryName(String languageCode, CityDatabase? cities) {
    final code = place?.countryCode ?? row.country;
    if (code == null || code.trim().isEmpty) return null;
    if (code.length == 2 && cities != null && cities.countries.containsKey(code.toUpperCase())) {
      return cities.countryName(code.toUpperCase(), languageCode);
    }
    return code;
  }
}

/// The travel lists: current, upcoming (soonest first, undated last) and
/// past (latest first) trips, and documents by expiry.
@immutable
class TravelOverview {
  const TravelOverview({
    required this.current,
    required this.upcoming,
    required this.past,
    required this.documents,
    required this.warnings,
  });

  static const empty = TravelOverview(current: [], upcoming: [], past: [], documents: [], warnings: []);

  factory TravelOverview.of({
    required List<TripView> trips,
    required List<DocFacts> documents,
  }) {
    int byStart(TripView a, TripView b) {
      final sa = a.row.startDate, sb = b.row.startDate;
      if (sa == null && sb == null) return a.row.createdAt.compareTo(b.row.createdAt);
      if (sa == null) return 1;
      if (sb == null) return -1;
      return sa.compareTo(sb);
    }

    final current = trips.where((t) => t.phase == TripPhase.current).toList()..sort(byStart);
    final upcoming = trips.where((t) => t.phase == TripPhase.upcoming || t.phase == TripPhase.undated).toList()
      ..sort(byStart);
    final past = trips.where((t) => t.phase == TripPhase.past).toList()..sort((a, b) => byStart(b, a));
    final docs = TravelDocumentChecks.sortByExpiry(documents, expiryOf: (d) => d.expiry, nameOf: (d) => d.name);
    final warnings = TravelDocumentChecks.forTrips([for (final t in [...current, ...upcoming]) t.facts], docs);
    return TravelOverview(current: current, upcoming: upcoming, past: past, documents: docs, warnings: warnings);
  }

  final List<TripView> current;
  final List<TripView> upcoming;
  final List<TripView> past;
  final List<DocFacts> documents;
  final List<TripDocumentWarning> warnings;

  bool get hasTrips => current.isNotEmpty || upcoming.isNotEmpty || past.isNotEmpty;

  /// The trip under way, else the next dated one, else the first undated.
  TripView? get focus => current.firstOrNull ?? upcoming.firstOrNull;

  List<TripDocumentWarning> warningsFor(String tripId) => [
    for (final w in warnings)
      if (w.trip.id == tripId) w,
  ];

  /// Documents that need attention on [today] (inside their reminder
  /// period, due today or expired).
  List<(DocFacts, DocumentExpiry)> attention(DateTime today) => [
    for (final d in documents)
      if (DocumentExpiry.of(expiry: d.expiry, remindDaysBefore: d.remindDaysBefore, today: today) case final e
          when e.needsAttention)
        (d, e),
  ];
}

/// [TravelDocumentRow] → [DocFacts].
DocFacts docFactsOf(TravelDocumentRow d) => DocFacts(
  id: d.id,
  name: d.name,
  expiry: d.expiry,
  remindDaysBefore: d.remindDaysBefore,
  notes: d.notes,
  holder: d.holder,
  number: d.number,
);
