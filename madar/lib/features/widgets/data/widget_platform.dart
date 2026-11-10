import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/widget_kind.dart';

/// What Android tells the app about its widgets.
enum WidgetPlatformEvent {
  /// A widget was added, removed or resized: ask [WidgetPlatform.installed]
  /// again.
  changed,

  /// A widget was tapped: [WidgetPlatform.takeLaunch] has its location.
  launch,
}

/// The Android side of the home-screen widgets (`app.madar.orbit/widgets`,
/// `MadarWidgetsChannel.kt`).
abstract interface class WidgetPlatform {
  /// The kinds with at least one widget on a home screen. Nothing is written
  /// for any other kind.
  Future<Set<MadarWidgetKind>> installed();

  /// Stores [json] (a `WidgetSnapshot`) for [kind] – encrypted with a
  /// Keystore key on the Android side – and [images] (PNG bytes by name;
  /// null keeps the images already there, an empty map removes them), then
  /// redraws that kind's widgets and arms the alarm of its next page.
  Future<void> publish(MadarWidgetKind kind, String json, {Map<String, Uint8List>? images});

  /// Deletes [kind]'s data (its widgets fall back to "Open Madar").
  Future<void> remove(MadarWidgetKind kind);

  /// Deletes every widget's data and the widgets' key ("delete all data").
  Future<void> clearAll();

  /// The location of the widget tap that launched or reached the app, once
  /// (null when there is none).
  Future<String?> takeLaunch();

  Stream<WidgetPlatformEvent> get events;
}

/// [WidgetPlatform] over the method channel. Off Android (tests, other
/// platforms) the channel has no handler: no widget is installed and every
/// write is a no-op.
class MethodChannelWidgetPlatform implements WidgetPlatform {
  MethodChannelWidgetPlatform({MethodChannel? channel}) : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler(_onCall);
  }

  static const String channelName = 'app.madar.orbit/widgets';

  final MethodChannel _channel;
  final StreamController<WidgetPlatformEvent> _events = StreamController.broadcast();

  Future<Object?> _onCall(MethodCall call) async {
    switch (call.method) {
      case 'changed':
        _events.add(WidgetPlatformEvent.changed);
      case 'launch':
        _events.add(WidgetPlatformEvent.launch);
    }
    return null;
  }

  @override
  Stream<WidgetPlatformEvent> get events => _events.stream;

  @override
  Future<Set<MadarWidgetKind>> installed() async {
    try {
      final kinds = await _channel.invokeListMethod<Object?>('installed');
      return {for (final k in kinds ?? const []) ?MadarWidgetKind.fromWire(k)};
    } on MissingPluginException {
      return const {};
    }
  }

  @override
  Future<void> publish(MadarWidgetKind kind, String json, {Map<String, Uint8List>? images}) =>
      _call('publish', {'kind': kind.wire, 'json': json, 'images': images});

  @override
  Future<void> remove(MadarWidgetKind kind) => _call('remove', {'kind': kind.wire});

  @override
  Future<void> clearAll() => _call('clearAll', null);

  @override
  Future<String?> takeLaunch() async {
    try {
      return await _channel.invokeMethod<String>('takeLaunch');
    } on MissingPluginException {
      return null;
    }
  }

  Future<void> _call(String method, Object? arguments) async {
    try {
      await _channel.invokeMethod<Object?>(method, arguments);
    } on MissingPluginException {
      // No Android side (tests, other platforms): nothing to write.
    }
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    unawaited(_events.close());
  }
}

/// Deletes every widget's data – callable before the database is open (the
/// unlock screen's "delete all data" path) and without providers.
Future<void> clearMadarWidgetData() async {
  try {
    await const MethodChannel(MethodChannelWidgetPlatform.channelName).invokeMethod<Object?>('clearAll');
  } on MissingPluginException {
    // Not on Android.
  } catch (e) {
    if (kDebugMode) debugPrint('Madar widgets: clearing the widget data failed: $e');
  }
}

/// In-memory [WidgetPlatform] for tests and previews.
class FakeWidgetPlatform implements WidgetPlatform {
  FakeWidgetPlatform({Set<MadarWidgetKind> installed = const {}}) : installedKinds = {...installed};

  final Set<MadarWidgetKind> installedKinds;

  /// What each kind holds (as Android would store it).
  final Map<MadarWidgetKind, String> stored = {};
  final Map<MadarWidgetKind, Map<String, Uint8List>> storedImages = {};

  /// Every publish, in order.
  final List<({MadarWidgetKind kind, String json, Map<String, Uint8List>? images})> published = [];
  final List<MadarWidgetKind> removed = [];
  int clears = 0;
  String? pendingLaunch;

  final StreamController<WidgetPlatformEvent> _events = StreamController.broadcast(sync: true);

  void emit(WidgetPlatformEvent e) => _events.add(e);

  @override
  Stream<WidgetPlatformEvent> get events => _events.stream;

  @override
  Future<Set<MadarWidgetKind>> installed() async => {...installedKinds};

  @override
  Future<void> publish(MadarWidgetKind kind, String json, {Map<String, Uint8List>? images}) async {
    published.add((kind: kind, json: json, images: images));
    stored[kind] = json;
    if (images != null) storedImages[kind] = images;
  }

  @override
  Future<void> remove(MadarWidgetKind kind) async {
    removed.add(kind);
    stored.remove(kind);
    storedImages.remove(kind);
  }

  @override
  Future<void> clearAll() async {
    clears++;
    stored.clear();
    storedImages.clear();
  }

  @override
  Future<String?> takeLaunch() async {
    final l = pendingLaunch;
    pendingLaunch = null;
    return l;
  }
}
