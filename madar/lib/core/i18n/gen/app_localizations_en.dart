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
  String get commonFactSeparator => ' · ';

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
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'Keep it to $max characters or fewer',
      one: 'Keep it to one character',
    );
    return '$_temp0';
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
  String interactionFieldIcon(int index) {
    return 'Icon $index';
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
  String get settingsThemeLightMode => 'Light mode';

  @override
  String get settingsThemeDarkMode => 'Dark mode';

  @override
  String get settingsAccent => 'Accent colour';

  @override
  String get settingsAccentDefault => 'Theme colour';

  @override
  String get settingsAccentCustom => 'Custom colour';

  @override
  String get settingsAccentCustomHint =>
      'Slide along the spectrum for any colour; its brightness adapts so it stays readable in every theme.';

  @override
  String settingsAccentPlanet(String planet) {
    return '$planet colour';
  }

  @override
  String settingsAccentHueValue(String degrees) {
    return 'Hue $degrees°';
  }

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
  String get settingsSectionMotionPower => 'Motion & power';

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
  String settingsFontsBody(String version) {
    return 'Open fonts under the SIL Open Font License $version';
  }

  @override
  String get settingsLicenses => 'Open-source licences';

  @override
  String get settingsLicensesBody =>
      'SQLCipher, OpenSSL, Flutter and every package Madar is built with';

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

  @override
  String get settingsFaithSection => 'Faith';

  @override
  String get settingsFaithSectionHint => 'Prayer, the Quran and reminders';

  @override
  String get settingsPrayerTimes => 'Prayer times & calculation';

  @override
  String get settingsAdhan => 'Adhan & notifications';

  @override
  String get settingsAdhkarReminders => 'Adhkar reminders';

  @override
  String get settingsAdhkarMorning => 'Morning adhkar after Fajr';

  @override
  String get settingsAdhkarEvening => 'Evening adhkar after Asr';

  @override
  String settingsAdhkarAfter(String offset) {
    return '$offset after the adhan';
  }

  @override
  String get settingsAdhkarOff => 'No reminder';

  @override
  String get settingsSecuritySection => 'Privacy & security';

  @override
  String get settingsAppLock => 'App lock';

  @override
  String get settingsAppLockOff => 'Off – set a PIN to protect Madar';

  @override
  String get settingsAppLockOn => 'On, with your PIN';

  @override
  String get settingsAppLockOnBio => 'On, with fingerprint and PIN';

  @override
  String get settingsSecurityNote =>
      'The lock hides what is on screen whenever you step away; your data is always encrypted on your device, locked or not.';

  @override
  String get settingsCredits => 'Fonts & sources';

  @override
  String get settingsCreditsBody =>
      'Open fonts, and the sources of the Quran, hadith, adhkar, cities and tones';

  @override
  String get settingsCreditsContent => 'Content and its sources';

  @override
  String get settingsCreditsContentBody =>
      'Every text, dataset and sound in Madar is openly licensed or its own work – here are the full sources.';

  @override
  String get settingsCreditAdhkar => 'Adhkar – Hisn al-Muslim';

  @override
  String get settingsCreditAdhkarRole =>
      'Open datasets (MIT), the Quran text from quran-api';

  @override
  String get settingsCreditCities => 'City list';

  @override
  String get settingsCreditCitiesRole =>
      'Natural Earth, GeoNames, IANA and Unicode CLDR';

  @override
  String get settingsCreditAdhan => 'Adhan tones';

  @override
  String get settingsCreditAdhanRole => 'Madar’s own – no recordings bundled';

  @override
  String get onboardingLocationTitle => 'Where do you pray?';

  @override
  String get onboardingLocationBody =>
      'Prayer times are calculated on your device from your location, offline. Pick your city, or use your approximate location once.';

  @override
  String get onboardingLocationSet => 'Choose your location';

  @override
  String get onboardingLocationChange => 'Change location';

  @override
  String onboardingLocationFor(String place) {
    return 'Your times are for $place';
  }

  @override
  String get onboardingAdhanTitle => 'The adhan, on time';

  @override
  String get onboardingAdhanBody =>
      'For the adhan to sound at its minute, even with the phone locked, Madar needs a few Android permissions. Grant them now or later in Settings.';

  @override
  String get onboardingLockTitle => 'Protect Madar';

  @override
  String get onboardingLockBody =>
      'A lock with a PIN and your fingerprint closes Madar whenever you step away. No account, no server – the PIN stays on your device.';

  @override
  String get onboardingLockSet => 'Set a PIN';

  @override
  String get onboardingLockOn => 'The lock is on, with your PIN';

  @override
  String get onboardingLockOnBio => 'The lock is on, with fingerprint and PIN';

  @override
  String get onboardingOptional =>
      'Optional – you can set this later in Settings';

  @override
  String homeDateWithHijri(String gregorian, String hijri) {
    return '$gregorian · $hijri';
  }

  @override
  String get homeAllTimes => 'All times';

  @override
  String get settingsQuran => 'Quran reading';

  @override
  String get settingsQuranTajweedOn => 'with tajweed colours';

  @override
  String get settingsQuranTajweedOff => 'without tajweed colours';

  @override
  String get settingsQuranReading => 'Reading';

  @override
  String get settingsQuranPreviewLabel => 'Text size preview';

  @override
  String settingsQuranDownloaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Downloaded for $count suras',
      one: 'Downloaded for 1 sura',
      zero: 'Nothing downloaded yet',
    );
    return '$_temp0';
  }

  @override
  String get settingsQuranDownloadNote =>
      'The translation and the Quran.com tajweed download one sura at a time from the reader\'s settings – Madar goes online only when you ask.';

  @override
  String get settingsQuranSourceNote =>
      'The Uthmani text (Hafs) is Tanzil\'s, bundled with the app and fully offline.';

  @override
  String get settingsRecitation => 'Recitation & reciters';

  @override
  String get settingsReminders => 'Reminders';

  @override
  String settingsRemindersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reminders on',
      one: '1 reminder on',
      zero: 'No reminders on',
    );
    return '$_temp0';
  }

  @override
  String get settingsWirdReminders => 'Wird reminders';

  @override
  String get settingsWirdNoPlans =>
      'No wird plan yet. Start one, and its reminder comes after the prayer you choose.';

  @override
  String get settingsWirdOpen => 'Wird plans';

  @override
  String get settingsWirdNoWindow =>
      'Pick a prayer for this plan to be reminded';

  @override
  String get settingsWirdPaused => 'Plan paused – no reminder';

  @override
  String get settingsWirdEditPlan => 'Edit the plan';

  @override
  String get settingsWirdReminderNote =>
      'The reminder comes after the plan\'s prayer – not on a day you have already read your portion.';

  @override
  String get settingsCreditQuran => 'The Quran – Tanzil';

  @override
  String get settingsCreditQuranRole =>
      'Uthmani text and metadata, tajweed annotations – Creative Commons';

  @override
  String get settingsCreditHadith => 'An-Nawawi\'s Forty';

  @override
  String get settingsCreditHadithRole =>
      'Arabic text from hadith-api, public domain';

  @override
  String get settingsCreditRecitation => 'Recitations – EveryAyah';

  @override
  String get settingsCreditRecitationRole =>
      'Streamed or downloaded only when you ask – no audio bundled';

  @override
  String get settingsCreditQibla => 'Qibla compass – World Magnetic Model';

  @override
  String get settingsCreditQiblaRole =>
      'The WMM by NOAA and BGS, public domain';

  @override
  String orbitReasonPersonOverdue(String name, int days, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$n days overdue',
      one: '1 day overdue',
    );
    return '$name — $_temp0';
  }

  @override
  String orbitReasonDosesPastDue(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n doses past due',
      one: '1 dose past due',
    );
    return '$_temp0';
  }

  @override
  String orbitReasonDosesPastDueNamed(String name, int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n doses past due',
      one: '1 dose past due',
    );
    return '$name — $_temp0';
  }

  @override
  String orbitReasonPrayersMissed(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n prayers not logged this week',
      one: '1 prayer not logged this week',
    );
    return '$_temp0';
  }

  @override
  String orbitReasonTasksOverdue(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n tasks overdue',
      one: '1 task overdue',
    );
    return '$_temp0';
  }

  @override
  String orbitReasonCardsOverdue(String board, int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n cards overdue',
      one: '1 card overdue',
    );
    return '$board — $_temp0';
  }

  @override
  String orbitReasonBudgetOverspent(String item, String percent) {
    return '$item — $percent over budget';
  }

  @override
  String orbitReasonObligationOverdue(String name, int days, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$n days overdue',
      one: '1 day overdue',
    );
    return '$name — $_temp0';
  }

  @override
  String orbitReasonDebtOverdue(String person, int days, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$n days overdue',
      one: '1 day overdue',
    );
    return 'Debt to $person — $_temp0';
  }

  @override
  String orbitReasonGoalBehind(String name, String percent) {
    return '$name — $percent of the expected progress';
  }

  @override
  String orbitReasonGoalQuiet(String name, int days, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'no progress for $n days',
      one: 'no progress for a day',
    );
    return '$name — $_temp0';
  }

  @override
  String orbitReasonWorkoutsMissed(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n workouts missed this week',
      one: '1 workout missed this week',
    );
    return '$_temp0';
  }

  @override
  String orbitReasonWaterLow(String percent) {
    return 'Water — only $percent of today\'s goal';
  }

  @override
  String orbitReasonDocumentExpiring(String name, int days, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'expires in $n days',
      one: 'expires in a day',
    );
    return '$name — $_temp0';
  }

  @override
  String orbitReasonDocumentExpiresToday(String name) {
    return '$name — expires today';
  }

  @override
  String orbitReasonDocumentExpired(String name) {
    return '$name — expired';
  }

  @override
  String orbitReasonTripUnpacked(
    String destination,
    int days,
    String n,
    String percent,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'leaving in $n days',
      one: 'leaving tomorrow',
      zero: 'leaving today',
    );
    return '$destination — $_temp0, only $percent packed';
  }

  @override
  String orbitReasonModuleStale(String name, int days, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'no entry for $n days',
      one: 'no entry for a day',
    );
    return '$name — $_temp0';
  }

  @override
  String orbitReasonNoActivity(int days, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'No activity for $n days',
      one: 'No activity for a day',
    );
    return '$_temp0';
  }

  @override
  String orbitReasonHabitsSlipping(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n habits slipping this week',
      one: '1 habit slipping this week',
    );
    return '$_temp0';
  }

  @override
  String orbitReasonHabitSlipping(String name, int days, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'not done for $n days',
      one: 'not done for a day',
    );
    return '$name — $_temp0';
  }

  @override
  String orbitReasonProjectItemsOverdue(String project, int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n items overdue',
      one: '1 item overdue',
    );
    return '$project — $_temp0';
  }

  @override
  String orbitReasonJarBehind(String name, String percent) {
    return '$name — $percent of the expected savings';
  }

  @override
  String orbitReasonSourceStale(String source, int days, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'nothing logged for $n days',
      one: 'nothing logged for a day',
    );
    return '$source — $_temp0';
  }

  @override
  String get orbitSourcePrayers => 'Prayers';

  @override
  String get orbitSourceAdhkar => 'Adhkar';

  @override
  String get orbitSourceQuran => 'Quran';

  @override
  String get orbitSourceDoses => 'Medication doses';

  @override
  String get orbitSourceHabits => 'Habits';

  @override
  String get orbitSourceMood => 'Mood';

  @override
  String get orbitSourcePain => 'Pain';

  @override
  String get orbitSourceAppointments => 'Appointments';

  @override
  String get orbitSourceContacts => 'Keeping in touch';

  @override
  String get orbitSourceTasks => 'Tasks';

  @override
  String get orbitSourceCards => 'Work boards';

  @override
  String get orbitSourceProjects => 'Projects';

  @override
  String get orbitSourceBudget => 'Budget';

  @override
  String get orbitSourceTransactions => 'Spending log';

  @override
  String get orbitSourceJars => 'Savings jars';

  @override
  String get orbitSourceObligations => 'Bills & obligations';

  @override
  String get orbitSourceDebts => 'Debts';

  @override
  String get orbitSourceGoals => 'Learning goals';

  @override
  String get orbitSourceWorkouts => 'Workouts';

  @override
  String get orbitSourceFasting => 'Fasting';

  @override
  String get orbitSourceWater => 'Water';

  @override
  String get orbitSourceDocuments => 'Travel documents';

  @override
  String get orbitSourceTrips => 'Trips';

  @override
  String get orbitSourceActivity => 'Logged activity';

  @override
  String get orbitArchetypeFaith => 'Engraved gold dome';

  @override
  String get orbitArchetypeOcean => 'Living ocean';

  @override
  String get orbitArchetypeTerracotta => 'Warm terracotta';

  @override
  String get orbitArchetypeIndustrial => 'Industrial world';

  @override
  String get orbitArchetypeCrystal => 'Crystal with gold veins';

  @override
  String get orbitArchetypeVerdant => 'Verdant world';

  @override
  String get orbitArchetypeVolcanic => 'Volcanic world';

  @override
  String get orbitArchetypeGasGiant => 'Ringed gas giant';

  @override
  String get orbitArchetypeIce => 'Ice world';

  @override
  String get orbitArchetypeDesert => 'Desert world';

  @override
  String get orbitStateThriving => 'Thriving';

  @override
  String get orbitStateSteady => 'Steady';

  @override
  String get orbitStateNeglected => 'Needs care';

  @override
  String get orbitStateDormant => 'Quiet, no data yet';

  @override
  String orbitPlanetSemantics(String name, String state, String percent) {
    return '$name, $state, balance $percent';
  }

  @override
  String orbitBalanceSemantics(String percent) {
    return 'Life balance $percent';
  }

  @override
  String orbitMoonsMore(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$n more moons',
      one: '+1 more moon',
    );
    return '$_temp0';
  }

  @override
  String orbitMoonSemantics(String name, String planet) {
    return '$name, a moon of $planet';
  }

  @override
  String get orbitNewPlanetName => 'New planet';

  @override
  String get orbitBuiltInCannotDelete =>
      'Built-in planets can be hidden, not deleted';

  @override
  String get orbitPlanetNeedsName => 'Give the planet a name';

  @override
  String get orbitUnknownSource => 'This data source isn\'t available';

  @override
  String get orbitPlanetGone => 'This planet is no longer in your orbit';

  @override
  String get orbitUndoRenamed => 'Planet renamed';

  @override
  String orbitUndoRecolored(String name) {
    return '$name recoloured';
  }

  @override
  String get orbitUndoReordered => 'Planets reordered';

  @override
  String orbitUndoHidden(String name) {
    return '$name hidden';
  }

  @override
  String orbitUndoShown(String name) {
    return '$name is back in orbit';
  }

  @override
  String orbitUndoWeight(String name) {
    return '$name\'s weight changed';
  }

  @override
  String orbitUndoSources(String name) {
    return '$name\'s sources changed';
  }

  @override
  String orbitUndoStyle(String name) {
    return '$name\'s style changed';
  }

  @override
  String orbitUndoAdded(String name) {
    return '$name added to the orbit';
  }

  @override
  String orbitUndoDeleted(String name) {
    return '$name deleted';
  }

  @override
  String orbitUndoReset(String name) {
    return '$name restored to its defaults';
  }

  @override
  String astrolabeCountdown(String prayer, String time) {
    return '$prayer in $time';
  }

  @override
  String astrolabeCountdownNow(String prayer) {
    return 'Time for $prayer';
  }

  @override
  String astrolabeSemantics(
    String window,
    String countdown,
    String done,
    String total,
  ) {
    return 'Your day\'s astrolabe. $window. $countdown. $done of $total prayers done.';
  }

  @override
  String astrolabeWindowNow(String window) {
    return 'Now: $window';
  }

  @override
  String astrolabePrayerPrayed(String prayer) {
    return '$prayer: prayed';
  }

  @override
  String astrolabePrayerDue(String prayer) {
    return '$prayer: it\'s time';
  }

  @override
  String astrolabePrayerUpcoming(String prayer, String time) {
    return '$prayer: at $time';
  }

  @override
  String astrolabePrayerMissed(String prayer) {
    return '$prayer: missed';
  }

  @override
  String get astrolabeMakersMark => 'MADAR';

  @override
  String get astrolabeStarDenebKaitos => 'Deneb Kaitos';

  @override
  String get astrolabeStarMenkar => 'Menkar';

  @override
  String get astrolabeStarAldebaran => 'Aldebaran';

  @override
  String get astrolabeStarRigel => 'Rigel';

  @override
  String get astrolabeStarBetelgeuse => 'Betelgeuse';

  @override
  String get astrolabeStarSirius => 'Sirius';

  @override
  String get astrolabeStarProcyon => 'Procyon';

  @override
  String get astrolabeStarAlphard => 'Alphard';

  @override
  String get astrolabeStarRegulus => 'Regulus';

  @override
  String get astrolabeStarDenebola => 'Denebola';

  @override
  String get astrolabeStarSpica => 'Spica';

  @override
  String get astrolabeStarArcturus => 'Arcturus';

  @override
  String get astrolabeStarUnukalhai => 'Unukalhai';

  @override
  String get astrolabeStarRasAlhague => 'Rasalhague';

  @override
  String get astrolabeStarAltair => 'Altair';

  @override
  String get astrolabeStarDenebAlgedi => 'Deneb Algedi';

  @override
  String get astrolabeStarMarkab => 'Markab';

  @override
  String get astrolabeZodiacAries => 'Aries';

  @override
  String get astrolabeZodiacTaurus => 'Taurus';

  @override
  String get astrolabeZodiacGemini => 'Gemini';

  @override
  String get astrolabeZodiacCancer => 'Cancer';

  @override
  String get astrolabeZodiacLeo => 'Leo';

  @override
  String get astrolabeZodiacVirgo => 'Virgo';

  @override
  String get astrolabeZodiacLibra => 'Libra';

  @override
  String get astrolabeZodiacScorpio => 'Scorpio';

  @override
  String get astrolabeZodiacSagittarius => 'Sagittarius';

  @override
  String get astrolabeZodiacCapricorn => 'Capricorn';

  @override
  String get astrolabeZodiacAquarius => 'Aquarius';

  @override
  String get astrolabeZodiacPisces => 'Pisces';

  @override
  String astrolabeCountdownUntil(String prayer) {
    return 'to $prayer';
  }

  @override
  String get astrolabeCountdownNowBand => 'it is time';

  @override
  String skySemantics(String sky, String moon) {
    return 'Sky now: $sky. $moon';
  }

  @override
  String get skyMoodNight => 'night';

  @override
  String get skyMoodDawn => 'dawn';

  @override
  String get skyMoodSunrise => 'sunrise';

  @override
  String get skyMoodDay => 'clear day';

  @override
  String get skyMoodGoldenHour => 'golden hour';

  @override
  String get skyMoodSunset => 'sunset';

  @override
  String get skyMoodDusk => 'dusk';

  @override
  String get skyMoonBelow => 'The moon is below the horizon';

  @override
  String skyMoonPhase(String phase, String percent) {
    return 'Moon: $phase, $percent lit';
  }

  @override
  String get skyMoonNew => 'new moon';

  @override
  String get skyMoonWaxingCrescent => 'waxing crescent';

  @override
  String get skyMoonFirstQuarter => 'first quarter';

  @override
  String get skyMoonWaxingGibbous => 'waxing gibbous';

  @override
  String get skyMoonFull => 'full moon';

  @override
  String get skyMoonWaningGibbous => 'waning gibbous';

  @override
  String get skyMoonLastQuarter => 'last quarter';

  @override
  String get skyMoonWaningCrescent => 'waning crescent';

  @override
  String get skyStarNames => 'Star names';

  @override
  String get skyStarNamesHint =>
      'Engraves the traditional Arabic names of the brightest stars in the night sky';

  @override
  String planetsSystemSemantics(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Your life\'s orbit: $n worlds circling your star',
      one: 'Your life\'s orbit: 1 world circling your star',
      zero: 'Your life\'s orbit, no worlds shown',
    );
    return '$_temp0';
  }

  @override
  String get planetsOpenHint => 'Fly into this world';

  @override
  String get planetsCustomizeHint => 'Customise this world';

  @override
  String get planetsMoonOpenHint => 'Open';

  @override
  String planetsMoonsCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n moons',
      one: '1 moon',
      zero: 'no moons',
    );
    return '$_temp0';
  }

  @override
  String get orbitUiSceneHint =>
      'Drag to turn the orbit, pinch to zoom into a world';

  @override
  String get orbitUiRecenter => 'Back to the whole orbit';

  @override
  String get orbitUiRadarClear =>
      'All your worlds are in balance — nothing needs you right now';

  @override
  String get orbitUiRadarWaiting =>
      'The radar wakes up once you log your first activities';

  @override
  String orbitUiRadarEntrySemantics(String planet, String reason) {
    return '$planet: $reason';
  }

  @override
  String get orbitUiRadarOpenHint => 'Fly to this world';

  @override
  String get orbitUiBalanceLabel => 'Balance';

  @override
  String orbitUiPlanetWeight(String weight) {
    return 'Weight in your balance ×$weight';
  }

  @override
  String get orbitUiPlanetNotCounted => 'Not counted in your balance';

  @override
  String get orbitUiReasonsTitle => 'What needs your care';

  @override
  String get orbitUiReasonsNone => 'Nothing is overdue here — well done';

  @override
  String get orbitUiReasonsDormant =>
      'This world is calm, waiting for your first entries';

  @override
  String get orbitUiSourcesTitle => 'What feeds this balance';

  @override
  String get orbitUiMoonsTitle => 'Moons';

  @override
  String get orbitUiMoonsNone => 'No moons circle this world yet';

  @override
  String get orbitUiMoonKindPerson => 'Person';

  @override
  String get orbitUiMoonKindWallet => 'Wallet';

  @override
  String get orbitUiMoonKindBoard => 'Board';

  @override
  String get orbitUiMoonKindTrip => 'Trip';

  @override
  String get orbitUiMoonKindModule => 'Module';

  @override
  String orbitUiMoonFreshness(String percent) {
    return 'Freshness $percent';
  }

  @override
  String get orbitUiMoonSelected => 'The moon you picked';

  @override
  String get orbitUiCustomize => 'Customise';

  @override
  String orbitUiCustomizeTitle(String planet) {
    return 'Customise $planet';
  }

  @override
  String get orbitUiCustomizeSubtitle => 'Every change can be undone';

  @override
  String get orbitUiEditLook => 'Name and look';

  @override
  String get orbitUiEditWeight => 'Weight in the balance';

  @override
  String get orbitUiEditSources => 'Data sources';

  @override
  String get orbitUiMoveOrbit => 'Move its orbit';

  @override
  String get orbitUiHide => 'Hide from the orbit';

  @override
  String get orbitUiReset => 'Restore the original';

  @override
  String get orbitUiDelete => 'Delete this world';

  @override
  String get orbitUiAddPlanet => 'Add a new world';

  @override
  String get orbitUiHiddenWorlds => 'Hidden worlds';

  @override
  String get orbitUiFieldName => 'Name';

  @override
  String get orbitUiFieldColor => 'Colour';

  @override
  String get orbitUiFieldStyle => 'World style';

  @override
  String get orbitUiFieldWeight => 'Weight';

  @override
  String get orbitUiWeightNone => 'Not counted';

  @override
  String get orbitUiWeightNormal => 'Normal';

  @override
  String get orbitUiWeightMost => 'Most important';

  @override
  String get orbitUiSourcesHint => 'Slide a source to zero to switch it off';

  @override
  String get orbitUiSourceOff => 'Off';

  @override
  String get orbitUiMoveTitle => 'Orbit position';

  @override
  String get orbitUiMoveSubtitle => 'Closest to your star first';

  @override
  String orbitUiMoveBefore(String planet) {
    return 'Before $planet';
  }

  @override
  String get orbitUiMoveLast => 'Outermost orbit';

  @override
  String orbitUiOrbitNumber(String n) {
    return 'Orbit $n';
  }

  @override
  String orbitUiPrayerAt(String time) {
    return 'At $time';
  }

  @override
  String get orbitUiPrayerPrayed => 'Prayed';

  @override
  String get orbitUiPrayerLate => 'Prayed late';

  @override
  String get orbitUiPrayerMissed => 'Missed it';

  @override
  String get orbitUiPrayerClear => 'Clear the log';

  @override
  String get orbitUiPrayerNotYet => 'Its time hasn\'t come yet';

  @override
  String orbitUiPrayerLogged(String prayer) {
    return '$prayer logged';
  }

  @override
  String orbitUiPrayerCleared(String prayer) {
    return '$prayer log cleared';
  }

  @override
  String get orbitUiPrayerHint => 'Log this prayer';

  @override
  String get orbitUiPlanetMissing => 'This world is no longer in your orbit';

  @override
  String get orbitUiBackToOrbit => 'Back to the orbit';

  @override
  String orbitUiInDuration(String duration) {
    return 'in $duration';
  }

  @override
  String orbitUiPrayerPrayedAt(String time) {
    return 'Prayed at $time';
  }

  @override
  String orbitUiPrayerLateAt(String time) {
    return 'Prayed late at $time';
  }

  @override
  String orbitUiMoonOf(String kind, String planet) {
    return '$kind in $planet';
  }

  @override
  String get orbitUiMoonInTouch => 'In touch today';

  @override
  String orbitUiMoonInTouchLogged(String name) {
    return 'Logged: in touch with $name';
  }

  @override
  String get orbitUiMoonRename => 'Rename';

  @override
  String get orbitUiMoonRenamed => 'Renamed';

  @override
  String orbitUiMoonLastContact(String when) {
    return 'Last in touch: $when';
  }

  @override
  String orbitUiMoonTripStarts(String date) {
    return 'Starts $date';
  }

  @override
  String get orbitUiMoonNever => 'Not logged yet';

  @override
  String orbitUiListSeparator(String a, String b) {
    return '$a · $b';
  }

  @override
  String orbitUiFraction(String done, String total) {
    return '$done/$total';
  }

  @override
  String get orbitUiPrayerDone => 'Prayed';

  @override
  String get orbitUiPrayerLateDone => 'Prayed late';

  @override
  String get orbitUiPanelExpand =>
      'Show this window\'s tasks and the Neglect Radar';

  @override
  String get orbitUiPanelCollapse => 'Fold the panel and show the orbit';

  @override
  String get orbitUiRadarLineJoin => ' — ';

  @override
  String get orbitUiTodayPrayersTitle => 'Today\'s prayers';

  @override
  String orbitUiPrayersProgress(String done, String total) {
    return '$done of $total prayed';
  }

  @override
  String get orbitUiPrayerStatusPrayed => 'Prayed';

  @override
  String get orbitUiPrayerStatusDue => 'Due now';

  @override
  String get orbitUiPrayerStatusMissed => 'Missed';

  @override
  String get orbitUiPrayerStatusUpcoming => 'Upcoming';

  @override
  String get orbitUiWirdTitle => 'Wird and adhkar';

  @override
  String get orbitUiWorldTasksTitle => 'Today on this world';

  @override
  String get orbitUiWorldTasksNone => 'Nothing planned for this world today';

  @override
  String orbitUiSourceSemantics(String source, String value) {
    return '$source: $value';
  }

  @override
  String get orbitUiMoonWaiting => 'Waiting on you';

  @override
  String get lockScreenSubtitle => 'Your data is encrypted on this phone';

  @override
  String get lockHoldHint => 'Press and hold the astrolabe to unlock';

  @override
  String get lockHoldingHint =>
      'Keep holding… the astrolabe is coming together';

  @override
  String get lockReadingHint => 'Touch the fingerprint sensor';

  @override
  String get lockReleasedEarly => 'Hold until the astrolabe is complete';

  @override
  String get lockWelcome => 'Welcome back';

  @override
  String get lockPinHint => 'Enter your Madar PIN';

  @override
  String get lockPinChecking => 'Checking…';

  @override
  String lockPinWrong(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Wrong PIN · $n tries left before a pause',
      one: 'Wrong PIN · 1 try left before a pause',
      zero: 'Wrong PIN',
    );
    return '$_temp0';
  }

  @override
  String lockLockedOut(String time) {
    return 'Too many attempts. Try again in $time';
  }

  @override
  String lockSeconds(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n seconds',
      one: '1 second',
    );
    return '$_temp0';
  }

  @override
  String get lockUsePin => 'Use PIN';

  @override
  String get lockUseFingerprint => 'Use fingerprint';

  @override
  String get lockForgotPin => 'Forgot PIN?';

  @override
  String get lockPromptTitle => 'Unlock Madar';

  @override
  String get lockPromptHint => 'Use your fingerprint';

  @override
  String get lockPromptReason => 'Confirm it\'s you to open your data';

  @override
  String get lockPromptSettingsReason =>
      'Confirm it\'s you to change the lock settings';

  @override
  String get lockPromptCancel => 'Use PIN';

  @override
  String get lockPromptCancelPlain => 'Cancel';

  @override
  String get lockStorageError => 'Couldn\'t read this phone\'s secure vault.';

  @override
  String get lockRetry => 'Try again';

  @override
  String get lockAstrolabeSemantics =>
      'Astrolabe. Press and hold to unlock with your fingerprint';

  @override
  String get lockAstrolabeAction => 'Unlock with fingerprint';

  @override
  String lockPinProgress(String count, String total) {
    return '$count of $total digits entered';
  }

  @override
  String lockPinProgressOpen(String count) {
    return '$count digits entered';
  }

  @override
  String get lockKeyDelete => 'Delete';

  @override
  String get lockKeyFingerprint => 'Fingerprint';

  @override
  String get lockKeyDone => 'Done';

  @override
  String get lockShieldSemantics => 'Madar is hidden until you return';

  @override
  String get lockForgotTitle => 'Forgot your PIN?';

  @override
  String get lockForgotBody =>
      'Madar has no account and no server: your data is encrypted and kept on this phone alone, so the PIN can\'t be recovered or reset remotely.';

  @override
  String get lockForgotBiometric =>
      'Confirm with your fingerprint, then choose a new PIN.';

  @override
  String get lockForgotBiometricAction => 'Confirm with fingerprint';

  @override
  String get lockForgotNoBiometric =>
      'Without the PIN, Madar stays locked. If you can\'t recall it, the only way out is to clear Madar\'s data in the phone\'s settings (Apps → Madar → Storage → Clear data) and start fresh; anything not in a backup will be lost.';

  @override
  String get lockForgotBack => 'Back';

  @override
  String get lockNewPinTitle => 'Choose a new PIN';

  @override
  String get lockPinCreateTitle => 'Choose a PIN for Madar';

  @override
  String lockPinCreateBody(String min, String max) {
    return '$min to $max digits. It opens Madar whenever your fingerprint can\'t.';
  }

  @override
  String get lockPinConfirmTitle => 'Confirm your PIN';

  @override
  String get lockPinConfirmBody => 'Enter it once more to be sure.';

  @override
  String get lockPinMismatch => 'Those PINs don\'t match. Let\'s start again.';

  @override
  String get lockPinWeak => 'That PIN is easy to guess. Consider another.';

  @override
  String get lockPinCurrentTitle => 'Enter your current PIN';

  @override
  String get lockPinSaved => 'PIN saved. Madar is now locked for you alone.';

  @override
  String get lockPinChanged => 'PIN changed';

  @override
  String get lockConfirmTitle => 'Confirm it\'s you';

  @override
  String get lockConfirmBody => 'Enter your Madar PIN to continue.';

  @override
  String get lockBioOfferTitle => 'Unlock with your fingerprint too?';

  @override
  String get lockBioOfferBody =>
      'Quicker every time, and your PIN is always there as a fallback.';

  @override
  String get lockBioOfferEnable => 'Use fingerprint';

  @override
  String get lockBioOfferSkip => 'Not now';

  @override
  String get lockSettingsTitle => 'Security';

  @override
  String get lockSettingsLock => 'App lock';

  @override
  String get lockSettingsLockOn => 'Asked on every launch and after time away';

  @override
  String get lockSettingsLockOff =>
      'Protect your data with a PIN and fingerprint';

  @override
  String get lockSettingsBiometric => 'Fingerprint unlock';

  @override
  String get lockSettingsBiometricHint => 'Your PIN always stays as a fallback';

  @override
  String get lockSettingsBiometricNotEnrolled =>
      'Add a fingerprint in the phone\'s settings first';

  @override
  String get lockSettingsBiometricUnavailable =>
      'The fingerprint sensor isn\'t available right now';

  @override
  String get lockSettingsChangePin => 'Change PIN';

  @override
  String lockSettingsChangePinHint(String min, String max) {
    return 'A PIN of $min to $max digits';
  }

  @override
  String get lockSettingsLockAfter => 'Lock after leaving the app';

  @override
  String get lockSettingsLockAfterHint => 'And always on a fresh launch';

  @override
  String get lockAfterImmediately => 'Immediately';

  @override
  String lockAfterMinutes(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String get lockSettingsRemovePin => 'Remove PIN';

  @override
  String get lockSettingsRemovePinHint =>
      'Turns off the app lock and fingerprint unlock';

  @override
  String get lockRemoveTitle => 'Remove your PIN?';

  @override
  String get lockRemoveBody =>
      'Madar will open without a lock until you choose a new PIN.';

  @override
  String get lockRemoveConfirm => 'Remove PIN';

  @override
  String get lockSettingsNote =>
      'No account, no server: your data is encrypted on this phone alone and the PIN can\'t be recovered remotely, so keep it safe.';

  @override
  String get lockSettingsSaveFailed =>
      'Couldn\'t save to the secure vault. Please try again.';

  @override
  String get lockBioLockedOut =>
      'Fingerprint is paused after too many tries. Use your PIN.';

  @override
  String get lockBioLockedOutPermanently =>
      'Fingerprint is locked until you unlock the phone with its screen lock. Use your Madar PIN for now.';

  @override
  String get lockBioNotEnrolled =>
      'No fingerprint is enrolled on this phone. Use your PIN.';

  @override
  String get lockBioNoHardware =>
      'This phone has no fingerprint sensor. Use your PIN.';

  @override
  String get lockBioUnavailable =>
      'The fingerprint sensor isn\'t available right now. Use your PIN.';

  @override
  String get lockBioError =>
      'Couldn\'t verify your fingerprint. Try again or use your PIN.';

  @override
  String get lockBioInterrupted =>
      'Verification was interrupted. Press and hold to try again.';

  @override
  String get ptTitle => 'Prayer times';

  @override
  String get ptSettingsTitle => 'Prayer time settings';

  @override
  String get ptOpenSettings => 'Prayer time settings';

  @override
  String get ptFajr => 'Fajr';

  @override
  String get ptSunrise => 'Sunrise';

  @override
  String get ptDuha => 'Duha';

  @override
  String get ptDhuhr => 'Dhuhr';

  @override
  String get ptJumuah => 'Jumu’ah';

  @override
  String get ptAsr => 'Asr';

  @override
  String get ptMaghrib => 'Maghrib';

  @override
  String get ptIsha => 'Isha';

  @override
  String get ptMidnight => 'Midnight';

  @override
  String get ptLastThird => 'Last third';

  @override
  String get ptSunriseHint => 'Fajr time ends';

  @override
  String get ptDuhaHint => 'A quarter hour after sunrise';

  @override
  String get ptMidnightHint => 'Halfway from Maghrib to Fajr';

  @override
  String get ptLastThirdHint => 'The time for Qiyam';

  @override
  String get ptNightSection => 'The night & Qiyam';

  @override
  String get ptNow => 'Now';

  @override
  String get ptNextPrayer => 'Next prayer';

  @override
  String ptNextIn(String prayer) {
    return '$prayer in';
  }

  @override
  String ptAtTime(String time) {
    return 'at $time';
  }

  @override
  String ptItsTime(String prayer) {
    return 'It\'s time for $prayer';
  }

  @override
  String ptCurrentWindow(String window) {
    return 'Now: $window';
  }

  @override
  String ptCountdownSemantics(String prayer, String duration) {
    return '$prayer in $duration';
  }

  @override
  String get ptToday => 'Today';

  @override
  String get ptTomorrow => 'Tomorrow';

  @override
  String get ptYesterday => 'Yesterday';

  @override
  String get ptTonight => 'Tonight';

  @override
  String get ptPrevDay => 'Previous day';

  @override
  String get ptNextDay => 'Next day';

  @override
  String get ptBackToToday => 'Back to today';

  @override
  String get ptViewDay => 'Day';

  @override
  String get ptViewMonth => 'Month';

  @override
  String get ptPrevMonth => 'Previous month';

  @override
  String get ptNextMonth => 'Next month';

  @override
  String get ptMonthDay => 'Day';

  @override
  String ptMonthHijriSpan(String from, String to) {
    return '$from – $to';
  }

  @override
  String get ptAm => 'AM';

  @override
  String get ptPm => 'PM';

  @override
  String ptClockHours(String hours) {
    return '$hours-hour';
  }

  @override
  String ptMinutesSigned(String minutes) {
    return '$minutes min';
  }

  @override
  String ptHijriDate(String day, String month, String year) {
    return '$day $month $year AH';
  }

  @override
  String ptHijriDayMonth(String day, String month) {
    return '$day $month';
  }

  @override
  String get ptHijriMonth1 => 'Muharram';

  @override
  String get ptHijriMonth2 => 'Safar';

  @override
  String get ptHijriMonth3 => 'Rabi’ al-Awwal';

  @override
  String get ptHijriMonth4 => 'Rabi’ al-Akhir';

  @override
  String get ptHijriMonth5 => 'Jumada al-Ula';

  @override
  String get ptHijriMonth6 => 'Jumada al-Akhirah';

  @override
  String get ptHijriMonth7 => 'Rajab';

  @override
  String get ptHijriMonth8 => 'Sha’ban';

  @override
  String get ptHijriMonth9 => 'Ramadan';

  @override
  String get ptHijriMonth10 => 'Shawwal';

  @override
  String get ptHijriMonth11 => 'Dhu al-Qa’dah';

  @override
  String get ptHijriMonth12 => 'Dhu al-Hijjah';

  @override
  String get ptLocationTitle => 'Your location';

  @override
  String get ptLocationSubtitle =>
      'Times are calculated on your device, offline';

  @override
  String ptLocationDefault(String city) {
    return '$city (default)';
  }

  @override
  String ptLocationNear(String city) {
    return 'Near $city';
  }

  @override
  String ptPlaceWithCountry(String city, String country) {
    return '$city, $country';
  }

  @override
  String get ptPinnedLocation => 'Pinned location';

  @override
  String get ptDefaultCityName => 'Amman';

  @override
  String get ptSourceGps => 'From your current location';

  @override
  String get ptSourceCity => 'Chosen city';

  @override
  String get ptSourceDefault => 'Default location – choose yours';

  @override
  String ptCoordinates(String lat, String lon) {
    return '$lat, $lon';
  }

  @override
  String ptTimeZoneLabel(String zone) {
    return 'Time zone: $zone';
  }

  @override
  String get ptTimeZoneDevice => 'Device time';

  @override
  String ptZoneOffset(String offset) {
    return 'GMT$offset';
  }

  @override
  String ptZoneDiffers(String place) {
    return 'Times in $place time';
  }

  @override
  String get ptUseCurrentLocation => 'Use my current location';

  @override
  String get ptUseCurrentLocationHint =>
      'A one-time approximate fix that stays on your device';

  @override
  String get ptChooseCity => 'Choose a city';

  @override
  String get ptChooseCityHint => 'Search in Arabic or English, offline';

  @override
  String get ptRationaleTitle => 'We need your approximate location';

  @override
  String get ptRationaleBody =>
      'To calculate prayer times precisely, Madar asks for your location once. It is stored encrypted on your device and never sent anywhere.';

  @override
  String get ptRationaleAllow => 'Allow location';

  @override
  String get ptRequesting => 'Waiting for your permission…';

  @override
  String get ptLocating => 'Finding your location…';

  @override
  String get ptDeniedTitle => 'Location permission not granted';

  @override
  String get ptDeniedBody =>
      'You can try again, or choose your city from the list.';

  @override
  String get ptTryAgain => 'Try again';

  @override
  String get ptDeniedForeverTitle => 'Location permission is off';

  @override
  String get ptDeniedForeverBody =>
      'Turn it on in the app\'s system settings, or choose your city manually.';

  @override
  String get ptOpenAppSettings => 'Open app settings';

  @override
  String get ptServiceOffTitle => 'Location services are off';

  @override
  String get ptServiceOffBody =>
      'Turn on location in the device settings and come back, or choose your city.';

  @override
  String get ptOpenLocationSettings => 'Location settings';

  @override
  String get ptUnsupportedBody =>
      'Location isn\'t available on this device. Choose your city from the list.';

  @override
  String get ptFailedTitle => 'Couldn\'t find your location';

  @override
  String get ptFailedBody =>
      'The signal may be weak. Try again in the open, or choose your city.';

  @override
  String ptLocationChanged(String place) {
    return 'Location set to $place';
  }

  @override
  String get ptCitySearchHint => 'Search for a city…';

  @override
  String get ptCitySearchEmpty => 'No city by that name';

  @override
  String get ptCitySearchEmptyHint => 'Try another name or a shorter spelling';

  @override
  String get ptCitySuggestions => 'Suggested cities';

  @override
  String get ptCityResults => 'Results';

  @override
  String get ptCitySelected => 'Selected';

  @override
  String get ptSectionLocation => 'Location';

  @override
  String get ptSectionMethod => 'Calculation method';

  @override
  String get ptSectionMethodHint =>
      'Methods differ mainly in the Fajr and Isha angles';

  @override
  String get ptSectionAsr => 'Asr';

  @override
  String get ptAsrStandard => 'Standard';

  @override
  String get ptAsrHanafi => 'Hanafi';

  @override
  String get ptAsrNote =>
      'Standard (Shafi’i, Maliki, Hanbali): Asr begins when an object\'s shadow equals its length; Hanafi: twice its length.';

  @override
  String get ptSectionHighLat => 'High latitudes';

  @override
  String get ptHighLatAuto => 'Automatic';

  @override
  String get ptHighLatMiddle => 'Middle of the night';

  @override
  String get ptHighLatSeventh => 'One-seventh of the night';

  @override
  String get ptHighLatAngle => 'Twilight angle';

  @override
  String ptHighLatNote(String degrees) {
    return 'Where twilight never ends in summer, Fajr and Isha are estimated from a portion of the night. Automatic uses one-seventh above about $degrees latitude.';
  }

  @override
  String get ptSectionAdjustments => 'Manual adjustments';

  @override
  String get ptAdjustmentsNote =>
      'Add or subtract minutes to match your mosque\'s timetable.';

  @override
  String get ptResetAdjustments => 'Reset';

  @override
  String get ptAdjustmentsReset => 'Manual adjustments reset';

  @override
  String get ptSectionHijri => 'Hijri date';

  @override
  String get ptHijriOffset => 'Hijri day adjustment';

  @override
  String get ptHijriOffsetNote =>
      'Based on the Umm al-Qura calendar; shift it by a day or two to match the moon sighting where you live.';

  @override
  String get ptHijriAtMaghrib => 'Hijri day begins at Maghrib';

  @override
  String get ptHijriAtMaghribHint =>
      'The Islamic day runs from sunset to sunset';

  @override
  String get ptSectionDisplay => 'Display';

  @override
  String get ptClockFormat => 'Clock';

  @override
  String get ptPreviewTitle => 'Today\'s times';

  @override
  String get ptPreviewHint => 'Updates with every change';

  @override
  String get ptMethodSheetTitle => 'Calculation method';

  @override
  String get ptMethodSuggested => 'Suggested for your location';

  @override
  String get ptMethodDefault => 'Default';

  @override
  String ptMethodChanged(String method) {
    return 'Method set to $method';
  }

  @override
  String get ptMethodJordan => 'Jordan – Ministry of Awqaf';

  @override
  String get ptMethodMuslimWorldLeague => 'Muslim World League';

  @override
  String get ptMethodUmmAlQura => 'Umm al-Qura – Makkah';

  @override
  String get ptMethodEgyptian => 'Egyptian General Authority of Survey';

  @override
  String get ptMethodKarachi => 'University of Islamic Sciences, Karachi';

  @override
  String get ptMethodNorthAmerica => 'ISNA – North America';

  @override
  String get ptMethodDubai => 'Dubai – UAE';

  @override
  String get ptMethodKuwait => 'Kuwait';

  @override
  String get ptMethodQatar => 'Qatar';

  @override
  String get ptMethodTurkiye => 'Türkiye – Diyanet';

  @override
  String get ptMethodSingapore => 'Singapore';

  @override
  String get ptMethodTehran => 'Institute of Geophysics, Tehran';

  @override
  String get ptMethodGulfRegion => 'Gulf region';

  @override
  String get ptMethodMoonsightingCommittee => 'Moonsighting Committee';

  @override
  String get ptMethodAlgerian => 'Algeria – Ministry of Religious Affairs';

  @override
  String get ptMethodMorocco => 'Morocco – Ministry of Habous';

  @override
  String get ptMethodTunisia => 'Tunisia – Ministry of Religious Affairs';

  @override
  String get ptMethodFrance => 'France – UOIF';

  @override
  String get ptMethodRussia => 'Russia – Spiritual Administration';

  @override
  String get ptMethodIndonesian => 'Indonesia – KEMENAG';

  @override
  String get ptMethodJafari => 'Jafari – Leva Institute, Qum';

  @override
  String get ptMethodCustom => 'Custom angles';

  @override
  String get ptMethodCustomHint => 'Set the Fajr and Isha angles yourself';

  @override
  String ptSummaryAngle(String prayer, String angle) {
    return '$prayer $angle';
  }

  @override
  String ptSummaryIshaInterval(String minutes) {
    return 'Isha $minutes min after Maghrib';
  }

  @override
  String ptSummaryRamadan(String minutes) {
    return '$minutes min in Ramadan';
  }

  @override
  String ptSummaryOffset(String prayer, String minutes) {
    return '$prayer $minutes min';
  }

  @override
  String ptSummaryMaghribAngle(String angle) {
    return 'Maghrib $angle';
  }

  @override
  String get ptCustomFajrAngle => 'Fajr angle';

  @override
  String get ptCustomIshaAngle => 'Isha angle';

  @override
  String get ptCustomIshaByInterval => 'Isha a fixed time after Maghrib';

  @override
  String get ptCustomIshaInterval => 'Time after Maghrib';

  @override
  String get ptIncrease => 'Increase';

  @override
  String get ptDecrease => 'Decrease';

  @override
  String get ptUndoSettings => 'Previous settings restored';

  @override
  String get ptAsrRule => 'When Asr begins';

  @override
  String get ptHighLatRule => 'Estimation rule';

  @override
  String get ptNoAdjustment => 'None';

  @override
  String ptDayUnit(String days) {
    return '$days d';
  }

  @override
  String ptAdjustTitle(String prayer) {
    return 'Adjust $prayer';
  }

  @override
  String get ptAdjustHint => 'Long-press any time to adjust it by minutes';

  @override
  String ptAdjustCalculated(String time) {
    return 'Calculated: $time';
  }

  @override
  String get ptAdjustDone => 'Done';

  @override
  String ptAdjusted(String prayer) {
    return '$prayer adjusted';
  }

  @override
  String get adhanSettingsTitle => 'Adhan';

  @override
  String get adhanSettingsSubtitle =>
      'The adhan on time, the muezzin and reminders';

  @override
  String adhanMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
      zero: 'now',
    );
    return '$_temp0';
  }

  @override
  String adhanMinutesShort(String minutes) {
    return '$minutes min';
  }

  @override
  String adhanSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seconds',
      one: '1 second',
      zero: 'a moment',
    );
    return '$_temp0';
  }

  @override
  String adhanNotifCallTitle(String prayer) {
    return 'It\'s time for $prayer';
  }

  @override
  String adhanNotifCallBody(String time) {
    return '$time · Come to prayer';
  }

  @override
  String adhanNotifPreTitle(String prayer, String minutes) {
    return '$prayer in $minutes';
  }

  @override
  String adhanNotifPreBody(String time) {
    return 'Get ready – the adhan is at $time';
  }

  @override
  String get adhanNotifSunriseTitle => 'The sun has risen';

  @override
  String get adhanNotifSunriseBody => 'The time for Fajr has ended';

  @override
  String adhanNotifSunriseSoonTitle(String minutes) {
    return 'Sunrise in $minutes';
  }

  @override
  String adhanNotifSunriseSoonBody(String time) {
    return 'Fajr time is ending – pray before $time';
  }

  @override
  String adhanNotifTestTitle(String prayer) {
    return 'Test: $prayer adhan';
  }

  @override
  String get adhanNotifTestBody => 'This is how the adhan will look and sound';

  @override
  String get adhanChannelGroup => 'Prayer & adhan';

  @override
  String adhanChannelCall(String sound) {
    return 'Adhan · $sound';
  }

  @override
  String get adhanChannelCallHint => 'The adhan as each prayer time begins';

  @override
  String get adhanChannelReminder => 'Before the adhan';

  @override
  String get adhanChannelSunrise => 'Sunrise';

  @override
  String get adhanToneDawn => 'Dawn light';

  @override
  String get adhanToneDawnHint =>
      'A crystal glow rising over a warm drone, like first light';

  @override
  String get adhanToneBrass => 'Astrolabe brass';

  @override
  String get adhanToneBrassHint => 'Quiet bells, like a distant tower clock';

  @override
  String get adhanToneBowl => 'Serenity';

  @override
  String get adhanToneBowlHint => 'Three strikes of a singing bowl';

  @override
  String get adhanToneChime => 'Reminder chime';

  @override
  String get adhanToneSunrise => 'Sunrise crystal';

  @override
  String get adhanToneChimeHint => 'A short glass chime';

  @override
  String get adhanSilent => 'Silent';

  @override
  String get adhanSilentHint => 'Notification and vibration, no sound';

  @override
  String get adhanScreenOverlineCall => 'It is now time for';

  @override
  String get adhanScreenOverlinePre => 'Get ready for';

  @override
  String get adhanScreenOverlineSunrise => 'Fajr time has ended';

  @override
  String get adhanScreenOverlineSunriseSoon => 'Fajr time is ending';

  @override
  String adhanScreenSunriseIn(String duration) {
    return 'Sunrise in $duration';
  }

  @override
  String get adhanScreenOverlineTest => 'Adhan test';

  @override
  String adhanScreenAdhanIn(String duration) {
    return 'Adhan in $duration';
  }

  @override
  String adhanScreenAdhanAt(String time) {
    return 'The adhan is at $time';
  }

  @override
  String get adhanScreenSoundingCall => 'The adhan is sounding';

  @override
  String get adhanScreenSoundingTone => 'The alert is sounding';

  @override
  String get adhanScreenSilent => 'Silent adhan';

  @override
  String adhanScreenSemantics(String prayer, String time) {
    return '$prayer adhan, $time';
  }

  @override
  String get adhanDuaTitle => 'Supplication after the adhan';

  @override
  String get adhanDuaMeaning =>
      'O Allah, Lord of this perfect call and of the prayer about to be established, grant Muhammad the Wasilah and virtue, and raise him to the praised station You promised him.';

  @override
  String adhanDuaSource(String number) {
    return 'Sahih al-Bukhari, $number';
  }

  @override
  String get adhanStop => 'Stop adhan';

  @override
  String get adhanPrayed => 'I prayed';

  @override
  String adhanPrayedNamed(String prayer) {
    return 'I prayed $prayer';
  }

  @override
  String get adhanPrayedDone => 'May Allah accept it';

  @override
  String get adhanPrayedFailed => 'Couldn\'t log the prayer';

  @override
  String get adhanClose => 'Close';

  @override
  String adhanSnooze(String minutes) {
    return 'Remind me in $minutes';
  }

  @override
  String adhanSnoozed(String minutes) {
    return 'I\'ll remind you in $minutes';
  }

  @override
  String get adhanNextTitle => 'Next adhan';

  @override
  String adhanNextIn(String duration) {
    return 'in $duration';
  }

  @override
  String get adhanNextNone => 'No adhan is on';

  @override
  String adhanScheduledCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count alerts scheduled',
      one: '1 alert scheduled',
      zero: 'No alerts scheduled',
    );
    return '$_temp0';
  }

  @override
  String get adhanScheduleWeek =>
      'Keeps calling for a whole week without opening Madar, and after a restart';

  @override
  String get adhanScheduleInexact =>
      'Exact alarms aren\'t allowed – the adhan may be minutes late';

  @override
  String get adhanSectionPrayers => 'Prayers';

  @override
  String get adhanSectionPrayersHint =>
      'The adhan as each time begins, and a reminder before it if you like';

  @override
  String get adhanPrayerOff => 'Adhan off';

  @override
  String adhanPrayerReminder(String minutes) {
    return 'Reminder $minutes before';
  }

  @override
  String adhanPrayerToggle(String prayer) {
    return '$prayer adhan';
  }

  @override
  String adhanAlertSheetTitle(String prayer) {
    return '$prayer adhan';
  }

  @override
  String get adhanAlertCall => 'Call the adhan at the prayer time';

  @override
  String get adhanAlertReminder => 'Reminder before the adhan';

  @override
  String get adhanReminderNone => 'None';

  @override
  String get adhanTestThis => 'Test this adhan';

  @override
  String get adhanSunrise => 'Sunrise alert';

  @override
  String get adhanSunriseHint => 'A gentle alert as Fajr time ends';

  @override
  String get adhanSunriseAt => 'At sunrise';

  @override
  String adhanSunriseBefore(String minutes) {
    return '$minutes before';
  }

  @override
  String get adhanSectionMuezzin => 'Muezzin';

  @override
  String get adhanSectionMuezzinHint => 'Fajr can have a voice of its own';

  @override
  String get adhanMuezzinFajr => 'Fajr';

  @override
  String get adhanMuezzinOthers => 'Dhuhr, Asr, Maghrib and Isha';

  @override
  String get adhanPickerTitleFajr => 'Fajr adhan sound';

  @override
  String get adhanPickerTitleOthers => 'Adhan sound';

  @override
  String get adhanPickerTones => 'Madar tones';

  @override
  String get adhanPickerTonesHint =>
      'Procedurally synthesised alerts – bells and singing bowls, never a voice or an adhan melody';

  @override
  String get adhanPickerYours => 'Your recordings';

  @override
  String get adhanPickerYoursHint =>
      'Attach an adhan recording you love – it is copied into Madar and stays on your device';

  @override
  String get adhanPickerEmpty => 'No recordings attached yet';

  @override
  String get adhanPickerAttach => 'Attach a recording';

  @override
  String get adhanPickerNote =>
      'Madar ships no recordings of human voices: none with a verifiable open licence could be found';

  @override
  String get adhanListen => 'Listen';

  @override
  String get adhanListenStop => 'Stop listening';

  @override
  String get adhanSelected => 'Selected';

  @override
  String get adhanDone => 'Done';

  @override
  String adhanTestSlotHint(String sound) {
    return 'With $sound';
  }

  @override
  String get adhanMuezzinRename => 'Rename';

  @override
  String get adhanMuezzinRenameTitle => 'Recording name';

  @override
  String get adhanMuezzinNameField => 'Name';

  @override
  String adhanMuezzinAdded(String name) {
    return 'Added “$name”';
  }

  @override
  String adhanMuezzinDeleted(String name) {
    return 'Deleted “$name”';
  }

  @override
  String get adhanMuezzinUnsupported =>
      'Unsupported format – pick a common audio file';

  @override
  String get adhanMuezzinTooLarge => 'That file is too large';

  @override
  String get adhanMuezzinUnreadable => 'Couldn\'t read that file';

  @override
  String get adhanMuezzinNoPreview =>
      'This format plays with the adhan itself – try it with “Test adhan now”';

  @override
  String get adhanMuezzinMissing => 'Deleted recording';

  @override
  String get adhanSectionAlert => 'Alert';

  @override
  String get adhanVibrate => 'Vibration';

  @override
  String get adhanVibrateHint =>
      'The phone vibrates with the adhan and reminders';

  @override
  String get adhanFullScreen => 'Full-screen adhan';

  @override
  String get adhanFullScreenHint =>
      'Appears over the lock screen and wakes the display at the adhan';

  @override
  String get adhanQuiet => 'Prayer quiet';

  @override
  String get adhanQuietHint =>
      'Game music and ambient sounds fall silent with the adhan and during the prayer';

  @override
  String get adhanQuietAdhanOnly => 'Adhan only';

  @override
  String get adhanSnoozeLength => 'Snooze length';

  @override
  String get adhanAlarmVolume => 'Alarm volume';

  @override
  String get adhanAlarmVolumeHint =>
      'The adhan plays at your phone\'s alarm volume';

  @override
  String get adhanAlarmMuted =>
      'Alarm volume is off – the adhan won\'t be heard';

  @override
  String get adhanOpenSoundSettings => 'Sound settings';

  @override
  String get adhanSectionTry => 'Try it';

  @override
  String get adhanTestNow => 'Test adhan now';

  @override
  String get adhanTestHint =>
      'A real adhan in a moment – lock the screen to see it full-screen';

  @override
  String adhanTestScheduled(String seconds) {
    return 'The adhan sounds in $seconds';
  }

  @override
  String get adhanTestFailed =>
      'Couldn\'t schedule the test – check the permissions';

  @override
  String get adhanPermTitle => 'So the adhan sounds on time';

  @override
  String get adhanPermSubtitle =>
      'A few Android permissions – nothing leaves your device';

  @override
  String get adhanPermReady =>
      'The adhan is ready – everything it needs is allowed';

  @override
  String get adhanPermNotifications => 'Notifications';

  @override
  String get adhanPermNotificationsHint => 'So the adhan can sound and show';

  @override
  String get adhanPermExact => 'Exact alarms';

  @override
  String get adhanPermExactHint =>
      'So the adhan fires at the exact minute, not after it';

  @override
  String get adhanPermFullScreen => 'Over the lock screen';

  @override
  String get adhanPermFullScreenHint =>
      'So the adhan screen appears while the phone is locked';

  @override
  String get adhanPermBattery => 'Battery optimisation exemption';

  @override
  String get adhanPermBatteryHint =>
      'So the system never stops the adhan to save power';

  @override
  String get adhanPermAllow => 'Allow';

  @override
  String get adhanPermAllowed => 'Allowed';

  @override
  String get adhanPermOpenSettings => 'Settings';

  @override
  String get adhanPermRefusedHint =>
      'You declined it in Android\'s dialog – turn it on in Settings whenever you like';

  @override
  String get adhanPermRequired => 'Required';

  @override
  String get adhanPermDeniedHint =>
      'If you refused it before, turn it on in the app\'s settings';

  @override
  String get trackerTitle => 'Prayer tracker';

  @override
  String get trackerTabToday => 'Today';

  @override
  String get trackerTabHistory => 'History';

  @override
  String get trackerTodayLabel => 'Today';

  @override
  String get trackerObligatory => 'Obligatory prayers';

  @override
  String get trackerObligatoryHint =>
      'Tap to change the status, swipe right to log it on time';

  @override
  String get trackerVoluntary => 'Voluntary prayers';

  @override
  String get trackerTodayPrayed => 'Today\'s prayers';

  @override
  String trackerOfTotal(String total) {
    return 'of $total';
  }

  @override
  String trackerProgress(String done, String total) {
    return '$done of $total prayed';
  }

  @override
  String get trackerAllDone => 'All five prayed – may Allah accept';

  @override
  String trackerNextIn(String prayer, String duration) {
    return '$prayer in $duration';
  }

  @override
  String get trackerNightLeft =>
      'All five prayers are due – the night is for voluntary prayer';

  @override
  String trackerStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
      zero: 'No streak yet',
    );
    return '$_temp0';
  }

  @override
  String trackerStreakChip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count-day streak',
      one: '1-day streak',
      zero: 'Start your streak today',
    );
    return '$_temp0';
  }

  @override
  String trackerDaysUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'days',
      one: 'day',
    );
    return '$_temp0';
  }

  @override
  String trackerJamaahCount(String count) {
    return '$count in jamaah';
  }

  @override
  String get trackerStatusPrayed => 'On time';

  @override
  String get trackerStatusLate => 'Late';

  @override
  String get trackerStatusMissed => 'Missed';

  @override
  String get trackerStatusQada => 'Made up';

  @override
  String get trackerStatusDue => 'Due now';

  @override
  String get trackerStatusUnlogged => 'Not logged';

  @override
  String get trackerStatusUpcoming => 'Not yet due';

  @override
  String get trackerStatusVoluntaryDone => 'Prayed';

  @override
  String get trackerStatusVoluntaryOpen => 'Not prayed yet';

  @override
  String trackerUpcomingIn(String duration) {
    return 'in $duration';
  }

  @override
  String trackerTimeLeft(String duration) {
    return '$duration left';
  }

  @override
  String get trackerActionPrayed => 'Prayed on time';

  @override
  String get trackerActionLate => 'Prayed late';

  @override
  String get trackerActionMissed => 'Missed it';

  @override
  String get trackerActionMadeUp => 'Made it up';

  @override
  String get trackerActionClear => 'Clear the log';

  @override
  String get trackerActionJamaahOn => 'Prayed in jamaah';

  @override
  String get trackerActionJamaahOff => 'Not in jamaah';

  @override
  String get trackerActionMosqueOn => 'Prayed at the mosque';

  @override
  String get trackerActionMosqueOff => 'Not at the mosque';

  @override
  String trackerActionMakeUpAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Made them all up',
      one: 'Made it up',
    );
    return '$_temp0';
  }

  @override
  String get trackerJamaah => 'Jamaah';

  @override
  String get trackerMosque => 'Mosque';

  @override
  String get trackerSwipePrayed => 'Prayed';

  @override
  String trackerUndoStatus(String prayer, String status) {
    return '$prayer: $status';
  }

  @override
  String trackerUndoCleared(String prayer) {
    return '$prayer log cleared';
  }

  @override
  String trackerUndoJamaahOn(String prayer) {
    return '$prayer in jamaah';
  }

  @override
  String trackerUndoJamaahOff(String prayer) {
    return '$prayer not in jamaah';
  }

  @override
  String trackerUndoMosqueOn(String prayer) {
    return '$prayer at the mosque';
  }

  @override
  String trackerUndoMosqueOff(String prayer) {
    return '$prayer not at the mosque';
  }

  @override
  String trackerUndoVoluntaryOn(String prayer) {
    return '$prayer logged';
  }

  @override
  String trackerUndoVoluntaryOff(String prayer) {
    return '$prayer removed';
  }

  @override
  String trackerUndoMadeUp(String prayer, String date) {
    return '$prayer of $date made up';
  }

  @override
  String trackerUndoMadeUpAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count prayers made up',
      one: '1 prayer made up',
    );
    return '$_temp0';
  }

  @override
  String trackerNotYet(String prayer) {
    return 'It isn\'t time for $prayer yet';
  }

  @override
  String get trackerSunnahFajr => 'Fajr sunnah';

  @override
  String get trackerSunnahDhuhr => 'Dhuhr sunnah';

  @override
  String get trackerSunnahMaghrib => 'Maghrib sunnah';

  @override
  String get trackerSunnahIsha => 'Isha sunnah';

  @override
  String get trackerDuha => 'Duha';

  @override
  String get trackerWitr => 'Witr';

  @override
  String get trackerQiyam => 'Night prayer';

  @override
  String get trackerSunnahLabel => 'Sunnah';

  @override
  String trackerRakahBefore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count before',
      one: '1 before',
    );
    return '$_temp0';
  }

  @override
  String trackerRakahAfter(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count after',
      one: '1 after',
    );
    return '$_temp0';
  }

  @override
  String trackerRakahBoth(String before, String after) {
    return '$before, $after';
  }

  @override
  String get trackerDuhaWindow => 'From mid-morning until Dhuhr';

  @override
  String get trackerNightWindow => 'From Isha until Fajr';

  @override
  String get trackerStreakCurrent => 'Current streak';

  @override
  String get trackerStreakBest => 'Best streak';

  @override
  String get trackerStreakRule =>
      'A day counts when all five are prayed or made up';

  @override
  String get trackerWeekTitle => 'The last seven days';

  @override
  String get trackerHeatmapTitle => 'The month';

  @override
  String get trackerLegendLess => 'Less';

  @override
  String get trackerLegendMore => 'All five';

  @override
  String get trackerLegendJamaah => 'Dots: prayers in jamaah';

  @override
  String get trackerPrevMonth => 'Previous month';

  @override
  String get trackerNextMonth => 'Next month';

  @override
  String trackerDaySemantics(
    String date,
    String done,
    String total,
    String jamaah,
  ) {
    return '$date: $done of $total prayed, $jamaah in jamaah';
  }

  @override
  String trackerTotalsTitle(String month) {
    return '$month at a glance';
  }

  @override
  String get trackerTotalOnTime => 'On time';

  @override
  String get trackerTotalJamaah => 'In jamaah';

  @override
  String get trackerTotalMosque => 'At the mosque';

  @override
  String get trackerTotalCompleteDays => 'Complete days';

  @override
  String get trackerTotalRawatib => 'Rawatib';

  @override
  String get trackerTotalSunnahTitle => 'Sunnah and voluntary';

  @override
  String get trackerBreakdownTitle => 'Prayer by prayer';

  @override
  String get trackerNoMonthData => 'Nothing logged this month yet';

  @override
  String get trackerQadaTitle => 'Qada ledger';

  @override
  String trackerQadaOutstanding(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count prayers to make up',
      one: '1 prayer to make up',
      zero: 'Nothing to make up',
    );
    return '$_temp0';
  }

  @override
  String trackerQadaMadeUpSoFar(String count) {
    return 'Made up so far: $count';
  }

  @override
  String get trackerQadaEmpty => 'No missed prayers waiting – well done';

  @override
  String trackerQadaEmptyFiltered(String prayer) {
    return 'Nothing to make up for $prayer';
  }

  @override
  String trackerQadaMissedOn(String date) {
    return 'Missed $date';
  }

  @override
  String trackerQadaShowMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Show $count more',
      one: 'Show 1 more',
    );
    return '$_temp0';
  }

  @override
  String get trackerFilterAll => 'All';

  @override
  String get trackerCardOpen => 'Open the tracker';

  @override
  String trackerSlotSemantics(String prayer, String time, String status) {
    return '$prayer, $time, $status';
  }

  @override
  String trackerMarks(String first, String second) {
    return '$first, $second';
  }

  @override
  String trackerUntil(String time) {
    return 'until $time';
  }

  @override
  String trackerDueNow(String duration) {
    return 'Due now · $duration left';
  }

  @override
  String trackerValueOf(String label, String value) {
    return '$label: $value';
  }

  @override
  String get adhkarTitle => 'Adhkar';

  @override
  String get adhkarTodayTitle => 'Today\'s adhkar';

  @override
  String adhkarSetsDoneOf(String done, String total) {
    return '$done of $total';
  }

  @override
  String get adhkarSetsDoneCaption => 'sets complete';

  @override
  String get adhkarCategoryMorning => 'Morning adhkar';

  @override
  String get adhkarCategoryEvening => 'Evening adhkar';

  @override
  String get adhkarCategoryAfterPrayer => 'After-prayer adhkar';

  @override
  String get adhkarCategorySleep => 'Before-sleep adhkar';

  @override
  String get adhkarCategoryWaking => 'On-waking adhkar';

  @override
  String get adhkarCategoryMorningHint => 'From Fajr until mid-morning';

  @override
  String get adhkarCategoryEveningHint => 'From Asr until after Maghrib';

  @override
  String get adhkarCategoryAfterPrayerHint =>
      'After the salam of every obligatory prayer';

  @override
  String get adhkarCategorySleepHint => 'As you go to bed';

  @override
  String get adhkarCategoryWakingHint => 'When you wake up';

  @override
  String get adhkarSuggestMorning => 'Time for your morning adhkar';

  @override
  String get adhkarSuggestEvening => 'Time for your evening adhkar';

  @override
  String get adhkarSuggestSleep => 'Your before-sleep adhkar, before you rest';

  @override
  String get adhkarSuggestWaking => 'Your on-waking adhkar';

  @override
  String adhkarSuggestAfterPrayer(String prayer) {
    return 'The adhkar after $prayer';
  }

  @override
  String get adhkarSuggestAllDone =>
      'You\'ve said all of today\'s adhkar — may Allah accept';

  @override
  String get adhkarStart => 'Begin';

  @override
  String get adhkarContinue => 'Continue';

  @override
  String adhkarContinueAt(String position) {
    return 'Continue from dhikr $position';
  }

  @override
  String get adhkarDoneToday => 'Done today';

  @override
  String adhkarAfterPrayerProgress(String done, String total) {
    return '$done of $total prayers';
  }

  @override
  String adhkarItemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count adhkar',
      one: '1 dhikr',
    );
    return '$_temp0';
  }

  @override
  String get adhkarMarkDone => 'Mark as done';

  @override
  String adhkarMarkedDone(String name) {
    return '$name marked done';
  }

  @override
  String get adhkarRestart => 'Start over';

  @override
  String adhkarRestarted(String name) {
    return '$name restarted';
  }

  @override
  String get adhkarSourceCredit =>
      'From “Hisn al-Muslim” by Sa\'id ibn Wahf al-Qahtani';

  @override
  String get adhkarLoadError => 'Couldn\'t load the adhkar';

  @override
  String get adhkarTasbeehTitle => 'Tasbeeh';

  @override
  String get adhkarTasbeehCardSubtitle =>
      'A ring of beads that moves with every glorification';

  @override
  String adhkarTasbeehToday(String count) {
    return 'Today: $count';
  }

  @override
  String get adhkarRemindersTitle => 'Reminders';

  @override
  String get adhkarReminderMorningLabel =>
      'Remind me of the morning adhkar after Fajr';

  @override
  String get adhkarReminderEveningLabel =>
      'Remind me of the evening adhkar after Asr';

  @override
  String adhkarReminderOffset(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes min',
      one: '1 min',
      zero: 'At the adhan',
    );
    return '$_temp0';
  }

  @override
  String get adhkarReminderOffsetCaption => 'How long after the adhan';

  @override
  String get adhkarReminderNote =>
      'Reminders stay on this device and arrive once Madar may send notifications.';

  @override
  String get adhkarReminderMorningTitle => 'Morning adhkar';

  @override
  String get adhkarReminderMorningBody =>
      'Time for your morning adhkar — begin your day with the remembrance of Allah';

  @override
  String get adhkarReminderEveningTitle => 'Evening adhkar';

  @override
  String get adhkarReminderEveningBody =>
      'Time for your evening adhkar — a calm close to your day';

  @override
  String adhkarReaderPosition(String index, String total) {
    return '$index of $total';
  }

  @override
  String get adhkarRemaining => 'to go';

  @override
  String get adhkarCounterDone => 'Done';

  @override
  String get adhkarCounterHint => 'Tap anywhere to count';

  @override
  String adhkarCounterSemantics(String done, String total) {
    return 'Count once — $done of $total';
  }

  @override
  String adhkarRepeat(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count times',
      two: 'Twice',
      one: 'Once',
    );
    return '$_temp0';
  }

  @override
  String get adhkarReadingDone => 'I\'ve read them';

  @override
  String get adhkarVirtue => 'Its virtue';

  @override
  String get adhkarReference => 'Source';

  @override
  String get adhkarMeaning => 'Meaning';

  @override
  String adhkarQuranRef(String surah, String ayahs) {
    return 'Surat $surah · $ayahs';
  }

  @override
  String get adhkarSurah2 => 'al-Baqarah';

  @override
  String get adhkarSurah3 => 'Al Imran';

  @override
  String get adhkarSurah112 => 'al-Ikhlas';

  @override
  String get adhkarSurah113 => 'al-Falaq';

  @override
  String get adhkarSurah114 => 'an-Nas';

  @override
  String adhkarSurahNumber(String number) {
    return 'no. $number';
  }

  @override
  String get adhkarPrevious => 'Previous dhikr';

  @override
  String get adhkarNext => 'Next dhikr';

  @override
  String adhkarDhikrSemantics(String index, String total) {
    return 'Dhikr $index of $total';
  }

  @override
  String get adhkarOptionsTitle => 'Reading options';

  @override
  String get adhkarTextSize => 'Text size';

  @override
  String get adhkarTextSizeSmaller => 'Smaller text';

  @override
  String get adhkarTextSizeLarger => 'Larger text';

  @override
  String get adhkarShowTranslation => 'Show the English meaning';

  @override
  String get adhkarShowVirtue => 'Show virtue and source';

  @override
  String get adhkarRecountCurrent => 'Recount this dhikr';

  @override
  String get adhkarRestartSet => 'Restart the set';

  @override
  String get adhkarMarkSetDone => 'I\'ve said the whole set';

  @override
  String adhkarAfterPrayerFor(String prayer) {
    return 'After $prayer';
  }

  @override
  String get adhkarChoosePrayer => 'After which prayer?';

  @override
  String get adhkarSetCompleteTitle => 'May Allah accept it from you';

  @override
  String adhkarSetCompleteBody(String name) {
    return '$name complete';
  }

  @override
  String get adhkarSetCompleteReview => 'Review';

  @override
  String get adhkarAudioTitle => 'Recording';

  @override
  String get adhkarAudioAttach => 'Attach a recording';

  @override
  String get adhkarAudioReplace => 'Replace';

  @override
  String get adhkarAudioRemove => 'Remove';

  @override
  String get adhkarAudioRemoved => 'Recording removed';

  @override
  String get adhkarAudioAttached => 'Recording attached';

  @override
  String get adhkarAudioPlay => 'Play the recording';

  @override
  String get adhkarAudioStop => 'Stop the recording';

  @override
  String get adhkarAudioNone =>
      'No recording for this dhikr yet. Attach an audio file from your device (MP3, WAV or FLAC) to hear it here.';

  @override
  String get adhkarAudioPolicy =>
      'Madar never uses generated voices for Quran or adhkar — attach a recording you trust; it stays on your device.';

  @override
  String get adhkarAudioUnsupported =>
      'This file isn\'t in a supported format (MP3, WAV or FLAC)';

  @override
  String get adhkarAudioTooLarge => 'The file is larger than 30 MB';

  @override
  String get adhkarAudioUnavailable => 'Audio can\'t play on this device';

  @override
  String adhkarAudioFile(String name, String duration) {
    return '$name · $duration';
  }

  @override
  String get adhkarTasbeehTarget => 'Round of';

  @override
  String get adhkarTasbeehCustom => 'Custom';

  @override
  String get adhkarTasbeehCustomTitle => 'Custom round';

  @override
  String get adhkarTasbeehCustomField => 'Count per round';

  @override
  String get adhkarTasbeehCustomInvalid => 'Enter a number from 1 to 9999';

  @override
  String adhkarTasbeehRound(String round) {
    return 'Round $round';
  }

  @override
  String adhkarTasbeehOf(String target) {
    return 'of $target';
  }

  @override
  String adhkarTasbeehTotal(String count) {
    return 'Total $count';
  }

  @override
  String get adhkarTasbeehTapHint => 'Tap to count · long-press to reset';

  @override
  String adhkarTasbeehCountSemantics(
    String phrase,
    String count,
    String target,
    String round,
  ) {
    return '$phrase: $count of $target, round $round';
  }

  @override
  String get adhkarTasbeehCountHint => 'Double-tap to count';

  @override
  String get adhkarTasbeehResetTitle => 'Reset the count?';

  @override
  String adhkarTasbeehResetBody(String count) {
    return 'Your count ($count) is saved to your history, then counting starts again from zero.';
  }

  @override
  String get adhkarTasbeehReset => 'Reset';

  @override
  String get adhkarTasbeehPhrases => 'Tasbeeh phrases';

  @override
  String get adhkarTasbeehEditPhrases => 'Edit phrases';

  @override
  String get adhkarTasbeehAddPhrase => 'Add a phrase';

  @override
  String get adhkarTasbeehEditPhrase => 'Edit phrase';

  @override
  String get adhkarTasbeehPhraseField => 'Phrase';

  @override
  String get adhkarTasbeehPhraseDeleted => 'Phrase removed';

  @override
  String get adhkarTasbeehNoPhrases => 'Add a phrase to start counting';

  @override
  String get adhkarTasbeehHistory => 'Tasbeeh history';

  @override
  String get adhkarTasbeehHistoryEmpty => 'No sessions yet';

  @override
  String get adhkarTasbeehSessionDeleted => 'Session removed';

  @override
  String adhkarTasbeehRounds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rounds',
      one: '1 round',
      zero: 'No full round',
    );
    return '$_temp0';
  }

  @override
  String get adhkarPhraseSubhanallah => 'Glory be to Allah';

  @override
  String get adhkarPhraseAlhamdulillah => 'Praise be to Allah';

  @override
  String get adhkarPhraseAllahuakbar => 'Allah is the Greatest';

  @override
  String get adhkarPhraseTahlil => 'There is no god but Allah';

  @override
  String get adhkarPhraseIstighfar => 'I seek Allah\'s forgiveness';

  @override
  String get adhkarPhraseSubhanallahWaBihamdihi =>
      'Glory be to Allah, and praise be to Him';

  @override
  String get adhkarPhraseSubhanallahilAzim =>
      'Glory be to Allah, the Magnificent';

  @override
  String get adhkarPhraseHawqala =>
      'There is no might and no power except by Allah';

  @override
  String get adhkarPhraseSalawat =>
      'O Allah, send blessings and peace upon our Prophet Muhammad';

  @override
  String get adhkarAllAdhkar => 'All adhkar';

  @override
  String get adhkarShortMorning => 'Morning';

  @override
  String get adhkarShortEvening => 'Evening';

  @override
  String get adhkarShortAfterPrayer => 'After prayer';

  @override
  String get adhkarShortSleep => 'Sleep';

  @override
  String get adhkarShortWaking => 'Waking';

  @override
  String adhkarJoin(String first, String second) {
    return '$first · $second';
  }

  @override
  String adhkarTasbeehChip(String count) {
    return 'Tasbeeh: $count';
  }

  @override
  String adhkarTodayLine(String suggestion, String done, String total) {
    return '$suggestion ($done of $total done)';
  }

  @override
  String get adhkarReminderChannelName => 'Adhkar reminders';

  @override
  String get adhkarReminderChannelDescription =>
      'Morning adhkar after Fajr and evening adhkar after Asr';

  @override
  String get adhkarReminderPermissionDenied =>
      'Notifications are off for Madar, so reminders can’t arrive. You can turn them on in your phone’s settings.';

  @override
  String adhkarSuggestDone(String set) {
    String _temp0 = intl.Intl.selectLogic(set, {
      'morning': 'Morning adhkar said — may Allah accept',
      'evening': 'Evening adhkar said — may Allah accept',
      'sleep': 'Before-sleep adhkar said — rest well',
      'waking': 'On-waking adhkar said — a blessed day to you',
      'other': 'Adhkar said — may Allah accept',
    });
    return '$_temp0';
  }

  @override
  String adhkarSuggestAfterPrayerDone(String prayer) {
    return 'Adhkar after $prayer said — may Allah accept';
  }

  @override
  String faithHubAt(String time) {
    return 'at $time';
  }

  @override
  String get faithHubHistory => 'Prayer history';

  @override
  String get faithHubHistoryHint => 'Streaks, make-ups and totals';

  @override
  String get faithHubAdhkarHint => 'Hisn al-Muslim';

  @override
  String get faithHubTasbeehHint => 'A bead counter';

  @override
  String get faithHubAdhanHint => 'Muezzin, reminders and permissions';

  @override
  String get faithHubTodayTitle => 'Your day';

  @override
  String get faithHubQuranTitle => 'With the Quran';

  @override
  String get faithHubQuranIndex => 'Index';

  @override
  String get faithHubToolsTitle => 'Tools';

  @override
  String get faithHubMushafHint => 'Index, search and bookmarks';

  @override
  String get faithHubHifzHint => 'Spaced-repetition review';

  @override
  String get faithHubRecitationHint => 'Reciters, repeats and downloads';

  @override
  String get faithHubAdhanTool => 'Adhan';

  @override
  String get faithHubHifzAlready => 'These ayat are already in your Hifz';

  @override
  String get quranTitle => 'The Holy Quran';

  @override
  String quranSurahTitle(String name) {
    return 'Surah $name';
  }

  @override
  String get quranMakki => 'Makki';

  @override
  String get quranMadani => 'Madani';

  @override
  String quranAyatCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ayat',
      one: '1 ayah',
      zero: 'No ayat',
    );
    return '$_temp0';
  }

  @override
  String quranPageLabel(String page) {
    return 'Page $page';
  }

  @override
  String quranPageCounter(String page, String total) {
    return 'Page $page of $total';
  }

  @override
  String quranJuzLabel(String juz) {
    return 'Juz $juz';
  }

  @override
  String quranHizbLabel(String hizb) {
    return 'Hizb $hizb';
  }

  @override
  String quranAyahLabel(String ayah) {
    return 'Ayah $ayah';
  }

  @override
  String quranAyahOfSurah(String surah, String ayah) {
    return '$surah · Ayah $ayah';
  }

  @override
  String quranJuzHizb(String juz, String hizb) {
    return 'Juz $juz · Hizb $hizb';
  }

  @override
  String quranQuarter1(String hizb) {
    return '¼ Hizb $hizb';
  }

  @override
  String quranQuarter2(String hizb) {
    return '½ Hizb $hizb';
  }

  @override
  String quranQuarter3(String hizb) {
    return '¾ Hizb $hizb';
  }

  @override
  String quranShareRef(String surah, String ayah) {
    return '($surah, ayah $ayah)';
  }

  @override
  String get quranLoadError => 'Couldn\'t load the mushaf';

  @override
  String get quranRetry => 'Try again';

  @override
  String get quranTabSurahs => 'Surahs';

  @override
  String get quranTabJuz => 'Juz';

  @override
  String get quranTabBookmarks => 'Bookmarks';

  @override
  String get quranSearchHint => 'Search the Quran…';

  @override
  String get quranGoTo => 'Go to';

  @override
  String get quranGoToTitle => 'Go to';

  @override
  String quranGoToHint(String a, String b, String c) {
    return 'e.g. $a, “Baqarah $b” or “page $c”';
  }

  @override
  String quranGoToNone(String example) {
    return 'Nothing matches — try a sura and ayah like $example';
  }

  @override
  String get quranGoToOpen => 'Open';

  @override
  String get quranBookmarksEmptyTitle => 'No bookmarks yet';

  @override
  String get quranBookmarksEmptyBody =>
      'Tap an ayah in the reader, then choose “Bookmark” to keep its place.';

  @override
  String get quranBookmarkDeleted => 'Bookmark removed';

  @override
  String get quranBookmarkSaved => 'Bookmark saved';

  @override
  String get quranBookmarkEdit => 'Edit bookmark';

  @override
  String get quranBookmarkNew => 'New bookmark';

  @override
  String get quranBookmarkLabel => 'Label';

  @override
  String get quranBookmarkLabelHint => 'e.g. Fajr wird';

  @override
  String get quranBookmarkNote => 'Note';

  @override
  String get quranBookmarkColor => 'Colour';

  @override
  String get quranBookmarkRemove => 'Remove bookmark';

  @override
  String get quranJuzQuarters => 'Quarters of this juz';

  @override
  String get quranContinueTitle => 'Continue reading';

  @override
  String get quranContinueEmpty => 'Begin your journey with the Book of Allah';

  @override
  String get quranContinueStart => 'Start with Al-Fatihah';

  @override
  String get quranContinueAction => 'Continue';

  @override
  String quranLastReadAt(String when) {
    return 'Last read $when';
  }

  @override
  String get quranModeMushaf => 'Mushaf';

  @override
  String get quranModeList => 'Verses';

  @override
  String get quranShowList => 'Show as verses';

  @override
  String get quranShowMushaf => 'Show as mushaf pages';

  @override
  String get quranSettingsTitle => 'Reading settings';

  @override
  String get quranReaderLayout => 'Layout';

  @override
  String get quranFontSize => 'Text size';

  @override
  String get quranFontLarger => 'Larger text';

  @override
  String get quranFontSmaller => 'Smaller text';

  @override
  String get quranTajweedColors => 'Tajweed colours';

  @override
  String get quranTajweedSection => 'Tajweed';

  @override
  String get quranTajweedLegend => 'Colour guide';

  @override
  String get quranTajweedSource => 'Tajweed source';

  @override
  String get quranTajweedSourceBundled => 'Built in';

  @override
  String get quranTajweedSourceQuranCom => 'Quran.com when downloaded';

  @override
  String get quranDownloadTajweed =>
      'Download this surah\'s tajweed from Quran.com';

  @override
  String get quranTranslation => 'Translation';

  @override
  String get quranTranslationShow => 'Show the translation under each ayah';

  @override
  String get quranTranslationName => 'English — Saheeh International';

  @override
  String get quranTranslationMissing =>
      'This surah\'s translation isn\'t downloaded yet';

  @override
  String get quranDownloadTranslation => 'Download translation';

  @override
  String get quranDownloadNote =>
      'Downloaded once from Quran.com and kept on your device.';

  @override
  String get quranDownloading => 'Downloading…';

  @override
  String get quranDownloaded => 'Downloaded';

  @override
  String get quranDownloadOffline => 'No internet connection — try again later';

  @override
  String get quranDownloadFailed => 'The download failed, try again';

  @override
  String quranNextSurah(String name) {
    return 'Next: $name';
  }

  @override
  String quranPrevSurah(String name) {
    return 'Previous: $name';
  }

  @override
  String get quranNowReciting => 'Now reciting';

  @override
  String get quranSajdah => 'Prostration of recitation';

  @override
  String quranAyahSemantics(String ayah, String surah) {
    return 'Ayah $ayah of Surah $surah';
  }

  @override
  String get quranActionPlay => 'Play from here';

  @override
  String get quranActionRepeat => 'Repeat ayah';

  @override
  String quranRepeatTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count times',
      two: 'twice',
      one: 'once',
    );
    return '$_temp0';
  }

  @override
  String get quranActionBookmark => 'Bookmark';

  @override
  String get quranActionCopy => 'Copy';

  @override
  String get quranCopied => 'Ayah copied';

  @override
  String get quranActionShare => 'Share';

  @override
  String get quranActionHifz => 'Add to Hifz';

  @override
  String get quranHifzAdded => 'Added to Hifz';

  @override
  String get quranActionTafsir => 'Tafsir';

  @override
  String get quranTafsirSoon => 'Tafsir is coming soon, in sha Allah';

  @override
  String get quranSoon => 'Soon';

  @override
  String get quranSearchTitle => 'Search the Quran';

  @override
  String get quranSearchFieldHint => 'A word or part of an ayah';

  @override
  String get quranSearchIntro =>
      'Searches the Arabic text, ignoring diacritics, hamza and the forms of alef.';

  @override
  String quranSearchResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ayat',
      one: '1 ayah',
      zero: 'No results',
    );
    return '$_temp0';
  }

  @override
  String quranSearchOccurrences(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count matches',
      one: '1 match',
      zero: 'No matches',
    );
    return '$_temp0';
  }

  @override
  String quranSearchShowingFirst(String count) {
    return 'Showing the first $count';
  }

  @override
  String get quranSearchTooShort => 'Type at least two letters';

  @override
  String get quranSearchNoResults => 'No ayah contains these words';

  @override
  String get quranSearchPreparing => 'Preparing the search index…';

  @override
  String get quranLegendTitle => 'Tajweed colour guide';

  @override
  String get quranLegendNote =>
      'The colours are a learning aid; learning from a qualified reciter comes first.';

  @override
  String get quranLegendCredits =>
      'Quran text from the Tanzil Project; tajweed marks from the quran-tajweed project (CC BY).';

  @override
  String get quranFamilySilent => 'Not pronounced';

  @override
  String get quranFamilyMadd => 'Prolongation (madd)';

  @override
  String get quranFamilyGhunnah => 'Nasalisation (ghunnah)';

  @override
  String get quranFamilyMerge => 'Merging without ghunnah';

  @override
  String get quranFamilyQalqalah => 'Echo (qalqalah)';

  @override
  String get quranRuleHamzatWasl => 'Hamzat al-wasl';

  @override
  String get quranRuleHamzatWaslHint =>
      'Written, not pronounced when joined to what precedes';

  @override
  String get quranRuleLamShamsiyyah => 'Lam shamsiyyah';

  @override
  String get quranRuleLamShamsiyyahHint =>
      'The lam of the article is silent before a sun letter';

  @override
  String get quranRuleSilent => 'Silent letter';

  @override
  String get quranRuleSilentHint => 'Written but not read';

  @override
  String get quranRuleMaddNatural => 'Natural madd';

  @override
  String get quranRuleMaddNaturalHint => 'Two counts';

  @override
  String get quranRuleMaddPermissible => 'Madd \'arid or leen';

  @override
  String get quranRuleMaddPermissibleHint =>
      'Two, four or six counts when stopping';

  @override
  String get quranRuleMaddSeparated => 'Madd munfasil';

  @override
  String get quranRuleMaddSeparatedHint => 'Four or five counts';

  @override
  String get quranRuleMaddConnected => 'Madd muttasil';

  @override
  String get quranRuleMaddConnectedHint => 'Four or five counts';

  @override
  String get quranRuleMaddNecessary => 'Madd lazim';

  @override
  String get quranRuleMaddNecessaryHint => 'Six counts';

  @override
  String get quranRuleQalqalah => 'Qalqalah';

  @override
  String get quranRuleQalqalahHint =>
      'An echo on the five qalqalah letters when still';

  @override
  String get quranRuleGhunnah => 'Ghunnah';

  @override
  String get quranRuleGhunnahHint =>
      'Doubled noon or meem, nasalised for two counts';

  @override
  String get quranRuleIkhfa => 'Ikhfa';

  @override
  String get quranRuleIkhfaHint =>
      'Noon sakinah or tanween hidden, with ghunnah';

  @override
  String get quranRuleIkhfaShafawi => 'Ikhfa shafawi';

  @override
  String get quranRuleIkhfaShafawiHint => 'Still meem before ba';

  @override
  String get quranRuleIqlab => 'Iqlab';

  @override
  String get quranRuleIqlabHint =>
      'Noon sakinah or tanween turned into meem before ba';

  @override
  String get quranRuleIdghamGhunnah => 'Idgham with ghunnah';

  @override
  String get quranRuleIdghamGhunnahHint => 'Into ya, noon, meem or waw';

  @override
  String get quranRuleIdghamShafawi => 'Idgham shafawi';

  @override
  String get quranRuleIdghamShafawiHint => 'Still meem into meem';

  @override
  String get quranRuleIdghamNoGhunnah => 'Idgham without ghunnah';

  @override
  String get quranRuleIdghamNoGhunnahHint => 'Into lam or ra';

  @override
  String get quranRuleIdghamMutajanisayn => 'Idgham mutajanisayn';

  @override
  String get quranRuleIdghamMutajanisaynHint =>
      'Two letters of one articulation point';

  @override
  String get quranRuleIdghamMutaqaribayn => 'Idgham mutaqaribayn';

  @override
  String get quranRuleIdghamMutaqaribaynHint =>
      'Two letters of nearby articulation points';

  @override
  String get recitationTitle => 'Recitation';

  @override
  String get recitationChannelName => 'Quran recitation';

  @override
  String get recitationAlbum => 'The Noble Quran';

  @override
  String get recitationReciterLabel => 'Reciter';

  @override
  String get recitationSectionReciters => 'Reciters';

  @override
  String get recitationSectionRecitersHint =>
      'Real reciters from everyayah.com – never a generated voice for the Quran';

  @override
  String get recitationStyleMujawwad => 'Mujawwad';

  @override
  String get recitationStyleMurattal => 'Murattal';

  @override
  String get recitationStyleMuallim => 'Muʿallim';

  @override
  String get recitationStyleMujawwadHint =>
      'Slow, melodic, with the full art of tajweed';

  @override
  String get recitationStyleMurattalHint => 'Measured, flowing recitation';

  @override
  String get recitationStyleMuallimHint =>
      'The clear teaching recitation, for memorising';

  @override
  String recitationBitrate(String kbps) {
    return '$kbps kbps';
  }

  @override
  String get recitationSample => 'Hear a sample';

  @override
  String get recitationSampleStop => 'Stop the sample';

  @override
  String recitationSampleOf(String name) {
    return 'Sample of $name';
  }

  @override
  String get recitationChosen => 'Chosen reciter';

  @override
  String recitationChoose(String name) {
    return 'Choose $name';
  }

  @override
  String recitationSurahsDownloaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count surahs downloaded',
      one: '1 surah downloaded',
      zero: 'No surahs downloaded',
    );
    return '$_temp0';
  }

  @override
  String get recitationWholeMushafDownloaded => 'Whole Quran downloaded';

  @override
  String get recitationSectionPlayback => 'Repeat and playback';

  @override
  String get recitationSectionPlaybackHint =>
      'Defaults for every new recitation';

  @override
  String get recitationRepeatAyah => 'Repeat each ayah';

  @override
  String get recitationRepeatRange => 'Repeat the passage';

  @override
  String recitationTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count times',
      two: 'Twice',
      one: 'Once',
    );
    return '$_temp0';
  }

  @override
  String get recitationEndless => 'Until I stop';

  @override
  String get recitationGap => 'Pause after each recitation';

  @override
  String get recitationGapHint => 'Time to repeat the ayah after the reciter';

  @override
  String get recitationGapNone => 'None';

  @override
  String recitationSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seconds',
      one: '1 second',
    );
    return '$_temp0';
  }

  @override
  String get recitationSpeed => 'Speed';

  @override
  String recitationSpeedValue(String value) {
    return '$value×';
  }

  @override
  String get recitationBasmala => 'Basmala before each surah';

  @override
  String get recitationBasmalaHint =>
      'As in the mushaf – except al-Fatihah (where it is the first ayah) and at-Tawbah';

  @override
  String get recitationSectionDownloads => 'Listen offline';

  @override
  String get recitationSectionDownloadsHint =>
      'Nothing downloads unless you start it';

  @override
  String recitationStorageUsed(String size) {
    return 'Storage used: $size';
  }

  @override
  String get recitationWifiOnly => 'Download on Wi-Fi only';

  @override
  String get recitationWifiOnlyHint =>
      'Downloads wait when you\'re not on Wi-Fi';

  @override
  String recitationMushafFor(String name) {
    return 'The whole Quran by $name';
  }

  @override
  String recitationAbout(String size) {
    return 'About $size';
  }

  @override
  String get recitationDownloadMushaf => 'Download the Quran';

  @override
  String get recitationChooseSurahs => 'Choose surahs';

  @override
  String recitationSurahProgress(String done, String total) {
    return '$done of $total surahs';
  }

  @override
  String recitationFilesProgress(String done, String total) {
    return '$done of $total files';
  }

  @override
  String get recitationPauseDownloads => 'Pause';

  @override
  String get recitationResumeDownloads => 'Resume';

  @override
  String get recitationCancelDownload => 'Cancel download';

  @override
  String get recitationDeleteDownloads => 'Delete downloads';

  @override
  String recitationDeleteConfirm(String name) {
    return 'Delete $name\'s recitation from the phone?';
  }

  @override
  String recitationDeleteConfirmHint(String size) {
    return 'Frees $size. You can download it again any time.';
  }

  @override
  String recitationDeleteSurahConfirm(String surah) {
    return 'Delete surah $surah?';
  }

  @override
  String get recitationOtherDownloads => 'Other reciters\' downloads';

  @override
  String recitationDownloadsTitle(String name) {
    return '$name – downloads';
  }

  @override
  String recitationAyatCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ayat',
      one: '1 ayah',
    );
    return '$_temp0';
  }

  @override
  String get recitationDownloadSurah => 'Download surah';

  @override
  String get recitationStatusQueued => 'Queued';

  @override
  String get recitationStatusDownloading => 'Downloading';

  @override
  String get recitationStatusPaused => 'Paused';

  @override
  String get recitationStatusWifi => 'Waiting for Wi-Fi';

  @override
  String get recitationStatusFailed => 'Download failed';

  @override
  String get recitationStatusComplete => 'Downloaded';

  @override
  String get recitationErrorNetwork => 'Check the connection, then resume';

  @override
  String get recitationErrorNotFound =>
      'The file isn\'t available at the source';

  @override
  String get recitationErrorStorage => 'Not enough space on the phone';

  @override
  String recitationSizeMb(String size) {
    return '$size MB';
  }

  @override
  String recitationSizeGb(String size) {
    return '$size GB';
  }

  @override
  String recitationSizeKb(String size) {
    return '$size KB';
  }

  @override
  String get recitationSourceCredit =>
      'Recitations from everyayah.com – streamed when you press play or downloaded when you ask';

  @override
  String recitationSurahNumber(String number) {
    return 'Surah $number';
  }

  @override
  String recitationTitleAyah(String surah, String ayah) {
    return '$surah · Ayah $ayah';
  }

  @override
  String recitationTitleBasmala(String surah) {
    return '$surah · Basmala';
  }

  @override
  String recitationAyahNumber(String ayah) {
    return 'Ayah $ayah';
  }

  @override
  String get recitationBasmalaNow => 'Basmala';

  @override
  String get recitationNowPlaying => 'Now reciting';

  @override
  String get recitationPlay => 'Play';

  @override
  String get recitationPause => 'Pause';

  @override
  String get recitationNextAyah => 'Next ayah';

  @override
  String get recitationPreviousAyah => 'Previous ayah';

  @override
  String get recitationStop => 'Stop recitation';

  @override
  String get recitationOpenPlayer => 'Open the player';

  @override
  String get recitationLoading => 'Loading…';

  @override
  String get recitationPausedPrayer => 'Paused for the adhan – tap to continue';

  @override
  String get recitationPausedInterruption => 'Paused';

  @override
  String get recitationPausedNoisy => 'Paused – headphones disconnected';

  @override
  String get recitationPausedSleep => 'Sleep timer ended';

  @override
  String get recitationPlaybackNetwork =>
      'No connection – download the surah to listen offline';

  @override
  String get recitationPlaybackNotFound =>
      'This ayah isn\'t available for this reciter';

  @override
  String get recitationPlaybackFailed => 'Couldn\'t play';

  @override
  String get recitationRetry => 'Retry';

  @override
  String get recitationOffline => 'Offline';

  @override
  String get recitationStreaming => 'Streaming';

  @override
  String recitationAyahPass(String pass, String total) {
    return 'Repeat $pass of $total';
  }

  @override
  String recitationRangePass(String pass, String total) {
    return 'Pass $pass of $total';
  }

  @override
  String recitationRangePassEndless(String pass) {
    return 'Pass $pass';
  }

  @override
  String get recitationRepeatAyahShort => 'Ayah';

  @override
  String get recitationRepeatRangeShort => 'Passage';

  @override
  String get recitationMore => 'More';

  @override
  String get recitationLess => 'Fewer';

  @override
  String get recitationSleepTimer => 'Sleep timer';

  @override
  String get recitationSleepOff => 'Off';

  @override
  String get recitationSleepAfterAyah => 'After this ayah';

  @override
  String recitationMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min',
      one: '1 min',
    );
    return '$_temp0';
  }

  @override
  String recitationSleepUntil(String time) {
    return 'Stops at $time';
  }

  @override
  String get recitationChangeReciter => 'Change reciter';

  @override
  String recitationProgress(String percent) {
    return '$percent of the passage';
  }

  @override
  String recitationRangeLabel(String from, String to) {
    return '$from to $to';
  }

  @override
  String recitationRangeInSurah(String surah, String from, String to) {
    return '$surah $from–$to';
  }

  @override
  String get recitationBackgroundOff => 'Plays while Madar is open';

  @override
  String get wirdSep => ' · ';

  @override
  String get wirdTitle => 'Daily wird';

  @override
  String get wirdTodayTitle => 'Today\'s wird';

  @override
  String get wirdReadNow => 'Read now';

  @override
  String get wirdContinue => 'Continue reading';

  @override
  String get wirdMarkDone => 'Mark done';

  @override
  String get wirdStoppedAt => 'I stopped at…';

  @override
  String get wirdStoppedAtTitle => 'Where did you stop?';

  @override
  String get wirdStoppedAtHint => 'Move the marker to the last ayah you read';

  @override
  String get wirdSaveProgress => 'Save';

  @override
  String get wirdDoneToast => 'Today\'s wird recorded — may Allah accept it';

  @override
  String wirdPartialToast(String ayah) {
    return 'Reading recorded up to $ayah';
  }

  @override
  String get wirdMetToday => 'Today\'s wird is done — may Allah accept it';

  @override
  String get wirdRestToday => 'Nothing due today — you\'re ahead of your plan';

  @override
  String get wirdPausedNote => 'This plan is paused';

  @override
  String wirdNotStarted(String date) {
    return 'Starts $date';
  }

  @override
  String get wirdKhatmaDone => 'Khatma complete — may Allah accept it';

  @override
  String wirdBehindSpread(String amount) {
    return '$amount behind — spread over the coming days';
  }

  @override
  String wirdBehindAll(String amount) {
    return '$amount behind — added to today';
  }

  @override
  String wirdAhead(String amount) {
    return '$amount ahead — well done';
  }

  @override
  String wirdBehindShort(String amount) {
    return '$amount behind';
  }

  @override
  String wirdAheadShort(String amount) {
    return '$amount ahead';
  }

  @override
  String wirdTodayLine(String range) {
    return 'Today: $range';
  }

  @override
  String wirdPagePosition(String page) {
    return 'At p. $page';
  }

  @override
  String wirdLeftToday(String amount) {
    return '$amount to go';
  }

  @override
  String wirdAyahRef(String surah, String ayah) {
    return '$surah $ayah';
  }

  @override
  String wirdRangeSameSurah(String surah, String from, String to) {
    return '$surah $from–$to';
  }

  @override
  String wirdRangeCross(String from, String to) {
    return '$from – $to';
  }

  @override
  String wirdPageRange(String from, String to) {
    return 'pp. $from–$to';
  }

  @override
  String wirdPageSingle(String page) {
    return 'p. $page';
  }

  @override
  String wirdUnitPages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages',
      one: '1 page',
      zero: '0 pages',
    );
    return '$_temp0';
  }

  @override
  String wirdUnitJuz(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count juz',
      one: '1 juz',
      zero: '0 juz',
    );
    return '$_temp0';
  }

  @override
  String wirdUnitHizb(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hizb',
      one: '1 hizb',
      zero: '0 hizb',
    );
    return '$_temp0';
  }

  @override
  String wirdUnitAyat(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ayat',
      one: '1 ayah',
      zero: '0 ayat',
    );
    return '$_temp0';
  }

  @override
  String wirdUnitPagesDecimal(String amount) {
    return '$amount pages';
  }

  @override
  String wirdUnitJuzDecimal(String amount) {
    return '$amount juz';
  }

  @override
  String wirdUnitHizbDecimal(String amount) {
    return '$amount hizb';
  }

  @override
  String wirdDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
      zero: '0 days',
    );
    return '$_temp0';
  }

  @override
  String get wirdTemplateKhatma => 'Khatma';

  @override
  String get wirdTemplatePages => 'Pages';

  @override
  String get wirdTemplateJuz => 'Juz';

  @override
  String get wirdTemplateHizb => 'Hizb';

  @override
  String get wirdTemplateAyat => 'Ayat';

  @override
  String wirdSummaryKhatma(String days, String amount) {
    return 'Khatma in $days · $amount a day';
  }

  @override
  String wirdSummaryDaily(String amount) {
    return '$amount a day';
  }

  @override
  String wirdDefaultNameKhatma(String days) {
    return 'Khatma in $days';
  }

  @override
  String wirdDefaultNameDaily(String amount) {
    return '$amount every day';
  }

  @override
  String wirdWindowAfter(String prayer) {
    return 'After $prayer';
  }

  @override
  String get wirdWindowDuha => 'Duha time';

  @override
  String get wirdWindowAnytime => 'Any time';

  @override
  String get wirdPlansTitle => 'My plans';

  @override
  String get wirdAddPlan => 'New plan';

  @override
  String get wirdPrimary => 'Primary';

  @override
  String get wirdMakePrimary => 'Make primary';

  @override
  String get wirdPause => 'Pause';

  @override
  String get wirdResume => 'Resume';

  @override
  String get wirdPaused => 'Paused';

  @override
  String get wirdEdit => 'Edit';

  @override
  String get wirdDelete => 'Delete';

  @override
  String get wirdDeletedToast => 'Plan deleted';

  @override
  String get wirdPausedToast => 'Plan paused';

  @override
  String get wirdResumedToast => 'Plan resumed';

  @override
  String wirdPrimaryToast(String name) {
    return '“$name” is now your primary plan';
  }

  @override
  String get wirdSavedToast => 'Plan saved';

  @override
  String wirdCreatedToast(String name) {
    return '“$name” has begun — may Allah make it easy';
  }

  @override
  String get wirdEmptyTitle => 'No wird plan yet';

  @override
  String get wirdEmptyBody =>
      'Choose a khatma in thirty days or a daily amount that suits you — we\'ll remind you after the prayer.';

  @override
  String get wirdEmptyAction => 'Start a plan';

  @override
  String get wirdStreak => 'Streak';

  @override
  String wirdBestStreak(String days) {
    return 'Best: $days';
  }

  @override
  String get wirdFinish => 'Projected finish';

  @override
  String wirdTargetDate(String date) {
    return 'Target $date';
  }

  @override
  String get wirdProgress => 'Progress';

  @override
  String wirdKhatmas(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count khatmas',
      one: '1 khatma',
      zero: 'No khatma yet',
    );
    return '$_temp0';
  }

  @override
  String get wirdNoProjection => 'Not yet known';

  @override
  String wirdProgressOf(String done, String quota) {
    return '$done of $quota';
  }

  @override
  String wirdProgressOfShort(String quota) {
    return 'of $quota';
  }

  @override
  String get wirdHistoryTitle => 'History';

  @override
  String get wirdLegendMet => 'Done';

  @override
  String get wirdLegendPartial => 'Partly';

  @override
  String get wirdLegendMissed => 'Missed';

  @override
  String get wirdLegendRest => 'Nothing due';

  @override
  String get wirdLegendPaused => 'Paused';

  @override
  String get wirdPrevMonth => 'Previous month';

  @override
  String get wirdNextMonth => 'Next month';

  @override
  String get wirdNewPlanTitle => 'New wird plan';

  @override
  String get wirdEditPlanTitle => 'Edit plan';

  @override
  String get wirdPlanSheetSubtitle =>
      'A little, done steadily, is better than a lot, abandoned';

  @override
  String get wirdFieldName => 'Name';

  @override
  String get wirdFieldType => 'Plan type';

  @override
  String get wirdFieldDays => 'Duration';

  @override
  String get wirdFieldCustom => 'Other';

  @override
  String get wirdFieldAmount => 'Daily amount';

  @override
  String get wirdFieldStart => 'Start from';

  @override
  String get wirdFieldStartDate => 'Start date';

  @override
  String get wirdStartToday => 'Today';

  @override
  String get wirdStartTomorrow => 'Tomorrow';

  @override
  String wirdFinishesOn(String date) {
    return 'Finishes on $date';
  }

  @override
  String wirdPerDayPreview(String amount) {
    return 'About $amount a day';
  }

  @override
  String get wirdFieldWindow => 'Wird time';

  @override
  String get wirdFieldCatchUp => 'If you fall behind';

  @override
  String get wirdCatchUpSpread => 'Spread it out';

  @override
  String get wirdCatchUpAll => 'Add it to today';

  @override
  String get wirdCatchUpSpreadHint =>
      'What you missed is shared across the coming days, so no single day is heavy';

  @override
  String get wirdCatchUpAllHint =>
      'Everything you missed is added to the next day\'s portion';

  @override
  String get wirdFieldRemind => 'Remind me after the prayer';

  @override
  String wirdRemindAfter(String minutes) {
    return '$minutes after';
  }

  @override
  String wirdMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min',
      one: '1 min',
    );
    return '$_temp0';
  }

  @override
  String get wirdDecrease => 'Decrease';

  @override
  String get wirdIncrease => 'Increase';

  @override
  String get wirdSurah => 'Surah';

  @override
  String get wirdAyah => 'Ayah';

  @override
  String get wirdStartJuzShortcut => 'Juz start';

  @override
  String wirdJuzNumber(String n) {
    return 'Juz $n';
  }

  @override
  String get wirdChooseSurah => 'Choose a surah';

  @override
  String get wirdSearchSurah => 'Search by name or number';

  @override
  String get wirdCreate => 'Start plan';

  @override
  String get wirdSave => 'Save';

  @override
  String get wirdNameRequired => 'Give the plan a name';

  @override
  String get wirdReminderChannelName => 'Wird reminders';

  @override
  String get wirdReminderChannelDescription =>
      'A reminder for your daily wird after the prayer you choose';

  @override
  String get wirdReminderTitle => 'Time for your wird';

  @override
  String wirdReminderBodyToday(String plan, String range) {
    return '$plan: $range';
  }

  @override
  String wirdReminderBody(String plan, String window) {
    return '$plan — $window';
  }

  @override
  String get wirdCatalogError => 'Couldn\'t load the Quran data';

  @override
  String wirdOverallOf(String percent) {
    return '$percent of the khatma';
  }

  @override
  String wirdPositionIn(String percent) {
    return '$percent through the mushaf';
  }

  @override
  String get wirdOpenAll => 'All plans';

  @override
  String get wirdStartPlanCta => 'Start a daily wird';

  @override
  String wirdDayStatusSemantics(String date, String status) {
    return '$date: $status';
  }

  @override
  String get hifzTitle => 'Hifz';

  @override
  String get hifzTodayTitle => 'Hifz review';

  @override
  String get hifzStartReview => 'Start review';

  @override
  String get hifzContinueReview => 'Keep reviewing';

  @override
  String get hifzNothingDue => 'Nothing to review today';

  @override
  String get hifzAllCaughtUp => 'All caught up for today — barakAllahu feek';

  @override
  String hifzDueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count to review',
      one: '1 to review',
      zero: 'Nothing due',
    );
    return '$_temp0';
  }

  @override
  String hifzNewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new',
      one: '1 new',
      zero: 'No new',
    );
    return '$_temp0';
  }

  @override
  String get hifzTabDue => 'Due';

  @override
  String get hifzTabNew => 'New';

  @override
  String get hifzTabLearned => 'Learned';

  @override
  String get hifzStatDue => 'Today';

  @override
  String get hifzStatLearned => 'Learned';

  @override
  String get hifzStatRetention => 'Retention';

  @override
  String get hifzStatStreak => 'Streak';

  @override
  String hifzRetentionCaption(String days) {
    return 'Last $days days';
  }

  @override
  String get hifzForecastTitle => 'Reviews in the week ahead';

  @override
  String get hifzForecastToday => 'Today';

  @override
  String get hifzKindAyat => 'Ayat';

  @override
  String get hifzKindHadith => 'Hadith';

  @override
  String get hifzKindCustom => 'Text';

  @override
  String hifzDueIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count days',
      one: 'tomorrow',
      zero: 'today',
    );
    return '$_temp0';
  }

  @override
  String hifzOverdue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days overdue',
      one: '1 day overdue',
    );
    return '$_temp0';
  }

  @override
  String hifzReviews(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reviews',
      one: '1 review',
      zero: 'Not reviewed yet',
    );
    return '$_temp0';
  }

  @override
  String hifzLapses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'forgotten $count times',
      one: 'forgotten once',
    );
    return '$_temp0';
  }

  @override
  String get hifzNewBadge => 'New';

  @override
  String get hifzSuspendedBadge => 'Suspended';

  @override
  String get hifzAdd => 'Add';

  @override
  String get hifzAddTitle => 'Add to Hifz';

  @override
  String get hifzAddSubtitle =>
      'What you learn today comes back before it fades';

  @override
  String get hifzAddAyat => 'Ayat of the Quran';

  @override
  String get hifzAddAyatHint =>
      'Pick a surah and ayat — split into short chunks';

  @override
  String get hifzAddHadith => 'A hadith from An-Nawawi\'s Forty';

  @override
  String get hifzAddHadithHint => 'Forty-two concise, comprehensive hadith';

  @override
  String get hifzAddCustom => 'Your own text';

  @override
  String get hifzAddCustomHint =>
      'A dua, a classical text — anything you want to memorise';

  @override
  String get hifzFromAyah => 'From ayah';

  @override
  String get hifzToAyah => 'To ayah';

  @override
  String get hifzChunkSize => 'Ayat per chunk';

  @override
  String hifzChunks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chunks',
      one: '1 chunk',
      zero: 'No chunks',
    );
    return '$_temp0';
  }

  @override
  String hifzChunkPreview(String chunks, String ranges) {
    return '$chunks: $ranges';
  }

  @override
  String get hifzAddButton => 'Add to Hifz';

  @override
  String hifzAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items added to Hifz',
      one: '1 item added to Hifz',
    );
    return '$_temp0';
  }

  @override
  String get hifzInHifz => 'In Hifz';

  @override
  String get hifzCustomTitle => 'Title';

  @override
  String get hifzCustomTitleHint => 'e.g. The istikhara dua';

  @override
  String get hifzCustomBody => 'Text';

  @override
  String get hifzCustomSource => 'Source (optional)';

  @override
  String get hifzBodyRequired => 'Write the text you want to memorise';

  @override
  String get hifzEdit => 'Edit';

  @override
  String get hifzEditTitle => 'Edit item';

  @override
  String get hifzSuspend => 'Suspend';

  @override
  String get hifzUnsuspend => 'Back to reviews';

  @override
  String get hifzResetProgress => 'Start it over';

  @override
  String get hifzDelete => 'Delete';

  @override
  String get hifzReviewNow => 'Review now';

  @override
  String get hifzDeletedToast => 'Removed from Hifz';

  @override
  String get hifzSuspendedToast => 'Item suspended';

  @override
  String get hifzUnsuspendedToast => 'Item back in reviews';

  @override
  String get hifzResetToast => 'Item is new again';

  @override
  String get hifzSavedToast => 'Changes saved';

  @override
  String get hifzReviewTitle => 'Review';

  @override
  String hifzReviewProgress(String done, String total) {
    return '$done of $total';
  }

  @override
  String get hifzRecitePrompt =>
      'Recite from memory, then reveal the text and grade yourself honestly';

  @override
  String get hifzRevealFirstLetters => 'First letters';

  @override
  String get hifzRevealNextWord => 'Next word';

  @override
  String get hifzRevealAll => 'Show all';

  @override
  String get hifzRevealHide => 'Hide';

  @override
  String get hifzListen => 'Listen';

  @override
  String get hifzListenStop => 'Stop';

  @override
  String hifzRepeatTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count times',
      two: 'twice',
      one: 'once',
    );
    return '$_temp0';
  }

  @override
  String get hifzRedrill => 'Once more, until it\'s “good”';

  @override
  String get hifzNewItem => 'New item';

  @override
  String get hifzGradePrompt => 'How well did you recall it?';

  @override
  String get hifzGrade0 => 'Blank';

  @override
  String get hifzGrade0Hint => 'Couldn\'t recall anything';

  @override
  String get hifzGrade1 => 'Wrong';

  @override
  String get hifzGrade1Hint => 'Wrong; recognised it when shown';

  @override
  String get hifzGrade2 => 'Almost';

  @override
  String get hifzGrade2Hint => 'Wrong, but it seemed easy once shown';

  @override
  String get hifzGrade3 => 'Hard';

  @override
  String get hifzGrade3Hint => 'Correct, with serious effort';

  @override
  String get hifzGrade4 => 'Good';

  @override
  String get hifzGrade4Hint => 'Correct after a little hesitation';

  @override
  String get hifzGrade5 => 'Perfect';

  @override
  String get hifzGrade5Hint => 'Correct, without hesitation';

  @override
  String get hifzUndoGrade => 'Undo grade';

  @override
  String hifzNextReview(String when) {
    return 'Next review $when';
  }

  @override
  String get hifzFinish => 'Finish';

  @override
  String get hifzSummaryTitle => 'Review complete';

  @override
  String get hifzSummarySubtitle =>
      '“The best of you are those who learn the Quran and teach it”';

  @override
  String get hifzSummaryReviewed => 'Reviewed';

  @override
  String get hifzSummaryNew => 'New';

  @override
  String get hifzSummaryAgain => 'Repeated';

  @override
  String get hifzSummaryRecall => 'Recalled';

  @override
  String hifzSummaryTomorrow(String count) {
    return 'Tomorrow: $count';
  }

  @override
  String get hifzSummaryDone => 'Done';

  @override
  String get hifzEmptySession => 'Nothing to review right now';

  @override
  String get hifzEmptyTitle => 'Begin your Hifz';

  @override
  String get hifzEmptyBody =>
      'Add ayat or a hadith — spaced repetition brings them back before they fade.';

  @override
  String get hifzEmptyDue => 'Nothing due today';

  @override
  String get hifzEmptyNew => 'No new items waiting';

  @override
  String get hifzEmptyLearned => 'Items appear here after their first review';

  @override
  String get hifzSettingsTitle => 'Hifz settings';

  @override
  String get hifzNewPerDay => 'New items a day';

  @override
  String get hifzListenRepeat => 'Listening repeats per ayah';

  @override
  String hifzHadithNumber(String n) {
    return 'Hadith $n';
  }

  @override
  String hifzHadithSource(String collection, String n) {
    return '$collection · $n';
  }

  @override
  String get hifzCatalogError => 'Couldn\'t load the Quran data';

  @override
  String hifzEase(String value) {
    return 'Ease $value';
  }

  @override
  String get hifzEveryDay => 'Every day';

  @override
  String hifzInterval(String days) {
    return 'Every $days';
  }

  @override
  String get hifzOpenAll => 'All items';

  @override
  String get hifzStartCta => 'Start memorising';

  @override
  String get qiblaTitle => 'Qibla';

  @override
  String get qiblaFacing => 'You\'re facing the qibla';

  @override
  String qiblaTurnRight(String degrees) {
    return 'Turn right $degrees';
  }

  @override
  String qiblaTurnLeft(String degrees) {
    return 'Turn left $degrees';
  }

  @override
  String get qiblaReading => 'Reading the compass…';

  @override
  String get qiblaHoldFlat => 'Hold the phone flat in front of you';

  @override
  String get qiblaBearing => 'Qibla bearing';

  @override
  String get qiblaDistance => 'To the Kaaba';

  @override
  String qiblaKm(String distance) {
    return '$distance km';
  }

  @override
  String get qiblaYourHeading => 'Your heading';

  @override
  String get qiblaSunBearing => 'Sun bearing';

  @override
  String qiblaDeclination(String value, String direction) {
    return 'Magnetic declination here is $value $direction; corrected automatically with the World Magnetic Model.';
  }

  @override
  String get qiblaEast => 'east';

  @override
  String get qiblaWest => 'west';

  @override
  String get qiblaAccuracyHigh => 'High accuracy';

  @override
  String get qiblaAccuracyMedium => 'Medium accuracy';

  @override
  String get qiblaAccuracyLow => 'Low accuracy';

  @override
  String get qiblaAccuracyUnreliable => 'Unreliable reading';

  @override
  String qiblaAccuracyChip(String level, String error) {
    return '$level · $error';
  }

  @override
  String get qiblaCalibrateTitle => 'Calibrate the compass';

  @override
  String qiblaCalibrateBody(String eight) {
    return 'Move the phone through the air in a figure-$eight a few times, away from metal and magnets.';
  }

  @override
  String qiblaInterferenceBody(String eight) {
    return 'The magnetic field here is disturbed: step away from metal, electronics and magnets (magnetic phone cases too), then move the phone in a figure-$eight.';
  }

  @override
  String get qiblaCalibrateLater => 'Later';

  @override
  String get qiblaCalibrated => 'Compass calibrated';

  @override
  String get qiblaCalibrateAction => 'Calibrate';

  @override
  String get qiblaSunTitle => 'Sun compass';

  @override
  String get qiblaSunHowTo =>
      'Face the sun and point the top of your phone at it, without looking straight at it; the golden needle then points to the qibla.';

  @override
  String qiblaSunRightOf(String degrees) {
    return 'Qibla: $degrees right of the sun';
  }

  @override
  String qiblaSunLeftOf(String degrees) {
    return 'Qibla: $degrees left of the sun';
  }

  @override
  String get qiblaSunAhead => 'The qibla lies straight toward the sun';

  @override
  String get qiblaSunHigh =>
      'The sun is high now, so aiming at it is less precise.';

  @override
  String get qiblaDiagramTitle => 'Bearing diagram';

  @override
  String qiblaDiagramHowTo(String degrees) {
    return 'Find north with a compass, or at night by the Pole Star, then turn $degrees clockwise.';
  }

  @override
  String qiblaDiagramHowToSouth(String degrees) {
    return 'Find north with a compass, or at night from the Southern Cross, which points south; then turn $degrees clockwise from north.';
  }

  @override
  String get qiblaNoSensor => 'This phone has no compass (magnetometer).';

  @override
  String get qiblaSensorError => 'The compass could not be read.';

  @override
  String get qiblaNoReadings => 'The compass isn\'t responding.';

  @override
  String get qiblaUseSun => 'Use the sun';

  @override
  String get qiblaUseCompass => 'Back to the compass';

  @override
  String get qiblaRetry => 'Try again';

  @override
  String get qiblaAtKaaba => 'You\'re at the Kaaba itself — face it directly.';

  @override
  String get qiblaCardTitle => 'Qibla direction';

  @override
  String get qiblaCardOpen => 'Open the compass';

  @override
  String qiblaFromPlace(String place) {
    return 'From $place';
  }

  @override
  String get qiblaPointN => 'N';

  @override
  String get qiblaPointNE => 'NE';

  @override
  String get qiblaPointE => 'E';

  @override
  String get qiblaPointSE => 'SE';

  @override
  String get qiblaPointS => 'S';

  @override
  String get qiblaPointSW => 'SW';

  @override
  String get qiblaPointW => 'W';

  @override
  String get qiblaPointNW => 'NW';

  @override
  String get qiblaPointNameN => 'north';

  @override
  String get qiblaPointNameNE => 'north-east';

  @override
  String get qiblaPointNameE => 'east';

  @override
  String get qiblaPointNameSE => 'south-east';

  @override
  String get qiblaPointNameS => 'south';

  @override
  String get qiblaPointNameSW => 'south-west';

  @override
  String get qiblaPointNameW => 'west';

  @override
  String get qiblaPointNameNW => 'north-west';

  @override
  String qiblaDialLabel(String bearing, String point) {
    return 'Qibla compass: the qibla is at $bearing, toward the $point.';
  }
}
