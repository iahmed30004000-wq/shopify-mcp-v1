import 'package:drift/drift.dart';
import 'package:flutter/material.dart' show Icons, IconData;

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../../../core/domain/enums.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../domain/search_doc.dart';
import 'custom_module_source.dart';
import 'search_source.dart';

/// Non-empty [lines], one per line.
String _lines(Iterable<String?> lines) => lines.where((l) => l != null && l.trim().isNotEmpty).join('\n');

bool _has(String? s) => s != null && s.trim().isNotEmpty;

/// `yyyy-MM-dd` → local midnight.
DateTime? _day(String day) {
  final parts = day.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]), m = int.tryParse(parts[1]), d = int.tryParse(parts[2]);
  return y == null || m == null || d == null ? null : DateTime(y, m, d);
}

/// A prayer window by its prayer's name («العصر»), as tasks are filed.
String _window(L10n l, PrayerWindow w) => switch (w) {
  PrayerWindow.fajr => l.prayerFajr,
  PrayerWindow.duha => l.trackerDuha,
  PrayerWindow.dhuhr => l.prayerDhuhr,
  PrayerWindow.asr => l.prayerAsr,
  PrayerWindow.maghrib => l.prayerMaghrib,
  PrayerWindow.isha => l.prayerIsha,
  PrayerWindow.anytime => l.windowAnytime,
};

String _prayer(L10n l, Prayer p) => switch (p) {
  Prayer.fajr => l.prayerFajr,
  Prayer.dhuhr => l.prayerDhuhr,
  Prayer.asr => l.prayerAsr,
  Prayer.maghrib => l.prayerMaghrib,
  Prayer.isha => l.prayerIsha,
  Prayer.sunnahFajr => l.trackerSunnahFajr,
  Prayer.sunnahDhuhr => l.trackerSunnahDhuhr,
  Prayer.sunnahMaghrib => l.trackerSunnahMaghrib,
  Prayer.sunnahIsha => l.trackerSunnahIsha,
  Prayer.duha => l.trackerDuha,
  Prayer.witr => l.trackerWitr,
  Prayer.qiyam => l.trackerQiyam,
};

String _prayerStatus(L10n l, PrayerStatus s) => switch (s) {
  PrayerStatus.prayed => l.trackerStatusPrayed,
  PrayerStatus.late => l.trackerStatusLate,
  PrayerStatus.missed => l.trackerStatusMissed,
  PrayerStatus.qada => l.trackerStatusQada,
};

String _txKind(L10n l, TxKind k) => switch (k) {
  TxKind.expense => l.searchTxExpense,
  TxKind.income => l.searchTxIncome,
  TxKind.transfer => l.searchTxTransfer,
  TxKind.adjustment => l.searchTxAdjustment,
};

String _channel(L10n l, ContactChannel c) => switch (c) {
  ContactChannel.call => l.searchChannelCall,
  ContactChannel.visit => l.searchChannelVisit,
  ContactChannel.message => l.searchChannelMessage,
  ContactChannel.other => l.searchChannelOther,
};

/// Rows with a non-empty text column (notes-only logs).
Expression<bool> _filled(Expression<String> column) => column.isNotNull() & column.trim().equals('').not();

/// An indexed source over one [table]: its rows (read a page at a time,
/// see [SearchLoadContext.mapRows]), [map]ped each to a record (null to
/// skip).
SearchSource _rows<T extends Table, R extends DataClass>({
  required String id,
  required String planet,
  required IconData icon,
  required String label,
  Set<String>? tables,
  double weight = 1,
  required EntityRepository<T, R> Function(Repositories r) table,
  required SearchDoc? Function(R row, SearchLoadContext c) map,
}) => SearchSource(
  id: id,
  planetKey: planet,
  icon: icon,
  labelKey: label,
  weight: weight,
  tables: tables ?? {id},
  load: (c) => c.mapRows(table(c.repos), (row) => map(row, c)),
);

/// The global search's built-in sources: one per table with text the user
/// wrote, plus planets and custom modules. Settings (key/values), reminders,
/// the activity stream, import archives and plain number logs (water,
/// Quran sessions, habit ticks …) are never indexed; neither are travel
/// document numbers or phone numbers.
abstract final class BuiltInSearchSources {
  /// Source ids (also their SQL tables).
  static const String tasks = 'tasks';
  static const String customModules = CustomModuleSearch.modulesSourceId;
  static const String customEntries = CustomModuleSearch.entriesSourceId;
  static const String quran = 'quran';

