// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class L10nAr extends L10n {
  L10nAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'مَدار';

  @override
  String get appTagline => 'حياتك تدور حول الصلاة';

  @override
  String get actionSave => 'حفظ';

  @override
  String get actionCancel => 'إلغاء';

  @override
  String get actionAdd => 'إضافة';

  @override
  String get actionEdit => 'تعديل';

  @override
  String get actionDuplicate => 'تكرار';

  @override
  String get actionMove => 'نقل';

  @override
  String get actionSetReminder => 'تذكير';

  @override
  String get actionDelete => 'حذف';

  @override
  String get actionUndo => 'تراجع';

  @override
  String get actionDone => 'تم';

  @override
  String get actionClose => 'إغلاق';

  @override
  String get actionBack => 'رجوع';

  @override
  String get actionContinue => 'متابعة';

  @override
  String get actionComplete => 'إنجاز';

  @override
  String get actionSearch => 'بحث';

  @override
  String get itemDeleted => 'تم الحذف';

  @override
  String get itemDuplicated => 'تم التكرار';

  @override
  String get itemMoved => 'تم النقل';

  @override
  String get itemSaved => 'تم الحفظ';

  @override
  String get fieldRequired => 'هذا الحقل مطلوب';

  @override
  String get fieldInvalidNumber => 'أدخل رقمًا صحيحًا';

  @override
  String get windowFajr => 'بعد الفجر';

  @override
  String get windowDuha => 'الضحى';

  @override
  String get windowDhuhr => 'الظهر ← العصر';

  @override
  String get windowAsr => 'العصر ← المغرب';

  @override
  String get windowMaghrib => 'المغرب ← العشاء';

  @override
  String get windowIsha => 'بعد العشاء';

  @override
  String get windowAnytime => 'أي وقت';

  @override
  String get prayerFajr => 'الفجر';

  @override
  String get prayerSunrise => 'الشروق';

  @override
  String get prayerDhuhr => 'الظهر';

  @override
  String get prayerAsr => 'العصر';

  @override
  String get prayerMaghrib => 'المغرب';

  @override
  String get prayerIsha => 'العشاء';

  @override
  String get planetFaith => 'الإيمان';

  @override
  String get planetHealth => 'الصحة';

  @override
  String get planetFamily => 'العائلة';

  @override
  String get planetWork => 'العمل';

  @override
  String get planetMoney => 'المال';

  @override
  String get planetGrowth => 'النمو';

  @override
  String get planetBody => 'الجسد';

  @override
  String get planetTravel => 'السفر';

  @override
  String itemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عنصر',
      many: '$count عنصرًا',
      few: '$count عناصر',
      two: 'عنصران',
      one: 'عنصر واحد',
      zero: 'لا عناصر',
    );
    return '$_temp0';
  }

  @override
  String get designLoading => 'جارٍ التحميل';

  @override
  String get designEmptyListTitle => 'لا شيء هنا بعد';

  @override
  String get designEmptyListBody => 'أضف أول عنصر، ودَعْ مداره يبدأ بالدوران.';

  @override
  String get designNoDataTitle => 'لا بيانات بعد';

  @override
  String get designNoDataBody => 'ستظهر الرسوم هنا حين تتجمّع لديك بضعة أيام.';

  @override
  String get designNoResultsTitle => 'لا نتائج';

  @override
  String get designNoResultsBody => 'جرّب كلمة أخرى، أو وسّع نطاق البحث.';

  @override
  String get designGalleryTitle => 'معرض التصميم';

  @override
  String get designGallerySubtitle => 'مكوّنات مَدار كلّها في مكان واحد';

  @override
  String get designGalleryTheme => 'السِّمة';

  @override
  String get designGalleryDirection => 'اتجاه الكتابة';

  @override
  String get designDirectionRtl => 'من اليمين';

  @override
  String get designDirectionLtr => 'من اليسار';

  @override
  String get designThemeLapis => 'لازَوَرد';

  @override
  String get designThemeEmerald => 'زُمُرُّد';

  @override
  String get designThemeDesert => 'صحراء';

  @override
  String get designThemeAurora => 'شَفَق';

  @override
  String get designThemePearl => 'لؤلؤ';

  @override
  String get designSectionSurfaces => 'الأسطح الزجاجية';

  @override
  String get designSectionButtons => 'الأزرار';

  @override
  String get designSectionChips => 'الاختيارات';

  @override
  String get designSectionToggles => 'المفاتيح';

  @override
  String get designSectionProgress => 'التقدّم';

  @override
  String get designSectionStats => 'الإحصاءات';

  @override
  String get designSectionOrnaments => 'الزخارف';

  @override
  String get designSectionLoaders => 'الانتظار';

  @override
  String get designSectionEmpty => 'الحالات الفارغة';

  @override
  String get designSectionType => 'الخطوط والألوان';

  @override
  String get designSeeAll => 'عرض الكل';

  @override
  String get designPanelTitle => 'لوحة زجاجية';

  @override
  String get designPanelBody =>
      'ضبابية حقيقية فوق الكون الحيّ، بإطار ذهبي رفيع ولمعة تنساب على مهل.';

  @override
  String get designCardBody =>
      'زجاج مُحاكى للقوائم الطويلة: بلا ضبابية، وبالأناقة نفسها.';

  @override
  String get designButtonPrimary => 'ابدأ يومك';

  @override
  String get designButtonSecondary => 'لاحقًا';

  @override
  String get designButtonGhost => 'التفاصيل';

  @override
  String get designChipsSingle => 'اختيار واحد';

  @override
  String get designChipsMulti => 'اختيارات متعددة';

  @override
  String get designToggleSound => 'أصوات الواجهة';

  @override
  String get designToggleHaptics => 'الاهتزاز اللمسي';

  @override
  String get designToggleReduceMotion => 'تقليل الحركة';

  @override
  String get designRingDaily => 'هدف اليوم';

  @override
  String get designRingPrayers => 'الصلوات';

  @override
  String get designRingDone => 'اكتمل';

  @override
  String get designStatStreak => 'سلسلة الصلاة';

  @override
  String get designStatSteps => 'الخطوات';

  @override
  String get designStatWater => 'الماء';

  @override
  String get designStatFocus => 'التركيز';

  @override
  String get designStatVsLastWeek => 'مقارنةً بالأسبوع الماضي';

  @override
  String designUnitDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'يوم',
      many: 'يومًا',
      few: 'أيام',
      two: 'يومان',
      one: 'يوم',
      zero: 'يوم',
    );
    return '$_temp0';
  }

  @override
  String get designUnitLitres => 'لتر';

  @override
  String get designUnitHours => 'ساعة';

  @override
  String get designOrnamentStar => 'نجمة ثُمانية';

  @override
  String get designOrnamentStar12 => 'نجمة اثنا عشرية';

  @override
  String get designOrnamentRub => 'ربع الحزب';

  @override
  String get designOrnamentRosette => 'وردة هندسية متشابكة';

  @override
  String get designOrnamentAstrolabe => 'حلقة الأسطرلاب';

  @override
  String get designOrnamentArabesque => 'إفريز الأرابيسك';

  @override
  String get designTypeSample =>
      'يتنفّس الخطّ العربي هنا براحة: سطور رحبة، وتشكيل واضح، وأرقام منتظمة.';

  @override
  String get dbCurrencyJod => 'دينار أردني';

  @override
  String get dbCurrencyUsd => 'دولار أمريكي';

  @override
  String get dbCurrencySyp => 'ليرة سورية';

  @override
  String get dbCurrencyEgp => 'جنيه مصري';

  @override
  String get dbCurrencyLyd => 'دينار ليبي';

  @override
  String get dbSeedPainHead => 'الرأس';

  @override
  String get dbSeedPainNeck => 'الرقبة';

  @override
  String get dbSeedPainShoulders => 'الكتفان';

  @override
  String get dbSeedPainUpperBack => 'أعلى الظهر';

  @override
  String get dbSeedPainLowerBack => 'أسفل الظهر';

  @override
  String get dbSeedPainChest => 'الصدر';

  @override
  String get dbSeedPainAbdomen => 'البطن';

  @override
  String get dbSeedPainArms => 'الذراعان';

  @override
  String get dbSeedPainHands => 'اليدان والأصابع';

  @override
  String get dbSeedPainHips => 'الوركان';

  @override
  String get dbSeedPainKnees => 'الركبتان';

  @override
  String get dbSeedPainFeet => 'القدمان والكاحلان';

  @override
  String get dbSeedPainJoints => 'المفاصل عمومًا';

  @override
  String get dbSeedTriggerSleep => 'قلّة النوم';

  @override
  String get dbSeedTriggerStress => 'التوتر والضغط';

  @override
  String get dbSeedTriggerSitting => 'الجلوس الطويل';

  @override
  String get dbSeedTriggerStanding => 'الوقوف الطويل';

  @override
  String get dbSeedTriggerExertion => 'مجهود بدني زائد';

  @override
  String get dbSeedTriggerCold => 'البرد';

  @override
  String get dbSeedTriggerWeather => 'تقلّب الطقس';

  @override
  String get dbSeedTriggerFood => 'طعام بعينه';

  @override
  String get dbSeedTriggerWater => 'قلّة شرب الماء';

  @override
  String get dbSeedTriggerMissedDose => 'نسيان جرعة الدواء';

  @override
  String get dbSeedTriggerScreens => 'طول النظر إلى الشاشات';

  @override
  String get dbSeedMoodSleep => 'النوم';

  @override
  String get dbSeedMoodPrayer => 'الصلاة والذكر';

  @override
  String get dbSeedMoodFamily => 'العائلة';

  @override
  String get dbSeedMoodWork => 'العمل';

  @override
  String get dbSeedMoodMoney => 'المال';

  @override
  String get dbSeedMoodHealth => 'الصحة';

  @override
  String get dbSeedMoodExercise => 'الحركة والرياضة';

  @override
  String get dbSeedMoodFriends => 'الأصدقاء';

  @override
  String get dbSeedMoodCaffeine => 'الكافيين';

  @override
  String get dbSeedMoodWeather => 'الطقس';

  @override
  String get dbSeedMoodNews => 'الأخبار';

  @override
  String get dbSeedMoodLoneliness => 'الوحدة';

  @override
  String get dbSeedHabitBreathing => 'خمس دقائق من التنفّس العميق';

  @override
  String get dbSeedHabitWalk => 'مشيٌ هادئ في الهواء الطلق';

  @override
  String get dbSeedHabitAdhkar => 'أذكار الصباح والمساء';

  @override
  String get dbSeedHabitGratitude => 'ثلاث نِعَم أحمد الله عليها اليوم';

  @override
  String get dbSeedHabitScreens => 'ساعة بلا شاشات قبل النوم';

  @override
  String get dbSeedHabitSleep => 'النوم في وقت مبكر';

  @override
  String get dbSeedHabitWater => 'شرب الماء على مدار اليوم';

  @override
  String get dbSeedHabitCaffeine => 'لا كافيين بعد العصر';

  @override
  String get dbSeedHabitStretch => 'تمارين إطالة خفيفة';

  @override
  String get dbSeedHabitJournal => 'تدوين ما يشغل البال';

  @override
  String get dbSeedHabitConnect => 'التواصل مع شخص عزيز';

  @override
  String get dbErrorCipherUnavailable =>
      'تعذّر تفعيل تشفير البيانات على هذا الجهاز، ولن يحفظ مَدار بياناتك دون تشفير.';

  @override
  String get dbErrorWrongKey =>
      'تعذّر فتح بياناتك: مفتاح التشفير لا يطابق الملف، أو أن الملف تالف.';

  @override
  String get dbErrorKeyMissing =>
      'مفتاح التشفير غير موجود في المخزن الآمن، لذلك لا يمكن فتح البيانات المحفوظة.';

  @override
  String get dbErrorKeyMalformed => 'مفتاح التشفير المحفوظ تالف.';

  @override
  String get dbErrorKeyStorage => 'تعذّر الوصول إلى المخزن الآمن في الجهاز.';

  @override
  String get dbErrorSnapshotInvalid =>
      'هذا الملف ليس نسخة احتياطية صالحة من مَدار.';

  @override
  String get dbErrorSnapshotNewer =>
      'هذه النسخة الاحتياطية من إصدار أحدث من مَدار. حدّث التطبيق ثم أعد المحاولة.';

  @override
  String get dbErrorSnapshotRejected =>
      'تعذّرت استعادة النسخة الاحتياطية، وبقيت بياناتك الحالية كما هي.';

  @override
  String get dbErrorUnknown => 'حدث خطأ غير متوقّع في حفظ البيانات.';

  @override
  String get soundProfileLapis => 'أجراسٌ بلّورية';

  @override
  String get soundProfileEmerald => 'خشبٌ دافئ';

  @override
  String get soundProfileDesert => 'عودٌ ودفّ';

  @override
  String get soundProfileAurora => 'وميض الشفق';

  @override
  String get soundProfilePearl => 'رنين اللؤلؤ';

  @override
  String get soundProfileLapisDescription =>
      'أجراسٌ زجاجية صافية على مقام الراست';

  @override
  String get soundProfileEmeraldDescription =>
      'كاليمبا وخشبٌ دافئ على مقام البياتي';

  @override
  String get soundProfileDesertDescription =>
      'نقراتُ عودٍ ودفٌّ هادئ على مقام الحجاز';

  @override
  String get soundProfileAuroraDescription =>
      'بريقٌ سماويّ هادئ على مقام العجم';

  @override
  String get soundProfilePearlDescription =>
      'رنينٌ بلّوريّ رقيق على مقام النهاوند';

  @override
  String get soundCategoryUi => 'أصوات الواجهة';

  @override
  String get soundCategoryAmbient => 'أجواء الفضاء';

  @override
  String get soundCategoryGames => 'الألعاب';

  @override
  String get soundCategoryPrayer => 'الأذان والصلاة';

  @override
  String get soundPrayerMuteNote =>
      'تهدأ الأجواء والألعاب وقت الأذان والصلاة، وتبقى أصوات الواجهة الخافتة.';

  @override
  String get soundPreview => 'استمع';

  @override
  String get soundUnavailable => 'الصوت غير متاح على هذا الجهاز';

  @override
  String get interactionMenuLabel => 'خيارات العنصر';

  @override
  String get interactionMenuDismiss => 'إغلاق القائمة';

  @override
  String get interactionQuickActions => 'إجراءات سريعة';

  @override
  String get interactionSwipeToComplete => 'اسحب نحو اليمين للإنجاز';

  @override
  String get interactionReorderHandle => 'اسحب لإعادة الترتيب';

  @override
  String interactionUndoAvailable(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'يمكنك التراجع خلال $seconds ثانية',
      many: 'يمكنك التراجع خلال $seconds ثانية',
      few: 'يمكنك التراجع خلال $seconds ثوانٍ',
      two: 'يمكنك التراجع خلال ثانيتين',
      one: 'يمكنك التراجع خلال ثانية واحدة',
      zero: 'انتهت مهلة التراجع',
    );
    return '$_temp0';
  }

  @override
  String get interactionUndone => 'تمّ التراجع';

  @override
  String get interactionSheetGrabber => 'اسحب للأسفل للإغلاق';

  @override
  String get interactionDiscardTitle => 'تجاهُل التعديلات؟';

  @override
  String get interactionDiscardBody => 'لم تُحفَظ تعديلاتك بعد.';

  @override
  String get interactionDiscardConfirm => 'تجاهُل';

  @override
  String get interactionKeepEditing => 'متابعة التعديل';

  @override
  String get interactionSaveDisabledHint => 'أكمل الحقول المطلوبة أولًا';

  @override
  String get interactionFieldOptional => 'اختياري';

  @override
  String interactionFieldMin(String min) {
    return 'لا يقلّ عن $min';
  }

  @override
  String interactionFieldMax(String max) {
    return 'لا يزيد على $max';
  }

  @override
  String interactionFieldDecimals(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count منزلة عشرية كحدّ أقصى',
      many: '$count منزلة عشرية كحدّ أقصى',
      few: '$count منازل عشرية كحدّ أقصى',
      two: 'منزلتان عشريتان كحدّ أقصى',
      one: 'منزلة عشرية واحدة كحدّ أقصى',
      zero: 'أدخل عددًا صحيحًا دون كسور',
    );
    return '$_temp0';
  }

  @override
  String interactionFieldTooLong(int max) {
    return 'النص أطول من $max حرفًا';
  }

  @override
  String interactionFieldSelectAtLeast(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'اختر $count خيار على الأقل',
      many: 'اختر $count خيارًا على الأقل',
      few: 'اختر $count خيارات على الأقل',
      two: 'اختر خيارين على الأقل',
      one: 'اختر خيارًا واحدًا على الأقل',
    );
    return '$_temp0';
  }

  @override
  String interactionFieldSelectAtMost(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count خيار على الأكثر',
      many: '$count خيارًا على الأكثر',
      few: '$count خيارات على الأكثر',
      two: 'خياران على الأكثر',
      one: 'اختر خيارًا واحدًا فقط',
    );
    return '$_temp0';
  }

  @override
  String get interactionFieldDateRange => 'التاريخ خارج النطاق المسموح';

  @override
  String get interactionFieldPickDate => 'اختر تاريخًا';

  @override
  String get interactionFieldPickTime => 'اختر وقتًا';

  @override
  String get interactionFieldClear => 'مسح';

  @override
  String get interactionFieldAddTime => 'إضافة وقت';

  @override
  String get interactionFieldTimeExists => 'هذا الوقت مضاف مسبقًا';

  @override
  String get interactionFieldAddOption => 'خيار جديد';

  @override
  String get interactionFieldAddOptionHint => 'اكتب الخيار ثم اضغط إضافة';

  @override
  String interactionFieldRemove(String label) {
    return 'إزالة $label';
  }

  @override
  String interactionFieldRating(int count, int max) {
    return '$count من $max';
  }

  @override
  String get interactionFieldIncrease => 'زيادة';

  @override
  String get interactionFieldDecrease => 'إنقاص';

  @override
  String interactionFieldColor(int index) {
    return 'لون $index';
  }

  @override
  String get interactionFieldAmount => 'المبلغ';

  @override
  String get interactionFieldCurrency => 'العملة';

  @override
  String get interactionTimeHour => 'الساعة';

  @override
  String get interactionTimeMinute => 'الدقيقة';

  @override
  String get interactionDateToday => 'اليوم';

  @override
  String get interactionDateTomorrow => 'غدًا';

  @override
  String get interactionDateDayAfter => 'بعد غد';

  @override
  String get interactionDateYesterday => 'أمس';

  @override
  String get interactionCurrencyJOD => 'دينار أردني';

  @override
  String get interactionCurrencyUSD => 'دولار أمريكي';

  @override
  String get interactionCurrencySYP => 'ليرة سورية';

  @override
  String get interactionCurrencyEGP => 'جنيه مصري';

  @override
  String get interactionCurrencyLYD => 'دينار ليبي';

  @override
  String get interactionCurrencySymbolJOD => 'د.أ';

  @override
  String get interactionCurrencySymbolUSD => '\$';

  @override
  String get interactionCurrencySymbolSYP => 'ل.س';

  @override
  String get interactionCurrencySymbolEGP => 'ج.م';

  @override
  String get interactionCurrencySymbolLYD => 'د.ل';

  @override
  String get interactionMoveSearch => 'ابحث عن وجهة';

  @override
  String get interactionMoveCurrent => 'الحالي';

  @override
  String get interactionMoveEmpty => 'لا وجهة تطابق بحثك';

  @override
  String get interactionReminderTitle => 'متى أذكّرك؟';

  @override
  String get interactionReminderKindOnce => 'مرة واحدة';

  @override
  String get interactionReminderKindDaily => 'يوميًا';

  @override
  String get interactionReminderKindWeekly => 'أسبوعيًا';

  @override
  String get interactionReminderKindPrayer => 'مع الصلاة';

  @override
  String get interactionReminderKindBeforeDue => 'قبل الموعد';

  @override
  String get interactionReminderDate => 'اليوم';

  @override
  String get interactionReminderTime => 'الوقت';

  @override
  String get interactionReminderDays => 'الأيام';

  @override
  String get interactionReminderPrayer => 'الصلاة';

  @override
  String get interactionReminderOffset => 'التوقيت حول الصلاة';

  @override
  String get interactionReminderLead => 'قبل الموعد بـ';

  @override
  String get interactionReminderPast => 'هذا الوقت مضى، اختر وقتًا قادمًا';

  @override
  String get interactionReminderNoDays => 'اختر يومًا واحدًا على الأقل';

  @override
  String interactionReminderPrayerAt(String prayer) {
    return 'عند $prayer';
  }

  @override
  String interactionReminderPrayerAfter(String prayer, String duration) {
    return 'بعد $prayer بـ$duration';
  }

  @override
  String interactionReminderPrayerBefore(String prayer, String duration) {
    return 'قبل $prayer بـ$duration';
  }

  @override
  String interactionReminderBefore(String duration) {
    return 'قبل $duration';
  }

  @override
  String interactionReminderDaily(String time) {
    return 'كل يوم الساعة $time';
  }

  @override
  String interactionReminderOnce(String date, String time) {
    return '$date الساعة $time';
  }

  @override
  String interactionDurationMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دقيقة',
      many: '$count دقيقة',
      few: '$count دقائق',
      two: 'دقيقتين',
      one: 'دقيقة',
    );
    return '$_temp0';
  }

  @override
  String interactionDurationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ساعة',
      many: '$count ساعة',
      few: '$count ساعات',
      two: 'ساعتين',
      one: 'ساعة',
    );
    return '$_temp0';
  }

  @override
  String interactionDurationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يوم',
      many: '$count يومًا',
      few: '$count أيام',
      two: 'يومين',
      one: 'يوم',
    );
    return '$_temp0';
  }

  @override
  String interactionDurationWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أسبوع',
      many: '$count أسبوعًا',
      few: '$count أسابيع',
      two: 'أسبوعين',
      one: 'أسبوع',
    );
    return '$_temp0';
  }

  @override
  String get interactionWeekdayMon => 'إثنين';

  @override
  String get interactionWeekdayTue => 'ثلاثاء';

  @override
  String get interactionWeekdayWed => 'أربعاء';

  @override
  String get interactionWeekdayThu => 'خميس';

  @override
  String get interactionWeekdayFri => 'جمعة';

  @override
  String get interactionWeekdaySat => 'سبت';

  @override
  String get interactionWeekdaySun => 'أحد';

  @override
  String get interactionQuickAddHint =>
      'اكتب ما يدور في بالك… «صرفت ٥ دنانير قهوة»';

  @override
  String get interactionQuickAddLabel => 'إضافة سريعة';

  @override
  String get interactionQuickAddUnavailable => 'الإضافة السريعة ليست جاهزة بعد';

  @override
  String get interactionQuickAddFailed => 'تعذّرت الإضافة، حاول مرة أخرى';

  @override
  String get interactionQuickAddEmpty => 'اكتب شيئًا أولًا';

  @override
  String get interactionQuickAddAdded => 'أُضيف إلى مداره';

  @override
  String interactionQuickAddAt(String time) {
    return 'الساعة $time';
  }

  @override
  String interactionQuickAddMl(String ml) {
    return '$ml مل';
  }

  @override
  String interactionQuickAddScore(String score, int max) {
    return '$score من $max';
  }

  @override
  String get interactionKindTask => 'مهمة';

  @override
  String get interactionKindExpense => 'مصروف';

  @override
  String get interactionKindIncome => 'دخل';

  @override
  String get interactionKindWater => 'ماء';

  @override
  String get interactionKindPain => 'ألم';

  @override
  String get interactionKindMood => 'مزاج';

  @override
  String get interactionKindContact => 'تواصل';

  @override
  String get interactionKindNote => 'ملاحظة';
}
