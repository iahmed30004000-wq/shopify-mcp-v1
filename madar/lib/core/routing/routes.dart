import '../quran/ayah.dart';

/// Every route location of the app. Navigate with `context.go(AppRoutes.x)`
/// (routes below `/` are nested, so `go` builds the whole stack and the back
/// button returns to the parent).
abstract final class AppRoutes {
  static const String home = '/';
  static const String onboarding = '/onboarding';
  static const String settings = '/settings';
  static const String appearance = '/settings/appearance';
  static const String sound = '/settings/sound';
  static const String licenses = '/settings/licenses';
  static const String import = '/import';
  static const String gallery = '/gallery';

  // Phase 2 – the day around the five prayers.

  /// Prayer times (day and month views, next prayer, Hijri date).
  static const String prayerTimes = '/prayer-times';

  /// Calculation method, location, adjustments, Hijri offset, clock.
  static const String prayerSettings = '/settings/prayer';

  /// The adhan: sounds, reminders, full-screen, permissions.
  static const String adhanSettings = '/settings/adhan';

  /// Settings › Security (app lock: PIN, fingerprint, time-out).
  static const String security = '/settings/security';

  /// The prayer tracker (`?tab=history` opens the history tab).
  static const String prayerTracker = '/prayer-tracker';

  /// Location of the tracker's history tab.
  static const String prayerTrackerHistory = '/prayer-tracker?tab=history';

  /// Adhkar (Hisn al-Muslim): the sets of the day.
  static const String adhkar = '/adhkar';

  /// The tasbeeh ring.
  static const String tasbeeh = '/adhkar/tasbeeh';

  /// One adhkar set in the reader (`/adhkar/morning`,
  /// `/adhkar/afterPrayer?prayer=asr`).
  static const String adhkarSet = '/adhkar/:set';

  /// Location of the reader of [set] (an `AdhkarCategoryId` name), for the
  /// after-prayer set optionally of [prayer] (a `Prayer` name).
  static String adhkarSetOf(String set, {String? prayer}) => Uri(
    path: '/adhkar/${Uri.encodeComponent(set)}',
    queryParameters: prayer == null ? null : {'prayer': prayer},
  ).toString();

  /// A planet's page over the orbit (`/planet/faith?item=people:<id>`); the
  /// orbit scene flies in underneath it.
  static const String planet = '/planet/:key';

  /// Location of [key]'s planet page, optionally highlighting the moon or
  /// record [item] (`refTable:refId`).
  static String planetOf(String key, {String? item}) => Uri(
    path: '/planet/${Uri.encodeComponent(key)}',
    queryParameters: item == null ? null : {'item': item},
  ).toString();

  // Phase 3 – the Quran, recitation, the wird, Hifz and the qibla.

  /// The Quran's front page: continue reading, search, go to, the index.
  static const String quran = '/quran';

  /// The reader (`?ayah=2:255` or `?page=42`; neither: where it last
  /// stopped).
  static const String quranReader = '/quran/read';

  /// Location of the reader at [ayah] (lit briefly) or at mushaf [page].
  static String quranReaderOf({AyahRef? ayah, int? page}) => Uri(
    path: quranReader,
    queryParameters: ayah != null
        ? {'ayah': '$ayah'}
        : page != null
        ? {'page': '$page'}
        : null,
  ).toString();

  /// Search across the Arabic text (`?q=` starts with a query).
  static const String quranSearch = '/quran/search';

  /// The daily wird (`?plan=<id>` focuses one plan).
  static const String wird = '/wird';

  /// Location of the wird screen focused on [planId].
  static String wirdOf(String? planId) =>
      Uri(path: wird, queryParameters: planId == null ? null : {'plan': planId}).toString();

  /// Hifz: due items, all items, stats.
  static const String hifz = '/hifz';

  /// A review session (`?card=<id>` reviews one item).
  static const String hifzReview = '/hifz/review';

  /// Location of a review of the card [cardId] only (all due when null).
  static String hifzReviewOf(String? cardId) =>
      Uri(path: hifzReview, queryParameters: cardId == null ? null : {'card': cardId}).toString();

  /// The qibla compass.
  static const String qibla = '/qibla';

  /// The full recitation player (a sheet over the page underneath).
  static const String nowPlaying = '/now-playing';

  /// Settings › Quran reading (layout, text size, tajweed, translation).
  static const String quranSettings = '/settings/quran';

  /// Settings › Recitation (reciter, repeats, speed, downloads).
  static const String recitationSettings = '/settings/recitation';

  /// One reciter's per-surah downloads (`?reciter=<id>`).
  static const String recitationDownloads = '/settings/recitation/downloads';

  /// Location of [reciterId]'s downloads.
  static String recitationDownloadsOf(String reciterId) =>
      Uri(path: recitationDownloads, queryParameters: {'reciter': reciterId}).toString();

  /// Settings › Reminders (adhkar and wird).
  static const String reminders = '/settings/reminders';

  // Phase 4 – health (tracking only). The Health world's own page is its
  // hub (`planetOf('health')`); every health screen below opens from it.

  /// Medications & supplements (`?tab=meds|courses`; none: today's doses).
  static const String meds = '/meds';

  /// Location of the medications screen on [tab] (`today`, `meds`,
  /// `courses`; null or `today`: the plain location).
  static String medsOf({String? tab}) => _withTab(meds, tab, 'today');

