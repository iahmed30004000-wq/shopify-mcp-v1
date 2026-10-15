import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../../../core/domain/enums.dart';
import '../domain/contact_stats.dart';
import '../domain/family_models.dart';
import '../domain/rhythm.dart';

/// Undoes one Family change.
typedef FamilyUndo = Future<void> Function();

/// Logs a Family activity (the orbit's pulse hub in the app, so the Family
/// planet pulses at once; the plain activity log otherwise).
typedef FamilyActivityRecorder = Future<void> Function({
  required String kind,
  required String refTable,
  required String refId,
  required DateTime at,
});

/// A logged contact and how to take it back.
class ContactLogged {
  const ContactLogged({required this.log, required this.undo, required this.previousLastContact});

  final ContactLogRow log;
  final FamilyUndo undo;

  /// The person's stored last contact before this one.
  final DateTime? previousLastContact;
}

/// People, their contact log and the Family settings – every write the
/// Family screens make, each with its undo.
///
/// Contacts are written the way the home quick-add ("called Mum") and the
/// orbit's moon sheet write them, so the Family planet, its moons and the
/// Neglect Radar all read the same thing: a `contact_logs` row, the
/// person's `last_contact` moved forward (never back, never into the
/// future) and a `family` / `family.contact` activity pointing at the log.
class FamilyService {
  FamilyService(this.repos, {DateTime Function()? clock, FamilyActivityRecorder? recorder})
    : _clock = clock ?? DateTime.now,
      _recorder = recorder; // ignore: prefer_initializing_formals

  static const String planetKey = 'family';
  static const String contactKind = 'family.contact';
  static const String contactTable = 'contact_logs';

  final Repositories repos;
  final DateTime Function() _clock;
  final FamilyActivityRecorder? _recorder;

  MadarDatabase get _db => repos.db;

  /// Now, to the second (the database stores whole seconds, so what is
  /// written compares equal to what is read back).
  DateTime get now => _seconds(_clock());

  static DateTime _seconds(DateTime t) =>
      DateTime.fromMillisecondsSinceEpoch(t.millisecondsSinceEpoch ~/ 1000 * 1000, isUtc: t.isUtc);

  // ------------------------------------------------------------------ reads

  Stream<List<PersonRow>> watchPeople() => repos.people.watchAll();

  Future<List<PersonRow>> people() => repos.people.getAll();

  Stream<PersonRow?> watchPerson(String id) => repos.people.watchById(id);

  /// Every contact (the overview needs each person's latest).
  Stream<List<ContactLogRow>> watchLogs() => repos.contactLogs.watchAll();

  Future<List<ContactLogRow>> logs() => repos.contactLogs.getAll();

  /// One person's contacts, newest first.
  Stream<List<ContactLogRow>> watchLogsOf(String personId) =>
      repos.contactLogs.watchAll(where: (t) => t.personId.equals(personId)).map(_newestFirst);

  Future<List<ContactLogRow>> logsOf(String personId) async =>
      _newestFirst(await repos.contactLogs.getAll(where: (t) => t.personId.equals(personId)));

  static List<ContactLogRow> _newestFirst(List<ContactLogRow> rows) =>
      rows.toList()..sort((a, b) => b.at.compareTo(a.at));

  static Iterable<({String personId, ContactPoint point})> points(Iterable<ContactLogRow> logs) => [
    for (final l in logs) (personId: l.personId, point: (at: l.at, channel: l.channel)),
  ];

  /// Everyone evaluated now.
  Future<FamilyOverview> overview() async => FamilyOverview.build(await people(), points(await logs()), now);

  // ----------------------------------------------------------------- people

  PeopleCompanion _companion(PersonDraft d) => PeopleCompanion(
    name: Value(d.name),
    relation: Value(d.relation),
    rhythmDays: Value(d.rhythmDays),
    phone: Value(d.phone),
    birthday: Value(d.birthday),
    notes: Value(d.notes),
    color: Value(d.color),
    showAsMoon: Value(d.showAsMoon),
  );

