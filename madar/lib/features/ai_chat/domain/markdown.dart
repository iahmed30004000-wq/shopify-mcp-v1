/// A small, safe Markdown parser for AI replies: headings, paragraphs,
/// bold / italic / strikethrough, inline code and code blocks, bullet and
/// numbered lists (nested), quotes, rules, simple tables and links.
///
/// Safe by construction: no HTML is interpreted (it stays literal text),
/// images are never loaded (`![alt](url)` becomes a link labelled alt), and
/// the parser tolerates the half-finished text of a streaming reply
/// (unclosed markers stay literal, an unclosed fence runs to the end).
/// Pure Dart.
library;

import 'package:meta/meta.dart';

/// A run of inline text with its styles.
@immutable
class MdSpan {
  const MdSpan(this.text, {this.bold = false, this.italic = false, this.code = false, this.strike = false, this.link});

  final String text;
  final bool bold;
  final bool italic;
  final bool code;
  final bool strike;

  /// Target of a link (as written; checked before opening).
  final String? link;

  MdSpan styled({bool bold = false, bool italic = false, bool strike = false, String? link}) => MdSpan(
    text,
    bold: this.bold || bold,
    italic: this.italic || italic,
    code: code,
    strike: this.strike || strike,
    link: this.link ?? link,
  );

  @override
  bool operator ==(Object other) =>
      other is MdSpan &&
      other.text == text &&
      other.bold == bold &&
      other.italic == italic &&
      other.code == code &&
      other.strike == strike &&
      other.link == link;

  @override
  int get hashCode => Object.hash(text, bold, italic, code, strike, link);

  @override
  String toString() {
    final f = [if (bold) 'b', if (italic) 'i', if (code) 'c', if (strike) 's', if (link != null) 'link=$link'];
    return f.isEmpty ? 'MdSpan("$text")' : 'MdSpan("$text", ${f.join(',')})';
  }
}

/// Plain text of [spans].
String mdPlain(List<MdSpan> spans) => spans.map((s) => s.text).join();

@immutable
sealed class MdBlock {
  const MdBlock();
}

final class MdHeading extends MdBlock {
  const MdHeading(this.level, this.spans);
  final int level;
  final List<MdSpan> spans;
}

final class MdParagraph extends MdBlock {
  const MdParagraph(this.spans);
  final List<MdSpan> spans;
}

final class MdCodeBlock extends MdBlock {
  const MdCodeBlock(this.code, {this.language});
  final String code;
  final String? language;
}

final class MdQuote extends MdBlock {
  const MdQuote(this.children);
  final List<MdBlock> children;
}

final class MdRule extends MdBlock {
  const MdRule();
}

final class MdListItem {
  const MdListItem(this.spans, {this.children = const [], this.number});
  final List<MdSpan> spans;

  /// Nested lists.
  final List<MdList> children;

  /// The number of an ordered item.
  final int? number;
}

final class MdList extends MdBlock {
  const MdList(this.items, {required this.ordered});
  final List<MdListItem> items;
  final bool ordered;
}

enum MdAlign { start, center, end }

final class MdTable extends MdBlock {
  const MdTable(this.header, this.rows, this.aligns);
  final List<List<MdSpan>> header;
  final List<List<List<MdSpan>>> rows;
  final List<MdAlign> aligns;
}

/// Parses Markdown into blocks.
abstract final class MdParser {
  static const int _maxDepth = 4;

  static final RegExp _fence = RegExp(r'^ {0,3}(`{3,}|~{3,})\s*([^`\s]*)');
  static final RegExp _heading = RegExp(r'^ {0,3}(#{1,6})(?:\s+(.*?))?\s*#*\s*$');
  static final RegExp _rule = RegExp(r'^ {0,3}([-*_])(?:\s*\1){2,}\s*$');
  static final RegExp _quote = RegExp(r'^ {0,3}>\s?(.*)$');
  static final RegExp _item = RegExp(r'^(\s*)([-*+•]|\d{1,9}[.)])\s+(.*)$');
  static final RegExp _tableSep = RegExp(r'^\s*\|?\s*:?-{2,}:?\s*(\|\s*:?-{2,}:?\s*)*\|?\s*$');

