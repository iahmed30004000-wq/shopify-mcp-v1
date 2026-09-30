import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../core/notifications/notifications.dart';
import '../features/adhan/adhan.dart';
import '../features/adhkar/adhkar.dart' show dhikrAudioPickerProvider, pickDhikrAudio;
import '../features/health/meds/meds.dart' show medsNotificationBackgroundTap;
import '../features/health/record/record.dart'
    show DoctorReportFile, PlatformReportExporter, ReportExporter, reportExporterProvider;
import '../features/health/wellbeing/wellbeing.dart' show PhoneDialer, UrlLauncherPhoneDialer, phoneDialerProvider;
import '../features/import/import_controller.dart' show importFilePickerProvider, pickJsonFile;
import '../features/lock/application/lock_controller.dart';
import '../features/prayer/prayer.dart';

/// Runs an app-opened system flow (a permission dialog, a system settings
/// page, the document picker) so the app lock treats it as the owner's own:
/// no privacy cover over the dialog, and the time away does not lock the
/// app on return (the lock's `whileSuspended`, which still locks after its
/// grace).
typedef SuspendRunner = Future<T> Function<T>(Future<T> Function() action);

/// The [SuspendRunner] of the app lock.
SuspendRunner lockSuspender(Ref ref) =>
    <T>(action) => ref.read(lockControllerProvider.notifier).whileSuspended<T>(action);

/// Production overrides that route every system flow the Phase 2 features
/// open through [lockSuspender]: notification / exact-alarm / full-screen
/// permission requests, the battery-optimisation dialog, the adhan's system
/// settings pages, the location permission and settings pages, the file
/// pickers (muezzin recordings, dhikr recordings, the importer), and the
/// health flows that leave the app: the doctor report's share sheet and
/// save dialog, and the support note's dialler.
///
/// The notifications plugin is also where a dose's Taken / Snooze / Skip
/// buttons land when they are pressed in the shade: they never open the
/// app, so Android hands them to the plugin's background isolate, whose
/// entry point [medsNotificationBackgroundTap] records them (see
/// `meds_background.dart`); every other background response is left alone.
///
/// Tests replace these providers with fakes, so they are installed by
/// `bootstrap` only; the decorators themselves are unit-tested.
List<Override> suspendingFlowOverrides() => [
  notificationPlatformProvider.overrideWith(
    (ref) => SuspendingNotificationPlatform(
      FlutterLocalNotificationsPlatform(backgroundHandler: medsNotificationBackgroundTap),
      lockSuspender(ref),
    ),
  ),
  batteryGateProvider.overrideWith(
    (ref) => SuspendingBatteryGate(const PermissionHandlerBatteryGate(), lockSuspender(ref)),
  ),
  adhanSystemProvider.overrideWith(
    (ref) => SuspendingAdhanSystem(const MethodChannelAdhanSystem(), lockSuspender(ref)),
  ),
  locationSourceProvider.overrideWith(
    (ref) => SuspendingLocationSource(const GeolocatorLocationSource(), lockSuspender(ref)),
  ),
  audioFilePickerProvider.overrideWith(
    (ref) => SuspendingAudioFilePicker(const SystemAudioFilePicker(), lockSuspender(ref)),
  ),
  dhikrAudioPickerProvider.overrideWith((ref) {
    final suspend = lockSuspender(ref);
    return () => suspend(pickDhikrAudio);
  }),
  importFilePickerProvider.overrideWith((ref) {
    final suspend = lockSuspender(ref);
    return () => suspend(pickJsonFile);
  }),
  reportExporterProvider.overrideWith(
    (ref) => SuspendingReportExporter(const PlatformReportExporter(), lockSuspender(ref)),
  ),
  phoneDialerProvider.overrideWith((ref) => SuspendingPhoneDialer(const UrlLauncherPhoneDialer(), lockSuspender(ref))),
];

/// The doctor report's share sheet and save dialog suspended.
class SuspendingReportExporter implements ReportExporter {
  SuspendingReportExporter(this.inner, this.suspend);

  final ReportExporter inner;
  final SuspendRunner suspend;

  @override
  Future<void> share(DoctorReportFile file, {String? subject}) => suspend(() => inner.share(file, subject: subject));

  @override
  Future<bool> save(DoctorReportFile file) => suspend(() => inner.save(file));
}

/// The support note's trip to the phone's dialler suspended (the lock still
/// locks after its grace if the call runs long).
class SuspendingPhoneDialer implements PhoneDialer {
  SuspendingPhoneDialer(this.inner, this.suspend);

  final PhoneDialer inner;
  final SuspendRunner suspend;

