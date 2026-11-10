import 'package:meta/meta.dart';

/// The rule families a reader learns first; each has one colour family.
enum TajweedFamily {
  /// Written but not pronounced (hamzat al-wasl, lam shamsiyyah, silent letters).
  silent,

  /// Prolongation (madd) – natural to necessary.
  madd,

  /// Nasalisation (ghunnah, ikhfa, idgham with ghunnah, iqlab).
  ghunnah,

  /// Merging without ghunnah (idgham without ghunnah, mutajanisayn, mutaqaribayn).
  merge,

  /// Echoing stop (qalqalah).
  qalqalah,
}

/// Tajweed rules, as annotated by the bundled data (cpfair/quran-tajweed)
/// and as marked up by the Quran.com API (`text_uthmani_tajweed`).
enum TajweedRule {
  hamzatWasl('w', TajweedFamily.silent, ['ham_wasl', 'hamzat_wasl']),
  lamShamsiyyah('l', TajweedFamily.silent, ['laam_shamsiyah', 'lam_shamsiyyah']),
  silent('s', TajweedFamily.silent, ['slnt', 'silent']),

  /// Madd tabi'i, 2 counts.
  maddNatural('a', TajweedFamily.madd, ['madda_normal', 'madd_2']),

  /// Madd 'arid / leen, 2–4–6 counts (Quran.com's "permissible").
  maddPermissible('b', TajweedFamily.madd, ['madda_permissible', 'madd_246']),

  /// Madd jaiz munfasil, 4–5 counts.
  maddSeparated('c', TajweedFamily.madd, ['madd_munfasil']),

  /// Madd wajib muttasil, 4–5 counts (Quran.com's "obligatory").
  maddConnected('d', TajweedFamily.madd, ['madda_obligatory', 'madd_muttasil']),

  /// Madd lazim, 6 counts.
  maddNecessary('e', TajweedFamily.madd, ['madda_necessary', 'madd_6']),
  qalqalah('q', TajweedFamily.qalqalah, ['qalaqah', 'qalqalah', 'qlq']),
  ghunnah('g', TajweedFamily.ghunnah, ['ghunnah']),
  ikhfa('i', TajweedFamily.ghunnah, ['ikhafa', 'ikhfa']),
  ikhfaShafawi('f', TajweedFamily.ghunnah, ['ikhafa_shafawi', 'ikhfa_shafawi']),
  iqlab('p', TajweedFamily.ghunnah, ['iqlab']),
  idghamGhunnah('n', TajweedFamily.ghunnah, ['idgham_ghunnah', 'idghaam_ghunnah']),
  idghamShafawi('h', TajweedFamily.ghunnah, ['idgham_shafawi', 'idghaam_shafawi']),
  idghamNoGhunnah('o', TajweedFamily.merge, ['idgham_wo_ghunnah', 'idghaam_no_ghunnah']),
  idghamMutajanisayn('j', TajweedFamily.merge, ['idgham_mutajanisayn', 'idghaam_mutajanisayn']),
  idghamMutaqaribayn('k', TajweedFamily.merge, ['idgham_mutaqaribayn', 'idghaam_mutaqaribayn']);

  const TajweedRule(this.code, this.family, this.aliases);

  /// One-letter code in assets/quran/quran-tajweed.txt.
  final String code;
  final TajweedFamily family;

  /// Class names used by Quran.com markup and the bundled source data.
  final List<String> aliases;

  static final Map<String, TajweedRule> _byCode = {for (final r in values) r.code: r};
  static final Map<String, TajweedRule> _byAlias = {
    for (final r in values)
      for (final a in r.aliases) a: r,
  };

  static TajweedRule? fromCode(String code) => _byCode[code];

  /// A Quran.com / source class name (`ham_wasl`, `madda_normal` …); null
  /// for anything else (e.g. `end`).
  static TajweedRule? fromClass(String name) => _byAlias[name.trim().toLowerCase()];
}

/// One annotation: [rule] applies to code units [start, end) of a text.
@immutable
class TajweedMark {
  const TajweedMark(this.rule, this.start, this.end) : assert(start < end);

  final TajweedRule rule;
  final int start;
  final int end;

  int get length => end - start;

  TajweedMark shift(int by) => TajweedMark(rule, start + by, end + by);

  @override
  bool operator ==(Object other) =>
      other is TajweedMark && other.rule == rule && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(rule, start, end);

  @override
  String toString() => '${rule.name}[$start,$end)';
}

/// A stretch of text in one style: plain ([rule] null) or one tajweed rule.
@immutable
class TajweedRun {
  const TajweedRun(this.start, this.end, this.rule);

  final int start;
  final int end;
  final TajweedRule? rule;

  @override
  bool operator ==(Object other) =>
      other is TajweedRun && other.rule == rule && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(rule, start, end);

  @override
  String toString() => '${rule?.name ?? 'plain'}[$start,$end)';
}

/// Text plus its tajweed marks (a parsed Quran.com verse).
@immutable
class TajweedText {
  const TajweedText(this.text, this.marks);

  final String text;
  final List<TajweedMark> marks;
}

abstract final class Tajweed {
  /// Decodes one line's annotations from quran-tajweed.txt:
  /// `w7.8 l16.17 a24.26` → marks. Unknown codes are skipped.
  static List<TajweedMark> decode(String encoded) {
    if (encoded.isEmpty) return const [];
    final out = <TajweedMark>[];
    for (final token in encoded.split(' ')) {
      if (token.length < 4) continue;
      final rule = TajweedRule.fromCode(token[0]);
      final dot = token.indexOf('.');
      if (rule == null || dot < 0) continue;
      final start = int.tryParse(token.substring(1, dot));
      final end = int.tryParse(token.substring(dot + 1));
      if (start == null || end == null || end <= start) continue;
      out.add(TajweedMark(rule, start, end));
    }
    return out;
  }

