import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;

import '../../app/system_services.dart' show afterRestoreProvider;
import '../../features/ai_chat/ai_chat.dart' show AiChatListScreen, AiChatScreen;
import '../../features/data/data.dart' show DataCentreScreen, RestoreFlow;
import '../../features/lock/application/lock_controller.dart' show lockControllerProvider;
import '../../features/notification_center/notification_center.dart'
    show CenterTab, NotificationCenterScreen, NotificationSettingsSummary;
import '../../features/search/search.dart' show GlobalSearchScreen, SearchDoc;
import '../../features/together/together.dart' show TogetherHomeScreen;
import '../design/tokens.dart' show Space;
import '../design/widgets/widgets.dart' show MadarScaffold;
import '../i18n/gen/app_localizations.dart';
import '../quran/ayah.dart' show AyahRef;
import '../settings/app_settings.dart';
import '../sound/sound_api.dart';
import 'life_route_pages.dart' show LifeRecordLinks;
import 'routes.dart';

/// Adapters between the router and the Phase 9 system screens (global
/// search, the notification centre and its group settings).
///
/// In-app links `push`, so back returns to where they were opened; a planet
/// location `go`es, because the planet page is a transparent route that
/// needs home underneath it.
abstract final class SystemNav {
  /// Goes to [location]: a planet page replaces the stack (`go`), anything
  /// else is pushed over it.
  static void to(BuildContext context, String location) {
    if (location.startsWith('/planet/')) {
      context.go(location);
    } else {
      unawaited(context.push<void>(location));
    }
  }

  static void search(BuildContext context, {String? query}) =>
      unawaited(context.push<void>(AppRoutes.searchOf(query: query)));

  static void notifications(BuildContext context, {String? tab}) =>
      unawaited(context.push<void>(AppRoutes.notificationsOf(tab: tab)));
}

