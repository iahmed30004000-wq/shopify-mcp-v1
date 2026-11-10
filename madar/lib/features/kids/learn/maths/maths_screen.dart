// «الحساب» (design 07b): tables, division and fractions in sets of five.
// No timer, no score, nobody is told they are wrong: a miss shows a soft amber
// «جرّب مرّة ثانية» and the tapped answer fades. A finished set earns a star.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';

import '../../core/kids_section.dart';
import '../domain/maths_engine.dart';
import '../ui/kids_tokens.dart';
import '../ui/kids_widgets.dart';
import 'maths_visuals.dart';

/// Questions in one set; a finished set earns one star.
const int kMathsSetSize = 5;

class MathsScreen extends ConsumerStatefulWidget {
  const MathsScreen({super.key, this.seed, this.initialTab = 0});

  /// Seed of the question stream (tests pass one; null varies every launch).
  final int? seed;
  final int initialTab;

  @override
  ConsumerState<MathsScreen> createState() => _MathsScreenState();
}

class _MathsScreenState extends ConsumerState<MathsScreen> {
  late final MathsEngine _engine = MathsEngine(seed: widget.seed ?? DateTime.now().microsecondsSinceEpoch & 0x7fffffff);
  late int _tab = widget.initialTab.clamp(0, 2);
  late MathsQuestion _q = _engine.next(_kind);
  int _n = 0;
  final Set<int> _dimmed = {};
  bool _answeredOnce = false;
  bool _solved = false;
  bool _retry = false;
  bool _finished = false;

  MathsKind get _kind => MathsKind.values[_tab];

  void _newSet(int tab) => setState(() {
    _tab = tab;
    _n = 0;
    _finished = false;
    _reset(_engine.next(_kind));
  });

  void _reset(MathsQuestion q) {
    _q = q;
    _dimmed.clear();
    _answeredOnce = false;
    _solved = false;
    _retry = false;
  }

  void _pick(int i) {
    if (_solved) return;
    final right = _q.isCorrect(_q.choices[i]);
    if (!_answeredOnce) {
      _answeredOnce = true;
      _engine.record(firstTry: right);
    }
    setState(() {
      if (right) {
        _solved = true;
        _retry = false;
      } else {
        _dimmed.add(i);
        _retry = true;
      }
    });
  }

