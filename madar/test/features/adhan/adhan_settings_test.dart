import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/features/adhan/data/adhan_settings_repository.dart';
import 'package:madar/features/adhan/domain/adhan_settings.dart';
import 'package:madar/features/adhan/domain/adhan_slot.dart';
import 'package:madar/features/adhan/domain/adhan_sound.dart';

final _recording = CustomMuezzin(
  id: 'abc123xyz789',
  name: 'Makkah',
  fileName: 'abc123xyz789.mp3',
  length: const Duration(minutes: 3, seconds: 12),
  addedAt: DateTime.utc(2026, 9, 1),
);

void main() {
  group('defaults', () {
    test('a fresh install: every adhan on, Madar tones, no reminders', () {
      const s = AdhanSettings();
      for (final slot in AdhanSlot.prayers) {
        expect(s.alertOf(slot), const PrayerAlert());
        expect(s.alertOf(slot).adhan, isTrue);
        expect(s.alertOf(slot).hasReminder, isFalse);
      }
      expect(s.fajrSound, const AdhanSoundRef.tone(TanbihTone.dawn));
      expect(s.soundFor(AdhanSlot.isha), const AdhanSoundRef.tone(TanbihTone.brass));
      expect(s.sunriseAlert, isFalse);
      expect(s.fullScreen, isTrue);
      expect(s.muezzins, isEmpty);
      expect(AdhanSettings.fromJson(null), s);
    });
  });

  group('json', () {
    test('round-trips', () {
      final s =
          const AdhanSettings(
                sunriseAlert: true,
                sunriseMinutesBefore: 15,
                vibrate: false,
                fullScreen: false,
                quietMinutes: 30,
                snoozeMinutes: 10,
              )
              .withAlert(AdhanSlot.asr, const PrayerAlert(adhan: false, preMinutes: 10))
              .withMuezzin(_recording)
              .copyWith(fajrSound: AdhanSoundRef.file(_recording.id), sound: const AdhanSoundRef.silent());
      final back = AdhanSettings.fromJson(s.toJson());
      expect(back, s);
      expect(back.muezzins.single, _recording);
      expect(back.fajrSound.fileId, _recording.id);
      expect(back.sound.kind, AdhanSoundKind.silent);
      expect(back.alertOf(AdhanSlot.asr), const PrayerAlert(adhan: false, preMinutes: 10));
    });

    test('tolerates junk', () {
      final s = AdhanSettings.fromJson({
        'alerts': {
          'asr': {'adhan': 'yes', 'pre': 900},
          'noon': {'adhan': false},
          'sunrise': {'adhan': false},
        },
        'fajrSound': 'tone:thunder',
        'sound': 'file:../../etc',
        'quiet': -4,
        'snooze': 'x',
        'muezzins': [
          {'id': 'BAD ID', 'name': 'x', 'fileName': 'x.mp3'},
          {'id': 'good1234', 'name': 'ok', 'fileName': '../good1234.mp3'},
          'nonsense',
        ],
      });
      expect(s.alertOf(AdhanSlot.asr), const PrayerAlert(preMinutes: 120));
      expect(s.alerts.containsKey(AdhanSlot.sunrise), isFalse);
      expect(s.fajrSound, const AdhanSoundRef.tone(TanbihTone.dawn));
      expect(s.sound, const AdhanSoundRef.tone(TanbihTone.brass));
      expect(s.quietMinutes, 0);
      expect(s.snoozeMinutes, 5);
      expect(s.muezzins, isEmpty);
    });

    test('a sound pointing at a missing recording falls back to the default', () {
      final s = AdhanSettings.fromJson({'fajrSound': 'file:gone1234', 'sound': 'file:gone1234'});
      expect(s.fajrSound, const AdhanSoundRef.tone(TanbihTone.dawn));
      expect(s.sound, const AdhanSoundRef.tone(TanbihTone.brass));
    });
  });

  group('recordings', () {
    test('removing one resets the prayers that used it', () {
      final s = const AdhanSettings().withMuezzin(_recording).copyWith(sound: AdhanSoundRef.file(_recording.id));
      expect(s.muezzinById(_recording.id), _recording);
      final gone = s.withoutMuezzin(_recording.id);
      expect(gone.muezzins, isEmpty);
      expect(gone.sound, const AdhanSoundRef.tone(TanbihTone.brass));
      expect(gone.fajrSound, const AdhanSoundRef.tone(TanbihTone.dawn));
    });

    test('only mp3 and wav preview in the app', () {
      expect(_recording.playableInApp, isTrue);
      expect(
        CustomMuezzin(id: 'x1234', name: 'n', fileName: 'x1234.m4a', addedAt: DateTime.utc(2026)).playableInApp,
        isFalse,
      );
    });

    test('sound refs parse strictly', () {
      expect(AdhanSoundRef.parse('tone:bowl'), const AdhanSoundRef.tone(TanbihTone.bowl));
      expect(AdhanSoundRef.parse('file:abcd1234'), const AdhanSoundRef.file('abcd1234'));
      expect(AdhanSoundRef.parse('silent'), const AdhanSoundRef.silent());
      expect(AdhanSoundRef.parse('file:'), isNull);
      expect(AdhanSoundRef.parse('file:A/B'), isNull);
      expect(AdhanSoundRef.parse(3), isNull);
      for (final t in TanbihTone.values) {
        expect(AdhanSoundRef.parse(AdhanSoundRef.tone(t).key), AdhanSoundRef.tone(t));
      }
    });
  });

  test('persists encrypted in key_values and streams changes', () async {
    final db = MadarDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = AdhanSettingsRepository(Repositories(db).keyValues);
    expect(await repo.load(), const AdhanSettings());
    final changes = <AdhanSettings>[];
    final sub = repo.watch().listen(changes.add);
    final s = const AdhanSettings(vibrate: false).withAlert(AdhanSlot.fajr, const PrayerAlert(preMinutes: 20));
    await repo.save(s);
    expect(await repo.load(), s);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(changes.last, s);
    await sub.cancel();
  });
}
