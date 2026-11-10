import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/reading/domain/book_direction.dart';
import 'package:madar/features/reading/domain/library_entry.dart';
import 'package:madar/features/reading/domain/licence_policy.dart';

final _hash = 'a' * 64;

LibraryEntry _entry({
  String id = 'b1',
  LibrarySourceKind kind = LibrarySourceKind.wikisource,
  String? sourceUrl = 'https://ar.wikisource.org/wiki/x',
  String licence = 'cc-by-sa-4.0',
  String? licenceUrl = 'https://creativecommons.org/licenses/by-sa/4.0/',
  String credit = 'Wikisource contributors',
  int size = 1000,
  String? sha = 'AUTO',
  List<LibraryPart> parts = const [],
}) => LibraryEntry(
  id: id,
  title: 'Title',
  authors: const ['A'],
  language: 'ar',
  sourceKind: kind,
  sourceUrl: sourceUrl,
  licenceId: licence,
  licenceUrl: licenceUrl,
  credit: credit,
  sizeBytes: size,
  sha256: sha == 'AUTO' ? _hash : sha,
  parts: parts,
);

Set<ViolationCode> _codes(LibraryEntry e) => const LicenceGate().assess(e).violations.map((v) => v.code).toSet();

void main() {
  const gate = LicenceGate();

  group('LibraryEntry JSON', () {
    test('round-trips every field', () {
      final e = LibraryEntry(
        id: 'g-1',
        title: 'عنوان',
        authors: const ['a', 'b'],
        language: 'ar',
        sourceKind: LibrarySourceKind.gutenberg,
        sourceUrl: 'https://www.gutenberg.org/ebooks/1',
        licenceId: 'pg-license',
        licenceUrl: 'https://www.gutenberg.org/policy/license.html',
        credit: 'Project Gutenberg',
        sizeBytes: 300,
        sha256: _hash,
        parts: [LibraryPart(sizeBytes: 100, sha256: _hash), const LibraryPart(sizeBytes: 200)],
        directionOverride: BookDirection.rtl,
      );
      expect(LibraryEntry.fromJson(e.toJson()), e);
      expect(LibraryCatalogCodec.decode(LibraryCatalogCodec.encode([e, _entry()])), [e, _entry()]);
    });

    test('an unknown sourceKind is an error, not a silent default', () {
      expect(() => LibraryEntry.fromJson({'id': 'x', 'title': 't', 'sourceKind': 'pirate'}), throwsFormatException);
    });
  });

  group('licence gate', () {
    test('a well-formed entry passes', () {
      expect(gate.assess(_entry()).allowed, isTrue);
    });

    test('every allow-listed licence passes for a source that may carry it', () {
      for (final l in ['public-domain', 'cc0-1.0', 'cc-by-3.0', 'cc-by-4.0', 'cc-by-sa-3.0', 'cc-by-sa-4.0', 'CC-BY-4.0']) {
        expect(gate.assess(_entry(licence: l)).allowed, isTrue, reason: l);
      }
      expect(gate.assess(_entry(kind: LibrarySourceKind.gutenberg, licence: 'pg-license')).allowed, isTrue);
      expect(gate.assess(_entry(kind: LibrarySourceKind.kiwix, licence: 'gfdl-1.3')).allowed, isTrue);
    });

    test('a missing licence fails', () {
      expect(_codes(_entry(licence: '')), contains(ViolationCode.missingLicence));
      expect(_codes(_entry(licence: '   ')), contains(ViolationCode.missingLicence));
    });

    test('a licence that is not on the list fails', () {
      for (final l in ['cc-by-nc-4.0', 'cc-by-nd-4.0', 'all-rights-reserved', 'unknown', 'mit', 'gpl-3.0']) {
        expect(_codes(_entry(licence: l)), contains(ViolationCode.licenceNotAllowed), reason: l);
      }
    });

    test('source-restricted licences are refused for the wrong source', () {
      expect(_codes(_entry(kind: LibrarySourceKind.kiwix, licence: 'pg-license')), contains(ViolationCode.licenceNotAllowedForSource));
      expect(_codes(_entry(kind: LibrarySourceKind.gutenberg, licence: 'gfdl-1.3')), contains(ViolationCode.licenceNotAllowedForSource));
    });

    test('source, licence link and credit are all required', () {
      expect(_codes(_entry(sourceUrl: null)), contains(ViolationCode.missingSource));
      expect(_codes(_entry(sourceUrl: 'http://insecure.example/x')), contains(ViolationCode.missingSource));
      expect(_codes(_entry(licenceUrl: null)), contains(ViolationCode.missingLicenceUrl));
      expect(_codes(_entry(credit: ' ')), contains(ViolationCode.missingCredit));
    });

    test('a downloadable entry needs a size and a sha256', () {
      expect(_codes(_entry(size: 0)), contains(ViolationCode.missingSize));
      expect(_codes(_entry(sha: null)), contains(ViolationCode.missingChecksum));
      expect(_codes(_entry(sha: 'ABC')), contains(ViolationCode.missingChecksum));
    });

    test('declared parts must add up to the size', () {
      final bad = _entry(size: 300, parts: const [LibraryPart(sizeBytes: 100), LibraryPart(sizeBytes: 100)]);
      expect(_codes(bad), contains(ViolationCode.badPartLayout));
      final ok = _entry(size: 200, parts: const [LibraryPart(sizeBytes: 100), LibraryPart(sizeBytes: 100)]);
      expect(gate.assess(ok).allowed, isTrue);
    });

    test('a bundled book needs source, licence and credit but no checksum', () {
      expect(gate.assess(_entry(kind: LibrarySourceKind.bundled, size: 0, sha: null)).allowed, isTrue);
      expect(_codes(_entry(kind: LibrarySourceKind.bundled, licence: '')), contains(ViolationCode.missingLicence));
    });
  });

  group('catalogue', () {
    test('validateCatalog reports every violation and duplicate ids', () {
      final v = gate.validateCatalog([_entry(), _entry(), _entry(id: 'b2', licence: 'cc-by-nc-4.0')]);
      expect(v.map((x) => x.code), containsAll([ViolationCode.duplicateId, ViolationCode.licenceNotAllowed]));
    });

    test('a device-only PDF can never be part of a catalogue', () {
      const pdf = LibraryEntry(id: 'p', title: 'mine', sourceKind: LibrarySourceKind.localPdf);
      expect(gate.validateCatalog([pdf]).single.code, ViolationCode.localPdfInCatalogue);
    });

    test('assertCatalogCompliant fails the build with the full list', () {
      assertCatalogCompliant([_entry()]);
      expect(
        () => assertCatalogCompliant([_entry(licence: ''), _entry(id: 'b2', credit: '')]),
        throwsA(isA<CatalogLicenceException>().having((e) => e.violations.length, 'count', 2)),
      );
    });
  });

  group('local PDF is device-only', () {
    const pdf = LibraryEntry(id: 'p1', title: 'my.pdf', sourceKind: LibrarySourceKind.localPdf);

    test('allowed with no licence, but flagged device-only', () {
      final d = gate.assess(pdf);
      expect(d.allowed, isTrue);
      expect(d.deviceOnly, isTrue);
      expect(pdf.deviceOnly, isTrue);
    });

    test('the flag cannot be cleared by editing JSON', () {
      expect(LibraryEntry.fromJson(pdf.toJson()).deviceOnly, isTrue);
    });

    test('the export function refuses and never calls the transport', () async {
      var sent = 0;
      await expectLater(
        gate.exportToRemote(pdf, () async => sent++),
        throwsA(isA<DeviceOnlyException>()),
      );
      expect(sent, 0);
      expect(gate.canLeaveDevice(pdf), isFalse);
    });

    test('a catalogue book may be exported; exportable() drops device-only books', () async {
      final cat = _entry();
      expect(await gate.exportToRemote(cat, () async => 42), 42);
      expect(gate.exportable([pdf, cat]), [cat]);
    });
  });
}
