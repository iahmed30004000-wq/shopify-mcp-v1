import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../../../core/domain/enums.dart';
import '../../../core/interaction/quick_add/parser.dart';
import '../../../core/interaction/quick_add/quick_add_handler.dart';
import '../../money/ledger/data/ledger_service.dart';
import '../../money/ledger/domain/tx_draft.dart' show TxWrite;
import 'home_tasks.dart';
import 'prayer_day.dart';

/// Everything the shell's quick-add handlers need, read lazily at the moment
/// an intent is handled (so the handler can be registered before the
/// database is unlocked).
class QuickAddContext {
  const QuickAddContext({
    required this.repositories,
    required this.clock,
    required this.prayerDay,
    required this.focusedWindow,
    required this.defaultWalletName,
    this.ledger,
  });

  final Repositories Function() repositories;
  final DateTime Function() clock;
  final PrayerDayTimes Function() prayerDay;

  /// The window the user is looking at on home – where an unscheduled task
  /// lands.
  final PrayerWindow Function() focusedWindow;

  /// Localised name of the wallet quick add creates on demand.
  final String Function() defaultWalletName;

  /// The ledger's service (the app's records through the orbit's pulse
  /// hub, so the Money world pulses); null: a plain [LedgerService] over
  /// [repositories].
  final LedgerService Function()? ledger;
}

/// The app's quick-add handler: routes each [QuickAddKind] to a small
/// handler below. Register it with
/// `quickAddHandlerProvider.overrideWith((ref) => shellQuickAddHandler(...))`
/// (the app shell does); features can later replace single kinds by
/// building their own [KindQuickAddHandler].
QuickAddHandler shellQuickAddHandler(QuickAddContext c) {
  final tasks = TaskQuickAdd(c);
  return KindQuickAddHandler({
    QuickAddKind.task: tasks,
    QuickAddKind.note: tasks,
    QuickAddKind.expense: MoneyQuickAdd(c),
    QuickAddKind.income: MoneyQuickAdd(c),
    QuickAddKind.water: WaterQuickAdd(c),
    QuickAddKind.pain: PainQuickAdd(c),
    QuickAddKind.mood: MoodQuickAdd(c),
    QuickAddKind.contact: ContactQuickAdd(c),
  });
}

/// Tasks (and notes, kept as tasks): the stated window, else the window of
/// the stated clock time, else the window in focus; the stated day, else
/// today's prayer day.
class TaskQuickAdd extends QuickAddHandler {
  const TaskQuickAdd(this.c);

  final QuickAddContext c;

  @override
  Future<bool> handle(QuickAddIntent intent) async {
    final title = intent.title.trim().isEmpty ? intent.raw.trim() : intent.title.trim();
    if (title.isEmpty) return false;
    final day = c.prayerDay();
    final now = c.clock();
    final at = intent.dateTime;
    final PrayerWindow window;
    if (intent.window != null && intent.window != PrayerWindow.anytime) {
      window = intent.window!;
    } else if (intent.time != null) {
      final (h, m) = _hm(intent.time!);
      window = day.windowAt(DateTime(now.year, now.month, now.day, h, m));
    } else {
      window = c.focusedWindow();
    }
    final date = at ?? intent.date ?? day.prayerDayOf(now);
    await HomeTasksService(
      c.repositories(),
      clock: c.clock,
    ).add(title: title, window: window, date: date, planetKey: intent.planetKey);
    return true;
  }

  static (int, int) _hm(String hhmm) {
    final p = hhmm.split(':');
    return (int.tryParse(p.first) ?? 0, p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0);
  }
}

/// Expenses and income into the first open wallet of the intent's currency
/// (the base currency when none was stated). A wallet is created on demand.
/// The entry is written by the ledger's own service, exactly like one added
/// in the ledger (activity `money.tx`, the Money world pulses).
class MoneyQuickAdd extends QuickAddHandler {
  const MoneyQuickAdd(this.c);

  final QuickAddContext c;

  @override
  Future<bool> handle(QuickAddIntent intent) async {
    final amount = intent.amountMilli;
    if (amount == null || amount <= 0) return false;
    final kind = intent.kind == QuickAddKind.income ? TxKind.income : TxKind.expense;
    final repos = c.repositories();
    final currency = intent.currency ?? (await repos.currencies.base())?.code ?? 'JOD';
    final wallet = await walletFor(repos, currency, c.defaultWalletName());
    final ledger = c.ledger?.call() ?? LedgerService(repos, clock: c.clock);
    final note = intent.title.trim();
    await ledger.add(
      TxWrite(
        walletId: wallet.id,
        kind: kind,
        amountMilli: amount,
        date: intent.dateTime ?? c.clock(),
        note: note.isEmpty ? null : note,
      ),
    );
    return true;
  }

