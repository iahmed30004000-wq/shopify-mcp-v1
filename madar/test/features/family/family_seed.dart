// Generic sample people for the Family tests and screenshots (examples
// only – never app data).
import 'package:drift/drift.dart' show Value;
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';

/// "Now" of the Family tests: Tuesday 29 September 2026, 07:00.
final DateTime familyTestNow = DateTime(2026, 9, 29, 7);

Future<PersonRow> seedPerson(
  Repositories repos, {
  required String name,
  String? relation,
  int? rhythm,
  DateTime? lastContact,
  DateTime? createdAt,
  DateTime? birthday,
  String? phone,
  String? notes,
  int? color,
  bool moon = true,
  List<(DateTime, ContactChannel, String?)> logs = const [],
}) async {
  final row = await repos.people.insert(
    PeopleCompanion.insert(
      name: name,
      relation: Value(relation),
      rhythmDays: Value(rhythm),
      lastContact: Value(lastContact),
      birthday: Value(birthday),
      phone: Value(phone),
      notes: Value(notes),
      color: Value(color),
      showAsMoon: Value(moon),
      createdAt: createdAt == null ? const Value.absent() : Value(createdAt),
    ),
  );
  for (final (at, channel, note) in logs) {
    await repos.contactLogs.insert(
      ContactLogsCompanion.insert(personId: row.id, at: at, channel: Value(channel), note: Value(note)),
    );
  }
  return row;
}

DateTime daysAgo(int days, {int hour = 19, DateTime? now}) {
  final n = now ?? familyTestNow;
  return DateTime(n.year, n.month, n.day - days, hour);
}

/// A varied circle: overdue, due today, this week, in touch and without a
/// rhythm; birthdays soon; a history for the first person.
Future<Map<String, PersonRow>> seedFamily(MadarDatabase db, {bool arabic = true, DateTime? now}) async {
  final repos = Repositories(db);
  final n = now ?? familyTestNow;
  DateTime ago(int d, [int h = 19]) => daysAgo(d, hour: h, now: n);
  final created = DateTime(n.year - 1, 1, 10);
  final out = <String, PersonRow>{};
  out['mother'] = await seedPerson(
    repos,
    name: arabic ? 'أمي' : 'Mum',
    relation: 'mother',
    rhythm: 2,
    lastContact: ago(5, 20),
    createdAt: created,
    birthday: DateTime(1962, 10, 2),
    phone: '+962 79 000 0000',
    notes: arabic ? 'تحبّ الورد الجوري وقهوة الصباح على الشرفة' : 'Loves roses and morning coffee on the balcony',
    logs: [
      (ago(40, 18), ContactChannel.visit, null),
      (ago(38, 21), ContactChannel.call, null),
      (ago(35, 20), ContactChannel.call, arabic ? 'سألت عن موعد الطبيب' : 'Asked about the doctor'),
      (ago(33, 13), ContactChannel.visit, arabic ? 'غداء العائلة' : 'Family lunch'),
      (ago(29, 20), ContactChannel.call, null),
      (ago(27, 9), ContactChannel.message, null),
      (ago(24, 20), ContactChannel.call, null),
      (ago(22, 20), ContactChannel.call, null),
      (ago(19, 13), ContactChannel.visit, arabic ? 'غداء العائلة مع الجميع' : 'Family lunch with everyone'),
      (ago(17, 20), ContactChannel.call, null),
      (ago(14, 9), ContactChannel.message, null),
      (ago(12, 13), ContactChannel.visit, null),
      (ago(9, 20), ContactChannel.call, null),
      (ago(7, 21), ContactChannel.call, null),
      (ago(5, 20), ContactChannel.call, arabic ? 'اطمأننت على صحتها' : 'Checked on her health'),
    ],
  );
  out['brother'] = await seedPerson(
    repos,
    name: arabic ? 'أخي أحمد' : 'Adam',
    relation: 'brother',
    rhythm: 7,
    lastContact: ago(7, 21),
    createdAt: created,
    logs: [(ago(7, 21), ContactChannel.call, null)],
  );
  out['friend'] = await seedPerson(
    repos,
    name: arabic ? 'سامي' : 'Sam',
    relation: 'friend',
    rhythm: 14,
    lastContact: ago(24, 22),
    createdAt: created,
    color: 0xFF9C8CFF,
    logs: [(ago(24, 22), ContactChannel.message, null)],
  );
  out['sister'] = await seedPerson(
    repos,
    name: arabic ? 'أختي ليلى' : 'Lily',
    relation: 'sister',
    rhythm: 7,
    lastContact: ago(4, 17),
    createdAt: created,
    birthday: DateTime(1994, 10, 1),
    logs: [(ago(4, 17), ContactChannel.visit, null)],
  );
  out['colleague'] = await seedPerson(
    repos,
    name: arabic ? 'م. خالد' : 'Chris',
    relation: 'colleague',
    rhythm: 30,
    lastContact: ago(3, 10),
    createdAt: created,
    color: 0xFF1FB5C9,
    logs: [(ago(3, 10), ContactChannel.call, null)],
  );
  out['neighbour'] = await seedPerson(
    repos,
    name: arabic ? 'أبو يوسف' : 'Mr. Jones',
    relation: 'neighbour',
    lastContact: ago(18, 18),
    createdAt: created,
    moon: false,
    logs: [(ago(18, 18), ContactChannel.visit, null)],
  );
  return out;
}
