import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/sound/prayer_mute.dart';
import 'package:madar/core/sound/sound_api.dart';

void main() {
  test('muted while any lease is held; release is idempotent', () {
    final sound = SilentSoundService();
    final mute = PrayerMuteController(sound);
    addTearDown(mute.dispose);
    expect(mute.muted, isFalse);

    final screen = mute.acquire('adhan screen');
    final quiet = mute.acquire('prayer quiet');
    expect(sound.prayerMuted, isTrue);
    expect(mute.reasons, ['adhan screen', 'prayer quiet']);

    screen.release();
    screen.release();
    expect(sound.prayerMuted, isTrue, reason: 'the quiet lease still holds');
    expect(screen.isActive, isFalse);

    quiet.release();
    expect(sound.prayerMuted, isFalse);
    expect(mute.muted, isFalse);
  });
}