  /// The medical record (`?tab=labs|appointments|questions|conditions`).
  static const String record = '/record';

  /// Location of the record on [tab] (null or `labs`: the plain location).
  static String recordOf({String? tab}) => _withTab(record, tab, 'labs');

  /// One lab test's readings and trend (`/record/lab/<id>`).
  static const String labTest = '/record/lab/:id';

  /// Location of the lab test [testId].
  static String labTestOf(String testId) => '/record/lab/${Uri.encodeComponent(testId)}';

  /// Upcoming and past appointments (`?highlight=<id>` lights one).
  static const String appointments = '/record/appointments';

  /// Location of the appointments, lighting [highlightId].
  static String appointmentsOf({String? highlightId}) =>
      Uri(path: appointments, queryParameters: highlightId == null ? null : {'highlight': highlightId}).toString();

  /// Wellbeing: check-in, pain, habits, worries, insights
  /// (`?tab=pain|habits|worries|insights`; none: today).
  static const String wellbeing = '/wellbeing';

  /// Location of wellbeing on [tab] (null or `today`: the plain location).
  static String wellbeingOf({String? tab}) => _withTab(wellbeing, tab, 'today');

  /// Guided breathing (`?pattern=478|box`; none: the user's last pattern).
  static const String breathing = '/wellbeing/breathing';

  /// Location of guided breathing with [pattern].
  static String breathingOf({String? pattern}) =>
      Uri(path: breathing, queryParameters: pattern == null ? null : {'pattern': pattern}).toString();

  /// Settings › Health (meal times, reminders, worry window, emergency
  /// number, lab margin, doctor report).
  static const String healthSettings = '/settings/health';

  // Phase 5 – money (no tax, VAT, fee or zakat anywhere). The Money world's
  // own page is its hub (`planetOf('money')`); every money screen below
  // opens from it.

  /// The ledger: net balance, wallets, charts, recent entries.
  static const String ledger = '/ledger';

  /// One wallet's balance, chart and entries (`/ledger/wallet/<id>`).
  static const String wallet = '/ledger/wallet/:id';

  /// Location of the wallet [walletId].
  static String walletOf(String walletId) => '/ledger/wallet/${Uri.encodeComponent(walletId)}';

  /// Every entry, searchable and filtered (`?wallet=&kind=&item=&tag=&from=
  /// &to=&scope=&unassigned=1&q=`; repeated keys for several values).
  static const String transactions = '/ledger/transactions';

  /// Location of the transactions filtered by [query] (see
  /// `TxFilterQuery`); none: every entry.
  static String transactionsOf([Map<String, List<String>>? query]) =>
      Uri(path: transactions, queryParameters: query == null || query.isEmpty ? null : query).toString();

  /// Currencies, the base currency and the manual exchange rates.
  static const String currencies = '/ledger/currencies';

  /// The nested budget (`?tab=spending`; none: the plan).
  static const String budget = '/budget';

  /// Location of the budget on [tab] (`plan`, `spending`; null or `plan`:
  /// the plain location).
  static String budgetOf({String? tab}) => _withTab(budget, tab, 'plan');

  /// Savings jars, debts and recurring obligations (`?tab=debts|obligations`;
  /// `&debt=<id>` / `&obligation=<id>` opens that one's sheet).
  static const String goals = '/goals';

  /// Location of the goals on [tab] (`jars`, `debts`, `obligations`),
  /// opening the sheet of [debt] or [obligation] (their tab implied).
  static String goalsOf({String? tab, String? debt, String? obligation}) {
    final t = debt != null ? 'debts' : (obligation != null ? 'obligations' : tab);
    return Uri(
      path: goals,
      queryParameters: {
        if (t != null && t != 'jars') 'tab': t,
        'debt': ?debt,
        if (debt == null) 'obligation': ?obligation,
      }.nullIfEmpty,
    ).toString();
  }

  /// One savings jar: progress, plan, chart, movements (`/goals/jar/<id>`).
  static const String jar = '/goals/jar/:id';

  /// Location of the jar [jarId].
  static String jarOf(String jarId) => '/goals/jar/${Uri.encodeComponent(jarId)}';

  static String _withTab(String path, String? tab, String home) =>
      Uri(path: path, queryParameters: tab == null || tab == home ? null : {'tab': tab}).toString();

  /// Locations reachable before onboarding is finished (onboarding can hand
  /// over to the importer).
  static const Set<String> beforeOnboarding = {onboarding, import};
}

extension on Map<String, String> {
  Map<String, String>? get nullIfEmpty => isEmpty ? null : this;
}

/// Where the router must send [location] (a matched location such as
/// `/settings/sound`), or null to stay. Pure – unit-tested.
///
/// * Not onboarded → everything except [AppRoutes.beforeOnboarding] goes to
///   onboarding.
/// * Onboarded → onboarding is closed and goes home.
String? onboardingRedirect({required bool onboarded, required String location}) {
  final path = location.isEmpty ? AppRoutes.home : location;
  if (!onboarded) {
    return AppRoutes.beforeOnboarding.contains(path) ? null : AppRoutes.onboarding;
  }
  return path == AppRoutes.onboarding ? AppRoutes.home : null;
}