  /// Marks falling inside [from, to) of a text, re-based to [from] (used to
  /// split the basmala off ayah 1). Marks straddling the cut are clipped.
  static List<TajweedMark> slice(List<TajweedMark> marks, int from, int to) => [
    for (final m in marks)
      if (m.end > from && m.start < to)
        TajweedMark(m.rule, (m.start < from ? from : m.start) - from, (m.end > to ? to : m.end) - from),
  ];

  /// Splits a text of [length] code units into runs, each plain or under
  /// exactly one rule. Where marks overlap the shorter (more specific) one
  /// wins; runs of the same rule merge. Out-of-range marks are clipped.
  static List<TajweedRun> runs(int length, List<TajweedMark> marks) {
    if (length <= 0) return const [];
    if (marks.isEmpty) return [TajweedRun(0, length, null)];
    final owner = List<TajweedMark?>.filled(length, null);
    for (final m in marks) {
      final s = m.start < 0 ? 0 : m.start;
      final e = m.end > length ? length : m.end;
      for (var i = s; i < e; i++) {
        final current = owner[i];
        if (current == null || m.length < current.length || (m.length == current.length && m.start >= current.start)) {
          owner[i] = m;
        }
      }
    }
    final out = <TajweedRun>[];
    var start = 0;
    TajweedRule? rule = owner[0]?.rule;
    for (var i = 1; i <= length; i++) {
      final r = i < length ? owner[i]?.rule : null;
      if (i == length || r != rule) {
        out.add(TajweedRun(start, i, rule));
        start = i;
        rule = r;
      }
    }
    return out;
  }

  static final RegExp _tag = RegExp(r'<(/?)([a-zA-Z][a-zA-Z0-9_-]*)([^>]*)>');
  static final RegExp _class = RegExp('''class\\s*=\\s*(?:"([^"]*)"|'([^']*)'|([^\\s>]+))''');

  /// Parses Quran.com's `text_uthmani_tajweed` markup, e.g.
  /// `بِسْمِ <tajweed class=ham_wasl>ٱ</tajweed>للَّهِ … <span class=end>١</span>`,
  /// into plain text and marks. The trailing ayah-number span is dropped;
  /// unknown tags keep their text unmarked; entities are decoded; nested
  /// rules resolve to the innermost one.
  static TajweedText parseQuranCom(String markup) {
    final text = StringBuffer();
    final marks = <TajweedMark>[];
    // Open elements: (tag, rule or null, start offset, skip content).
    final stack = <(String, TajweedRule?, int, bool)>[];
    var skipDepth = 0;
    var pos = 0;
    for (final m in _tag.allMatches(markup)) {
      if (m.start > pos && skipDepth == 0) text.write(_decodeEntities(markup.substring(pos, m.start)));
      pos = m.end;
      final closing = m.group(1) == '/';
      final tag = m.group(2)!.toLowerCase();
      final attrs = m.group(3) ?? '';
      if (!closing) {
        final selfClosing = attrs.trimRight().endsWith('/') || tag == 'br';
        if (selfClosing) continue;
        final cls = _class.firstMatch(attrs);
        final className = cls == null ? '' : (cls.group(1) ?? cls.group(2) ?? cls.group(3) ?? '');
        final isEnd = tag == 'span' && className.split(RegExp(r'\s+')).contains('end');
        final isFootnote = tag == 'sup';
        final skip = isEnd || isFootnote;
        if (skip) skipDepth++;
        final rule = tag == 'tajweed' || tag == 'span' ? TajweedRule.fromClass(className.split(' ').first) : null;
        stack.add((tag, rule, text.length, skip));
      } else {
        final i = stack.lastIndexWhere((e) => e.$1 == tag);
        if (i < 0) continue;
        final open = stack[i];
        stack.removeRange(i, stack.length);
        if (open.$4) {
          skipDepth--;
          continue;
        }
        if (open.$2 != null && text.length > open.$3) marks.add(TajweedMark(open.$2!, open.$3, text.length));
      }
    }
    if (pos < markup.length && skipDepth == 0) text.write(_decodeEntities(markup.substring(pos)));
    var plain = text.toString();
    // Trim the space that preceded the dropped ayah number.
    final trimmed = plain.trimRight();
    if (trimmed.length != plain.length) plain = trimmed;
    final valid = [
      for (final m in marks)
        if (m.start < plain.length) TajweedMark(m.rule, m.start, m.end > plain.length ? plain.length : m.end),
    ]..sort((a, b) => a.start.compareTo(b.start));
    return TajweedText(plain, valid);
  }

  /// Strips all markup (footnote markers and the ayah-number span dropped).
  static String stripMarkup(String markup) => parseQuranCom(markup).text;

  static final RegExp _entity = RegExp(r'&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);');

  static String _decodeEntities(String s) {
    if (!s.contains('&')) return s;
    return s.replaceAllMapped(_entity, (m) {
      final e = m.group(1)!;
      if (e.startsWith('#x')) return String.fromCharCode(int.parse(e.substring(2), radix: 16));
      if (e.startsWith('#')) return String.fromCharCode(int.parse(e.substring(1)));
      return switch (e) {
        'amp' => '&',
        'lt' => '<',
        'gt' => '>',
        'quot' => '"',
        'apos' => "'",
        'nbsp' => ' ',
        _ => m.group(0)!,
      };
    });
  }
}
