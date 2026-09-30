import '../../../core/routing/routes.dart';

/// Where taps on the widgets lead (app router locations), and the check a
/// location handed back by Android must pass before the router goes there.
///
/// The locations travel inside the widget's snapshot (so Android needs no
/// routing knowledge): a tap launches `MainActivity` with the action
/// `app.madar.orbit.widgets.OPEN` and the extra `route`, and Dart
/// ([WidgetLaunchRouter]) goes there – underneath the app lock, like a
/// notification tap. The activity is exported, so another app could forge
/// that intent: [isAllowed] only lets through the few pages a widget opens.
abstract final class WidgetLinks {
  /// The prayer widget → the prayer times.
  static const String prayer = AppRoutes.prayerTimes;

  /// The meds widget and each of its doses → today's doses.
  static String get meds => AppRoutes.medsOf();

  /// The budget widget → the budget's spending tab.
  static String get budget => AppRoutes.budgetOf(tab: 'spending');

  /// The Top 3 widget itself → the Work world (where the Top 3 card lives).
  static String get tasks => AppRoutes.planetOf(workPlanet);

  static const String workPlanet = 'work';

  /// A Top 3 task → its editor over the Work world (`RecordOpener` opens
  /// `tasks:<id>`).
  static String task(String taskId) => AppRoutes.planetOf(workPlanet, item: 'tasks:$taskId');

  /// A Top 3 kanban card → its board's moon on the Work world (cards have
  /// no route of their own yet), or the world itself.
  static String card(String cardId, {String? boardId}) =>
      boardId == null ? tasks : AppRoutes.planetOf(workPlanet, item: 'boards:$boardId');

  static final RegExp _id = RegExp(r'^[A-Za-z0-9_\-:.]{1,80}$');

  /// Whether [location] is one a widget can open: the exact locations above
  /// or a Work world item made of a safe table:id.
  static bool isAllowed(String? location) {
    if (location == null || location.isEmpty || location.length > 200) return false;
    if (location == prayer || location == meds || location == budget || location == tasks) return true;
    final uri = Uri.tryParse(location);
    if (uri == null || uri.hasScheme || uri.hasAuthority) return false;
    if (uri.path != '/planet/$workPlanet') return false;
    final params = uri.queryParameters;
    if (params.length != 1) return false;
    final item = params['item'];
    if (item == null || !_id.hasMatch(item)) return false;
    return item.startsWith('tasks:') || item.startsWith('boards:');
  }
}
