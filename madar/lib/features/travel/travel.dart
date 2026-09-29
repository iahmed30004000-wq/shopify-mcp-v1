/// Travel: trips with countdowns and packing lists, packing templates,
/// document expiry reminders, and the destination's prayer times and qibla.
///
/// * Screens: [TravelScreen] (trips / documents / templates),
///   [TripScreen], [PackingTemplatesScreen], [PackingTemplateScreen].
/// * Sheets: [showTripSheet] / [TripSheet], [showDocumentSheet] /
///   [DocumentSheet], [showTemplatePickerSheet].
/// * Hub card: [TravelTodayCard].
/// * State: [travelServiceProvider], [travelOverviewProvider],
///   [travelTripViewProvider], [travelDestinationPrayerProvider],
///   [travelStatusSyncProvider], [travelReminderSyncProvider],
///   [travelUsePrayerLocationProvider] (the app wires "use as my prayer
///   location while travelling").
/// * Pure domain: [TripTimeline] / [TravelToday] / [TravelDates],
///   [PackingProgress] / [PackingLayout] / [PackingTemplateMath],
///   [TravelDocumentChecks] / [DocumentExpiry], [DocumentReminderPlanner] /
///   [TravelReminderIds], [DestinationPrayer] / [TripPlace],
///   [TravelOverview] / [TripView].
library;

export 'data/travel_notifications.dart';
export 'data/travel_providers.dart';
export 'data/travel_service.dart';
export 'domain/destination_prayer.dart';
export 'domain/document_reminders.dart';
export 'domain/documents.dart';
export 'domain/packing.dart';
export 'domain/starter_templates.dart';
export 'domain/travel_overview.dart';
export 'domain/trip_timeline.dart';
export 'presentation/document_sheet.dart';
export 'presentation/packing_templates_screen.dart';
export 'presentation/travel_actions.dart';
export 'presentation/travel_screen.dart';
export 'presentation/travel_today_card.dart';
export 'presentation/trip_screen.dart';
export 'presentation/trip_sheet.dart';
export 'presentation/widgets/destination_prayer_card.dart';
export 'presentation/widgets/packing_widgets.dart';
export 'presentation/widgets/travel_tiles.dart';
export 'presentation/widgets/travel_widgets.dart';
export 'travel_texts.dart';
