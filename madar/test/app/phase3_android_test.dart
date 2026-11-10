// The Android side of Phase 3's background recitation (audio_service
// 0.18.19, just_audio), checked statically: there is no Android SDK on the
// development machine and CI builds the APK. audio_service's own
// AndroidManifest.xml is empty, so without these declarations
// `AudioService.init` fails and recitation stays foreground-only.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';

void main() {
  // Comments stripped: a comment naming a component must not satisfy a check.
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync().replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

  /// The whole `<tag …>…</tag>` element whose android:name is [name].
  String element(String tag, String name) {
    final match = RegExp(
      '<$tag\\s[^>]*android:name="${RegExp.escape(name)}"[^>]*>(.*?)</$tag>',
      dotAll: true,
    ).firstMatch(manifest);
    expect(match, isNotNull, reason: '<$tag android:name="$name">');
    return match!.group(0)!;
  }

  test('the media-playback foreground service permissions are declared', () {
    for (final p in ['FOREGROUND_SERVICE', 'FOREGROUND_SERVICE_MEDIA_PLAYBACK', 'WAKE_LOCK']) {
      expect(manifest, contains('<uses-permission android:name="android.permission.$p" />'), reason: p);
    }
  });

  test("audio_service's media service is declared: mediaPlayback, exported, media browser, app process", () {
    final service = element('service', 'com.ryanheise.audioservice.AudioService');
    expect(service, contains('android:foregroundServiceType="mediaPlayback"'));
    expect(service, contains('android:exported="true"'));
    expect(service, contains('<action android:name="android.media.browse.MediaBrowserService" />'));
    // It shares MainActivity's FlutterEngine: never a separate process.
    expect(service, isNot(contains('android:process')));
  });

  test("audio_service's media-button receiver is declared for headset / Bluetooth buttons", () {
    final receiver = element('receiver', 'com.ryanheise.audioservice.MediaButtonReceiver');
    expect(receiver, contains('android:exported="true"'));
    expect(receiver, contains('<action android:name="android.intent.action.MEDIA_BUTTON" />'));
  });

  test('the adhan wiring is untouched next to it', () {
    expect(element('activity', '.MainActivity'), contains('android:launchMode="singleTop"'));
    expect(manifest, contains('android:name=".AdhanSoundProvider"'));
    expect(manifest, contains('android:name=".AdhanBootGuard"'));
    expect(manifest, isNot(contains('android:showWhenLocked')));
  });

  test('streaming needs no cleartext: the user agent goes out natively, not via a localhost proxy', () {
    // just_audio's default proxy for request headers (the user agent) is a
    // plain-HTTP server on 127.0.0.1, blocked by Android's default policy.
    final engine = File('lib/features/recitation/data/just_audio_engine.dart').readAsStringSync();
    expect(engine, contains('useProxyForRequestHeaders: false'));
    expect(manifest, isNot(contains('android:usesCleartextTraffic="true"')));
  });

  test("the recitation notification's icons exist and are kept from resource shrinking", () {
    const res = 'android/app/src/main/res';
    final session = File('lib/features/recitation/data/audio_service_session.dart').readAsStringSync();
    expect(session, contains("androidNotificationIcon: 'drawable/ic_stat_madar'"));
    expect(File('$res/drawable/ic_stat_madar.xml').existsSync(), isTrue);

    final keep = File('$res/raw/keep.xml').readAsStringSync();
    final kept = RegExp(r'tools:keep="([^"]*)"').firstMatch(keep)?.group(1)?.split(',');
    expect(kept, containsAll(<String>['@drawable/ic_stat_madar', '@drawable/audio_service_*']));

    // Every button icon the handler names ships with the resolved plugin.
    final icons = RegExp(r"androidIcon: 'drawable/(\w+)'").allMatches(session).map((m) => m.group(1)!).toSet();
    expect(icons, isNotEmpty);
    final plugin = _packageRoot('audio_service');
    for (final icon in icons) {
      expect(icon, startsWith('audio_service_'));
      expect(File('$plugin/android/src/main/res/drawable-mdpi/$icon.png').existsSync(), isTrue, reason: icon);
    }
  });

  test('the notification channel is named in both languages', () {
    expect(lookupL10n(const Locale('ar')).recitationChannelName, 'تلاوة القرآن');
    expect(lookupL10n(const Locale('en')).recitationChannelName, 'Quran recitation');
  });

  test('phones without a compass or accelerometer can still install Madar (qibla falls back)', () {
    for (final f in ['compass', 'accelerometer']) {
      expect(
        manifest,
        contains('<uses-feature android:name="android.hardware.sensor.$f" android:required="false" />'),
        reason: f,
      );
    }
  });
}

/// The directory of a resolved package (from `.dart_tool/package_config.json`).
String _packageRoot(String name) {
  final config = File('.dart_tool/package_config.json');
  final packages = (jsonDecode(config.readAsStringSync()) as Map<String, dynamic>)['packages'] as List<dynamic>;
  final entry = packages.cast<Map<String, dynamic>>().firstWhere((p) => p['name'] == name);
  return config.parent.uri.resolve(entry['rootUri'] as String).toFilePath().replaceAll(RegExp(r'/$'), '');
}
