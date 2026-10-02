import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/tokens.dart';
import '../../core/design/widgets/widgets.dart';
import '../../core/i18n/gen/app_localizations.dart';
import '../../core/motion/motion_kit.dart';
import '../../core/settings/app_settings.dart';
import '../lock/presentation/security_settings.dart';
import 'widgets/settings_widgets.dart';

/// Settings › Security (`/settings/security`): the app lock – PIN,
/// fingerprint, how long Madar may stay in the background before it locks –
/// and a word on what the lock protects.
class SecuritySettingsScreen extends ConsumerWidget {
  const SecuritySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final saver = ref.watch(appSettingsProvider.select((s) => s.powerMode == PowerMode.batterySaver));
    return MadarScaffold(
      title: l.settingsSecuritySection,
      extendBodyBehindAppBar: true,
      animateBackdrop: !saver,
      backdropSeed: 0.41,
      body: SettingsListView(
        horizontal: Space.gutter,
        top: Space.xs,
        children: [
          StaggerIn(
            id: 'settings-security',
            fade: false,
            children: [
              const SecuritySettingsSection(seed: 0.45, showTitle: false),
              SettingsNote(l.settingsSecurityNote, icon: Icons.shield_moon_rounded),
            ],
          ),
        ],
      ),
    );
  }
}
