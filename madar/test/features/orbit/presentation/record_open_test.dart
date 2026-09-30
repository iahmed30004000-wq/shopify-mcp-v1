import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/orbit/domain/orbit_moons.dart';
import 'package:madar/features/orbit/presentation/planet/record_open.dart';

void main() {
  const dad = OrbitMoon(
    planetKey: 'family',
    refTable: 'people',
    refId: 'p1',
    label: 'Dad',
    color: Color(0xFFE0A060),
    kind: MoonKind.rocky,
    score: 0.2,
    size: 1,
    seed: 0.3,
  );

  test('a reason opens its moon or its task; other records are not buttons', () {
    expect(RecordOpener.canOpen('people', 'p1', const [dad]), isTrue);
    expect(RecordOpener.canOpen('tasks', 't1', const []), isTrue);
    expect(RecordOpener.canOpen('medications', 'm1', const [dad]), isFalse);
    expect(RecordOpener.canOpen('people', 'p2', const [dad]), isFalse, reason: 'a hidden / missing moon');
    expect(RecordOpener.canOpen(null, null, const [dad]), isFalse);
  });

  test('item ids split into table and id (ids may contain colons)', () {
    expect(RecordOpener.parse('tasks:abc'), ('tasks', 'abc'));
    expect(RecordOpener.parse('custom_modules:a:b'), ('custom_modules', 'a:b'));
    expect(RecordOpener.parse('tasks:'), isNull);
    expect(RecordOpener.parse(':x'), isNull);
    expect(RecordOpener.moonOf('people:p1', const [dad]), dad);
  });
}
