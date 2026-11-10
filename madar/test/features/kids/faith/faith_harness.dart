// Shared by the kids faith tests. Test content is Latin placeholder text on
// purpose: not one religious word is typed anywhere in these tests.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/core/quran/quran_audio.dart';
import 'package:madar/features/kids/core/kids_section.dart';
import 'package:madar/features/kids/faith/application/faith_providers.dart';
import 'package:madar/features/kids/faith/data/kids_audio.dart';
import 'package:madar/features/kids/faith/data/kids_religious_loader.dart';
import 'package:madar/features/kids/faith/domain/kids_art.dart';
import 'package:madar/features/kids/faith/domain/kids_religious_item.dart';
import 'package:madar/features/quran/data/quran_providers.dart';
import 'package:madar/features/recitation/domain/reciters.dart';

import '../../quran/quran_test_data.dart';

/// Reads files straight from disk, the way the app bundle would (a missing
/// file throws, like a missing asset).
class DiskAssetBundle extends AssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final f = File(key);
    if (!f.existsSync()) throw FlutterError('Unable to load asset: $key');
    final bytes = f.readAsBytesSync();
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async => utf8.decode(
    (await load(key)).buffer.asUint8List(),
  );
}

final DateTime signedOn = DateTime(2026, 11, 1);

KidsReligiousItem item(
  String id,
  KidsReligiousKind kind, {
  bool approved = true,
  String? text,
  String? title,
  String? group,
  int order = 0,
  List<KidsArt> art = const [],
  int? repeat,
}) => KidsReligiousItem(
  id: id,
  kind: kind,
  arabicText: text ?? 'TEXT-$id',
  source: 'Test source',
  reviewer: approved ? 'Test Reviewer' : null,
  reviewedOn: approved ? signedOn : null,
  title: title,
  group: group,
  order: order,
  art: art,
  repeat: repeat,
);

/// Content provider overrides serving [items] (validated like the real loader).
List<Override> contentOverrides(List<KidsReligiousItem> items, {bool unlocked = true}) => [
  kidsReligiousUnlockedProvider.overrideWithValue(unlocked),
  kidsReligiousContentProvider.overrideWith(
    (ref) async => KidsReligiousLoadResult(items, validateKidsReligiousItems(items)),
  ),
];

/// The bundled Quran data from disk (a fake-async test never finishes rootBundle).
List<Override> quranOverrides() => [
  quranMetaProvider.overrideWith((ref) async => QuranTestData.meta),
  quranTextProvider.overrideWith((ref) async => QuranTestData.text),
];

Widget faithApp(Widget home, {List<Override> overrides = const [], double textScale = 1.0}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    locale: const Locale('ar'),
    localizationsDelegates: L10n.localizationsDelegates,
    supportedLocales: L10n.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: home,
  ),
);

/// A scripted [KidsAyahAudio].
class FakeKidsAudio implements KidsAyahAudio {
  FakeKidsAudio({this.onPhone = true});

  bool onPhone;
  final List<AyahRange> played = [];
  final StreamController<QuranPlayback> _c = StreamController.broadcast();
  QuranPlayback _v = QuranPlayback.idle;

  void emit(QuranPlayback p) {
    _v = p;
    _c.add(p);
  }

  @override
  Reciter get reciter => Reciters.fallback;
  @override
  Future<bool> isSurahOnPhone(int surah, {required int ayahCount}) async => onPhone;
  @override
  Stream<QuranPlayback> get playback => _c.stream;
  @override
  QuranPlayback get value => _v;
  @override
  Future<bool> play(AyahRange range) async {
    if (!onPhone) return false;
    played.add(range);
    emit(QuranPlayback(current: range.first, range: range, playing: true));
    return true;
  }

  @override
  Future<void> pause() async => emit(QuranPlayback(current: _v.current, range: _v.range));
  @override
  Future<void> resume() async => emit(QuranPlayback(current: _v.current, range: _v.range, playing: true));
  @override
  Future<void> stop() async => emit(QuranPlayback.idle);
}
