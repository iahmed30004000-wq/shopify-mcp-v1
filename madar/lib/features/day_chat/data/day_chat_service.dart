/// The daily chat's writes: read a line, apply one piece, edit one, reject
/// one – each with an undo, and nothing written until he says so.
///
/// It is the Part 3 plan review's shape, kept on purpose because he already
/// knows and trusts it (`PlanApplyService`): **one** piece at a time, no
/// apply-all, every apply idempotent and undoable.
///
/// Every write goes through the feature's own service – the ledger's
/// [LedgerService], nutrition's [NutritionService], the body's
/// [BodyService], wellbeing's [WellbeingService], the family's
/// [FamilyService], the prayer tracker's [PrayerTrackerRepository], the
/// builder's [CustomModulesService] and home's [HomeTasksService] – so a
/// piece filed from the chat is indistinguishable from one added by hand on
/// its own screen (same activity entries, same planet pulses, same undo).
library;

import '../../../core/db/repositories/repositories.dart';
import '../../../core/domain/enums.dart';
import '../../body/data/body_service.dart';
import '../../custom_modules/data/custom_modules_service.dart';
import '../../custom_modules/domain/field_values.dart';
import '../../family/data/family_service.dart';
import '../../family/domain/family_models.dart' show PersonDraft;
import '../../family/family_texts.dart' show FamilyTexts;
import '../../health/wellbeing/data/wellbeing_service.dart';
import '../../health/wellbeing/domain/wellbeing_drafts.dart';
import '../../home/domain/home_tasks.dart';
import '../../home/domain/prayer_day.dart';
import '../../home/domain/quick_add_handlers.dart' show MoneyQuickAdd, TaskQuickAdd;
import '../../money/ledger/data/ledger_service.dart';
import '../../money/ledger/domain/tx_draft.dart' show TxWrite;
import '../../nutrition/data/nutrition_service.dart';
import '../../prayer_tracker/data/prayer_tracker_repository.dart';
import '../domain/day_chat_journal.dart';
import '../domain/day_chat_piece.dart';
import '../domain/day_chat_reader.dart';
import '../domain/day_chat_vocabulary.dart';
import '../domain/day_summary.dart';
import 'day_chat_store.dart';

/// Puts his data – and the chat's record of the decision – back as they
/// were.
typedef DayChatUndo = Future<void> Function();

/// One applied piece.
class DayChatOutcome {
  const DayChatOutcome({
    required this.piece,
    required this.undo,
    this.refTable,
    this.refId,
    this.alreadyApplied = false,
  });

  final DayChatPiece piece;

  /// The table and row the write landed in (null for a piece that only
  /// ticked something off).
  final String? refTable;
  final String? refId;

  final DayChatUndo undo;

  /// True when this piece had already been applied: nothing was written
  /// this time.
  final bool alreadyApplied;
}

/// Thrown when a caller asks for something the engine must not do: applying
/// a piece that still needs him, or one of a kind that writes nothing.
class DayChatRefused implements Exception {
  DayChatRefused(this.reason);

  final String reason;

  @override
  String toString() => 'DayChatRefused: $reason';
}

/// One write and how to take it back.
class _Write {
  const _Write({this.table, this.id, required this.undo});

  final String? table;
  final String? id;
  final DayChatUndo undo;
}

/// The daily chat, end to end.
///
/// ## What the chat screen builds on
///
/// * [read] – his line in, a [DayChatReading] out: one [DayChatPiece] per
///   thing he said, each with the exact span of his own words, a
///   confidence, and what it could not resolve. Nothing is written.
/// * [remember] / [watchDay] / [day] – the chat as it was, after the app
///   was closed: his lines and what he decided about every piece.
/// * [apply] – **one** piece, only when [DayChatPiece.canApply].
///   Idempotent (a second call writes nothing and says so) and it returns an
///   undo closure. There is deliberately no "apply all".
/// * [applyEdited] – the same, for a piece he corrected first (the screen
///   hands back a piece with the same id and a changed fact).
/// * [reject] – he said no; also undoable, and it writes nothing of his.
/// * [summary] – «شو صار اليوم؟» from his own data, offline, no AI.
/// * [vocabulary] – his modules, people, foods, exercises and open tasks,
///   the names the reader recognises.
///
/// Nothing in here touches the network, and nothing calls an AI: the AI
/// round trip for a sentence the reader could not read is the chat screen's,
/// on his explicit tap, through Part 3's bridge.
class DayChatService {
  DayChatService(
    this.repos, {
    DateTime Function()? clock,
    PrayerDayTimes Function()? prayerDay,
    PrayerWindow Function()? focusedWindow,
    String Function()? defaultWalletName,
    this.ledger,
    this.nutrition,
    this.body,
    this.wellbeing,
    this.family,
    this.modules,
    this.prayers,
    this.tasks,
  }) : clock = clock ?? DateTime.now,
       _prayerDay = prayerDay ?? (() => PrayerDayTimes.placeholder),
       _focusedWindow = focusedWindow ?? (() => PrayerWindow.anytime),
       _walletName = defaultWalletName ?? (() => 'Wallet');

