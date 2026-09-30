import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion.dart';
import '../../../core/sound/sound_api.dart';
import '../data/data_providers.dart';
import '../data/data_repository.dart';
import '../domain/ai_summary.dart';
import '../domain/ai_summary_builder.dart';
import '../domain/summary_input.dart';
import 'widgets/data_widgets.dart';
import 'widgets/file_panel.dart';

/// What the preview's main button does.
enum ExportPreviewMode {
  /// Copy / save / share the Markdown file.
  share,

  /// Return the reviewed Markdown to the caller (e.g. an AI chat that sends
  /// it only after this review).
  select,
}

/// Opens the AI-ready summary preview. In [ExportPreviewMode.select] the
/// future completes with the exact Markdown the user approved (null when
/// dismissed); in share mode it completes with null.
Future<String?> showExportPreviewSheet(
  BuildContext context, {
  ExportPreviewMode mode = ExportPreviewMode.share,
  String? confirmLabel,
}) => showInteractionSheet<String>(
  context,
  builder: (_) => ExportPreviewSheet(mode: mode, confirmLabel: confirmLabel),
);

/// Builds the summary on the device and shows exactly what would go out,
/// with a switch per section, the profile basics the user opts into, and a
/// size estimate. Choices are remembered (in the encrypted database).
class ExportPreviewSheet extends ConsumerStatefulWidget {
  const ExportPreviewSheet({super.key, this.mode = ExportPreviewMode.share, this.confirmLabel, this.input});

  final ExportPreviewMode mode;

  /// Label of the select-mode button (defaults to "Use this summary").
  final String? confirmLabel;

  /// Pre-loaded input (tests / screenshots); otherwise read from the database.
  final SummaryInput? input;

  @override
  ConsumerState<ExportPreviewSheet> createState() => _ExportPreviewSheetState();
}

class _ExportPreviewSheetState extends ConsumerState<ExportPreviewSheet> {
  AiSummaryOptions? _options;
  final _about = TextEditingController();
  Timer? _saveTimer;
  String? _notice;

  // Memoised summary (rebuilt only when its inputs change).
  AiSummary? _summary;
  Object? _summaryKey;

