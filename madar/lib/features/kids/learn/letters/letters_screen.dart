// «الحروف»: the Arabic letters section (design 07a), with finger tracing and
// the «أي حرف هاد؟» quiz. Everything happens inside this one widget (no
// routes): the system back button walks back to the letter card first.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';

import '../../core/kids_section.dart';
import '../data/arabic_letters.dart';
import '../domain/letter_quiz_engine.dart';
import '../ui/kids_tokens.dart';
import '../ui/kids_widgets.dart';
import 'letter_picture.dart';
import 'trace_canvas.dart';

enum _LettersMode { learn, trace, quiz }

/// Questions in one quiz round; finishing a round earns one star.
const int kLetterQuizRound = 5;

class LettersScreen extends ConsumerStatefulWidget {
  const LettersScreen({super.key, this.initialIndex = 0, this.quizSeed, this.letters = arabicLetters});

  final int initialIndex;

  /// Seed of the quiz (tests pass one; null means "vary every round").
  final int? quizSeed;
  final List<ArabicLetter> letters;

  @override
  ConsumerState<LettersScreen> createState() => _LettersScreenState();
}

class _LettersScreenState extends ConsumerState<LettersScreen> {
  late int _index = widget.initialIndex.clamp(0, widget.letters.length - 1);
  _LettersMode _mode = _LettersMode.learn;
  LetterForm _form = LetterForm.isolated;

  ArabicLetter get _letter => widget.letters[_index];

  void _go(int i) {
    final n = widget.letters.length;
    setState(() {
      _index = (i % n + n) % n;
      _form = LetterForm.isolated;
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _mode == _LettersMode.learn,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) setState(() => _mode = _LettersMode.learn);
    },
    child: KidsBackdrop(
      top: KidsColors.sun100,
      child: switch (_mode) {
        _LettersMode.learn => _LearnView(
          letters: widget.letters,
          index: _index,
          form: _form,
          onSelect: _go,
          onForm: (f) => setState(() => _form = f),
          onTrace: () => setState(() => _mode = _LettersMode.trace),
          onQuiz: () => setState(() => _mode = _LettersMode.quiz),
        ),
        _LettersMode.trace => _TraceView(letter: _letter, onBack: () => setState(() => _mode = _LettersMode.learn)),
        _LettersMode.quiz => LetterQuizView(
          letters: widget.letters,
          seed: widget.quizSeed,
          onBack: () => setState(() => _mode = _LettersMode.learn),
        ),
      },
    ),
  );
}

// ---- the letter card ------------------------------------------------------

class _LearnView extends StatefulWidget {
  const _LearnView({
    required this.letters,
    required this.index,
    required this.form,
    required this.onSelect,
    required this.onForm,
    required this.onTrace,
    required this.onQuiz,
  });

  final List<ArabicLetter> letters;
  final int index;
  final LetterForm form;
  final ValueChanged<int> onSelect;
  final ValueChanged<LetterForm> onForm;
  final VoidCallback onTrace;
  final VoidCallback onQuiz;

  @override
  State<_LearnView> createState() => _LearnViewState();
}

