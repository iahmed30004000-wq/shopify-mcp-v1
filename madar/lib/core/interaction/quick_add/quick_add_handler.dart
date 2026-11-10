import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'parser.dart';

/// Turns a parsed [QuickAddIntent] into a real record (task, transaction,
/// water log …). Features implement it and register it through
/// [quickAddHandlerProvider].
abstract class QuickAddHandler {
  const QuickAddHandler();

  /// Creates whatever [intent] describes. Returns true when something was
  /// added, false when this handler cannot (or chose not to) handle it.
  Future<bool> handle(QuickAddIntent intent);
}

/// Tries each handler in order until one returns true – lets several features
/// register independently.
class CompositeQuickAddHandler extends QuickAddHandler {
  const CompositeQuickAddHandler(this.handlers);

  final List<QuickAddHandler> handlers;

  @override
  Future<bool> handle(QuickAddIntent intent) async {
    for (final h in handlers) {
      if (await h.handle(intent)) return true;
    }
    return false;
  }
}

/// Routes by [QuickAddIntent.kind] (e.g. expense/income → finance, water →
/// health). Kinds without a route fall back to [fallback] (if any).
class KindQuickAddHandler extends QuickAddHandler {
  const KindQuickAddHandler(this.routes, {this.fallback});

  final Map<QuickAddKind, QuickAddHandler> routes;
  final QuickAddHandler? fallback;

  @override
  Future<bool> handle(QuickAddIntent intent) async {
    final h = routes[intent.kind] ?? fallback;
    return h == null ? false : h.handle(intent);
  }
}

/// A handler from a plain function (handy for features and tests).
class CallbackQuickAddHandler extends QuickAddHandler {
  const CallbackQuickAddHandler(this.callback);

  final Future<bool> Function(QuickAddIntent intent) callback;

  @override
  Future<bool> handle(QuickAddIntent intent) => callback(intent);
}

/// The app's quick-add handler. None by default – the quick-add bar then
/// explains that quick add isn't ready. Features register at bootstrap:
///
/// ```dart
/// ProviderScope(overrides: [
///   quickAddHandlerProvider.overrideWith((ref) => KindQuickAddHandler({
///     QuickAddKind.task: TasksQuickAdd(ref),
///     QuickAddKind.expense: FinanceQuickAdd(ref),
///   })),
/// ])
/// ```
final quickAddHandlerProvider = Provider<QuickAddHandler?>((ref) => null);
