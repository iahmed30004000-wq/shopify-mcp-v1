/// «شازام القرآن», typed · he writes a phrase, Madar says where it is
/// (Part 13's engine, Part 14's screen).
///
/// Part 13's [ReciteIndex] works on **text**, not on sound: the recogniser
/// it was built for only turns a voice into words. So the whole feature
/// already works tonight, with the keyboard instead of the microphone, and
/// it works **offline** – the index is built once over the app's own
/// verified text.
///
/// The engine's honesty is kept whole here:
///
/// * one ayah and sure → it is named;
/// * several fit equally well (مثل «فَبِأَىِّ آلَآءِ رَبِّكُمَا تُكَذِّبَانِ»)
///   → **all of them** are offered, never a guess;
/// * nothing found → it says so and invents nothing;
/// * fewer than three words → it says two words are everywhere.
///
/// What he typed is **his**, and is shown as his: labelled, in a different
/// face, never as Quran text. The ayah itself is drawn from the verified
/// text that came back from the index.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/sound/sound_api.dart';
import '../../../quran/data/quran_providers.dart' show quranMetaProvider, quranTextProvider;
import '../../../wird/data/wird_providers.dart' show quranCatalogReadyProvider;
import '../../../tasmee/tasmee.dart';
import 'hifz_plan_nav.dart';
import 'hifz_plan_texts.dart';
import 'hifz_plan_widgets.dart';

/// Type a phrase, be told where it is – offline, on his own phone.
class HifzFindScreen extends ConsumerStatefulWidget {
  const HifzFindScreen({super.key, this.initialQuery = '', this.animateBackdrop = true});

  final String initialQuery;
  final bool animateBackdrop;

  @override
  ConsumerState<HifzFindScreen> createState() => _HifzFindScreenState();
}

class _HifzFindScreenState extends ConsumerState<HifzFindScreen> {
  late final TextEditingController _query = TextEditingController(text: widget.initialQuery);
  ReciteFindResult? _result;
  bool _searching = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final phrase = _query.text.trim();
    if (phrase.isEmpty) return;
    Fx.fire(Sfx.tap);
    setState(() => _searching = true);
    try {
      final index = await ref.read(reciteIndexProvider.future);
      if (!mounted) return;
      setState(() {
        _result = index.find(phrase);
        _searching = false;
      });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final texts = HifzPlanTexts.of(context, catalog: ref.watch(quranCatalogReadyProvider).value);
    final result = _result;
    return MadarScaffold(
      title: l.hifzFindTypedTitle,
      backdropSeed: 5.1,
      animateBackdrop:
          widget.animateBackdrop &&
          ref.watch(appSettingsProvider.select((s) => s.powerMode != PowerMode.batterySaver)),
      body: ListView(
        key: const PageStorageKey('hifz.find'),
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xxxl),
        children: [
          HifzPanel(
            key: const ValueKey('hifz.find.box'),
            title: l.hifzFindTypedTitle,
            icon: Icons.travel_explore_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.hifzFindTypedBody,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textSecondary),
                ),
                const SizedBox(height: Space.m),
                TextField(
                  key: const ValueKey('hifz.find.field'),
                  controller: _query,
                  textDirection: TextDirection.rtl,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: l.hifzFindTypedHint,
                    labelText: l.hifzWritingYours,
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                  onSubmitted: (_) => unawaited(_search()),
                ),
                const SizedBox(height: Space.m),
                MadarButton(
                  key: const ValueKey('hifz.find.search'),
                  label: l.hifzFindSearch,
                  icon: Icons.search_rounded,
                  loading: _searching,
                  onPressed: () => unawaited(_search()),
                ),
                const SizedBox(height: Space.s),
                Text(
                  l.tasmeeOfflineNote,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textTertiary),
                ),
              ],
            ),
          ),
          if (result != null) ...[
            const SizedBox(height: Space.m),
            _Verdict(result: result),
            for (final place in result.places)
              Padding(
                padding: const EdgeInsets.only(top: Space.s),
                child: _PlaceCard(place: place, texts: texts),
              ),
          ],
          const HifzHonestyNote(),
        ],
      ),
    );
  }
}

/// What the engine is willing to say – and nothing more.
class _Verdict extends StatelessWidget {
  const _Verdict({required this.result});

  final ReciteFindResult result;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final fmt = MadarFormatter.of(context);
    final (line, icon, color) = switch (result.confidence) {
      ReciteConfidence.sure => (l.tasmeeFindSure, Icons.check_circle_outline_rounded, t.success),
      ReciteConfidence.several => (l.tasmeeFindSeveral, Icons.list_alt_rounded, t.accent),
      ReciteConfidence.unsure => (l.tasmeeFindUnsure, Icons.help_outline_rounded, t.warning),
      ReciteConfidence.none => (l.tasmeeFindNone, Icons.search_off_rounded, t.textSecondary),
      ReciteConfidence.tooShort => (l.tasmeeFindTooShort, Icons.short_text_rounded, t.warning),
    };
    return HifzPanel(
      key: ValueKey('hifz.find.verdict.${result.confidence.name}'),
      title: line,
      icon: icon,
      iconColor: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (result.places.isNotEmpty)
            Text(
              fmt.localizeDigits(l.tasmeeFindCandidates(result.total)),
              key: const ValueKey('hifz.find.count'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textSecondary),
            ),
          if (result.heardPhrase.trim().isNotEmpty) ...[
            const SizedBox(height: Space.s),
            HifzTypedAnswer(text: result.heardPhrase.trim()),
          ],
        ],
      ),
    );
  }
}

/// One place the phrase might be: the surah and the ayah, the verified
/// words that matched, and the way into the mushaf.
class _PlaceCard extends ConsumerWidget {
  const _PlaceCard({required this.place, required this.texts});

  final RecitePlace place;
  final HifzPlanTexts texts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final fmt = MadarFormatter.of(context);
    final text = ref.watch(quranTextProvider).value;
    final meta = ref.watch(quranMetaProvider).value;
    // The verified ayah text, exactly as the app's own data holds it.
    final ayah = (text == null || meta == null) ? null : text.ayahText(meta.indexOf(place.ref));
    return HifzPanel(
      key: ValueKey('hifz.find.place.${place.ref}'),
      title: texts.ayahRef(place.ref),
      subtitle: fmt.localizeDigits(l.hifzFindMatchedWords(place.matchedWords)),
      icon: Icons.menu_book_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ayah != null)
            Text(
              ayah,
              key: ValueKey('hifz.find.text.${place.ref}'),
              textAlign: TextAlign.center,
              style: MadarTypography.quran(t, size: 22),
            ),
          const SizedBox(height: Space.m),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: MadarButton(
              key: ValueKey('hifz.find.open.${place.ref}'),
              label: l.hifzFindOpenInMushaf,
              icon: Icons.chevron_right_rounded,
              size: MadarButtonSize.small,
              variant: MadarButtonVariant.secondary,
              onPressed: () => hifzOpenAyah(context, ref, place.ref),
            ),
          ),
        ],
      ),
    );
  }
}
