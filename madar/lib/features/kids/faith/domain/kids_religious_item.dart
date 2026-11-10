// The content contract for everything religious a child can reach.
//
// Nothing here (or anywhere in lib/features/kids/faith) contains religious
// text. A child sees such text only if it arrives as a [KidsReligiousItem]
// that (1) names its verified source, (2) carries a grading when it is a
// hadith, and (3) has been signed off by the owner's named reviewer with a
// date. [validateKidsReligiousItems] is run by a test over every bundled file
// and FAILS THE BUILD on a gap, and the loader drops any item that fails or is
// not approved, so a gap can never reach a screen either.
import 'package:meta/meta.dart';

import '../../../../core/quran/ayah.dart';
import 'kids_art.dart';

enum KidsReligiousKind {
  quran,
  prayerStep,
  wuduStep,
  story,
  manner,
  dhikr;

  static KidsReligiousKind? byName(String? name) {
    for (final k in values) {
      if (k.name == name) return k;
    }
    return null;
  }
}

/// The adhkar groups the screen knows how to show.
abstract final class KidsDhikrGroup {
  static const String morning = 'morning';
  static const String evening = 'evening';
  static const Set<String> all = {morning, evening};
}

@immutable
class KidsReligiousItem {
  const KidsReligiousItem({
    required this.id,
    required this.kind,
    required this.arabicText,
    required this.source,
    this.grading,
    this.isHadith = false,
    this.reviewer,
    this.reviewedOn,
    this.quranRef,
    this.group,
    this.order = 0,
    this.title,
    this.art = const [],
    this.repeat,
  });

  /// Stable, unique across all files.
  final String id;
  final KidsReligiousKind kind;
  final String arabicText;

  /// Where the text comes from: 'Tanzil Uthmani', 'Hisn al-Muslim p.12',
  /// 'Sahih Muslim #223' ... Required, never blank.
  final String source;

  /// sahih / hasan / ... Required when [isHadith] (or when [source] reads like
  /// a hadith book: see the validator).
  final String? grading;
  final bool isHadith;

  /// The sheikh's name. Null until he has signed the item off.
  final String? reviewer;
  final DateTime? reviewedOn;

  /// For [KidsReligiousKind.quran]: the ayah, so a test can check the text
  /// against the bundled Tanzil file instead of trusting typing.
  final AyahRef? quranRef;

  /// Story id, adhkar session ('morning' | 'evening'), manners category ...
  final String? group;

  /// Position inside its group / kind (steps, story pages, adhkar).
  final int order;

  /// Heading of the step / story / dhikr, when it has one.
  final String? title;

  /// Illustration, from the closed allow-list [KidsArt].
  final List<KidsArt> art;

  /// How many times a dhikr is said (the bead counter's total).
  final int? repeat;

  /// Shown to a child only when true.
  bool get approved => reviewer != null && reviewer!.trim().isNotEmpty && reviewedOn != null;

  /// Reads one JSON object. Throws [FormatException] on a shape it cannot
  /// understand (unknown kind, unknown art name, bad date). Missing source /
  /// grading / reviewer are NOT thrown here: they parse as absent and are
  /// reported by the validator, so one list of problems comes back.
  factory KidsReligiousItem.fromJson(Map<String, Object?> j) {
    final kind = KidsReligiousKind.byName(j['kind'] as String?);
    if (kind == null) throw FormatException('Unknown kind', j['kind']);
    final art = <KidsArt>[];
    for (final n in (j['art'] as List?) ?? const []) {
      final a = KidsArt.byName('$n');
      if (a == null) throw FormatException('Art "$n" is not on the allow-list', j['id']);
      art.add(a);
    }
    final reviewedOn = j['reviewedOn'] as String?;
    return KidsReligiousItem(
      id: (j['id'] as String?) ?? '',
      kind: kind,
      arabicText: (j['arabicText'] as String?) ?? '',
      source: (j['source'] as String?) ?? '',
      grading: j['grading'] as String?,
      isHadith: j['hadith'] == true,
      reviewer: j['reviewer'] as String?,
      reviewedOn: reviewedOn == null ? null : DateTime.parse(reviewedOn),
      quranRef: j['quranRef'] == null ? null : (AyahRef.tryParse('${j['quranRef']}') ?? (throw FormatException('Bad quranRef', j['quranRef']))),
      group: j['group'] as String?,
      order: (j['order'] as num?)?.toInt() ?? 0,
      title: j['title'] as String?,
      art: List.unmodifiable(art),
      repeat: (j['repeat'] as num?)?.toInt(),
    );
  }
}

/// One thing wrong with one item.
@immutable
class KidsContentProblem {
  const KidsContentProblem(this.itemId, this.message);
  final String itemId;
  final String message;

  @override
  String toString() => '$itemId: $message';
}

/// Source names that mean "this is a hadith" (so a grading is needed even if
/// nobody ticked `hadith`).
final RegExp _hadithSource = RegExp(
  r'sahih|bukhari|muslim|tirmidhi|abu dawud|abu daud|nasa|ibn majah|riyad|hadith|صحيح|البخاري|مسلم|الترمذي|أبي داود|أبو داود|النسائي|ابن ماجه|حديث',
  caseSensitive: false,
);

/// Everything wrong with [items], as a flat list (empty = fine).
List<KidsContentProblem> validateKidsReligiousItems(Iterable<KidsReligiousItem> items) {
  final problems = <KidsContentProblem>[];
  final seen = <String>{};
  for (final i in items) {
    final id = i.id.trim().isEmpty ? '(no id)' : i.id;
    void bad(String m) => problems.add(KidsContentProblem(id, m));

    if (i.id.trim().isEmpty) bad('missing id');
    if (!seen.add(i.id)) bad('duplicate id');
    if (i.arabicText.trim().isEmpty) bad('empty text');
    if (i.source.trim().isEmpty) bad('missing source');

    final graded = (i.grading ?? '').trim().isNotEmpty;
    if ((i.isHadith || _hadithSource.hasMatch(i.source)) && !graded) {
      bad('a hadith needs its grading (sahih / hasan ...)');
    }
    // Half a sign-off is a defect, not "unapproved": nobody can tell what
    // happened, so the build stops.
    final hasReviewer = (i.reviewer ?? '').trim().isNotEmpty;
    if (hasReviewer != (i.reviewedOn != null)) bad('reviewer and reviewedOn must be set together');

    if (i.kind == KidsReligiousKind.quran && i.quranRef == null) bad('a Quran item needs quranRef');
    if (i.kind == KidsReligiousKind.dhikr) {
      if (!KidsDhikrGroup.all.contains(i.group)) bad('a dhikr needs group morning or evening');
      if ((i.repeat ?? 0) < 1) bad('a dhikr needs repeat >= 1');
    }
    if (i.kind == KidsReligiousKind.story && (i.group ?? '').trim().isEmpty) bad('a story page needs its story group');
  }
  return problems;
}
