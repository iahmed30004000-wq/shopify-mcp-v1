/// «التسميع» · his own choices (Part 13, step 1).
///
/// Pure Dart, stored as one JSON value in `key_values` – the same shape
/// `SufraSettings` uses. Nothing here is a judgement: it is what he asked
/// for.
library;

import 'package:meta/meta.dart';

import 'alignment.dart';
import 'blanks.dart';

/// The settings of «التسميع».
@immutable
final class TasmeeSettings {
  const TasmeeSettings({
    this.checkTashkeel = false,
    this.confidenceFloor = 0.35,
    this.blankShare = Blanks.defaultShare,
    this.blankSpread = BlankSpread.scattered,
    this.hideAyahMarkers = false,
    this.keepHeardWords = true,
  });

  factory TasmeeSettings.fromJson(Object? json) {
    final map = json is Map ? json.cast<String, Object?>() : const <String, Object?>{};
    double number(String key, double fallback) {
      final v = map[key];
      return v is num ? v.toDouble() : fallback;
    }

    bool flag(String key, bool fallback) {
      final v = map[key];
      return v is bool ? v : fallback;
    }

    final spread = map['blankSpread'];
    return TasmeeSettings(
      checkTashkeel: flag('checkTashkeel', false),
      confidenceFloor: number('confidenceFloor', 0.35).clamp(0.0, 0.9),
      blankShare: number('blankShare', Blanks.defaultShare).clamp(0.05, 0.9),
      blankSpread: BlankSpread.values.firstWhere(
        (s) => s.name == spread,
        orElse: () => BlankSpread.scattered,
      ),
      hideAyahMarkers: flag('hideAyahMarkers', false),
      keepHeardWords: flag('keepHeardWords', true),
    );
  }

  /// Where the settings live in `key_values`.
  static const String storageKey = 'tasmee.settings';

  /// The **experimental** diacritics check. Off until it earns its place,
  /// and labelled as experimental wherever it is shown.
  final bool checkTashkeel;

  /// Below this confidence the recogniser can never produce a mistake.
  final double confidenceFloor;

  /// How much of a range fill-in-the-blank blanks out.
  final double blankShare;
  final BlankSpread blankSpread;

  /// Hide the ayah markers while he tests himself (his own request).
  final bool hideAyahMarkers;

  /// Whether the log keeps what the recogniser heard beside the verified
  /// word. On, because he asked for «اللي سمعه التطبيق منك»; off strips it
  /// from the log and from the export.
  final bool keepHeardWords;

  /// The alignment options these settings imply.
  AlignmentOptions get alignment =>
      AlignmentOptions(confidenceFloor: confidenceFloor, checkTashkeel: checkTashkeel);

  TasmeeSettings copyWith({
    bool? checkTashkeel,
    double? confidenceFloor,
    double? blankShare,
    BlankSpread? blankSpread,
    bool? hideAyahMarkers,
    bool? keepHeardWords,
  }) => TasmeeSettings(
    checkTashkeel: checkTashkeel ?? this.checkTashkeel,
    confidenceFloor: confidenceFloor ?? this.confidenceFloor,
    blankShare: blankShare ?? this.blankShare,
    blankSpread: blankSpread ?? this.blankSpread,
    hideAyahMarkers: hideAyahMarkers ?? this.hideAyahMarkers,
    keepHeardWords: keepHeardWords ?? this.keepHeardWords,
  );

  Map<String, Object?> toJson() => {
    'checkTashkeel': checkTashkeel,
    'confidenceFloor': confidenceFloor,
    'blankShare': blankShare,
    'blankSpread': blankSpread.name,
    'hideAyahMarkers': hideAyahMarkers,
    'keepHeardWords': keepHeardWords,
  };

  @override
  bool operator ==(Object other) =>
      other is TasmeeSettings &&
      other.checkTashkeel == checkTashkeel &&
      other.confidenceFloor == confidenceFloor &&
      other.blankShare == blankShare &&
      other.blankSpread == blankSpread &&
      other.hideAyahMarkers == hideAyahMarkers &&
      other.keepHeardWords == keepHeardWords;

  @override
  int get hashCode =>
      Object.hash(checkTashkeel, confidenceFloor, blankShare, blankSpread, hideAyahMarkers, keepHeardWords);

  @override
  String toString() => 'TasmeeSettings(tashkeel $checkTashkeel, floor $confidenceFloor)';
}
