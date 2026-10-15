import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/interaction/sheets/field_inputs.dart';
import '../../../core/motion/motion_kit.dart';
import '../domain/family_models.dart';
import '../family_texts.dart';
import 'widgets/family_sheet_frame.dart';

/// Opens the reach-out reminder settings; returns the new settings (null
/// when cancelled).
Future<FamilySettings?> showFamilySettingsSheet(BuildContext context, {required FamilySettings settings}) =>
    showInteractionSheet<FamilySettings>(context, builder: (_) => FamilySettingsSheet(settings: settings));

/// The daily digest (on/off + time) and birthday reminders (on/off + time).
class FamilySettingsSheet extends StatefulWidget {
  const FamilySettingsSheet({super.key, required this.settings});

  final FamilySettings settings;

  @override
  State<FamilySettingsSheet> createState() => _FamilySettingsSheetState();
}

class _FamilySettingsSheetState extends State<FamilySettingsSheet> {
  late FamilySettings _s = widget.settings;

  static String _hm(int minutes) => ClockTime.format(minutes ~/ 60, minutes % 60);

  static int _minutes(String hm) {
    final p = hm.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final tx = FamilyTexts.of(context);

    Widget section({
      required IconData icon,
      required String title,
      required String hint,
      required bool on,
      required ValueChanged<bool> onToggle,
      required String timeLabel,
      required int minutes,
      required ValueChanged<int> onTime,
    }) {
      final t = context.tokens;
      final text = Theme.of(context).textTheme;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: t.accent),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleMedium),
                    Text(hint, style: text.bodySmall!.copyWith(color: t.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: Space.s),
              GlassSwitch(value: on, onChanged: onToggle, semanticLabel: title),
            ],
          ),
          AnimatedSize(
            duration: context.motion(MadarMotion.medium),
            curve: MadarMotion.standard,
            alignment: AlignmentDirectional.topStart,
            child: !on
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsetsDirectional.only(top: Space.m),
                    child: FieldShell(
                      label: timeLabel,
                      icon: Icons.schedule_rounded,
                      trailing: Text(tx.clock(minutes), style: text.labelMedium!.copyWith(color: t.accent)),
                      child: TimeWheel(value: _hm(minutes), minuteStep: 5, onChanged: (v) => onTime(_minutes(v))),
                    ),
                  ),
          ),
        ],
      );
    }

    return FamilySheetFrame(
      title: l.familyRemindersTitle,
      icon: Icons.notifications_active_rounded,
      saveLabel: l.familySave,
      dirty: _s != widget.settings,
      onSave: () => Navigator.of(context).pop(_s),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          section(
            icon: Icons.volunteer_activism_rounded,
            title: l.familyDigestTitle,
            hint: l.familyDigestHint,
            on: _s.digestEnabled,
            onToggle: (v) => setState(() => _s = _s.copyWith(digestEnabled: v)),
            timeLabel: l.familyDigestTime,
            minutes: _s.digestMinutes,
            onTime: (m) => setState(() => _s = _s.copyWith(digestMinutes: m)),
          ),
          const SizedBox(height: Space.xl),
          section(
            icon: Icons.cake_rounded,
            title: l.familyBirthdayReminders,
            hint: l.familyBirthdayRemindersHint,
            on: _s.birthdaysEnabled,
            onToggle: (v) => setState(() => _s = _s.copyWith(birthdaysEnabled: v)),
            timeLabel: l.familyBirthdayTime,
            minutes: _s.birthdayMinutes,
            onTime: (m) => setState(() => _s = _s.copyWith(birthdayMinutes: m)),
          ),
        ],
      ),
    );
  }
}