  static List<MdBlock> parse(String source) => _blocks(source.replaceAll('\r\n', '\n').split('\n'), 0);

  /// The text of [source] without Markdown syntax, blocks joined by a space
  /// (for one-line previews).
  static String plainText(String source) {
    final parts = <String>[];
    void add(MdBlock b) {
      switch (b) {
        case MdParagraph(:final spans) || MdHeading(:final spans):
          parts.add(mdPlain(spans));
        case MdCodeBlock(:final code):
          parts.add(code);
        case MdQuote(:final children):
          children.forEach(add);
        case MdList(:final items):
          void item(MdListItem i) {
            parts.add(mdPlain(i.spans));
            for (final c in i.children) {
              c.items.forEach(item);
            }
          }
          items.forEach(item);
        case MdTable(:final header, :final rows):
          parts.add(
            [
              for (final c in header) mdPlain(c),
              for (final r in rows)
                for (final c in r) mdPlain(c),
            ].join(' '),
          );
        case MdRule():
          break;
      }
    }

    parse(source).forEach(add);
    return parts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static List<MdBlock> _blocks(List<String> lines, int depth) {
    final out = <MdBlock>[];
    final para = <String>[];
    void flush() {
      if (para.isEmpty) return;
      out.add(MdParagraph(MdInline.parse(para.join('\n').trim())));
      para.clear();
    }

    var i = 0;
    while (i < lines.length) {
      final line = lines[i];
      if (line.trim().isEmpty) {
        flush();
        i++;
        continue;
      }
      final fence = _fence.firstMatch(line);
      if (fence != null) {
        flush();
        final marker = fence[1]!;
        final lang = fence[2]!.isEmpty ? null : fence[2];
        final body = <String>[];
        i++;
        while (i < lines.length) {
          final t = lines[i].trimLeft();
          if (t.startsWith(marker[0] * marker.length) && t.replaceAll(marker[0], '').trim().isEmpty) {
            i++;
            break;
          }
          body.add(lines[i]);
          i++;
        }
        out.add(MdCodeBlock(body.join('\n'), language: lang));
        continue;
      }
      final heading = _heading.firstMatch(line);
      if (heading != null) {
        flush();
        out.add(MdHeading(heading[1]!.length, MdInline.parse((heading[2] ?? '').trim())));
        i++;
        continue;
      }
      if (_rule.hasMatch(line)) {
        flush();
        out.add(const MdRule());
        i++;
        continue;
      }
      if (_quote.hasMatch(line)) {
        flush();
        final body = <String>[];
        while (i < lines.length && lines[i].trim().isNotEmpty) {
          final q = _quote.firstMatch(lines[i]);
          body.add(q != null ? q[1]! : lines[i]);
          i++;
        }
        out.add(depth >= _maxDepth ? MdParagraph(MdInline.parse(body.join('\n'))) : MdQuote(_blocks(body, depth + 1)));
        continue;
      }
      if (_item.hasMatch(line) && !(para.isNotEmpty && _isOrderedNotOne(line))) {
        flush();
        final (lists, next) = _list(lines, i);
        out.addAll(lists);
        i = next;
        continue;
      }
      if (line.contains('|') && i + 1 < lines.length && _tableSep.hasMatch(lines[i + 1]) && para.isEmpty) {
        final header = _cells(line);
        final aligns = [
          for (final c in _cells(lines[i + 1]))
            c.startsWith(':') && c.endsWith(':')
                ? MdAlign.center
                : c.endsWith(':')
                ? MdAlign.end
                : MdAlign.start,
        ];
        if (header.isNotEmpty) {
          i += 2;
          final rows = <List<List<MdSpan>>>[];
          while (i < lines.length && lines[i].contains('|') && lines[i].trim().isNotEmpty) {
            rows.add([for (final c in _cells(lines[i])) MdInline.parse(c)]);
            i++;
          }
          out.add(MdTable([for (final c in header) MdInline.parse(c)], rows, aligns));
          continue;
        }
      }
      para.add(line);
      i++;
    }
    flush();
    return out;
  }

  /// A numbered line inside a paragraph only starts a list at "1."
  /// (so "in 2024. we…" wrapping onto a new line stays text).
  static bool _isOrderedNotOne(String line) {
    final m = _item.firstMatch(line)!;
    final marker = m[2]!;
    return RegExp(r'^\d').hasMatch(marker) && !marker.startsWith('1');
  }

  static List<String> _cells(String row) {
    var t = row.trim();
    if (t.startsWith('|')) t = t.substring(1);
    if (t.endsWith('|') && !t.endsWith(r'\|')) t = t.substring(0, t.length - 1);
    final cells = <String>[];
    final b = StringBuffer();
    for (var k = 0; k < t.length; k++) {
      final c = t[k];
      if (c == r'\' && k + 1 < t.length && t[k + 1] == '|') {
        b.write('|');
        k++;
      } else if (c == '|') {
        cells.add(b.toString().trim());
        b.clear();
      } else {
        b.write(c);
      }
    }
    cells.add(b.toString().trim());
    return cells;
  }

  static int _indentOf(String s) {
    var n = 0;
    for (final c in s.codeUnits) {
      if (c == 0x20) {
        n++;
      } else if (c == 0x09) {
        n += 4;
      } else {
        break;
      }
    }
    return n;
  }

  /// Parses a (possibly nested) list starting at [start].
  static (List<MdList>, int) _list(List<String> lines, int start) {
    final flat = <({int indent, bool ordered, int? number, List<String> text})>[];
    var i = start;
    var blankRun = 0;
    while (i < lines.length) {
      final line = lines[i];
      if (line.trim().isEmpty) {
        blankRun++;
        i++;
        continue;
      }
      final m = _item.firstMatch(line);
      if (m != null && !_rule.hasMatch(line)) {
        final marker = m[2]!;
        final ordered = RegExp(r'^\d').hasMatch(marker);
        flat.add((
          indent: _indentOf(m[1]!),
          ordered: ordered,
          number: ordered ? int.tryParse(marker.substring(0, marker.length - 1)) : null,
          text: [m[3]!],
        ));
        blankRun = 0;
        i++;
        continue;
      }
      // Continuation: indented, or a lazy line right after an item.
      final indented = _indentOf(line) >= 2;
      if (flat.isNotEmpty && (indented || blankRun == 0) && !_startsBlock(line)) {
        flat.last.text.add(line.trim());
        blankRun = 0;
        i++;
        continue;
      }
      break;
    }
    // Leave trailing blank lines for the caller.
    while (i > start && lines[i - 1].trim().isEmpty) {
      i--;
    }

    var pos = 0;
    MdList build(int depth) {
      final base = flat[pos].indent;
      final ordered = flat[pos].ordered;
      final items = <({List<MdSpan> spans, int? number, List<MdList> children})>[];
      while (pos < flat.length) {
        final f = flat[pos];
        if (f.indent < base - 1) break; // back to the parent level
        if (f.indent > base + 1 && items.isNotEmpty && depth < _maxDepth) {
          items.last.children.add(build(depth + 1));
          continue;
        }
        if (items.isNotEmpty && f.ordered != ordered && f.indent <= base + 1) break; // another list
        pos++;
        items.add((spans: MdInline.parse(f.text.join('\n')), number: f.number, children: <MdList>[]));
      }
      return MdList([
        for (final it in items) MdListItem(it.spans, number: it.number, children: List.unmodifiable(it.children)),
      ], ordered: ordered);
    }

    final lists = <MdList>[];
    while (pos < flat.length) {
      lists.add(build(0));
    }
    return (lists, i);
  }

  static bool _startsBlock(String line) =>
      _fence.hasMatch(line) || _heading.hasMatch(line) || _quote.hasMatch(line) || _rule.hasMatch(line);
}

/// Inline Markdown: emphasis, code, strikethrough, links and bare URLs.
abstract final class MdInline {
  static const int _maxDepth = 6;
  static final RegExp _bareUrl = RegExp(r'''https?://[^\s<>"'`]+''');
  static const String _punct = r'''!"#$%&'()*+,-./:;<=>?@[\]^_`{|}~''';

