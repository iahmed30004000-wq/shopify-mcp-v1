import 'package:meta/meta.dart';

import '../../../core/quran/ayah.dart';
import 'reciters.dart';
import 'surah_ayah_counts.dart';

/// What a queue entry plays.
enum QueueItemKind {
  /// One recitation of an ayah.
  ayah,

  /// The basmala recited before ayah 1 of a surah (al-Fatihah's first ayah
  /// file, everyayah convention).
  basmala,

  /// Silence between repetitions (the "pause between repeats" option).
  gap,
}

/// One entry of a [RecitationQueue].
@immutable
class QueueItem {
  const QueueItem({
    required this.kind,
    required this.ayah,
    required this.ayahIndex,
    required this.group,
    this.ayahPass = 1,
    this.rangePass = 1,
    this.gap = Duration.zero,
  });

  final QueueItemKind kind;

  /// The ayah this entry belongs to: the recited ayah, the ayah a basmala
  /// opens, or the ayah a gap follows.
  final AyahRef ayah;

  /// 0-based position of [ayah] within the range.
  final int ayahIndex;

  /// Which of the ayah's repetitions this is (1-based; basmala = 1).
  final int ayahPass;

  /// Which pass over the whole range (1-based).
  final int rangePass;

  /// Index of the ayah's group (basmala + repetitions + gaps of one ayah in
  /// one pass) across the whole queue – what "next" and "previous" jump by.
  final int group;

  /// Length of a [QueueItemKind.gap].
  final Duration gap;

  bool get isAyah => kind == QueueItemKind.ayah;
  bool get isBasmala => kind == QueueItemKind.basmala;
  bool get isGap => kind == QueueItemKind.gap;

  /// The file this entry plays (null for a gap).
  AyahRef? get audioAyah => switch (kind) {
    QueueItemKind.ayah => ayah,
    QueueItemKind.basmala => EveryAyah.basmala,
    QueueItemKind.gap => null,
  };

  QueueItem _inPass(int pass, int groupsPerPass) => QueueItem(
    kind: kind,
    ayah: ayah,
    ayahIndex: ayahIndex,
    ayahPass: ayahPass,
    rangePass: pass,
    group: group + (pass - 1) * groupsPerPass,
    gap: gap,
  );

  @override
  bool operator ==(Object other) =>
      other is QueueItem &&
      other.kind == kind &&
      other.ayah == ayah &&
      other.ayahIndex == ayahIndex &&
      other.ayahPass == ayahPass &&
      other.rangePass == rangePass &&
      other.group == group &&
      other.gap == gap;

  @override
  int get hashCode => Object.hash(kind, ayah, ayahIndex, ayahPass, rangePass, group, gap);

  @override
  String toString() => switch (kind) {
    QueueItemKind.ayah => 'ayah($ayah #$ayahPass/r$rangePass)',
    QueueItemKind.basmala => 'basmala($ayah/r$rangePass)',
    QueueItemKind.gap => 'gap(${gap.inMilliseconds}ms after $ayah/r$rangePass)',
  };
}

/// The virtual play queue for a range: every pass is identical, so only one
/// pass is materialised and entries of later passes are derived on demand –
/// a whole-mushaf range repeated forever costs the same as one pass.
///
/// Rules (everyayah convention, as in the quran.com Android app): ayah 1 of
/// every surah except al-Fatihah and at-Tawbah is preceded by the basmala
/// (file 001001) in every range pass, never repeated with the ayah's own
/// repetitions; with a [gap], a silence follows every recitation of an ayah
/// except the very last entry of the queue.
@immutable
class RecitationQueue {
  const RecitationQueue._({
    required this.range,
    required this.repeatAyah,
    required this.repeatRange,
    required this.gap,
    required this.basmala,
    required this.ayatPerPass,
    required this._pass,
    required this._groupStarts,
  });