  final Repositories repos;
  final DateTime Function() clock;
  final PrayerDayTimes Function() _prayerDay;
  final PrayerWindow Function() _focusedWindow;
  final String Function() _walletName;

  /// The feature services to write through. The app shell passes the ones
  /// that pulse the orbit (exactly as the quick-add bar does); null builds
  /// a plain service over [repos], which is what tests do.
  final LedgerService Function()? ledger;
  final NutritionService Function()? nutrition;
  final BodyService Function()? body;
  final WellbeingService Function()? wellbeing;
  final FamilyService Function()? family;
  final CustomModulesService Function()? modules;
  final PrayerTrackerRepository Function()? prayers;
  final HomeTasksService Function()? tasks;

  LedgerService get _ledger => ledger?.call() ?? LedgerService(repos, clock: clock);
  NutritionService get _nutrition => nutrition?.call() ?? NutritionService(repos, clock: clock);
  BodyService get _body => body?.call() ?? BodyService(repos, clock: clock);
  WellbeingService get _wellbeing => wellbeing?.call() ?? WellbeingService(repos, clock: clock);
  FamilyService get _family => family?.call() ?? FamilyService(repos, clock: clock);
  CustomModulesService get _modules => modules?.call() ?? CustomModulesService(repos, clock: clock);
  PrayerTrackerRepository get _prayers => prayers?.call() ?? PrayerTrackerRepository(repos, clock: clock);
  HomeTasksService get _tasks => tasks?.call() ?? HomeTasksService(repos, clock: clock);

  /// The chat's memory (JSON in `key_values`, no schema change).
  late final DayChatStore store = DayChatStore(repos.db);

  /// The prayer day the chat is about: a line typed at 00:30 still belongs
  /// to the evening he is talking about.
  DateTime today() => _prayerDay().prayerDayOf(clock());

  // ------------------------------------------------------------- reading --

  /// His own names the reader recognises.
  Future<DayChatVocabulary> vocabulary() async {
    final openTasks = await repos.tasks.getAll();
    return DayChatVocabulary(
      modules: [for (final m in await _modules.modules()) DayChatModule.of(m)],
      people: [for (final p in await repos.people.getAll()) DayChatPerson(id: p.id, name: p.name, relation: p.relation)],
      foods: [
        for (final f in await repos.foods.getAll())
          if (!f.archived) DayChatNamed(id: f.id, name: f.name, unit: f.unit, portion: f.defaultPortion),
      ],
      exercises: [
        for (final e in await repos.exercises.getAll())
          if (e.active) DayChatNamed(id: e.id, name: e.name),
      ],
      openTasks: [
        for (final t in openTasks)
          if (!t.done) DayChatOpenTask(id: t.id, title: t.title),
      ],
    );
  }

  /// Reads one typed line. Offline, no AI, nothing written.
  Future<DayChatReading> read(String text, {DateTime? now, DateTime? day}) async {
    final vocab = await vocabulary();
    final base = (await repos.currencies.base())?.code;
    final reader = DayChatReader(vocabulary: vocab, baseCurrency: base);
    return reader.read(text, now: now ?? clock(), day: day ?? today());
  }

  // -------------------------------------------------------------- memory --

  Future<DayChatDay> day([DateTime? day]) => store.day(day ?? today());

  Stream<DayChatDay> watchDay([DateTime? day]) => store.watchDay(day ?? today());

  Stream<List<DateTime>> watchDays() => store.watchDays();

  /// Keeps his line and the pieces it was read into, so the chat is still
  /// there tomorrow. Returns the stored line.
  Future<DayChatLine> remember(DayChatReading reading, {String? lineId, DateTime? at}) async {
    final line = DayChatLine(
      id: lineId ?? 'l${(at ?? clock()).microsecondsSinceEpoch}',
      at: at ?? clock(),
      text: reading.raw,
      pieceIds: [for (final p in reading.pieces) p.id],
    );
    await store.update(reading.day, (d) => d.withLine(line));
    return line;
  }

