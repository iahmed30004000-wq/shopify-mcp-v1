import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/tokens.dart';
import '../../core/design/widgets/widgets.dart' show MadarButtonSize;
import '../../core/i18n/formatters.dart';
import '../../core/i18n/gen/app_localizations.dart';
import '../../core/routing/routes.dart';
import '../data/data.dart' show lastBackupAtProvider;
import '../notification_center/notification_center.dart' show NotificationBell, notificationCenterProvider;
import '../together/pairing/pairing.dart' show OnlinePlayTile;
import '../together/together.dart' show TogetherSettingsTile;
import 'widgets/settings_widgets.dart';

/// Settings › the system shell, between Life and "Motion & power":
///
/// * **Notifications** – the notification centre (what arrived and what is
///   coming, with the bell's badge on the row itself) and "what each part
///   sends" with the number of groups he has muted;
/// * **Home-screen widgets** – the four widgets' previews and their "show
///   details" switches;
/// * **Together** – Together Mode itself, its settings sheet (default play
///   mode, split layout, hide from recents, clearing the history) and the
///   online-play sheet (his own Firebase project);
/// * **AI** – his own key, the model and the reply length, plus his saved
///   chats.
///
/// Every row opens a page or a sheet that the feature itself owns, so a
/// change is saved by that feature and the rest of Madar follows at once.
/// The pages are pushed (`push`: back returns here) when they live outside
/// `/settings`, and `go`ne to when they are children of it.
class SystemSettingsSections extends ConsumerWidget {
  const SystemSettingsSections({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [_NotificationsSection(), _WidgetsSection(), _TogetherSection(), _AiSection()],
  );
}

class _NotificationsSection extends ConsumerWidget {
  const _NotificationsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final fmt = MadarFormatter.of(context);
    // Already watched app-wide (AppServices), so this costs nothing new.
    final muted = ref.watch(notificationCenterProvider).mutes.length;
    return SettingsSection(
      title: l.ncTitle,
      seed: 0.29,
      children: [
        SettingsTile(
          icon: Icons.notifications_rounded,
          iconColor: t.accent,
          title: l.systemShellNotificationCenterRow,
          subtitle: l.systemShellNotificationCenterHint,
          navigates: true,
          // The badge on the row, so the count is visible from Settings too.
          trailing: NotificationBell(
            size: MadarButtonSize.small,
            onPressed: () => unawaited(context.push<void>(AppRoutes.notifications)),
          ),
          // push: /notifications is not nested under /settings.
          onTap: () => unawaited(context.push<void>(AppRoutes.notifications)),
        ),
        SettingsTile(
          icon: Icons.tune_rounded,
          title: l.systemShellNotificationGroupsRow,
          subtitle: fmt.localizeDigits(l.systemShellNotificationsMuted(muted, fmt.formatInt(muted))),
          navigates: true,
          onTap: () => context.go(AppRoutes.notificationSettings),
        ),
      ],
    );
  }
}

class _WidgetsSection extends ConsumerWidget {
  const _WidgetsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    return SettingsSection(
      title: l.widgetsSettingsTitle,
      seed: 0.3,
      children: [
        SettingsTile(
          icon: Icons.widgets_rounded,
          title: l.systemShellWidgetsRow,
          subtitle: l.systemShellWidgetsRowHint,
          navigates: true,
          onTap: () => context.go(AppRoutes.widgetsSettings),
        ),
      ],
    );
  }
}

class _TogetherSection extends ConsumerWidget {
  const _TogetherSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SettingsSection(
          title: l.togetherTitle,
          seed: 0.31,
          children: [
            SettingsTile(
              icon: Icons.diversity_1_rounded,
              iconColor: t.gold,
              title: l.systemShellTogetherRow,
              subtitle: l.systemShellTogetherRowHint,
              navigates: true,
              onTap: () => unawaited(context.push<void>(AppRoutes.together)),
            ),
          ],
        ),
        // Both are glass cards of their own package – never inside a
        // SettingsSection's panel (a panel inside a panel).
        const Padding(
          padding: EdgeInsetsDirectional.only(top: Space.m),
          child: TogetherSettingsTile(),
        ),
        const Padding(
          padding: EdgeInsetsDirectional.only(top: Space.m),
          child: OnlinePlayTile(),
        ),
      ],
    );
  }
}

class _AiSection extends ConsumerWidget {
  const _AiSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    return SettingsSection(
      title: l.systemShellAiSection,
      seed: 0.33,
      children: [
        SettingsTile(
          icon: Icons.auto_awesome_rounded,
          title: l.aiChatSettingsTitle,
          subtitle: l.aiChatSettingsRowSubtitle,
          navigates: true,
          onTap: () => context.go(AppRoutes.aiSettings),
        ),
        SettingsTile(
          icon: Icons.forum_rounded,
          title: l.aiChatListTitle,
          subtitle: l.systemShellAiChatsRowHint,
          navigates: true,
          onTap: () => unawaited(context.push<void>(AppRoutes.aiChats)),
        ),
      ],
    );
  }
}

/// Settings › «بياناتك»: the backup, the exports and the restore (one row
/// into the data centre, with the date of his last backup underneath), the
/// prototype import, and the privacy note – which now says the truth: the
/// data is encrypted on this phone and leaves it only when he shares, saves
/// or sends it himself.
class YourDataSection extends ConsumerWidget {
  const YourDataSection({super.key, this.seed = 0.5});

  final double seed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final fmt = MadarFormatter.of(context);
    final lastBackup = ref.watch(lastBackupAtProvider).value;
    return SettingsSection(
      title: l.dataCentreTitle,
      seed: seed,
      children: [
        SettingsTile(
          icon: Icons.shield_moon_rounded,
          iconColor: t.gold,
          title: l.systemShellDataRow,
          subtitle: lastBackup == null
              ? l.systemShellDataRowNever
              : l.systemShellDataRowLast(fmt.formatDate(lastBackup)),
          navigates: true,
          onTap: () => context.go(AppRoutes.dataCentre),
        ),
        SettingsTile(
          icon: Icons.move_to_inbox_rounded,
          title: l.settingsImport,
          subtitle: l.settingsImportHint,
          navigates: true,
          // push: back returns here (/import is not nested under /settings).
          onTap: () => unawaited(context.push<void>(AppRoutes.import)),
        ),
        SettingsNote(l.systemShellPrivacyNote, icon: Icons.lock_rounded),
      ],
    );
  }
}