  late final DataExportRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(dataExportRepositoryProvider);
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    AiSummaryOptions options;
    try {
      options = await _repo.summaryOptions();
    } catch (_) {
      options = const AiSummaryOptions();
    }
    if (!mounted) return;
    _about.text = options.profile.aboutMe;
    setState(() => _options = options);
  }

  @override
  void dispose() {
    // Flush a pending (debounced) save of the "about me" note.
    if (_saveTimer?.isActive ?? false) {
      _saveTimer!.cancel();
      final o = _options;
      if (o != null) unawaited(_persist(o));
    }
    _about.dispose();
    super.dispose();
  }

  Future<void> _persist(AiSummaryOptions o) async {
    try {
      await _repo.saveSummaryOptions(o);
    } catch (_) {}
  }

  void _update(AiSummaryOptions o, {bool debounce = false}) {
    setState(() {
      _options = o;
      _notice = null;
    });
    _saveTimer?.cancel();
    if (debounce) {
      _saveTimer = Timer(const Duration(milliseconds: 600), () => _persist(o));
    } else {
      unawaited(_persist(o));
    }
  }

  AiSummary _summaryFor(SummaryInput input, AiSummaryOptions o, L10n l, String lang) {
    final key = (input, o.profile, lang);
    if (_summary == null || _summaryKey != key) {
      _summary = AiSummaryBuilder(l, languageCode: lang).build(input, profile: o.profile);
      _summaryKey = key;
    }
    return _summary!;
  }

  Future<void> _deliver(String markdown, DataDelivery? how) async {
    final l = L10n.of(context);
    final bridge = ref.read(dataFileBridgeProvider);
    try {
      if (how == null) {
        await bridge.copyText(markdown);
        Fx.fire(Sfx.complete);
        if (mounted) setState(() => _notice = l.dataSummaryCopied);
        return;
      }
      final file = DataExportRepository.summaryFile(markdown, ref.read(dataClockProvider)());
      final ok = how == DataDelivery.shared ? await bridge.share(file, subject: l.dataExportSummaryTitle) : await bridge.save(file);
      if (ok) {
        Fx.fire(Sfx.complete);
        if (mounted) setState(() => _notice = how == DataDelivery.shared ? l.dataFileShared : l.dataFileSaved);
      }
    } catch (_) {
      Fx.fire(Sfx.error);
      if (mounted) setState(() => _notice = l.dataFileSendFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final fmt = context.formatter;
    final text = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;
    final options = _options;
    final provided = widget.input;
    final AsyncValue<SummaryInput> input = provided != null ? AsyncData(provided) : ref.watch(summaryInputProvider);

    final ready = options != null && input.hasValue;
    final summary = ready ? _summaryFor(input.requireValue, options, l, lang) : null;
    final markdown = summary?.compose(options!.included) ?? '';
    final selected = summary?.selected(options!.included) ?? const <SummarySection>[];
    final available = summary?.sections.where((s) => !s.isEmpty).length ?? 0;

    Widget body;
    if (input.hasError) {
      body = DataNote(text: l.dataExportFailed, icon: Icons.error_outline_rounded, color: t.danger);
    } else if (!ready) {
      body = DataBusy(title: l.dataSummaryPreparing);
    } else {
      final bytes = AiSummary.byteSize(markdown);
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          DataNote(text: l.dataSummaryIntro, icon: Icons.shield_moon_outlined, color: t.accent),
          const SizedBox(height: Space.m),
          Wrap(
            spacing: Space.s,
            runSpacing: Space.s,
            children: [
              _Pill(icon: Icons.straighten_rounded, label: formatDataSize(l, fmt, bytes)),
              _Pill(icon: Icons.token_outlined, label: l.dataSummaryTokens(fmt.formatInt(AiSummary.estimateTokens(markdown)))),
              _Pill(
                icon: Icons.checklist_rounded,
                label: l.dataSummarySectionsOf(fmt.formatInt(selected.length), fmt.formatInt(available)),
              ),
            ],
          ),
          const SizedBox(height: Space.l),
          Text(l.dataSummarySections, style: text.labelLarge!.copyWith(color: t.textSecondary)),
          const SizedBox(height: Space.s),
          DataGroup(
            children: [
              for (final s in summary!.sections)
                _SectionToggle(
                  section: s,
                  on: options.included.contains(s.id),
                  subtitle: s.isEmpty
                      ? (s.id == SummarySectionId.profile ? l.dataSummaryProfileHint : l.dataSummaryNoData)
                      : l.dataSummaryTokens(fmt.formatInt(AiSummary.estimateTokens(s.markdown))),
                  enabled: !s.isEmpty || s.id == SummarySectionId.profile,
                  onChanged: (v) => _update(options.toggle(s.id, v)),
                  extra: s.id == SummarySectionId.profile && options.included.contains(s.id)
                      ? _ProfileOptions(
                          options: options.profile,
                          place: input.requireValue.place,
                          language: lang,
                          about: _about,
                          onChanged: (p, {bool debounce = false}) => _update(options.withProfile(p), debounce: debounce),
                        )
                      : null,
                ),
            ],
          ),
          const SizedBox(height: Space.l),
          Row(
            children: [
              Expanded(child: Text(l.dataSummaryPreviewTitle, style: text.labelLarge!.copyWith(color: t.textSecondary))),
              Icon(Icons.visibility_rounded, size: 16, color: t.textTertiary),
            ],
          ),
          const SizedBox(height: Space.s),
          Container(
            padding: const EdgeInsetsDirectional.all(Space.m),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(t.radiusM),
              color: t.space0.withValues(alpha: t.isDark ? 0.42 : 0.55),
              border: Border.all(color: t.glassBorder.withValues(alpha: 0.7), width: 0.8),
            ),
            child: SelectableText(
              markdown.trimRight(),
              style: text.bodySmall!.copyWith(color: t.textPrimary, height: 1.55, fontSize: 12.5),
            ),
          ),
          if (_notice != null) ...[
            const SizedBox(height: Space.m),
            DataNote(
              text: _notice!,
              icon: _notice == l.dataFileSendFailed ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: _notice == l.dataFileSendFailed ? t.danger : t.success,
              dense: true,
            ),
          ],
        ],
      );
    }

    final canSend = ready && selected.isNotEmpty;
    final Widget? footer = !ready
        ? null
        : widget.mode == ExportPreviewMode.select
        ? SheetButton(
            label: widget.confirmLabel ?? l.dataSummaryUse,
            icon: Icons.check_rounded,
            primary: true,
            enabled: canSend,
            onPressed: () => Navigator.of(context).pop(markdown),
          )
        : Row(
            children: [
              SheetButton(
                label: l.dataCopyAction,
                icon: Icons.copy_rounded,
                enabled: canSend,
                onPressed: () => _deliver(markdown, null),
              ),
              const SizedBox(width: Space.s),
              Expanded(
                child: SheetButton(
                  label: l.dataSaveAction,
                  icon: Icons.save_alt_rounded,
                  enabled: canSend,
                  onPressed: () => _deliver(markdown, DataDelivery.saved),
                ),
              ),
              const SizedBox(width: Space.s),
              Expanded(
                child: SheetButton(
                  label: l.dataShareAction,
                  icon: Icons.ios_share_rounded,
                  primary: true,
                  enabled: canSend,
                  onPressed: () => _deliver(markdown, DataDelivery.shared),
                ),
              ),
            ],
          );

    return InteractionSheetFrame(
      title: l.dataExportSummaryTitle,
      subtitle: l.dataSummarySubtitle,
      icon: Icons.auto_awesome_rounded,
      body: AnimatedSwitcher(
        duration: context.motion(MadarMotion.medium),
        child: KeyedSubtree(key: ValueKey(ready), child: body),
      ),
      footer: footer,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.m, vertical: Space.xs + 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        color: t.accent.withValues(alpha: 0.1),
        border: Border.all(color: t.accent.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: t.accent),
          const SizedBox(width: Space.xs),
          Text(label, style: Theme.of(context).textTheme.labelMedium!.copyWith(color: t.textPrimary)),
        ],
      ),
    );
  }
}