  /// Forgets one line of the chat (his data stays exactly as it is).
  Future<void> forgetLine(DateTime day, String lineId) => store.update(day, (d) => d.withoutLine(lineId));

  Future<DayChatState> stateOf(DayChatPiece piece, {DateTime? day}) async =>
      (await store.day(day ?? today())).stateOf(piece.id);

  // -------------------------------------------------------------- decide --

  /// Applies **one** piece.
  ///
  /// Idempotent: a second call on a piece that is already applied writes
  /// nothing and comes back with [DayChatOutcome.alreadyApplied]. The undo
  /// puts his data back and marks the piece undone again.
  Future<DayChatOutcome> apply(DayChatPiece piece, {DateTime? day}) async {
    if (!piece.canApply) throw DayChatRefused('${piece.kind.name}: ${piece.gaps.map((g) => g.kind.name).join(',')}');
    final theDay = day ?? today();
    final before = (await store.day(theDay)).decision(piece.id);
    if (before != null && before.isApplied && await _stillThere(before)) {
      return DayChatOutcome(
        piece: piece,
        undo: () async {},
        refTable: before.refTable,
        refId: before.refId,
        alreadyApplied: true,
      );
    }
    final write = await _write(piece);
    final at = clock();
    await store.update(
      theDay,
      (d) => d.withDecision(
        DayChatDecision(
          pieceId: piece.id,
          state: DayChatState.applied,
          at: at,
          kind: piece.kind,
          refTable: write.table,
          refId: write.id,
          text: piece.text,
          edited: piece.edited,
        ),
      ),
    );
    return DayChatOutcome(
      piece: piece,
      refTable: write.table,
      refId: write.id,
      undo: () async {
        await write.undo();
        await store.update(
          theDay,
          (d) => d.withDecision(
            DayChatDecision(
              pieceId: piece.id,
              state: DayChatState.undone,
              at: clock(),
              kind: piece.kind,
              text: piece.text,
              edited: piece.edited,
            ),
          ),
        );
      },
    );
  }

  /// A piece he corrected first: the screen hands back the same piece with
  /// a changed fact (and [DayChatPiece.edited] set by [DayChatPiece.copyWith]).
  Future<DayChatOutcome> applyEdited(DayChatPiece piece, DayChatFact fact, {DateTime? day}) =>
      apply(piece.copyWith(fact: fact, gaps: const [], edited: true), day: day);

  /// He said no. Undoable, and nothing of his is written.
  Future<DayChatUndo> reject(DayChatPiece piece, {DateTime? day}) async {
    final theDay = day ?? today();
    final before = (await store.day(theDay)).decision(piece.id);
    if (before != null && before.isApplied) {
      throw DayChatRefused('${piece.id}: applied – undo it first');
    }
    await store.update(
      theDay,
      (d) => d.withDecision(
        DayChatDecision(
          pieceId: piece.id,
          state: DayChatState.rejected,
          at: clock(),
          kind: piece.kind,
          text: piece.text,
        ),
      ),
    );
    return () async => store.update(
      theDay,
      (d) => before == null
          ? DayChatDay(day: d.day, lines: d.lines, decisions: {...d.decisions}..remove(piece.id))
          : d.withDecision(before),
    );
  }

  /// Whether the row an earlier apply wrote is still in his data (he may
  /// have deleted it on its own screen – then applying again is right).
  Future<bool> _stillThere(DayChatDecision decision) async {
    final table = decision.refTable;
    final id = decision.refId;
    if (table == null || id == null) return true;
    final repo = repos.forTable(table);
    if (repo == null) return true;
    return await repo.byId(id) != null;
  }

  // -------------------------------------------------------------- writes --

  Future<_Write> _write(DayChatPiece piece) async {
    final fact = piece.fact;
    switch (fact) {
      case MoneyFact():
        return _money(fact);
      case MealFact():
        return _meal(fact);
      case WorkoutFact():
        return _workout(fact);
      case WaterFact():
        final (row, undo) = await _body.addWater(fact.ml, at: fact.at);
        return _Write(table: 'water_logs', id: row.id, undo: undo);
      case PainFact():
        final row = await _wellbeing.logPain(
          PainDraft(at: fact.at, score: fact.score, locations: [?_blank(fact.location)]),
        );
        return _Write(table: 'pain_entries', id: row.id, undo: () async => _wellbeing.deletePain(row.id));
      case MoodFact():
        final row = await _wellbeing.logMood(MoodDraft(at: fact.at, mood: fact.score, notes: _blank(fact.note)));
        return _Write(table: 'mood_entries', id: row.id, undo: () async => _wellbeing.deleteMood(row.id));
      case PrayerFact():
        return _prayer(fact);
      case TaskDoneFact():
        return _taskDone(fact);
      case TaskTodoFact():
        return _todo(fact);
      case ContactFact():
        return _contact(fact);
      case ModuleFact():
        return _module(piece, fact);
      case NoteFact():
        return _note(fact);
      case UnreadFact():
        throw DayChatRefused('unread pieces are never written on their own');
    }
  }

