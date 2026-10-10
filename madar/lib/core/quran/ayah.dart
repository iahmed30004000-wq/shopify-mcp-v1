import 'package:meta/meta.dart';

/// One ayah of the Quran: surah 1–114, ayah number within the surah.
@immutable
class AyahRef implements Comparable<AyahRef> {
  const AyahRef(this.surah, this.ayah) : assert(surah >= 1 && surah <= 114), assert(ayah >= 1);

  final int surah;
  final int ayah;

  /// `2:255`.
  @override
  String toString() => '$surah:$ayah';

  /// Parses `2:255`; null when malformed.
  static AyahRef? tryParse(String s) {
    final parts = s.split(':');
    if (parts.length != 2) return null;
    final surah = int.tryParse(parts[0]);
    final ayah = int.tryParse(parts[1]);
    if (surah == null || ayah == null || surah < 1 || surah > 114 || ayah < 1) return null;
    return AyahRef(surah, ayah);
  }

  /// Six-digit key used by per-ayah audio files: `002255`.
  String get fileKey => '${surah.toString().padLeft(3, '0')}${ayah.toString().padLeft(3, '0')}';

  @override
  int compareTo(AyahRef other) => surah != other.surah ? surah.compareTo(other.surah) : ayah.compareTo(other.ayah);

  bool operator <(AyahRef other) => compareTo(other) < 0;
  bool operator <=(AyahRef other) => compareTo(other) <= 0;
  bool operator >(AyahRef other) => compareTo(other) > 0;
  bool operator >=(AyahRef other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) => other is AyahRef && other.surah == surah && other.ayah == ayah;

  @override
  int get hashCode => Object.hash(surah, ayah);
}

/// An inclusive range of ayat, possibly spanning surahs (`first <= last`).
@immutable
class AyahRange {
  const AyahRange(this.first, this.last);

  /// A single ayah.
  const AyahRange.single(AyahRef ayah) : first = ayah, last = ayah;

  final AyahRef first;
  final AyahRef last;

  bool contains(AyahRef ayah) => ayah >= first && ayah <= last;

  @override
  String toString() => first == last ? '$first' : '$first-$last';

  @override
  bool operator ==(Object other) => other is AyahRange && other.first == first && other.last == last;

  @override
  int get hashCode => Object.hash(first, last);
}
