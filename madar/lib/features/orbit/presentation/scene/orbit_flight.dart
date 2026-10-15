import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import 'scene_controller.dart';

/// The bridge between a planet page (a transparent route over home) and the
/// persistent orbit scene underneath it.
///
/// The page [attach]es its route animation: the scene flies in as the route
/// pushes and flies out – the exact reverse – as it pops (system back
/// gesture included); home's own chrome fades with [progress]. The scene
/// registers itself as [scene] so the page can hit-test the hero world's
/// moons and highlight one ([select]).
class OrbitFlight extends ChangeNotifier {
  /// Route progress of the open planet page (0 when none) – drives home's
  /// chrome with Fade/SlideTransitions, never a rebuild.
  final ProxyAnimation progress = ProxyAnimation(kAlwaysDismissedAnimation);

  String? _key;
  String? _item;
  Animation<double>? _route;

  /// The world whose page is open (flying to / from it).
  String? get key => _key;

  /// The moon (`refTable:refId`) highlighted on that page.
  String? get item => _item;

  /// The planet page's route animation.
  Animation<double>? get route => _route;

  bool get active => _route != null;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// The scene underneath (set by the orbit scene while it is mounted).
  SceneController? scene;

  /// Converts a global position into the scene's coordinates (set by the
  /// orbit scene with [scene]; identity when none).
  Offset Function(Offset global)? globalToScene;

  /// [globalToScene] applied (identity without a scene).
  Offset toScene(Offset global) => globalToScene?.call(global) ?? global;

  /// A planet page for [key] is on screen, animated by [route].
  void attach(String key, Animation<double> route, {String? item}) {
    if (_disposed || (identical(route, _route) && key == _key && item == _item)) return;
    _route = route;
    _key = key;
    _item = item;
    progress.parent = route;
    notifyListeners();
  }

  /// The page animated by [route] is gone (ignored if another page took over).
  void detach(Animation<double> route) {
    if (_disposed || !identical(route, _route)) return;
    _route = null;
    _key = null;
    _item = null;
    progress.parent = kAlwaysDismissedAnimation;
    notifyListeners();
  }

  /// Highlights the moon [item] (`refTable:refId`) of the open world.
  void select(String? item) {
    if (_disposed || item == _item) return;
    _item = item;
    notifyListeners();
  }
}