class _SectionToggle extends StatelessWidget {
  const _SectionToggle({
    required this.section,
    required this.on,
    required this.subtitle,
    required this.enabled,
    required this.onChanged,
    this.extra,
  });

  final SummarySection section;
  final bool on;
  final String subtitle;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final Widget? extra;

  static IconData iconOf(SummarySectionId id) => switch (id) {
    SummarySectionId.profile => Icons.person_outline_rounded,
    SummarySectionId.faith => Icons.mosque_outlined,
    SummarySectionId.health => Icons.favorite_border_rounded,
    SummarySectionId.money => Icons.account_balance_wallet_outlined,
    SummarySectionId.family => Icons.diversity_3_rounded,
    SummarySectionId.work => Icons.work_outline_rounded,
    SummarySectionId.growth => Icons.spa_outlined,
    SummarySectionId.body => Icons.fitness_center_rounded,
    SummarySectionId.travel => Icons.flight_takeoff_rounded,
    SummarySectionId.custom => Icons.dashboard_customize_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final active = enabled && on;
    return AnimatedOpacity(
      duration: context.motion(MadarMotion.short),
      opacity: enabled ? 1 : 0.5,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.s, Space.m, Space.s),
            child: Row(
              children: [
                DataIconBadge(iconOf(section.id), size: 34, color: active ? t.accent : t.textTertiary),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(section.title, style: text.titleSmall!.copyWith(color: t.textPrimary)),
                      Text(subtitle, style: text.bodySmall!.copyWith(color: t.textTertiary)),
                    ],
                  ),
                ),
                MadarSwitch(
                  value: active,
                  semanticLabel: section.title,
                  onChanged: enabled ? onChanged : null,
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: context.motion(MadarMotion.medium),
            curve: MadarMotion.emphasized,
            alignment: AlignmentDirectional.topCenter,
            child: extra == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(Space.l, 0, Space.l, Space.m),
                    child: extra,
                  ),
          ),
        ],
      ),
    );
  }
}

enum _ProfileItem { city, timeZone, currency, language }

class _ProfileOptions extends StatelessWidget {
  const _ProfileOptions({
    required this.options,
    required this.place,
    required this.language,
    required this.about,
    required this.onChanged,
  });

  final SummaryProfileOptions options;
  final SummaryPlace place;
  final String language;
  final TextEditingController about;
  final void Function(SummaryProfileOptions options, {bool debounce}) onChanged;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final city = place.cityFor(language);
    final selected = {
      if (options.city) _ProfileItem.city,
      if (options.timeZone) _ProfileItem.timeZone,
      if (options.currency) _ProfileItem.currency,
      if (options.language) _ProfileItem.language,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l.dataProfileChoose, style: text.bodySmall!.copyWith(color: t.textSecondary)),
        const SizedBox(height: Space.s),
        ChoicePills<_ProfileItem>.multi(
          dense: true,
          options: [
            if (city != null) ChoiceOption(value: _ProfileItem.city, label: '${l.dataSumCity}: $city'),
            if (place.timeZone != null) ChoiceOption(value: _ProfileItem.timeZone, label: l.dataSumTimeZone),
            ChoiceOption(value: _ProfileItem.currency, label: l.dataSumBaseCurrency),
            ChoiceOption(value: _ProfileItem.language, label: l.dataSumLanguage),
          ],
          selected: selected,
          onChanged: (s) => onChanged(
            options.copyWith(
              city: s.contains(_ProfileItem.city),
              timeZone: s.contains(_ProfileItem.timeZone),
              currency: s.contains(_ProfileItem.currency),
              language: s.contains(_ProfileItem.language),
            ),
          ),
        ),
        const SizedBox(height: Space.m),
        TextField(
          controller: about,
          minLines: 1,
          maxLines: 3,
          maxLength: 280,
          style: text.bodyMedium!.copyWith(color: t.textPrimary),
          cursorColor: t.accent,
          decoration: dataInputDecoration(context, label: l.dataSumAboutMe, hint: l.dataProfileAboutHint),
          onChanged: (v) => onChanged(options.copyWith(aboutMe: v), debounce: true),
        ),
      ],
    );
  }
}