  /// Adds a person (at the end of the manual order). A draft's
  /// `lastContact` seeds the rhythm (clamped to now; no log is written).
  Future<PersonRow> addPerson(PersonDraft draft) {
    final d = draft.normalized();
    if (!d.isValid) throw ArgumentError.value(draft.name, 'name', 'empty');
    final last = d.lastContact == null ? null : _seconds(RhythmEngine.clampToNow(d.lastContact!, now));
    return repos.people.insert(_companion(d).copyWith(lastContact: Value(last)));
  }

  /// Saves [draft] over person [id]; the undo restores the previous row.
  Future<FamilyUndo> updatePerson(String id, PersonDraft draft) async {
    final d = draft.normalized();
    if (!d.isValid) throw ArgumentError.value(draft.name, 'name', 'empty');
    final before = await repos.people.byId(id);
    if (before == null) return () async {};
    await repos.people.update(_companion(d).copyWith(id: Value(id)));
    return () => repos.people.update(before);
  }

  /// Deletes a person and their contact log; the undo restores both (the
  /// activity entries stay – those contacts did happen).
  Future<FamilyUndo> deletePerson(String id) async {
    final (person, logs) = await _db.transaction(() async {
      final logs = await repos.contactLogs.deleteWhere((t) => t.personId.equals(id));
      final person = await repos.people.delete(id);
      return (person, logs);
    });
    return () => _db.transaction(() async {
      if (person != null) await repos.people.restore(person);
      await repos.contactLogs.restoreAll(logs);
    });
  }

  /// Persists a manual order (drag-reorder).
  Future<void> reorder(List<String> idsInOrder) => repos.people.reorder(idsInOrder);

  /// Shows / hides the person as a moon of the Family planet.
  Future<FamilyUndo> setShowAsMoon(String id, bool show) async {
    final before = await repos.people.byId(id);
    if (before == null || before.showAsMoon == show) return () async {};
    await repos.people.setColumn(id, 'showAsMoon', show);
    return () => repos.people.setColumn(id, 'showAsMoon', before.showAsMoon);
  }

  Future<FamilyUndo> setNotes(String id, String? notes) async {
    final before = await repos.people.byId(id);
    if (before == null) return () async {};
    final t = notes?.trim();
    await repos.people.setColumn(id, 'notes', t == null || t.isEmpty ? null : t);
    return () => repos.people.setColumn(id, 'notes', before.notes);
  }

  // --------------------------------------------------------------- contacts

  Future<void> _record(String logId, DateTime at) async {
    final recorder = _recorder;
    if (recorder != null) {
      await recorder(kind: contactKind, refTable: contactTable, refId: logId, at: at);
    } else {
      await repos.activity.log(planetKey: planetKey, kind: contactKind, refTable: contactTable, refId: logId, at: at);
    }
  }

  /// "Contacted": logs a contact at [at] (default now; clamped – never in
  /// the future), moves the person's last contact forward and records a
  /// Family activity. The undo removes exactly this contact and puts the
  /// last contact back.
  Future<ContactLogged> logContact(
    String personId, {
    ContactChannel channel = ContactChannel.other,
    String? note,
    DateTime? at,
  }) async {
    final n = now;
    final when = _seconds(RhythmEngine.clampToNow(at ?? n, n));
    final cleanNote = note?.trim();
    final (log, previous, fromLog) = await _db.transaction(() async {
      final person = await repos.people.byId(personId);
      if (person == null) throw StateError('No person $personId');
      final previous = person.lastContact;
      // Whether the previous value came from a logged contact (then an undo
      // re-derives it from the logs still there) or stands on its own (set
      // when the person was added, or imported) – then an undo restores it.
      final fromLog =
          previous != null &&
          await repos.contactLogs.count(where: (t) => t.personId.equals(personId) & t.at.equals(previous)) > 0;
      final log = await repos.contactLogs.insert(
        ContactLogsCompanion.insert(
          personId: personId,
          at: when,
          channel: Value(channel),
          note: Value(cleanNote == null || cleanNote.isEmpty ? null : cleanNote),
        ),
      );
      final next = RhythmEngine.lastContactAfterLog(stored: previous, at: when, now: n);
      if (next != previous) await repos.people.setColumn(personId, 'lastContact', next);
      return (log, previous, fromLog);
    });
    await _record(log.id, when);
    return ContactLogged(
      log: log,
      previousLastContact: previous,
      undo: () => _removeContact(log, fallback: fromLog ? null : previous),
    );
  }

