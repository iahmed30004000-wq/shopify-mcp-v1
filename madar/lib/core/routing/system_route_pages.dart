import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;

import '../../app/system_services.dart' show afterRestoreProvider;
import '../../features/ai_bridge/ai_bridge.dart'
    show PlanHistoryScreen, PlanImportScreen, PlanScreen, PlanTab;
import '../../features/ai_chat/ai_chat.dart' show AiChatListScreen, AiChatScreen;
import '../../features/data/data.dart' show DataCentreScreen, RestoreFlow;
import '../../features/day_chat/day_chat.dart' show DayChatScreen, DayChatTab;
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
import 'life_route_pages.dart' show LifeRecordLinks, LoggedRecordLinks;
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

/// How the AI bridge's pages open from the rest of the app (the card on
/// the home panel, Settings › Your data, a share intent).
abstract final class PlanNav {
  /// The plans he brought back.
  static void plans(BuildContext context) => unawaited(context.push<void>(AppRoutes.plans));

  /// Bringing an answer in.
  static void import(BuildContext context) => unawaited(context.push<void>(AppRoutes.planImport));

  /// One plan's suggestions.
  static void plan(BuildContext context, String planId) =>
      unawaited(context.push<void>(AppRoutes.planOf(planId)));

  /// One plan straight on its checklist – where the home panel's line goes.
  static void checklist(BuildContext context, String planId) =>
      unawaited(context.push<void>(AppRoutes.planOf(planId, tab: 'list')));
}

/// Part 7 – how the daily chat opens: from the quick-add bar on the home
/// panel (carrying whatever he already typed), and from anywhere else that
/// wants his day.
abstract final class DayChatNav {
  /// The chat of today, with [draft] already typed into the box – never
  /// sent: he still taps send, and then decides each card.
  static void open(BuildContext context, {String? draft}) =>
      unawaited(context.push<void>(AppRoutes.dayChatOf(draft: draft)));

  /// «شو صار اليوم؟» straight away.
  static void summary(BuildContext context, {DateTime? day}) =>
      unawaited(context.push<void>(AppRoutes.dayChatOf(day: day, tab: 'summary')));

  /// Another day of the chat **in place of** this one, so back leaves the
  /// chat instead of walking through every day he looked at.
  static void day(BuildContext context, DateTime day) =>
      context.pushReplacement(AppRoutes.dayChatOf(day: day));
}

/// `/day?day=&tab=&q=` – the daily chat: he types his day, and every piece
/// it was read into waits on its own card for his tap.
///
/// Nothing here writes or sends anything by itself: `q` only fills the box,
/// and a card's own «سجّلها» is the only thing that writes.
class DayChatRoutePage extends ConsumerWidget {
  const DayChatRoutePage({super.key, this.day, this.tab, this.initialDraft});

  final DateTime? day;
  final DayChatTab? tab;
  final String? initialDraft;

  /// The tab named by the `tab` query parameter (null: the chat itself).
  static DayChatTab? tabOf(String? name) {
    for (final t in DayChatTab.values) {
      if (t.name == name) return t;
    }
    return null;
  }