  /// Every built-in indexed source.
  static List<SearchSource> all() => [
    // ------------------------------------------------------------ core
    _rows(
      id: 'tasks',
      planet: 'work',
      icon: Icons.task_alt_rounded,
      label: 'searchSourceTasks',
      table: (r) => r.tasks,
      map: (t, c) => SearchDoc(
        id: t.id,
        refTable: 'tasks',
        refId: t.id,
        title: t.title,
        subtitle: c.join([
          if (t.window != PrayerWindow.anytime) _window(c.l10n, t.window),
          if (t.done) c.l10n.searchDone,
        ]),
        body: t.notes ?? '',
        date: t.date ?? t.createdAt,
        planetKey: t.planetKey ?? 'work',
        extra: {'projectId': ?t.projectId, 'cardId': ?t.cardId},
      ),
    ),
    SearchSource(
      id: 'planets',
      planetKey: 'faith',
      icon: Icons.public_rounded,
      labelKey: 'searchSourcePlanets',
      weight: 1.2,
      tables: const {'planets'},
      load: (c) async => [
        for (final p in await c.repos.planets.getAll())
          if (!p.hidden)
            SearchDoc(
              id: p.key,
              refTable: 'planets',
              refId: p.key,
              title: c.arabic ? p.nameAr : p.nameEn,
              subtitle: c.arabic ? p.nameEn : p.nameAr,
              planetKey: p.key,
              extra: {'planetId': p.id},
            ),
      ],
    ),

    // ----------------------------------------------------------- faith
    _rows(
      id: 'prayer_logs',
      planet: 'faith',
      icon: Icons.mosque_rounded,
      label: 'searchSourcePrayerLogs',
      weight: 0.6,
      table: (r) => r.prayerLogs,
      map: (p, c) => SearchDoc(
        id: p.id,
        refTable: 'prayer_logs',
        refId: p.id,
        title: _prayer(c.l10n, p.prayer),
        subtitle: c.join([
          _prayerStatus(c.l10n, p.status),
          if (p.inJamaah) c.l10n.trackerJamaah,
          if (p.atMosque) c.l10n.trackerMosque,
        ]),
        date: _day(p.day) ?? p.loggedAt,
        planetKey: 'faith',
        extra: {'day': p.day, 'prayer': p.prayer.name},
      ),
    ),
    _rows(
      id: 'quran_bookmarks',
      planet: 'faith',
      icon: Icons.bookmark_rounded,
      label: 'searchSourceQuranBookmarks',
      table: (r) => r.quranBookmarks,
      map: (b, c) {
        final place = c.ayahPlace(b.surah, b.ayah);
        return SearchDoc(
          id: b.id,
          refTable: 'quran_bookmarks',
          refId: b.id,
          title: _has(b.label) ? b.label! : place,
          subtitle: _has(b.label) ? place : '',
          body: b.note ?? '',
          date: b.createdAt,
          planetKey: 'faith',
          extra: {'surah': '${b.surah}', 'ayah': '${b.ayah}'},
        );
      },
    ),
    _rows(
      id: 'wird_plans',
      planet: 'faith',
      icon: Icons.auto_stories_rounded,
      label: 'searchSourceWirdPlans',
      table: (r) => r.wirdPlans,
      map: (w, c) => SearchDoc(
        id: w.id,
        refTable: 'wird_plans',
        refId: w.id,
        title: w.name,
        subtitle: c.surah(w.startSurah),
        date: w.startDate,
        planetKey: 'faith',
      ),
    ),
    _rows(
      id: 'hifz_items',
      planet: 'faith',
      icon: Icons.psychology_rounded,
      label: 'searchSourceHifz',
      table: (r) => r.hifzItems,
      map: (h, c) {
        final s = h.surah;
        final range = s == null
            ? null
            : (h.ayahFrom != null && h.ayahTo != null && h.ayahTo != h.ayahFrom)
            ? c.l10n.searchAyahRange(
                c.surah(s),
                c.formatter.formatInt(h.ayahFrom!, grouping: false),
                c.formatter.formatInt(h.ayahTo!, grouping: false),
              )
            : c.ayahPlace(s, h.ayahFrom ?? 1);
        return SearchDoc(
          id: h.id,
          refTable: 'hifz_items',
          refId: h.id,
          title: _has(h.title) ? h.title! : (range ?? c.l10n.searchSourceHifz),
          subtitle: c.join([if (_has(h.title)) range, h.source]),
          body: h.body ?? '',
          date: h.due ?? h.createdAt,
          planetKey: 'faith',
          extra: {'surah': ?s?.toString()},
        );
      },
    ),

    // ---------------------------------------------------------- health
    _rows(
      id: 'health_alerts',
      planet: 'health',
      icon: Icons.warning_amber_rounded,
      label: 'searchSourceHealthAlerts',
      weight: 1.1,
      table: (r) => r.healthAlerts,
      map: (a, c) => SearchDoc(id: a.id, refTable: 'health_alerts', refId: a.id, title: a.body, planetKey: 'health'),
    ),
    _rows(
      id: 'conditions',
      planet: 'health',
      icon: Icons.healing_rounded,
      label: 'searchSourceConditions',
      table: (r) => r.conditions,
      map: (x, c) => SearchDoc(
        id: x.id,
        refTable: 'conditions',
        refId: x.id,
        title: x.name,
        body: x.notes ?? '',
        date: x.since,
        planetKey: 'health',
      ),
    ),
    _rows(
      id: 'medications',
      planet: 'health',
      icon: Icons.medication_rounded,
      label: 'searchSourceMedications',
      table: (r) => r.medications,
      map: (m, c) => SearchDoc(
        id: m.id,
        refTable: 'medications',
        refId: m.id,
        title: m.name,
        subtitle: c.join([m.dose, if (m.times.isNotEmpty) c.formatter.localizeDigits(m.times.join(' '))]),
        body: _lines([m.notes, m.takenWithNote]),
        planetKey: 'health',
      ),
    ),
    SearchSource(
      id: 'med_courses',
      planetKey: 'health',
      icon: Icons.vaccines_rounded,
      labelKey: 'searchSourceMedCourses',
      tables: const {'med_courses', 'medications'},
      load: (c) async {
        final meds = {for (final m in await c.repos.medications.getAll()) m.id: m.name};
        return c.mapRows(
          c.repos.medCourses,
          (x) => SearchDoc(
            id: x.id,
            refTable: 'med_courses',
            refId: x.id,
            title: x.name,
            subtitle: meds[x.medicationId] ?? '',
            body: x.notes ?? '',
            date: x.startDate,
            planetKey: 'health',
            extra: {'medicationId': ?x.medicationId},
          ),
        );
      },
    ),
    SearchSource(
      id: 'med_doses',
      planetKey: 'health',
      icon: Icons.medication_liquid_rounded,
      labelKey: 'searchSourceMedDoses',
      weight: 0.7,
      tables: const {'med_doses', 'medications'},
      load: (c) async {
        final meds = {for (final m in await c.repos.medications.getAll()) m.id: m.name};
        return c.mapRows(
          c.repos.medDoses,
          (d) => SearchDoc(
            id: d.id,
            refTable: 'med_doses',
            refId: d.id,
            title: meds[d.medicationId] ?? '',
            subtitle: d.dose ?? '',
            body: d.note ?? '',
            date: d.takenAt ?? d.scheduledAt ?? d.createdAt,
            planetKey: 'health',
            extra: {'medicationId': d.medicationId},
          ),
          where: (t) => _filled(t.note),
        );
      },
    ),
    _rows(
      id: 'lab_tests',
      planet: 'health',
      icon: Icons.biotech_rounded,
      label: 'searchSourceLabTests',
      table: (r) => r.labTests,
      map: (x, c) => SearchDoc(
        id: x.id,
        refTable: 'lab_tests',
        refId: x.id,
        title: x.name,
        subtitle: c.join([
          x.category,
          if (x.low != null && x.high != null) '${c.number(x.low!)}–${c.number(x.high!)} ${x.unit ?? ''}'.trim(),
        ]),
        body: x.notes ?? '',
        planetKey: 'health',
      ),
    ),
    SearchSource(
      id: 'lab_readings',
      planetKey: 'health',
      icon: Icons.science_rounded,
      labelKey: 'searchSourceLabReadings',
      weight: 0.8,
      tables: const {'lab_readings', 'lab_tests'},
      load: (c) async {
        final tests = {for (final t in await c.repos.labTests.getAll()) t.id: t};
        return c.mapRows(
          c.repos.labReadings,
          (x) => SearchDoc(
            id: x.id,
            refTable: 'lab_readings',
            refId: x.id,
            title: tests[x.testId]?.name ?? '',
            subtitle: _has(x.valueText)
                ? x.valueText!
                : x.value == null
                ? ''
                : '${c.number(x.value!)} ${tests[x.testId]?.unit ?? ''}'.trim(),
            body: x.note ?? '',
            date: x.date,
            planetKey: 'health',
            extra: {'testId': x.testId},
          ),
        );
      },
    ),
    _rows(
      id: 'appointments',
      planet: 'health',
      icon: Icons.event_available_rounded,
      label: 'searchSourceAppointments',
      table: (r) => r.appointments,
      map: (a, c) => SearchDoc(
        id: a.id,
        refTable: 'appointments',
        refId: a.id,
        title: a.title,
        subtitle: c.join([a.doctor, a.place]),
        body: a.notes ?? '',
        date: a.at,
        planetKey: 'health',
      ),
    ),
    SearchSource(
      id: 'doctor_questions',
      planetKey: 'health',
      icon: Icons.contact_support_rounded,
      labelKey: 'searchSourceDoctorQuestions',
      tables: const {'doctor_questions', 'appointments'},
      load: (c) async {
        final appts = {for (final a in await c.repos.appointments.getAll()) a.id: a};
        return c.mapRows(
          c.repos.doctorQuestions,
          (q) => SearchDoc(
            id: q.id,
            refTable: 'doctor_questions',
            refId: q.id,
            title: q.question,
            subtitle: appts[q.appointmentId]?.title ?? '',
            body: q.answer ?? '',
            date: appts[q.appointmentId]?.at ?? q.createdAt,
            planetKey: 'health',
            extra: {'appointmentId': ?q.appointmentId},
          ),
        );
      },
    ),
    _rows(
      id: 'pain_entries',
      planet: 'health',
      icon: Icons.personal_injury_rounded,
      label: 'searchSourcePain',
      weight: 0.8,
      table: (r) => r.painEntries,
      map: (p, c) => SearchDoc(
        id: p.id,
        refTable: 'pain_entries',
        refId: p.id,
        title: c.l10n.searchPainTitle(c.formatter.formatInt(p.score), c.formatter.formatInt(10)),
        subtitle: c.join([...p.locations, ...p.triggers]),
        body: p.notes ?? '',
        date: p.at,
        planetKey: 'health',
      ),
    ),
    _rows(
      id: 'mood_entries',
      planet: 'health',
      icon: Icons.mood_rounded,
      label: 'searchSourceMood',
      weight: 0.8,
      table: (r) => r.moodEntries,
      map: (m, c) => !_has(m.notes) && m.factors.isEmpty
          ? null
          : SearchDoc(
              id: m.id,
              refTable: 'mood_entries',
              refId: m.id,
              title: c.l10n.searchMoodTitle,
              subtitle: c.join(m.factors),
              body: m.notes ?? '',
              date: m.at,
              planetKey: 'health',
            ),
    ),
    _rows(
      id: 'habits',
      planet: 'health',
      icon: Icons.repeat_rounded,
      label: 'searchSourceHabits',
      table: (r) => r.habits,
      map: (h, c) =>
          SearchDoc(id: h.id, refTable: 'habits', refId: h.id, title: h.name, planetKey: h.planetKey ?? 'health'),
    ),
    _rows(
      id: 'worries',
      planet: 'health',
      icon: Icons.cloud_rounded,
      label: 'searchSourceWorries',
      table: (r) => r.worries,
      map: (w, c) => SearchDoc(
        id: w.id,
        refTable: 'worries',
        refId: w.id,
        title: w.body,
        body: w.reflection ?? '',
        date: w.createdAt,
        planetKey: 'health',
      ),
    ),

    // ----------------------------------------------------------- money
    _rows(
      id: 'wallets',
      planet: 'money',
      icon: Icons.account_balance_wallet_rounded,
      label: 'searchSourceWallets',
      table: (r) => r.wallets,
      map: (w, c) => SearchDoc(
        id: w.id,
        refTable: 'wallets',
        refId: w.id,
        title: w.name,
        subtitle: c.join([w.currency, if (w.archived) c.l10n.searchArchived]),
        planetKey: 'money',
      ),
    ),
    SearchSource(
      id: 'transactions',
      planetKey: 'money',
      icon: Icons.receipt_long_rounded,
      labelKey: 'searchSourceTransactions',
      tables: const {'transactions', 'wallets', 'budget_items'},
      load: (c) async {
        final wallets = {for (final w in await c.repos.wallets.getAll()) w.id: w};
        final budget = {for (final b in await c.repos.budgetItems.getAll()) b.id: b.name};
        return c.mapRows(
          c.repos.transactions,
          (t) => () {
            final wallet = wallets[t.walletId];
            final category = budget[t.budgetItemId];
            final note = t.note?.trim() ?? '';
            final kind = _txKind(c.l10n, t.kind);
            return SearchDoc(
              id: t.id,
              refTable: 'transactions',
              refId: t.id,
              title: note.isNotEmpty ? note : (category ?? kind),
              subtitle: c.join([
                c.money(t.amountMilli, wallet?.currency ?? 'JOD'),
                kind,
                wallet?.name,
                if (wallets[t.toWalletId] case final to?) '→ ${to.name}',
                if (note.isNotEmpty) category,
              ]),
              body: t.tags.map((tag) => '#$tag').join(' '),
              date: t.date,
              planetKey: 'money',
              extra: {'walletId': t.walletId},
            );
          }(),
        );
      },
    ),
    SearchSource(
      id: 'budget_items',
      planetKey: 'money',
      icon: Icons.pie_chart_rounded,
      labelKey: 'searchSourceBudget',
      tables: const {'budget_items'},
      load: (c) async {
        final items = await c.repos.budgetItems.getAll();
        final names = {for (final b in items) b.id: b.name};
        return [
          for (final b in items)
            SearchDoc(
              id: b.id,
              refTable: 'budget_items',
              refId: b.id,
              title: b.name,
              subtitle: c.join([
                names[b.parentId],
                if (b.amountMilli != null && b.mode == BudgetMode.amount) c.money(b.amountMilli!, b.currency ?? 'JOD'),
                if (b.percent != null && b.mode == BudgetMode.percent) c.formatter.formatPercent(b.percent! / 100),
              ]),
              planetKey: 'money',
            ),
        ];
      },
    ),
    _rows(
      id: 'jars',
      planet: 'money',
      icon: Icons.savings_rounded,
      label: 'searchSourceJars',
      table: (r) => r.jars,
      map: (j, c) => SearchDoc(
        id: j.id,
        refTable: 'jars',
        refId: j.id,
        title: j.name,
        subtitle: c.join([c.money(j.targetMilli, j.currency), if (j.archived) c.l10n.searchArchived]),
        date: j.deadline,
        planetKey: 'money',
      ),
    ),
    SearchSource(
      id: 'jar_deposits',
      planetKey: 'money',
      icon: Icons.move_to_inbox_rounded,
      labelKey: 'searchSourceJarDeposits',
      weight: 0.7,
      tables: const {'jar_deposits', 'jars'},
      load: (c) async {
        final jars = {for (final j in await c.repos.jars.getAll()) j.id: j};
        return c.mapRows(
          c.repos.jarDeposits,
          (d) => SearchDoc(
            id: d.id,
            refTable: 'jar_deposits',
            refId: d.id,
            title: d.note!.trim(),
            subtitle: c.join([jars[d.jarId]?.name, c.money(d.amountMilli, jars[d.jarId]?.currency ?? 'JOD')]),
            date: d.date,
            planetKey: 'money',
            extra: {'jarId': d.jarId},
          ),
          where: (t) => _filled(t.note),
        );
      },
    ),
    _rows(
      id: 'debts',
      planet: 'money',
      icon: Icons.handshake_rounded,
      label: 'searchSourceDebts',
      table: (r) => r.debts,
      map: (d, c) => SearchDoc(
        id: d.id,
        refTable: 'debts',
        refId: d.id,
        title: d.person,
        subtitle: c.join([
          d.direction == DebtDirection.iOwe ? c.l10n.searchDebtIOwe : c.l10n.searchDebtOwedToMe,
          c.money(d.amountMilli, d.currency),
          if (d.settledAt != null) c.l10n.searchDone,
        ]),
        body: d.note ?? '',
        date: d.dueDate ?? d.createdAt,
        planetKey: 'money',
      ),
    ),
    SearchSource(
      id: 'debt_payments',
      planetKey: 'money',
      icon: Icons.price_check_rounded,
      labelKey: 'searchSourceDebtPayments',
      weight: 0.7,
      tables: const {'debt_payments', 'debts'},
      load: (c) async {
        final debts = {for (final d in await c.repos.debts.getAll()) d.id: d};
        return c.mapRows(
          c.repos.debtPayments,
          (p) => SearchDoc(
            id: p.id,
            refTable: 'debt_payments',
            refId: p.id,
            title: p.note!.trim(),
            subtitle: c.join([debts[p.debtId]?.person, c.money(p.amountMilli, debts[p.debtId]?.currency ?? 'JOD')]),
            date: p.date,
            planetKey: 'money',
            extra: {'debtId': p.debtId},
          ),
          where: (t) => _filled(t.note),
        );
      },
    ),
    _rows(
      id: 'obligations',
      planet: 'money',
      icon: Icons.event_repeat_rounded,
      label: 'searchSourceObligations',
      table: (r) => r.obligations,
      map: (o, c) => SearchDoc(
        id: o.id,
        refTable: 'obligations',
        refId: o.id,
        title: o.name,
        subtitle: c.money(o.amountMilli, o.currency),
        body: o.note ?? '',
        date: o.nextDue,
        planetKey: 'money',
      ),
    ),

    // ---------------------------------------------------------- family
    _rows(
      id: 'people',
      planet: 'family',
      icon: Icons.person_rounded,
      label: 'searchSourcePeople',
      weight: 1.1,
      table: (r) => r.people,
      // The phone number is never indexed.
      map: (p, c) => SearchDoc(
        id: p.id,
        refTable: 'people',
        refId: p.id,
        title: p.name,
        subtitle: p.relation ?? '',
        body: p.notes ?? '',
        date: p.lastContact,
        planetKey: 'family',
      ),
    ),
    SearchSource(
      id: 'contact_logs',
      planetKey: 'family',
      icon: Icons.forum_rounded,
      labelKey: 'searchSourceContactLogs',
      weight: 0.8,
      tables: const {'contact_logs', 'people'},
      load: (c) async {
        final people = {for (final p in await c.repos.people.getAll()) p.id: p.name};
        return c.mapRows(
          c.repos.contactLogs,
          (x) => SearchDoc(
            id: x.id,
            refTable: 'contact_logs',
            refId: x.id,
            title: people[x.personId] ?? '',
            subtitle: _channel(c.l10n, x.channel),
            body: x.note ?? '',
            date: x.at,
            planetKey: 'family',
            extra: {'personId': x.personId},
          ),
          where: (t) => _filled(t.note),
        );
      },
    ),

    // ------------------------------------------------------------ work
    _rows(
      id: 'projects',
      planet: 'work',
      icon: Icons.rocket_launch_rounded,
      label: 'searchSourceProjects',
      table: (r) => r.projects,
      map: (p, c) => SearchDoc(
        id: p.id,
        refTable: 'projects',
        refId: p.id,
        title: p.name,
        body: p.description ?? '',
        date: p.deadline,
        planetKey: p.planetKey ?? 'work',
      ),
    ),
    SearchSource(
      id: 'project_items',
      planetKey: 'work',
      icon: Icons.checklist_rounded,
      labelKey: 'searchSourceProjectItems',
      tables: const {'project_items', 'projects'},
      load: (c) async {
        final projects = {for (final p in await c.repos.projects.getAll()) p.id: p};
        return c.mapRows(
          c.repos.projectItems,
          (i) => SearchDoc(
            id: i.id,
            refTable: 'project_items',
            refId: i.id,
            title: i.body,
            subtitle: c.join([projects[i.projectId]?.name, if (i.done) c.l10n.searchDone]),
            date: i.dueDate,
            planetKey: projects[i.projectId]?.planetKey ?? 'work',
            extra: {'projectId': i.projectId},
          ),
        );
      },
    ),
    _rows(
      id: 'boards',
      planet: 'work',
      icon: Icons.view_kanban_rounded,
      label: 'searchSourceBoards',
      table: (r) => r.boards,
      map: (b, c) => SearchDoc(
        id: b.id,
        refTable: 'boards',
        refId: b.id,
        title: b.name,
        subtitle: b.country ?? '',
        planetKey: 'work',
      ),
    ),
    SearchSource(
      id: 'board_cards',
      planetKey: 'work',
      icon: Icons.sticky_note_2_rounded,
      labelKey: 'searchSourceCards',
      tables: const {'board_cards', 'boards'},
      load: (c) async {
        final boards = {for (final b in await c.repos.boards.getAll()) b.id: b};
        String? column(BoardRow? b, String id) {
          for (final col in b?.columns ?? const <Object?>[]) {
            if (col is Map && col['id'] == id) return '${col['label'] ?? id}';
          }
          return null;
        }

        return c.mapRows(
          c.repos.boardCards,
          (k) => SearchDoc(
            id: k.id,
            refTable: 'board_cards',
            refId: k.id,
            title: k.title,
            subtitle: c.join([boards[k.boardId]?.name, column(boards[k.boardId], k.columnId), k.assignee]),
            body: k.notes ?? '',
            date: k.dueDate,
            planetKey: 'work',
            extra: {'boardId': k.boardId, 'columnId': k.columnId},
          ),
        );
      },
    ),

    // ---------------------------------------------------------- travel
    _rows(
      id: 'trips',
      planet: 'travel',
      icon: Icons.flight_takeoff_rounded,
      label: 'searchSourceTrips',
      table: (r) => r.trips,
      map: (t, c) => SearchDoc(
        id: t.id,
        refTable: 'trips',
        refId: t.id,
        title: t.destination,
        subtitle: t.country ?? '',
        body: t.notes ?? '',
        date: t.startDate,
        planetKey: 'travel',
      ),
    ),
    SearchSource(
      id: 'trip_items',
      planetKey: 'travel',
      icon: Icons.luggage_rounded,
      labelKey: 'searchSourceTripItems',
      weight: 0.8,
      tables: const {'trip_items', 'trips'},
      load: (c) async {
        final trips = {for (final t in await c.repos.trips.getAll()) t.id: t};
        return c.mapRows(
          c.repos.tripItems,
          (i) => SearchDoc(
            id: i.id,
            refTable: 'trip_items',
            refId: i.id,
            title: i.body,
            subtitle: c.join([trips[i.tripId]?.destination, i.category]),
            date: trips[i.tripId]?.startDate,
            planetKey: 'travel',
            extra: {'tripId': i.tripId},
          ),
        );
      },
    ),
    _rows(
      id: 'packing_templates',
      planet: 'travel',
      icon: Icons.backpack_rounded,
      label: 'searchSourcePackingTemplates',
      table: (r) => r.packingTemplates,
      map: (p, c) => SearchDoc(
        id: p.id,
        refTable: 'packing_templates',
        refId: p.id,
        title: p.name,
        body: p.items.join(c.listSeparator),
        planetKey: 'travel',
      ),
    ),
    _rows(
      id: 'travel_documents',
      planet: 'travel',
      icon: Icons.badge_rounded,
      label: 'searchSourceTravelDocuments',
      table: (r) => r.travelDocuments,
      // The document number is never indexed.
      map: (d, c) => SearchDoc(
        id: d.id,
        refTable: 'travel_documents',
        refId: d.id,
        title: d.name,
        subtitle: d.holder ?? '',
        body: d.notes ?? '',
        date: d.expiry,
        planetKey: 'travel',
      ),
    ),

    // ---------------------------------------------------------- growth
    _rows(
      id: 'learning_goals',
      planet: 'growth',
      icon: Icons.school_rounded,
      label: 'searchSourceLearningGoals',
      table: (r) => r.learningGoals,
      map: (g, c) => SearchDoc(
        id: g.id,
        refTable: 'learning_goals',
        refId: g.id,
        title: g.name,
        subtitle: '${c.number(g.target)} ${g.unit}'.trim(),
        date: g.deadline,
        planetKey: 'growth',
      ),
    ),
    SearchSource(
      id: 'goal_logs',
      planetKey: 'growth',
      icon: Icons.trending_up_rounded,
      labelKey: 'searchSourceGoalLogs',
      weight: 0.7,
      tables: const {'goal_logs', 'learning_goals'},
      load: (c) async {
        final goals = {for (final g in await c.repos.learningGoals.getAll()) g.id: g};
        return c.mapRows(
          c.repos.goalLogs,
          (x) => SearchDoc(
            id: x.id,
            refTable: 'goal_logs',
            refId: x.id,
            title: x.note!.trim(),
            subtitle: c.join([goals[x.goalId]?.name, '${c.number(x.amount)} ${goals[x.goalId]?.unit ?? ''}'.trim()]),
            date: x.at,
            planetKey: 'growth',
            extra: {'goalId': x.goalId},
          ),
          where: (t) => _filled(t.note),
        );
      },
    ),

    // ------------------------------------------------------------ body
    _rows(
      id: 'exercises',
      planet: 'body',
      icon: Icons.fitness_center_rounded,
      label: 'searchSourceExercises',
      table: (r) => r.exercises,
      map: (e, c) => SearchDoc(
        id: e.id,
        refTable: 'exercises',
        refId: e.id,
        title: e.name,
        subtitle: _workout(c, e.sets, e.reps, e.weight, e.durationMin),
        body: e.notes ?? '',
        planetKey: 'body',
      ),
    ),
    _rows(
      id: 'workout_logs',
      planet: 'body',
      icon: Icons.directions_run_rounded,
      label: 'searchSourceWorkouts',
      weight: 0.8,
      table: (r) => r.workoutLogs,
      map: (w, c) => SearchDoc(
        id: w.id,
        refTable: 'workout_logs',
        refId: w.id,
        title: w.name,
        subtitle: _workout(c, w.sets, w.reps, w.weight, w.durationMin),
        body: w.notes ?? '',
        date: w.at,
        planetKey: 'body',
        extra: {'exerciseId': ?w.exerciseId},
      ),
    ),
    _rows(
      id: 'avoid_items',
      planet: 'body',
      icon: Icons.do_not_disturb_on_rounded,
      label: 'searchSourceAvoidItems',
      table: (r) => r.avoidItems,
      map: (a, c) => SearchDoc(
        id: a.id,
        refTable: 'avoid_items',
        refId: a.id,
        title: a.body,
        body: a.reason ?? '',
        planetKey: 'body',
      ),
    ),
    SearchSource(
      id: 'fasting_sessions',
      planetKey: 'body',
      icon: Icons.timelapse_rounded,
      labelKey: 'searchSourceFasting',
      weight: 0.7,
      tables: const {'fasting_sessions'},
      load: (c) async => [
        for (final f in await c.repos.fastingSessions.getAll(where: (t) => _filled(t.note)))
          SearchDoc(
            id: f.id,
            refTable: 'fasting_sessions',
            refId: f.id,
            title: f.note!.trim(),
            subtitle: c.join([c.l10n.searchFastingTitle, c.number(f.targetHours)]),
            date: f.start,
            planetKey: 'body',
          ),
      ],
    ),

    // ------------------------------------------------- custom modules
    CustomModuleSearch.modules(),
    CustomModuleSearch.entries(),
  ];

  static String _workout(SearchLoadContext c, int? sets, int? reps, double? weight, int? minutes) => c.join([
    if (sets != null && reps != null)
      c.formatter.localizeDigits('$sets×$reps')
    else if (sets != null)
      c.formatter.formatInt(sets)
    else if (reps != null)
      c.formatter.formatInt(reps),
    if (weight != null) c.number(weight),
    if (minutes != null) c.formatter.localizeDigits('$minutes′'),
  ]);

  /// SQL tables that are never read by a built-in source.
  static const Set<String> neverIndexed = {
    'key_values',
    'reminders',
    'activity_log',
    'import_archive',
    'tag_options',
    'habit_logs',
    'med_rules',
    'water_logs',
    'quran_sessions',
    'hifz_reviews',
    'currencies',
    'obligation_payments',
  };
}
