import 'package:flutter/foundation.dart';

import '../../../core/domain/enums.dart' show BudgetPeriod;
import 'widget_kind.dart';

/// The widgets' own settings (SharedPreferences `madar.widgets.v1` – nothing
/// personal): per widget, whether it shows details (names, times, amounts)
/// or counts only, and the budget widget's period.
@immutable
class WidgetPrefs {
  const WidgetPrefs({this.details = const {}, this.budgetPeriod = BudgetPeriod.monthly});

  /// Explicit choices only: a widget missing here follows the default
  /// ([showsDetails]).
  final Map<MadarWidgetKind, bool> details;
  final BudgetPeriod budgetPeriod;

  /// Whether [kind] shows details: the user's choice, else hidden while the
  /// app lock is on and shown while it is off.
  bool showsDetails(MadarWidgetKind kind, {required bool appLockOn}) => details[kind] ?? !appLockOn;

  WidgetPrefs withDetails(MadarWidgetKind kind, bool? show) {
    final next = Map<MadarWidgetKind, bool>.of(details);
    if (show == null) {
      next.remove(kind);
    } else {
      next[kind] = show;
    }
    return WidgetPrefs(details: Map.unmodifiable(next), budgetPeriod: budgetPeriod);
  }

  WidgetPrefs withBudgetPeriod(BudgetPeriod period) => WidgetPrefs(details: details, budgetPeriod: period);

  Map<String, Object?> toJson() => {
    'details': {for (final e in details.entries) e.key.wire: e.value},
    'budgetPeriod': budgetPeriod.name,
  };

  factory WidgetPrefs.fromJson(Map<String, Object?> j) {
    final raw = j['details'];
    final details = <MadarWidgetKind, bool>{};
    if (raw is Map) {
      for (final e in raw.entries) {
        final kind = MadarWidgetKind.fromWire(e.key);
        if (kind != null && e.value is bool) details[kind] = e.value as bool;
      }
    }
    return WidgetPrefs(
      details: Map.unmodifiable(details),
      budgetPeriod: j['budgetPeriod'] == BudgetPeriod.weekly.name ? BudgetPeriod.weekly : BudgetPeriod.monthly,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WidgetPrefs && mapEquals(other.details, details) && other.budgetPeriod == budgetPeriod;

  @override
  int get hashCode => Object.hash(Object.hashAllUnordered(details.entries.map((e) => (e.key, e.value))), budgetPeriod);
}