class _LearnViewState extends State<_LearnView> {
  final _strip = ScrollController();
  static const double _chip = 64, _gap = 8;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(animate: false));
  }

  @override
  void didUpdateWidget(_LearnView old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
  }

  /// Keeps the chosen letter's chip in the middle of the strip.
  void _reveal({bool animate = true}) {
    if (!mounted || !_strip.hasClients) return;
    final pos = _strip.position;
    final target = (widget.index * (_chip + _gap) - (pos.viewportDimension - _chip) / 2).clamp(
      0.0,
      pos.maxScrollExtent,
    );
    if (animate && !MediaQuery.disableAnimationsOf(context)) {
      _strip.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else {
      _strip.jumpTo(target);
    }
  }

  @override
  void dispose() {
    _strip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final letter = widget.letters[widget.index];
    return Column(
      children: [
        SizedBox(
          height: _chip + 14,
          child: ListView.separated(
            controller: _strip,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            itemCount: widget.letters.length,
            separatorBuilder: (_, _) => const SizedBox(width: _gap),
            itemBuilder: (context, i) => _LetterChip(
              letter: widget.letters[i],
              selected: i == widget.index,
              onTap: () => widget.onSelect(i),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LetterCard(letter: letter, form: widget.form, onForm: widget.onForm),
                const SizedBox(height: 16),
                _WordCard(letter: letter),
                const SizedBox(height: 20),
                KidsButton(label: l.kidsLettersTraceCta, icon: Icons.draw_rounded, kind: KidsButtonKind.rose, onTap: widget.onTrace),
                const SizedBox(height: 14),
                KidsButton(label: l.kidsLettersQuizCta, icon: Icons.extension_rounded, kind: KidsButtonKind.teal, onTap: widget.onQuiz),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: KidsButton(
                        label: l.kidsLettersNext,
                        icon: Icons.chevron_right_rounded,
                        onTap: () => widget.onSelect(widget.index + 1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    KidsRoundButton(
                      icon: Icons.chevron_left_rounded,
                      semanticLabel: l.kidsLettersPrevious,
                      onTap: () => widget.onSelect(widget.index - 1),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LetterChip extends StatelessWidget {
  const _LetterChip({required this.letter, required this.selected, required this.onTap});

  final ArabicLetter letter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: letter.name,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [KidsColors.sun300, KidsColors.sun500],
                )
              : null,
          color: selected ? null : KidsColors.paper,
          boxShadow: [BoxShadow(color: selected ? KidsColors.sun700 : KidsColors.sand2, offset: const Offset(0, 3))],
        ),
        child: Text(letter.glyph, textDirection: TextDirection.rtl, style: KidsType.letterStyle(38, color: KidsColors.night900)),
      ),
    ),
  );
}

class _LetterCard extends StatelessWidget {
  const _LetterCard({required this.letter, required this.form, required this.onForm});

  final ArabicLetter letter;
  final LetterForm form;
  final ValueChanged<LetterForm> onForm;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return KidsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(l.kidsLettersLetterOf(letter.name), style: KidsType.title(28)),
                    ),
                    const SizedBox(height: 4),
                    Text(l.kidsLettersTapHear, style: KidsType.bodyText(16, color: KidsColors.ink2)),
                    const SizedBox(height: 10),
                    SpeakerButton(voiceId: 'letter_${letter.id}'),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Narrow phones give the letter less room so the title keeps its line.
              LayoutBuilder(
                builder: (context, _) => _BigLetter(
                  text: letter.form(form),
                  size: (MediaQuery.sizeOf(context).width * 0.36).clamp(104.0, 140.0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final f in LetterForm.values) ...[
                if (f != LetterForm.isolated) const SizedBox(width: 6),
                Expanded(child: _FormTile(letter: letter, form: f, selected: f == form, onTap: () => onForm(f))),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _BigLetter extends StatelessWidget {
  const _BigLetter({required this.text, required this.size});
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(color: KidsColors.sun100, shape: BoxShape.circle),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: CustomPaint(painter: const KhatamStarPainter(fill: Color(0x00000000), line: KidsColors.sun300)),
              ),
            ),
          ),
          FittedBox(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(text, textDirection: TextDirection.rtl, style: KidsType.letterStyle(96, color: KidsColors.night800)),
            ),
          ),
        ],
      ),
    ),
  );
}

class _FormTile extends StatelessWidget {
  const _FormTile({required this.letter, required this.form, required this.selected, required this.onTap});

  final ArabicLetter letter;
  final LetterForm form;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final label = switch (form) {
      LetterForm.isolated => l.kidsLettersFormIsolated,
      LetterForm.initial => l.kidsLettersFormInitial,
      LetterForm.medial => l.kidsLettersFormMedial,
      LetterForm.final_ => l.kidsLettersFormFinal,
    };
    final real = letter.hasForm(form);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          children: [
            Opacity(
              opacity: real ? 1 : 0.45,
              child: Container(
                height: 76,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? KidsColors.sun100 : Colors.white,
                  border: Border.all(color: selected ? KidsColors.sun500 : KidsColors.sand2, width: 3),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(letter.form(form), textDirection: TextDirection.rtl, style: KidsType.letterStyle(40).copyWith(height: 1.7)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center, style: KidsType.bodyText(15, color: KidsColors.ink2)),
          ],
        ),
      ),
    );
  }
}

