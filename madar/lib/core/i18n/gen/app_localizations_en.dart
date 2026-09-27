// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class L10nEn extends L10n {
  L10nEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Madar';

  @override
  String get appTagline => 'A life that orbits the prayer';

  @override
  String get actionSave => 'Save';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionAdd => 'Add';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionDuplicate => 'Duplicate';

  @override
  String get actionMove => 'Move';

  @override
  String get actionSetReminder => 'Set reminder';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionUndo => 'Undo';

  @override
  String get actionDone => 'Done';

  @override
  String get actionClose => 'Close';

  @override
  String get actionBack => 'Back';

  @override
  String get actionContinue => 'Continue';

  @override
  String get actionComplete => 'Complete';

  @override
  String get actionSearch => 'Search';

  @override
  String get itemDeleted => 'Deleted';

  @override
  String get itemDuplicated => 'Duplicated';

  @override
  String get itemMoved => 'Moved';

  @override
  String get itemSaved => 'Saved';

  @override
  String get fieldRequired => 'This field is required';

  @override
  String get fieldInvalidNumber => 'Enter a valid number';

  @override
  String get windowFajr => 'After Fajr';

  @override
  String get windowDuha => 'Duha';

  @override
  String get windowDhuhr => 'Dhuhr → Asr';

  @override
  String get windowAsr => 'Asr → Maghrib';

  @override
  String get windowMaghrib => 'Maghrib → Isha';

  @override
  String get windowIsha => 'After Isha';

  @override
  String get windowAnytime => 'Anytime';

  @override
  String get prayerFajr => 'Fajr';

  @override
  String get prayerSunrise => 'Sunrise';

  @override
  String get prayerDhuhr => 'Dhuhr';

  @override
  String get prayerAsr => 'Asr';

  @override
  String get prayerMaghrib => 'Maghrib';

  @override
  String get prayerIsha => 'Isha';

  @override
  String get planetFaith => 'Faith';

  @override
  String get planetHealth => 'Health';

  @override
  String get planetFamily => 'Family';

  @override
  String get planetWork => 'Work';

  @override
  String get planetMoney => 'Money';

  @override
  String get planetGrowth => 'Growth';

  @override
  String get planetBody => 'Body';

  @override
  String get planetTravel => 'Travel';

  @override
  String itemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
      zero: 'No items',
    );
    return '$_temp0';
  }

  @override
  String get designLoading => 'Loading';

  @override
  String get designEmptyListTitle => 'Nothing here yet';

  @override
  String get designEmptyListBody =>
      'Add your first item and set its orbit in motion.';

  @override
  String get designNoDataTitle => 'No data yet';

  @override
  String get designNoDataBody =>
      'Charts appear here once a few days are recorded.';

  @override
  String get designNoResultsTitle => 'No results';

  @override
  String get designNoResultsBody => 'Try another word, or widen your search.';

  @override
  String get designGalleryTitle => 'Design gallery';

  @override
  String get designGallerySubtitle => 'Every Madar component in one place';

  @override
  String get designGalleryTheme => 'Theme';

  @override
  String get designGalleryDirection => 'Writing direction';

  @override
  String get designDirectionRtl => 'Right to left';

  @override
  String get designDirectionLtr => 'Left to right';

  @override
  String get designThemeLapis => 'Lapis';

  @override
  String get designThemeEmerald => 'Emerald';

  @override
  String get designThemeDesert => 'Desert';

  @override
  String get designThemeAurora => 'Aurora';

  @override
  String get designThemePearl => 'Pearl';

  @override
  String get designSectionSurfaces => 'Glass surfaces';

  @override
  String get designSectionButtons => 'Buttons';

  @override
  String get designSectionChips => 'Choices';

  @override
  String get designSectionToggles => 'Toggles';

  @override
  String get designSectionProgress => 'Progress';

  @override
  String get designSectionStats => 'Stats';

  @override
  String get designSectionOrnaments => 'Ornaments';

  @override
  String get designSectionLoaders => 'Loading';

  @override
  String get designSectionEmpty => 'Empty states';

  @override
  String get designSectionType => 'Type & colour';

  @override
  String get designSeeAll => 'See all';

  @override
  String get designPanelTitle => 'Glass panel';

  @override
  String get designPanelBody =>
      'Real blur over the living cosmos, with a fine gold hairline and a slowly drifting sheen.';

  @override
  String get designCardBody =>
      'Faux glass for long lists: no blur, the same elegance.';

  @override
  String get designButtonPrimary => 'Start your day';

  @override
  String get designButtonSecondary => 'Later';

  @override
  String get designButtonGhost => 'Details';

  @override
  String get designChipsSingle => 'Single choice';

  @override
  String get designChipsMulti => 'Multiple choice';

  @override
  String get designToggleSound => 'Interface sounds';

  @override
  String get designToggleHaptics => 'Haptics';

  @override
  String get designToggleReduceMotion => 'Reduce motion';

  @override
  String get designRingDaily => 'Daily goal';

  @override
  String get designRingPrayers => 'Prayers';

  @override
  String get designRingDone => 'Complete';

  @override
  String get designStatStreak => 'Prayer streak';

  @override
  String get designStatSteps => 'Steps';

  @override
  String get designStatWater => 'Water';

  @override
  String get designStatFocus => 'Focus';

  @override
  String get designStatVsLastWeek => 'vs last week';

  @override
  String designUnitDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'days',
      one: 'day',
    );
    return '$_temp0';
  }

  @override
  String get designUnitLitres => 'L';

  @override
  String get designUnitHours => 'h';

  @override
  String get designOrnamentStar => 'Eight-point star';

  @override
  String get designOrnamentStar12 => 'Twelve-point star';

  @override
  String get designOrnamentRub => 'Rub el Hizb';

  @override
  String get designOrnamentRosette => 'Girih rosette';

  @override
  String get designOrnamentAstrolabe => 'Astrolabe ring';

  @override
  String get designOrnamentArabesque => 'Arabesque band';

  @override
  String get designTypeSample =>
      'Arabic breathes easy here: generous lines, clear diacritics, tidy numerals.';

  @override
  String get dbCurrencyJod => 'Jordanian Dinar';

  @override
  String get dbCurrencyUsd => 'US Dollar';

  @override
  String get dbCurrencySyp => 'Syrian Pound';

  @override
  String get dbCurrencyEgp => 'Egyptian Pound';

  @override
  String get dbCurrencyLyd => 'Libyan Dinar';

  @override
  String get dbSeedPainHead => 'Head';

  @override
  String get dbSeedPainNeck => 'Neck';

  @override
  String get dbSeedPainShoulders => 'Shoulders';

  @override
  String get dbSeedPainUpperBack => 'Upper back';

  @override
  String get dbSeedPainLowerBack => 'Lower back';

  @override
  String get dbSeedPainChest => 'Chest';

  @override
  String get dbSeedPainAbdomen => 'Abdomen';

  @override
  String get dbSeedPainArms => 'Arms';

  @override
  String get dbSeedPainHands => 'Hands and fingers';

  @override
  String get dbSeedPainHips => 'Hips';

  @override
  String get dbSeedPainKnees => 'Knees';

  @override
  String get dbSeedPainFeet => 'Feet and ankles';

  @override
  String get dbSeedPainJoints => 'Joints in general';

  @override
  String get dbSeedTriggerSleep => 'Poor sleep';

  @override
  String get dbSeedTriggerStress => 'Stress';

  @override
  String get dbSeedTriggerSitting => 'Sitting for long';

  @override
  String get dbSeedTriggerStanding => 'Standing for long';

  @override
  String get dbSeedTriggerExertion => 'Overexertion';

  @override
  String get dbSeedTriggerCold => 'Cold';

  @override
  String get dbSeedTriggerWeather => 'Weather change';

  @override
  String get dbSeedTriggerFood => 'A particular food';

  @override
  String get dbSeedTriggerWater => 'Not drinking enough water';

  @override
  String get dbSeedTriggerMissedDose => 'Missed medication dose';

  @override
  String get dbSeedTriggerScreens => 'Long screen time';

  @override
  String get dbSeedMoodSleep => 'Sleep';

  @override
  String get dbSeedMoodPrayer => 'Prayer and dhikr';

  @override
  String get dbSeedMoodFamily => 'Family';

  @override
  String get dbSeedMoodWork => 'Work';

  @override
  String get dbSeedMoodMoney => 'Money';

  @override
  String get dbSeedMoodHealth => 'Health';

  @override
  String get dbSeedMoodExercise => 'Movement and exercise';

  @override
  String get dbSeedMoodFriends => 'Friends';

  @override
  String get dbSeedMoodCaffeine => 'Caffeine';

  @override
  String get dbSeedMoodWeather => 'Weather';

  @override
  String get dbSeedMoodNews => 'News';

  @override
  String get dbSeedMoodLoneliness => 'Loneliness';

  @override
  String get dbSeedHabitBreathing => 'Five minutes of deep breathing';

  @override
  String get dbSeedHabitWalk => 'A calm walk outdoors';

  @override
  String get dbSeedHabitAdhkar => 'Morning and evening adhkar';

  @override
  String get dbSeedHabitGratitude => 'Three blessings to thank Allah for today';

  @override
  String get dbSeedHabitScreens => 'A screen-free hour before bed';

  @override
  String get dbSeedHabitSleep => 'Go to bed early';

  @override
  String get dbSeedHabitWater => 'Drink water through the day';

  @override
  String get dbSeedHabitCaffeine => 'No caffeine after Asr';

  @override
  String get dbSeedHabitStretch => 'Gentle stretching';

  @override
  String get dbSeedHabitJournal => 'Write down what\'s on your mind';

  @override
  String get dbSeedHabitConnect => 'Reach out to someone dear';

  @override
  String get dbErrorCipherUnavailable =>
      'Encryption isn\'t available on this device, and Madar won\'t store your data unencrypted.';

  @override
  String get dbErrorWrongKey =>
      'Couldn\'t unlock your data: the encryption key doesn\'t match the file, or the file is damaged.';

  @override
  String get dbErrorKeyMissing =>
      'The encryption key is missing from secure storage, so the saved data can\'t be opened.';

  @override
  String get dbErrorKeyMalformed => 'The stored encryption key is damaged.';

  @override
  String get dbErrorKeyStorage =>
      'Couldn\'t reach the device\'s secure storage.';

  @override
  String get dbErrorSnapshotInvalid => 'This file isn\'t a valid Madar backup.';

  @override
  String get dbErrorSnapshotNewer =>
      'This backup comes from a newer version of Madar. Update the app and try again.';

  @override
  String get dbErrorSnapshotRejected =>
      'The backup couldn\'t be restored; your current data is unchanged.';

  @override
  String get dbErrorUnknown => 'Something went wrong while saving your data.';

  @override
  String get soundProfileLapis => 'Crystal bells';

  @override
  String get soundProfileEmerald => 'Warm wood';

  @override
  String get soundProfileDesert => 'Oud & frame drum';

  @override
  String get soundProfileAurora => 'Aurora shimmer';

  @override
  String get soundProfilePearl => 'Pearl chimes';

  @override
  String get soundProfileLapisDescription => 'Clear glass bells in maqam Rast';

  @override
  String get soundProfileEmeraldDescription =>
      'Kalimba and warm wood in maqam Bayati';

  @override
  String get soundProfileDesertDescription =>
      'Oud plucks and a soft frame drum in maqam Hijaz';

  @override
  String get soundProfileAuroraDescription =>
      'An airy, shimmering glow in maqam \'Ajam';

  @override
  String get soundProfilePearlDescription =>
      'Delicate crystal chimes in maqam Nahawand';

  @override
  String get soundCategoryUi => 'Interface sounds';

  @override
  String get soundCategoryAmbient => 'Cosmic ambience';

  @override
  String get soundCategoryGames => 'Games';

  @override
  String get soundCategoryPrayer => 'Adhan & prayer';

  @override
  String get soundPrayerMuteNote =>
      'Ambience and games fall silent during the adhan and prayer; soft interface sounds remain.';

  @override
  String get soundPreview => 'Preview';

  @override
  String get soundUnavailable => 'Audio isn\'t available on this device';

  @override
  String get interactionMenuLabel => 'Item options';

  @override
  String get interactionMenuDismiss => 'Close menu';

  @override
  String get interactionQuickActions => 'Quick actions';

  @override
  String get interactionSwipeToComplete => 'Swipe right to complete';

  @override
  String get interactionReorderHandle => 'Drag to reorder';

  @override
  String interactionUndoAvailable(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Undo available for $seconds seconds',
      one: 'Undo available for 1 second',
      zero: 'Undo expired',
    );
    return '$_temp0';
  }

  @override
  String get interactionUndone => 'Undone';

  @override
  String get interactionSheetGrabber => 'Drag down to close';

  @override
  String get interactionDiscardTitle => 'Discard changes?';

  @override
  String get interactionDiscardBody => 'Your changes haven\'t been saved.';

  @override
  String get interactionDiscardConfirm => 'Discard';

  @override
  String get interactionKeepEditing => 'Keep editing';

  @override
  String get interactionSaveDisabledHint =>
      'Complete the required fields first';

  @override
  String get interactionFieldOptional => 'Optional';

  @override
  String interactionFieldMin(String min) {
    return 'At least $min';
  }

  @override
  String interactionFieldMax(String max) {
    return 'At most $max';
  }

  @override
  String interactionFieldDecimals(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Up to $count decimal places',
      one: 'Up to 1 decimal place',
      zero: 'Whole numbers only',
    );
    return '$_temp0';
  }

  @override
  String interactionFieldTooLong(int max) {
    return 'Keep it under $max characters';
  }

  @override
  String interactionFieldSelectAtLeast(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Pick at least $count',
      one: 'Pick at least one',
    );
    return '$_temp0';
  }

  @override
  String interactionFieldSelectAtMost(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Pick up to $count',
      one: 'Pick only one',
    );
    return '$_temp0';
  }

  @override
  String get interactionFieldDateRange => 'That date is out of range';

  @override
  String get interactionFieldPickDate => 'Pick a date';

  @override
  String get interactionFieldPickTime => 'Pick a time';

  @override
  String get interactionFieldClear => 'Clear';

  @override
  String get interactionFieldAddTime => 'Add time';

  @override
  String get interactionFieldTimeExists => 'That time is already added';

  @override
  String get interactionFieldAddOption => 'New option';

  @override
  String get interactionFieldAddOptionHint => 'Type it, then tap Add';

  @override
  String interactionFieldRemove(String label) {
    return 'Remove $label';
  }

  @override
  String interactionFieldRating(int count, int max) {
    return '$count of $max';
  }

  @override
  String get interactionFieldIncrease => 'Increase';

  @override
  String get interactionFieldDecrease => 'Decrease';

  @override
  String interactionFieldColor(int index) {
    return 'Colour $index';
  }

  @override
  String get interactionFieldAmount => 'Amount';

  @override
  String get interactionFieldCurrency => 'Currency';

  @override
  String get interactionTimeHour => 'Hour';

  @override
  String get interactionTimeMinute => 'Minute';

  @override
  String get interactionDateToday => 'Today';

  @override
  String get interactionDateTomorrow => 'Tomorrow';

  @override
  String get interactionDateDayAfter => 'Day after tomorrow';

  @override
  String get interactionDateYesterday => 'Yesterday';

  @override
  String get interactionCurrencyJOD => 'Jordanian dinar';

  @override
  String get interactionCurrencyUSD => 'US dollar';

  @override
  String get interactionCurrencySYP => 'Syrian pound';

  @override
  String get interactionCurrencyEGP => 'Egyptian pound';

  @override
  String get interactionCurrencyLYD => 'Libyan dinar';

  @override
  String get interactionCurrencySymbolJOD => 'JD';

  @override
  String get interactionCurrencySymbolUSD => '\$';

  @override
  String get interactionCurrencySymbolSYP => 'SYP';

  @override
  String get interactionCurrencySymbolEGP => 'EGP';

  @override
  String get interactionCurrencySymbolLYD => 'LYD';

  @override
  String get interactionMoveSearch => 'Find a destination';

  @override
  String get interactionMoveCurrent => 'Current';

  @override
  String get interactionMoveEmpty => 'No destination matches';

  @override
  String get interactionReminderTitle => 'When should I remind you?';

  @override
  String get interactionReminderKindOnce => 'Once';

  @override
  String get interactionReminderKindDaily => 'Daily';

  @override
  String get interactionReminderKindWeekly => 'Weekly';

  @override
  String get interactionReminderKindPrayer => 'With prayer';

  @override
  String get interactionReminderKindBeforeDue => 'Before due';

  @override
  String get interactionReminderDate => 'Date';

  @override
  String get interactionReminderTime => 'Time';

  @override
  String get interactionReminderDays => 'Days';

  @override
  String get interactionReminderPrayer => 'Prayer';

  @override
  String get interactionReminderOffset => 'Timing around the prayer';

  @override
  String get interactionReminderLead => 'Remind me';

  @override
  String get interactionReminderPast =>
      'That time has passed – pick a later one';

  @override
  String get interactionReminderNoDays => 'Pick at least one day';

  @override
  String interactionReminderPrayerAt(String prayer) {
    return 'At $prayer';
  }

  @override
  String interactionReminderPrayerAfter(String prayer, String duration) {
    return '$duration after $prayer';
  }

  @override
  String interactionReminderPrayerBefore(String prayer, String duration) {
    return '$duration before $prayer';
  }

  @override
  String interactionReminderBefore(String duration) {
    return '$duration before';
  }

  @override
  String interactionReminderDaily(String time) {
    return 'Every day at $time';
  }

  @override
  String interactionReminderOnce(String date, String time) {
    return '$date at $time';
  }

  @override
  String get interactionReminderRelBefore => 'Before';

  @override
  String get interactionReminderRelAt => 'On time';

  @override
  String get interactionReminderRelAfter => 'After';

  @override
  String interactionReminderWeekly(String days, String time) {
    return '$days at $time';
  }

  @override
  String get interactionReminderWorkdays => 'Workdays';

  @override
  String get interactionReminderEveryDay => 'Every day';

  @override
  String get interactionReminderRemove => 'Remove reminder';

  @override
  String get interactionReminderNoDue => 'This item has no due date';

  @override
  String interactionDurationMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String interactionDurationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String interactionDurationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String interactionDurationWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks',
      one: '1 week',
    );
    return '$_temp0';
  }

  @override
  String get interactionWeekdayMon => 'Mon';

  @override
  String get interactionWeekdayTue => 'Tue';

  @override
  String get interactionWeekdayWed => 'Wed';

  @override
  String get interactionWeekdayThu => 'Thu';

  @override
  String get interactionWeekdayFri => 'Fri';

  @override
  String get interactionWeekdaySat => 'Sat';

  @override
  String get interactionWeekdaySun => 'Sun';

  @override
  String get interactionQuickAddHint => 'Type anything… “spent 5 JD on coffee”';

  @override
  String get interactionQuickAddLabel => 'Quick add';

  @override
  String get interactionQuickAddUnavailable => 'Quick add isn\'t ready yet';

  @override
  String get interactionQuickAddFailed => 'Couldn\'t add that – try again';

  @override
  String get interactionQuickAddEmpty => 'Type something first';

  @override
  String get interactionQuickAddAdded => 'Added to its orbit';

  @override
  String interactionQuickAddAt(String time) {
    return 'at $time';
  }

  @override
  String interactionQuickAddMl(String ml) {
    return '$ml ml';
  }

  @override
  String interactionQuickAddScore(String score, int max) {
    return '$score/$max';
  }

  @override
  String get interactionKindTask => 'Task';

  @override
  String get interactionKindExpense => 'Expense';

  @override
  String get interactionKindIncome => 'Income';

  @override
  String get interactionKindWater => 'Water';

  @override
  String get interactionKindPain => 'Pain';

  @override
  String get interactionKindMood => 'Mood';

  @override
  String get interactionKindContact => 'Contact';

  @override
  String get interactionKindNote => 'Note';

  @override
  String get interactionListSeparator => ', ';

  @override
  String get interactionQuickAddPreview => 'Here\'s how I read it';

  @override
  String get interactionTrayLabel => 'Quick actions open';

  @override
  String get importTitle => 'Import data';

  @override
  String get importHeroTitle => 'Bring your data into orbit';

  @override
  String get importHeroBody =>
      'Choose the JSON file you exported from the prototype, or paste its contents. We analyse it first and show you everything before a single row is written.';

  @override
  String get importPickFile => 'Choose a JSON file';

  @override
  String get importPasteToggle => 'Paste JSON text';

  @override
  String get importPasteHint => 'Paste the file contents here…';

  @override
  String get importAnalyzeAction => 'Analyse';

  @override
  String get importAnalyzing => 'Reading your file and charting it…';

  @override
  String get importAcceptedHint =>
      'We accept the prototype export (data + logs) or plain sections, with Arabic or English keys. Nothing is lost: what we don\'t recognise is kept in the archive.';

  @override
  String get importFileLabel => 'File';

  @override
  String get importPastedLabel => 'Pasted text';

  @override
  String get importPreviewTitle => 'What we found';

  @override
  String importRecordsReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'records ready to import',
      one: 'record ready to import',
      zero: 'No records to import',
    );
    return '$_temp0';
  }

  @override
  String get importShapeTitle => 'File layout';

  @override
  String get importShapeWrapped => 'data + logs';

  @override
  String get importShapeDataOnly => 'data only';

  @override
  String get importShapeLogsOnly => 'logs only';

  @override
  String get importShapeFlat => 'plain sections';

  @override
  String get importShapeList => 'a list of records';

  @override
  String get importShapeNested => 'grouped by area';

  @override
  String get importShapeDayKeyed => 'logs by day';

  @override
  String get importShapeTyped => 'typed events';

  @override
  String get importShapeIdKeyed => 'keyed by id';

  @override
  String get importKeysArabic => 'Arabic keys';

  @override
  String get importKeysCamel => 'camelCase keys';

  @override
  String get importKeysSnake => 'snake_case keys';

  @override
  String get importKeysMixed => 'mixed keys';

  @override
  String get importSectionsTitle => 'Sections';

  @override
  String importBudgetTotal(String amount) {
    return 'Monthly budget total: $amount';
  }

  @override
  String get importModulesTitle => 'New modules from unknown data';

  @override
  String get importModulesBody =>
      'We didn\'t recognise these sections, so they became custom modules — nothing is lost.';

  @override
  String importModuleEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '1 entry',
      zero: 'no entries',
    );
    return '$_temp0';
  }

  @override
  String get importWarningsTitle => 'Before you import';

  @override
  String get importUnmappedTitle => 'Kept in the archive';

  @override
  String get importUnmappedBody =>
      'Values Madar has no place for yet; they are kept as they are with the original file.';

  @override
  String importTimesCount(String count) {
    return '×$count';
  }

  @override
  String get importDuplicateTitle => 'You imported this file before';

  @override
  String importDuplicateBody(String date) {
    return 'That was on $date. Existing records won\'t be duplicated — only new ones are added.';
  }

  @override
  String get importDuplicateAnyway => 'Import anyway';

  @override
  String importStartAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Import $count records',
      one: 'Import 1 record',
      zero: 'Keep in the archive',
    );
    return '$_temp0';
  }

  @override
  String get importChooseAnother => 'Another file';

  @override
  String get importWriting => 'Writing your data into orbit…';

  @override
  String get importDoneTitle => 'Import complete';

  @override
  String importDoneBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count records added',
      one: '1 record added',
      zero: 'No new records were added',
    );
    return '$_temp0';
  }

  @override
  String importDoneExisting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count records already existed and were left as they are',
      one: '1 record already existed and was left as it is',
    );
    return '$_temp0';
  }

  @override
  String get importDoneArchived =>
      'A complete original copy of the file is kept in the archive.';

  @override
  String get importErrorInvalidJson => 'This isn\'t valid JSON.';

  @override
  String get importErrorEmpty => 'There\'s nothing to import.';

  @override
  String get importErrorNotObject => 'The file holds no importable data.';

  @override
  String get importErrorRead => 'The file couldn\'t be read.';

  @override
  String get importErrorCommit =>
      'The import failed and nothing in your data changed.';

  @override
  String get importNothingFound =>
      'We found nothing we recognise in this file, but it will be kept whole in the archive.';

  @override
  String get importTryAgain => 'Try again';

  @override
  String get importDefaultWallet => 'Main wallet';

  @override
  String get importDefaultBoard => 'Work';

  @override
  String get importOpeningBalance => 'Opening balance';

  @override
  String get importColumnTodo => 'To-do';

  @override
  String get importColumnDoing => 'Doing';

  @override
  String get importColumnDone => 'Done';

  @override
  String get importSectionHealthAlerts => 'Health alerts';

  @override
  String get importSectionConditions => 'Conditions';

  @override
  String get importSectionMedications => 'Medications';

  @override
  String get importSectionMedDoses => 'Dose log';

  @override
  String get importSectionLabTests => 'Lab tests';

  @override
  String get importSectionLabReadings => 'Lab results';

  @override
  String get importSectionAppointments => 'Appointments';

  @override
  String get importSectionDoctorQuestions => 'Doctor questions';

  @override
  String get importSectionPainEntries => 'Pain log';

  @override
  String get importSectionMoodEntries => 'Mood & stress';

  @override
  String get importSectionHabits => 'Habits';

  @override
  String get importSectionHabitLogs => 'Habit log';

  @override
  String get importSectionWorries => 'Worries';

  @override
  String get importSectionCurrencies => 'Currencies';

  @override
  String get importSectionWallets => 'Wallets';

  @override
  String get importSectionBudgetItems => 'Budget items';

  @override
  String get importSectionTransactions => 'Transactions';

  @override
  String get importSectionJars => 'Savings jars';

  @override
  String get importSectionJarDeposits => 'Jar deposits';

  @override
  String get importSectionDebts => 'Debts';

  @override
  String get importSectionDebtPayments => 'Debt payments';

  @override
  String get importSectionObligations => 'Recurring bills';

  @override
  String get importSectionPeople => 'People';

  @override
  String get importSectionContactLogs => 'Contact log';

  @override
  String get importSectionProjects => 'Projects';

  @override
  String get importSectionProjectItems => 'Project items';

  @override
  String get importSectionBoards => 'Work boards';

  @override
  String get importSectionBoardCards => 'Work cards';

  @override
  String get importSectionTrips => 'Trips';

  @override
  String get importSectionTripItems => 'Packing items';

  @override
  String get importSectionTravelDocuments => 'Travel documents';

  @override
  String get importSectionLearningGoals => 'Learning goals';

  @override
  String get importSectionGoalLogs => 'Progress log';

  @override
  String get importSectionExercises => 'Exercises';

  @override
  String get importSectionWorkoutLogs => 'Workout log';

  @override
  String get importSectionAvoidItems => 'Avoid list';

  @override
  String get importSectionFastingSessions => 'Fasting';

  @override
  String get importSectionWaterLogs => 'Water';

  @override
  String get importSectionPrayerLogs => 'Prayer log';

  @override
  String get importSectionTasks => 'Tasks';

  @override
  String get importSectionCustomModules => 'Custom modules';

  @override
  String get importSectionCustomEntries => 'Module entries';

  @override
  String get importIssueInvalidJson => 'Invalid JSON';

  @override
  String get importIssueEmptyInput => 'Nothing to import';

  @override
  String get importIssueNotAnObject => 'No importable data';

  @override
  String get importIssueUnparsedDate => 'Dates we couldn\'t read';

  @override
  String get importIssueUnparsedAmount => 'Amounts we couldn\'t read';

  @override
  String get importIssueUnparsedTime => 'Times we couldn\'t read';

  @override
  String get importIssueUnparsedNumber => 'Numbers we couldn\'t read';

  @override
  String get importIssueInferredTime =>
      'Times inferred from words (morning → 08:00)';

  @override
  String get importIssueMissingRequired =>
      'Records missing a required value weren\'t imported — they\'re kept in the archive';

  @override
  String get importIssueUnresolvedReference =>
      'References to items that don\'t exist';

  @override
  String get importIssueCreatedReference => 'Items created from their names';

  @override
  String get importIssueUnknownValue =>
      'Unknown values replaced with the default';

  @override
  String get importIssueAssumedGlasses =>
      'Water amounts read as glasses (250 ml)';

  @override
  String get importIssueAssumedFastingTarget => 'Assumed fasting targets';

  @override
  String get importIssueAssumedDate => 'Assumed dates';

  @override
  String get importIssueAssumedValue => 'Assumed values';

  @override
  String get importIssueCurrencyWallet =>
      'Wallets created for other currencies (nothing converted)';

  @override
  String get importIssueMissingRate =>
      'Currencies without a rate (1 assumed) — set it in settings';

  @override
  String get importIssueDuplicateSourceId => 'Duplicate ids in the file';

  @override
  String get importIssueBudget => 'Budget checks';

  @override
  String get importIssueDuplicateFile => 'File imported before';

  @override
  String get importIssueSettingRead => 'Settings read from the file';

  @override
  String importBudgetChildrenUnder(String name, String amount) {
    return 'Items under “$name” add up to $amount less than it';
  }

  @override
  String importBudgetChildrenOver(String name, String amount) {
    return 'Items under “$name” add up to $amount more than it';
  }

  @override
  String importBudgetPercentOver(String name, String percent) {
    return 'Percentages of “$name” exceed 100% ($percent)';
  }

  @override
  String importBudgetCircular(String name) {
    return 'Percentages of “$name” depend on themselves';
  }

  @override
  String importBudgetStructure(String name) {
    return '“$name” pointed to an invalid parent, so it became a top-level item';
  }

  @override
  String importBudgetMissingRate(String currency) {
    return 'No exchange rate for $currency';
  }

  @override
  String get importBudgetWhole => 'the whole budget';

  @override
  String get shellSplashAssembling => 'Assembling your astrolabe…';

  @override
  String get shellSplashSemantics => 'Unlocking your encrypted data';

  @override
  String get shellGateErrorTitle => 'Madar couldn\'t open';

  @override
  String get shellGateRetry => 'Try again';

  @override
  String get shellGateReset => 'Start fresh';

  @override
  String get shellGateResetTitle => 'Delete all data?';

  @override
  String get shellGateResetBody =>
      'The encrypted data file will be permanently deleted and Madar will start from scratch. This can\'t be undone, and without a backup your old data won\'t come back.';

  @override
  String get shellGateResetConfirm => 'Delete and start fresh';

  @override
  String get shellGateResetFailed =>
      'Couldn\'t delete the data. Restart the app and try again.';

  @override
  String shellDurationHoursMinutes(String hours, String minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String shellDurationHours(String hours) {
    return '${hours}h';
  }

  @override
  String shellDurationMinutes(String minutes) {
    return '$minutes min';
  }

  @override
  String get shellDurationLessThanMinute => 'under a minute';

  @override
  String get homeOpenSettings => 'Settings';

  @override
  String get homeNow => 'Now';

  @override
  String homeNextPrayer(String prayer, String duration) {
    return '$prayer in $duration';
  }

  @override
  String get homePlaceholderBadge => 'Approximate times';

  @override
  String get homePlaceholderNote =>
      'Exact times for your location are coming soon';

  @override
  String homeWindowStarts(String window, String time) {
    return '$window, starts $time';
  }

  @override
  String homeTasksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks',
      one: '1 task',
      zero: 'No tasks yet',
    );
    return '$_temp0';
  }

  @override
  String homeTasksProgress(String done, String total) {
    return '$done of $total done';
  }

  @override
  String get homeAddTask => 'New task';

  @override
  String get homeEditTask => 'Edit task';

  @override
  String get homeTaskTitleField => 'Task';

  @override
  String get homeTaskTitleHint => 'What would you like to get done?';

  @override
  String get homeTaskNotesField => 'Notes';

  @override
  String get homeTaskWindowField => 'Time of day';

  @override
  String get homeTaskDateField => 'Day';

  @override
  String get homeTaskPlanetField => 'Planet';

  @override
  String get homeTaskAdded => 'Task added';

  @override
  String get homeTaskCompleted => 'Task completed';

  @override
  String get homeTaskReopened => 'Task reopened';

  @override
  String get homeTaskReopen => 'Reopen';

  @override
  String get homeTaskDone => 'Done';

  @override
  String get homeMoveTitle => 'Move to another window';

  @override
  String get homeMoveSubtitle => 'It stays on the same day';

  @override
  String get homeReminderSet => 'Reminder set';

  @override
  String get homeReminderRemoved => 'Reminder removed';

  @override
  String get homeEmptyTitle => 'This window is wide open';

  @override
  String get homeEmptyBody =>
      'Add a task, or type what\'s on your mind in the bar below.';

  @override
  String get homeRadarTitle => 'Neglect Radar';

  @override
  String get homeRadarBody =>
      'It will gently point you to the parts of life you\'ve drifted from — arriving with the living orbit.';

  @override
  String get homeRadarBadge => 'Soon';

  @override
  String get homeDefaultWallet => 'Wallet';

  @override
  String homeDialSemantics(String window, String next) {
    return 'Today\'s astrolabe: $window; $next';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsPersonal => 'Personalisation';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsAppearanceSubtitle => 'Theme, accent, language and digits';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeSelected => 'Current theme';

  @override
  String get settingsFollowSystem => 'Follow the device';

  @override
  String get settingsFollowSystemHint =>
      'Pearl in light mode, your chosen theme in dark mode';

  @override
  String get settingsAccent => 'Accent colour';

  @override
  String get settingsAccentDefault => 'Theme colour';

  @override
  String get settingsAccentCustom => 'Custom colour';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageArabic => 'العربية';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsDigits => 'Digits';

  @override
  String get settingsDigitsAuto => 'Automatic';

  @override
  String get settingsDigitsWestern => 'Western';

  @override
  String get settingsDigitsArabicIndic => 'Arabic-Indic';

  @override
  String get settingsDigitsHint =>
      'Automatic: Arabic-Indic in Arabic, Western in English';

  @override
  String get settingsSound => 'Sound & haptics';

  @override
  String get settingsSoundSubtitle => 'Effects, ambience and volume levels';

  @override
  String get settingsSoundEnabled => 'Sounds';

  @override
  String get settingsSoundEnabledHint =>
      'One switch for every sound in the app';

  @override
  String get settingsHaptics => 'Haptics';

  @override
  String get settingsHapticsHint => 'A light pulse with every sound';

  @override
  String get settingsAmbient => 'Cosmic ambience';

  @override
  String get settingsAmbientHint => 'A calm bed of sound beneath the interface';

  @override
  String get settingsVolumes => 'Volume levels';

  @override
  String get settingsSoundProfile => 'Sound character';

  @override
  String get settingsSoundProfileHint => 'Changes with the theme';

  @override
  String get settingsMotion => 'Motion';

  @override
  String get settingsMotionSystem => 'Device';

  @override
  String get settingsMotionReduced => 'Reduced';

  @override
  String get settingsMotionFull => 'Full';

  @override
  String get settingsMotionHint =>
      'Reduced swaps cinematic transitions for a calm fade';

  @override
  String get settingsPower => 'Power mode';

  @override
  String get settingsPowerAuto => 'Automatic';

  @override
  String get settingsPowerSaver => 'Battery saver';

  @override
  String get settingsPowerHint =>
      'Battery saver stills the cosmic backdrop and lightens rendering';

  @override
  String get settingsData => 'Data';

  @override
  String get settingsImport => 'Import from the prototype';

  @override
  String get settingsImportHint =>
      'A JSON file exported from the first version';

  @override
  String get settingsPrivacyNote =>
      'Your data is encrypted and never leaves your device.';

  @override
  String get settingsAbout => 'About Madar';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsFonts => 'Fonts';

  @override
  String get settingsFontsBody =>
      'Open fonts under the SIL Open Font License 1.1';

  @override
  String get settingsFontRoleUi => 'Interface';

  @override
  String get settingsFontRoleDisplay => 'Headings';

  @override
  String get settingsFontRoleQuran => 'Quran text';

  @override
  String get settingsFontRoleNaskh => 'Classical text';

  @override
  String get settingsFontPlex => 'IBM Plex Sans Arabic';

  @override
  String get settingsFontReemKufi => 'Reem Kufi';

  @override
  String get settingsFontAmiriQuran => 'Amiri Quran';

  @override
  String get settingsFontAmiri => 'Amiri';

  @override
  String get settingsLicense => 'Licence';

  @override
  String get settingsLicenseUnavailable => 'Couldn\'t load the licence text';

  @override
  String get settingsGalleryHint => 'Every interface component in one place';

  @override
  String get settingsDeveloper => 'Developer';

  @override
  String settingsOpen(String name) {
    return 'Open $name';
  }

  @override
  String get onboardingWelcomeTagline => 'Your day orbits the five prayers';

  @override
  String get onboardingWelcomeBody =>
      'Tasks, health, money, family — each has its own orbit, and prayer is the centre that holds them together and sets their rhythm.';

  @override
  String get onboardingStyleTitle => 'Your language and look';

  @override
  String get onboardingStyleBody =>
      'Try them and watch everything change live — you can adjust this anytime in Settings.';

  @override
  String get onboardingStartTitle => 'Where shall we begin?';

  @override
  String get onboardingStartBody =>
      'Your data is encrypted and stays on your device.';

  @override
  String get onboardingStartFresh => 'Start fresh';

  @override
  String get onboardingStartFreshBody =>
      'A clear orbit, waiting for your first step';

  @override
  String get onboardingImport => 'Import my data';

  @override
  String get onboardingImportBody =>
      'From a JSON file exported by the prototype';

  @override
  String get onboardingBegin => 'Let\'s begin';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String onboardingStep(String current, String total) {
    return 'Step $current of $total';
  }
}
