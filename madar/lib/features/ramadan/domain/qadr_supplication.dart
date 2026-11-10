import 'package:flutter/foundation.dart';

/// The supplication slot of the last ten nights (`LastTenNights.qadrSupplicationSlotId`).
///
/// **Nothing here is written by the app.** The text, where it comes from and
/// how it is graded are typed by the owner and shown back exactly as typed,
/// the source and the grading under the text.
@immutable
class QadrSupplication {
  const QadrSupplication({required this.text, this.source = '', this.grading = ''});

  /// Null when [json] holds no text (nothing stored, or damaged).
  static QadrSupplication? fromJson(Object? json) {
    if (json is! Map) return null;
    String s(Object? v) => v is String ? v.trim() : '';
    final text = s(json['text']);
    if (text.isEmpty) return null;
    return QadrSupplication(text: text, source: s(json['source']), grading: s(json['grading']));
  }

  final String text;
  final String source;
  final String grading;

  bool get hasSource => source.isNotEmpty;
  bool get hasGrading => grading.isNotEmpty;

  Map<String, Object?> toJson() => {'text': text, 'source': source, 'grading': grading};

  @override
  bool operator ==(Object other) =>
      other is QadrSupplication && other.text == text && other.source == source && other.grading == grading;

  @override
  int get hashCode => Object.hash(text, source, grading);
}