class _WordCard extends StatelessWidget {
  const _WordCard({required this.letter});
  final ArabicLetter letter;

  @override
  Widget build(BuildContext context) {
    final (from, to) = letter.highlight;
    final base = KidsType.letterStyle(56, color: KidsColors.night900);
    return KidsCard(
      child: Row(
        children: [
          Container(
            width: 104,
            height: 104,
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: KidsColors.night100, shape: BoxShape.circle),
            child: LetterPictureView(picture: letter.picture, size: 88),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              label: letter.word,
              excludeSemantics: true,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: letter.word.substring(0, from)),
                      TextSpan(
                        text: letter.word.substring(from, to),
                        style: TextStyle(color: KidsColors.sun700),
                      ),
                      TextSpan(text: letter.word.substring(to)),
                    ],
                  ),
                  textDirection: TextDirection.rtl,
                  style: base,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SpeakerButton(voiceId: 'word_${letter.id}'),
        ],
      ),
    );
  }
}

// ---- tracing --------------------------------------------------------------

class _TraceView extends StatefulWidget {
  const _TraceView({required this.letter, required this.onBack});

  final ArabicLetter letter;
  final VoidCallback onBack;

  @override
  State<_TraceView> createState() => _TraceViewState();
}

class _TraceViewState extends State<_TraceView> {
  final _canvas = GlobalKey<TraceCanvasState>();
  bool _enough = false;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(l.kidsLettersLetterOf(widget.letter.name), style: KidsType.title(28))),
              SpeakerButton(voiceId: 'letter_${widget.letter.id}'),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: TraceCanvas(
                  key: _canvas,
                  glyph: widget.letter.glyph,
                  onEnough: () => setState(() => _enough = true),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (_enough) GoodBanner(text: l.kidsLettersTraceGood) else Text(l.kidsLettersTraceHint, textAlign: TextAlign.center, style: KidsType.bodyText(18, color: KidsColors.ink2)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: KidsButton(
                  label: l.kidsLettersTraceClear,
                  icon: Icons.refresh_rounded,
                  kind: KidsButtonKind.rose,
                  onTap: () {
                    _canvas.currentState?.clear();
                    setState(() => _enough = false);
                  },
                ),
              ),
              const SizedBox(width: 12),
              KidsRoundButton(icon: Icons.home_rounded, semanticLabel: l.kidsLettersBack, onTap: widget.onBack),
            ],
          ),
        ],
      ),
    );
  }
}

// ---- the quiz -------------------------------------------------------------

/// «أي حرف هاد؟»: five questions, three choices each. A miss shows a soft
/// amber retry and the picked choice fades; a hit shows «أحسنت». The round
/// earns one star when it ends.
class LetterQuizView extends ConsumerStatefulWidget {
  const LetterQuizView({super.key, required this.letters, required this.onBack, this.seed});

  final List<ArabicLetter> letters;
  final VoidCallback onBack;
  final int? seed;

  @override
  ConsumerState<LetterQuizView> createState() => _LetterQuizViewState();
}

class _LetterQuizViewState extends ConsumerState<LetterQuizView> {
  late LetterQuizEngine _engine = _newEngine();
  late LetterQuestion _q = _engine.next();
  int _n = 0; // zero-based index of the current question
  final Set<String> _dimmed = {};
  bool _solved = false;
  bool _finished = false;
  bool _retryShown = false;

  LetterQuizEngine _newEngine() =>
      LetterQuizEngine(seed: widget.seed ?? DateTime.now().microsecondsSinceEpoch & 0x7fffffff, letters: widget.letters);

  void _pick(ArabicLetter pick) {
    if (_solved) return;
    if (_q.isCorrect(pick)) {
      setState(() => _solved = true);
    } else {
      setState(() {
        _dimmed.add(pick.id);
        _retryShown = true;
      });
    }
  }

