// Madar keeps data on the device and goes to the network only when the user
// asks (plays a recitation, starts a download, downloads a translation).
// Walks the whole Phase 3 surface of the real app – the Faith page, the
// Quran index, reader and search, the wird, Hifz and a review, the qibla,
// the Quran, recitation, downloads and reminders settings – with recording
// network seams, and expects not a single request or audio source.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/features/quran/quran.dart';
import 'package:madar/features/recitation/recitation.dart';

import '../helpers/test_app.dart';

class _RecordingHttp implements QuranHttp {
  final List<Uri> requests = [];

  @override
  Future<(int, String)> get(Uri uri) async {
    requests.add(uri);
    throw const QuranComException(QuranComProblem.offline);
  }
}

class _RecordingTransport implements DownloadTransport {
  final List<Uri> requests = [];

  @override
  Future<DownloadResponse> get(Uri uri, {int from = 0}) async {
    requests.add(uri);
    throw StateError('network used for $uri');
  }

  @override
  void close() {}
}

void main() {
  testWidgets('no Phase 3 screen touches the network or loads audio by itself', (tester) async {
    final http = _RecordingHttp();
    final transport = _RecordingTransport();
    final app = await pumpMadarApp(
      tester,
      overrides: [
        quranHttpProvider.overrideWithValue(http),
        recitationTransportProvider.overrideWithValue(transport),
      ],
    );
    final routes = [
      AppRoutes.planetOf('faith'),
      AppRoutes.quran,
      AppRoutes.quranReaderOf(page: 42),
      AppRoutes.quranReaderOf(ayah: const AyahRef(1, 1)),
      Uri(path: AppRoutes.quranSearch, queryParameters: {'q': 'الرحمن'}).toString(),
      AppRoutes.wird,
      AppRoutes.hifz,
      AppRoutes.hifzReview,
      AppRoutes.qibla,
      AppRoutes.quranSettings,
      AppRoutes.recitationSettings,
      AppRoutes.recitationDownloadsOf(Reciters.fallback.id),
      AppRoutes.reminders,
      AppRoutes.home,
    ];
    for (final route in routes) {
      app.router.go(route);
      await settleApp(tester);
      expect(app.location, Uri.parse(route).path, reason: 'did not open $route');
      expect(http.requests, isEmpty, reason: 'Quran.com was called on $route');
      expect(transport.requests, isEmpty, reason: 'a download started on $route');
      expect(app.faith.engine.sources, isEmpty, reason: 'audio was loaded on $route');
    }
  });
}