  /// Builds the queue for [range] (clamped to real ayat). [repeatAyah] and
  /// [repeatRange] are at least 1; [repeatRange] ≤ 0 loops until stopped.
  factory RecitationQueue.build(
    AyahRange range, {
    int repeatAyah = 1,
    int repeatRange = 1,
    Duration gap = Duration.zero,
    bool basmala = true,
  }) {
    final first = SurahMath.clamp(range.first);
    var last = SurahMath.clamp(range.last);
    if (last < first) last = first;
    final perAyah = repeatAyah < 1 ? 1 : repeatAyah;
    final withGap = gap > Duration.zero;
    final pass = <QueueItem>[];
    final starts = <int>[];
    var index = 0;
    for (final ayah in SurahMath.ayatIn(AyahRange(first, last))) {
      final group = index;
      starts.add(pass.length);
      if (basmala && ayah.ayah == 1 && EveryAyah.surahNeedsBasmala(ayah.surah)) {
        pass.add(QueueItem(kind: QueueItemKind.basmala, ayah: ayah, ayahIndex: index, group: group));
      }
      for (var p = 1; p <= perAyah; p++) {
        pass.add(QueueItem(kind: QueueItemKind.ayah, ayah: ayah, ayahIndex: index, ayahPass: p, group: group));
        if (withGap) {
          pass.add(
            QueueItem(kind: QueueItemKind.gap, ayah: ayah, ayahIndex: index, ayahPass: p, group: group, gap: gap),
          );
        }
      }
      index++;
    }
    return RecitationQueue._(
      range: AyahRange(first, last),
      repeatAyah: perAyah,
      repeatRange: repeatRange < 1 ? 0 : repeatRange,
      gap: withGap ? gap : Duration.zero,
      basmala: basmala,
      pass: List.unmodifiable(pass),
      groupStarts: List.unmodifiable(starts),
      ayatPerPass: index,
    );
  }

  final AyahRange range;
  final int repeatAyah;

  /// Passes over the range; 0 = until stopped.
  final int repeatRange;
  final Duration gap;
  final bool basmala;
  final int ayatPerPass;
  final List<QueueItem> _pass;
  final List<int> _groupStarts;

  bool get loops => repeatRange == 0;

  /// Entries in one pass.
  int get passLength => _pass.length;

  /// Entries in the whole queue; null when it [loops].
  int? get length {
    if (loops) return null;
    // The last pass drops its trailing gap.
    final trailingGap = _pass.isNotEmpty && _pass.last.isGap ? 1 : 0;
    return passLength * repeatRange - trailingGap;
  }

  /// Whether [index] is inside the queue.
  bool contains(int index) {
    if (index < 0) return false;
    final n = length;
    return n == null || index < n;
  }

  /// The entry at [index] (0-based across passes).
  QueueItem itemAt(int index) {
    assert(contains(index), 'index $index outside the queue');
    final pass = index ~/ passLength + 1;
    return _pass[index % passLength]._inPass(pass, ayatPerPass);
  }

  /// Entries [start] ≤ i < [end] (clamped to the queue).
  List<QueueItem> slice(int start, int end) {
    final n = length;
    final stop = n == null ? end : (end < n ? end : n);
    return [for (var i = start; i < stop; i++) itemAt(i)];
  }

  /// Index of the first entry of [group] (its basmala, if any).
  int startOfGroup(int group) {
    final pass = group ~/ ayatPerPass;
    return pass * passLength + _groupStarts[group % ayatPerPass];
  }

  /// Start of the next ayah's group after the entry at [index]; null at the
  /// end of the queue.
  int? nextAyahStart(int index) {
    final start = startOfGroup(itemAt(index).group + 1);
    return contains(start) ? start : null;
  }

  /// Start of the group before the entry at [index]'s; null in the first.
  int? previousAyahStart(int index) {
    final group = itemAt(index).group;
    return group == 0 ? null : startOfGroup(group - 1);
  }

  /// Start of the entry at [index]'s own group.
  int groupStartOf(int index) => startOfGroup(itemAt(index).group);

  /// First entry of [ayah] in [rangePass] (its basmala, if any); null when
  /// the ayah is not in the range.
  int? indexOfAyah(AyahRef ayah, {int rangePass = 1}) {
    if (!range.contains(ayah)) return null;
    final group = SurahMath.ordinal(ayah) - SurahMath.ordinal(range.first);
    final index = startOfGroup(group + (rangePass - 1) * ayatPerPass);
    return contains(index) ? index : null;
  }

  /// Fraction of one pass done at the start of the entry at [index] plus
  /// [within] (0..1) of that entry's ayah – drives progress rings.
  double passProgress(int index, {double within = 0}) {
    if (ayatPerPass == 0) return 0;
    final item = itemAt(index);
    final ofAyah = switch (item.kind) {
      QueueItemKind.basmala => 0.0,
      QueueItemKind.ayah => ((item.ayahPass - 1) + within.clamp(0.0, 1.0)) / repeatAyah,
      QueueItemKind.gap => item.ayahPass / repeatAyah,
    };
    final done = item.ayahIndex + ofAyah;
    return (done / ayatPerPass).clamp(0.0, 1.0);
  }
}
