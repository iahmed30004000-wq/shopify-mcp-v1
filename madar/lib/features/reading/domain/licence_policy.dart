/// The licence rule of the reading planet, as code (Part 17: "no pirated book,
/// ever - a build-time rule, not a promise").
///
/// * An explicit ALLOW-LIST of licences. Anything not on it is rejected; there
///   is no "unknown but probably fine".
/// * Every catalogue entry carries source + licence + licence link + credit.
/// * A PDF he adds himself (`localPdf`) needs no licence, but it is
///   `deviceOnly`: it can never be uploaded or exported to a remote.
library;

import 'package:meta/meta.dart';

import 'library_entry.dart';

/// One licence on the allow-list.
@immutable
final class AllowedLicence {
  const AllowedLicence(this.id, this.name, {this.onlyFor});

  final String id;
  final String name;

  /// When set, the licence is accepted only for these sources. The Project
  /// Gutenberg licence covers Gutenberg's own US-public-domain texts, and
  /// GFDL is accepted only where Wikimedia dual-licenses its text.
  final Set<LibrarySourceKind>? onlyFor;
}

/// The licences Madar accepts. Ids are SPDX-style and compared lowercase.
@immutable
final class LicencePolicy {
  const LicencePolicy(this.allowed);

  /// The standing policy. Changing this list is a deliberate, reviewed act.
  static const LicencePolicy standard = LicencePolicy([
    AllowedLicence('public-domain', 'Public domain'),
    AllowedLicence('cc0-1.0', 'CC0 1.0'),
    AllowedLicence('cc-by-3.0', 'CC BY 3.0'),
    AllowedLicence('cc-by-4.0', 'CC BY 4.0'),
    AllowedLicence('cc-by-sa-3.0', 'CC BY-SA 3.0'),
    AllowedLicence('cc-by-sa-4.0', 'CC BY-SA 4.0'),
    AllowedLicence(
      'pg-license',
      'Project Gutenberg licence (US public domain)',
      onlyFor: {LibrarySourceKind.gutenberg},
    ),
    AllowedLicence(
      'gfdl-1.3',
      'GFDL 1.3 (Wikimedia dual licence)',
      onlyFor: {LibrarySourceKind.wikisource, LibrarySourceKind.kiwix},
    ),
  ]);

  final List<AllowedLicence> allowed;

  static String normalise(String id) => id.trim().toLowerCase();

  AllowedLicence? find(String id) {
    final n = normalise(id);
    for (final l in allowed) {
      if (l.id == n) return l;
    }
    return null;
  }
}

enum ViolationCode {
  duplicateId,
  missingTitle,
  missingSource,
  missingLicence,
  licenceNotAllowed,
  licenceNotAllowedForSource,
  missingLicenceUrl,
  missingCredit,
  missingSize,
  missingChecksum,
  badPartLayout,
  localPdfInCatalogue,
}

@immutable
final class LicenceViolation {
  const LicenceViolation(this.entryId, this.code, this.detail);

  final String entryId;
  final ViolationCode code;

  /// Developer-facing: shown in the failing build, never to the user.
  final String detail;

  @override
  String toString() => '$entryId: ${code.name} ($detail)';
}

/// What the gate says about ONE entry.
@immutable
final class GateDecision {
  const GateDecision({required this.violations, required this.deviceOnly});

  final List<LicenceViolation> violations;
  final bool deviceOnly;

  bool get allowed => violations.isEmpty;
}

/// Thrown by [LicenceGate.exportToRemote] for a device-only book.
final class DeviceOnlyException implements Exception {
  const DeviceOnlyException(this.entryId);

  final String entryId;

  @override
  String toString() => 'DeviceOnlyException: "$entryId" was added from this phone and never leaves it';
}

/// Thrown by [assertCatalogCompliant]; lists every violation at once.
final class CatalogLicenceException implements Exception {
  const CatalogLicenceException(this.violations);

  final List<LicenceViolation> violations;

  @override
  String toString() => 'Catalogue breaks the licence rule:\n${violations.map((v) => '  - $v').join('\n')}';
}

final RegExp _sha256Hex = RegExp(r'^[0-9a-f]{64}$');

final class LicenceGate {
  const LicenceGate({this.policy = LicencePolicy.standard});

  final LicencePolicy policy;