/// `/search?q=` – global search, opening every result through
/// [openSearchResult] (installed app-wide as `searchOpenerProvider`).
class SearchRoutePage extends StatelessWidget {
  const SearchRoutePage({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  Widget build(BuildContext context) => GlobalSearchScreen(initialQuery: initialQuery);
}

/// `/notifications?tab=upcoming|recent` – the notification centre.
class NotificationsRoutePage extends ConsumerWidget {
  const NotificationsRoutePage({super.key, this.tab});

  final CenterTab? tab;

  /// The tab named by the `tab` query parameter (null: the centre picks –
  /// Recent when something is new).
  static CenterTab? tabOf(String? name) {
    for (final t in CenterTab.values) {
      if (t.name == name) return t;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => NotificationCenterScreen(
    initialTab: tab,
    animateBackdrop: !ref.watch(appSettingsProvider.select((s) => s.powerMode == PowerMode.batterySaver)),
  );
}

/// `/settings/notifications` – what each part of Madar sends, and what is
/// muted.
class NotificationSettingsRoutePage extends StatelessWidget {
  const NotificationSettingsRoutePage({super.key});

  @override
  Widget build(BuildContext context) => MadarScaffold(
    title: L10n.of(context).ncSettingsTitle,
    backdropSeed: 5.31,
    body: const SingleChildScrollView(
      padding: EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.xs, Space.gutter, 120),
      child: NotificationSettingsSummary(),
    ),
  );
}

/// `/settings/data` – «بياناتك»: the full JSON, the AI-ready summary, the
/// CSV files, the encrypted backup and the way into the restore.
///
/// A restore done from here (or from `/settings/data/restore`) is reported
/// to [afterRestoreProvider], which is bound to the root container – so the
/// re-planning of every reminder finishes even after these screens close.
class DataCentreRoutePage extends ConsumerWidget {
  const DataCentreRoutePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => DataCentreScreen(
    onOpenImport: () => unawaited(context.push<void>(AppRoutes.import)),
    onOpenRestore: () => unawaited(context.push<void>(AppRoutes.dataRestore)),
    onRestored: (result) => unawaited(ref.read(afterRestoreProvider)(result)),
  );
}

/// `/settings/data/restore` – the restore flow on its own (the file, the
/// passphrase, the preview, the safety copy, then Done).
class RestoreRoutePage extends ConsumerWidget {
  const RestoreRoutePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => RestoreFlow(
    onRestored: (result) => unawaited(ref.read(afterRestoreProvider)(result)),
    onDone: () => context.canPop() ? context.pop() : context.go(AppRoutes.home),
  );
}

/// `/ai?q=` (a new chat, the question only typed) and `/ai/chat/<id>` (a
/// saved one).
///
/// Nothing is ever sent without a tap on Send: [initialDraft] only fills
/// the field.
class AiChatRoutePage extends ConsumerWidget {
  const AiChatRoutePage({super.key, this.conversationId, this.initialDraft});

  final String? conversationId;
  final String? initialDraft;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AiChatScreen(
    conversationId: conversationId,
    initialDraft: initialDraft,
    onOpenSettings: () => unawaited(context.push<void>(AppRoutes.aiSettings)),
    onOpenList: () => unawaited(context.push<void>(AppRoutes.aiChats)),
    // A link in a reply leaves Madar: the app lock treats that as his own
    // trip out (no privacy cover, no lock on return within the grace).
    onOpenLink: (uri) => ref
        .read(lockControllerProvider.notifier)
        .whileSuspended<bool>(() => launchUrl(uri, mode: LaunchMode.externalApplication)),
  );
}

/// `/ai/chats` – the saved conversations (a sibling of `/ai`, so no empty
/// chat is left underneath).
class AiChatListRoutePage extends StatelessWidget {
  const AiChatListRoutePage({super.key});

  @override
  Widget build(BuildContext context) => AiChatListScreen(
    onOpenConversation: (id) => unawaited(context.push<void>(id == null ? AppRoutes.ai : AppRoutes.aiChatOf(id))),
    onOpenSettings: () => unawaited(context.push<void>(AppRoutes.aiSettings)),
  );
}

/// `/together` – Together Mode: the two profiles, the head-to-head, and the
/// doors to the Hall of Fame and the three couple specials (each its own
/// route, so Android back returns here).
class TogetherRoutePage extends ConsumerWidget {
  const TogetherRoutePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => TogetherHomeScreen(
    animateBackdrop: !ref.watch(appSettingsProvider.select((s) => s.powerMode == PowerMode.batterySaver)),
    onOpenHallOfFame: () => unawaited(context.push<void>(AppRoutes.togetherHallOfFame)),
    onOpenKnowMe: () => unawaited(context.push<void>(AppRoutes.togetherKnowMe)),
    onOpenWeekly: () => unawaited(context.push<void>(AppRoutes.togetherWeekly)),
    onOpenGoal: () => unawaited(context.push<void>(AppRoutes.togetherGoal)),
  );
}

// ---------------------------------------------------------------------------
// Global search: every result's route

/// Where a search result opens, or null when that kind of record has no
/// screen of its own yet (the results list then says it cannot be opened
/// from here). Pure – table-tested against every source the search has.
///
/// The life worlds' records (people, boards, projects, trips, documents,
/// templates, learning goals, the body's tabs, the food library, plan and
/// rules, the trackers) go through [LifeRecordLinks], so the search and the
/// Neglect Radar never disagree about where a record lives.
String? searchTargetOf(SearchDoc doc) {
  final id = doc.refId.isEmpty ? null : doc.refId;
  String? e(String key) {
    final v = doc.extra[key];
    return v == null || v.isEmpty ? null : v;
  }

  final life = LifeRecordLinks.locationOf(doc.openKey, id, extra: doc.extra);
  if (life != null) return life;

  return switch (doc.openKey) {
    // ------------------------------------------------------------- core
    // The planet page opens the task's editor (RecordOpener).
    'tasks' => id == null ? null : AppRoutes.planetOf(doc.planetKey, item: 'tasks:$id'),
    'planets' => id == null ? null : AppRoutes.planetOf(id),

    // ------------------------------------------------------------ faith
    'prayer_logs' => AppRoutes.prayerTrackerHistory,
    'quran_bookmarks' => _ayah(e('surah'), e('ayah')),
    // QuranSearchSource's refId is the ayah itself («2:255»).
    'quran.ayah' => _ayahRef(id),
    'wird_plans' => AppRoutes.wirdOf(id),
    'hifz_items' => AppRoutes.hifz,

    // ----------------------------------------------------------- health
    // The standing alerts live on the Health world's page.
    'health_alerts' => AppRoutes.planetOf('health'),
    'conditions' => AppRoutes.recordOf(tab: 'conditions'),
    'medications' => AppRoutes.medsOf(tab: 'meds'),
    'med_courses' => AppRoutes.medsOf(tab: 'courses'),
    'med_doses' => AppRoutes.meds,
    'lab_tests' => id == null ? AppRoutes.record : AppRoutes.labTestOf(id),
    'lab_readings' => _or(e('testId'), AppRoutes.labTestOf, AppRoutes.record),
    'appointments' => AppRoutes.appointmentsOf(highlightId: id),
    'doctor_questions' => _or(
      e('appointmentId'),
      (a) => AppRoutes.appointmentsOf(highlightId: a),
      AppRoutes.recordOf(tab: 'questions'),
    ),
    'pain_entries' => AppRoutes.wellbeingOf(tab: 'pain'),
    'mood_entries' => AppRoutes.wellbeing,
    'habits' => AppRoutes.wellbeingOf(tab: 'habits'),
    'worries' => AppRoutes.wellbeingOf(tab: 'worries'),

    // ------------------------------------------------------------ money
    'wallets' => _or(id, AppRoutes.walletOf, AppRoutes.ledger),
    // An entry has no screen of its own: its wallet's list, filtered.
    'transactions' => _or(
      e('walletId'),
      (w) => AppRoutes.transactionsOf({
        'wallet': [w],
      }),
      AppRoutes.ledger,
    ),
    'budget_items' => AppRoutes.budgetOf(),
    'jars' => _or(id, AppRoutes.jarOf, AppRoutes.goals),
    'jar_deposits' => _or(e('jarId'), AppRoutes.jarOf, AppRoutes.goals),
    // The goals page opens the debt's / the obligation's own sheet.
    'debts' => _or(id, (d) => AppRoutes.goalsOf(debt: d), AppRoutes.goalsOf(tab: 'debts')),
    'debt_payments' => _or(e('debtId'), (d) => AppRoutes.goalsOf(debt: d), AppRoutes.goalsOf(tab: 'debts')),
    'obligations' => _or(id, (o) => AppRoutes.goalsOf(obligation: o), AppRoutes.goalsOf(tab: 'obligations')),

    // --------------------------------------------------- Madar Cinema
    'game' => id == null ? AppRoutes.cinema : AppRoutes.cinemaGameOf(id),
    'savedGame' => AppRoutes.savedGames,

    _ => null,
  };
}

String _or(String? id, String Function(String id) withId, String without) => id == null ? without : withId(id);

/// The reader at the ayah [surah]:[ayah] (a bad or missing pair opens the
/// reader where it was left).
String _ayah(String? surah, String? ayah) => _ayahRef(surah == null || ayah == null ? null : '$surah:$ayah');

/// The reader at the ayah written «surah:ayah».
String _ayahRef(String? ref) {
  final parsed = ref == null ? null : AyahRef.tryParse(ref);
  return parsed == null ? AppRoutes.quranReader : AppRoutes.quranReaderOf(ayah: parsed);
}

/// Opens [doc] where [searchTargetOf] says, with the app's navigation sound;
/// false when that kind of record has no screen yet, which the results list
/// reports as «لا يمكن فتح هذه النتيجة من هنا بعد».
///
/// Installed app-wide as `searchOpenerProvider` (`systemHookOverrides`).
bool openSearchResult(BuildContext context, SearchDoc doc) {
  final target = searchTargetOf(doc);
  if (target == null) return false;
  Fx.fire(Sfx.navigate);
  SystemNav.to(context, target);
  return true;
}