  /// The day named by the `day` query parameter (`yyyy-mm-dd`; null: today).
  static DateTime? dayOf(String? key) {
    if (key == null || key.isEmpty) return null;
    final parsed = DateTime.tryParse(key);
    return parsed == null ? null : DateTime(parsed.year, parsed.month, parsed.day);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => DayChatScreen(
    day: day,
    initialTab: tab ?? DayChatTab.chat,
    initialDraft: initialDraft,
    animateBackdrop: !ref.watch(appSettingsProvider.select((s) => s.powerMode == PowerMode.batterySaver)),
    onOpenDay: (picked) => DayChatNav.day(context, picked),
    // A filed card can be followed to the row it created, wherever that
    // feature keeps it (the same map the global search uses).
    onOpenRecord: (table, id) {
      final target = LoggedRecordLinks.locationOf(table, id);
      if (target == null) return;
      Fx.fire(Sfx.navigate);
      SystemNav.to(context, target);
    },
  );
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
    onOpenPlanImport: () => unawaited(context.push<void>(AppRoutes.planImport)),
    onOpenPlans: () => unawaited(context.push<void>(AppRoutes.plans)),
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

/// `/plans` – the «خطة مدار» answers he brought back, newest first. Each
/// one opens again through `PlanApplyService.reopen`, so an old plan is
/// read against his data as it is today.
class PlanHistoryRoutePage extends ConsumerWidget {
  const PlanHistoryRoutePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => PlanHistoryScreen(
    animateBackdrop: !ref.watch(appSettingsProvider.select((s) => s.powerMode == PowerMode.batterySaver)),
    onOpenPlan: (id) => unawaited(context.push<void>(AppRoutes.planOf(id))),
    onImport: () => unawaited(context.push<void>(AppRoutes.planImport)),
  );
}

/// `/plans/import` – paste an answer or pick its file; an answer shared
/// out of another app lands here too (`pendingSharedPlanProvider`).
///
/// The plan it reads **replaces** this screen, so Android back from the
/// review returns to the plans instead of to the paste box.
class PlanImportRoutePage extends ConsumerWidget {
  const PlanImportRoutePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => PlanImportScreen(
    animateBackdrop: !ref.watch(appSettingsProvider.select((s) => s.powerMode == PowerMode.batterySaver)),
    onOpenPlan: (id) => context.pushReplacement(AppRoutes.planOf(id)),
  );
}

/// `/plans/plan/<id>?tab=items|list` – one plan: the suggestions, decided
/// one at a time, and the list he ticks off.
class PlanRoutePage extends ConsumerWidget {
  const PlanRoutePage({super.key, required this.planId, this.tab});

  final String planId;
  final PlanTab? tab;

  /// The tab named by the `tab` query parameter (null: the suggestions).
  static PlanTab? tabOf(String? name) {
    for (final t in PlanTab.values) {
      if (t.name == name) return t;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => PlanScreen(
    planId: planId,
    initialTab: tab ?? PlanTab.items,
    animateBackdrop: !ref.watch(appSettingsProvider.select((s) => s.powerMode == PowerMode.batterySaver)),
    onOpenMealPlan: () => unawaited(context.push<void>(AppRoutes.foodPlan)),
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
/// rules, the trackers, the kitchen, and the games' two kinds) go through
/// [LifeRecordLinks], so the search and the Neglect Radar never disagree
/// about where a record lives.
String? searchTargetOf(SearchDoc doc) {
  final id = doc.refId.isEmpty ? null : doc.refId;
  String? e(String key) {
    final v = doc.extra[key];
    return v == null || v.isEmpty ? null : v;
  }

  // Everything the life worlds map, plus the logged rows the daily chat can
  // create (a ledger entry, a prayer log, pain, mood, a task) – one source
  // of truth for the search, the chat and the Neglect Radar. The planet
  // page opens a task's editor (RecordOpener).
  final logged = LoggedRecordLinks.locationOf(
    doc.openKey,
    id,
    planetKey: doc.planetKey,
    walletId: e('walletId'),
    extra: doc.extra,
  );
  if (logged != null) return logged;

  return switch (doc.openKey) {
    // ------------------------------------------------------------- core
    'planets' => id == null ? null : AppRoutes.planetOf(id),

    // ------------------------------------------------------------ faith
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
    'habits' => AppRoutes.wellbeingOf(tab: 'habits'),
    'worries' => AppRoutes.wellbeingOf(tab: 'worries'),

    // ------------------------------------------------------------ money
    'wallets' => _or(id, AppRoutes.walletOf, AppRoutes.ledger),
    'budget_items' => AppRoutes.budgetOf(),
    'jars' => _or(id, AppRoutes.jarOf, AppRoutes.goals),
    'jar_deposits' => _or(e('jarId'), AppRoutes.jarOf, AppRoutes.goals),
    // The goals page opens the debt's / the obligation's own sheet.
    'debts' => _or(id, (d) => AppRoutes.goalsOf(debt: d), AppRoutes.goalsOf(tab: 'debts')),
    'debt_payments' => _or(e('debtId'), (d) => AppRoutes.goalsOf(debt: d), AppRoutes.goalsOf(tab: 'debts')),
    'obligations' => _or(id, (o) => AppRoutes.goalsOf(obligation: o), AppRoutes.goalsOf(tab: 'obligations')),

    // The games («الألعاب», `game` / `savedGame`) go through
    // [LifeRecordLinks] with the other worlds' records, above.

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