  static List<MdSpan> parse(String text) => _merge(_parse(text, 0));

  static List<MdSpan> _parse(String s, int depth) {
    final out = <MdSpan>[];
    final plain = StringBuffer();
    void flushPlain() {
      if (plain.isEmpty) return;
      out.add(MdSpan(plain.toString()));
      plain.clear();
    }

    List<MdSpan> inner(String t) => depth >= _maxDepth ? [MdSpan(t)] : _parse(t, depth + 1);

    var i = 0;
    while (i < s.length) {
      final c = s[i];
      // Escapes.
      if (c == r'\' && i + 1 < s.length && _punct.contains(s[i + 1])) {
        plain.write(s[i + 1]);
        i += 2;
        continue;
      }
      // Code span.
      if (c == '`') {
        var n = 0;
        while (i + n < s.length && s[i + n] == '`') {
          n++;
        }
        final ticks = '`' * n;
        final close = s.indexOf(ticks, i + n);
        if (close > i + n) {
          var code = s.substring(i + n, close);
          if (code.length > 2 && code.startsWith(' ') && code.endsWith(' ')) code = code.substring(1, code.length - 1);
          flushPlain();
          out.add(MdSpan(code.replaceAll('\n', ' '), code: true));
          i = close + n;
          continue;
        }
        plain.write(ticks);
        i += n;
        continue;
      }
      // Image → a link labelled with its alt text (never loaded).
      if (c == '!' && i + 1 < s.length && s[i + 1] == '[') {
        final link = _link(s, i + 1);
        if (link != null) {
          flushPlain();
          final label = link.label.trim().isEmpty ? link.url : link.label;
          out.add(MdSpan(label, link: link.url));
          i = link.end;
          continue;
        }
      }
      // Link.
      if (c == '[') {
        final link = _link(s, i);
        if (link != null) {
          flushPlain();
          out.addAll([for (final span in inner(link.label)) span.styled(link: link.url)]);
          i = link.end;
          continue;
        }
      }
      // <https://…> autolink.
      if (c == '<') {
        final close = s.indexOf('>', i + 1);
        if (close > i) {
          final body = s.substring(i + 1, close);
          if (_bareUrl.matchAsPrefix(body)?.end == body.length) {
            flushPlain();
            out.add(MdSpan(body, link: body));
            i = close + 1;
            continue;
          }
        }
      }
      // Bare URL.
      if (c == 'h' && (i == 0 || !_isWordChar(s[i - 1]))) {
        final m = _bareUrl.matchAsPrefix(s, i);
        if (m != null) {
          var url = m[0]!;
          // Trailing punctuation belongs to the sentence (keep a balanced ')').
          while (url.isNotEmpty && '.,;:!?\'"*_~'.contains(url[url.length - 1])) {
            url = url.substring(0, url.length - 1);
          }
          if (url.endsWith(')') && '('.allMatches(url).length < ')'.allMatches(url).length) {
            url = url.substring(0, url.length - 1);
          }
          if (url.length > 'https://'.length) {
            flushPlain();
            out.add(MdSpan(url, link: url));
            i += url.length;
            continue;
          }
        }
      }
      // Strikethrough.
      if (c == '~' && s.startsWith('~~', i)) {
        final close = s.indexOf('~~', i + 2);
        if (close > i + 2) {
          flushPlain();
          out.addAll([for (final span in inner(s.substring(i + 2, close))) span.styled(strike: true)]);
          i = close + 2;
          continue;
        }
      }
      // Strong / emphasis.
      if (c == '*' || c == '_') {
        final run = s.startsWith('$c$c$c', i)
            ? 3
            : s.startsWith('$c$c', i)
            ? 2
            : 1;
        final canOpen = i + run < s.length && s[i + run].trim().isNotEmpty && (c == '*' || !_isWordBefore(s, i));
        if (canOpen) {
          final close = _closing(s, i + run, c, run);
          if (close != null) {
            final body = s.substring(i + run, close);
            flushPlain();
            out.addAll([for (final span in inner(body)) span.styled(bold: run >= 2, italic: run != 2)]);
            i = close + run;
            continue;
          }
        }
        plain.write(c * run);
        i += run;
        continue;
      }
      plain.write(c);
      i++;
    }
    flushPlain();
    return out;
  }

