import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/features/recitation/data/download_transport.dart';
import 'package:madar/features/recitation/data/network_probe.dart';
import 'package:madar/features/recitation/domain/recitation_settings.dart';
import 'package:madar/features/recitation/domain/reciters.dart';

void main() {
  test('everyayah URLs use the folder and the six-digit file key', () {
    expect(
      EveryAyah.urlFor(Reciters.husaryMujawwad, const AyahRef(2, 255)).toString(),
      'https://everyayah.com/data/Husary_128kbps_Mujawwad/002255.mp3',
    );
    expect(
      EveryAyah.urlFor(Reciters.abdulBasitMujawwad, const AyahRef(114, 6)).toString(),
      'https://everyayah.com/data/Abdul_Basit_Mujawwad_128kbps/114006.mp3',
    );
    expect(EveryAyah.fileName(const AyahRef(1, 1)), '001001.mp3');
  });

  test('the required reciters are there in both styles', () {
    Reciter? find(String name, ReciterStyle style) {
      for (final r in Reciters.all) {
        if (r.nameEn.contains(name) && r.style == style) return r;
      }
      return null;
    }

    for (final name in ['Abdul Basit', 'Minshawi', 'Husary']) {
      expect(find(name, ReciterStyle.mujawwad), isNotNull, reason: '$name mujawwad');
      expect(find(name, ReciterStyle.murattal), isNotNull, reason: '$name murattal');
    }
    expect(Reciters.all.where((r) => r.style == ReciterStyle.murattal).length, greaterThan(8));
  });

  test('ids and folders are unique; lookups fall back', () {
    expect(Reciters.all.map((r) => r.id).toSet(), hasLength(Reciters.all.length));
    expect(Reciters.all.map((r) => r.folder).toSet(), hasLength(Reciters.all.length));
    for (final r in Reciters.all) {
      expect(r.folder, matches(RegExp(r'^[A-Za-z0-9_.-]+$')));
      expect(r.folder, contains('${r.bitrate}kbps'));
    }
    expect(Reciters.byId('husary.muallim'), Reciters.husaryMuallim);
    expect(Reciters.byId('nobody'), Reciters.fallback);
    expect(Reciters.byIdOrNull('nobody'), isNull);
  });

  test('size estimate follows bitrate and style', () {
    // 40 h at 128 kbit/s ≈ 2.3 GB.
    expect(Reciters.abdulBasitMujawwad.approxMushafBytes, 40 * 3600 * 16000);
    expect(Reciters.alafasy.approxMushafBytes, lessThan(Reciters.abdulBasitMujawwad.approxMushafBytes));
  });

  group('settings', () {
    test('round-trips', () {
      const s = RecitationSettings(
        reciterId: 'minshawi.mujawwad',
        repeatAyah: 3,
        repeatRange: 0,
        gapSeconds: 4,
        speed: 1.25,
        basmala: false,
        wifiOnly: false,
      );
      expect(RecitationSettings.fromJson(s.toJson()), s);
    });

    test('tolerates junk', () {
      expect(RecitationSettings.fromJson(null), const RecitationSettings());
      expect(
        RecitationSettings.fromJson({'reciter': 'x', 'repeatAyah': 0, 'speed': 9, 'gap': -1, 'basmala': 'yes'}),
        const RecitationSettings(),
      );
      expect(const RecitationSettings().reciter, Reciters.abdulBasitMujawwad);
      expect(const RecitationSettings().wifiOnly, isTrue);
    });
  });

  test('Content-Range total', () {
    expect(HttpDownloadTransport.totalFromContentRange('bytes 100-999/1000'), 1000);
    expect(HttpDownloadTransport.totalFromContentRange('bytes */1000'), 1000);
    expect(HttpDownloadTransport.totalFromContentRange('bytes 0-9/*'), isNull);
    expect(HttpDownloadTransport.totalFromContentRange(null), isNull);
  });

  test('Wi-Fi interface names', () {
    expect(InterfaceNetworkProbe.isWifiName('wlan0'), isTrue);
    expect(InterfaceNetworkProbe.isWifiName('wl0'), isTrue);
    expect(InterfaceNetworkProbe.isWifiName('rmnet_data0'), isFalse);
    expect(InterfaceNetworkProbe.isWifiName('ccmni1'), isFalse);
    expect(InterfaceNetworkProbe.isWifiName('swlan0'), isFalse);
    expect(InterfaceNetworkProbe.isWifiName('ap0'), isFalse);
  });
}
