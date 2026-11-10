// «التسميع» for a child (designs 04a / 04b): UI over the pure rule in
// domain/recitation_check.dart.
//
// Colours: soft amber for "again", teal for "well done". There is no red, no
// cross and no count of tries anywhere on this screen: the child may tap «عيد»
// ten times and nothing changes but the next chance.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../core/kids_section.dart' show kidsStarCountProvider;
import '../domain/recitation_check.dart';
import '../domain/word_highlight.dart';
import 'widgets/kids_faith_ui.dart';

class KidsRecitationScreen extends ConsumerWidget {
  const KidsRecitationScreen({super.key, required this.ayahKey, required this.ayahText});

  /// 'surah:ayah'.
  final String ayahKey;

  /// The ayah as written in the bundled Tanzil text.
  final String ayahText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final hasEngine = ref.watch(kidsRecitationCheckerProvider) != null;
    final target = (ayahKey, ayahText);
    final phase = ref.watch(kidsRecitationControllerProvider(target));
    final ctrl = ref.read(kidsRecitationControllerProvider(target).notifier);
    final stars = ref.watch(kidsStarCountProvider);
    final well = phase == KidsRecitationPhase.wellDone;

    return KidsFaithScaffold(
      title: l.kidsFaithTryYourself,
      background: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [KP.night100, KP.paper],
        ),
      ),
      child: !hasEngine
          ? const KidsSoonState()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(color: KP.paper, borderRadius: BorderRadius.circular(32)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final w in ayahWords(ayahText))
                          // Never marks a word wrong: all neutral, all teal once heard well.
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: well ? KP.teal100 : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              w,
                              style: TextStyle(
                                fontFamily: KP.quran,
                                fontSize: 28,
                                height: 1.8,
                                color: well ? KP.teal700 : KP.ink,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (well)
                  const Center(
                    child: KhatamBadge(
                      size: 120,
                      color: KP.teal500,
                      child: Icon(Icons.check_rounded, size: 56, color: KP.night900),
                    ),
                  )
                else
                  Center(
                    child: Semantics(
                      button: true,
                      label: phase == KidsRecitationPhase.listening ? l.kidsFaithListening : l.kidsFaithTapToSpeak,
                      excludeSemantics: true,
                      child: Material(
                        color: KP.retry,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: ctrl.listen,
                          child: SizedBox(
                            width: 120,
                            height: 120,
                            child: Icon(
                              phase == KidsRecitationPhase.listening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                              size: 56,
                              color: KP.night900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                if (phase == KidsRecitationPhase.idle || phase == KidsRecitationPhase.listening)
                  Center(
                    child: Text(
                      phase == KidsRecitationPhase.listening ? l.kidsFaithListening : l.kidsFaithTapToSpeak,
                      style: const TextStyle(fontFamily: KP.body, fontSize: 20, color: KP.ink2),
                    ),
                  ),
                if (phase == KidsRecitationPhase.tryAgain) ...[
                  _FeedbackCard(
                    title: l.kidsFaithSoftRetryTitle,
                    body: l.kidsFaithSoftRetryBody,
                    fill: KP.retryFill,
                    border: KP.retry,
                    text: KP.retryText,
                  ),
                  const SizedBox(height: 16),
                  KidsBigButton(label: l.kidsFaithAgain, icon: Icons.replay_rounded, onPressed: ctrl.listen),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      l.kidsFaithStarsSafe,
                      style: const TextStyle(fontFamily: KP.body, fontSize: 16, color: KP.ink2),
                    ),
                  ),
                ],
                if (well) ...[
                  _FeedbackCard(
                    title: l.kidsFaithWellDoneTitle,
                    body: l.kidsFaithWellDoneBody,
                    fill: KP.teal100,
                    border: KP.teal500,
                    text: KP.teal700,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: KidsBigButton(
                          label: l.kidsFaithNextAyah,
                          tone: KidsButtonTone.teal,
                          onPressed: () => Navigator.of(context).maybePop(true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      KidsRoundButton(icon: Icons.replay_rounded, label: l.kidsFaithAgain, onPressed: ctrl.listen),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      l.kidsFaithStarNow(fmt.formatInt(stars)),
                      style: const TextStyle(
                        fontFamily: KP.body,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: KP.night800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.title,
    required this.body,
    required this.fill,
    required this.border,
    required this.text,
  });

  final String title;
  final String body;
  final Color fill;
  final Color border;
  final Color text;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: border, width: 4),
        borderRadius: BorderRadius.circular(32),
      ),
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: KP.heading, fontSize: 34, color: text),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: KP.body, fontSize: 20, height: 1.5, color: KP.ink),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