  /// The first non-archived wallet in [currency], created when missing
  /// ("Wallet", or "Wallet · USD" when other wallets already exist).
  static Future<WalletRow> walletFor(Repositories repos, String currency, String defaultName) async {
    final wallets = await repos.wallets.getAll(where: (w) => w.archived.equals(false));
    for (final w in wallets) {
      if (w.currency == currency) return w;
    }
    final name = wallets.isEmpty ? defaultName : '$defaultName · $currency';
    return repos.wallets.insert(WalletsCompanion.insert(name: name, currency: currency));
  }
}

class WaterQuickAdd extends QuickAddHandler {
  const WaterQuickAdd(this.c);

  final QuickAddContext c;

  @override
  Future<bool> handle(QuickAddIntent intent) async {
    final ml = intent.ml;
    if (ml == null || ml <= 0) return false;
    final repos = c.repositories();
    final at = intent.dateTime ?? c.clock();
    final row = await repos.waterLogs.insert(WaterLogsCompanion.insert(at: at, ml: ml));
    await repos.activity.log(
      planetKey: 'health',
      kind: 'health.water',
      refTable: 'water_logs',
      refId: row.id,
      at: at,
      value: ml.toDouble(),
    );
    return true;
  }
}

class PainQuickAdd extends QuickAddHandler {
  const PainQuickAdd(this.c);

  final QuickAddContext c;

  @override
  Future<bool> handle(QuickAddIntent intent) async {
    final score = intent.score;
    if (score == null) return false;
    final repos = c.repositories();
    final at = intent.dateTime ?? c.clock();
    final where = intent.title.trim();
    final row = await repos.painEntries.insert(
      PainEntriesCompanion.insert(
        at: at,
        score: score.clamp(0, 10),
        locations: Value(where.isEmpty ? const [] : [where]),
      ),
    );
    await repos.activity.log(
      planetKey: 'health',
      kind: 'health.pain',
      refTable: 'pain_entries',
      refId: row.id,
      at: at,
      value: score.toDouble(),
    );
    return true;
  }
}

class MoodQuickAdd extends QuickAddHandler {
  const MoodQuickAdd(this.c);

  final QuickAddContext c;

  @override
  Future<bool> handle(QuickAddIntent intent) async {
    final score = intent.score;
    if (score == null) return false;
    final repos = c.repositories();
    final at = intent.dateTime ?? c.clock();
    final note = intent.title.trim();
    final row = await repos.moodEntries.insert(
      MoodEntriesCompanion.insert(at: at, mood: Value(score.clamp(1, 5)), notes: Value(note.isEmpty ? null : note)),
    );
    await repos.activity.log(
      planetKey: 'health',
      kind: 'health.mood',
      refTable: 'mood_entries',
      refId: row.id,
      at: at,
      value: score.toDouble(),
    );
    return true;
  }
}

/// "Called Mum": logs a contact with the person of that name (created when
/// unknown) and refreshes their last-contact date.
class ContactQuickAdd extends QuickAddHandler {
  const ContactQuickAdd(this.c);

  final QuickAddContext c;

  @override
  Future<bool> handle(QuickAddIntent intent) async {
    final name = intent.title.trim();
    if (name.isEmpty) return false;
    final repos = c.repositories();
    final now = c.clock();
    final at = intent.dateTime ?? now;
    // A contact planned for later ("زيارة بكرا") is a task, not a log.
    if (at.isAfter(now)) return TaskQuickAdd(c).handle(intent);
    final key = name.toLowerCase();
    final people = await repos.people.getAll();
    final person =
        people.where((p) => p.name.trim().toLowerCase() == key).firstOrNull ??
        await repos.people.insert(PeopleCompanion.insert(name: name));
    final log = await repos.contactLogs.insert(
      ContactLogsCompanion.insert(personId: person.id, at: at, channel: Value(intent.channel ?? ContactChannel.other)),
    );
    final last = person.lastContact;
    if (last == null || last.isBefore(at)) await repos.people.setColumn(person.id, 'lastContact', at);
    await repos.activity.log(
      planetKey: 'family',
      kind: 'family.contact',
      refTable: 'contact_logs',
      refId: log.id,
      at: at,
    );
    return true;
  }
}