  Future<void> _removeContact(ContactLogRow log, {DateTime? fallback}) => _db.transaction(() async {
    await repos.contactLogs.delete(log.id);
    await repos.activity.removeFor(refTable: contactTable, refId: log.id, kind: contactKind);
    final person = await repos.people.byId(log.personId);
    if (person == null) return;
    final remaining = await repos.contactLogs.getAll(where: (t) => t.personId.equals(log.personId));
    final next = RhythmEngine.lastContactAfterRemoval(
      stored: person.lastContact,
      removedAt: log.at,
      remaining: [for (final r in remaining) r.at],
      now: now,
      fallback: fallback,
    );
    if (next != person.lastContact) await repos.people.setColumn(log.personId, 'lastContact', next);
  });

  /// Edits a logged contact (channel, note, time – clamped to now); the
  /// last contact follows. The undo restores the log, its activity time and
  /// the last contact.
  Future<FamilyUndo> updateContact(String logId, ContactDraft draft) async {
    final n = now;
    final before = await repos.contactLogs.byId(logId);
    if (before == null) return () async {};
    final at = _seconds(RhythmEngine.clampToNow(draft.at, n));
    final note = draft.note?.trim();
    final personBefore = await repos.people.byId(before.personId);
    final activities = await repos.activityLog.getAll(
      where: (t) => t.refTable.equals(contactTable) & t.refId.equals(logId),
    );
    await _db.transaction(() async {
      await repos.contactLogs.setColumns(logId, {
        'at': at,
        'channel': draft.channel,
        'note': note == null || note.isEmpty ? null : note,
      });
      for (final a in activities) {
        await repos.activityLog.setColumn(a.id, 'at', at);
      }
      final person = await repos.people.byId(before.personId);
      if (person == null) return;
      final others = await repos.contactLogs.getAll(
        where: (t) => t.personId.equals(before.personId) & t.id.equals(logId).not(),
      );
      var next = RhythmEngine.lastContactAfterRemoval(
        stored: person.lastContact,
        removedAt: before.at,
        remaining: [for (final r in others) r.at],
        now: n,
      );
      next = RhythmEngine.lastContactAfterLog(stored: next, at: at, now: n);
      if (next != person.lastContact) await repos.people.setColumn(person.id, 'lastContact', next);
    });
    return () => _db.transaction(() async {
      await repos.contactLogs.update(before);
      for (final a in activities) {
        await repos.activityLog.setColumn(a.id, 'at', a.at);
      }
      if (personBefore != null) await repos.people.setColumn(personBefore.id, 'lastContact', personBefore.lastContact);
    });
  }

  /// Deletes a logged contact (and its activity); the last contact falls
  /// back to the latest remaining one. The undo restores all three.
  Future<FamilyUndo> deleteContact(String logId) async {
    final log = await repos.contactLogs.byId(logId);
    if (log == null) return () async {};
    final personBefore = await repos.people.byId(log.personId);
    final activities = await repos.activityLog.getAll(
      where: (t) => t.refTable.equals(contactTable) & t.refId.equals(logId),
    );
    await _removeContact(log);
    return () => _db.transaction(() async {
      await repos.contactLogs.restore(log);
      await repos.activityLog.restoreAll(activities);
      if (personBefore != null) await repos.people.setColumn(personBefore.id, 'lastContact', personBefore.lastContact);
    });
  }

  // --------------------------------------------------------------- settings

  Stream<FamilySettings> watchSettings() =>
      repos.keyValues.watchJson(FamilySettings.storageKey).map(FamilySettings.fromJson).distinct();

  Future<FamilySettings> settings() async =>
      FamilySettings.fromJson(await repos.keyValues.getJson(FamilySettings.storageKey));

  Future<void> saveSettings(FamilySettings settings) =>
      repos.keyValues.setJson(FamilySettings.storageKey, settings.toJson());
}
