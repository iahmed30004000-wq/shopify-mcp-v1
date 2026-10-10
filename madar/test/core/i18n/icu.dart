// A small ICU MessageFormat parser for linting the ARB parts: literal text,
// `{arg}` and `{arg, plural|select, key{…} …}` – the subset gen-l10n
// supports without `use-escaping` (apostrophes are literal).

sealed class IcuNode {
  const IcuNode();
}

class IcuText extends IcuNode {
  const IcuText(this.text);
  final String text;
}

class IcuArg extends IcuNode {
  const IcuArg(this.name);
  final String name;
}

class IcuChoice extends IcuNode {
  const IcuChoice(this.name, this.kind, this.branches);
  final String name;

  /// `plural` or `select`.
  final String kind;
  final Map<String, List<IcuNode>> branches;
}

class IcuFormatException implements Exception {
  IcuFormatException(this.message, this.source, this.offset);
  final String message;
  final String source;
  final int offset;

  @override
  String toString() => 'IcuFormatException: $message at $offset in "$source"';
}

/// Parses [source] into nodes; throws [IcuFormatException] on unbalanced
/// braces or a malformed argument.
List<IcuNode> parseIcu(String source) {
  final p = _Parser(source);
  final nodes = p.message(topLevel: true);
  if (p.i != source.length) throw IcuFormatException('unexpected "}"', source, p.i);
  return nodes;
}

class _Parser {
  _Parser(this.s);
  final String s;
  int i = 0;

  static final _name = RegExp(r'[A-Za-z_][A-Za-z0-9_]*');

  List<IcuNode> message({bool topLevel = false}) {
    final out = <IcuNode>[];
    final text = StringBuffer();
    void flush() {
      if (text.isNotEmpty) out.add(IcuText(text.toString()));
      text.clear();
    }

    while (i < s.length) {
      final c = s[i];
      if (c == '{') {
        flush();
        out.add(argument());
      } else if (c == '}') {
        if (topLevel) throw IcuFormatException('unexpected "}"', s, i);
        break;
      } else {
        text.write(c);
        i++;
      }
    }
    flush();
    return out;
  }

  void ws() {
    while (i < s.length && s[i].trim().isEmpty) {
      i++;
    }
  }

  String name() {
    ws();
    final m = _name.matchAsPrefix(s, i);
    if (m == null) throw IcuFormatException('expected a name', s, i);
    i = m.end;
    ws();
    return m[0]!;
  }

  void expect(String c) {
    if (i >= s.length || s[i] != c) throw IcuFormatException('expected "$c"', s, i);
    i++;
  }

  IcuNode argument() {
    expect('{');
    final arg = name();
    if (i < s.length && s[i] == '}') {
      i++;
      return IcuArg(arg);
    }
    expect(',');
    final kind = name();
    if (kind != 'plural' && kind != 'select') throw IcuFormatException('unknown kind "$kind"', s, i);
    expect(',');
    final branches = <String, List<IcuNode>>{};
    ws();
    while (i < s.length && s[i] != '}') {
      final start = i;
      while (i < s.length && s[i] != '{' && s[i].trim().isNotEmpty) {
        i++;
      }
      final key = s.substring(start, i);
      if (key.isEmpty) throw IcuFormatException('expected a branch key', s, i);
      ws();
      expect('{');
      branches[key] = message();
      expect('}');
      ws();
    }
    expect('}');
    return IcuChoice(arg, kind, branches);
  }
}

/// Every argument name used anywhere in [nodes] (choice variables included).
Set<String> icuArguments(List<IcuNode> nodes) => {
  for (final n in nodes)
    ...switch (n) {
      IcuText() => const <String>{},
      IcuArg(:final name) => {name},
      IcuChoice(:final name, :final branches) => {name, for (final b in branches.values) ...icuArguments(b)},
    },
};

/// Every literal text run in [nodes], branches included.
Iterable<String> icuTexts(List<IcuNode> nodes) sync* {
  for (final n in nodes) {
    switch (n) {
      case IcuText(:final text):
        yield text;
      case IcuArg():
        break;
      case IcuChoice(:final branches):
        for (final b in branches.values) {
          yield* icuTexts(b);
        }
    }
  }
}

/// Every plural choice in [nodes], nested ones included.
Iterable<IcuChoice> icuPlurals(List<IcuNode> nodes) sync* {
  for (final n in nodes) {
    if (n is IcuChoice) {
      if (n.kind == 'plural') yield n;
      for (final b in n.branches.values) {
        yield* icuPlurals(b);
      }
    }
  }
}
