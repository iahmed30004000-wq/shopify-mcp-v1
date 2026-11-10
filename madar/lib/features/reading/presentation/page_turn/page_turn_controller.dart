import 'package:flutter/foundation.dart';

/// What a [PageTurnView] exposes to its owner. Attach it with
/// `PageTurnView(controller: ...)`; it is a [ChangeNotifier] that fires when
/// the current page (or the page count) changes.
class PageTurnController extends ChangeNotifier {
  PageTurnController();

  PageTurnHost? _host;
  int _page = 0;
  int _count = 0;

  bool get isAttached => _host != null;

  /// 0-based. In a facing-pages layout: the lower page of the visible pair.
  int get currentPage => _page;

  int get pageCount => _count;

  bool get canGoNext => _host?.canGoNext ?? false;
  bool get canGoPrevious => _host?.canGoPrevious ?? false;

  /// Turns to the next page (spread); completes when the turn has finished.
  Future<void> next() => _host?.turnNext() ?? Future<void>.value();

  Future<void> previous() => _host?.turnPrevious() ?? Future<void>.value();

  /// Goes to [page]. A neighbour turns with the curl; anything further is a
  /// quick cross-fade (never a flip through every page between). With
  /// [animate] false it just lands there.
  Future<void> jumpTo(int page, {bool animate = true}) =>
      _host?.jumpToPage(page, animate: animate) ?? Future<void>.value();

  /// The content of a page changed (a highlight was added, the font size
  /// changed): its stored image is stale. Without [page]: every page.
  void invalidate([int? page]) => _host?.invalidatePage(page);

  // ---- used by the view ------------------------------------------------

  void attach(PageTurnHost host, {required int page, required int count}) {
    _host = host;
    update(page: page, count: count);
  }

  void detach(PageTurnHost host) {
    if (_host == host) _host = null;
  }

  void update({required int page, required int count}) {
    if (page == _page && count == _count) return;
    _page = page;
    _count = count;
    notifyListeners();
  }
}

/// The view side of the controller (implemented by the view's state).
abstract interface class PageTurnHost {
  bool get canGoNext;
  bool get canGoPrevious;
  Future<void> turnNext();
  Future<void> turnPrevious();
  Future<void> jumpToPage(int page, {required bool animate});
  void invalidatePage(int? page);
}
