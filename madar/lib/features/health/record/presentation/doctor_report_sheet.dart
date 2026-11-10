import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/interaction/sheets/field_inputs.dart' show FieldShell, kitInputDecoration;
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../data/doctor_report.dart';
import '../data/record_providers.dart';
import '../domain/report_model.dart';
import 'record_ui.dart';

/// Opens [DoctorReportSheet].
Future<void> showDoctorReportSheet(BuildContext context) =>
    showInteractionSheet<void>(context, builder: (_) => const DoctorReportSheet());

/// The doctor report dialog: a name for the header (printed only – kept on
/// the device only if "remember" is on), the period, the sections; then an
/// A4 PDF in the app language is built on the device and shared or saved.
class DoctorReportSheet extends ConsumerStatefulWidget {
  const DoctorReportSheet({super.key});

  @override
  ConsumerState<DoctorReportSheet> createState() => _DoctorReportSheetState();
}

enum _Busy { share, save }

class _DoctorReportSheetState extends ConsumerState<DoctorReportSheet> {
  late final TextEditingController _name;
  late bool _remember;
  late ReportPeriod _period;
  late Set<ReportSection> _sections;
  _Busy? _busy;
  String? _status;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(recordSettingsValueProvider);
    _name = TextEditingController(text: s.reportName ?? '');
    _remember = s.reportName != null;
    _period = s.reportPeriod;
    _sections = {...s.sectionsOrDefault};
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  static IconData _icon(ReportSection s) => switch (s) {
    ReportSection.alerts => RecordIcons.alert,
    ReportSection.conditions => RecordIcons.conditions,
    ReportSection.medications => Icons.medication_outlined,
    ReportSection.labs => RecordIcons.labs,
    ReportSection.pain => Icons.healing_outlined,
    ReportSection.mood => Icons.self_improvement_rounded,
    ReportSection.questions => RecordIcons.questions,
  };

  Future<DoctorReportFile?> _build() async {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final service = ref.read(recordServiceProvider);
    final settings = ref.read(recordSettingsValueProvider);
    final name = _name.text.trim();
    // The name is stored only when the user asked for it.
    final next = settings.copyWith(
      reportSections: _sections,
      reportPeriod: _period,
      reportName: _remember && name.isNotEmpty ? name : null,
      clearReportName: !_remember || name.isEmpty,
    );
    if (next != settings) await service.saveSettings(next);
    return ref
        .read(doctorReportBuilderProvider)
        .build(
          DoctorReportRequest(
            sections: _sections,
            period: _period,
            now: ref.read(recordClockProvider)(),
            patientName: name.isEmpty ? null : name,
            languageCode: lang == 'ar' ? 'ar' : 'en',
          ),
          l: l,
          fmt: fmt,
          margin: settings.borderlineMargin,
        );
  }

  Future<void> _run(_Busy kind) async {
    if (_busy != null || _sections.isEmpty) return;
    final l = L10n.of(context);
    setState(() {
      _busy = kind;
      _status = null;
      _failed = false;
    });
    try {
      final file = await _build();
      if (file == null || !mounted) return;
      final exporter = ref.read(reportExporterProvider);
      if (kind == _Busy.share) {
        await exporter.share(file, subject: l.recordReportTitle);
        Fx.fire(Sfx.complete);
        if (mounted) Navigator.of(context).maybePop();
        return;
      }
      final saved = await exporter.save(file);
      if (!mounted) return;
      if (saved) Fx.fire(Sfx.complete);
      setState(() => _status = saved ? l.recordReportSaved : null);
    } catch (e) {
      debugPrint('doctor report: $e');
      Fx.fire(Sfx.error);
      if (mounted) {
        setState(() {
          _status = l.recordReportFailed;
          _failed = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final texts = context.recordTexts;
    return InteractionSheetFrame(
      title: l.recordDoctorReport,
      subtitle: l.recordReportSheetSubtitle,
      icon: RecordIcons.report,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FieldShell(
            label: l.recordReportNameField,
            icon: Icons.badge_outlined,
            optional: true,
            child: TextField(
              controller: _name,
              textInputAction: TextInputAction.done,
              maxLength: 60,
              decoration: kitInputDecoration(context, hint: l.recordReportNameHint),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: Space.xs, bottom: Space.m),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.recordReportRememberName, style: text.bodyMedium),
                      Text(l.recordReportRememberHint, style: text.bodySmall!.copyWith(color: t.textTertiary)),
                    ],
                  ),
                ),
                const SizedBox(width: Space.m),
                MadarSwitch(
                  value: _remember,
                  semanticLabel: l.recordReportRememberName,
                  onChanged: (v) => setState(() => _remember = v),
                ),
              ],
            ),
          ),
          FieldShell(
            label: l.recordReportPeriodField,
            icon: Icons.date_range_outlined,
            child: ChoicePills<ReportPeriod>.single(
              options: [for (final p in ReportPeriod.values) ChoiceOption(value: p, label: texts.reportPeriod(p))],
              selected: _period,
              onChanged: (p) => setState(() => _period = p ?? _period),
              dense: true,
            ),
          ),
          const SizedBox(height: Space.m),
          FieldShell(
            label: l.recordReportSectionsField,
            icon: Icons.checklist_rounded,
            child: ChoicePills<ReportSection>.multi(
              options: [
                for (final s in ReportSection.values) ChoiceOption(value: s, label: texts.section(s), icon: _icon(s)),
              ],
              selected: _sections,
              minSelected: 1,
              onChanged: (s) => setState(() => _sections = s),
              dense: true,
            ),
          ),
          const SizedBox(height: Space.l),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline_rounded, size: 16, color: t.textTertiary),
              const SizedBox(width: Space.s),
              Expanded(
                child: Text(l.recordReportPrivacyNote, style: text.bodySmall!.copyWith(color: t.textTertiary)),
              ),
            ],
          ),
          AnimatedSize(
            duration: context.motion(MadarMotion.short),
            child: _status == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: Space.m),
                    child: Row(
                      children: [
                        Icon(
                          _failed ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                          size: 18,
                          color: _failed ? t.danger : t.success,
                        ),
                        const SizedBox(width: Space.s),
                        Expanded(
                          child: Text(
                            _status!,
                            style: text.bodyMedium!.copyWith(color: _failed ? t.danger : t.success),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      footer: _busy != null
          ? SizedBox(
              height: 52,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const OrbitLoader(size: 26),
                  const SizedBox(width: Space.m),
                  Text(l.recordReportBuilding, style: text.bodyMedium),
                ],
              ),
            )
          : Row(
              children: [
                Expanded(
                  child: SheetButton(
                    label: l.recordReportSave,
                    icon: Icons.download_rounded,
                    enabled: _sections.isNotEmpty,
                    onPressed: () => _run(_Busy.save),
                  ),
                ),
                const SizedBox(width: Space.s),
                Expanded(
                  child: SheetButton(
                    label: l.recordReportShare,
                    icon: Icons.ios_share_rounded,
                    primary: true,
                    enabled: _sections.isNotEmpty,
                    onPressed: () => _run(_Busy.share),
                  ),
                ),
              ],
            ),
    );
  }
}
