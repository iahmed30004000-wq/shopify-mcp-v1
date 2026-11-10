import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';
import 'package:madar/features/cinema/games/catalog.dart';

void main() {
  final ar = lookupL10n(const Locale('ar'));
  final en = lookupL10n(const Locale('en'));

  test('ids are unique snake_case', () {
    final ids = CinemaCatalog.all.map((e) => e.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
    for (final id in ids) {
      expect(RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(id), isTrue, reason: id);
      expect(CinemaCatalog.byId(id)!.id, id);
    }
    expect(CinemaCatalog.byId('nope'), isNull);
  });

  test('the five Tier 1 features are announced with their eras and homages', () {
    final features = CinemaCatalog.ofTier(GameTier.feature);
    expect(features.map((e) => e.id), [
      'flappy_orbit',
      'metropolis_machine',
      'caravan_dash',
      'noir_rooftops',
      'neon_souk_racer',
    ]);
    expect(features.map((e) => e.era), [Era.rubberHose, Era.silent, Era.technicolor, Era.noir, Era.vhs]);
    for (final e in features) {
      expect(e.homage, isNotNull, reason: e.id);
      expect(e.homage!(ar), isNotEmpty);
    }
  });

  test('names are localised (Arabic primary) and the demo is playable', () {
    for (final e in CinemaCatalog.all) {
      expect(e.title(ar), isNotEmpty);
      expect(e.title(en), isNotEmpty);
      expect(e.title(ar), isNot(e.title(en)), reason: '${e.id} needs an Arabic title');
      expect(e.tagline(ar), isNotEmpty);
    }
    expect(CinemaCatalog.byId('demo')!.isPlayable, isTrue);
  });
}
