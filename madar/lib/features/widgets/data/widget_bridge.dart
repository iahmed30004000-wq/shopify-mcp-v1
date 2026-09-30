import 'dart:typed_data';

import '../domain/widget_build.dart';
import '../domain/widget_kind.dart';
import '../render/mini_astrolabe.dart';
import 'widget_platform.dart';

/// Renders a widget image (PNG bytes).
typedef WidgetImageRenderer = Future<Uint8List> Function(MiniAstrolabeSpec spec, {required bool dark});

/// Hands built snapshots to Android: renders their images (light and dark
/// variants, `<key>_light` / `<key>_dark`) and writes only what changed –
/// the JSON when its text differs from the last one written, the images
/// when their drawings differ – so the many rebuilds of a running app cost
/// nothing on disk.
class WidgetBridge {
  WidgetBridge(this.platform, {WidgetImageRenderer? renderImage})
    : _render = renderImage ?? ((spec, {required dark}) => MiniAstrolabeRenderer.png(spec, dark: dark));

  final WidgetPlatform platform;
  final WidgetImageRenderer _render;

  final Map<MadarWidgetKind, String> _json = {};
  final Map<MadarWidgetKind, String> _images = {};

  /// Publishes [build] unless Android already has it; true when written.
  Future<bool> push(WidgetBuild build) async {
    final kind = build.snapshot.kind;
    final json = build.snapshot.encode();
    final signature = imageSignature(build.images);
    final imagesChanged = _images[kind] != signature;
    if (!imagesChanged && _json[kind] == json) return false;
    Map<String, Uint8List>? images;
    if (imagesChanged) {
      images = {};
      for (final e in build.images.entries) {
        images['${e.key}_light'] = await _render(e.value, dark: false);
        images['${e.key}_dark'] = await _render(e.value, dark: true);
      }
    }
    await platform.publish(kind, json, images: images);
    _json[kind] = json;
    _images[kind] = signature;
    return true;
  }

  /// Forgets what was written for [kind] (its widget was removed – Android
  /// deleted the data – so the next push writes everything again).
  void forget(MadarWidgetKind kind) {
    _json.remove(kind);
    _images.remove(kind);
  }

  Future<void> remove(MadarWidgetKind kind) async {
    forget(kind);
    await platform.remove(kind);
  }

  /// "Delete all data": every widget's data and key.
  Future<void> clearAll() async {
    _json.clear();
    _images.clear();
    await platform.clearAll();
  }

  static String imageSignature(Map<String, MiniAstrolabeSpec> images) {
    final keys = images.keys.toList()..sort();
    return [for (final k in keys) '$k=${images[k]!.signature}'].join(';');
  }
}
