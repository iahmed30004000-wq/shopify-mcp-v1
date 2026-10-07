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
  String get orbitUiRecenter => 'Reset view';

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
  String get lockHoldHint => 'Unlock Madar with your fingerprint';

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
      'The fingerprint check was interrupted. Try again.';

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

  @override
  String get medsTitle => 'Medications & supplements';

  @override
  String get medsTabToday => 'Today';

  @override
  String get medsTabMeds => 'My meds';

  @override
  String get medsTabCourses => 'Courses';

  @override
  String get medsSettingsOpen => 'Medication settings';

  @override
  String get medsAddMed => 'New medication';

  @override
  String get medsAddCourse => 'New course';

  @override
  String get medsAddRule => 'New timing rule';

  @override
  String get medsKindMedication => 'Medication';

  @override
  String get medsKindSupplement => 'Supplement';

  @override
  String get medsKindInjection => 'Injection';

  @override
  String get medsKindOther => 'Other';

  @override
  String get medsWithEmptyStomach => 'Empty stomach';

  @override
  String get medsWithBreakfast => 'With breakfast';

  @override
  String get medsWithLunch => 'With lunch';

  @override
  String get medsWithDinner => 'With dinner';

  @override
  String get medsWithBedtime => 'At bedtime';

  @override
  String get medsWithOther => 'Other';

  @override
  String get medsWithPerCourse => 'Per course';

  @override
  String get medsWithAnytime => 'Any time';

  @override
  String get medsMealBreakfast => 'breakfast';

  @override
  String get medsMealLunch => 'lunch';

  @override
  String get medsMealDinner => 'dinner';

  @override
  String get medsMealBedtime => 'bedtime';

  @override
  String get medsMealBreakfastTitle => 'Breakfast';

  @override
  String get medsMealLunchTitle => 'Lunch';

  @override
  String get medsMealDinnerTitle => 'Dinner';

  @override
  String get medsMealBedtimeTitle => 'Bedtime';

  @override
  String medsAnchorAtPrayer(String place) {
    return 'At $place';
  }

  @override
  String medsAnchorWithMeal(String place) {
    return 'With $place';
  }

  @override
  String medsAnchorBefore(String place, String duration) {
    return '$duration before $place';
  }

  @override
  String medsAnchorAfter(String place, String duration) {
    return '$duration after $place';
  }

  @override
  String get medsAnchorBedtime => 'At bedtime';

  @override
  String get medsTimes => 'Dose times';

  @override
  String get medsTimesHint =>
      'A fixed time, or one that follows a prayer or a meal and moves with it every day';

  @override
  String get medsAddFixedTime => 'Fixed time';

  @override
  String get medsAddAnchoredTime => 'Prayer or meal';

  @override
  String medsTimeToday(String time) {
    return 'today $time';
  }

  @override
  String get medsRemoveTime => 'Remove time';

  @override
  String get medsOffsetBefore => 'Before';

  @override
  String get medsOffsetAt => 'At';

  @override
  String get medsOffsetAfter => 'After';

  @override
  String get medsAnchorPrayers => 'Prayers';

  @override
  String get medsAnchorMeals => 'Meals';

  @override
  String get medsAnchorPick => 'Follows';

  @override
  String get medsAnchorOffset => 'Timing';

  @override
  String get medsAnchorDone => 'Done';

  @override
  String get medsNoTimesAsNeeded => 'No times: log each dose when you take it';

  @override
  String get medsEditorNew => 'New medication';

  @override
  String get medsEditorEdit => 'Edit medication';

  @override
  String get medsFieldName => 'Name';

  @override
  String get medsFieldNameHint => 'As on the box';

  @override
  String get medsFieldNameRequired => 'Enter a name';

  @override
  String get medsFieldKind => 'Type';

  @override
  String get medsFieldDose => 'Dose';

  @override
  String get medsFieldDoseHint => 'As prescribed, e.g. 10 mg or 2 tablets';

  @override
  String get medsFieldAmount => 'Amount';

  @override
  String get medsFieldUnit => 'Unit';

  @override
  String get medsUnitTab => 'tab';

  @override
  String get medsUnitCap => 'cap';

  @override
  String get medsUnitMg => 'mg';

  @override
  String get medsUnitMl => 'ml';

  @override
  String get medsUnitIu => 'IU';

  @override
  String get medsUnitDrop => 'drop';

  @override
  String get medsUnitPuff => 'puff';

  @override
  String get medsUnitAmp => 'amp';

  @override
  String get medsFieldTakenWith => 'Taken';

  @override
  String get medsFieldTakenWithNote => 'Details';

  @override
  String get medsFieldNotes => 'Notes';

  @override
  String get medsFieldStock => 'Units left';

  @override
  String get medsFieldRefillAt => 'Alert me at';

  @override
  String get medsStockHint => 'Goes down with every Taken by the dose';

  @override
  String get medsFieldColor => 'Colour';

  @override
  String get medsFieldActive => 'Active';

  @override
  String get medsFieldActiveHint => 'Pause it without losing its history';

  @override
  String get medsFieldCourse => 'Course';

  @override
  String get medsNoCourse => 'No course';

  @override
  String get medsCourseLinkedHint => 'Its doses follow the course’s phases';

  @override
  String get medsTitration => 'Titration';

  @override
  String get medsTitrationHint =>
      'The dose your doctor set for each period, from date to date';

  @override
  String get medsTitrationAdd => 'Add step';

  @override
  String medsTitrationFrom(String date) {
    return 'From $date';
  }

  @override
  String get medsTitrationStop => 'Stop';

  @override
  String get medsTitrationStopLine => 'Doses stop';

  @override
  String get medsTitrationStepDose => 'Dose from this date';

  @override
  String get medsTitrationStepTitle => 'Titration step';

  @override
  String get medsTitrationNow => 'Current';

  @override
  String get medsSave => 'Save';

  @override
  String get medsDelete => 'Delete';

  @override
  String get medsMore => 'More details';

  @override
  String get medsTodayHeader => 'Today’s doses';

  @override
  String medsTodayCount(String taken, String total) {
    return '$taken of $total taken';
  }

  @override
  String medsNextDose(String name, String time) {
    return 'Next: $name · $time';
  }

  @override
  String medsDueNowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count doses waiting now',
      one: '1 dose waiting now',
    );
    return '$_temp0';
  }

  @override
  String get medsAllAnswered => 'Every dose of today is answered';

  @override
  String get medsNoDosesToday => 'No doses scheduled today';

  @override
  String get medsEmptyTitle => 'No medications yet';

  @override
  String get medsEmptyBody =>
      'Add a medication or supplement with its times; Madar arranges the doses around your prayers and meals.';

  @override
  String get medsAsNeeded => 'As needed';

  @override
  String get medsLogNow => 'Log a dose now';

  @override
  String get medsAnytimeGroup => 'No window';

  @override
  String get medsStateUpcoming => 'Upcoming';

  @override
  String get medsStateDue => 'Due now';

  @override
  String get medsStateLate => 'Late';

  @override
  String get medsStateMissed => 'Missed';

  @override
  String medsStateTakenAt(String time) {
    return 'Taken $time';
  }

  @override
  String get medsStateSkipped => 'Skipped';

  @override
  String medsStateSnoozedUntil(String time) {
    return 'Snoozed until $time';
  }

  @override
  String get medsTake => 'Taken';

  @override
  String get medsSnooze => 'Snooze';

  @override
  String medsSnoozeFor(String duration) {
    return 'Snooze $duration';
  }

  @override
  String get medsSkip => 'Skip';

  @override
  String get medsReset => 'Clear answer';

  @override
  String medsTookToast(String name) {
    return '$name logged as taken';
  }

  @override
  String medsSkippedToast(String name) {
    return '$name skipped';
  }

  @override
  String medsSnoozedToast(String name, String time) {
    return '$name snoozed until $time';
  }

  @override
  String get medsResetToast => 'Answer cleared';

  @override
  String medsShiftedLater(String duration) {
    return 'Moved $duration later by a timing rule';
  }

  @override
  String medsShiftedEarlier(String duration) {
    return 'Moved $duration earlier by a timing rule';
  }

  @override
  String get medsPinnedToMeal => 'Set by food timing';

  @override
  String get medsPastMidnight => 'after midnight';

  @override
  String medsPartOfCourse(String name) {
    return 'Part of $name';
  }

  @override
  String medsDoseSemantics(
    String name,
    String dose,
    String time,
    String state,
  ) {
    return '$name, $dose, $time, $state';
  }

  @override
  String medsRefillBanner(String name, String count) {
    return '$name: $count left — time to refill';
  }

  @override
  String get medsRefilled => 'Refilled';

  @override
  String medsRefillSheetTitle(String name) {
    return 'Refill $name';
  }

  @override
  String get medsRefillAdded => 'Units added';

  @override
  String medsStockUpdated(String name) {
    return '$name stock updated';
  }

  @override
  String medsStockLine(String count) {
    return '$count left';
  }

  @override
  String medsRefillAtLine(String count) {
    return 'alert at $count';
  }

  @override
  String get medsLowStock => 'Running low';

  @override
  String get medsConflictsTitle => 'Rules not met';

  @override
  String medsConflictSeparation(
    String a,
    String b,
    String required,
    String actual,
  ) {
    return 'Couldn’t keep $required between $a and $b; they are $actual apart.';
  }

  @override
  String medsConflictNoMeal(String name) {
    return 'No free meal for an extra dose of $name; it keeps its time.';
  }

  @override
  String medsConflictClash(String name) {
    return '$name has two different food rules; the first one applies.';
  }

  @override
  String get medsAtTheSameTime => 'at the same time';

  @override
  String get medsAlertsTitle => 'Standing alerts';

  @override
  String get medsAdherence => 'Adherence';

  @override
  String medsAdherenceRate(String percent) {
    return '$percent of doses taken';
  }

  @override
  String medsLastDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Last $count days',
      one: 'Last day',
    );
    return '$_temp0';
  }

  @override
  String get medsNoAdherence => 'No doses were due in this period';

  @override
  String get medsStatTaken => 'Taken';

  @override
  String get medsStatSkipped => 'Skipped';

  @override
  String get medsStatMissed => 'Missed';

  @override
  String get medsStatLate => 'Late';

  @override
  String medsStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count full days in a row',
      one: '1 full day',
      zero: 'No full days in a row yet',
    );
    return '$_temp0';
  }

  @override
  String medsDayBarSemantics(String date, String taken, String total) {
    return '$date: $taken of $total';
  }

  @override
  String medsDayNothingDue(String date) {
    return '$date: no doses';
  }

  @override
  String get medsHistory => 'History';

  @override
  String medsHistoryTitle(String name) {
    return '$name history';
  }

  @override
  String get medsNoHistory => 'No history yet';

  @override
  String get medsOffSchedule => 'Off schedule';

  @override
  String get medsRecent => 'Recent doses';

  @override
  String get medsPaused => 'Paused';

  @override
  String get medsPausedSection => 'Paused';

  @override
  String get medsPause => 'Pause';

  @override
  String get medsResume => 'Resume';

  @override
  String get medsDuplicate => 'Duplicate';

  @override
  String get medsEdit => 'Edit';

  @override
  String medsDeletedToast(String name) {
    return '$name deleted';
  }

  @override
  String medsPausedToast(String name) {
    return '$name paused';
  }

  @override
  String medsResumedToast(String name) {
    return '$name resumed';
  }

  @override
  String medsDuplicatedToast(String name) {
    return '$name duplicated';
  }

  @override
  String medsCopyName(String name) {
    return '$name (copy)';
  }

  @override
  String medsTimesPerDay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count times a day',
      two: 'Twice a day',
      one: 'Once a day',
      zero: 'No times',
    );
    return '$_temp0';
  }

  @override
  String get medsRulesTitle => 'Timing rules';

  @override
  String get medsRulesEmpty =>
      'Rules keep doses on the timing you set: a gap between two medicines, or a time before or after food.';

  @override
  String get medsRuleKindSeparate => 'Gap between two';

  @override
  String get medsRuleKindNotWith => 'Not together';

  @override
  String get medsRuleKindBeforeFood => 'Before food';

  @override
  String get medsRuleKindAfterFood => 'After food';

  @override
  String get medsRuleKindWithFood => 'With food';

  @override
  String get medsRuleKindCustom => 'Note';

  @override
  String medsRuleSeparateText(String a, String b, String duration) {
    return 'At least $duration between $a and $b';
  }

  @override
  String medsRuleBeforeFoodText(String a, String duration) {
    return '$a $duration before food';
  }

  @override
  String medsRuleAfterFoodText(String a, String duration) {
    return '$a $duration after food';
  }

  @override
  String medsRuleWithFoodText(String a) {
    return '$a with food';
  }

  @override
  String medsRuleCustomText(String a, String note) {
    return '$a: $note';
  }

  @override
  String get medsRuleEditorNew => 'New timing rule';

  @override
  String get medsRuleEditorEdit => 'Edit rule';

  @override
  String get medsRuleKind => 'Rule';

  @override
  String get medsRuleMedA => 'Medication';

  @override
  String get medsRuleMedB => 'And the other';

  @override
  String get medsRuleMinutes => 'Time';

  @override
  String get medsRuleNote => 'Note';

  @override
  String get medsRuleNeedTwo => 'Pick two different medications';

  @override
  String get medsRuleNeedMed => 'Pick the medication';

  @override
  String get medsRuleNeedMeds => 'Add a medication first';

  @override
  String get medsRuleNeedNote => 'Write the note';

  @override
  String get medsRuleFoodHint =>
      'Food times come from your meal times in settings';

  @override
  String get medsRuleDeleted => 'Rule deleted';

  @override
  String get medsCoursesEmptyTitle => 'No courses';

  @override
  String get medsCoursesEmptyBody =>
      'For injections and treatments in phases, like daily, then weekly, then monthly.';

  @override
  String get medsCourseEditorNew => 'New course';

  @override
  String get medsCourseEditorEdit => 'Edit course';

  @override
  String get medsCourseName => 'Course name';

  @override
  String get medsCourseNameRequired => 'Enter a name';

  @override
  String get medsCourseMed => 'Medication';

  @override
  String get medsCourseStart => 'Start date';

  @override
  String get medsCoursePhases => 'Phases';

  @override
  String get medsCourseAddPhase => 'Add phase';

  @override
  String medsCoursePhaseN(String n) {
    return 'Phase $n';
  }

  @override
  String get medsCourseNeedsPhase => 'Add at least one phase';

  @override
  String get medsFreqDaily => 'Daily';

  @override
  String get medsFreqWeekly => 'Weekly';

  @override
  String get medsFreqMonthly => 'Monthly';

  @override
  String medsEveryDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count days',
      two: 'Every other day',
      one: 'Daily',
    );
    return '$_temp0';
  }

  @override
  String medsEveryWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count weeks',
      one: 'Weekly',
    );
    return '$_temp0';
  }

  @override
  String medsEveryMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count months',
      one: 'Monthly',
    );
    return '$_temp0';
  }

  @override
  String get medsPhaseInterval => 'Every';

  @override
  String get medsPhaseCount => 'Doses';

  @override
  String get medsPhaseOngoing => 'Ongoing';

  @override
  String get medsPhaseDose => 'Phase dose';

  @override
  String medsPhaseTimes(String freq, String count) {
    return '$freq × $count';
  }

  @override
  String medsPhaseOngoingLine(String freq) {
    return '$freq, ongoing';
  }

  @override
  String medsCourseDoneOf(String done, String total) {
    return '$done of $total doses';
  }

  @override
  String medsCourseDosesSoFar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count doses so far',
      one: '1 dose so far',
      zero: 'No doses yet',
    );
    return '$_temp0';
  }

  @override
  String medsCoursePhaseProgress(String phase, String done, String total) {
    return 'Phase $phase: $done of $total';
  }

  @override
  String medsCoursePhaseOngoingProgress(String phase) {
    return 'Phase $phase (ongoing)';
  }

  @override
  String medsCourseNext(String date) {
    return 'Next dose $date';
  }

  @override
  String medsCourseStarts(String date) {
    return 'Starts $date';
  }

  @override
  String medsCourseFinished(String date) {
    return 'Completed on $date';
  }

  @override
  String get medsCourseNoMed => 'Link a medication to schedule its doses';

  @override
  String get medsCourseDeleted => 'Course deleted';

  @override
  String get medsCoursePaused => 'Paused';

  @override
  String get medsCourseActive => 'Course active';

  @override
  String get medsCourseTimeline => 'Course dates';

  @override
  String medsCourseMoreDates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'and $count more dates',
      one: 'and 1 more date',
    );
    return '$_temp0';
  }

  @override
  String get medsToday => 'Today';

  @override
  String get medsSettingsTitle => 'Medication settings';

  @override
  String get medsMealTimes => 'Meal times';

  @override
  String get medsMealTimesHint =>
      'Ties “with breakfast” and food rules to your day';

  @override
  String get medsEmptyStomachLead => '“Empty stomach”: time before breakfast';

  @override
  String get medsReminders => 'Dose reminders';

  @override
  String get medsRemindersHint =>
      'A notification at each dose with Taken, Snooze and Skip';

  @override
  String get medsSnoozeDefault => 'Notification snooze';

  @override
  String get medsLateAfter => 'Counts as late after';

  @override
  String get medsNotifyGroup => 'Medications';

  @override
  String get medsNotifyChannel => 'Dose times';

  @override
  String get medsNotifyChannelDescription =>
      'A reminder at each dose, with Taken, Snooze and Skip';

  @override
  String medsNotifyTitle(String name) {
    return 'Time for $name';
  }

  @override
  String medsNotifyAgainTitle(String name) {
    return 'Reminder: $name';
  }

  @override
  String medsNotifyRefillTitle(String name) {
    return '$name is running low';
  }

  @override
  String medsNotifyRefillBody(String count) {
    return '$count left. Time to refill.';
  }

  @override
  String get medsNotifyFailedTitle => 'The dose wasn’t logged';

  @override
  String get medsNotifyFailedBody => 'Open Madar to log it.';

  @override
  String get recordTitle => 'Medical record';

  @override
  String get recordTabLabs => 'Labs';

  @override
  String get recordTabAppointments => 'Appointments';

  @override
  String get recordTabConditions => 'Conditions';

  @override
  String get recordTabQuestions => 'Questions';

  @override
  String get recordAdd => 'Add';

  @override
  String get recordSave => 'Save';

  @override
  String get recordDelete => 'Delete';

  @override
  String get recordNotes => 'Notes';

  @override
  String get recordDate => 'Date';

  @override
  String get recordTime => 'Time';

  @override
  String get recordListSeparator => ', ';

  @override
  String get recordToday => 'Today';

  @override
  String get recordTomorrow => 'Tomorrow';

  @override
  String get recordYesterday => 'Yesterday';

  @override
  String recordInDays(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'In $n days',
      one: 'In 1 day',
    );
    return '$_temp0';
  }

  @override
  String recordDaysAgo(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get recordDoctorReport => 'Doctor report';

  @override
  String get recordSettingsTitle => 'Record settings';

  @override
  String get recordFlagLow => 'Low';

  @override
  String get recordFlagHigh => 'High';

  @override
  String get recordFlagBorderline => 'Borderline';

  @override
  String get recordFlagBorderlineLow => 'Near low limit';

  @override
  String get recordFlagBorderlineHigh => 'Near high limit';

  @override
  String get recordFlagInRange => 'In range';

  @override
  String get recordFlagNoRange => 'No range';

  @override
  String get recordFlagQualitative => 'Descriptive';

  @override
  String get recordSeverityCritical => 'Critical';

  @override
  String get recordSeverityWarning => 'Caution';

  @override
  String get recordSeverityInfo => 'Note';

  @override
  String recordRangeBetween(String low, String high) {
    return '$low – $high';
  }

  @override
  String recordRangeUpTo(String high) {
    return 'up to $high';
  }

  @override
  String recordRangeAtLeast(String low) {
    return '$low or more';
  }

  @override
  String get recordTakenWithEmptyStomach => 'On an empty stomach';

  @override
  String get recordTakenWithBreakfast => 'With breakfast';

  @override
  String get recordTakenWithLunch => 'With lunch';

  @override
  String get recordTakenWithDinner => 'With dinner';

  @override
  String get recordTakenWithBedtime => 'At bedtime';

  @override
  String get recordTakenWithOther => 'Other';

  @override
  String get recordTakenWithPerCourse => 'Per course';

  @override
  String get recordTakenWithAnytime => 'Any time';

  @override
  String get recordPeriod1m => '1 month';

  @override
  String recordPeriodMonths(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String get recordPeriod12m => '1 year';

  @override
  String get recordPeriodAll => 'All';

  @override
  String get recordSectionAlerts => 'Standing alerts';

  @override
  String get recordSectionConditions => 'Conditions';

  @override
  String get recordSectionMedications => 'Current medications & supplements';

  @override
  String get recordSectionLabs => 'Lab results';

  @override
  String get recordSectionPain => 'Pain summary';

  @override
  String get recordSectionMood => 'Mood & stress summary';

  @override
  String get recordSectionQuestions => 'Questions for the doctor';

  @override
  String recordOffsetWeeks(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n weeks before',
      one: '1 week before',
    );
    return '$_temp0';
  }

  @override
  String recordOffsetDays(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n days before',
      one: '1 day before',
    );
    return '$_temp0';
  }

  @override
  String recordOffsetHours(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n hours before',
      one: '1 hour before',
    );
    return '$_temp0';
  }

  @override
  String recordOffsetMinutes(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n minutes before',
      one: '1 minute before',
    );
    return '$_temp0';
  }

  @override
  String get recordReportTitle => 'Health summary for my doctor';

  @override
  String get recordReportNameLabel => 'Name';

  @override
  String recordReportGenerated(String date) {
    return 'Prepared on $date';
  }

  @override
  String recordReportPeriodLine(String from, String to) {
    return 'Period: $from to $to';
  }

  @override
  String recordReportPeriodAll(String date) {
    return 'Whole record up to $date';
  }

  @override
  String get recordReportFooter =>
      'A personal record kept by the patient on their own device. It contains no diagnosis or treatment advice.';

  @override
  String recordReportPage(String page, String total) {
    return 'Page $page of $total';
  }

  @override
  String get recordReportNothing => 'Nothing recorded for this period.';

  @override
  String recordConditionSince(String date) {
    return 'Since $date';
  }

  @override
  String get recordReportColName => 'Name';

  @override
  String get recordReportColDose => 'Dose';

  @override
  String get recordReportColTimes => 'Times';

  @override
  String get recordReportColWith => 'Taken';

  @override
  String recordReportSupplementName(String name) {
    return '$name · supplement';
  }

  @override
  String get recordReportColTest => 'Test';

  @override
  String get recordReportColLatest => 'Latest';

  @override
  String get recordReportColRange => 'Reference range';

  @override
  String get recordReportColTrend => 'Trend';

  @override
  String get recordReportColHistory => 'Earlier results';

  @override
  String recordReportLabLegend(String margin) {
    return 'Each result is compared with the reference range I entered for the test. “Borderline” means within range and within $margin of its width from a limit.';
  }

  @override
  String get recordReportEntries => 'Entries';

  @override
  String get recordReportDaysLogged => 'Days with an entry';

  @override
  String recordReportPainAverage(String max) {
    return 'Average score out of $max';
  }

  @override
  String get recordReportPainHighest => 'Highest score recorded';

  @override
  String get recordReportTopLocations => 'Most frequent locations';

  @override
  String get recordReportTopTriggers => 'Most frequent triggers';

  @override
  String recordReportMoodAverage(String max) {
    return 'Average mood out of $max';
  }

  @override
  String recordReportStressAverage(String max) {
    return 'Average stress out of $max';
  }

  @override
  String recordReportAnxietyAverage(String max) {
    return 'Average anxiety out of $max';
  }

  @override
  String recordReportEnergyAverage(String max) {
    return 'Average energy out of $max';
  }

  @override
  String get recordReportSleepAverage => 'Average hours of sleep';

  @override
  String get recordReportCaffeineAverage => 'Average cups of caffeine';

  @override
  String get recordReportTopFactors => 'Most frequent factors';

  @override
  String recordReportQuestionFor(String title, String date) {
    return 'For $title on $date';
  }

  @override
  String get recordLabUncategorized => 'Other';

  @override
  String recordReminderTitle(String title) {
    return 'Appointment: $title';
  }

  @override
  String recordReminderIn(String duration) {
    return 'In $duration';
  }

  @override
  String get recordReminderGroup => 'Health';

  @override
  String get recordReminderChannelName => 'Doctor appointments';

  @override
  String get recordReminderChannelDescription =>
      'Reminders before your medical appointments';

  @override
  String recordDateAtTime(String date, String time) {
    return '$date at $time';
  }

  @override
  String get recordSavedToast => 'Changes saved';

  @override
  String get recordReorder => 'Reorder';

  @override
  String get recordReorderDone => 'Done reordering';

  @override
  String get recordReordered => 'Order changed';

  @override
  String get recordAlertAdd => 'Add a standing alert';

  @override
  String get recordAlertEdit => 'Edit alert';

  @override
  String get recordAlertSubtitle => 'What any doctor should know first';

  @override
  String get recordAlertBody => 'Alert';

  @override
  String get recordAlertBodyHint => 'e.g. Allergic to penicillin';

  @override
  String get recordAlertSeverity => 'Importance';

  @override
  String get recordAlertPinned => 'Pinned at the top of Health';

  @override
  String get recordAlertPinnedHint => 'Always shown above the health screens';

  @override
  String get recordAlertUnpin => 'Unpin';

  @override
  String get recordAlertAdded => 'Alert added';

  @override
  String get recordAlertDeleted => 'Alert deleted';

  @override
  String get recordAlertPinnedToast => 'Alert pinned';

  @override
  String get recordAlertUnpinnedToast => 'Alert unpinned';

  @override
  String get recordAlertsManage => 'Manage';

  @override
  String get recordAlertsManagerSubtitle =>
      'Drag to order them; pin the ones to keep in sight';

  @override
  String get recordAlertsEmptyHint =>
      'An allergy, a drug to avoid, or anything no doctor should miss.';

  @override
  String recordAlertsMore(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n more alerts',
      one: '1 more alert',
    );
    return '$_temp0';
  }

  @override
  String get recordConditionAdd => 'Add condition';

  @override
  String get recordConditionEdit => 'Edit condition';

  @override
  String get recordConditionName => 'Condition';

  @override
  String get recordConditionSinceLabel => 'Since';

  @override
  String get recordConditionActive => 'Currently active';

  @override
  String get recordConditionInactive => 'Inactive';

  @override
  String get recordConditionMarkInactive => 'Mark inactive';

  @override
  String get recordConditionMarkActive => 'Mark active';

  @override
  String get recordConditionMarkedInactive => 'Condition marked inactive';

  @override
  String get recordConditionMarkedActive => 'Condition marked active';

  @override
  String get recordConditionAdded => 'Condition added';

  @override
  String get recordConditionDeleted => 'Condition deleted';

  @override
  String get recordConditionsEmpty => 'No conditions yet';

  @override
  String get recordConditionsEmptyBody =>
      'Record your conditions with when they started and your notes, ready for any visit.';

  @override
  String get recordConditionsInactiveHeader => 'Inactive conditions';

  @override
  String get recordLabVisit => 'Lab visit';

  @override
  String get recordLabVisitSubtitle => 'Several results on one date';

  @override
  String get recordLabVisitDate => 'Test date';

  @override
  String get recordLabVisitSaveNone => 'Enter at least one result';

  @override
  String recordLabVisitSave(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Save $n results',
      one: 'Save 1 result',
    );
    return '$_temp0';
  }

  @override
  String recordLabVisitSaved(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n results saved',
      one: '1 result saved',
    );
    return '$_temp0';
  }

  @override
  String get recordLabAddTest => 'New test';

  @override
  String get recordLabEditTest => 'Edit test';

  @override
  String get recordLabTestSubtitle =>
      'Enter the reference range as printed by your lab';

  @override
  String get recordLabTestName => 'Test name';

  @override
  String get recordLabUnit => 'Unit';

  @override
  String get recordLabUnitHint => 'e.g. mg/dL';

  @override
  String get recordLabLow => 'Range low limit';

  @override
  String get recordLabHigh => 'Range high limit';

  @override
  String get recordLabRangeInvalid => 'The low limit is above the high limit';

  @override
  String get recordLabCategory => 'Category';

  @override
  String get recordLabTestAdded => 'Test added';

  @override
  String get recordLabTestDeleted => 'Test and its results deleted';

  @override
  String get recordLabTestGone => 'This test no longer exists';

  @override
  String get recordLabAddReading => 'Add result';

  @override
  String get recordLabEditReading => 'Edit result';

  @override
  String get recordLabValue => 'Result';

  @override
  String recordLabValueWithUnit(String unit) {
    return 'Result in $unit';
  }

  @override
  String get recordLabValueHint => 'A number, or a word such as “negative”';

  @override
  String get recordLabNote => 'Note';

  @override
  String get recordLabReadingAdded => 'Result added';

  @override
  String get recordLabReadingDeleted => 'Result deleted';

  @override
  String get recordLabsEmpty => 'No lab tests yet';

  @override
  String get recordLabsEmptyBody =>
      'Set up your tests once with their reference ranges, then log each visit to see their course.';

  @override
  String get recordLabNoReadings => 'No results';

  @override
  String get recordLabNoReadingsBody =>
      'No results recorded for this test yet.';

  @override
  String get recordLabNoRange => 'No reference range';

  @override
  String get recordLabRangeLabel => 'Reference range';

  @override
  String get recordLabLatest => 'Latest result';

  @override
  String recordLabChange(String delta) {
    return '$delta since the previous result';
  }

  @override
  String get recordLabHistory => 'All results';

  @override
  String get recordLabChartEmpty => 'No numeric results in this period';

  @override
  String recordLabChartSemantics(String name, int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name trend: $n results',
      one: '$name trend: 1 result',
    );
    return '$_temp0';
  }

  @override
  String recordLabReadingsCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n results',
      one: '1 result',
      zero: 'No results',
    );
    return '$_temp0';
  }

  @override
  String recordLabTestsCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n tests',
      one: '1 test',
    );
    return '$_temp0';
  }

  @override
  String recordLabMarginNote(String margin) {
    return '“Borderline” means within range and within $margin of its width from a limit. You can change the share in record settings.';
  }

  @override
  String get recordLabFlagsTitle => 'Lab results';

  @override
  String recordLabFlaggedCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n outside or near their range',
      one: '1 outside or near its range',
    );
    return '$_temp0';
  }

  @override
  String get recordLabAllInRange =>
      'Your latest results are all within the ranges you entered.';

  @override
  String get recordAppointmentsTitle => 'Medical appointments';

  @override
  String get recordAppointmentAdd => 'New appointment';

  @override
  String get recordAppointmentEdit => 'Edit appointment';

  @override
  String get recordAppointmentTitleField => 'Appointment';

  @override
  String get recordAppointmentTitleHint => 'e.g. Routine check-up';

  @override
  String get recordAppointmentDoctor => 'Doctor';

  @override
  String get recordAppointmentPlace => 'Place';

  @override
  String get recordAppointmentDone => 'Done';

  @override
  String get recordAppointmentMarkDone => 'Mark as done';

  @override
  String get recordAppointmentMarkUndone => 'Mark as not done';

  @override
  String get recordAppointmentDoneToast => 'Appointment marked done';

  @override
  String get recordAppointmentUndoneToast => 'Appointment marked not done';

  @override
  String get recordAppointmentAdded => 'Appointment added';

  @override
  String get recordAppointmentDeleted =>
      'Appointment deleted; its questions were kept';

  @override
  String get recordAppointmentUpcoming => 'Upcoming';

  @override
  String get recordAppointmentPast => 'Past';

  @override
  String get recordAppointmentShowAll => 'All appointments';

  @override
  String get recordAppointmentsEmpty => 'No upcoming appointments';

  @override
  String get recordAppointmentsEmptyBody =>
      'Add your next appointment to get a reminder before it, with your questions kept alongside.';

  @override
  String get recordNextAppointment => 'Next appointment';

  @override
  String recordAppointmentQuestions(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n questions waiting',
      one: '1 question waiting',
    );
    return '$_temp0';
  }

  @override
  String get recordQuestionAdd => 'New question';

  @override
  String get recordQuestionAddForVisit => 'Add a question for this visit';

  @override
  String get recordQuestionEdit => 'Edit question';

  @override
  String get recordQuestionField => 'Question';

  @override
  String get recordQuestionAppointment => 'For which appointment?';

  @override
  String get recordQuestionGeneral => 'General';

  @override
  String get recordQuestionAnswered => 'Answered';

  @override
  String get recordQuestionAnswer => 'Answer';

  @override
  String get recordQuestionAnswerOptional => 'Answer (optional)';

  @override
  String get recordQuestionMarkAnswered => 'Mark answered';

  @override
  String get recordQuestionReopen => 'Reopen question';

  @override
  String get recordQuestionAdded => 'Question added';

  @override
  String get recordQuestionDeleted => 'Question deleted';

  @override
  String get recordQuestionAnsweredToast => 'Answer recorded';

  @override
  String get recordQuestionReopened => 'Question reopened';

  @override
  String get recordQuestionsEmpty => 'No questions yet';

  @override
  String get recordQuestionsEmptyBody =>
      'Jot down what to ask when it comes to mind, so it is not lost in the clinic.';

  @override
  String get recordQuestionsGeneralHeader => 'General questions';

  @override
  String get recordQuestionsAnsweredHeader => 'Answered';

  @override
  String recordQuestionsMore(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'and $n more',
      one: 'and 1 more',
    );
    return '$_temp0';
  }

  @override
  String get recordReportSheetSubtitle => 'A tidy PDF to print or share';

  @override
  String get recordReportNameField => 'Name on the report';

  @override
  String get recordReportNameHint => 'Printed only, not stored';

  @override
  String get recordReportRememberName => 'Remember the name';

  @override
  String get recordReportRememberHint => 'Kept on this device only';

  @override
  String get recordReportPeriodField => 'Period';

  @override
  String get recordReportSectionsField => 'Sections';

  @override
  String get recordReportPrivacyNote =>
      'The report is made on your device and leaves it only if you share it.';

  @override
  String get recordReportShare => 'Share';

  @override
  String get recordReportSave => 'Save file';

  @override
  String get recordReportBuilding => 'Preparing the report…';

  @override
  String get recordReportSaved => 'Report saved';

  @override
  String get recordReportFailed =>
      'Could not prepare the report, please try again';

  @override
  String get recordSettingsMargin => '“Borderline” margin next to each limit';

  @override
  String get recordSettingsReminders => 'Appointment reminders';

  @override
  String get recordSettingsRemindersHint =>
      'A notification before each appointment';

  @override
  String get recordSettingsReminderTimes => 'Remind me';

  @override
  String get wbTitle => 'Wellbeing';

  @override
  String get wbTabToday => 'Today';

  @override
  String get wbTabPain => 'Pain';

  @override
  String get wbTabHabits => 'Habits';

  @override
  String get wbTabWorries => 'Worries';

  @override
  String get wbTabInsights => 'Insights';

  @override
  String get wbAdd => 'Add';

  @override
  String get wbCancel => 'Cancel';

  @override
  String get wbSave => 'Save';

  @override
  String get wbDelete => 'Delete';

  @override
  String get wbEdit => 'Edit';

  @override
  String get wbClose => 'Close';

  @override
  String get wbOpen => 'Open';

  @override
  String get wbEditList => 'Edit list';

  @override
  String get wbShowAll => 'Show all';

  @override
  String get wbShowLess => 'Show less';

  @override
  String get wbNotes => 'Notes';

  @override
  String get wbWhen => 'When';

  @override
  String get wbNow => 'Now';

  @override
  String get wbToday => 'Today';

  @override
  String get wbYesterday => 'Yesterday';

  @override
  String wbDayAtTime(String day, String time) {
    return '$day, $time';
  }

  @override
  String get wbListSeparator => ', ';

  @override
  String get wbLess => 'Less';

  @override
  String get wbMore => 'More';

  @override
  String wbOutOf(String value, String max) {
    return '$value/$max';
  }

  @override
  String wbOutOfMax(String max) {
    return '/ $max';
  }

  @override
  String wbFraction(String done, String total) {
    return '$done/$total';
  }

  @override
  String get wbMetricMood => 'Mood';

  @override
  String get wbMetricStress => 'Stress';

  @override
  String get wbMetricAnxiety => 'Anxiety';

  @override
  String get wbMetricEnergy => 'Energy';

  @override
  String get wbMetricSleep => 'Sleep';

  @override
  String get wbMetricCaffeine => 'Caffeine';

  @override
  String get wbMetricPain => 'Pain';

  @override
  String wbMetricYour(String metric) {
    String _temp0 = intl.Intl.selectLogic(metric, {
      'mood': 'your mood rating',
      'stress': 'your stress',
      'anxiety': 'your anxiety',
      'energy': 'your energy',
      'sleep': 'your sleep',
      'caffeine': 'your caffeine',
      'pain': 'your pain',
      'other': 'the value',
    });
    return '$_temp0';
  }

  @override
  String get wbMood1 => 'Heavy';

  @override
  String get wbMood2 => 'Low';

  @override
  String get wbMood3 => 'Okay';

  @override
  String get wbMood4 => 'Good';

  @override
  String get wbMood5 => 'Bright';

  @override
  String get wbMoodQuestion => 'How are you today?';

  @override
  String get wbCheckInPrompt =>
      'Pick a face for a quick check-in, or log stress, sleep and energy together.';

  @override
  String get wbCheckInFull => 'Full check-in';

  @override
  String get wbCheckInTitle => 'Mood & stress check-in';

  @override
  String get wbCheckInEditTitle => 'Edit check-in';

  @override
  String get wbCheckInSubtitle => 'Everything is optional — log what fits.';

  @override
  String get wbCheckInAnother => 'Another check-in';

  @override
  String get wbCheckedIn => 'Checked in';

  @override
  String get wbTodayCheckIn => 'Today\'s check-in';

  @override
  String get wbCheckInDeleted => 'Check-in deleted';

  @override
  String get wbMoodNotesHint => 'What shaped your day?';

  @override
  String get wbScaleCalm => 'Calm';

  @override
  String get wbScaleVeryHigh => 'Very high';

  @override
  String get wbScaleNone => 'None';

  @override
  String get wbScaleDrained => 'Drained';

  @override
  String get wbScaleFull => 'Full';

  @override
  String get wbSleepHours => 'Sleep';

  @override
  String get wbCaffeine => 'Caffeine cups';

  @override
  String get wbFactors => 'Factors';

  @override
  String wbHours(String n) {
    return '$n h';
  }

  @override
  String wbCups(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n cups',
      one: '1 cup',
      zero: 'No cups',
    );
    return '$_temp0';
  }

  @override
  String wbDaysRange(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String wbDayCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String wbMinutes(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n min',
      one: '1 min',
    );
    return '$_temp0';
  }

  @override
  String wbTimes(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n times',
      two: 'twice',
      one: 'once',
    );
    return '$_temp0';
  }

  @override
  String wbPointsCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n points on the map',
      one: '1 point on the map',
    );
    return '$_temp0';
  }

  @override
  String get wbPainLogTitle => 'Log pain';

  @override
  String get wbPainEditTitle => 'Edit pain log';

  @override
  String get wbPainLogSubtitle => 'From no pain to the worst imaginable';

  @override
  String get wbPainScore => 'Pain score';

  @override
  String get wbPainNone => 'No pain';

  @override
  String get wbPainMild => 'Mild';

  @override
  String get wbPainModerate => 'Moderate';

  @override
  String get wbPainSevere => 'Severe';

  @override
  String get wbPainWorst => 'Worst';

  @override
  String get wbBodyMap => 'Body map';

  @override
  String get wbBodyMapHint =>
      'Tap where it hurts to drop a point; tap it again to remove it.';

  @override
  String wbBodyMapSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Body map, $count points',
      one: 'Body map, 1 point',
      zero: 'Body map, front and back, no points',
    );
    return '$_temp0';
  }

  @override
  String get wbClearPoints => 'Clear points';

  @override
  String get wbFront => 'Front';

  @override
  String get wbBack => 'Back';

  @override
  String get wbLocations => 'Locations';

  @override
  String get wbTriggers => 'Triggers';

  @override
  String get wbPainNotesHint => 'What was it like? What came before?';

  @override
  String get wbPainNowQuestion => 'How much pain right now?';

  @override
  String get wbQuickLog => 'Quick log';

  @override
  String get wbWithDetails => 'With details';

  @override
  String wbPainLogged(String score) {
    return 'Pain $score logged';
  }

  @override
  String get wbPainDeleted => 'Pain log deleted';

  @override
  String get wbPainOverTime => 'Pain over time';

  @override
  String get wbPainChartEmpty =>
      'The chart appears once pain is logged on two days.';

  @override
  String get wbPainDailyMax => 'Daily highest';

  @override
  String get wbPainDailyMean => 'Daily mean';

  @override
  String get wbPainAvgMax => 'Avg high';

  @override
  String get wbPainPeak => 'Peak';

  @override
  String get wbPainDaysLogged => 'Days logged';

  @override
  String get wbWhereItHurt => 'Where it hurt';

  @override
  String get wbHeatEmpty => 'No body-map points in this range yet.';

  @override
  String get wbHeatLess => 'Milder';

  @override
  String get wbHeatMore => 'Stronger';

  @override
  String wbHeatSemantics(String places) {
    return 'Pain map; most frequent: $places';
  }

  @override
  String get wbTriggersFrequent => 'Most frequent triggers';

  @override
  String get wbTriggersEmpty => 'No triggers logged in this range.';

  @override
  String get wbLocationsFrequent => 'Most frequent locations';

  @override
  String get wbLocationsEmpty => 'No locations logged in this range.';

  @override
  String get wbManageTriggers => 'Edit triggers';

  @override
  String get wbManageLocations => 'Edit locations';

  @override
  String get wbHistoryPain => 'Pain log';

  @override
  String get wbPainHistoryEmpty => 'Nothing logged yet.';

  @override
  String get wbLogPain => 'Log pain';

  @override
  String get wbNoPainToday => 'Nothing today';

  @override
  String wbLastPain(String score, String time) {
    return '$score at $time';
  }

  @override
  String get wbRegionLegs => 'Legs';

  @override
  String get wbTagKindLocations => 'Pain locations';

  @override
  String get wbTagKindTriggers => 'Pain triggers';

  @override
  String get wbTagKindFactors => 'Mood factors';

  @override
  String get wbTagKindGeneric => 'Tags';

  @override
  String wbTagAddTitle(String list) {
    return 'Add to $list';
  }

  @override
  String get wbTagName => 'Name';

  @override
  String get wbTagRenameTitle => 'Rename';

  @override
  String wbTagDeleted(String name) {
    return 'Removed “$name”';
  }

  @override
  String get wbTagManagerSubtitle =>
      'Drag to reorder, tap to rename (past entries follow), long-press to delete.';

  @override
  String get wbTagAdd => 'Add an item';

  @override
  String get wbTagEmpty => 'The list is empty — add your own.';

  @override
  String get wbTrends => 'Trends';

  @override
  String get wbTrendsNone =>
      'After a few check-ins, your mood, stress and sleep appear here over time.';

  @override
  String wbTrendsEmpty(String metric) {
    return '$metric appears here once logged on two days.';
  }

  @override
  String wbChartSemantics(String metric, String range) {
    return '$metric chart over $range';
  }

  @override
  String wbAverageOver(String value, String days) {
    return 'Average $value across $days';
  }

  @override
  String get wbFactorsFrequent => 'Most frequent factors';

  @override
  String get wbHistoryCheckIns => 'Past check-ins';

  @override
  String get wbHistoryEmpty =>
      'No check-ins yet — one face is enough to start.';

  @override
  String get wbHabitsToday => 'Today\'s habits';

  @override
  String get wbHabitsSubtitle => 'Small steps you chose for your day.';

  @override
  String get wbHabitsAllDone => 'All done for today.';

  @override
  String wbBestStreakNow(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Longest streak now: $n days',
      one: 'Longest streak now: 1 day',
    );
    return '$_temp0';
  }

  @override
  String wbStreak(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n days in a row',
      one: '1 day in a row',
    );
    return '$_temp0';
  }

  @override
  String get wbStreakNone => 'Start today';

  @override
  String get wbHabitDoneState => 'Done today';

  @override
  String get wbHabitOpenState => 'Not done yet';

  @override
  String get wbHabitPausedState => 'Paused';

  @override
  String get wbHabitMarkDone => 'Done';

  @override
  String get wbHabitUndo => 'Undo';

  @override
  String wbHabitDone(String name) {
    return 'Done: $name';
  }

  @override
  String get wbHabitUndone => 'Unmarked';

  @override
  String get wbHabitPause => 'Pause';

  @override
  String get wbHabitResume => 'Resume';

  @override
  String get wbHabitPaused => 'Habit paused';

  @override
  String get wbHabitResumed => 'Habit resumed';

  @override
  String wbHabitDeleted(String name) {
    return 'Deleted: $name';
  }

  @override
  String get wbHabitEditTitle => 'Edit habit';

  @override
  String get wbHabitAddTitle => 'New habit';

  @override
  String get wbHabitAddSubtitle => 'A small daily step of your own.';

  @override
  String get wbHabitName => 'Habit';

  @override
  String get wbHabitsEmptyTitle => 'No habits yet';

  @override
  String get wbHabitsEmptyBody =>
      'Add small habits you\'d like to keep up daily.';

  @override
  String get wbHabitsHint =>
      'Tap to tick, drag to reorder, long-press for more.';

  @override
  String get wbHabitsShort => 'Habits';

  @override
  String get wbWorriesShort => 'Parked';

  @override
  String get wbWorryWindowTitle => 'Worry window';

  @override
  String get wbWorryWindowExplain =>
      'A short daily time to go through what\'s on your mind. Until then, park worries here and return to them at that time.';

  @override
  String get wbWorryWindowSet => 'Set the window';

  @override
  String get wbWorryWindowEdit => 'Edit window';

  @override
  String get wbWorryWindowEnabled => 'Worry window on';

  @override
  String get wbWorryWindowStart => 'Starts at';

  @override
  String get wbWorryWindowLength => 'Length';

  @override
  String get wbWorryWindowRemind => 'Remind me';

  @override
  String get wbWorryWindowRemindHint => 'A quiet notification when it opens.';

  @override
  String get wbWorryWindowAbout =>
      'Your worries stay on this device only, encrypted.';

  @override
  String wbWorryWindowSummary(String time, String length) {
    return 'Daily at $time · $length';
  }

  @override
  String get wbWorryWindowOff => 'Off';

  @override
  String wbWorryWindowOpenNow(String left) {
    return 'Open now — $left left';
  }

  @override
  String wbWorryWindowOpensIn(String left) {
    return 'Opens in $left';
  }

  @override
  String wbWorryReviewStart(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Review $n worries',
      one: 'Review 1 worry',
    );
    return '$_temp0';
  }

  @override
  String get wbWorryReviewNothing => 'Nothing parked';

  @override
  String get wbWorryParkTitle => 'Park a worry';

  @override
  String get wbWorryParkExplain =>
      'Write it as it is, then let it wait for your window. No need to solve it now.';

  @override
  String get wbWorryParkHint => 'What\'s on your mind?';

  @override
  String get wbWorryPark => 'Park it';

  @override
  String wbWorriesParked(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n parked worries',
      one: '1 parked worry',
      zero: 'Parked worries',
    );
    return '$_temp0';
  }

  @override
  String get wbWorriesNone => 'Nothing parked right now.';

  @override
  String wbWorriesResolved(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n resolved',
      one: '1 resolved',
    );
    return '$_temp0';
  }

  @override
  String wbWorryParkedOn(String date) {
    return 'Parked: $date';
  }

  @override
  String get wbWorryEditTitle => 'Edit worry';

  @override
  String get wbWorryBody => 'Worry';

  @override
  String get wbWorryDeleted => 'Worry deleted';

  @override
  String get wbWorryMarkedResolved => 'Marked resolved';

  @override
  String get wbWorryReopened => 'Moved back to parked';

  @override
  String get wbWorryResolved => 'Resolved';

  @override
  String get wbWorryReopen => 'Park again';

  @override
  String get wbWorryKeep => 'Keep for later';

  @override
  String get wbWorryReviewTitle => 'Worry review';

  @override
  String get wbWorryReviewSubtitle => 'One at a time, no rush.';

  @override
  String wbWorryReviewProgress(String index, String total) {
    return '$index of $total';
  }

  @override
  String get wbWorryReviewQuestion =>
      'Is it resolved, or keep it for another window?';

  @override
  String get wbWorryAddReflection => 'Add a reflection';

  @override
  String get wbWorryReflection => 'Reflection';

  @override
  String get wbWorryReflectionHint => 'How does it look to you now?';

  @override
  String wbWorryEarlierReflection(String text) {
    return 'Earlier: $text';
  }

  @override
  String get wbWorryReviewEmpty => 'Nothing parked to review right now.';

  @override
  String get wbWorryReviewDoneTitle => 'Review done';

  @override
  String wbWorryReviewDoneBody(int count, String n, String resolved) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You reviewed $n worries; $resolved resolved.',
      one: 'You reviewed 1 worry; $resolved resolved.',
    );
    return '$_temp0';
  }

  @override
  String get wbWorryNotifyTitle => 'Your worry window is open';

  @override
  String wbWorryNotifyBody(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n parked worries are waiting.',
      one: '1 parked worry is waiting.',
    );
    return '$_temp0';
  }

  @override
  String get wbWorryNotifyBodyEmpty =>
      'Nothing parked today — a quiet moment for you.';

  @override
  String get wbNotifyGroup => 'Health';

  @override
  String get wbNotifyChannel => 'Worry window';

  @override
  String get wbNotifyChannelDescription =>
      'A quiet reminder when your worry window opens.';

  @override
  String wbInsightsIntro(String days) {
    return 'Neutral observations computed on this device from your own data over the last $days. Numbers to reflect on — no diagnosis, no advice — and two things happening together doesn\'t mean one causes the other.';
  }

  @override
  String get wbInsightsNotYetTitle => 'Insights on the way';

  @override
  String wbInsightsNotYetBody(String needed, String logged) {
    return 'Observations appear once there are at least $needed days of data. You have $logged of $needed.';
  }

  @override
  String get wbInsightsNoneTitle => 'No clear patterns yet';

  @override
  String get wbInsightsNoneBody =>
      'No differences or links clear enough have shown up in your data so far. They\'ll appear here if they do.';

  @override
  String wbInsightBasis(String days) {
    return 'Based on $days of your data';
  }

  @override
  String get wbInsightCorrelationNote =>
      'A correlation describes co-occurrence only, not a cause.';

  @override
  String get wbInsightThoseDays => 'Those days';

  @override
  String get wbInsightOtherDays => 'Other days';

  @override
  String get wbCorrelationOpposite => 'Opposite';

  @override
  String get wbCorrelationNone => 'None';

  @override
  String get wbCorrelationTogether => 'Together';

  @override
  String wbAverages30(String days) {
    return 'Averages, last $days';
  }

  @override
  String wbInsightSplit(
    String condition,
    String comparison,
    String a,
    String b,
  ) {
    return '$condition, $comparison: $a vs $b on other days.';
  }

  @override
  String wbAvgHigher(String metric, String amount) {
    return '$metric averaged $amount higher';
  }

  @override
  String wbAvgLower(String metric, String amount) {
    return '$metric averaged $amount lower';
  }

  @override
  String wbByPoints(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n points',
      one: '1 point',
    );
    return '$_temp0';
  }

  @override
  String wbByPointsFraction(String n) {
    return '$n points';
  }

  @override
  String wbByHours(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String wbByHoursFraction(String n) {
    return '$n hours';
  }

  @override
  String wbWhenSleptUnder(String hours, String days) {
    return 'On days you slept under $hours hours ($days)';
  }

  @override
  String wbWhenCaffeineAtLeast(String cups, String days) {
    return 'On days with $cups or more cups of caffeine ($days)';
  }

  @override
  String wbWhenStressAtLeast(String level, String days) {
    return 'On days your stress was $level or more ($days)';
  }

  @override
  String wbWhenMetricAtLeast(String metric, String level, String days) {
    return 'On days $metric was $level or more ($days)';
  }

  @override
  String wbInsightCorrelation(String when, String then, String r, String days) {
    return '$when, $then (correlation $r over $days).';
  }

  @override
  String wbWhenHigher(String metric) {
    String _temp0 = intl.Intl.selectLogic(metric, {
      'mood': 'On days your mood rating was higher',
      'stress': 'On days your stress was higher',
      'anxiety': 'On days your anxiety was higher',
      'energy': 'On days your energy was higher',
      'sleep': 'On days you slept longer',
      'caffeine': 'On days you had more caffeine',
      'pain': 'On days your pain was stronger',
      'other': 'On days the value was higher',
    });
    return '$_temp0';
  }

  @override
  String wbThenHigher(String metric) {
    String _temp0 = intl.Intl.selectLogic(metric, {
      'mood': 'your mood rating tended to be higher',
      'stress': 'your stress tended to be higher',
      'anxiety': 'your anxiety tended to be higher',
      'energy': 'your energy tended to be higher',
      'sleep': 'your sleep tended to be longer',
      'caffeine': 'you tended to have more caffeine',
      'pain': 'your pain tended to be stronger',
      'other': 'the value tended to be higher',
    });
    return '$_temp0';
  }

  @override
  String wbThenLower(String metric) {
    String _temp0 = intl.Intl.selectLogic(metric, {
      'mood': 'your mood rating tended to be lower',
      'stress': 'your stress tended to be lower',
      'anxiety': 'your anxiety tended to be lower',
      'energy': 'your energy tended to be lower',
      'sleep': 'your sleep tended to be shorter',
      'caffeine': 'you tended to have less caffeine',
      'pain': 'your pain tended to be milder',
      'other': 'the value tended to be lower',
    });
    return '$_temp0';
  }

  @override
  String get wbSupportTitle => 'You\'re not alone';

  @override
  String wbSupportBody(String low, String total) {
    return 'You logged a low mood in $low of your last $total check-ins. If you need urgent help, the emergency line is there around the clock.';
  }

  @override
  String wbSupportCall(String number) {
    return 'Call $number';
  }

  @override
  String get wbSupportHideWeek => 'Hide for a week';

  @override
  String get wbSupportCompact =>
      'You\'ve logged a low mood lately. Emergency help is always there.';

  @override
  String wbDialFailed(String number) {
    return 'Couldn\'t open the dialer. Emergency number: $number';
  }

  @override
  String get wbSettingsTitle => 'Wellbeing settings';

  @override
  String get wbSettingsSubtitle =>
      'Emergency number, worry window, breathing sound';

  @override
  String get wbSettingsSupportNumber => 'Emergency number';

  @override
  String wbSettingsSupportNumberHint(String number) {
    return 'Shown in the support banner. Jordan: $number; change it if you live elsewhere.';
  }

  @override
  String get wbSettingsNumberInvalid => 'Enter a valid number';

  @override
  String wbSettingsResetNumber(String number) {
    return 'Reset to $number';
  }

  @override
  String get wbSettingsBreathingSound => 'Soft breathing sounds';

  @override
  String get wbSettingsBreathingSoundHint =>
      'A light tone at each phase; haptics always play.';

  @override
  String get wbBreathTitle => 'Breathe';

  @override
  String get wbBreatheShort => 'Breathe';

  @override
  String get wbBreath478 => 'Long exhale';

  @override
  String get wbBreathBox => 'Box';

  @override
  String get wbBreathIn => 'Breathe in';

  @override
  String get wbBreathHold => 'Hold';

  @override
  String get wbBreathOut => 'Breathe out';

  @override
  String get wbBreathRest => 'Rest';

  @override
  String wbBreathReady(String rhythm) {
    return 'A $rhythm seconds rhythm. Start when you\'re ready.';
  }

  @override
  String get wbBreathDone => 'Session complete';

  @override
  String wbBreathDoneBody(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You completed $n cycles.',
      one: 'You completed 1 cycle.',
    );
    return '$_temp0';
  }

  @override
  String wbBreathCycle(String index, String total) {
    return 'Cycle $index of $total';
  }

  @override
  String get wbBreathPaused => 'Paused';

  @override
  String get wbBreathCycles => 'Cycles';

  @override
  String get wbBreathStart => 'Start';

  @override
  String get wbBreathAgain => 'Again';

  @override
  String get wbBreathStop => 'End';

  @override
  String get wbBreathPause => 'Pause';

  @override
  String get wbBreathResume => 'Resume';

  @override
  String get wbBreathSoundOn => 'Sound on';

  @override
  String get wbBreathSoundOff => 'Sound off';

  @override
  String get wbBreathGentleNote => 'Go gently — you can stop at any moment.';

  @override
  String get wbTodayCardTitle => 'Wellbeing today';

  @override
  String get healthHubTodayTitle => 'Today\'s care';

  @override
  String get healthHubDoctorTitle => 'With your doctor';

  @override
  String get healthHubRecordAction => 'Record';

  @override
  String get healthHubToolsTitle => 'Health tools';

  @override
  String get healthHubPainTitle => 'Pain right now';

  @override
  String get healthHubPainNone => 'No pain logged today';

  @override
  String healthHubPainToday(int count, String n, String max) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n entries today, highest $max',
      one: '1 entry today, score $max',
    );
    return '$_temp0';
  }

  @override
  String get healthHubPainWhere => 'Details';

  @override
  String get healthHubPainWhereHint =>
      'Full log: where it hurts on the body, triggers and notes';

  @override
  String get healthHubPainLow => 'No pain';

  @override
  String get healthHubPainHigh => 'Worst pain';

  @override
  String healthHubPainLogScore(String score, String max) {
    return 'Log pain $score of $max';
  }

  @override
  String get healthHubQuestionsTitle => 'Questions for your doctor';

  @override
  String healthHubQuestionsCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n open questions',
      one: '1 open question',
    );
    return '$_temp0';
  }

  @override
  String healthHubQuestionFor(String title) {
    return 'For $title';
  }

  @override
  String get healthHubToolMeds => 'Medications';

  @override
  String get healthHubToolMedsHint => 'Doses, courses and timing rules';

  @override
  String get healthHubToolLabs => 'Labs';

  @override
  String get healthHubToolLabsHint =>
      'Results, trends and your reference ranges';

  @override
  String get healthHubToolAppointments => 'Appointments';

  @override
  String get healthHubToolAppointmentsHint =>
      'Upcoming and past appointments and their questions';

  @override
  String get healthHubToolWellbeing => 'Wellbeing';

  @override
  String get healthHubToolWellbeingHint => 'Mood, pain, habits and worries';

  @override
  String get healthHubToolBreathe => 'Breathe';

  @override
  String get healthHubToolBreatheHint => 'Guided breathing at a calm pace';

  @override
  String get healthHubToolReport => 'Doctor summary';

  @override
  String get healthHubToolReportHint => 'A PDF to print or share';

  @override
  String get healthHubSettingsSection => 'Health';

  @override
  String get healthHubSettingsSectionHint =>
      'Medications, appointments and wellbeing – all on your device';

  @override
  String get healthHubSettingsTitle => 'Health settings';

  @override
  String healthHubSettingsRemindersOn(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n reminders on',
      one: '1 reminder on',
      zero: 'Health reminders off',
    );
    return '$_temp0';
  }

  @override
  String healthHubSettingsEntrySummary(String reminders, String number) {
    return '$reminders – emergency $number';
  }

  @override
  String get healthHubSettingsRecordSection => 'Appointments & labs';

  @override
  String get healthHubSettingsMarginHint =>
      'A share of the range you entered for each test; a result within it next to a limit is marked “borderline”.';

  @override
  String get healthHubSettingsReportSection => 'Doctor summary';

  @override
  String get healthHubSettingsReportPeriod => 'Usual period';

  @override
  String get healthHubSettingsReportSections => 'Sections included';

  @override
  String get healthHubSettingsReportSectionsAll => 'All sections';

  @override
  String get healthHubSettingsReportNameNone =>
      'No name kept – typed for each report';

  @override
  String healthHubSettingsReportNameKept(String name) {
    return '$name – on this device only';
  }

  @override
  String get healthHubSettingsReportNameHint =>
      'Leave it empty to keep no name';

  @override
  String healthHubSettingsEmergencyHint(String number) {
    return '$number – shown in the support note when low moods repeat';
  }

  @override
  String get healthHubSettingsDenied =>
      'Madar\'s notifications are off in the phone\'s settings, so reminders won\'t arrive.';

  @override
  String get healthHubSettingsPrivacy =>
      'Everything in Health stays on this device, encrypted. Madar records and shows – it never diagnoses or advises treatment.';

  @override
  String get healthHubSettingsOff => 'Off';

  @override
  String healthHubSettingsWorrySummary(String time, String length) {
    return 'Daily at $time, for $length';
  }

  @override
  String get ledgerTitle => 'Wallets & ledger';

  @override
  String get ledgerNetBalance => 'Net balance';

  @override
  String get ledgerPersonal => 'Personal';

  @override
  String get ledgerBusiness => 'Business';

  @override
  String ledgerApprox(String amount) {
    return '≈ $amount';
  }

  @override
  String get ledgerWallets => 'Wallets';

  @override
  String get ledgerAddWallet => 'New wallet';

  @override
  String ledgerArchivedCount(String count) {
    return 'Archived ($count)';
  }

  @override
  String get ledgerRecent => 'Recent activity';

  @override
  String get ledgerSeeAll => 'See all';

  @override
  String get ledgerCurrencies => 'Currencies & rates';

  @override
  String get ledgerSearch => 'Search transactions';

  @override
  String get ledgerAddTx => 'New transaction';

  @override
  String get ledgerEmptyTitle => 'Start with your first wallet';

  @override
  String get ledgerEmptyBody =>
      'Create a wallet for every place your money lives: cash, a bank account, or cash held by a courier.';

  @override
  String get ledgerNoTxTitle => 'No transactions yet';

  @override
  String get ledgerNoTxBody =>
      'Record an expense or income and it shows up here.';

  @override
  String get ledgerNoResults => 'No matching transactions';

  @override
  String get ledgerNoResultsBody => 'Try another word or remove some filters.';

  @override
  String ledgerMissingRate(String codes) {
    return 'No exchange rate, left out of the total: $codes';
  }

  @override
  String get ledgerRatesDefaults =>
      'Exchange rates are still rough defaults. Review them for accurate totals.';

  @override
  String get ledgerReview => 'Review';

  @override
  String get ledgerKindExpense => 'Expense';

  @override
  String get ledgerKindIncome => 'Income';

  @override
  String get ledgerKindTransfer => 'Transfer';

  @override
  String get ledgerKindAdjustment => 'Adjustment';

  @override
  String get ledgerToday => 'Today';

  @override
  String get ledgerYesterday => 'Yesterday';

  @override
  String ledgerTransferRoute(String from, String to) {
    return '$from → $to';
  }

  @override
  String ledgerTransferOut(String wallet) {
    return 'Transfer to $wallet';
  }

  @override
  String ledgerTransferIn(String wallet) {
    return 'Transfer from $wallet';
  }

  @override
  String get ledgerAdjustmentTitle => 'Balance adjustment';

  @override
  String get ledgerUnassigned => 'No budget item';

  @override
  String ledgerBalanceAfter(String amount) {
    return 'Balance $amount';
  }

  @override
  String get ledgerDuplicateToday => 'Duplicate to today';

  @override
  String get ledgerDeleted => 'Transaction deleted';

  @override
  String get ledgerDuplicated => 'Duplicated to today';

  @override
  String ledgerMoved(String wallet) {
    return 'Moved to $wallet';
  }

  @override
  String ledgerMovedConverted(String wallet, String amount) {
    return 'Moved to $wallet as $amount';
  }

  @override
  String get ledgerSaved => 'Transaction saved';

  @override
  String get ledgerUpdated => 'Transaction updated';

  @override
  String get ledgerMoveTitle => 'Move to…';

  @override
  String get ledgerEditTx => 'Edit transaction';

  @override
  String get ledgerWallet => 'Wallet';

  @override
  String get ledgerFrom => 'From';

  @override
  String get ledgerTo => 'To';

  @override
  String get ledgerSent => 'Sent';

  @override
  String get ledgerReceived => 'Received';

  @override
  String get ledgerUseRate => 'Use the rate';

  @override
  String ledgerRateLine(String one, String from, String rate, String to) {
    return '$one $from = $rate $to';
  }

  @override
  String get ledgerBudgetItem => 'Budget item';

  @override
  String get ledgerChooseItem => 'Choose an item';

  @override
  String get ledgerNoBudget => 'No budget items yet';

  @override
  String get ledgerSearchItems => 'Search items';

  @override
  String ledgerItemLeft(String amount) {
    return '$amount left';
  }

  @override
  String ledgerItemOver(String amount) {
    return '$amount over';
  }

  @override
  String get ledgerDate => 'Date';

  @override
  String get ledgerOtherDay => 'Other day';

  @override
  String get ledgerNote => 'Note';

  @override
  String get ledgerNoteHint => 'e.g. vegetables from the market';

  @override
  String get ledgerTags => 'Tags';

  @override
  String get ledgerTagHint => 'Add a tag';

  @override
  String get ledgerSetBalance => 'Actual balance';

  @override
  String get ledgerDifference => 'Difference';

  @override
  String get ledgerCurrentBalance => 'Current balance';

  @override
  String get ledgerNegative => 'Negative';

  @override
  String get ledgerErrNoWallet => 'Choose a wallet';

  @override
  String get ledgerErrNoAmount => 'Enter an amount';

  @override
  String get ledgerErrNoDestination => 'Choose the receiving wallet';

  @override
  String get ledgerErrSameWallet => 'Pick a different wallet';

  @override
  String get ledgerErrNoRate => 'No exchange rate: enter the received amount';

  @override
  String get ledgerErrNoChange => 'The balance already matches';

  @override
  String get ledgerNeedWallet => 'Create a wallet first to record transactions';

  @override
  String get ledgerKeyDecimal => 'Decimal point';

  @override
  String get ledgerKeyBackspace => 'Delete last digit';

  @override
  String get ledgerAmount => 'Amount';

  @override
  String get ledgerWalletEdit => 'Edit wallet';

  @override
  String get ledgerWalletName => 'Name';

  @override
  String get ledgerWalletNameHint => 'e.g. Cash, Bank, Courier float';

  @override
  String get ledgerOpening => 'Opening balance & currency';

  @override
  String get ledgerWalletKind => 'Wallet type';

  @override
  String get ledgerColor => 'Colour';

  @override
  String get ledgerIcon => 'Icon';

  @override
  String get ledgerCurrencyLocked =>
      'The currency can’t change once the wallet has transactions';

  @override
  String get ledgerArchive => 'Archive';

  @override
  String get ledgerUnarchive => 'Unarchive';

  @override
  String get ledgerArchivedToast => 'Wallet archived';

  @override
  String get ledgerUnarchivedToast => 'Wallet restored';

  @override
  String ledgerWalletDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Wallet and $count transactions deleted',
      one: 'Wallet and 1 transaction deleted',
      zero: 'Wallet deleted',
    );
    return '$_temp0';
  }

  @override
  String get ledgerWalletSaved => 'Wallet saved';

  @override
  String get ledgerBalance => 'Balance';

  @override
  String get ledgerBalanceHistory => 'Balance over time';

  @override
  String get ledgerRange1M => '1M';

  @override
  String get ledgerRange3M => '3M';

  @override
  String get ledgerRange1Y => '1Y';

  @override
  String get ledgerRangeAll => 'All';

  @override
  String get ledgerTransactions => 'Transactions';

  @override
  String get ledgerWalletMissing => 'This wallet no longer exists';

  @override
  String ledgerOpeningLine(String amount) {
    return 'Opening balance $amount';
  }

  @override
  String get ledgerFilterWallet => 'Wallet';

  @override
  String get ledgerFilterKind => 'Type';

  @override
  String get ledgerFilterItem => 'Item';

  @override
  String get ledgerFilterTag => 'Tag';

  @override
  String get ledgerFilterDate => 'Dates';

  @override
  String get ledgerFilterScope => 'Scope';

  @override
  String get ledgerFilterClear => 'Clear filters';

  @override
  String ledgerFilterMore(String first, String count) {
    return '$first +$count';
  }

  @override
  String get ledgerAll => 'All';

  @override
  String get ledgerAllWallets => 'All wallets';

  @override
  String get ledgerThisWeek => 'This week';

  @override
  String get ledgerThisMonth => 'This month';

  @override
  String get ledgerLastMonth => 'Last month';

  @override
  String ledgerLastDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Last $count days',
      one: 'Last day',
    );
    return '$_temp0';
  }

  @override
  String get ledgerCustomRange => 'Custom range';

  @override
  String ledgerRangeLabel(String from, String to) {
    return '$from – $to';
  }

  @override
  String get ledgerIncomeTotal => 'Income';

  @override
  String get ledgerExpenseTotal => 'Spent';

  @override
  String get ledgerNet => 'Net';

  @override
  String ledgerTxCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions',
      one: '1 transaction',
      zero: 'No transactions',
    );
    return '$_temp0';
  }

  @override
  String get ledgerSpending => 'Spending';

  @override
  String get ledgerByItem => 'By item';

  @override
  String get ledgerByWallet => 'By wallet';

  @override
  String get ledgerPeriodMonth => 'Monthly';

  @override
  String get ledgerPeriodWeek => 'Weekly';

  @override
  String get ledgerPrevPeriod => 'Previous period';

  @override
  String get ledgerNextPeriod => 'Next period';

  @override
  String get ledgerNoSpending => 'No spending in this period';

  @override
  String get ledgerTrend => 'Income vs spending';

  @override
  String ledgerTrendSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Last $count months',
      one: 'Last month',
    );
    return '$_temp0';
  }

  @override
  String ledgerInBase(String code) {
    return 'In base currency $code';
  }

  @override
  String get ledgerTotal => 'Total';

  @override
  String get ledgerOther => 'Other';

  @override
  String ledgerChartSpendingSemantics(
    String period,
    String total,
    String slices,
  ) {
    return 'Spending $period: total $total. $slices';
  }

  @override
  String ledgerChartTrendSemantics(
    String period,
    String income,
    String expense,
  ) {
    return '$period: income $income, spending $expense';
  }

  @override
  String get ledgerCurrenciesTitle => 'Currencies';

  @override
  String get ledgerBaseCurrency => 'Base currency';

  @override
  String get ledgerBaseHint => 'Every total and chart is shown in it';

  @override
  String get ledgerChangeBase => 'Change base currency';

  @override
  String get ledgerOtherCurrencies => 'Other currencies';

  @override
  String get ledgerAddCurrency => 'Add currency';

  @override
  String get ledgerNewCurrency => 'New currency';

  @override
  String get ledgerEditCurrency => 'Edit currency';

  @override
  String get ledgerCode => 'Code';

  @override
  String get ledgerCodeHint => 'e.g. EUR';

  @override
  String get ledgerNameAr => 'Arabic name';

  @override
  String get ledgerNameEn => 'English name';

  @override
  String get ledgerSymbol => 'Symbol';

  @override
  String get ledgerDecimals => 'Decimal places';

  @override
  String get ledgerRate => 'Exchange rate';

  @override
  String get ledgerRateHint => 'Entered by hand, never fetched online';

  @override
  String get ledgerErrCode => 'Use Latin letters (e.g. EUR)';

  @override
  String get ledgerErrCodeExists => 'This currency already exists';

  @override
  String get ledgerErrRate => 'Enter a rate above zero';

  @override
  String get ledgerErrName => 'Enter a name';

  @override
  String ledgerCurrencyInUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Used by $count wallets',
      one: 'Used by 1 wallet',
    );
    return '$_temp0';
  }

  @override
  String get ledgerCurrencyDeleted => 'Currency deleted';

  @override
  String get ledgerCurrencySaved => 'Currency saved';

  @override
  String get ledgerNoRate => 'No rate';

  @override
  String get ledgerRebaseTitle => 'New base currency';

  @override
  String ledgerRebaseExplain(String code) {
    return 'Every rate is re-expressed exactly against $code, so converted values stay the same.';
  }

  @override
  String get ledgerRebaseNow => 'Now';

  @override
  String get ledgerRebaseAfter => 'After';

  @override
  String ledgerRebaseConfirm(String code) {
    return 'Make $code the base';
  }

  @override
  String ledgerRebaseDone(String code) {
    return '$code is now the base currency';
  }

  @override
  String get ledgerRebaseChoose => 'Choose the new base currency';

  @override
  String get ledgerSummaryEmpty => 'No wallets yet';

  @override
  String ledgerMoreWallets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'and $count more wallets',
      one: 'and 1 more wallet',
    );
    return '$_temp0';
  }

  @override
  String ledgerWalletSemantics(String name, String amount) {
    return '$name, balance $amount';
  }

  @override
  String get ledgerApply => 'Apply';

  @override
  String get ledgerNoTags => 'No tags yet';

  @override
  String get ledgerCompactThousand => 'K';

  @override
  String get ledgerCompactMillion => 'M';

  @override
  String get ledgerMakeBase => 'Make it the base';

  @override
  String get ledgerRatesStale =>
      'Rates are manual: update them when the market moves';

  @override
  String get ledgerNoteHintIncome => 'e.g. payout from the courier';

  @override
  String get ledgerNoteHintTransfer => 'e.g. cash deposited at the bank';

  @override
  String get ledgerNoteHintAdjust => 'e.g. after counting the cash';

  @override
  String get ledgerLinkJar => 'Savings jar';

  @override
  String get ledgerLinkDebt => 'Debt';

  @override
  String get ledgerLinkObligation => 'Obligation';

  @override
  String get ledgerOpenJar => 'Open the jar';

  @override
  String get ledgerOpenDebt => 'Open the debt';

  @override
  String get ledgerOpenObligation => 'Open the obligation';

  @override
  String ledgerLinkedHint(String source) {
    return 'Managed from $source';
  }

  @override
  String get ledgerArchivedBadge => 'Archived';

  @override
  String get ledgerUnknownCurrencies =>
      'Some wallets use currencies that aren\'t in your list yet. Add them with a rate so they count in the totals.';

  @override
  String ledgerAddCode(String code) {
    return 'Add $code';
  }

  @override
  String get ledgerFixRates => 'Set rates';

  @override
  String get ledgerCurrencyInUseElsewhere =>
      'Used by savings, debts, bills or the budget';

  @override
  String get budgetTitle => 'Budget';

  @override
  String get budgetTabPlan => 'Plan';

  @override
  String get budgetTabSpending => 'Spending';

  @override
  String get budgetAddItem => 'Add item';

  @override
  String get budgetMonthlyPlan => 'Monthly plan';

  @override
  String budgetWeeklyEquivalent(String amount) {
    return '≈ $amount a week';
  }

  @override
  String budgetWeeksPerMonthChip(String weeks) {
    return 'Weeks per month: $weeks';
  }

  @override
  String get budgetAllocation => 'How the plan is split';

  @override
  String get budgetBalanced => 'Everything adds up';

  @override
  String budgetWarningsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count things need attention',
      one: '1 thing needs attention',
    );
    return '$_temp0';
  }

  @override
  String budgetWarningsMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'and $count more',
      one: 'and 1 more',
    );
    return '$_temp0';
  }

  @override
  String get budgetShowLess => 'Show less';

  @override
  String budgetIssueChildrenUnder(String name, String amount) {
    return 'Sub-items of $name are $amount short of it';
  }

  @override
  String budgetIssueChildrenOver(String name, String amount) {
    return 'Sub-items of $name exceed it by $amount';
  }

  @override
  String budgetIssuePercentSelf(String name, String percent) {
    return '$name is set above its whole: $percent';
  }

  @override
  String budgetIssuePercentChildren(String name, String percent) {
    return 'Sub-items of $name claim $percent of it';
  }

  @override
  String budgetIssuePercentTotal(String percent) {
    return 'Items set as a share of the total add up to $percent';
  }

  @override
  String budgetIssueCircular(String name) {
    return '$name\'s percentages depend on each other and can\'t be worked out';
  }

  @override
  String get budgetIssueCircularTotal =>
      'Items set as a share of the total take all of it';

  @override
  String budgetIssueCircularParent(String name) {
    return '$name was nested inside itself; it is shown at the top level';
  }

  @override
  String budgetIssueOrphan(String name) {
    return '$name\'s parent is missing; it is shown at the top level';
  }

  @override
  String budgetIssueMissingRate(String currency) {
    return 'No exchange rate for $currency; it is counted one to one';
  }

  @override
  String budgetIssueOverspent(String name, String amount) {
    return '$name is $amount over plan this month';
  }

  @override
  String budgetBadgeUnder(String amount) {
    return '$amount unallocated';
  }

  @override
  String budgetBadgeOver(String amount) {
    return 'Over by $amount';
  }

  @override
  String budgetBadgePercent(String percent) {
    return '$percent – above its whole';
  }

  @override
  String budgetBadgePercentChildren(String percent) {
    return 'Sub-items total $percent';
  }

  @override
  String get budgetBadgeCircular => 'Circular %';

  @override
  String get budgetBadgeMoved => 'Moved to top';

  @override
  String get budgetBadgeNoRate => 'No rate';

  @override
  String budgetBadgeOverspent(String amount) {
    return 'Overspent $amount';
  }

  @override
  String budgetPercentOf(String percent, String name) {
    return '$percent of $name';
  }

  @override
  String budgetPercentOfTotal(String percent) {
    return '$percent of the total';
  }

  @override
  String budgetPerMonth(String amount) {
    return '$amount a month';
  }

  @override
  String budgetPerWeek(String amount) {
    return '$amount a week';
  }

  @override
  String budgetApproxMonthly(String amount) {
    return '≈ $amount a month';
  }

  @override
  String get budgetSumOfChildren => 'Sum of its sub-items';

  @override
  String budgetChildrenSum(String sum, String plan) {
    return 'Sub-items: $sum of $plan';
  }

  @override
  String get budgetSetByAmount => 'Set by amount';

  @override
  String get budgetSetByPercent => 'Set by percentage';

  @override
  String get budgetDragHint =>
      'Drag a handle to reorder items within their group';

  @override
  String get budgetAddChild => 'Add sub-item';

  @override
  String get budgetAddSibling => 'Add item beside';

  @override
  String budgetMoveTitle(String name) {
    return 'Move $name';
  }

  @override
  String get budgetMoveSubtitle => 'Its amount stays the same';

  @override
  String get budgetTopLevel => 'Top level';

  @override
  String budgetDeletedWithChildren(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Deleted with $count sub-items',
      one: 'Deleted with 1 sub-item',
      zero: 'Item deleted',
    );
    return '$_temp0';
  }

  @override
  String get budgetSaved => 'Item saved';

  @override
  String get budgetAdded => 'Item added';

  @override
  String get budgetEmptyTitle => 'No budget yet';

  @override
  String get budgetEmptyBody =>
      'Plan by amount or by percentage, nest items inside each other, then compare your spending with the plan.';

  @override
  String get budgetEmptyAction => 'Add the first item';

  @override
  String get budgetWeeksTitle => 'Weeks per month';

  @override
  String get budgetWeeksSubtitle =>
      'Weekly items are multiplied by this to get their monthly plan';

  @override
  String get budgetWeeksRound => 'Whole weeks';

  @override
  String get budgetWeeksCalendar => 'Calendar average';

  @override
  String get budgetWeeksCustom => 'Other number';

  @override
  String budgetWeeksInvalid(String min, String max) {
    return 'Enter a number between $min and $max';
  }

  @override
  String budgetWeeksExample(String weekly, String monthly) {
    return '$weekly a week = $monthly a month';
  }

  @override
  String get budgetWeeksSaved => 'Weeks per month changed';

  @override
  String get budgetNewItem => 'New item';

  @override
  String budgetNewChild(String name) {
    return 'New sub-item in $name';
  }

  @override
  String get budgetEditItem => 'Edit item';

  @override
  String get budgetFieldName => 'Name';

  @override
  String get budgetFieldNameHint => 'e.g. Groceries';

  @override
  String get budgetFieldParent => 'Inside';

  @override
  String get budgetFieldSetBy => 'Set by';

  @override
  String get budgetModeAmount => 'Amount';

  @override
  String get budgetModePercent => 'Percentage';

  @override
  String get budgetModeSum => 'Sub-items';

  @override
  String get budgetFieldAmount => 'Amount';

  @override
  String get budgetFieldPercent => 'Percentage';

  @override
  String budgetOfParent(String name) {
    return 'of $name';
  }

  @override
  String get budgetOfTotal => 'of the total';

  @override
  String get budgetCalculated => 'calculated';

  @override
  String get budgetFieldPeriod => 'Period';

  @override
  String get budgetMonthly => 'Monthly';

  @override
  String get budgetWeekly => 'Weekly';

  @override
  String get budgetFieldCurrency => 'Currency';

  @override
  String budgetBaseCurrency(String code) {
    return '$code · base';
  }

  @override
  String get budgetPreviewTitle => 'In the budget';

  @override
  String get budgetAmountInvalid => 'Enter an amount of zero or more';

  @override
  String get budgetPercentInvalid => 'Enter a percentage of zero or more';

  @override
  String get budgetSumHint =>
      'Equals the sum of its sub-items and follows them';

  @override
  String get budgetPickerTitle => 'Budget item';

  @override
  String get budgetPickerSearch => 'Search items';

  @override
  String get budgetPickerNone => 'No budget item';

  @override
  String get budgetPickerEmpty => 'No budget items yet';

  @override
  String get budgetPickerNoResults => 'No matching items';

  @override
  String get budgetPickerPlaceholder => 'Choose an item';

  @override
  String budgetLeft(String amount) {
    return '$amount left';
  }

  @override
  String budgetOverBy(String amount) {
    return '$amount over';
  }

  @override
  String get budgetCurrentBadge => 'Current';

  @override
  String get budgetPreviousPeriod => 'Previous period';

  @override
  String get budgetNextPeriod => 'Next period';

  @override
  String get budgetSpent => 'Spent';

  @override
  String budgetOfPlan(String amount) {
    return 'of $amount';
  }

  @override
  String get budgetRemaining => 'Remaining';

  @override
  String get budgetOverPlan => 'Over plan';

  @override
  String get budgetProjection => 'At this pace';

  @override
  String budgetProjectionMonth(String amount) {
    return '$amount by month end';
  }

  @override
  String budgetProjectionWeek(String amount) {
    return '$amount by week end';
  }

  @override
  String budgetDayOf(String day, String days) {
    return 'Day $day of $days';
  }

  @override
  String get budgetPeriodClosed => 'Finished period';

  @override
  String get budgetUnassigned => 'Outside the budget';

  @override
  String get budgetStatusCalm => 'On track';

  @override
  String get budgetStatusNear => 'Nearly used';

  @override
  String get budgetStatusAtRisk => 'On pace to exceed';

  @override
  String get budgetStatusOver => 'Over plan';

  @override
  String get budgetStatusUnplanned => 'Unplanned';

  @override
  String budgetSpentOf(String spent, String plan) {
    return '$spent of $plan';
  }

  @override
  String get budgetByItem => 'By item';

  @override
  String get budgetHistoryMonths => 'Previous months';

  @override
  String get budgetHistoryWeeks => 'Previous weeks';

  @override
  String get budgetLegendPlan => 'Plan';

  @override
  String get budgetLegendSpent => 'Spent';

  @override
  String get budgetHistoryNote =>
      'Earlier periods are compared with today\'s plan';

  @override
  String get budgetNoSpending => 'No expenses in this period yet';

  @override
  String budgetHistoryBar(String period, String spent, String plan) {
    return '$period: $spent of $plan';
  }

  @override
  String budgetCardSpentOf(String spent, String plan) {
    return 'Spent $spent of $plan';
  }

  @override
  String get budgetCardEmpty => 'Plan your budget by amount or percentage';

  @override
  String budgetCardWarnings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count warnings',
      one: '1 warning',
    );
    return '$_temp0';
  }

  @override
  String get goalsTitle => 'Savings & dues';

  @override
  String get goalsTabJars => 'Jars';

  @override
  String get goalsTabDebts => 'Debts';

  @override
  String get goalsTabObligations => 'Recurring';

  @override
  String get goalsDebtsTitle => 'Debts';

  @override
  String get goalsObligationsTitle => 'Recurring payments';

  @override
  String get goalsUpcomingTitle => 'Coming due';

  @override
  String get goalsSeeAll => 'See all';

  @override
  String get goalsCreate => 'Create';

  @override
  String get goalsGone => 'This item no longer exists.';

  @override
  String get goalsShow => 'Show';

  @override
  String get goalsHide => 'Hide';

  @override
  String get goalsFilterAll => 'All';

  @override
  String get goalsAmountPositive => 'Enter an amount above zero';

  @override
  String get goalsFieldAmount => 'Amount';

  @override
  String get goalsFieldDate => 'Date';

  @override
  String get goalsFieldNote => 'Note';

  @override
  String get goalsFieldFromWallet => 'From wallet';

  @override
  String get goalsFieldToWallet => 'To wallet';

  @override
  String get goalsNoWallet => 'No wallet';

  @override
  String get goalsOf => 'of';

  @override
  String goalsOfTotal(String amount) {
    return 'of $amount';
  }

  @override
  String goalsSavedOfTarget(String saved, String target) {
    return '$saved of $target';
  }

  @override
  String goalsFromWallet(String name) {
    return 'from $name';
  }

  @override
  String goalsToWallet(String name) {
    return 'to $name';
  }

  @override
  String goalsMissingRates(String codes) {
    return 'No exchange rate for $codes; counted at face value.';
  }

  @override
  String get goalsDueToday => 'Today';

  @override
  String get goalsDueTomorrow => 'Tomorrow';

  @override
  String goalsDueInDays(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'In $n days',
      one: 'In 1 day',
    );
    return '$_temp0';
  }

  @override
  String goalsOverdueDays(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n days overdue',
      one: '1 day overdue',
    );
    return '$_temp0';
  }

  @override
  String goalsDueOn(String date) {
    return 'On $date';
  }

  @override
  String goalsEveryWeeks(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $n weeks',
      one: 'Every week',
    );
    return '$_temp0';
  }

  @override
  String goalsEveryMonths(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $n months',
      one: 'Every month',
    );
    return '$_temp0';
  }

  @override
  String goalsEveryYears(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $n years',
      one: 'Every year',
    );
    return '$_temp0';
  }

  @override
  String get goalsJarNew => 'New jar';

  @override
  String get goalsJarNewSubtitle => 'A savings goal with a target and a date';

  @override
  String get goalsJarEdit => 'Edit jar';

  @override
  String get goalsFieldJarName => 'Name';

  @override
  String get goalsFieldJarNameHint => 'e.g. Travel';

  @override
  String get goalsFieldTarget => 'Target';

  @override
  String get goalsFieldDeadline => 'Deadline';

  @override
  String get goalsFieldIcon => 'Icon';

  @override
  String get goalsFieldColor => 'Colour';

  @override
  String get goalsDeposit => 'Deposit';

  @override
  String get goalsWithdraw => 'Withdraw';

  @override
  String goalsDepositTo(String name) {
    return 'Deposit to $name';
  }

  @override
  String goalsWithdrawFrom(String name) {
    return 'Withdraw from $name';
  }

  @override
  String goalsWithdrawTooMuch(String amount) {
    return 'Only $amount is saved';
  }

  @override
  String goalsJarReached(String name) {
    return '$name reached its target!';
  }

  @override
  String goalsDeposited(String amount) {
    return 'Deposited $amount';
  }

  @override
  String goalsWithdrawn(String amount) {
    return 'Withdrew $amount';
  }

  @override
  String get goalsJarArchived => 'Jar archived';

  @override
  String get goalsJarRestored => 'Jar restored';

  @override
  String get goalsArchive => 'Archive';

  @override
  String get goalsUnarchive => 'Unarchive';

  @override
  String get goalsArchivedJars => 'Archived jars';

  @override
  String get goalsJarsEmptyTitle => 'No jars yet';

  @override
  String get goalsJarsEmptyBody =>
      'Give each goal its own jar – travel, emergencies, a gift – and watch it fill.';

  @override
  String get goalsJarsHint =>
      'Swipe a jar for a quick deposit, long-press for more, drag the handle to reorder.';

  @override
  String goalsJarsReachedCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n jars reached their targets',
      one: '1 jar reached its target',
    );
    return '$_temp0';
  }

  @override
  String get goalsSavedInJars => 'Saved in jars';

  @override
  String get goalsNeededThisMonth => 'Needed this month';

  @override
  String get goalsOfTargets => 'of targets';

  @override
  String goalsOverallProgress(String percent) {
    return 'Overall progress $percent';
  }

  @override
  String goalsNeedPerMonth(String amount) {
    return '$amount a month';
  }

  @override
  String goalsDeadlineOn(String date) {
    return 'By $date';
  }

  @override
  String goalsSurplus(String amount) {
    return '$amount over';
  }

  @override
  String goalsTargetOf(String amount) {
    return 'Target $amount';
  }

  @override
  String get goalsNoDeadlineHint => 'Add a deadline to see the monthly amount';

  @override
  String get goalsPaceReached => 'Target reached';

  @override
  String get goalsPaceOnTrack => 'On track';

  @override
  String get goalsPaceBehind => 'Behind plan';

  @override
  String get goalsPaceOverdue => 'Past deadline';

  @override
  String get goalsPaceOpen => 'No deadline';

  @override
  String goalsBalanceAfter(String amount) {
    return 'Balance after: $amount';
  }

  @override
  String goalsPercentOfTarget(String percent) {
    return '$percent of the target';
  }

  @override
  String goalsWalletAmount(String amount) {
    return 'In the wallet’s currency: $amount';
  }

  @override
  String get goalsTrajectory => 'Savings trajectory';

  @override
  String get goalsHistory => 'History';

  @override
  String get goalsNoMovements => 'No deposits yet';

  @override
  String get goalsDeleteJar => 'Delete jar';

  @override
  String goalsAlidadeHint(String percent) {
    return 'The gold pointer marks where the plan puts you today ($percent)';
  }

  @override
  String get goalsRemaining => 'Remaining';

  @override
  String get goalsSurplusLabel => 'Over target';

  @override
  String get goalsNeededNow => 'Needed now';

  @override
  String get goalsPerMonth => 'Per month';

  @override
  String goalsPerWeekCaption(String amount) {
    return 'or $amount a week';
  }

  @override
  String goalsDaysLeft(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n days left',
      one: '1 day left',
      zero: 'Ends today',
    );
    return '$_temp0';
  }

  @override
  String get goalsAtYourPace => 'At your pace';

  @override
  String get goalsAfterDeadline => 'after the deadline';

  @override
  String get goalsBeforeDeadline => 'before the deadline';

  @override
  String goalsSavedTotal(String amount) {
    return '$amount saved';
  }

  @override
  String get goalsDebtNew => 'New debt';

  @override
  String get goalsDebtEdit => 'Edit debt';

  @override
  String get goalsFieldDirection => 'Direction';

  @override
  String get goalsIOwe => 'I owe';

  @override
  String get goalsOwedToMe => 'Owed to me';

  @override
  String get goalsDebtIOweSubtitle => 'I owe them';

  @override
  String get goalsDebtOwedSubtitle => 'They owe me';

  @override
  String get goalsFieldPerson => 'Person';

  @override
  String get goalsFieldPersonHint => 'Person or business';

  @override
  String get goalsFieldDueDate => 'Due date';

  @override
  String goalsIOweTo(String person) {
    return 'I owe $person';
  }

  @override
  String goalsOwedBy(String person) {
    return '$person owes me';
  }

  @override
  String goalsRemainingOf(String remaining, String total) {
    return '$remaining left of $total';
  }

  @override
  String get goalsSettle => 'Settle';

  @override
  String get goalsReopen => 'Reopen';

  @override
  String get goalsSettled => 'Settled';

  @override
  String goalsSettledOn(String date) {
    return 'Settled $date';
  }

  @override
  String goalsSettledWrittenOff(String date, String amount) {
    return 'Settled $date; $amount written off';
  }

  @override
  String get goalsNoDueDate => 'No due date';

  @override
  String get goalsRecordPayment => 'Record payment';

  @override
  String goalsPayTo(String person) {
    return 'Payment to $person';
  }

  @override
  String goalsReceiveFrom(String person) {
    return 'Payment from $person';
  }

  @override
  String goalsDebtPaidOff(String person) {
    return 'All paid up with $person';
  }

  @override
  String goalsPaymentRecorded(String amount) {
    return 'Recorded $amount';
  }

  @override
  String goalsDebtSettled(String person) {
    return 'Settled with $person';
  }

  @override
  String get goalsDebtReopened => 'Debt reopened';

  @override
  String get goalsPayments => 'Payments';

  @override
  String get goalsNoPayments => 'No payments yet';

  @override
  String goalsPaidSoFar(String amount) {
    return '$amount paid so far';
  }

  @override
  String get goalsPaysOff => 'This pays it off';

  @override
  String goalsRemainingAfter(String amount) {
    return '$amount left after this';
  }

  @override
  String goalsPaidOfTotal(String paid, String total) {
    return '$paid of $total';
  }

  @override
  String get goalsDebtsEmptyTitle => 'No debts';

  @override
  String get goalsDebtsEmptyBody =>
      'Keep track of what you owe and what others owe you, with due dates and partial payments.';

  @override
  String get goalsNoOpenDebts => 'Nothing open here';

  @override
  String get goalsSettledDebts => 'Settled';

  @override
  String get goalsDebtsHint => 'Swipe a debt to settle it – you can undo.';

  @override
  String goalsDebtsCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n open',
      one: '1 open',
      zero: 'none open',
    );
    return '$_temp0';
  }

  @override
  String get goalsNetEven => 'You’re even';

  @override
  String goalsNetOwedToMe(String amount) {
    return 'Net owed to you: $amount';
  }

  @override
  String goalsNetIOwe(String amount) {
    return 'Net you owe: $amount';
  }

  @override
  String goalsOverdueCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n overdue',
      one: '1 overdue',
    );
    return '$_temp0';
  }

  @override
  String get goalsObligationNew => 'New recurring payment';

  @override
  String get goalsObligationNewSubtitle =>
      'Rent, an instalment, a subscription, an allowance… anything that repeats';

  @override
  String get goalsObligationEdit => 'Edit recurring payment';

  @override
  String get goalsFieldObligationName => 'Name';

  @override
  String get goalsFieldObligationNameHint => 'e.g. Rent';

  @override
  String get goalsFieldFrequency => 'Repeats';

  @override
  String get goalsWeekly => 'Weekly';

  @override
  String get goalsMonthly => 'Monthly';

  @override
  String get goalsYearly => 'Yearly';

  @override
  String get goalsFieldInterval => 'Every how many';

  @override
  String get goalsFieldIntervalHint => '1 = every time, 2 = every other…';

  @override
  String get goalsFieldNextDue => 'Next due';

  @override
  String get goalsFieldPayFromWallet => 'Paid from wallet';

  @override
  String get goalsFieldBudgetItem => 'Budget item';

  @override
  String get goalsNoBudgetItem => 'No budget item';

  @override
  String get goalsFieldPaidOn => 'Paid on';

  @override
  String get goalsMarkPaid => 'Paid';

  @override
  String goalsMarkPaidFor(String name) {
    return 'Mark $name paid';
  }

  @override
  String get goalsPayOther => 'Pay a different amount';

  @override
  String get goalsPayOtherShort => 'Other amount';

  @override
  String goalsPayObligation(String name) {
    return 'Pay $name';
  }

  @override
  String goalsForDue(String date) {
    return 'For $date';
  }

  @override
  String get goalsSkip => 'Skip';

  @override
  String get goalsSkippedEntry => 'Skipped';

  @override
  String get goalsPause => 'Pause';

  @override
  String get goalsResume => 'Resume';

  @override
  String get goalsPaused => 'Paused';

  @override
  String goalsObligationPaid(String date) {
    return 'Paid – next due $date';
  }

  @override
  String goalsObligationSkipped(String date) {
    return 'Skipped – next due $date';
  }

  @override
  String get goalsObligationPaused => 'Paused';

  @override
  String get goalsObligationResumed => 'Resumed';

  @override
  String get goalsObligationsEmptyTitle => 'No recurring payments';

  @override
  String get goalsObligationsEmptyBody =>
      'Add what repeats – rent, instalments, subscriptions. You’ll get a reminder before each one, and “Paid” records the expense and moves on to the next date.';

  @override
  String get goalsObligationsHint => 'Swipe to mark paid – you can undo.';

  @override
  String get goalsMonthlyCommitments => 'Commitments per month';

  @override
  String goalsActiveCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n active',
      one: '1 active',
      zero: 'none active',
    );
    return '$_temp0';
  }

  @override
  String goalsDueSoonCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n within a week',
      one: '1 within a week',
    );
    return '$_temp0';
  }

  @override
  String get goalsSectionOverdue => 'Overdue';

  @override
  String get goalsSectionThisWeek => 'Within a week';

  @override
  String get goalsSectionLater => 'Later';

  @override
  String get goalsSectionPaused => 'Paused';

  @override
  String get goalsNextDue => 'Next due';

  @override
  String get goalsComingUp => 'After that';

  @override
  String get goalsNoHistory => 'Nothing paid yet';

  @override
  String goalsPaidOnForDue(String paid, String due) {
    return 'Paid $paid for $due';
  }

  @override
  String goalsPaidFrom(String wallet) {
    return 'Paid from $wallet';
  }

  @override
  String goalsCountsToward(String item) {
    return 'Counts toward $item';
  }

  @override
  String get goalsNoWalletHint =>
      'No wallet: “Paid” records the payment without a wallet transaction.';

  @override
  String get goalsRecordedInLedger => 'Recorded in the ledger';

  @override
  String goalsPeriodsDue(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n periods due',
      one: '1 period due',
    );
    return '$_temp0';
  }

  @override
  String goalsNextDates(String dates) {
    return 'Next: $dates';
  }

  @override
  String goalsAboutPerMonth(String amount) {
    return 'About $amount a month';
  }

  @override
  String goalsNothingDue(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Nothing due in the next $n days',
      one: 'Nothing due tomorrow',
    );
    return '$_temp0';
  }

  @override
  String goalsMoreDues(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'and $n more',
      one: 'and 1 more',
    );
    return '$_temp0';
  }

  @override
  String get goalsRemindersTitle => 'Due reminders';

  @override
  String get goalsRemindersSubtitle => 'For debts and recurring payments';

  @override
  String get goalsRemindersEnabled => 'Reminders';

  @override
  String get goalsRemindersEnabledHint =>
      'A quiet nudge before and on the due day';

  @override
  String get goalsRemindersLead => 'Early reminder';

  @override
  String get goalsRemindersLeadNone => 'None';

  @override
  String goalsRemindersLeadDays(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n days before',
      one: '1 day before',
    );
    return '$_temp0';
  }

  @override
  String get goalsRemindersOnDueDay => 'On the due day too';

  @override
  String get goalsRemindersTime => 'Time';

  @override
  String get goalsNotifyGroup => 'Money';

  @override
  String get goalsNotifyChannel => 'Due dates';

  @override
  String get goalsNotifyChannelDescription =>
      'Reminders for debts and recurring payments before they are due';

  @override
  String goalsNotifyObligationTitle(String name) {
    return '$name is due';
  }

  @override
  String goalsNotifyObligationBody(String when, String amount) {
    return '$when – $amount';
  }

  @override
  String goalsNotifyDebtIOweTitle(String person) {
    return 'Pay back $person';
  }

  @override
  String goalsNotifyDebtIOweBody(String when, String amount) {
    return '$when – you owe $amount';
  }

  @override
  String goalsNotifyDebtOwedTitle(String person) {
    return '$person owes you';
  }

  @override
  String goalsNotifyDebtOwedBody(String when, String amount) {
    return '$when – $amount is due to you';
  }

  @override
  String get goalsFieldDebtWallet => 'Through a wallet';

  @override
  String goalsDebtLentFrom(String wallet, String amount) {
    return 'Lent from $wallet – its balance drops by $amount';
  }

  @override
  String goalsDebtBorrowedInto(String wallet, String amount) {
    return 'Borrowed into $wallet – its balance rises by $amount';
  }

  @override
  String get goalsDebtNoWalletHint =>
      'No wallet: wallet balances stay as they are.';

  @override
  String get moneyHubNetWorthTitle => 'Net worth';

  @override
  String moneyHubNetWorthIn(String code) {
    return 'in $code';
  }

  @override
  String get moneyHubNetWorthEmpty =>
      'Add your first wallet to see your net worth here, in your base currency.';

  @override
  String get moneyHubPartWallets => 'Wallets';

  @override
  String get moneyHubPartJars => 'Jars';

  @override
  String get moneyHubPartOwedToMe => 'Owed to you';

  @override
  String get moneyHubPartIOwe => 'You owe';

  @override
  String moneyHubNetWorthSemantics(
    String total,
    String wallets,
    String jars,
    String owed,
    String owe,
  ) {
    return 'Net worth $total: wallets $wallets, jars $jars, owed to you $owed, you owe $owe';
  }

  @override
  String get moneyHubRatesAction => 'Currencies';

  @override
  String get moneyHubQuickTitle => 'Add an entry';

  @override
  String get moneyHubAddExpenseHint => 'Add an expense';

  @override
  String get moneyHubAddIncomeHint => 'Add income';

  @override
  String get moneyHubAddTransferHint => 'Move money between wallets';

  @override
  String get moneyHubWalletsTitle => 'Your wallets';

  @override
  String get moneyHubLedgerAction => 'Ledger';

  @override
  String get moneyHubPlanTitle => 'This month\'s plan';

  @override
  String get moneyHubBudgetAction => 'Budget';

  @override
  String get moneyHubDuesTitle => 'Dues & savings';

  @override
  String get moneyHubGoalsAction => 'All';

  @override
  String get moneyHubToolsTitle => 'Money tools';

  @override
  String get moneyHubToolLedger => 'Ledger';

  @override
  String get moneyHubToolLedgerHint => 'Wallets, balances and recent entries';

  @override
  String get moneyHubToolTransactions => 'Entries';

  @override
  String get moneyHubToolTransactionsHint =>
      'Every entry, searchable and filtered';

  @override
  String get moneyHubToolBudget => 'Budget';

  @override
  String get moneyHubToolBudgetHint =>
      'The nested plan and spending against it';

  @override
  String get moneyHubToolJars => 'Savings jars';

  @override
  String get moneyHubToolJarsHint => 'Targets, deadlines and deposits';

  @override
  String get moneyHubToolDebts => 'Debts';

  @override
  String get moneyHubToolDebtsHint =>
      'What you owe and are owed, with due dates';

  @override
  String get moneyHubToolBills => 'Bills';

  @override
  String get moneyHubToolBillsHint =>
      'Recurring bills; “Paid” moves the next due date';

  @override
  String get moneyHubMoonOpenWallet => 'Open wallet';

  @override
  String get moneyHubSettingsSection => 'Money';

  @override
  String get moneyHubSettingsSectionHint =>
      'Currencies, weeks per month, the week\'s start and due reminders';

  @override
  String get moneyHubSettingsCurrencies => 'Base currency & rates';

  @override
  String moneyHubSettingsCurrencyCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n currencies',
      one: '1 currency',
    );
    return '$_temp0';
  }

  @override
  String get moneyHubSettingsWeeks => 'Weeks per month';

  @override
  String moneyHubSettingsWeeksSummary(String weeks) {
    return '$weeks · converts weekly and monthly amounts';
  }

  @override
  String get moneyHubSettingsWeekStart => 'Week starts on';

  @override
  String get moneyHubSettingsWeekStartHint =>
      'For weekly budget items and the ledger\'s weekly reports';

  @override
  String get moneyHubWeekSaturday => 'Saturday';

  @override
  String get moneyHubWeekSunday => 'Sunday';

  @override
  String get moneyHubWeekMonday => 'Monday';

  @override
  String get moneyHubSettingsReminders => 'Due reminders';

  @override
  String get moneyHubSettingsRemindersOff => 'Off';

  @override
  String get moneyHubSettingsRemindersOnDay => 'On the due day';

  @override
  String moneyHubSettingsRemindersBoth(String lead) {
    return '$lead and on the day';
  }

  @override
  String moneyHubSettingsRemindersAt(String when, String time) {
    return '$when · at $time';
  }

  @override
  String get workTitle => 'Work';

  @override
  String get workBoards => 'Boards';

  @override
  String get workProjects => 'Projects';

  @override
  String get workAllProjects => 'All projects';

  @override
  String get workOpenAll => 'Open Work';

  @override
  String get workSep => ' · ';

  @override
  String get workSave => 'Save';

  @override
  String get workCreate => 'Add';

  @override
  String get workToday => 'Today';

  @override
  String get workTomorrow => 'Tomorrow';

  @override
  String get workPickDate => 'Pick a date…';

  @override
  String get workNoDate => 'No date';

  @override
  String get workClear => 'Clear';

  @override
  String get workNewBoard => 'New board';

  @override
  String get workEditBoard => 'Edit board';

  @override
  String get workBoardName => 'Board name';

  @override
  String get workBoardNameHint => 'e.g. Online store';

  @override
  String get workBoardCountry => 'Country or business';

  @override
  String get workBoardCountryHint => 'Pick a country or type a short label';

  @override
  String get workBoardColor => 'Colour';

  @override
  String get workBoardOptions => 'Board options';

  @override
  String get workArchive => 'Archive';

  @override
  String get workUnarchive => 'Restore';

  @override
  String get workArchivedSection => 'Archived boards';

  @override
  String get workBoardArchived => 'Board archived';

  @override
  String get workBoardRestored => 'Board restored';

  @override
  String get workBoardDeleted => 'Board and its cards deleted';

  @override
  String get workBoardsEmptyTitle => 'Start your first board';

  @override
  String get workBoardsEmptyBody =>
      'One board per country or business — e.g. “Online store” or “Delivery team” — with To-do, Doing and Done columns.';

  @override
  String get workBoardMissing => 'This board no longer exists';

  @override
  String workOpenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count open cards',
      one: '1 open card',
      zero: 'No open cards',
    );
    return '$_temp0';
  }

  @override
  String workDoneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count done',
      one: '1 done',
      zero: 'None done',
    );
    return '$_temp0';
  }

  @override
  String workDueTodayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count due today',
      one: '$count due today',
    );
    return '$_temp0';
  }

  @override
  String workOverdueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count overdue',
      one: '$count overdue',
    );
    return '$_temp0';
  }

  @override
  String workCardsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards',
      one: '1 card',
      zero: 'No cards',
    );
    return '$_temp0';
  }

  @override
  String workArchivedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archived boards',
      one: '1 archived board',
    );
    return '$_temp0';
  }

  @override
  String get workColTodo => 'To-do';

  @override
  String get workColDoing => 'Doing';

  @override
  String get workColDone => 'Done';

  @override
  String get workColumnUntitled => 'Column';

  @override
  String get workEditColumns => 'Edit columns';

  @override
  String get workEditColumnsHint => 'Drag to reorder; choose the done column';

  @override
  String get workAddColumn => 'Add column';

  @override
  String get workColumnName => 'Column name';

  @override
  String get workRenameColumn => 'Rename';

  @override
  String get workDeleteColumn => 'Delete column';

  @override
  String get workDoneColumn => 'Done column';

  @override
  String get workDoneColumnHint =>
      'Cards here count as done and brighten the Work planet';

  @override
  String get workMakeDoneColumn => 'Make it the done column';

  @override
  String get workNeedOneColumn => 'A board needs at least one column';

  @override
  String workColumnDeleted(String column) {
    return 'Column deleted — its cards moved to “$column”';
  }

  @override
  String get workColumnsSaved => 'Columns saved';

  @override
  String get workColumnEmpty => 'No cards here yet';

  @override
  String get workDropHere => 'Drop the card here';

  @override
  String get workAddCard => 'Add card';

  @override
  String get workNewCard => 'New card';

  @override
  String get workEditCard => 'Edit card';

  @override
  String get workCardTitle => 'Title';

  @override
  String get workCardTitleHint => 'What needs doing?';

  @override
  String get workCardNotes => 'Notes';

  @override
  String get workCardAssignee => 'Assignee';

  @override
  String get workCardAssigneeHint => 'Who is on it?';

  @override
  String get workCardDue => 'Due date';

  @override
  String get workCardColumn => 'Column';

  @override
  String get workCardWindow => 'When to work on it';

  @override
  String get workCardWindowHint =>
      'It shows in that window’s list on the home screen';

  @override
  String get workNotPlaced => 'Not placed';

  @override
  String get workCardDeleted => 'Card deleted';

  @override
  String get workCardDuplicated => 'Card duplicated';

  @override
  String workCardMovedTo(String column) {
    return 'Moved to “$column”';
  }

  @override
  String workCardMovedBoard(String board) {
    return 'Moved to the “$board” board';
  }

  @override
  String get workCardDoneToast => 'Done — well done';

  @override
  String workCardReopened(String column) {
    return 'Back in “$column”';
  }

  @override
  String get workCardSaved => 'Card saved';

  @override
  String get workMoveToBoard => 'Move to board';

  @override
  String get workMoveToColumn => 'Move to column';

  @override
  String workMoveForward(String column) {
    return 'Advance to “$column”';
  }

  @override
  String workMoveBack(String column) {
    return 'Send back to “$column”';
  }

  @override
  String get workPlaceInWindow => 'Place in a prayer window';

  @override
  String get workRemoveFromWindow => 'Remove from the prayer window';

  @override
  String workPlacedToast(String window) {
    return 'Placed in “$window”';
  }

  @override
  String get workUnplacedToast => 'Removed from the prayer window';

  @override
  String get workDueSetToast => 'Due date set';

  @override
  String workCardSemantics(String title, String column) {
    return '$title, in $column';
  }

  @override
  String get workSwipeHint =>
      'Swipe toward the next column to advance it or the previous one to send it back; long-press to drag it or for options';

  @override
  String get workUnassigned => 'Unassigned';

  @override
  String get workDoneBadge => 'Done';

  @override
  String workLateDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days late',
      one: '1 day late',
    );
    return '$_temp0';
  }

  @override
  String workInWindow(String window) {
    return '$window';
  }

  @override
  String workWindowOnDay(String window, String day) {
    return '$window, $day';
  }

  @override
  String get workFilter => 'Filter';

  @override
  String get workFilterAll => 'All';

  @override
  String get workFilterOverdue => 'Overdue';

  @override
  String get workFilterToday => 'Due today';

  @override
  String get workFilterWeek => 'This week';

  @override
  String get workFilterNoDate => 'No date';

  @override
  String get workFilterAssignee => 'Assignee';

  @override
  String get workFilterDue => 'Due';

  @override
  String get workFilterClear => 'Clear filter';

  @override
  String get workFilterNoMatch => 'No cards match the filter';

  @override
  String get workTop3Title => 'Today’s Top 3';

  @override
  String get workTop3Subtitle => 'Three priorities are enough for a good day';

  @override
  String get workTop3Empty =>
      'Pick what deserves your focus today — three things are enough.';

  @override
  String get workTop3Choose => 'Choose';

  @override
  String get workTop3ChooseTitle => 'Choose your Top 3';

  @override
  String workTop3SlotsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count slots left',
      one: '1 slot left',
      zero: 'All three chosen',
    );
    return '$_temp0';
  }

  @override
  String get workTop3NoCandidates => 'No open cards or tasks to choose from';

  @override
  String workTop3Progress(String done, String total) {
    return '$done of $total';
  }

  @override
  String get workTop3AllDone =>
      'Today’s Top 3 are done — may your time be blessed';

  @override
  String get workTop3Add => 'Add to Top 3';

  @override
  String get workTop3Remove => 'Remove from Top 3';

  @override
  String get workTop3Added => 'Added to Top 3';

  @override
  String get workTop3Removed => 'Removed from Top 3';

  @override
  String get workTop3Toggle => 'In today’s Top 3';

  @override
  String get workTop3FullTitle => 'Your Top 3 is full';

  @override
  String workTop3FullBody(String title) {
    return 'Choose what “$title” replaces';
  }

  @override
  String get workTop3Swapped => 'Swapped in your Top 3';

  @override
  String get workTop3FullShort => 'Top 3 is full';

  @override
  String get workCarryTitle => 'From yesterday’s focus';

  @override
  String workCarryBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items weren’t finished. Carry them over to today?',
      one: 'One item wasn’t finished. Carry it over to today?',
    );
    return '$_temp0';
  }

  @override
  String get workCarryOver => 'Carry over';

  @override
  String get workStartFresh => 'Start fresh';

  @override
  String get workCarriedToast => 'Carried over to today';

  @override
  String get workFreshToast => 'A fresh start for today';

  @override
  String get workKindTask => 'Task';

  @override
  String get workItemDoneToast => 'Done';

  @override
  String get workItemReopenedToast => 'Reopened';

  @override
  String get workTodayTitle => 'Work today';

  @override
  String get workTodayAllClear => 'Nothing due today';

  @override
  String get workTodayTop3 => 'Top 3';

  @override
  String workTodayTop3Line(String done, String total) {
    return 'Top 3: $done of $total';
  }

  @override
  String get workNewProject => 'New project';

  @override
  String get workEditProject => 'Edit project';

  @override
  String get workProjectName => 'Project name';

  @override
  String get workProjectNameHint => 'e.g. Launch a new product';

  @override
  String get workProjectDescription => 'Description';

  @override
  String get workProjectDeadline => 'Deadline';

  @override
  String get workProjectStatus => 'Status';

  @override
  String get workStatusActive => 'Active';

  @override
  String get workStatusPaused => 'Paused';

  @override
  String get workStatusDone => 'Done';

  @override
  String get workProjectPlanet => 'Planet';

  @override
  String get workProjectColor => 'Colour';

  @override
  String get workChecklist => 'Checklist';

  @override
  String get workAddItemHint => 'Add a step…';

  @override
  String get workAddItem => 'Add step';

  @override
  String get workEditItem => 'Edit step';

  @override
  String get workItemBody => 'Step';

  @override
  String get workItemDue => 'Step due date';

  @override
  String get workItemDeleted => 'Step deleted';

  @override
  String get workChecklistEmpty =>
      'Break the project into small steps — every journey starts with one.';

  @override
  String get workProjectTasks => 'Project tasks';

  @override
  String get workProjectTasksEmpty =>
      'Tasks you place in prayer windows for this project appear here';

  @override
  String get workAddProjectTask => 'Task in a prayer window';

  @override
  String get workTaskTitle => 'Task';

  @override
  String get workTaskWindow => 'Window';

  @override
  String get workTaskDay => 'Day';

  @override
  String get workProjectDeleted => 'Project deleted';

  @override
  String get workProjectDuplicated => 'Project duplicated';

  @override
  String get workProjectComplete => 'Project complete — mashallah!';

  @override
  String get workProjectMissing => 'This project no longer exists';

  @override
  String get workProjectsEmptyTitle => 'No projects yet';

  @override
  String get workProjectsEmptyBody =>
      'A project with steps and a deadline — e.g. “Launch a new product” or “Refresh the website”.';

  @override
  String workStatusChanged(String status) {
    return 'Status: $status';
  }

  @override
  String get workSetStatus => 'Change status';

  @override
  String workDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get workDaysLeftCaption => 'to the deadline';

  @override
  String get workDueTodayCaption => 'Deadline is today';

  @override
  String get workDueTomorrowCaption => 'Deadline is tomorrow';

  @override
  String workOverdueDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days past the deadline',
      one: '1 day past the deadline',
    );
    return '$_temp0';
  }

  @override
  String get workNoDeadline => 'No deadline';

  @override
  String workDeadlineOn(String date) {
    return 'Due $date';
  }

  @override
  String workItemsProgress(String done, String total) {
    return '$done of $total steps';
  }

  @override
  String get workCountryJO => 'Jordan';

  @override
  String get workCountrySA => 'Saudi Arabia';

  @override
  String get workCountryAE => 'UAE';

  @override
  String get workCountryKW => 'Kuwait';

  @override
  String get workCountryQA => 'Qatar';

  @override
  String get workCountryBH => 'Bahrain';

  @override
  String get workCountryOM => 'Oman';

  @override
  String get workCountryIQ => 'Iraq';

  @override
  String get workCountrySY => 'Syria';

  @override
  String get workCountryLB => 'Lebanon';

  @override
  String get workCountryPS => 'Palestine';

  @override
  String get workCountryEG => 'Egypt';

  @override
  String get workCountryLY => 'Libya';

  @override
  String get workCountryTN => 'Tunisia';

  @override
  String get workCountryDZ => 'Algeria';

  @override
  String get workCountryMA => 'Morocco';

  @override
  String get workCountrySD => 'Sudan';

  @override
  String get workCountryYE => 'Yemen';

  @override
  String get workCountryTR => 'Türkiye';

  @override
  String get familyTitle => 'Family & friends';

  @override
  String get familyTodayTitle => 'Today\'s reach-outs';

  @override
  String get familyOpenAll => 'See all';

  @override
  String get familyAddPerson => 'Add a person';

  @override
  String get familyEmptyTitle => 'Your close circle starts here';

  @override
  String get familyEmptyBody =>
      'Add the people you want to stay close to and how often to reach out — for example “Mum, every 2 days”.';

  @override
  String get familySortUrgency => 'By urgency';

  @override
  String get familySortManual => 'My own order';

  @override
  String get familySortLabel => 'Sort order';

  @override
  String get familyRemindersTitle => 'Reach-out reminders';

  @override
  String get familyGroupOverdue => 'Overdue';

  @override
  String get familyGroupDueToday => 'Due today';

  @override
  String get familyGroupThisWeek => 'This week';

  @override
  String get familyGroupInTouch => 'In touch';

  @override
  String get familyGroupNoRhythm => 'No set rhythm';

  @override
  String familyHeroWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people are waiting to hear from you',
      one: '1 person is waiting to hear from you',
      zero: 'Nobody is waiting',
    );
    return '$_temp0';
  }

  @override
  String get familyHeroAllGood => 'Everyone\'s in touch';

  @override
  String get familyHeroBlessing => 'May your ties stay blessed';

  @override
  String familyHeroInTouch(String inTouch, String total) {
    return '$inTouch of $total in touch';
  }

  @override
  String get familyHeroNoRhythm =>
      'Set how often to reach out to each person to see who\'s due';

  @override
  String familyStatusOverdue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days overdue',
      one: '1 day overdue',
    );
    return '$_temp0';
  }

  @override
  String get familyStatusDueToday => 'Due today';

  @override
  String familyStatusDueIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Due in $count days',
      one: 'Due tomorrow',
    );
    return '$_temp0';
  }

  @override
  String get familyStatusNoRhythm => 'No rhythm';

  @override
  String get familyLastNever => 'No contact logged yet';

  @override
  String familyLastDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Last contact $count days ago',
      one: 'Last contact yesterday',
      zero: 'Last contact today',
    );
    return '$_temp0';
  }

  @override
  String familyInDays(int count) {
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
  String familyDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: 'yesterday',
      zero: 'today',
    );
    return '$_temp0';
  }

  @override
  String familyDaysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String familyRhythmEvery(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count days',
      one: 'Daily',
    );
    return '$_temp0';
  }

  @override
  String get familyRhythmWeekly => 'Weekly';

  @override
  String get familyRhythmBiweekly => 'Every 2 weeks';

  @override
  String get familyRhythmMonthly => 'Monthly';

  @override
  String get familyRhythmNone => 'No rhythm';

  @override
  String get familyRhythmCustom => 'Custom';

  @override
  String get familyRhythmCustomLabel => 'Every how many days?';

  @override
  String get familyUnitDays => 'days';

  @override
  String get familyChannelCall => 'Call';

  @override
  String get familyChannelVisit => 'Visit';

  @override
  String get familyChannelMessage => 'Message';

  @override
  String get familyChannelOther => 'Other';

  @override
  String get familyContacted => 'Contacted';

  @override
  String get familyContactedDetails => 'Contacted… with details';

  @override
  String get familyCall => 'Call';

  @override
  String get familySms => 'Text message';

  @override
  String get familyWhatsApp => 'WhatsApp';

  @override
  String get familyLaunchFailed => 'Couldn\'t open the app on this device';

  @override
  String get familyMoonShow => 'Show in the orbit';

  @override
  String get familyMoonHide => 'Hide from the orbit';

  @override
  String get familyOpenProfile => 'Open profile';

  @override
  String get familyEdit => 'Edit';

  @override
  String get familyDelete => 'Delete';

  @override
  String familyContactedToast(String name) {
    return 'Logged: you reached out to $name';
  }

  @override
  String familyDeletedToast(String name) {
    return '$name deleted';
  }

  @override
  String familySavedToast(String name) {
    return '$name saved';
  }

  @override
  String get familyContactDeletedToast => 'Contact removed from the history';

  @override
  String get familyContactUpdatedToast => 'Contact updated';

  @override
  String familyMoonShownToast(String name) {
    return '$name now orbits the Family planet';
  }

  @override
  String familyMoonHiddenToast(String name) {
    return '$name hidden from the orbit';
  }

  @override
  String get familyNewPerson => 'New person';

  @override
  String get familyNewPersonSubtitle => 'Someone you want to stay close to';

  @override
  String familyEditTitle(String name) {
    return 'Edit $name';
  }

  @override
  String get familyFieldName => 'Name';

  @override
  String get familyFieldNameHint => 'e.g. Mum, Alex';

  @override
  String get familyFieldNameRequired => 'Enter a name';

  @override
  String get familyFieldRelation => 'Relation';

  @override
  String get familyFieldRelationHint => 'Pick or type';

  @override
  String get familyFieldRhythm => 'How often to reach out?';

  @override
  String get familyFieldLastContact => 'Last contact';

  @override
  String get familyFieldPhone => 'Phone number';

  @override
  String get familyFieldPhoneHint => 'With the country code, for WhatsApp';

  @override
  String get familyFieldBirthday => 'Birthday';

  @override
  String get familyBirthdayYearUnknown => 'Year unknown';

  @override
  String get familyBirthdayNone => 'None';

  @override
  String get familyFieldNotes => 'Notes';

  @override
  String get familyFieldNotesHint => 'Interests, occasions, gift ideas…';

  @override
  String get familyFieldColor => 'Colour';

  @override
  String get familyFieldMoon => 'Moon in the orbit';

  @override
  String get familyFieldMoonHint =>
      'Shown as a moon around the Family planet on home';

  @override
  String get familyMoreDetails => 'More details';

  @override
  String get familyFewerDetails => 'Fewer details';

  @override
  String get familySave => 'Save';

  @override
  String get familyWhenNow => 'Now';

  @override
  String get familyWhenToday => 'Today';

  @override
  String get familyWhenEarlierToday => 'Earlier today';

  @override
  String get familyWhenYesterday => 'Yesterday';

  @override
  String get familyWhenWeekAgo => 'A week ago';

  @override
  String get familyWhenUnknown => 'Not sure';

  @override
  String get familyWhenPick => 'Another date';

  @override
  String familyContactedTitle(String name) {
    return 'You reached out to $name';
  }

  @override
  String get familyContactedSubtitle => 'Log how and when — a word is enough';

  @override
  String get familyEditContactTitle => 'Edit contact';

  @override
  String get familyFieldChannel => 'How';

  @override
  String get familyFieldWhen => 'When';

  @override
  String get familyFieldNote => 'Note';

  @override
  String get familyFieldNoteHint => 'What did you talk about?';

  @override
  String get familyFutureError => 'A contact can\'t be in the future';

  @override
  String get familyLog => 'Log it';

  @override
  String get familyRhythmCardTitle => 'Rhythm';

  @override
  String get familyStatAverage => 'Average gap';

  @override
  String get familyStatOnRhythm => 'On rhythm';

  @override
  String get familyStatLongestGap => 'Longest gap';

  @override
  String get familyStatRecent => 'Last 90 days';

  @override
  String familyStatTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count times',
      one: 'once',
      zero: 'none',
    );
    return '$_temp0';
  }

  @override
  String familyVsRhythm(String rhythm) {
    return 'Rhythm: $rhythm';
  }

  @override
  String get familyChartCaption => 'Gaps between recent contacts';

  @override
  String get familyStatsEmpty =>
      'After two or three contacts your stats appear here';

  @override
  String get familyHistoryTitle => 'Contact history';

  @override
  String get familyHistoryEmpty =>
      'Nothing logged yet. Tap “Contacted” after each call or visit.';

  @override
  String get familyNotesTitle => 'Notes';

  @override
  String get familyNotesAdd => 'Add a note';

  @override
  String get familyBirthdayTitle => 'Birthday';

  @override
  String get familyBirthdayTodayBadge => 'Today!';

  @override
  String familyAgeTurning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Turns $count',
      one: 'Turns 1',
    );
    return '$_temp0';
  }

  @override
  String familyBirthdayUpcoming(String name, String when) {
    return '$name\'s birthday $when';
  }

  @override
  String familyCardMore(String count) {
    return '+$count more';
  }

  @override
  String get familyCardEmpty => 'Add your loved ones to stay in touch';

  @override
  String get familyDigestTitle => 'Gentle daily digest';

  @override
  String get familyDigestHint =>
      'One notification a day listing who\'s due — never one per person';

  @override
  String get familyDigestTime => 'Digest time';

  @override
  String get familyBirthdayReminders => 'Birthday reminders';

  @override
  String get familyBirthdayRemindersHint => 'The day before and on the day';

  @override
  String get familyBirthdayTime => 'Birthday reminder time';

  @override
  String get familyNotifyGroup => 'Family & friends';

  @override
  String get familyNotifyChannel => 'Reach-out reminders';

  @override
  String get familyNotifyChannelDescription =>
      'The daily reach-out digest and birthday reminders';

  @override
  String familyDigestNotifyTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people to reach out to today',
      one: '1 person to reach out to today',
    );
    return '$_temp0';
  }

  @override
  String familyDigestNotifyBody(String names) {
    return '$names — a short call is enough.';
  }

  @override
  String familyBirthdayEveTitle(String name) {
    return '$name\'s birthday is tomorrow';
  }

  @override
  String get familyBirthdayEveBody => 'Get a kind word or a small gift ready.';

  @override
  String familyBirthdayDayTitle(String name) {
    return 'It\'s $name\'s birthday today';
  }

  @override
  String get familyBirthdayDayBody => 'Send your wishes.';

  @override
  String get familyListSep => ', ';

  @override
  String get familyDot => ' · ';

  @override
  String get familyRelFather => 'Father';

  @override
  String get familyRelMother => 'Mother';

  @override
  String get familyRelWife => 'Wife';

  @override
  String get familyRelHusband => 'Husband';

  @override
  String get familyRelSon => 'Son';

  @override
  String get familyRelDaughter => 'Daughter';

  @override
  String get familyRelBrother => 'Brother';

  @override
  String get familyRelSister => 'Sister';

  @override
  String get familyRelGrandfather => 'Grandfather';

  @override
  String get familyRelGrandmother => 'Grandmother';

  @override
  String get familyRelUncle => 'Uncle (father\'s side)';

  @override
  String get familyRelMaternalUncle => 'Uncle (mother\'s side)';

  @override
  String get familyRelAunt => 'Aunt (father\'s side)';

  @override
  String get familyRelMaternalAunt => 'Aunt (mother\'s side)';

  @override
  String get familyRelInLaw => 'In-law';

  @override
  String get familyRelRelative => 'Relative';

  @override
  String get familyRelFriend => 'Friend';

  @override
  String get familyRelColleague => 'Colleague';

  @override
  String get familyRelPartner => 'Business partner';

  @override
  String get familyRelNeighbour => 'Neighbour';

  @override
  String get familyRelTeacher => 'Teacher';

  @override
  String get travelTitle => 'Travel';

  @override
  String get travelTabTrips => 'Trips';

  @override
  String get travelTabDocuments => 'Documents';

  @override
  String get travelTabTemplates => 'Packing lists';

  @override
  String get travelAddTrip => 'New trip';

  @override
  String get travelAddDocument => 'New document';

  @override
  String get travelAddTemplate => 'New list';

  @override
  String get travelSectionCurrent => 'Under way';

  @override
  String get travelSectionUpcoming => 'Coming up';

  @override
  String get travelSectionPast => 'Past trips';

  @override
  String get travelTripsEmptyTitle => 'No trips yet';

  @override
  String get travelTripsEmptyBody =>
      'Plan your next trip: destination, dates, a packing list, and the prayer times and qibla there.';

  @override
  String get travelTripsEmptyExample =>
      'For example: Umrah this winter, or a short business trip';

  @override
  String travelShowPast(String n) {
    return 'Show past trips ($n)';
  }

  @override
  String get travelHidePast => 'Hide past trips';

  @override
  String get travelCountdownToday => 'Leaving today';

  @override
  String get travelCountdownTomorrow => 'Leaving tomorrow';

  @override
  String travelCountdownIn(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'In $n days',
      one: 'In 1 day',
    );
    return '$_temp0';
  }

  @override
  String travelCountdownDayOf(String day, String total) {
    return 'Day $day of $total';
  }

  @override
  String travelCountdownDay(String day) {
    return 'Day $day';
  }

  @override
  String travelCountdownEnded(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ended $n days ago',
      one: 'Ended yesterday',
    );
    return '$_temp0';
  }

  @override
  String get travelCountdownFinished => 'Finished';

  @override
  String get travelCountdownUndated => 'No dates yet';

  @override
  String travelDays(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get travelOpenEnded => 'Open return';

  @override
  String get travelStatusPlanned => 'Planned';

  @override
  String get travelStatusActive => 'Under way';

  @override
  String get travelStatusDone => 'Finished';

  @override
  String get travelStatusAuto => 'From the dates';

  @override
  String travelStatusAutoHint(String status) {
    return 'The status follows the dates by itself: now “$status”';
  }

  @override
  String get travelStatusManualHint => 'A manual status that ignores the dates';

  @override
  String get travelMarkDone => 'Finish trip';

  @override
  String get travelFollowDates => 'Follow the dates';

  @override
  String get travelSheetNewTitle => 'New trip';

  @override
  String get travelSheetEditTitle => 'Edit trip';

  @override
  String get travelSheetSubtitle =>
      'Destination, dates, and the prayer times there';

  @override
  String get travelFieldDestination => 'Destination';

  @override
  String get travelFieldDestinationHint => 'Search a city or type any place';

  @override
  String get travelDestinationRequired => 'Enter a destination';

  @override
  String travelDestinationFree(String name) {
    return 'Use “$name” as typed';
  }

  @override
  String get travelDestinationFreeHint =>
      'No prayer times or qibla; pick a listed city to get them';

  @override
  String get travelDestinationChange => 'Change';

  @override
  String travelDestinationCity(String zone) {
    return '$zone · qibla and prayer times included';
  }

  @override
  String get travelFieldStart => 'Departure';

  @override
  String get travelFieldEnd => 'Return';

  @override
  String get travelFieldEndHint => 'Leave empty if the return is open';

  @override
  String get travelEndBeforeStart => 'The return is before the departure';

  @override
  String get travelFieldStatus => 'Status';

  @override
  String get travelFieldColor => 'Colour';

  @override
  String get travelFieldNotes => 'Notes';

  @override
  String get travelFieldNotesHint =>
      'Bookings, addresses, anything to remember…';

  @override
  String get travelSave => 'Save';

  @override
  String get travelCreate => 'Add trip';

  @override
  String get travelNoDate => 'Not set';

  @override
  String get travelLocalTime => 'Local time';

  @override
  String travelTimeAhead(String duration) {
    return '$duration ahead of your phone';
  }

  @override
  String travelTimeBehind(String duration) {
    return '$duration behind your phone';
  }

  @override
  String get travelTimeSame => 'Same time as your phone';

  @override
  String travelHours(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String travelHoursMinutes(String hm) {
    return '$hm h';
  }

  @override
  String get travelTripDates => 'Dates';

  @override
  String get travelPackingTitle => 'Packing list';

  @override
  String travelPackedCount(String packed, String total) {
    return '$packed of $total';
  }

  @override
  String get travelPackingEmptyTitle => 'Nothing to pack yet';

  @override
  String get travelPackingEmptyBody =>
      'Add what you\'ll need, or start from a packing list.';

  @override
  String get travelPackingAllDone => 'All packed. Have a blessed trip';

  @override
  String travelPackingRemaining(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n items to go',
      one: '1 item to go',
    );
    return '$_temp0';
  }

  @override
  String get travelAddItem => 'Add an item';

  @override
  String get travelAddItemHint => 'e.g. phone charger';

  @override
  String travelAddItemTo(String category) {
    return 'Add to $category…';
  }

  @override
  String travelAddItemIn(String category) {
    return 'To: $category';
  }

  @override
  String get travelFromTemplate => 'From a list';

  @override
  String get travelSaveAsTemplate => 'Save as a list';

  @override
  String get travelUnpackAll => 'Unpack all';

  @override
  String travelTemplatesApplied(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $n items',
      one: 'Added 1 item',
      zero: 'Everything was already on the list',
    );
    return '$_temp0';
  }

  @override
  String get travelPickTemplatesTitle => 'Choose packing lists';

  @override
  String get travelPickTemplatesHint =>
      'Lists merge without repeating what is already there';

  @override
  String get travelPickTemplatesAdd => 'Add to trip';

  @override
  String get travelTemplateNameTitle => 'Save as a packing list';

  @override
  String travelTemplateSaved(String name) {
    return 'Saved “$name”';
  }

  @override
  String get travelItemNewTitle => 'New item';

  @override
  String get travelItemEditTitle => 'Edit item';

  @override
  String get travelFieldItem => 'Item';

  @override
  String get travelItemRequired => 'Enter the item';

  @override
  String get travelFieldCategory => 'Category';

  @override
  String get travelMoveToCategory => 'Move to a category';

  @override
  String get travelItemPacked => 'Packed';

  @override
  String get travelItemNotPacked => 'Not packed yet';

  @override
  String get travelPack => 'Pack';

  @override
  String get travelUnpack => 'Unpack';

  @override
  String get travelCatDocuments => 'Papers & money';

  @override
  String get travelCatClothes => 'Clothes';

  @override
  String get travelCatToiletries => 'Toiletries';

  @override
  String get travelCatHealth => 'Health';

  @override
  String get travelCatElectronics => 'Electronics';

  @override
  String get travelCatPrayer => 'Prayer & worship';

  @override
  String get travelCatMisc => 'Other';

  @override
  String get travelCatNew => 'New category';

  @override
  String get travelCatNewHint => 'Category name';

  @override
  String travelPrayerTitle(String place) {
    return 'Prayer in $place';
  }

  @override
  String get travelPrayerMethodNote =>
      'Your calculation settings, in the destination\'s time';

  @override
  String travelPrayerNext(String prayer, String duration) {
    return '$prayer in $duration';
  }

  @override
  String get travelPrayerUseHere =>
      'Use as my prayer location while travelling';

  @override
  String get travelPrayerIsLocation => 'This is your prayer location now';

  @override
  String travelPrayerUsed(String place) {
    return 'Your prayer times now follow $place';
  }

  @override
  String get travelPrayerNoPlace =>
      'Pick the destination from the city list to see its prayer times and qibla.';

  @override
  String get travelPrayerPickCity => 'Pick the city';

  @override
  String get travelPrayerToday => 'Today';

  @override
  String get travelQiblaTitle => 'Qibla from there';

  @override
  String travelQiblaBearing(String bearing) {
    return '$bearing from north';
  }

  @override
  String travelQiblaDistance(String distance) {
    return '$distance to the Kaaba';
  }

  @override
  String get travelQiblaAtKaaba => 'At the Kaaba';

  @override
  String travelQiblaSemantics(String bearing) {
    return 'Qibla direction $bearing';
  }

  @override
  String travelWarnBeforeTrip(String doc, String date) {
    return '$doc expires before you leave ($date)';
  }

  @override
  String travelWarnDuringTrip(String doc, String date) {
    return '$doc expires during the trip ($date)';
  }

  @override
  String travelWarnValidity(String doc, String months) {
    return '$doc expires less than $months months after your return – many countries ask for more';
  }

  @override
  String travelWarnTrip(String destination) {
    return 'Trip to $destination';
  }

  @override
  String get travelDocsEmptyTitle => 'No documents yet';

  @override
  String get travelDocsEmptyBody =>
      'Record passports, visas and licences: Madar reminds you before they expire and warns you if one runs out before a trip.';

  @override
  String get travelDocNew => 'New document';

  @override
  String get travelDocEdit => 'Edit document';

  @override
  String get travelDocSubtitle =>
      'A reminder before it expires, as early as you choose';

  @override
  String get travelDocName => 'Document';

  @override
  String get travelDocNameHint => 'Passport, visa, driving licence…';

  @override
  String get travelDocNameRequired => 'Enter the document';

  @override
  String get travelDocHolder => 'Holder';

  @override
  String get travelDocHolderHint => 'Whose document is it?';

  @override
  String get travelDocNumber => 'Number';

  @override
  String get travelDocExpiry => 'Expiry date';

  @override
  String get travelDocRemind => 'Remind me';

  @override
  String travelDocNumberShort(String last) {
    return 'No. $last';
  }

  @override
  String get travelRemindOnDay => 'Only on the day';

  @override
  String get travelRemindWeek => '1 week before';

  @override
  String get travelRemindTwoWeeks => '2 weeks before';

  @override
  String get travelRemindMonth => '1 month before';

  @override
  String get travelRemindTwoMonths => '2 months before';

  @override
  String travelRemindMonths(String n) {
    return '$n months before';
  }

  @override
  String travelRemindDays(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n days before',
      one: '1 day before',
      zero: 'Only on the day',
    );
    return '$_temp0';
  }

  @override
  String travelRemindSummary(String when) {
    return 'Reminder: $when';
  }

  @override
  String get travelExpiresToday => 'Expires today';

  @override
  String travelExpiresInDays(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Expires in $n days',
      one: 'Expires tomorrow',
    );
    return '$_temp0';
  }

  @override
  String travelExpiresInMonths(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Expires in $n months',
      one: 'Expires in 1 month',
    );
    return '$_temp0';
  }

  @override
  String travelExpiresInYears(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Expires in $n years',
      one: 'Expires in 1 year',
    );
    return '$_temp0';
  }

  @override
  String travelExpiredAgo(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Expired $n days ago',
      one: 'Expired yesterday',
    );
    return '$_temp0';
  }

  @override
  String travelExpiredOn(String date) {
    return 'Expired on $date';
  }

  @override
  String get travelNoExpiry => 'No expiry date';

  @override
  String get travelDocKindPassport => 'Passport';

  @override
  String get travelDocKindVisa => 'Visa';

  @override
  String get travelDocKindLicence => 'Licence';

  @override
  String get travelDocKindId => 'ID';

  @override
  String get travelDocKindInsurance => 'Insurance';

  @override
  String get travelDocKindOther => 'Document';

  @override
  String travelDocAffects(String destination) {
    return 'Affects the trip to $destination';
  }

  @override
  String get travelNoticeGroup => 'Travel';

  @override
  String get travelNoticeChannel => 'Document expiry';

  @override
  String get travelNoticeChannelDescription =>
      'Reminders before passports, visas and licences expire';

  @override
  String travelNoticeTitle(String doc, String when) {
    return '$doc: $when';
  }

  @override
  String travelNoticeAheadBody(String date) {
    return 'It expires on $date. Start renewing early so no trip is held up.';
  }

  @override
  String get travelNoticeOnDayBody =>
      'It expires today. Renew it before your next trip.';

  @override
  String travelDocWithHolder(String doc, String holder) {
    return '$doc ($holder)';
  }

  @override
  String get travelTemplatesTitle => 'Packing lists';

  @override
  String get travelTemplatesEmptyTitle => 'No packing lists yet';

  @override
  String get travelTemplatesEmptyBody =>
      'A packing list fills any trip\'s checklist in one tap, and remembers what you usually forget.';

  @override
  String get travelTemplatesStarter => 'Add suggested lists';

  @override
  String get travelTemplatesStarterAdded =>
      'Suggested lists added; edit them as you like';

  @override
  String travelTemplateItems(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n items',
      one: '1 item',
      zero: 'No items',
    );
    return '$_temp0';
  }

  @override
  String get travelTemplateNew => 'New packing list';

  @override
  String get travelTemplateRename => 'Rename';

  @override
  String get travelTemplateName => 'Name';

  @override
  String get travelTemplateNameHint => 'e.g. Business trip';

  @override
  String get travelTemplateNameRequired => 'Enter a name';

  @override
  String get travelTemplateEmptyItems =>
      'Add this list\'s items and drag to order them.';

  @override
  String travelTemplateCopy(String name) {
    return '$name (copy)';
  }

  @override
  String get travelStarterEssentials => 'Essentials';

  @override
  String get travelStarterBusiness => 'Business trip';

  @override
  String get travelStarterUmrah => 'Umrah';

  @override
  String get travelStarterWinter => 'Winter trip';

  @override
  String get travelSeedPassport => 'Passport';

  @override
  String get travelSeedTickets => 'Tickets & bookings';

  @override
  String get travelSeedWallet => 'Wallet & cards';

  @override
  String get travelSeedCash => 'Local cash';

  @override
  String get travelSeedClothes => 'Clothes for each day';

  @override
  String get travelSeedSleepwear => 'Sleepwear';

  @override
  String get travelSeedToothbrush => 'Toothbrush & toothpaste';

  @override
  String get travelSeedMiswak => 'Miswak';

  @override
  String get travelSeedDeodorant => 'Deodorant';

  @override
  String get travelSeedMeds => 'My usual medicines';

  @override
  String get travelSeedFirstAid => 'First-aid kit';

  @override
  String get travelSeedCharger => 'Phone charger';

  @override
  String get travelSeedPowerBank => 'Power bank';

  @override
  String get travelSeedAdapter => 'Plug adapter';

  @override
  String get travelSeedPrayerMat => 'Travel prayer mat';

  @override
  String get travelSeedQuran => 'Pocket Quran';

  @override
  String get travelSeedLaptop => 'Laptop & charger';

  @override
  String get travelSeedFormal => 'Formal clothes';

  @override
  String get travelSeedCards => 'Business cards';

  @override
  String get travelSeedNotebook => 'Notebook & pen';

  @override
  String get travelSeedIhram => 'Ihram garments';

  @override
  String get travelSeedIhramBelt => 'Ihram belt';

  @override
  String get travelSeedUnscented => 'Unscented soap';

  @override
  String get travelSeedSandals => 'Comfortable sandals';

  @override
  String get travelSeedShoeBag => 'Shoe bag';

  @override
  String get travelSeedUmbrella => 'Sun umbrella';

  @override
  String get travelSeedDuas => 'Book of duas';

  @override
  String get travelSeedWater => 'Water bottle';

  @override
  String get travelSeedPermit => 'Umrah permit';

  @override
  String get travelSeedCoat => 'Warm coat';

  @override
  String get travelSeedScarf => 'Scarf & gloves';

  @override
  String get travelSeedThermal => 'Thermal layers';

  @override
  String get travelSeedLipBalm => 'Lip balm';

  @override
  String get travelCardNoTrips => 'No trips coming up';

  @override
  String travelCardPacked(String packed, String total) {
    return '$packed/$total packed';
  }

  @override
  String get travelCardNoPacking => 'Packing list not started';

  @override
  String travelCardNext(String destination, String countdown) {
    return 'Next trip: $destination · $countdown';
  }

  @override
  String travelCardDocsAttention(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n documents need attention',
      one: '1 document needs attention',
    );
    return '$_temp0';
  }

  @override
  String get travelUndoTripDeleted => 'Trip deleted';

  @override
  String get travelUndoTripDuplicated => 'Trip duplicated';

  @override
  String get travelUndoItemDeleted => 'Item removed';

  @override
  String get travelUndoPacked => 'Packed';

  @override
  String get travelUndoUnpacked => 'Unpacked';

  @override
  String travelUndoMoved(String category) {
    return 'Moved to $category';
  }

  @override
  String get travelUndoDocDeleted => 'Document deleted';

  @override
  String get travelUndoDocDuplicated => 'Document duplicated';

  @override
  String get travelUndoTemplateDeleted => 'List deleted';

  @override
  String get travelUndoTemplateDuplicated => 'List duplicated';

  @override
  String travelUndoStatus(String status) {
    return 'Trip is now: $status';
  }

  @override
  String get travelUndoUnpackedAll => 'Everything unpacked';

  @override
  String get travelUndoSaved => 'Changes saved';

  @override
  String travelUndoReminder(String when) {
    return 'Reminder: $when';
  }

  @override
  String travelOpenTrip(String destination) {
    return 'Open the trip to $destination';
  }

  @override
  String get travelMore => 'More';

  @override
  String get travelEdit => 'Edit';

  @override
  String get travelTripNotFound => 'This trip no longer exists';

  @override
  String get growthTitle => 'Learning goals';

  @override
  String get growthNewGoal => 'New goal';

  @override
  String get growthEditGoal => 'Edit goal';

  @override
  String get growthEmptyTitle => 'Start a learning journey';

  @override
  String get growthEmptyBody =>
      'Set a goal you can measure and log your progress as you go – like reading a 300-page book or finishing a 12-lesson course.';

  @override
  String get growthEmptyAction => 'Add your first goal';

  @override
  String get growthSectionActive => 'In progress';

  @override
  String get growthSectionCompleted => 'Completed';

  @override
  String get growthSectionPaused => 'Paused';

  @override
  String get growthSectionHint => 'Drag the handle to reorder';

  @override
  String get growthOverviewTitle => 'Your learning';

  @override
  String growthActiveGoals(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active goals',
      one: '1 active goal',
      zero: 'No active goals',
    );
    return '$_temp0';
  }

  @override
  String growthCompletedGoals(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count completed',
      one: '1 completed',
      zero: 'None completed',
    );
    return '$_temp0';
  }

  @override
  String growthLoggedToday(String done, String total) {
    return 'Logged today on $done of $total';
  }

  @override
  String get growthNothingToday => 'Nothing logged yet today';

  @override
  String get growthAverageLabel => 'Average';

  @override
  String get growthLastSevenDays => 'Last seven days';

  @override
  String growthDayActive(String day) {
    return '$day: progress logged';
  }

  @override
  String growthDayIdle(String day) {
    return '$day: nothing logged';
  }

  @override
  String get growthStreakLabel => 'Streak';

  @override
  String growthStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count-day streak',
      one: '1-day streak',
      zero: 'No streak yet',
    );
    return '$_temp0';
  }

  @override
  String growthBestStreak(String days) {
    return 'Best: $days';
  }

  @override
  String get growthStreakAtRisk => 'Log today to keep your streak';

  @override
  String get growthActiveDaysLabel => 'Active days';

  @override
  String growthDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get growthUnitPagesName => 'pages';

  @override
  String growthUnitPages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages',
      one: '1 page',
    );
    return '$_temp0';
  }

  @override
  String growthUnitPagesDecimal(String amount) {
    return '$amount pages';
  }

  @override
  String get growthUnitLessonsName => 'lessons';

  @override
  String growthUnitLessons(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lessons',
      one: '1 lesson',
    );
    return '$_temp0';
  }

  @override
  String growthUnitLessonsDecimal(String amount) {
    return '$amount lessons';
  }

  @override
  String get growthUnitHoursName => 'hours';

  @override
  String growthUnitHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String growthUnitHoursDecimal(String amount) {
    return '$amount hours';
  }

  @override
  String get growthUnitChaptersName => 'chapters';

  @override
  String growthUnitChapters(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapters',
      one: '1 chapter',
    );
    return '$_temp0';
  }

  @override
  String growthUnitChaptersDecimal(String amount) {
    return '$amount chapters';
  }

  @override
  String get growthUnitCoursesName => 'courses';

  @override
  String growthUnitCourses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count courses',
      one: '1 course',
    );
    return '$_temp0';
  }

  @override
  String growthUnitCoursesDecimal(String amount) {
    return '$amount courses';
  }

  @override
  String get growthUnitWordsName => 'words';

  @override
  String growthUnitWords(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count words',
      one: '1 word',
    );
    return '$_temp0';
  }

  @override
  String growthUnitWordsDecimal(String amount) {
    return '$amount words';
  }

  @override
  String get growthUnitBooksName => 'books';

  @override
  String growthUnitBooks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count books',
      one: '1 book',
    );
    return '$_temp0';
  }

  @override
  String growthUnitBooksDecimal(String amount) {
    return '$amount books';
  }

  @override
  String get growthUnitLecturesName => 'lectures';

  @override
  String growthUnitLectures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lectures',
      one: '1 lecture',
    );
    return '$_temp0';
  }

  @override
  String growthUnitLecturesDecimal(String amount) {
    return '$amount lectures';
  }

  @override
  String get growthUnitMinutesName => 'minutes';

  @override
  String growthUnitMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String growthUnitMinutesDecimal(String amount) {
    return '$amount minutes';
  }

  @override
  String get growthUnitArticlesName => 'articles';

  @override
  String growthUnitArticles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articles',
      one: '1 article',
    );
    return '$_temp0';
  }

  @override
  String growthUnitArticlesDecimal(String amount) {
    return '$amount articles';
  }

  @override
  String growthAmountCustom(String amount, String unit) {
    return '$amount $unit';
  }

  @override
  String growthProgressOf(String current, String target) {
    return '$current of $target';
  }

  @override
  String growthRemaining(String amount) {
    return '$amount to go';
  }

  @override
  String growthExceeded(String amount) {
    return '$amount past the target';
  }

  @override
  String growthStartedFrom(String amount) {
    return 'Started from $amount';
  }

  @override
  String growthRatePerDay(String amount) {
    return '$amount a day';
  }

  @override
  String growthRatePerWeek(String amount) {
    return '$amount a week';
  }

  @override
  String get growthPaceCompleted => 'Completed';

  @override
  String get growthPacePaused => 'Paused';

  @override
  String get growthPaceNotStarted => 'Not started';

  @override
  String get growthPaceNoDeadline => 'Open-ended';

  @override
  String get growthPaceAhead => 'Ahead';

  @override
  String get growthPaceOnTrack => 'On track';

  @override
  String get growthPaceBehind => 'Behind';

  @override
  String get growthPaceOverdue => 'Overdue';

  @override
  String growthLineNeed(String rate, String date) {
    return 'Needs $rate until $date';
  }

  @override
  String growthLineAhead(String rate) {
    return 'Ahead at $rate';
  }

  @override
  String growthLineStart(String rate, String date) {
    return '$rate gets you there by $date';
  }

  @override
  String get growthLineFirstLog => 'Log your first progress to begin';

  @override
  String growthLineOpen(String rate) {
    return 'Your pace: $rate';
  }

  @override
  String growthLineOpenFinish(String rate, String date) {
    return 'At $rate · done by $date';
  }

  @override
  String get growthLineQuiet => 'Nothing logged in the last two weeks';

  @override
  String growthLineOverdue(String days, String amount) {
    return '$days late · $amount left';
  }

  @override
  String growthLineDueToday(String amount) {
    return 'Due today · $amount left';
  }

  @override
  String growthLineCompleted(String date) {
    return 'Completed on $date';
  }

  @override
  String get growthLinePaused => 'Paused – resume any time';

  @override
  String get growthNeededLabel => 'Needed';

  @override
  String get growthActualLabel => 'Your pace';

  @override
  String growthActualWindow(String days) {
    return 'Last $days';
  }

  @override
  String growthNeededUntil(String date) {
    return 'Until $date';
  }

  @override
  String get growthNoPaceYet => 'No pace yet';

  @override
  String get growthProjectedLabel => 'Projected finish';

  @override
  String growthProjectionEarly(String days) {
    return '$days early';
  }

  @override
  String growthProjectionLate(String days) {
    return '$days late';
  }

  @override
  String get growthProjectionOnDay => 'Right on the deadline';

  @override
  String get growthProjectionNone => 'Log progress to see when you\'ll finish';

  @override
  String get growthPaceNoDeadlineHint => 'No deadline – go at your own pace';

  @override
  String get growthPaceDoneHint => 'Target reached – you can keep logging';

  @override
  String growthPlanBehind(String amount) {
    return '$amount behind plan';
  }

  @override
  String growthPlanAhead(String amount) {
    return '$amount ahead of plan';
  }

  @override
  String growthDaysLeft(String days) {
    return '$days left';
  }

  @override
  String get growthDeadlineLabel => 'Deadline';

  @override
  String get growthChartTitle => 'Trajectory';

  @override
  String get growthChartActual => 'Progress';

  @override
  String get growthChartPlan => 'Plan';

  @override
  String get growthChartTarget => 'Target';

  @override
  String get growthChartProjection => 'Projection';

  @override
  String growthChartSemantics(String current, String target) {
    return 'Progress chart: $current of $target';
  }

  @override
  String get growthHistoryTitle => 'Progress log';

  @override
  String get growthHistoryEmpty =>
      'No entries yet. A small step today makes the difference.';

  @override
  String get growthToday => 'Today';

  @override
  String get growthYesterday => 'Yesterday';

  @override
  String growthRunningTotal(String amount) {
    return 'Total $amount';
  }

  @override
  String growthDayTotal(String amount) {
    return '$amount logged';
  }

  @override
  String get growthLogProgress => 'Log progress';

  @override
  String get growthEditLog => 'Edit entry';

  @override
  String get growthLogOther => 'Other amount';

  @override
  String growthLogQuick(String amount) {
    return 'Log $amount';
  }

  @override
  String get growthLogAmount => 'Amount';

  @override
  String get growthLogWhen => 'When';

  @override
  String get growthLogDate => 'Day';

  @override
  String get growthLogTime => 'Time';

  @override
  String get growthLogNow => 'Now';

  @override
  String get growthLogNote => 'Note';

  @override
  String get growthLogNoteHint => 'What did you learn?';

  @override
  String growthLogNewTotal(String total, String percent) {
    return 'New total: $total ($percent)';
  }

  @override
  String get growthLogWillComplete => 'This completes your goal!';

  @override
  String get growthLogSave => 'Log it';

  @override
  String get growthDecrease => 'Decrease';

  @override
  String get growthIncrease => 'Increase';

  @override
  String get growthErrorAmount => 'Enter an amount above zero';

  @override
  String get growthFieldName => 'Goal name';

  @override
  String get growthFieldNameHint => 'e.g. Read a book on management';

  @override
  String get growthFieldUnit => 'Unit';

  @override
  String get growthFieldUnitHint => 'Pick or type your own';

  @override
  String get growthFieldTarget => 'Target';

  @override
  String get growthFieldInitial => 'Starting from';

  @override
  String get growthFieldInitialHint => 'What you\'ve already done';

  @override
  String get growthFieldDeadline => 'Deadline';

  @override
  String get growthFieldNoDeadline => 'No deadline';

  @override
  String get growthFieldColor => 'Colour';

  @override
  String get growthFieldActive => 'Active';

  @override
  String get growthFieldActiveHint => 'Pause it without losing progress';

  @override
  String get growthInMonth => 'In a month';

  @override
  String get growthInThreeMonths => 'In 3 months';

  @override
  String get growthEndOfYear => 'End of year';

  @override
  String get growthErrorName => 'Give the goal a name';

  @override
  String get growthErrorTarget => 'Enter an amount above zero';

  @override
  String get growthErrorInitial => 'Must be less than the target';

  @override
  String growthPreviewNeed(String rate, String date) {
    return '$rate gets you there by $date';
  }

  @override
  String get growthPreviewOpen => 'No deadline: log at whatever pace suits you';

  @override
  String get growthPreviewPast => 'That date has passed – pick one ahead';

  @override
  String get growthCreate => 'Create goal';

  @override
  String get growthSave => 'Save';

  @override
  String get growthCancel => 'Cancel';

  @override
  String get growthPause => 'Pause';

  @override
  String get growthResume => 'Resume';

  @override
  String get growthDelete => 'Delete';

  @override
  String get growthEdit => 'Edit';

  @override
  String growthCopyName(String name) {
    return '$name (copy)';
  }

  @override
  String growthLogged(String amount, String goal) {
    return 'Logged $amount · $goal';
  }

  @override
  String get growthLogUpdated => 'Entry updated';

  @override
  String get growthLogDeleted => 'Entry deleted';

  @override
  String growthGoalCreated(String name) {
    return 'Goal added: $name';
  }

  @override
  String get growthGoalSaved => 'Changes saved';

  @override
  String growthGoalDeleted(String name) {
    return 'Goal deleted: $name';
  }

  @override
  String get growthGoalDuplicated => 'Goal duplicated';

  @override
  String get growthGoalPaused => 'Goal paused';

  @override
  String get growthGoalResumed => 'Goal resumed';

  @override
  String get growthGoalMissing => 'This goal no longer exists';

  @override
  String get growthCelebrateTitle => 'Goal complete – well done!';

  @override
  String growthCelebrateBody(String amount, String days) {
    return '$amount in $days';
  }

  @override
  String get growthCelebrateThanks => 'Alhamdulillah';

  @override
  String get growthCelebrateNext => 'Set a new goal';

  @override
  String get growthCardTitle => 'Growth today';

  @override
  String get growthCardOpenAll => 'All goals';

  @override
  String get growthCardEmpty =>
      'No learning goals yet. Add one and follow it here.';

  @override
  String get growthCardAllDone => 'Every active goal is complete – well done';

  @override
  String get growthOpenGoal => 'Open goal';

  @override
  String growthGoalSemantics(String name, String progress, String status) {
    return '$name, $progress, $status';
  }

  @override
  String get growthSep => ' · ';

  @override
  String get growthPaceTitle => 'Pace';

  @override
  String get growthStatsDeadlineNone => 'None';

  @override
  String growthStartedOn(String date) {
    return 'Started $date';
  }

  @override
  String get growthAllActiveDone =>
      'Nothing in progress right now. What\'s next?';

  @override
  String growthOverdueBy(String days) {
    return '$days overdue';
  }

  @override
  String growthOfDays(String days) {
    return 'of $days';
  }

  @override
  String get bodyTitle => 'Body';

  @override
  String get bodyTabToday => 'Today';

  @override
  String get bodyTabPlan => 'Plan';

  @override
  String get bodyTabFasting => 'Fasting';

  @override
  String get bodyTabWater => 'Water';

  @override
  String get bodyTabAvoid => 'Avoid';

  @override
  String get bodySave => 'Save';

  @override
  String get bodyCancel => 'Cancel';

  @override
  String get bodyDelete => 'Delete';

  @override
  String get bodyNameRequired => 'Enter a name';

  @override
  String bodyKg(String value) {
    return '$value kg';
  }

  @override
  String bodyMinutes(String value) {
    return '$value min';
  }

  @override
  String bodyHours(String value) {
    return '$value h';
  }

  @override
  String bodyRepsValue(String value) {
    return '$value reps';
  }

  @override
  String bodySetsReps(String sets, String reps) {
    return '$sets × $reps';
  }

  @override
  String bodyMl(String value) {
    return '$value ml';
  }

  @override
  String bodyLiters(String value) {
    return '$value L';
  }

  @override
  String bodyFraction(String done, String total) {
    return '$done of $total';
  }

  @override
  String bodyDaysInRow(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n days in a row',
      one: '1 day in a row',
      zero: 'No streak yet',
    );
    return '$_temp0';
  }

  @override
  String bodyExercisesCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n exercises',
      one: '1 exercise',
      zero: 'No exercises',
    );
    return '$_temp0';
  }

  @override
  String bodyPerWeek(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n× a week',
      two: 'Twice a week',
      one: 'Once a week',
      zero: 'No set days',
    );
    return '$_temp0';
  }

  @override
  String get bodyTodaySession => 'Today\'s session';

  @override
  String get bodyRestDay => 'Rest day';

  @override
  String get bodyRestDayBody => 'Nothing planned today. Enjoy the rest.';

  @override
  String bodyNextSession(String day) {
    return 'Next session: $day';
  }

  @override
  String get bodySessionDone => 'Today\'s session is done — well done!';

  @override
  String get bodySessionKeepGoing =>
      'One at a time — swipe an exercise to log it.';

  @override
  String get bodyNoPlanTitle => 'No training plan yet';

  @override
  String get bodyNoPlanBody =>
      'Add your exercises and their days in the Plan tab; each shows up here on its day.';

  @override
  String get bodyOpenPlan => 'Go to plan';

  @override
  String get bodyAlsoToday => 'Also today';

  @override
  String get bodyLogExtra => 'Log a workout';

  @override
  String get bodyMarkDone => 'Done';

  @override
  String get bodyUnmark => 'Mark not done';

  @override
  String bodyLogged(String summary) {
    return 'Done: $summary';
  }

  @override
  String bodyLoggedToast(String name) {
    return 'Logged “$name”';
  }

  @override
  String bodyUnloggedToast(String name) {
    return 'Removed the log for “$name”';
  }

  @override
  String get bodyLogDetails => 'Log with details';

  @override
  String get bodyAvoidReminder => 'Remember to avoid';

  @override
  String get bodyStateDone => 'done';

  @override
  String get bodyStateOpen => 'not done yet';

  @override
  String get bodyPlanWeek => 'This week';

  @override
  String get bodyPlanHint =>
      'Drag the handle to reorder; long-press for more options.';

  @override
  String get bodyPlanEmptyTitle => 'Your plan is empty';

  @override
  String get bodyPlanEmptyBody =>
      'Add your exercises and their days — e.g. push-ups on Sat, Mon and Wed, 3 × 12.';

  @override
  String get bodyAddExercise => 'New exercise';

  @override
  String get bodyEditExercise => 'Edit exercise';

  @override
  String get bodyExerciseSubtitle =>
      'Pick its days and what you aim for each time.';

  @override
  String get bodyExerciseName => 'Exercise name';

  @override
  String get bodyExerciseNameHint => 'e.g. Brisk walk';

  @override
  String get bodyWeekdays => 'Training days';

  @override
  String get bodyEveryDay => 'Every day';

  @override
  String get bodyClearDays => 'Clear';

  @override
  String bodyListAnd(String head, String last) {
    return '$head and $last';
  }

  @override
  String get bodyListSep => ', ';

  @override
  String get bodyPartsSep => ' · ';

  @override
  String get bodyNoDays => 'No set days — it won\'t show up in Today.';

  @override
  String get bodyTarget => 'Each time';

  @override
  String get bodySets => 'Sets';

  @override
  String get bodyReps => 'Reps';

  @override
  String get bodyWeight => 'Weight';

  @override
  String get bodyDuration => 'Duration';

  @override
  String get bodyNotes => 'Notes';

  @override
  String get bodyNotesHint => 'e.g. Focus on form';

  @override
  String get bodyUnitKg => 'kg';

  @override
  String get bodyUnitMin => 'min';

  @override
  String get bodyUnitMl => 'ml';

  @override
  String get bodyUnitHours => 'hours';

  @override
  String bodyStepperDecrease(String label) {
    return 'Decrease $label';
  }

  @override
  String bodyStepperIncrease(String label) {
    return 'Increase $label';
  }

  @override
  String get bodyNotSet => '—';

  @override
  String get bodyExerciseHistory => 'History & progress';

  @override
  String get bodyPause => 'Pause';

  @override
  String get bodyResume => 'Resume';

  @override
  String get bodyPaused => 'Paused';

  @override
  String bodyCopyName(String name) {
    return '$name (copy)';
  }

  @override
  String bodyDeletedName(String name) {
    return 'Deleted “$name”';
  }

  @override
  String bodyDuplicatedName(String name) {
    return 'Duplicated “$name”';
  }

  @override
  String bodyPausedName(String name) {
    return 'Paused “$name”';
  }

  @override
  String bodyResumedName(String name) {
    return '“$name” is back in the plan';
  }

  @override
  String get bodyLogTitle => 'Log workout';

  @override
  String get bodyLogEditTitle => 'Edit log';

  @override
  String get bodyLogSubtitle =>
      'Prefilled from your plan — adjust to what you actually did.';

  @override
  String get bodyLogExtraSubtitle => 'Something outside the plan? Log it here.';

  @override
  String get bodyYesterday => 'Yesterday';

  @override
  String get bodyLogWhen => 'When';

  @override
  String get bodyLogSave => 'Log it';

  @override
  String get bodyWorkoutName => 'Workout';

  @override
  String get bodyWorkoutNameHint => 'e.g. Swimming';

  @override
  String bodyLogVolume(String value) {
    return 'Volume: $value';
  }

  @override
  String get bodyHistoryEmpty =>
      'No logs yet. Your progress shows up here once you do this exercise.';

  @override
  String get bodyHistoryOneDay => 'The chart appears after two days of logs.';

  @override
  String get bodyMetricWeight => 'Weight';

  @override
  String get bodyMetricVolume => 'Volume';

  @override
  String get bodyMetricReps => 'Reps';

  @override
  String get bodyMetricMinutes => 'Minutes';

  @override
  String get bodyBest => 'Best';

  @override
  String get bodyChange => 'Change';

  @override
  String get bodySessions => 'Sessions';

  @override
  String get bodyVolumeHint => 'Volume = sets × reps × weight';

  @override
  String get bodyLogs => 'Logs';

  @override
  String get bodyLogDeleted => 'Log deleted';

  @override
  String get bodyLogUpdated => 'Log updated';

  @override
  String get bodyFastingTitle => 'Intermittent fasting';

  @override
  String get bodyFastPhaseFasting => 'Fasting';

  @override
  String get bodyFastPhaseEating => 'Eating window';

  @override
  String get bodyFastPhaseWaiting => 'Not fasting';

  @override
  String bodyFastRemaining(String time) {
    return '$time left';
  }

  @override
  String bodyFastGoalAt(String time) {
    return 'Goal at $time';
  }

  @override
  String get bodyFastReached => 'Goal reached!';

  @override
  String bodyFastOvertime(String time) {
    return '$time past your goal';
  }

  @override
  String get bodyFastTimeNow => 'Time to start your fast';

  @override
  String bodyEatingOpenSince(String time) {
    return 'Open since $time';
  }

  @override
  String bodyEatingClosesAt(String time) {
    return 'Last meal $time';
  }

  @override
  String bodyNextFastAt(String time) {
    return 'Next fast $time';
  }

  @override
  String bodyWindowOpensAt(String time) {
    return 'Eating window opens $time';
  }

  @override
  String get bodyStartFast => 'Start fast';

  @override
  String get bodyEndFast => 'End fast';

  @override
  String get bodyStartedEarlier => 'Started earlier?';

  @override
  String get bodyFastStartTitle => 'When did your fast start?';

  @override
  String get bodyFastStarted => 'Fast started — you\'ve got this';

  @override
  String bodyFastEnded(String duration) {
    return 'Fast ended: $duration';
  }

  @override
  String get bodyFastPlan => 'Fasting plan';

  @override
  String get bodyFastHours => 'Fasting hours';

  @override
  String get bodyFastCustom => 'Custom';

  @override
  String get bodyFastCustomTitle => 'Custom fasting hours';

  @override
  String get bodyFastCustomHint => '1 to 72 hours';

  @override
  String bodyFastRatioHint(String fast, String eat) {
    return '$fast h fasting, then $eat h to eat';
  }

  @override
  String bodyFastLongHint(String fast) {
    return '$fast h fast, no daily eating window';
  }

  @override
  String get bodyLastMeal => 'Last meal';

  @override
  String get bodyLastMealHint => 'Your planned fast starts then.';

  @override
  String get bodyNotifyGoal => 'Notify me when I reach my goal';

  @override
  String get bodyNotifyEating => 'Remind me before the eating window closes';

  @override
  String bodyLeadBefore(String n) {
    return '$n min before';
  }

  @override
  String get bodyLeadAtTime => 'On time';

  @override
  String get bodyStatStreak => 'Streak';

  @override
  String get bodyStatLongest => 'Longest';

  @override
  String get bodyStatAverage => 'Average';

  @override
  String get bodyStatCompleted => 'Goal reached';

  @override
  String get bodyFastHistory => 'Fasting history';

  @override
  String get bodyFastHistoryEmpty =>
      'No fasts yet. Tap “Start fast” after your last meal.';

  @override
  String bodyFastGoalBadge(String hours) {
    return 'Goal $hours h';
  }

  @override
  String get bodyFastEditTitle => 'Edit fast';

  @override
  String get bodyFastStartDate => 'Start date';

  @override
  String get bodyFastStartTime => 'Start time';

  @override
  String get bodyFastEndDate => 'End date';

  @override
  String get bodyFastEndTime => 'End time';

  @override
  String get bodyFastGoalHours => 'Goal';

  @override
  String get bodyFastNote => 'Note';

  @override
  String get bodyFastNoteHint => 'e.g. Ramadan, a voluntary fast';

  @override
  String get bodyFastEndBeforeStart => 'The end is before the start';

  @override
  String get bodyFastInFuture => 'That time hasn\'t come yet';

  @override
  String get bodyFastDeleted => 'Fast deleted';

  @override
  String get bodyFastUpdated => 'Fast updated';

  @override
  String bodyFastRingSemantics(String phase, String detail) {
    return '$phase: $detail';
  }

  @override
  String get bodyWaterTitle => 'Water';

  @override
  String bodyWaterOf(String target) {
    return 'of $target';
  }

  @override
  String bodyAddAmount(String amount) {
    return '+$amount';
  }

  @override
  String bodyAddWaterSemantics(String amount) {
    return 'Add $amount';
  }

  @override
  String get bodyWaterCustom => 'Other amount';

  @override
  String get bodyWaterCustomTitle => 'How much did you drink?';

  @override
  String get bodyWaterAmount => 'Amount';

  @override
  String get bodyWaterTarget => 'Daily target';

  @override
  String get bodyWaterTargetTitle => 'Daily water target';

  @override
  String bodyWaterTargetSaved(String amount) {
    return 'Target is now $amount';
  }

  @override
  String get bodyWaterGoalMet => 'Today\'s target reached!';

  @override
  String bodyWaterLeft(String amount) {
    return '$amount to go';
  }

  @override
  String get bodyWaterWeek => 'Past week';

  @override
  String bodyWaterAverage(String amount) {
    return 'Average $amount';
  }

  @override
  String get bodyWaterToday => 'Today\'s log';

  @override
  String get bodyWaterEmptyToday =>
      'No water logged today yet — one glass is a good start.';

  @override
  String bodyWaterAdded(String amount) {
    return 'Added $amount';
  }

  @override
  String bodyWaterRemoved(String amount) {
    return 'Removed $amount';
  }

  @override
  String get bodyWaterEditTitle => 'Edit amount';

  @override
  String get bodyWaterUpdated => 'Amount updated';

  @override
  String get bodyAvoidTitle => 'Avoid list';

  @override
  String get bodyAvoidSubtitle =>
      'Movements and foods you\'ve chosen to stay away from, with your own reasons.';

  @override
  String get bodyAvoidAdd => 'Add to the list';

  @override
  String get bodyAvoidEdit => 'Edit item';

  @override
  String get bodyAvoidWhat => 'What to avoid';

  @override
  String get bodyAvoidWhatHint => 'e.g. Overhead lifting';

  @override
  String get bodyAvoidReason => 'Reason';

  @override
  String get bodyAvoidReasonHint => 'e.g. As my specialist advised';

  @override
  String get bodyAvoidEmptyTitle => 'Nothing here yet';

  @override
  String get bodyAvoidEmptyBody =>
      'Note what you want to avoid and why — e.g. fizzy drinks, or deep squats.';

  @override
  String get bodyAvoidRemoved => 'Removed from the list';

  @override
  String get bodyAvoidNoReason => 'No reason noted';

  @override
  String get bodyCardTitle => 'Body today';

  @override
  String get bodyCardTraining => 'Training';

  @override
  String get bodyCardFasting => 'Fasting';

  @override
  String get bodyCardWater => 'Water';

  @override
  String get bodyNotifyGroup => 'Body';

  @override
  String get bodyNotifyChannel => 'Fasting reminders';

  @override
  String get bodyNotifyChannelDescription =>
      'Fasting goal reached and eating window closing';

  @override
  String get bodyNotifyGoalTitle => 'You reached your fasting goal';

  @override
  String bodyNotifyGoalBody(String hours) {
    return 'You fasted $hours h — well done.';
  }

  @override
  String get bodyNotifyEatingTitle => 'Eating window closing soon';

  @override
  String bodyNotifyEatingBody(String time) {
    return 'Last meal at $time.';
  }

  @override
  String get bodyNotifyHint => 'Needs notification permission on the phone.';

  @override
  String get cmodTitle => 'Trackers & lists';

  @override
  String get cmodNewModule => 'New module';

  @override
  String cmodModulesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modules',
      one: '1 module',
      zero: 'No modules yet',
    );
    return '$_temp0';
  }

  @override
  String cmodLoggedToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries today',
      one: '1 entry today',
      zero: 'Nothing logged today yet',
    );
    return '$_temp0';
  }

  @override
  String cmodEntriesCount(int count) {
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
  String cmodItemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
      zero: 'no items',
    );
    return '$_temp0';
  }

  @override
  String cmodItemsProgress(String done, String total) {
    return '$done of $total done';
  }

  @override
  String cmodOpenItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items left',
      one: '1 item left',
      zero: 'Nothing left',
    );
    return '$_temp0';
  }

  @override
  String get cmodEmptyTitle => 'Build your first tracker';

  @override
  String get cmodEmptyBody =>
      'Track what matters with your own fields – a reading log, dhikr after prayer, a habit list… and watch it feed your planets.';

  @override
  String get cmodEmptyAction => 'Create a module';

  @override
  String get cmodArchivedSection => 'Archived';

  @override
  String get cmodKindTracker => 'Tracker';

  @override
  String get cmodKindList => 'List';

  @override
  String get cmodKindTrackerHint => 'Values you log over time, with charts';

  @override
  String get cmodKindListHint => 'Items you check off and reorder';

  @override
  String get cmodLastToday => 'Last entry today';

  @override
  String get cmodLastYesterday => 'Last entry yesterday';

  @override
  String cmodLastDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Last entry $count days ago',
      one: 'Last entry a day ago',
    );
    return '$_temp0';
  }

  @override
  String get cmodNoEntries => 'No entries yet';

  @override
  String cmodStreakBadge(String count) {
    return '$count-day streak';
  }

  @override
  String get cmodActionArchive => 'Archive';

  @override
  String get cmodActionUnarchive => 'Unarchive';

  @override
  String get cmodActionAddEntry => 'New entry';

  @override
  String get cmodActionOpen => 'Open';

  @override
  String get cmodActionExport => 'Share as CSV';

  @override
  String get cmodActionUncheck => 'Reopen';

  @override
  String get cmodActionCheck => 'Check off';

  @override
  String cmodToastArchived(String name) {
    return 'Archived “$name”';
  }

  @override
  String cmodToastUnarchived(String name) {
    return '“$name” is back';
  }

  @override
  String cmodToastDeleted(String name) {
    return 'Deleted “$name”';
  }

  @override
  String cmodToastDuplicated(String name) {
    return 'Duplicated “$name”';
  }

  @override
  String cmodToastLogged(String name) {
    return 'Logged to “$name”';
  }

  @override
  String get cmodToastUnchecked => 'Today’s check-in removed';

  @override
  String get cmodToastEntryDeleted => 'Entry deleted';

  @override
  String get cmodToastEntryDuplicated => 'Entry duplicated';

  @override
  String get cmodToastItemDone => 'Item done';

  @override
  String get cmodToastItemReopened => 'Item reopened';

  @override
  String get cmodToastCleared => 'Done items cleared';

  @override
  String cmodToastSaved(String name) {
    return 'Saved “$name”';
  }

  @override
  String get cmodToastReminderDeleted => 'Reminder deleted';

  @override
  String get cmodToastReminderAdded => 'Reminder added';

  @override
  String get cmodQuickDone => 'Done today';

  @override
  String get cmodQuickDoneHint => 'Log today with one tap';

  @override
  String get cmodQuickChecked => 'Done for today';

  @override
  String get cmodQuickCheckedHint => 'Tap to undo today’s check-in';

  @override
  String get cmodQuickAddOne => 'Log one';

  @override
  String get cmodQuickRate => 'Rate today';

  @override
  String cmodRateStars(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stars',
      one: '1 star',
    );
    return '$_temp0';
  }

  @override
  String get cmodBuilderNewTitle => 'New module';

  @override
  String get cmodBuilderEditTitle => 'Edit module';

  @override
  String get cmodSectionBasics => 'Basics';

  @override
  String get cmodName => 'Name';

  @override
  String get cmodNameHint => 'e.g. Reading log';

  @override
  String get cmodKind => 'Kind';

  @override
  String get cmodIcon => 'Icon';

  @override
  String get cmodColor => 'Colour';

  @override
  String get cmodPlanet => 'Planet';

  @override
  String get cmodPlanetNone => 'No planet';

  @override
  String get cmodPlanetHint =>
      'Every entry brings this planet to life and circles it as a moon';

  @override
  String get cmodWindow => 'Prayer window';

  @override
  String get cmodWindowHint => 'When you usually log it';

  @override
  String get cmodSectionFields => 'Fields';

  @override
  String get cmodAddField => 'Add field';

  @override
  String get cmodFieldsEmptyTracker =>
      'With no fields, a tracker is a one-tap counter';

  @override
  String get cmodFieldsEmptyList =>
      'Add at least one field, such as the item’s name';

  @override
  String get cmodHiddenFields => 'Hidden fields';

  @override
  String get cmodHiddenFieldsHint =>
      'Removed from the form – their old data is kept';

  @override
  String get cmodRestoreField => 'Show again';

  @override
  String get cmodSectionChart => 'Chart';

  @override
  String get cmodChartField => 'What to plot';

  @override
  String get cmodChartEntries => 'Number of entries';

  @override
  String get cmodChartStyle => 'Style';

  @override
  String get cmodChartRange => 'Period';

  @override
  String get cmodChartLine => 'Line';

  @override
  String get cmodChartBar => 'Bars';

  @override
  String get cmodChartHeat => 'Calendar';

  @override
  String get cmodChartStreak => 'Streak';

  @override
  String get cmodChartEmpty => 'No data in this period yet';

  @override
  String cmodRangeDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get cmodSave => 'Save';

  @override
  String get cmodCreate => 'Create';

  @override
  String get cmodCancel => 'Cancel';

  @override
  String get cmodDiscardTitle => 'Discard changes?';

  @override
  String get cmodDiscardBody => 'Your changes to this module are not saved.';

  @override
  String get cmodDiscard => 'Discard';

  @override
  String get cmodKeepEditing => 'Keep editing';

  @override
  String get cmodPreviewUntitled => 'Untitled module';

  @override
  String get cmodIssueNameMissing => 'Give the module a name';

  @override
  String get cmodIssueNameTooLong => 'The name is too long';

  @override
  String get cmodIssueNoFields => 'Add at least one field';

  @override
  String cmodIssueTooManyFields(String max) {
    return '$max fields at most';
  }

  @override
  String get cmodIssueLabelMissing => 'A field has no name';

  @override
  String get cmodIssueLabelDuplicate => 'Two fields share this name';

  @override
  String get cmodIssueNoOptions => 'Add at least one option';

  @override
  String get cmodIssueOptionLabelMissing => 'An option has no name';

  @override
  String get cmodIssueOptionDuplicate => 'Two options share a name';

  @override
  String get cmodIssueRangeInverted => 'The minimum is above the maximum';

  @override
  String get cmodIssueCurrencyCode => 'Not a valid currency code';

  @override
  String get cmodMigrationTitle => 'Before saving';

  @override
  String get cmodMigrationBlockedTitle => 'This change would lose data';

  @override
  String get cmodMigrationBlockedBody =>
      'Nothing was saved. Change the type back, or add a new field with the type you want.';

  @override
  String get cmodMigrationOk => 'OK';

  @override
  String cmodMigTypeBlocked(String field, String entries, String type) {
    return '“$field”: $entries can’t become “$type”';
  }

  @override
  String cmodMigRatingBlocked(String field, String entries) {
    return '“$field”: $entries have more stars than the new scale';
  }

  @override
  String cmodMigFieldHidden(String field, String entries) {
    return '“$field” will be hidden; its values in $entries are kept';
  }

  @override
  String cmodMigOptionHidden(String field) {
    return 'Removed options of “$field” that are in use will be hidden, not deleted';
  }

  @override
  String cmodMigConverted(String field, String entries, String type) {
    return 'Values of “$field” in $entries will be converted to “$type”';
  }

  @override
  String cmodMigOutOfRange(String field, String entries) {
    return '$entries in “$field” are outside the new limits and stay as they are';
  }

  @override
  String cmodMigNewlyRequired(String field, String entries) {
    return '$entries have no value for “$field”, now required';
  }

  @override
  String get cmodTypeText => 'Text';

  @override
  String get cmodTypeNumber => 'Number';

  @override
  String get cmodTypeDate => 'Date';

  @override
  String get cmodTypeTime => 'Time';

  @override
  String get cmodTypeCheckbox => 'Checkbox';

  @override
  String get cmodTypeSingle => 'Single choice';

  @override
  String get cmodTypeMulti => 'Multiple choice';

  @override
  String get cmodTypeRating => 'Star rating';

  @override
  String get cmodTypeCurrency => 'Amount';

  @override
  String get cmodTypeTextHint => 'A note, a book title…';

  @override
  String get cmodTypeNumberHint => 'Pages, minutes, times…';

  @override
  String get cmodTypeDateHint => 'An appointment or occasion';

  @override
  String get cmodTypeTimeHint => 'Bedtime, start time…';

  @override
  String get cmodTypeCheckboxHint => 'Done or not';

  @override
  String get cmodTypeSingleHint => 'One option from your list';

  @override
  String get cmodTypeMultiHint => 'Several options from your list';

  @override
  String get cmodTypeRatingHint => 'Two to ten stars';

  @override
  String get cmodTypeCurrencyHint => 'Money in the currency you choose';

  @override
  String get cmodPickType => 'Field type';

  @override
  String get cmodFieldNew => 'New field';

  @override
  String get cmodFieldEdit => 'Edit field';

  @override
  String get cmodFieldLabel => 'Field name';

  @override
  String get cmodFieldLabelHint => 'e.g. Pages';

  @override
  String get cmodFieldRequired => 'Required';

  @override
  String get cmodFieldRequiredHint => 'An entry can’t be saved without it';

  @override
  String get cmodFieldUnit => 'Unit';

  @override
  String get cmodFieldUnitHint => 'pages, min, kg…';

  @override
  String get cmodFieldMin => 'Minimum';

  @override
  String get cmodFieldMax => 'Maximum';

  @override
  String get cmodFieldNoLimit => 'No limit';

  @override
  String get cmodFieldDecimals => 'Decimal places';

  @override
  String get cmodFieldScale => 'Scale';

  @override
  String get cmodFieldCurrency => 'Currency';

  @override
  String get cmodFieldOptions => 'Options';

  @override
  String get cmodAddOption => 'Add option';

  @override
  String get cmodOptionHint => 'Option name';

  @override
  String get cmodRemoveOption => 'Remove option';

  @override
  String get cmodFieldMultiline => 'Long text';

  @override
  String get cmodFieldMultilineHint => 'Room for several lines';

  @override
  String get cmodFieldDelete => 'Delete field';

  @override
  String cmodFieldCopyLabel(String label) {
    return '$label (copy)';
  }

  @override
  String get cmodFieldTypeNote =>
      'Changing the type converts old values when possible; otherwise the change is not saved.';

  @override
  String cmodFieldOptionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count options',
      one: '1 option',
      zero: 'no options',
    );
    return '$_temp0';
  }

  @override
  String cmodFieldRange(String min, String max) {
    return '$min – $max';
  }

  @override
  String cmodFieldAtLeast(String min) {
    return 'from $min';
  }

  @override
  String cmodFieldAtMost(String max) {
    return 'up to $max';
  }

  @override
  String cmodFieldDeleted(String name) {
    return 'Removed “$name” from the form';
  }

  @override
  String get cmodFieldDuplicated => 'Field duplicated';

  @override
  String get cmodGalleryTitle => 'Start a module';

  @override
  String get cmodGallerySubtitle =>
      'From scratch or a template – everything stays editable';

  @override
  String get cmodBlankTracker => 'Blank tracker';

  @override
  String get cmodBlankList => 'Blank list';

  @override
  String get cmodTemplatesHeader => 'Starter templates';

  @override
  String get cmodTplReadingLog => 'Reading log';

  @override
  String get cmodTplReadingLogDesc => 'Book, pages and your rating';

  @override
  String get cmodTplDhikr => 'Dhikr after prayer';

  @override
  String get cmodTplDhikrDesc => 'How many times, and after which prayer';

  @override
  String get cmodTplHabit => 'Daily habit';

  @override
  String get cmodTplHabitDesc => 'One tap a day, and a growing streak';

  @override
  String get cmodTplHabitList => 'Habit list';

  @override
  String get cmodTplHabitListDesc => 'Habits to build, and how often';

  @override
  String get cmodTplSleep => 'Sleep log';

  @override
  String get cmodTplSleepDesc => 'Bedtime, wake-up, hours and quality';

  @override
  String get cmodTplGifts => 'Gift ideas';

  @override
  String get cmodTplGiftsDesc => 'The idea, who for, budget and occasion';

  @override
  String get cmodTplBook => 'Book';

  @override
  String get cmodTplPages => 'Pages';

  @override
  String get cmodTplRating => 'Rating';

  @override
  String get cmodTplUnitPages => 'pages';

  @override
  String get cmodTplAfterPrayer => 'After prayer';

  @override
  String get cmodTplCount => 'Count';

  @override
  String get cmodTplUnitTimes => 'times';

  @override
  String get cmodTplDone => 'Done';

  @override
  String get cmodTplNote => 'Note';

  @override
  String get cmodTplHabitItem => 'Habit';

  @override
  String get cmodTplFrequency => 'How often';

  @override
  String get cmodTplDaily => 'Daily';

  @override
  String get cmodTplWeekly => 'Weekly';

  @override
  String get cmodTplMonthly => 'Monthly';

  @override
  String get cmodTplBedtime => 'Bedtime';

  @override
  String get cmodTplWake => 'Wake-up';

  @override
  String get cmodTplHours => 'Hours';

  @override
  String get cmodTplUnitHours => 'h';

  @override
  String get cmodTplQuality => 'Quality';

  @override
  String get cmodTplIdea => 'Idea';

  @override
  String get cmodTplFor => 'Who for';

  @override
  String get cmodTplBudget => 'Budget';

  @override
  String get cmodTplOccasion => 'Occasion';

  @override
  String get cmodTplNotes => 'Notes';

  @override
  String get cmodAddEntry => 'New entry';

  @override
  String get cmodAddItem => 'New item';

  @override
  String get cmodEntriesSection => 'Entries';

  @override
  String get cmodItemsSection => 'Items';

  @override
  String get cmodDoneSection => 'Done';

  @override
  String get cmodClearDone => 'Clear done';

  @override
  String get cmodToday => 'Today';

  @override
  String get cmodYesterday => 'Yesterday';

  @override
  String get cmodEntriesEmpty =>
      'No entries yet. The first one starts the story.';

  @override
  String get cmodItemsEmpty => 'The list is empty. Add the first item.';

  @override
  String get cmodAllDone => 'All done – well done';

  @override
  String get cmodStatStreak => 'Streak';

  @override
  String get cmodStatBest => 'Best';

  @override
  String get cmodStatTotal => 'Total';

  @override
  String get cmodStatAverage => 'Average';

  @override
  String get cmodStatActive => 'Active days';

  @override
  String get cmodStatEntries => 'Entries';

  @override
  String get cmodStatRate => 'Check-in rate';

  @override
  String cmodDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get cmodReminders => 'Reminders';

  @override
  String get cmodAddReminder => 'Add reminder';

  @override
  String get cmodRemindersEmpty => 'Remind me after a prayer or at a set time';

  @override
  String get cmodReminderPaused => 'Paused';

  @override
  String get cmodReminderToggle => 'Reminder on';

  @override
  String get cmodModuleMenu => 'Module options';

  @override
  String cmodHiddenValue(String label) {
    return '$label (hidden)';
  }

  @override
  String get cmodNotifyGroup => 'Trackers & lists';

  @override
  String get cmodNotifyChannel => 'Tracker & list reminders';

  @override
  String get cmodNotifyChannelDescription =>
      'Gentle nudges to log your trackers and review your lists';

  @override
  String get cmodNotifyBodyTracker => 'Time to log it';

  @override
  String get cmodNotifyBodyList => 'Take a look at your list';

  @override
  String get cmodEntryNew => 'New entry';

  @override
  String get cmodEntryEdit => 'Edit entry';

  @override
  String get cmodItemNew => 'New item';

  @override
  String get cmodItemEdit => 'Edit item';

  @override
  String get cmodEntryWhen => 'When';

  @override
  String get cmodEntryDone => 'Done';

  @override
  String get cmodEntryCounter => 'This module is a counter: saving logs one.';

  @override
  String get cmodErrRequired => 'This field is required';

  @override
  String get cmodErrNumber => 'Enter a number';

  @override
  String get cmodErrWhole => 'Whole numbers only';

  @override
  String cmodErrPrecise(String count) {
    return 'At most $count decimal places';
  }

  @override
  String cmodErrMin(String value) {
    return 'At least $value';
  }

  @override
  String cmodErrMax(String value) {
    return 'At most $value';
  }

  @override
  String get cmodErrDate => 'Not a valid date';

  @override
  String get cmodErrTime => 'Not a valid time';

  @override
  String get cmodErrOption => 'Pick from the list';

  @override
  String get cmodErrScale => 'Outside the scale';

  @override
  String get cmodErrTooLong => 'The text is too long';

  @override
  String get cmodPickDate => 'Pick a date';

  @override
  String get cmodPickTime => 'Pick a time';

  @override
  String get cmodClear => 'Clear';

  @override
  String get cmodYes => 'Yes';

  @override
  String get cmodNo => 'No';

  @override
  String get cmodChecked => 'Done';

  @override
  String get cmodUnchecked => 'Not done';

  @override
  String get cmodCardTitle => 'Your trackers here';

  @override
  String get cmodCardSeeAll => 'See all';

  @override
  String get cmodCardEmpty => 'Create a tracker for this planet';

  @override
  String get cmodCardEmptyHint =>
      'A counter, a log or a list – with your own fields';

  @override
  String get cmodExportDate => 'date';

  @override
  String get cmodExportTime => 'time';

  @override
  String get cmodExportDone => 'done';

  @override
  String get cmodExportEntries => 'Entries';

  @override
  String get cmodExportLastEntry => 'Last entry';

  @override
  String get cmodExportOpen => 'Open';

  @override
  String cmodExportLastDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Last $count days',
      one: 'Last day',
    );
    return '$_temp0';
  }

  @override
  String cmodExportActiveDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active days',
      one: '1 active day',
    );
    return '$_temp0';
  }

  @override
  String cmodExportTotal(String value) {
    return 'total $value';
  }

  @override
  String cmodExportAverage(String value) {
    return 'average $value';
  }

  @override
  String cmodExportStreak(String current, String best) {
    return 'streak $current (best $best)';
  }

  @override
  String get cmodExportHidden => 'hidden';

  @override
  String get lifeHubToolsTitle => 'Tools';

  @override
  String get lifeHubPeople => 'People';

  @override
  String get lifeHubToolBoardsHint => 'Your kanban boards and their columns';

  @override
  String get lifeHubToolProjectsHint =>
      'Projects, their checklists and countdowns';

  @override
  String get lifeHubToolPeopleHint => 'Everyone you want to stay close to';

  @override
  String get lifeHubToolRemindersHint => 'The daily digest and birthdays';

  @override
  String get lifeHubToolTripsHint => 'Your trips and their countdowns';

  @override
  String get lifeHubToolDocumentsHint =>
      'Passports, visas and when they expire';

  @override
  String get lifeHubToolGoalsHint => 'Your learning goals and progress';

  @override
  String get lifeHubToolPlanHint => 'The week\'s training by weekday';

  @override
  String get lifeHubToolAvoidHint => 'What you chose to stay away from';

  @override
  String get lifeHubMoonOpenPerson => 'Open their page';

  @override
  String get lifeHubMoonOpenBoard => 'Open board';

  @override
  String get lifeHubMoonOpenTrip => 'Open trip';

  @override
  String get lifeHubMoonOpenModule => 'Open tracker';

  @override
  String get lifeHubSettingsSection => 'Life';

  @override
  String get lifeHubSettingsSectionHint =>
      'Family, body, travel and your trackers';

  @override
  String lifeHubSettingsFamilyOn(String time) {
    return 'Daily digest at $time';
  }

  @override
  String get lifeHubSettingsFamilyBirthdays => 'Birthdays only';

  @override
  String get lifeHubSettingsFamilyOff => 'Off';

  @override
  String lifeHubSettingsWaterValue(String ml) {
    return '$ml ml a day';
  }

  @override
  String get lifeHubSettingsFastingHint => 'Plan and notifications';

  @override
  String get lifeHubSettingsTemplatesHint => 'Ready lists for every trip';

  @override
  String lifeHubSettingsModulesCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n trackers',
      one: '$n tracker',
      zero: 'None yet',
    );
    return '$_temp0';
  }

  @override
  String get lifeHubPrayerDestination => 'your destination';

  @override
  String get cinemaTitle => 'Madar Cinema';

  @override
  String get cinemaHallSubtitle =>
      'Original games in the spirit of classic cinema';

  @override
  String get cinemaFeatures => 'Features';

  @override
  String get cinemaShorts => 'Shorts';

  @override
  String get cinemaComingSoon => 'Coming soon';

  @override
  String get cinemaPlay => 'Play';

  @override
  String get cinemaGameViewLabel => 'Game screen';

  @override
  String get cinemaPause => 'Pause';

  @override
  String get cinemaIntermission => 'Intermission';

  @override
  String get cinemaResume => 'Resume';

  @override
  String get cinemaRestart => 'Restart';

  @override
  String get cinemaLeave => 'Leave';

  @override
  String get cinemaPlayAgain => 'Play again';

  @override
  String get cinemaTheEnd => 'The End';

  @override
  String get cinemaGameOver => 'Show\'s Over';

  @override
  String cinemaScoreLine(String score) {
    return 'Score: $score';
  }

  @override
  String cinemaBestLine(String score) {
    return 'Best: $score';
  }

  @override
  String get cinemaEraSilent => 'Silent 1920s';

  @override
  String get cinemaEraRubberHose => '1930s Cartoon';

  @override
  String get cinemaEraNoir => '1940s Noir';

  @override
  String get cinemaEraTechnicolor => '1950s Technicolor';

  @override
  String get cinemaEraGrindhouse => '1970s Grindhouse';

  @override
  String get cinemaEraVhs => '1980s VHS';

  @override
  String get cinemaDemoTitle => 'Rehearsal';

  @override
  String get cinemaDemoTagline => 'A test scene for the Film Reel Engine';

  @override
  String get cinemaDemoOpening => 'Scene One';

  @override
  String get cinemaDemoOpeningSubtitle => 'Tap to jump over the barrels!';

  @override
  String get cinemaFlappyOrbitTitle => 'Flappy Orbit';

  @override
  String get cinemaFlappyOrbitTagline => 'Flap between planets to a swing beat';

  @override
  String get cinemaFlappyOrbitHomage => 'Homage to 1930s rubber-hose cartoons';

  @override
  String get cinemaMetropolisTitle => 'Metropolis Machine';

  @override
  String get cinemaMetropolisTagline => 'Take on the giant machines one by one';

  @override
  String get cinemaMetropolisHomage =>
      'Homage to the silent film Metropolis (1927)';

  @override
  String get cinemaCaravanTitle => 'Caravan Dash';

  @override
  String get cinemaCaravanTagline => 'Race the dunes in Technicolor';

  @override
  String get cinemaCaravanHomage => 'Homage to 1950s desert epics';

  @override
  String get cinemaNoirTitle => 'Noir Rooftops';

  @override
  String get cinemaNoirTagline => 'Chase shadows across rain-soaked rooftops';

  @override
  String get cinemaNoirHomage => 'Homage to 1940s film noir';

  @override
  String get cinemaNeonSoukTitle => 'Neon Souk Racer';

  @override
  String get cinemaNeonSoukTagline => 'Race through a souk of neon lights';

  @override
  String get cinemaNeonSoukHomage => 'Homage to 1980s sci-fi on VHS';

  @override
  String get cinemaSavedGames => 'Saved games';

  @override
  String get cinemaSavedGamesEmpty =>
      'Add a web game by its link to play it here full screen.';

  @override
  String get cinemaSavedGamesNote =>
      'Games open from their original link; nothing is copied into the app.';

  @override
  String get cinemaAddGame => 'Add game';

  @override
  String get cinemaGameName => 'Game name';

  @override
  String get cinemaGameUrl => 'Game link';

  @override
  String get cinemaInvalidUrl => 'Enter a valid link starting with https://';

  @override
  String get cinemaRemoveGame => 'Remove';

  @override
  String get cinemaOpenGameFailed => 'Couldn\'t open the link';

  @override
  String get cinemaSave => 'Save';

  @override
  String get cinemaCancel => 'Cancel';

  @override
  String get cinemaFxTestCard => 'Calibration card';

  @override
  String get cinemaFxFilmLook => 'Film look';

  @override
  String get cinemaFxQualityLowPower => 'Power saver';

  @override
  String get cinemaFxQualityBalanced => 'Balanced';

  @override
  String get cinemaFxQualityFull => 'Full quality';

  @override
  String get cinemaFxReelLabel => 'Reel';

  @override
  String get cinemaHallNowShowing => 'Now Showing';

  @override
  String get cinemaHallTonight => 'Tonight';

  @override
  String get cinemaHallWelcome => 'Welcome to the picture palace';

  @override
  String get cinemaHallProgramme => 'The full programme';

  @override
  String get cinemaHallAllEras => 'All eras';

  @override
  String get cinemaHallAllKinds => 'All kinds';

  @override
  String get cinemaHallReadyOnly => 'Ready to play';

  @override
  String get cinemaHallGenreCards => 'Card games';

  @override
  String get cinemaHallGenreBoard => 'Board games';

  @override
  String get cinemaHallGenreArcade => 'Arcade';

  @override
  String get cinemaHallGenrePuzzle => 'Puzzles';

  @override
  String get cinemaHallGenreWord => 'Word games';

  @override
  String get cinemaHallBackstage => 'Backstage';

  @override
  String get cinemaHallLockedSlot => 'Coming attraction';

  @override
  String get cinemaHallLockedHint =>
      'This one is still in the cutting room. Come back soon!';

  @override
  String get cinemaHallShortsSoon =>
      'Dozens of shorts on the way: cards, board games, arcade and words.';

  @override
  String get cinemaHallNothingMatches => 'No shows match. Try another era.';

  @override
  String get cinemaHallTicketBook => 'Ticket book';

  @override
  String get cinemaHallStatShows => 'Shows';

  @override
  String get cinemaHallStatWins => 'Happy endings';

  @override
  String get cinemaHallStatTime => 'Time watched';

  @override
  String get cinemaHallStatFavourite => 'Favourite show';

  @override
  String get cinemaHallFirstTicket =>
      'Your first ticket is waiting. Pick a show and step inside.';

  @override
  String cinemaHallBestBadge(String score) {
    return 'Best $score';
  }

  @override
  String cinemaHallPosterLabel(String title, String era) {
    return '$title poster, $era';
  }

  @override
  String get cinemaHallComingSoonTitle => 'This show hasn\'t opened yet';

  @override
  String get cinemaHallComingSoonBody =>
      'We\'re still filming this one. The curtain rises soon.';

  @override
  String get cinemaHallNotFound =>
      'We couldn\'t find this show in the programme.';

  @override
  String get cinemaHallBackToLobby => 'Back to the lobby';

  @override
  String get cinemaHallPrayerMuted => 'Sound paused for prayer';

  @override
  String get cinemaHallFooter =>
      'Every picture here is drawn in code and every note is composed as it plays.';

  @override
  String get cinemaStageBoothNote =>
      'The reel is resting. The show waits for you.';

  @override
  String get cinemaStageScore => 'Score';

  @override
  String get cinemaStageBest => 'Best';

  @override
  String get cinemaStageNewRecord => 'New record!';

  @override
  String get cinemaStageRunningTime => 'Running time';

  @override
  String get cinemaStageAdmitOne => 'Admit one';

  @override
  String get cinemaRigCast => 'The Cast';

  @override
  String get cinemaRigNujaym => 'Nujaym';

  @override
  String get cinemaRigNujaymRole => 'The plucky star-bird of Flappy Orbit';

  @override
  String get cinemaRigZunbruk => 'Baron Zunbruk';

  @override
  String get cinemaRigZunbrukRole =>
      'The clockwork foreman of Metropolis Machine';

  @override
  String get cinemaRigZajil => 'Zajil';

  @override
  String get cinemaRigZajilRole => 'The camel courier of Caravan Dash';

  @override
  String get cinemaRigMishmish => 'Inspector Mishmish';

  @override
  String get cinemaRigMishmishRole =>
      'The trench-coat detective cat of Noir Rooftops';

  @override
  String get cinemaRigSarab => 'Sarab';

  @override
  String get cinemaRigSarabRole => 'The hover-bike courier of Neon Souk Racer';

  @override
  String get cinemaRigBean => 'Habba';

  @override
  String get cinemaRigBeanRole =>
      'Star of the rehearsal, a bean in white gloves';

  @override
  String get cinemaDemoTapToJump => 'Tap to jump!';

  @override
  String get cinemaDemoActTwo => 'Act Two';

  @override
  String get cinemaDemoBossEnters => 'Baron Zunbruk takes the stage';

  @override
  String get dataCentreTitle => 'Your data';

  @override
  String get dataHeroTitle => 'Your data stays with you';

  @override
  String get dataHeroBody =>
      'Madar keeps everything encrypted on this phone and uploads nothing. A file leaves only when you share or save it yourself.';

  @override
  String get dataStatRecords => 'Records';

  @override
  String get dataStatLastBackup => 'Last backup';

  @override
  String get dataLastBackupNever => 'Not yet';

  @override
  String get dataLastBackupToday => 'Today';

  @override
  String dataLastBackupDaysAgo(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days ago',
      one: 'Yesterday',
    );
    return '$_temp0';
  }

  @override
  String get dataBackupSection => 'Backup';

  @override
  String get dataBackupSectionHint =>
      'One encrypted file to move or safeguard your data';

  @override
  String get dataBackupCreateTitle => 'Encrypted backup';

  @override
  String get dataBackupCreateBody =>
      'One file, locked with a passphrase only you know. Keep it somewhere safe to move your data to a new phone.';

  @override
  String get dataBackupCreateAction => 'Create backup';

  @override
  String get dataRestoreTitle => 'Restore from a backup';

  @override
  String get dataRestoreBody =>
      'Replaces everything in Madar with a backup file. A safety copy of your current data is kept on this phone first.';

  @override
  String get dataRestoreAction => 'Choose a backup file';

  @override
  String dataSafetyCopiesLine(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count safety copies on this phone',
      one: '1 safety copy on this phone',
    );
    return '$_temp0 · latest $date';
  }

  @override
  String get dataExportSection => 'Export';

  @override
  String get dataExportSectionHint =>
      'Readable copies of your data – not encrypted';

  @override
  String get dataExportSummaryTitle => 'AI-ready summary';

  @override
  String get dataExportSummaryBody =>
      'A short Markdown overview you review section by section before sharing.';

  @override
  String get dataExportCsvTitle => 'Spreadsheets (CSV)';

  @override
  String get dataExportCsvBody =>
      'Labs, transactions, pain and mood – for Excel or Sheets.';

  @override
  String get dataExportJsonTitle => 'Everything (JSON)';

  @override
  String get dataExportJsonBody =>
      'Every record in one file, for your own archive or other apps.';

  @override
  String get dataExportPlainWarning =>
      'Exported files are not encrypted: anyone who gets them can read them. Share them only with people you trust.';

  @override
  String get dataImportSection => 'Import';

  @override
  String get dataImportTitle => 'Import from the Madar prototype';

  @override
  String get dataImportBody =>
      'Bring in data exported from the earlier version (a JSON file).';

  @override
  String get dataFooter =>
      'Madar never uploads your data to any server. You alone decide where your files go.';

  @override
  String get dataAreaOther => 'Settings & history';

  @override
  String get dataShareAction => 'Share';

  @override
  String get dataSaveAction => 'Save to…';

  @override
  String get dataCopyAction => 'Copy';

  @override
  String get dataDoneAction => 'Done';

  @override
  String get dataCancelAction => 'Cancel';

  @override
  String get dataTryAgainAction => 'Try again';

  @override
  String get dataFileReadyTitle => 'Your file is ready';

  @override
  String get dataFileReadySubtitle =>
      'Choose where it goes – nothing is sent automatically';

  @override
  String get dataFileEncryptedNote =>
      'Encrypted with your passphrase and opens only with it – keep the two apart.';

  @override
  String get dataFilePlainNote =>
      'Not encrypted: anyone who gets this file can read it.';

  @override
  String get dataFileShared => 'Handed to the share sheet.';

  @override
  String get dataFileSaved => 'Saved where you chose.';

  @override
  String get dataFileSendFailed =>
      'That didn’t work. Nothing was sent – please try again.';

  @override
  String get dataExportFailed =>
      'Couldn’t prepare the file. Your data is unchanged.';

  @override
  String dataRecordsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count records',
      one: '1 record',
      zero: 'no records',
    );
    return '$_temp0';
  }

  @override
  String dataSizeBytes(String size) {
    return '$size bytes';
  }

  @override
  String dataSizeKb(String size) {
    return '$size KB';
  }

  @override
  String dataSizeMb(String size) {
    return '$size MB';
  }

  @override
  String get dataBackupSheetTitle => 'Encrypted backup';

  @override
  String get dataBackupSheetSubtitle =>
      'AES-GCM encryption · keys derived with Argon2id on your phone';

  @override
  String get dataBackupSheetBody =>
      'Choose a passphrase to lock the backup file. Madar never stores it and can’t recover it, so write it down somewhere you trust.';

  @override
  String get dataPassphraseLabel => 'Passphrase';

  @override
  String get dataPassphraseConfirmLabel => 'Type the passphrase again';

  @override
  String get dataPassphraseMismatch => 'The two don’t match.';

  @override
  String get dataPassphraseShow => 'Show passphrase';

  @override
  String get dataPassphraseHide => 'Hide passphrase';

  @override
  String get dataPassphraseNeverStored =>
      'The passphrase is never stored anywhere. Without it the backup can’t be opened – not even by us.';

  @override
  String get dataStrengthLabel => 'Strength';

  @override
  String get dataStrengthEmpty => '—';

  @override
  String get dataStrengthVeryWeak => 'Very weak';

  @override
  String get dataStrengthWeak => 'Weak';

  @override
  String get dataStrengthFair => 'Fair';

  @override
  String get dataStrengthStrong => 'Strong';

  @override
  String get dataStrengthVeryStrong => 'Very strong';

  @override
  String dataStrengthHintShort(String min) {
    return 'Use at least $min characters – a short sentence works well.';
  }

  @override
  String get dataStrengthHintCommon =>
      'This is a common password that’s easy to guess.';

  @override
  String get dataStrengthHintPattern =>
      'Avoid repeats and runs like abcd or aaaa.';

  @override
  String get dataStrengthHintDigits =>
      'Digits alone are easy to guess; add some words.';

  @override
  String get dataStrengthHintWords =>
      'Good. One or two more words make it much stronger.';

  @override
  String get dataBackupWorking => 'Locking your data…';

  @override
  String get dataBackupWorkingHint =>
      'This takes a few seconds on purpose – it makes the passphrase hard to guess.';

  @override
  String get dataBackupReadyTitle => 'Backup ready';

  @override
  String get dataBackupReadySubtitle => 'Share it or save it somewhere safe';

  @override
  String get dataBackupReadyHint =>
      'Keep the file and the passphrase in different places. You’ll need both to restore.';

  @override
  String get dataBackupShareSubject => 'Madar backup';

  @override
  String get dataBackupFailed =>
      'Couldn’t create the backup. Your data is untouched – please try again.';

  @override
  String dataBackupMadeOn(String date) {
    return 'Made on $date';
  }

  @override
  String get dataCsvSheetTitle => 'Spreadsheet export';

  @override
  String get dataCsvSheetSubtitle => 'CSV · UTF-8 · opens in Excel and Sheets';

  @override
  String get dataCsvWhat => 'What';

  @override
  String get dataCsvWhen => 'When';

  @override
  String get dataCsvLabs => 'Labs';

  @override
  String get dataCsvTransactions => 'Transactions';

  @override
  String get dataCsvPain => 'Pain';

  @override
  String get dataCsvMood => 'Mood';

  @override
  String dataRangeDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '$days day',
    );
    return '$_temp0';
  }

  @override
  String dataRangeMonths(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months months',
      one: '$months month',
    );
    return '$_temp0';
  }

  @override
  String get dataRangeAll => 'All time';

  @override
  String get dataRangeCustom => 'Custom…';

  @override
  String get dataRangeAllTime => 'Every record since the start';

  @override
  String dataRangeFromTo(String from, String to) {
    return 'From $from to $to';
  }

  @override
  String dataCsvFormatNote(String example) {
    return 'Dates look like $example and numbers use a decimal point, so any spreadsheet opens them as they are.';
  }

  @override
  String get dataCsvCreate => 'Create file';

  @override
  String dataCsvCreateRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Create file ($count rows)',
      one: 'Create file (1 row)',
      zero: 'No rows in this range',
    );
    return '$_temp0';
  }

  @override
  String get dataCsvDate => 'date';

  @override
  String get dataCsvTime => 'time';

  @override
  String get dataCsvTest => 'test';

  @override
  String get dataCsvCategory => 'category';

  @override
  String get dataCsvValue => 'value';

  @override
  String get dataCsvTextResult => 'text_result';

  @override
  String get dataCsvUnit => 'unit';

  @override
  String get dataCsvRangeLow => 'range_low';

  @override
  String get dataCsvRangeHigh => 'range_high';

  @override
  String get dataCsvFlag => 'flag';

  @override
  String get dataCsvNote => 'note';

  @override
  String get dataCsvNotes => 'notes';

  @override
  String get dataCsvKind => 'kind';

  @override
  String get dataCsvWallet => 'wallet';

  @override
  String get dataCsvCurrency => 'currency';

  @override
  String get dataCsvAmount => 'amount';

  @override
  String get dataCsvAmountBase => 'amount_base';

  @override
  String get dataCsvBaseCurrency => 'base_currency';

  @override
  String get dataCsvBudgetItem => 'budget_item';

  @override
  String get dataCsvToWallet => 'to_wallet';

  @override
  String get dataCsvToAmount => 'to_amount';

  @override
  String get dataCsvToCurrency => 'to_currency';

  @override
  String get dataCsvTags => 'tags';

  @override
  String dataCsvPainScore(String min, String max) {
    return 'score_${min}_$max';
  }

  @override
  String get dataCsvLocations => 'locations';

  @override
  String get dataCsvTriggers => 'triggers';

  @override
  String get dataCsvBodyPoints => 'body_points';

  @override
  String dataCsvMoodScore(String min, String max) {
    return 'mood_${min}_$max';
  }

  @override
  String dataCsvStress(String min, String max) {
    return 'stress_${min}_$max';
  }

  @override
  String dataCsvAnxiety(String min, String max) {
    return 'anxiety_${min}_$max';
  }

  @override
  String dataCsvEnergy(String min, String max) {
    return 'energy_${min}_$max';
  }

  @override
  String get dataCsvSleepHours => 'sleep_hours';

  @override
  String get dataCsvCaffeine => 'caffeine_cups';

  @override
  String get dataCsvFactors => 'factors';

  @override
  String get dataFlagLow => 'low';

  @override
  String get dataFlagBorderlineLow => 'borderline low';

  @override
  String get dataFlagInRange => 'in range';

  @override
  String get dataFlagBorderlineHigh => 'borderline high';

  @override
  String get dataFlagHigh => 'high';

  @override
  String get dataTxExpense => 'expense';

  @override
  String get dataTxIncome => 'income';

  @override
  String get dataTxTransfer => 'transfer';

  @override
  String get dataTxAdjustment => 'adjustment';

  @override
  String get dataSummarySubtitle =>
      'Made on your phone · review each section before sharing';

  @override
  String get dataSummaryIntro =>
      'Nothing goes anywhere until you choose. The preview below is exactly what would leave – notes, phone numbers and document or account numbers are never included.';

  @override
  String get dataSummaryPreparing => 'Preparing the summary on your phone…';

  @override
  String get dataSummarySections => 'Sections to include';

  @override
  String dataSummarySectionsOf(String selected, String total) {
    return '$selected of $total sections';
  }

  @override
  String dataSummaryTokens(String count) {
    return '≈ $count tokens';
  }

  @override
  String get dataSummaryNoData => 'No data yet';

  @override
  String get dataSummaryProfileHint => 'Optional';

  @override
  String get dataSummaryPreviewTitle => 'Exactly what will be shared';

  @override
  String get dataSummaryCopied => 'Summary copied to the clipboard.';

  @override
  String get dataSummaryUse => 'Use this summary';

  @override
  String get dataProfileChoose => 'Choose what to mention about you:';

  @override
  String get dataProfileAboutHint =>
      'e.g. your age, or anything the assistant should know';

  @override
  String get dataRestoreFlowTitle => 'Restore';

  @override
  String get dataRestoreChooseTitle => 'Bring your data back';

  @override
  String dataRestoreChooseBody(String ext) {
    return 'Pick a $ext file. You’ll see what’s inside before anything changes.';
  }

  @override
  String get dataRestorePickFile => 'Choose backup file';

  @override
  String get dataRestoreNothingChanges =>
      'Nothing in your current data changes until you confirm the replacement in the last step.';

  @override
  String get dataSafetyCopiesTitle => 'Safety copies on this phone';

  @override
  String get dataSafetyCopiesHint =>
      'Made automatically before each restore; each opens with the passphrase used for that restore.';

  @override
  String get dataRestoreUnlockBody =>
      'Enter the passphrase this backup was locked with.';

  @override
  String get dataRestoreUnlockAction => 'Unlock backup';

  @override
  String get dataRestoreOtherFile => 'Choose another file';

  @override
  String get dataRestoreOpening => 'Checking the backup…';

  @override
  String get dataRestoreOpeningHint =>
      'Making sure the file is intact and unchanged, then decrypting it on your phone.';

  @override
  String get dataRestorePreviewTitle => 'The backup is intact';

  @override
  String get dataRestoreInBackup => 'In the backup';

  @override
  String get dataRestoreOnPhone => 'On this phone now';

  @override
  String get dataRestoreWhatsInside => 'What’s inside';

  @override
  String get dataRestoreReplaceWarning =>
      'This backup will replace all data in Madar now. First, your current data is saved as a safety copy on this phone, opening with the same passphrase.';

  @override
  String get dataRestoreUnderstand =>
      'I understand my current data will be replaced';

  @override
  String get dataRestoreConfirmAction => 'Replace my data';

  @override
  String get dataRestoreSavingSafety =>
      'Saving a safety copy of your current data…';

  @override
  String get dataRestoreRestoring => 'Restoring your data…';

  @override
  String get dataRestoreKeepOpen => 'Keep the app open for a moment.';

  @override
  String get dataRestoreDoneTitle => 'Restored';

  @override
  String dataRestoreDoneBody(String count) {
    return 'Your records ($count) are back in Madar.';
  }

  @override
  String get dataRestoreSafetyKept =>
      'A safety copy of your previous data is kept on this phone and opens with the same passphrase.';

  @override
  String get dataSafetyCopySave => 'Save the safety copy elsewhere';

  @override
  String get dataSafetyCopyTitle => 'Safety copy';

  @override
  String get dataNothingChanged => 'Nothing in your data was changed.';

  @override
  String get dataErrWrongPassphrase =>
      'That passphrase doesn’t open this backup. Check for typos and try again.';

  @override
  String get dataErrNotBackupTitle => 'This isn’t a Madar backup';

  @override
  String dataErrNotBackupBody(String ext) {
    return 'Choose a file ending in $ext, made with “Create backup”.';
  }

  @override
  String get dataErrNewerTitle => 'Made by a newer Madar';

  @override
  String get dataErrNewerBody => 'Update Madar on this phone, then try again.';

  @override
  String get dataErrTruncatedTitle => 'The file is incomplete';

  @override
  String get dataErrTruncatedBody =>
      'It may not have finished copying or downloading. Copy it again and retry.';

  @override
  String get dataErrCorruptedTitle => 'The file is damaged';

  @override
  String get dataErrCorruptedBody =>
      'It changed or was damaged after it was made, so it can’t be trusted.';

  @override
  String get dataErrUnreadableTitle => 'Couldn’t read the file';

  @override
  String get dataErrUnreadableBody =>
      'Try another file, or copy it to the phone first.';

  @override
  String get dataErrSafetyTitle => 'Couldn’t save a safety copy';

  @override
  String get dataErrSafetyBody =>
      'So your data was not replaced. Free some space and try again.';

  @override
  String get dataErrRejectedTitle => 'This backup couldn’t be restored';

  @override
  String get dataErrRejectedBody => 'Its data didn’t pass the safety checks.';

  @override
  String dataSumHeading(String date) {
    return 'Madar summary — $date';
  }

  @override
  String get dataSumPreamble =>
      'Personal tracking data from the Madar app, prepared on the user’s own phone. Dates are yyyy-mm-dd; decimals use a point. Notes, phone numbers and document or account numbers are never included.';

  @override
  String get dataSumNoData => 'No data yet.';

  @override
  String get dataSumListSep => ', ';

  @override
  String dataSumLastDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Last $days days',
      one: 'Today',
    );
    return '$_temp0';
  }

  @override
  String dataSumPreviousDays(String days) {
    return 'The $days days before';
  }

  @override
  String dataSumMore(String count) {
    return 'not shown: $count';
  }

  @override
  String get dataSumProfile => 'Profile';

  @override
  String get dataSumFaith => 'Faith';

  @override
  String get dataSumHealth => 'Health';

  @override
  String get dataSumMoney => 'Money';

  @override
  String get dataSumFamily => 'Family';

  @override
  String get dataSumWork => 'Work';

  @override
  String get dataSumGrowth => 'Growth';

  @override
  String get dataSumBody => 'Body';

  @override
  String get dataSumTravel => 'Travel';

  @override
  String get dataSumCustom => 'Custom trackers';

  @override
  String get dataSumCity => 'City';

  @override
  String get dataSumTimeZone => 'Time zone';

  @override
  String get dataSumBaseCurrency => 'Base currency';

  @override
  String get dataSumLanguage => 'App language';

  @override
  String get dataSumLanguageName => 'English';

  @override
  String get dataSumAboutMe => 'About me';

  @override
  String get dataSumPrayersTitle => 'Prayers';

  @override
  String dataSumObligatory(String window) {
    return '$window (obligatory)';
  }

  @override
  String dataSumLogged(String logged, String expected) {
    return 'logged: $logged/$expected';
  }

  @override
  String dataSumOnTime(String count) {
    return 'on time: $count';
  }

  @override
  String dataSumLate(String count) {
    return 'late: $count';
  }

  @override
  String dataSumMadeUp(String count) {
    return 'made up: $count';
  }

  @override
  String dataSumMissed(String count) {
    return 'missed: $count';
  }

  @override
  String dataSumInCongregation(String count) {
    return 'in congregation: $count';
  }

  @override
  String dataSumVoluntary(String window) {
    return '$window (voluntary)';
  }

  @override
  String get dataSumQuranTitle => 'Quran and wird';

  @override
  String dataSumSessions(String count) {
    return 'sessions: $count';
  }

  @override
  String dataSumPages(String count) {
    return 'pages: $count';
  }

  @override
  String dataSumMinutes(String count) {
    return '$count min';
  }

  @override
  String dataSumLastSession(String date) {
    return 'Last session: $date';
  }

  @override
  String dataSumWird(String name) {
    return 'Wird “$name”';
  }

  @override
  String dataSumPerDay(String amount, String unit) {
    return '$amount $unit a day';
  }

  @override
  String get dataSumUnitPages => 'pages';

  @override
  String get dataSumUnitJuz => 'juz';

  @override
  String get dataSumUnitHizb => 'hizb';

  @override
  String get dataSumUnitAyat => 'ayat';

  @override
  String dataSumSince(String date) {
    return 'since $date';
  }

  @override
  String dataSumBy(String date) {
    return 'by $date';
  }

  @override
  String get dataSumHifzTitle => 'Hifz';

  @override
  String dataSumItems(String count) {
    return 'items: $count';
  }

  @override
  String dataSumNew(String count) {
    return 'new: $count';
  }

  @override
  String dataSumDueToday(String count) {
    return 'due today: $count';
  }

  @override
  String dataSumReviews(String count) {
    return 'reviews: $count';
  }

  @override
  String dataSumAvgGrade(String value, String max) {
    return 'average grade: $value/$max';
  }

  @override
  String get dataSumAlertsTitle => 'Standing alerts';

  @override
  String get dataSumSeverityCritical => 'critical';

  @override
  String get dataSumSeverityWarning => 'warning';

  @override
  String get dataSumSeverityInfo => 'note';

  @override
  String get dataSumConditionsTitle => 'Conditions';

  @override
  String get dataSumMedsTitle => 'Active medications';

  @override
  String get dataSumKindSupplement => 'supplement';

  @override
  String get dataSumKindInjection => 'injection';

  @override
  String get dataSumWithEmptyStomach => 'on an empty stomach';

  @override
  String get dataSumWithBreakfast => 'with breakfast';

  @override
  String get dataSumWithLunch => 'with lunch';

  @override
  String get dataSumWithDinner => 'with dinner';

  @override
  String get dataSumWithBedtime => 'at bedtime';

  @override
  String get dataSumWithCourse => 'per course plan';

  @override
  String get dataSumLabsTitle => 'Recent labs';

  @override
  String dataSumLabsWindow(String months) {
    return 'Latest result per test in the last $months months; flags compare with the range saved in the app.';
  }

  @override
  String get dataSumColTest => 'Test';

  @override
  String get dataSumColDate => 'Date';

  @override
  String get dataSumColResult => 'Result';

  @override
  String get dataSumColRange => 'Range';

  @override
  String get dataSumColFlag => 'Flag';

  @override
  String get dataSumColPrevious => 'Previous';

  @override
  String get dataSumPainTitle => 'Pain (tracking)';

  @override
  String dataSumEntries(String count) {
    return 'entries: $count';
  }

  @override
  String dataSumAverageOf(String value, String max) {
    return 'average: $value/$max';
  }

  @override
  String dataSumHighest(String value, String max) {
    return 'highest: $value/$max';
  }

  @override
  String get dataSumTopPlaces => 'Most logged places';

  @override
  String get dataSumTopTriggers => 'Most logged triggers';

  @override
  String get dataSumMoodTitle => 'Mood (tracking)';

  @override
  String dataSumMoodAvg(String value, String max) {
    return 'mood: $value/$max';
  }

  @override
  String dataSumStressAvg(String value, String max) {
    return 'stress: $value/$max';
  }

  @override
  String dataSumAnxietyAvg(String value, String max) {
    return 'anxiety: $value/$max';
  }

  @override
  String dataSumEnergyAvg(String value, String max) {
    return 'energy: $value/$max';
  }

  @override
  String dataSumSleepAvg(String value) {
    return 'sleep: $value h';
  }

  @override
  String dataSumCaffeineAvg(String value) {
    return 'caffeine: $value cups';
  }

  @override
  String get dataSumTopFactors => 'Common factors';

  @override
  String get dataSumWalletsTitle => 'Wallets';

  @override
  String dataSumConvertedTo(String code) {
    return 'Converted to $code with the exchange rates saved in the app.';
  }

  @override
  String get dataSumColWallet => 'Wallet';

  @override
  String get dataSumColBalance => 'Balance';

  @override
  String dataSumColInBase(String code) {
    return 'In $code';
  }

  @override
  String dataSumTotal(String amount) {
    return 'Total: $amount';
  }

  @override
  String dataSumBudgetTitle(String month) {
    return 'Budget — $month';
  }

  @override
  String dataSumPlanned(String amount) {
    return 'planned: $amount';
  }

  @override
  String dataSumSpent(String amount) {
    return 'spent: $amount';
  }

  @override
  String dataSumRemaining(String amount) {
    return 'remaining: $amount';
  }

  @override
  String get dataSumOverPlan => 'Over plan';

  @override
  String dataSumUnassigned(String amount) {
    return 'Spent without a budget item: $amount';
  }

  @override
  String dataSumDueTitle(String days) {
    return 'Due in the next $days days';
  }

  @override
  String dataSumDueOn(String date) {
    return 'due $date';
  }

  @override
  String dataSumOverdueSince(String date) {
    return 'overdue since $date';
  }

  @override
  String get dataSumDebtsTitle => 'Debts';

  @override
  String dataSumIOwe(String person, String left, String total) {
    return 'I owe $person: $left left of $total';
  }

  @override
  String dataSumOwedToMe(String person, String left, String total) {
    return '$person owes me: $left left of $total';
  }

  @override
  String get dataSumJarsTitle => 'Savings jars';

  @override
  String dataSumJar(String name, String saved, String target, String percent) {
    return '$name: $saved of $target ($percent%)';
  }

  @override
  String dataSumEvery(String days) {
    return 'rhythm: every $days days';
  }

  @override
  String dataSumLastContact(String days) {
    return 'days since last contact: $days';
  }

  @override
  String get dataSumNeverContacted => 'no contact logged yet';

  @override
  String dataSumOverdueBy(String days) {
    return 'overdue by (days): $days';
  }

  @override
  String get dataSumDueTodayStatus => 'due today';

  @override
  String dataSumDueIn(String days) {
    return 'due in (days): $days';
  }

  @override
  String dataSumNoRhythm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more people without a contact rhythm',
      one: '1 more person without a contact rhythm',
    );
    return '$_temp0';
  }

  @override
  String dataSumPeopleNoRhythm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people, no contact rhythm set',
      one: '1 person, no contact rhythm set',
    );
    return '$_temp0';
  }

  @override
  String dataSumTop3Title(String count) {
    return 'Top $count';
  }

  @override
  String dataSumOnBoard(String board) {
    return 'board: $board';
  }

  @override
  String get dataSumBoardsTitle => 'Boards';

  @override
  String get dataSumOther => 'Other';

  @override
  String get dataSumProjectsTitle => 'Projects';

  @override
  String get dataSumStatusActive => 'active';

  @override
  String get dataSumStatusPaused => 'paused';

  @override
  String dataSumDoneOf(String done, String total) {
    return 'items done: $done/$total';
  }

  @override
  String dataSumDeadline(String date) {
    return 'deadline: $date';
  }

  @override
  String dataSumProgress(String current, String target, String unit) {
    return '$current of $target $unit';
  }

  @override
  String dataSumRecentGain(String amount, String window) {
    return '$window: $amount';
  }

  @override
  String get dataSumExercisePlanTitle => 'Exercise plan';

  @override
  String get dataSumWeekdays => 'Mon,Tue,Wed,Thu,Fri,Sat,Sun';

  @override
  String dataSumSets(String count) {
    return 'sets: $count';
  }

  @override
  String dataSumKg(String value) {
    return '$value kg';
  }

  @override
  String dataSumWorkouts(String count) {
    return 'workouts: $count';
  }

  @override
  String dataSumFasting(String count, String hours) {
    return 'fasts: $count · average: $hours h';
  }

  @override
  String dataSumTargetHours(String hours) {
    return 'target: $hours h';
  }

  @override
  String dataSumWater(String days, String ml) {
    return 'Water, last $days days: $ml ml a day on average';
  }

  @override
  String dataSumTargetMl(String ml) {
    return 'target: $ml ml';
  }

  @override
  String get dataSumAvoidTitle => 'Avoid';

  @override
  String get dataSumTripsTitle => 'Upcoming trips';

  @override
  String get dataSumTripPlanned => 'planned';

  @override
  String get dataSumTripUnderWay => 'under way';

  @override
  String get dataSumDocumentsTitle => 'Documents (numbers are never included)';

  @override
  String dataSumExpiresIn(String date, String days) {
    return 'expires $date (days left: $days)';
  }

  @override
  String dataSumExpired(String date) {
    return 'expired $date';
  }

  @override
  String get dataSumNoExpiry => 'no expiry date';

  @override
  String get dataSumModuleTracker => 'tracker';

  @override
  String get dataSumModuleList => 'list';

  @override
  String dataSumOpen(String count) {
    return 'open: $count';
  }

  @override
  String dataSumDone(String count) {
    return 'done: $count';
  }

  @override
  String dataSumInWindow(String count, String window) {
    return '$window: $count';
  }

  @override
  String dataSumLastOn(String date) {
    return 'last: $date';
  }

  @override
  String dataSumAverage(String value) {
    return 'average: $value';
  }

  @override
  String dataSumMin(String value) {
    return 'min: $value';
  }

  @override
  String dataSumMax(String value) {
    return 'max: $value';
  }

  @override
  String dataSumSum(String value) {
    return 'total: $value';
  }

  @override
  String dataSumTicked(String count, String total) {
    return 'ticked: $count/$total';
  }

  @override
  String get searchTitle => 'Search';

  @override
  String get searchFieldHint => 'Search tasks, notes, people, ayat…';

  @override
  String get searchLauncherHint => 'Search Madar';

  @override
  String get searchLauncherTooltip => 'Search everything';

  @override
  String get searchClear => 'Clear text';

  @override
  String get searchRecentTitle => 'Recent searches';

  @override
  String get searchRecentClear => 'Clear history';

  @override
  String searchRecentRemove(String query) {
    return 'Remove “$query” from history';
  }

  @override
  String get searchIntroTitle => 'Search your whole orbit';

  @override
  String get searchIntroBody =>
      'Tasks, notes, people, money and ayat in one place. Search runs on your phone only.';

  @override
  String get searchPreparing => 'Preparing the search index…';

  @override
  String searchNoResultsTitle(String query) {
    return 'No results for “$query”';
  }

  @override
  String get searchNoResultsBody => 'Try fewer words or another spelling.';

  @override
  String get searchNoResultsFiltered => 'Nothing here with the current filter.';

  @override
  String get searchClearFilters => 'Clear filter';

  @override
  String get searchAll => 'All';

  @override
  String searchResultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '1 result',
      zero: 'No results',
    );
    return '$_temp0';
  }

  @override
  String searchShowAll(String count) {
    return 'Show all ($count)';
  }

  @override
  String searchGroupSemantics(String module, String count) {
    return '$module, $count';
  }

  @override
  String get searchPartial =>
      'Not every word was found together; these are the closest matches.';

  @override
  String get searchCannotOpen => 'This result can’t be opened from here yet.';

  @override
  String get searchToday => 'Today';

  @override
  String get searchYesterday => 'Yesterday';

  @override
  String get searchTomorrow => 'Tomorrow';

  @override
  String get searchFilterPlanets => 'Filter by planet';

  @override
  String get searchFilterModules => 'Filter by section';

  @override
  String get searchPlanetCustom => 'Custom modules';

  @override
  String get searchKeyboardHint => '↑ ↓ to move, Enter to open, Esc to clear';

  @override
  String get searchDone => 'Done';

  @override
  String get searchArchived => 'Archived';

  @override
  String get searchTxExpense => 'Expense';

  @override
  String get searchTxIncome => 'Income';

  @override
  String get searchTxTransfer => 'Transfer';

  @override
  String get searchTxAdjustment => 'Adjustment';

  @override
  String get searchDebtIOwe => 'I owe';

  @override
  String get searchDebtOwedToMe => 'Owed to me';

  @override
  String get searchChannelCall => 'Call';

  @override
  String get searchChannelVisit => 'Visit';

  @override
  String get searchChannelMessage => 'Message';

  @override
  String get searchChannelOther => 'Contact';

  @override
  String searchPainTitle(String score, String max) {
    return 'Pain $score/$max';
  }

  @override
  String get searchMoodTitle => 'Mood';

  @override
  String get searchFastingTitle => 'Fast';

  @override
  String searchAyahPlace(String surah, String ayah) {
    return '$surah · ayah $ayah';
  }

  @override
  String searchAyahRange(String surah, String from, String to) {
    return '$surah · $from–$to';
  }

  @override
  String searchSurahNumber(String number) {
    return 'Surah $number';
  }

  @override
  String get searchSourceTasks => 'Tasks';

  @override
  String get searchSourcePrayerLogs => 'Prayer log';

  @override
  String get searchSourceMedications => 'Medications';

  @override
  String get searchSourceMedCourses => 'Treatment courses';

  @override
  String get searchSourceMedDoses => 'Dose notes';

  @override
  String get searchSourceConditions => 'Conditions';

  @override
  String get searchSourceHealthAlerts => 'Health alerts';

  @override
  String get searchSourceLabTests => 'Lab tests';

  @override
  String get searchSourceLabReadings => 'Lab results';

  @override
  String get searchSourceAppointments => 'Appointments';

  @override
  String get searchSourceDoctorQuestions => 'Doctor questions';

  @override
  String get searchSourcePain => 'Pain log';

  @override
  String get searchSourceMood => 'Mood log';

  @override
  String get searchSourceHabits => 'Habits';

  @override
  String get searchSourceWorries => 'Worries';

  @override
  String get searchSourceWallets => 'Wallets';

  @override
  String get searchSourceTransactions => 'Transactions';

  @override
  String get searchSourceBudget => 'Budget';

  @override
  String get searchSourceJars => 'Savings jars';

  @override
  String get searchSourceJarDeposits => 'Jar deposits';

  @override
  String get searchSourceDebts => 'Debts';

  @override
  String get searchSourceDebtPayments => 'Debt payments';

  @override
  String get searchSourceObligations => 'Obligations';

  @override
  String get searchSourcePeople => 'People';

  @override
  String get searchSourceContactLogs => 'Contact log';

  @override
  String get searchSourceProjects => 'Projects';

  @override
  String get searchSourceProjectItems => 'Project items';

  @override
  String get searchSourceBoards => 'Boards';

  @override
  String get searchSourceCards => 'Cards';

  @override
  String get searchSourceTrips => 'Trips';

  @override
  String get searchSourceTripItems => 'Trip items';

  @override
  String get searchSourcePackingTemplates => 'Packing lists';

  @override
  String get searchSourceTravelDocuments => 'Travel documents';

  @override
  String get searchSourceLearningGoals => 'Learning goals';

  @override
  String get searchSourceGoalLogs => 'Goal log';

  @override
  String get searchSourceExercises => 'Exercises';

  @override
  String get searchSourceWorkouts => 'Workout log';

  @override
  String get searchSourceAvoidItems => 'Avoid list';

  @override
  String get searchSourceFasting => 'Fasting';

  @override
  String get searchSourceCustomModules => 'Custom modules';

  @override
  String get searchSourceCustomEntries => 'Module entries';

  @override
  String get searchSourceQuranAyat => 'Quran ayat';

  @override
  String get searchSourceQuranBookmarks => 'Quran bookmarks';

  @override
  String get searchSourceWirdPlans => 'Wird plans';

  @override
  String get searchSourceHifz => 'Hifz';

  @override
  String get searchSourcePlanets => 'Planets';

  @override
  String get ncTitle => 'Notifications';

  @override
  String get ncTabUpcoming => 'Upcoming';

  @override
  String get ncTabRecent => 'Recent';

  @override
  String ncTabWithCount(String label, String count) {
    return '$label, $count';
  }

  @override
  String get ncOpenSettings => 'Notification settings';

  @override
  String get ncUpcomingEmptyTitle => 'Nothing scheduled';

  @override
  String get ncUpcomingEmptyBody =>
      'The adhan and reminders you switch on line up here for the next seven days.';

  @override
  String get ncRecentEmptyTitle => 'All caught up';

  @override
  String get ncRecentEmptyBody =>
      'Notifications that arrive stay here for two weeks, so you can come back to them.';

  @override
  String get ncClearAll => 'Clear all';

  @override
  String ncClearedAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cleared $count notifications',
      one: 'Cleared 1 notification',
    );
    return '$_temp0';
  }

  @override
  String get ncDismissed => 'Dismissed';

  @override
  String get ncSkippedToast => 'This one won\'t arrive';

  @override
  String get ncRestoredToast => 'It will arrive on time';

  @override
  String ncShowMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Show $count more',
      one: 'Show 1 more',
    );
    return '$_temp0';
  }

  @override
  String get ncShowLess => 'Show less';

  @override
  String ncSectionLabel(String group, String count) {
    return '$group, $count';
  }

  @override
  String get ncGroupPrayer => 'Prayer & adhan';

  @override
  String get ncGroupAdhkar => 'Adhkar';

  @override
  String get ncGroupMedications => 'Medications';

  @override
  String get ncGroupHealth => 'Health';

  @override
  String get ncGroupMoney => 'Money dues';

  @override
  String get ncGroupFamily => 'Family';

  @override
  String get ncGroupTravel => 'Travel documents';

  @override
  String get ncGroupWird => 'Wird';

  @override
  String get ncGroupCustom => 'Custom modules';

  @override
  String get ncGroupOther => 'Other';

  @override
  String ncKindAdhan(String prayer) {
    return '$prayer adhan';
  }

  @override
  String ncKindPreAdhan(String prayer, String minutes) {
    return '$prayer in $minutes';
  }

  @override
  String ncKindPreAdhanShort(String prayer) {
    return 'Before $prayer';
  }

  @override
  String get ncKindSunrise => 'Sunrise';

  @override
  String get ncKindAdhanTest => 'Test adhan';

  @override
  String get ncKindAdhkarMorning => 'Morning adhkar';

  @override
  String get ncKindAdhkarEvening => 'Evening adhkar';

  @override
  String get ncKindAdhkar => 'Adhkar reminder';

  @override
  String get ncKindDose => 'Dose reminder';

  @override
  String get ncKindRefill => 'Time to refill';

  @override
  String get ncKindMedsNotice => 'Answer not recorded';

  @override
  String get ncKindAppointment => 'Appointment';

  @override
  String get ncKindWorry => 'Worry window';

  @override
  String get ncKindFastGoal => 'Fasting goal';

  @override
  String get ncKindEatingClose => 'Eating window closing';

  @override
  String get ncKindDebt => 'Debt due';

  @override
  String get ncKindObligation => 'Payment due';

  @override
  String get ncKindFamilyDigest => 'Keep in touch';

  @override
  String get ncKindBirthdayEve => 'Birthday tomorrow';

  @override
  String get ncKindBirthday => 'Birthday today';

  @override
  String get ncKindDocAhead => 'Document expiring soon';

  @override
  String get ncKindDocToday => 'Document expires today';

  @override
  String get ncKindWird => 'Daily wird';

  @override
  String get ncKindCustom => 'Module reminder';

  @override
  String get ncKindOther => 'Notification';

  @override
  String ncAtTime(String time) {
    return 'at $time';
  }

  @override
  String get ncStateMuted => 'Muted';

  @override
  String get ncStateSkipped => 'Skipped';

  @override
  String ncStateSnoozedUntil(String time) {
    return 'Snoozed until $time';
  }

  @override
  String get ncStateLive => 'Showing now';

  @override
  String get ncStateSilenced => 'Arrived muted';

  @override
  String get ncStateOpened => 'Opened';

  @override
  String ncStateAnswered(String action) {
    return 'Answered: $action';
  }

  @override
  String get ncStateSnoozed => 'Snoozed';

  @override
  String get ncStateNew => 'New';

  @override
  String get ncTimeNow => 'Now';

  @override
  String ncTimeIn(String duration) {
    return 'in $duration';
  }

  @override
  String ncTimeAgo(String duration) {
    return '$duration ago';
  }

  @override
  String ncTimeToday(String time) {
    return 'Today $time';
  }

  @override
  String ncTimeTomorrow(String time) {
    return 'Tomorrow $time';
  }

  @override
  String ncTimeYesterday(String time) {
    return 'Yesterday $time';
  }

  @override
  String ncTimeOnDay(String day, String time) {
    return '$day, $time';
  }

  @override
  String get ncActionTaken => 'Taken';

  @override
  String get ncActionSnooze => 'Snooze';

  @override
  String get ncActionSkip => 'Skip';

  @override
  String get ncActionStop => 'Stop';

  @override
  String get ncActionOpen => 'Open';

  @override
  String get ncActionSkipOne => 'Skip this one';

  @override
  String get ncActionRestore => 'Restore';

  @override
  String ncActionSnoozeFor(String duration) {
    return 'Snooze $duration';
  }

  @override
  String ncActionMuteGroup(String group) {
    return 'Mute $group';
  }

  @override
  String get ncActionUnmute => 'Unmute';

  @override
  String get ncActionSettings => 'Reminder settings';

  @override
  String get ncActionDismiss => 'Dismiss';

  @override
  String get ncActionFailed => 'Couldn\'t do that right now – try again';

  @override
  String ncSnoozedToast(String time) {
    return 'Snoozed until $time';
  }

  @override
  String ncMutedToast(String group, String when) {
    return '$group muted until $when';
  }

  @override
  String ncUnmutedToast(String group) {
    return '$group is back on';
  }

  @override
  String ncMuteTitle(String group) {
    return 'Mute $group';
  }

  @override
  String get ncMuteSubtitle =>
      'Nothing from this group will sound for a while – you\'ll still find it listed here.';

  @override
  String ncMuteForHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String get ncMuteUntilMorning => 'Until tomorrow morning';

  @override
  String get ncMuteWeek => 'A week';

  @override
  String ncMutedUntil(String when) {
    return 'Muted until $when';
  }

  @override
  String get ncSettingsTitle => 'Notifications';

  @override
  String get ncSettingsSubtitle =>
      'What each part of Madar sends you, in one place';

  @override
  String get ncSettingsOn => 'On';

  @override
  String get ncSettingsOff => 'Off';

  @override
  String ncSettingsSome(String on, String total) {
    return '$on of $total on';
  }

  @override
  String get ncSettingsPerItem => 'Set per item';

  @override
  String ncSettingsComing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count coming',
      one: '1 coming',
      zero: 'Nothing coming',
    );
    return '$_temp0';
  }

  @override
  String ncSettingsOpen(String group) {
    return 'Open $group settings';
  }

  @override
  String get ncSettingsMute => 'Mute';

  @override
  String get ncPermissionOff =>
      'Madar\'s notifications are off in the phone\'s settings, so none of this will arrive.';

  @override
  String get ncPermissionTurnOn => 'Turn on';

  @override
  String ncBellLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Notifications, $count new',
      one: 'Notifications, 1 new',
      zero: 'Notifications',
    );
    return '$_temp0';
  }

  @override
  String get ncActionCancelSnooze => 'Cancel snooze';

  @override
  String get ncActionSnoozeMenu => 'Snooze…';

  @override
  String get ncSnoozeTitle => 'Bring it back later';

  @override
  String get ncSnoozeSubtitle =>
      'It leaves now and arrives again when you choose.';

  @override
  String ncOptionUntil(String time) {
    return 'until $time';
  }

  @override
  String ncOptionAt(String time) {
    return 'back $time';
  }

  @override
  String ncRecentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notifications',
      one: '1 notification',
    );
    return '$_temp0';
  }

  @override
  String ncUpcomingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notifications in the next seven days',
      one: '1 notification in the next seven days',
      zero: 'Nothing in the next seven days',
    );
    return '$_temp0';
  }

  @override
  String ncNewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new',
      one: '1 new',
    );
    return '$_temp0';
  }

  @override
  String ncUntilTomorrow(String time) {
    return 'tomorrow $time';
  }

  @override
  String get aiChatTitle => 'AI chat';

  @override
  String get aiChatNewChat => 'New chat';

  @override
  String get aiChatListTitle => 'Conversations';

  @override
  String get aiChatSettingsTitle => 'AI settings';

  @override
  String get aiChatSettingsRowSubtitle => 'Keys, model and reply length';

  @override
  String get aiChatAskAi => 'Ask AI';

  @override
  String get aiChatAskAiSubtitle =>
      'With your own key – you choose what’s sent';

  @override
  String aiChatAskAbout(String area) {
    return 'Ask about $area';
  }

  @override
  String get aiChatMenu => 'More';

  @override
  String get aiChatOpenList => 'All conversations';

  @override
  String get aiChatInputHint => 'Write your message…';

  @override
  String get aiChatSend => 'Send';

  @override
  String get aiChatStop => 'Stop';

  @override
  String get aiChatThinking => 'Thinking…';

  @override
  String get aiChatWriting => 'Writing a reply';

  @override
  String get aiChatWillSend => 'Will send';

  @override
  String get aiChatContextReviewFirst => 'you’ll review your summary first';

  @override
  String get aiChatContextNone => 'No personal context';

  @override
  String aiChatContextSections(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count summary sections',
      one: '1 summary section',
      zero: 'No sections',
    );
    return '$_temp0';
  }

  @override
  String aiChatMessagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages',
      one: '1 message',
      zero: 'No messages',
    );
    return '$_temp0';
  }

  @override
  String aiChatApproxTokens(String count) {
    return '≈ $count tokens';
  }

  @override
  String aiChatStripSemantics(String summary) {
    return 'Will send: $summary. Tap to review or change';
  }

  @override
  String aiChatOmitted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count older messages left out',
      one: '1 older message left out',
    );
    return '$_temp0';
  }

  @override
  String get aiChatContextTitle => 'What will be sent';

  @override
  String get aiChatContextSubtitle => 'Nothing is sent until you tap Send';

  @override
  String get aiChatContextFromSummary => 'From your summary';

  @override
  String get aiChatContextChange => 'Review sections';

  @override
  String get aiChatContextChoose => 'Choose sections';

  @override
  String get aiChatContextNoneHint =>
      'Nothing from your data is sent – only this conversation’s messages.';

  @override
  String get aiChatContextUnsetHint =>
      'On the first send, the summary preview opens so you can pick sections or leave any out.';

  @override
  String get aiChatContextUse => 'Use in this chat';

  @override
  String get aiChatContextUseAndSend => 'Use and send';

  @override
  String aiChatContextReviewed(String when) {
    return 'Reviewed $when';
  }

  @override
  String get aiChatContextCancelled => 'Nothing was sent.';

  @override
  String aiChatServiceModel(String service, String model) {
    return '$service · $model';
  }

  @override
  String get aiChatViewPayload => 'View the exact request';

  @override
  String get aiChatDone => 'Done';

  @override
  String get aiChatPayloadTitle => 'The exact request';

  @override
  String get aiChatPayloadEndpoint => 'Endpoint';

  @override
  String get aiChatPayloadHeaders => 'Headers (key hidden)';

  @override
  String get aiChatPayloadSystem => 'Instructions and context';

  @override
  String get aiChatPayloadMessages => 'Messages';

  @override
  String get aiChatPayloadRaw => 'Full body (JSON)';

  @override
  String get aiChatPayloadDraftNote =>
      'Includes the message you’re typing. It’s sent only when you tap Send.';

  @override
  String get aiChatPayloadNoDraft =>
      'Write a message to see the complete request.';

  @override
  String aiChatPayloadSize(String size, String tokens) {
    return '$size · ≈ $tokens tokens';
  }

  @override
  String aiChatBytes(String count) {
    return '$count bytes';
  }

  @override
  String aiChatKiloBytes(String count) {
    return '$count KB';
  }

  @override
  String get aiChatRoleUser => 'You';

  @override
  String get aiChatRoleAssistant => 'Assistant';

  @override
  String get aiChatCopy => 'Copy';

  @override
  String get aiChatCopied => 'Copied';

  @override
  String get aiChatCopyCode => 'Copy code';

  @override
  String get aiChatRegenerate => 'Regenerate';

  @override
  String get aiChatRetry => 'Try again';

  @override
  String get aiChatStopped => 'You stopped the reply';

  @override
  String get aiChatCutShort =>
      'The reply hit the length limit. You can raise it in settings.';

  @override
  String get aiChatRefused => 'The model declined to answer.';

  @override
  String get aiChatFiltered => 'The content filter stopped the reply.';

  @override
  String get aiChatHealthNote =>
      'For tracking only, not medical advice – ask your clinician about any health decision.';

  @override
  String aiChatOpenLink(String url) {
    return 'Open link $url';
  }

  @override
  String get aiChatLinkFailed => 'Couldn’t open the link.';

  @override
  String aiChatErrorNoKey(String service) {
    return 'Add your $service key first.';
  }

  @override
  String aiChatErrorBadKey(String service) {
    return '$service rejected the key. Check it or replace it in settings.';
  }

  @override
  String get aiChatErrorForbidden =>
      'This key isn’t allowed to use this model.';

  @override
  String get aiChatErrorRateLimited =>
      'Too many requests right now. Wait a moment, then try again.';

  @override
  String aiChatErrorRetryAfter(String seconds) {
    return 'You can try again in $seconds s.';
  }

  @override
  String aiChatErrorQuota(String service) {
    return 'You’re out of credit or at your spend limit with $service.';
  }

  @override
  String aiChatErrorOverloaded(String service) {
    return '$service is busy right now. Try again shortly.';
  }

  @override
  String aiChatErrorServer(String service) {
    return '$service had a problem. Try again.';
  }

  @override
  String aiChatErrorModelNotFound(String model) {
    return 'The model “$model” isn’t available to this key. Pick another model.';
  }

  @override
  String get aiChatErrorTemperature =>
      'This model doesn’t accept a custom temperature. Set it to “Model default” in settings.';

  @override
  String get aiChatErrorContextTooLong =>
      'The conversation is too long for the model. Start a new chat or share fewer sections.';

  @override
  String aiChatErrorBadRequest(String service) {
    return '$service rejected the request.';
  }

  @override
  String get aiChatErrorNetwork =>
      'No internet connection, or the connection dropped.';

  @override
  String get aiChatErrorTimeout => 'No answer came in time.';

  @override
  String get aiChatErrorBadResponse => 'The answer couldn’t be read.';

  @override
  String get aiChatErrorUnknown => 'Something unexpected went wrong.';

  @override
  String get aiChatOpenSettings => 'Open settings';

  @override
  String get aiChatSetupTitle => 'Connect your own key';

  @override
  String get aiChatSetupBody =>
      'The chat uses your own Anthropic or OpenAI API key. It’s stored encrypted on this phone only – never in backups or exports.';

  @override
  String aiChatSetupAdd(String service) {
    return 'Add $service key';
  }

  @override
  String get aiChatSetupPrivacy =>
      'Nothing is sent until you tap Send, and you see exactly what goes out first.';

  @override
  String get aiChatEmptyTitle => 'How can I help today?';

  @override
  String get aiChatEmptyBody =>
      'Ask about your day, prayers, budget or goals. You choose what’s shared from your summary before sending.';

  @override
  String get aiChatSuggestWeek => 'Sum up my week in a few points';

  @override
  String get aiChatSuggestBudget => 'How can I improve my budget this month?';

  @override
  String get aiChatSuggestPlan => 'Help me plan a balanced tomorrow';

  @override
  String get aiChatSuggestPrayer => 'How can I keep my prayers on time?';

  @override
  String get aiChatListEmptyTitle => 'No conversations yet';

  @override
  String get aiChatListEmptyBody =>
      'Start a chat – it’s kept here, encrypted on your phone.';

  @override
  String get aiChatRename => 'Rename';

  @override
  String get aiChatRenameField => 'Conversation name';

  @override
  String get aiChatRenameSave => 'Save name';

  @override
  String get aiChatDelete => 'Delete chat';

  @override
  String get aiChatDeleted => 'Chat deleted';

  @override
  String get aiChatDeleteAll => 'Delete all chats';

  @override
  String get aiChatDeletedAll => 'All chats deleted';

  @override
  String get aiChatUntitled => 'Untitled chat';

  @override
  String aiChatListLimitNote(String count) {
    return 'The latest $count chats are kept; older ones are removed automatically.';
  }

  @override
  String aiChatListUpdated(String when, String messages) {
    return '$when · $messages';
  }

  @override
  String get aiChatToday => 'Today';

  @override
  String get aiChatYesterday => 'Yesterday';

  @override
  String get aiChatSettingsService => 'Service';

  @override
  String get aiChatSettingsServiceModel => 'Service and model';

  @override
  String get aiChatServiceAnthropic => 'Anthropic';

  @override
  String get aiChatServiceOpenai => 'OpenAI';

  @override
  String get aiChatSettingsKeys => 'API keys';

  @override
  String aiChatKeyTitle(String service) {
    return '$service key';
  }

  @override
  String aiChatKeySaved(String mask) {
    return 'Saved · $mask';
  }

  @override
  String get aiChatKeyNotSet => 'Not added yet';

  @override
  String get aiChatKeySheetSubtitle => 'Stored encrypted on this phone only.';

  @override
  String get aiChatKeyCurrent => 'Current key';

  @override
  String get aiChatKeyField => 'Key';

  @override
  String get aiChatKeyFieldHint => 'Paste the key here';

  @override
  String get aiChatKeyPaste => 'Paste';

  @override
  String get aiChatKeySave => 'Save key';

  @override
  String get aiChatKeyReplace => 'Replace key';

  @override
  String get aiChatKeyDelete => 'Delete key';

  @override
  String get aiChatKeyDeleted => 'Key deleted';

  @override
  String get aiChatKeySavedNotice => 'Key saved.';

  @override
  String get aiChatKeyTest => 'Test key';

  @override
  String get aiChatKeyTestOk => 'The key works.';

  @override
  String get aiChatKeyTestNote =>
      'The test only asks for the model list – none of your data is sent.';

  @override
  String get aiChatKeyWhere => 'Where do I get a key?';

  @override
  String get aiChatKeyProblemEmpty => 'Paste the key first.';

  @override
  String get aiChatKeyProblemShort => 'That’s too short to be a key.';

  @override
  String get aiChatKeyProblemSpaces =>
      'The key contains spaces – copy it again.';

  @override
  String aiChatKeyProblemProvider(String service) {
    return 'This key belongs to $service, so it wasn’t saved here – it would be sent to the wrong service. Add it under $service.';
  }

  @override
  String get aiChatSettingsModel => 'Model';

  @override
  String get aiChatModelPickerTitle => 'Choose a model';

  @override
  String get aiChatModelYourList => 'Your list';

  @override
  String aiChatModelsAvailable(String service) {
    return 'Available from $service';
  }

  @override
  String get aiChatModelCustom => 'Add a model id';

  @override
  String get aiChatModelCustomField => 'Model id';

  @override
  String aiChatModelCustomHint(String model) {
    return 'e.g. $model';
  }

  @override
  String get aiChatModelInvalid => 'Not a valid model id.';

  @override
  String get aiChatModelUse => 'Use';

  @override
  String get aiChatModelRefresh => 'Refresh models';

  @override
  String aiChatModelRefreshed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count models available',
      one: '1 model available',
      zero: 'No models available',
    );
    return '$_temp0';
  }

  @override
  String aiChatModelRefreshNote(String service) {
    return 'Asks $service for the list only when you tap.';
  }

  @override
  String get aiChatModelReset => 'Reset the list';

  @override
  String aiChatModelRemove(String model) {
    return 'Remove $model from the list';
  }

  @override
  String get aiChatModelSelected => 'Selected';

  @override
  String aiChatModelChip(String model) {
    return 'Model: $model. Tap to change';
  }

  @override
  String get aiChatSettingsReply => 'Reply';

  @override
  String get aiChatMaxTokens => 'Longest reply';

  @override
  String get aiChatMaxTokensNote => 'In tokens, including any model reasoning.';

  @override
  String get aiChatTemperature => 'Temperature';

  @override
  String get aiChatTemperatureDefault => 'Model default (recommended)';

  @override
  String get aiChatTemperatureNote =>
      'Newer models accept only the default. Lower = steadier replies.';

  @override
  String get aiChatSettingsPrivacy => 'Privacy';

  @override
  String get aiChatPrivacyKeys =>
      'Keys live in the phone’s encrypted storage – not in the database, backups or exports.';

  @override
  String get aiChatPrivacyCalls =>
      'Madar contacts the service only when you tap Send, Regenerate, Try again, Test key or Refresh models. Nothing runs in the background.';

  @override
  String aiChatPrivacyHistory(String count) {
    return 'Chats are kept encrypted on your phone (the latest $count), each with the summary you approved for it. They are part of your backups and your full data export.';
  }

  @override
  String get aiChatKeyProblemChars =>
      'The key has characters no key has (maybe from copying) – copy it again.';

  @override
  String get aiChatLinkTitle => 'Open this link?';

  @override
  String get aiChatLinkBody =>
      'It opens outside Madar, and everything in the address goes to that site. Open it only if you trust it.';

  @override
  String get aiChatLinkOpen => 'Open link';

  @override
  String get togetherTitle => 'Together';

  @override
  String get togetherHallOfFame => 'Our Hall of Fame';

  @override
  String togetherPlayerDefault(String number) {
    return 'Player $number';
  }

  @override
  String get togetherVs => 'vs';

  @override
  String togetherEditProfile(String name) {
    return 'Edit $name\'s profile';
  }

  @override
  String get togetherSettingsTitle => 'Together settings';

  @override
  String get togetherPlayers => 'Players';

  @override
  String get togetherWinsLabel => 'Wins';

  @override
  String togetherLeads(String name, String diff) {
    return '$name leads by $diff';
  }

  @override
  String get togetherAllSquare => 'All square';

  @override
  String togetherDrawsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count draws',
      one: '1 draw',
      zero: 'No draws',
    );
    return '$_temp0';
  }

  @override
  String togetherMatchesCount(int count) {
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
  String togetherDaysCount(int count) {
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
  String get togetherDayStreakLabel => 'Days in a row';

  @override
  String get togetherWinStreakLabel => 'Win streak';

  @override
  String get togetherCoopLabel => 'Team wins';

  @override
  String get togetherPlayedToday => 'Played today';

  @override
  String get togetherPlayTodayHint => 'Play today to keep it going';

  @override
  String get togetherNoStreak => 'No streak yet';

  @override
  String get togetherSeeAll => 'See all';

  @override
  String get togetherHeadToHead => 'Head to head';

  @override
  String get togetherRecentMatches => 'Recent matches';

  @override
  String get togetherEmptyTitle => 'No matches yet';

  @override
  String get togetherEmptyBody =>
      'Play your first game together — every match lands here, with streaks and trophies.';

  @override
  String get togetherShelfEmpty => 'Your first trophy is waiting';

  @override
  String togetherTrophiesProgress(String earned, String total) {
    return '$earned of $total';
  }

  @override
  String get togetherTrophiesEarned => 'Trophies earned';

  @override
  String togetherResultWon(String name) {
    return '$name won';
  }

  @override
  String get togetherResultDraw => 'Draw';

  @override
  String get togetherResultTeamWon => 'Won together';

  @override
  String get togetherResultTeamLost => 'Lost together';

  @override
  String togetherBestScore(String score) {
    return 'Best: $score';
  }

  @override
  String get togetherModePassAndPlay => 'Pass & play';

  @override
  String get togetherModePassAndPlayBody =>
      'One phone taking turns — a hand-off screen hides cards and answers';

  @override
  String get togetherModeSplitScreen => 'Split screen';

  @override
  String get togetherModeSplitScreenBody =>
      'One phone, a half each, both touching at once';

  @override
  String get togetherModeNearby => 'Two phones nearby';

  @override
  String get togetherModeNearbyBody =>
      'Bluetooth & Wi-Fi Direct — no internet, no servers';

  @override
  String get togetherModeOnline => 'Two phones online';

  @override
  String get togetherModeOnlineBody => 'From different places — off by default';

  @override
  String get togetherComingSoon => 'Coming soon';

  @override
  String get togetherModeUnsupported => 'Not in this game';

  @override
  String get togetherModeDisabled => 'Off in settings';

  @override
  String get togetherOnlyGameState =>
      'Only game state ever travels between phones — health, money and personal data never leave the device.';

  @override
  String get togetherLaunchSubtitle => 'How will you play?';

  @override
  String get togetherWhoStarts => 'Who starts?';

  @override
  String get togetherRandomStart => 'Random';

  @override
  String get togetherStartGame => 'Let\'s play';

  @override
  String get togetherSplitLayout => 'Screen layout';

  @override
  String get togetherLayoutFaceToFace => 'Face to face';

  @override
  String get togetherLayoutSideBySide => 'Side by side';

  @override
  String get togetherLayoutEndToEnd => 'End to end';

  @override
  String get togetherPassTo => 'Pass the phone to';

  @override
  String togetherPassToName(String name) {
    return 'Pass the phone to $name';
  }

  @override
  String get togetherHandOffHint =>
      'Private info stays hidden until its owner reveals it';

  @override
  String get togetherNoPeeking => 'No peeking!';

  @override
  String togetherReveal(String name) {
    return 'I\'m $name — reveal';
  }

  @override
  String togetherStillYou(String name) {
    return 'Still you, $name?';
  }

  @override
  String get togetherShieldHint =>
      'The screen was hidden when you left the app';

  @override
  String get togetherContinue => 'Continue';

  @override
  String togetherLastMove(String move) {
    return 'Last move: $move';
  }

  @override
  String get togetherPause => 'Pause';

  @override
  String togetherYourSide(String name) {
    return '$name\'s side';
  }

  @override
  String get togetherProfileTitle => 'Player profile';

  @override
  String get togetherFieldName => 'Name';

  @override
  String get togetherFieldTitle => 'Title';

  @override
  String get togetherTitleNone => 'No title';

  @override
  String get togetherTitleCustom => 'Custom';

  @override
  String get togetherTitleCustomHint => 'Type a title';

  @override
  String get togetherFieldAvatar => 'Avatar';

  @override
  String get togetherAvatarConstellation => 'Emblem';

  @override
  String get togetherAvatarEmoji => 'Emoji';

  @override
  String get togetherAvatarInitials => 'Initial';

  @override
  String get togetherAvatarShuffle => 'Shuffle';

  @override
  String togetherAvatarOption(String number) {
    return 'Design $number';
  }

  @override
  String get togetherFieldColor => 'Colour';

  @override
  String togetherColorTaken(String name) {
    return '$name\'s colour';
  }

  @override
  String get togetherSave => 'Save';

  @override
  String get togetherCancel => 'Cancel';

  @override
  String get togetherTitleStrategist => 'The Mastermind';

  @override
  String get togetherTitleCardShark => 'Card Star';

  @override
  String get togetherTitleLuckyStar => 'Lucky Star';

  @override
  String get togetherTitleChallenger => 'The Challenger';

  @override
  String get togetherTitleGrandmaster => 'Board Legend';

  @override
  String get togetherTitleQuizWhiz => 'Quiz Whiz';

  @override
  String get togetherTitleComebackKing => 'Comeback Kid';

  @override
  String get togetherTitleLightning => 'Lightning';

  @override
  String get togetherTitlePeacemaker => 'Peacemaker';

  @override
  String get togetherTitleDreamer => 'Dreamer';

  @override
  String get togetherTrophyFirstMatch => 'First Match';

  @override
  String get togetherTrophyFirstMatchDesc => 'Your first match together';

  @override
  String get togetherTrophyMatches10 => 'Ten Together';

  @override
  String togetherTrophyMatches10Desc(String count) {
    return '$count matches together';
  }

  @override
  String get togetherTrophyMatches50 => 'Fifty Strong';

  @override
  String togetherTrophyMatches50Desc(String count) {
    return '$count matches together';
  }

  @override
  String get togetherTrophyMatches100 => 'Century Club';

  @override
  String togetherTrophyMatches100Desc(String count) {
    return '$count matches together';
  }

  @override
  String get togetherTrophyMatches250 => 'Partners for Life';

  @override
  String togetherTrophyMatches250Desc(String count) {
    return '$count matches together';
  }

  @override
  String get togetherTrophyDayStreak3 => 'Little Flame';

  @override
  String togetherTrophyDayStreak3Desc(String count) {
    return 'Played together $count days in a row';
  }

  @override
  String get togetherTrophyDayStreak7 => 'Full Week';

  @override
  String togetherTrophyDayStreak7Desc(String count) {
    return 'Played together $count days in a row';
  }

  @override
  String get togetherTrophyDayStreak30 => 'A Month Strong';

  @override
  String togetherTrophyDayStreak30Desc(String count) {
    return 'Played together $count days in a row';
  }

  @override
  String get togetherTrophyWinStreak3 => 'Hat-trick';

  @override
  String togetherTrophyWinStreak3Desc(String count) {
    return '$count wins in a row';
  }

  @override
  String get togetherTrophyWinStreak5 => 'Unstoppable';

  @override
  String togetherTrophyWinStreak5Desc(String count) {
    return '$count wins in a row';
  }

  @override
  String get togetherTrophyWinStreak10 => 'Legendary Run';

  @override
  String togetherTrophyWinStreak10Desc(String count) {
    return '$count wins in a row';
  }

  @override
  String get togetherTrophyExplorer5 => 'Explorers';

  @override
  String togetherTrophyExplorer5Desc(String count) {
    return 'Played $count different games';
  }

  @override
  String get togetherTrophyExplorer10 => 'Game Voyagers';

  @override
  String togetherTrophyExplorer10Desc(String count) {
    return 'Played $count different games';
  }

  @override
  String get togetherTrophyCoopWins5 => 'Dream Team';

  @override
  String togetherTrophyCoopWins5Desc(String count) {
    return '$count wins as a team';
  }

  @override
  String get togetherTrophyCoopWins25 => 'One Heart';

  @override
  String togetherTrophyCoopWins25Desc(String count) {
    return '$count wins as a team';
  }

  @override
  String get togetherTrophyMarathon => 'Marathon';

  @override
  String togetherTrophyMarathonDesc(String count) {
    return '$count matches in one day';
  }

  @override
  String get togetherTrophyPhotoFinish => 'Neck and Neck';

  @override
  String get togetherTrophyPhotoFinishDesc => 'Your first draw';

  @override
  String get togetherTrophyNailBiter => 'Nail-biter';

  @override
  String get togetherTrophyNailBiterDesc => 'Won by a single point';

  @override
  String get togetherTrophyPerfectBalance => 'Perfect Balance';

  @override
  String togetherTrophyPerfectBalanceDesc(String count) {
    return 'Level on wins after at least $count matches';
  }

  @override
  String get togetherTrophyGameMaster => 'Game Master';

  @override
  String togetherTrophyGameMasterDesc(String count, String game) {
    return '$count wins in $game';
  }

  @override
  String get togetherTierBronze => 'Bronze';

  @override
  String get togetherTierSilver => 'Silver';

  @override
  String get togetherTierGold => 'Gold';

  @override
  String get togetherTierLegendary => 'Legendary';

  @override
  String togetherEarnedOn(String date) {
    return 'Earned $date';
  }

  @override
  String get togetherLocked => 'Not earned yet';

  @override
  String get togetherTrophyShared => 'Shared by you both';

  @override
  String togetherTrophyHolder(String name) {
    return 'Earned by $name';
  }

  @override
  String get togetherNewTrophies => 'New in our Hall of Fame!';

  @override
  String togetherProgressOf(String current, String target) {
    return '$current / $target';
  }

  @override
  String get togetherGameTarneeb => 'Tarneeb';

  @override
  String get togetherGameTrix => 'Trix';

  @override
  String get togetherGameBasra => 'Basra';

  @override
  String get togetherGameKonkan => 'Konkan';

  @override
  String get togetherGameBackgammon => 'Backgammon';

  @override
  String get togetherGameChess => 'Chess';

  @override
  String get togetherGameDominoes => 'Dominoes';

  @override
  String get togetherGameLudo => 'Ludo';

  @override
  String get togetherGameFourInARow => 'Four in a Row';

  @override
  String get togetherGameWordDuel => 'Word Duel';

  @override
  String get togetherGameQuizDuel => 'Islamic Quiz Duel';

  @override
  String get togetherGameDrawGuess => 'Draw & Guess';

  @override
  String get togetherGameMiniGolf => 'Mini Golf';

  @override
  String get togetherGameKnowMe => 'How Well Do You Know Me?';

  @override
  String get togetherGameAirHockey => 'Air Hockey';

  @override
  String get togetherGameBeachVolley => 'Beach Volley Duo';

  @override
  String get togetherGameKartDash => 'Kart Dash';

  @override
  String get togetherGameSnowballFight => 'Snowball Fight';

  @override
  String get togetherGamePaddleDuel => 'Paddle Duel';

  @override
  String get togetherGameTankDuel => 'Tank Duel';

  @override
  String get togetherGameMetropolisCoop => 'Metropolis Machine Co-op';

  @override
  String get togetherGameUnknown => 'Game';

  @override
  String get togetherSettingsDefaultMode => 'Default play mode';

  @override
  String get togetherSettingsDefaultModeHint =>
      'Suggested at the start of every game — you can still change it then';

  @override
  String get togetherSettingsOnline => 'Online play';

  @override
  String get togetherSettingsOnlineHint =>
      'Off by default. When on, only game state travels.';

  @override
  String get togetherSettingsPrivacy => 'Hide from recent apps';

  @override
  String get togetherSettingsPrivacyHint =>
      'During private turns the screen stays out of thumbnails and screenshots';

  @override
  String get togetherResetRecords => 'Clear history & trophies';

  @override
  String get togetherResetDone => 'History and trophies cleared';

  @override
  String get togetherTapToEdit => 'Tap to edit';

  @override
  String get togetherSpecialsTitle => 'Just the two of us';

  @override
  String get togetherSpecialsGoalEmpty => 'Set a goal and a reward';

  @override
  String get togetherSpecialsSettings => 'Challenge settings';

  @override
  String get togetherKnowMeIntro =>
      'Each of you answers about yourself and guesses the other\'s answers – they stay hidden until you reveal them together.';

  @override
  String get togetherKnowMeQuestionsPerRound => 'Questions per round';

  @override
  String get togetherKnowMeCategories => 'Categories';

  @override
  String get togetherKnowMeAllCategories => 'All';

  @override
  String get togetherKnowMeStart => 'Start the round';

  @override
  String get togetherKnowMeEditQuestions => 'Edit questions';

  @override
  String togetherKnowMeQuestionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions',
      one: '1 question',
      zero: 'No questions',
    );
    return '$_temp0';
  }

  @override
  String get togetherKnowMeNoQuestions => 'No questions in these categories';

  @override
  String get togetherKnowMeWhoKnowsBest => 'Who knows the other best?';

  @override
  String togetherKnowMeRoundsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rounds',
      one: '1 round',
      zero: 'No rounds yet',
    );
    return '$_temp0';
  }

  @override
  String togetherKnowMeQuestionOf(String current, String total) {
    return 'Question $current of $total';
  }

  @override
  String get togetherKnowMeYourAnswer => 'Your own answer';

  @override
  String get togetherKnowMeYourAnswerHint =>
      'Leave it empty to skip the question';

  @override
  String togetherKnowMeYourGuess(String name) {
    return 'Your guess of $name\'s answer';
  }

  @override
  String get togetherKnowMeGuessHint => 'Your guess…';

  @override
  String get togetherKnowMeNext => 'Next';

  @override
  String get togetherKnowMeBack => 'Back';

  @override
  String get togetherKnowMeDonePass => 'I\'m done';

  @override
  String get togetherKnowMeDoneReveal => 'I\'m done – to the reveal';

  @override
  String get togetherKnowMeHiddenNote =>
      'Your answers stay hidden until the reveal';

  @override
  String get togetherKnowMeRevealTitle => 'The reveal';

  @override
  String togetherKnowMeAnswerOf(String name) {
    return '$name\'s answer';
  }

  @override
  String togetherKnowMeGuessOf(String name) {
    return '$name\'s guess';
  }

  @override
  String get togetherKnowMeRevealButton => 'Reveal';

  @override
  String get togetherKnowMeHiddenAnswer => 'Hidden until the reveal';

  @override
  String get togetherKnowMeSkipped => 'Skipped – not scored';

  @override
  String get togetherKnowMeNoGuess => 'No guess';

  @override
  String togetherKnowMeJudgePrompt(String name) {
    return '$name, how close was the guess?';
  }

  @override
  String get togetherKnowMeExact => 'Spot on';

  @override
  String get togetherKnowMeClose => 'Close';

  @override
  String get togetherKnowMeMiss => 'Not quite';

  @override
  String get togetherKnowMeSuggested => 'Suggested';

  @override
  String get togetherKnowMeNextQuestion => 'Next question';

  @override
  String get togetherKnowMeSeeResults => 'See the results';

  @override
  String get togetherKnowMeJudgeFirst => 'Judge the guesses first';

  @override
  String get togetherKnowMeResultsTitle => 'Results';

  @override
  String get togetherKnowMeDrawText =>
      'A draw – you know each other equally well!';

  @override
  String togetherKnowMeScoreOf(String score, String max) {
    return '$score of $max';
  }

  @override
  String togetherKnowMeAccuracy(String percent) {
    return 'Guessing accuracy $percent';
  }

  @override
  String get togetherKnowMePlayAgain => 'Another round';

  @override
  String get togetherKnowMeFinish => 'Done';

  @override
  String get togetherKnowMeNotRecorded =>
      'Not recorded – no question was answered';

  @override
  String get togetherKnowMeLeaveTitle => 'Leave the round?';

  @override
  String get togetherKnowMeLeaveBody =>
      'The answers typed in this round will be lost.';

  @override
  String get togetherKnowMeLeave => 'Leave';

  @override
  String get togetherKnowMeStay => 'Keep playing';

  @override
  String get togetherKnowMeBankTitle => 'Question bank';

  @override
  String get togetherKnowMeAddQuestion => 'New question';

  @override
  String get togetherKnowMeEditQuestion => 'Edit question';

  @override
  String get togetherKnowMeQuestionField => 'Question';

  @override
  String get togetherKnowMeQuestionHint =>
      'In the first person: “What\'s my favourite …?”';

  @override
  String get togetherKnowMeCategoryField => 'Category';

  @override
  String get togetherKnowMeAddCategory => 'New category';

  @override
  String get togetherKnowMeEditCategory => 'Edit category';

  @override
  String get togetherKnowMeCategoryName => 'Category name';

  @override
  String get togetherKnowMeCategoryIcon => 'Icon';

  @override
  String get togetherKnowMeDeleteCategory => 'Delete category';

  @override
  String togetherKnowMeCategoryDeleted(String name) {
    return 'Category deleted – its questions moved to “$name”';
  }

  @override
  String get togetherKnowMeQuestionDeleted => 'Question deleted';

  @override
  String get togetherKnowMeMoveTo => 'Move to category';

  @override
  String get togetherKnowMeResetWording => 'Original wording';

  @override
  String get togetherKnowMeRestoreDefaults => 'Restore default questions';

  @override
  String get togetherKnowMeRestored => 'Default questions restored';

  @override
  String togetherKnowMeBankFull(String max) {
    return 'The bank is full ($max questions)';
  }

  @override
  String get togetherKnowMeEmptyCategory => 'No questions in this category yet';

  @override
  String get togetherKnowMeEdited => 'Edited';

  @override
  String get togetherKnowMeOwn => 'Our own';

  @override
  String get togetherKnowMeLastCategory => 'At least one category must stay';

  @override
  String get togetherKnowMeReorderHint =>
      'Drag the handle to reorder; long-press for more';

  @override
  String get togetherWeeklyTitle => 'Challenge of the week';

  @override
  String togetherWeeklyDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days left',
      one: 'Last day',
      zero: 'Last day',
    );
    return '$_temp0';
  }

  @override
  String togetherWeeklyRenewsOn(String day) {
    return 'Renews on $day';
  }

  @override
  String get togetherWeeklyMarkDone => 'I did it';

  @override
  String get togetherWeeklyDone => 'Done';

  @override
  String togetherWeeklyWaiting(String name) {
    return 'Waiting for $name';
  }

  @override
  String get togetherWeeklyNotYet => 'Not started yet';

  @override
  String get togetherWeeklyBothDone => 'Done together!';

  @override
  String get togetherWeeklyStreak => 'Streak';

  @override
  String get togetherWeeklyBest => 'Best streak';

  @override
  String get togetherWeeklyTotal => 'Completed';

  @override
  String get togetherWeeklyAnother => 'Another one';

  @override
  String get togetherWeeklyPick => 'Pick a challenge';

  @override
  String get togetherWeeklySwapLocked =>
      'The challenge can\'t change once one of you has done it';

  @override
  String get togetherWeeklyList => 'Our challenges';

  @override
  String get togetherWeeklyListHint =>
      'Challenges take turns in this order, week after week';

  @override
  String get togetherWeeklyAdd => 'New challenge';

  @override
  String get togetherWeeklyEdit => 'Edit challenge';

  @override
  String get togetherWeeklyField => 'Challenge';

  @override
  String get togetherWeeklyFieldHint => 'Something to do together this week';

  @override
  String get togetherWeeklyHide => 'Take out of rotation';

  @override
  String get togetherWeeklyShow => 'Put back in rotation';

  @override
  String get togetherWeeklyHidden => 'Not in rotation';

  @override
  String get togetherWeeklyDeleted => 'Challenge deleted';

  @override
  String get togetherWeeklyHiddenDone => 'Taken out of rotation';

  @override
  String get togetherWeeklyLastActive =>
      'At least one challenge must stay in rotation';

  @override
  String get togetherWeeklyRecent => 'Recent weeks';

  @override
  String get togetherWeeklyUndone => 'Marked as not done';

  @override
  String get togetherWeeklyThisWeek => 'This week';

  @override
  String get togetherWeekStart => 'Week starts on';

  @override
  String get togetherWeekStartHint =>
      'The challenge renews at midnight on this day, phone time.';

  @override
  String togetherWeeksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks',
      one: '1 week',
      zero: '0 weeks',
    );
    return '$_temp0';
  }

  @override
  String get togetherGoalTitle => 'Our goal';

  @override
  String get togetherGoalNone => 'No goal yet';

  @override
  String get togetherGoalNoneBody =>
      'Choose a goal together – and a reward that waits for you when you reach it.';

  @override
  String get togetherGoalSet => 'Set a goal';

  @override
  String get togetherGoalEdit => 'Edit goal';

  @override
  String get togetherGoalNew => 'New goal';

  @override
  String get togetherGoalNameField => 'Goal name';

  @override
  String get togetherGoalRewardField => 'The reward';

  @override
  String get togetherGoalRewardHint => 'e.g. dinner at our favourite place';

  @override
  String get togetherGoalRewardRequired =>
      'Write the reward that waits for you';

  @override
  String get togetherGoalMetricField => 'How do we get there?';

  @override
  String get togetherGoalMetricPoints => 'Together points';

  @override
  String togetherGoalMetricPointsBody(String match, String challenge) {
    return '$match for each match we play, $challenge for each weekly challenge we complete';
  }

  @override
  String get togetherGoalMetricCounter => 'Our own counter';

  @override
  String get togetherGoalMetricCounterBody =>
      'We move it ourselves: walks, pages, visits…';

  @override
  String get togetherGoalTargetField => 'Target';

  @override
  String get togetherGoalUnitField => 'Unit';

  @override
  String get togetherGoalUnitHint => 'e.g. walks';

  @override
  String get togetherGoalCountGames => 'Matches';

  @override
  String get togetherGoalCountChallenges => 'Weekly challenges';

  @override
  String togetherGoalPointsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points',
      one: '1 point',
      zero: '0 points',
    );
    return '$_temp0';
  }

  @override
  String togetherGoalProgress(String current, String target) {
    return '$current of $target';
  }

  @override
  String togetherGoalRemaining(String count) {
    return '$count to go';
  }

  @override
  String get togetherGoalRewardLocked => 'Your reward is waiting';

  @override
  String get togetherGoalUnlocked => 'Reward unlocked!';

  @override
  String get togetherGoalUnlockedBody =>
      'You reached your goal. Enjoy your reward:';

  @override
  String get togetherGoalNext => 'Our next goal';

  @override
  String togetherGoalFromMatches(String points) {
    return 'From matches: $points';
  }

  @override
  String togetherGoalFromChallenges(String points) {
    return 'From challenges: $points';
  }

  @override
  String get togetherGoalAchieved => 'Our rewards';

  @override
  String get togetherGoalDelete => 'Drop this goal';

  @override
  String get togetherGoalDeleted => 'Goal dropped';

  @override
  String get togetherGoalAddOne => 'Add one';

  @override
  String get togetherGoalTakeOne => 'Take one away';

  @override
  String get togetherGoalCounterDefaultUnit => 'times';

  @override
  String togetherGoalSince(String date) {
    return 'Since $date';
  }

  @override
  String get togetherTrophyMindReader => 'Mind reader';

  @override
  String get togetherTrophyMindReaderDesc =>
      'A perfect round of “How well do you know me?”';

  @override
  String get togetherTrophyChallengeChampions => 'Weekly heroes';

  @override
  String get togetherTrophyChallengeChampionsDesc =>
      'The weekly challenge, four weeks in a row';

  @override
  String get togetherTrophyDreamCameTrue => 'Wish granted';

  @override
  String get togetherTrophyDreamCameTrueDesc =>
      'A shared goal reached, its reward unlocked';

  @override
  String togetherWeeklyInRotation(String count) {
    return '$count in rotation';
  }

  @override
  String get togetherKnowMeRecap => 'The answers';

  @override
  String togetherWeeklyRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String get widgetsPrayerName => 'Next prayer';

  @override
  String get widgetsMedsName => 'Today’s meds';

  @override
  String get widgetsTasksName => 'Today’s Top 3';

  @override
  String get widgetsBudgetName => 'Budget left';

  @override
  String widgetsCountdown(String time) {
    return 'in $time';
  }

  @override
  String widgetsPrayerNotePlace(String date, String place) {
    return '$date · $place';
  }

  @override
  String widgetsFraction(String done, String total) {
    return '$done/$total';
  }

  @override
  String widgetsMedsNext(String time, String name) {
    return 'Next at $time: $name';
  }

  @override
  String widgetsMedsPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count doses to go',
      one: '1 dose to go',
    );
    return '$_temp0';
  }

  @override
  String get widgetsMedsAllDone => 'Every dose of today is logged';

  @override
  String get widgetsMedsNoneToday => 'No doses today';

  @override
  String get widgetsMedsSetUp => 'Add your medications in Madar';

  @override
  String widgetsMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count more doses',
      one: '+1 more dose',
    );
    return '$_temp0';
  }

  @override
  String widgetsTasksLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count to go',
      one: '1 to go',
    );
    return '$_temp0';
  }

  @override
  String get widgetsTasksAllDone => 'Today’s Top 3 are done';

  @override
  String get widgetsTasksEmpty => 'Choose today’s Top 3 in Madar';

  @override
  String widgetsTasksCarried(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unfinished from yesterday',
      one: '1 unfinished from yesterday',
    );
    return '$_temp0';
  }

  @override
  String widgetsBudgetOf(String amount) {
    return 'of $amount';
  }

  @override
  String widgetsBudgetOverBy(String amount) {
    return 'Over by $amount';
  }

  @override
  String get widgetsBudgetOver => 'Over budget';

  @override
  String get widgetsBudgetLeftMonth => 'left this month';

  @override
  String get widgetsBudgetLeftWeek => 'left this week';

  @override
  String widgetsBudgetDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days left',
      one: '1 day left',
      zero: 'Last day',
    );
    return '$_temp0';
  }

  @override
  String get widgetsBudgetNone => 'Set up your budget in Madar';

  @override
  String get widgetsStale => 'Open Madar to refresh this widget';

  @override
  String get widgetsSettingsTitle => 'Home-screen widgets';

  @override
  String get widgetsSettingsIntro =>
      'Add Madar’s widgets from your home screen: long-press an empty spot, choose Widgets, then Madar.';

  @override
  String get widgetsShowDetails => 'Show details';

  @override
  String get widgetsDetailsShown =>
      'Names, times and amounts show on the home screen';

  @override
  String get widgetsDetailsHidden => 'Counts only — no names or amounts';

  @override
  String get widgetsPrayerDetailsShown =>
      'Your city’s name shows under the Hijri date';

  @override
  String get widgetsPrayerDetailsHidden =>
      'The prayer, its time and the date — no city';

  @override
  String get widgetsOnHomeScreen => 'On your home screen';

  @override
  String get widgetsNotAdded => 'Not added yet';

  @override
  String get widgetsLockNote =>
      'App Lock is on, so widgets show counts only unless you choose otherwise here.';

  @override
  String get widgetsPrivacyNote =>
      'Widget data is written on this device only, encrypted, never for a widget you have not added, and erased with “Delete all data”.';

  @override
  String get widgetsBudgetPeriod => 'Budget period';

  @override
  String get widgetsPeriodMonth => 'This month';

  @override
  String get widgetsPeriodWeek => 'This week';

  @override
  String get savedGamesTitle => 'Saved games';

  @override
  String get savedGamesShelfTitle => 'My saved games';

  @override
  String get savedGamesShelfSubtitle =>
      'Web games that run from their own links';

  @override
  String get savedGamesSeeAll => 'See all';

  @override
  String get savedGamesAdd => 'Add a game';

  @override
  String get savedGamesAddTitle => 'New game from a link';

  @override
  String get savedGamesAddSubtitle =>
      'It runs from its original link; none of its code is copied';

  @override
  String get savedGamesEditTitle => 'Edit game';

  @override
  String get savedGamesUrlLabel => 'Link';

  @override
  String get savedGamesUrlHint => 'https://claude.ai/public/artifacts/…';

  @override
  String get savedGamesPaste => 'Paste';

  @override
  String get savedGamesClipboardEmpty => 'There\'s no link on the clipboard';

  @override
  String get savedGamesUrlEmpty => 'Paste the game\'s link first';

  @override
  String get savedGamesUrlNotHttps => 'Only secure (https) links are supported';

  @override
  String get savedGamesUseHttps => 'Use https';

  @override
  String get savedGamesUrlScheme => 'That isn\'t a web page link';

  @override
  String get savedGamesUrlMalformed => 'That doesn\'t look like a valid link';

  @override
  String get savedGamesUrlCredentials =>
      'Links containing a user name or password aren\'t allowed';

  @override
  String get savedGamesUrlTooLong => 'That link is too long';

  @override
  String savedGamesUrlDuplicate(String title) {
    return 'Already saved as “$title”';
  }

  @override
  String get savedGamesArtifactBadge => 'Claude artifact';

  @override
  String get savedGamesSecureBadge => 'Secure link';

  @override
  String get savedGamesNameLabel => 'Name';

  @override
  String get savedGamesNameHint => 'Game name';

  @override
  String get savedGamesFetchTitle => 'Fetch title';

  @override
  String get savedGamesFetchFailed =>
      'Couldn\'t read the page title – type one instead';

  @override
  String get savedGamesFetchNote =>
      '“Fetch” contacts the site once, only when you tap it, and sends nothing about you.';

  @override
  String get savedGamesIconLabel => 'Icon';

  @override
  String get savedGamesUseSiteIcon => 'Site icon';

  @override
  String get savedGamesRemoveSiteIcon => 'Remove site icon';

  @override
  String get savedGamesIconFailed => 'No usable icon was found for this site';

  @override
  String get savedGamesShuffleIcon => 'Shuffle';

  @override
  String savedGamesGlyph(String number) {
    return 'Symbol $number';
  }

  @override
  String savedGamesColor(String number) {
    return 'Colour $number';
  }

  @override
  String get savedGamesOrientationLabel => 'Screen orientation while playing';

  @override
  String get savedGamesOrientationAuto => 'Auto';

  @override
  String get savedGamesOrientationPortrait => 'Portrait';

  @override
  String get savedGamesOrientationLandscape => 'Landscape';

  @override
  String get savedGamesNotesLabel => 'Notes';

  @override
  String get savedGamesNotesHint => 'e.g. how to play, or who shared it';

  @override
  String get savedGamesSave => 'Save';

  @override
  String get savedGamesCancel => 'Cancel';

  @override
  String savedGamesAdded(String title) {
    return 'Added “$title”';
  }

  @override
  String get savedGamesUpdated => 'Changes saved';

  @override
  String savedGamesDeleted(String title) {
    return 'Deleted “$title”';
  }

  @override
  String savedGamesFull(String max) {
    return 'You\'ve reached the limit of $max games – delete one first';
  }

  @override
  String savedGamesPlayGame(String title) {
    return 'Play $title';
  }

  @override
  String savedGamesPlayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Played $count times',
      one: 'Played once',
      zero: 'Not played yet',
    );
    return '$_temp0';
  }

  @override
  String get savedGamesLastPlayedToday => 'Last played today';

  @override
  String get savedGamesLastPlayedYesterday => 'Last played yesterday';

  @override
  String savedGamesLastPlayedDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Last played $days days ago',
      one: 'Last played $days day ago',
    );
    return '$_temp0';
  }

  @override
  String savedGamesLastPlayedOn(String date) {
    return 'Last played $date';
  }

  @override
  String get savedGamesNew => 'New';

  @override
  String get savedGamesLayoutGrid => 'Poster view';

  @override
  String get savedGamesLayoutList => 'List view & reorder';

  @override
  String get savedGamesReorderHint => 'Drag a handle to reorder';

  @override
  String get savedGamesEmptyTitle => 'Bring the web games you love';

  @override
  String get savedGamesEmptyBody =>
      'Save any browser game by its secure link and play it full-screen inside Madar.';

  @override
  String get savedGamesEmptyStep1 =>
      'Open the game – for example an interactive artifact someone shared from Claude.';

  @override
  String savedGamesEmptyStep2(String example) {
    return 'Copy its link – it usually looks like $example';
  }

  @override
  String get savedGamesEmptyStep3 =>
      'Tap “Add a game”, paste the link, then give it a name and an icon.';

  @override
  String get savedGamesPrivacyNote =>
      'Each game runs from its original link; its code is never copied. Madar only goes online when you open a game or tap “Fetch”.';

  @override
  String get savedGamesOpenExternal => 'Open in browser';

  @override
  String get savedGamesEdit => 'Edit';

  @override
  String get savedGamesClearData => 'Clear site data';

  @override
  String savedGamesClearDataTitle(String title) {
    return 'Clear “$title” data?';
  }

  @override
  String get savedGamesClearDataBody =>
      'Removes what the game\'s site stored on this device – progress, settings and cookies the page can see – for every game from that site. Content it embeds from other sites is removed by “Clear data of all games”. This can\'t be undone.';

  @override
  String get savedGamesClearDataScheduled =>
      'Its data will be cleared the next time it opens';

  @override
  String get savedGamesClearDataPending => 'Data will be cleared on open';

  @override
  String get savedGamesClearAll => 'Clear data of all games';

  @override
  String get savedGamesClearAllTitle => 'Clear the data of all games?';

  @override
  String get savedGamesClearAllBody =>
      'Deletes the cookies, storage and cache of every web game. The rest of Madar\'s data and your list of games stay untouched.';

  @override
  String get savedGamesClearAllDone => 'All game data cleared';

  @override
  String get savedGamesClearFailed => 'Some data couldn\'t be cleared';

  @override
  String get savedGamesConfirmClear => 'Clear';

  @override
  String savedGamesLoading(String title) {
    return 'Loading “$title”…';
  }

  @override
  String get savedGamesClearing => 'Clearing the game\'s data…';

  @override
  String get savedGamesOfflineTitle => 'You\'re offline';

  @override
  String get savedGamesOfflineBody =>
      'This game needs the internet because it runs from its original link.';

  @override
  String get savedGamesErrorTitle => 'Couldn\'t open the game';

  @override
  String get savedGamesErrorBody =>
      'The site may be down, or its link may have changed.';

  @override
  String get savedGamesInsecureTitle => 'Connection not secure';

  @override
  String get savedGamesInsecureBody =>
      'The site\'s security certificate isn\'t valid, so Madar stopped the connection to protect you.';

  @override
  String get savedGamesCrashedTitle => 'The game stopped';

  @override
  String get savedGamesCrashedBody =>
      'The game\'s page crashed or was closed to free memory. Try again to load it afresh.';

  @override
  String get savedGamesRetry => 'Try again';

  @override
  String get savedGamesBackToMadar => 'Back to Madar';

  @override
  String get savedGamesReload => 'Reload';

  @override
  String get savedGamesMute => 'Mute';

  @override
  String get savedGamesUnmute => 'Unmute';

  @override
  String get savedGamesControls => 'Game controls';

  @override
  String get savedGamesCloseControls => 'Hide controls';

  @override
  String get savedGamesMuteSealed =>
      'Some of this game\'s sound plays inside a protected frame – use your phone\'s volume buttons.';

  @override
  String get savedGamesExitTitle => 'Leave the game?';

  @override
  String get savedGamesExitBody =>
      'Any progress the game doesn\'t save itself may be lost.';

  @override
  String get savedGamesExitStay => 'Keep playing';

  @override
  String get savedGamesExitLeave => 'Leave';

  @override
  String get savedGamesExternalTitle => 'Open an outside link?';

  @override
  String savedGamesExternalBody(String host) {
    return 'The game wants to open $host. It will open in your browser, outside Madar.';
  }

  @override
  String get savedGamesExternalFailed => 'No browser could open the link';

  @override
  String get savedGamesPrayerTitle => 'Time for prayer';

  @override
  String get savedGamesPrayerBody =>
      'The game and its sound are paused. It resumes by itself after the adhan and prayer time.';

  @override
  String get savedGamesPrayerUnloaded =>
      'The game was stopped so none of its sound can play; it will reload after prayer.';

  @override
  String savedGamesPageSays(String host) {
    return '$host says';
  }

  @override
  String get savedGamesOk => 'OK';

  @override
  String savedGamesStats(String added, String played) {
    return '$added · $played';
  }

  @override
  String savedGamesAddedOn(String date) {
    return 'Added $date';
  }

  @override
  String get savedGamesAddCardHint => 'Paste a web game link';

  @override
  String get savedGamesShelfEmpty =>
      'Save a web game by its link and it will appear here.';

  @override
  String get savedGamesOpenAll => 'Open saved games';

  @override
  String get savedGamesClearDataDone => 'Game data cleared';

  @override
  String get togetherNetOnThisPhone => 'On this phone';

  @override
  String get togetherNetOnThisPhoneHint =>
      'Pick who this phone belongs to — it\'s remembered';

  @override
  String togetherNetThisIsMe(String name) {
    return 'This phone is $name\'s';
  }

  @override
  String get togetherNetNearbyIntro =>
      'Open the same game on both phones, then tap “Play together” on each. Just Bluetooth and Wi-Fi Direct — no internet, no servers.';

  @override
  String get togetherNetPlayTogether => 'Play together';

  @override
  String get togetherNetSearching => 'Looking for the other phone…';

  @override
  String get togetherNetSearchingHint =>
      'Not showing up? Make sure both phones have the same game open, with Bluetooth and Wi-Fi on.';

  @override
  String get togetherNetPaused => 'Search paused until you\'re back in Madar';

  @override
  String get togetherNetPickPhone =>
      'More than one phone found — pick the other one';

  @override
  String get togetherNetConnect => 'Connect';

  @override
  String togetherNetConnecting(String name) {
    return 'Connecting to $name…';
  }

  @override
  String get togetherNetConfirmTitle => 'Same number on both phones?';

  @override
  String togetherNetConfirmBody(String name) {
    return 'Check that $name\'s phone shows these same four digits.';
  }

  @override
  String togetherNetDigits(String digits) {
    return 'Check code $digits';
  }

  @override
  String get togetherNetMatch => 'They match';

  @override
  String get togetherNetNoMatch => 'They don\'t match';

  @override
  String togetherNetWaitingFor(String name) {
    return 'Waiting for $name to confirm…';
  }

  @override
  String togetherNetConnected(String name) {
    return 'Connected — $name is on the other phone';
  }

  @override
  String togetherNetReconnecting(String name) {
    return 'Connection lost — looking for $name…';
  }

  @override
  String togetherNetLost(String name) {
    return 'Couldn\'t find $name';
  }

  @override
  String get togetherNetLostHint =>
      'Bring the phones closer and make sure Madar is open on both.';

  @override
  String get togetherNetSearchAgain => 'Search again';

  @override
  String get togetherNetTryAgain => 'Try again';

  @override
  String get togetherNetCancel => 'Cancel';

  @override
  String get togetherNetPermTitle => 'Allow finding nearby devices';

  @override
  String get togetherNetPermNearbyBody =>
      'To find the other phone without the internet, Madar needs the “Nearby devices” permission: Bluetooth and Wi-Fi Direct.';

  @override
  String get togetherNetPermLocationBody =>
      'On this Android version, the system ties Bluetooth and Wi-Fi searches to the location permission. Madar never reads your location.';

  @override
  String get togetherNetPermPointPairing =>
      'Used only while pairing and playing';

  @override
  String get togetherNetPermPointGameOnly => 'Only game state leaves the phone';

  @override
  String get togetherNetPermPointStops =>
      'Searching stops once paired, or when you leave the app';

  @override
  String get togetherNetContinue => 'Continue';

  @override
  String get togetherNetNotNow => 'Not now';

  @override
  String get togetherNetPermDenied =>
      'Madar can\'t search without this permission';

  @override
  String get togetherNetPermDeniedForever =>
      'The permission was refused. Turn it on in App settings › Permissions.';

  @override
  String get togetherNetOpenSettings => 'Open settings';

  @override
  String get togetherNetLocationOff => 'Location services are off';

  @override
  String get togetherNetLocationOffBody =>
      'On this Android version, finding devices needs them on. Madar doesn\'t read your location.';

  @override
  String get togetherNetSearchAnyway => 'Search anyway';

  @override
  String get togetherNetFailRadio =>
      'Turn on Bluetooth and Wi-Fi, then try again';

  @override
  String get togetherNetFailDeclined => 'The other phone declined';

  @override
  String get togetherNetFailNotFound => 'No open room with this code';

  @override
  String get togetherNetFailExpired =>
      'This code has expired — create a new one';

  @override
  String get togetherNetFailTaken =>
      'Another phone already joined with this code';

  @override
  String get togetherNetFailDifferentGame => 'This code is for another game';

  @override
  String get togetherNetFailNetwork => 'No internet connection';

  @override
  String get togetherNetFailSetup =>
      'Firebase refused the project settings — check them in Online play';

  @override
  String get togetherNetFailSignIn =>
      'Anonymous sign-in failed — enable it in your Firebase project';

  @override
  String get togetherNetFailRules =>
      'The database refused access — paste the security rules';

  @override
  String get togetherNetFailRulesOpen =>
      'The database is open to everyone — paste the security rules before playing';

  @override
  String get togetherNetFailPeerLeft => 'The other player left';

  @override
  String get togetherNetFailUnknown => 'Something went wrong';

  @override
  String get togetherNetCreateCode => 'Create a code';

  @override
  String get togetherNetEnterCode => 'Enter a code';

  @override
  String get togetherNetOnlineIntro =>
      'One of you creates a code, the other types it on their phone. Only game state is kept in your own Firebase project, and it\'s deleted when you leave.';

  @override
  String get togetherNetYourCode => 'Room code';

  @override
  String get togetherNetCodeHint =>
      'Type this code on the other phone under “Enter a code”';

  @override
  String togetherNetCodeValid(String time) {
    return 'Valid until $time';
  }

  @override
  String get togetherNetCopyCode => 'Copy code';

  @override
  String get togetherNetCopied => 'Copied';

  @override
  String get togetherNetWaitingJoin => 'Waiting for the other phone to join…';

  @override
  String togetherNetJoinRequest(String name) {
    return '$name wants to join';
  }

  @override
  String get togetherNetJoinRequestBody =>
      'Is this really the other player? If not, decline and we\'ll make a new code.';

  @override
  String get togetherNetAccept => 'Play';

  @override
  String get togetherNetDecline => 'Decline';

  @override
  String get togetherNetCodeField => 'Code (6 digits)';

  @override
  String get togetherNetJoin => 'Join';

  @override
  String get togetherNetJoining => 'Checking the code…';

  @override
  String togetherNetWaitingAccept(String name) {
    return 'Waiting for $name to accept…';
  }

  @override
  String get togetherNetSigningIn => 'Connecting to your project…';

  @override
  String get togetherNetNeedsSetup => 'Online play is off';

  @override
  String get togetherNetNeedsSetupBody =>
      'It runs on your own free Firebase project and stays off until you turn it on.';

  @override
  String get togetherNetSetUp => 'Set up online play';

  @override
  String togetherNetQrLabel(String code) {
    return 'QR code of room $code';
  }

  @override
  String get togetherNetOnlineIntroSheet =>
      'To play from different places, Madar uses your own free Firebase project — Madar has no server. It only ever holds game state, plus a display name, avatar and colour, for a few hours; then it\'s deleted.';

  @override
  String get togetherNetEnable => 'Online play';

  @override
  String get togetherNetEnableHint =>
      'Off by default. Needs valid project settings.';

  @override
  String get togetherNetEnableNeedsConfig => 'Save the project settings first';

  @override
  String get togetherNetStepsTitle => 'One-time setup';

  @override
  String get togetherNetStep1 =>
      'Create a free project at console.firebase.google.com';

  @override
  String get togetherNetStep2 =>
      'Add an Android app with the package name app.madar.orbit';

  @override
  String get togetherNetStep3 =>
      'Enable anonymous sign-in: Authentication › Sign-in method › Anonymous';

  @override
  String get togetherNetStep4 =>
      'Create a Realtime Database and paste the security rules into its Rules tab';

  @override
  String get togetherNetStep5 =>
      'Copy the values into the fields here, or paste the whole google-services.json';

  @override
  String get togetherNetCopyRules => 'Copy security rules';

  @override
  String get togetherNetRulesCopied => 'Security rules copied';

  @override
  String get togetherNetPasteConfig => 'Paste from clipboard';

  @override
  String get togetherNetPasteNothing => 'No settings on the clipboard';

  @override
  String get togetherNetPasted => 'Fields filled from the clipboard';

  @override
  String get togetherNetFieldApiKey => 'API key';

  @override
  String get togetherNetFieldAppId => 'App ID';

  @override
  String get togetherNetFieldProjectId => 'Project ID';

  @override
  String get togetherNetFieldDatabaseUrl => 'Database URL';

  @override
  String get togetherNetFieldSenderId => 'Sender ID';

  @override
  String get togetherNetErrMissing => 'Required';

  @override
  String get togetherNetErrFormat => 'Not in the expected format';

  @override
  String get togetherNetErrMismatch =>
      'Doesn\'t match the project number in the App ID';

  @override
  String get togetherNetSave => 'Save';

  @override
  String get togetherNetSaved => 'Settings saved';

  @override
  String get togetherNetTest => 'Test connection';

  @override
  String get togetherNetTesting => 'Testing…';

  @override
  String get togetherNetTestOk =>
      'It works! Anonymous sign-in and the rules are ready';

  @override
  String get togetherNetRemove => 'Remove settings';

  @override
  String get togetherNetRemoved => 'Project settings removed';

  @override
  String get togetherNetStoredSecurely =>
      'Kept only in this phone\'s secure storage and sent nowhere but your own project.';

  @override
  String get togetherNetOnlineOn => 'On';

  @override
  String get togetherNetOnlineOff => 'Off';

  @override
  String get togetherNetOnlineNotSetUp => 'Not set up';

  @override
  String get togetherNetTurnGroup => 'Together';

  @override
  String get togetherNetTurnChannel => 'Your turn';

  @override
  String get togetherNetTurnChannelBody =>
      'When the other player moves from another phone';

  @override
  String togetherNetTurnTitle(String game) {
    return 'Your turn in $game';
  }

  @override
  String togetherNetTurnBody(String name) {
    return '$name played — it\'s your move';
  }
}
