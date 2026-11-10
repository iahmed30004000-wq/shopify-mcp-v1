import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/travel/domain/documents.dart';

void main() {
  DateTime d(int y, int m, int day) => DateTime(y, m, day);

  group('kind', () {
    test('is read from the name in Arabic or English', () {
      expect(TravelDocKind.infer('جواز السفر'), TravelDocKind.passport);
      expect(TravelDocKind.infer('Passport'), TravelDocKind.passport);
      expect(TravelDocKind.infer('تأشيرة تركيا'), TravelDocKind.visa);
      expect(TravelDocKind.infer('Schengen visa'), TravelDocKind.visa);
      expect(TravelDocKind.infer('رخصة القيادة'), TravelDocKind.licence);
      expect(TravelDocKind.infer('Driving licence'), TravelDocKind.licence);
      expect(TravelDocKind.infer('البطاقة الشخصية'), TravelDocKind.id);
      expect(TravelDocKind.infer('National ID'), TravelDocKind.id);
      expect(TravelDocKind.infer('تأمين السفر'), TravelDocKind.insurance);
      expect(TravelDocKind.infer('Vaccination card'), TravelDocKind.other);
    });
  });

  group('expiry', () {
    final today = d(2026, 9, 29);
    DocumentExpiry of(DateTime? e, [int remind = 30]) =>
        DocumentExpiry.of(expiry: e, remindDaysBefore: remind, today: today);

    test('counts calendar days to the expiry', () {
      expect(of(null), const DocumentExpiry(ExpiryState.none));
      expect(of(d(2027, 3, 1)), const DocumentExpiry(ExpiryState.ok, 153));
      expect(of(d(2026, 10, 29)), const DocumentExpiry(ExpiryState.soon, 30));
      expect(of(d(2026, 10, 30)).state, ExpiryState.ok);
      expect(of(d(2026, 9, 29)), const DocumentExpiry(ExpiryState.today, 0));
      expect(of(d(2026, 9, 26)), const DocumentExpiry(ExpiryState.expired, -3));
      expect(of(d(2026, 10, 5), 0).state, ExpiryState.ok);
    });

    test('flags the ones needing attention', () {
      expect(of(d(2026, 10, 10)).needsAttention, isTrue);
      expect(of(d(2027, 10, 10)).needsAttention, isFalse);
      expect(of(d(2026, 1, 1)).needsAttention, isTrue);
    });

    test('sorts soonest first, undated last', () {
      final docs = [
        (name: 'b', e: null),
        (name: 'c', e: d(2027, 1, 1)),
        (name: 'a', e: d(2026, 10, 1)),
        (name: 'a2', e: null),
      ];
      final sorted = TravelDocumentChecks.sortByExpiry(docs, expiryOf: (x) => x.e, nameOf: (x) => x.name);
      expect(sorted.map((x) => x.name), ['a', 'c', 'a2', 'b']);
    });
  });

  group('trip warnings', () {
    const trip = TripFacts(id: 't', destination: 'إسطنبول', country: 'TR', start: null, end: null);
    final oct = TripFacts(id: 't', destination: 'إسطنبول', country: 'TR', start: d(2026, 10, 8), end: d(2026, 10, 14));
    DocFacts doc(String name, DateTime? expiry, {String? notes}) =>
        DocFacts(id: name, name: name, expiry: expiry, notes: notes);

    test('expires before the departure', () {
      expect(TravelDocumentChecks.conflictOf(doc('جواز السفر', d(2026, 10, 7)), oct), DocumentConflict.beforeTrip);
      expect(TravelDocumentChecks.conflictOf(doc('Licence', d(2026, 9, 1)), oct), DocumentConflict.beforeTrip);
    });

    test('expires during the trip (first and last day included)', () {
      expect(TravelDocumentChecks.conflictOf(doc('Licence', d(2026, 10, 8)), oct), DocumentConflict.duringTrip);
      expect(TravelDocumentChecks.conflictOf(doc('Licence', d(2026, 10, 14)), oct), DocumentConflict.duringTrip);
      expect(TravelDocumentChecks.conflictOf(doc('Licence', d(2026, 10, 15)), oct), isNull);
    });

    test('a passport needs six months after the return', () {
      expect(TravelDocumentChecks.conflictOf(doc('Passport', d(2027, 3, 1)), oct), DocumentConflict.validityShort);
      expect(TravelDocumentChecks.conflictOf(doc('Passport', d(2027, 4, 15)), oct), isNull);
      // Only passports: a licence may expire soon after.
      expect(TravelDocumentChecks.conflictOf(doc('Licence', d(2027, 1, 1)), oct), isNull);
    });

    test('no dates, no expiry: nothing to say', () {
      expect(TravelDocumentChecks.conflictOf(doc('Passport', d(2026, 1, 1)), trip), isNull);
      expect(TravelDocumentChecks.conflictOf(doc('Passport', null), oct), isNull);
    });

    test('a visa for another country does not concern the trip', () {
      expect(TravelDocumentChecks.conflictOf(doc('تأشيرة مصر', d(2026, 10, 10)), oct), isNull);
      // A country code matches whole words only ("SA" is not in "visa").
      const makkah = TripFacts(id: 'm', destination: 'Makkah', country: 'SA', start: null, end: null);
      final dec = TripFacts(id: 'm', destination: makkah.destination, country: 'SA', start: d(2026, 12, 20), end: d(2026, 12, 28));
      expect(TravelDocumentChecks.conflictOf(doc('Turkey e-visa', d(2026, 10, 20)), dec), isNull);
      expect(TravelDocumentChecks.conflictOf(doc('Visa SA', d(2026, 10, 20)), dec), DocumentConflict.beforeTrip);
      expect(TravelDocumentChecks.conflictOf(doc('تأشيرة اسطنبول', d(2026, 10, 10)), oct), DocumentConflict.duringTrip);
      expect(
        TravelDocumentChecks.conflictOf(doc('Visa', d(2026, 10, 10), notes: 'multiple entry'), oct),
        DocumentConflict.duringTrip,
      );
      expect(
        TravelDocumentChecks.conflictOf(doc('e-Visa', d(2026, 10, 10), notes: 'tr'), oct),
        DocumentConflict.duringTrip,
      );
    });

    test('warnings come most serious first', () {
      final w = TravelDocumentChecks.forTrip(oct, [
        doc('Passport', d(2027, 2, 1)),
        doc('Licence', d(2026, 10, 1)),
        doc('Insurance', d(2026, 10, 10)),
      ]);
      expect(w.map((x) => x.conflict), [
        DocumentConflict.beforeTrip,
        DocumentConflict.duringTrip,
        DocumentConflict.validityShort,
      ]);
    });
  });
}