  void _next() {
    if (_n + 1 >= kMathsSetSize) {
      setState(() => _finished = true);
      ref.read(kidsStarAwardProvider)('maths_set');
      return;
    }
    setState(() {
      _n++;
      _reset(_engine.next(_kind));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return KidsBackdrop(
      top: KidsColors.teal100,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KidsTabs(labels: [l.kidsMathsTabMul, l.kidsMathsTabDiv, l.kidsMathsTabFrac], selected: _tab, onSelect: _newSet),
            const SizedBox(height: 14),
            Semantics(
              label: l.kidsMathsProgress(_n + 1, kMathsSetSize),
              child: ExcludeSemantics(child: _Dots(done: _finished ? kMathsSetSize : _n, total: kMathsSetSize)),
            ),
            const SizedBox(height: 14),
            if (_finished)
              _finishedCard(l)
            else ...[
              _QuestionCard(question: _q),
              const SizedBox(height: 16),
              _Choices(question: _q, dimmed: _dimmed, solved: _solved, onPick: _pick),
              const SizedBox(height: 16),
              if (_solved)
                GoodBanner(text: l.kidsMathsGood)
              else if (_retry)
                SoftRetryBanner(text: l.kidsMathsTryAgain),
              if (_solved) ...[
                const SizedBox(height: 14),
                KidsButton(label: l.kidsMathsNext, icon: Icons.chevron_right_rounded, onTap: _next),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _finishedCard(L10n l) => KidsCard(
    child: Column(
      children: [
        const SizedBox(width: 120, height: 120, child: CustomPaint(painter: KhatamStarPainter())),
        const SizedBox(height: 12),
        Text(l.kidsMathsSetDone, textAlign: TextAlign.center, style: KidsType.title(26)),
        const SizedBox(height: 16),
        KidsButton(label: l.kidsMathsNewSet, kind: KidsButtonKind.teal, onTap: () => _newSet(_tab)),
      ],
    ),
  );
}

String _voiceId(MathsQuestion q) => switch (q.kind) {
  MathsKind.multiplication => 'maths_mul_${q.a}_${q.b}',
  MathsKind.division => 'maths_div_${q.a}_${q.b}',
  MathsKind.fractions => q.task == FractionTask.ofAmount ? 'maths_fracof_${q.a}_${q.b}_${q.total}' : 'maths_frac_${q.a}_${q.b}',
};

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.question});
  final MathsQuestion question;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final f = MadarFormatter.of(context);
    String n(int v) => f.localizeDigits('$v');
    final q = question;
    final qMark = Text('؟', style: KidsType.title(52, color: KidsColors.rose500));
    final numStyle = KidsType.title(52);

    // The sum is always written left to right, as in a school book.
    Widget? sum;
    Widget visual;
    String caption;
    switch (q.kind) {
      case MathsKind.multiplication:
        sum = _sumRow([Text('${n(q.a)} × ${n(q.b)} =', style: numStyle), qMark]);
        visual = CustomPaint(painter: DotArrayPainter(rows: q.a, cols: q.b));
        caption = f.localizeDigits(l.kidsMathsRowsCaption(q.a, q.b));
      case MathsKind.division:
        sum = _sumRow([Text('${n(q.a)} ÷ ${n(q.b)} =', style: numStyle), qMark]);
        visual = CustomPaint(painter: GroupsPainter(total: q.a, groups: q.b));
        caption = f.localizeDigits(l.kidsMathsDivCaption(q.a, q.b));
      case MathsKind.fractions:
        if (q.task == FractionTask.readPie) {
          visual = CustomPaint(painter: PiePainter(num: q.a, den: q.b));
          caption = l.kidsMathsPieCaption;
        } else {
          sum = _sumRow([
            FractionStack(num: n(q.a), den: n(q.b), size: 40),
            Text(l.kidsMathsOf, style: KidsType.title(28)),
            Text('${n(q.total!)} =', style: numStyle),
            qMark,
          ]);
          visual = CustomPaint(painter: GroupsPainter(total: q.total!, groups: q.b, lit: q.a));
          caption = f.localizeDigits(l.kidsMathsDivCaption(q.total!, q.b));
        }
    }
    final isPie = q.task == FractionTask.readPie;
    return KidsCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: sum == null
                    ? const SizedBox.shrink()
                    : Directionality(
                        textDirection: TextDirection.ltr,
                        child: FittedBox(fit: BoxFit.scaleDown, child: sum),
                      ),
              ),
              SpeakerButton(voiceId: _voiceId(q)),
            ],
          ),
          const SizedBox(height: 8),
          ExcludeSemantics(
            child: SizedBox(height: isPie ? 170 : (q.kind == MathsKind.multiplication ? 190 : 150), width: double.infinity, child: Center(child: AspectRatio(aspectRatio: isPie ? 1 : 1.6, child: visual))),
          ),
          const SizedBox(height: 8),
          Text(caption, textAlign: TextAlign.center, style: KidsType.bodyText(18, color: KidsColors.ink2)),
        ],
      ),
    );
  }

  Widget _sumRow(List<Widget> kids) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [for (var i = 0; i < kids.length; i++) ...[if (i > 0) const SizedBox(width: 10), kids[i]]],
  );
}

class _Choices extends StatelessWidget {
  const _Choices({required this.question, required this.dimmed, required this.solved, required this.onPick});

  final MathsQuestion question;
  final Set<int> dimmed;
  final bool solved;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final f = MadarFormatter.of(context);
    return Row(
      children: [
        for (var i = 0; i < question.choices.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: _ChoiceButton(
              semantic: l.kidsMathsChoiceLabel(f.localizeDigits(question.choices[i].toString())),
              dimmed: dimmed.contains(i),
              right: solved && question.isCorrect(question.choices[i]),
              onTap: () => onPick(i),
              child: question.choices[i].isWhole
                  ? FittedBox(fit: BoxFit.scaleDown, child: Text(f.localizeDigits('${question.choices[i].num}'), style: KidsType.title(44)))
                  : FractionStack(num: f.localizeDigits('${question.choices[i].num}'), den: f.localizeDigits('${question.choices[i].den}'), size: 30),
            ),
          ),
        ],
      ],
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({required this.child, required this.semantic, required this.dimmed, required this.right, required this.onTap});

  final Widget child;
  final String semantic;
  final bool dimmed;
  final bool right;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semantic,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        opacity: dimmed ? 0.5 : 1,
        child: Container(
          constraints: const BoxConstraints(minHeight: 88),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: right ? null : (dimmed ? KidsColors.retryFill : KidsColors.paper),
            gradient: right
                ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [KidsColors.sun300, KidsColors.sun500])
                : null,
            border: dimmed ? Border.all(color: KidsColors.retry, width: 3) : null,
            boxShadow: [BoxShadow(color: right ? KidsColors.sun700 : KidsColors.sand2, offset: const Offset(0, 4))],
          ),
          child: child,
        ),
      ),
    ),
  );
}

class _Dots extends StatelessWidget {
  const _Dots({required this.done, required this.total});
  final int done, total;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < total; i++)
        Container(
          width: 18,
          height: 18,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(shape: BoxShape.circle, color: i < done ? KidsColors.teal500 : KidsColors.teal200),
        ),
    ],
  );
}
