import 'package:flutter/widgets.dart' show Color, Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/orbit/domain/orbit_labels.dart';
import 'package:madar/features/orbit/domain/orbit_moons.dart';
import 'package:madar/features/orbit/domain/planet_scores.dart';
import 'package:madar/features/orbit/domain/prayer_schedule.dart';
import 'package:madar/features/orbit/domain/scene_snapshot.dart';

const _fsi = '\u2068', _pdi = '\u2069';
String iso(String s) => '$_fsi$s$_pdi';

void main() {
  final ar = lookupL10n(const Locale('ar'));
  final en = lookupL10n(const Locale('en'));
  const arFmt = MadarFormatter();
  const enFmt = MadarFormatter(languageCode: 'en');

  test('undo labels for every customisation, with the name isolated', () {
    expect(planetEditUndoLabel(ar, arFmt, PlanetEdit.hide, name: 'العمل'), 'أُخفي ${iso('العمل')}');
    expect(planetEditUndoLabel(en, enFmt, PlanetEdit.hide, name: 'Work'), '${iso('Work')} hidden');
    expect(planetEditUndoLabel(ar, arFmt, PlanetEdit.add, name: 'Garden'), 'أُضيف ${iso('Garden')} إلى المدار');
    expect(planetEditUndoLabel(en, enFmt, PlanetEdit.reorder), 'Planets reordered');
    for (final e in PlanetEdit.values) {
      expect(planetEditUndoLabel(ar, arFmt, e, name: 'x'), isNotEmpty);
      expect(planetEditUndoLabel(en, enFmt, e, name: 'x'), isNotEmpty);
    }
    for (final e in PlanetEditError.values) {
      expect(planetEditErrorText(ar, e), isNotEmpty);
    }
    expect(planetEditErrorText(ar, PlanetEditError.builtInDelete), 'الكواكب الأساسية تُخفى ولا تُحذف');
    expect(planetEditErrorText(en, PlanetEditError.needsName), 'Give the planet a name');
  });

  test('moons beyond the cap: Arabic plural forms and digits', () {
    expect(moonOverflowText(ar, arFmt, 0), '');
    expect(moonOverflowText(ar, arFmt, 1), 'وقمر آخر');
    expect(moonOverflowText(ar, arFmt, 2), 'وقمران آخران');
    expect(moonOverflowText(ar, arFmt, 3), 'و٣ أقمار أخرى');
    expect(moonOverflowText(ar, arFmt, 11), 'و١١ قمرًا آخر');
    expect(moonOverflowText(ar, arFmt, 100), 'و١٠٠ قمر آخر');
    expect(moonOverflowText(en, enFmt, 1), '+1 more moon');
    expect(moonOverflowText(en, enFmt, 4), '+4 more moons');
  });

  test('screen-reader labels of moons, planets and the core star', () {
    final now = DateTime(2026, 9, 27, 16);
    const moon = OrbitMoon(
      planetKey: 'family',
      refTable: 'people',
      refId: 'p1',
      label: 'أبي',
      color: Color(0xFFCC8855),
      kind: MoonKind.rocky,
      score: 0.1,
      size: 1,
      seed: 1,
    );
    expect(moonSemanticsLabel(ar, arFmt, moon, 'العائلة'), '${iso('أبي')}، قمرٌ يدور حول ${iso('العائلة')}');

    final family = OrbitPlanet(
      config: const PlanetConfig(
        id: 'f',
        key: 'family',
        nameAr: 'العائلة',
        nameEn: 'Family',
        color: 0xFFE07A5F,
        archetype: PlanetArchetype.terracotta,
      ),
      name: 'العائلة',
      palette: PlanetPalettes.family,
      score: const PlanetScore(planetKey: 'family', score: 0.32, sources: {'contacts': 0.32}, reasons: []),
      moonSet: const MoonSet([moon]),
      extras: const [0, 0, 0, 0],
      seed: 1,
    );
    expect(planetSemanticsLabel(ar, arFmt, family), '${iso('العائلة')}، يحتاج إلى اهتمام، التوازن ٣٢٪');

    final schedule = PrayerSchedule(const PrayerSettings());
    SceneSnapshot snap({required bool dormant}) => SceneSnapshot(
      at: now,
      languageCode: 'ar',
      planets: [family],
      balance: dormant ? 0.6 : 0.72,
      balanceDormant: dormant,
      radar: const [],
      prayer: PrayerState(
        settings: schedule.settings,
        times: schedule.timesFor(now),
        window: schedule.windowAt(now),
        prayerDay: DateTime(2026, 9, 27),
        logged: const {},
      ),
    );
    expect(balanceSemanticsLabel(ar, arFmt, snap(dormant: false)), 'توازن حياتك ٧٢٪');
    expect(balanceSemanticsLabel(en, enFmt, snap(dormant: false)), 'Life balance 72%');
    expect(balanceSemanticsLabel(ar, arFmt, snap(dormant: true)), 'توازن حياتك هادئ، لا بيانات بعد');
  });
}
