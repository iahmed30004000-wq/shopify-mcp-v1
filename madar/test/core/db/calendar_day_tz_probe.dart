// Helper process for calendar_day_converter_test.dart (not a test itself):
// maps a calendar day to drift's stored text in this process's time zone
// (`write y m d`), or reads stored text back to a calendar day (`read text`).
// Pure Dart – drift's own DateTime ⇄ text mapping, no SQLite needed.
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:madar/core/db/tables/converters.dart';

void main(List<String> args) {
  // The exact DateTime ⇄ text mapping drift uses with
  // store_date_time_values_as_text: true.
  // ignore: invalid_use_of_internal_member
  final types = SqlTypes(true);
  const converter = CalendarDayConverter();
  final legacy = args.contains('--legacy');
  switch (args.first) {
    case 'write':
      final day = DateTime(int.parse(args[1]), int.parse(args[2]), int.parse(args[3]));
      stdout.writeln(types.mapToSqlVariable(legacy ? day : converter.toSql(day)));
    case 'read':
      final stored = types.read(DriftSqlType.dateTime, args[1])!;
      final day = legacy ? stored : converter.fromSql(stored);
      stdout.writeln('${day.year}-${day.month}-${day.day}');
  }
}