  /// Checks one entry. A `localPdf` is allowed without a licence and comes
  /// back `deviceOnly`; every other kind must carry the full proof.
  GateDecision assess(LibraryEntry e) {
    if (e.sourceKind == LibrarySourceKind.localPdf) {
      return GateDecision(violations: _title(e), deviceOnly: true);
    }
    final v = <LicenceViolation>[..._title(e)];
    void add(ViolationCode c, String d) => v.add(LicenceViolation(e.id, c, d));

    if (!_isHttps(e.sourceUrl)) add(ViolationCode.missingSource, 'sourceUrl must be an https link');
    if (e.licenceId.trim().isEmpty) {
      add(ViolationCode.missingLicence, 'no licenceId');
    } else {
      final lic = policy.find(e.licenceId);
      if (lic == null) {
        add(ViolationCode.licenceNotAllowed, '"${e.licenceId}" is not on the allow-list');
      } else if (lic.onlyFor != null && !lic.onlyFor!.contains(e.sourceKind)) {
        add(ViolationCode.licenceNotAllowedForSource, '"${lic.id}" is not accepted for ${e.sourceKind.name}');
      }
    }
    if (!_isHttps(e.licenceUrl)) add(ViolationCode.missingLicenceUrl, 'licenceUrl must be an https link');
    if (e.credit.trim().isEmpty) add(ViolationCode.missingCredit, 'no credit line');

    if (e.sourceKind.isDownloadable) {
      if (e.sizeBytes <= 0) add(ViolationCode.missingSize, 'sizeBytes must be known before download');
      if (e.sha256 == null || !_sha256Hex.hasMatch(e.sha256!)) {
        add(ViolationCode.missingChecksum, 'sha256 must be 64 lowercase hex characters');
      }
      if (e.parts.isNotEmpty) {
        final sum = e.parts.fold<int>(0, (a, p) => a + p.sizeBytes);
        if (e.parts.any((p) => p.sizeBytes <= 0) || sum != e.sizeBytes) {
          add(ViolationCode.badPartLayout, 'parts must be positive and add up to sizeBytes ($sum != ${e.sizeBytes})');
        }
        if (e.parts.any((p) => p.sha256 != null && !_sha256Hex.hasMatch(p.sha256!))) {
          add(ViolationCode.badPartLayout, 'a part sha256 is malformed');
        }
      }
    }
    return GateDecision(violations: v, deviceOnly: false);
  }

  List<LicenceViolation> _title(LibraryEntry e) =>
      e.title.trim().isEmpty ? [LicenceViolation(e.id, ViolationCode.missingTitle, 'no title')] : const [];

  /// Every violation of a whole catalogue (bundled or downloadable). A
  /// `localPdf` can never be part of a catalogue: it has no licence to ship.
  List<LicenceViolation> validateCatalog(List<LibraryEntry> entries) {
    final out = <LicenceViolation>[];
    final seen = <String>{};
    for (final e in entries) {
      if (!seen.add(e.id)) out.add(LicenceViolation(e.id, ViolationCode.duplicateId, 'id used twice'));
      if (e.sourceKind == LibrarySourceKind.localPdf) {
        out.add(LicenceViolation(e.id, ViolationCode.localPdfInCatalogue, 'a device-only PDF cannot be catalogued'));
        continue;
      }
      out.addAll(assess(e).violations);
    }
    return out;
  }

  /// Whether the book may leave the phone for a remote (upload, cloud backup,
  /// a share link). A device-only book never may.
  bool canLeaveDevice(LibraryEntry e) => !e.deviceOnly;

  /// The entries that may be put in an export or a backup.
  List<LibraryEntry> exportable(Iterable<LibraryEntry> entries) => [
    for (final e in entries)
      if (canLeaveDevice(e)) e,
  ];

  /// The ONLY door to a remote: [transport] runs only for a book that may
  /// leave the phone. For a device-only book it is never called.
  Future<T> exportToRemote<T>(LibraryEntry e, Future<T> Function() transport) async {
    if (!canLeaveDevice(e)) throw DeviceOnlyException(e.id);
    return transport();
  }
}

/// The function the integrator calls from a build-failing test over the
/// bundled / downloadable catalogue: throws with the full list of violations.
void assertCatalogCompliant(List<LibraryEntry> entries, {LicenceGate gate = const LicenceGate()}) {
  final violations = gate.validateCatalog(entries);
  if (violations.isNotEmpty) throw CatalogLicenceException(violations);
}

bool _isHttps(String? url) {
  if (url == null) return false;
  final u = Uri.tryParse(url.trim());
  return u != null && u.scheme == 'https' && u.host.isNotEmpty;
}