  static String? _blank(String? s) {
    final t = s?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  Future<_Write> _money(MoneyFact fact) async {
    if (fact.amountMilli <= 0) throw DayChatRefused('money: no amount');
    final currency = fact.currency ?? (await repos.currencies.base())?.code ?? 'JOD';
    final wallet = await MoneyQuickAdd.walletFor(repos, currency, _walletName());
    final service = _ledger;
    final tx = await service.add(
      TxWrite(
        walletId: wallet.id,
        kind: fact.income ? TxKind.income : TxKind.expense,
        amountMilli: fact.amountMilli,
        date: fact.at,
        note: _blank(fact.note),
      ),
    );
    return _Write(table: 'transactions', id: tx.id, undo: () async {
      await service.delete(tx.id);
    });
  }

  Future<_Write> _meal(MealFact fact) async {
    final (row, undo) = await _nutrition.logFood(
      FoodLogDraft(
        name: fact.name,
        at: fact.at,
        foodId: fact.foodId,
        portion: fact.portion,
        unit: fact.unit,
        note: _blank(fact.note),
      ),
    );
    return _Write(table: 'food_logs', id: row.id, undo: undo);
  }

  Future<_Write> _workout(WorkoutFact fact) async {
    final (row, undo) = await _body.logWorkout(
      WorkoutDraft(
        name: fact.name,
        at: fact.at,
        exerciseId: fact.exerciseId,
        sets: fact.sets,
        reps: fact.reps,
        weight: fact.weight,
        durationMin: fact.durationMin,
      ),
    );
    return _Write(table: 'workout_logs', id: row.id, undo: undo);
  }

  Future<_Write> _prayer(PrayerFact fact) async {
    final tracker = _prayers;
    final undos = <Future<void> Function()>[];
    final status = await tracker.setStatus(fact.day, fact.prayer, fact.status);
    undos.add(status.undo);
    if (fact.inJamaah) {
      final change = await tracker.setJamaah(fact.day, fact.prayer, true);
      undos.add(change.undo);
    }
    if (fact.atMosque) {
      final change = await tracker.setMosque(fact.day, fact.prayer, true);
      undos.add(change.undo);
    }
    final row = status.after ?? await tracker.logOf(fact.day, fact.prayer);
    return _Write(
      table: PrayerTrackerRepository.table,
      id: row?.id,
      undo: () async {
        for (final u in undos.reversed) {
          await u();
        }
      },
    );
  }

  Future<_Write> _taskDone(TaskDoneFact fact) async {
    final service = _tasks;
    final id = fact.taskId;
    if (id != null) {
      final row = await repos.tasks.byId(id);
      if (row != null) {
        if (row.done) return _Write(table: HomeTasksService.table, id: row.id, undo: () async {});
        final undo = await service.toggleDone(row);
        return _Write(table: HomeTasksService.table, id: row.id, undo: undo);
      }
    }
    // Nothing of his matched: the finished thing is still part of his day,
    // so it is filed as a task that is already done.
    final day = today();
    final created = await service.add(
      title: fact.title,
      window: _windowNow(day),
      date: day,
    );
    final undo = await service.toggleDone(created);
    return _Write(
      table: HomeTasksService.table,
      id: created.id,
      undo: () async {
        await undo();
        await service.delete(created);
      },
    );
  }

  Future<_Write> _todo(TaskTodoFact fact) async {
    final day = today();
    final times = _prayerDay();
    final now = clock();
    // The quick-add bar's own rule, shared with it (see
    // `TaskQuickAdd.windowFor`): the window he said, else the window of the
    // time he said, else the one he is looking at.
    final window = TaskQuickAdd.windowFor(
      stated: fact.window,
      time: fact.time,
      day: times,
      now: now,
      focused: _focusedWindow(),
    );
    final created = await _tasks.add(
      title: fact.title,
      window: window,
      date: fact.date ?? day,
      planetKey: fact.planetKey,
    );
    return _Write(
      table: HomeTasksService.table,
      id: created.id,
      undo: () async {
        await _tasks.delete(created);
      },
    );
  }

  Future<_Write> _note(NoteFact fact) async {
    final created = await _tasks.add(
      title: fact.text,
      window: fact.window != null && fact.window != PrayerWindow.anytime ? fact.window! : _windowNow(fact.day),
      date: fact.day,
      planetKey: fact.planetKey,
    );
    return _Write(
      table: HomeTasksService.table,
      id: created.id,
      undo: () async {
        await _tasks.delete(created);
      },
    );
  }

  Future<_Write> _contact(ContactFact fact) async {
    final service = _family;
    var personId = fact.personId;
    String? createdId;
    if (personId == null) {
      final relation = FamilyTexts.relationKeyFor(fact.name);
      final person = await service.addPerson(PersonDraft(name: fact.name.trim(), relation: relation));
      personId = person.id;
      createdId = person.id;
    }
    final logged = await service.logContact(personId, channel: fact.channel, at: fact.at);
    return _Write(
      table: 'contact_logs',
      id: logged.log.id,
      undo: () async {
        await logged.undo();
        if (createdId != null) await service.deletePerson(createdId);
      },
    );
  }

  Future<_Write> _module(DayChatPiece piece, ModuleFact fact) async {
    if (fact.moduleId.isEmpty) throw DayChatRefused('sign: no module of his was named');
    final fieldId = fact.fieldId;
    if (fieldId == null) throw DayChatRefused('module ${fact.moduleId}: no field');
    final definition = await _modules.module(fact.moduleId);
    if (definition == null) throw DayChatRefused('module ${fact.moduleId}: gone');
    final field = definition.field(fieldId);
    if (field == null) throw DayChatRefused('module ${fact.moduleId}: field $fieldId gone');
    final value = FieldValues.normalize(field, fact.value);
    final (entry, undo) = await _modules.addEntry(fact.moduleId, {fieldId: value}, at: fact.at);
    return _Write(table: CustomModulesService.entriesTable, id: entry.id, undo: undo);
  }

  PrayerWindow _windowNow(DateTime day) {
    final focused = _focusedWindow();
    if (focused != PrayerWindow.anytime) return focused;
    return _prayerDay().windowAt(clock());
  }

  // ------------------------------------------------------------- summary --

  /// «شو صار اليوم؟» – his own day, from his own data, offline.
  Future<DaySummary> summary({DateTime? day}) async {
    final theDay = day ?? today();
    return DaySummaryBuilder().build(await summaryInput(day: theDay));
  }

  /// Everything the day summary reads (so a test can build it by hand).
  Future<DaySummaryInput> summaryInput({DateTime? day}) async {
    final theDay = day ?? today();
    final times = _prayerDay();
    bool onDay(DateTime at) => _sameDay(times.prayerDayOf(at), theDay);
    // The ledger dates an entry by the calendar day (no clock time), so a
    // prayer day would push a midnight date onto the day before.
    bool onCalendarDay(DateTime at) => _sameDay(at, theDay);
    final chat = await store.day(theDay);
    return DaySummaryInput(
      day: theDay,
      now: clock(),
      transactions: [
        for (final t in await repos.transactions.getAll())
          if (onCalendarDay(t.date)) t,
      ],
      wallets: await repos.wallets.getAll(),
      foodLogs: [
        for (final f in await repos.foodLogs.getAll())
          if (onDay(f.at)) f,
      ],
      workouts: [
        for (final w in await repos.workoutLogs.getAll())
          if (onDay(w.at)) w,
      ],
      water: [
        for (final w in await repos.waterLogs.getAll())
          if (onDay(w.at)) w,
      ],
      waterTargetMl: await repos.keyValues.get(BodyService.waterTargetKey),
      pain: [
        for (final p in await repos.painEntries.getAll())
          if (onDay(p.at)) p,
      ],
      moods: [
        for (final m in await repos.moodEntries.getAll())
          if (onDay(m.at)) m,
      ],
      prayers: await _prayers.dayLogs(theDay),
      tasks: [
        for (final t in await repos.tasks.getAll())
          if (TaskDayFilter.includes(t, theDay, times: times)) t,
      ],
      contacts: [
        for (final c in await repos.contactLogs.getAll())
          if (onDay(c.at)) c,
      ],
      people: await repos.people.getAll(),
      moduleEntries: [
        for (final e in await repos.customEntries.getAll())
          if (onDay(e.at)) e,
      ],
      modules: [for (final m in await _modules.modules()) DayChatModule.of(m)],
      chat: chat,
      baseCurrency: (await repos.currencies.base())?.code,
    );
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}
