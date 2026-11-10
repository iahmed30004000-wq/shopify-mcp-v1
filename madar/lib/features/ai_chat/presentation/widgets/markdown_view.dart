import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/sound/sound_api.dart';
import '../../domain/markdown.dart';

/// Opens a link the user tapped.
typedef MdLinkOpener = Future<bool> Function(Uri uri);

Future<bool> _launch(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// Renders an AI reply's Markdown safely (see [MdParser]). Each paragraph,
/// heading and list item takes its own direction from its first strong
/// letter, so an English paragraph in an Arabic reply reads left to right
/// (and the reverse), with numbers kept in place by the bidi algorithm.
/// Code is always left to right. Links are shown and open only on tap
/// (web and e-mail only), after a sheet shows where they really go – a
/// reply's link label can hide an address that carries data away.
class MarkdownView extends StatefulWidget {
  const MarkdownView(this.text, {super.key, this.style, this.onOpenLink, this.selectable = false});

  /// "Open link" in the confirmation sheet.
  static const Key openLinkKey = ValueKey('ai-open-link');

  final String text;
  final TextStyle? style;

  /// Defaults to url_launcher (external app).
  final MdLinkOpener? onOpenLink;
  final bool selectable;

  @override
  State<MarkdownView> createState() => _MarkdownViewState();
}

class _MarkdownViewState extends State<MarkdownView> {
  final List<TapGestureRecognizer> _recognizers = [];
  List<MdBlock>? _blocks;
  String? _parsed;

  List<MdBlock> get blocks {
    if (_parsed != widget.text) {
      _parsed = widget.text;
      _blocks = MdParser.parse(widget.text);
    }
    return _blocks!;
  }

  void _clearRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _clearRecognizers();
    super.dispose();
  }

  Future<void> _open(String raw) async {
    final uri = MdLinks.safeUri(raw);
    if (uri == null) return;
    final go = await showInteractionSheet<bool>(context, builder: (_) => LinkConfirmSheet(uri: uri));
    if (go != true || !mounted) return;
    Fx.fire(Sfx.navigate);
    final ok = await (widget.onOpenLink ?? _launch)(uri);
    if (!ok && mounted) {
      Fx.fire(Sfx.error);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(L10n.of(context).aiChatLinkFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    _clearRecognizers();
    final base = widget.style ?? Theme.of(context).textTheme.bodyLarge!;
    final children = <Widget>[];
    final list = blocks;
    for (var i = 0; i < list.length; i++) {
      if (i > 0) children.add(SizedBox(height: _gapBefore(list[i])));
      children.add(_block(context, list[i], base, 0));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: children);
  }

  double _gapBefore(MdBlock b) => switch (b) {
    MdHeading() => Space.m,
    MdList() || MdTable() || MdCodeBlock() => Space.s + 2,
    _ => Space.s + 2,
  };

  TextDirection _dirOf(BuildContext context, String plain) =>
      BidiIsolate.directionOf(plain) ?? Directionality.of(context);

  Widget _block(BuildContext context, MdBlock b, TextStyle base, int depth) {
    final t = context.tokens;
    switch (b) {
      case MdParagraph(:final spans):
        return _text(context, spans, base);
      case MdHeading(:final level, :final spans):
        final scale = switch (level) {
          1 => 1.22,
          2 => 1.14,
          3 => 1.06,
          _ => 1.0,
        };
        return _text(
          context,
          spans,
          base.copyWith(fontWeight: FontWeight.w700, fontSize: (base.fontSize ?? 15) * scale, color: t.textPrimary),
        );
      case MdCodeBlock(:final code):
        return _CodeBlock(code: code, style: base);
      case MdRule():
        return Padding(
          padding: const EdgeInsetsDirectional.symmetric(vertical: Space.xs),
          child: Divider(height: 1, thickness: 0.8, color: t.glassBorder.withValues(alpha: 0.6)),
        );
      case MdQuote(:final children):
        final plain = children.whereType<MdParagraph>().map((p) => mdPlain(p.spans)).join(' ');
        return Directionality(
          textDirection: _dirOf(context, plain),
          child: Container(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.xxs, 0, Space.xxs),
            decoration: BoxDecoration(
              border: BorderDirectional(start: BorderSide(color: t.brass.withValues(alpha: 0.7), width: 2.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(height: Space.xs),
                  _block(context, children[i], base.copyWith(color: t.textSecondary), depth + 1),
                ],
              ],
            ),
          ),
        );
      case MdList():
        return _list(context, b, base, depth);
      case MdTable():
        return _table(context, b, base);
    }
  }

  Widget _list(BuildContext context, MdList list, TextStyle base, int depth) {
    final t = context.tokens;
    final fmt = context.formatter;
    final items = <Widget>[];
    for (var i = 0; i < list.items.length; i++) {
      final item = list.items[i];
      final dir = _dirOf(context, mdPlain(item.spans));
      final number = item.number ?? (i + 1);
      final marker = list.ordered
          ? Text(
              '${fmt.localizeDigits('$number')}.',
              style: base.copyWith(color: t.accent, fontWeight: FontWeight.w600),
            )
          : Padding(
              padding: EdgeInsetsDirectional.only(top: (base.fontSize ?? 15) * (base.height ?? 1.4) / 2 - 3),
              child: Container(
                width: depth == 0 ? 6 : 5,
                height: depth == 0 ? 6 : 5,
                decoration: BoxDecoration(
                  shape: depth == 0 ? BoxShape.circle : BoxShape.rectangle,
                  color: depth == 0 ? t.accent : null,
                  border: depth == 0 ? null : Border.all(color: t.accent, width: 1.2),
                ),
              ),
            );
      items.add(
        Directionality(
          textDirection: dir,
          child: Padding(
            padding: EdgeInsetsDirectional.only(top: i == 0 ? 0 : Space.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: list.ordered ? 24 : 16,
                  child: Align(alignment: AlignmentDirectional.topStart, child: marker),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _text(context, item.spans, base),
                      for (final child in item.children)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(top: Space.xs),
                          child: _list(context, child, base, depth + 1),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: items);
  }

  Widget _table(BuildContext context, MdTable table, TextStyle base) {
    final t = context.tokens;
    final columns = [table.header.length, for (final r in table.rows) r.length].reduce((a, b) => a > b ? a : b);
    final plain = [for (final c in table.header) mdPlain(c)].join(' ');
    final dir = _dirOf(context, plain);
    TableRow row(List<List<MdSpan>> cells, {bool header = false}) => TableRow(
      decoration: header ? BoxDecoration(color: t.accent.withValues(alpha: 0.08)) : null,
      children: [
        for (var c = 0; c < columns; c++)
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.s + 2, vertical: Space.xs + 2),
            child: _text(
              context,
              c < cells.length ? cells[c] : const [],
              header ? base.copyWith(fontWeight: FontWeight.w600) : base,
              align: switch (c < table.aligns.length ? table.aligns[c] : MdAlign.start) {
                MdAlign.start => TextAlign.start,
                MdAlign.center => TextAlign.center,
                MdAlign.end => TextAlign.end,
              },
            ),
          ),
      ],
    );
    return Directionality(
      textDirection: dir,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(t.radiusS),
            border: Border.all(color: t.glassBorder.withValues(alpha: 0.7), width: 0.8),
          ),
          clipBehavior: Clip.antiAlias,
          child: Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            border: TableBorder.symmetric(inside: BorderSide(color: t.glassBorder.withValues(alpha: 0.45), width: 0.6)),
            children: [row(table.header, header: true), for (final r in table.rows) row(r)],
          ),
        ),
      ),
    );
  }

  Widget _text(BuildContext context, List<MdSpan> spans, TextStyle base, {TextAlign align = TextAlign.start}) {
    final t = context.tokens;
    final dir = _dirOf(context, mdPlain(spans));
    final children = <InlineSpan>[];
    for (final s in spans) {
      var style = base;
      if (s.bold) style = style.copyWith(fontWeight: FontWeight.w700);
      if (s.italic) style = style.copyWith(fontStyle: FontStyle.italic);
      if (s.strike) style = style.copyWith(decoration: TextDecoration.lineThrough);
      if (s.code) {
        // The app font (bundled, so it renders the same everywhere) with
        // even digits on a soft tint.
        style = style.copyWith(
          fontSize: (base.fontSize ?? 15) * 0.92,
          fontFeatures: const [FontFeature.tabularFigures()],
          backgroundColor: t.accent.withValues(alpha: 0.14),
          color: t.textPrimary,
        );
      }
      final uri = MdLinks.safeUri(s.link);
      if (uri != null) {
        final r = TapGestureRecognizer()..onTap = () => _open(s.link!);
        _recognizers.add(r);
        children.add(
          TextSpan(
            text: s.text,
            style: style.copyWith(
              color: t.accent,
              decoration: TextDecoration.underline,
              decorationColor: t.accent.withValues(alpha: 0.6),
            ),
            recognizer: r,
            semanticsLabel: L10n.of(context).aiChatOpenLink(s.text),
          ),
        );
      } else {
        // Code keeps its own left-to-right order inside any paragraph.
        children.add(TextSpan(text: s.code ? BidiIsolate.ltr(s.text) : s.text, style: style));
      }
    }
    final span = TextSpan(style: base, children: children);
    return widget.selectable
        ? SelectableText.rich(span, textDirection: dir, textAlign: align)
        : Text.rich(span, textDirection: dir, textAlign: align);
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.code, required this.style});

  final String code;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(t.radiusS),
          color: t.space0.withValues(alpha: t.isDark ? 0.5 : 0.06),
          border: Border.all(color: t.glassBorder.withValues(alpha: 0.6), width: 0.8),
        ),
        child: Stack(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(Space.m, Space.m, 40, Space.m),
              child: Text(
                code,
                style: style.copyWith(
                  fontSize: (style.fontSize ?? 15) * 0.88,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  height: 1.45,
                  color: t.textPrimary,
                ),
              ),
            ),
            Positioned(
              right: 2,
              top: 2,
              child: IconButton(
                tooltip: l.aiChatCopyCode,
                visualDensity: VisualDensity.compact,
                iconSize: 16,
                color: t.textTertiary,
                icon: const Icon(Icons.copy_rounded),
                onPressed: () {
                  Fx.fire(Sfx.tap);
                  Clipboard.setData(ClipboardData(text: code));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Open this link?": the real destination of a tapped link – its site in
/// large type and the whole address – before anything opens.
class LinkConfirmSheet extends StatelessWidget {
  const LinkConfirmSheet({super.key, required this.uri});

  final Uri uri;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final mail = uri.scheme == 'mailto';
    final site = mail ? uri.path : uri.host;
    return InteractionSheetFrame(
      title: l.aiChatLinkTitle,
      icon: mail ? Icons.mail_outline_rounded : Icons.open_in_new_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            BidiIsolate.ltr(site),
            style: text.titleLarge!.copyWith(color: t.textPrimary, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: Space.s),
          Container(
            padding: const EdgeInsetsDirectional.all(Space.m),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(t.radiusM),
              color: t.space0.withValues(alpha: t.isDark ? 0.42 : 0.55),
              border: Border.all(color: t.glassBorder.withValues(alpha: 0.7), width: 0.8),
            ),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: SelectableText(
                uri.toString(),
                minLines: 1,
                maxLines: 6,
                style: text.bodySmall!.copyWith(color: t.textSecondary, height: 1.45),
              ),
            ),
          ),
          const SizedBox(height: Space.m),
          Text(l.aiChatLinkBody, style: text.bodySmall!.copyWith(color: t.textSecondary, height: 1.45)),
        ],
      ),
      footer: Row(
        children: [
          SheetButton(label: l.actionCancel, onPressed: () => Navigator.of(context).pop(false)),
          const SizedBox(width: Space.s),
          Expanded(
            child: SheetButton(
              key: MarkdownView.openLinkKey,
              label: l.aiChatLinkOpen,
              icon: Icons.open_in_new_rounded,
              primary: true,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ),
        ],
      ),
    );
  }
}
