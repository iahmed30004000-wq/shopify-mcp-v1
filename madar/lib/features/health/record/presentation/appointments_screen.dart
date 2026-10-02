import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import 'record_actions.dart';
import 'record_screen.dart' show AppointmentsView;
import 'widgets/health_alerts_banner.dart';

/// Every appointment: upcoming ones (the next lit, with its questions) and
/// the whole past. [highlightId] lights one (from a reminder tap).
class AppointmentsScreen extends ConsumerWidget {
  const AppointmentsScreen({super.key, this.highlightId, this.animateBackdrop = true});

  final String? highlightId;
  final bool animateBackdrop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final actions = RecordActions(context, ref);
    return MadarScaffold(
      title: l.recordAppointmentsTitle,
      backdropSeed: 5.3,
      animateBackdrop: animateBackdrop,
      floatingAction: MadarButton.icon(
        icon: Icons.add_rounded,
        onPressed: actions.addAppointment,
        semanticLabel: l.recordAppointmentAdd,
        variant: MadarButtonVariant.primary,
        size: MadarButtonSize.large,
        sfx: Sfx.sheetOpen,
      ),
      body: EntranceChoreo(
        id: 'appointments',
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, 110),
          children: [
            const StaggerItem(
              index: 0,
              child: HealthAlertsBanner(padding: EdgeInsets.only(bottom: Space.s), maxVisible: 2, dense: true),
            ),
            StaggerItem(index: 1, child: AppointmentsView(showAll: true, highlightId: highlightId)),
          ],
        ),
      ),
    );
  }
}
