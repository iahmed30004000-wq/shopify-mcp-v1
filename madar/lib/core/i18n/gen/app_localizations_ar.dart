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
  String interactionFieldIcon(int index) {
    return 'أيقونة $index';
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
  String get interactionCurrencySymbolLYD => 'ل.د';

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
  String get interactionReminderDate => 'التاريخ';

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
  String get interactionReminderRelBefore => 'قبلها';

  @override
  String get interactionReminderRelAt => 'في وقتها';

  @override
  String get interactionReminderRelAfter => 'بعدها';

  @override
  String interactionReminderWeekly(String days, String time) {
    return '$days الساعة $time';
  }

  @override
  String get interactionReminderWorkdays => 'أيام الدوام';

  @override
  String get interactionReminderEveryDay => 'كل الأيام';

  @override
  String get interactionReminderRemove => 'إزالة التذكير';

  @override
  String get interactionReminderNoDue => 'لا موعد نهائي لهذا العنصر';

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

  @override
  String get interactionListSeparator => '، ';

  @override
  String get interactionQuickAddPreview => 'هكذا فهمتُها';

  @override
  String get interactionTrayLabel => 'إجراءات سريعة مفتوحة';

  @override
  String get importTitle => 'استيراد البيانات';

  @override
  String get importHeroTitle => 'أعِد بياناتك إلى مَدارها';

  @override
  String get importHeroBody =>
      'اختر ملف JSON الذي صدّرته من النسخة التجريبية، أو الصق محتواه. نحلّله أولًا ونريك كل شيء قبل أن يُكتب سطر واحد.';

  @override
  String get importPickFile => 'اختيار ملف JSON';

  @override
  String get importPasteToggle => 'لصق نص JSON';

  @override
  String get importPasteHint => 'الصق محتوى الملف هنا…';

  @override
  String get importAnalyzeAction => 'تحليل';

  @override
  String get importAnalyzing => 'نقرأ ملفك ونرسم خريطته…';

  @override
  String get importAcceptedHint =>
      'نقبل تصدير النسخة التجريبية (data و logs) أو أقسامًا مباشرة، بمفاتيح عربية أو إنجليزية. لا يضيع شيء: ما لا نعرفه يُحفظ في الأرشيف.';

  @override
  String get importFileLabel => 'الملف';

  @override
  String get importPastedLabel => 'نص ملصوق';

  @override
  String get importPreviewTitle => 'ما وجدناه';

  @override
  String importRecordsReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'سجل جاهز للاستيراد',
      many: 'سجلًا جاهزًا للاستيراد',
      few: 'سجلات جاهزة للاستيراد',
      two: 'سجلان جاهزان للاستيراد',
      one: 'سجل جاهز للاستيراد',
      zero: 'لا سجلات للاستيراد',
    );
    return '$_temp0';
  }

  @override
  String get importShapeTitle => 'بنية الملف';

  @override
  String get importShapeWrapped => 'بيانات + سجلات';

  @override
  String get importShapeDataOnly => 'بيانات فقط';

  @override
  String get importShapeLogsOnly => 'سجلات فقط';

  @override
  String get importShapeFlat => 'أقسام مباشرة';

  @override
  String get importShapeList => 'قائمة سجلات';

  @override
  String get importShapeNested => 'مجمّعة حسب المجال';

  @override
  String get importShapeDayKeyed => 'سجلات مرتّبة بالأيام';

  @override
  String get importShapeTyped => 'أحداث مصنّفة';

  @override
  String get importShapeIdKeyed => 'مفهرسة بالمعرّفات';

  @override
  String get importKeysArabic => 'مفاتيح عربية';

  @override
  String get importKeysCamel => 'مفاتيح camelCase';

  @override
  String get importKeysSnake => 'مفاتيح snake_case';

  @override
  String get importKeysMixed => 'مفاتيح مختلطة';

  @override
  String get importSectionsTitle => 'الأقسام';

  @override
  String importBudgetTotal(String amount) {
    return 'مجموع الميزانية الشهرية: $amount';
  }

  @override
  String get importModulesTitle => 'وحدات جديدة من بيانات غير معروفة';

  @override
  String get importModulesBody =>
      'لم نتعرّف على هذه الأقسام، فحوّلناها إلى وحدات مخصّصة كي لا يضيع منها شيء.';

  @override
  String importModuleEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count إدخال',
      many: '$count إدخالًا',
      few: '$count إدخالات',
      two: 'إدخالان',
      one: 'إدخال واحد',
      zero: 'بلا إدخالات',
    );
    return '$_temp0';
  }

  @override
  String get importWarningsTitle => 'ملاحظات قبل الاستيراد';

  @override
  String get importUnmappedTitle => 'محفوظ في الأرشيف';

  @override
  String get importUnmappedBody =>
      'قيم لا مكان لها في مَدار بعد؛ تُحفظ كما هي مع النسخة الأصلية من الملف.';

  @override
  String importTimesCount(String count) {
    return '×$count';
  }

  @override
  String get importDuplicateTitle => 'استوردت هذا الملف من قبل';

  @override
  String importDuplicateBody(String date) {
    return 'كان ذلك في $date. لن تتكرر السجلات الموجودة؛ ستُضاف الجديدة فقط.';
  }

  @override
  String get importDuplicateAnyway => 'استيراد على أي حال';

  @override
  String importStartAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'استيراد $count سجل',
      many: 'استيراد $count سجلًا',
      few: 'استيراد $count سجلات',
      two: 'استيراد سجلين',
      one: 'استيراد سجل واحد',
      zero: 'حفظ في الأرشيف',
    );
    return '$_temp0';
  }

  @override
  String get importChooseAnother => 'ملف آخر';

  @override
  String get importWriting => 'نكتب بياناتك في مَدارها…';

  @override
  String get importDoneTitle => 'اكتمل الاستيراد';

  @override
  String importDoneBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أُضيف $count سجل',
      many: 'أُضيف $count سجلًا',
      few: 'أُضيفت $count سجلات',
      two: 'أُضيف سجلان',
      one: 'أُضيف سجل واحد',
      zero: 'لم يُضف أي سجل جديد',
    );
    return '$_temp0';
  }

  @override
  String importDoneExisting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count سجل كانت موجودة فتُركت كما هي',
      many: '$count سجلًا كانت موجودة فتُركت كما هي',
      few: '$count سجلات كانت موجودة فتُركت كما هي',
      two: 'سجلان كانا موجودَين فتُركا كما هما',
      one: 'سجل واحد كان موجودًا فتُرك كما هو',
    );
    return '$_temp0';
  }

  @override
  String get importDoneArchived =>
      'حُفظت نسخة أصلية كاملة من الملف في الأرشيف.';

  @override
  String get importErrorInvalidJson => 'هذا ليس نص JSON صالحًا.';

  @override
  String get importErrorEmpty => 'لا يوجد محتوى لاستيراده.';

  @override
  String get importErrorNotObject =>
      'الملف لا يحتوي على بيانات قابلة للاستيراد.';

  @override
  String get importErrorRead => 'تعذّرت قراءة الملف.';

  @override
  String get importErrorCommit => 'تعذّر الاستيراد، ولم يتغيّر شيء في بياناتك.';

  @override
  String get importNothingFound =>
      'لم نجد في هذا الملف بيانات نعرفها، لكنه سيُحفظ كاملًا في الأرشيف.';

  @override
  String get importTryAgain => 'حاول مجددًا';

  @override
  String get importDefaultWallet => 'المحفظة الرئيسية';

  @override
  String get importDefaultBoard => 'العمل';

  @override
  String get importOpeningBalance => 'الرصيد الافتتاحي';

  @override
  String get importColumnTodo => 'للإنجاز';

  @override
  String get importColumnDoing => 'قيد العمل';

  @override
  String get importColumnDone => 'منجز';

  @override
  String get importSectionHealthAlerts => 'تنبيهات صحية';

  @override
  String get importSectionConditions => 'الحالات الصحية';

  @override
  String get importSectionMedications => 'الأدوية والمكمّلات';

  @override
  String get importSectionMedDoses => 'سجل الجرعات';

  @override
  String get importSectionLabTests => 'التحاليل';

  @override
  String get importSectionLabReadings => 'نتائج التحاليل';

  @override
  String get importSectionAppointments => 'المواعيد الطبية';

  @override
  String get importSectionDoctorQuestions => 'أسئلة للطبيب';

  @override
  String get importSectionPainEntries => 'سجل الألم';

  @override
  String get importSectionMoodEntries => 'المزاج والتوتر';

  @override
  String get importSectionHabits => 'العادات';

  @override
  String get importSectionHabitLogs => 'سجل العادات';

  @override
  String get importSectionWorries => 'المخاوف';

  @override
  String get importSectionCurrencies => 'العملات';

  @override
  String get importSectionWallets => 'المحافظ';

  @override
  String get importSectionBudgetItems => 'بنود الميزانية';

  @override
  String get importSectionTransactions => 'المعاملات';

  @override
  String get importSectionJars => 'الحصّالات';

  @override
  String get importSectionJarDeposits => 'إيداعات الحصّالات';

  @override
  String get importSectionDebts => 'الديون';

  @override
  String get importSectionDebtPayments => 'سداد الديون';

  @override
  String get importSectionObligations => 'الالتزامات الدورية';

  @override
  String get importSectionPeople => 'الأشخاص';

  @override
  String get importSectionContactLogs => 'سجل التواصل';

  @override
  String get importSectionProjects => 'المشاريع';

  @override
  String get importSectionProjectItems => 'مهام المشاريع';

  @override
  String get importSectionBoards => 'لوحات العمل';

  @override
  String get importSectionBoardCards => 'بطاقات العمل';

  @override
  String get importSectionTrips => 'الرحلات';

  @override
  String get importSectionTripItems => 'قوائم التجهيز';

  @override
  String get importSectionTravelDocuments => 'وثائق السفر';

  @override
  String get importSectionLearningGoals => 'أهداف التعلّم';

  @override
  String get importSectionGoalLogs => 'سجل التقدّم';

  @override
  String get importSectionExercises => 'التمارين';

  @override
  String get importSectionWorkoutLogs => 'سجل التمارين';

  @override
  String get importSectionAvoidItems => 'قائمة التجنّب';

  @override
  String get importSectionFastingSessions => 'الصيام';

  @override
  String get importSectionWaterLogs => 'الماء';

  @override
  String get importSectionPrayerLogs => 'سجل الصلاة';

  @override
  String get importSectionTasks => 'المهام';

  @override
  String get importSectionCustomModules => 'وحدات مخصّصة';

  @override
  String get importSectionCustomEntries => 'إدخالات الوحدات';

  @override
  String get importIssueInvalidJson => 'نص JSON غير صالح';

  @override
  String get importIssueEmptyInput => 'لا يوجد محتوى';

  @override
  String get importIssueNotAnObject => 'لا بيانات قابلة للاستيراد';

  @override
  String get importIssueUnparsedDate => 'تواريخ لم نستطع قراءتها';

  @override
  String get importIssueUnparsedAmount => 'مبالغ لم نستطع قراءتها';

  @override
  String get importIssueUnparsedTime => 'أوقات لم نستطع قراءتها';

  @override
  String get importIssueUnparsedNumber => 'أرقام لم نستطع قراءتها';

  @override
  String get importIssueInferredTime =>
      'أوقات استنتجناها من كلمات (صباحًا ← ٨:٠٠)';

  @override
  String get importIssueMissingRequired =>
      'سجلات تنقصها قيمة أساسية فلم تُستورد، وهي محفوظة في الأرشيف';

  @override
  String get importIssueUnresolvedReference => 'إشارات إلى عناصر غير موجودة';

  @override
  String get importIssueCreatedReference => 'عناصر أنشأناها من أسمائها';

  @override
  String get importIssueUnknownValue => 'قيم غير معروفة استبدلنا بها الافتراضي';

  @override
  String get importIssueAssumedGlasses => 'كميات ماء قرأناها أكوابًا (٢٥٠ مل)';

  @override
  String get importIssueAssumedFastingTarget => 'أهداف صيام مفترضة';

  @override
  String get importIssueAssumedDate => 'تواريخ مفترضة';

  @override
  String get importIssueAssumedValue => 'قيم مفترضة';

  @override
  String get importIssueCurrencyWallet =>
      'محافظ أنشأناها لعملات مختلفة (دون تحويل)';

  @override
  String get importIssueMissingRate =>
      'عملات بلا سعر صرف (افترضنا ١) — عدّلها من الإعدادات';

  @override
  String get importIssueDuplicateSourceId => 'معرّفات مكرّرة في الملف';

  @override
  String get importIssueBudget => 'فحوص الميزانية';

  @override
  String get importIssueDuplicateFile => 'ملف مستورد من قبل';

  @override
  String get importIssueSettingRead => 'إعدادات قرأناها من الملف';

  @override
  String importBudgetChildrenUnder(String name, String amount) {
    return 'بنود «$name» أقل منه بـ $amount';
  }

  @override
  String importBudgetChildrenOver(String name, String amount) {
    return 'بنود «$name» تزيد عليه بـ $amount';
  }

  @override
  String importBudgetPercentOver(String name, String percent) {
    return 'نِسَب «$name» تتجاوز ١٠٠٪ ($percent)';
  }

  @override
  String importBudgetCircular(String name) {
    return 'نِسَب «$name» تعتمد على نفسها';
  }

  @override
  String importBudgetStructure(String name) {
    return '«$name» مرتبط ببند غير صالح، فجعلناه بندًا رئيسيًا';
  }

  @override
  String importBudgetMissingRate(String currency) {
    return 'لا يوجد سعر صرف لـ $currency';
  }

  @override
  String get importBudgetWhole => 'الميزانية كلها';

  @override
  String get shellSplashAssembling => 'نُركّب أسطرلابك…';

  @override
  String get shellSplashSemantics => 'يجري فتح بياناتك المشفّرة';

  @override
  String get shellGateErrorTitle => 'تعذّر فتح مَدار';

  @override
  String get shellGateRetry => 'أعِد المحاولة';

  @override
  String get shellGateReset => 'ابدأ من جديد';

  @override
  String get shellGateResetTitle => 'حذف جميع البيانات؟';

  @override
  String get shellGateResetBody =>
      'سيُحذف ملف البيانات المشفّر نهائيًا ويبدأ مَدار من الصفر، ولا يمكن التراجع عن ذلك. إن لم تكن لديك نسخة احتياطية فلن تعود بياناتك القديمة.';

  @override
  String get shellGateResetConfirm => 'احذف وابدأ من جديد';

  @override
  String get shellGateResetFailed =>
      'تعذّر حذف البيانات. أعد تشغيل التطبيق ثم حاول مجددًا.';

  @override
  String shellDurationHoursMinutes(String hours, String minutes) {
    return '$hours س $minutes د';
  }

  @override
  String shellDurationHours(String hours) {
    return '$hours س';
  }

  @override
  String shellDurationMinutes(String minutes) {
    return '$minutes د';
  }

  @override
  String get shellDurationLessThanMinute => 'أقل من دقيقة';

  @override
  String get homeOpenSettings => 'الإعدادات';

  @override
  String get homeNow => 'الآن';

  @override
  String homeNextPrayer(String prayer, String duration) {
    return '$prayer بعد $duration';
  }

  @override
  String get homePlaceholderBadge => 'مواقيت تقريبية';

  @override
  String get homePlaceholderNote => 'المواقيت الدقيقة لموقعك تصل قريبًا';

  @override
  String homeWindowStarts(String window, String time) {
    return '$window، يبدأ $time';
  }

  @override
  String homeTasksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مهمة',
      many: '$count مهمة',
      few: '$count مهام',
      two: 'مهمتان',
      one: 'مهمة واحدة',
      zero: 'لا مهام بعد',
    );
    return '$_temp0';
  }

  @override
  String homeTasksProgress(String done, String total) {
    return 'أنجزت $done من $total';
  }

  @override
  String get homeAddTask => 'مهمة جديدة';

  @override
  String get homeEditTask => 'تعديل المهمة';

  @override
  String get homeTaskTitleField => 'المهمة';

  @override
  String get homeTaskTitleHint => 'ماذا تودّ أن تنجز؟';

  @override
  String get homeTaskNotesField => 'ملاحظات';

  @override
  String get homeTaskWindowField => 'وقتها من اليوم';

  @override
  String get homeTaskDateField => 'اليوم';

  @override
  String get homeTaskPlanetField => 'الكوكب';

  @override
  String get homeTaskAdded => 'أُضيفت المهمة';

  @override
  String get homeTaskCompleted => 'أُنجزت المهمة';

  @override
  String get homeTaskReopened => 'أُعيد فتح المهمة';

  @override
  String get homeTaskReopen => 'إعادة فتح';

  @override
  String get homeTaskDone => 'منجزة';

  @override
  String get homeMoveTitle => 'انقلها إلى وقت آخر';

  @override
  String get homeMoveSubtitle => 'تبقى في اليوم نفسه';

  @override
  String get homeReminderSet => 'ضُبط التذكير';

  @override
  String get homeReminderRemoved => 'أُزيل التذكير';

  @override
  String get homeEmptyTitle => 'هذا الوقت ما زال رحبًا';

  @override
  String get homeEmptyBody =>
      'أضف مهمة، أو اكتب ما يدور في بالك في الشريط أدناه.';

  @override
  String get homeRadarTitle => 'رادار الإهمال';

  @override
  String get homeRadarBody =>
      'سيلفت نظرك بلطف إلى جوانب حياتك التي غبت عنها طويلًا، ويصل مع المدار الحيّ.';

  @override
  String get homeRadarBadge => 'قريبًا';

  @override
  String get homeDefaultWallet => 'المحفظة';

  @override
  String homeDialSemantics(String window, String next) {
    return 'أسطرلاب اليوم: $window، و$next';
  }

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get settingsPersonal => 'التخصيص';

  @override
  String get settingsGeneral => 'عام';

  @override
  String get settingsAppearance => 'المظهر';

  @override
  String get settingsAppearanceSubtitle => 'السمة ولون التمييز واللغة والأرقام';

  @override
  String get settingsTheme => 'السمة';

  @override
  String get settingsThemeSelected => 'السمة الحالية';

  @override
  String get settingsFollowSystem => 'اتّباع وضع الجهاز';

  @override
  String get settingsFollowSystemHint =>
      'اللؤلؤ في الوضع الفاتح، وسمتك المختارة في الداكن';

  @override
  String get settingsAccent => 'لون التمييز';

  @override
  String get settingsAccentDefault => 'لون السمة';

  @override
  String get settingsAccentCustom => 'لون مخصّص';

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get settingsLanguageArabic => 'العربية';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsDigits => 'الأرقام';

  @override
  String get settingsDigitsAuto => 'تلقائية';

  @override
  String get settingsDigitsWestern => 'غربية';

  @override
  String get settingsDigitsArabicIndic => 'مشرقية';

  @override
  String get settingsDigitsHint =>
      'التلقائية: مشرقية بالعربية وغربية بالإنجليزية';

  @override
  String get settingsSound => 'الصوت واللمس';

  @override
  String get settingsSoundSubtitle => 'المؤثرات والأجواء ومستويات الصوت';

  @override
  String get settingsSoundEnabled => 'الأصوات';

  @override
  String get settingsSoundEnabledHint => 'مفتاح عام لكل أصوات التطبيق';

  @override
  String get settingsHaptics => 'الاهتزاز اللمسي';

  @override
  String get settingsHapticsHint => 'نبضة خفيفة ترافق كل صوت';

  @override
  String get settingsAmbient => 'أجواء الفضاء';

  @override
  String get settingsAmbientHint => 'طبقة صوتية هادئة تحت الواجهة';

  @override
  String get settingsVolumes => 'مستويات الصوت';

  @override
  String get settingsSoundProfile => 'طابع الأصوات';

  @override
  String get settingsSoundProfileHint => 'يتبدّل مع السمة';

  @override
  String get settingsMotion => 'الحركة';

  @override
  String get settingsMotionSystem => 'حسب الجهاز';

  @override
  String get settingsMotionReduced => 'مخفّفة';

  @override
  String get settingsMotionFull => 'كاملة';

  @override
  String get settingsMotionHint =>
      'المخفّفة تستبدل الانتقالات السينمائية بتلاشٍ هادئ';

  @override
  String get settingsPower => 'وضع الطاقة';

  @override
  String get settingsPowerAuto => 'تلقائي';

  @override
  String get settingsPowerSaver => 'توفير البطارية';

  @override
  String get settingsPowerHint =>
      'توفير البطارية يُثبّت خلفية الفضاء ويخفّف العرض';

  @override
  String get settingsData => 'البيانات';

  @override
  String get settingsImport => 'استيراد من النموذج الأوّلي';

  @override
  String get settingsImportHint => 'ملف JSON صدّرته من النسخة الأولى';

  @override
  String get settingsPrivacyNote => 'بياناتك مشفّرة وتبقى على جهازك وحده.';

  @override
  String get settingsAbout => 'حول مَدار';

  @override
  String settingsVersion(String version) {
    return 'الإصدار $version';
  }

  @override
  String get settingsFonts => 'الخطوط';

  @override
  String get settingsFontsBody =>
      'خطوط حرّة مرخّصة برخصة SIL للخطوط المفتوحة 1.1';

  @override
  String get settingsLicenses => 'تراخيص البرمجيات المفتوحة';

  @override
  String get settingsLicensesBody =>
      'SQLCipher وOpenSSL وFlutter وكل حزمة بُني بها مَدار';

  @override
  String get settingsFontRoleUi => 'خط الواجهة';

  @override
  String get settingsFontRoleDisplay => 'خط العناوين';

  @override
  String get settingsFontRoleQuran => 'نص القرآن الكريم';

  @override
  String get settingsFontRoleNaskh => 'النصوص الكلاسيكية';

  @override
  String get settingsFontPlex => 'IBM Plex Sans Arabic';

  @override
  String get settingsFontReemKufi => 'Reem Kufi';

  @override
  String get settingsFontAmiriQuran => 'Amiri Quran';

  @override
  String get settingsFontAmiri => 'Amiri';

  @override
  String get settingsLicense => 'الترخيص';

  @override
  String get settingsLicenseUnavailable => 'تعذّر تحميل نص الترخيص';

  @override
  String get settingsGalleryHint => 'كل مكوّنات الواجهة في مكان واحد';

  @override
  String get settingsDeveloper => 'للمطوّرين';

  @override
  String settingsOpen(String name) {
    return 'فتح $name';
  }

  @override
  String get onboardingWelcomeTagline => 'يومك يدور حول الصلوات الخمس';

  @override
  String get onboardingWelcomeBody =>
      'مهامك وصحتك ومالك وأهلك… لكلٍّ منها مداره، والصلاة هي المركز الذي يجمعها ويضبط إيقاعها.';

  @override
  String get onboardingStyleTitle => 'لغتك وطابعك';

  @override
  String get onboardingStyleBody =>
      'جرّب وشاهد التغيير فورًا، ويمكنك تعديله متى شئت من الإعدادات.';

  @override
  String get onboardingStartTitle => 'من أين نبدأ؟';

  @override
  String get onboardingStartBody => 'بياناتك مشفّرة وتبقى على جهازك وحده.';

  @override
  String get onboardingStartFresh => 'بداية جديدة';

  @override
  String get onboardingStartFreshBody => 'مدارٌ صافٍ ينتظر خطوتك الأولى';

  @override
  String get onboardingImport => 'استيراد بياناتي';

  @override
  String get onboardingImportBody => 'من ملف JSON صدّرته من النموذج الأوّلي';

  @override
  String get onboardingBegin => 'لنبدأ';

  @override
  String get onboardingSkip => 'تخطٍّ';

  @override
  String onboardingStep(String current, String total) {
    return 'الخطوة $current من $total';
  }

  @override
  String orbitReasonPersonOverdue(String name, int days, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'متأخر $n يوم',
      many: 'متأخر $n يومًا',
      few: 'متأخر $n أيام',
      two: 'متأخر يومين',
      one: 'متأخر يومًا واحدًا',
    );
    return '$name — $_temp0';
  }

  @override
  String orbitReasonDosesPastDue(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n جرعة فائتة',
      many: '$n جرعة فائتة',
      few: '$n جرعات فائتة',
      two: 'جرعتان فائتتان',
      one: 'جرعة فائتة',
    );
    return '$_temp0';
  }

  @override
  String orbitReasonDosesPastDueNamed(String name, int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n جرعة فائتة',
      many: '$n جرعة فائتة',
      few: '$n جرعات فائتة',
      two: 'جرعتان فائتتان',
      one: 'جرعة فائتة',
    );
    return '$name — $_temp0';
  }

  @override
  String orbitReasonPrayersMissed(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n صلاة لم تُسجَّل هذا الأسبوع',
      many: '$n صلاةً لم تُسجَّل هذا الأسبوع',
      few: '$n صلوات لم تُسجَّل هذا الأسبوع',
      two: 'صلاتان لم تُسجَّلا هذا الأسبوع',
      one: 'صلاة لم تُسجَّل هذا الأسبوع',
    );
    return '$_temp0';
  }

  @override
  String orbitReasonTasksOverdue(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n مهمة متأخرة',
      many: '$n مهمة متأخرة',
      few: '$n مهام متأخرة',
      two: 'مهمتان متأخرتان',
      one: 'مهمة متأخرة',
    );
    return '$_temp0';
  }

  @override
  String orbitReasonCardsOverdue(String board, int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n بطاقة متأخرة',
      many: '$n بطاقة متأخرة',
      few: '$n بطاقات متأخرة',
      two: 'بطاقتان متأخرتان',
      one: 'بطاقة متأخرة',
    );
    return '$board — $_temp0';
  }

  @override
  String orbitReasonBudgetOverspent(String item, String percent) {
    return '$item — تجاوز الميزانية بنسبة $percent';
  }

  @override
  String orbitReasonObligationOverdue(String name, int days, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'تأخّر السداد $n يوم',
      many: 'تأخّر السداد $n يومًا',
      few: 'تأخّر السداد $n أيام',
      two: 'تأخّر السداد يومين',
      one: 'تأخّر السداد يومًا واحدًا',
    );
    return '$name — $_temp0';
  }

  @override
  String orbitReasonDebtOverdue(String person, int days, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'تأخّر السداد $n يوم',
      many: 'تأخّر السداد $n يومًا',
      few: 'تأخّر السداد $n أيام',
      two: 'تأخّر السداد يومين',
      one: 'تأخّر السداد يومًا واحدًا',
    );
    return 'دَين $person — $_temp0';
  }

  @override
  String orbitReasonGoalBehind(String name, String percent) {
    return '$name — أنجزتَ $percent من المتوقَّع حتى الآن';
  }

  @override
  String orbitReasonGoalQuiet(String name, int days, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'لا تقدّم منذ $n يوم',
      many: 'لا تقدّم منذ $n يومًا',
      few: 'لا تقدّم منذ $n أيام',
      two: 'لا تقدّم منذ يومين',
      one: 'لا تقدّم منذ يوم',
    );
    return '$name — $_temp0';
  }

  @override
  String orbitReasonWorkoutsMissed(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n تمرين فائت هذا الأسبوع',
      many: '$n تمرينًا فائتًا هذا الأسبوع',
      few: '$n تمارين فائتة هذا الأسبوع',
      two: 'تمرينان فائتان هذا الأسبوع',
      one: 'تمرين فائت هذا الأسبوع',
    );
    return '$_temp0';
  }

  @override
  String orbitReasonWaterLow(String percent) {
    return 'الماء — $percent فقط من هدف اليوم';
  }

  @override
  String orbitReasonDocumentExpiring(String name, int days, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'انتهاء الصلاحية خلال $n يوم',
      many: 'انتهاء الصلاحية خلال $n يومًا',
      few: 'انتهاء الصلاحية خلال $n أيام',
      two: 'انتهاء الصلاحية خلال يومين',
      one: 'انتهاء الصلاحية خلال يوم',
    );
    return '$name — $_temp0';
  }

  @override
  String orbitReasonDocumentExpiresToday(String name) {
    return '$name — انتهاء الصلاحية اليوم';
  }

  @override
  String orbitReasonDocumentExpired(String name) {
    return '$name — انتهت الصلاحية';
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
      other: 'السفر بعد $n يوم',
      many: 'السفر بعد $n يومًا',
      few: 'السفر بعد $n أيام',
      two: 'السفر بعد يومين',
      one: 'السفر غدًا',
      zero: 'السفر اليوم',
    );
    return '$destination — $_temp0، والتجهيز $percent فقط';
  }

  @override
  String orbitReasonModuleStale(String name, int days, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'لا إدخال منذ $n يوم',
      many: 'لا إدخال منذ $n يومًا',
      few: 'لا إدخال منذ $n أيام',
      two: 'لا إدخال منذ يومين',
      one: 'لا إدخال منذ يوم',
    );
    return '$name — $_temp0';
  }

  @override
  String orbitReasonNoActivity(int days, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'لا نشاط منذ $n يوم',
      many: 'لا نشاط منذ $n يومًا',
      few: 'لا نشاط منذ $n أيام',
      two: 'لا نشاط منذ يومين',
      one: 'لا نشاط منذ يوم',
    );
    return '$_temp0';
  }

  @override
  String orbitReasonHabitsSlipping(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n عادة متعثّرة هذا الأسبوع',
      many: '$n عادةً متعثّرة هذا الأسبوع',
      few: '$n عادات متعثّرة هذا الأسبوع',
      two: 'عادتان متعثّرتان هذا الأسبوع',
      one: 'عادة متعثّرة هذا الأسبوع',
    );
    return '$_temp0';
  }

  @override
  String orbitReasonHabitSlipping(String name, int days, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'لم تُنجَز منذ $n يوم',
      many: 'لم تُنجَز منذ $n يومًا',
      few: 'لم تُنجَز منذ $n أيام',
      two: 'لم تُنجَز منذ يومين',
      one: 'لم تُنجَز منذ يوم',
    );
    return '$name — $_temp0';
  }

  @override
  String orbitReasonProjectItemsOverdue(String project, int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n بند متأخر',
      many: '$n بندًا متأخرًا',
      few: '$n بنود متأخرة',
      two: 'بندان متأخران',
      one: 'بند متأخر',
    );
    return '$project — $_temp0';
  }

  @override
  String orbitReasonJarBehind(String name, String percent) {
    return '$name — ادّخرتَ $percent من المتوقَّع';
  }

  @override
  String orbitReasonSourceStale(String source, int days, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'لا تسجيل منذ $n يوم',
      many: 'لا تسجيل منذ $n يومًا',
      few: 'لا تسجيل منذ $n أيام',
      two: 'لا تسجيل منذ يومين',
      one: 'لا تسجيل منذ يوم',
    );
    return '$source — $_temp0';
  }

  @override
  String get orbitSourcePrayers => 'الصلوات';

  @override
  String get orbitSourceAdhkar => 'الأذكار';

  @override
  String get orbitSourceQuran => 'القرآن';

  @override
  String get orbitSourceDoses => 'جرعات الأدوية';

  @override
  String get orbitSourceHabits => 'العادات';

  @override
  String get orbitSourceMood => 'المزاج';

  @override
  String get orbitSourcePain => 'الألم';

  @override
  String get orbitSourceAppointments => 'المواعيد الطبية';

  @override
  String get orbitSourceContacts => 'التواصل مع الناس';

  @override
  String get orbitSourceTasks => 'المهام';

  @override
  String get orbitSourceCards => 'لوحات العمل';

  @override
  String get orbitSourceProjects => 'المشاريع';

  @override
  String get orbitSourceBudget => 'الميزانية';

  @override
  String get orbitSourceTransactions => 'تسجيل المصروفات';

  @override
  String get orbitSourceJars => 'صناديق الادّخار';

  @override
  String get orbitSourceObligations => 'الالتزامات والفواتير';

  @override
  String get orbitSourceDebts => 'الديون';

  @override
  String get orbitSourceGoals => 'أهداف التعلّم';

  @override
  String get orbitSourceWorkouts => 'التمارين';

  @override
  String get orbitSourceFasting => 'الصيام';

  @override
  String get orbitSourceWater => 'شرب الماء';

  @override
  String get orbitSourceDocuments => 'وثائق السفر';

  @override
  String get orbitSourceTrips => 'الرحلات';

  @override
  String get orbitSourceActivity => 'النشاط المسجَّل';

  @override
  String get orbitArchetypeFaith => 'قبّة ذهبية منقوشة';

  @override
  String get orbitArchetypeOcean => 'محيط حيّ';

  @override
  String get orbitArchetypeTerracotta => 'أرض فخّارية دافئة';

  @override
  String get orbitArchetypeIndustrial => 'عالم صناعي مضيء';

  @override
  String get orbitArchetypeCrystal => 'بلّور بعروق ذهبية';

  @override
  String get orbitArchetypeVerdant => 'عالم أخضر ينمو';

  @override
  String get orbitArchetypeVolcanic => 'عالم بركاني';

  @override
  String get orbitArchetypeGasGiant => 'عملاق غازي بحلقات';

  @override
  String get orbitArchetypeIce => 'عالم جليدي';

  @override
  String get orbitArchetypeDesert => 'عالم صحراوي';

  @override
  String get orbitStateThriving => 'مزدهر';

  @override
  String get orbitStateSteady => 'مستقر';

  @override
  String get orbitStateNeglected => 'يحتاج إلى اهتمام';

  @override
  String get orbitStateDormant => 'هادئ، لا بيانات بعد';

  @override
  String orbitPlanetSemantics(String name, String state, String percent) {
    return '$name، $state، التوازن $percent';
  }

  @override
  String orbitBalanceSemantics(String percent) {
    return 'توازن حياتك $percent';
  }

  @override
  String orbitMoonsMore(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'و$n قمر آخر',
      many: 'و$n قمرًا آخر',
      few: 'و$n أقمار أخرى',
      two: 'وقمران آخران',
      one: 'وقمر آخر',
    );
    return '$_temp0';
  }

  @override
  String orbitMoonSemantics(String name, String planet) {
    return '$name، قمرٌ يدور حول $planet';
  }

  @override
  String get orbitNewPlanetName => 'كوكب جديد';

  @override
  String get orbitBuiltInCannotDelete => 'الكواكب الأساسية تُخفى ولا تُحذف';

  @override
  String get orbitPlanetNeedsName => 'اكتب اسمًا للكوكب';

  @override
  String get orbitUnknownSource => 'مصدر البيانات هذا غير متاح';

  @override
  String get orbitPlanetGone => 'لم يعُد هذا الكوكب في مدارك';

  @override
  String get orbitUndoRenamed => 'تغيّر اسم الكوكب';

  @override
  String orbitUndoRecolored(String name) {
    return 'تغيّر لون $name';
  }

  @override
  String get orbitUndoReordered => 'تغيّر ترتيب الكواكب';

  @override
  String orbitUndoHidden(String name) {
    return 'أُخفي $name';
  }

  @override
  String orbitUndoShown(String name) {
    return 'عاد $name إلى المدار';
  }

  @override
  String orbitUndoWeight(String name) {
    return 'تغيّرت أهمية $name';
  }

  @override
  String orbitUndoSources(String name) {
    return 'تغيّرت مصادر $name';
  }

  @override
  String orbitUndoStyle(String name) {
    return 'تغيّر طراز $name';
  }

  @override
  String orbitUndoAdded(String name) {
    return 'أُضيف $name إلى المدار';
  }

  @override
  String orbitUndoDeleted(String name) {
    return 'حُذف $name';
  }

  @override
  String orbitUndoReset(String name) {
    return 'أُعيد $name إلى أصله';
  }

  @override
  String astrolabeCountdown(String prayer, String time) {
    return '$prayer بعد $time';
  }

  @override
  String astrolabeCountdownNow(String prayer) {
    return 'حان وقت $prayer';
  }

  @override
  String astrolabeSemantics(
    String window,
    String countdown,
    String done,
    String total,
  ) {
    return 'أسطرلاب يومك. $window. $countdown. صلّيت $done من $total.';
  }

  @override
  String astrolabeWindowNow(String window) {
    return 'الآن وقت $window';
  }

  @override
  String astrolabePrayerPrayed(String prayer) {
    return '$prayer: صلّيتها';
  }

  @override
  String astrolabePrayerDue(String prayer) {
    return '$prayer: حان وقتها';
  }

  @override
  String astrolabePrayerUpcoming(String prayer, String time) {
    return '$prayer: الساعة $time';
  }

  @override
  String astrolabePrayerMissed(String prayer) {
    return '$prayer: فاتت';
  }

  @override
  String get astrolabeMakersMark => 'مَدار';

  @override
  String get astrolabeStarDenebKaitos => 'ذنب قيطس';

  @override
  String get astrolabeStarMenkar => 'منخر قيطس';

  @override
  String get astrolabeStarAldebaran => 'الدبران';

  @override
  String get astrolabeStarRigel => 'رجل الجبار';

  @override
  String get astrolabeStarBetelgeuse => 'يد الجوزاء';

  @override
  String get astrolabeStarSirius => 'الشعرى اليمانية';

  @override
  String get astrolabeStarProcyon => 'الشعرى الشامية';

  @override
  String get astrolabeStarAlphard => 'فرد الشجاع';

  @override
  String get astrolabeStarRegulus => 'قلب الأسد';

  @override
  String get astrolabeStarDenebola => 'ذنب الأسد';

  @override
  String get astrolabeStarSpica => 'السماك الأعزل';

  @override
  String get astrolabeStarArcturus => 'السماك الرامح';

  @override
  String get astrolabeStarUnukalhai => 'عنق الحية';

  @override
  String get astrolabeStarRasAlhague => 'رأس الحوّاء';

  @override
  String get astrolabeStarAltair => 'النسر الطائر';

  @override
  String get astrolabeStarDenebAlgedi => 'ذنب الجدي';

  @override
  String get astrolabeStarMarkab => 'مركب الفرس';

  @override
  String get astrolabeZodiacAries => 'الحمل';

  @override
  String get astrolabeZodiacTaurus => 'الثور';

  @override
  String get astrolabeZodiacGemini => 'الجوزاء';

  @override
  String get astrolabeZodiacCancer => 'السرطان';

  @override
  String get astrolabeZodiacLeo => 'الأسد';

  @override
  String get astrolabeZodiacVirgo => 'السنبلة';

  @override
  String get astrolabeZodiacLibra => 'الميزان';

  @override
  String get astrolabeZodiacScorpio => 'العقرب';

  @override
  String get astrolabeZodiacSagittarius => 'القوس';

  @override
  String get astrolabeZodiacCapricorn => 'الجدي';

  @override
  String get astrolabeZodiacAquarius => 'الدلو';

  @override
  String get astrolabeZodiacPisces => 'الحوت';

  @override
  String astrolabeCountdownUntil(String prayer) {
    return 'حتى $prayer';
  }

  @override
  String get astrolabeCountdownNowBand => 'حان وقتها';

  @override
  String skySemantics(String sky, String moon) {
    return 'السماء الآن: $sky. $moon';
  }

  @override
  String get skyMoodNight => 'ليل';

  @override
  String get skyMoodDawn => 'فجر';

  @override
  String get skyMoodSunrise => 'شروق';

  @override
  String get skyMoodDay => 'نهار صافٍ';

  @override
  String get skyMoodGoldenHour => 'الساعة الذهبية';

  @override
  String get skyMoodSunset => 'غروب';

  @override
  String get skyMoodDusk => 'شفق المغرب';

  @override
  String get skyMoonBelow => 'القمر تحت الأفق';

  @override
  String skyMoonPhase(String phase, String percent) {
    return 'القمر $phase، مضاء بنسبة $percent';
  }

  @override
  String get skyMoonNew => 'محاق';

  @override
  String get skyMoonWaxingCrescent => 'هلال متزايد';

  @override
  String get skyMoonFirstQuarter => 'تربيع أول';

  @override
  String get skyMoonWaxingGibbous => 'أحدب متزايد';

  @override
  String get skyMoonFull => 'بدر';

  @override
  String get skyMoonWaningGibbous => 'أحدب متناقص';

  @override
  String get skyMoonLastQuarter => 'تربيع أخير';

  @override
  String get skyMoonWaningCrescent => 'هلال متناقص';

  @override
  String get skyStarNames => 'أسماء النجوم';

  @override
  String get skyStarNamesHint =>
      'تُنقش الأسماء العربية لألمع النجوم في سماء الليل';

  @override
  String planetsSystemSemantics(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'مدار حياتك: $n عالم يدور حول نجمك',
      many: 'مدار حياتك: $n عالمًا يدور حول نجمك',
      few: 'مدار حياتك: $n عوالم تدور حول نجمك',
      two: 'مدار حياتك: عالمان يدوران حول نجمك',
      one: 'مدار حياتك: عالم واحد يدور حول نجمك',
      zero: 'مدار حياتك بلا عوالم ظاهرة',
    );
    return '$_temp0';
  }

  @override
  String get planetsOpenHint => 'ادخل إلى هذا العالم';

  @override
  String get planetsCustomizeHint => 'خصّص هذا العالم';

  @override
  String get planetsMoonOpenHint => 'افتح';

  @override
  String planetsMoonsCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n قمر',
      many: '$n قمرًا',
      few: '$n أقمار',
      two: 'قمران',
      one: 'قمر واحد',
      zero: 'بلا أقمار',
    );
    return '$_temp0';
  }

  @override
  String get orbitUiSceneHint =>
      'اسحب لتدوير المدار، وباعد بإصبعين للاقتراب من عالم';

  @override
  String get orbitUiRecenter => 'العودة إلى المدار كاملًا';

  @override
  String get orbitUiRadarClear =>
      'عوالمك كلها في توازن — لا شيء يحتاج انتباهك الآن';

  @override
  String get orbitUiRadarWaiting => 'سيبدأ الرادار عمله حين تسجّل أول أنشطتك';

  @override
  String orbitUiRadarEntrySemantics(String planet, String reason) {
    return '$planet: $reason';
  }

  @override
  String get orbitUiRadarOpenHint => 'انتقل إلى هذا العالم';

  @override
  String get orbitUiBalanceLabel => 'التوازن';

  @override
  String orbitUiPlanetWeight(String weight) {
    return 'وزنه في توازنك ×$weight';
  }

  @override
  String get orbitUiPlanetNotCounted => 'لا يُحتسب في توازنك';

  @override
  String get orbitUiReasonsTitle => 'ما يحتاج عنايتك';

  @override
  String get orbitUiReasonsNone => 'لا شيء متأخر هنا — أحسنت';

  @override
  String get orbitUiReasonsDormant => 'هذا العالم هادئ بانتظار أول بياناتك';

  @override
  String get orbitUiSourcesTitle => 'ما يغذّي هذا التوازن';

  @override
  String get orbitUiMoonsTitle => 'الأقمار';

  @override
  String get orbitUiMoonsNone => 'لا أقمار تدور حول هذا العالم بعد';

  @override
  String get orbitUiMoonKindPerson => 'شخص';

  @override
  String get orbitUiMoonKindWallet => 'محفظة';

  @override
  String get orbitUiMoonKindBoard => 'لوحة عمل';

  @override
  String get orbitUiMoonKindTrip => 'رحلة';

  @override
  String get orbitUiMoonKindModule => 'وحدة';

  @override
  String orbitUiMoonFreshness(String percent) {
    return 'حيويته $percent';
  }

  @override
  String get orbitUiMoonSelected => 'القمر الذي اخترته';

  @override
  String get orbitUiCustomize => 'تخصيص';

  @override
  String orbitUiCustomizeTitle(String planet) {
    return 'تخصيص $planet';
  }

  @override
  String get orbitUiCustomizeSubtitle => 'كل تغيير يمكن التراجع عنه';

  @override
  String get orbitUiEditLook => 'الاسم والمظهر';

  @override
  String get orbitUiEditWeight => 'أهميته في التوازن';

  @override
  String get orbitUiEditSources => 'مصادر البيانات';

  @override
  String get orbitUiMoveOrbit => 'نقل مداره';

  @override
  String get orbitUiHide => 'إخفاء من المدار';

  @override
  String get orbitUiReset => 'استعادة الإعدادات الأصلية';

  @override
  String get orbitUiDelete => 'حذف هذا العالم';

  @override
  String get orbitUiAddPlanet => 'إضافة عالم جديد';

  @override
  String get orbitUiHiddenWorlds => 'العوالم المخفية';

  @override
  String get orbitUiFieldName => 'الاسم';

  @override
  String get orbitUiFieldColor => 'اللون';

  @override
  String get orbitUiFieldStyle => 'طراز العالم';

  @override
  String get orbitUiFieldWeight => 'الأهمية';

  @override
  String get orbitUiWeightNone => 'لا يُحتسب';

  @override
  String get orbitUiWeightNormal => 'عادي';

  @override
  String get orbitUiWeightMost => 'الأهم';

  @override
  String get orbitUiSourcesHint => 'حرّك المصدر إلى الصفر لإيقافه';

  @override
  String get orbitUiSourceOff => 'متوقف';

  @override
  String get orbitUiMoveTitle => 'موضع المدار';

  @override
  String get orbitUiMoveSubtitle => 'الأقرب إلى نجمك أولًا';

  @override
  String orbitUiMoveBefore(String planet) {
    return 'قبل $planet';
  }

  @override
  String get orbitUiMoveLast => 'المدار الأبعد';

  @override
  String orbitUiOrbitNumber(String n) {
    return 'المدار $n';
  }

  @override
  String orbitUiPrayerAt(String time) {
    return 'وقتها $time';
  }

  @override
  String get orbitUiPrayerPrayed => 'صلّيتها';

  @override
  String get orbitUiPrayerLate => 'صلّيتها متأخرة';

  @override
  String get orbitUiPrayerMissed => 'فاتتني';

  @override
  String get orbitUiPrayerClear => 'إلغاء التسجيل';

  @override
  String get orbitUiPrayerNotYet => 'لم يدخل وقتها بعد';

  @override
  String orbitUiPrayerLogged(String prayer) {
    return 'سُجّلت صلاة $prayer';
  }

  @override
  String orbitUiPrayerCleared(String prayer) {
    return 'أُلغي تسجيل $prayer';
  }

  @override
  String get orbitUiPrayerHint => 'سجّل هذه الصلاة';

  @override
  String get orbitUiPlanetMissing => 'هذا العالم لم يعد في مدارك';

  @override
  String get orbitUiBackToOrbit => 'العودة إلى المدار';

  @override
  String orbitUiInDuration(String duration) {
    return 'بعد $duration';
  }

  @override
  String orbitUiPrayerPrayedAt(String time) {
    return 'صُلّيت $time';
  }

  @override
  String orbitUiPrayerLateAt(String time) {
    return 'صُلّيت متأخرة $time';
  }

  @override
  String orbitUiMoonOf(String kind, String planet) {
    return '$kind في $planet';
  }

  @override
  String get orbitUiMoonInTouch => 'تواصلت اليوم';

  @override
  String orbitUiMoonInTouchLogged(String name) {
    return 'سُجّل تواصلك مع $name';
  }

  @override
  String get orbitUiMoonRename => 'إعادة التسمية';

  @override
  String get orbitUiMoonRenamed => 'تمت إعادة التسمية';

  @override
  String orbitUiMoonLastContact(String when) {
    return 'آخر تواصل: $when';
  }

  @override
  String orbitUiMoonTripStarts(String date) {
    return 'تبدأ في $date';
  }

  @override
  String get orbitUiMoonNever => 'لم يُسجَّل بعد';

  @override
  String orbitUiListSeparator(String a, String b) {
    return '$a · $b';
  }

  @override
  String orbitUiFraction(String done, String total) {
    return '$done/$total';
  }

  @override
  String get orbitUiPrayerDone => 'صُلّيت';

  @override
  String get orbitUiPrayerLateDone => 'صُلّيت متأخرة';

  @override
  String get orbitUiPanelExpand => 'عرض مهام هذا الوقت ورادار الإهمال';

  @override
  String get orbitUiPanelCollapse => 'طيّ اللوحة وإظهار المدار';

  @override
  String get orbitUiRadarLineJoin => ' — ';

  @override
  String get orbitUiTodayPrayersTitle => 'صلوات اليوم';

  @override
  String orbitUiPrayersProgress(String done, String total) {
    return 'صلّيت $done من $total';
  }

  @override
  String get orbitUiPrayerStatusPrayed => 'صُلّيت';

  @override
  String get orbitUiPrayerStatusDue => 'حان وقتها';

  @override
  String get orbitUiPrayerStatusMissed => 'فاتت';

  @override
  String get orbitUiPrayerStatusUpcoming => 'قادمة';

  @override
  String get orbitUiWirdTitle => 'الورد والأذكار';

  @override
  String get orbitUiWorldTasksTitle => 'اليوم في هذا العالم';

  @override
  String get orbitUiWorldTasksNone => 'لا شيء مخطّط لهذا العالم اليوم';

  @override
  String orbitUiSourceSemantics(String source, String value) {
    return '$source: $value';
  }

  @override
  String get orbitUiMoonWaiting => 'بانتظارك';
}
