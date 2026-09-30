import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/ai_chat/domain/markdown.dart';

List<MdSpan> _inline(String s) => MdInline.parse(s);

void main() {
  group('inline', () {
    test('bold, italic, code, strike, links', () {
      expect(_inline('a **b** *c* `d` ~~e~~ [f](https://x.org)'), const [
        MdSpan('a '),
        MdSpan('b', bold: true),
        MdSpan(' '),
        MdSpan('c', italic: true),
        MdSpan(' '),
        MdSpan('d', code: true),
        MdSpan(' '),
        MdSpan('e', strike: true),
        MdSpan(' '),
        MdSpan('f', link: 'https://x.org'),
      ]);
      expect(_inline('***both***'), const [MdSpan('both', bold: true, italic: true)]);
      expect(_inline('__bold__ and _it_'), const [MdSpan('bold', bold: true), MdSpan(' and '), MdSpan('it', italic: true)]);
      expect(_inline('**bold with *inner* italic**'), const [
        MdSpan('bold with ', bold: true),
        MdSpan('inner', bold: true, italic: true),
        MdSpan(' italic', bold: true),
      ]);
    });

    test('unclosed markers stay literal (streaming)', () {
      expect(mdPlain(_inline('**half')), '**half');
      expect(mdPlain(_inline('a `code')), 'a `code');
      expect(mdPlain(_inline('[link](https://x')), '[link](https://x');
      expect(_inline('2 * 3 * 4'), const [MdSpan('2 * 3 * 4')]);
    });

    test('snake_case and escapes are not emphasis', () {
      expect(_inline('use snake_case_name here'), const [MdSpan('use snake_case_name here')]);
      expect(_inline(r'\*not\* italic'), const [MdSpan('*not* italic')]);
    });

    test('bare URLs and autolinks; trailing punctuation stays text', () {
      expect(_inline('See https://madar.app/help.'), const [
        MdSpan('See '),
        MdSpan('https://madar.app/help', link: 'https://madar.app/help'),
        MdSpan('.'),
      ]);
      expect(_inline('<https://a.b/c>'), const [MdSpan('https://a.b/c', link: 'https://a.b/c')]);
      expect(_inline('(see https://a.b/c)'), const [
        MdSpan('(see '),
        MdSpan('https://a.b/c', link: 'https://a.b/c'),
        MdSpan(')'),
      ]);
    });

    test('HTML stays literal text; images become links (never loaded)', () {
      expect(_inline('<script>alert(1)</script>'), const [MdSpan('<script>alert(1)</script>')]);
      expect(_inline('![chart](https://x.org/c.png)'), const [MdSpan('chart', link: 'https://x.org/c.png')]);
    });

    test('safe links: web and e-mail only', () {
      expect(MdLinks.safeUri('https://x.org'), isNotNull);
      expect(MdLinks.safeUri('mailto:a@b.co'), isNotNull);
      expect(MdLinks.safeUri('javascript:alert(1)'), isNull);
      expect(MdLinks.safeUri('file:///etc/passwd'), isNull);
      expect(MdLinks.safeUri('tel:123'), isNull);
      expect(MdLinks.safeUri('intent://x'), isNull);
    });
  });

  group('blocks', () {
    test('headings, paragraphs with line breaks, rules, quotes', () {
      final b = MdParser.parse('# Title\n\nLine one\nline two\n\n---\n\n> quoted\n> more');
      expect(b.length, 4);
      expect((b[0] as MdHeading).level, 1);
      expect(mdPlain((b[0] as MdHeading).spans), 'Title');
      expect(mdPlain((b[1] as MdParagraph).spans), 'Line one\nline two');
      expect(b[2], isA<MdRule>());
      final q = b[3] as MdQuote;
      expect(mdPlain((q.children.single as MdParagraph).spans), 'quoted\nmore');
    });

    test('bullet and numbered lists, nested, with continuation lines', () {
      final b = MdParser.parse('- one\n- two\n  - nested a\n  - nested b\n- three\n  continued\n\n1. first\n2. second');
      expect(b.length, 2);
      final ul = b[0] as MdList;
      expect(ul.ordered, isFalse);
      expect(ul.items.map((i) => mdPlain(i.spans)), ['one', 'two', 'three\ncontinued']);
      expect(ul.items[1].children.single.items.map((i) => mdPlain(i.spans)), ['nested a', 'nested b']);
      final ol = b[1] as MdList;
      expect(ol.ordered, isTrue);
      expect(ol.items.map((i) => i.number), [1, 2]);
    });

    test('Arabic list markers and a bullet list right after a paragraph', () {
      final b = MdParser.parse('خطة الغد:\n- الفجر في وقته\n- مشي ٢٠ دقيقة');
      expect(b.length, 2);
      expect((b[1] as MdList).items.length, 2);
    });

    test('a year at a line start inside a paragraph is not a list', () {
      final b = MdParser.parse('We moved in\n2024. Then more.');
      expect(b.single, isA<MdParagraph>());
    });

    test('code fences (closed and still streaming)', () {
      final b = MdParser.parse('```dart\nvoid main() {}\n```\nafter');
      expect((b[0] as MdCodeBlock).code, 'void main() {}');
      expect((b[0] as MdCodeBlock).language, 'dart');
      expect(mdPlain((b[1] as MdParagraph).spans), 'after');
      final open = MdParser.parse('```\nline 1\nline 2');
      expect((open.single as MdCodeBlock).code, 'line 1\nline 2');
    });

    test('tables with alignment', () {
      final b = MdParser.parse('| Item | Amount |\n|:-----|------:|\n| Rent | 350 |\n| Food | 120 |');
      final t = b.single as MdTable;
      expect(t.header.map(mdPlain), ['Item', 'Amount']);
      expect(t.aligns, [MdAlign.start, MdAlign.end]);
      expect(t.rows.map((r) => r.map(mdPlain).toList()), [
        ['Rent', '350'],
        ['Food', '120'],
      ]);
    });

    test('never throws on arbitrary prefixes of a reply', () {
      const reply = '## خطة\n\n1. **الفجر** في وقته\n   - `05:12`\n2. [رابط](https://x.org)\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\n```\ncode';
      for (var i = 0; i <= reply.length; i++) {
        MdParser.parse(reply.substring(0, i));
      }
    });
  });
}