  static bool _isWordChar(String ch) => RegExp(r'[\p{L}\p{N}_]', unicode: true).hasMatch(ch);

  static bool _isWordBefore(String s, int i) => i > 0 && _isWordChar(s[i - 1]);

  /// Index of the closing delimiter run for an emphasis opened before
  /// [from], or null.
  static int? _closing(String s, int from, String c, int run) {
    final marker = c * run;
    var k = from;
    while (true) {
      final idx = s.indexOf(marker, k);
      if (idx < 0) return null;
      final prevOk = idx > from && s[idx - 1].trim().isNotEmpty;
      final after = idx + run;
      // Not part of a longer run, and for "_" not inside a word.
      final longer = after < s.length && s[after] == c;
      final intraword = c == '_' && after < s.length && _isWordChar(s[after]);
      if (prevOk && !longer && !intraword) return idx;
      k = idx + (longer ? run + 1 : 1);
      if (k >= s.length) return null;
    }
  }

  static ({String label, String url, int end})? _link(String s, int open) {
    var depth = 0;
    var k = open;
    for (; k < s.length; k++) {
      if (s[k] == r'\') {
        k++;
        continue;
      }
      if (s[k] == '[') depth++;
      if (s[k] == ']') {
        depth--;
        if (depth == 0) break;
      }
    }
    if (k >= s.length || k + 1 >= s.length || s[k + 1] != '(') return null;
    final close = s.indexOf(')', k + 2);
    if (close < 0) return null;
    var url = s.substring(k + 2, close).trim();
    // Drop an optional "title".
    final space = url.indexOf(RegExp(r'\s'));
    if (space > 0) url = url.substring(0, space);
    if (url.startsWith('<') && url.endsWith('>')) url = url.substring(1, url.length - 1);
    if (url.isEmpty) return null;
    return (label: s.substring(open + 1, k), url: url, end: close + 1);
  }

  /// Joins neighbouring spans with identical styles.
  static List<MdSpan> _merge(List<MdSpan> spans) {
    final out = <MdSpan>[];
    for (final s in spans) {
      if (s.text.isEmpty) continue;
      if (out.isNotEmpty) {
        final p = out.last;
        if (p.bold == s.bold && p.italic == s.italic && p.code == s.code && p.strike == s.strike && p.link == s.link) {
          out[out.length - 1] = MdSpan(
            p.text + s.text,
            bold: p.bold,
            italic: p.italic,
            code: p.code,
            strike: p.strike,
            link: p.link,
          );
          continue;
        }
      }
      out.add(s);
    }
    return out;
  }
}

/// Links the chat will open: web and e-mail only.
abstract final class MdLinks {
  static Uri? safeUri(String? raw) {
    if (raw == null) return null;
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) return null;
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'https' || scheme == 'http') return uri.host.isEmpty ? null : uri;
    if (scheme == 'mailto') return uri.path.contains('@') ? uri : null;
    return null;
  }
}
