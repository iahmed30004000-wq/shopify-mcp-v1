/// Home-screen widgets (Android): the next prayer on a mini astrolabe,
/// today's meds, today's Top 3 and the budget left.
///
/// * Pure snapshot builders (`domain/`): [PrayerWidgetBuilder],
///   [MedsWidgetBuilder], [TasksWidgetBuilder], [BudgetWidgetBuilder] turn
///   app data into a [WidgetSnapshot] – a timeline of pages (prayer times,
///   midnight, …) with every text in the app's language and digits, and
///   nothing personal when the widget shows counts only ([WidgetPrefs]).
/// * [MiniAstrolabeRenderer] draws the prayer widget's astrolabe to PNG
///   (light and dark).
/// * [WidgetBridge] writes snapshots and images through
///   [MethodChannelWidgetPlatform] (`app.madar.orbit/widgets`), only when they
///   changed and only for widgets on a home screen; Android encrypts them
///   (Keystore AES-GCM) and draws RemoteViews
///   (android/…/kotlin/app/madar/orbit/widgets).
/// * App wiring: [watchWidgetServices] (sync + tap routing, from
///   `AppServices`), [clearWidgetData] ("delete all data"),
///   [WidgetsSettingsScreen] / [WidgetsSettingsSection] (details switches),
///   [WidgetLinks] (tap locations).
library;

export 'data/widget_bridge.dart';
export 'data/widget_platform.dart';
export 'data/widget_providers.dart';
export 'data/widget_services.dart';
export 'domain/budget_widget.dart';
export 'domain/meds_widget.dart';
export 'domain/prayer_widget.dart';
export 'domain/tasks_widget.dart';
export 'domain/widget_build.dart';
export 'domain/widget_kind.dart';
export 'domain/widget_links.dart';
export 'domain/widget_prefs.dart';
export 'domain/widget_snapshot.dart';
export 'domain/widget_texts.dart';
export 'presentation/widget_preview.dart';
export 'presentation/widgets_settings.dart';
export 'render/mini_astrolabe.dart' show MiniAstrolabePainter, MiniAstrolabeRenderer;
