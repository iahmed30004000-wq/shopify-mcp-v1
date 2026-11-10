/// «الإقامة»: for each of the five prayers a call at *adhan + offset*
/// («قامت الصلاة»), each one switchable on its own while its adhan stays
/// on, Friday's Dhuhr with its own offset, its own sound, and two buttons
/// answered straight from the shade – «صلّيت», which logs that prayer in
/// the existing tracker even with Madar closed, and «بعد شوي», one snooze.
///
/// It owns notification ids 180000–180999 ([IqamaIds]), never the adhan's.
library;

export 'application/iqama_providers.dart';
export 'data/iqama_background.dart';
export 'data/iqama_scheduler.dart';
export 'data/iqama_settings_repository.dart';
export 'data/iqama_texts.dart';
export 'domain/iqama_event.dart';
export 'domain/iqama_plan.dart';
export 'domain/iqama_settings.dart';
export 'presentation/iqama_settings_screen.dart';