  @override
  Future<bool> dial(String number) => suspend(() => inner.dial(number));
}

/// Permission requests suspended; everything else passes straight through.
class SuspendingNotificationPlatform implements NotificationPlatform {
  SuspendingNotificationPlatform(this.inner, this.suspend);

  final NotificationPlatform inner;
  final SuspendRunner suspend;

  @override
  Future<bool> requestNotifications() => suspend(inner.requestNotifications);

  @override
  Future<bool> requestExactAlarms() => suspend(inner.requestExactAlarms);

  @override
  Future<bool> requestFullScreenIntent() => suspend(inner.requestFullScreenIntent);

  @override
  Future<void> initialize({required void Function(RawNotificationTap tap) onTap}) => inner.initialize(onTap: onTap);

  @override
  Future<RawNotificationTap?> launchTap() => inner.launchTap();

  @override
  Future<void> createChannelGroup(String id, String name) => inner.createChannelGroup(id, name);

  @override
  Future<void> createChannel(NotificationChannelSpec spec) => inner.createChannel(spec);

  @override
  Future<void> deleteChannel(String id) => inner.deleteChannel(id);

  @override
  Future<List<String>> channelIds() => inner.channelIds();

  @override
  Future<void> schedule(NotificationRequest request, String payload, {required NotificationTiming timing}) =>
      inner.schedule(request, payload, timing: timing);

  @override
  Future<void> show(NotificationRequest request, String payload) => inner.show(request, payload);

  @override
  Future<void> cancel(int id) => inner.cancel(id);

  @override
  Future<List<PendingNotice>> pending() => inner.pending();

  @override
  Future<Set<int>?> armedIds(Iterable<int> ids) => inner.armedIds(ids);

  @override
  Future<List<int>> activeIds() => inner.activeIds();

  @override
  Future<bool> notificationsEnabled() => inner.notificationsEnabled();

  @override
  Future<bool> canScheduleExact() => inner.canScheduleExact();
}

/// The battery-optimisation dialog suspended.
class SuspendingBatteryGate implements BatteryOptimizationGate {
  SuspendingBatteryGate(this.inner, this.suspend);

  final BatteryOptimizationGate inner;
  final SuspendRunner suspend;

  @override
  Future<bool> isExempt() => inner.isExempt();

  @override
  Future<bool> requestExemption() => suspend(inner.requestExemption);
}

/// The adhan's trips to system settings suspended.
class SuspendingAdhanSystem implements AdhanSystem {
  SuspendingAdhanSystem(this.inner, this.suspend);

  final AdhanSystem inner;
  final SuspendRunner suspend;

  @override
  Future<bool> openSoundSettings() => suspend(inner.openSoundSettings);

  @override
  Future<bool> openNotificationSettings({String? channelId}) =>
      suspend(() => inner.openNotificationSettings(channelId: channelId));

  @override
  Future<bool> openFullScreenIntentSettings() => suspend(inner.openFullScreenIntentSettings);

  @override
  Future<bool> openBatterySettings() => suspend(inner.openBatterySettings);

  @override
  Future<void> setLockScreenMode(bool enabled) => inner.setLockScreenMode(enabled);

  @override
  Future<bool> isKeyguardLocked() => inner.isKeyguardLocked();

  @override
  Future<bool> canUseFullScreenIntent() => inner.canUseFullScreenIntent();

  @override
  Future<AlarmVolume?> alarmVolume() => inner.alarmVolume();

  @override
  Future<String?> soundsDirectory() => inner.soundsDirectory();

  @override
  Future<String?> soundUri(String fileName) => inner.soundUri(fileName);
}

/// The location permission and settings pages suspended.
class SuspendingLocationSource implements LocationSource {
  SuspendingLocationSource(this.inner, this.suspend);

  final LocationSource inner;
  final SuspendRunner suspend;

  @override
  Future<LocationAccess> check() => inner.check();

  @override
  Future<LocationAccess> request() => suspend(inner.request);

  @override
  Future<GeoFix> currentFix({Duration timeLimit = const Duration(seconds: 20)}) =>
      inner.currentFix(timeLimit: timeLimit);

  @override
  Future<bool> openAppSettings() => suspend(inner.openAppSettings);

  @override
  Future<bool> openLocationSettings() => suspend(inner.openLocationSettings);
}

/// The document picker (muezzin recordings) suspended.
class SuspendingAudioFilePicker implements AudioFilePicker {
  SuspendingAudioFilePicker(this.inner, this.suspend);

  final AudioFilePicker inner;
  final SuspendRunner suspend;

  @override
  Future<PickedAudio?> pick() => suspend(inner.pick);
}