  void _next() {
    if (_n + 1 >= kLetterQuizRound) {
      setState(() => _finished = true);
      ref.read(kidsStarAwardProvider)('letters_quiz');
      return;
    }
    setState(() {
      _n++;
      _q = _engine.next();
      _dimmed.clear();
      _solved = false;
      _retryShown = false;
    });
  }

  void _again() => setState(() {
    _engine = _newEngine();
    _q = _engine.next();
    _n = 0;
    _dimmed.clear();
    _solved = false;
    _finished = false;
    _retryShown = false;
  });

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(l.kidsLettersQuizCta, style: KidsType.title(28))),
              KidsRoundButton(icon: Icons.home_rounded, semanticLabel: l.kidsLettersBack, onTap: widget.onBack),
            ],
          ),
          const SizedBox(height: 10),
          Semantics(
            label: l.kidsLettersQuizProgress(_n + 1, kLetterQuizRound),
            child: ExcludeSemantics(child: _ProgressDots(done: _finished ? kLetterQuizRound : _n, total: kLetterQuizRound)),
          ),
          const SizedBox(height: 14),
          if (_finished) _finishedCard(l) else ..._questionCard(l),
        ],
      ),
    );
  }

  Widget _finishedCard(L10n l) => KidsCard(
    child: Column(
      children: [
        const SizedBox(width: 120, height: 120, child: CustomPaint(painter: KhatamStarPainter())),
        const SizedBox(height: 12),
        Text(l.kidsLettersQuizDone, textAlign: TextAlign.center, style: KidsType.title(26)),
        const SizedBox(height: 16),
        KidsButton(label: l.kidsLettersQuizAgain, kind: KidsButtonKind.teal, onTap: _again),
      ],
    ),
  );

  List<Widget> _questionCard(L10n l) => [
    KidsCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Center(
                  child: ExcludeSemantics(
                    child: SizedBox(
                      height: 130,
                      child: FittedBox(
                        child: Text(_q.target.form(_q.form), textDirection: TextDirection.rtl, style: KidsType.letterStyle(110, color: KidsColors.night800)),
                      ),
                    ),
                  ),
                ),
              ),
              SpeakerButton(voiceId: 'letter_${_q.target.id}'),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final c in _q.choices)
                _ChoiceTile(
                  letter: c,
                  dimmed: _dimmed.contains(c.id),
                  right: _solved && _q.isCorrect(c),
                  onTap: () => _pick(c),
                ),
            ],
          ),
        ],
      ),
    ),
    const SizedBox(height: 14),
    if (_solved)
      GoodBanner(text: l.kidsLettersQuizGood)
    else if (_retryShown)
      SoftRetryBanner(text: l.kidsLettersQuizRetry),
    if (_solved) ...[
      const SizedBox(height: 14),
      KidsButton(label: l.kidsLettersQuizNext, icon: Icons.chevron_right_rounded, onTap: _next),
    ],
  ];
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({required this.letter, required this.dimmed, required this.right, required this.onTap});

  final ArabicLetter letter;
  final bool dimmed;
  final bool right;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: letter.name,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        opacity: dimmed ? 0.45 : 1,
        child: Container(
          width: 88,
          height: 88,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: right ? KidsColors.teal100 : (dimmed ? KidsColors.retryFill : Colors.white),
            border: Border.all(color: right ? KidsColors.teal500 : (dimmed ? KidsColors.retry : KidsColors.sand2), width: 3),
            boxShadow: const [BoxShadow(color: KidsColors.sand2, offset: Offset(0, 3))],
          ),
          child: Text(letter.glyph, textDirection: TextDirection.rtl, style: KidsType.letterStyle(54, color: KidsColors.night900)),
        ),
      ),
    ),
  );
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.done, required this.total});
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < total; i++)
        Container(
          width: 18,
          height: 18,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < done ? KidsColors.sun500 : KidsColors.sand2,
          ),
        ),
    ],
  );
}
