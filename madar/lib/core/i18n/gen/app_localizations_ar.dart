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
  String get commonFactSeparator => '، ';

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
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'الحدّ الأقصى $max حرف',
      many: 'الحدّ الأقصى $max حرفًا',
      few: 'الحدّ الأقصى $max أحرف',
      two: 'الحدّ الأقصى حرفان',
      one: 'الحدّ الأقصى حرف واحد',
    );
    return '$_temp0';
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
  String get settingsThemeLightMode => 'للوضع الفاتح';

  @override
  String get settingsThemeDarkMode => 'للوضع الداكن';

  @override
  String get settingsAccent => 'لون التمييز';

  @override
  String get settingsAccentDefault => 'لون السمة';

  @override
  String get settingsAccentCustom => 'لون مخصّص';

  @override
  String get settingsAccentCustomHint =>
      'اسحب على الطيف لاختيار أي لون؛ يُضبط سطوعه تلقائيًا ليبقى مقروءًا في كل سمة.';

  @override
  String settingsAccentPlanet(String planet) {
    return 'لون $planet';
  }

  @override
  String settingsAccentHueValue(String degrees) {
    return 'درجة اللون $degrees°';
  }

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
  String get settingsSectionMotionPower => 'الحركة والطاقة';

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
  String settingsFontsBody(String version) {
    return 'خطوط حرّة مرخّصة برخصة SIL للخطوط المفتوحة $version';
  }

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
  String get settingsFaithSection => 'الإيمان';

  @override
  String get settingsFaithSectionHint => 'الصلاة والقرآن والتذكير';

  @override
  String get settingsPrayerTimes => 'المواقيت وطريقة الحساب';

  @override
  String get settingsAdhan => 'الأذان والإشعارات';

  @override
  String get settingsAdhkarReminders => 'تذكير الأذكار';

  @override
  String get settingsAdhkarMorning => 'أذكار الصباح بعد الفجر';

  @override
  String get settingsAdhkarEvening => 'أذكار المساء بعد العصر';

  @override
  String settingsAdhkarAfter(String offset) {
    return 'بعد الأذان بـ$offset';
  }

  @override
  String get settingsAdhkarOff => 'لا تذكير';

  @override
  String get settingsSecuritySection => 'الخصوصية والأمان';

  @override
  String get settingsAppLock => 'قفل التطبيق';

  @override
  String get settingsAppLockOff => 'متوقف؛ اضبط رمزًا ليحمي مَدار';

  @override
  String get settingsAppLockOn => 'مفعّل بالرمز';

  @override
  String get settingsAppLockOnBio => 'مفعّل بالبصمة والرمز';

  @override
  String get settingsSecurityNote =>
      'يحجب القفلُ ما على الشاشة كلما غبت عن مَدار، أمّا بياناتك فمشفّرة على جهازك دائمًا، مقفلًا كان أو مفتوحًا.';

  @override
  String get settingsCredits => 'الخطوط والمصادر';

  @override
  String get settingsCreditsBody =>
      'الخطوط المفتوحة، ومصادر القرآن والحديث والأذكار والمدن والنغمات';

  @override
  String get settingsCreditsContent => 'المحتوى ومصادره';

  @override
  String get settingsCreditsContentBody =>
      'كل نصّ وبيانات وصوت في مَدار مرخّصٌ ترخيصًا مفتوحًا أو من صنعه، وهذه مصادره كاملة.';

  @override
  String get settingsCreditAdhkar => 'الأذكار — حصن المسلم';

  @override
  String get settingsCreditAdhkarRole =>
      'بيانات مفتوحة (MIT)، ونص القرآن من quran-api';

  @override
  String get settingsCreditCities => 'قائمة المدن';

  @override
  String get settingsCreditCitiesRole =>
      'Natural Earth وGeoNames وIANA وUnicode CLDR';

  @override
  String get settingsCreditAdhan => 'نغمات الأذان';

  @override
  String get settingsCreditAdhanRole =>
      'من صنع مَدار، ولا تسجيلات صوتية مضمّنة';

  @override
  String get onboardingLocationTitle => 'أين تصلّي؟';

  @override
  String get onboardingLocationBody =>
      'تُحسب مواقيت الصلاة على جهازك من موقعك، دون إنترنت. اختر مدينتك، أو استخدم موقعك التقريبي مرة واحدة.';

  @override
  String get onboardingLocationSet => 'اختر موقعك';

  @override
  String get onboardingLocationChange => 'غيّر الموقع';

  @override
  String onboardingLocationFor(String place) {
    return 'مواقيتك في $place';
  }

  @override
  String get onboardingAdhanTitle => 'الأذان في وقته';

  @override
  String get onboardingAdhanBody =>
      'ليُرفَع الأذان في دقيقته ولو كان الهاتف مقفلًا، يحتاج مَدار بعض أذونات أندرويد. امنحها الآن أو لاحقًا من الإعدادات.';

  @override
  String get onboardingLockTitle => 'احمِ مَدار';

  @override
  String get onboardingLockBody =>
      'قفلٌ برمز وبصمة يُغلق مَدار كلما غبت عنه. لا حساب ولا خادم؛ يبقى الرمز على جهازك وحده.';

  @override
  String get onboardingLockSet => 'اضبط رمزًا';

  @override
  String get onboardingLockOn => 'القفل مفعّل بالرمز';

  @override
  String get onboardingLockOnBio => 'القفل مفعّل بالبصمة والرمز';

  @override
  String get onboardingOptional =>
      'خطوة اختيارية، ويمكنك ضبطها لاحقًا من الإعدادات';

  @override
  String homeDateWithHijri(String gregorian, String hijri) {
    return '$gregorian — $hijri';
  }

  @override
  String get homeAllTimes => 'كل المواقيت';

  @override
  String get settingsQuran => 'القراءة والمصحف';

  @override
  String get settingsQuranTajweedOn => 'بألوان التجويد';

  @override
  String get settingsQuranTajweedOff => 'بلا ألوان التجويد';

  @override
  String get settingsQuranReading => 'القراءة';

  @override
  String get settingsQuranPreviewLabel => 'معاينة حجم الخط';

  @override
  String settingsQuranDownloaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'نُزِّل لـ$count سورة',
      many: 'نُزِّل لـ$count سورة',
      few: 'نُزِّل لـ$count سور',
      two: 'نُزِّل لسورتين',
      one: 'نُزِّل لسورة واحدة',
      zero: 'لم يُنزَّل شيء بعد',
    );
    return '$_temp0';
  }

  @override
  String get settingsQuranDownloadNote =>
      'تُنزَّل الترجمة وتجويد Quran.com سورةً سورة من إعدادات القارئ، ولا يتصل مَدار بالإنترنت إلا حين تطلب.';

  @override
  String get settingsQuranSourceNote =>
      'نص المصحف العثماني برواية حفص من مشروع تنزيل، مضمَّن في التطبيق ويعمل دون إنترنت.';

  @override
  String get settingsRecitation => 'التلاوة والقرّاء';

  @override
  String get settingsReminders => 'التذكيرات';

  @override
  String settingsRemindersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تذكير مفعّل',
      many: '$count تذكيرًا مفعّلًا',
      few: '$count تذكيرات مفعّلة',
      two: 'تذكيران مفعّلان',
      one: 'تذكير واحد مفعّل',
      zero: 'لا تذكير مفعّل',
    );
    return '$_temp0';
  }

  @override
  String get settingsWirdReminders => 'تذكير الوِرد';

  @override
  String get settingsWirdNoPlans =>
      'لا خطة وِرد بعد. ابدأ خطة، ويصلك تذكيرها بعد الصلاة التي تختارها.';

  @override
  String get settingsWirdOpen => 'خطط الوِرد';

  @override
  String get settingsWirdNoWindow => 'اختر للخطة صلاةً ليصلك تذكيرها';

  @override
  String get settingsWirdPaused => 'الخطة متوقفة، فلا تذكير';

  @override
  String get settingsWirdEditPlan => 'عدّل الخطة';

  @override
  String get settingsWirdReminderNote =>
      'يصل التذكير بعد الصلاة التي اخترتها للخطة، ولا يصل يومَ تقرأ وِردك قبله.';

  @override
  String get settingsCreditQuran => 'القرآن الكريم — تنزيل';

  @override
  String get settingsCreditQuranRole =>
      'النص العثماني وبياناته، وعلامات التجويد — تراخيص المشاع الإبداعي';

  @override
  String get settingsCreditHadith => 'الأربعون النووية';

  @override
  String get settingsCreditHadithRole => 'النص العربي من hadith-api، ملكٌ عام';

  @override
  String get settingsCreditRecitation => 'التلاوات — EveryAyah';

  @override
  String get settingsCreditRecitationRole =>
      'تُبثّ أو تُنزَّل بطلبك فقط، ولا صوت مضمَّن';

  @override
  String get settingsCreditQibla => 'بوصلة القبلة — النموذج المغناطيسي العالمي';

  @override
  String get settingsCreditQiblaRole => 'نموذج WMM من NOAA وBGS، ملكٌ عام';

  @override
  String orbitReasonPersonOverdue(String name, int days, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'فات الموعد بـ$n يوم',
      many: 'فات الموعد بـ$n يومًا',
      few: 'فات الموعد بـ$n أيام',
      two: 'فات الموعد بيومين',
      one: 'فات الموعد بيوم',
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
  String get orbitUiRecenter => 'إعادة ضبط العرض';

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

  @override
  String get lockScreenSubtitle => 'بياناتك مشفّرة ومحفوظة على هاتفك';

  @override
  String get lockHoldHint => 'افتح مَدار ببصمتك';

  @override
  String get lockHoldingHint => 'أبقِ إصبعك… الأسطرلاب يكتمل';

  @override
  String get lockReadingHint => 'المس مستشعر البصمة';

  @override
  String get lockReleasedEarly => 'أبقِ إصبعك حتى يكتمل الأسطرلاب';

  @override
  String get lockWelcome => 'أهلًا بعودتك';

  @override
  String get lockPinHint => 'أدخل رمز مَدار';

  @override
  String get lockPinChecking => 'نتحقّق…';

  @override
  String lockPinWrong(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'رمز غير صحيح · تبقّت $n محاولة قبل الإيقاف المؤقت',
      many: 'رمز غير صحيح · تبقّت $n محاولة قبل الإيقاف المؤقت',
      few: 'رمز غير صحيح · تبقّت $n محاولات قبل الإيقاف المؤقت',
      two: 'رمز غير صحيح · تبقّت محاولتان قبل الإيقاف المؤقت',
      one: 'رمز غير صحيح · تبقّت محاولة واحدة قبل الإيقاف المؤقت',
      zero: 'رمز غير صحيح',
    );
    return '$_temp0';
  }

  @override
  String lockLockedOut(String time) {
    return 'محاولات كثيرة. حاول مجددًا بعد $time';
  }

  @override
  String lockSeconds(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n ثانية',
      many: '$n ثانية',
      few: '$n ثوانٍ',
      two: 'ثانيتين',
      one: 'ثانية واحدة',
    );
    return '$_temp0';
  }

  @override
  String get lockUsePin => 'استخدم الرمز';

  @override
  String get lockUseFingerprint => 'استخدم البصمة';

  @override
  String get lockForgotPin => 'نسيت الرمز؟';

  @override
  String get lockPromptTitle => 'افتح مَدار';

  @override
  String get lockPromptHint => 'استخدم بصمتك';

  @override
  String get lockPromptReason => 'تحقّق من هويتك لتفتح بياناتك';

  @override
  String get lockPromptSettingsReason => 'تحقّق من هويتك لتغيير إعدادات القفل';

  @override
  String get lockPromptCancelPlain => 'إلغاء';

  @override
  String get lockStorageError => 'تعذّرت قراءة الخزنة الآمنة على هاتفك.';

  @override
  String get lockRetry => 'أعِد المحاولة';

  @override
  String get lockAstrolabeSemantics =>
      'الأسطرلاب. اضغط مطوّلًا لتفتح القفل بالبصمة';

  @override
  String get lockAstrolabeAction => 'افتح بالبصمة';

  @override
  String lockPinProgress(String count, String total) {
    return 'أُدخل $count من $total';
  }

  @override
  String lockPinProgressOpen(String count) {
    return 'أُدخل $count';
  }

  @override
  String get lockKeyDelete => 'حذف';

  @override
  String get lockKeyFingerprint => 'البصمة';

  @override
  String get lockKeyDone => 'تم';

  @override
  String get lockShieldSemantics => 'مَدار مخفيّ حتى تعود';

  @override
  String get lockForgotTitle => 'نسيت الرمز؟';

  @override
  String get lockForgotBody =>
      'لا حساب في مَدار ولا خادم: بياناتك مشفّرة ومحفوظة على هذا الهاتف وحده، لذلك لا يمكن استرجاع الرمز ولا إعادة تعيينه عن بُعد.';

  @override
  String get lockForgotBiometric => 'تحقّق ببصمتك، ثم اختر رمزًا جديدًا.';

  @override
  String get lockForgotBiometricAction => 'تحقّق بالبصمة';

  @override
  String get lockForgotNoBiometric =>
      'من دون الرمز يبقى مَدار مقفلًا. إن تعذّر عليك تذكّره فالسبيل الوحيد مسح بيانات مَدار من إعدادات الهاتف (التطبيقات ← مَدار ← التخزين ← مسح البيانات) والبدء من جديد، وسيضيع كل ما ليس في نسخة احتياطية.';

  @override
  String get lockForgotBack => 'رجوع';

  @override
  String get lockNewPinTitle => 'اختر رمزًا جديدًا';

  @override
  String get lockPinCreateTitle => 'اختر رمزًا لمَدار';

  @override
  String lockPinCreateBody(String min, String max) {
    return 'من $min إلى $max أرقام، يفتح مَدار متى تعذّرت البصمة.';
  }

  @override
  String get lockPinConfirmTitle => 'أكّد الرمز';

  @override
  String get lockPinConfirmBody => 'أدخله مرة أخرى للتأكّد.';

  @override
  String get lockPinMismatch => 'الرمزان مختلفان. لنبدأ من جديد.';

  @override
  String get lockPinWeak => 'هذا الرمز سهل التخمين. يُفضَّل اختيار غيره.';

  @override
  String get lockPinCurrentTitle => 'أدخل الرمز الحالي';

  @override
  String get lockPinSaved => 'حُفظ الرمز، وصار مَدار مقفلًا لك وحدك.';

  @override
  String get lockPinChanged => 'تغيّر الرمز';

  @override
  String get lockConfirmTitle => 'تحقّق من هويتك';

  @override
  String get lockConfirmBody => 'أدخل رمز مَدار للمتابعة.';

  @override
  String get lockBioOfferTitle => 'والفتح بالبصمة أيضًا؟';

  @override
  String get lockBioOfferBody =>
      'أسرع في كل مرة، ويبقى الرمز بديلًا متى احتجت إليه.';

  @override
  String get lockBioOfferEnable => 'فعّل البصمة';

  @override
  String get lockBioOfferSkip => 'ليس الآن';

  @override
  String get lockSettingsTitle => 'الأمان';

  @override
  String get lockSettingsLock => 'قفل التطبيق';

  @override
  String get lockSettingsLockOn => 'يُطلب عند كل تشغيل وبعد الغياب';

  @override
  String get lockSettingsLockOff => 'احمِ بياناتك برمز وبصمة';

  @override
  String get lockSettingsBiometric => 'الفتح بالبصمة';

  @override
  String get lockSettingsBiometricHint => 'ويبقى الرمز بديلًا دائمًا';

  @override
  String get lockSettingsBiometricNotEnrolled =>
      'سجّل بصمة في إعدادات الهاتف أولًا';

  @override
  String get lockSettingsBiometricUnavailable => 'مستشعر البصمة غير متاح الآن';

  @override
  String get lockSettingsChangePin => 'تغيير الرمز';

  @override
  String lockSettingsChangePinHint(String min, String max) {
    return 'رمز من $min إلى $max أرقام';
  }

  @override
  String get lockSettingsLockAfter => 'القفل بعد مغادرة التطبيق';

  @override
  String get lockSettingsLockAfterHint => 'وعند كل تشغيل جديد دائمًا';

  @override
  String get lockAfterImmediately => 'فورًا';

  @override
  String lockAfterMinutes(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n دقيقة',
      many: '$n دقيقة',
      few: '$n دقائق',
      two: 'دقيقتان',
      one: 'دقيقة',
    );
    return '$_temp0';
  }

  @override
  String get lockSettingsRemovePin => 'إزالة الرمز';

  @override
  String get lockSettingsRemovePinHint => 'يوقف قفل التطبيق والفتح بالبصمة';

  @override
  String get lockRemoveTitle => 'إزالة الرمز؟';

  @override
  String get lockRemoveBody => 'سيُفتح مَدار دون قفل حتى تختار رمزًا جديدًا.';

  @override
  String get lockRemoveConfirm => 'أزِل الرمز';

  @override
  String get lockSettingsNote =>
      'لا حساب ولا خادم: بياناتك مشفّرة على هذا الهاتف وحده، ولا يمكن استرجاع الرمز عن بُعد، فاحفظه جيدًا.';

  @override
  String get lockSettingsSaveFailed =>
      'تعذّر الحفظ في الخزنة الآمنة. حاول مجددًا.';

  @override
  String get lockBioLockedOut =>
      'توقّفت البصمة مؤقتًا بعد محاولات كثيرة. استخدم الرمز.';

  @override
  String get lockBioLockedOutPermanently =>
      'البصمة مقفلة حتى تفتح هاتفك بقفل شاشته. استخدم رمز مَدار الآن.';

  @override
  String get lockBioNotEnrolled =>
      'لا توجد بصمة مسجّلة على هذا الهاتف. استخدم الرمز.';

  @override
  String get lockBioNoHardware => 'لا يدعم هذا الهاتف البصمة. استخدم الرمز.';

  @override
  String get lockBioUnavailable => 'مستشعر البصمة غير متاح الآن. استخدم الرمز.';

  @override
  String get lockBioError =>
      'تعذّر التحقّق بالبصمة. حاول مجددًا أو استخدم الرمز.';

  @override
  String get lockBioInterrupted => 'انقطع التحقّق بالبصمة. حاول مجددًا.';

  @override
  String get ptTitle => 'مواقيت الصلاة';

  @override
  String get ptSettingsTitle => 'إعدادات المواقيت';

  @override
  String get ptOpenSettings => 'إعدادات المواقيت';

  @override
  String get ptFajr => 'الفجر';

  @override
  String get ptSunrise => 'الشروق';

  @override
  String get ptDuha => 'الضحى';

  @override
  String get ptDhuhr => 'الظهر';

  @override
  String get ptJumuah => 'الجمعة';

  @override
  String get ptAsr => 'العصر';

  @override
  String get ptMaghrib => 'المغرب';

  @override
  String get ptIsha => 'العشاء';

  @override
  String get ptMidnight => 'منتصف الليل';

  @override
  String get ptLastThird => 'الثلث الأخير';

  @override
  String get ptSunriseHint => 'ينتهي وقت الفجر';

  @override
  String get ptDuhaHint => 'بعد الشروق بربع ساعة';

  @override
  String get ptMidnightHint => 'منتصف ما بين المغرب والفجر';

  @override
  String get ptLastThirdHint => 'وقت قيام الليل';

  @override
  String get ptNightSection => 'الليل وقيامه';

  @override
  String get ptNow => 'الآن';

  @override
  String get ptNextPrayer => 'الصلاة القادمة';

  @override
  String ptNextIn(String prayer) {
    return 'يحين وقت $prayer بعد';
  }

  @override
  String ptAtTime(String time) {
    return 'عند $time';
  }

  @override
  String ptItsTime(String prayer) {
    return 'حان وقت $prayer';
  }

  @override
  String ptCurrentWindow(String window) {
    return 'الوقت الحالي: $window';
  }

  @override
  String ptCountdownSemantics(String prayer, String duration) {
    return 'يحين وقت $prayer بعد $duration';
  }

  @override
  String get ptToday => 'اليوم';

  @override
  String get ptTomorrow => 'غدًا';

  @override
  String get ptYesterday => 'أمس';

  @override
  String get ptTonight => 'الليلة';

  @override
  String get ptPrevDay => 'اليوم السابق';

  @override
  String get ptNextDay => 'اليوم التالي';

  @override
  String get ptBackToToday => 'العودة إلى اليوم';

  @override
  String get ptViewDay => 'اليوم';

  @override
  String get ptViewMonth => 'الشهر';

  @override
  String get ptPrevMonth => 'الشهر السابق';

  @override
  String get ptNextMonth => 'الشهر التالي';

  @override
  String get ptMonthDay => 'اليوم';

  @override
  String ptMonthHijriSpan(String from, String to) {
    return '$from – $to';
  }

  @override
  String get ptAm => 'ص';

  @override
  String get ptPm => 'م';

  @override
  String ptClockHours(String hours) {
    return '$hours ساعة';
  }

  @override
  String ptMinutesSigned(String minutes) {
    return '$minutes د';
  }

  @override
  String ptHijriDate(String day, String month, String year) {
    return '$day $month $year هـ';
  }

  @override
  String ptHijriDayMonth(String day, String month) {
    return '$day $month';
  }

  @override
  String get ptHijriMonth1 => 'محرّم';

  @override
  String get ptHijriMonth2 => 'صفر';

  @override
  String get ptHijriMonth3 => 'ربيع الأول';

  @override
  String get ptHijriMonth4 => 'ربيع الآخر';

  @override
  String get ptHijriMonth5 => 'جمادى الأولى';

  @override
  String get ptHijriMonth6 => 'جمادى الآخرة';

  @override
  String get ptHijriMonth7 => 'رجب';

  @override
  String get ptHijriMonth8 => 'شعبان';

  @override
  String get ptHijriMonth9 => 'رمضان';

  @override
  String get ptHijriMonth10 => 'شوّال';

  @override
  String get ptHijriMonth11 => 'ذو القعدة';

  @override
  String get ptHijriMonth12 => 'ذو الحجة';

  @override
  String get ptLocationTitle => 'موقعك';

  @override
  String get ptLocationSubtitle => 'تُحسب المواقيت على جهازك، دون إنترنت';

  @override
  String ptLocationDefault(String city) {
    return '$city (افتراضي)';
  }

  @override
  String ptLocationNear(String city) {
    return 'قرب $city';
  }

  @override
  String ptPlaceWithCountry(String city, String country) {
    return '$city، $country';
  }

  @override
  String get ptPinnedLocation => 'موقع محدّد';

  @override
  String get ptDefaultCityName => 'عمّان';

  @override
  String get ptSourceGps => 'من موقعك الحالي';

  @override
  String get ptSourceCity => 'مدينة مختارة';

  @override
  String get ptSourceDefault => 'الموقع الافتراضي – اختر موقعك';

  @override
  String ptCoordinates(String lat, String lon) {
    return '$lat، $lon';
  }

  @override
  String ptTimeZoneLabel(String zone) {
    return 'المنطقة الزمنية: $zone';
  }

  @override
  String get ptTimeZoneDevice => 'توقيت الجهاز';

  @override
  String ptZoneOffset(String offset) {
    return 'غرينتش $offset';
  }

  @override
  String ptZoneDiffers(String place) {
    return 'المواقيت بتوقيت $place';
  }

  @override
  String get ptUseCurrentLocation => 'استخدم موقعي الحالي';

  @override
  String get ptUseCurrentLocationHint =>
      'تحديد تقريبي لمرة واحدة، يبقى على جهازك';

  @override
  String get ptChooseCity => 'اختر مدينة';

  @override
  String get ptChooseCityHint => 'بحث بالعربية أو الإنجليزية، دون إنترنت';

  @override
  String get ptRationaleTitle => 'نحتاج موقعك التقريبي';

  @override
  String get ptRationaleBody =>
      'ليحسب مَدار مواقيت الصلاة بدقة يطلب موقعك مرة واحدة. يُحفظ مشفّرًا على جهازك ولا يُرسَل إلى أي مكان.';

  @override
  String get ptRationaleAllow => 'السماح بالموقع';

  @override
  String get ptRequesting => 'بانتظار إذنك…';

  @override
  String get ptLocating => 'نحدّد موقعك…';

  @override
  String get ptDeniedTitle => 'لم يُمنح إذن الموقع';

  @override
  String get ptDeniedBody =>
      'يمكنك المحاولة مجددًا، أو اختيار مدينتك من القائمة.';

  @override
  String get ptTryAgain => 'حاول مجددًا';

  @override
  String get ptDeniedForeverTitle => 'إذن الموقع مغلق';

  @override
  String get ptDeniedForeverBody =>
      'فعّله من إعدادات التطبيق في النظام، أو اختر مدينتك يدويًا.';

  @override
  String get ptOpenAppSettings => 'فتح إعدادات التطبيق';

  @override
  String get ptServiceOffTitle => 'خدمة الموقع متوقفة';

  @override
  String get ptServiceOffBody =>
      'شغّل الموقع من إعدادات الجهاز ثم عُد إلى هنا، أو اختر مدينتك.';

  @override
  String get ptOpenLocationSettings => 'إعدادات الموقع';

  @override
  String get ptUnsupportedBody =>
      'تحديد الموقع غير متاح على هذا الجهاز. اختر مدينتك من القائمة.';

  @override
  String get ptFailedTitle => 'تعذّر تحديد الموقع';

  @override
  String get ptFailedBody =>
      'قد تكون الإشارة ضعيفة. حاول مجددًا في مكان مكشوف، أو اختر مدينتك.';

  @override
  String ptLocationChanged(String place) {
    return 'صار الموقع: $place';
  }

  @override
  String get ptCitySearchHint => 'ابحث عن مدينة…';

  @override
  String get ptCitySearchEmpty => 'لا مدينة بهذا الاسم';

  @override
  String get ptCitySearchEmptyHint => 'جرّب اسمًا آخر أو كتابة أقصر';

  @override
  String get ptCitySuggestions => 'مدن مقترحة';

  @override
  String get ptCityResults => 'النتائج';

  @override
  String get ptCitySelected => 'المختارة';

  @override
  String get ptSectionLocation => 'الموقع';

  @override
  String get ptSectionMethod => 'طريقة الحساب';

  @override
  String get ptSectionMethodHint =>
      'تختلف الطرق أساسًا في زاويتي الفجر والعشاء';

  @override
  String get ptSectionAsr => 'صلاة العصر';

  @override
  String get ptAsrStandard => 'الجمهور';

  @override
  String get ptAsrHanafi => 'الحنفي';

  @override
  String get ptAsrNote =>
      'عند الجمهور (الشافعية والمالكية والحنابلة) يبدأ العصر حين يصير ظل الشيء مثله، وعند الحنفية مثليه.';

  @override
  String get ptSectionHighLat => 'خطوط العرض العليا';

  @override
  String get ptHighLatAuto => 'تلقائي';

  @override
  String get ptHighLatMiddle => 'منتصف الليل';

  @override
  String get ptHighLatSeventh => 'سُبع الليل';

  @override
  String get ptHighLatAngle => 'زاوية الشفق';

  @override
  String ptHighLatNote(String degrees) {
    return 'حيث لا يغيب الشفق صيفًا يُقدَّر الفجر والعشاء بجزء من الليل. التلقائي يختار سُبع الليل شمال خط العرض $degrees تقريبًا.';
  }

  @override
  String get ptSectionAdjustments => 'تعديلات يدوية';

  @override
  String get ptAdjustmentsNote => 'أضِف دقائق أو اطرحها لتوافق تقويم مسجدك.';

  @override
  String get ptResetAdjustments => 'تصفير';

  @override
  String get ptAdjustmentsReset => 'صُفّرت التعديلات اليدوية';

  @override
  String get ptSectionHijri => 'التاريخ الهجري';

  @override
  String get ptHijriOffset => 'تعديل اليوم الهجري';

  @override
  String get ptHijriOffsetNote =>
      'حسب تقويم أم القرى؛ عدّله يومًا أو يومين ليوافق رؤية الهلال في بلدك.';

  @override
  String get ptHijriAtMaghrib => 'يبدأ اليوم الهجري عند المغرب';

  @override
  String get ptHijriAtMaghribHint => 'كما يُحسب اليوم شرعًا، من غروب إلى غروب';

  @override
  String get ptSectionDisplay => 'العرض';

  @override
  String get ptClockFormat => 'نظام الساعة';

  @override
  String get ptPreviewTitle => 'مواقيت اليوم';

  @override
  String get ptPreviewHint => 'تتحدّث مع كل تغيير';

  @override
  String get ptMethodSheetTitle => 'طريقة الحساب';

  @override
  String get ptMethodSuggested => 'مقترحة لموقعك';

  @override
  String get ptMethodDefault => 'الافتراضية';

  @override
  String ptMethodChanged(String method) {
    return 'صارت طريقة الحساب: $method';
  }

  @override
  String get ptMethodJordan => 'وزارة الأوقاف الأردنية';

  @override
  String get ptMethodMuslimWorldLeague => 'رابطة العالم الإسلامي';

  @override
  String get ptMethodUmmAlQura => 'أم القرى – مكة المكرمة';

  @override
  String get ptMethodEgyptian => 'الهيئة المصرية العامة للمساحة';

  @override
  String get ptMethodKarachi => 'جامعة العلوم الإسلامية – كراتشي';

  @override
  String get ptMethodNorthAmerica => 'الجمعية الإسلامية لأمريكا الشمالية';

  @override
  String get ptMethodDubai => 'دبي – الإمارات';

  @override
  String get ptMethodKuwait => 'الكويت';

  @override
  String get ptMethodQatar => 'قطر';

  @override
  String get ptMethodTurkiye => 'رئاسة الشؤون الدينية التركية';

  @override
  String get ptMethodSingapore => 'سنغافورة';

  @override
  String get ptMethodTehran => 'معهد الجيوفيزياء – طهران';

  @override
  String get ptMethodGulfRegion => 'منطقة الخليج';

  @override
  String get ptMethodMoonsightingCommittee => 'لجنة رؤية الهلال';

  @override
  String get ptMethodAlgerian => 'وزارة الشؤون الدينية الجزائرية';

  @override
  String get ptMethodMorocco => 'وزارة الأوقاف المغربية';

  @override
  String get ptMethodTunisia => 'وزارة الشؤون الدينية التونسية';

  @override
  String get ptMethodFrance => 'اتحاد المنظمات الإسلامية في فرنسا';

  @override
  String get ptMethodRussia => 'الإدارة الدينية لمسلمي روسيا';

  @override
  String get ptMethodIndonesian => 'وزارة الشؤون الدينية الإندونيسية';

  @override
  String get ptMethodJafari => 'الجعفري – معهد ليفا، قم';

  @override
  String get ptMethodCustom => 'زوايا مخصّصة';

  @override
  String get ptMethodCustomHint => 'حدّد زاويتي الفجر والعشاء بنفسك';

  @override
  String ptSummaryAngle(String prayer, String angle) {
    return '$prayer $angle';
  }

  @override
  String ptSummaryIshaInterval(String minutes) {
    return 'العشاء بعد المغرب بـ$minutes د';
  }

  @override
  String ptSummaryRamadan(String minutes) {
    return 'في رمضان بعد المغرب بـ$minutes د';
  }

  @override
  String ptSummaryOffset(String prayer, String minutes) {
    return '$prayer $minutes د';
  }

  @override
  String ptSummaryMaghribAngle(String angle) {
    return 'المغرب $angle';
  }

  @override
  String get ptCustomFajrAngle => 'زاوية الفجر';

  @override
  String get ptCustomIshaAngle => 'زاوية العشاء';

  @override
  String get ptCustomIshaByInterval => 'العشاء بعد المغرب بمدة ثابتة';

  @override
  String get ptCustomIshaInterval => 'المدة بعد المغرب';

  @override
  String get ptIncrease => 'زيادة';

  @override
  String get ptDecrease => 'إنقاص';

  @override
  String get ptUndoSettings => 'أُعيدت الإعدادات السابقة';

  @override
  String get ptAsrRule => 'بداية وقت العصر';

  @override
  String get ptHighLatRule => 'طريقة التقدير';

  @override
  String get ptNoAdjustment => 'بلا تعديل';

  @override
  String ptDayUnit(String days) {
    return '$days يوم';
  }

  @override
  String ptAdjustTitle(String prayer) {
    return 'ضبط وقت $prayer';
  }

  @override
  String get ptAdjustHint => 'اضغط مطوّلًا على أي وقت لضبطه بالدقائق';

  @override
  String ptAdjustCalculated(String time) {
    return 'المحسوب: $time';
  }

  @override
  String get ptAdjustDone => 'تم';

  @override
  String ptAdjusted(String prayer) {
    return 'عُدّل وقت $prayer';
  }

  @override
  String get adhanSettingsTitle => 'الأذان';

  @override
  String get adhanSettingsSubtitle => 'الأذان في وقته، والمؤذّن، والتذكير قبله';

  @override
  String adhanMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دقيقة',
      many: '$count دقيقة',
      few: '$count دقائق',
      two: 'دقيقتين',
      one: 'دقيقة',
      zero: 'الآن',
    );
    return '$_temp0';
  }

  @override
  String adhanMinutesShort(String minutes) {
    return '$minutes د';
  }

  @override
  String adhanSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ثانية',
      many: '$count ثانية',
      few: '$count ثوانٍ',
      two: 'ثانيتين',
      one: 'ثانية',
      zero: 'لحظات',
    );
    return '$_temp0';
  }

  @override
  String adhanNotifCallTitle(String prayer) {
    return 'حان الآن وقت صلاة $prayer';
  }

  @override
  String adhanNotifCallBody(String time) {
    return '$time · حيّ على الصلاة';
  }

  @override
  String adhanNotifPreTitle(String prayer, String minutes) {
    return '$prayer بعد $minutes';
  }

  @override
  String adhanNotifPreBody(String time) {
    return 'استعدّ للصلاة؛ يُرفَع الأذان عند $time';
  }

  @override
  String get adhanNotifSunriseTitle => 'أشرقت الشمس';

  @override
  String get adhanNotifSunriseBody => 'انتهى وقت صلاة الفجر';

  @override
  String adhanNotifSunriseSoonTitle(String minutes) {
    return 'الشروق بعد $minutes';
  }

  @override
  String adhanNotifSunriseSoonBody(String time) {
    return 'يوشك وقت الفجر أن ينتهي؛ صلِّ قبل $time';
  }

  @override
  String adhanNotifTestTitle(String prayer) {
    return 'تجربة: أذان $prayer';
  }

  @override
  String get adhanNotifTestBody => 'هكذا سيبدو الأذان ويُسمَع في وقته';

  @override
  String get adhanChannelGroup => 'الصلاة والأذان';

  @override
  String adhanChannelCall(String sound) {
    return 'الأذان · $sound';
  }

  @override
  String get adhanChannelCallHint => 'الأذان عند دخول وقت كل صلاة';

  @override
  String get adhanChannelReminder => 'تذكير قبل الأذان';

  @override
  String get adhanChannelSunrise => 'الشروق';

  @override
  String get adhanToneDawn => 'نور الفجر';

  @override
  String get adhanToneDawnHint =>
      'توهّج بلّوري يعلو فوق نغمة دافئة، كأول الضوء';

  @override
  String get adhanToneBrass => 'نحاس الأسطرلاب';

  @override
  String get adhanToneBrassHint => 'أجراس هادئة كساعة برجٍ بعيدة';

  @override
  String get adhanToneBowl => 'سكينة';

  @override
  String get adhanToneBowlHint => 'ثلاث قرعات على وعاءٍ غنائي';

  @override
  String get adhanToneChime => 'جرس التذكير';

  @override
  String get adhanToneSunrise => 'بلّور الشروق';

  @override
  String get adhanToneChimeHint => 'رنّة زجاجية قصيرة';

  @override
  String get adhanSilent => 'بلا صوت';

  @override
  String get adhanSilentHint => 'إشعار واهتزاز دون صوت';

  @override
  String get adhanScreenOverlineCall => 'حان الآن وقت صلاة';

  @override
  String get adhanScreenOverlinePre => 'استعدّ لصلاة';

  @override
  String get adhanScreenOverlineSunrise => 'انتهى وقت الفجر';

  @override
  String get adhanScreenOverlineSunriseSoon => 'يوشك وقت الفجر أن ينتهي';

  @override
  String adhanScreenSunriseIn(String duration) {
    return 'الشروق بعد $duration';
  }

  @override
  String get adhanScreenOverlineTest => 'تجربة أذان';

  @override
  String adhanScreenAdhanIn(String duration) {
    return 'الأذان بعد $duration';
  }

  @override
  String adhanScreenAdhanAt(String time) {
    return 'يُرفَع الأذان عند $time';
  }

  @override
  String get adhanScreenSoundingCall => 'يُرفَع الأذان الآن';

  @override
  String get adhanScreenSoundingTone => 'التنبيه يصدح الآن';

  @override
  String get adhanScreenSilent => 'أذان صامت';

  @override
  String adhanScreenSemantics(String prayer, String time) {
    return 'أذان $prayer، $time';
  }

  @override
  String get adhanDuaTitle => 'دعاء ما بعد الأذان';

  @override
  String get adhanDuaMeaning => 'يُقال بعد الأذان، مع الصلاة على النبي ﷺ';

  @override
  String adhanDuaSource(String number) {
    return 'رواه البخاري ($number)';
  }

  @override
  String get adhanStop => 'إيقاف الأذان';

  @override
  String get adhanPrayed => 'صلّيتُ';

  @override
  String adhanPrayedNamed(String prayer) {
    return 'صلّيتُ $prayer';
  }

  @override
  String get adhanPrayedDone => 'تقبّل الله منك';

  @override
  String get adhanPrayedFailed => 'تعذّر تسجيل الصلاة';

  @override
  String get adhanClose => 'إغلاق';

  @override
  String adhanSnooze(String minutes) {
    return 'ذكّرني بعد $minutes';
  }

  @override
  String adhanSnoozed(String minutes) {
    return 'سأذكّرك بعد $minutes';
  }

  @override
  String get adhanNextTitle => 'الأذان القادم';

  @override
  String adhanNextIn(String duration) {
    return 'بعد $duration';
  }

  @override
  String get adhanNextNone => 'لا أذان مفعّل';

  @override
  String adhanScheduledCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تنبيه مجدول',
      many: '$count تنبيهًا مجدولًا',
      few: '$count تنبيهات مجدولة',
      two: 'تنبيهان مجدولان',
      one: 'تنبيه واحد مجدول',
      zero: 'لا تنبيهات مجدولة',
    );
    return '$_temp0';
  }

  @override
  String get adhanScheduleWeek =>
      'يبقى الأذان يعمل أسبوعًا كاملًا دون فتح مَدار، وبعد إعادة التشغيل';

  @override
  String get adhanScheduleInexact =>
      'المنبّهات الدقيقة غير مسموحة؛ قد يتأخر الأذان دقائق';

  @override
  String get adhanSectionPrayers => 'الصلوات';

  @override
  String get adhanSectionPrayersHint =>
      'الأذان عند دخول الوقت، وتذكير قبله إن شئت';

  @override
  String get adhanPrayerOff => 'الأذان متوقف';

  @override
  String adhanPrayerReminder(String minutes) {
    return 'تذكير قبل $minutes';
  }

  @override
  String adhanPrayerToggle(String prayer) {
    return 'أذان $prayer';
  }

  @override
  String adhanAlertSheetTitle(String prayer) {
    return 'أذان $prayer';
  }

  @override
  String get adhanAlertCall => 'رفع الأذان عند دخول الوقت';

  @override
  String get adhanAlertReminder => 'تذكير قبل الأذان';

  @override
  String get adhanReminderNone => 'بلا';

  @override
  String get adhanTestThis => 'جرّب هذا الأذان';

  @override
  String get adhanSunrise => 'تنبيه الشروق';

  @override
  String get adhanSunriseHint => 'تنبيه لطيف حين ينتهي وقت الفجر';

  @override
  String get adhanSunriseAt => 'عند الشروق';

  @override
  String adhanSunriseBefore(String minutes) {
    return 'قبله بـ$minutes';
  }

  @override
  String get adhanSectionMuezzin => 'المؤذّن';

  @override
  String get adhanSectionMuezzinHint => 'للفجر صوتٌ خاص إن شئت';

  @override
  String get adhanMuezzinFajr => 'أذان الفجر';

  @override
  String get adhanMuezzinOthers => 'الظهر والعصر والمغرب والعشاء';

  @override
  String get adhanPickerTitleFajr => 'صوت أذان الفجر';

  @override
  String get adhanPickerTitleOthers => 'صوت الأذان';

  @override
  String get adhanPickerTones => 'نغمات مَدار';

  @override
  String get adhanPickerTonesHint =>
      'تنبيهات مركّبة إجرائيًا من أجراس وأوعية غنائية؛ لا صوت بشري فيها ولا لحن أذان';

  @override
  String get adhanPickerYours => 'تسجيلاتك';

  @override
  String get adhanPickerYoursHint =>
      'أرفِق تسجيل أذانٍ تحبّه؛ يُنسخ إلى مَدار ويبقى على جهازك وحده';

  @override
  String get adhanPickerEmpty => 'لم تُرفِق أي تسجيل بعد';

  @override
  String get adhanPickerAttach => 'إرفاق تسجيل';

  @override
  String get adhanPickerNote =>
      'لا يأتي مَدار بتسجيلات أذانٍ بأصوات بشرية، إذ لم نجد تسجيلًا بترخيصٍ مفتوح يمكن التحقّق منه';

  @override
  String get adhanListen => 'استماع';

  @override
  String get adhanListenStop => 'إيقاف الاستماع';

  @override
  String get adhanSelected => 'مختار';

  @override
  String get adhanDone => 'تم';

  @override
  String adhanTestSlotHint(String sound) {
    return 'بصوت $sound';
  }

  @override
  String get adhanMuezzinRename => 'إعادة التسمية';

  @override
  String get adhanMuezzinRenameTitle => 'اسم التسجيل';

  @override
  String get adhanMuezzinNameField => 'الاسم';

  @override
  String adhanMuezzinAdded(String name) {
    return 'أُضيف «$name»';
  }

  @override
  String adhanMuezzinDeleted(String name) {
    return 'حُذف «$name»';
  }

  @override
  String get adhanMuezzinUnsupported =>
      'صيغة غير مدعومة؛ اختر ملفًا صوتيًا شائعًا';

  @override
  String get adhanMuezzinTooLarge => 'الملف كبير جدًا';

  @override
  String get adhanMuezzinUnreadable => 'تعذّرت قراءة الملف';

  @override
  String get adhanMuezzinNoPreview =>
      'تُسمَع هذه الصيغة مع الأذان نفسه؛ جرّبها بـ«جرّب الأذان الآن»';

  @override
  String get adhanMuezzinMissing => 'تسجيل محذوف';

  @override
  String get adhanSectionAlert => 'التنبيه';

  @override
  String get adhanVibrate => 'الاهتزاز';

  @override
  String get adhanVibrateHint => 'يهتزّ الهاتف مع الأذان والتذكير';

  @override
  String get adhanFullScreen => 'شاشة الأذان الكاملة';

  @override
  String get adhanFullScreenHint =>
      'تظهر فوق شاشة القفل وتوقظ الشاشة عند الأذان';

  @override
  String get adhanQuiet => 'سكون الصلاة';

  @override
  String get adhanQuietHint =>
      'تصمت موسيقى الألعاب وأصوات الأجواء مع الأذان وأثناء الصلاة';

  @override
  String get adhanQuietAdhanOnly => 'مع الأذان فقط';

  @override
  String get adhanSnoozeLength => 'مدة التأجيل';

  @override
  String get adhanAlarmVolume => 'مستوى صوت المنبّه';

  @override
  String get adhanAlarmVolumeHint =>
      'يُرفَع الأذان على مستوى صوت المنبّه في هاتفك';

  @override
  String get adhanAlarmMuted => 'صوت المنبّه مكتوم؛ لن يُسمَع الأذان';

  @override
  String get adhanOpenSoundSettings => 'إعدادات الصوت';

  @override
  String get adhanSectionTry => 'تجربة';

  @override
  String get adhanTestNow => 'جرّب الأذان الآن';

  @override
  String get adhanTestHint =>
      'أذانٌ حقيقي بعد لحظات؛ أقفل الشاشة لترى عرضه الكامل';

  @override
  String adhanTestScheduled(String seconds) {
    return 'سيُرفَع الأذان بعد $seconds';
  }

  @override
  String get adhanTestFailed => 'تعذّرت جدولة التجربة؛ تحقّق من الأذونات';

  @override
  String get adhanPermTitle => 'ليُرفَع الأذان في وقته';

  @override
  String get adhanPermSubtitle => 'بضعة أذونات من أندرويد؛ لا يغادر شيءٌ جهازك';

  @override
  String get adhanPermReady => 'الأذان جاهز؛ كل ما يحتاجه مسموح';

  @override
  String get adhanPermNotifications => 'الإشعارات';

  @override
  String get adhanPermNotificationsHint => 'ليُسمَع الأذان ويظهر';

  @override
  String get adhanPermExact => 'المنبّهات الدقيقة';

  @override
  String get adhanPermExactHint => 'ليُرفَع الأذان في الدقيقة نفسها، لا بعدها';

  @override
  String get adhanPermFullScreen => 'الظهور فوق شاشة القفل';

  @override
  String get adhanPermFullScreenHint => 'لتظهر شاشة الأذان والهاتف مقفل';

  @override
  String get adhanPermBattery => 'استثناء من توفير البطارية';

  @override
  String get adhanPermBatteryHint => 'كي لا يوقف النظامُ الأذانَ لتوفير الطاقة';

  @override
  String get adhanPermAllow => 'اسمح';

  @override
  String get adhanPermAllowed => 'مسموح';

  @override
  String get adhanPermOpenSettings => 'الإعدادات';

  @override
  String get adhanPermRefusedHint =>
      'رفضتَه في نافذة أندرويد؛ فعّله من الإعدادات متى شئت';

  @override
  String get adhanPermRequired => 'ضروري';

  @override
  String get adhanPermDeniedHint =>
      'إن رفضتَ الطلب من قبل، فعّله من إعدادات التطبيق';

  @override
  String get trackerTitle => 'متتبّع الصلاة';

  @override
  String get trackerTabToday => 'اليوم';

  @override
  String get trackerTabHistory => 'السجلّ';

  @override
  String get trackerTodayLabel => 'اليوم';

  @override
  String get trackerObligatory => 'الفرائض';

  @override
  String get trackerObligatoryHint =>
      'اضغط لتبديل الحالة، واسحب يمينًا لتسجيلها في وقتها';

  @override
  String get trackerVoluntary => 'النوافل';

  @override
  String get trackerTodayPrayed => 'صلوات اليوم';

  @override
  String trackerOfTotal(String total) {
    return 'من $total';
  }

  @override
  String trackerProgress(String done, String total) {
    return 'صلّيت $done من $total';
  }

  @override
  String get trackerAllDone => 'اكتملت صلواتك الخمس، تقبّل الله';

  @override
  String trackerNextIn(String prayer, String duration) {
    return '$prayer بعد $duration';
  }

  @override
  String get trackerNightLeft => 'حان وقت الصلوات الخمس كلها، والليل للنوافل';

  @override
  String trackerStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يوم',
      many: '$count يومًا',
      few: '$count أيام',
      two: 'يومان',
      one: 'يوم واحد',
      zero: 'لا سلسلة بعد',
    );
    return '$_temp0';
  }

  @override
  String trackerStreakChip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'سلسلة $count يوم',
      many: 'سلسلة $count يومًا',
      few: 'سلسلة $count أيام',
      two: 'سلسلة يومين',
      one: 'سلسلة يوم واحد',
      zero: 'ابدأ سلسلتك اليوم',
    );
    return '$_temp0';
  }

  @override
  String trackerDaysUnit(int count) {
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
  String trackerJamaahCount(String count) {
    return '$count في جماعة';
  }

  @override
  String get trackerStatusPrayed => 'في وقتها';

  @override
  String get trackerStatusLate => 'متأخرة';

  @override
  String get trackerStatusMissed => 'فاتت';

  @override
  String get trackerStatusQada => 'قُضيت';

  @override
  String get trackerStatusDue => 'حان وقتها';

  @override
  String get trackerStatusUnlogged => 'لم تُسجَّل';

  @override
  String get trackerStatusUpcoming => 'لم يحن وقتها';

  @override
  String get trackerStatusVoluntaryDone => 'صلّيتها';

  @override
  String get trackerStatusVoluntaryOpen => 'لم تُصلَّ بعد';

  @override
  String trackerUpcomingIn(String duration) {
    return 'بعد $duration';
  }

  @override
  String trackerTimeLeft(String duration) {
    return 'يبقى $duration';
  }

  @override
  String get trackerActionPrayed => 'صلّيتها في وقتها';

  @override
  String get trackerActionLate => 'صلّيتها متأخرة';

  @override
  String get trackerActionMissed => 'فاتتني';

  @override
  String get trackerActionMadeUp => 'قضيتها';

  @override
  String get trackerActionClear => 'إلغاء التسجيل';

  @override
  String get trackerActionJamaahOn => 'صلّيتها في جماعة';

  @override
  String get trackerActionJamaahOff => 'لم أصلّها في جماعة';

  @override
  String get trackerActionMosqueOn => 'صلّيتها في المسجد';

  @override
  String get trackerActionMosqueOff => 'لم أصلّها في المسجد';

  @override
  String trackerActionMakeUpAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قضيتها كلها',
      two: 'قضيتهما',
      one: 'قضيتها',
    );
    return '$_temp0';
  }

  @override
  String get trackerJamaah => 'جماعة';

  @override
  String get trackerMosque => 'المسجد';

  @override
  String get trackerSwipePrayed => 'صلّيتها';

  @override
  String trackerUndoStatus(String prayer, String status) {
    return '$prayer: $status';
  }

  @override
  String trackerUndoCleared(String prayer) {
    return 'أُلغي تسجيل $prayer';
  }

  @override
  String trackerUndoJamaahOn(String prayer) {
    return '$prayer في جماعة';
  }

  @override
  String trackerUndoJamaahOff(String prayer) {
    return '$prayer من غير جماعة';
  }

  @override
  String trackerUndoMosqueOn(String prayer) {
    return '$prayer في المسجد';
  }

  @override
  String trackerUndoMosqueOff(String prayer) {
    return '$prayer خارج المسجد';
  }

  @override
  String trackerUndoVoluntaryOn(String prayer) {
    return 'تمّ تسجيل $prayer';
  }

  @override
  String trackerUndoVoluntaryOff(String prayer) {
    return 'أُلغي تسجيل $prayer';
  }

  @override
  String trackerUndoMadeUp(String prayer, String date) {
    return 'قُضيت صلاة $prayer ليوم $date';
  }

  @override
  String trackerUndoMadeUpAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قُضيت $count صلاة',
      many: 'قُضيت $count صلاة',
      few: 'قُضيت $count صلوات',
      two: 'قُضيت صلاتان',
      one: 'قُضيت صلاة واحدة',
    );
    return '$_temp0';
  }

  @override
  String trackerNotYet(String prayer) {
    return 'لم يدخل وقت $prayer بعد';
  }

  @override
  String get trackerSunnahFajr => 'سنّة الفجر';

  @override
  String get trackerSunnahDhuhr => 'راتبة الظهر';

  @override
  String get trackerSunnahMaghrib => 'راتبة المغرب';

  @override
  String get trackerSunnahIsha => 'راتبة العشاء';

  @override
  String get trackerDuha => 'الضحى';

  @override
  String get trackerWitr => 'الوتر';

  @override
  String get trackerQiyam => 'قيام الليل';

  @override
  String get trackerSunnahLabel => 'السنّة الراتبة';

  @override
  String trackerRakahBefore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ركعة قبلها',
      many: '$count ركعة قبلها',
      few: '$count ركعات قبلها',
      two: 'ركعتان قبلها',
      one: 'ركعة قبلها',
    );
    return '$_temp0';
  }

  @override
  String trackerRakahAfter(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ركعة بعدها',
      many: '$count ركعة بعدها',
      few: '$count ركعات بعدها',
      two: 'ركعتان بعدها',
      one: 'ركعة بعدها',
    );
    return '$_temp0';
  }

  @override
  String trackerRakahBoth(String before, String after) {
    return '$before و$after';
  }

  @override
  String get trackerDuhaWindow => 'من ارتفاع الشمس إلى الظهر';

  @override
  String get trackerNightWindow => 'من العشاء إلى الفجر';

  @override
  String get trackerStreakCurrent => 'السلسلة الحالية';

  @override
  String get trackerStreakBest => 'أطول سلسلة';

  @override
  String get trackerStreakRule =>
      'يُحتسب اليوم في السلسلة حين تُصلّى الفرائض الخمس أو تُقضى';

  @override
  String get trackerWeekTitle => 'آخر سبعة أيام';

  @override
  String get trackerHeatmapTitle => 'خريطة الشهر';

  @override
  String get trackerLegendLess => 'أقل';

  @override
  String get trackerLegendMore => 'الخمس';

  @override
  String get trackerLegendJamaah => 'النقاط: صلوات الجماعة';

  @override
  String get trackerPrevMonth => 'الشهر السابق';

  @override
  String get trackerNextMonth => 'الشهر التالي';

  @override
  String trackerDaySemantics(
    String date,
    String done,
    String total,
    String jamaah,
  ) {
    return '$date: صلّيت $done من $total، منها $jamaah في جماعة';
  }

  @override
  String trackerTotalsTitle(String month) {
    return 'حصاد $month';
  }

  @override
  String get trackerTotalOnTime => 'في وقتها';

  @override
  String get trackerTotalJamaah => 'في جماعة';

  @override
  String get trackerTotalMosque => 'في المسجد';

  @override
  String get trackerTotalCompleteDays => 'أيام مكتملة';

  @override
  String get trackerTotalRawatib => 'الرواتب';

  @override
  String get trackerTotalSunnahTitle => 'النوافل والسنن';

  @override
  String get trackerBreakdownTitle => 'كل صلاة على حدة';

  @override
  String get trackerNoMonthData => 'لا سجلات في هذا الشهر بعد';

  @override
  String get trackerQadaTitle => 'دفتر القضاء';

  @override
  String trackerQadaOutstanding(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صلاة بانتظار القضاء',
      many: '$count صلاة بانتظار القضاء',
      few: '$count صلوات بانتظار القضاء',
      two: 'صلاتان بانتظار القضاء',
      one: 'صلاة واحدة بانتظار القضاء',
      zero: 'لا صلوات بانتظار القضاء',
    );
    return '$_temp0';
  }

  @override
  String trackerQadaMadeUpSoFar(String count) {
    return 'قُضيت حتى الآن: $count';
  }

  @override
  String get trackerQadaEmpty => 'لا صلوات فائتة تنتظر القضاء، بارك الله فيك';

  @override
  String trackerQadaEmptyFiltered(String prayer) {
    return 'لا قضاء لصلاة $prayer';
  }

  @override
  String trackerQadaMissedOn(String date) {
    return 'فاتت يوم $date';
  }

  @override
  String trackerQadaShowMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'اعرض $count صلاة أخرى',
      many: 'اعرض $count صلاة أخرى',
      few: 'اعرض $count صلوات أخرى',
      two: 'اعرض صلاتين أخريين',
      one: 'اعرض صلاة أخرى',
    );
    return '$_temp0';
  }

  @override
  String get trackerFilterAll => 'الكل';

  @override
  String get trackerCardOpen => 'افتح المتتبّع';

  @override
  String trackerSlotSemantics(String prayer, String time, String status) {
    return '$prayer، $time، $status';
  }

  @override
  String trackerMarks(String first, String second) {
    return '$first، $second';
  }

  @override
  String trackerUntil(String time) {
    return 'حتى $time';
  }

  @override
  String trackerDueNow(String duration) {
    return 'حان وقتها · يبقى $duration';
  }

  @override
  String trackerValueOf(String label, String value) {
    return '$label: $value';
  }

  @override
  String get adhkarTitle => 'الأذكار';

  @override
  String get adhkarTodayTitle => 'أذكار اليوم';

  @override
  String adhkarSetsDoneOf(String done, String total) {
    return '$done من $total';
  }

  @override
  String get adhkarSetsDoneCaption => 'مجموعات مكتملة';

  @override
  String get adhkarCategoryMorning => 'أذكار الصباح';

  @override
  String get adhkarCategoryEvening => 'أذكار المساء';

  @override
  String get adhkarCategoryAfterPrayer => 'أذكار بعد الصلاة';

  @override
  String get adhkarCategorySleep => 'أذكار النوم';

  @override
  String get adhkarCategoryWaking => 'أذكار الاستيقاظ';

  @override
  String get adhkarCategoryMorningHint => 'من الفجر حتى الضحى';

  @override
  String get adhkarCategoryEveningHint => 'من العصر إلى ما بعد المغرب';

  @override
  String get adhkarCategoryAfterPrayerHint => 'عقب السلام من كل فريضة';

  @override
  String get adhkarCategorySleepHint => 'حين تأوي إلى فراشك';

  @override
  String get adhkarCategoryWakingHint => 'حين تستيقظ من نومك';

  @override
  String get adhkarSuggestMorning => 'حان وقت أذكار الصباح';

  @override
  String get adhkarSuggestEvening => 'حان وقت أذكار المساء';

  @override
  String get adhkarSuggestSleep => 'أذكار النوم قبل أن تأوي إلى فراشك';

  @override
  String get adhkarSuggestWaking => 'أذكار الاستيقاظ';

  @override
  String adhkarSuggestAfterPrayer(String prayer) {
    return 'أذكار ما بعد صلاة $prayer';
  }

  @override
  String get adhkarSuggestAllDone => 'أتممتَ أذكار يومك — تقبّل الله';

  @override
  String get adhkarStart => 'ابدأ';

  @override
  String get adhkarContinue => 'تابِع';

  @override
  String adhkarContinueAt(String position) {
    return 'تابِع من الذكر $position';
  }

  @override
  String get adhkarDoneToday => 'تمّت اليوم';

  @override
  String adhkarAfterPrayerProgress(String done, String total) {
    return '$done من $total صلوات';
  }

  @override
  String adhkarItemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ذكر',
      many: '$count ذكرًا',
      few: '$count أذكار',
      two: 'ذكران',
      one: 'ذكر واحد',
    );
    return '$_temp0';
  }

  @override
  String get adhkarMarkDone => 'تمّت قراءتها';

  @override
  String adhkarMarkedDone(String name) {
    return '$name: تمّت — تقبّل الله';
  }

  @override
  String get adhkarRestart => 'البدء من جديد';

  @override
  String adhkarRestarted(String name) {
    return 'بدأت $name من جديد';
  }

  @override
  String get adhkarSourceCredit =>
      'من «حصن المسلم» لسعيد بن علي بن وهف القحطاني';

  @override
  String get adhkarLoadError => 'تعذّر تحميل الأذكار';

  @override
  String get adhkarTasbeehTitle => 'المسبحة';

  @override
  String get adhkarTasbeehCardSubtitle => 'حلقة من الخرز تتقدّم مع كل تسبيحة';

  @override
  String adhkarTasbeehToday(String count) {
    return 'اليوم: $count';
  }

  @override
  String get adhkarRemindersTitle => 'التذكير';

  @override
  String get adhkarReminderMorningLabel => 'ذكّرني بأذكار الصباح بعد الفجر';

  @override
  String get adhkarReminderEveningLabel => 'ذكّرني بأذكار المساء بعد العصر';

  @override
  String adhkarReminderOffset(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes دقيقة',
      many: '$minutes دقيقة',
      few: '$minutes دقائق',
      two: 'دقيقتان',
      one: 'دقيقة',
      zero: 'مع الأذان',
    );
    return '$_temp0';
  }

  @override
  String get adhkarReminderOffsetCaption => 'موعد التذكير بعد الأذان';

  @override
  String get adhkarReminderNote =>
      'تصلك التذكيرات على الجهاز فقط، متى سمحتَ لمَدار بالإشعارات.';

  @override
  String get adhkarReminderMorningTitle => 'أذكار الصباح';

  @override
  String get adhkarReminderMorningBody =>
      'حان وقت أذكار الصباح — ابدأ يومك بذكر الله';

  @override
  String get adhkarReminderEveningTitle => 'أذكار المساء';

  @override
  String get adhkarReminderEveningBody =>
      'حان وقت أذكار المساء — طمأنينةٌ تختم بها نهارك';

  @override
  String adhkarReaderPosition(String index, String total) {
    return '$index من $total';
  }

  @override
  String get adhkarRemaining => 'متبقٍّ';

  @override
  String get adhkarCounterDone => 'تمّ';

  @override
  String get adhkarCounterHint => 'انقر في أي مكان للعدّ';

  @override
  String adhkarCounterSemantics(String done, String total) {
    return 'عُدّ مرة — $done من $total';
  }

  @override
  String adhkarRepeat(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مرة',
      many: '$count مرة',
      few: '$count مرات',
      two: 'مرتان',
      one: 'مرة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get adhkarReadingDone => 'قرأتُها';

  @override
  String get adhkarVirtue => 'فضلها';

  @override
  String get adhkarReference => 'المصدر';

  @override
  String get adhkarMeaning => 'المعنى';

  @override
  String adhkarQuranRef(String surah, String ayahs) {
    return 'سورة $surah: $ayahs';
  }

  @override
  String get adhkarSurah2 => 'البقرة';

  @override
  String get adhkarSurah3 => 'آل عمران';

  @override
  String get adhkarSurah112 => 'الإخلاص';

  @override
  String get adhkarSurah113 => 'الفلق';

  @override
  String get adhkarSurah114 => 'الناس';

  @override
  String adhkarSurahNumber(String number) {
    return 'رقم $number';
  }

  @override
  String get adhkarPrevious => 'الذكر السابق';

  @override
  String get adhkarNext => 'الذكر التالي';

  @override
  String adhkarDhikrSemantics(String index, String total) {
    return 'الذكر $index من $total';
  }

  @override
  String get adhkarOptionsTitle => 'خيارات القراءة';

  @override
  String get adhkarTextSize => 'حجم الخط';

  @override
  String get adhkarTextSizeSmaller => 'تصغير الخط';

  @override
  String get adhkarTextSizeLarger => 'تكبير الخط';

  @override
  String get adhkarShowTranslation => 'إظهار المعنى بالإنجليزية';

  @override
  String get adhkarShowVirtue => 'إظهار الفضل والمصدر';

  @override
  String get adhkarRecountCurrent => 'إعادة عدّ هذا الذكر';

  @override
  String get adhkarRestartSet => 'البدء من أول المجموعة';

  @override
  String get adhkarMarkSetDone => 'قرأتُ المجموعة كلّها';

  @override
  String adhkarAfterPrayerFor(String prayer) {
    return 'بعد صلاة $prayer';
  }

  @override
  String get adhkarChoosePrayer => 'بعد أي صلاة؟';

  @override
  String get adhkarSetCompleteTitle => 'تقبّل الله منك';

  @override
  String adhkarSetCompleteBody(String name) {
    return 'اكتملت $name';
  }

  @override
  String get adhkarSetCompleteReview => 'مراجعة الأذكار';

  @override
  String get adhkarAudioTitle => 'التسجيل الصوتي';

  @override
  String get adhkarAudioAttach => 'إرفاق تسجيل';

  @override
  String get adhkarAudioReplace => 'استبدال';

  @override
  String get adhkarAudioRemove => 'إزالة';

  @override
  String get adhkarAudioRemoved => 'أُزيل التسجيل';

  @override
  String get adhkarAudioAttached => 'أُرفق التسجيل';

  @override
  String get adhkarAudioPlay => 'تشغيل التسجيل';

  @override
  String get adhkarAudioStop => 'إيقاف التسجيل';

  @override
  String get adhkarAudioNone =>
      'لا تسجيل لهذا الذكر بعد. أرفق ملفًا صوتيًا من جهازك (MP3 أو WAV أو FLAC) لتسمعه هنا.';

  @override
  String get adhkarAudioPolicy =>
      'لا يستخدم مَدار أصواتًا مولّدة آليًّا للقرآن أو الأذكار؛ أرفق تسجيلًا تثق به، ويبقى على جهازك.';

  @override
  String get adhkarAudioUnsupported =>
      'هذا الملف ليس بصيغة مدعومة (MP3 أو WAV أو FLAC)';

  @override
  String get adhkarAudioTooLarge => 'الملف أكبر من ٣٠ ميغابايت';

  @override
  String get adhkarAudioUnavailable => 'تعذّر تشغيل الصوت على هذا الجهاز';

  @override
  String adhkarAudioFile(String name, String duration) {
    return '$name، $duration';
  }

  @override
  String get adhkarTasbeehTarget => 'عدد الدورة';

  @override
  String get adhkarTasbeehCustom => 'مخصّص';

  @override
  String get adhkarTasbeehCustomTitle => 'عدد مخصّص للدورة';

  @override
  String get adhkarTasbeehCustomField => 'العدد في كل دورة';

  @override
  String get adhkarTasbeehCustomInvalid => 'أدخل عددًا من ١ إلى ٩٩٩٩';

  @override
  String adhkarTasbeehRound(String round) {
    return 'الدورة $round';
  }

  @override
  String adhkarTasbeehOf(String target) {
    return 'من $target';
  }

  @override
  String adhkarTasbeehTotal(String count) {
    return 'المجموع $count';
  }

  @override
  String get adhkarTasbeehTapHint => 'انقر للتسبيح، واضغط مطوّلًا لإعادة العدّ';

  @override
  String adhkarTasbeehCountSemantics(
    String phrase,
    String count,
    String target,
    String round,
  ) {
    return '$phrase: $count من $target، الدورة $round';
  }

  @override
  String get adhkarTasbeehCountHint => 'انقر نقرتين للتسبيح';

  @override
  String get adhkarTasbeehResetTitle => 'إعادة العدّ؟';

  @override
  String adhkarTasbeehResetBody(String count) {
    return 'يُحفظ عددك ($count) في السجل، ثم يبدأ العدّ من الصفر.';
  }

  @override
  String get adhkarTasbeehReset => 'إعادة العدّ';

  @override
  String get adhkarTasbeehPhrases => 'أذكار المسبحة';

  @override
  String get adhkarTasbeehEditPhrases => 'تعديل الأذكار';

  @override
  String get adhkarTasbeehAddPhrase => 'إضافة ذكر';

  @override
  String get adhkarTasbeehEditPhrase => 'تعديل الذكر';

  @override
  String get adhkarTasbeehPhraseField => 'نص الذكر';

  @override
  String get adhkarTasbeehPhraseDeleted => 'حُذف الذكر';

  @override
  String get adhkarTasbeehNoPhrases => 'أضف ذكرًا لتبدأ التسبيح';

  @override
  String get adhkarTasbeehHistory => 'سجلّ التسبيح';

  @override
  String get adhkarTasbeehHistoryEmpty => 'لم تُسجَّل جلسات بعد';

  @override
  String get adhkarTasbeehSessionDeleted => 'حُذفت الجلسة';

  @override
  String adhkarTasbeehRounds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دورة',
      many: '$count دورة',
      few: '$count دورات',
      two: 'دورتان',
      one: 'دورة واحدة',
      zero: 'دون دورة كاملة',
    );
    return '$_temp0';
  }

  @override
  String get adhkarPhraseSubhanallah => 'سبحان الله';

  @override
  String get adhkarPhraseAlhamdulillah => 'الحمد لله';

  @override
  String get adhkarPhraseAllahuakbar => 'الله أكبر';

  @override
  String get adhkarPhraseTahlil => 'لا إله إلا الله';

  @override
  String get adhkarPhraseIstighfar => 'أستغفر الله';

  @override
  String get adhkarPhraseSubhanallahWaBihamdihi => 'سبحان الله وبحمده';

  @override
  String get adhkarPhraseSubhanallahilAzim => 'سبحان الله العظيم';

  @override
  String get adhkarPhraseHawqala => 'لا حول ولا قوة إلا بالله';

  @override
  String get adhkarPhraseSalawat => 'اللهم صل وسلم على نبينا محمد';

  @override
  String get adhkarAllAdhkar => 'كل الأذكار';

  @override
  String get adhkarShortMorning => 'الصباح';

  @override
  String get adhkarShortEvening => 'المساء';

  @override
  String get adhkarShortAfterPrayer => 'بعد الصلاة';

  @override
  String get adhkarShortSleep => 'النوم';

  @override
  String get adhkarShortWaking => 'الاستيقاظ';

  @override
  String adhkarJoin(String first, String second) {
    return '$first، $second';
  }

  @override
  String adhkarTasbeehChip(String count) {
    return 'المسبحة: $count';
  }

  @override
  String adhkarTodayLine(String suggestion, String done, String total) {
    return '$suggestion (أُنجز $done من $total)';
  }

  @override
  String get adhkarReminderChannelName => 'تذكير الأذكار';

  @override
  String get adhkarReminderChannelDescription =>
      'تذكيرٌ بأذكار الصباح بعد الفجر وبأذكار المساء بعد العصر';

  @override
  String get adhkarReminderPermissionDenied =>
      'إشعارات مَدار متوقفة، فلن يصلك التذكير. يمكنك تفعيلها من إعدادات الجهاز.';

  @override
  String adhkarSuggestDone(String set) {
    String _temp0 = intl.Intl.selectLogic(set, {
      'morning': 'أتممتَ أذكار الصباح — تقبّل الله',
      'evening': 'أتممتَ أذكار المساء — تقبّل الله',
      'sleep': 'أتممتَ أذكار النوم — تصبح على خير',
      'waking': 'أتممتَ أذكار الاستيقاظ — يومٌ مبارك',
      'other': 'أتممتَ الأذكار — تقبّل الله',
    });
    return '$_temp0';
  }

  @override
  String adhkarSuggestAfterPrayerDone(String prayer) {
    return 'أتممتَ أذكار ما بعد صلاة $prayer — تقبّل الله';
  }

  @override
  String faithHubAt(String time) {
    return 'عند $time';
  }

  @override
  String get faithHubHistory => 'سجلّ الصلوات';

  @override
  String get faithHubHistoryHint => 'السلاسل والقضاء والإحصاءات';

  @override
  String get faithHubAdhkarHint => 'حصن المسلم';

  @override
  String get faithHubTasbeehHint => 'عدّاد بالخرز';

  @override
  String get faithHubAdhanHint => 'المؤذّن والتذكير والأذونات';

  @override
  String get faithHubTodayTitle => 'يومك';

  @override
  String get faithHubQuranTitle => 'مع القرآن';

  @override
  String get faithHubQuranIndex => 'الفهرس';

  @override
  String get faithHubToolsTitle => 'أدوات';

  @override
  String get faithHubMushafHint => 'الفهرس والبحث والعلامات';

  @override
  String get faithHubHifzHint => 'مراجعة بالتكرار المتباعد';

  @override
  String get faithHubRecitationHint => 'القرّاء والتكرار والتنزيل';

  @override
  String get faithHubAdhanTool => 'الأذان';

  @override
  String get faithHubHifzAlready => 'هذه الآيات في حفظك من قبل';

  @override
  String get quranTitle => 'القرآن الكريم';

  @override
  String quranSurahTitle(String name) {
    return 'سورة $name';
  }

  @override
  String get quranMakki => 'مكية';

  @override
  String get quranMadani => 'مدنية';

  @override
  String quranAyatCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count آية',
      many: '$count آية',
      few: '$count آيات',
      two: 'آيتان',
      one: 'آية واحدة',
      zero: 'لا آيات',
    );
    return '$_temp0';
  }

  @override
  String quranPageLabel(String page) {
    return 'صفحة $page';
  }

  @override
  String quranPageCounter(String page, String total) {
    return 'صفحة $page من $total';
  }

  @override
  String quranJuzLabel(String juz) {
    return 'الجزء $juz';
  }

  @override
  String quranHizbLabel(String hizb) {
    return 'الحزب $hizb';
  }

  @override
  String quranAyahLabel(String ayah) {
    return 'الآية $ayah';
  }

  @override
  String quranAyahOfSurah(String surah, String ayah) {
    return '$surah، الآية $ayah';
  }

  @override
  String quranJuzHizb(String juz, String hizb) {
    return 'الجزء $juz، الحزب $hizb';
  }

  @override
  String quranQuarter1(String hizb) {
    return 'ربع الحزب $hizb';
  }

  @override
  String quranQuarter2(String hizb) {
    return 'نصف الحزب $hizb';
  }

  @override
  String quranQuarter3(String hizb) {
    return 'ثلاثة أرباع الحزب $hizb';
  }

  @override
  String quranShareRef(String surah, String ayah) {
    return '[$surah: $ayah]';
  }

  @override
  String get quranLoadError => 'تعذّر تحميل المصحف';

  @override
  String get quranRetry => 'إعادة المحاولة';

  @override
  String get quranTabSurahs => 'السور';

  @override
  String get quranTabJuz => 'الأجزاء';

  @override
  String get quranTabBookmarks => 'العلامات';

  @override
  String get quranSearchHint => 'ابحث في القرآن…';

  @override
  String get quranGoTo => 'انتقال';

  @override
  String get quranGoToTitle => 'انتقل إلى';

  @override
  String quranGoToHint(String a, String b, String c) {
    return 'مثل $a أو «البقرة $b» أو «صفحة $c»';
  }

  @override
  String quranGoToNone(String example) {
    return 'لا نتيجة — جرّب رقم سورة وآية مثل $example';
  }

  @override
  String get quranGoToOpen => 'فتح';

  @override
  String get quranBookmarksEmptyTitle => 'لا علامات بعد';

  @override
  String get quranBookmarksEmptyBody =>
      'المس آية في المصحف ثم اختر «علامة» لتحفظ موضعها.';

  @override
  String get quranBookmarkDeleted => 'حُذفت العلامة';

  @override
  String get quranBookmarkSaved => 'حُفظت العلامة';

  @override
  String get quranBookmarkEdit => 'تعديل العلامة';

  @override
  String get quranBookmarkNew => 'علامة جديدة';

  @override
  String get quranBookmarkLabel => 'الاسم';

  @override
  String get quranBookmarkLabelHint => 'مثل: وِرد الفجر';

  @override
  String get quranBookmarkNote => 'ملاحظة';

  @override
  String get quranBookmarkColor => 'اللون';

  @override
  String get quranBookmarkRemove => 'إزالة العلامة';

  @override
  String get quranJuzQuarters => 'أرباع الجزء';

  @override
  String get quranContinueTitle => 'تابع القراءة';

  @override
  String get quranContinueEmpty => 'ابدأ رحلتك مع كتاب الله';

  @override
  String get quranContinueStart => 'ابدأ بالفاتحة';

  @override
  String get quranContinueAction => 'تابع';

  @override
  String quranLastReadAt(String when) {
    return 'آخر قراءة $when';
  }

  @override
  String get quranModeMushaf => 'المصحف';

  @override
  String get quranModeList => 'الآيات';

  @override
  String get quranShowList => 'عرض الآيات';

  @override
  String get quranShowMushaf => 'عرض المصحف';

  @override
  String get quranSettingsTitle => 'إعدادات القراءة';

  @override
  String get quranReaderLayout => 'طريقة العرض';

  @override
  String get quranFontSize => 'حجم الخط';

  @override
  String get quranFontLarger => 'تكبير الخط';

  @override
  String get quranFontSmaller => 'تصغير الخط';

  @override
  String get quranTajweedColors => 'ألوان التجويد';

  @override
  String get quranTajweedSection => 'التجويد';

  @override
  String get quranTajweedLegend => 'دليل الألوان';

  @override
  String get quranTajweedSource => 'مصدر التجويد';

  @override
  String get quranTajweedSourceBundled => 'مدمج في التطبيق';

  @override
  String get quranTajweedSourceQuranCom => 'Quran.com عند تنزيله';

  @override
  String get quranDownloadTajweed => 'تنزيل تجويد هذه السورة من Quran.com';

  @override
  String get quranTranslation => 'الترجمة';

  @override
  String get quranTranslationShow => 'إظهار الترجمة تحت الآيات';

  @override
  String get quranTranslationName => 'الإنجليزية — صحيح إنترناشونال';

  @override
  String get quranTranslationMissing => 'ترجمة هذه السورة غير منزّلة بعد';

  @override
  String get quranDownloadTranslation => 'تنزيل الترجمة';

  @override
  String get quranDownloadNote =>
      'يُنزَّل من Quran.com مرة واحدة ويبقى على جهازك.';

  @override
  String get quranDownloading => 'جارٍ التنزيل…';

  @override
  String get quranDownloaded => 'مُنزَّل';

  @override
  String get quranDownloadOffline => 'لا اتصال بالإنترنت — حاول لاحقًا';

  @override
  String get quranDownloadFailed => 'تعذّر التنزيل، حاول مرة أخرى';

  @override
  String quranNextSurah(String name) {
    return 'التالية: $name';
  }

  @override
  String quranPrevSurah(String name) {
    return 'السابقة: $name';
  }

  @override
  String get quranNowReciting => 'تُتلى الآن';

  @override
  String get quranSajdah => 'سجدة تلاوة';

  @override
  String quranAyahSemantics(String ayah, String surah) {
    return 'الآية $ayah من سورة $surah';
  }

  @override
  String get quranActionPlay => 'استمع من هنا';

  @override
  String get quranActionRepeat => 'كرّر الآية';

  @override
  String quranRepeatTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مرة',
      many: '$count مرة',
      few: '$count مرات',
      two: 'مرتين',
      one: 'مرة',
    );
    return '$_temp0';
  }

  @override
  String get quranActionBookmark => 'علامة';

  @override
  String get quranActionCopy => 'نسخ';

  @override
  String get quranCopied => 'نُسخت الآية';

  @override
  String get quranActionShare => 'مشاركة';

  @override
  String get quranActionHifz => 'أضف إلى الحفظ';

  @override
  String get quranHifzAdded => 'أُضيفت إلى الحفظ';

  @override
  String get quranActionTafsir => 'التفسير';

  @override
  String get quranTafsirSoon => 'التفسير قادم قريبًا بإذن الله';

  @override
  String get quranSoon => 'قريبًا';

  @override
  String get quranSearchTitle => 'البحث في القرآن';

  @override
  String get quranSearchFieldHint => 'كلمة أو جزء من آية';

  @override
  String get quranSearchIntro =>
      'يبحث في النص العربي متجاهلًا التشكيل والهمزات وصور الألف.';

  @override
  String quranSearchResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count آية',
      many: '$count آية',
      few: '$count آيات',
      two: 'آيتان',
      one: 'آية واحدة',
      zero: 'لا نتائج',
    );
    return '$_temp0';
  }

  @override
  String quranSearchOccurrences(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count موضع',
      many: '$count موضعًا',
      few: '$count مواضع',
      two: 'موضعان',
      one: 'موضع واحد',
      zero: 'لا مواضع',
    );
    return '$_temp0';
  }

  @override
  String quranSearchShowingFirst(String count) {
    return 'تُعرض أول $count';
  }

  @override
  String get quranSearchTooShort => 'اكتب حرفين على الأقل';

  @override
  String get quranSearchNoResults => 'لا توجد آية بهذه الكلمات';

  @override
  String get quranSearchPreparing => 'يُجهَّز فهرس البحث…';

  @override
  String get quranLegendTitle => 'دليل ألوان التجويد';

  @override
  String get quranLegendNote =>
      'الألوان عون على التعلّم، والتلقي من قارئ متقن هو الأصل.';

  @override
  String get quranLegendCredits =>
      'النص القرآني من مشروع تنزيل، وعلامات التجويد من مشروع quran-tajweed (CC BY).';

  @override
  String get quranFamilySilent => 'ما لا يُنطق';

  @override
  String get quranFamilyMadd => 'المدود';

  @override
  String get quranFamilyGhunnah => 'الغنة';

  @override
  String get quranFamilyMerge => 'الإدغام بلا غنة';

  @override
  String get quranFamilyQalqalah => 'القلقلة';

  @override
  String get quranRuleHamzatWasl => 'همزة الوصل';

  @override
  String get quranRuleHamzatWaslHint => 'تُكتب ولا تُنطق عند وصل الكلام';

  @override
  String get quranRuleLamShamsiyyah => 'اللام الشمسية';

  @override
  String get quranRuleLamShamsiyyahHint => 'لام «ال» لا تُنطق قبل الحرف الشمسي';

  @override
  String get quranRuleSilent => 'حرف لا يُنطق';

  @override
  String get quranRuleSilentHint => 'يُكتب ولا يُقرأ';

  @override
  String get quranRuleMaddNatural => 'مد طبيعي';

  @override
  String get quranRuleMaddNaturalHint => 'حركتان';

  @override
  String get quranRuleMaddPermissible => 'مد عارض أو لين';

  @override
  String get quranRuleMaddPermissibleHint => 'حركتان أو أربع أو ست عند الوقف';

  @override
  String get quranRuleMaddSeparated => 'مد جائز منفصل';

  @override
  String get quranRuleMaddSeparatedHint => 'أربع أو خمس حركات';

  @override
  String get quranRuleMaddConnected => 'مد واجب متصل';

  @override
  String get quranRuleMaddConnectedHint => 'أربع أو خمس حركات';

  @override
  String get quranRuleMaddNecessary => 'مد لازم';

  @override
  String get quranRuleMaddNecessaryHint => 'ست حركات';

  @override
  String get quranRuleQalqalah => 'قلقلة';

  @override
  String get quranRuleQalqalahHint => 'اضطراب الصوت في حروف «قطب جد» الساكنة';

  @override
  String get quranRuleGhunnah => 'غنة';

  @override
  String get quranRuleGhunnahHint => 'النون والميم المشددتان بغنة حركتين';

  @override
  String get quranRuleIkhfa => 'إخفاء';

  @override
  String get quranRuleIkhfaHint => 'إخفاء النون الساكنة والتنوين مع الغنة';

  @override
  String get quranRuleIkhfaShafawi => 'إخفاء شفوي';

  @override
  String get quranRuleIkhfaShafawiHint => 'الميم الساكنة قبل الباء';

  @override
  String get quranRuleIqlab => 'إقلاب';

  @override
  String get quranRuleIqlabHint =>
      'النون الساكنة والتنوين تُقلب ميمًا قبل الباء';

  @override
  String get quranRuleIdghamGhunnah => 'إدغام بغنة';

  @override
  String get quranRuleIdghamGhunnahHint => 'في حروف «ينمو»';

  @override
  String get quranRuleIdghamShafawi => 'إدغام شفوي';

  @override
  String get quranRuleIdghamShafawiHint => 'الميم الساكنة في الميم';

  @override
  String get quranRuleIdghamNoGhunnah => 'إدغام بلا غنة';

  @override
  String get quranRuleIdghamNoGhunnahHint => 'في اللام والراء';

  @override
  String get quranRuleIdghamMutajanisayn => 'إدغام متجانسين';

  @override
  String get quranRuleIdghamMutajanisaynHint =>
      'حرفان اتفقا مخرجًا واختلفا صفة';

  @override
  String get quranRuleIdghamMutaqaribayn => 'إدغام متقاربين';

  @override
  String get quranRuleIdghamMutaqaribaynHint => 'حرفان تقاربا مخرجًا';

  @override
  String get recitationTitle => 'التلاوة';

  @override
  String get recitationChannelName => 'تلاوة القرآن';

  @override
  String get recitationAlbum => 'القرآن الكريم';

  @override
  String get recitationReciterLabel => 'القارئ';

  @override
  String get recitationSectionReciters => 'القرّاء';

  @override
  String get recitationSectionRecitersHint =>
      'أصوات قرّاء حقيقيين من everyayah.com – لا أصوات مولَّدة للقرآن أبدًا';

  @override
  String get recitationStyleMujawwad => 'مجوَّد';

  @override
  String get recitationStyleMurattal => 'مرتَّل';

  @override
  String get recitationStyleMuallim => 'معلِّم';

  @override
  String get recitationStyleMujawwadHint =>
      'تلاوة متأنّية منغَّمة بأحكام التجويد كاملة';

  @override
  String get recitationStyleMurattalHint => 'ترتيل متّصل هادئ';

  @override
  String get recitationStyleMuallimHint => 'تلاوة تعليمية واضحة للحفظ';

  @override
  String recitationBitrate(String kbps) {
    return '$kbps كيلوبت/ث';
  }

  @override
  String get recitationSample => 'استمع إلى عيّنة';

  @override
  String get recitationSampleStop => 'إيقاف العيّنة';

  @override
  String recitationSampleOf(String name) {
    return 'عيّنة من تلاوة $name';
  }

  @override
  String get recitationChosen => 'القارئ المختار';

  @override
  String recitationChoose(String name) {
    return 'اختيار $name';
  }

  @override
  String recitationSurahsDownloaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count سورة محمّلة',
      many: '$count سورة محمّلة',
      few: '$count سور محمّلة',
      two: 'سورتان محمّلتان',
      one: 'سورة واحدة محمّلة',
      zero: 'لا سور محمّلة',
    );
    return '$_temp0';
  }

  @override
  String get recitationWholeMushafDownloaded => 'المصحف كاملًا محمّل';

  @override
  String get recitationSectionPlayback => 'التكرار والتشغيل';

  @override
  String get recitationSectionPlaybackHint =>
      'الإعدادات الافتراضية لكل تلاوة جديدة';

  @override
  String get recitationRepeatAyah => 'تكرار كل آية';

  @override
  String get recitationRepeatRange => 'تكرار المقطع';

  @override
  String recitationTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مرة',
      many: '$count مرة',
      few: '$count مرات',
      two: 'مرتان',
      one: 'مرة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get recitationEndless => 'بلا توقّف';

  @override
  String get recitationGap => 'مهلة بعد كل تلاوة';

  @override
  String get recitationGapHint => 'وقت لتردّد الآية بعد القارئ';

  @override
  String get recitationGapNone => 'بلا مهلة';

  @override
  String recitationSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ثانية',
      many: '$count ثانية',
      few: '$count ثوانٍ',
      two: 'ثانيتان',
      one: 'ثانية',
    );
    return '$_temp0';
  }

  @override
  String get recitationSpeed => 'السرعة';

  @override
  String recitationSpeedValue(String value) {
    return '$value×';
  }

  @override
  String get recitationBasmala => 'البسملة قبل السور';

  @override
  String get recitationBasmalaHint =>
      'كما في المصحف – عدا الفاتحة (البسملة آيتها الأولى) والتوبة';

  @override
  String get recitationSectionDownloads => 'الاستماع دون اتصال';

  @override
  String get recitationSectionDownloadsHint => 'لا يبدأ أي تنزيل إلا حين تطلبه';

  @override
  String recitationStorageUsed(String size) {
    return 'المساحة المستخدمة: $size';
  }

  @override
  String get recitationWifiOnly => 'التنزيل عبر Wi-Fi فقط';

  @override
  String get recitationWifiOnlyHint =>
      'يتوقف التنزيل حين لا تكون على شبكة Wi-Fi';

  @override
  String recitationMushafFor(String name) {
    return 'المصحف كاملًا بصوت $name';
  }

  @override
  String recitationAbout(String size) {
    return 'نحو $size';
  }

  @override
  String get recitationDownloadMushaf => 'تنزيل المصحف';

  @override
  String get recitationChooseSurahs => 'اختيار السور';

  @override
  String recitationSurahProgress(String done, String total) {
    return '$done من $total سورة';
  }

  @override
  String recitationFilesProgress(String done, String total) {
    return '$done من $total ملف';
  }

  @override
  String get recitationPauseDownloads => 'إيقاف مؤقت';

  @override
  String get recitationResumeDownloads => 'استئناف';

  @override
  String get recitationCancelDownload => 'إلغاء التنزيل';

  @override
  String get recitationDeleteDownloads => 'حذف التنزيلات';

  @override
  String recitationDeleteConfirm(String name) {
    return 'حذف تلاوة $name من الهاتف؟';
  }

  @override
  String recitationDeleteConfirmHint(String size) {
    return 'تُحذف $size. يمكنك تنزيلها مرة أخرى متى شئت.';
  }

  @override
  String recitationDeleteSurahConfirm(String surah) {
    return 'حذف سورة $surah؟';
  }

  @override
  String get recitationOtherDownloads => 'تنزيلات قرّاء آخرين';

  @override
  String recitationDownloadsTitle(String name) {
    return 'تنزيلات $name';
  }

  @override
  String recitationAyatCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count آية',
      many: '$count آية',
      few: '$count آيات',
      two: 'آيتان',
      one: 'آية واحدة',
    );
    return '$_temp0';
  }

  @override
  String get recitationDownloadSurah => 'تنزيل السورة';

  @override
  String get recitationStatusQueued => 'في الانتظار';

  @override
  String get recitationStatusDownloading => 'جارٍ التنزيل';

  @override
  String get recitationStatusPaused => 'متوقّف مؤقتًا';

  @override
  String get recitationStatusWifi => 'بانتظار Wi-Fi';

  @override
  String get recitationStatusFailed => 'تعذّر التنزيل';

  @override
  String get recitationStatusComplete => 'محمّلة';

  @override
  String get recitationErrorNetwork => 'تحقّق من الاتصال ثم استأنف';

  @override
  String get recitationErrorNotFound => 'الملف غير متوفر لدى المصدر';

  @override
  String get recitationErrorStorage => 'لا توجد مساحة كافية على الهاتف';

  @override
  String recitationSizeMb(String size) {
    return '$size ميغابايت';
  }

  @override
  String recitationSizeGb(String size) {
    return '$size غيغابايت';
  }

  @override
  String recitationSizeKb(String size) {
    return '$size كيلوبايت';
  }

  @override
  String get recitationSourceCredit =>
      'التلاوات من everyayah.com – تُبثّ عند التشغيل أو تُنزَّل بطلبك';

  @override
  String recitationSurahNumber(String number) {
    return 'سورة $number';
  }

  @override
  String recitationTitleAyah(String surah, String ayah) {
    return '$surah، الآية $ayah';
  }

  @override
  String recitationTitleBasmala(String surah) {
    return '$surah، البسملة';
  }

  @override
  String recitationAyahNumber(String ayah) {
    return 'الآية $ayah';
  }

  @override
  String get recitationBasmalaNow => 'البسملة';

  @override
  String get recitationNowPlaying => 'يُتلى الآن';

  @override
  String get recitationPlay => 'تشغيل';

  @override
  String get recitationPause => 'إيقاف مؤقت';

  @override
  String get recitationNextAyah => 'الآية التالية';

  @override
  String get recitationPreviousAyah => 'الآية السابقة';

  @override
  String get recitationStop => 'إيقاف التلاوة';

  @override
  String get recitationOpenPlayer => 'فتح المشغّل';

  @override
  String get recitationLoading => 'جارٍ التحميل…';

  @override
  String get recitationPausedPrayer => 'توقّفت للأذان – اضغط للمتابعة';

  @override
  String get recitationPausedInterruption => 'متوقّفة مؤقتًا';

  @override
  String get recitationPausedNoisy => 'توقّفت بعد فصل السمّاعات';

  @override
  String get recitationPausedSleep => 'انتهى مؤقّت النوم';

  @override
  String get recitationPlaybackNetwork =>
      'لا اتصال – نزّل السورة للاستماع دون اتصال';

  @override
  String get recitationPlaybackNotFound => 'هذه الآية غير متوفرة لهذا القارئ';

  @override
  String get recitationPlaybackFailed => 'تعذّر التشغيل';

  @override
  String get recitationRetry => 'إعادة المحاولة';

  @override
  String get recitationOffline => 'من التنزيلات';

  @override
  String get recitationStreaming => 'بثّ';

  @override
  String recitationAyahPass(String pass, String total) {
    return 'التكرار $pass من $total';
  }

  @override
  String recitationRangePass(String pass, String total) {
    return 'الدورة $pass من $total';
  }

  @override
  String recitationRangePassEndless(String pass) {
    return 'الدورة $pass';
  }

  @override
  String get recitationRepeatAyahShort => 'الآية';

  @override
  String get recitationRepeatRangeShort => 'المقطع';

  @override
  String get recitationMore => 'زيادة';

  @override
  String get recitationLess => 'إنقاص';

  @override
  String get recitationSleepTimer => 'مؤقّت النوم';

  @override
  String get recitationSleepOff => 'بلا';

  @override
  String get recitationSleepAfterAyah => 'بعد هذه الآية';

  @override
  String recitationMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دقيقة',
      many: '$count دقيقة',
      few: '$count دقائق',
      two: 'دقيقتان',
      one: 'دقيقة',
    );
    return '$_temp0';
  }

  @override
  String recitationSleepUntil(String time) {
    return 'يتوقف $time';
  }

  @override
  String get recitationChangeReciter => 'تغيير القارئ';

  @override
  String recitationProgress(String percent) {
    return '$percent من المقطع';
  }

  @override
  String recitationRangeLabel(String from, String to) {
    return 'من $from إلى $to';
  }

  @override
  String recitationRangeInSurah(String surah, String from, String to) {
    return '$surah $from–$to';
  }

  @override
  String get recitationBackgroundOff => 'يعمل ما دام مَدار مفتوحًا';

  @override
  String get wirdSep => '، ';

  @override
  String get wirdTitle => 'الوِرد اليومي';

  @override
  String get wirdTodayTitle => 'وِرد اليوم';

  @override
  String get wirdReadNow => 'اقرأ الآن';

  @override
  String get wirdContinue => 'أكمِل القراءة';

  @override
  String get wirdMarkDone => 'أتممتُه';

  @override
  String get wirdStoppedAt => 'توقّفتُ عند…';

  @override
  String get wirdStoppedAtTitle => 'أين توقّفت؟';

  @override
  String get wirdStoppedAtHint => 'حرّك المؤشّر إلى آخر آية قرأتها';

  @override
  String get wirdSaveProgress => 'سجّل';

  @override
  String get wirdDoneToast => 'سُجّل وِرد اليوم، تقبّل الله';

  @override
  String wirdPartialToast(String ayah) {
    return 'سُجّلت قراءتك حتى $ayah';
  }

  @override
  String get wirdMetToday => 'أتممتَ وِرد اليوم، تقبّل الله منك';

  @override
  String get wirdRestToday => 'لا شيء عليك اليوم، فأنت متقدّم على خطّتك';

  @override
  String get wirdPausedNote => 'الخطة متوقّفة مؤقتًا';

  @override
  String wirdNotStarted(String date) {
    return 'تبدأ الخطة $date';
  }

  @override
  String get wirdKhatmaDone => 'ختمتَ القرآن، تقبّل الله منك';

  @override
  String wirdBehindSpread(String amount) {
    return 'متأخّر بمقدار $amount، ووُزِّع على الأيام القادمة';
  }

  @override
  String wirdBehindAll(String amount) {
    return 'متأخّر بمقدار $amount، وأُضيف إلى وِرد اليوم';
  }

  @override
  String wirdAhead(String amount) {
    return 'متقدّم بمقدار $amount، أحسنت';
  }

  @override
  String wirdBehindShort(String amount) {
    return 'متأخّر $amount';
  }

  @override
  String wirdAheadShort(String amount) {
    return 'متقدّم $amount';
  }

  @override
  String wirdTodayLine(String range) {
    return 'اليوم: $range';
  }

  @override
  String wirdPagePosition(String page) {
    return 'عند ص $page';
  }

  @override
  String wirdLeftToday(String amount) {
    return 'بقي $amount';
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
    return 'ص $from–$to';
  }

  @override
  String wirdPageSingle(String page) {
    return 'ص $page';
  }

  @override
  String wirdUnitPages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صفحة',
      many: '$count صفحة',
      few: '$count صفحات',
      two: 'صفحتان',
      one: 'صفحة واحدة',
      zero: 'لا صفحات',
    );
    return '$_temp0';
  }

  @override
  String wirdUnitJuz(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count جزء',
      many: '$count جزءًا',
      few: '$count أجزاء',
      two: 'جزآن',
      one: 'جزء واحد',
      zero: 'لا أجزاء',
    );
    return '$_temp0';
  }

  @override
  String wirdUnitHizb(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حزب',
      many: '$count حزبًا',
      few: '$count أحزاب',
      two: 'حزبان',
      one: 'حزب واحد',
      zero: 'لا أحزاب',
    );
    return '$_temp0';
  }

  @override
  String wirdUnitAyat(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count آية',
      many: '$count آية',
      few: '$count آيات',
      two: 'آيتان',
      one: 'آية واحدة',
      zero: 'لا آيات',
    );
    return '$_temp0';
  }

  @override
  String wirdUnitPagesDecimal(String amount) {
    return '$amount صفحة';
  }

  @override
  String wirdUnitJuzDecimal(String amount) {
    return '$amount جزء';
  }

  @override
  String wirdUnitHizbDecimal(String amount) {
    return '$amount حزب';
  }

  @override
  String wirdDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يوم',
      many: '$count يومًا',
      few: '$count أيام',
      two: 'يومان',
      one: 'يوم واحد',
      zero: 'لا أيام',
    );
    return '$_temp0';
  }

  @override
  String get wirdTemplateKhatma => 'ختمة';

  @override
  String get wirdTemplatePages => 'صفحات';

  @override
  String get wirdTemplateJuz => 'أجزاء';

  @override
  String get wirdTemplateHizb => 'أحزاب';

  @override
  String get wirdTemplateAyat => 'آيات';

  @override
  String wirdSummaryKhatma(String days, String amount) {
    return 'ختمة في $days، $amount يوميًا';
  }

  @override
  String wirdSummaryDaily(String amount) {
    return '$amount يوميًا';
  }

  @override
  String wirdDefaultNameKhatma(String days) {
    return 'ختمة في $days';
  }

  @override
  String wirdDefaultNameDaily(String amount) {
    return '$amount كل يوم';
  }

  @override
  String wirdWindowAfter(String prayer) {
    return 'بعد $prayer';
  }

  @override
  String get wirdWindowDuha => 'وقت الضحى';

  @override
  String get wirdWindowAnytime => 'أي وقت';

  @override
  String get wirdPlansTitle => 'خططي';

  @override
  String get wirdAddPlan => 'خطة جديدة';

  @override
  String get wirdPrimary => 'الأساسية';

  @override
  String get wirdMakePrimary => 'اجعلها الأساسية';

  @override
  String get wirdPause => 'إيقاف مؤقت';

  @override
  String get wirdResume => 'استئناف';

  @override
  String get wirdPaused => 'متوقّفة';

  @override
  String get wirdEdit => 'تعديل';

  @override
  String get wirdDelete => 'حذف';

  @override
  String get wirdDeletedToast => 'حُذفت الخطة';

  @override
  String get wirdPausedToast => 'أُوقفت الخطة مؤقتًا';

  @override
  String get wirdResumedToast => 'استُؤنفت الخطة';

  @override
  String wirdPrimaryToast(String name) {
    return 'صارت «$name» خطّتك الأساسية';
  }

  @override
  String get wirdSavedToast => 'حُفظت الخطة';

  @override
  String wirdCreatedToast(String name) {
    return 'بدأت خطة «$name»، يسّر الله لك';
  }

  @override
  String get wirdEmptyTitle => 'لا خطة وِرد بعد';

  @override
  String get wirdEmptyBody =>
      'اختر ختمة في ثلاثين يومًا أو قدرًا يوميًا يناسبك، ونذكّرك به بعد الصلاة.';

  @override
  String get wirdEmptyAction => 'ابدأ خطة';

  @override
  String get wirdStreak => 'السلسلة';

  @override
  String wirdBestStreak(String days) {
    return 'الأطول: $days';
  }

  @override
  String get wirdFinish => 'الختم المتوقّع';

  @override
  String wirdTargetDate(String date) {
    return 'الموعد $date';
  }

  @override
  String get wirdProgress => 'التقدّم';

  @override
  String wirdKhatmas(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ختمة',
      many: '$count ختمة',
      few: '$count ختمات',
      two: 'ختمتان',
      one: 'ختمة واحدة',
      zero: 'لم تُختم بعد',
    );
    return '$_temp0';
  }

  @override
  String get wirdNoProjection => 'لم يتّضح بعد';

  @override
  String wirdProgressOf(String done, String quota) {
    return '$done من $quota';
  }

  @override
  String wirdProgressOfShort(String quota) {
    return 'من $quota';
  }

  @override
  String get wirdHistoryTitle => 'السجلّ';

  @override
  String get wirdLegendMet => 'أُتمّ';

  @override
  String get wirdLegendPartial => 'بعضه';

  @override
  String get wirdLegendMissed => 'فات';

  @override
  String get wirdLegendRest => 'لا شيء عليه';

  @override
  String get wirdLegendPaused => 'متوقّف';

  @override
  String get wirdPrevMonth => 'الشهر السابق';

  @override
  String get wirdNextMonth => 'الشهر التالي';

  @override
  String get wirdNewPlanTitle => 'خطة وِرد جديدة';

  @override
  String get wirdEditPlanTitle => 'تعديل الخطة';

  @override
  String get wirdPlanSheetSubtitle => 'قليلٌ دائم خيرٌ من كثيرٍ منقطع';

  @override
  String get wirdFieldName => 'الاسم';

  @override
  String get wirdFieldType => 'نوع الخطة';

  @override
  String get wirdFieldDays => 'المدّة';

  @override
  String get wirdFieldCustom => 'أخرى';

  @override
  String get wirdFieldAmount => 'المقدار اليومي';

  @override
  String get wirdFieldStart => 'نقطة البداية';

  @override
  String get wirdFieldStartDate => 'تاريخ البدء';

  @override
  String get wirdStartToday => 'اليوم';

  @override
  String get wirdStartTomorrow => 'غدًا';

  @override
  String wirdFinishesOn(String date) {
    return 'تختم يوم $date';
  }

  @override
  String wirdPerDayPreview(String amount) {
    return 'نحو $amount كل يوم';
  }

  @override
  String get wirdFieldWindow => 'وقت الوِرد';

  @override
  String get wirdFieldCatchUp => 'إذا فاتك شيء';

  @override
  String get wirdCatchUpSpread => 'وزّعه على الأيام';

  @override
  String get wirdCatchUpAll => 'أضِفه إلى اليوم';

  @override
  String get wirdCatchUpSpreadHint =>
      'يُقسَّم ما فاتك على الأيام القادمة فلا يثقل عليك يوم';

  @override
  String get wirdCatchUpAllHint => 'يُضاف ما فاتك كلّه إلى وِرد اليوم التالي';

  @override
  String get wirdFieldRemind => 'ذكّرني بعد الصلاة';

  @override
  String wirdRemindAfter(String minutes) {
    return 'بعد $minutes';
  }

  @override
  String wirdMinutes(int count) {
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
  String get wirdDecrease => 'إنقاص';

  @override
  String get wirdIncrease => 'زيادة';

  @override
  String get wirdSurah => 'السورة';

  @override
  String get wirdAyah => 'الآية';

  @override
  String get wirdStartJuzShortcut => 'أول الجزء';

  @override
  String wirdJuzNumber(String n) {
    return 'الجزء $n';
  }

  @override
  String get wirdChooseSurah => 'اختر السورة';

  @override
  String get wirdSearchSurah => 'ابحث باسم السورة أو رقمها';

  @override
  String get wirdCreate => 'ابدأ الخطة';

  @override
  String get wirdSave => 'حفظ';

  @override
  String get wirdNameRequired => 'اكتب اسمًا للخطة';

  @override
  String get wirdReminderChannelName => 'تذكير الوِرد';

  @override
  String get wirdReminderChannelDescription =>
      'تذكير بوِردك اليومي بعد الصلاة التي تختارها';

  @override
  String get wirdReminderTitle => 'حان وقت وِردك';

  @override
  String wirdReminderBodyToday(String plan, String range) {
    return '$plan: $range';
  }

  @override
  String wirdReminderBody(String plan, String window) {
    return '$plan — $window';
  }

  @override
  String get wirdCatalogError => 'تعذّر تحميل بيانات المصحف';

  @override
  String wirdOverallOf(String percent) {
    return '$percent من الختمة';
  }

  @override
  String wirdPositionIn(String percent) {
    return '$percent من المصحف';
  }

  @override
  String get wirdOpenAll => 'كل الخطط';

  @override
  String get wirdStartPlanCta => 'ابدأ وِردًا يوميًا';

  @override
  String wirdDayStatusSemantics(String date, String status) {
    return '$date: $status';
  }

  @override
  String get hifzTitle => 'الحفظ';

  @override
  String get hifzTodayTitle => 'مراجعة الحفظ';

  @override
  String get hifzStartReview => 'ابدأ المراجعة';

  @override
  String get hifzContinueReview => 'واصل المراجعة';

  @override
  String get hifzNothingDue => 'لا مراجعة اليوم';

  @override
  String get hifzAllCaughtUp => 'راجعتَ كلّ ما استحقّ اليوم، بارك الله فيك';

  @override
  String hifzDueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مقطع للمراجعة',
      many: '$count مقطعًا للمراجعة',
      few: '$count مقاطع للمراجعة',
      two: 'مقطعان للمراجعة',
      one: 'مقطع للمراجعة',
      zero: 'لا مراجعة',
    );
    return '$_temp0';
  }

  @override
  String hifzNewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مقطع جديد',
      many: '$count مقطعًا جديدًا',
      few: '$count مقاطع جديدة',
      two: 'مقطعان جديدان',
      one: 'مقطع جديد',
      zero: 'لا جديد',
    );
    return '$_temp0';
  }

  @override
  String get hifzTabDue => 'المستحق';

  @override
  String get hifzTabNew => 'الجديد';

  @override
  String get hifzTabLearned => 'المحفوظ';

  @override
  String get hifzStatDue => 'اليوم';

  @override
  String get hifzStatLearned => 'محفوظ';

  @override
  String get hifzStatRetention => 'التذكّر';

  @override
  String get hifzStatStreak => 'السلسلة';

  @override
  String hifzRetentionCaption(String days) {
    return 'آخر $days يومًا';
  }

  @override
  String get hifzForecastTitle => 'المراجعات في الأسبوع القادم';

  @override
  String get hifzForecastToday => 'اليوم';

  @override
  String get hifzKindAyat => 'آيات';

  @override
  String get hifzKindHadith => 'حديث';

  @override
  String get hifzKindCustom => 'نص';

  @override
  String hifzDueIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بعد $count يوم',
      many: 'بعد $count يومًا',
      few: 'بعد $count أيام',
      two: 'بعد يومين',
      one: 'غدًا',
      zero: 'اليوم',
    );
    return '$_temp0';
  }

  @override
  String hifzOverdue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'فات موعده منذ $count يوم',
      many: 'فات موعده منذ $count يومًا',
      few: 'فات موعده منذ $count أيام',
      two: 'فات موعده منذ يومين',
      one: 'فات موعده أمس',
    );
    return '$_temp0';
  }

  @override
  String hifzReviews(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مراجعة',
      many: '$count مراجعة',
      few: '$count مراجعات',
      two: 'مراجعتان',
      one: 'مراجعة واحدة',
      zero: 'لم يُراجَع بعد',
    );
    return '$_temp0';
  }

  @override
  String hifzLapses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'نُسي $count مرة',
      many: 'نُسي $count مرة',
      few: 'نُسي $count مرات',
      two: 'نُسي مرتين',
      one: 'نُسي مرة',
    );
    return '$_temp0';
  }

  @override
  String get hifzNewBadge => 'جديد';

  @override
  String get hifzSuspendedBadge => 'معلّق';

  @override
  String get hifzAdd => 'أضِف';

  @override
  String get hifzAddTitle => 'إضافة إلى الحفظ';

  @override
  String get hifzAddSubtitle => 'ما تحفظه اليوم يعود إليك قبل أن يُنسى';

  @override
  String get hifzAddAyat => 'آيات من القرآن';

  @override
  String get hifzAddAyatHint => 'اختر سورة وآيات، وتُقسَّم إلى مقاطع قصيرة';

  @override
  String get hifzAddHadith => 'حديث من الأربعين النووية';

  @override
  String get hifzAddHadithHint => 'اثنان وأربعون حديثًا من جوامع الكلم';

  @override
  String get hifzAddCustom => 'نصّ من اختيارك';

  @override
  String get hifzAddCustomHint => 'دعاء أو متن أو أيّ نصّ تريد حفظه';

  @override
  String get hifzFromAyah => 'من الآية';

  @override
  String get hifzToAyah => 'إلى الآية';

  @override
  String get hifzChunkSize => 'آيات كل مقطع';

  @override
  String hifzChunks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مقطع',
      many: '$count مقطعًا',
      few: '$count مقاطع',
      two: 'مقطعان',
      one: 'مقطع واحد',
      zero: 'لا مقاطع',
    );
    return '$_temp0';
  }

  @override
  String hifzChunkPreview(String chunks, String ranges) {
    return '$chunks: $ranges';
  }

  @override
  String get hifzAddButton => 'أضِف إلى الحفظ';

  @override
  String hifzAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أُضيف $count مقطع إلى الحفظ',
      many: 'أُضيف $count مقطعًا إلى الحفظ',
      few: 'أُضيفت $count مقاطع إلى الحفظ',
      two: 'أُضيف مقطعان إلى الحفظ',
      one: 'أُضيف مقطع إلى الحفظ',
    );
    return '$_temp0';
  }

  @override
  String get hifzInHifz => 'في الحفظ';

  @override
  String get hifzCustomTitle => 'العنوان';

  @override
  String get hifzCustomTitleHint => 'مثلًا: دعاء الاستخارة';

  @override
  String get hifzCustomBody => 'النص';

  @override
  String get hifzCustomSource => 'المصدر (اختياري)';

  @override
  String get hifzBodyRequired => 'اكتب النصّ الذي تريد حفظه';

  @override
  String get hifzEdit => 'تعديل';

  @override
  String get hifzEditTitle => 'تعديل المقطع';

  @override
  String get hifzSuspend => 'تعليق';

  @override
  String get hifzUnsuspend => 'إعادة إلى المراجعة';

  @override
  String get hifzResetProgress => 'البدء فيه من جديد';

  @override
  String get hifzDelete => 'حذف';

  @override
  String get hifzReviewNow => 'راجِعه الآن';

  @override
  String get hifzDeletedToast => 'حُذف من الحفظ';

  @override
  String get hifzSuspendedToast => 'عُلّق المقطع';

  @override
  String get hifzUnsuspendedToast => 'عاد المقطع إلى المراجعة';

  @override
  String get hifzResetToast => 'عاد المقطع جديدًا';

  @override
  String get hifzSavedToast => 'حُفظت التعديلات';

  @override
  String get hifzReviewTitle => 'المراجعة';

  @override
  String hifzReviewProgress(String done, String total) {
    return '$done من $total';
  }

  @override
  String get hifzRecitePrompt => 'اقرأ من حفظك، ثم اكشف النصّ وقيّم نفسك بصدق';

  @override
  String get hifzRevealFirstLetters => 'أوائل الكلمات';

  @override
  String get hifzRevealNextWord => 'الكلمة التالية';

  @override
  String get hifzRevealAll => 'أظهِر النصّ';

  @override
  String get hifzRevealHide => 'أخفِ';

  @override
  String get hifzListen => 'استمع';

  @override
  String get hifzListenStop => 'أوقِف';

  @override
  String hifzRepeatTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مرة',
      many: '$count مرة',
      few: '$count مرات',
      two: 'مرتين',
      one: 'مرة',
    );
    return '$_temp0';
  }

  @override
  String get hifzRedrill => 'نعيده حتى يبلغ «جيد»';

  @override
  String get hifzNewItem => 'مقطع جديد';

  @override
  String get hifzGradePrompt => 'كيف كان استحضارك؟';

  @override
  String get hifzGrade0 => 'نسيته';

  @override
  String get hifzGrade0Hint => 'لم أستحضر شيئًا';

  @override
  String get hifzGrade1 => 'أخطأت';

  @override
  String get hifzGrade1Hint => 'أخطأت، وعرفته حين رأيته';

  @override
  String get hifzGrade2 => 'قريب';

  @override
  String get hifzGrade2Hint => 'أخطأت، وبدا سهلًا حين رأيته';

  @override
  String get hifzGrade3 => 'بصعوبة';

  @override
  String get hifzGrade3Hint => 'صحيح بجهدٍ كبير';

  @override
  String get hifzGrade4 => 'جيد';

  @override
  String get hifzGrade4Hint => 'صحيح بعد تردّد يسير';

  @override
  String get hifzGrade5 => 'متقَن';

  @override
  String get hifzGrade5Hint => 'صحيح بلا تردّد';

  @override
  String get hifzUndoGrade => 'تراجع عن التقييم';

  @override
  String hifzNextReview(String when) {
    return 'المراجعة القادمة $when';
  }

  @override
  String get hifzFinish => 'إنهاء';

  @override
  String get hifzSummaryTitle => 'أتممتَ المراجعة';

  @override
  String get hifzSummarySubtitle => '«خيرُكم من تعلّم القرآن وعلّمه»';

  @override
  String get hifzSummaryReviewed => 'راجعت';

  @override
  String get hifzSummaryNew => 'جديد';

  @override
  String get hifzSummaryAgain => 'أُعيد';

  @override
  String get hifzSummaryRecall => 'تذكّرت';

  @override
  String hifzSummaryTomorrow(String count) {
    return 'غدًا: $count';
  }

  @override
  String get hifzSummaryDone => 'تمّ';

  @override
  String get hifzEmptySession => 'لا شيء للمراجعة الآن';

  @override
  String get hifzEmptyTitle => 'ابدأ رحلة الحفظ';

  @override
  String get hifzEmptyBody =>
      'أضِف آيات أو حديثًا، ويعيدها التكرار المتباعد إليك قبل أن تُنسى.';

  @override
  String get hifzEmptyDue => 'لا شيء مستحقّ اليوم';

  @override
  String get hifzEmptyNew => 'لا مقاطع جديدة تنتظر';

  @override
  String get hifzEmptyLearned => 'تظهر هنا المقاطع بعد أول مراجعة لها';

  @override
  String get hifzSettingsTitle => 'إعدادات الحفظ';

  @override
  String get hifzNewPerDay => 'مقاطع جديدة كل يوم';

  @override
  String get hifzListenRepeat => 'تكرار الاستماع لكل آية';

  @override
  String hifzHadithNumber(String n) {
    return 'الحديث $n';
  }

  @override
  String hifzHadithSource(String collection, String n) {
    return '$collection، $n';
  }

  @override
  String get hifzCatalogError => 'تعذّر تحميل بيانات المصحف';

  @override
  String hifzEase(String value) {
    return 'السهولة $value';
  }

  @override
  String get hifzEveryDay => 'كل يوم';

  @override
  String hifzInterval(String days) {
    return 'كل $days';
  }

  @override
  String get hifzOpenAll => 'كل المقاطع';

  @override
  String get hifzStartCta => 'ابدأ الحفظ';

  @override
  String get qiblaTitle => 'القبلة';

  @override
  String get qiblaFacing => 'اتجاهك الآن إلى القبلة';

  @override
  String qiblaTurnRight(String degrees) {
    return 'استدر يمينًا $degrees';
  }

  @override
  String qiblaTurnLeft(String degrees) {
    return 'استدر يسارًا $degrees';
  }

  @override
  String get qiblaReading => 'جارٍ قراءة البوصلة…';

  @override
  String get qiblaHoldFlat => 'أمسك الهاتف مستويًا أمامك';

  @override
  String get qiblaBearing => 'اتجاه القبلة';

  @override
  String get qiblaDistance => 'المسافة إلى الكعبة';

  @override
  String qiblaKm(String distance) {
    return '$distance كم';
  }

  @override
  String get qiblaYourHeading => 'اتجاهك';

  @override
  String get qiblaSunBearing => 'اتجاه الشمس';

  @override
  String qiblaDeclination(String value, String direction) {
    return 'الانحراف المغناطيسي هنا $value $direction، ويُصحَّح تلقائيًّا بنموذج المجال المغناطيسي العالمي.';
  }

  @override
  String get qiblaEast => 'شرقًا';

  @override
  String get qiblaWest => 'غربًا';

  @override
  String get qiblaAccuracyHigh => 'دقة عالية';

  @override
  String get qiblaAccuracyMedium => 'دقة متوسطة';

  @override
  String get qiblaAccuracyLow => 'دقة منخفضة';

  @override
  String get qiblaAccuracyUnreliable => 'قراءة غير موثوقة';

  @override
  String qiblaAccuracyChip(String level, String error) {
    return '$level، $error';
  }

  @override
  String get qiblaCalibrateTitle => 'عايِر البوصلة';

  @override
  String qiblaCalibrateBody(String eight) {
    return 'حرّك الهاتف في الهواء على شكل الرقم $eight مرّاتٍ قليلة، بعيدًا عن المعادن والمغانط.';
  }

  @override
  String qiblaInterferenceBody(String eight) {
    return 'المجال المغناطيسي هنا مضطرب: ابتعد عن المعادن والأجهزة والمغانط (ومنها أغطية الهاتف المغناطيسية)، ثم حرّك الهاتف على شكل الرقم $eight.';
  }

  @override
  String get qiblaCalibrateLater => 'لاحقًا';

  @override
  String get qiblaCalibrated => 'تمّت معايرة البوصلة';

  @override
  String get qiblaCalibrateAction => 'معايرة';

  @override
  String get qiblaSunTitle => 'بوصلة الشمس';

  @override
  String get qiblaSunHowTo =>
      'قف والشمس أمامك، ووجّه أعلى الهاتف نحوها دون أن تنظر إليها مباشرة؛ عندئذٍ تشير الإبرة الذهبية إلى القبلة.';

  @override
  String qiblaSunRightOf(String degrees) {
    return 'القبلة إلى يمين الشمس بزاوية $degrees';
  }

  @override
  String qiblaSunLeftOf(String degrees) {
    return 'القبلة إلى يسار الشمس بزاوية $degrees';
  }

  @override
  String get qiblaSunAhead => 'القبلة في جهة الشمس تمامًا';

  @override
  String get qiblaSunHigh => 'الشمس عالية الآن، فالتصويب نحوها أقلّ دقة.';

  @override
  String get qiblaDiagramTitle => 'مخطط الاتجاه';

  @override
  String qiblaDiagramHowTo(String degrees) {
    return 'حدّد الشمال ببوصلة، أو ليلًا بالنجم القطبي (الجُدَيّ)، ثم استدر $degrees باتجاه عقارب الساعة.';
  }

  @override
  String qiblaDiagramHowToSouth(String degrees) {
    return 'حدّد الشمال ببوصلة، أو ليلًا بكوكبة الصليب الجنوبي التي تدلّ على الجنوب، ثم استدر $degrees من الشمال باتجاه عقارب الساعة.';
  }

  @override
  String get qiblaNoSensor =>
      'لا يحتوي هذا الهاتف على بوصلة (مستشعر مغناطيسي).';

  @override
  String get qiblaSensorError => 'تعذّرت قراءة البوصلة.';

  @override
  String get qiblaNoReadings => 'لا تصل قراءات من البوصلة.';

  @override
  String get qiblaUseSun => 'استعن بالشمس';

  @override
  String get qiblaUseCompass => 'عُد إلى البوصلة';

  @override
  String get qiblaRetry => 'أعد المحاولة';

  @override
  String get qiblaAtKaaba => 'أنت عند الكعبة المشرّفة، فتوجّه إليها مباشرة.';

  @override
  String get qiblaCardTitle => 'اتجاه القبلة';

  @override
  String get qiblaCardOpen => 'افتح البوصلة';

  @override
  String qiblaFromPlace(String place) {
    return 'من $place';
  }

  @override
  String get qiblaPointN => 'ش';

  @override
  String get qiblaPointNE => 'ش ق';

  @override
  String get qiblaPointE => 'ق';

  @override
  String get qiblaPointSE => 'ج ق';

  @override
  String get qiblaPointS => 'ج';

  @override
  String get qiblaPointSW => 'ج غ';

  @override
  String get qiblaPointW => 'غ';

  @override
  String get qiblaPointNW => 'ش غ';

  @override
  String get qiblaPointNameN => 'الشمال';

  @override
  String get qiblaPointNameNE => 'الشمال الشرقي';

  @override
  String get qiblaPointNameE => 'الشرق';

  @override
  String get qiblaPointNameSE => 'الجنوب الشرقي';

  @override
  String get qiblaPointNameS => 'الجنوب';

  @override
  String get qiblaPointNameSW => 'الجنوب الغربي';

  @override
  String get qiblaPointNameW => 'الغرب';

  @override
  String get qiblaPointNameNW => 'الشمال الغربي';

  @override
  String qiblaDialLabel(String bearing, String point) {
    return 'بوصلة القبلة: القبلة على $bearing نحو $point.';
  }

  @override
  String get medsTitle => 'الأدوية والمكمّلات';

  @override
  String get medsTabToday => 'اليوم';

  @override
  String get medsTabMeds => 'أدويتي';

  @override
  String get medsTabCourses => 'الدورات';

  @override
  String get medsSettingsOpen => 'إعدادات الأدوية';

  @override
  String get medsAddMed => 'دواء جديد';

  @override
  String get medsAddCourse => 'دورة علاجية جديدة';

  @override
  String get medsAddRule => 'قاعدة توقيت جديدة';

  @override
  String get medsKindMedication => 'دواء';

  @override
  String get medsKindSupplement => 'مكمّل';

  @override
  String get medsKindInjection => 'حقنة';

  @override
  String get medsKindOther => 'أخرى';

  @override
  String get medsWithEmptyStomach => 'على الريق';

  @override
  String get medsWithBreakfast => 'مع الفطور';

  @override
  String get medsWithLunch => 'مع الغداء';

  @override
  String get medsWithDinner => 'مع العشاء';

  @override
  String get medsWithBedtime => 'قبل النوم';

  @override
  String get medsWithOther => 'أخرى';

  @override
  String get medsWithPerCourse => 'حسب الدورة';

  @override
  String get medsWithAnytime => 'في أي وقت';

  @override
  String get medsMealBreakfast => 'الفطور';

  @override
  String get medsMealLunch => 'الغداء';

  @override
  String get medsMealDinner => 'وجبة العشاء';

  @override
  String get medsMealBedtime => 'النوم';

  @override
  String get medsMealBreakfastTitle => 'الفطور';

  @override
  String get medsMealLunchTitle => 'الغداء';

  @override
  String get medsMealDinnerTitle => 'العشاء';

  @override
  String get medsMealBedtimeTitle => 'النوم';

  @override
  String medsAnchorAtPrayer(String place) {
    return 'عند $place';
  }

  @override
  String medsAnchorWithMeal(String place) {
    return 'مع $place';
  }

  @override
  String medsAnchorBefore(String place, String duration) {
    return 'قبل $place بـ$duration';
  }

  @override
  String medsAnchorAfter(String place, String duration) {
    return 'بعد $place بـ$duration';
  }

  @override
  String get medsAnchorBedtime => 'عند النوم';

  @override
  String get medsTimes => 'مواعيد الجرعات';

  @override
  String get medsTimesHint =>
      'وقت ثابت، أو موعد يتبع صلاة أو وجبة ويتحرّك معها كل يوم';

  @override
  String get medsAddFixedTime => 'وقت ثابت';

  @override
  String get medsAddAnchoredTime => 'مع صلاة أو وجبة';

  @override
  String medsTimeToday(String time) {
    return 'اليوم $time';
  }

  @override
  String get medsRemoveTime => 'إزالة الموعد';

  @override
  String get medsOffsetBefore => 'قبل';

  @override
  String get medsOffsetAt => 'عند';

  @override
  String get medsOffsetAfter => 'بعد';

  @override
  String get medsAnchorPrayers => 'الصلوات';

  @override
  String get medsAnchorMeals => 'الوجبات';

  @override
  String get medsAnchorPick => 'يتبع';

  @override
  String get medsAnchorOffset => 'التوقيت';

  @override
  String get medsAnchorDone => 'تم';

  @override
  String get medsNoTimesAsNeeded => 'بلا مواعيد: تُسجَّل الجرعة عند أخذها';

  @override
  String get medsEditorNew => 'دواء جديد';

  @override
  String get medsEditorEdit => 'تعديل الدواء';

  @override
  String get medsFieldName => 'الاسم';

  @override
  String get medsFieldNameHint => 'كما هو على العلبة';

  @override
  String get medsFieldNameRequired => 'اكتب الاسم';

  @override
  String get medsFieldKind => 'النوع';

  @override
  String get medsFieldDose => 'الجرعة';

  @override
  String get medsFieldDoseHint => 'كما في الوصفة، مثلًا: ١٠ ملغ أو حبّتان';

  @override
  String get medsFieldAmount => 'الكمية';

  @override
  String get medsFieldUnit => 'الوحدة';

  @override
  String get medsUnitTab => 'حبة';

  @override
  String get medsUnitCap => 'كبسولة';

  @override
  String get medsUnitMg => 'ملغ';

  @override
  String get medsUnitMl => 'مل';

  @override
  String get medsUnitIu => 'وحدة';

  @override
  String get medsUnitDrop => 'نقطة';

  @override
  String get medsUnitPuff => 'بخة';

  @override
  String get medsUnitAmp => 'أمبولة';

  @override
  String get medsFieldTakenWith => 'يؤخذ';

  @override
  String get medsFieldTakenWithNote => 'توضيح';

  @override
  String get medsFieldNotes => 'ملاحظات';

  @override
  String get medsFieldStock => 'المتبقي';

  @override
  String get medsFieldRefillAt => 'نبّهني عند';

  @override
  String get medsStockHint => 'ينقص مع كل «أخذتُها» بقدر الجرعة';

  @override
  String get medsFieldColor => 'اللون';

  @override
  String get medsFieldActive => 'نشط';

  @override
  String get medsFieldActiveHint => 'أوقفه مؤقتًا دون أن تفقد سجلّه';

  @override
  String get medsFieldCourse => 'الدورة العلاجية';

  @override
  String get medsNoCourse => 'بلا دورة';

  @override
  String get medsCourseLinkedHint => 'جرعاته تتبع مراحل الدورة';

  @override
  String get medsTitration => 'جدول التدرّج';

  @override
  String get medsTitrationHint =>
      'الجرعة التي حدّدها طبيبك لكل فترة، من تاريخ إلى آخر';

  @override
  String get medsTitrationAdd => 'خطوة جديدة';

  @override
  String medsTitrationFrom(String date) {
    return 'من $date';
  }

  @override
  String get medsTitrationStop => 'توقّف';

  @override
  String get medsTitrationStopLine => 'تتوقف الجرعات';

  @override
  String get medsTitrationStepDose => 'الجرعة من هذا التاريخ';

  @override
  String get medsTitrationStepTitle => 'خطوة تدرّج';

  @override
  String get medsTitrationNow => 'الحالية';

  @override
  String get medsSave => 'حفظ';

  @override
  String get medsDelete => 'حذف';

  @override
  String get medsMore => 'تفاصيل إضافية';

  @override
  String get medsTodayHeader => 'جرعات اليوم';

  @override
  String medsTodayCount(String taken, String total) {
    return 'أُخذت $taken من $total';
  }

  @override
  String medsNextDose(String name, String time) {
    return 'التالية: $name · $time';
  }

  @override
  String medsDueNowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count جرعة تنتظرك الآن',
      many: '$count جرعة تنتظرك الآن',
      few: '$count جرعات تنتظرك الآن',
      two: 'جرعتان تنتظرانك الآن',
      one: 'جرعة تنتظرك الآن',
    );
    return '$_temp0';
  }

  @override
  String get medsAllAnswered => 'أجبتَ عن كل جرعات اليوم';

  @override
  String get medsNoDosesToday => 'لا جرعات مجدولة اليوم';

  @override
  String get medsEmptyTitle => 'لا أدوية بعد';

  @override
  String get medsEmptyBody =>
      'أضف دواءً أو مكمّلًا بمواعيده، وسيرتّب مَدار جرعاتك حول صلواتك ووجباتك.';

  @override
  String get medsAsNeeded => 'عند الحاجة';

  @override
  String get medsLogNow => 'سجّل جرعة الآن';

  @override
  String get medsAnytimeGroup => 'بلا نافذة';

  @override
  String get medsStateUpcoming => 'قادمة';

  @override
  String get medsStateDue => 'حان وقتها';

  @override
  String get medsStateLate => 'متأخرة';

  @override
  String get medsStateMissed => 'فاتت';

  @override
  String medsStateTakenAt(String time) {
    return 'أُخذت $time';
  }

  @override
  String get medsStateSkipped => 'تُخطّيت';

  @override
  String medsStateSnoozedUntil(String time) {
    return 'مؤجّلة حتى $time';
  }

  @override
  String get medsTake => 'أخذتُها';

  @override
  String get medsSnooze => 'غفوة';

  @override
  String medsSnoozeFor(String duration) {
    return 'غفوة $duration';
  }

  @override
  String get medsSkip => 'تخطّي';

  @override
  String get medsReset => 'إلغاء الإجابة';

  @override
  String medsTookToast(String name) {
    return 'سُجّلت جرعة $name';
  }

  @override
  String medsSkippedToast(String name) {
    return 'تُخطّيت جرعة $name';
  }

  @override
  String medsSnoozedToast(String name, String time) {
    return 'جرعة $name مؤجّلة حتى $time';
  }

  @override
  String get medsResetToast => 'أُلغيت الإجابة';

  @override
  String medsShiftedLater(String duration) {
    return 'أُخّرت $duration لقاعدة توقيت';
  }

  @override
  String medsShiftedEarlier(String duration) {
    return 'قُدّمت $duration لقاعدة توقيت';
  }

  @override
  String get medsPinnedToMeal => 'على موعد الطعام';

  @override
  String get medsPastMidnight => 'بعد منتصف الليل';

  @override
  String medsPartOfCourse(String name) {
    return 'ضمن $name';
  }

  @override
  String medsDoseSemantics(
    String name,
    String dose,
    String time,
    String state,
  ) {
    return '$name، $dose، $time، $state';
  }

  @override
  String medsRefillBanner(String name, String count) {
    return 'بقي $count من $name — حان وقت إعادة التعبئة';
  }

  @override
  String get medsRefilled => 'أعدتُ التعبئة';

  @override
  String medsRefillSheetTitle(String name) {
    return 'إعادة تعبئة $name';
  }

  @override
  String get medsRefillAdded => 'الوحدات المضافة';

  @override
  String medsStockUpdated(String name) {
    return 'حُدّث المتبقي من $name';
  }

  @override
  String medsStockLine(String count) {
    return 'المتبقي $count';
  }

  @override
  String medsRefillAtLine(String count) {
    return 'التنبيه عند $count';
  }

  @override
  String get medsLowStock => 'قارب على النفاد';

  @override
  String get medsConflictsTitle => 'قواعد لم تتحقق';

  @override
  String medsConflictSeparation(
    String a,
    String b,
    String required,
    String actual,
  ) {
    return 'تعذّر ترك $required بين $a و$b؛ الفاصل الآن $actual.';
  }

  @override
  String medsConflictNoMeal(String name) {
    return 'لا وجبة متاحة لجرعة إضافية من $name؛ بقيت في موعدها.';
  }

  @override
  String medsConflictClash(String name) {
    return 'لدى $name قاعدتا طعام مختلفتان؛ طُبّقت الأولى.';
  }

  @override
  String get medsAtTheSameTime => 'في الوقت نفسه';

  @override
  String get medsAlertsTitle => 'تنبيهات دائمة';

  @override
  String get medsAdherence => 'الالتزام';

  @override
  String medsAdherenceRate(String percent) {
    return 'أُخذت $percent من الجرعات';
  }

  @override
  String medsLastDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'آخر $count يوم',
      many: 'آخر $count يومًا',
      few: 'آخر $count أيام',
      two: 'آخر يومين',
      one: 'آخر يوم',
    );
    return '$_temp0';
  }

  @override
  String get medsNoAdherence => 'لا جرعات مستحقة في هذه الفترة';

  @override
  String get medsStatTaken => 'أُخذت';

  @override
  String get medsStatSkipped => 'تُخطّيت';

  @override
  String get medsStatMissed => 'فاتت';

  @override
  String get medsStatLate => 'متأخرة';

  @override
  String medsStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يوم كامل متتالٍ',
      many: '$count يومًا كاملًا متتاليًا',
      few: '$count أيام كاملة متتالية',
      two: 'يومان كاملان متتاليان',
      one: 'يوم كامل',
      zero: 'لا أيام كاملة متتالية بعد',
    );
    return '$_temp0';
  }

  @override
  String medsDayBarSemantics(String date, String taken, String total) {
    return '$date: $taken من $total';
  }

  @override
  String medsDayNothingDue(String date) {
    return '$date: لا جرعات';
  }

  @override
  String get medsHistory => 'السجل';

  @override
  String medsHistoryTitle(String name) {
    return 'سجل $name';
  }

  @override
  String get medsNoHistory => 'لا سجل بعد';

  @override
  String get medsOffSchedule => 'خارج المواعيد';

  @override
  String get medsRecent => 'آخر الجرعات';

  @override
  String get medsPaused => 'متوقف مؤقتًا';

  @override
  String get medsPausedSection => 'متوقفة مؤقتًا';

  @override
  String get medsPause => 'إيقاف مؤقت';

  @override
  String get medsResume => 'استئناف';

  @override
  String get medsDuplicate => 'نسخ';

  @override
  String get medsEdit => 'تعديل';

  @override
  String medsDeletedToast(String name) {
    return 'حُذف $name';
  }

  @override
  String medsPausedToast(String name) {
    return 'أُوقف $name مؤقتًا';
  }

  @override
  String medsResumedToast(String name) {
    return 'استُؤنف $name';
  }

  @override
  String medsDuplicatedToast(String name) {
    return 'نُسخ $name';
  }

  @override
  String medsCopyName(String name) {
    return '$name (نسخة)';
  }

  @override
  String medsTimesPerDay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مرة يوميًا',
      many: '$count مرة يوميًا',
      few: '$count مرات يوميًا',
      two: 'مرتان يوميًا',
      one: 'مرة يوميًا',
      zero: 'بلا مواعيد',
    );
    return '$_temp0';
  }

  @override
  String get medsRulesTitle => 'قواعد التوقيت';

  @override
  String get medsRulesEmpty =>
      'القواعد تُبقي الجرعات على التوقيت الذي حدّدتَه: فاصل بين دواءين، أو موعد قبل الطعام أو بعده.';

  @override
  String get medsRuleKindSeparate => 'فاصل بين دواءين';

  @override
  String get medsRuleKindNotWith => 'لا يؤخذان معًا';

  @override
  String get medsRuleKindBeforeFood => 'قبل الطعام';

  @override
  String get medsRuleKindAfterFood => 'بعد الطعام';

  @override
  String get medsRuleKindWithFood => 'مع الطعام';

  @override
  String get medsRuleKindCustom => 'ملاحظة';

  @override
  String medsRuleSeparateText(String a, String b, String duration) {
    return '$duration على الأقل بين $a و$b';
  }

  @override
  String medsRuleBeforeFoodText(String a, String duration) {
    return '$a قبل الطعام بـ$duration';
  }

  @override
  String medsRuleAfterFoodText(String a, String duration) {
    return '$a بعد الطعام بـ$duration';
  }

  @override
  String medsRuleWithFoodText(String a) {
    return '$a مع الطعام';
  }

  @override
  String medsRuleCustomText(String a, String note) {
    return '$a: $note';
  }

  @override
  String get medsRuleEditorNew => 'قاعدة توقيت جديدة';

  @override
  String get medsRuleEditorEdit => 'تعديل القاعدة';

  @override
  String get medsRuleKind => 'نوع القاعدة';

  @override
  String get medsRuleMedA => 'الدواء';

  @override
  String get medsRuleMedB => 'والدواء الآخر';

  @override
  String get medsRuleMinutes => 'المدة';

  @override
  String get medsRuleNote => 'الملاحظة';

  @override
  String get medsRuleNeedTwo => 'اختر دواءين مختلفين';

  @override
  String get medsRuleNeedMed => 'اختر الدواء';

  @override
  String get medsRuleNeedMeds => 'أضف دواءً أولًا';

  @override
  String get medsRuleNeedNote => 'اكتب الملاحظة';

  @override
  String get medsRuleFoodHint => 'أوقات الطعام من «أوقات الوجبات» في الإعدادات';

  @override
  String get medsRuleDeleted => 'حُذفت القاعدة';

  @override
  String get medsCoursesEmptyTitle => 'لا دورات علاجية';

  @override
  String get medsCoursesEmptyBody =>
      'للحقن والعلاجات على مراحل، مثل: يوميًا، ثم أسبوعيًا، ثم شهريًا.';

  @override
  String get medsCourseEditorNew => 'دورة علاجية جديدة';

  @override
  String get medsCourseEditorEdit => 'تعديل الدورة';

  @override
  String get medsCourseName => 'اسم الدورة';

  @override
  String get medsCourseNameRequired => 'اكتب اسم الدورة';

  @override
  String get medsCourseMed => 'الدواء';

  @override
  String get medsCourseStart => 'تاريخ البدء';

  @override
  String get medsCoursePhases => 'المراحل';

  @override
  String get medsCourseAddPhase => 'مرحلة جديدة';

  @override
  String medsCoursePhaseN(String n) {
    return 'المرحلة $n';
  }

  @override
  String get medsCourseNeedsPhase => 'أضف مرحلة واحدة على الأقل';

  @override
  String get medsFreqDaily => 'يومي';

  @override
  String get medsFreqWeekly => 'أسبوعي';

  @override
  String get medsFreqMonthly => 'شهري';

  @override
  String medsEveryDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'كل $count يوم',
      many: 'كل $count يومًا',
      few: 'كل $count أيام',
      two: 'كل يومين',
      one: 'يوميًا',
    );
    return '$_temp0';
  }

  @override
  String medsEveryWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'كل $count أسبوع',
      many: 'كل $count أسبوعًا',
      few: 'كل $count أسابيع',
      two: 'كل أسبوعين',
      one: 'أسبوعيًا',
    );
    return '$_temp0';
  }

  @override
  String medsEveryMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'كل $count شهر',
      many: 'كل $count شهرًا',
      few: 'كل $count أشهر',
      two: 'كل شهرين',
      one: 'شهريًا',
    );
    return '$_temp0';
  }

  @override
  String get medsPhaseInterval => 'كل';

  @override
  String get medsPhaseCount => 'عدد الجرعات';

  @override
  String get medsPhaseOngoing => 'مستمرة';

  @override
  String get medsPhaseDose => 'جرعة المرحلة';

  @override
  String medsPhaseTimes(String freq, String count) {
    return '$freq × $count';
  }

  @override
  String medsPhaseOngoingLine(String freq) {
    return '$freq باستمرار';
  }

  @override
  String medsCourseDoneOf(String done, String total) {
    return '$done من $total جرعة';
  }

  @override
  String medsCourseDosesSoFar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count جرعة حتى الآن',
      many: '$count جرعة حتى الآن',
      few: '$count جرعات حتى الآن',
      two: 'جرعتان حتى الآن',
      one: 'جرعة واحدة حتى الآن',
      zero: 'لم تبدأ الجرعات',
    );
    return '$_temp0';
  }

  @override
  String medsCoursePhaseProgress(String phase, String done, String total) {
    return 'المرحلة $phase: $done من $total';
  }

  @override
  String medsCoursePhaseOngoingProgress(String phase) {
    return 'المرحلة $phase (مستمرة)';
  }

  @override
  String medsCourseNext(String date) {
    return 'الجرعة التالية $date';
  }

  @override
  String medsCourseStarts(String date) {
    return 'تبدأ $date';
  }

  @override
  String medsCourseFinished(String date) {
    return 'اكتملت في $date';
  }

  @override
  String get medsCourseNoMed => 'اربطها بدواء لتظهر جرعاتها في اليوم';

  @override
  String get medsCourseDeleted => 'حُذفت الدورة';

  @override
  String get medsCoursePaused => 'متوقفة';

  @override
  String get medsCourseActive => 'الدورة نشطة';

  @override
  String get medsCourseTimeline => 'مواعيد الدورة';

  @override
  String medsCourseMoreDates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'و$count موعد آخر',
      many: 'و$count موعدًا آخر',
      few: 'و$count مواعيد أخرى',
      two: 'وموعدان آخران',
      one: 'وموعد آخر',
    );
    return '$_temp0';
  }

  @override
  String get medsToday => 'اليوم';

  @override
  String get medsSettingsTitle => 'إعدادات الأدوية';

  @override
  String get medsMealTimes => 'أوقات الوجبات';

  @override
  String get medsMealTimesHint => 'تربط «مع الفطور» وقواعد الطعام بيومك';

  @override
  String get medsEmptyStomachLead => 'مدة «على الريق» قبل الفطور';

  @override
  String get medsReminders => 'التذكير بالجرعات';

  @override
  String get medsRemindersHint =>
      'إشعار في موعد كل جرعة، فيه: أخذتُها، غفوة، تخطّي';

  @override
  String get medsSnoozeDefault => 'غفوة الإشعار';

  @override
  String get medsLateAfter => 'تُعدّ متأخرة بعد';

  @override
  String get medsNotifyGroup => 'الأدوية';

  @override
  String get medsNotifyChannel => 'مواعيد الجرعات';

  @override
  String get medsNotifyChannelDescription =>
      'تذكير في موعد كل جرعة، مع أزرار: أخذتُها، غفوة، تخطّي';

  @override
  String medsNotifyTitle(String name) {
    return 'حان موعد $name';
  }

  @override
  String medsNotifyAgainTitle(String name) {
    return 'تذكير: $name';
  }

  @override
  String medsNotifyRefillTitle(String name) {
    return '$name: الكمية تقارب النفاد';
  }

  @override
  String medsNotifyRefillBody(String count) {
    return 'بقي $count. حان وقت إعادة التعبئة.';
  }

  @override
  String get medsNotifyFailedTitle => 'لم تُسجَّل الجرعة';

  @override
  String get medsNotifyFailedBody => 'افتح مَدار لتسجيلها.';

  @override
  String get recordTitle => 'السجل الطبي';

  @override
  String get recordTabLabs => 'التحاليل';

  @override
  String get recordTabAppointments => 'المواعيد';

  @override
  String get recordTabConditions => 'الحالات';

  @override
  String get recordTabQuestions => 'الأسئلة';

  @override
  String get recordAdd => 'إضافة';

  @override
  String get recordSave => 'حفظ';

  @override
  String get recordDelete => 'حذف';

  @override
  String get recordNotes => 'ملاحظات';

  @override
  String get recordDate => 'التاريخ';

  @override
  String get recordTime => 'الوقت';

  @override
  String get recordListSeparator => '، ';

  @override
  String get recordToday => 'اليوم';

  @override
  String get recordTomorrow => 'غدًا';

  @override
  String get recordYesterday => 'أمس';

  @override
  String recordInDays(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بعد $n يوم',
      many: 'بعد $n يومًا',
      few: 'بعد $n أيام',
      two: 'بعد يومين',
      one: 'بعد يوم',
    );
    return '$_temp0';
  }

  @override
  String recordDaysAgo(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قبل $n يوم',
      many: 'قبل $n يومًا',
      few: 'قبل $n أيام',
      two: 'قبل يومين',
      one: 'قبل يوم',
    );
    return '$_temp0';
  }

  @override
  String get recordDoctorReport => 'تقرير للطبيب';

  @override
  String get recordSettingsTitle => 'إعدادات السجل';

  @override
  String get recordFlagLow => 'منخفض';

  @override
  String get recordFlagHigh => 'مرتفع';

  @override
  String get recordFlagBorderline => 'حدّي';

  @override
  String get recordFlagBorderlineLow => 'قرب الحدّ الأدنى';

  @override
  String get recordFlagBorderlineHigh => 'قرب الحدّ الأعلى';

  @override
  String get recordFlagInRange => 'ضمن المدى';

  @override
  String get recordFlagNoRange => 'بلا مدى';

  @override
  String get recordFlagQualitative => 'وصفية';

  @override
  String get recordSeverityCritical => 'بالغ الأهمية';

  @override
  String get recordSeverityWarning => 'تنبيه';

  @override
  String get recordSeverityInfo => 'للعلم';

  @override
  String recordRangeBetween(String low, String high) {
    return '$low – $high';
  }

  @override
  String recordRangeUpTo(String high) {
    return 'حتى $high';
  }

  @override
  String recordRangeAtLeast(String low) {
    return 'من $low فأكثر';
  }

  @override
  String get recordTakenWithEmptyStomach => 'على معدة فارغة';

  @override
  String get recordTakenWithBreakfast => 'مع الفطور';

  @override
  String get recordTakenWithLunch => 'مع الغداء';

  @override
  String get recordTakenWithDinner => 'مع العشاء';

  @override
  String get recordTakenWithBedtime => 'قبل النوم';

  @override
  String get recordTakenWithOther => 'أخرى';

  @override
  String get recordTakenWithPerCourse => 'حسب الكورس';

  @override
  String get recordTakenWithAnytime => 'في أي وقت';

  @override
  String get recordPeriod1m => 'شهر';

  @override
  String recordPeriodMonths(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n شهر',
      many: '$n شهرًا',
      few: '$n أشهر',
      two: 'شهران',
      one: 'شهر',
    );
    return '$_temp0';
  }

  @override
  String get recordPeriod12m => 'سنة';

  @override
  String get recordPeriodAll => 'الكل';

  @override
  String get recordSectionAlerts => 'تنبيهات دائمة';

  @override
  String get recordSectionConditions => 'الحالات الصحية';

  @override
  String get recordSectionMedications => 'الأدوية والمكمّلات الحالية';

  @override
  String get recordSectionLabs => 'نتائج التحاليل';

  @override
  String get recordSectionPain => 'ملخّص الألم';

  @override
  String get recordSectionMood => 'ملخّص المزاج والتوتر';

  @override
  String get recordSectionQuestions => 'أسئلة للطبيب';

  @override
  String recordOffsetWeeks(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قبل $n أسبوع',
      many: 'قبل $n أسبوعًا',
      few: 'قبل $n أسابيع',
      two: 'قبل أسبوعين',
      one: 'قبل أسبوع',
    );
    return '$_temp0';
  }

  @override
  String recordOffsetDays(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قبل $n يوم',
      many: 'قبل $n يومًا',
      few: 'قبل $n أيام',
      two: 'قبل يومين',
      one: 'قبل يوم',
    );
    return '$_temp0';
  }

  @override
  String recordOffsetHours(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قبل $n ساعة',
      many: 'قبل $n ساعة',
      few: 'قبل $n ساعات',
      two: 'قبل ساعتين',
      one: 'قبل ساعة',
    );
    return '$_temp0';
  }

  @override
  String recordOffsetMinutes(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قبل $n دقيقة',
      many: 'قبل $n دقيقة',
      few: 'قبل $n دقائق',
      two: 'قبل دقيقتين',
      one: 'قبل دقيقة',
    );
    return '$_temp0';
  }

  @override
  String get recordReportTitle => 'ملخّص صحي للطبيب';

  @override
  String get recordReportNameLabel => 'الاسم';

  @override
  String recordReportGenerated(String date) {
    return 'تاريخ الإعداد $date';
  }

  @override
  String recordReportPeriodLine(String from, String to) {
    return 'الفترة من $from إلى $to';
  }

  @override
  String recordReportPeriodAll(String date) {
    return 'السجل كاملًا حتى $date';
  }

  @override
  String get recordReportFooter =>
      'سجلّ شخصي يدوّنه صاحبه على جهازه. لا يتضمّن تشخيصًا ولا توصية علاجية.';

  @override
  String recordReportPage(String page, String total) {
    return 'صفحة $page من $total';
  }

  @override
  String get recordReportNothing => 'لا شيء مسجّل لهذه الفترة.';

  @override
  String recordConditionSince(String date) {
    return 'منذ $date';
  }

  @override
  String get recordReportColName => 'الاسم';

  @override
  String get recordReportColDose => 'الجرعة';

  @override
  String get recordReportColTimes => 'المواعيد';

  @override
  String get recordReportColWith => 'طريقة الأخذ';

  @override
  String recordReportSupplementName(String name) {
    return '$name – مكمّل';
  }

  @override
  String get recordReportColTest => 'التحليل';

  @override
  String get recordReportColLatest => 'آخر نتيجة';

  @override
  String get recordReportColRange => 'المدى المرجعي';

  @override
  String get recordReportColTrend => 'المسار';

  @override
  String get recordReportColHistory => 'نتائج سابقة';

  @override
  String recordReportLabLegend(String margin) {
    return 'تُقارَن كل نتيجة بالمدى المرجعي الذي أدخلتُه للتحليل. «حدّي» تعني ضمن المدى وعلى بُعد $margin من عرضه عن أحد الحدّين.';
  }

  @override
  String get recordReportEntries => 'عدد التسجيلات';

  @override
  String get recordReportDaysLogged => 'أيام فيها تسجيل';

  @override
  String recordReportPainAverage(String max) {
    return 'متوسط الشدة من $max';
  }

  @override
  String get recordReportPainHighest => 'أعلى شدة سُجّلت';

  @override
  String get recordReportTopLocations => 'أكثر المواضع تكرارًا';

  @override
  String get recordReportTopTriggers => 'أكثر المحفّزات تكرارًا';

  @override
  String recordReportMoodAverage(String max) {
    return 'متوسط المزاج من $max';
  }

  @override
  String recordReportStressAverage(String max) {
    return 'متوسط التوتر من $max';
  }

  @override
  String recordReportAnxietyAverage(String max) {
    return 'متوسط القلق من $max';
  }

  @override
  String recordReportEnergyAverage(String max) {
    return 'متوسط الطاقة من $max';
  }

  @override
  String get recordReportSleepAverage => 'متوسط ساعات النوم';

  @override
  String get recordReportCaffeineAverage => 'متوسط أكواب الكافيين';

  @override
  String get recordReportTopFactors => 'العوامل الأكثر تكرارًا';

  @override
  String recordReportQuestionFor(String title, String date) {
    return 'لموعد $title في $date';
  }

  @override
  String get recordLabUncategorized => 'أخرى';

  @override
  String recordReminderTitle(String title) {
    return 'موعد طبي: $title';
  }

  @override
  String recordReminderIn(String duration) {
    return 'بعد $duration';
  }

  @override
  String get recordReminderGroup => 'الصحة';

  @override
  String get recordReminderChannelName => 'مواعيد الطبيب';

  @override
  String get recordReminderChannelDescription => 'تذكير قبل مواعيدك الطبية';

  @override
  String recordDateAtTime(String date, String time) {
    return '$date، الساعة $time';
  }

  @override
  String get recordSavedToast => 'حُفظت التعديلات';

  @override
  String get recordReorder => 'ترتيب';

  @override
  String get recordReorderDone => 'تمّ الترتيب';

  @override
  String get recordReordered => 'تغيّر الترتيب';

  @override
  String get recordAlertAdd => 'إضافة تنبيه دائم';

  @override
  String get recordAlertEdit => 'تعديل التنبيه';

  @override
  String get recordAlertSubtitle => 'ما يجب أن يعرفه أي طبيب قبل كل شيء';

  @override
  String get recordAlertBody => 'نص التنبيه';

  @override
  String get recordAlertBodyHint => 'مثلًا: حساسية من البنسلين';

  @override
  String get recordAlertSeverity => 'الأهمية';

  @override
  String get recordAlertPinned => 'مثبّت في أعلى صفحات الصحة';

  @override
  String get recordAlertPinnedHint => 'يظهر دائمًا فوق شاشات الصحة';

  @override
  String get recordAlertUnpin => 'إلغاء التثبيت';

  @override
  String get recordAlertAdded => 'أُضيف التنبيه';

  @override
  String get recordAlertDeleted => 'حُذف التنبيه';

  @override
  String get recordAlertPinnedToast => 'ثُبّت التنبيه في الأعلى';

  @override
  String get recordAlertUnpinnedToast => 'أُلغي تثبيت التنبيه';

  @override
  String get recordAlertsManage => 'إدارة';

  @override
  String get recordAlertsManagerSubtitle =>
      'اسحب لترتيبها، وثبّت ما تريد رؤيته دائمًا';

  @override
  String get recordAlertsEmptyHint =>
      'حساسية، أو دواء لا يناسبك، أو معلومة يجب ألّا تغيب عن أي طبيب.';

  @override
  String recordAlertsMore(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n تنبيه آخر',
      many: '$n تنبيهًا آخر',
      few: '$n تنبيهات أخرى',
      two: 'تنبيهان آخران',
      one: 'تنبيه آخر',
    );
    return '$_temp0';
  }

  @override
  String get recordConditionAdd => 'إضافة حالة';

  @override
  String get recordConditionEdit => 'تعديل الحالة';

  @override
  String get recordConditionName => 'الحالة';

  @override
  String get recordConditionSinceLabel => 'منذ';

  @override
  String get recordConditionActive => 'نشطة حاليًا';

  @override
  String get recordConditionInactive => 'غير نشطة';

  @override
  String get recordConditionMarkInactive => 'تعليمها غير نشطة';

  @override
  String get recordConditionMarkActive => 'تعليمها نشطة';

  @override
  String get recordConditionMarkedInactive => 'صارت الحالة غير نشطة';

  @override
  String get recordConditionMarkedActive => 'صارت الحالة نشطة';

  @override
  String get recordConditionAdded => 'أُضيفت الحالة';

  @override
  String get recordConditionDeleted => 'حُذفت الحالة';

  @override
  String get recordConditionsEmpty => 'لا حالات مسجّلة';

  @override
  String get recordConditionsEmptyBody =>
      'سجّل حالاتك الصحية مع تاريخ بدايتها وملاحظاتك، لتكون حاضرة في أي زيارة.';

  @override
  String get recordConditionsInactiveHeader => 'حالات غير نشطة';

  @override
  String get recordLabVisit => 'زيارة مختبر';

  @override
  String get recordLabVisitSubtitle => 'نتائج عدة تحاليل بتاريخ واحد';

  @override
  String get recordLabVisitDate => 'تاريخ التحاليل';

  @override
  String get recordLabVisitSaveNone => 'أدخل نتيجة واحدة على الأقل';

  @override
  String recordLabVisitSave(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'حفظ $n نتيجة',
      many: 'حفظ $n نتيجة',
      few: 'حفظ $n نتائج',
      two: 'حفظ نتيجتين',
      one: 'حفظ نتيجة واحدة',
    );
    return '$_temp0';
  }

  @override
  String recordLabVisitSaved(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'حُفظت $n نتيجة',
      many: 'حُفظت $n نتيجة',
      few: 'حُفظت $n نتائج',
      two: 'حُفظت نتيجتان',
      one: 'حُفظت نتيجة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get recordLabAddTest => 'تحليل جديد';

  @override
  String get recordLabEditTest => 'تعديل التحليل';

  @override
  String get recordLabTestSubtitle => 'اكتب المدى المرجعي كما في ورقة مختبرك';

  @override
  String get recordLabTestName => 'اسم التحليل';

  @override
  String get recordLabUnit => 'الوحدة';

  @override
  String get recordLabUnitHint => 'مثلًا mg/dL';

  @override
  String get recordLabLow => 'الحدّ الأدنى للمدى';

  @override
  String get recordLabHigh => 'الحدّ الأعلى للمدى';

  @override
  String get recordLabRangeInvalid => 'الحدّ الأدنى أكبر من الأعلى';

  @override
  String get recordLabCategory => 'الفئة';

  @override
  String get recordLabTestAdded => 'أُضيف التحليل';

  @override
  String get recordLabTestDeleted => 'حُذف التحليل مع نتائجه';

  @override
  String get recordLabTestGone => 'لم يعد هذا التحليل موجودًا';

  @override
  String get recordLabAddReading => 'إضافة نتيجة';

  @override
  String get recordLabEditReading => 'تعديل النتيجة';

  @override
  String get recordLabValue => 'النتيجة';

  @override
  String recordLabValueWithUnit(String unit) {
    return 'النتيجة بوحدة $unit';
  }

  @override
  String get recordLabValueHint => 'رقم، أو نتيجة وصفية مثل «سلبي»';

  @override
  String get recordLabNote => 'ملاحظة';

  @override
  String get recordLabReadingAdded => 'أُضيفت النتيجة';

  @override
  String get recordLabReadingDeleted => 'حُذفت النتيجة';

  @override
  String get recordLabsEmpty => 'لا تحاليل بعد';

  @override
  String get recordLabsEmptyBody =>
      'أنشئ تحاليلك مرة واحدة بمداها المرجعي، ثم سجّل نتائج كل زيارة لترى مسارها.';

  @override
  String get recordLabNoReadings => 'لا نتائج';

  @override
  String get recordLabNoReadingsBody => 'لم تُسجَّل نتائج لهذا التحليل بعد.';

  @override
  String get recordLabNoRange => 'بلا مدى مرجعي';

  @override
  String get recordLabRangeLabel => 'المدى المرجعي';

  @override
  String get recordLabLatest => 'آخر نتيجة';

  @override
  String recordLabChange(String delta) {
    return '$delta عن النتيجة السابقة';
  }

  @override
  String get recordLabHistory => 'كل النتائج';

  @override
  String get recordLabChartEmpty => 'لا نتائج رقمية في هذه الفترة';

  @override
  String recordLabChartSemantics(String name, int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'مسار $name: $n نتيجة',
      many: 'مسار $name: $n نتيجة',
      few: 'مسار $name: $n نتائج',
      two: 'مسار $name: نتيجتان',
      one: 'مسار $name: نتيجة واحدة',
    );
    return '$_temp0';
  }

  @override
  String recordLabReadingsCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n نتيجة',
      many: '$n نتيجة',
      few: '$n نتائج',
      two: 'نتيجتان',
      one: 'نتيجة واحدة',
      zero: 'لا نتائج',
    );
    return '$_temp0';
  }

  @override
  String recordLabTestsCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n تحليل',
      many: '$n تحليلًا',
      few: '$n تحاليل',
      two: 'تحليلان',
      one: 'تحليل واحد',
    );
    return '$_temp0';
  }

  @override
  String recordLabMarginNote(String margin) {
    return '«حدّي» يعني: ضمن المدى وعلى بُعد $margin من عرضه عن أحد الحدّين. يمكنك تغيير النسبة من إعدادات السجل.';
  }

  @override
  String get recordLabFlagsTitle => 'التحاليل';

  @override
  String recordLabFlaggedCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n نتيجة خارج المدى أو قربه',
      many: '$n نتيجة خارج المدى أو قربه',
      few: '$n نتائج خارج المدى أو قربه',
      two: 'نتيجتان خارج المدى أو قربه',
      one: 'نتيجة خارج المدى أو قربه',
    );
    return '$_temp0';
  }

  @override
  String get recordLabAllInRange =>
      'آخر نتائج تحاليلك كلها ضمن المدى الذي أدخلته.';

  @override
  String get recordAppointmentsTitle => 'المواعيد الطبية';

  @override
  String get recordAppointmentAdd => 'موعد جديد';

  @override
  String get recordAppointmentEdit => 'تعديل الموعد';

  @override
  String get recordAppointmentTitleField => 'الموعد';

  @override
  String get recordAppointmentTitleHint => 'مثلًا: مراجعة دورية';

  @override
  String get recordAppointmentDoctor => 'الطبيب';

  @override
  String get recordAppointmentPlace => 'المكان';

  @override
  String get recordAppointmentDone => 'تمّ';

  @override
  String get recordAppointmentMarkDone => 'تمّ الموعد';

  @override
  String get recordAppointmentMarkUndone => 'لم يتمّ بعد';

  @override
  String get recordAppointmentDoneToast => 'سُجّل الموعد كمنجز';

  @override
  String get recordAppointmentUndoneToast => 'أُعيد الموعد إلى القادمة';

  @override
  String get recordAppointmentAdded => 'أُضيف الموعد';

  @override
  String get recordAppointmentDeleted => 'حُذف الموعد، وبقيت أسئلته';

  @override
  String get recordAppointmentUpcoming => 'القادمة';

  @override
  String get recordAppointmentPast => 'السابقة';

  @override
  String get recordAppointmentShowAll => 'كل المواعيد';

  @override
  String get recordAppointmentsEmpty => 'لا مواعيد قادمة';

  @override
  String get recordAppointmentsEmptyBody =>
      'أضف موعدك القادم لتصلك تذكرة قبله، وتبقى أسئلتك للطبيب معه.';

  @override
  String get recordNextAppointment => 'الموعد القادم';

  @override
  String recordAppointmentQuestions(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n سؤال بانتظاره',
      many: '$n سؤالًا بانتظاره',
      few: '$n أسئلة بانتظاره',
      two: 'سؤالان بانتظاره',
      one: 'سؤال واحد بانتظاره',
    );
    return '$_temp0';
  }

  @override
  String get recordQuestionAdd => 'سؤال جديد';

  @override
  String get recordQuestionAddForVisit => 'أضف سؤالًا لهذه الزيارة';

  @override
  String get recordQuestionEdit => 'تعديل السؤال';

  @override
  String get recordQuestionField => 'السؤال';

  @override
  String get recordQuestionAppointment => 'لأي موعد؟';

  @override
  String get recordQuestionGeneral => 'سؤال عام';

  @override
  String get recordQuestionAnswered => 'تمّت الإجابة';

  @override
  String get recordQuestionAnswer => 'الإجابة';

  @override
  String get recordQuestionAnswerOptional => 'الإجابة (اختياري)';

  @override
  String get recordQuestionMarkAnswered => 'أُجيب عنه';

  @override
  String get recordQuestionReopen => 'إعادة فتح السؤال';

  @override
  String get recordQuestionAdded => 'أُضيف السؤال';

  @override
  String get recordQuestionDeleted => 'حُذف السؤال';

  @override
  String get recordQuestionAnsweredToast => 'سُجّلت الإجابة';

  @override
  String get recordQuestionReopened => 'أُعيد فتح السؤال';

  @override
  String get recordQuestionsEmpty => 'لا أسئلة بعد';

  @override
  String get recordQuestionsEmptyBody =>
      'دوّن ما تريد سؤاله حين يخطر لك، حتى لا يضيع في العيادة.';

  @override
  String get recordQuestionsGeneralHeader => 'أسئلة عامة';

  @override
  String get recordQuestionsAnsweredHeader => 'أُجيب عنها';

  @override
  String recordQuestionsMore(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'و$n سؤال آخر',
      many: 'و$n سؤالًا آخر',
      few: 'و$n أسئلة أخرى',
      two: 'وسؤالان آخران',
      one: 'وسؤال آخر',
    );
    return '$_temp0';
  }

  @override
  String get recordReportSheetSubtitle => 'ملف PDF مرتّب للطباعة أو المشاركة';

  @override
  String get recordReportNameField => 'الاسم في رأس التقرير';

  @override
  String get recordReportNameHint => 'يُطبع فقط، ولا يُحفظ';

  @override
  String get recordReportRememberName => 'تذكّر الاسم';

  @override
  String get recordReportRememberHint => 'يُحفظ على هذا الجهاز فقط';

  @override
  String get recordReportPeriodField => 'الفترة';

  @override
  String get recordReportSectionsField => 'الأقسام';

  @override
  String get recordReportPrivacyNote =>
      'يُنشأ التقرير على جهازك، ولا يغادره إلا إذا شاركته بنفسك.';

  @override
  String get recordReportShare => 'مشاركة';

  @override
  String get recordReportSave => 'حفظ ملف';

  @override
  String get recordReportBuilding => 'جارٍ إعداد التقرير…';

  @override
  String get recordReportSaved => 'حُفظ التقرير';

  @override
  String get recordReportFailed => 'تعذّر إعداد التقرير، حاول مجددًا';

  @override
  String get recordSettingsMargin => 'هامش «حدّي» قرب كل حدّ';

  @override
  String get recordSettingsReminders => 'تذكير المواعيد';

  @override
  String get recordSettingsRemindersHint => 'إشعار قبل كل موعد طبي';

  @override
  String get recordSettingsReminderTimes => 'متى أُذكَّر';

  @override
  String get wbTitle => 'العافية';

  @override
  String get wbTabToday => 'اليوم';

  @override
  String get wbTabPain => 'الألم';

  @override
  String get wbTabHabits => 'العادات';

  @override
  String get wbTabWorries => 'الهموم';

  @override
  String get wbTabInsights => 'رؤى';

  @override
  String get wbAdd => 'إضافة';

  @override
  String get wbCancel => 'إلغاء';

  @override
  String get wbSave => 'حفظ';

  @override
  String get wbDelete => 'حذف';

  @override
  String get wbEdit => 'تعديل';

  @override
  String get wbClose => 'إغلاق';

  @override
  String get wbOpen => 'فتح';

  @override
  String get wbEditList => 'تعديل القائمة';

  @override
  String get wbShowAll => 'عرض الكل';

  @override
  String get wbShowLess => 'عرض أقل';

  @override
  String get wbNotes => 'ملاحظات';

  @override
  String get wbWhen => 'الوقت';

  @override
  String get wbNow => 'الآن';

  @override
  String get wbToday => 'اليوم';

  @override
  String get wbYesterday => 'أمس';

  @override
  String wbDayAtTime(String day, String time) {
    return '$day، $time';
  }

  @override
  String get wbListSeparator => '، ';

  @override
  String get wbLess => 'أقل';

  @override
  String get wbMore => 'أكثر';

  @override
  String wbOutOf(String value, String max) {
    return '$value من $max';
  }

  @override
  String wbOutOfMax(String max) {
    return 'من $max';
  }

  @override
  String wbFraction(String done, String total) {
    return '$done من $total';
  }

  @override
  String get wbMetricMood => 'المزاج';

  @override
  String get wbMetricStress => 'التوتر';

  @override
  String get wbMetricAnxiety => 'القلق';

  @override
  String get wbMetricEnergy => 'الطاقة';

  @override
  String get wbMetricSleep => 'النوم';

  @override
  String get wbMetricCaffeine => 'الكافيين';

  @override
  String get wbMetricPain => 'الألم';

  @override
  String wbMetricYour(String metric) {
    String _temp0 = intl.Intl.selectLogic(metric, {
      'mood': 'تقييم مزاجك',
      'stress': 'توترك',
      'anxiety': 'قلقك',
      'energy': 'طاقتك',
      'sleep': 'ساعات نومك',
      'caffeine': 'أكواب الكافيين',
      'pain': 'ألمك',
      'other': 'القيمة',
    });
    return '$_temp0';
  }

  @override
  String get wbMood1 => 'ثقيل';

  @override
  String get wbMood2 => 'منخفض';

  @override
  String get wbMood3 => 'معتدل';

  @override
  String get wbMood4 => 'طيّب';

  @override
  String get wbMood5 => 'مُشرق';

  @override
  String get wbMoodQuestion => 'كيف حالك اليوم؟';

  @override
  String get wbCheckInPrompt =>
      'اختر وجهًا لتسجيل سريع، أو سجّل التوتر والنوم والطاقة معًا.';

  @override
  String get wbCheckInFull => 'تسجيل كامل';

  @override
  String get wbCheckInTitle => 'تسجيل المزاج والتوتر';

  @override
  String get wbCheckInEditTitle => 'تعديل التسجيل';

  @override
  String get wbCheckInSubtitle => 'كل الحقول اختيارية؛ سجّل ما يناسبك.';

  @override
  String get wbCheckInAnother => 'تسجيل آخر';

  @override
  String get wbCheckedIn => 'تم التسجيل';

  @override
  String get wbTodayCheckIn => 'تسجيل اليوم';

  @override
  String get wbCheckInDeleted => 'حُذف التسجيل';

  @override
  String get wbMoodNotesHint => 'ما الذي أثّر في يومك؟';

  @override
  String get wbScaleCalm => 'هادئ';

  @override
  String get wbScaleVeryHigh => 'مرتفع جدًا';

  @override
  String get wbScaleNone => 'لا شيء';

  @override
  String get wbScaleDrained => 'مستنزَف';

  @override
  String get wbScaleFull => 'ممتلئ';

  @override
  String get wbSleepHours => 'ساعات النوم';

  @override
  String get wbCaffeine => 'أكواب الكافيين';

  @override
  String get wbFactors => 'ما الذي أثّر';

  @override
  String wbHours(String n) {
    return '$n س';
  }

  @override
  String wbCups(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n كوب',
      many: '$n كوبًا',
      few: '$n أكواب',
      two: 'كوبان',
      one: 'كوب واحد',
      zero: 'لا أكواب',
    );
    return '$_temp0';
  }

  @override
  String wbDaysRange(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n يوم',
      many: '$n يومًا',
      few: '$n أيام',
      two: 'يومان',
      one: 'يوم',
    );
    return '$_temp0';
  }

  @override
  String wbDayCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n يوم',
      many: '$n يومًا',
      few: '$n أيام',
      two: 'يومان',
      one: 'يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String wbMinutes(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n دقيقة',
      many: '$n دقيقة',
      few: '$n دقائق',
      two: 'دقيقتان',
      one: 'دقيقة',
    );
    return '$_temp0';
  }

  @override
  String wbTimes(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n مرة',
      many: '$n مرة',
      few: '$n مرات',
      two: 'مرتان',
      one: 'مرة واحدة',
    );
    return '$_temp0';
  }

  @override
  String wbPointsCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n نقطة على الخريطة',
      many: '$n نقطة على الخريطة',
      few: '$n نقاط على الخريطة',
      two: 'نقطتان على الخريطة',
      one: 'نقطة على الخريطة',
    );
    return '$_temp0';
  }

  @override
  String get wbPainLogTitle => 'تسجيل ألم';

  @override
  String get wbPainEditTitle => 'تعديل تسجيل الألم';

  @override
  String get wbPainLogSubtitle => 'من «لا ألم» إلى «أشدّ ما يكون»';

  @override
  String get wbPainScore => 'شدة الألم';

  @override
  String get wbPainNone => 'لا ألم';

  @override
  String get wbPainMild => 'خفيف';

  @override
  String get wbPainModerate => 'متوسط';

  @override
  String get wbPainSevere => 'شديد';

  @override
  String get wbPainWorst => 'أشدّ ما يكون';

  @override
  String get wbBodyMap => 'خريطة الجسم';

  @override
  String get wbBodyMapHint =>
      'المس موضع الألم لتضع نقطة، والمسها ثانيةً لإزالتها.';

  @override
  String wbBodyMapSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'خريطة الجسم، عليها $count نقطة',
      many: 'خريطة الجسم، عليها $count نقطة',
      few: 'خريطة الجسم، عليها $count نقاط',
      two: 'خريطة الجسم، عليها نقطتان',
      one: 'خريطة الجسم، عليها نقطة واحدة',
      zero: 'خريطة الجسم من الأمام والخلف، بلا نقاط',
    );
    return '$_temp0';
  }

  @override
  String get wbClearPoints => 'مسح النقاط';

  @override
  String get wbFront => 'أمام';

  @override
  String get wbBack => 'خلف';

  @override
  String get wbLocations => 'الأماكن';

  @override
  String get wbTriggers => 'المحفزات';

  @override
  String get wbPainNotesHint => 'كيف كان الألم؟ وما الذي سبقه؟';

  @override
  String get wbPainNowQuestion => 'كم ألمك الآن؟';

  @override
  String get wbQuickLog => 'تسجيل سريع';

  @override
  String get wbWithDetails => 'مع التفاصيل';

  @override
  String wbPainLogged(String score) {
    return 'سُجّل ألم بدرجة $score';
  }

  @override
  String get wbPainDeleted => 'حُذف تسجيل الألم';

  @override
  String get wbPainOverTime => 'الألم عبر الأيام';

  @override
  String get wbPainChartEmpty =>
      'يظهر الرسم بعد تسجيل الألم في يومين على الأقل.';

  @override
  String get wbPainDailyMax => 'أعلى درجة في اليوم';

  @override
  String get wbPainDailyMean => 'متوسط اليوم';

  @override
  String get wbPainAvgMax => 'متوسط الأعلى';

  @override
  String get wbPainPeak => 'الذروة';

  @override
  String get wbPainDaysLogged => 'أيام مسجّلة';

  @override
  String get wbWhereItHurt => 'مواضع الألم';

  @override
  String get wbHeatEmpty => 'لا نقاط على الخريطة في هذه المدة بعد.';

  @override
  String get wbHeatLess => 'أقل';

  @override
  String get wbHeatMore => 'أشد';

  @override
  String wbHeatSemantics(String places) {
    return 'خريطة الألم؛ أكثر المواضع تكرارًا: $places';
  }

  @override
  String get wbTriggersFrequent => 'المحفزات الأكثر تكرارًا';

  @override
  String get wbTriggersEmpty => 'لم تُسجَّل محفزات في هذه المدة.';

  @override
  String get wbLocationsFrequent => 'الأماكن الأكثر تكرارًا';

  @override
  String get wbLocationsEmpty => 'لم تُسجَّل أماكن في هذه المدة.';

  @override
  String get wbManageTriggers => 'تعديل قائمة المحفزات';

  @override
  String get wbManageLocations => 'تعديل قائمة الأماكن';

  @override
  String get wbHistoryPain => 'سجل الألم';

  @override
  String get wbPainHistoryEmpty => 'لا تسجيلات بعد.';

  @override
  String get wbLogPain => 'سجّل ألمًا';

  @override
  String get wbNoPainToday => 'لا تسجيل اليوم';

  @override
  String wbLastPain(String score, String time) {
    return '$score عند $time';
  }

  @override
  String get wbRegionLegs => 'الساقان';

  @override
  String get wbTagKindLocations => 'أماكن الألم';

  @override
  String get wbTagKindTriggers => 'محفزات الألم';

  @override
  String get wbTagKindFactors => 'عوامل المزاج';

  @override
  String get wbTagKindGeneric => 'الوسوم';

  @override
  String wbTagAddTitle(String list) {
    return 'إضافة إلى $list';
  }

  @override
  String get wbTagName => 'الاسم';

  @override
  String get wbTagRenameTitle => 'إعادة التسمية';

  @override
  String wbTagDeleted(String name) {
    return 'حُذف «$name» من القائمة';
  }

  @override
  String get wbTagManagerSubtitle =>
      'اسحب لإعادة الترتيب، والمس لإعادة التسمية (تتبعها التسجيلات السابقة)، واضغط مطوّلًا للحذف.';

  @override
  String get wbTagAdd => 'إضافة عنصر';

  @override
  String get wbTagEmpty => 'القائمة فارغة؛ أضف ما يناسبك.';

  @override
  String get wbTrends => 'مسار الأيام';

  @override
  String get wbTrendsNone =>
      'بعد بضعة تسجيلات يظهر هنا مسار مزاجك وتوترك ونومك عبر الأيام.';

  @override
  String wbTrendsEmpty(String metric) {
    return 'يظهر مسار $metric بعد تسجيله في يومين على الأقل.';
  }

  @override
  String wbChartSemantics(String metric, String range) {
    return 'رسم $metric خلال $range';
  }

  @override
  String wbAverageOver(String value, String days) {
    return 'المتوسط $value عبر $days';
  }

  @override
  String get wbFactorsFrequent => 'العوامل الأكثر حضورًا';

  @override
  String get wbHistoryCheckIns => 'التسجيلات السابقة';

  @override
  String get wbHistoryEmpty => 'لا تسجيلات بعد؛ يكفي وجه واحد لتبدأ.';

  @override
  String get wbHabitsToday => 'عادات اليوم';

  @override
  String get wbHabitsSubtitle => 'خطوات صغيرة اخترتها ليومك.';

  @override
  String get wbHabitsAllDone => 'أتممتها كلها اليوم.';

  @override
  String wbBestStreakNow(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أطول سلسلة الآن: $n يوم',
      many: 'أطول سلسلة الآن: $n يومًا',
      few: 'أطول سلسلة الآن: $n أيام',
      two: 'أطول سلسلة الآن: يومان',
      one: 'أطول سلسلة الآن: يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String wbStreak(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n يوم متتالٍ',
      many: '$n يومًا متتاليًا',
      few: '$n أيام متتالية',
      two: 'يومان متتاليان',
      one: 'يوم واحد متتالٍ',
    );
    return '$_temp0';
  }

  @override
  String get wbStreakNone => 'ابدأ اليوم';

  @override
  String get wbHabitDoneState => 'أُنجزت اليوم';

  @override
  String get wbHabitOpenState => 'لم تُنجز بعد';

  @override
  String get wbHabitPausedState => 'متوقفة مؤقتًا';

  @override
  String get wbHabitMarkDone => 'إنجاز';

  @override
  String get wbHabitUndo => 'تراجع';

  @override
  String wbHabitDone(String name) {
    return 'أُنجزت: $name';
  }

  @override
  String get wbHabitUndone => 'أُلغي الإنجاز';

  @override
  String get wbHabitPause => 'إيقاف مؤقت';

  @override
  String get wbHabitResume => 'استئناف';

  @override
  String get wbHabitPaused => 'أُوقفت العادة مؤقتًا';

  @override
  String get wbHabitResumed => 'استُؤنفت العادة';

  @override
  String wbHabitDeleted(String name) {
    return 'حُذفت: $name';
  }

  @override
  String get wbHabitEditTitle => 'تعديل العادة';

  @override
  String get wbHabitAddTitle => 'عادة جديدة';

  @override
  String get wbHabitAddSubtitle => 'خطوة صغيرة تختارها لنفسك كل يوم.';

  @override
  String get wbHabitName => 'العادة';

  @override
  String get wbHabitsEmptyTitle => 'لا عادات بعد';

  @override
  String get wbHabitsEmptyBody => 'أضف عادات صغيرة تودّ متابعتها يوميًا.';

  @override
  String get wbHabitsHint =>
      'المس للإنجاز، واسحب لإعادة الترتيب، واضغط مطوّلًا للمزيد.';

  @override
  String get wbHabitsShort => 'العادات';

  @override
  String get wbWorriesShort => 'مركونة';

  @override
  String get wbWorryWindowTitle => 'نافذة القلق';

  @override
  String get wbWorryWindowExplain =>
      'وقت قصير كل يوم تراجع فيه ما يشغل بالك. وحتى يحين، اركن الهموم هنا لتعود إليها في موعدها.';

  @override
  String get wbWorryWindowSet => 'حدّد النافذة';

  @override
  String get wbWorryWindowEdit => 'تعديل النافذة';

  @override
  String get wbWorryWindowEnabled => 'تفعيل نافذة القلق';

  @override
  String get wbWorryWindowStart => 'وقت البدء';

  @override
  String get wbWorryWindowLength => 'المدة';

  @override
  String get wbWorryWindowRemind => 'تذكير عند البدء';

  @override
  String get wbWorryWindowRemindHint => 'إشعار هادئ حين تُفتح النافذة.';

  @override
  String get wbWorryWindowAbout => 'تبقى همومك على هذا الجهاز وحده، مشفّرة.';

  @override
  String wbWorryWindowSummary(String time, String length) {
    return 'كل يوم عند $time · $length';
  }

  @override
  String get wbWorryWindowOff => 'غير مفعّلة';

  @override
  String wbWorryWindowOpenNow(String left) {
    return 'النافذة مفتوحة الآن؛ بقي $left';
  }

  @override
  String wbWorryWindowOpensIn(String left) {
    return 'تُفتح بعد $left';
  }

  @override
  String wbWorryReviewStart(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'راجع $n همّ',
      many: 'راجع $n همًّا',
      few: 'راجع $n هموم',
      two: 'راجع همّين',
      one: 'راجع همًّا واحدًا',
    );
    return '$_temp0';
  }

  @override
  String get wbWorryReviewNothing => 'لا هموم مركونة';

  @override
  String get wbWorryParkTitle => 'اركن همًّا';

  @override
  String get wbWorryParkExplain =>
      'اكتبه كما هو، ثم دعه ينتظر نافذتك. لا حاجة إلى حلّه الآن.';

  @override
  String get wbWorryParkHint => 'ما الذي يشغل بالك؟';

  @override
  String get wbWorryPark => 'اركنه';

  @override
  String wbWorriesParked(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n همّ مركون',
      many: '$n همًّا مركونًا',
      few: '$n هموم مركونة',
      two: 'همّان مركونان',
      one: 'همّ مركون واحد',
      zero: 'الهموم المركونة',
    );
    return '$_temp0';
  }

  @override
  String get wbWorriesNone => 'لا شيء مركون الآن.';

  @override
  String wbWorriesResolved(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n همّ انتهى أمرها',
      many: '$n همًّا انتهى أمرها',
      few: '$n هموم انتهى أمرها',
      two: 'همّان انتهى أمرهما',
      one: 'همّ انتهى أمره',
    );
    return '$_temp0';
  }

  @override
  String wbWorryParkedOn(String date) {
    return 'رُكن: $date';
  }

  @override
  String get wbWorryEditTitle => 'تعديل الهمّ';

  @override
  String get wbWorryBody => 'الهمّ';

  @override
  String get wbWorryDeleted => 'حُذف الهمّ';

  @override
  String get wbWorryMarkedResolved => 'انتهى أمره';

  @override
  String get wbWorryReopened => 'أُعيد إلى المركونة';

  @override
  String get wbWorryResolved => 'انتهى أمره';

  @override
  String get wbWorryReopen => 'اركنه من جديد';

  @override
  String get wbWorryKeep => 'أبقِه لاحقًا';

  @override
  String get wbWorryReviewTitle => 'مراجعة الهموم';

  @override
  String get wbWorryReviewSubtitle => 'واحدًا تلو الآخر، بلا عجلة.';

  @override
  String wbWorryReviewProgress(String index, String total) {
    return '$index من $total';
  }

  @override
  String get wbWorryReviewQuestion => 'هل انتهى أمره، أم تبقيه لنافذة قادمة؟';

  @override
  String get wbWorryAddReflection => 'أضف تأمّلًا';

  @override
  String get wbWorryReflection => 'تأمّل';

  @override
  String get wbWorryReflectionHint => 'كيف تراه الآن؟';

  @override
  String wbWorryEarlierReflection(String text) {
    return 'تأمّل سابق: $text';
  }

  @override
  String get wbWorryReviewEmpty => 'لا هموم مركونة للمراجعة الآن.';

  @override
  String get wbWorryReviewDoneTitle => 'انتهت المراجعة';

  @override
  String wbWorryReviewDoneBody(int count, String n, String resolved) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'راجعت $n همّ، وانتهى أمر $resolved منها.',
      many: 'راجعت $n همًّا، وانتهى أمر $resolved منها.',
      few: 'راجعت $n هموم، وانتهى أمر $resolved منها.',
      two: 'راجعت همّين، وانتهى أمر $resolved منهما.',
      one: 'راجعت همًّا واحدًا، وانتهى أمر $resolved.',
    );
    return '$_temp0';
  }

  @override
  String get wbWorryNotifyTitle => 'حان وقت نافذة القلق';

  @override
  String wbWorryNotifyBody(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n همّ مركون ينتظرك.',
      many: '$n همًّا مركونًا ينتظرك.',
      few: '$n هموم مركونة تنتظرك.',
      two: 'همّان مركونان ينتظرانك.',
      one: 'همّ واحد مركون ينتظرك.',
    );
    return '$_temp0';
  }

  @override
  String get wbWorryNotifyBodyEmpty => 'لا شيء مركون اليوم؛ لحظة هدوء لك.';

  @override
  String get wbNotifyGroup => 'الصحة';

  @override
  String get wbNotifyChannel => 'نافذة القلق';

  @override
  String get wbNotifyChannelDescription =>
      'تذكير هادئ حين يحين وقت مراجعة الهموم المركونة.';

  @override
  String wbInsightsIntro(String days) {
    return 'ملاحظات محايدة تُحسب على جهازك من بياناتك وحدها خلال آخر $days. هي أرقام للتأمل، لا تشخيص فيها ولا نصيحة، وتزامن أمرين لا يعني أن أحدهما سبب الآخر.';
  }

  @override
  String get wbInsightsNotYetTitle => 'الرؤى في الطريق';

  @override
  String wbInsightsNotYetBody(String needed, String logged) {
    return 'تظهر الملاحظات حين تتجمّع بيانات $needed أيام على الأقل. لديك الآن $logged من $needed.';
  }

  @override
  String get wbInsightsNoneTitle => 'لا أنماط واضحة بعد';

  @override
  String get wbInsightsNoneBody =>
      'لم تظهر في بياناتك حتى الآن فروق أو ارتباطات واضحة بما يكفي، وستظهر هنا إن ظهرت.';

  @override
  String wbInsightBasis(String days) {
    return 'بناءً على $days من بياناتك';
  }

  @override
  String get wbInsightCorrelationNote => 'الارتباط يصف تزامنًا فقط، لا سببًا.';

  @override
  String get wbInsightThoseDays => 'تلك الأيام';

  @override
  String get wbInsightOtherDays => 'بقية الأيام';

  @override
  String get wbCorrelationOpposite => 'عكسي';

  @override
  String get wbCorrelationNone => 'لا ارتباط';

  @override
  String get wbCorrelationTogether => 'معًا';

  @override
  String wbAverages30(String days) {
    return 'متوسطات آخر $days';
  }

  @override
  String wbInsightSplit(
    String condition,
    String comparison,
    String a,
    String b,
  ) {
    return '$condition، $comparison: $a مقابل $b في بقية الأيام.';
  }

  @override
  String wbAvgHigher(String metric, String amount) {
    return 'كان متوسط $metric أعلى $amount';
  }

  @override
  String wbAvgLower(String metric, String amount) {
    return 'كان متوسط $metric أقل $amount';
  }

  @override
  String wbByPoints(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بـ$n درجة',
      many: 'بـ$n درجة',
      few: 'بـ$n درجات',
      two: 'بدرجتين',
      one: 'بدرجة واحدة',
    );
    return '$_temp0';
  }

  @override
  String wbByPointsFraction(String n) {
    return 'بـ$n درجة';
  }

  @override
  String wbByHours(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بـ$n ساعة',
      many: 'بـ$n ساعة',
      few: 'بـ$n ساعات',
      two: 'بساعتين',
      one: 'بساعة واحدة',
    );
    return '$_temp0';
  }

  @override
  String wbByHoursFraction(String n) {
    return 'بـ$n ساعة';
  }

  @override
  String wbWhenSleptUnder(String hours, String days) {
    return 'في الأيام التي نمت فيها أقل من $hours ساعات ($days)';
  }

  @override
  String wbWhenCaffeineAtLeast(String cups, String days) {
    return 'في الأيام التي شربت فيها $cups أكواب كافيين أو أكثر ($days)';
  }

  @override
  String wbWhenStressAtLeast(String level, String days) {
    return 'في الأيام التي كان توترك فيها $level فأكثر ($days)';
  }

  @override
  String wbWhenMetricAtLeast(String metric, String level, String days) {
    return 'في الأيام التي بلغ فيها $metric $level فأكثر ($days)';
  }

  @override
  String wbInsightCorrelation(String when, String then, String r, String days) {
    return '$when، $then في الغالب (معامل الارتباط $r على مدى $days).';
  }

  @override
  String wbWhenHigher(String metric) {
    String _temp0 = intl.Intl.selectLogic(metric, {
      'mood': 'في الأيام التي ارتفع فيها تقييم مزاجك',
      'stress': 'في الأيام التي ارتفع فيها توترك',
      'anxiety': 'في الأيام التي ارتفع فيها قلقك',
      'energy': 'في الأيام التي ارتفعت فيها طاقتك',
      'sleep': 'في الأيام التي طال فيها نومك',
      'caffeine': 'في الأيام التي زادت فيها أكواب الكافيين',
      'pain': 'في الأيام التي اشتدّ فيها ألمك',
      'other': 'في الأيام التي ارتفعت فيها القيمة',
    });
    return '$_temp0';
  }

  @override
  String wbThenHigher(String metric) {
    String _temp0 = intl.Intl.selectLogic(metric, {
      'mood': 'كان تقييم مزاجك أعلى',
      'stress': 'كان توترك أعلى',
      'anxiety': 'كان قلقك أعلى',
      'energy': 'كانت طاقتك أعلى',
      'sleep': 'كان نومك أطول',
      'caffeine': 'كانت أكواب الكافيين أكثر',
      'pain': 'كان ألمك أشدّ',
      'other': 'كانت القيمة أعلى',
    });
    return '$_temp0';
  }

  @override
  String wbThenLower(String metric) {
    String _temp0 = intl.Intl.selectLogic(metric, {
      'mood': 'كان تقييم مزاجك أقل',
      'stress': 'كان توترك أقل',
      'anxiety': 'كان قلقك أقل',
      'energy': 'كانت طاقتك أقل',
      'sleep': 'كان نومك أقصر',
      'caffeine': 'كانت أكواب الكافيين أقل',
      'pain': 'كان ألمك أخفّ',
      'other': 'كانت القيمة أقل',
    });
    return '$_temp0';
  }

  @override
  String get wbSupportTitle => 'لست وحدك';

  @override
  String wbSupportBody(String low, String total) {
    return 'سجّلت مزاجًا منخفضًا في $low من آخر $total تسجيلات. إن احتجت إلى مساعدة عاجلة، فخط الطوارئ متاح على مدار الساعة.';
  }

  @override
  String wbSupportCall(String number) {
    return 'اتصال بـ $number';
  }

  @override
  String get wbSupportHideWeek => 'إخفاء لأسبوع';

  @override
  String get wbSupportCompact =>
      'سجّلت مزاجًا منخفضًا مؤخرًا. الطوارئ متاحة دائمًا.';

  @override
  String wbDialFailed(String number) {
    return 'تعذّر فتح الهاتف. رقم الطوارئ: $number';
  }

  @override
  String get wbSettingsTitle => 'إعدادات العافية';

  @override
  String get wbSettingsSubtitle => 'رقم الطوارئ، ونافذة القلق، وصوت التنفّس';

  @override
  String get wbSettingsSupportNumber => 'رقم الطوارئ';

  @override
  String wbSettingsSupportNumberHint(String number) {
    return 'يظهر في لافتة الدعم. في الأردن $number؛ غيّره إن كنت تقيم في بلد آخر.';
  }

  @override
  String get wbSettingsNumberInvalid => 'أدخل رقمًا صالحًا';

  @override
  String wbSettingsResetNumber(String number) {
    return 'استعادة $number';
  }

  @override
  String get wbSettingsBreathingSound => 'صوت هادئ للتنفّس';

  @override
  String get wbSettingsBreathingSoundHint =>
      'نغمة خفيفة عند كل مرحلة؛ الاهتزاز يعمل دائمًا.';

  @override
  String get wbBreathTitle => 'تنفّس';

  @override
  String get wbBreatheShort => 'تنفّس';

  @override
  String get wbBreath478 => 'الزفير الطويل';

  @override
  String get wbBreathBox => 'الصندوق';

  @override
  String get wbBreathIn => 'شهيق';

  @override
  String get wbBreathHold => 'احبس';

  @override
  String get wbBreathOut => 'زفير';

  @override
  String get wbBreathRest => 'توقّف';

  @override
  String wbBreathReady(String rhythm) {
    return 'إيقاع $rhythm ثوانٍ. ابدأ حين تكون مستعدًا.';
  }

  @override
  String get wbBreathDone => 'اكتملت الجلسة';

  @override
  String wbBreathDoneBody(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أتممت $n دورة.',
      many: 'أتممت $n دورة.',
      few: 'أتممت $n دورات.',
      two: 'أتممت دورتين.',
      one: 'أتممت دورة واحدة.',
    );
    return '$_temp0';
  }

  @override
  String wbBreathCycle(String index, String total) {
    return 'الدورة $index من $total';
  }

  @override
  String get wbBreathPaused => 'متوقف مؤقتًا';

  @override
  String get wbBreathCycles => 'عدد الدورات';

  @override
  String get wbBreathStart => 'ابدأ';

  @override
  String get wbBreathAgain => 'مرة أخرى';

  @override
  String get wbBreathStop => 'إنهاء';

  @override
  String get wbBreathPause => 'إيقاف مؤقت';

  @override
  String get wbBreathResume => 'متابعة';

  @override
  String get wbBreathSoundOn => 'الصوت مفعّل';

  @override
  String get wbBreathSoundOff => 'الصوت مغلق';

  @override
  String get wbBreathGentleNote => 'خذ الإيقاع بلطف، ويمكنك التوقف في أي لحظة.';

  @override
  String get wbTodayCardTitle => 'العافية اليوم';

  @override
  String get healthHubTodayTitle => 'عنايتك اليوم';

  @override
  String get healthHubDoctorTitle => 'مع طبيبك';

  @override
  String get healthHubRecordAction => 'السجل';

  @override
  String get healthHubToolsTitle => 'أدوات الصحة';

  @override
  String get healthHubPainTitle => 'الألم الآن';

  @override
  String get healthHubPainNone => 'لا ألم مسجّل اليوم';

  @override
  String healthHubPainToday(int count, String n, String max) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n تسجيل اليوم، أعلاها $max',
      many: '$n تسجيلًا اليوم، أعلاها $max',
      few: '$n تسجيلات اليوم، أعلاها $max',
      two: 'تسجيلان اليوم، أعلاهما $max',
      one: 'تسجيل واحد اليوم بدرجة $max',
    );
    return '$_temp0';
  }

  @override
  String get healthHubPainWhere => 'تفاصيل';

  @override
  String get healthHubPainWhereHint =>
      'تسجيل كامل: موضع الألم على الجسم والمحفّزات والملاحظات';

  @override
  String get healthHubPainLow => 'لا ألم';

  @override
  String get healthHubPainHigh => 'أشدّ ألم';

  @override
  String healthHubPainLogScore(String score, String max) {
    return 'سجّل ألمًا بدرجة $score من $max';
  }

  @override
  String get healthHubQuestionsTitle => 'أسئلة لطبيبك';

  @override
  String healthHubQuestionsCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n سؤال بانتظار الإجابة',
      many: '$n سؤالًا بانتظار الإجابة',
      few: '$n أسئلة بانتظار الإجابة',
      two: 'سؤالان بانتظار الإجابة',
      one: 'سؤال واحد بانتظار الإجابة',
    );
    return '$_temp0';
  }

  @override
  String healthHubQuestionFor(String title) {
    return 'لموعد $title';
  }

  @override
  String get healthHubToolMeds => 'الأدوية';

  @override
  String get healthHubToolMedsHint => 'الجرعات والدورات وقواعد التوقيت';

  @override
  String get healthHubToolLabs => 'التحاليل';

  @override
  String get healthHubToolLabsHint => 'النتائج ومساراتها ومداك المرجعي';

  @override
  String get healthHubToolAppointments => 'المواعيد';

  @override
  String get healthHubToolAppointmentsHint =>
      'المواعيد القادمة والسابقة وأسئلتها';

  @override
  String get healthHubToolWellbeing => 'العافية';

  @override
  String get healthHubToolWellbeingHint => 'المزاج والألم والعادات والهموم';

  @override
  String get healthHubToolBreathe => 'تنفّس';

  @override
  String get healthHubToolBreatheHint => 'تنفّس موجَّه بإيقاع هادئ';

  @override
  String get healthHubToolReport => 'ملخّص للطبيب';

  @override
  String get healthHubToolReportHint => 'ملف PDF تطبعه أو تشاركه';

  @override
  String get healthHubSettingsSection => 'الصحة';

  @override
  String get healthHubSettingsSectionHint =>
      'الأدوية والمواعيد والعافية، وكلها على جهازك';

  @override
  String get healthHubSettingsTitle => 'إعدادات الصحة';

  @override
  String healthHubSettingsRemindersOn(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n تذكير مفعّل',
      many: '$n تذكيرًا مفعّلًا',
      few: '$n تذكيرات مفعّلة',
      two: 'تذكيران مفعّلان',
      one: 'تذكير واحد مفعّل',
      zero: 'تذكيرات الصحة متوقفة',
    );
    return '$_temp0';
  }

  @override
  String healthHubSettingsEntrySummary(String reminders, String number) {
    return '$reminders، والطوارئ $number';
  }

  @override
  String get healthHubSettingsRecordSection => 'المواعيد والتحاليل';

  @override
  String get healthHubSettingsMarginHint =>
      'جزء من عرض المدى الذي أدخلته لكل تحليل؛ النتيجة ضمنه قرب أحد الحدّين تُعلَّم «حدّية».';

  @override
  String get healthHubSettingsReportSection => 'ملخّص الطبيب';

  @override
  String get healthHubSettingsReportPeriod => 'الفترة المعتادة';

  @override
  String get healthHubSettingsReportSections => 'الأقسام المضمّنة';

  @override
  String get healthHubSettingsReportSectionsAll => 'كل الأقسام';

  @override
  String get healthHubSettingsReportNameNone =>
      'لا يُحفظ اسم، يُكتب عند كل تقرير';

  @override
  String healthHubSettingsReportNameKept(String name) {
    return '$name، على هذا الجهاز فقط';
  }

  @override
  String get healthHubSettingsReportNameHint =>
      'اتركه فارغًا كي لا يُحفظ أي اسم';

  @override
  String healthHubSettingsEmergencyHint(String number) {
    return '$number، ويظهر في رسالة الدعم حين يتكرّر المزاج المنخفض';
  }

  @override
  String get healthHubSettingsDenied =>
      'إشعارات مَدار متوقفة في إعدادات الهاتف، فلن تصل التذكيرات.';

  @override
  String get healthHubSettingsPrivacy =>
      'كل ما في الصحة يبقى على هذا الجهاز مشفّرًا. مَدار يسجّل ويعرض فقط؛ لا يشخّص ولا ينصح بعلاج.';

  @override
  String get healthHubSettingsOff => 'متوقفة';

  @override
  String healthHubSettingsWorrySummary(String time, String length) {
    return 'يوميًا عند $time، لمدة $length';
  }

  @override
  String get ledgerTitle => 'المحافظ والحركات';

  @override
  String get ledgerNetBalance => 'صافي الرصيد';

  @override
  String get ledgerPersonal => 'شخصي';

  @override
  String get ledgerBusiness => 'تجاري';

  @override
  String ledgerApprox(String amount) {
    return '≈ $amount';
  }

  @override
  String get ledgerWallets => 'المحافظ';

  @override
  String get ledgerAddWallet => 'محفظة جديدة';

  @override
  String ledgerArchivedCount(String count) {
    return 'المؤرشفة ($count)';
  }

  @override
  String get ledgerRecent => 'آخر الحركات';

  @override
  String get ledgerSeeAll => 'عرض الكل';

  @override
  String get ledgerCurrencies => 'العملات وأسعار الصرف';

  @override
  String get ledgerSearch => 'ابحث في الحركات';

  @override
  String get ledgerAddTx => 'حركة جديدة';

  @override
  String get ledgerEmptyTitle => 'ابدأ بمحفظتك الأولى';

  @override
  String get ledgerEmptyBody =>
      'أنشئ محفظة لكل مكان يوجد فيه مالك: نقدًا، في البنك، أو عهدة لدى شركة التوصيل.';

  @override
  String get ledgerNoTxTitle => 'لا حركات بعد';

  @override
  String get ledgerNoTxBody => 'سجّل مصروفًا أو دخلًا وسيظهر هنا.';

  @override
  String get ledgerNoResults => 'لا حركات مطابقة';

  @override
  String get ledgerNoResultsBody => 'جرّب كلمة أخرى أو أزل بعض عوامل التصفية.';

  @override
  String ledgerMissingRate(String codes) {
    return 'بلا سعر صرف، فلم تُحسب في المجموع: $codes';
  }

  @override
  String get ledgerRatesDefaults =>
      'أسعار الصرف ما زالت تقديرية. راجعها لتكون المجاميع دقيقة.';

  @override
  String get ledgerReview => 'مراجعة';

  @override
  String get ledgerKindExpense => 'مصروف';

  @override
  String get ledgerKindIncome => 'دخل';

  @override
  String get ledgerKindTransfer => 'تحويل';

  @override
  String get ledgerKindAdjustment => 'تسوية';

  @override
  String get ledgerToday => 'اليوم';

  @override
  String get ledgerYesterday => 'أمس';

  @override
  String ledgerTransferRoute(String from, String to) {
    return '$from ← $to';
  }

  @override
  String ledgerTransferOut(String wallet) {
    return 'تحويل إلى $wallet';
  }

  @override
  String ledgerTransferIn(String wallet) {
    return 'تحويل من $wallet';
  }

  @override
  String get ledgerAdjustmentTitle => 'تسوية الرصيد';

  @override
  String get ledgerUnassigned => 'بلا بند';

  @override
  String ledgerBalanceAfter(String amount) {
    return 'الرصيد $amount';
  }

  @override
  String get ledgerDuplicateToday => 'تكرار لليوم';

  @override
  String get ledgerDeleted => 'حُذفت الحركة';

  @override
  String get ledgerDuplicated => 'تكررت الحركة بتاريخ اليوم';

  @override
  String ledgerMoved(String wallet) {
    return 'نُقلت إلى $wallet';
  }

  @override
  String ledgerMovedConverted(String wallet, String amount) {
    return 'نُقلت إلى $wallet بمبلغ $amount';
  }

  @override
  String get ledgerSaved => 'حُفظت الحركة';

  @override
  String get ledgerUpdated => 'عُدّلت الحركة';

  @override
  String get ledgerMoveTitle => 'نقل الحركة إلى…';

  @override
  String get ledgerEditTx => 'تعديل الحركة';

  @override
  String get ledgerWallet => 'المحفظة';

  @override
  String get ledgerFrom => 'من';

  @override
  String get ledgerTo => 'إلى';

  @override
  String get ledgerSent => 'المُرسَل';

  @override
  String get ledgerReceived => 'المستلَم';

  @override
  String get ledgerUseRate => 'حسب سعر الصرف';

  @override
  String ledgerRateLine(String one, String from, String rate, String to) {
    return '$one $from = $rate $to';
  }

  @override
  String get ledgerBudgetItem => 'البند';

  @override
  String get ledgerChooseItem => 'اختر بندًا';

  @override
  String get ledgerNoBudget => 'لا بنود في الميزانية بعد';

  @override
  String get ledgerSearchItems => 'ابحث عن بند';

  @override
  String ledgerItemLeft(String amount) {
    return 'متبقٍّ $amount';
  }

  @override
  String ledgerItemOver(String amount) {
    return 'تجاوز $amount';
  }

  @override
  String get ledgerDate => 'التاريخ';

  @override
  String get ledgerOtherDay => 'يوم آخر';

  @override
  String get ledgerNote => 'ملاحظة';

  @override
  String get ledgerNoteHint => 'مثلًا: خضار من السوق';

  @override
  String get ledgerTags => 'الوسوم';

  @override
  String get ledgerTagHint => 'أضف وسمًا';

  @override
  String get ledgerSetBalance => 'الرصيد الفعلي';

  @override
  String get ledgerDifference => 'الفرق';

  @override
  String get ledgerCurrentBalance => 'الرصيد الحالي';

  @override
  String get ledgerNegative => 'سالب';

  @override
  String get ledgerErrNoWallet => 'اختر محفظة';

  @override
  String get ledgerErrNoAmount => 'أدخل المبلغ';

  @override
  String get ledgerErrNoDestination => 'اختر المحفظة المستلِمة';

  @override
  String get ledgerErrSameWallet => 'اختر محفظة مختلفة';

  @override
  String get ledgerErrNoRate => 'لا يوجد سعر صرف، أدخل المبلغ المستلَم';

  @override
  String get ledgerErrNoChange => 'الرصيد مطابق أصلًا';

  @override
  String get ledgerNeedWallet => 'أنشئ محفظة أولًا لتسجيل الحركات';

  @override
  String get ledgerKeyDecimal => 'فاصلة عشرية';

  @override
  String get ledgerKeyBackspace => 'حذف آخر رقم';

  @override
  String get ledgerAmount => 'المبلغ';

  @override
  String get ledgerWalletEdit => 'تعديل المحفظة';

  @override
  String get ledgerWalletName => 'الاسم';

  @override
  String get ledgerWalletNameHint => 'مثلًا: الصندوق، البنك، عهدة المندوب';

  @override
  String get ledgerOpening => 'الرصيد الافتتاحي والعملة';

  @override
  String get ledgerWalletKind => 'نوع المحفظة';

  @override
  String get ledgerColor => 'اللون';

  @override
  String get ledgerIcon => 'الأيقونة';

  @override
  String get ledgerCurrencyLocked =>
      'لا يمكن تغيير العملة بعد تسجيل حركات في المحفظة';

  @override
  String get ledgerArchive => 'أرشفة';

  @override
  String get ledgerUnarchive => 'إعادة من الأرشيف';

  @override
  String get ledgerArchivedToast => 'أُرشفت المحفظة';

  @override
  String get ledgerUnarchivedToast => 'أُعيدت المحفظة';

  @override
  String ledgerWalletDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'حُذفت المحفظة و$count حركة',
      many: 'حُذفت المحفظة و$count حركة',
      few: 'حُذفت المحفظة و$count حركات',
      two: 'حُذفت المحفظة وحركتان',
      one: 'حُذفت المحفظة وحركة واحدة',
      zero: 'حُذفت المحفظة',
    );
    return '$_temp0';
  }

  @override
  String get ledgerWalletSaved => 'حُفظت المحفظة';

  @override
  String get ledgerBalance => 'الرصيد';

  @override
  String get ledgerBalanceHistory => 'تطوّر الرصيد';

  @override
  String get ledgerRange1M => 'شهر';

  @override
  String get ledgerRange3M => '٣ أشهر';

  @override
  String get ledgerRange1Y => 'سنة';

  @override
  String get ledgerRangeAll => 'الكل';

  @override
  String get ledgerTransactions => 'الحركات';

  @override
  String get ledgerWalletMissing => 'لم نجد هذه المحفظة';

  @override
  String ledgerOpeningLine(String amount) {
    return 'رصيد افتتاحي $amount';
  }

  @override
  String get ledgerFilterWallet => 'المحفظة';

  @override
  String get ledgerFilterKind => 'النوع';

  @override
  String get ledgerFilterItem => 'البند';

  @override
  String get ledgerFilterTag => 'الوسم';

  @override
  String get ledgerFilterDate => 'الفترة';

  @override
  String get ledgerFilterScope => 'النطاق';

  @override
  String get ledgerFilterClear => 'مسح التصفية';

  @override
  String ledgerFilterMore(String first, String count) {
    return '$first +$count';
  }

  @override
  String get ledgerAll => 'الكل';

  @override
  String get ledgerAllWallets => 'كل المحافظ';

  @override
  String get ledgerThisWeek => 'هذا الأسبوع';

  @override
  String get ledgerThisMonth => 'هذا الشهر';

  @override
  String get ledgerLastMonth => 'الشهر الماضي';

  @override
  String ledgerLastDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'آخر $count يوم',
      many: 'آخر $count يومًا',
      few: 'آخر $count أيام',
      two: 'آخر يومين',
      one: 'آخر يوم',
    );
    return '$_temp0';
  }

  @override
  String get ledgerCustomRange => 'مدة مخصّصة';

  @override
  String ledgerRangeLabel(String from, String to) {
    return '$from – $to';
  }

  @override
  String get ledgerIncomeTotal => 'الدخل';

  @override
  String get ledgerExpenseTotal => 'المصروف';

  @override
  String get ledgerNet => 'الصافي';

  @override
  String ledgerTxCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حركة',
      many: '$count حركة',
      few: '$count حركات',
      two: 'حركتان',
      one: 'حركة واحدة',
      zero: 'لا حركات',
    );
    return '$_temp0';
  }

  @override
  String get ledgerSpending => 'الإنفاق';

  @override
  String get ledgerByItem => 'حسب البند';

  @override
  String get ledgerByWallet => 'حسب المحفظة';

  @override
  String get ledgerPeriodMonth => 'شهري';

  @override
  String get ledgerPeriodWeek => 'أسبوعي';

  @override
  String get ledgerPrevPeriod => 'الفترة السابقة';

  @override
  String get ledgerNextPeriod => 'الفترة التالية';

  @override
  String get ledgerNoSpending => 'لا مصاريف في هذه الفترة';

  @override
  String get ledgerTrend => 'الدخل والإنفاق';

  @override
  String ledgerTrendSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'آخر $count شهر',
      many: 'آخر $count شهرًا',
      few: 'آخر $count أشهر',
      two: 'آخر شهرين',
      one: 'آخر شهر',
    );
    return '$_temp0';
  }

  @override
  String ledgerInBase(String code) {
    return 'بالعملة الأساسية $code';
  }

  @override
  String get ledgerTotal => 'المجموع';

  @override
  String get ledgerOther => 'أخرى';

  @override
  String ledgerChartSpendingSemantics(
    String period,
    String total,
    String slices,
  ) {
    return 'الإنفاق $period: المجموع $total. $slices';
  }

  @override
  String ledgerChartTrendSemantics(
    String period,
    String income,
    String expense,
  ) {
    return '$period: دخل $income، إنفاق $expense';
  }

  @override
  String get ledgerCurrenciesTitle => 'العملات';

  @override
  String get ledgerBaseCurrency => 'العملة الأساسية';

  @override
  String get ledgerBaseHint => 'تُعرض بها كل المجاميع والرسوم البيانية';

  @override
  String get ledgerChangeBase => 'تغيير العملة الأساسية';

  @override
  String get ledgerOtherCurrencies => 'عملات أخرى';

  @override
  String get ledgerAddCurrency => 'إضافة عملة';

  @override
  String get ledgerNewCurrency => 'عملة جديدة';

  @override
  String get ledgerEditCurrency => 'تعديل العملة';

  @override
  String get ledgerCode => 'الرمز الدولي';

  @override
  String get ledgerCodeHint => 'مثل EUR';

  @override
  String get ledgerNameAr => 'الاسم بالعربية';

  @override
  String get ledgerNameEn => 'الاسم بالإنجليزية';

  @override
  String get ledgerSymbol => 'الرمز المختصر';

  @override
  String get ledgerDecimals => 'المنازل العشرية';

  @override
  String get ledgerRate => 'سعر الصرف';

  @override
  String get ledgerRateHint => 'يُدخَل يدويًا، دون اتصال بالإنترنت';

  @override
  String get ledgerErrCode => 'استخدم حروفًا لاتينية (مثل EUR)';

  @override
  String get ledgerErrCodeExists => 'هذه العملة موجودة';

  @override
  String get ledgerErrRate => 'أدخل سعرًا أكبر من صفر';

  @override
  String get ledgerErrName => 'أدخل اسمًا';

  @override
  String ledgerCurrencyInUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'مستخدمة في $count محفظة',
      many: 'مستخدمة في $count محفظة',
      few: 'مستخدمة في $count محافظ',
      two: 'مستخدمة في محفظتين',
      one: 'مستخدمة في محفظة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get ledgerCurrencyDeleted => 'حُذفت العملة';

  @override
  String get ledgerCurrencySaved => 'حُفظت العملة';

  @override
  String get ledgerNoRate => 'بلا سعر';

  @override
  String get ledgerRebaseTitle => 'عملة أساسية جديدة';

  @override
  String ledgerRebaseExplain(String code) {
    return 'تُعاد كتابة كل الأسعار نسبةً إلى $code بدقة، فتبقى القيم المحوّلة كما هي.';
  }

  @override
  String get ledgerRebaseNow => 'الآن';

  @override
  String get ledgerRebaseAfter => 'بعد التغيير';

  @override
  String ledgerRebaseConfirm(String code) {
    return 'اعتماد $code';
  }

  @override
  String ledgerRebaseDone(String code) {
    return 'أصبحت $code العملة الأساسية';
  }

  @override
  String get ledgerRebaseChoose => 'اختر العملة الأساسية الجديدة';

  @override
  String get ledgerSummaryEmpty => 'لا محافظ بعد';

  @override
  String ledgerMoreWallets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'و$count محفظة أخرى',
      many: 'و$count محفظة أخرى',
      few: 'و$count محافظ أخرى',
      two: 'ومحفظتان أخريان',
      one: 'ومحفظة أخرى',
    );
    return '$_temp0';
  }

  @override
  String ledgerWalletSemantics(String name, String amount) {
    return '$name، الرصيد $amount';
  }

  @override
  String get ledgerApply => 'تطبيق';

  @override
  String get ledgerNoTags => 'لا وسوم بعد';

  @override
  String get ledgerCompactThousand => 'ألف';

  @override
  String get ledgerCompactMillion => 'مليون';

  @override
  String get ledgerMakeBase => 'اعتمادها عملة أساسية';

  @override
  String get ledgerRatesStale => 'الأسعار يدوية؛ حدّثها حين يتغيّر السوق';

  @override
  String get ledgerNoteHintIncome => 'مثلًا: تحصيل من شركة الشحن';

  @override
  String get ledgerNoteHintTransfer => 'مثلًا: إيداع في البنك';

  @override
  String get ledgerNoteHintAdjust => 'مثلًا: بعد عدّ النقود';

  @override
  String get ledgerLinkJar => 'حصّالة';

  @override
  String get ledgerLinkDebt => 'دَين';

  @override
  String get ledgerLinkObligation => 'التزام';

  @override
  String get ledgerOpenJar => 'فتح الحصّالة';

  @override
  String get ledgerOpenDebt => 'فتح الدَّين';

  @override
  String get ledgerOpenObligation => 'فتح الالتزام';

  @override
  String ledgerLinkedHint(String source) {
    return 'تُعدَّل من $source';
  }

  @override
  String get ledgerArchivedBadge => 'مؤرشفة';

  @override
  String get ledgerUnknownCurrencies =>
      'بعض المحافظ بعملات غير موجودة في قائمتك بعد. أضِفها مع سعر صرف لتدخل في المجاميع.';

  @override
  String ledgerAddCode(String code) {
    return 'إضافة $code';
  }

  @override
  String get ledgerFixRates => 'ضبط الأسعار';

  @override
  String get ledgerCurrencyInUseElsewhere =>
      'مستخدمة في الحصّالات أو الديون أو الالتزامات أو الميزانية';

  @override
  String get budgetTitle => 'الميزانية';

  @override
  String get budgetTabPlan => 'الخطة';

  @override
  String get budgetTabSpending => 'الإنفاق';

  @override
  String get budgetAddItem => 'إضافة بند';

  @override
  String get budgetMonthlyPlan => 'الخطة الشهرية';

  @override
  String budgetWeeklyEquivalent(String amount) {
    return '≈ $amount في الأسبوع';
  }

  @override
  String budgetWeeksPerMonthChip(String weeks) {
    return 'أسابيع الشهر: $weeks';
  }

  @override
  String get budgetAllocation => 'توزيع الخطة';

  @override
  String get budgetBalanced => 'كل البنود متوازنة';

  @override
  String budgetWarningsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أمر يحتاج انتباهك',
      many: '$count أمرًا يحتاج انتباهك',
      few: '$count أمور تحتاج انتباهك',
      two: 'أمران يحتاجان انتباهك',
      one: 'أمر واحد يحتاج انتباهك',
    );
    return '$_temp0';
  }

  @override
  String budgetWarningsMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'و$count أمر آخر',
      many: 'و$count أمرًا آخر',
      few: 'و$count أمور أخرى',
      two: 'وأمران آخران',
      one: 'وأمر آخر',
    );
    return '$_temp0';
  }

  @override
  String get budgetShowLess => 'عرض أقل';

  @override
  String budgetIssueChildrenUnder(String name, String amount) {
    return 'بنود «$name» الفرعية أقلّ منه بـ$amount';
  }

  @override
  String budgetIssueChildrenOver(String name, String amount) {
    return 'بنود «$name» الفرعية تتجاوزه بـ$amount';
  }

  @override
  String budgetIssuePercentSelf(String name, String percent) {
    return 'نسبة «$name» أكبر من أصلها: $percent';
  }

  @override
  String budgetIssuePercentChildren(String name, String percent) {
    return 'نِسب بنود «$name» الفرعية مجموعها $percent';
  }

  @override
  String budgetIssuePercentTotal(String percent) {
    return 'البنود المحدّدة بنسبة من الإجمالي مجموعها $percent';
  }

  @override
  String budgetIssueCircular(String name) {
    return 'نِسب «$name» تعتمد على بعضها فتعذّر حسابها';
  }

  @override
  String get budgetIssueCircularTotal =>
      'البنود المحدّدة بنسبة من الإجمالي تستهلكه كلّه';

  @override
  String budgetIssueCircularParent(String name) {
    return '«$name» كان داخل نفسه، فيظهر في المستوى الأعلى';
  }

  @override
  String budgetIssueOrphan(String name) {
    return 'البند الأب لـ«$name» غير موجود، فيظهر في المستوى الأعلى';
  }

  @override
  String budgetIssueMissingRate(String currency) {
    return 'لا سعر صرف مسجّل لـ$currency، فاحتُسب واحدًا بواحد';
  }

  @override
  String budgetIssueOverspent(String name, String amount) {
    return 'تجاوز «$name» خطّته بـ$amount هذا الشهر';
  }

  @override
  String budgetBadgeUnder(String amount) {
    return '$amount غير موزّع';
  }

  @override
  String budgetBadgeOver(String amount) {
    return 'زيادة $amount';
  }

  @override
  String budgetBadgePercent(String percent) {
    return '$percent أكبر من الأصل';
  }

  @override
  String budgetBadgePercentChildren(String percent) {
    return 'مجموع نِسب الفروع $percent';
  }

  @override
  String get budgetBadgeCircular => 'نِسب متداخلة';

  @override
  String get budgetBadgeMoved => 'نُقل للأعلى';

  @override
  String get budgetBadgeNoRate => 'بلا سعر صرف';

  @override
  String budgetBadgeOverspent(String amount) {
    return 'تجاوز بـ$amount';
  }

  @override
  String budgetPercentOf(String percent, String name) {
    return '$percent من «$name»';
  }

  @override
  String budgetPercentOfTotal(String percent) {
    return '$percent من الإجمالي';
  }

  @override
  String budgetPerMonth(String amount) {
    return '$amount شهريًا';
  }

  @override
  String budgetPerWeek(String amount) {
    return '$amount أسبوعيًا';
  }

  @override
  String budgetApproxMonthly(String amount) {
    return '≈ $amount شهريًا';
  }

  @override
  String get budgetSumOfChildren => 'مجموع البنود الفرعية';

  @override
  String budgetChildrenSum(String sum, String plan) {
    return 'الفروع: $sum من $plan';
  }

  @override
  String get budgetSetByAmount => 'محدّد بالمبلغ';

  @override
  String get budgetSetByPercent => 'محدّد بالنسبة';

  @override
  String get budgetDragHint => 'اسحب المقبض لترتيب البنود داخل مجموعتها';

  @override
  String get budgetAddChild => 'إضافة بند فرعي';

  @override
  String get budgetAddSibling => 'إضافة بند مجاور';

  @override
  String budgetMoveTitle(String name) {
    return 'نقل «$name»';
  }

  @override
  String get budgetMoveSubtitle => 'يبقى مبلغه كما هو';

  @override
  String get budgetTopLevel => 'المستوى الأعلى';

  @override
  String budgetDeletedWithChildren(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'حُذف البند و$count بند فرعي',
      many: 'حُذف البند و$count بندًا فرعيًا',
      few: 'حُذف البند و$count بنود فرعية',
      two: 'حُذف البند وبندان فرعيان',
      one: 'حُذف البند وبند فرعي',
      zero: 'حُذف البند',
    );
    return '$_temp0';
  }

  @override
  String get budgetSaved => 'حُفظ البند';

  @override
  String get budgetAdded => 'أُضيف البند';

  @override
  String get budgetEmptyTitle => 'لا ميزانية بعد';

  @override
  String get budgetEmptyBody =>
      'خطّط بالمبلغ أو بالنسبة، وضع البنود داخل بعضها، ثم قارن إنفاقك بالخطة.';

  @override
  String get budgetEmptyAction => 'أضف أول بند';

  @override
  String get budgetWeeksTitle => 'أسابيع الشهر';

  @override
  String get budgetWeeksSubtitle =>
      'تُضرب البنود الأسبوعية في هذا العدد لحساب خطتها الشهرية';

  @override
  String get budgetWeeksRound => 'أسابيع كاملة';

  @override
  String get budgetWeeksCalendar => 'متوسط التقويم';

  @override
  String get budgetWeeksCustom => 'عدد آخر';

  @override
  String budgetWeeksInvalid(String min, String max) {
    return 'أدخل عددًا بين $min و$max';
  }

  @override
  String budgetWeeksExample(String weekly, String monthly) {
    return '$weekly أسبوعيًا = $monthly شهريًا';
  }

  @override
  String get budgetWeeksSaved => 'تغيّر عدد أسابيع الشهر';

  @override
  String get budgetNewItem => 'بند جديد';

  @override
  String budgetNewChild(String name) {
    return 'بند فرعي في «$name»';
  }

  @override
  String get budgetEditItem => 'تعديل البند';

  @override
  String get budgetFieldName => 'الاسم';

  @override
  String get budgetFieldNameHint => 'مثل: البقالة';

  @override
  String get budgetFieldParent => 'ضمن';

  @override
  String get budgetFieldSetBy => 'يُحدَّد بـ';

  @override
  String get budgetModeAmount => 'مبلغ';

  @override
  String get budgetModePercent => 'نسبة';

  @override
  String get budgetModeSum => 'مجموع الفروع';

  @override
  String get budgetFieldAmount => 'المبلغ';

  @override
  String get budgetFieldPercent => 'النسبة';

  @override
  String budgetOfParent(String name) {
    return 'من «$name»';
  }

  @override
  String get budgetOfTotal => 'من الإجمالي';

  @override
  String get budgetCalculated => 'محسوب';

  @override
  String get budgetFieldPeriod => 'الفترة';

  @override
  String get budgetMonthly => 'شهري';

  @override
  String get budgetWeekly => 'أسبوعي';

  @override
  String get budgetFieldCurrency => 'العملة';

  @override
  String budgetBaseCurrency(String code) {
    return '$code · الأساس';
  }

  @override
  String get budgetPreviewTitle => 'في الميزانية';

  @override
  String get budgetAmountInvalid => 'أدخل مبلغًا صحيحًا، صفرًا أو أكثر';

  @override
  String get budgetPercentInvalid => 'أدخل نسبة صحيحة، صفرًا أو أكثر';

  @override
  String get budgetSumHint => 'يساوي مجموع بنوده الفرعية ويتغيّر معها';

  @override
  String get budgetPickerTitle => 'بند الميزانية';

  @override
  String get budgetPickerSearch => 'ابحث في البنود';

  @override
  String get budgetPickerNone => 'بلا بند';

  @override
  String get budgetPickerEmpty => 'لا بنود في الميزانية بعد';

  @override
  String get budgetPickerNoResults => 'لا بنود مطابقة';

  @override
  String get budgetPickerPlaceholder => 'اختر بندًا';

  @override
  String budgetLeft(String amount) {
    return 'متبقٍّ $amount';
  }

  @override
  String budgetOverBy(String amount) {
    return 'تجاوز $amount';
  }

  @override
  String get budgetCurrentBadge => 'الحالي';

  @override
  String get budgetPreviousPeriod => 'الفترة السابقة';

  @override
  String get budgetNextPeriod => 'الفترة التالية';

  @override
  String get budgetSpent => 'المصروف';

  @override
  String budgetOfPlan(String amount) {
    return 'من $amount';
  }

  @override
  String get budgetRemaining => 'المتبقي';

  @override
  String get budgetOverPlan => 'فوق الخطة';

  @override
  String get budgetProjection => 'بهذا المعدّل';

  @override
  String budgetProjectionMonth(String amount) {
    return '$amount بنهاية الشهر';
  }

  @override
  String budgetProjectionWeek(String amount) {
    return '$amount بنهاية الأسبوع';
  }

  @override
  String budgetDayOf(String day, String days) {
    return 'اليوم $day من $days';
  }

  @override
  String get budgetPeriodClosed => 'فترة منتهية';

  @override
  String get budgetUnassigned => 'خارج الميزانية';

  @override
  String get budgetStatusCalm => 'ضمن الخطة';

  @override
  String get budgetStatusNear => 'قارب النفاد';

  @override
  String get budgetStatusAtRisk => 'في طريقه للتجاوز';

  @override
  String get budgetStatusOver => 'تجاوز الخطة';

  @override
  String get budgetStatusUnplanned => 'بلا خطة';

  @override
  String budgetSpentOf(String spent, String plan) {
    return '$spent من $plan';
  }

  @override
  String get budgetByItem => 'حسب البند';

  @override
  String get budgetHistoryMonths => 'الأشهر السابقة';

  @override
  String get budgetHistoryWeeks => 'الأسابيع السابقة';

  @override
  String get budgetLegendPlan => 'الخطة';

  @override
  String get budgetLegendSpent => 'المصروف';

  @override
  String get budgetHistoryNote => 'تُقارن الفترات السابقة بخطة اليوم';

  @override
  String get budgetNoSpending => 'لا مصروفات في هذه الفترة بعد';

  @override
  String budgetHistoryBar(String period, String spent, String plan) {
    return '$period: $spent من $plan';
  }

  @override
  String budgetCardSpentOf(String spent, String plan) {
    return 'صُرف $spent من $plan';
  }

  @override
  String get budgetCardEmpty => 'خطّط ميزانيتك بالمبلغ أو بالنسبة';

  @override
  String budgetCardWarnings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تنبيه',
      many: '$count تنبيهًا',
      few: '$count تنبيهات',
      two: 'تنبيهان',
      one: 'تنبيه واحد',
    );
    return '$_temp0';
  }

  @override
  String get goalsTitle => 'المدّخرات والالتزامات';

  @override
  String get goalsTabJars => 'الحصّالات';

  @override
  String get goalsTabDebts => 'الديون';

  @override
  String get goalsTabObligations => 'الالتزامات';

  @override
  String get goalsDebtsTitle => 'الديون';

  @override
  String get goalsObligationsTitle => 'الالتزامات الدورية';

  @override
  String get goalsUpcomingTitle => 'مستحقات قريبة';

  @override
  String get goalsSeeAll => 'عرض الكل';

  @override
  String get goalsCreate => 'إنشاء';

  @override
  String get goalsGone => 'لم يعد هذا العنصر موجودًا.';

  @override
  String get goalsShow => 'إظهار';

  @override
  String get goalsHide => 'إخفاء';

  @override
  String get goalsFilterAll => 'الكل';

  @override
  String get goalsAmountPositive => 'أدخل مبلغًا أكبر من صفر';

  @override
  String get goalsFieldAmount => 'المبلغ';

  @override
  String get goalsFieldDate => 'التاريخ';

  @override
  String get goalsFieldNote => 'ملاحظة';

  @override
  String get goalsFieldFromWallet => 'من محفظة';

  @override
  String get goalsFieldToWallet => 'إلى محفظة';

  @override
  String get goalsNoWallet => 'بلا محفظة';

  @override
  String get goalsOf => 'من';

  @override
  String goalsOfTotal(String amount) {
    return 'من $amount';
  }

  @override
  String goalsSavedOfTarget(String saved, String target) {
    return '$saved من $target';
  }

  @override
  String goalsFromWallet(String name) {
    return 'من $name';
  }

  @override
  String goalsToWallet(String name) {
    return 'إلى $name';
  }

  @override
  String goalsMissingRates(String codes) {
    return 'لا سعر صرف لـ$codes، فحُسبت بقيمتها الاسمية.';
  }

  @override
  String get goalsDueToday => 'اليوم';

  @override
  String get goalsDueTomorrow => 'غدًا';

  @override
  String goalsDueInDays(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بعد $n يوم',
      many: 'بعد $n يومًا',
      few: 'بعد $n أيام',
      two: 'بعد يومين',
      one: 'بعد يوم',
    );
    return '$_temp0';
  }

  @override
  String goalsOverdueDays(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'متأخر $n يوم',
      many: 'متأخر $n يومًا',
      few: 'متأخر $n أيام',
      two: 'متأخر يومين',
      one: 'متأخر يومًا',
    );
    return '$_temp0';
  }

  @override
  String goalsDueOn(String date) {
    return 'في $date';
  }

  @override
  String goalsEveryWeeks(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'كل $n أسبوع',
      many: 'كل $n أسبوعًا',
      few: 'كل $n أسابيع',
      two: 'كل أسبوعين',
      one: 'كل أسبوع',
    );
    return '$_temp0';
  }

  @override
  String goalsEveryMonths(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'كل $n شهر',
      many: 'كل $n شهرًا',
      few: 'كل $n أشهر',
      two: 'كل شهرين',
      one: 'كل شهر',
    );
    return '$_temp0';
  }

  @override
  String goalsEveryYears(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'كل $n سنة',
      many: 'كل $n سنةً',
      few: 'كل $n سنوات',
      two: 'كل سنتين',
      one: 'كل سنة',
    );
    return '$_temp0';
  }

  @override
  String get goalsJarNew => 'حصّالة جديدة';

  @override
  String get goalsJarNewSubtitle => 'هدف ادّخار له مبلغ وموعد';

  @override
  String get goalsJarEdit => 'تعديل الحصّالة';

  @override
  String get goalsFieldJarName => 'الاسم';

  @override
  String get goalsFieldJarNameHint => 'مثلًا: السفر';

  @override
  String get goalsFieldTarget => 'المبلغ المستهدف';

  @override
  String get goalsFieldDeadline => 'الموعد النهائي';

  @override
  String get goalsFieldIcon => 'الرمز';

  @override
  String get goalsFieldColor => 'اللون';

  @override
  String get goalsDeposit => 'إيداع';

  @override
  String get goalsWithdraw => 'سحب';

  @override
  String goalsDepositTo(String name) {
    return 'إيداع في $name';
  }

  @override
  String goalsWithdrawFrom(String name) {
    return 'سحب من $name';
  }

  @override
  String goalsWithdrawTooMuch(String amount) {
    return 'المدّخر $amount فقط';
  }

  @override
  String goalsJarReached(String name) {
    return 'بلغت $name هدفها!';
  }

  @override
  String goalsDeposited(String amount) {
    return 'أُودِع $amount';
  }

  @override
  String goalsWithdrawn(String amount) {
    return 'سُحب $amount';
  }

  @override
  String get goalsJarArchived => 'أُرشفت الحصّالة';

  @override
  String get goalsJarRestored => 'أُعيدت الحصّالة';

  @override
  String get goalsArchive => 'أرشفة';

  @override
  String get goalsUnarchive => 'إلغاء الأرشفة';

  @override
  String get goalsArchivedJars => 'حصّالات مؤرشفة';

  @override
  String get goalsJarsEmptyTitle => 'لا حصّالات بعد';

  @override
  String get goalsJarsEmptyBody =>
      'خصّص حصّالة لكل هدف – سفر، طوارئ، هدية – وراقبها تمتلئ.';

  @override
  String get goalsJarsHint =>
      'اسحب الحصّالة لإيداع سريع، واضغط مطوّلًا لبقية الخيارات، واسحب المقبض لترتيبها.';

  @override
  String goalsJarsReachedCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n حصّالة بلغت أهدافها',
      many: '$n حصّالةً بلغت أهدافها',
      few: '$n حصّالات بلغت أهدافها',
      two: 'حصّالتان بلغتا هدفيهما',
      one: 'حصّالة بلغت هدفها',
    );
    return '$_temp0';
  }

  @override
  String get goalsSavedInJars => 'المدّخر في الحصّالات';

  @override
  String get goalsNeededThisMonth => 'المطلوب هذا الشهر';

  @override
  String get goalsOfTargets => 'من الأهداف';

  @override
  String goalsOverallProgress(String percent) {
    return 'التقدّم الكلّي $percent';
  }

  @override
  String goalsNeedPerMonth(String amount) {
    return '$amount شهريًا';
  }

  @override
  String goalsDeadlineOn(String date) {
    return 'حتى $date';
  }

  @override
  String goalsSurplus(String amount) {
    return 'فائض $amount';
  }

  @override
  String goalsTargetOf(String amount) {
    return 'الهدف $amount';
  }

  @override
  String get goalsNoDeadlineHint => 'أضف موعدًا لتعرف المطلوب شهريًا';

  @override
  String get goalsPaceReached => 'بلغت الهدف';

  @override
  String get goalsPaceOnTrack => 'على المسار';

  @override
  String get goalsPaceBehind => 'متأخرة عن الخطة';

  @override
  String get goalsPaceOverdue => 'فات الموعد';

  @override
  String get goalsPaceOpen => 'بلا موعد';

  @override
  String goalsBalanceAfter(String amount) {
    return 'الرصيد بعدها: $amount';
  }

  @override
  String goalsPercentOfTarget(String percent) {
    return '$percent من الهدف';
  }

  @override
  String goalsWalletAmount(String amount) {
    return 'بعملة المحفظة: $amount';
  }

  @override
  String get goalsTrajectory => 'مسار الادّخار';

  @override
  String get goalsHistory => 'السجلّ';

  @override
  String get goalsNoMovements => 'لا إيداعات بعد';

  @override
  String get goalsDeleteJar => 'حذف الحصّالة';

  @override
  String goalsAlidadeHint(String percent) {
    return 'المؤشّر الذهبي يدلّ على موضعك المفترض اليوم ($percent)';
  }

  @override
  String get goalsRemaining => 'المتبقّي';

  @override
  String get goalsSurplusLabel => 'فوق الهدف';

  @override
  String get goalsNeededNow => 'المطلوب الآن';

  @override
  String get goalsPerMonth => 'المطلوب شهريًا';

  @override
  String goalsPerWeekCaption(String amount) {
    return 'أو $amount أسبوعيًا';
  }

  @override
  String goalsDaysLeft(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'باقٍ $n يوم',
      many: 'باقٍ $n يومًا',
      few: 'باقٍ $n أيام',
      two: 'باقٍ يومان',
      one: 'باقٍ يوم واحد',
      zero: 'ينتهي اليوم',
    );
    return '$_temp0';
  }

  @override
  String get goalsAtYourPace => 'بوتيرتك الحالية';

  @override
  String get goalsAfterDeadline => 'بعد الموعد';

  @override
  String get goalsBeforeDeadline => 'قبل الموعد';

  @override
  String goalsSavedTotal(String amount) {
    return 'مدّخر $amount';
  }

  @override
  String get goalsDebtNew => 'دين جديد';

  @override
  String get goalsDebtEdit => 'تعديل الدين';

  @override
  String get goalsFieldDirection => 'الاتجاه';

  @override
  String get goalsIOwe => 'عليّ';

  @override
  String get goalsOwedToMe => 'لي';

  @override
  String get goalsDebtIOweSubtitle => 'دين عليّ';

  @override
  String get goalsDebtOwedSubtitle => 'دين لي عنده';

  @override
  String get goalsFieldPerson => 'الشخص';

  @override
  String get goalsFieldPersonHint => 'اسم الشخص أو الجهة';

  @override
  String get goalsFieldDueDate => 'تاريخ الاستحقاق';

  @override
  String goalsIOweTo(String person) {
    return 'أنا مدين لـ$person';
  }

  @override
  String goalsOwedBy(String person) {
    return '$person مدين لي';
  }

  @override
  String goalsRemainingOf(String remaining, String total) {
    return 'يتبقّى $remaining من $total';
  }

  @override
  String get goalsSettle => 'تسوية';

  @override
  String get goalsReopen => 'إعادة فتح';

  @override
  String get goalsSettled => 'مُسوّى';

  @override
  String goalsSettledOn(String date) {
    return 'سُوّي في $date';
  }

  @override
  String goalsSettledWrittenOff(String date, String amount) {
    return 'سُوّي في $date، وسُومح بـ$amount';
  }

  @override
  String get goalsNoDueDate => 'بلا موعد';

  @override
  String get goalsRecordPayment => 'تسجيل دفعة';

  @override
  String goalsPayTo(String person) {
    return 'دفعة إلى $person';
  }

  @override
  String goalsReceiveFrom(String person) {
    return 'دفعة من $person';
  }

  @override
  String goalsDebtPaidOff(String person) {
    return 'سُدّد الحساب مع $person بالكامل';
  }

  @override
  String goalsPaymentRecorded(String amount) {
    return 'سُجّلت دفعة $amount';
  }

  @override
  String goalsDebtSettled(String person) {
    return 'سُوّي الدين مع $person';
  }

  @override
  String get goalsDebtReopened => 'أُعيد فتح الدين';

  @override
  String get goalsPayments => 'الدفعات';

  @override
  String get goalsNoPayments => 'لا دفعات بعد';

  @override
  String goalsPaidSoFar(String amount) {
    return 'دُفع حتى الآن $amount';
  }

  @override
  String get goalsPaysOff => 'هذه الدفعة تُنهي الدين';

  @override
  String goalsRemainingAfter(String amount) {
    return 'يتبقّى بعدها $amount';
  }

  @override
  String goalsPaidOfTotal(String paid, String total) {
    return '$paid من $total';
  }

  @override
  String get goalsDebtsEmptyTitle => 'لا ديون مسجّلة';

  @override
  String get goalsDebtsEmptyBody =>
      'سجّل ما عليك وما لك عند الآخرين، مع مواعيد السداد والدفعات الجزئية.';

  @override
  String get goalsNoOpenDebts => 'لا ديون مفتوحة هنا';

  @override
  String get goalsSettledDebts => 'ديون مُسوّاة';

  @override
  String get goalsDebtsHint => 'اسحب الدين لتسويته فورًا، ويمكنك التراجع.';

  @override
  String goalsDebtsCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n دين مفتوح',
      many: '$n دينًا مفتوحًا',
      few: '$n ديون مفتوحة',
      two: 'دينان مفتوحان',
      one: 'دين مفتوح واحد',
      zero: 'لا ديون مفتوحة',
    );
    return '$_temp0';
  }

  @override
  String get goalsNetEven => 'الكفّتان متعادلتان';

  @override
  String goalsNetOwedToMe(String amount) {
    return 'الصافي لك: $amount';
  }

  @override
  String goalsNetIOwe(String amount) {
    return 'الصافي عليك: $amount';
  }

  @override
  String goalsOverdueCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n متأخر',
      many: '$n متأخرًا',
      few: '$n متأخرة',
      two: 'متأخران',
      one: 'متأخر واحد',
    );
    return '$_temp0';
  }

  @override
  String get goalsObligationNew => 'التزام جديد';

  @override
  String get goalsObligationNewSubtitle =>
      'إيجار، قسط، اشتراك، مصروف… أي دفعة تتكرر';

  @override
  String get goalsObligationEdit => 'تعديل الالتزام';

  @override
  String get goalsFieldObligationName => 'الاسم';

  @override
  String get goalsFieldObligationNameHint => 'مثلًا: الإيجار';

  @override
  String get goalsFieldFrequency => 'يتكرر';

  @override
  String get goalsWeekly => 'أسبوعيًا';

  @override
  String get goalsMonthly => 'شهريًا';

  @override
  String get goalsYearly => 'سنويًا';

  @override
  String get goalsFieldInterval => 'كل كم فترة';

  @override
  String get goalsFieldIntervalHint => 'واحد: كل فترة، اثنان: كل فترتين…';

  @override
  String get goalsFieldNextDue => 'الاستحقاق القادم';

  @override
  String get goalsFieldPayFromWallet => 'يُدفع من محفظة';

  @override
  String get goalsFieldBudgetItem => 'بند الميزانية';

  @override
  String get goalsNoBudgetItem => 'بلا بند';

  @override
  String get goalsFieldPaidOn => 'تاريخ الدفع';

  @override
  String get goalsMarkPaid => 'دُفع';

  @override
  String goalsMarkPaidFor(String name) {
    return 'تسجيل دفع $name';
  }

  @override
  String get goalsPayOther => 'دفع بمبلغ آخر';

  @override
  String get goalsPayOtherShort => 'مبلغ آخر';

  @override
  String goalsPayObligation(String name) {
    return 'دفع $name';
  }

  @override
  String goalsForDue(String date) {
    return 'عن استحقاق $date';
  }

  @override
  String get goalsSkip => 'تخطّي';

  @override
  String get goalsSkippedEntry => 'تم التخطّي';

  @override
  String get goalsPause => 'إيقاف مؤقت';

  @override
  String get goalsResume => 'استئناف';

  @override
  String get goalsPaused => 'موقوف';

  @override
  String goalsObligationPaid(String date) {
    return 'سُجّل الدفع، والموعد القادم $date';
  }

  @override
  String goalsObligationSkipped(String date) {
    return 'تم التخطّي، والموعد القادم $date';
  }

  @override
  String get goalsObligationPaused => 'أُوقف الالتزام مؤقتًا';

  @override
  String get goalsObligationResumed => 'استُؤنف الالتزام';

  @override
  String get goalsObligationsEmptyTitle => 'لا التزامات دورية';

  @override
  String get goalsObligationsEmptyBody =>
      'أضف ما يتكرر – الإيجار، الأقساط، الاشتراكات – وستصلك تذكرة قبل موعده، ويسجّل «دُفع» المصروف وينقلك إلى الموعد التالي.';

  @override
  String get goalsObligationsHint =>
      'اسحب الالتزام لتسجيل دفعه، ويمكنك التراجع.';

  @override
  String get goalsMonthlyCommitments => 'الالتزامات شهريًا';

  @override
  String goalsActiveCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n التزام نشط',
      many: '$n التزامًا نشطًا',
      few: '$n التزامات نشطة',
      two: 'التزامان نشطان',
      one: 'التزام نشط واحد',
      zero: 'لا التزامات نشطة',
    );
    return '$_temp0';
  }

  @override
  String goalsDueSoonCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n مستحق خلال أسبوع',
      many: '$n مستحقًا خلال أسبوع',
      few: '$n مستحقة خلال أسبوع',
      two: 'مستحقان خلال أسبوع',
      one: 'مستحق خلال أسبوع',
    );
    return '$_temp0';
  }

  @override
  String get goalsSectionOverdue => 'متأخرة';

  @override
  String get goalsSectionThisWeek => 'خلال أسبوع';

  @override
  String get goalsSectionLater => 'لاحقًا';

  @override
  String get goalsSectionPaused => 'موقوفة';

  @override
  String get goalsNextDue => 'الاستحقاق القادم';

  @override
  String get goalsComingUp => 'المواعيد التالية';

  @override
  String get goalsNoHistory => 'لم يُسجّل دفع بعد';

  @override
  String goalsPaidOnForDue(String paid, String due) {
    return 'دُفع في $paid عن $due';
  }

  @override
  String goalsPaidFrom(String wallet) {
    return 'يُدفع من $wallet';
  }

  @override
  String goalsCountsToward(String item) {
    return 'يُحسب على بند $item';
  }

  @override
  String get goalsNoWalletHint =>
      'بلا محفظة: «دُفع» يسجّل الدفعة دون حركة في المحافظ.';

  @override
  String get goalsRecordedInLedger => 'مسجّل في دفتر الحركات';

  @override
  String goalsPeriodsDue(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n فترة مستحقة',
      many: '$n فترةً مستحقة',
      few: '$n فترات مستحقة',
      two: 'فترتان مستحقتان',
      one: 'فترة مستحقة',
    );
    return '$_temp0';
  }

  @override
  String goalsNextDates(String dates) {
    return 'التالي: $dates';
  }

  @override
  String goalsAboutPerMonth(String amount) {
    return 'قرابة $amount شهريًا';
  }

  @override
  String goalsNothingDue(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'لا شيء مستحق خلال $n يوم',
      many: 'لا شيء مستحق خلال $n يومًا',
      few: 'لا شيء مستحق خلال $n أيام',
      two: 'لا شيء مستحق خلال يومين',
      one: 'لا شيء مستحق غدًا',
    );
    return '$_temp0';
  }

  @override
  String goalsMoreDues(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'و$n أخرى',
      many: 'و$n أخرى',
      few: 'و$n أخرى',
      two: 'واثنان آخران',
      one: 'وواحد آخر',
    );
    return '$_temp0';
  }

  @override
  String get goalsRemindersTitle => 'تذكير المستحقات';

  @override
  String get goalsRemindersSubtitle => 'للديون والالتزامات الدورية';

  @override
  String get goalsRemindersEnabled => 'التذكيرات';

  @override
  String get goalsRemindersEnabledHint => 'تنبيه هادئ قبل الموعد وفي يومه';

  @override
  String get goalsRemindersLead => 'تذكير مبكر';

  @override
  String get goalsRemindersLeadNone => 'بلا تذكير مبكر';

  @override
  String goalsRemindersLeadDays(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قبل $n يوم',
      many: 'قبل $n يومًا',
      few: 'قبل $n أيام',
      two: 'قبل يومين',
      one: 'قبل يوم',
    );
    return '$_temp0';
  }

  @override
  String get goalsRemindersOnDueDay => 'وفي يوم الاستحقاق أيضًا';

  @override
  String get goalsRemindersTime => 'الوقت';

  @override
  String get goalsNotifyGroup => 'المال';

  @override
  String get goalsNotifyChannel => 'مواعيد الاستحقاق';

  @override
  String get goalsNotifyChannelDescription =>
      'تذكير بالديون والالتزامات الدورية قبل موعدها';

  @override
  String goalsNotifyObligationTitle(String name) {
    return 'استحقاق $name';
  }

  @override
  String goalsNotifyObligationBody(String when, String amount) {
    return '$when – المبلغ $amount';
  }

  @override
  String goalsNotifyDebtIOweTitle(String person) {
    return 'سداد لـ$person';
  }

  @override
  String goalsNotifyDebtIOweBody(String when, String amount) {
    return '$when – يُستحق عليك $amount';
  }

  @override
  String goalsNotifyDebtOwedTitle(String person) {
    return 'دين على $person';
  }

  @override
  String goalsNotifyDebtOwedBody(String when, String amount) {
    return '$when – يُستحق لك $amount';
  }

  @override
  String get goalsFieldDebtWallet => 'عبر محفظة';

  @override
  String goalsDebtLentFrom(String wallet, String amount) {
    return 'خرج المبلغ من $wallet، فينقص رصيدها $amount';
  }

  @override
  String goalsDebtBorrowedInto(String wallet, String amount) {
    return 'دخل المبلغ إلى $wallet، فيزيد رصيدها $amount';
  }

  @override
  String get goalsDebtNoWalletHint => 'بلا محفظة: تبقى أرصدة المحافظ كما هي.';

  @override
  String get moneyHubNetWorthTitle => 'صافي ثروتك';

  @override
  String moneyHubNetWorthIn(String code) {
    return 'بعملة $code';
  }

  @override
  String get moneyHubNetWorthEmpty =>
      'أضف محفظتك الأولى ليظهر هنا صافي ثروتك بعملتك الأساسية.';

  @override
  String get moneyHubPartWallets => 'المحافظ';

  @override
  String get moneyHubPartJars => 'الحصّالات';

  @override
  String get moneyHubPartOwedToMe => 'لك عند الناس';

  @override
  String get moneyHubPartIOwe => 'عليك';

  @override
  String moneyHubNetWorthSemantics(
    String total,
    String wallets,
    String jars,
    String owed,
    String owe,
  ) {
    return 'صافي ثروتك $total: المحافظ $wallets، الحصّالات $jars، لك $owed، عليك $owe';
  }

  @override
  String get moneyHubRatesAction => 'العملات';

  @override
  String get moneyHubQuickTitle => 'سجّل حركة';

  @override
  String get moneyHubAddExpenseHint => 'سجّل مصروفًا';

  @override
  String get moneyHubAddIncomeHint => 'سجّل دخلًا';

  @override
  String get moneyHubAddTransferHint => 'حوّل بين محفظتين';

  @override
  String get moneyHubWalletsTitle => 'محافظك';

  @override
  String get moneyHubLedgerAction => 'الدفتر';

  @override
  String get moneyHubPlanTitle => 'خطة هذا الشهر';

  @override
  String get moneyHubBudgetAction => 'الميزانية';

  @override
  String get moneyHubDuesTitle => 'المستحقات والادّخار';

  @override
  String get moneyHubGoalsAction => 'الكل';

  @override
  String get moneyHubToolsTitle => 'أدوات المال';

  @override
  String get moneyHubToolLedger => 'الدفتر';

  @override
  String get moneyHubToolLedgerHint => 'المحافظ وأرصدتها وآخر الحركات';

  @override
  String get moneyHubToolTransactions => 'الحركات';

  @override
  String get moneyHubToolTransactionsHint => 'كل الحركات مع البحث والتصفية';

  @override
  String get moneyHubToolBudget => 'الميزانية';

  @override
  String get moneyHubToolBudgetHint => 'الخطة المتداخلة والإنفاق مقابلها';

  @override
  String get moneyHubToolJars => 'الحصّالات';

  @override
  String get moneyHubToolJarsHint => 'الأهداف والمواعيد والإيداعات';

  @override
  String get moneyHubToolDebts => 'الديون';

  @override
  String get moneyHubToolDebtsHint => 'ما عليك وما لك، ومواعيد السداد';

  @override
  String get moneyHubToolBills => 'الالتزامات';

  @override
  String get moneyHubToolBillsHint =>
      'الالتزامات المتكررة؛ «دُفع» ينقل الموعد التالي';

  @override
  String get moneyHubMoonOpenWallet => 'افتح المحفظة';

  @override
  String get moneyHubSettingsSection => 'المال';

  @override
  String get moneyHubSettingsSectionHint =>
      'العملات وأسابيع الشهر وبداية الأسبوع وتذكير المستحقات';

  @override
  String get moneyHubSettingsCurrencies => 'العملة الأساسية والأسعار';

  @override
  String moneyHubSettingsCurrencyCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n عملة',
      many: '$n عملة',
      few: '$n عملات',
      two: 'عملتان',
      one: 'عملة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get moneyHubSettingsWeeks => 'أسابيع الشهر';

  @override
  String moneyHubSettingsWeeksSummary(String weeks) {
    return '$weeks · للتحويل بين الأسبوعي والشهري';
  }

  @override
  String get moneyHubSettingsWeekStart => 'بداية الأسبوع';

  @override
  String get moneyHubSettingsWeekStartHint =>
      'للبنود الأسبوعية في الميزانية وتقارير الأسبوع في الدفتر';

  @override
  String get moneyHubWeekSaturday => 'السبت';

  @override
  String get moneyHubWeekSunday => 'الأحد';

  @override
  String get moneyHubWeekMonday => 'الإثنين';

  @override
  String get moneyHubSettingsReminders => 'تذكير المستحقات';

  @override
  String get moneyHubSettingsRemindersOff => 'متوقف';

  @override
  String get moneyHubSettingsRemindersOnDay => 'في يوم الاستحقاق';

  @override
  String moneyHubSettingsRemindersBoth(String lead) {
    return '$lead وفي يومه';
  }

  @override
  String moneyHubSettingsRemindersAt(String when, String time) {
    return '$when · الساعة $time';
  }

  @override
  String get workTitle => 'العمل';

  @override
  String get workBoards => 'اللوحات';

  @override
  String get workProjects => 'المشاريع';

  @override
  String get workAllProjects => 'كل المشاريع';

  @override
  String get workOpenAll => 'فتح العمل';

  @override
  String get workSep => '، ';

  @override
  String get workSave => 'حفظ';

  @override
  String get workCreate => 'إضافة';

  @override
  String get workToday => 'اليوم';

  @override
  String get workTomorrow => 'غدًا';

  @override
  String get workPickDate => 'تاريخ آخر…';

  @override
  String get workNoDate => 'بلا موعد';

  @override
  String get workClear => 'مسح';

  @override
  String get workNewBoard => 'لوحة جديدة';

  @override
  String get workEditBoard => 'تعديل اللوحة';

  @override
  String get workBoardName => 'اسم اللوحة';

  @override
  String get workBoardNameHint => 'مثلًا: المتجر الإلكتروني';

  @override
  String get workBoardCountry => 'البلد أو النشاط';

  @override
  String get workBoardCountryHint => 'اختر بلدًا أو اكتب وصفًا قصيرًا';

  @override
  String get workBoardColor => 'اللون';

  @override
  String get workBoardOptions => 'خيارات اللوحة';

  @override
  String get workArchive => 'أرشفة';

  @override
  String get workUnarchive => 'إعادة من الأرشيف';

  @override
  String get workArchivedSection => 'اللوحات المؤرشفة';

  @override
  String get workBoardArchived => 'أُرشفت اللوحة';

  @override
  String get workBoardRestored => 'عادت اللوحة من الأرشيف';

  @override
  String get workBoardDeleted => 'حُذفت اللوحة وبطاقاتها';

  @override
  String get workBoardsEmptyTitle => 'ابدأ لوحتك الأولى';

  @override
  String get workBoardsEmptyBody =>
      'لوحة لكل بلد أو نشاط — مثلًا «المتجر الإلكتروني» أو «فريق التوصيل» — بأعمدة: المطلوب، قيد التنفيذ، تمّ.';

  @override
  String get workBoardMissing => 'لم تعد هذه اللوحة موجودة';

  @override
  String workOpenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count بطاقة مفتوحة',
      many: '$count بطاقة مفتوحة',
      few: '$count بطاقات مفتوحة',
      two: 'بطاقتان مفتوحتان',
      one: 'بطاقة مفتوحة',
      zero: 'لا بطاقات مفتوحة',
    );
    return '$_temp0';
  }

  @override
  String workDoneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count منجزة',
      many: '$count منجزة',
      few: '$count منجزة',
      two: 'اثنتان منجزتان',
      one: 'واحدة منجزة',
      zero: 'لا منجز',
    );
    return '$_temp0';
  }

  @override
  String workDueTodayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مستحقة اليوم',
      many: '$count مستحقة اليوم',
      few: '$count مستحقة اليوم',
      two: 'اثنتان مستحقتان اليوم',
      one: 'واحدة مستحقة اليوم',
    );
    return '$_temp0';
  }

  @override
  String workOverdueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count متأخرة',
      many: '$count متأخرة',
      few: '$count متأخرة',
      two: 'اثنتان متأخرتان',
      one: 'واحدة متأخرة',
    );
    return '$_temp0';
  }

  @override
  String workCardsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count بطاقة',
      many: '$count بطاقة',
      few: '$count بطاقات',
      two: 'بطاقتان',
      one: 'بطاقة واحدة',
      zero: 'لا بطاقات',
    );
    return '$_temp0';
  }

  @override
  String workArchivedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count لوحة مؤرشفة',
      many: '$count لوحة مؤرشفة',
      few: '$count لوحات مؤرشفة',
      two: 'لوحتان مؤرشفتان',
      one: 'لوحة مؤرشفة',
    );
    return '$_temp0';
  }

  @override
  String get workColTodo => 'المطلوب';

  @override
  String get workColDoing => 'قيد التنفيذ';

  @override
  String get workColDone => 'تمّ';

  @override
  String get workColumnUntitled => 'عمود';

  @override
  String get workEditColumns => 'تعديل الأعمدة';

  @override
  String get workEditColumnsHint => 'اسحب لإعادة الترتيب، واختر عمود الإنجاز';

  @override
  String get workAddColumn => 'إضافة عمود';

  @override
  String get workColumnName => 'اسم العمود';

  @override
  String get workRenameColumn => 'إعادة تسمية';

  @override
  String get workDeleteColumn => 'حذف العمود';

  @override
  String get workDoneColumn => 'عمود الإنجاز';

  @override
  String get workDoneColumnHint => 'البطاقات فيه تُعدّ منجزة وتُنعش كوكب العمل';

  @override
  String get workMakeDoneColumn => 'اجعله عمود الإنجاز';

  @override
  String get workNeedOneColumn => 'تحتاج اللوحة عمودًا واحدًا على الأقل';

  @override
  String workColumnDeleted(String column) {
    return 'حُذف العمود ونُقلت بطاقاته إلى «$column»';
  }

  @override
  String get workColumnsSaved => 'حُفظت الأعمدة';

  @override
  String get workColumnEmpty => 'لا بطاقات هنا بعد';

  @override
  String get workDropHere => 'أفلِت البطاقة هنا';

  @override
  String get workAddCard => 'إضافة بطاقة';

  @override
  String get workNewCard => 'بطاقة جديدة';

  @override
  String get workEditCard => 'تعديل البطاقة';

  @override
  String get workCardTitle => 'العنوان';

  @override
  String get workCardTitleHint => 'ما المطلوب إنجازه؟';

  @override
  String get workCardNotes => 'ملاحظات';

  @override
  String get workCardAssignee => 'المسؤول';

  @override
  String get workCardAssigneeHint => 'من سيتولّاها؟';

  @override
  String get workCardDue => 'موعد الاستحقاق';

  @override
  String get workCardColumn => 'العمود';

  @override
  String get workCardWindow => 'وقت العمل عليها';

  @override
  String get workCardWindowHint =>
      'تظهر في قائمة ذلك الوقت على الشاشة الرئيسية';

  @override
  String get workNotPlaced => 'غير محدد';

  @override
  String get workCardDeleted => 'حُذفت البطاقة';

  @override
  String get workCardDuplicated => 'نُسخت البطاقة';

  @override
  String workCardMovedTo(String column) {
    return 'نُقلت إلى «$column»';
  }

  @override
  String workCardMovedBoard(String board) {
    return 'نُقلت إلى لوحة «$board»';
  }

  @override
  String get workCardDoneToast => 'أُنجزت، بارك الله فيك';

  @override
  String workCardReopened(String column) {
    return 'أُعيدت إلى «$column»';
  }

  @override
  String get workCardSaved => 'حُفظت البطاقة';

  @override
  String get workMoveToBoard => 'نقل إلى لوحة';

  @override
  String get workMoveToColumn => 'نقل إلى عمود';

  @override
  String workMoveForward(String column) {
    return 'تقديم إلى «$column»';
  }

  @override
  String workMoveBack(String column) {
    return 'إرجاع إلى «$column»';
  }

  @override
  String get workPlaceInWindow => 'ضعها في وقت صلاة';

  @override
  String get workRemoveFromWindow => 'أزلها من وقت الصلاة';

  @override
  String workPlacedToast(String window) {
    return 'وُضعت في «$window»';
  }

  @override
  String get workUnplacedToast => 'أُزيلت من وقت الصلاة';

  @override
  String get workDueSetToast => 'حُدّد موعد الاستحقاق';

  @override
  String workCardSemantics(String title, String column) {
    return '$title، في عمود $column';
  }

  @override
  String get workSwipeHint =>
      'اسحب نحو العمود التالي لتقديمها أو السابق لإرجاعها، واضغط مطوّلًا لسحبها أو لفتح الخيارات';

  @override
  String get workUnassigned => 'بلا مسؤول';

  @override
  String get workDoneBadge => 'منجزة';

  @override
  String workLateDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تأخّر $count يوم',
      many: 'تأخّر $count يومًا',
      few: 'تأخّر $count أيام',
      two: 'تأخّر يومين',
      one: 'تأخّر يومًا',
    );
    return '$_temp0';
  }

  @override
  String workInWindow(String window) {
    return '$window';
  }

  @override
  String workWindowOnDay(String window, String day) {
    return '$window، $day';
  }

  @override
  String get workFilter => 'تصفية';

  @override
  String get workFilterAll => 'الكل';

  @override
  String get workFilterOverdue => 'المتأخرة';

  @override
  String get workFilterToday => 'مستحقة اليوم';

  @override
  String get workFilterWeek => 'هذا الأسبوع';

  @override
  String get workFilterNoDate => 'بلا موعد';

  @override
  String get workFilterAssignee => 'المسؤول';

  @override
  String get workFilterDue => 'الموعد';

  @override
  String get workFilterClear => 'إلغاء التصفية';

  @override
  String get workFilterNoMatch => 'لا بطاقات تطابق التصفية';

  @override
  String get workTop3Title => 'أهم ثلاث اليوم';

  @override
  String get workTop3Subtitle => 'ثلاث أولويات تكفي ليوم مبارك';

  @override
  String get workTop3Empty => 'اختر ما يستحق تركيزك اليوم — ثلاثة أشياء تكفي.';

  @override
  String get workTop3Choose => 'اختر';

  @override
  String get workTop3ChooseTitle => 'اختر أهم ثلاث';

  @override
  String workTop3SlotsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بقي $count مكان',
      many: 'بقي $count مكانًا',
      few: 'بقيت $count أماكن',
      two: 'بقي مكانان',
      one: 'بقي مكان واحد',
      zero: 'اكتملت الثلاث',
    );
    return '$_temp0';
  }

  @override
  String get workTop3NoCandidates => 'لا بطاقات أو مهام مفتوحة لتختار منها';

  @override
  String workTop3Progress(String done, String total) {
    return '$done من $total';
  }

  @override
  String get workTop3AllDone => 'أنجزت أهم ثلاث اليوم — بارك الله في وقتك';

  @override
  String get workTop3Add => 'أضف إلى أهم ثلاث';

  @override
  String get workTop3Remove => 'أزل من أهم ثلاث';

  @override
  String get workTop3Added => 'أُضيفت إلى أهم ثلاث';

  @override
  String get workTop3Removed => 'أُزيلت من أهم ثلاث';

  @override
  String get workTop3Toggle => 'من أهم ثلاث اليوم';

  @override
  String get workTop3FullTitle => 'أهم ثلاث مكتملة';

  @override
  String workTop3FullBody(String title) {
    return 'اختر ما تستبدله بـ«$title»';
  }

  @override
  String get workTop3Swapped => 'استُبدلت في أهم ثلاث';

  @override
  String get workTop3FullShort => 'أهم ثلاث مكتملة';

  @override
  String get workCarryTitle => 'من تركيز الأمس';

  @override
  String workCarryBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بقي $count أمر لم يكتمل. أتنقلها إلى اليوم؟',
      many: 'بقي $count أمرًا لم يكتمل. أتنقلها إلى اليوم؟',
      few: 'بقيت $count أمور لم تكتمل. أتنقلها إلى اليوم؟',
      two: 'بقي أمران لم يكتملا. أتنقلهما إلى اليوم؟',
      one: 'بقي أمر واحد لم يكتمل. أتنقله إلى اليوم؟',
    );
    return '$_temp0';
  }

  @override
  String get workCarryOver => 'انقلها إلى اليوم';

  @override
  String get workStartFresh => 'ابدأ من جديد';

  @override
  String get workCarriedToast => 'انتقلت إلى تركيز اليوم';

  @override
  String get workFreshToast => 'بداية جديدة لليوم';

  @override
  String get workKindTask => 'مهمة';

  @override
  String get workItemDoneToast => 'أُنجزت';

  @override
  String get workItemReopenedToast => 'أُعيد فتحها';

  @override
  String get workTodayTitle => 'العمل اليوم';

  @override
  String get workTodayAllClear => 'لا شيء مستحق اليوم';

  @override
  String get workTodayTop3 => 'أهم ثلاث';

  @override
  String workTodayTop3Line(String done, String total) {
    return 'أهم ثلاث: $done من $total';
  }

  @override
  String get workNewProject => 'مشروع جديد';

  @override
  String get workEditProject => 'تعديل المشروع';

  @override
  String get workProjectName => 'اسم المشروع';

  @override
  String get workProjectNameHint => 'مثلًا: إطلاق منتج جديد';

  @override
  String get workProjectDescription => 'الوصف';

  @override
  String get workProjectDeadline => 'الموعد النهائي';

  @override
  String get workProjectStatus => 'الحالة';

  @override
  String get workStatusActive => 'نشط';

  @override
  String get workStatusPaused => 'متوقف مؤقتًا';

  @override
  String get workStatusDone => 'مكتمل';

  @override
  String get workProjectPlanet => 'الكوكب';

  @override
  String get workProjectColor => 'اللون';

  @override
  String get workChecklist => 'قائمة الخطوات';

  @override
  String get workAddItemHint => 'أضف خطوة…';

  @override
  String get workAddItem => 'إضافة خطوة';

  @override
  String get workEditItem => 'تعديل الخطوة';

  @override
  String get workItemBody => 'الخطوة';

  @override
  String get workItemDue => 'موعد الخطوة';

  @override
  String get workItemDeleted => 'حُذفت الخطوة';

  @override
  String get workChecklistEmpty =>
      'قسّم المشروع إلى خطوات صغيرة — تبدأ الرحلة بخطوة.';

  @override
  String get workProjectTasks => 'مهام المشروع';

  @override
  String get workProjectTasksEmpty =>
      'المهام التي تضعها للمشروع في أوقات الصلاة تظهر هنا';

  @override
  String get workAddProjectTask => 'مهمة في وقت صلاة';

  @override
  String get workTaskTitle => 'المهمة';

  @override
  String get workTaskWindow => 'الوقت';

  @override
  String get workTaskDay => 'اليوم';

  @override
  String get workProjectDeleted => 'حُذف المشروع';

  @override
  String get workProjectDuplicated => 'نُسخ المشروع';

  @override
  String get workProjectComplete => 'اكتمل المشروع، ما شاء الله!';

  @override
  String get workProjectMissing => 'لم يعد هذا المشروع موجودًا';

  @override
  String get workProjectsEmptyTitle => 'لا مشاريع بعد';

  @override
  String get workProjectsEmptyBody =>
      'مشروع بخطوات وموعد نهائي — مثلًا «إطلاق منتج جديد» أو «تجديد الموقع».';

  @override
  String workStatusChanged(String status) {
    return 'الحالة: $status';
  }

  @override
  String get workSetStatus => 'تغيير الحالة';

  @override
  String workDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يوم',
      many: '$count يومًا',
      few: '$count أيام',
      two: 'يومان',
      one: 'يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String get workDaysLeftCaption => 'حتى الموعد النهائي';

  @override
  String get workDueTodayCaption => 'الموعد النهائي اليوم';

  @override
  String get workDueTomorrowCaption => 'الموعد النهائي غدًا';

  @override
  String workOverdueDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'فات الموعد بـ$count يوم',
      many: 'فات الموعد بـ$count يومًا',
      few: 'فات الموعد بـ$count أيام',
      two: 'فات الموعد بيومين',
      one: 'فات الموعد بيوم',
    );
    return '$_temp0';
  }

  @override
  String get workNoDeadline => 'بلا موعد نهائي';

  @override
  String workDeadlineOn(String date) {
    return 'الموعد: $date';
  }

  @override
  String workItemsProgress(String done, String total) {
    return '$done من $total خطوات';
  }

  @override
  String get workCountryJO => 'الأردن';

  @override
  String get workCountrySA => 'السعودية';

  @override
  String get workCountryAE => 'الإمارات';

  @override
  String get workCountryKW => 'الكويت';

  @override
  String get workCountryQA => 'قطر';

  @override
  String get workCountryBH => 'البحرين';

  @override
  String get workCountryOM => 'عُمان';

  @override
  String get workCountryIQ => 'العراق';

  @override
  String get workCountrySY => 'سوريا';

  @override
  String get workCountryLB => 'لبنان';

  @override
  String get workCountryPS => 'فلسطين';

  @override
  String get workCountryEG => 'مصر';

  @override
  String get workCountryLY => 'ليبيا';

  @override
  String get workCountryTN => 'تونس';

  @override
  String get workCountryDZ => 'الجزائر';

  @override
  String get workCountryMA => 'المغرب';

  @override
  String get workCountrySD => 'السودان';

  @override
  String get workCountryYE => 'اليمن';

  @override
  String get workCountryTR => 'تركيا';

  @override
  String get familyTitle => 'العائلة والأحبّة';

  @override
  String get familyTodayTitle => 'صلة اليوم';

  @override
  String get familyOpenAll => 'عرض الكل';

  @override
  String get familyAddPerson => 'إضافة شخص';

  @override
  String get familyEmptyTitle => 'دائرتك القريبة تبدأ هنا';

  @override
  String get familyEmptyBody =>
      'أضف من تحبّ أن تبقى على صلة به، واختر كل كم يومًا تتواصل — مثلًا: «أمي، كل يومين».';

  @override
  String get familySortUrgency => 'حسب الأولوية';

  @override
  String get familySortManual => 'ترتيبي الخاص';

  @override
  String get familySortLabel => 'طريقة الترتيب';

  @override
  String get familyRemindersTitle => 'تذكيرات الصلة';

  @override
  String get familyGroupOverdue => 'فات موعدهم';

  @override
  String get familyGroupDueToday => 'موعدهم اليوم';

  @override
  String get familyGroupThisWeek => 'خلال هذا الأسبوع';

  @override
  String get familyGroupInTouch => 'على تواصل';

  @override
  String get familyGroupNoRhythm => 'بلا موعد محدّد';

  @override
  String familyHeroWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count شخص ينتظرون سؤالك',
      many: '$count شخصًا ينتظرون سؤالك',
      few: '$count أشخاص ينتظرون سؤالك',
      two: 'شخصان ينتظران سؤالك',
      one: 'شخص واحد ينتظر سؤالك',
      zero: 'لا أحد ينتظر',
    );
    return '$_temp0';
  }

  @override
  String get familyHeroAllGood => 'الجميع على تواصل';

  @override
  String get familyHeroBlessing => 'بارك الله في وصلك';

  @override
  String familyHeroInTouch(String inTouch, String total) {
    return '$inTouch من $total على تواصل';
  }

  @override
  String get familyHeroNoRhythm =>
      'حدّد كل كم تتواصل مع كل شخص لتظهر هنا مواعيدهم';

  @override
  String familyStatusOverdue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'فات الموعد بـ$count يوم',
      many: 'فات الموعد بـ$count يومًا',
      few: 'فات الموعد بـ$count أيام',
      two: 'فات الموعد بيومين',
      one: 'فات الموعد بيوم',
    );
    return '$_temp0';
  }

  @override
  String get familyStatusDueToday => 'موعد السؤال اليوم';

  @override
  String familyStatusDueIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'الموعد بعد $count يوم',
      many: 'الموعد بعد $count يومًا',
      few: 'الموعد بعد $count أيام',
      two: 'الموعد بعد يومين',
      one: 'الموعد غدًا',
    );
    return '$_temp0';
  }

  @override
  String get familyStatusNoRhythm => 'بلا موعد';

  @override
  String get familyLastNever => 'لم يُسجَّل تواصل بعد';

  @override
  String familyLastDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'آخر تواصل قبل $count يوم',
      many: 'آخر تواصل قبل $count يومًا',
      few: 'آخر تواصل قبل $count أيام',
      two: 'آخر تواصل قبل يومين',
      one: 'آخر تواصل أمس',
      zero: 'آخر تواصل اليوم',
    );
    return '$_temp0';
  }

  @override
  String familyInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بعد $count يوم',
      many: 'بعد $count يومًا',
      few: 'بعد $count أيام',
      two: 'بعد يومين',
      one: 'غدًا',
      zero: 'اليوم',
    );
    return '$_temp0';
  }

  @override
  String familyDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قبل $count يوم',
      many: 'قبل $count يومًا',
      few: 'قبل $count أيام',
      two: 'قبل يومين',
      one: 'أمس',
      zero: 'اليوم',
    );
    return '$_temp0';
  }

  @override
  String familyDaysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يوم',
      many: '$count يومًا',
      few: '$count أيام',
      two: 'يومان',
      one: 'يوم واحد',
      zero: '$count يوم',
    );
    return '$_temp0';
  }

  @override
  String familyRhythmEvery(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'كل $count يوم',
      many: 'كل $count يومًا',
      few: 'كل $count أيام',
      two: 'كل يومين',
      one: 'يوميًا',
    );
    return '$_temp0';
  }

  @override
  String get familyRhythmWeekly => 'أسبوعيًا';

  @override
  String get familyRhythmBiweekly => 'كل أسبوعين';

  @override
  String get familyRhythmMonthly => 'شهريًا';

  @override
  String get familyRhythmNone => 'بلا إيقاع';

  @override
  String get familyRhythmCustom => 'عدد آخر';

  @override
  String get familyRhythmCustomLabel => 'كل كم يومًا؟';

  @override
  String get familyUnitDays => 'يوم';

  @override
  String get familyChannelCall => 'مكالمة';

  @override
  String get familyChannelVisit => 'زيارة';

  @override
  String get familyChannelMessage => 'رسالة';

  @override
  String get familyChannelOther => 'أخرى';

  @override
  String get familyContacted => 'تواصلت';

  @override
  String get familyContactedDetails => 'تواصلت… مع التفاصيل';

  @override
  String get familyCall => 'اتصال';

  @override
  String get familySms => 'رسالة نصية';

  @override
  String get familyWhatsApp => 'واتساب';

  @override
  String get familyLaunchFailed => 'تعذّر فتح التطبيق على هذا الجهاز';

  @override
  String get familyMoonShow => 'أظهِر في المدار';

  @override
  String get familyMoonHide => 'أخفِ من المدار';

  @override
  String get familyOpenProfile => 'فتح الملف';

  @override
  String get familyEdit => 'تعديل';

  @override
  String get familyDelete => 'حذف';

  @override
  String familyContactedToast(String name) {
    return 'سُجِّل تواصلك مع $name';
  }

  @override
  String familyDeletedToast(String name) {
    return 'حُذف $name';
  }

  @override
  String familySavedToast(String name) {
    return 'حُفظ $name';
  }

  @override
  String get familyContactDeletedToast => 'حُذف التواصل من السجل';

  @override
  String get familyContactUpdatedToast => 'عُدِّل التواصل';

  @override
  String familyMoonShownToast(String name) {
    return 'أُضيف $name إلى المدار';
  }

  @override
  String familyMoonHiddenToast(String name) {
    return 'أُخفي $name من المدار';
  }

  @override
  String get familyNewPerson => 'شخص جديد';

  @override
  String get familyNewPersonSubtitle => 'من تحبّ أن تبقى قريبًا منه';

  @override
  String familyEditTitle(String name) {
    return 'تعديل $name';
  }

  @override
  String get familyFieldName => 'الاسم';

  @override
  String get familyFieldNameHint => 'مثلًا: أمي، أحمد';

  @override
  String get familyFieldNameRequired => 'اكتب الاسم';

  @override
  String get familyFieldRelation => 'صلة القرابة';

  @override
  String get familyFieldRelationHint => 'اختر أو اكتب';

  @override
  String get familyFieldRhythm => 'كل كم تتواصل؟';

  @override
  String get familyFieldLastContact => 'آخر تواصل';

  @override
  String get familyFieldPhone => 'رقم الهاتف';

  @override
  String get familyFieldPhoneHint => 'مع رمز الدولة ليعمل واتساب';

  @override
  String get familyFieldBirthday => 'تاريخ الميلاد';

  @override
  String get familyBirthdayYearUnknown => 'السنة غير معروفة';

  @override
  String get familyBirthdayNone => 'بلا تاريخ';

  @override
  String get familyFieldNotes => 'ملاحظات';

  @override
  String get familyFieldNotesHint => 'اهتمامات، مناسبات، أفكار هدايا…';

  @override
  String get familyFieldColor => 'اللون';

  @override
  String get familyFieldMoon => 'قمر في المدار';

  @override
  String get familyFieldMoonHint => 'يظهر قمرًا حول كوكب العائلة في الرئيسية';

  @override
  String get familyMoreDetails => 'تفاصيل أكثر';

  @override
  String get familyFewerDetails => 'تفاصيل أقل';

  @override
  String get familySave => 'حفظ';

  @override
  String get familyWhenNow => 'الآن';

  @override
  String get familyWhenToday => 'اليوم';

  @override
  String get familyWhenEarlierToday => 'في وقت سابق اليوم';

  @override
  String get familyWhenYesterday => 'أمس';

  @override
  String get familyWhenWeekAgo => 'قبل أسبوع';

  @override
  String get familyWhenUnknown => 'لا أذكر';

  @override
  String get familyWhenPick => 'تاريخ آخر';

  @override
  String familyContactedTitle(String name) {
    return 'تواصلت مع $name';
  }

  @override
  String get familyContactedSubtitle => 'سجّل كيف ومتى — ولو بكلمة';

  @override
  String get familyEditContactTitle => 'تعديل التواصل';

  @override
  String get familyFieldChannel => 'الطريقة';

  @override
  String get familyFieldWhen => 'متى';

  @override
  String get familyFieldNote => 'ملاحظة';

  @override
  String get familyFieldNoteHint => 'عمّ تحدّثتما؟';

  @override
  String get familyFutureError => 'لا يمكن تسجيل تواصل في المستقبل';

  @override
  String get familyLog => 'سجّل';

  @override
  String get familyRhythmCardTitle => 'إيقاع الصلة';

  @override
  String get familyStatAverage => 'متوسط الفاصل';

  @override
  String get familyStatOnRhythm => 'في الموعد';

  @override
  String get familyStatLongestGap => 'أطول انقطاع';

  @override
  String get familyStatRecent => 'آخر ٩٠ يومًا';

  @override
  String familyStatTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مرّة',
      many: '$count مرّة',
      few: '$count مرّات',
      two: 'مرّتان',
      one: 'مرّة واحدة',
      zero: 'لا مرّات',
    );
    return '$_temp0';
  }

  @override
  String familyVsRhythm(String rhythm) {
    return 'الإيقاع: $rhythm';
  }

  @override
  String get familyChartCaption => 'الفواصل بين آخر مرّات التواصل';

  @override
  String get familyStatsEmpty =>
      'بعد مرّتين أو ثلاث من التواصل تظهر هنا إحصاءاتك';

  @override
  String get familyHistoryTitle => 'سجل التواصل';

  @override
  String get familyHistoryEmpty =>
      'لا تواصل مسجّل بعد. اضغط «تواصلت» بعد كل مكالمة أو زيارة.';

  @override
  String get familyNotesTitle => 'ملاحظات';

  @override
  String get familyNotesAdd => 'أضف ملاحظة';

  @override
  String get familyBirthdayTitle => 'ذكرى الميلاد';

  @override
  String get familyBirthdayTodayBadge => 'اليوم!';

  @override
  String familyAgeTurning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عام',
      many: '$count عامًا',
      few: '$count أعوام',
      two: 'عامان',
      one: 'عام واحد',
    );
    return '$_temp0';
  }

  @override
  String familyBirthdayUpcoming(String name, String when) {
    return 'ذكرى ميلاد $name $when';
  }

  @override
  String familyCardMore(String count) {
    return 'و$count غيرهم';
  }

  @override
  String get familyCardEmpty => 'أضف أحبّتك لتبقى على صلة بهم';

  @override
  String get familyDigestTitle => 'ملخّص يومي لطيف';

  @override
  String get familyDigestHint =>
      'إشعار واحد في اليوم بمن حان موعد السؤال عنهم — لا إشعار لكل شخص';

  @override
  String get familyDigestTime => 'وقت الملخّص';

  @override
  String get familyBirthdayReminders => 'تذكير بذكرى الميلاد';

  @override
  String get familyBirthdayRemindersHint => 'قبلها بيوم وفي يومها';

  @override
  String get familyBirthdayTime => 'وقت تذكير الميلاد';

  @override
  String get familyNotifyGroup => 'العائلة والأحبّة';

  @override
  String get familyNotifyChannel => 'تذكيرات الصلة';

  @override
  String get familyNotifyChannelDescription =>
      'ملخّص الصلة اليومي وتذكيرات ذكرى الميلاد';

  @override
  String familyDigestNotifyTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count شخص ينتظرون سؤالك اليوم',
      many: '$count شخصًا ينتظرون سؤالك اليوم',
      few: '$count أشخاص ينتظرون سؤالك اليوم',
      two: 'شخصان ينتظران سؤالك اليوم',
      one: 'شخص واحد ينتظر سؤالك اليوم',
    );
    return '$_temp0';
  }

  @override
  String familyDigestNotifyBody(String names) {
    return '$names — مكالمة قصيرة تكفي.';
  }

  @override
  String familyBirthdayEveTitle(String name) {
    return 'غدًا ذكرى ميلاد $name';
  }

  @override
  String get familyBirthdayEveBody => 'جهّز كلمة طيبة أو هدية صغيرة.';

  @override
  String familyBirthdayDayTitle(String name) {
    return 'اليوم ذكرى ميلاد $name';
  }

  @override
  String get familyBirthdayDayBody => 'بادِر بالتهنئة.';

  @override
  String get familyListSep => '، ';

  @override
  String get familyDot => ' · ';

  @override
  String get familyRelFather => 'أبي';

  @override
  String get familyRelMother => 'أمي';

  @override
  String get familyRelWife => 'زوجتي';

  @override
  String get familyRelHusband => 'زوجي';

  @override
  String get familyRelSon => 'ابني';

  @override
  String get familyRelDaughter => 'ابنتي';

  @override
  String get familyRelBrother => 'أخي';

  @override
  String get familyRelSister => 'أختي';

  @override
  String get familyRelGrandfather => 'جدّي';

  @override
  String get familyRelGrandmother => 'جدّتي';

  @override
  String get familyRelUncle => 'عمّي';

  @override
  String get familyRelMaternalUncle => 'خالي';

  @override
  String get familyRelAunt => 'عمّتي';

  @override
  String get familyRelMaternalAunt => 'خالتي';

  @override
  String get familyRelInLaw => 'نسيبي';

  @override
  String get familyRelRelative => 'قريبي';

  @override
  String get familyRelFriend => 'صديقي';

  @override
  String get familyRelColleague => 'زميلي';

  @override
  String get familyRelPartner => 'شريكي';

  @override
  String get familyRelNeighbour => 'جاري';

  @override
  String get familyRelTeacher => 'معلّمي';

  @override
  String get travelTitle => 'السفر';

  @override
  String get travelTabTrips => 'الرحلات';

  @override
  String get travelTabDocuments => 'الوثائق';

  @override
  String get travelTabTemplates => 'قوائم التجهيز';

  @override
  String get travelAddTrip => 'رحلة جديدة';

  @override
  String get travelAddDocument => 'وثيقة جديدة';

  @override
  String get travelAddTemplate => 'قائمة جديدة';

  @override
  String get travelSectionCurrent => 'في الطريق الآن';

  @override
  String get travelSectionUpcoming => 'رحلات قادمة';

  @override
  String get travelSectionPast => 'رحلات سابقة';

  @override
  String get travelTripsEmptyTitle => 'لا رحلات بعد';

  @override
  String get travelTripsEmptyBody =>
      'خطّط لرحلتك القادمة: الوجهة والمواعيد وقائمة التجهيز، وأوقات الصلاة والقبلة هناك.';

  @override
  String get travelTripsEmptyExample =>
      'مثلًا: عمرة في الشتاء، أو رحلة عمل قصيرة';

  @override
  String travelShowPast(String n) {
    return 'عرض الرحلات السابقة ($n)';
  }

  @override
  String get travelHidePast => 'إخفاء الرحلات السابقة';

  @override
  String get travelCountdownToday => 'السفر اليوم';

  @override
  String get travelCountdownTomorrow => 'السفر غدًا';

  @override
  String travelCountdownIn(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بعد $n يوم',
      many: 'بعد $n يومًا',
      few: 'بعد $n أيام',
      two: 'بعد يومين',
      one: 'بعد يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String travelCountdownDayOf(String day, String total) {
    return 'اليوم $day من $total';
  }

  @override
  String travelCountdownDay(String day) {
    return 'اليوم $day';
  }

  @override
  String travelCountdownEnded(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'انتهت قبل $n يوم',
      many: 'انتهت قبل $n يومًا',
      few: 'انتهت قبل $n أيام',
      two: 'انتهت قبل يومين',
      one: 'انتهت أمس',
    );
    return '$_temp0';
  }

  @override
  String get travelCountdownFinished => 'انتهت';

  @override
  String get travelCountdownUndated => 'بلا موعد بعد';

  @override
  String travelDays(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n يوم',
      many: '$n يومًا',
      few: '$n أيام',
      two: 'يومان',
      one: 'يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String get travelOpenEnded => 'بلا موعد عودة';

  @override
  String get travelStatusPlanned => 'مخطّط لها';

  @override
  String get travelStatusActive => 'جارية';

  @override
  String get travelStatusDone => 'منتهية';

  @override
  String get travelStatusAuto => 'حسب التواريخ';

  @override
  String travelStatusAutoHint(String status) {
    return 'تتغيّر الحالة وحدها مع التواريخ: الآن «$status»';
  }

  @override
  String get travelStatusManualHint => 'حالة يدوية لا تتبع التواريخ';

  @override
  String get travelMarkDone => 'أنهِ الرحلة';

  @override
  String get travelFollowDates => 'اتبع التواريخ';

  @override
  String get travelSheetNewTitle => 'رحلة جديدة';

  @override
  String get travelSheetEditTitle => 'تعديل الرحلة';

  @override
  String get travelSheetSubtitle => 'الوجهة والمواعيد، وأوقات الصلاة هناك';

  @override
  String get travelFieldDestination => 'الوجهة';

  @override
  String get travelFieldDestinationHint => 'ابحث عن مدينة أو اكتب أي وجهة';

  @override
  String get travelDestinationRequired => 'اكتب الوجهة';

  @override
  String travelDestinationFree(String name) {
    return 'استخدم «$name» كما كتبتها';
  }

  @override
  String get travelDestinationFreeHint =>
      'بلا أوقات صلاة ولا قبلة؛ اختر مدينة من القائمة لتظهر';

  @override
  String get travelDestinationChange => 'تغيير';

  @override
  String travelDestinationCity(String zone) {
    return '$zone، القبلة وأوقات الصلاة متاحة';
  }

  @override
  String get travelFieldStart => 'المغادرة';

  @override
  String get travelFieldEnd => 'العودة';

  @override
  String get travelFieldEndHint => 'اتركها فارغة إن لم تحدّد العودة بعد';

  @override
  String get travelEndBeforeStart => 'العودة قبل المغادرة';

  @override
  String get travelFieldStatus => 'الحالة';

  @override
  String get travelFieldColor => 'اللون';

  @override
  String get travelFieldNotes => 'ملاحظات';

  @override
  String get travelFieldNotesHint => 'الحجوزات، العناوين، ما يجب تذكّره…';

  @override
  String get travelSave => 'حفظ';

  @override
  String get travelCreate => 'أضف الرحلة';

  @override
  String get travelNoDate => 'لم يُحدَّد';

  @override
  String get travelLocalTime => 'الساعة هناك';

  @override
  String travelTimeAhead(String duration) {
    return 'تسبق هاتفك بـ$duration';
  }

  @override
  String travelTimeBehind(String duration) {
    return 'تتأخر عن هاتفك $duration';
  }

  @override
  String get travelTimeSame => 'بتوقيت هاتفك نفسه';

  @override
  String travelHours(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n ساعة',
      many: '$n ساعة',
      few: '$n ساعات',
      two: 'ساعتين',
      one: 'ساعة',
    );
    return '$_temp0';
  }

  @override
  String travelHoursMinutes(String hm) {
    return '$hm ساعة';
  }

  @override
  String get travelTripDates => 'المواعيد';

  @override
  String get travelPackingTitle => 'قائمة التجهيز';

  @override
  String travelPackedCount(String packed, String total) {
    return '$packed من $total';
  }

  @override
  String get travelPackingEmptyTitle => 'لا شيء في القائمة بعد';

  @override
  String get travelPackingEmptyBody =>
      'أضف ما ستحتاجه، أو ابدأ من قائمة جاهزة.';

  @override
  String get travelPackingAllDone => 'اكتملت الحقيبة، سفرًا موفّقًا';

  @override
  String travelPackingRemaining(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بقي $n غرض',
      many: 'بقي $n غرضًا',
      few: 'بقيت $n أغراض',
      two: 'بقي غرضان',
      one: 'بقي غرض واحد',
    );
    return '$_temp0';
  }

  @override
  String get travelAddItem => 'أضف غرضًا';

  @override
  String get travelAddItemHint => 'مثلًا: شاحن الهاتف';

  @override
  String travelAddItemTo(String category) {
    return 'أضف إلى «$category»…';
  }

  @override
  String travelAddItemIn(String category) {
    return 'إلى: $category';
  }

  @override
  String get travelFromTemplate => 'من قائمة جاهزة';

  @override
  String get travelSaveAsTemplate => 'احفظها قائمة جاهزة';

  @override
  String get travelUnpackAll => 'أفرغ الحقيبة';

  @override
  String travelTemplatesApplied(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أُضيف $n غرض',
      many: 'أُضيف $n غرضًا',
      few: 'أُضيفت $n أغراض',
      two: 'أُضيف غرضان',
      one: 'أُضيف غرض واحد',
      zero: 'كل الأغراض موجودة في القائمة أصلًا',
    );
    return '$_temp0';
  }

  @override
  String get travelPickTemplatesTitle => 'اختر قوائم جاهزة';

  @override
  String get travelPickTemplatesHint => 'تُدمج القوائم دون تكرار ما في حقيبتك';

  @override
  String get travelPickTemplatesAdd => 'أضف إلى الرحلة';

  @override
  String get travelTemplateNameTitle => 'احفظها قائمة جاهزة';

  @override
  String travelTemplateSaved(String name) {
    return 'حُفظت «$name»';
  }

  @override
  String get travelItemNewTitle => 'غرض جديد';

  @override
  String get travelItemEditTitle => 'تعديل الغرض';

  @override
  String get travelFieldItem => 'الغرض';

  @override
  String get travelItemRequired => 'اكتب الغرض';

  @override
  String get travelFieldCategory => 'الفئة';

  @override
  String get travelMoveToCategory => 'انقل إلى فئة';

  @override
  String get travelItemPacked => 'في الحقيبة';

  @override
  String get travelItemNotPacked => 'لم يُحزم بعد';

  @override
  String get travelPack => 'في الحقيبة';

  @override
  String get travelUnpack => 'أخرِجه';

  @override
  String get travelCatDocuments => 'الأوراق والمال';

  @override
  String get travelCatClothes => 'الملابس';

  @override
  String get travelCatToiletries => 'العناية الشخصية';

  @override
  String get travelCatHealth => 'الصحة والأدوية';

  @override
  String get travelCatElectronics => 'الأجهزة والشواحن';

  @override
  String get travelCatPrayer => 'العبادة';

  @override
  String get travelCatMisc => 'أغراض أخرى';

  @override
  String get travelCatNew => 'فئة جديدة';

  @override
  String get travelCatNewHint => 'اسم الفئة';

  @override
  String travelPrayerTitle(String place) {
    return 'الصلاة في $place';
  }

  @override
  String get travelPrayerMethodNote =>
      'بطريقة الحساب في إعداداتك، على توقيت الوجهة';

  @override
  String travelPrayerNext(String prayer, String duration) {
    return '$prayer بعد $duration';
  }

  @override
  String get travelPrayerUseHere => 'اعتمدها موقعًا لصلاتي أثناء السفر';

  @override
  String get travelPrayerIsLocation => 'هذه وجهة صلاتك الآن';

  @override
  String travelPrayerUsed(String place) {
    return 'صارت أوقات صلاتك على توقيت $place';
  }

  @override
  String get travelPrayerNoPlace =>
      'اختر الوجهة من قائمة المدن لتظهر أوقات الصلاة والقبلة هناك.';

  @override
  String get travelPrayerPickCity => 'اختر المدينة';

  @override
  String get travelPrayerToday => 'اليوم';

  @override
  String get travelQiblaTitle => 'القبلة من هناك';

  @override
  String travelQiblaBearing(String bearing) {
    return '$bearing من الشمال';
  }

  @override
  String travelQiblaDistance(String distance) {
    return '$distance إلى الكعبة';
  }

  @override
  String get travelQiblaAtKaaba => 'أنت عند الكعبة';

  @override
  String travelQiblaSemantics(String bearing) {
    return 'اتجاه القبلة $bearing';
  }

  @override
  String travelWarnBeforeTrip(String doc, String date) {
    return '$doc: الصلاحية تنتهي قبل السفر ($date)';
  }

  @override
  String travelWarnDuringTrip(String doc, String date) {
    return '$doc: الصلاحية تنتهي أثناء الرحلة ($date)';
  }

  @override
  String travelWarnValidity(String doc, String months) {
    return '$doc: تنتهي الصلاحية بعد عودتك بأقل من $months أشهر، ودول كثيرة تشترط مدة أطول';
  }

  @override
  String travelWarnTrip(String destination) {
    return 'رحلة $destination';
  }

  @override
  String get travelDocsEmptyTitle => 'لا وثائق بعد';

  @override
  String get travelDocsEmptyBody =>
      'سجّل الجوازات والتأشيرات والرخص ليذكّرك مدار قبل انتهائها، وينبّهك إن انتهت قبل رحلة.';

  @override
  String get travelDocNew => 'وثيقة جديدة';

  @override
  String get travelDocEdit => 'تعديل الوثيقة';

  @override
  String get travelDocSubtitle => 'تذكير قبل الانتهاء بالمدة التي تختارها';

  @override
  String get travelDocName => 'الوثيقة';

  @override
  String get travelDocNameHint => 'جواز السفر، تأشيرة، رخصة قيادة…';

  @override
  String get travelDocNameRequired => 'اكتب اسم الوثيقة';

  @override
  String get travelDocHolder => 'صاحبها';

  @override
  String get travelDocHolderHint => 'لمن هذه الوثيقة؟';

  @override
  String get travelDocNumber => 'الرقم';

  @override
  String get travelDocExpiry => 'تاريخ الانتهاء';

  @override
  String get travelDocRemind => 'ذكّرني';

  @override
  String travelDocNumberShort(String last) {
    return 'رقم $last';
  }

  @override
  String get travelRemindOnDay => 'يوم الانتهاء فقط';

  @override
  String get travelRemindWeek => 'قبل أسبوع';

  @override
  String get travelRemindTwoWeeks => 'قبل أسبوعين';

  @override
  String get travelRemindMonth => 'قبل شهر';

  @override
  String get travelRemindTwoMonths => 'قبل شهرين';

  @override
  String travelRemindMonths(String n) {
    return 'قبل $n أشهر';
  }

  @override
  String travelRemindDays(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قبل $n يوم',
      many: 'قبل $n يومًا',
      few: 'قبل $n أيام',
      two: 'قبل يومين',
      one: 'قبل يوم',
      zero: 'يوم الانتهاء فقط',
    );
    return '$_temp0';
  }

  @override
  String travelRemindSummary(String when) {
    return 'التذكير: $when';
  }

  @override
  String get travelExpiresToday => 'الانتهاء اليوم';

  @override
  String travelExpiresInDays(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'الانتهاء بعد $n يوم',
      many: 'الانتهاء بعد $n يومًا',
      few: 'الانتهاء بعد $n أيام',
      two: 'الانتهاء بعد يومين',
      one: 'الانتهاء غدًا',
    );
    return '$_temp0';
  }

  @override
  String travelExpiresInMonths(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'الانتهاء بعد $n شهر',
      many: 'الانتهاء بعد $n شهرًا',
      few: 'الانتهاء بعد $n أشهر',
      two: 'الانتهاء بعد شهرين',
      one: 'الانتهاء بعد شهر',
    );
    return '$_temp0';
  }

  @override
  String travelExpiresInYears(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'الانتهاء بعد $n سنة',
      many: 'الانتهاء بعد $n سنة',
      few: 'الانتهاء بعد $n سنوات',
      two: 'الانتهاء بعد سنتين',
      one: 'الانتهاء بعد سنة',
    );
    return '$_temp0';
  }

  @override
  String travelExpiredAgo(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'انتهت الصلاحية منذ $n يوم',
      many: 'انتهت الصلاحية منذ $n يومًا',
      few: 'انتهت الصلاحية منذ $n أيام',
      two: 'انتهت الصلاحية منذ يومين',
      one: 'انتهت الصلاحية أمس',
    );
    return '$_temp0';
  }

  @override
  String travelExpiredOn(String date) {
    return 'انتهت الصلاحية في $date';
  }

  @override
  String get travelNoExpiry => 'بلا تاريخ انتهاء';

  @override
  String get travelDocKindPassport => 'جواز سفر';

  @override
  String get travelDocKindVisa => 'تأشيرة';

  @override
  String get travelDocKindLicence => 'رخصة';

  @override
  String get travelDocKindId => 'هوية';

  @override
  String get travelDocKindInsurance => 'تأمين';

  @override
  String get travelDocKindOther => 'وثيقة';

  @override
  String travelDocAffects(String destination) {
    return 'يمسّ رحلة $destination';
  }

  @override
  String get travelNoticeGroup => 'السفر';

  @override
  String get travelNoticeChannel => 'انتهاء الوثائق';

  @override
  String get travelNoticeChannelDescription =>
      'تذكير قبل انتهاء الجوازات والتأشيرات والرخص';

  @override
  String travelNoticeTitle(String doc, String when) {
    return '$doc: $when';
  }

  @override
  String travelNoticeAheadBody(String date) {
    return 'تاريخ الانتهاء $date. ابدأ التجديد مبكرًا حتى لا تتعطّل رحلاتك.';
  }

  @override
  String get travelNoticeOnDayBody =>
      'تنتهي صلاحيتها اليوم. جدّدها قبل سفرك القادم.';

  @override
  String travelDocWithHolder(String doc, String holder) {
    return '$doc ($holder)';
  }

  @override
  String get travelTemplatesTitle => 'قوائم التجهيز الجاهزة';

  @override
  String get travelTemplatesEmptyTitle => 'لا قوائم جاهزة بعد';

  @override
  String get travelTemplatesEmptyBody =>
      'القائمة الجاهزة تملأ حقيبة أي رحلة بلمسة، وتحفظ ما تنساه عادةً.';

  @override
  String get travelTemplatesStarter => 'أضف قوائم مقترحة';

  @override
  String get travelTemplatesStarterAdded =>
      'أُضيفت القوائم المقترحة، عدّلها كما تشاء';

  @override
  String travelTemplateItems(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n غرض',
      many: '$n غرضًا',
      few: '$n أغراض',
      two: 'غرضان',
      one: 'غرض واحد',
      zero: 'لا أغراض',
    );
    return '$_temp0';
  }

  @override
  String get travelTemplateNew => 'قائمة جديدة';

  @override
  String get travelTemplateRename => 'إعادة التسمية';

  @override
  String get travelTemplateName => 'الاسم';

  @override
  String get travelTemplateNameHint => 'مثلًا: رحلة عمل';

  @override
  String get travelTemplateNameRequired => 'اكتب اسمًا';

  @override
  String get travelTemplateEmptyItems =>
      'أضف أغراض هذه القائمة، ورتّبها بالسحب.';

  @override
  String travelTemplateCopy(String name) {
    return '$name (نسخة)';
  }

  @override
  String get travelStarterEssentials => 'الأساسيات';

  @override
  String get travelStarterBusiness => 'رحلة عمل';

  @override
  String get travelStarterUmrah => 'العمرة';

  @override
  String get travelStarterWinter => 'سفر الشتاء';

  @override
  String get travelSeedPassport => 'جواز السفر';

  @override
  String get travelSeedTickets => 'التذاكر والحجوزات';

  @override
  String get travelSeedWallet => 'المحفظة والبطاقات';

  @override
  String get travelSeedCash => 'نقود بعملة البلد';

  @override
  String get travelSeedClothes => 'ملابس لأيام الرحلة';

  @override
  String get travelSeedSleepwear => 'ملابس النوم';

  @override
  String get travelSeedToothbrush => 'فرشاة ومعجون الأسنان';

  @override
  String get travelSeedMiswak => 'سواك';

  @override
  String get travelSeedDeodorant => 'مزيل العرق';

  @override
  String get travelSeedMeds => 'أدويتي المعتادة';

  @override
  String get travelSeedFirstAid => 'إسعافات أولية';

  @override
  String get travelSeedCharger => 'شاحن الهاتف';

  @override
  String get travelSeedPowerBank => 'بطارية متنقلة';

  @override
  String get travelSeedAdapter => 'محوّل كهرباء';

  @override
  String get travelSeedPrayerMat => 'سجادة صلاة للسفر';

  @override
  String get travelSeedQuran => 'مصحف الجيب';

  @override
  String get travelSeedLaptop => 'الحاسوب وشاحنه';

  @override
  String get travelSeedFormal => 'ملابس رسمية';

  @override
  String get travelSeedCards => 'بطاقات العمل';

  @override
  String get travelSeedNotebook => 'دفتر وقلم';

  @override
  String get travelSeedIhram => 'ملابس الإحرام';

  @override
  String get travelSeedIhramBelt => 'حزام الإحرام';

  @override
  String get travelSeedUnscented => 'صابون بلا عطر';

  @override
  String get travelSeedSandals => 'نعال مريحة';

  @override
  String get travelSeedShoeBag => 'كيس للأحذية';

  @override
  String get travelSeedUmbrella => 'مظلة للشمس';

  @override
  String get travelSeedDuas => 'كتيّب الأدعية';

  @override
  String get travelSeedWater => 'قارورة ماء';

  @override
  String get travelSeedPermit => 'تصريح العمرة';

  @override
  String get travelSeedCoat => 'معطف ثقيل';

  @override
  String get travelSeedScarf => 'وشاح وقفازات';

  @override
  String get travelSeedThermal => 'ملابس حرارية';

  @override
  String get travelSeedLipBalm => 'مرطّب شفاه';

  @override
  String get travelCardNoTrips => 'لا رحلات قادمة';

  @override
  String travelCardPacked(String packed, String total) {
    return '$packed/$total في الحقيبة';
  }

  @override
  String get travelCardNoPacking => 'لم تبدأ قائمة التجهيز';

  @override
  String travelCardNext(String destination, String countdown) {
    return 'الرحلة التالية: $destination · $countdown';
  }

  @override
  String travelCardDocsAttention(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n وثيقة تحتاج انتباهك',
      many: '$n وثيقة تحتاج انتباهك',
      few: '$n وثائق تحتاج انتباهك',
      two: 'وثيقتان تحتاجان انتباهك',
      one: 'وثيقة تحتاج انتباهك',
    );
    return '$_temp0';
  }

  @override
  String get travelUndoTripDeleted => 'حُذفت الرحلة';

  @override
  String get travelUndoTripDuplicated => 'نُسخت الرحلة';

  @override
  String get travelUndoItemDeleted => 'حُذف الغرض';

  @override
  String get travelUndoPacked => 'في الحقيبة';

  @override
  String get travelUndoUnpacked => 'أُخرج من الحقيبة';

  @override
  String travelUndoMoved(String category) {
    return 'نُقل إلى $category';
  }

  @override
  String get travelUndoDocDeleted => 'حُذفت الوثيقة';

  @override
  String get travelUndoDocDuplicated => 'نُسخت الوثيقة';

  @override
  String get travelUndoTemplateDeleted => 'حُذفت القائمة';

  @override
  String get travelUndoTemplateDuplicated => 'نُسخت القائمة';

  @override
  String travelUndoStatus(String status) {
    return 'الرحلة الآن: $status';
  }

  @override
  String get travelUndoUnpackedAll => 'أُفرغت الحقيبة';

  @override
  String get travelUndoSaved => 'حُفظت التعديلات';

  @override
  String travelUndoReminder(String when) {
    return 'التذكير: $when';
  }

  @override
  String travelOpenTrip(String destination) {
    return 'افتح رحلة $destination';
  }

  @override
  String get travelMore => 'المزيد';

  @override
  String get travelEdit => 'تعديل';

  @override
  String get travelTripNotFound => 'لم تعد هذه الرحلة موجودة';

  @override
  String get travelTemplateNotFound => 'لم تعد قائمة التجهيز هذه موجودة';

  @override
  String get growthTitle => 'أهداف التعلّم';

  @override
  String get growthNewGoal => 'هدف جديد';

  @override
  String get growthEditGoal => 'تعديل الهدف';

  @override
  String get growthEmptyTitle => 'ابدأ رحلة تعلّم';

  @override
  String get growthEmptyBody =>
      'ضع هدفًا تقيسه وسجّل تقدّمك أولًا بأول: كقراءة كتاب من ثلاثمئة صفحة، أو إنهاء دورة من اثني عشر درسًا.';

  @override
  String get growthEmptyAction => 'أضف أول هدف';

  @override
  String get growthSectionActive => 'قيد التعلّم';

  @override
  String get growthSectionCompleted => 'أهداف مكتملة';

  @override
  String get growthSectionPaused => 'متوقفة مؤقتًا';

  @override
  String get growthSectionHint => 'اسحب المقبض لترتيب أهدافك';

  @override
  String get growthOverviewTitle => 'مسيرة التعلّم';

  @override
  String growthActiveGoals(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count هدف نشط',
      many: '$count هدفًا نشطًا',
      few: '$count أهداف نشطة',
      two: 'هدفان نشطان',
      one: 'هدف نشط واحد',
      zero: 'لا أهداف نشطة',
    );
    return '$_temp0';
  }

  @override
  String growthCompletedGoals(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count هدف مكتمل',
      many: '$count هدفًا مكتملًا',
      few: '$count أهداف مكتملة',
      two: 'هدفان مكتملان',
      one: 'هدف مكتمل',
      zero: 'لا أهداف مكتملة',
    );
    return '$_temp0';
  }

  @override
  String growthLoggedToday(String done, String total) {
    return 'سجّلتَ اليوم في $done من $total';
  }

  @override
  String get growthNothingToday => 'لم تسجّل شيئًا اليوم بعد';

  @override
  String get growthAverageLabel => 'المتوسط';

  @override
  String get growthLastSevenDays => 'الأيام السبعة الأخيرة';

  @override
  String growthDayActive(String day) {
    return '$day: سُجّل تقدّم';
  }

  @override
  String growthDayIdle(String day) {
    return '$day: لا تقدّم';
  }

  @override
  String get growthStreakLabel => 'السلسلة';

  @override
  String growthStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يوم متتالٍ',
      many: '$count يومًا متتاليًا',
      few: '$count أيام متتالية',
      two: 'يومان متتاليان',
      one: 'يوم واحد متتالٍ',
      zero: 'لا سلسلة بعد',
    );
    return '$_temp0';
  }

  @override
  String growthBestStreak(String days) {
    return 'الأطول: $days';
  }

  @override
  String get growthStreakAtRisk => 'سجّل اليوم لتحافظ على سلسلتك';

  @override
  String get growthActiveDaysLabel => 'أيام النشاط';

  @override
  String growthDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يوم',
      many: '$count يومًا',
      few: '$count أيام',
      two: 'يومان',
      one: 'يوم واحد',
      zero: '$count يوم',
    );
    return '$_temp0';
  }

  @override
  String get growthUnitPagesName => 'صفحات';

  @override
  String growthUnitPages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صفحة',
      many: '$count صفحة',
      few: '$count صفحات',
      two: 'صفحتان',
      one: 'صفحة واحدة',
      zero: '$count صفحة',
    );
    return '$_temp0';
  }

  @override
  String growthUnitPagesDecimal(String amount) {
    return '$amount صفحة';
  }

  @override
  String get growthUnitLessonsName => 'دروس';

  @override
  String growthUnitLessons(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count درس',
      many: '$count درسًا',
      few: '$count دروس',
      two: 'درسان',
      one: 'درس واحد',
      zero: '$count درس',
    );
    return '$_temp0';
  }

  @override
  String growthUnitLessonsDecimal(String amount) {
    return '$amount درس';
  }

  @override
  String get growthUnitHoursName => 'ساعات';

  @override
  String growthUnitHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ساعة',
      many: '$count ساعة',
      few: '$count ساعات',
      two: 'ساعتان',
      one: 'ساعة واحدة',
      zero: '$count ساعة',
    );
    return '$_temp0';
  }

  @override
  String growthUnitHoursDecimal(String amount) {
    return '$amount ساعة';
  }

  @override
  String get growthUnitChaptersName => 'فصول';

  @override
  String growthUnitChapters(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فصل',
      many: '$count فصلًا',
      few: '$count فصول',
      two: 'فصلان',
      one: 'فصل واحد',
      zero: '$count فصل',
    );
    return '$_temp0';
  }

  @override
  String growthUnitChaptersDecimal(String amount) {
    return '$amount فصل';
  }

  @override
  String get growthUnitCoursesName => 'دورات';

  @override
  String growthUnitCourses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دورة',
      many: '$count دورة',
      few: '$count دورات',
      two: 'دورتان',
      one: 'دورة واحدة',
      zero: '$count دورة',
    );
    return '$_temp0';
  }

  @override
  String growthUnitCoursesDecimal(String amount) {
    return '$amount دورة';
  }

  @override
  String get growthUnitWordsName => 'كلمات';

  @override
  String growthUnitWords(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count كلمة',
      many: '$count كلمة',
      few: '$count كلمات',
      two: 'كلمتان',
      one: 'كلمة واحدة',
      zero: '$count كلمة',
    );
    return '$_temp0';
  }

  @override
  String growthUnitWordsDecimal(String amount) {
    return '$amount كلمة';
  }

  @override
  String get growthUnitBooksName => 'كتب';

  @override
  String growthUnitBooks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count كتاب',
      many: '$count كتابًا',
      few: '$count كتب',
      two: 'كتابان',
      one: 'كتاب واحد',
      zero: '$count كتاب',
    );
    return '$_temp0';
  }

  @override
  String growthUnitBooksDecimal(String amount) {
    return '$amount كتاب';
  }

  @override
  String get growthUnitLecturesName => 'محاضرات';

  @override
  String growthUnitLectures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count محاضرة',
      many: '$count محاضرة',
      few: '$count محاضرات',
      two: 'محاضرتان',
      one: 'محاضرة واحدة',
      zero: '$count محاضرة',
    );
    return '$_temp0';
  }

  @override
  String growthUnitLecturesDecimal(String amount) {
    return '$amount محاضرة';
  }

  @override
  String get growthUnitMinutesName => 'دقائق';

  @override
  String growthUnitMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دقيقة',
      many: '$count دقيقة',
      few: '$count دقائق',
      two: 'دقيقتان',
      one: 'دقيقة واحدة',
      zero: '$count دقيقة',
    );
    return '$_temp0';
  }

  @override
  String growthUnitMinutesDecimal(String amount) {
    return '$amount دقيقة';
  }

  @override
  String get growthUnitArticlesName => 'مقالات';

  @override
  String growthUnitArticles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مقال',
      many: '$count مقالًا',
      few: '$count مقالات',
      two: 'مقالان',
      one: 'مقال واحد',
      zero: '$count مقال',
    );
    return '$_temp0';
  }

  @override
  String growthUnitArticlesDecimal(String amount) {
    return '$amount مقال';
  }

  @override
  String growthAmountCustom(String amount, String unit) {
    return '$amount $unit';
  }

  @override
  String growthProgressOf(String current, String target) {
    return '$current من $target';
  }

  @override
  String growthRemaining(String amount) {
    return 'تبقّى $amount';
  }

  @override
  String growthExceeded(String amount) {
    return 'تجاوزتَ الهدف بـ$amount';
  }

  @override
  String growthStartedFrom(String amount) {
    return 'بدأتَ من $amount';
  }

  @override
  String growthRatePerDay(String amount) {
    return '$amount يوميًا';
  }

  @override
  String growthRatePerWeek(String amount) {
    return '$amount أسبوعيًا';
  }

  @override
  String get growthPaceCompleted => 'مكتمل';

  @override
  String get growthPacePaused => 'متوقف مؤقتًا';

  @override
  String get growthPaceNotStarted => 'لم يبدأ بعد';

  @override
  String get growthPaceNoDeadline => 'بلا موعد';

  @override
  String get growthPaceAhead => 'متقدّم';

  @override
  String get growthPaceOnTrack => 'على المسار';

  @override
  String get growthPaceBehind => 'متأخّر';

  @override
  String get growthPaceOverdue => 'فات الموعد';

  @override
  String growthLineNeed(String rate, String date) {
    return 'تحتاج $rate حتى $date';
  }

  @override
  String growthLineAhead(String rate) {
    return 'متقدّم بوتيرة $rate';
  }

  @override
  String growthLineStart(String rate, String date) {
    return '$rate تكفيك حتى $date';
  }

  @override
  String get growthLineFirstLog => 'سجّل أول تقدّم لتبدأ';

  @override
  String growthLineOpen(String rate) {
    return 'وتيرتك $rate';
  }

  @override
  String growthLineOpenFinish(String rate, String date) {
    return 'وتيرتك $rate، تُنهيه في $date';
  }

  @override
  String get growthLineQuiet => 'لا تقدّم في الأسبوعين الأخيرين';

  @override
  String growthLineOverdue(String days, String amount) {
    return 'متأخّر $days، تبقّى $amount';
  }

  @override
  String growthLineDueToday(String amount) {
    return 'الموعد اليوم، تبقّى $amount';
  }

  @override
  String growthLineCompleted(String date) {
    return 'اكتمل في $date';
  }

  @override
  String get growthLinePaused => 'متوقف مؤقتًا، استأنفه متى شئت';

  @override
  String get growthNeededLabel => 'المطلوب';

  @override
  String get growthActualLabel => 'وتيرتك';

  @override
  String growthActualWindow(String days) {
    return 'آخر $days';
  }

  @override
  String growthNeededUntil(String date) {
    return 'حتى $date';
  }

  @override
  String get growthNoPaceYet => 'لا وتيرة بعد';

  @override
  String get growthProjectedLabel => 'الإنهاء المتوقع';

  @override
  String growthProjectionEarly(String days) {
    return 'قبل الموعد بـ$days';
  }

  @override
  String growthProjectionLate(String days) {
    return 'بعد الموعد بـ$days';
  }

  @override
  String get growthProjectionOnDay => 'في الموعد تمامًا';

  @override
  String get growthProjectionNone => 'سجّل تقدّمًا لنتوقّع موعد إنهائك';

  @override
  String get growthPaceNoDeadlineHint =>
      'بلا موعد نهائي، تقدّم بالوتيرة التي تناسبك';

  @override
  String get growthPaceDoneHint => 'بلغتَ هدفك، ويمكنك مواصلة التسجيل';

  @override
  String growthPlanBehind(String amount) {
    return 'خلف الخطة بـ$amount';
  }

  @override
  String growthPlanAhead(String amount) {
    return 'أمام الخطة بـ$amount';
  }

  @override
  String growthDaysLeft(String days) {
    return 'بقي $days';
  }

  @override
  String get growthDeadlineLabel => 'الموعد';

  @override
  String get growthChartTitle => 'المسار';

  @override
  String get growthChartActual => 'التقدّم';

  @override
  String get growthChartPlan => 'الخطة';

  @override
  String get growthChartTarget => 'الهدف';

  @override
  String get growthChartProjection => 'التوقّع';

  @override
  String growthChartSemantics(String current, String target) {
    return 'مخطط التقدّم: $current من $target';
  }

  @override
  String get growthHistoryTitle => 'سجلّ التقدّم';

  @override
  String get growthHistoryEmpty => 'لا سجلات بعد. خطوة صغيرة اليوم تصنع الفرق.';

  @override
  String get growthToday => 'اليوم';

  @override
  String get growthYesterday => 'أمس';

  @override
  String growthRunningTotal(String amount) {
    return 'المجموع $amount';
  }

  @override
  String growthDayTotal(String amount) {
    return '$amount في هذا اليوم';
  }

  @override
  String get growthLogProgress => 'سجّل تقدّمًا';

  @override
  String get growthEditLog => 'تعديل السجل';

  @override
  String get growthLogOther => 'مقدار آخر';

  @override
  String growthLogQuick(String amount) {
    return 'سجّل $amount';
  }

  @override
  String get growthLogAmount => 'المقدار';

  @override
  String get growthLogWhen => 'الوقت';

  @override
  String get growthLogDate => 'اليوم';

  @override
  String get growthLogTime => 'الساعة';

  @override
  String get growthLogNow => 'الآن';

  @override
  String get growthLogNote => 'ملاحظة';

  @override
  String get growthLogNoteHint => 'ماذا تعلّمت؟';

  @override
  String growthLogNewTotal(String total, String percent) {
    return 'المجموع بعدها $total ($percent)';
  }

  @override
  String get growthLogWillComplete => 'بهذا تُتمّ هدفك!';

  @override
  String get growthLogSave => 'سجّل';

  @override
  String get growthDecrease => 'أنقِص';

  @override
  String get growthIncrease => 'زِد';

  @override
  String get growthErrorAmount => 'أدخل مقدارًا أكبر من صفر';

  @override
  String get growthFieldName => 'اسم الهدف';

  @override
  String get growthFieldNameHint => 'مثال: قراءة كتاب في الإدارة';

  @override
  String get growthFieldUnit => 'الوحدة';

  @override
  String get growthFieldUnitHint => 'اختر أو اكتب وحدتك';

  @override
  String get growthFieldTarget => 'المستهدف';

  @override
  String get growthFieldInitial => 'نقطة البداية';

  @override
  String get growthFieldInitialHint => 'ما أنجزته من قبل';

  @override
  String get growthFieldDeadline => 'الموعد النهائي';

  @override
  String get growthFieldNoDeadline => 'بلا موعد';

  @override
  String get growthFieldColor => 'اللون';

  @override
  String get growthFieldActive => 'هدف نشط';

  @override
  String get growthFieldActiveHint => 'أوقفه مؤقتًا دون أن تخسر تقدّمك';

  @override
  String get growthInMonth => 'بعد شهر';

  @override
  String get growthInThreeMonths => 'بعد ثلاثة أشهر';

  @override
  String get growthEndOfYear => 'نهاية السنة';

  @override
  String get growthErrorName => 'اكتب اسمًا للهدف';

  @override
  String get growthErrorTarget => 'أدخل مقدارًا أكبر من صفر';

  @override
  String get growthErrorInitial => 'يجب أن تكون البداية أقل من المستهدف';

  @override
  String growthPreviewNeed(String rate, String date) {
    return '$rate تكفيك لتبلغ هدفك في $date';
  }

  @override
  String get growthPreviewOpen => 'بلا موعد: سجّل تقدّمك بالوتيرة التي تناسبك';

  @override
  String get growthPreviewPast => 'هذا الموعد مضى؛ اختر موعدًا قادمًا';

  @override
  String get growthCreate => 'أنشئ الهدف';

  @override
  String get growthSave => 'احفظ';

  @override
  String get growthCancel => 'إلغاء';

  @override
  String get growthPause => 'إيقاف مؤقت';

  @override
  String get growthResume => 'استئناف';

  @override
  String get growthDelete => 'حذف';

  @override
  String get growthEdit => 'تعديل';

  @override
  String growthCopyName(String name) {
    return '$name (نسخة)';
  }

  @override
  String growthLogged(String amount, String goal) {
    return 'سُجّل $amount، $goal';
  }

  @override
  String get growthLogUpdated => 'عُدّل السجل';

  @override
  String get growthLogDeleted => 'حُذف السجل';

  @override
  String growthGoalCreated(String name) {
    return 'أُضيف الهدف: $name';
  }

  @override
  String get growthGoalSaved => 'حُفظت التعديلات';

  @override
  String growthGoalDeleted(String name) {
    return 'حُذف الهدف: $name';
  }

  @override
  String get growthGoalDuplicated => 'نُسخ الهدف';

  @override
  String get growthGoalPaused => 'أُوقف الهدف مؤقتًا';

  @override
  String get growthGoalResumed => 'استُؤنف الهدف';

  @override
  String get growthGoalMissing => 'لم يعد هذا الهدف موجودًا';

  @override
  String get growthCelebrateTitle => 'ما شاء الله، أتممتَ هدفك!';

  @override
  String growthCelebrateBody(String amount, String days) {
    return '$amount خلال $days';
  }

  @override
  String get growthCelebrateThanks => 'الحمد لله';

  @override
  String get growthCelebrateNext => 'هدف جديد';

  @override
  String get growthCardTitle => 'النمو اليوم';

  @override
  String get growthCardOpenAll => 'كل الأهداف';

  @override
  String get growthCardEmpty =>
      'لا أهداف تعلّم بعد. أضف هدفًا وتابِع تقدّمك هنا.';

  @override
  String get growthCardAllDone => 'أتممتَ كل أهدافك النشطة، بارك الله فيك';

  @override
  String get growthOpenGoal => 'افتح الهدف';

  @override
  String growthGoalSemantics(String name, String progress, String status) {
    return '$name، $progress، $status';
  }

  @override
  String get growthSep => '، ';

  @override
  String get growthPaceTitle => 'الوتيرة';

  @override
  String get growthStatsDeadlineNone => 'بلا موعد';

  @override
  String growthStartedOn(String date) {
    return 'بدأ في $date';
  }

  @override
  String get growthAllActiveDone =>
      'لا أهداف قيد التعلّم الآن. ما خطوتك التالية؟';

  @override
  String growthOverdueBy(String days) {
    return 'فات الموعد منذ $days';
  }

  @override
  String growthOfDays(String days) {
    return 'من $days';
  }

  @override
  String get bodyTitle => 'الجسد';

  @override
  String get bodyTabToday => 'اليوم';

  @override
  String get bodyTabPlan => 'الخطة';

  @override
  String get bodyTabFasting => 'الصيام';

  @override
  String get bodyTabWater => 'الماء';

  @override
  String get bodyTabAvoid => 'تجنّب';

  @override
  String get bodySave => 'حفظ';

  @override
  String get bodyCancel => 'إلغاء';

  @override
  String get bodyDelete => 'حذف';

  @override
  String get bodyNameRequired => 'اكتب اسمًا';

  @override
  String bodyKg(String value) {
    return '$value كغ';
  }

  @override
  String bodyMinutes(String value) {
    return '$value د';
  }

  @override
  String bodyHours(String value) {
    return '$value س';
  }

  @override
  String bodyRepsValue(String value) {
    return '$value تكرار';
  }

  @override
  String bodySetsReps(String sets, String reps) {
    return '$sets × $reps';
  }

  @override
  String bodyMl(String value) {
    return '$value مل';
  }

  @override
  String bodyLiters(String value) {
    return '$value لتر';
  }

  @override
  String bodyFraction(String done, String total) {
    return '$done من $total';
  }

  @override
  String bodyDaysInRow(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n يوم متتالٍ',
      many: '$n يومًا متتاليًا',
      few: '$n أيام متتالية',
      two: 'يومان متتاليان',
      one: 'يوم واحد متتالٍ',
      zero: 'لا سلسلة بعد',
    );
    return '$_temp0';
  }

  @override
  String bodyExercisesCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n تمرين',
      many: '$n تمرينًا',
      few: '$n تمارين',
      two: 'تمرينان',
      one: 'تمرين واحد',
      zero: 'لا تمارين',
    );
    return '$_temp0';
  }

  @override
  String bodyPerWeek(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n مرة في الأسبوع',
      many: '$n مرة في الأسبوع',
      few: '$n مرات في الأسبوع',
      two: 'مرتان في الأسبوع',
      one: 'مرة في الأسبوع',
      zero: 'بلا أيام محددة',
    );
    return '$_temp0';
  }

  @override
  String get bodyTodaySession => 'تمرين اليوم';

  @override
  String get bodyRestDay => 'يوم راحة';

  @override
  String get bodyRestDayBody => 'لا شيء في خطة اليوم. خذ قسطك من الراحة.';

  @override
  String bodyNextSession(String day) {
    return 'التمرين القادم: $day';
  }

  @override
  String get bodySessionDone => 'أنهيت تمرين اليوم — أحسنت!';

  @override
  String get bodySessionKeepGoing => 'خطوة بخطوة، اسحب التمرين لتسجيله.';

  @override
  String get bodyNoPlanTitle => 'لا خطة تمارين بعد';

  @override
  String get bodyNoPlanBody =>
      'أضف تمارينك وأيامها من تبويب «الخطة»، وستظهر هنا في يومها.';

  @override
  String get bodyOpenPlan => 'إلى الخطة';

  @override
  String get bodyAlsoToday => 'أيضًا اليوم';

  @override
  String get bodyLogExtra => 'سجّل تمرينًا';

  @override
  String get bodyMarkDone => 'أنجزته';

  @override
  String get bodyUnmark => 'إلغاء الإنجاز';

  @override
  String bodyLogged(String summary) {
    return 'أنجزت: $summary';
  }

  @override
  String bodyLoggedToast(String name) {
    return 'سُجّل «$name»';
  }

  @override
  String bodyUnloggedToast(String name) {
    return 'أُلغي تسجيل «$name»';
  }

  @override
  String get bodyLogDetails => 'سجّل بالتفاصيل';

  @override
  String get bodyAvoidReminder => 'تذكّر أن تتجنّب';

  @override
  String get bodyStateDone => 'أُنجز';

  @override
  String get bodyStateOpen => 'لم يُنجز بعد';

  @override
  String get bodyPlanWeek => 'هذا الأسبوع';

  @override
  String get bodyPlanHint =>
      'اسحب المقبض لإعادة الترتيب، واضغط مطوّلًا لبقية الخيارات.';

  @override
  String get bodyPlanEmptyTitle => 'خطتك فارغة';

  @override
  String get bodyPlanEmptyBody =>
      'أضف تمارينك وأيامها — مثلًا: تمرين ضغط، السبت والإثنين والأربعاء، ٣ × ١٢.';

  @override
  String get bodyAddExercise => 'تمرين جديد';

  @override
  String get bodyEditExercise => 'تعديل التمرين';

  @override
  String get bodyExerciseSubtitle => 'حدّد أيامه وما تريد إنجازه في كل مرة.';

  @override
  String get bodyExerciseName => 'اسم التمرين';

  @override
  String get bodyExerciseNameHint => 'مثلًا: مشي سريع';

  @override
  String get bodyWeekdays => 'أيام التمرين';

  @override
  String get bodyEveryDay => 'كل يوم';

  @override
  String get bodyClearDays => 'مسح';

  @override
  String bodyListAnd(String head, String last) {
    return '$head و$last';
  }

  @override
  String get bodyListSep => '، ';

  @override
  String get bodyPartsSep => '، ';

  @override
  String get bodyNoDays => 'بلا أيام محددة — لن يظهر في «اليوم».';

  @override
  String get bodyTarget => 'في كل مرة';

  @override
  String get bodySets => 'المجموعات';

  @override
  String get bodyReps => 'التكرارات';

  @override
  String get bodyWeight => 'الوزن';

  @override
  String get bodyDuration => 'المدة';

  @override
  String get bodyNotes => 'ملاحظات';

  @override
  String get bodyNotesHint => 'مثلًا: ركّز على الوضعية';

  @override
  String get bodyUnitKg => 'كغ';

  @override
  String get bodyUnitMin => 'دقيقة';

  @override
  String get bodyUnitMl => 'مل';

  @override
  String get bodyUnitHours => 'ساعة';

  @override
  String bodyStepperDecrease(String label) {
    return 'إنقاص $label';
  }

  @override
  String bodyStepperIncrease(String label) {
    return 'زيادة $label';
  }

  @override
  String get bodyNotSet => '—';

  @override
  String get bodyExerciseHistory => 'السجل والتقدّم';

  @override
  String get bodyPause => 'إيقاف مؤقت';

  @override
  String get bodyResume => 'استئناف';

  @override
  String get bodyPaused => 'متوقف مؤقتًا';

  @override
  String bodyCopyName(String name) {
    return '$name (نسخة)';
  }

  @override
  String bodyDeletedName(String name) {
    return 'حُذف «$name»';
  }

  @override
  String bodyDuplicatedName(String name) {
    return 'نُسخ «$name»';
  }

  @override
  String bodyPausedName(String name) {
    return 'أُوقف «$name» مؤقتًا';
  }

  @override
  String bodyResumedName(String name) {
    return 'عاد «$name» إلى الخطة';
  }

  @override
  String get bodyLogTitle => 'تسجيل التمرين';

  @override
  String get bodyLogEditTitle => 'تعديل السجل';

  @override
  String get bodyLogSubtitle => 'القيم من خطتك — عدّلها لما أنجزته فعلًا.';

  @override
  String get bodyLogExtraSubtitle => 'تمرين خارج الخطة؟ سجّله هنا.';

  @override
  String get bodyYesterday => 'أمس';

  @override
  String get bodyLogWhen => 'متى';

  @override
  String get bodyLogSave => 'سجّل';

  @override
  String get bodyWorkoutName => 'التمرين';

  @override
  String get bodyWorkoutNameHint => 'مثلًا: سباحة';

  @override
  String bodyLogVolume(String value) {
    return 'الحجم: $value';
  }

  @override
  String get bodyHistoryEmpty =>
      'لا سجلات بعد. عندما تنجز هذا التمرين يظهر تقدّمك هنا.';

  @override
  String get bodyHistoryOneDay => 'يظهر المنحنى بعد يومين من السجلات.';

  @override
  String get bodyMetricWeight => 'الوزن';

  @override
  String get bodyMetricVolume => 'الحجم';

  @override
  String get bodyMetricReps => 'التكرارات';

  @override
  String get bodyMetricMinutes => 'الدقائق';

  @override
  String get bodyBest => 'الأفضل';

  @override
  String get bodyChange => 'التغيّر';

  @override
  String get bodySessions => 'الجلسات';

  @override
  String get bodyVolumeHint => 'الحجم = المجموعات × التكرارات × الوزن';

  @override
  String get bodyLogs => 'السجلات';

  @override
  String get bodyLogDeleted => 'حُذف السجل';

  @override
  String get bodyLogUpdated => 'حُدّث السجل';

  @override
  String get bodyFastingTitle => 'الصيام المتقطّع';

  @override
  String get bodyFastPhaseFasting => 'صائم';

  @override
  String get bodyFastPhaseEating => 'نافذة الأكل';

  @override
  String get bodyFastPhaseWaiting => 'خارج الصيام';

  @override
  String bodyFastRemaining(String time) {
    return 'بقي $time';
  }

  @override
  String bodyFastGoalAt(String time) {
    return 'الهدف $time';
  }

  @override
  String get bodyFastReached => 'بلغت هدفك!';

  @override
  String bodyFastOvertime(String time) {
    return '$time فوق الهدف';
  }

  @override
  String get bodyFastTimeNow => 'حان وقت صيامك';

  @override
  String bodyEatingOpenSince(String time) {
    return 'مفتوحة منذ $time';
  }

  @override
  String bodyEatingClosesAt(String time) {
    return 'آخر وجبة $time';
  }

  @override
  String bodyNextFastAt(String time) {
    return 'الصيام القادم $time';
  }

  @override
  String bodyWindowOpensAt(String time) {
    return 'تُفتح نافذة الأكل $time';
  }

  @override
  String get bodyStartFast => 'ابدأ الصيام';

  @override
  String get bodyEndFast => 'أنهِ الصيام';

  @override
  String get bodyStartedEarlier => 'بدأت قبل الآن؟';

  @override
  String get bodyFastStartTitle => 'متى بدأ صيامك؟';

  @override
  String get bodyFastStarted => 'بدأ صيامك — بالتوفيق';

  @override
  String bodyFastEnded(String duration) {
    return 'انتهى صيامك: $duration';
  }

  @override
  String get bodyFastPlan => 'خطة الصيام';

  @override
  String get bodyFastHours => 'ساعات الصيام';

  @override
  String get bodyFastCustom => 'مخصّص';

  @override
  String get bodyFastCustomTitle => 'ساعات صيام مخصّصة';

  @override
  String get bodyFastCustomHint => 'من ساعة إلى ٧٢ ساعة';

  @override
  String bodyFastRatioHint(String fast, String eat) {
    return 'صيام $fast س، ثم نافذة أكل $eat س';
  }

  @override
  String bodyFastLongHint(String fast) {
    return 'صيام $fast ساعة، بلا نافذة أكل يومية';
  }

  @override
  String get bodyLastMeal => 'آخر وجبة';

  @override
  String get bodyLastMealHint => 'يبدأ صيامك المخطط عندها.';

  @override
  String get bodyNotifyGoal => 'نبّهني عند بلوغ الهدف';

  @override
  String get bodyNotifyEating => 'ذكّرني قبل إغلاق نافذة الأكل';

  @override
  String bodyLeadBefore(String n) {
    return 'قبلها بـ$n د';
  }

  @override
  String get bodyLeadAtTime => 'في وقتها';

  @override
  String get bodyStatStreak => 'السلسلة';

  @override
  String get bodyStatLongest => 'الأطول';

  @override
  String get bodyStatAverage => 'المتوسط';

  @override
  String get bodyStatCompleted => 'بلغت الهدف';

  @override
  String get bodyFastHistory => 'سجل الصيام';

  @override
  String get bodyFastHistoryEmpty =>
      'لا صيام مسجّل بعد. اضغط «ابدأ الصيام» بعد آخر وجبة.';

  @override
  String bodyFastGoalBadge(String hours) {
    return 'الهدف $hours س';
  }

  @override
  String get bodyFastEditTitle => 'تعديل الصيام';

  @override
  String get bodyFastStartDate => 'يوم البدء';

  @override
  String get bodyFastStartTime => 'وقت البدء';

  @override
  String get bodyFastEndDate => 'يوم الانتهاء';

  @override
  String get bodyFastEndTime => 'وقت الانتهاء';

  @override
  String get bodyFastGoalHours => 'الهدف';

  @override
  String get bodyFastNote => 'ملاحظة';

  @override
  String get bodyFastNoteHint => 'مثلًا: صيام رمضان، صيام تطوّع';

  @override
  String get bodyFastEndBeforeStart => 'الانتهاء قبل البدء';

  @override
  String get bodyFastInFuture => 'هذا الوقت لم يأتِ بعد';

  @override
  String get bodyFastDeleted => 'حُذف الصيام';

  @override
  String get bodyFastUpdated => 'حُدّث الصيام';

  @override
  String bodyFastRingSemantics(String phase, String detail) {
    return '$phase: $detail';
  }

  @override
  String get bodyWaterTitle => 'الماء';

  @override
  String bodyWaterOf(String target) {
    return 'من $target';
  }

  @override
  String bodyAddAmount(String amount) {
    return '+$amount';
  }

  @override
  String bodyAddWaterSemantics(String amount) {
    return 'أضف $amount';
  }

  @override
  String get bodyWaterCustom => 'كمية أخرى';

  @override
  String get bodyWaterCustomTitle => 'كم شربت؟';

  @override
  String get bodyWaterAmount => 'الكمية';

  @override
  String get bodyWaterTarget => 'الهدف اليومي';

  @override
  String get bodyWaterTargetTitle => 'هدف الماء اليومي';

  @override
  String bodyWaterTargetSaved(String amount) {
    return 'الهدف الآن $amount';
  }

  @override
  String get bodyWaterGoalMet => 'بلغت هدف اليوم!';

  @override
  String bodyWaterLeft(String amount) {
    return 'بقي $amount';
  }

  @override
  String get bodyWaterWeek => 'الأسبوع الأخير';

  @override
  String bodyWaterAverage(String amount) {
    return 'المتوسط $amount';
  }

  @override
  String get bodyWaterToday => 'سجل اليوم';

  @override
  String get bodyWaterEmptyToday =>
      'لم تسجّل ماءً اليوم بعد — كوب واحد بداية جيدة.';

  @override
  String bodyWaterAdded(String amount) {
    return 'أُضيف $amount';
  }

  @override
  String bodyWaterRemoved(String amount) {
    return 'حُذف $amount';
  }

  @override
  String get bodyWaterEditTitle => 'تعديل الكمية';

  @override
  String get bodyWaterUpdated => 'حُدّثت الكمية';

  @override
  String get bodyAvoidTitle => 'قائمة التجنّب';

  @override
  String get bodyAvoidSubtitle =>
      'حركات وأطعمة اخترت أن تبتعد عنها، مع أسبابك أنت.';

  @override
  String get bodyAvoidAdd => 'أضف إلى القائمة';

  @override
  String get bodyAvoidEdit => 'تعديل البند';

  @override
  String get bodyAvoidWhat => 'ماذا تتجنّب؟';

  @override
  String get bodyAvoidWhatHint => 'مثلًا: رفع الأثقال فوق الرأس';

  @override
  String get bodyAvoidReason => 'السبب';

  @override
  String get bodyAvoidReasonHint => 'مثلًا: بحسب نصيحة المختص';

  @override
  String get bodyAvoidEmptyTitle => 'القائمة فارغة';

  @override
  String get bodyAvoidEmptyBody =>
      'دوّن ما تريد تجنّبه ولماذا — مثلًا: المشروبات الغازية، أو القرفصاء العميقة.';

  @override
  String get bodyAvoidRemoved => 'حُذف من القائمة';

  @override
  String get bodyAvoidNoReason => 'بلا سبب مكتوب';

  @override
  String get bodyCardTitle => 'الجسد اليوم';

  @override
  String get bodyCardTraining => 'التمرين';

  @override
  String get bodyCardFasting => 'الصيام';

  @override
  String get bodyCardWater => 'الماء';

  @override
  String get bodyNotifyGroup => 'الجسد';

  @override
  String get bodyNotifyChannel => 'تنبيهات الصيام';

  @override
  String get bodyNotifyChannelDescription =>
      'بلوغ هدف الصيام واقتراب إغلاق نافذة الأكل';

  @override
  String get bodyNotifyGoalTitle => 'بلغت هدف صيامك';

  @override
  String bodyNotifyGoalBody(String hours) {
    return 'أتممت هدف صيامك ($hours س) — أحسنت.';
  }

  @override
  String get bodyNotifyEatingTitle => 'نافذة الأكل تُغلق قريبًا';

  @override
  String bodyNotifyEatingBody(String time) {
    return 'آخر وجبة عند $time.';
  }

  @override
  String get bodyNotifyHint => 'يحتاج إذن الإشعارات على الهاتف.';

  @override
  String get cmodTitle => 'متتبّعات وقوائم';

  @override
  String get cmodNewModule => 'وحدة جديدة';

  @override
  String cmodModulesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count وحدة',
      many: '$count وحدة',
      few: '$count وحدات',
      two: 'وحدتان',
      one: 'وحدة واحدة',
      zero: 'لا وحدات بعد',
    );
    return '$_temp0';
  }

  @override
  String cmodLoggedToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count إدخال اليوم',
      many: '$count إدخالًا اليوم',
      few: '$count إدخالات اليوم',
      two: 'إدخالان اليوم',
      one: 'إدخال واحد اليوم',
      zero: 'لم تسجّل شيئًا اليوم بعد',
    );
    return '$_temp0';
  }

  @override
  String cmodEntriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count إدخال',
      many: '$count إدخالًا',
      few: '$count إدخالات',
      two: 'إدخالان',
      one: 'إدخال واحد',
      zero: 'لا إدخالات',
    );
    return '$_temp0';
  }

  @override
  String cmodItemsCount(int count) {
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
  String cmodItemsProgress(String done, String total) {
    return '$done من $total منجز';
  }

  @override
  String cmodOpenItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عنصر متبقٍّ',
      many: '$count عنصرًا متبقيًا',
      few: '$count عناصر متبقية',
      two: 'عنصران متبقيان',
      one: 'عنصر واحد متبقٍّ',
      zero: 'لا شيء متبقٍّ',
    );
    return '$_temp0';
  }

  @override
  String get cmodEmptyTitle => 'اصنع متتبّعك الأول';

  @override
  String get cmodEmptyBody =>
      'تتبّع ما يهمّك بحقولك أنت: سجلّ قراءة، أذكار بعد الصلاة، قائمة عادات… ويظهر كل ذلك في كواكبك.';

  @override
  String get cmodEmptyAction => 'أنشئ وحدة';

  @override
  String get cmodArchivedSection => 'المؤرشفة';

  @override
  String get cmodKindTracker => 'متتبّع';

  @override
  String get cmodKindList => 'قائمة';

  @override
  String get cmodKindTrackerHint => 'قيم تسجّلها مع الأيام، برسوم بيانية';

  @override
  String get cmodKindListHint => 'عناصر تشطبها وترتّبها';

  @override
  String get cmodLastToday => 'آخر إدخال اليوم';

  @override
  String get cmodLastYesterday => 'آخر إدخال أمس';

  @override
  String cmodLastDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'آخر إدخال قبل $count يوم',
      many: 'آخر إدخال قبل $count يومًا',
      few: 'آخر إدخال قبل $count أيام',
      two: 'آخر إدخال قبل يومين',
      one: 'آخر إدخال قبل يوم',
    );
    return '$_temp0';
  }

  @override
  String get cmodNoEntries => 'لا إدخالات بعد';

  @override
  String cmodStreakBadge(String count) {
    return 'سلسلة $count';
  }

  @override
  String get cmodActionArchive => 'أرشفة';

  @override
  String get cmodActionUnarchive => 'إعادة من الأرشيف';

  @override
  String get cmodActionAddEntry => 'إدخال جديد';

  @override
  String get cmodActionOpen => 'فتح';

  @override
  String get cmodActionExport => 'مشاركة كملف CSV';

  @override
  String get cmodActionUncheck => 'إعادة فتح';

  @override
  String get cmodActionCheck => 'إنجاز';

  @override
  String cmodToastArchived(String name) {
    return 'أُرشفت «$name»';
  }

  @override
  String cmodToastUnarchived(String name) {
    return 'عادت «$name» من الأرشيف';
  }

  @override
  String cmodToastDeleted(String name) {
    return 'حُذفت «$name»';
  }

  @override
  String cmodToastDuplicated(String name) {
    return 'نُسخت «$name»';
  }

  @override
  String cmodToastLogged(String name) {
    return 'سُجّل في «$name»';
  }

  @override
  String get cmodToastUnchecked => 'أُلغي تسجيل اليوم';

  @override
  String get cmodToastEntryDeleted => 'حُذف الإدخال';

  @override
  String get cmodToastEntryDuplicated => 'نُسخ الإدخال';

  @override
  String get cmodToastItemDone => 'أُنجز العنصر';

  @override
  String get cmodToastItemReopened => 'أُعيد فتح العنصر';

  @override
  String get cmodToastCleared => 'مُسحت العناصر المنجزة';

  @override
  String cmodToastSaved(String name) {
    return 'حُفظت «$name»';
  }

  @override
  String get cmodToastReminderDeleted => 'حُذف التذكير';

  @override
  String get cmodToastReminderAdded => 'أُضيف التذكير';

  @override
  String get cmodQuickDone => 'تمّ اليوم';

  @override
  String get cmodQuickDoneHint => 'سجّل إنجاز اليوم بلمسة';

  @override
  String get cmodQuickChecked => 'أُنجز اليوم';

  @override
  String get cmodQuickCheckedHint => 'المس لإلغاء تسجيل اليوم';

  @override
  String get cmodQuickAddOne => 'سجّل مرّة';

  @override
  String get cmodQuickRate => 'قيّم اليوم';

  @override
  String cmodRateStars(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نجمة',
      many: '$count نجمة',
      few: '$count نجوم',
      two: 'نجمتان',
      one: 'نجمة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get cmodBuilderNewTitle => 'وحدة جديدة';

  @override
  String get cmodBuilderEditTitle => 'تعديل الوحدة';

  @override
  String get cmodSectionBasics => 'الأساسيات';

  @override
  String get cmodName => 'الاسم';

  @override
  String get cmodNameHint => 'مثال: سجلّ القراءة';

  @override
  String get cmodKind => 'النوع';

  @override
  String get cmodIcon => 'الأيقونة';

  @override
  String get cmodColor => 'اللون';

  @override
  String get cmodPlanet => 'الكوكب';

  @override
  String get cmodPlanetNone => 'بلا كوكب';

  @override
  String get cmodPlanetHint =>
      'كل إدخال يُنعش هذا الكوكب في المدار، ويدور حوله قمرًا';

  @override
  String get cmodWindow => 'وقت الصلاة';

  @override
  String get cmodWindowHint => 'متى تتوقّع أن تسجّل عادةً';

  @override
  String get cmodSectionFields => 'الحقول';

  @override
  String get cmodAddField => 'أضف حقلًا';

  @override
  String get cmodFieldsEmptyTracker =>
      'بلا حقول يصبح المتتبّع عدّادًا بلمسة واحدة';

  @override
  String get cmodFieldsEmptyList => 'أضف حقلًا واحدًا على الأقل، كاسم العنصر';

  @override
  String get cmodHiddenFields => 'حقول مخفية';

  @override
  String get cmodHiddenFieldsHint =>
      'أُزيلت من النموذج، وبياناتها القديمة محفوظة';

  @override
  String get cmodRestoreField => 'إظهار';

  @override
  String get cmodSectionChart => 'الرسم البياني';

  @override
  String get cmodChartField => 'ما يُرسم';

  @override
  String get cmodChartEntries => 'عدد الإدخالات';

  @override
  String get cmodChartStyle => 'الشكل';

  @override
  String get cmodChartRange => 'المدة';

  @override
  String get cmodChartLine => 'خط';

  @override
  String get cmodChartBar => 'أعمدة';

  @override
  String get cmodChartHeat => 'تقويم';

  @override
  String get cmodChartStreak => 'سلسلة';

  @override
  String get cmodChartEmpty => 'لا بيانات في هذه المدة بعد';

  @override
  String cmodRangeDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يوم',
      many: '$count يومًا',
      few: '$count أيام',
      two: 'يومان',
      one: 'يوم',
    );
    return '$_temp0';
  }

  @override
  String get cmodSave => 'حفظ';

  @override
  String get cmodCreate => 'إنشاء';

  @override
  String get cmodCancel => 'إلغاء';

  @override
  String get cmodDiscardTitle => 'تجاهل التغييرات؟';

  @override
  String get cmodDiscardBody => 'لم تُحفظ تعديلاتك على هذه الوحدة.';

  @override
  String get cmodDiscard => 'تجاهل';

  @override
  String get cmodKeepEditing => 'متابعة التعديل';

  @override
  String get cmodPreviewUntitled => 'وحدة بلا اسم';

  @override
  String get cmodIssueNameMissing => 'اكتب اسمًا للوحدة';

  @override
  String get cmodIssueNameTooLong => 'الاسم طويل جدًا';

  @override
  String get cmodIssueNoFields => 'أضف حقلًا واحدًا على الأقل';

  @override
  String cmodIssueTooManyFields(String max) {
    return 'الحد الأقصى $max حقلًا';
  }

  @override
  String get cmodIssueLabelMissing => 'حقل بلا اسم';

  @override
  String get cmodIssueLabelDuplicate => 'اسم الحقل مكرّر';

  @override
  String get cmodIssueNoOptions => 'أضف خيارًا واحدًا على الأقل';

  @override
  String get cmodIssueOptionLabelMissing => 'خيار بلا اسم';

  @override
  String get cmodIssueOptionDuplicate => 'خيار مكرّر';

  @override
  String get cmodIssueRangeInverted => 'الحد الأدنى أكبر من الأعلى';

  @override
  String get cmodIssueCurrencyCode => 'رمز العملة غير صالح';

  @override
  String get cmodMigrationTitle => 'قبل الحفظ';

  @override
  String get cmodMigrationBlockedTitle => 'هذا التغيير سيضيّع بيانات';

  @override
  String get cmodMigrationBlockedBody =>
      'لم يُحفظ شيء. أعد النوع كما كان، أو أضف حقلًا جديدًا بالنوع الذي تريده.';

  @override
  String get cmodMigrationOk => 'حسنًا';

  @override
  String cmodMigTypeBlocked(String field, String entries, String type) {
    return '«$field»: $entries لا تصلح بنوع «$type»';
  }

  @override
  String cmodMigRatingBlocked(String field, String entries) {
    return '«$field»: $entries فيها نجوم أكثر من المقياس الجديد';
  }

  @override
  String cmodMigFieldHidden(String field, String entries) {
    return '«$field» سيُخفى، وتبقى قيمه في $entries';
  }

  @override
  String cmodMigOptionHidden(String field) {
    return 'الخيارات المحذوفة من «$field» والمستخدمة ستُخفى ولن تُحذف';
  }

  @override
  String cmodMigConverted(String field, String entries, String type) {
    return 'قيم «$field» في $entries ستتحوّل إلى «$type»';
  }

  @override
  String cmodMigOutOfRange(String field, String entries) {
    return '$entries في «$field» خارج الحدود الجديدة وستبقى كما هي';
  }

  @override
  String cmodMigNewlyRequired(String field, String entries) {
    return '$entries بلا قيمة لـ«$field» الذي صار مطلوبًا';
  }

  @override
  String get cmodTypeText => 'نص';

  @override
  String get cmodTypeNumber => 'رقم';

  @override
  String get cmodTypeDate => 'تاريخ';

  @override
  String get cmodTypeTime => 'وقت';

  @override
  String get cmodTypeCheckbox => 'خانة إنجاز';

  @override
  String get cmodTypeSingle => 'اختيار واحد';

  @override
  String get cmodTypeMulti => 'اختيارات متعددة';

  @override
  String get cmodTypeRating => 'تقييم بالنجوم';

  @override
  String get cmodTypeCurrency => 'مبلغ';

  @override
  String get cmodTypeTextHint => 'ملاحظة، عنوان كتاب…';

  @override
  String get cmodTypeNumberHint => 'صفحات، دقائق، مرّات…';

  @override
  String get cmodTypeDateHint => 'موعد أو مناسبة';

  @override
  String get cmodTypeTimeHint => 'وقت النوم، وقت البدء…';

  @override
  String get cmodTypeCheckboxHint => 'تمّ أو لم يتمّ';

  @override
  String get cmodTypeSingleHint => 'خيار واحد من قائمتك';

  @override
  String get cmodTypeMultiHint => 'عدّة خيارات من قائمتك';

  @override
  String get cmodTypeRatingHint => 'من نجمتين إلى عشر';

  @override
  String get cmodTypeCurrencyHint => 'مبلغ بعملة تختارها';

  @override
  String get cmodPickType => 'نوع الحقل';

  @override
  String get cmodFieldNew => 'حقل جديد';

  @override
  String get cmodFieldEdit => 'تعديل الحقل';

  @override
  String get cmodFieldLabel => 'اسم الحقل';

  @override
  String get cmodFieldLabelHint => 'مثال: الصفحات';

  @override
  String get cmodFieldRequired => 'مطلوب';

  @override
  String get cmodFieldRequiredHint => 'لا يُحفظ الإدخال دونه';

  @override
  String get cmodFieldUnit => 'الوحدة';

  @override
  String get cmodFieldUnitHint => 'صفحة، دقيقة، كغ…';

  @override
  String get cmodFieldMin => 'الحد الأدنى';

  @override
  String get cmodFieldMax => 'الحد الأعلى';

  @override
  String get cmodFieldNoLimit => 'بلا حد';

  @override
  String get cmodFieldDecimals => 'الخانات العشرية';

  @override
  String get cmodFieldScale => 'المقياس';

  @override
  String get cmodFieldCurrency => 'العملة';

  @override
  String get cmodFieldOptions => 'الخيارات';

  @override
  String get cmodAddOption => 'أضف خيارًا';

  @override
  String get cmodOptionHint => 'اسم الخيار';

  @override
  String get cmodRemoveOption => 'احذف الخيار';

  @override
  String get cmodFieldMultiline => 'نص طويل';

  @override
  String get cmodFieldMultilineHint => 'يتّسع لعدّة أسطر';

  @override
  String get cmodFieldDelete => 'احذف الحقل';

  @override
  String cmodFieldCopyLabel(String label) {
    return '$label (نسخة)';
  }

  @override
  String get cmodFieldTypeNote =>
      'إن غيّرت النوع تتحوّل القيم القديمة حين يمكن ذلك، وإلا لا يُحفظ التغيير.';

  @override
  String cmodFieldOptionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count خيار',
      many: '$count خيارًا',
      few: '$count خيارات',
      two: 'خياران',
      one: 'خيار واحد',
      zero: 'بلا خيارات',
    );
    return '$_temp0';
  }

  @override
  String cmodFieldRange(String min, String max) {
    return '$min – $max';
  }

  @override
  String cmodFieldAtLeast(String min) {
    return 'من $min';
  }

  @override
  String cmodFieldAtMost(String max) {
    return 'حتى $max';
  }

  @override
  String cmodFieldDeleted(String name) {
    return 'حُذف «$name» من النموذج';
  }

  @override
  String get cmodFieldDuplicated => 'نُسخ الحقل';

  @override
  String get cmodGalleryTitle => 'ابدأ وحدة';

  @override
  String get cmodGallerySubtitle => 'من الصفر أو من قالب، وكل شيء قابل للتعديل';

  @override
  String get cmodBlankTracker => 'متتبّع فارغ';

  @override
  String get cmodBlankList => 'قائمة فارغة';

  @override
  String get cmodTemplatesHeader => 'قوالب للبدء';

  @override
  String get cmodTplReadingLog => 'سجلّ القراءة';

  @override
  String get cmodTplReadingLogDesc => 'الكتاب والصفحات وتقييمك';

  @override
  String get cmodTplDhikr => 'أذكار بعد الصلاة';

  @override
  String get cmodTplDhikrDesc => 'كم مرّة ذكرت الله، وبعد أي صلاة';

  @override
  String get cmodTplHabit => 'عادة يومية';

  @override
  String get cmodTplHabitDesc => 'لمسة واحدة كل يوم، وسلسلة تكبر';

  @override
  String get cmodTplHabitList => 'قائمة عادات';

  @override
  String get cmodTplHabitListDesc => 'عادات تريد بناءها وكم تتكرّر';

  @override
  String get cmodTplSleep => 'سجلّ النوم';

  @override
  String get cmodTplSleepDesc => 'النوم والاستيقاظ والساعات والجودة';

  @override
  String get cmodTplGifts => 'أفكار هدايا';

  @override
  String get cmodTplGiftsDesc => 'الفكرة ولمن والميزانية والمناسبة';

  @override
  String get cmodTplBook => 'الكتاب';

  @override
  String get cmodTplPages => 'الصفحات';

  @override
  String get cmodTplRating => 'التقييم';

  @override
  String get cmodTplUnitPages => 'صفحة';

  @override
  String get cmodTplAfterPrayer => 'بعد صلاة';

  @override
  String get cmodTplCount => 'العدد';

  @override
  String get cmodTplUnitTimes => 'مرّة';

  @override
  String get cmodTplDone => 'تمّ';

  @override
  String get cmodTplNote => 'ملاحظة';

  @override
  String get cmodTplHabitItem => 'العادة';

  @override
  String get cmodTplFrequency => 'التكرار';

  @override
  String get cmodTplDaily => 'يوميًا';

  @override
  String get cmodTplWeekly => 'أسبوعيًا';

  @override
  String get cmodTplMonthly => 'شهريًا';

  @override
  String get cmodTplBedtime => 'وقت النوم';

  @override
  String get cmodTplWake => 'وقت الاستيقاظ';

  @override
  String get cmodTplHours => 'ساعات النوم';

  @override
  String get cmodTplUnitHours => 'ساعة';

  @override
  String get cmodTplQuality => 'الجودة';

  @override
  String get cmodTplIdea => 'الفكرة';

  @override
  String get cmodTplFor => 'لمن';

  @override
  String get cmodTplBudget => 'الميزانية';

  @override
  String get cmodTplOccasion => 'المناسبة';

  @override
  String get cmodTplNotes => 'ملاحظات';

  @override
  String get cmodAddEntry => 'إدخال جديد';

  @override
  String get cmodAddItem => 'عنصر جديد';

  @override
  String get cmodEntriesSection => 'الإدخالات';

  @override
  String get cmodItemsSection => 'العناصر';

  @override
  String get cmodDoneSection => 'المنجزة';

  @override
  String get cmodClearDone => 'امسح المنجزة';

  @override
  String get cmodToday => 'اليوم';

  @override
  String get cmodYesterday => 'أمس';

  @override
  String get cmodEntriesEmpty => 'لا إدخالات بعد. أول إدخال يبدأ الحكاية.';

  @override
  String get cmodItemsEmpty => 'القائمة فارغة. أضف أول عنصر.';

  @override
  String get cmodAllDone => 'أنجزت كل شيء، ما شاء الله';

  @override
  String get cmodStatStreak => 'السلسلة';

  @override
  String get cmodStatBest => 'الأفضل';

  @override
  String get cmodStatTotal => 'المجموع';

  @override
  String get cmodStatAverage => 'المتوسط';

  @override
  String get cmodStatActive => 'أيام نشطة';

  @override
  String get cmodStatEntries => 'الإدخالات';

  @override
  String get cmodStatRate => 'نسبة الإنجاز';

  @override
  String cmodDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يوم',
      many: '$count يومًا',
      few: '$count أيام',
      two: 'يومان',
      one: 'يوم',
      zero: '٠ يوم',
    );
    return '$_temp0';
  }

  @override
  String get cmodReminders => 'التذكيرات';

  @override
  String get cmodAddReminder => 'أضف تذكيرًا';

  @override
  String get cmodRemindersEmpty => 'ذكّرني بعد صلاة أو في وقت أحدّده';

  @override
  String get cmodReminderPaused => 'متوقّف';

  @override
  String get cmodReminderToggle => 'تشغيل التذكير';

  @override
  String get cmodModuleMenu => 'خيارات الوحدة';

  @override
  String cmodHiddenValue(String label) {
    return '$label (مخفي)';
  }

  @override
  String get cmodNotifyGroup => 'المتتبّعات والقوائم';

  @override
  String get cmodNotifyChannel => 'تذكيرات المتتبّعات والقوائم';

  @override
  String get cmodNotifyChannelDescription =>
      'تذكيرات لطيفة لتسجيل متتبّعاتك ومراجعة قوائمك';

  @override
  String get cmodNotifyBodyTracker => 'حان وقت التسجيل';

  @override
  String get cmodNotifyBodyList => 'ألقِ نظرة على قائمتك';

  @override
  String get cmodEntryNew => 'إدخال جديد';

  @override
  String get cmodEntryEdit => 'تعديل الإدخال';

  @override
  String get cmodItemNew => 'عنصر جديد';

  @override
  String get cmodItemEdit => 'تعديل العنصر';

  @override
  String get cmodEntryWhen => 'متى';

  @override
  String get cmodEntryDone => 'منجز';

  @override
  String get cmodEntryCounter => 'هذه الوحدة عدّاد: الحفظ يسجّل مرّة واحدة.';

  @override
  String get cmodErrRequired => 'هذا الحقل مطلوب';

  @override
  String get cmodErrNumber => 'اكتب رقمًا';

  @override
  String get cmodErrWhole => 'رقم صحيح فقط';

  @override
  String cmodErrPrecise(String count) {
    return '$count خانات عشرية على الأكثر';
  }

  @override
  String cmodErrMin(String value) {
    return 'لا يقلّ عن $value';
  }

  @override
  String cmodErrMax(String value) {
    return 'لا يزيد على $value';
  }

  @override
  String get cmodErrDate => 'تاريخ غير صالح';

  @override
  String get cmodErrTime => 'وقت غير صالح';

  @override
  String get cmodErrOption => 'اختر من القائمة';

  @override
  String get cmodErrScale => 'خارج المقياس';

  @override
  String get cmodErrTooLong => 'النص طويل جدًا';

  @override
  String get cmodPickDate => 'اختر تاريخًا';

  @override
  String get cmodPickTime => 'اختر وقتًا';

  @override
  String get cmodClear => 'مسح';

  @override
  String get cmodYes => 'نعم';

  @override
  String get cmodNo => 'لا';

  @override
  String get cmodChecked => 'تمّ';

  @override
  String get cmodUnchecked => 'لم يتمّ';

  @override
  String get cmodCardTitle => 'متتبّعاتك هنا';

  @override
  String get cmodCardSeeAll => 'عرض الكل';

  @override
  String get cmodCardEmpty => 'أنشئ متتبّعًا لهذا العالم';

  @override
  String get cmodCardEmptyHint => 'عدّاد، أو سجلّ، أو قائمة: بحقولك أنت';

  @override
  String get cmodExportDate => 'التاريخ';

  @override
  String get cmodExportTime => 'الوقت';

  @override
  String get cmodExportDone => 'منجز';

  @override
  String get cmodExportEntries => 'الإدخالات';

  @override
  String get cmodExportLastEntry => 'آخر إدخال';

  @override
  String get cmodExportOpen => 'متبقٍّ';

  @override
  String cmodExportLastDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'آخر $count يوم',
      many: 'آخر $count يومًا',
      few: 'آخر $count أيام',
      two: 'آخر يومين',
      one: 'آخر يوم',
    );
    return '$_temp0';
  }

  @override
  String cmodExportActiveDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يوم نشط',
      many: '$count يومًا نشطًا',
      few: '$count أيام نشطة',
      two: 'يومان نشطان',
      one: 'يوم نشط واحد',
      zero: 'لا أيام نشطة',
    );
    return '$_temp0';
  }

  @override
  String cmodExportTotal(String value) {
    return 'المجموع $value';
  }

  @override
  String cmodExportAverage(String value) {
    return 'المتوسط $value';
  }

  @override
  String cmodExportStreak(String current, String best) {
    return 'السلسلة $current (الأفضل $best)';
  }

  @override
  String get cmodExportHidden => 'مخفي';

  @override
  String get lifeHubToolsTitle => 'أدوات';

  @override
  String get lifeHubPeople => 'الأحبّة';

  @override
  String get lifeHubToolBoardsHint => 'لوحات المهام وأعمدتها';

  @override
  String get lifeHubToolProjectsHint => 'المشاريع وقوائمها وعدّها التنازلي';

  @override
  String get lifeHubToolPeopleHint => 'كل من تحبّ أن تبقى قريبًا منه';

  @override
  String get lifeHubToolRemindersHint => 'الملخّص اليومي وأعياد الميلاد';

  @override
  String get lifeHubToolTripsHint => 'رحلاتك وعدّها التنازلي';

  @override
  String get lifeHubToolDocumentsHint => 'الجوازات والتأشيرات وتواريخ انتهائها';

  @override
  String get lifeHubToolGoalsHint => 'أهداف التعلّم وتقدّمك فيها';

  @override
  String get lifeHubToolPlanHint => 'تمارين الأسبوع حسب الأيام';

  @override
  String get lifeHubToolAvoidHint => 'ما اخترت أن تبتعد عنه';

  @override
  String get lifeHubMoonOpenPerson => 'افتح صفحته';

  @override
  String get lifeHubMoonOpenBoard => 'افتح اللوحة';

  @override
  String get lifeHubMoonOpenTrip => 'افتح الرحلة';

  @override
  String get lifeHubMoonOpenModule => 'افتح المتتبّع';

  @override
  String get lifeHubSettingsSection => 'الحياة';

  @override
  String get lifeHubSettingsSectionHint => 'العائلة والجسد والسفر ومتتبّعاتك';

  @override
  String lifeHubSettingsFamilyOn(String time) {
    return 'ملخّص يومي الساعة $time';
  }

  @override
  String get lifeHubSettingsFamilyBirthdays => 'أعياد الميلاد فقط';

  @override
  String get lifeHubSettingsFamilyOff => 'متوقّفة';

  @override
  String lifeHubSettingsWaterValue(String ml) {
    return '$ml مل يوميًا';
  }

  @override
  String get lifeHubSettingsFastingHint => 'الخطة والتنبيهات';

  @override
  String get lifeHubSettingsTemplatesHint => 'قوائم جاهزة لكل رحلة';

  @override
  String lifeHubSettingsModulesCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n متتبّع',
      many: '$n متتبّعًا',
      few: '$n متتبّعات',
      two: 'متتبّعان',
      one: 'متتبّع واحد',
      zero: 'لا متتبّعات بعد',
    );
    return '$_temp0';
  }

  @override
  String get lifeHubPrayerDestination => 'وجهتك';

  @override
  String get cinemaTitle => 'سينما مدار';

  @override
  String get cinemaHallSubtitle => 'ألعاب أصلية بروح السينما الكلاسيكية';

  @override
  String get cinemaFeatures => 'الأفلام الطويلة';

  @override
  String get cinemaShorts => 'الأفلام القصيرة';

  @override
  String get cinemaComingSoon => 'قريبًا';

  @override
  String get cinemaPlay => 'إلى العرض';

  @override
  String get cinemaGameViewLabel => 'شاشة اللعبة';

  @override
  String get cinemaPause => 'إيقاف مؤقت';

  @override
  String get cinemaIntermission => 'استراحة';

  @override
  String get cinemaResume => 'متابعة العرض';

  @override
  String get cinemaRestart => 'من البداية';

  @override
  String get cinemaLeave => 'مغادرة القاعة';

  @override
  String get cinemaExitGame => 'الخروج من اللعبة';

  @override
  String get cinemaExitConfirmTitle => 'بدك تطلع من اللعبة؟';

  @override
  String get cinemaExitConfirmBody =>
      'إذا طلعت هلأ، الجولة الحالية تنتهي وما تنحفظ نتيجتها.';

  @override
  String get cinemaExitStay => 'أكمل اللعب';

  @override
  String get cinemaPlayAgain => 'عرض آخر';

  @override
  String get cinemaTheEnd => 'النهاية';

  @override
  String get cinemaGameOver => 'انتهى العرض';

  @override
  String cinemaScoreLine(String score) {
    return 'النتيجة: $score';
  }

  @override
  String cinemaBestLine(String score) {
    return 'أفضل نتيجة: $score';
  }

  @override
  String get cinemaEraSilent => 'العشرينيات الصامتة';

  @override
  String get cinemaEraRubberHose => 'كرتون الثلاثينيات';

  @override
  String get cinemaEraNoir => 'نوار الأربعينيات';

  @override
  String get cinemaEraTechnicolor => 'ألوان الخمسينيات';

  @override
  String get cinemaEraGrindhouse => 'سينما السبعينيات';

  @override
  String get cinemaEraVhs => 'فيديو الثمانينيات';

  @override
  String get cinemaDemoTitle => 'بروفة';

  @override
  String get cinemaDemoTagline => 'مشهد تجريبي لمحرّك بكرة الفيلم';

  @override
  String get cinemaDemoOpening => 'المشهد الأول';

  @override
  String get cinemaDemoOpeningSubtitle => 'المس الشاشة لتقفز فوق البراميل!';

  @override
  String get cinemaFlappyOrbitTitle => 'رفرفة المدار';

  @override
  String get cinemaFlappyOrbitTagline =>
      'رفرف فوق سطوح المدينة على أنغام السوينغ';

  @override
  String get cinemaFlappyOrbitHomage =>
      'تحية لرسوم الخرطوم المطاطي في الثلاثينيات';

  @override
  String get cinemaMetropolisTitle => 'آلة المتروبوليس';

  @override
  String get cinemaMetropolisTagline => 'واجه الآلات العملاقة واحدة تلو الأخرى';

  @override
  String get cinemaMetropolisHomage =>
      'تحية لفيلم «متروبوليس» الصامت من العشرينيات';

  @override
  String get cinemaCaravanTitle => 'سباق القافلة';

  @override
  String get cinemaCaravanTagline => 'اعبر الكثبان بألوان التكنيكولور';

  @override
  String get cinemaCaravanHomage => 'تحية لملاحم الصحراء في الخمسينيات';

  @override
  String get cinemaNoirTitle => 'أسطح النوار';

  @override
  String get cinemaNoirTagline => 'طارد الظلال فوق أسطح المدينة الممطرة';

  @override
  String get cinemaNoirHomage => 'تحية لأفلام النوار في الأربعينيات';

  @override
  String get cinemaNeonSoukTitle => 'متسابق سوق النيون';

  @override
  String get cinemaNeonSoukTagline => 'انطلق عبر سوق من أضواء النيون';

  @override
  String get cinemaNeonSoukHomage =>
      'تحية لأفلام الخيال العلمي على أشرطة الفيديو';

  @override
  String get cinemaSavedGames => 'ألعابي المحفوظة';

  @override
  String get cinemaSavedGamesEmpty =>
      'أضف لعبة ويب برابطها لتلعبها هنا بملء الشاشة.';

  @override
  String get cinemaSavedGamesNote =>
      'تُفتح الألعاب من رابطها الأصلي، ولا يُنسخ شيء منها داخل التطبيق.';

  @override
  String get cinemaAddGame => 'إضافة لعبة';

  @override
  String get cinemaGameName => 'اسم اللعبة';

  @override
  String get cinemaGameUrl => 'رابط اللعبة';

  @override
  String get cinemaInvalidUrl => 'أدخل رابطًا صحيحًا يبدأ بـ https://';

  @override
  String get cinemaRemoveGame => 'إزالة';

  @override
  String get cinemaOpenGameFailed => 'تعذّر فتح الرابط';

  @override
  String get cinemaSave => 'حفظ';

  @override
  String get cinemaCancel => 'إلغاء';

  @override
  String get cinemaFxTestCard => 'بطاقة المعايرة';

  @override
  String get cinemaFxFilmLook => 'مظهر الفيلم';

  @override
  String get cinemaFxQualityLowPower => 'توفير الطاقة';

  @override
  String get cinemaFxQualityBalanced => 'متوازن';

  @override
  String get cinemaFxQualityFull => 'أعلى دقة';

  @override
  String get cinemaFxReelLabel => 'بكرة';

  @override
  String get cinemaHallNowShowing => 'يُعرض الآن';

  @override
  String get cinemaHallTonight => 'عرض الليلة';

  @override
  String get cinemaHallWelcome => 'أهلًا بك في قصر العروض';

  @override
  String get cinemaHallProgramme => 'البرنامج الكامل';

  @override
  String get cinemaHallAllEras => 'كل العصور';

  @override
  String get cinemaHallAllKinds => 'كل الأنواع';

  @override
  String get cinemaHallReadyOnly => 'الجاهز للعرض';

  @override
  String get cinemaHallGenreCards => 'ألعاب الورق';

  @override
  String get cinemaHallGenreBoard => 'ألعاب الطاولة';

  @override
  String get cinemaHallGenreArcade => 'الأركيد';

  @override
  String get cinemaHallGenrePuzzle => 'الألغاز';

  @override
  String get cinemaHallGenreWord => 'ألعاب الكلمات';

  @override
  String get cinemaHallBackstage => 'خلف الكواليس';

  @override
  String get cinemaHallLockedSlot => 'عرض قادم';

  @override
  String get cinemaHallLockedHint =>
      'هذا الفيلم ما زال في غرفة المونتاج. عُد قريبًا!';

  @override
  String get cinemaHallShortsSoon =>
      'عشرات الأفلام القصيرة في الطريق: ورق وطاولة وأركيد وكلمات.';

  @override
  String get cinemaHallNothingMatches =>
      'لا عروض بهذا الاختيار. جرّب عصرًا آخر.';

  @override
  String get cinemaHallTicketBook => 'دفتر التذاكر';

  @override
  String get cinemaHallStatShows => 'العروض';

  @override
  String get cinemaHallStatWins => 'النهايات السعيدة';

  @override
  String get cinemaHallStatTime => 'وقت المشاهدة';

  @override
  String get cinemaHallStatFavourite => 'العرض المفضّل';

  @override
  String get cinemaHallFirstTicket =>
      'تذكرتك الأولى بانتظارك. اختر عرضًا وادخل القاعة.';

  @override
  String cinemaHallBestBadge(String score) {
    return 'الأفضل $score';
  }

  @override
  String cinemaHallPosterLabel(String title, String era) {
    return 'ملصق $title، $era';
  }

  @override
  String get cinemaHallComingSoonTitle => 'العرض لم يبدأ بعد';

  @override
  String get cinemaHallComingSoonBody =>
      'ما زلنا نصوّر هذا الفيلم. الستارة ستُفتح قريبًا.';

  @override
  String get cinemaHallNotFound => 'لم نجد هذا العرض في البرنامج.';

  @override
  String get cinemaHallBackToLobby => 'العودة إلى الردهة';

  @override
  String get cinemaHallPrayerMuted => 'الصوت متوقف وقت الصلاة';

  @override
  String get cinemaHallFooter =>
      'كل صورة هنا مرسومة بالكود، وكل نغمة مؤلَّفة لحظة العرض.';

  @override
  String get cinemaStageBoothNote => 'البكرة تستريح… والعرض بانتظارك.';

  @override
  String get cinemaStageScore => 'النتيجة';

  @override
  String get cinemaStageBest => 'الأفضل';

  @override
  String get cinemaStageNewRecord => 'رقم قياسي جديد!';

  @override
  String get cinemaStageRunningTime => 'مدة العرض';

  @override
  String get cinemaStageAdmitOne => 'تذكرة دخول';

  @override
  String get cinemaRigCast => 'طاقم التمثيل';

  @override
  String get cinemaRigNujaym => 'نُجيم';

  @override
  String get cinemaRigNujaymRole => 'طائر النجمة الشجاع، بطل «رفرفة المدار»';

  @override
  String get cinemaRigZunbruk => 'البارون زُنبُرك';

  @override
  String get cinemaRigZunbrukRole => 'رئيس العمّال الآلي في «آلة المتروبوليس»';

  @override
  String get cinemaRigZajil => 'زاجل';

  @override
  String get cinemaRigZajilRole => 'الجمل ساعي البريد في «سباق القافلة»';

  @override
  String get cinemaRigMishmish => 'المفتش مِشمِش';

  @override
  String get cinemaRigMishmishRole => 'القط المحقق ذو المعطف في «أسطح النوار»';

  @override
  String get cinemaRigSarab => 'سراب';

  @override
  String get cinemaRigSarabRole =>
      'راكبة الدراجة الطائرة في «متسابق سوق النيون»';

  @override
  String get cinemaRigBean => 'حبّة';

  @override
  String get cinemaRigBeanRole => 'نجم البروفة، حبّة فاصولياء بقفازين أبيضين';

  @override
  String get cinemaWiringEnterHall => 'ادخل القاعة';

  @override
  String cinemaWiringShowsReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عرض جاهز للعب',
      many: '$count عرضًا جاهزًا للعب',
      few: '$count عروض جاهزة للعب',
      two: 'عرضان جاهزان للعب',
      one: 'عرض واحد جاهز للعب',
      zero: 'العروض قيد التحضير',
    );
    return '$_temp0';
  }

  @override
  String get cinemaWiringCreditGames => 'ألعاب الكلمات والمعرفة في سينما مَدار';

  @override
  String get cinemaWiringCreditGamesRole => 'قوائم الكلمات وأسئلة المسابقات';

  @override
  String get cinemaDemoTapToJump => 'المس الشاشة لتقفز!';

  @override
  String get cinemaDemoActTwo => 'الفصل الثاني';

  @override
  String get cinemaDemoBossEnters => 'البارون زُنبُرك يدخل المسرح';

  @override
  String get cinemaFlappyOrbitTapToBoost => 'المس الشاشة لتدفع الصاروخ!';

  @override
  String get cinemaFlappyOrbitLaunchHint => 'المس الشاشة للإقلاع';

  @override
  String get cinemaFlappyOrbitBossName => 'المايسترو غَيم';

  @override
  String get cinemaFlappyOrbitActTwo => 'الفصل الثاني';

  @override
  String get cinemaFlappyOrbitActThree => 'الفصل الثالث';

  @override
  String get cinemaFlappyOrbitActFinal => 'الفصل الأخير';

  @override
  String get cinemaFlappyOrbitBossEnters => 'المايسترو غَيم يصعد المسرح';

  @override
  String get cinemaFlappyOrbitNearMiss => 'مرور خطر!';

  @override
  String get cinemaFlappyOrbitOnBeat => 'على الإيقاع!';

  @override
  String get cinemaFlappyOrbitGusted => 'عاصفة!';

  @override
  String get cinemaFlappyOrbitPhaseThunder => 'نوتات رعدية!';

  @override
  String get cinemaFlappyOrbitPhaseSpin => 'المسرح كله يدور!';

  @override
  String get cinemaFlappyOrbitBossDown => 'المايسترو طار مع الريح!';

  @override
  String get cinemaFlappyOrbitEndLoop => 'لفّة كاملة وهبوط بطولي!';

  @override
  String get cinemaFlappyOrbitEndPie => 'هبط في فطيرة الجيران!';

  @override
  String get cinemaMetropolisOpeningSubtitle =>
      'الوردية الليلية… والآلات استيقظت وحدها';

  @override
  String get cinemaMetropolisControlsHint =>
      'اضغط يسارًا أو يمينًا لتركض، المس لتضرب بالمفتاح، اسحب للأعلى لتقفز وللجانب لتندفع';

  @override
  String get cinemaMetropolisHero => 'مِفتاح';

  @override
  String get cinemaMetropolisIntroOne =>
      'دقّ جرس الوردية… ولم يخرج أحد من المصنع.';

  @override
  String get cinemaMetropolisIntroTwo =>
      'مِفتاح، مهندس الليل، حمل مفتاحه وفانوسه ودخل.';

  @override
  String cinemaMetropolisMachineOf(String index, String total) {
    return 'الآلة $index من $total';
  }

  @override
  String cinemaMetropolisBossPlate(String name, String index, String total) {
    return '$name — $index/$total';
  }

  @override
  String get cinemaMetropolisPressName => 'المِكبَس الساعاتي';

  @override
  String get cinemaMetropolisPressLine =>
      'يدقّ الساعة في الأرض. لا تقف حيث تقع الدقّة.';

  @override
  String get cinemaMetropolisBoilerName => 'القلب المِرجَل';

  @override
  String get cinemaMetropolisBoilerLine =>
      'ينفث بخاره بنظام. اقرأ النظام قبل أن يقرأك.';

  @override
  String get cinemaMetropolisSpiderName => 'عنكبوت لوحة التحويل';

  @override
  String get cinemaMetropolisSpiderLine =>
      'أرجلها أسلاك، وكل سلك يبحث عن مقبس… وأنت المقبس.';

  @override
  String get cinemaMetropolisTitanName => 'عملاق المصعد';

  @override
  String get cinemaMetropolisTitanLine =>
      'يرفع ويخفض كما يشاء. اركب المنصّات ولا تثق بالأرض.';

  @override
  String get cinemaMetropolisDynamoName => 'الدينامو الأم';

  @override
  String get cinemaMetropolisDynamoLine =>
      'قلب المدينة كلّه. كل ما تعلّمته… دفعة واحدة.';

  @override
  String get cinemaMetropolisTauntOne =>
      '«مكبس واحد؟ عندي مدينة كاملة من الآلات!»';

  @override
  String get cinemaMetropolisTauntTwo => '«بخار، أسلاك، مصاعد… اختر كيف تسقط.»';

  @override
  String get cinemaMetropolisTauntThree =>
      '«الطابق الأخير يا مهندس. هذا المصعد ينزل فقط.»';

  @override
  String get cinemaMetropolisTauntFour => '«كفى! سأشغّل الأم بنفسي!»';

  @override
  String get cinemaMetropolisBaronBeaten => '«هذا… ليس في الجدول!»';

  @override
  String get cinemaMetropolisTauntSigned => 'البارون زُنبُرك';

  @override
  String get cinemaMetropolisEndTitle => 'انتهت الوردية';

  @override
  String get cinemaMetropolisEndSubtitle =>
      'وعادت أنوار المدينة تشتعل واحدًا واحدًا.';

  @override
  String get cinemaMetropolisLostSubtitle =>
      'ربحت الآلات هذه الوردية. غدًا وردية أخرى.';

  @override
  String get cinemaMetropolisReelBack => 'استعدت بكرة!';

  @override
  String get cinemaMetropolisPhaseUp => 'الآلة تغضب!';

  @override
  String get cinemaMetropolisParry => 'صَدّ!';

  @override
  String get cinemaCaravanOpeningSubtitle =>
      'نوّارة وزاجل… وقافلة واحدة في سباق إلى الواحة الكبرى';

  @override
  String get cinemaCaravanControlsHint =>
      'المس لتقفز، اضغط مطوّلًا لتنزلق، اسحب للأعلى أو للأسفل لتغيّر المسار، اسحب جانبًا لترمي تمرة';

  @override
  String get cinemaCaravanHero => 'نوّارة';

  @override
  String get cinemaCaravanBossName => 'رَمّال، جنّي الرمل';

  @override
  String get cinemaCaravanScorpionName => 'العقربة النحاسية';

  @override
  String get cinemaCaravanLegOne => 'المرحلة الأولى: بحر الكثبان';

  @override
  String get cinemaCaravanLegTwo => 'المرحلة الثانية: الواحة وسوق الليل';

  @override
  String get cinemaCaravanLegThree => 'المرحلة الأخيرة: طريق الواحة الكبرى';

  @override
  String get cinemaCaravanMapHint => 'قافلة واحدة… وجنّي يريد حمولتها';

  @override
  String cinemaCaravanHudLeg(String index, String total) {
    return 'المرحلة $index/$total';
  }

  @override
  String get cinemaCaravanSandstorm => 'عاصفة رملية!';

  @override
  String get cinemaCaravanNightMarket => 'سوق الليل';

  @override
  String get cinemaCaravanLanternLit => 'الفانوس يضيء الدرب!';

  @override
  String get cinemaCaravanDjinnEnters => 'رَمّال يطلع من الرمل';

  @override
  String get cinemaCaravanDjinnBarrels => '«براميلي راح تدحرجكم للرمل!»';

  @override
  String get cinemaCaravanDjinnWhirls => '«زوابعي بتعرف وين تختبئوا!»';

  @override
  String get cinemaCaravanDjinnScorpion => '«عقربتي النحاسية أسرع من أي جمل!»';

  @override
  String get cinemaCaravanDjinnSigned => 'رَمّال';

  @override
  String get cinemaCaravanDjinnBeaten => '«هذا… مش عدل!»';

  @override
  String get cinemaCaravanDjinnFlees => 'رَمّال يهرب!';

  @override
  String get cinemaCaravanThrowHint => 'اسحب جانبًا لترمي التمر!';

  @override
  String get cinemaCaravanOutrun => 'اسبقه!';

  @override
  String get cinemaCaravanEndTitle => 'وصلت القافلة';

  @override
  String get cinemaCaravanEndSubtitle =>
      'واستقبلت الواحة نوّارة وزاجل بالطبول والتمر.';

  @override
  String get cinemaCaravanLostSubtitle =>
      'ضاعت القافلة في الرمل هالمرة. الواحة بتستنى محاولة ثانية.';

  @override
  String get cinemaCaravanLifeBack => 'استعدت بكرة!';

  @override
  String get cinemaCaravanLegDone => 'اكتملت المرحلة!';

  @override
  String get cinemaCaravanPouchFull => 'الجراب ممتلئ!';

  @override
  String get cinemaCaravanBossHit => 'إصابة!';

  @override
  String get cinemaCaravanDodged => 'نجوت!';

  @override
  String get cinemaCaravanDatePouch => 'جراب التمر';

  @override
  String get dataCentreTitle => 'بياناتك';

  @override
  String get dataHeroTitle => 'بياناتك تبقى معك';

  @override
  String get dataHeroBody =>
      'يحفظ مَدار كل شيء مشفّرًا على هذا الهاتف، ولا يرفع شيئًا إلى أي مكان. لا يغادر ملفٌّ التطبيقَ إلا حين تشاركه أو تحفظه بنفسك.';

  @override
  String get dataStatRecords => 'السجلات';

  @override
  String get dataStatLastBackup => 'آخر نسخة احتياطية';

  @override
  String get dataLastBackupNever => 'لم تُنشأ بعد';

  @override
  String get dataLastBackupToday => 'اليوم';

  @override
  String dataLastBackupDaysAgo(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'قبل $days يوم',
      many: 'قبل $days يومًا',
      few: 'قبل $days أيام',
      two: 'قبل يومين',
      one: 'أمس',
    );
    return '$_temp0';
  }

  @override
  String get dataBackupSection => 'النسخ الاحتياطي';

  @override
  String get dataBackupSectionHint =>
      'ملف واحد مشفّر لنقل بياناتك أو حفظها بأمان';

  @override
  String get dataBackupCreateTitle => 'نسخة احتياطية مشفّرة';

  @override
  String get dataBackupCreateBody =>
      'ملف واحد يُقفَل بعبارة مرور لا يعرفها أحد غيرك. احتفظ به في مكان آمن لتنقل بياناتك إلى هاتف جديد.';

  @override
  String get dataBackupCreateAction => 'إنشاء نسخة احتياطية';

  @override
  String get dataRestoreTitle => 'الاستعادة من نسخة احتياطية';

  @override
  String get dataRestoreBody =>
      'تستبدل كل ما في مَدار بمحتوى ملف النسخة. نحفظ أولًا نسخة أمان من بياناتك الحالية على الهاتف.';

  @override
  String get dataRestoreAction => 'اختيار ملف النسخة';

  @override
  String dataSafetyCopiesLine(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نسخة أمان على الهاتف',
      many: '$count نسخة أمان على الهاتف',
      few: '$count نسخ أمان على الهاتف',
      two: 'نسختا أمان على الهاتف',
      one: 'نسخة أمان واحدة على الهاتف',
    );
    return '$_temp0 · آخرها $date';
  }

  @override
  String get dataExportSection => 'التصدير';

  @override
  String get dataExportSectionHint => 'نسخ مقروءة لبياناتك – غير مشفّرة';

  @override
  String get dataExportSummaryTitle => 'ملخّص جاهز للذكاء الاصطناعي';

  @override
  String get dataExportSummaryBody =>
      'نظرة موجزة بصيغة Markdown تراجعها قسمًا قسمًا قبل مشاركتها.';

  @override
  String get dataExportCsvTitle => 'جداول (CSV)';

  @override
  String get dataExportCsvBody =>
      'التحاليل والمعاملات والألم والمزاج، لتفتحها في برامج الجداول.';

  @override
  String get dataExportJsonTitle => 'كل البيانات (JSON)';

  @override
  String get dataExportJsonBody =>
      'كل السجلات في ملف واحد، لأرشيفك الخاص أو لتطبيقات أخرى.';

  @override
  String get dataExportPlainWarning =>
      'ملفات التصدير غير مشفّرة: من يحصل عليها يستطيع قراءتها. شاركها مع من تثق به فقط.';

  @override
  String get dataImportSection => 'الاستيراد';

  @override
  String get dataImportTitle => 'الاستيراد من نموذج مَدار الأول';

  @override
  String get dataImportBody =>
      'أدخل البيانات التي صدّرتها من النسخة الأولى من مَدار.';

  @override
  String get dataFooter =>
      'لا يرفع مَدار بياناتك إلى أي خادم. أنت وحدك تقرّر أين تذهب ملفاتك.';

  @override
  String get dataAreaOther => 'الإعدادات والسجلّ';

  @override
  String get dataShareAction => 'مشاركة';

  @override
  String get dataSaveAction => 'حفظ في…';

  @override
  String get dataCopyAction => 'نسخ';

  @override
  String get dataDoneAction => 'تم';

  @override
  String get dataCancelAction => 'إلغاء';

  @override
  String get dataTryAgainAction => 'حاول مجددًا';

  @override
  String get dataFileReadyTitle => 'ملفّك جاهز';

  @override
  String get dataFileReadySubtitle => 'اختر أين يذهب – لا شيء يُرسَل تلقائيًا';

  @override
  String get dataFileEncryptedNote =>
      'مشفّر بعبارة المرور. لا يُفتح إلا بها – احتفظ بها بعيدًا عن الملف.';

  @override
  String get dataFilePlainNote =>
      'غير مشفّر: من يحصل على هذا الملف يستطيع قراءته.';

  @override
  String get dataFileShared => 'أُرسل إلى قائمة المشاركة.';

  @override
  String get dataFileSaved => 'حُفظ في المكان الذي اخترته.';

  @override
  String get dataFileSendFailed => 'تعذّر ذلك. لم يُرسَل شيء – حاول مجددًا.';

  @override
  String get dataExportFailed => 'تعذّر تجهيز الملف. بياناتك لم تتغيّر.';

  @override
  String dataRecordsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count سجل',
      many: '$count سجلًّا',
      few: '$count سجلات',
      two: 'سجلّان',
      one: 'سجل واحد',
      zero: 'لا سجلات',
    );
    return '$_temp0';
  }

  @override
  String dataSizeBytes(String size) {
    return '$size بايت';
  }

  @override
  String dataSizeKb(String size) {
    return '$size ك.ب';
  }

  @override
  String dataSizeMb(String size) {
    return '$size م.ب';
  }

  @override
  String get dataBackupSheetTitle => 'نسخة احتياطية مشفّرة';

  @override
  String get dataBackupSheetSubtitle =>
      'تشفير AES-GCM · تُشتقّ المفاتيح بـArgon2id على هاتفك';

  @override
  String get dataBackupSheetBody =>
      'اختر عبارة مرور تقفل ملف النسخة. لا يحفظها مَدار ولا يستطيع استرجاعها، فاكتبها في مكان تثق به.';

  @override
  String get dataPassphraseLabel => 'عبارة المرور';

  @override
  String get dataPassphraseConfirmLabel => 'أعد كتابة عبارة المرور';

  @override
  String get dataPassphraseMismatch => 'العبارتان غير متطابقتين.';

  @override
  String get dataPassphraseShow => 'إظهار عبارة المرور';

  @override
  String get dataPassphraseHide => 'إخفاء عبارة المرور';

  @override
  String get dataPassphraseNeverStored =>
      'لا تُحفظ عبارة المرور في أي مكان. بدونها لا يمكن فتح النسخة – ولا حتى بواسطتنا.';

  @override
  String get dataStrengthLabel => 'القوة';

  @override
  String get dataStrengthEmpty => '—';

  @override
  String get dataStrengthVeryWeak => 'ضعيفة جدًا';

  @override
  String get dataStrengthWeak => 'ضعيفة';

  @override
  String get dataStrengthFair => 'مقبولة';

  @override
  String get dataStrengthStrong => 'قوية';

  @override
  String get dataStrengthVeryStrong => 'قوية جدًا';

  @override
  String dataStrengthHintShort(String min) {
    return 'استخدم $min أحرف على الأقل – جملة قصيرة تفي بالغرض.';
  }

  @override
  String get dataStrengthHintCommon => 'هذه عبارة شائعة يسهل تخمينها.';

  @override
  String get dataStrengthHintPattern =>
      'تجنّب التكرار والتسلسلات مثل abcd أو aaaa.';

  @override
  String get dataStrengthHintDigits => 'الأرقام وحدها سهلة التخمين؛ أضف كلمات.';

  @override
  String get dataStrengthHintWords =>
      'جيدة. كلمة أو كلمتان إضافيتان تجعلانها أقوى بكثير.';

  @override
  String get dataBackupWorking => 'نقفل بياناتك…';

  @override
  String get dataBackupWorkingHint =>
      'يستغرق هذا بضع ثوانٍ عن قصد، ليصعب تخمين عبارة المرور.';

  @override
  String get dataBackupReadyTitle => 'النسخة الاحتياطية جاهزة';

  @override
  String get dataBackupReadySubtitle => 'شاركها أو احفظها في مكان آمن';

  @override
  String get dataBackupReadyHint =>
      'احفظ الملف وعبارة المرور في مكانين مختلفين. ستحتاج إلى كليهما للاستعادة.';

  @override
  String get dataBackupShareSubject => 'نسخة مَدار الاحتياطية';

  @override
  String get dataBackupFailed =>
      'تعذّر إنشاء النسخة. بياناتك كما هي – حاول مجددًا.';

  @override
  String dataBackupMadeOn(String date) {
    return 'أُنشئت في $date';
  }

  @override
  String get dataCsvSheetTitle => 'تصدير جدول';

  @override
  String get dataCsvSheetSubtitle => 'ملف CSV يُفتح في برامج الجداول';

  @override
  String get dataCsvWhat => 'ماذا';

  @override
  String get dataCsvWhen => 'الفترة';

  @override
  String get dataCsvLabs => 'التحاليل';

  @override
  String get dataCsvTransactions => 'المعاملات';

  @override
  String get dataCsvPain => 'الألم';

  @override
  String get dataCsvMood => 'المزاج';

  @override
  String dataRangeDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days يوم',
      many: '$days يومًا',
      few: '$days أيام',
      two: 'يومان',
      one: 'يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String dataRangeMonths(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months شهر',
      many: '$months شهرًا',
      few: '$months أشهر',
      two: 'شهران',
      one: 'شهر واحد',
    );
    return '$_temp0';
  }

  @override
  String get dataRangeAll => 'الكل';

  @override
  String get dataRangeCustom => 'مخصّصة…';

  @override
  String get dataRangeAllTime => 'كل السجلات منذ البداية';

  @override
  String dataRangeFromTo(String from, String to) {
    return 'من $from إلى $to';
  }

  @override
  String dataCsvFormatNote(String example) {
    return 'التواريخ بصيغة $example والأرقام بنقطة عشرية، فيفتحها أي برنامج جداول كما هي.';
  }

  @override
  String get dataCsvCreate => 'إنشاء الملف';

  @override
  String dataCsvCreateRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'إنشاء الملف ($count صف)',
      many: 'إنشاء الملف ($count صفًّا)',
      few: 'إنشاء الملف ($count صفوف)',
      two: 'إنشاء الملف (صفّان)',
      one: 'إنشاء الملف (صف واحد)',
      zero: 'لا صفوف في هذه الفترة',
    );
    return '$_temp0';
  }

  @override
  String get dataCsvDate => 'التاريخ';

  @override
  String get dataCsvTime => 'الوقت';

  @override
  String get dataCsvTest => 'التحليل';

  @override
  String get dataCsvCategory => 'الفئة';

  @override
  String get dataCsvValue => 'القيمة';

  @override
  String get dataCsvTextResult => 'نتيجة نصية';

  @override
  String get dataCsvUnit => 'الوحدة';

  @override
  String get dataCsvRangeLow => 'الحد الأدنى';

  @override
  String get dataCsvRangeHigh => 'الحد الأعلى';

  @override
  String get dataCsvFlag => 'العلامة';

  @override
  String get dataCsvNote => 'ملاحظة';

  @override
  String get dataCsvNotes => 'ملاحظات';

  @override
  String get dataCsvKind => 'النوع';

  @override
  String get dataCsvWallet => 'المحفظة';

  @override
  String get dataCsvCurrency => 'العملة';

  @override
  String get dataCsvAmount => 'المبلغ';

  @override
  String get dataCsvAmountBase => 'المبلغ بالعملة الأساسية';

  @override
  String get dataCsvBaseCurrency => 'العملة الأساسية';

  @override
  String get dataCsvBudgetItem => 'بند الميزانية';

  @override
  String get dataCsvToWallet => 'إلى المحفظة';

  @override
  String get dataCsvToAmount => 'المبلغ المستلم';

  @override
  String get dataCsvToCurrency => 'عملة الاستلام';

  @override
  String get dataCsvTags => 'الوسوم';

  @override
  String dataCsvPainScore(String min, String max) {
    return 'شدة الألم ($min-$max)';
  }

  @override
  String get dataCsvLocations => 'المواضع';

  @override
  String get dataCsvTriggers => 'المحفّزات';

  @override
  String get dataCsvBodyPoints => 'نقاط خريطة الجسم';

  @override
  String dataCsvMoodScore(String min, String max) {
    return 'المزاج ($min-$max)';
  }

  @override
  String dataCsvStress(String min, String max) {
    return 'التوتر ($min-$max)';
  }

  @override
  String dataCsvAnxiety(String min, String max) {
    return 'القلق ($min-$max)';
  }

  @override
  String dataCsvEnergy(String min, String max) {
    return 'الطاقة ($min-$max)';
  }

  @override
  String get dataCsvSleepHours => 'ساعات النوم';

  @override
  String get dataCsvCaffeine => 'أكواب الكافيين';

  @override
  String get dataCsvFactors => 'العوامل';

  @override
  String get dataFlagLow => 'منخفض';

  @override
  String get dataFlagBorderlineLow => 'على الحد الأدنى';

  @override
  String get dataFlagInRange => 'ضمن المعدل';

  @override
  String get dataFlagBorderlineHigh => 'على الحد الأعلى';

  @override
  String get dataFlagHigh => 'مرتفع';

  @override
  String get dataTxExpense => 'مصروف';

  @override
  String get dataTxIncome => 'دخل';

  @override
  String get dataTxTransfer => 'تحويل';

  @override
  String get dataTxAdjustment => 'تسوية';

  @override
  String get dataSummarySubtitle =>
      'يُعدّ على هاتفك · راجع كل قسم قبل المشاركة';

  @override
  String get dataSummaryIntro =>
      'لا يُرسَل شيء إلى أي مكان حتى تختار. ما تراه في المعاينة أدناه هو بالضبط ما سيخرج، ولا تُضمَّن الملاحظات أو أرقام الهواتف أو أرقام الوثائق والحسابات.';

  @override
  String get dataSummaryPreparing => 'نجهّز الملخّص على هاتفك…';

  @override
  String get dataSummarySections => 'الأقسام المضمَّنة';

  @override
  String dataSummarySectionsOf(String selected, String total) {
    return '$selected من $total أقسام';
  }

  @override
  String dataSummaryTokens(String count) {
    return '≈ $count رمز';
  }

  @override
  String get dataSummaryNoData => 'لا بيانات بعد';

  @override
  String get dataSummaryProfileHint => 'اختياري';

  @override
  String get dataSummaryPreviewTitle => 'ما سيُشارَك بالضبط';

  @override
  String get dataSummaryCopied => 'نُسخ الملخّص إلى الحافظة.';

  @override
  String get dataSummaryUse => 'استخدام هذا الملخّص';

  @override
  String get dataProfileChoose => 'اختر ما يُذكر عنك:';

  @override
  String get dataProfileAboutHint =>
      'مثلًا: العمر أو ما يهمّك أن يعرفه المساعد';

  @override
  String get dataRestoreFlowTitle => 'الاستعادة';

  @override
  String get dataRestoreChooseTitle => 'استعادة بياناتك';

  @override
  String dataRestoreChooseBody(String ext) {
    return 'اختر ملف نسخة ينتهي بـ $ext. سترى ما فيه قبل أن يتغيّر أي شيء.';
  }

  @override
  String get dataRestorePickFile => 'اختيار ملف النسخة';

  @override
  String get dataRestoreNothingChanges =>
      'لن يتغيّر شيء في بياناتك الحالية حتى تؤكّد الاستبدال في الخطوة الأخيرة.';

  @override
  String get dataSafetyCopiesTitle => 'نسخ الأمان على هذا الهاتف';

  @override
  String get dataSafetyCopiesHint =>
      'تُنشأ تلقائيًا قبل كل استعادة، وتُفتح بعبارة المرور التي استُخدمت حينها.';

  @override
  String get dataRestoreUnlockBody =>
      'اكتب عبارة المرور التي أقفلت بها هذه النسخة.';

  @override
  String get dataRestoreUnlockAction => 'فتح النسخة';

  @override
  String get dataRestoreOtherFile => 'اختيار ملف آخر';

  @override
  String get dataRestoreOpening => 'نتحقق من النسخة…';

  @override
  String get dataRestoreOpeningHint =>
      'نتأكد أن الملف سليم ولم يُعدَّل، ثم نفكّ تشفيره على هاتفك.';

  @override
  String get dataRestorePreviewTitle => 'النسخة سليمة';

  @override
  String get dataRestoreInBackup => 'في النسخة';

  @override
  String get dataRestoreOnPhone => 'على الهاتف الآن';

  @override
  String get dataRestoreWhatsInside => 'ما في هذه النسخة';

  @override
  String get dataRestoreReplaceWarning =>
      'ستحلّ هذه النسخة محلّ كل البيانات الموجودة في مَدار الآن. قبل ذلك نحفظ بياناتك الحالية نسخةَ أمان على هذا الهاتف، تُفتح بعبارة المرور نفسها.';

  @override
  String get dataRestoreUnderstand => 'فهمت أن بياناتي الحالية ستُستبدل';

  @override
  String get dataRestoreConfirmAction => 'استبدال بياناتي';

  @override
  String get dataRestoreSavingSafety => 'نحفظ نسخة أمان من بياناتك الحالية…';

  @override
  String get dataRestoreRestoring => 'نستعيد بياناتك…';

  @override
  String get dataRestoreKeepOpen => 'أبقِ التطبيق مفتوحًا لحظات.';

  @override
  String get dataRestoreDoneTitle => 'تمت الاستعادة';

  @override
  String dataRestoreDoneBody(String count) {
    return 'عادت سجلاتك ($count) إلى مَدار.';
  }

  @override
  String get dataRestoreSafetyKept =>
      'نسخة أمان من بياناتك السابقة محفوظة على هذا الهاتف، وتُفتح بعبارة المرور نفسها.';

  @override
  String get dataSafetyCopySave => 'حفظ نسخة الأمان في مكان آخر';

  @override
  String get dataSafetyCopyTitle => 'نسخة الأمان';

  @override
  String get dataNothingChanged => 'لم يتغيّر شيء في بياناتك.';

  @override
  String get dataErrWrongPassphrase =>
      'عبارة المرور هذه لا تفتح النسخة. تحقّق من الأحرف وحاول مجددًا.';

  @override
  String get dataErrNotBackupTitle => 'هذا ليس ملف نسخة من مَدار';

  @override
  String dataErrNotBackupBody(String ext) {
    return 'اختر ملفًا ينتهي بـ $ext أنشأته من «إنشاء نسخة احتياطية».';
  }

  @override
  String get dataErrNewerTitle => 'أُنشئت بإصدار أحدث من مَدار';

  @override
  String get dataErrNewerBody => 'حدّث مَدار على هذا الهاتف ثم حاول مجددًا.';

  @override
  String get dataErrTruncatedTitle => 'الملف غير مكتمل';

  @override
  String get dataErrTruncatedBody =>
      'ربما لم يكتمل نسخه أو تنزيله. انسخه مرة أخرى ثم حاول.';

  @override
  String get dataErrCorruptedTitle => 'الملف تالف';

  @override
  String get dataErrCorruptedBody =>
      'تغيّر الملف أو تلف بعد إنشائه، فلا يمكن الوثوق به.';

  @override
  String get dataErrUnreadableTitle => 'تعذّرت قراءة الملف';

  @override
  String get dataErrUnreadableBody =>
      'جرّب ملفًا آخر أو انسخه إلى الهاتف أولًا.';

  @override
  String get dataErrSafetyTitle => 'تعذّر حفظ نسخة الأمان';

  @override
  String get dataErrSafetyBody =>
      'لذلك لم نستبدل بياناتك. وفّر بعض المساحة ثم حاول مجددًا.';

  @override
  String get dataErrRejectedTitle => 'تعذّرت استعادة هذه النسخة';

  @override
  String get dataErrRejectedBody => 'لم تجتز بياناتها فحوص السلامة.';

  @override
  String dataSumHeading(String date) {
    return 'ملخّص مَدار — $date';
  }

  @override
  String get dataSumPreamble =>
      'بيانات متابعة شخصية من تطبيق مَدار، أُعدّت على هاتف المستخدم نفسه. التواريخ بصيغة سنة-شهر-يوم والكسور العشرية بنقطة. لا تُضمَّن الملاحظات ولا أرقام الهواتف ولا أرقام الوثائق أو الحسابات.';

  @override
  String get dataSumNoData => 'لا بيانات بعد.';

  @override
  String get dataSumListSep => '، ';

  @override
  String dataSumLastDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'آخر $days يوم',
      many: 'آخر $days يومًا',
      few: 'آخر $days أيام',
      two: 'آخر يومين',
      one: 'اليوم',
    );
    return '$_temp0';
  }

  @override
  String dataSumPreviousDays(String days) {
    return 'الأيام الـ$days السابقة';
  }

  @override
  String dataSumMore(String count) {
    return 'غير معروضة: $count';
  }

  @override
  String get dataSumProfile => 'نبذة شخصية';

  @override
  String get dataSumFaith => 'الإيمان';

  @override
  String get dataSumHealth => 'الصحة';

  @override
  String get dataSumMoney => 'المال';

  @override
  String get dataSumFamily => 'العائلة';

  @override
  String get dataSumWork => 'العمل';

  @override
  String get dataSumGrowth => 'النمو';

  @override
  String get dataSumBody => 'الجسد';

  @override
  String get dataSumTravel => 'السفر';

  @override
  String get dataSumCustom => 'متتبّعات مخصّصة';

  @override
  String get dataSumCity => 'المدينة';

  @override
  String get dataSumTimeZone => 'المنطقة الزمنية';

  @override
  String get dataSumBaseCurrency => 'العملة الأساسية';

  @override
  String get dataSumLanguage => 'لغة التطبيق';

  @override
  String get dataSumLanguageName => 'العربية';

  @override
  String get dataSumAboutMe => 'عنّي';

  @override
  String get dataSumPrayersTitle => 'الصلاة';

  @override
  String dataSumObligatory(String window) {
    return '$window (الفرائض)';
  }

  @override
  String dataSumLogged(String logged, String expected) {
    return 'المسجّل: $logged/$expected';
  }

  @override
  String dataSumOnTime(String count) {
    return 'في وقتها: $count';
  }

  @override
  String dataSumLate(String count) {
    return 'متأخرة: $count';
  }

  @override
  String dataSumMadeUp(String count) {
    return 'قضاء: $count';
  }

  @override
  String dataSumMissed(String count) {
    return 'فائتة: $count';
  }

  @override
  String dataSumInCongregation(String count) {
    return 'جماعة: $count';
  }

  @override
  String dataSumVoluntary(String window) {
    return '$window (النوافل)';
  }

  @override
  String get dataSumQuranTitle => 'القرآن والورد';

  @override
  String dataSumSessions(String count) {
    return 'الجلسات: $count';
  }

  @override
  String dataSumPages(String count) {
    return 'الصفحات: $count';
  }

  @override
  String dataSumMinutes(String count) {
    return '$count د';
  }

  @override
  String dataSumLastSession(String date) {
    return 'آخر جلسة: $date';
  }

  @override
  String dataSumWird(String name) {
    return 'الورد «$name»';
  }

  @override
  String dataSumPerDay(String amount, String unit) {
    return '$unit يوميًا: $amount';
  }

  @override
  String get dataSumUnitPages => 'الصفحات';

  @override
  String get dataSumUnitJuz => 'الأجزاء';

  @override
  String get dataSumUnitHizb => 'الأحزاب';

  @override
  String get dataSumUnitAyat => 'الآيات';

  @override
  String dataSumSince(String date) {
    return 'منذ $date';
  }

  @override
  String dataSumBy(String date) {
    return 'حتى $date';
  }

  @override
  String get dataSumHifzTitle => 'الحفظ';

  @override
  String dataSumItems(String count) {
    return 'المحفوظات: $count';
  }

  @override
  String dataSumNew(String count) {
    return 'جديدة: $count';
  }

  @override
  String dataSumDueToday(String count) {
    return 'مستحقة للمراجعة اليوم: $count';
  }

  @override
  String dataSumReviews(String count) {
    return 'المراجعات: $count';
  }

  @override
  String dataSumAvgGrade(String value, String max) {
    return 'متوسط التقييم: $value/$max';
  }

  @override
  String get dataSumAlertsTitle => 'تنبيهات دائمة';

  @override
  String get dataSumSeverityCritical => 'حرج';

  @override
  String get dataSumSeverityWarning => 'تنبيه';

  @override
  String get dataSumSeverityInfo => 'ملاحظة';

  @override
  String get dataSumConditionsTitle => 'الحالات الصحية';

  @override
  String get dataSumMedsTitle => 'الأدوية الحالية';

  @override
  String get dataSumKindSupplement => 'مكمّل';

  @override
  String get dataSumKindInjection => 'حقنة';

  @override
  String get dataSumWithEmptyStomach => 'على معدة فارغة';

  @override
  String get dataSumWithBreakfast => 'مع الفطور';

  @override
  String get dataSumWithLunch => 'مع الغداء';

  @override
  String get dataSumWithDinner => 'مع العشاء';

  @override
  String get dataSumWithBedtime => 'قبل النوم';

  @override
  String get dataSumWithCourse => 'حسب خطة العلاج';

  @override
  String get dataSumLabsTitle => 'أحدث التحاليل';

  @override
  String dataSumLabsWindow(String months) {
    return 'آخر نتيجة لكل تحليل خلال آخر $months شهرًا؛ العلامة مقارنةً بالمعدل المحفوظ في التطبيق.';
  }

  @override
  String get dataSumColTest => 'التحليل';

  @override
  String get dataSumColDate => 'التاريخ';

  @override
  String get dataSumColResult => 'النتيجة';

  @override
  String get dataSumColRange => 'المعدل';

  @override
  String get dataSumColFlag => 'العلامة';

  @override
  String get dataSumColPrevious => 'السابقة';

  @override
  String get dataSumPainTitle => 'الألم (متابعة)';

  @override
  String dataSumEntries(String count) {
    return 'الإدخالات: $count';
  }

  @override
  String dataSumAverageOf(String value, String max) {
    return 'المتوسط: $value/$max';
  }

  @override
  String dataSumHighest(String value, String max) {
    return 'الأعلى: $value/$max';
  }

  @override
  String get dataSumTopPlaces => 'أكثر المواضع تسجيلًا';

  @override
  String get dataSumTopTriggers => 'أكثر المحفّزات تسجيلًا';

  @override
  String get dataSumMoodTitle => 'المزاج (متابعة)';

  @override
  String dataSumMoodAvg(String value, String max) {
    return 'المزاج: $value/$max';
  }

  @override
  String dataSumStressAvg(String value, String max) {
    return 'التوتر: $value/$max';
  }

  @override
  String dataSumAnxietyAvg(String value, String max) {
    return 'القلق: $value/$max';
  }

  @override
  String dataSumEnergyAvg(String value, String max) {
    return 'الطاقة: $value/$max';
  }

  @override
  String dataSumSleepAvg(String value) {
    return 'النوم: $value س';
  }

  @override
  String dataSumCaffeineAvg(String value) {
    return 'الكافيين: $value كوب';
  }

  @override
  String get dataSumTopFactors => 'العوامل الأكثر تكرارًا';

  @override
  String get dataSumWalletsTitle => 'المحافظ';

  @override
  String dataSumConvertedTo(String code) {
    return 'محوّلة إلى $code بأسعار الصرف المحفوظة في التطبيق.';
  }

  @override
  String get dataSumColWallet => 'المحفظة';

  @override
  String get dataSumColBalance => 'الرصيد';

  @override
  String dataSumColInBase(String code) {
    return 'بـ$code';
  }

  @override
  String dataSumTotal(String amount) {
    return 'الإجمالي: $amount';
  }

  @override
  String dataSumBudgetTitle(String month) {
    return 'الميزانية — $month';
  }

  @override
  String dataSumPlanned(String amount) {
    return 'المخطط: $amount';
  }

  @override
  String dataSumSpent(String amount) {
    return 'المصروف: $amount';
  }

  @override
  String dataSumRemaining(String amount) {
    return 'المتبقي: $amount';
  }

  @override
  String get dataSumOverPlan => 'تجاوز الخطة';

  @override
  String dataSumUnassigned(String amount) {
    return 'مصروف بلا بند: $amount';
  }

  @override
  String dataSumDueTitle(String days) {
    return 'المستحق خلال الأيام الـ$days القادمة';
  }

  @override
  String dataSumDueOn(String date) {
    return 'يستحق $date';
  }

  @override
  String dataSumOverdueSince(String date) {
    return 'متأخر منذ $date';
  }

  @override
  String get dataSumDebtsTitle => 'الديون';

  @override
  String dataSumIOwe(String person, String left, String total) {
    return 'عليّ لـ$person: المتبقي $left من $total';
  }

  @override
  String dataSumOwedToMe(String person, String left, String total) {
    return 'لي عند $person: المتبقي $left من $total';
  }

  @override
  String get dataSumJarsTitle => 'حصّالات الادخار';

  @override
  String dataSumJar(String name, String saved, String target, String percent) {
    return '$name: $saved من $target ($percent%)';
  }

  @override
  String dataSumEvery(String days) {
    return 'الإيقاع (أيام): $days';
  }

  @override
  String dataSumLastContact(String days) {
    return 'أيام منذ آخر تواصل: $days';
  }

  @override
  String get dataSumNeverContacted => 'لم يُسجَّل تواصل بعد';

  @override
  String dataSumOverdueBy(String days) {
    return 'متأخر (أيام): $days';
  }

  @override
  String get dataSumDueTodayStatus => 'مستحق اليوم';

  @override
  String dataSumDueIn(String days) {
    return 'يستحق بعد (أيام): $days';
  }

  @override
  String dataSumNoRhythm(int count) {
    return 'آخرون بلا إيقاع تواصل: $count';
  }

  @override
  String dataSumPeopleNoRhythm(int count) {
    return 'أشخاص بلا إيقاع تواصل: $count';
  }

  @override
  String dataSumTop3Title(String count) {
    return 'أهم $count';
  }

  @override
  String dataSumOnBoard(String board) {
    return 'اللوحة: $board';
  }

  @override
  String get dataSumBoardsTitle => 'اللوحات';

  @override
  String get dataSumOther => 'أخرى';

  @override
  String get dataSumProjectsTitle => 'المشاريع';

  @override
  String get dataSumStatusActive => 'نشط';

  @override
  String get dataSumStatusPaused => 'متوقف مؤقتًا';

  @override
  String dataSumDoneOf(String done, String total) {
    return 'المنجز: $done/$total';
  }

  @override
  String dataSumDeadline(String date) {
    return 'الموعد النهائي: $date';
  }

  @override
  String dataSumProgress(String current, String target, String unit) {
    return '$current من $target $unit';
  }

  @override
  String dataSumRecentGain(String amount, String window) {
    return '$window: $amount';
  }

  @override
  String get dataSumExercisePlanTitle => 'خطة التمارين';

  @override
  String get dataSumWeekdays =>
      'الإثنين,الثلاثاء,الأربعاء,الخميس,الجمعة,السبت,الأحد';

  @override
  String dataSumSets(String count) {
    return 'المجموعات: $count';
  }

  @override
  String dataSumKg(String value) {
    return '$value كغ';
  }

  @override
  String dataSumWorkouts(String count) {
    return 'التمارين المنجزة: $count';
  }

  @override
  String dataSumFasting(String count, String hours) {
    return 'الصيام: $count · المتوسط: $hours س';
  }

  @override
  String dataSumTargetHours(String hours) {
    return 'الهدف: $hours س';
  }

  @override
  String dataSumWater(String days, String ml) {
    return 'الماء خلال آخر $days أيام: $ml مل يوميًا في المتوسط';
  }

  @override
  String dataSumTargetMl(String ml) {
    return 'الهدف: $ml مل';
  }

  @override
  String get dataSumAvoidTitle => 'تجنّب';

  @override
  String get dataSumTripsTitle => 'الرحلات القادمة';

  @override
  String get dataSumTripPlanned => 'مخطط لها';

  @override
  String get dataSumTripUnderWay => 'جارية الآن';

  @override
  String get dataSumDocumentsTitle => 'الوثائق (لا تُضمَّن أرقامها أبدًا)';

  @override
  String dataSumExpiresIn(String date, String days) {
    return 'تنتهي $date (الأيام المتبقية: $days)';
  }

  @override
  String dataSumExpired(String date) {
    return 'انتهت $date';
  }

  @override
  String get dataSumNoExpiry => 'بلا تاريخ انتهاء';

  @override
  String get dataSumModuleTracker => 'متتبّع';

  @override
  String get dataSumModuleList => 'قائمة';

  @override
  String dataSumOpen(String count) {
    return 'مفتوحة: $count';
  }

  @override
  String dataSumDone(String count) {
    return 'منجزة: $count';
  }

  @override
  String dataSumInWindow(String count, String window) {
    return '$window: $count';
  }

  @override
  String dataSumLastOn(String date) {
    return 'الأخير: $date';
  }

  @override
  String dataSumAverage(String value) {
    return 'المتوسط: $value';
  }

  @override
  String dataSumMin(String value) {
    return 'الأدنى: $value';
  }

  @override
  String dataSumMax(String value) {
    return 'الأعلى: $value';
  }

  @override
  String dataSumSum(String value) {
    return 'المجموع: $value';
  }

  @override
  String dataSumTicked(String count, String total) {
    return 'مؤشَّر عليها: $count/$total';
  }

  @override
  String get searchTitle => 'البحث';

  @override
  String get searchFieldHint => 'ابحث في المهام والملاحظات والأشخاص والآيات…';

  @override
  String get searchLauncherHint => 'ابحث في مَدار';

  @override
  String get searchLauncherTooltip => 'البحث في كل شيء';

  @override
  String get searchClear => 'مسح النص';

  @override
  String get searchRecentTitle => 'عمليات البحث الأخيرة';

  @override
  String get searchRecentClear => 'مسح السجل';

  @override
  String searchRecentRemove(String query) {
    return 'حذف «$query» من السجل';
  }

  @override
  String get searchIntroTitle => 'ابحث في مدارك كله';

  @override
  String get searchIntroBody =>
      'المهام والملاحظات والأشخاص والمال والآيات في مكان واحد. يجري البحث على هاتفك فقط.';

  @override
  String get searchPreparing => 'نُجهّز فهرس البحث…';

  @override
  String searchNoResultsTitle(String query) {
    return 'لا نتائج لـ «$query»';
  }

  @override
  String get searchNoResultsBody => 'جرّب كلمات أقل أو تهجئة أخرى.';

  @override
  String get searchNoResultsFiltered => 'لا شيء هنا ضمن التصفية الحالية.';

  @override
  String get searchClearFilters => 'إزالة التصفية';

  @override
  String get searchAll => 'الكل';

  @override
  String searchResultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نتيجة',
      many: '$count نتيجة',
      few: '$count نتائج',
      two: 'نتيجتان',
      one: 'نتيجة واحدة',
      zero: 'لا نتائج',
    );
    return '$_temp0';
  }

  @override
  String searchShowAll(String count) {
    return 'عرض الكل ($count)';
  }

  @override
  String searchGroupSemantics(String module, String count) {
    return '$module، $count';
  }

  @override
  String get searchPartial => 'لم نجد كل الكلمات معًا؛ هذه أقرب النتائج.';

  @override
  String get searchCannotOpen => 'لا يمكن فتح هذه النتيجة من هنا بعد.';

  @override
  String get searchToday => 'اليوم';

  @override
  String get searchYesterday => 'أمس';

  @override
  String get searchTomorrow => 'غدًا';

  @override
  String get searchFilterPlanets => 'التصفية حسب الكوكب';

  @override
  String get searchFilterModules => 'التصفية حسب القسم';

  @override
  String get searchPlanetCustom => 'وحدات مخصصة';

  @override
  String get searchKeyboardHint => '↑ ↓ للتنقل، Enter للفتح، Esc للمسح';

  @override
  String get searchDone => 'منجزة';

  @override
  String get searchArchived => 'مؤرشفة';

  @override
  String get searchTxExpense => 'مصروف';

  @override
  String get searchTxIncome => 'دخل';

  @override
  String get searchTxTransfer => 'تحويل';

  @override
  String get searchTxAdjustment => 'تسوية';

  @override
  String get searchDebtIOwe => 'دين عليّ';

  @override
  String get searchDebtOwedToMe => 'دين لي';

  @override
  String get searchChannelCall => 'مكالمة';

  @override
  String get searchChannelVisit => 'زيارة';

  @override
  String get searchChannelMessage => 'رسالة';

  @override
  String get searchChannelOther => 'تواصل';

  @override
  String searchPainTitle(String score, String max) {
    return 'ألم $score/$max';
  }

  @override
  String get searchMoodTitle => 'المزاج';

  @override
  String get searchFastingTitle => 'صيام';

  @override
  String searchAyahPlace(String surah, String ayah) {
    return '$surah، الآية $ayah';
  }

  @override
  String searchAyahRange(String surah, String from, String to) {
    return '$surah $from–$to';
  }

  @override
  String searchSurahNumber(String number) {
    return 'سورة $number';
  }

  @override
  String get searchSourceTasks => 'المهام';

  @override
  String get searchSourcePrayerLogs => 'سجل الصلوات';

  @override
  String get searchSourceMedications => 'الأدوية';

  @override
  String get searchSourceMedCourses => 'الكورسات العلاجية';

  @override
  String get searchSourceMedDoses => 'ملاحظات الجرعات';

  @override
  String get searchSourceConditions => 'الحالات الصحية';

  @override
  String get searchSourceHealthAlerts => 'التنبيهات الصحية';

  @override
  String get searchSourceLabTests => 'التحاليل';

  @override
  String get searchSourceLabReadings => 'نتائج التحاليل';

  @override
  String get searchSourceAppointments => 'المواعيد';

  @override
  String get searchSourceDoctorQuestions => 'أسئلة الطبيب';

  @override
  String get searchSourcePain => 'سجل الألم';

  @override
  String get searchSourceMood => 'سجل المزاج';

  @override
  String get searchSourceHabits => 'العادات';

  @override
  String get searchSourceWorries => 'المخاوف';

  @override
  String get searchSourceWallets => 'المحافظ';

  @override
  String get searchSourceTransactions => 'المعاملات';

  @override
  String get searchSourceBudget => 'الميزانية';

  @override
  String get searchSourceJars => 'الحصّالات';

  @override
  String get searchSourceJarDeposits => 'إيداعات الحصّالات';

  @override
  String get searchSourceDebts => 'الديون';

  @override
  String get searchSourceDebtPayments => 'سداد الديون';

  @override
  String get searchSourceObligations => 'الالتزامات';

  @override
  String get searchSourcePeople => 'الأشخاص';

  @override
  String get searchSourceContactLogs => 'سجل التواصل';

  @override
  String get searchSourceProjects => 'المشاريع';

  @override
  String get searchSourceProjectItems => 'بنود المشاريع';

  @override
  String get searchSourceBoards => 'اللوحات';

  @override
  String get searchSourceCards => 'البطاقات';

  @override
  String get searchSourceTrips => 'الرحلات';

  @override
  String get searchSourceTripItems => 'أغراض الرحلات';

  @override
  String get searchSourcePackingTemplates => 'قوائم التجهيز';

  @override
  String get searchSourceTravelDocuments => 'وثائق السفر';

  @override
  String get searchSourceLearningGoals => 'أهداف التعلّم';

  @override
  String get searchSourceGoalLogs => 'سجل الأهداف';

  @override
  String get searchSourceExercises => 'التمارين';

  @override
  String get searchSourceWorkouts => 'سجل التمارين';

  @override
  String get searchSourceAvoidItems => 'قائمة التجنّب';

  @override
  String get searchSourceFasting => 'الصيام المتقطع';

  @override
  String get searchSourceCustomModules => 'الوحدات المخصصة';

  @override
  String get searchSourceCustomEntries => 'سجلات الوحدات';

  @override
  String get searchSourceQuranAyat => 'آيات القرآن';

  @override
  String get searchSourceQuranBookmarks => 'علامات المصحف';

  @override
  String get searchSourceWirdPlans => 'خطط الورد';

  @override
  String get searchSourceHifz => 'الحفظ';

  @override
  String get searchSourcePlanets => 'الكواكب';

  @override
  String get ncTitle => 'الإشعارات';

  @override
  String get ncTabUpcoming => 'القادمة';

  @override
  String get ncTabRecent => 'الأخيرة';

  @override
  String ncTabWithCount(String label, String count) {
    return '$label، $count';
  }

  @override
  String get ncOpenSettings => 'إعدادات الإشعارات';

  @override
  String get ncUpcomingEmptyTitle => 'لا شيء مجدول';

  @override
  String get ncUpcomingEmptyBody =>
      'ما تفعّله من أذان وتذكيرات سيصطفّ هنا للأيام السبعة القادمة.';

  @override
  String get ncRecentEmptyTitle => 'لا جديد';

  @override
  String get ncRecentEmptyBody =>
      'ما يصلك من إشعارات يبقى هنا أسبوعين، لتعود إليه متى شئت.';

  @override
  String get ncClearAll => 'مسح الكل';

  @override
  String ncClearedAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'مُسح $count إشعار',
      many: 'مُسح $count إشعارًا',
      few: 'مُسحت $count إشعارات',
      two: 'مُسح إشعاران',
      one: 'مُسح إشعار واحد',
    );
    return '$_temp0';
  }

  @override
  String get ncDismissed => 'أُزيل من القائمة';

  @override
  String get ncSkippedToast => 'لن يصل هذا التذكير';

  @override
  String get ncRestoredToast => 'سيصل في وقته';

  @override
  String ncShowMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'عرض $count أخرى',
      many: 'عرض $count أخرى',
      few: 'عرض $count أخرى',
      two: 'عرض اثنين آخرين',
      one: 'عرض واحد آخر',
    );
    return '$_temp0';
  }

  @override
  String get ncShowLess => 'عرض أقل';

  @override
  String ncSectionLabel(String group, String count) {
    return '$group، $count';
  }

  @override
  String get ncGroupPrayer => 'الصلاة والأذان';

  @override
  String get ncGroupAdhkar => 'الأذكار';

  @override
  String get ncGroupMedications => 'الأدوية';

  @override
  String get ncGroupHealth => 'الصحة';

  @override
  String get ncGroupMoney => 'المستحقات المالية';

  @override
  String get ncGroupFamily => 'العائلة';

  @override
  String get ncGroupTravel => 'وثائق السفر';

  @override
  String get ncGroupWird => 'الوِرد';

  @override
  String get ncGroupCustom => 'الوحدات المخصّصة';

  @override
  String get ncGroupOther => 'أخرى';

  @override
  String ncKindAdhan(String prayer) {
    return 'أذان $prayer';
  }

  @override
  String ncKindPreAdhan(String prayer, String minutes) {
    return '$prayer بعد $minutes';
  }

  @override
  String ncKindPreAdhanShort(String prayer) {
    return 'تذكير قبل $prayer';
  }

  @override
  String get ncKindSunrise => 'الشروق';

  @override
  String get ncKindAdhanTest => 'أذان تجريبي';

  @override
  String get ncKindAdhkarMorning => 'أذكار الصباح';

  @override
  String get ncKindAdhkarEvening => 'أذكار المساء';

  @override
  String get ncKindAdhkar => 'تذكير بالأذكار';

  @override
  String get ncKindDose => 'موعد جرعة';

  @override
  String get ncKindRefill => 'حان وقت إعادة التعبئة';

  @override
  String get ncKindMedsNotice => 'إجابة لم تُسجَّل';

  @override
  String get ncKindAppointment => 'موعد طبي';

  @override
  String get ncKindWorry => 'نافذة القلق';

  @override
  String get ncKindFastGoal => 'هدف الصيام';

  @override
  String get ncKindEatingClose => 'نافذة الأكل تُغلق';

  @override
  String get ncKindDebt => 'دَين مستحق';

  @override
  String get ncKindObligation => 'التزام مستحق';

  @override
  String get ncKindFamilyDigest => 'صلة الرحم';

  @override
  String get ncKindBirthdayEve => 'عيد ميلاد غدًا';

  @override
  String get ncKindBirthday => 'عيد ميلاد اليوم';

  @override
  String get ncKindDocAhead => 'وثيقة تقترب من الانتهاء';

  @override
  String get ncKindDocToday => 'وثيقة تنتهي اليوم';

  @override
  String get ncKindWird => 'الوِرد اليومي';

  @override
  String get ncKindCustom => 'تذكير وحدة';

  @override
  String get ncKindOther => 'إشعار';

  @override
  String ncAtTime(String time) {
    return 'الساعة $time';
  }

  @override
  String get ncStateMuted => 'مكتوم';

  @override
  String get ncStateSkipped => 'متخطّى';

  @override
  String ncStateSnoozedUntil(String time) {
    return 'مؤجّل حتى $time';
  }

  @override
  String get ncStateLive => 'ظاهر الآن';

  @override
  String get ncStateSilenced => 'وصل صامتًا';

  @override
  String get ncStateOpened => 'فُتح';

  @override
  String ncStateAnswered(String action) {
    return 'أُجيب: $action';
  }

  @override
  String get ncStateSnoozed => 'أُجّل';

  @override
  String get ncStateNew => 'جديد';

  @override
  String get ncTimeNow => 'الآن';

  @override
  String ncTimeIn(String duration) {
    return 'بعد $duration';
  }

  @override
  String ncTimeAgo(String duration) {
    return 'قبل $duration';
  }

  @override
  String ncTimeToday(String time) {
    return 'اليوم $time';
  }

  @override
  String ncTimeTomorrow(String time) {
    return 'غدًا $time';
  }

  @override
  String ncTimeYesterday(String time) {
    return 'أمس $time';
  }

  @override
  String ncTimeOnDay(String day, String time) {
    return '$day $time';
  }

  @override
  String get ncActionTaken => 'أخذتها';

  @override
  String get ncActionSnooze => 'أجِّل';

  @override
  String get ncActionSkip => 'تخطَّ';

  @override
  String get ncActionStop => 'إيقاف';

  @override
  String get ncActionOpen => 'افتح';

  @override
  String get ncActionSkipOne => 'لا ترسل هذا';

  @override
  String get ncActionRestore => 'أعِده';

  @override
  String ncActionSnoozeFor(String duration) {
    return 'أجِّل $duration';
  }

  @override
  String ncActionMuteGroup(String group) {
    return 'اكتم $group';
  }

  @override
  String get ncActionUnmute => 'ألغِ الكتم';

  @override
  String get ncActionSettings => 'إعدادات التذكير';

  @override
  String get ncActionDismiss => 'أزِل';

  @override
  String get ncActionFailed => 'تعذّر ذلك الآن، حاول مرة أخرى';

  @override
  String ncSnoozedToast(String time) {
    return 'أُجّل حتى $time';
  }

  @override
  String ncMutedToast(String group, String when) {
    return '$group مكتوم حتى $when';
  }

  @override
  String ncUnmutedToast(String group) {
    return 'عاد $group إلى وضعه';
  }

  @override
  String ncMuteTitle(String group) {
    return 'اكتم $group';
  }

  @override
  String get ncMuteSubtitle =>
      'لن يصدر شيء من هذه المجموعة خلال المدة، وستجده هنا في القائمة.';

  @override
  String ncMuteForHours(int count) {
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
  String get ncMuteUntilMorning => 'حتى صباح الغد';

  @override
  String get ncMuteWeek => 'أسبوعًا';

  @override
  String ncMutedUntil(String when) {
    return 'مكتوم حتى $when';
  }

  @override
  String get ncSettingsTitle => 'الإشعارات';

  @override
  String get ncSettingsSubtitle => 'ما يرسله كل جزء من مَدار، في مكان واحد';

  @override
  String get ncSettingsOn => 'مفعّلة';

  @override
  String get ncSettingsOff => 'متوقفة';

  @override
  String ncSettingsSome(String on, String total) {
    return '$on من $total مفعّلة';
  }

  @override
  String get ncSettingsPerItem => 'تُضبط لكل عنصر';

  @override
  String ncSettingsComing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count قادم',
      many: '$count قادمًا',
      few: '$count قادمة',
      two: 'اثنان قادمان',
      one: 'واحد قادم',
      zero: 'لا شيء قادم',
    );
    return '$_temp0';
  }

  @override
  String ncSettingsOpen(String group) {
    return 'افتح إعدادات $group';
  }

  @override
  String get ncSettingsMute => 'اكتم';

  @override
  String get ncPermissionOff =>
      'إشعارات مَدار متوقفة من إعدادات الهاتف، فلن يصل شيء مما هنا.';

  @override
  String get ncPermissionTurnOn => 'فعّلها';

  @override
  String ncBellLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'الإشعارات، $count جديد',
      many: 'الإشعارات، $count جديدًا',
      few: 'الإشعارات، $count جديدة',
      two: 'الإشعارات، اثنان جديدان',
      one: 'الإشعارات، واحد جديد',
      zero: 'الإشعارات',
    );
    return '$_temp0';
  }

  @override
  String get ncActionCancelSnooze => 'ألغِ التأجيل';

  @override
  String get ncActionSnoozeMenu => 'أجِّل…';

  @override
  String get ncSnoozeTitle => 'أعِده بعد قليل';

  @override
  String get ncSnoozeSubtitle =>
      'يختفي الآن، ثم يصلك من جديد في الوقت الذي تختاره.';

  @override
  String ncOptionUntil(String time) {
    return 'حتى $time';
  }

  @override
  String ncOptionAt(String time) {
    return 'يعود $time';
  }

  @override
  String ncRecentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count إشعار',
      many: '$count إشعارًا',
      few: '$count إشعارات',
      two: 'إشعاران',
      one: 'إشعار واحد',
    );
    return '$_temp0';
  }

  @override
  String ncUpcomingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count إشعار في الأيام السبعة القادمة',
      many: '$count إشعارًا في الأيام السبعة القادمة',
      few: '$count إشعارات في الأيام السبعة القادمة',
      two: 'إشعاران في الأيام السبعة القادمة',
      one: 'إشعار واحد في الأيام السبعة القادمة',
      zero: 'لا شيء في الأيام السبعة القادمة',
    );
    return '$_temp0';
  }

  @override
  String ncNewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count جديد',
      many: '$count جديدًا',
      few: '$count جديدة',
      two: 'اثنان جديدان',
      one: 'واحد جديد',
    );
    return '$_temp0';
  }

  @override
  String ncUntilTomorrow(String time) {
    return 'غدًا $time';
  }

  @override
  String get aiChatTitle => 'المحادثة الذكية';

  @override
  String get aiChatNewChat => 'محادثة جديدة';

  @override
  String get aiChatListTitle => 'المحادثات';

  @override
  String get aiChatSettingsTitle => 'إعدادات الذكاء الاصطناعي';

  @override
  String get aiChatSettingsRowSubtitle => 'المفاتيح والنموذج وطول الرد';

  @override
  String get aiChatAskAi => 'اسأل الذكاء الاصطناعي';

  @override
  String get aiChatAskAiSubtitle => 'بمفتاحك الخاص، وأنت تختار ما يُرسل';

  @override
  String aiChatAskAbout(String area) {
    return 'اسأل عن $area';
  }

  @override
  String get aiChatMenu => 'المزيد';

  @override
  String get aiChatOpenList => 'كل المحادثات';

  @override
  String get aiChatInputHint => 'اكتب رسالتك…';

  @override
  String get aiChatSend => 'إرسال';

  @override
  String get aiChatStop => 'إيقاف';

  @override
  String get aiChatThinking => 'يفكّر…';

  @override
  String get aiChatWriting => 'يكتب الرد';

  @override
  String get aiChatWillSend => 'سيُرسل';

  @override
  String get aiChatContextReviewFirst => 'ستراجع ملخّصك قبل الإرسال';

  @override
  String get aiChatContextNone => 'بلا سياق شخصي';

  @override
  String aiChatContextSections(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count قسم من ملخّصك',
      many: '$count قسمًا من ملخّصك',
      few: '$count أقسام من ملخّصك',
      two: 'قسمان من ملخّصك',
      one: 'قسم واحد من ملخّصك',
      zero: 'لا أقسام',
    );
    return '$_temp0';
  }

  @override
  String aiChatMessagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رسالة',
      many: '$count رسالة',
      few: '$count رسائل',
      two: 'رسالتان',
      one: 'رسالة واحدة',
      zero: 'لا رسائل',
    );
    return '$_temp0';
  }

  @override
  String aiChatApproxTokens(String count) {
    return '≈ $count رمز';
  }

  @override
  String aiChatStripSemantics(String summary) {
    return 'سيُرسل: $summary. انقر للمراجعة أو التغيير';
  }

  @override
  String aiChatOmitted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رسالة أقدم لن تُرسل',
      many: '$count رسالة أقدم لن تُرسل',
      few: '$count رسائل أقدم لن تُرسل',
      two: 'رسالتان أقدم لن تُرسلا',
      one: 'رسالة أقدم لن تُرسل',
    );
    return '$_temp0';
  }

  @override
  String get aiChatContextTitle => 'ما الذي سيُرسل';

  @override
  String get aiChatContextSubtitle => 'لا يُرسل شيء إلا حين تضغط «إرسال»';

  @override
  String get aiChatContextFromSummary => 'من ملخّصك';

  @override
  String get aiChatContextChange => 'مراجعة الأقسام';

  @override
  String get aiChatContextChoose => 'اختيار الأقسام';

  @override
  String get aiChatContextNoneHint =>
      'لن يُرسل شيء من بياناتك، فقط رسائل هذه المحادثة.';

  @override
  String get aiChatContextUnsetHint =>
      'عند أول إرسال ستظهر معاينة الملخّص لتختار الأقسام أو تستبعد ما تشاء.';

  @override
  String get aiChatContextUse => 'استخدمه في المحادثة';

  @override
  String get aiChatContextUseAndSend => 'استخدمه وأرسل';

  @override
  String aiChatContextReviewed(String when) {
    return 'راجعته $when';
  }

  @override
  String get aiChatContextCancelled => 'لم يُرسل شيء.';

  @override
  String aiChatServiceModel(String service, String model) {
    return '$service · $model';
  }

  @override
  String get aiChatViewPayload => 'عرض الطلب كما سيُرسل';

  @override
  String get aiChatDone => 'تم';

  @override
  String get aiChatPayloadTitle => 'الطلب كما سيُرسل';

  @override
  String get aiChatPayloadEndpoint => 'العنوان';

  @override
  String get aiChatPayloadHeaders => 'الترويسات (المفتاح مخفي)';

  @override
  String get aiChatPayloadSystem => 'التعليمات والسياق';

  @override
  String get aiChatPayloadMessages => 'الرسائل';

  @override
  String get aiChatPayloadRaw => 'النص الكامل (JSON)';

  @override
  String get aiChatPayloadDraftNote =>
      'يشمل رسالتك الجاري كتابتها. لن يُرسل إلا حين تضغط «إرسال».';

  @override
  String get aiChatPayloadNoDraft => 'اكتب رسالة لترى الطلب كاملًا.';

  @override
  String aiChatPayloadSize(String size, String tokens) {
    return '$size · ≈ $tokens رمز';
  }

  @override
  String aiChatBytes(String count) {
    return '$count بايت';
  }

  @override
  String aiChatKiloBytes(String count) {
    return '$count ك.ب';
  }

  @override
  String get aiChatRoleUser => 'أنت';

  @override
  String get aiChatRoleAssistant => 'المساعد';

  @override
  String get aiChatCopy => 'نسخ';

  @override
  String get aiChatCopied => 'نُسخ';

  @override
  String get aiChatCopyCode => 'نسخ الشيفرة';

  @override
  String get aiChatRegenerate => 'إعادة كتابة الرد';

  @override
  String get aiChatRetry => 'إعادة المحاولة';

  @override
  String get aiChatStopped => 'أوقفتَ الرد';

  @override
  String get aiChatCutShort =>
      'توقّف الرد عند حدّ الطول. يمكنك رفعه من الإعدادات.';

  @override
  String get aiChatRefused => 'امتنع النموذج عن الإجابة.';

  @override
  String get aiChatFiltered => 'أوقف مرشّح المحتوى الرد.';

  @override
  String get aiChatHealthNote =>
      'للمتابعة فقط وليس نصيحة طبية؛ استشر طبيبك في أي قرار صحي.';

  @override
  String aiChatOpenLink(String url) {
    return 'فتح الرابط $url';
  }

  @override
  String get aiChatLinkFailed => 'تعذّر فتح الرابط.';

  @override
  String aiChatErrorNoKey(String service) {
    return 'أضف مفتاح $service أولًا.';
  }

  @override
  String aiChatErrorBadKey(String service) {
    return 'رفضت $service المفتاح. تحقّق منه أو استبدله في الإعدادات.';
  }

  @override
  String get aiChatErrorForbidden =>
      'لا يملك هذا المفتاح صلاحية استخدام هذا النموذج.';

  @override
  String get aiChatErrorRateLimited =>
      'طلبات كثيرة الآن. انتظر قليلًا ثم أعد المحاولة.';

  @override
  String aiChatErrorRetryAfter(String seconds) {
    return 'يمكنك المحاولة بعد $seconds ث.';
  }

  @override
  String aiChatErrorQuota(String service) {
    return 'نفد الرصيد أو بلغتَ حدّ الإنفاق لدى $service.';
  }

  @override
  String aiChatErrorOverloaded(String service) {
    return '$service مشغولة الآن. أعد المحاولة بعد قليل.';
  }

  @override
  String aiChatErrorServer(String service) {
    return 'حدث خلل لدى $service. أعد المحاولة.';
  }

  @override
  String aiChatErrorModelNotFound(String model) {
    return 'النموذج «$model» غير متاح لهذا المفتاح. اختر نموذجًا آخر.';
  }

  @override
  String get aiChatErrorTemperature =>
      'لا يقبل هذا النموذج درجة حرارة مخصّصة. اجعلها «افتراضي النموذج» في الإعدادات.';

  @override
  String get aiChatErrorContextTooLong =>
      'المحادثة أطول مما يحتمله النموذج. ابدأ محادثة جديدة أو شارك أقسامًا أقل.';

  @override
  String aiChatErrorBadRequest(String service) {
    return 'رفضت $service الطلب.';
  }

  @override
  String get aiChatErrorNetwork => 'لا اتصال بالإنترنت، أو انقطع الاتصال.';

  @override
  String get aiChatErrorTimeout => 'لم يصل ردّ في الوقت المناسب.';

  @override
  String get aiChatErrorBadResponse => 'وصل ردّ تعذّرت قراءته.';

  @override
  String get aiChatErrorUnknown => 'حدث خطأ غير متوقّع.';

  @override
  String get aiChatOpenSettings => 'فتح الإعدادات';

  @override
  String get aiChatSetupTitle => 'اربط مفتاحك الخاص';

  @override
  String get aiChatSetupBody =>
      'تعمل المحادثة بمفتاح API منك لدى Anthropic أو OpenAI. يُحفظ مشفّرًا على هذا الهاتف فقط، ولا يدخل النسخ الاحتياطية ولا التصدير.';

  @override
  String aiChatSetupAdd(String service) {
    return 'إضافة مفتاح $service';
  }

  @override
  String get aiChatSetupPrivacy =>
      'لا يُرسل شيء إلا حين تضغط «إرسال»، وترى قبلها ما سيُرسل بالضبط.';

  @override
  String get aiChatEmptyTitle => 'بمَ أساعدك اليوم؟';

  @override
  String get aiChatEmptyBody =>
      'اسأل عن يومك أو صلاتك أو ميزانيتك أو أهدافك. تختار ما يُشارك من ملخّصك قبل الإرسال.';

  @override
  String get aiChatSuggestWeek => 'لخّص أسبوعي في نقاط قليلة';

  @override
  String get aiChatSuggestBudget => 'كيف أحسّن ميزانيتي هذا الشهر؟';

  @override
  String get aiChatSuggestPlan => 'ساعدني أخطّط لغدٍ متوازن';

  @override
  String get aiChatSuggestPrayer => 'كيف أحافظ على الصلاة في وقتها؟';

  @override
  String get aiChatListEmptyTitle => 'لا محادثات بعد';

  @override
  String get aiChatListEmptyBody => 'ابدأ محادثة، وتُحفظ هنا مشفّرة على هاتفك.';

  @override
  String get aiChatRename => 'إعادة التسمية';

  @override
  String get aiChatRenameField => 'اسم المحادثة';

  @override
  String get aiChatRenameSave => 'حفظ الاسم';

  @override
  String get aiChatDelete => 'حذف المحادثة';

  @override
  String get aiChatDeleted => 'حُذفت المحادثة';

  @override
  String get aiChatDeleteAll => 'حذف كل المحادثات';

  @override
  String get aiChatDeletedAll => 'حُذفت كل المحادثات';

  @override
  String get aiChatUntitled => 'محادثة بلا عنوان';

  @override
  String aiChatListLimitNote(String count) {
    return 'تُحفظ آخر $count محادثة؛ الأقدم يُحذف تلقائيًا.';
  }

  @override
  String aiChatListUpdated(String when, String messages) {
    return '$when · $messages';
  }

  @override
  String get aiChatToday => 'اليوم';

  @override
  String get aiChatYesterday => 'أمس';

  @override
  String get aiChatSettingsService => 'الخدمة';

  @override
  String get aiChatSettingsServiceModel => 'الخدمة والنموذج';

  @override
  String get aiChatServiceAnthropic => 'Anthropic';

  @override
  String get aiChatServiceOpenai => 'OpenAI';

  @override
  String get aiChatSettingsKeys => 'مفاتيح API';

  @override
  String aiChatKeyTitle(String service) {
    return 'مفتاح $service';
  }

  @override
  String aiChatKeySaved(String mask) {
    return 'محفوظ · $mask';
  }

  @override
  String get aiChatKeyNotSet => 'لم يُضف بعد';

  @override
  String get aiChatKeySheetSubtitle => 'يُحفظ مشفّرًا على هذا الهاتف فقط.';

  @override
  String get aiChatKeyCurrent => 'المفتاح الحالي';

  @override
  String get aiChatKeyField => 'المفتاح';

  @override
  String get aiChatKeyFieldHint => 'الصق المفتاح هنا';

  @override
  String get aiChatKeyPaste => 'لصق';

  @override
  String get aiChatKeySave => 'حفظ المفتاح';

  @override
  String get aiChatKeyReplace => 'استبدال المفتاح';

  @override
  String get aiChatKeyDelete => 'حذف المفتاح';

  @override
  String get aiChatKeyDeleted => 'حُذف المفتاح';

  @override
  String get aiChatKeySavedNotice => 'حُفظ المفتاح.';

  @override
  String get aiChatKeyTest => 'اختبار المفتاح';

  @override
  String get aiChatKeyTestOk => 'المفتاح يعمل.';

  @override
  String get aiChatKeyTestNote =>
      'الاختبار يطلب قائمة النماذج فقط، ولا يرسل أي بيانات منك.';

  @override
  String get aiChatKeyWhere => 'أين أجد مفتاحي؟';

  @override
  String get aiChatKeyProblemEmpty => 'الصق المفتاح أولًا.';

  @override
  String get aiChatKeyProblemShort => 'هذا أقصر من أن يكون مفتاحًا.';

  @override
  String get aiChatKeyProblemSpaces => 'في المفتاح مسافات؛ انسخه مرة أخرى.';

  @override
  String aiChatKeyProblemProvider(String service) {
    return 'هذا المفتاح خاص بخدمة $service، لذا لم يُحفظ هنا حتى لا يُرسل إلى خدمة أخرى. أضِفه ضمن $service.';
  }

  @override
  String get aiChatSettingsModel => 'النموذج';

  @override
  String get aiChatModelPickerTitle => 'اختر النموذج';

  @override
  String get aiChatModelYourList => 'قائمتك';

  @override
  String aiChatModelsAvailable(String service) {
    return 'متاح لدى $service';
  }

  @override
  String get aiChatModelCustom => 'إضافة معرّف نموذج';

  @override
  String get aiChatModelCustomField => 'معرّف النموذج';

  @override
  String aiChatModelCustomHint(String model) {
    return 'مثل $model';
  }

  @override
  String get aiChatModelInvalid => 'معرّف غير صالح.';

  @override
  String get aiChatModelUse => 'استخدام';

  @override
  String get aiChatModelRefresh => 'تحديث قائمة النماذج';

  @override
  String aiChatModelRefreshed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نموذج متاح',
      many: '$count نموذجًا متاحًا',
      few: '$count نماذج متاحة',
      two: 'نموذجان متاحان',
      one: 'نموذج واحد متاح',
      zero: 'لا نماذج متاحة',
    );
    return '$_temp0';
  }

  @override
  String aiChatModelRefreshNote(String service) {
    return 'يطلب القائمة من $service حين تضغط فقط.';
  }

  @override
  String get aiChatModelReset => 'استعادة القائمة الأصلية';

  @override
  String aiChatModelRemove(String model) {
    return 'إزالة $model من القائمة';
  }

  @override
  String get aiChatModelSelected => 'المختار';

  @override
  String aiChatModelChip(String model) {
    return 'النموذج: $model. انقر للتغيير';
  }

  @override
  String get aiChatSettingsReply => 'الرد';

  @override
  String get aiChatMaxTokens => 'أقصى طول للرد';

  @override
  String get aiChatMaxTokensNote => 'بالرموز، ويشمل تفكير النموذج إن وُجد.';

  @override
  String get aiChatTemperature => 'درجة الحرارة';

  @override
  String get aiChatTemperatureDefault => 'افتراضي النموذج (موصى به)';

  @override
  String get aiChatTemperatureNote =>
      'النماذج الأحدث لا تقبل إلا القيمة الافتراضية. قيمة أقل = ردود أثبت.';

  @override
  String get aiChatSettingsPrivacy => 'الخصوصية';

  @override
  String get aiChatPrivacyKeys =>
      'المفاتيح في التخزين المشفّر للهاتف، لا في قاعدة البيانات ولا في النسخ الاحتياطية أو التصدير.';

  @override
  String get aiChatPrivacyCalls =>
      'لا يتصل التطبيق بالخدمة إلا حين تضغط «إرسال» أو «إعادة كتابة الرد» أو «إعادة المحاولة» أو «اختبار المفتاح» أو «تحديث قائمة النماذج». لا شيء في الخلفية.';

  @override
  String aiChatPrivacyHistory(String count) {
    return 'تُحفظ المحادثات مشفّرة على هاتفك (آخر $count)، مع الملخّص الذي وافقت عليه لكل محادثة. وتدخل في نسختك الاحتياطية وفي تصدير بياناتك الكامل.';
  }

  @override
  String get aiChatKeyProblemChars =>
      'في المفتاح رموز لا تكون في المفاتيح (ربما من النسخ)؛ انسخه مرة أخرى.';

  @override
  String get aiChatLinkTitle => 'فتح هذا الرابط؟';

  @override
  String get aiChatLinkBody =>
      'يُفتح خارج مَدار، وكل ما في العنوان يصل إلى ذلك الموقع. افتحه فقط إن كنت تثق به.';

  @override
  String get aiChatLinkOpen => 'فتح الرابط';

  @override
  String get togetherTitle => 'معًا';

  @override
  String get togetherHallOfFame => 'قاعة مجدنا';

  @override
  String togetherPlayerDefault(String number) {
    return 'اللاعب $number';
  }

  @override
  String get togetherVs => 'ضد';

  @override
  String togetherEditProfile(String name) {
    return 'تعديل ملف $name';
  }

  @override
  String get togetherSettingsTitle => 'إعدادات اللعب معًا';

  @override
  String get togetherPlayers => 'اللاعبان';

  @override
  String get togetherWinsLabel => 'الانتصارات';

  @override
  String togetherLeads(String name, String diff) {
    return 'في الصدارة: $name بفارق $diff';
  }

  @override
  String get togetherAllSquare => 'تعادل تام بينكما';

  @override
  String togetherDrawsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تعادل',
      many: '$count تعادلًا',
      few: '$count تعادلات',
      two: 'تعادلان',
      one: 'تعادل واحد',
      zero: 'لا تعادلات',
    );
    return '$_temp0';
  }

  @override
  String togetherMatchesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مباراة',
      many: '$count مباراة',
      few: '$count مباريات',
      two: 'مباراتان',
      one: 'مباراة واحدة',
      zero: 'لا مباريات',
    );
    return '$_temp0';
  }

  @override
  String togetherDaysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يوم',
      many: '$count يومًا',
      few: '$count أيام',
      two: 'يومان',
      one: 'يوم واحد',
      zero: 'لا أيام',
    );
    return '$_temp0';
  }

  @override
  String get togetherDayStreakLabel => 'أيام اللعب المتتالية';

  @override
  String get togetherWinStreakLabel => 'سلسلة الانتصارات';

  @override
  String get togetherCoopLabel => 'انتصارات مشتركة';

  @override
  String get togetherPlayedToday => 'لعبتما اليوم';

  @override
  String get togetherPlayTodayHint => 'العبا اليوم لتستمر السلسلة';

  @override
  String get togetherNoStreak => 'لا سلسلة الآن';

  @override
  String get togetherSeeAll => 'عرض الكل';

  @override
  String get togetherHeadToHead => 'وجهًا لوجه';

  @override
  String get togetherRecentMatches => 'آخر المباريات';

  @override
  String get togetherEmptyTitle => 'لا مباريات بعد';

  @override
  String get togetherEmptyBody =>
      'العبا أول لعبة معًا — كل مباراة تُسجَّل هنا مع السلاسل والجوائز.';

  @override
  String get togetherShelfEmpty => 'أول جائزة بانتظاركما';

  @override
  String togetherTrophiesProgress(String earned, String total) {
    return '$earned من $total';
  }

  @override
  String get togetherTrophiesEarned => 'جوائز محصودة';

  @override
  String togetherResultWon(String name) {
    return 'فوز $name';
  }

  @override
  String get togetherResultDraw => 'تعادل';

  @override
  String get togetherResultTeamWon => 'فزتما معًا';

  @override
  String get togetherResultTeamLost => 'خسرتما معًا';

  @override
  String togetherBestScore(String score) {
    return 'أفضل نتيجة: $score';
  }

  @override
  String get togetherModePassAndPlay => 'تمرير الهاتف';

  @override
  String get togetherModePassAndPlayBody =>
      'هاتف واحد بالتناوب، وشاشة تسليم تخفي الأوراق والإجابات';

  @override
  String get togetherModeSplitScreen => 'شاشة مقسومة';

  @override
  String get togetherModeSplitScreenBody =>
      'هاتف واحد، لكلٍّ نصفه، ولمسٌ متعدد في آنٍ واحد';

  @override
  String get togetherModeNearby => 'هاتفان متجاوران';

  @override
  String get togetherModeNearbyBody =>
      'بلوتوث وواي فاي مباشر — بلا إنترنت ولا خوادم';

  @override
  String get togetherModeOnline => 'هاتفان عبر الإنترنت';

  @override
  String get togetherModeOnlineBody => 'من مكانين مختلفين — مطفأ افتراضيًا';

  @override
  String get togetherComingSoon => 'قريبًا';

  @override
  String get togetherModeUnsupported => 'غير متاح لهذه اللعبة';

  @override
  String get togetherModeDisabled => 'مطفأ في الإعدادات';

  @override
  String get togetherOnlyGameState =>
      'لا ينتقل بين الهاتفين إلا حالة اللعبة — الصحة والمال وبياناتكما الشخصية لا تغادر الجهاز.';

  @override
  String get togetherLaunchSubtitle => 'كيف ستلعبان؟';

  @override
  String get togetherWhoStarts => 'من يبدأ؟';

  @override
  String get togetherRandomStart => 'قرعة';

  @override
  String get togetherStartGame => 'هيا نلعب';

  @override
  String get togetherSplitLayout => 'ترتيب الشاشة';

  @override
  String get togetherLayoutFaceToFace => 'متقابلان';

  @override
  String get togetherLayoutSideBySide => 'جنبًا إلى جنب';

  @override
  String get togetherLayoutEndToEnd => 'طرفًا لطرف';

  @override
  String get togetherPassTo => 'مرّر الهاتف إلى';

  @override
  String togetherPassToName(String name) {
    return 'مرّر الهاتف إلى $name';
  }

  @override
  String get togetherHandOffHint => 'المعلومات الخاصة مخفية حتى يكشفها صاحبها';

  @override
  String get togetherNoPeeking => 'بلا تلصّص!';

  @override
  String togetherReveal(String name) {
    return 'أنا $name — اكشف';
  }

  @override
  String togetherStillYou(String name) {
    return 'هل ما زلت $name؟';
  }

  @override
  String get togetherShieldHint => 'أُخفيت الشاشة عند مغادرة التطبيق';

  @override
  String get togetherContinue => 'متابعة';

  @override
  String togetherLastMove(String move) {
    return 'آخر حركة: $move';
  }

  @override
  String get togetherPause => 'إيقاف مؤقت';

  @override
  String togetherYourSide(String name) {
    return 'جهة $name';
  }

  @override
  String get togetherProfileTitle => 'ملف اللاعب';

  @override
  String get togetherFieldName => 'الاسم';

  @override
  String get togetherFieldTitle => 'اللقب';

  @override
  String get togetherTitleNone => 'بلا لقب';

  @override
  String get togetherTitleCustom => 'لقب خاص';

  @override
  String get togetherTitleCustomHint => 'اكتب لقبًا';

  @override
  String get togetherFieldAvatar => 'الصورة الرمزية';

  @override
  String get togetherAvatarConstellation => 'شعار';

  @override
  String get togetherAvatarEmoji => 'رمز';

  @override
  String get togetherAvatarInitials => 'الحرف الأول';

  @override
  String get togetherAvatarShuffle => 'شكل آخر';

  @override
  String togetherAvatarOption(String number) {
    return 'الشكل $number';
  }

  @override
  String get togetherFieldColor => 'اللون';

  @override
  String togetherColorTaken(String name) {
    return 'لون $name';
  }

  @override
  String get togetherSave => 'حفظ';

  @override
  String get togetherCancel => 'إلغاء';

  @override
  String get togetherTitleStrategist => 'العقل المدبّر';

  @override
  String get togetherTitleCardShark => 'نجم الورق';

  @override
  String get togetherTitleLuckyStar => 'نجم الحظ';

  @override
  String get togetherTitleChallenger => 'روح التحدّي';

  @override
  String get togetherTitleGrandmaster => 'أسطورة الرقعة';

  @override
  String get togetherTitleQuizWhiz => 'موسوعة الأسئلة';

  @override
  String get togetherTitleComebackKing => 'العودة القوية';

  @override
  String get togetherTitleLightning => 'البرق الخاطف';

  @override
  String get togetherTitlePeacemaker => 'حمامة السلام';

  @override
  String get togetherTitleDreamer => 'روح حالمة';

  @override
  String get togetherTrophyFirstMatch => 'البداية';

  @override
  String get togetherTrophyFirstMatchDesc => 'أول مباراة معًا';

  @override
  String get togetherTrophyMatches10 => 'عشر مباريات';

  @override
  String togetherTrophyMatches10Desc(String count) {
    return '$count مباريات معًا';
  }

  @override
  String get togetherTrophyMatches50 => 'نصف المئة';

  @override
  String togetherTrophyMatches50Desc(String count) {
    return '$count مباراة معًا';
  }

  @override
  String get togetherTrophyMatches100 => 'نادي المئة';

  @override
  String togetherTrophyMatches100Desc(String count) {
    return '$count مباراة معًا';
  }

  @override
  String get togetherTrophyMatches250 => 'رفيقا الدرب';

  @override
  String togetherTrophyMatches250Desc(String count) {
    return '$count مباراة معًا';
  }

  @override
  String get togetherTrophyDayStreak3 => 'شعلة صغيرة';

  @override
  String togetherTrophyDayStreak3Desc(String count) {
    return 'لعبتما $count أيام متتالية';
  }

  @override
  String get togetherTrophyDayStreak7 => 'أسبوع كامل';

  @override
  String togetherTrophyDayStreak7Desc(String count) {
    return 'لعبتما $count أيام متتالية';
  }

  @override
  String get togetherTrophyDayStreak30 => 'شهر من الوفاء';

  @override
  String togetherTrophyDayStreak30Desc(String count) {
    return 'لعبتما $count يومًا متتاليًا';
  }

  @override
  String get togetherTrophyWinStreak3 => 'هاتريك';

  @override
  String togetherTrophyWinStreak3Desc(String count) {
    return '$count انتصارات متتالية';
  }

  @override
  String get togetherTrophyWinStreak5 => 'لا يُوقَف';

  @override
  String togetherTrophyWinStreak5Desc(String count) {
    return '$count انتصارات متتالية';
  }

  @override
  String get togetherTrophyWinStreak10 => 'سلسلة أسطورية';

  @override
  String togetherTrophyWinStreak10Desc(String count) {
    return '$count انتصارات متتالية';
  }

  @override
  String get togetherTrophyExplorer5 => 'المستكشفان';

  @override
  String togetherTrophyExplorer5Desc(String count) {
    return 'جرّبتما $count ألعاب مختلفة';
  }

  @override
  String get togetherTrophyExplorer10 => 'رحّالة الألعاب';

  @override
  String togetherTrophyExplorer10Desc(String count) {
    return 'جرّبتما $count ألعاب مختلفة';
  }

  @override
  String get togetherTrophyCoopWins5 => 'فريق الأحلام';

  @override
  String togetherTrophyCoopWins5Desc(String count) {
    return '$count انتصارات مشتركة';
  }

  @override
  String get togetherTrophyCoopWins25 => 'قلب واحد';

  @override
  String togetherTrophyCoopWins25Desc(String count) {
    return '$count انتصارًا مشتركًا';
  }

  @override
  String get togetherTrophyMarathon => 'ماراثون';

  @override
  String togetherTrophyMarathonDesc(String count) {
    return '$count مباريات في يوم واحد';
  }

  @override
  String get togetherTrophyPhotoFinish => 'كتفًا بكتف';

  @override
  String get togetherTrophyPhotoFinishDesc => 'أول تعادل بينكما';

  @override
  String get togetherTrophyNailBiter => 'على الحافة';

  @override
  String get togetherTrophyNailBiterDesc => 'فوز بفارق نقطة واحدة';

  @override
  String get togetherTrophyPerfectBalance => 'توازن مثالي';

  @override
  String togetherTrophyPerfectBalanceDesc(String count) {
    return 'انتصارات متساوية بعد $count مباراة على الأقل';
  }

  @override
  String get togetherTrophyGameMaster => 'خبرة لا تُضاهى';

  @override
  String togetherTrophyGameMasterDesc(String count, String game) {
    return '$count انتصارات في $game';
  }

  @override
  String get togetherTierBronze => 'برونزية';

  @override
  String get togetherTierSilver => 'فضية';

  @override
  String get togetherTierGold => 'ذهبية';

  @override
  String get togetherTierLegendary => 'أسطورية';

  @override
  String togetherEarnedOn(String date) {
    return 'حُصدت في $date';
  }

  @override
  String get togetherLocked => 'لم تُحصد بعد';

  @override
  String get togetherTrophyShared => 'لكما معًا';

  @override
  String togetherTrophyHolder(String name) {
    return 'حصدها $name';
  }

  @override
  String get togetherNewTrophies => 'جديد في قاعة مجدنا!';

  @override
  String togetherProgressOf(String current, String target) {
    return '$current / $target';
  }

  @override
  String get togetherGameTarneeb => 'طرنيب';

  @override
  String get togetherGameTrix => 'تركس';

  @override
  String get togetherGameBasra => 'باصرة';

  @override
  String get togetherGameKonkan => 'كونكان';

  @override
  String get togetherGameBackgammon => 'طاولة الزهر';

  @override
  String get togetherGameChess => 'شطرنج';

  @override
  String get togetherGameDominoes => 'دومينو';

  @override
  String get togetherGameLudo => 'لودو';

  @override
  String get togetherGameFourInARow => 'أربعة في صف';

  @override
  String get togetherGameWordDuel => 'مبارزة الكلمات';

  @override
  String get togetherGameQuizDuel => 'تحدّي الأسئلة الإسلامية';

  @override
  String get togetherGameDrawGuess => 'ارسم وخمّن';

  @override
  String get togetherGameMiniGolf => 'جولف مصغّر';

  @override
  String get togetherGameKnowMe => 'قديش بتعرفني؟';

  @override
  String get togetherGameAirHockey => 'هوكي الطاولة';

  @override
  String get togetherGameBeachVolley => 'كرة الشاطئ الثنائية';

  @override
  String get togetherGameKartDash => 'سباق الكارت';

  @override
  String get togetherGameSnowballFight => 'معركة كرات الثلج';

  @override
  String get togetherGamePaddleDuel => 'مبارزة المضارب';

  @override
  String get togetherGameTankDuel => 'مبارزة الدبابات';

  @override
  String get togetherGameMetropolisCoop => 'مدينة الآلات معًا';

  @override
  String get togetherGameUnknown => 'لعبة';

  @override
  String get togetherSettingsDefaultMode => 'طريقة اللعب الافتراضية';

  @override
  String get togetherSettingsDefaultModeHint =>
      'تُقترح في بداية كل لعبة، ويمكن تغييرها وقتها';

  @override
  String get togetherSettingsOnline => 'اللعب عبر الإنترنت';

  @override
  String get togetherSettingsOnlineHint =>
      'مطفأ افتراضيًا. عند تفعيله لا تنتقل إلا حالة اللعبة.';

  @override
  String get togetherSettingsPrivacy => 'إخفاء من التطبيقات الأخيرة';

  @override
  String get togetherSettingsPrivacyHint =>
      'أثناء الأدوار الخاصة لا تظهر الشاشة في المصغّرات ولقطات الشاشة';

  @override
  String get togetherResetRecords => 'مسح السجل والجوائز';

  @override
  String get togetherResetDone => 'مُسح السجل والجوائز';

  @override
  String get togetherTapToEdit => 'اضغط للتعديل';

  @override
  String get togetherSpecialsTitle => 'لنا نحن الاثنين';

  @override
  String get togetherSpecialsGoalEmpty => 'حدّدا هدفًا ومكافأة';

  @override
  String get togetherSpecialsSettings => 'إعدادات التحدّي';

  @override
  String get togetherKnowMeIntro =>
      'كلٌّ منكما يجيب عن نفسه ويخمّن إجابات الآخر، وتبقى الإجابات مخفيّة حتى تكشفاها معًا.';

  @override
  String get togetherKnowMeQuestionsPerRound => 'عدد الأسئلة';

  @override
  String get togetherKnowMeCategories => 'الفئات';

  @override
  String get togetherKnowMeAllCategories => 'الكلّ';

  @override
  String get togetherKnowMeStart => 'ابدأ الجولة';

  @override
  String get togetherKnowMeEditQuestions => 'تعديل الأسئلة';

  @override
  String togetherKnowMeQuestionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count سؤال',
      many: '$count سؤالًا',
      few: '$count أسئلة',
      two: 'سؤالان',
      one: 'سؤال واحد',
      zero: 'لا أسئلة',
    );
    return '$_temp0';
  }

  @override
  String get togetherKnowMeNoQuestions => 'لا أسئلة في هذه الفئات';

  @override
  String get togetherKnowMeWhoKnowsBest => 'من يعرف الآخر أكثر؟';

  @override
  String togetherKnowMeRoundsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count جولة',
      many: '$count جولة',
      few: '$count جولات',
      two: 'جولتان',
      one: 'جولة واحدة',
      zero: 'لا جولات بعد',
    );
    return '$_temp0';
  }

  @override
  String togetherKnowMeQuestionOf(String current, String total) {
    return 'السؤال $current من $total';
  }

  @override
  String get togetherKnowMeYourAnswer => 'إجابتك عن نفسك';

  @override
  String get togetherKnowMeYourAnswerHint => 'يمكن تركها فارغة لتخطّي السؤال';

  @override
  String togetherKnowMeYourGuess(String name) {
    return 'تخمينك لإجابة $name';
  }

  @override
  String get togetherKnowMeGuessHint => 'تخمينك…';

  @override
  String get togetherKnowMeNext => 'التالي';

  @override
  String get togetherKnowMeBack => 'السابق';

  @override
  String get togetherKnowMeDonePass => 'انتهيت من الإجابة';

  @override
  String get togetherKnowMeDoneReveal => 'انتهيت – إلى الكشف';

  @override
  String get togetherKnowMeHiddenNote => 'لن تظهر إجاباتك قبل الكشف';

  @override
  String get togetherKnowMeRevealTitle => 'لحظة الكشف';

  @override
  String togetherKnowMeAnswerOf(String name) {
    return 'إجابة $name';
  }

  @override
  String togetherKnowMeGuessOf(String name) {
    return 'تخمين $name';
  }

  @override
  String get togetherKnowMeRevealButton => 'اكشف';

  @override
  String get togetherKnowMeHiddenAnswer => 'مخفيّة حتى الكشف';

  @override
  String get togetherKnowMeSkipped => 'سؤال متروك – بلا نقاط';

  @override
  String get togetherKnowMeNoGuess => 'بلا تخمين';

  @override
  String togetherKnowMeJudgePrompt(String name) {
    return 'يا $name، ما مدى قرب التخمين؟';
  }

  @override
  String get togetherKnowMeExact => 'في الصميم';

  @override
  String get togetherKnowMeClose => 'قريب';

  @override
  String get togetherKnowMeMiss => 'بعيد';

  @override
  String get togetherKnowMeSuggested => 'اقتراح';

  @override
  String get togetherKnowMeNextQuestion => 'السؤال التالي';

  @override
  String get togetherKnowMeSeeResults => 'النتيجة';

  @override
  String get togetherKnowMeJudgeFirst => 'قيّما التخمينات أولًا';

  @override
  String get togetherKnowMeResultsTitle => 'النتيجة';

  @override
  String get togetherKnowMeDrawText => 'تعادل! كلاكما يعرف الآخر بالقدر نفسه';

  @override
  String togetherKnowMeScoreOf(String score, String max) {
    return '$score من $max';
  }

  @override
  String togetherKnowMeAccuracy(String percent) {
    return 'دقّة التخمين $percent';
  }

  @override
  String get togetherKnowMePlayAgain => 'جولة أخرى';

  @override
  String get togetherKnowMeFinish => 'إنهاء';

  @override
  String get togetherKnowMeNotRecorded =>
      'لم تُسجَّل الجولة: لم يُجَب عن أيّ سؤال';

  @override
  String get togetherKnowMeLeaveTitle => 'مغادرة الجولة؟';

  @override
  String get togetherKnowMeLeaveBody =>
      'ستضيع الإجابات المكتوبة في هذه الجولة.';

  @override
  String get togetherKnowMeLeave => 'مغادرة';

  @override
  String get togetherKnowMeStay => 'متابعة اللعب';

  @override
  String get togetherKnowMeBankTitle => 'بنك الأسئلة';

  @override
  String get togetherKnowMeAddQuestion => 'سؤال جديد';

  @override
  String get togetherKnowMeEditQuestion => 'تعديل السؤال';

  @override
  String get togetherKnowMeQuestionField => 'السؤال';

  @override
  String get togetherKnowMeQuestionHint =>
      'بصيغة المتكلّم: ما ... المفضّل عندي؟';

  @override
  String get togetherKnowMeCategoryField => 'الفئة';

  @override
  String get togetherKnowMeAddCategory => 'فئة جديدة';

  @override
  String get togetherKnowMeEditCategory => 'تعديل الفئة';

  @override
  String get togetherKnowMeCategoryName => 'اسم الفئة';

  @override
  String get togetherKnowMeCategoryIcon => 'الأيقونة';

  @override
  String get togetherKnowMeDeleteCategory => 'حذف الفئة';

  @override
  String togetherKnowMeCategoryDeleted(String name) {
    return 'حُذفت الفئة ونُقلت أسئلتها إلى «$name»';
  }

  @override
  String get togetherKnowMeQuestionDeleted => 'حُذف السؤال';

  @override
  String get togetherKnowMeMoveTo => 'نقل إلى فئة';

  @override
  String get togetherKnowMeResetWording => 'الصياغة الأصلية';

  @override
  String get togetherKnowMeRestoreDefaults => 'استعادة الأسئلة الأصلية';

  @override
  String get togetherKnowMeRestored => 'استُعيدت الأسئلة الأصلية';

  @override
  String togetherKnowMeBankFull(String max) {
    return 'امتلأ البنك ($max سؤالًا)';
  }

  @override
  String get togetherKnowMeEmptyCategory => 'لا أسئلة في هذه الفئة بعد';

  @override
  String get togetherKnowMeEdited => 'معدّل';

  @override
  String get togetherKnowMeOwn => 'من إضافتنا';

  @override
  String get togetherKnowMeLastCategory => 'تبقى فئة واحدة على الأقل';

  @override
  String get togetherKnowMeReorderHint =>
      'اسحب المقبض لإعادة الترتيب، واضغط مطوّلًا لمزيد من الخيارات';

  @override
  String get togetherWeeklyTitle => 'تحدّي الأسبوع';

  @override
  String togetherWeeklyDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بقي $count يوم',
      many: 'بقي $count يومًا',
      few: 'بقيت $count أيام',
      two: 'بقي يومان',
      one: 'آخر يوم',
      zero: 'آخر يوم',
    );
    return '$_temp0';
  }

  @override
  String togetherWeeklyRenewsOn(String day) {
    return 'يتجدّد يوم $day';
  }

  @override
  String get togetherWeeklyMarkDone => 'أنجزته';

  @override
  String get togetherWeeklyDone => 'تمّ';

  @override
  String togetherWeeklyWaiting(String name) {
    return 'بانتظار $name';
  }

  @override
  String get togetherWeeklyNotYet => 'لم يبدأ بعد';

  @override
  String get togetherWeeklyBothDone => 'أنجزتماه معًا!';

  @override
  String get togetherWeeklyStreak => 'السلسلة';

  @override
  String get togetherWeeklyBest => 'أفضل سلسلة';

  @override
  String get togetherWeeklyTotal => 'المنجزة';

  @override
  String get togetherWeeklyAnother => 'تحدٍّ آخر';

  @override
  String get togetherWeeklyPick => 'اختيار تحدٍّ';

  @override
  String get togetherWeeklySwapLocked =>
      'لا يُبدَّل التحدّي بعد أن يبدأ أحدكما';

  @override
  String get togetherWeeklyList => 'قائمة التحدّيات';

  @override
  String get togetherWeeklyListHint =>
      'تدور التحدّيات بهذا الترتيب أسبوعًا بعد أسبوع';

  @override
  String get togetherWeeklyAdd => 'تحدٍّ جديد';

  @override
  String get togetherWeeklyEdit => 'تعديل التحدّي';

  @override
  String get togetherWeeklyField => 'التحدّي';

  @override
  String get togetherWeeklyFieldHint => 'شيء نفعله معًا هذا الأسبوع';

  @override
  String get togetherWeeklyHide => 'إخراج من الدورة';

  @override
  String get togetherWeeklyShow => 'إعادة إلى الدورة';

  @override
  String get togetherWeeklyHidden => 'خارج الدورة';

  @override
  String get togetherWeeklyDeleted => 'حُذف التحدّي';

  @override
  String get togetherWeeklyHiddenDone => 'أُخرج من الدورة';

  @override
  String get togetherWeeklyLastActive => 'يبقى تحدٍّ واحد على الأقل في الدورة';

  @override
  String get togetherWeeklyRecent => 'الأسابيع الماضية';

  @override
  String get togetherWeeklyUndone => 'أُلغي الإنجاز';

  @override
  String get togetherWeeklyThisWeek => 'هذا الأسبوع';

  @override
  String get togetherWeekStart => 'بداية الأسبوع';

  @override
  String get togetherWeekStartHint =>
      'يتجدّد التحدّي عند منتصف ليل هذا اليوم بتوقيت الهاتف.';

  @override
  String togetherWeeksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أسبوع',
      many: '$count أسبوعًا',
      few: '$count أسابيع',
      two: 'أسبوعان',
      one: 'أسبوع واحد',
      zero: 'لا أسابيع',
    );
    return '$_temp0';
  }

  @override
  String get togetherGoalTitle => 'هدفنا';

  @override
  String get togetherGoalNone => 'لا هدف بعد';

  @override
  String get togetherGoalNoneBody =>
      'اختارا معًا هدفًا، ومكافأةً تنتظركما عند الوصول إليه.';

  @override
  String get togetherGoalSet => 'حدّدا هدفًا';

  @override
  String get togetherGoalEdit => 'تعديل الهدف';

  @override
  String get togetherGoalNew => 'هدف جديد';

  @override
  String get togetherGoalNameField => 'اسم الهدف';

  @override
  String get togetherGoalRewardField => 'المكافأة';

  @override
  String get togetherGoalRewardHint => 'مثلًا: عشاء في مكاننا المفضّل';

  @override
  String get togetherGoalRewardRequired => 'اكتبا المكافأة التي تنتظركما';

  @override
  String get togetherGoalMetricField => 'كيف نتقدّم؟';

  @override
  String get togetherGoalMetricPoints => 'نقاط معًا';

  @override
  String togetherGoalMetricPointsBody(String match, String challenge) {
    return '$match لكلّ مباراة نلعبها معًا، و$challenge لكلّ تحدٍّ أسبوعي ننجزه';
  }

  @override
  String get togetherGoalMetricCounter => 'عدّاد خاصّ بنا';

  @override
  String get togetherGoalMetricCounterBody =>
      'نحرّكه بأنفسنا: مشاوير، صفحات، زيارات…';

  @override
  String get togetherGoalTargetField => 'الهدف';

  @override
  String get togetherGoalUnitField => 'الوحدة';

  @override
  String get togetherGoalUnitHint => 'مثلًا: مشوار';

  @override
  String get togetherGoalCountGames => 'المباريات';

  @override
  String get togetherGoalCountChallenges => 'التحدّيات الأسبوعية';

  @override
  String togetherGoalPointsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نقطة',
      many: '$count نقطة',
      few: '$count نقاط',
      two: 'نقطتان',
      one: 'نقطة واحدة',
      zero: 'لا نقاط',
    );
    return '$_temp0';
  }

  @override
  String togetherGoalProgress(String current, String target) {
    return '$current من $target';
  }

  @override
  String togetherGoalRemaining(String count) {
    return 'بقي $count';
  }

  @override
  String get togetherGoalRewardLocked => 'المكافأة بانتظاركما';

  @override
  String get togetherGoalUnlocked => 'فُتحت المكافأة!';

  @override
  String get togetherGoalUnlockedBody =>
      'وصلتما إلى الهدف. استمتعا بمكافأتكما:';

  @override
  String get togetherGoalNext => 'هدفنا التالي';

  @override
  String togetherGoalFromMatches(String points) {
    return 'من المباريات: $points';
  }

  @override
  String togetherGoalFromChallenges(String points) {
    return 'من التحدّيات: $points';
  }

  @override
  String get togetherGoalAchieved => 'مكافآتنا';

  @override
  String get togetherGoalDelete => 'التخلّي عن الهدف';

  @override
  String get togetherGoalDeleted => 'حُذف الهدف';

  @override
  String get togetherGoalAddOne => 'زيادة واحد';

  @override
  String get togetherGoalTakeOne => 'إنقاص واحد';

  @override
  String get togetherGoalCounterDefaultUnit => 'مرّة';

  @override
  String togetherGoalSince(String date) {
    return 'منذ $date';
  }

  @override
  String get togetherTrophyMindReader => 'قارئ الأفكار';

  @override
  String get togetherTrophyMindReaderDesc =>
      'جولة «قديش بتعرفني؟» كاملة بلا خطأ';

  @override
  String get togetherTrophyChallengeChampions => 'أبطال التحدّي';

  @override
  String get togetherTrophyChallengeChampionsDesc =>
      'تحدّي الأسبوع أربعة أسابيع متتالية';

  @override
  String get togetherTrophyDreamCameTrue => 'حلم تحقّق';

  @override
  String get togetherTrophyDreamCameTrueDesc =>
      'هدف مشترك تحقّق ومكافأته فُتحت';

  @override
  String togetherWeeklyInRotation(String count) {
    return '$count في الدورة';
  }

  @override
  String get togetherKnowMeRecap => 'الإجابات';

  @override
  String togetherWeeklyRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String get widgetsPrayerName => 'الصلاة القادمة';

  @override
  String get widgetsMedsName => 'أدوية اليوم';

  @override
  String get widgetsTasksName => 'أهم ثلاث اليوم';

  @override
  String get widgetsBudgetName => 'المتبقي من الميزانية';

  @override
  String widgetsCountdown(String time) {
    return 'بعد $time';
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
    return 'التالية $time: $name';
  }

  @override
  String widgetsMedsPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count جرعة بانتظارك',
      many: '$count جرعة بانتظارك',
      few: '$count جرعات بانتظارك',
      two: 'جرعتان بانتظارك',
      one: 'جرعة واحدة بانتظارك',
    );
    return '$_temp0';
  }

  @override
  String get widgetsMedsAllDone => 'جرعات اليوم كلها مسجّلة';

  @override
  String get widgetsMedsNoneToday => 'لا جرعات اليوم';

  @override
  String get widgetsMedsSetUp => 'أضف أدويتك في مدار';

  @override
  String widgetsMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'و$count جرعة أخرى',
      many: 'و$count جرعة أخرى',
      few: 'و$count جرعات أخرى',
      two: 'وجرعتان أخريان',
      one: 'وجرعة أخرى',
    );
    return '$_temp0';
  }

  @override
  String widgetsTasksLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بقي $count',
      many: 'بقي $count',
      few: 'بقيت $count',
      two: 'بقيت اثنتان',
      one: 'بقيت واحدة',
    );
    return '$_temp0';
  }

  @override
  String get widgetsTasksAllDone => 'أنجزت أهم ثلاث اليوم';

  @override
  String get widgetsTasksEmpty => 'اختر أهم ثلاث لليوم في مدار';

  @override
  String widgetsTasksCarried(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count لم تكتمل أمس',
      many: '$count لم تكتمل أمس',
      few: '$count لم تكتمل أمس',
      two: 'اثنتان لم تكتملا أمس',
      one: 'واحدة لم تكتمل أمس',
    );
    return '$_temp0';
  }

  @override
  String widgetsBudgetOf(String amount) {
    return 'من $amount';
  }

  @override
  String widgetsBudgetOverBy(String amount) {
    return 'تجاوزت بـ$amount';
  }

  @override
  String get widgetsBudgetOver => 'تجاوزت الميزانية';

  @override
  String get widgetsBudgetLeftMonth => 'متبقٍّ لهذا الشهر';

  @override
  String get widgetsBudgetLeftWeek => 'متبقٍّ لهذا الأسبوع';

  @override
  String widgetsBudgetDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يوم متبقٍّ',
      many: '$count يومًا متبقيًا',
      few: '$count أيام متبقية',
      two: 'يومان متبقيان',
      one: 'يوم واحد متبقٍّ',
      zero: 'آخر يوم',
    );
    return '$_temp0';
  }

  @override
  String get widgetsBudgetNone => 'ضع ميزانيتك في مدار';

  @override
  String get widgetsStale => 'افتح مدار لتحديث هذه الأداة';

  @override
  String get widgetsSettingsTitle => 'أدوات الشاشة الرئيسية';

  @override
  String get widgetsSettingsIntro =>
      'أضف أدوات مدار من شاشتك الرئيسية: اضغط مطولًا على مساحة فارغة، ثم «الأدوات»، ثم مدار.';

  @override
  String get widgetsShowDetails => 'إظهار التفاصيل';

  @override
  String get widgetsDetailsShown =>
      'الأسماء والأوقات والمبالغ ظاهرة على الشاشة الرئيسية';

  @override
  String get widgetsDetailsHidden => 'الأعداد فقط — لا أسماء ولا مبالغ';

  @override
  String get widgetsPrayerDetailsShown => 'يظهر اسم مدينتك تحت التاريخ الهجري';

  @override
  String get widgetsPrayerDetailsHidden =>
      'الصلاة ووقتها والتاريخ فقط — دون المدينة';

  @override
  String get widgetsOnHomeScreen => 'على شاشتك الرئيسية';

  @override
  String get widgetsNotAdded => 'لم تُضف بعد';

  @override
  String get widgetsLockNote =>
      'قفل التطبيق مفعّل، لذلك تعرض الأدوات الأعداد فقط ما لم تختر غير ذلك هنا.';

  @override
  String get widgetsPrivacyNote =>
      'تُكتب بيانات الأدوات على جهازك فقط، مشفّرة، ولا تُكتب لأداة لم تضفها، وتُمحى مع «حذف كل البيانات».';

  @override
  String get widgetsBudgetPeriod => 'فترة الميزانية';

  @override
  String get widgetsPeriodMonth => 'هذا الشهر';

  @override
  String get widgetsPeriodWeek => 'هذا الأسبوع';

  @override
  String get savedGamesTitle => 'ألعابي من الويب';

  @override
  String get savedGamesShelfTitle => 'ألعابي المحفوظة';

  @override
  String get savedGamesShelfSubtitle => 'ألعاب ويب تعمل من روابطها الأصلية';

  @override
  String get savedGamesSeeAll => 'الكل';

  @override
  String get savedGamesAdd => 'أضف لعبة';

  @override
  String get savedGamesAddTitle => 'لعبة جديدة من رابط';

  @override
  String get savedGamesAddSubtitle =>
      'تعمل من رابطها الأصلي؛ لا يُنسخ شيء من كودها';

  @override
  String get savedGamesEditTitle => 'تعديل اللعبة';

  @override
  String get savedGamesUrlLabel => 'الرابط';

  @override
  String get savedGamesUrlHint => 'https://claude.ai/public/artifacts/…';

  @override
  String get savedGamesPaste => 'لصق';

  @override
  String get savedGamesClipboardEmpty => 'لا يوجد رابط في الحافظة';

  @override
  String get savedGamesUrlEmpty => 'الصق رابط اللعبة أولًا';

  @override
  String get savedGamesUrlNotHttps => 'الروابط الآمنة (https) فقط';

  @override
  String get savedGamesUseHttps => 'استخدم https';

  @override
  String get savedGamesUrlScheme => 'هذا ليس رابط صفحة ويب';

  @override
  String get savedGamesUrlMalformed => 'لا يبدو هذا رابطًا صحيحًا';

  @override
  String get savedGamesUrlCredentials =>
      'لا تُقبل روابط تحوي اسم مستخدم أو كلمة مرور';

  @override
  String get savedGamesUrlTooLong => 'الرابط طويل جدًا';

  @override
  String savedGamesUrlDuplicate(String title) {
    return 'محفوظة من قبل باسم «$title»';
  }

  @override
  String get savedGamesArtifactBadge => 'عمل تفاعلي من Claude';

  @override
  String get savedGamesSecureBadge => 'رابط آمن';

  @override
  String get savedGamesNameLabel => 'الاسم';

  @override
  String get savedGamesNameHint => 'اسم اللعبة';

  @override
  String get savedGamesFetchTitle => 'جلب العنوان';

  @override
  String get savedGamesFetchFailed => 'تعذّرت قراءة عنوان الصفحة؛ اكتبه بنفسك';

  @override
  String get savedGamesFetchNote =>
      '«جلب» يتصل بالموقع مرة واحدة حين تضغطه فقط، ولا يُرسل عنك شيئًا.';

  @override
  String get savedGamesIconLabel => 'الأيقونة';

  @override
  String get savedGamesUseSiteIcon => 'أيقونة الموقع';

  @override
  String get savedGamesRemoveSiteIcon => 'إزالة أيقونة الموقع';

  @override
  String get savedGamesIconFailed => 'لم نجد أيقونة صالحة لهذا الموقع';

  @override
  String get savedGamesShuffleIcon => 'أيقونة أخرى';

  @override
  String savedGamesGlyph(String number) {
    return 'الرمز $number';
  }

  @override
  String savedGamesColor(String number) {
    return 'اللون $number';
  }

  @override
  String get savedGamesOrientationLabel => 'اتجاه الشاشة أثناء اللعب';

  @override
  String get savedGamesOrientationAuto => 'تلقائي';

  @override
  String get savedGamesOrientationPortrait => 'عمودي';

  @override
  String get savedGamesOrientationLandscape => 'أفقي';

  @override
  String get savedGamesNotesLabel => 'ملاحظات';

  @override
  String get savedGamesNotesHint => 'مثلًا: طريقة اللعب أو من شاركها معي';

  @override
  String get savedGamesSave => 'حفظ';

  @override
  String get savedGamesCancel => 'إلغاء';

  @override
  String savedGamesAdded(String title) {
    return 'أُضيفت «$title»';
  }

  @override
  String get savedGamesUpdated => 'حُفظت التعديلات';

  @override
  String savedGamesDeleted(String title) {
    return 'حُذفت «$title»';
  }

  @override
  String savedGamesFull(String max) {
    return 'بلغتَ الحد الأقصى ($max لعبة)؛ احذف واحدة أولًا';
  }

  @override
  String savedGamesPlayGame(String title) {
    return 'العب $title';
  }

  @override
  String savedGamesPlayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'لُعبت $count مرة',
      many: 'لُعبت $count مرة',
      few: 'لُعبت $count مرات',
      two: 'لُعبت مرتين',
      one: 'لُعبت مرة واحدة',
      zero: 'لم تُلعب بعد',
    );
    return '$_temp0';
  }

  @override
  String get savedGamesLastPlayedToday => 'آخر لعب اليوم';

  @override
  String get savedGamesLastPlayedYesterday => 'آخر لعب أمس';

  @override
  String savedGamesLastPlayedDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'آخر لعب قبل $days يوم',
      many: 'آخر لعب قبل $days يومًا',
      few: 'آخر لعب قبل $days أيام',
      two: 'آخر لعب قبل يومين',
      one: 'آخر لعب قبل يوم',
    );
    return '$_temp0';
  }

  @override
  String savedGamesLastPlayedOn(String date) {
    return 'آخر لعب $date';
  }

  @override
  String get savedGamesNew => 'جديدة';

  @override
  String get savedGamesLayoutGrid => 'عرض الملصقات';

  @override
  String get savedGamesLayoutList => 'عرض القائمة والترتيب';

  @override
  String get savedGamesReorderHint => 'اسحب المقبض لتغيير الترتيب';

  @override
  String get savedGamesEmptyTitle => 'أحضِر ألعاب الويب التي تحبها';

  @override
  String get savedGamesEmptyBody =>
      'احفظ أي لعبة تعمل في المتصفح برابطها الآمن، والعبها بملء الشاشة داخل مَدار.';

  @override
  String get savedGamesEmptyStep1 =>
      'افتح اللعبة، مثل عمل تفاعلي (Artifact) شاركه أحدهم من Claude.';

  @override
  String savedGamesEmptyStep2(String example) {
    return 'انسخ رابطها، ويكون عادةً بالشكل $example';
  }

  @override
  String get savedGamesEmptyStep3 =>
      'اضغط «أضف لعبة» والصق الرابط، ثم اختر لها اسمًا وأيقونة.';

  @override
  String get savedGamesPrivacyNote =>
      'تعمل كل لعبة من رابطها الأصلي ولا يُنسخ كودها. لا يتصل مَدار بالشبكة إلا حين تفتح لعبة أو تضغط «جلب».';

  @override
  String get savedGamesOpenExternal => 'فتح في المتصفح';

  @override
  String get savedGamesEdit => 'تعديل';

  @override
  String get savedGamesClearData => 'مسح بيانات الموقع';

  @override
  String savedGamesClearDataTitle(String title) {
    return 'مسح بيانات «$title»؟';
  }

  @override
  String get savedGamesClearDataBody =>
      'يُحذف ما حفظه موقع اللعبة على هذا الجهاز: التقدّم والإعدادات وملفات الارتباط الظاهرة للصفحة، لكل الألعاب من هذا الموقع. ما تضمّنه اللعبة من مواقع أخرى يُمسح بـ«مسح بيانات كل الألعاب». لا يمكن التراجع.';

  @override
  String get savedGamesClearDataScheduled =>
      'ستُمسح بياناتها عند فتحها في المرة القادمة';

  @override
  String get savedGamesClearDataPending => 'ستُمسح بياناتها عند الفتح';

  @override
  String get savedGamesClearAll => 'مسح بيانات كل الألعاب';

  @override
  String get savedGamesClearAllTitle => 'مسح بيانات كل الألعاب؟';

  @override
  String get savedGamesClearAllBody =>
      'يحذف ملفات الارتباط والتخزين والذاكرة المؤقتة لكل ألعاب الويب. لا يمسّ بقية بيانات مَدار ولا قائمة ألعابك.';

  @override
  String get savedGamesClearAllDone => 'مُسحت بيانات كل الألعاب';

  @override
  String get savedGamesClearFailed => 'تعذّر مسح بعض البيانات';

  @override
  String get savedGamesConfirmClear => 'مسح';

  @override
  String savedGamesLoading(String title) {
    return 'يُحمَّل «$title»…';
  }

  @override
  String get savedGamesClearing => 'تُمسح بيانات اللعبة…';

  @override
  String get savedGamesOfflineTitle => 'لا يوجد اتصال';

  @override
  String get savedGamesOfflineBody =>
      'تحتاج هذه اللعبة إلى الإنترنت لأنها تعمل من رابطها الأصلي.';

  @override
  String get savedGamesErrorTitle => 'تعذّر فتح اللعبة';

  @override
  String get savedGamesErrorBody => 'قد يكون الموقع متوقفًا أو تغيّر رابطه.';

  @override
  String get savedGamesInsecureTitle => 'اتصال غير آمن';

  @override
  String get savedGamesInsecureBody =>
      'شهادة أمان الموقع غير صالحة، فأوقف مَدار الاتصال لحمايتك.';

  @override
  String get savedGamesCrashedTitle => 'توقّفت اللعبة';

  @override
  String get savedGamesCrashedBody =>
      'تعطّلت صفحة اللعبة أو أُغلقت لنفاد الذاكرة. أعد المحاولة لتحميلها من جديد.';

  @override
  String get savedGamesRetry => 'إعادة المحاولة';

  @override
  String get savedGamesBackToMadar => 'العودة إلى مَدار';

  @override
  String get savedGamesReload => 'إعادة التحميل';

  @override
  String get savedGamesMute => 'كتم الصوت';

  @override
  String get savedGamesUnmute => 'تشغيل الصوت';

  @override
  String get savedGamesControls => 'أدوات اللعبة';

  @override
  String get savedGamesCloseControls => 'إخفاء الأدوات';

  @override
  String get savedGamesMuteSealed =>
      'بعض أصوات هذه اللعبة داخل إطار محمي؛ استخدم أزرار الصوت في هاتفك.';

  @override
  String get savedGamesExitTitle => 'الخروج من اللعبة؟';

  @override
  String get savedGamesExitBody => 'قد يضيع أي تقدّم لا تحفظه اللعبة بنفسها.';

  @override
  String get savedGamesExitStay => 'متابعة اللعب';

  @override
  String get savedGamesExitLeave => 'خروج';

  @override
  String get savedGamesExternalTitle => 'فتح رابط خارجي؟';

  @override
  String savedGamesExternalBody(String host) {
    return 'تريد اللعبة فتح $host. سيُفتح في متصفحك خارج مَدار.';
  }

  @override
  String get savedGamesExternalFailed => 'لم يُعثر على متصفح يفتح الرابط';

  @override
  String get savedGamesPrayerTitle => 'حان وقت الصلاة';

  @override
  String get savedGamesPrayerBody =>
      'أوقفنا اللعبة وصوتها. تُستأنف من تلقاء نفسها بعد الأذان ووقت الصلاة.';

  @override
  String get savedGamesPrayerUnloaded =>
      'أوقفنا اللعبة كي لا يصدر عنها أي صوت، وسيُعاد تحميلها بعد الصلاة.';

  @override
  String savedGamesPageSays(String host) {
    return 'رسالة من $host';
  }

  @override
  String get savedGamesOk => 'حسنًا';

  @override
  String savedGamesStats(String added, String played) {
    return '$added · $played';
  }

  @override
  String savedGamesAddedOn(String date) {
    return 'أُضيفت $date';
  }

  @override
  String get savedGamesAddCardHint => 'الصق رابط لعبة ويب';

  @override
  String get savedGamesShelfEmpty => 'احفظ لعبة ويب برابطها وستظهر هنا.';

  @override
  String get savedGamesOpenAll => 'فتح ألعابي المحفوظة';

  @override
  String get savedGamesClearDataDone => 'مُسحت بيانات اللعبة';

  @override
  String get togetherNetOnThisPhone => 'على هذا الهاتف';

  @override
  String get togetherNetOnThisPhoneHint =>
      'اختارا صاحب هذا الهاتف — يُحفظ الاختيار';

  @override
  String togetherNetThisIsMe(String name) {
    return 'هذا الهاتف لـ$name';
  }

  @override
  String get togetherNetNearbyIntro =>
      'افتحا اللعبة نفسها على الهاتفين ثم اضغطا «العبا معًا» على كلٍّ منهما. بلوتوث وواي فاي مباشر فقط — بلا إنترنت ولا خوادم.';

  @override
  String get togetherNetPlayTogether => 'العبا معًا';

  @override
  String get togetherNetSearching => 'نبحث عن الهاتف الآخر…';

  @override
  String get togetherNetSearchingHint =>
      'لا يظهر؟ تأكّدا أن اللعبة نفسها مفتوحة على الهاتفين وأن البلوتوث والواي فاي يعملان.';

  @override
  String get togetherNetPaused => 'توقّف البحث ريثما تعودان إلى مَدار';

  @override
  String get togetherNetPickPhone => 'وجدنا أكثر من هاتف — اختارا الهاتف الآخر';

  @override
  String get togetherNetConnect => 'اتصال';

  @override
  String togetherNetConnecting(String name) {
    return 'نتصل بـ$name…';
  }

  @override
  String get togetherNetConfirmTitle => 'هل يظهر الرقم نفسه؟';

  @override
  String togetherNetConfirmBody(String name) {
    return 'تأكّدا أن هاتف $name يعرض هذه الأرقام الأربعة نفسها.';
  }

  @override
  String togetherNetDigits(String digits) {
    return 'رمز التحقّق $digits';
  }

  @override
  String get togetherNetMatch => 'متطابقة';

  @override
  String get togetherNetNoMatch => 'غير متطابقة';

  @override
  String togetherNetWaitingFor(String name) {
    return 'بانتظار تأكيد $name…';
  }

  @override
  String togetherNetConnected(String name) {
    return 'متصلان — $name على الهاتف الآخر';
  }

  @override
  String togetherNetReconnecting(String name) {
    return 'انقطع الاتصال — نبحث عن $name…';
  }

  @override
  String togetherNetLost(String name) {
    return 'لم نعثر على $name';
  }

  @override
  String get togetherNetLostHint =>
      'قرّبا الهاتفين وتأكّدا أن مَدار مفتوح على كليهما.';

  @override
  String get togetherNetSearchAgain => 'ابحث مجددًا';

  @override
  String get togetherNetTryAgain => 'حاول مجددًا';

  @override
  String get togetherNetCancel => 'إلغاء';

  @override
  String get togetherNetPermTitle => 'اسمح بالعثور على الأجهزة القريبة';

  @override
  String get togetherNetPermNearbyBody =>
      'ليجد مَدار الهاتف الآخر دون إنترنت يحتاج إذن «الأجهزة المجاورة»: بلوتوث وواي فاي مباشر.';

  @override
  String get togetherNetPermLocationBody =>
      'على هذا الإصدار من أندرويد يربط النظام البحث بالبلوتوث والواي فاي بإذن الموقع. لا يقرأ مَدار موقعكما أبدًا.';

  @override
  String get togetherNetPermPointPairing => 'يُستخدم أثناء الاقتران واللعب فقط';

  @override
  String get togetherNetPermPointGameOnly => 'لا يغادر الهاتف إلا حالة اللعبة';

  @override
  String get togetherNetPermPointStops =>
      'يتوقف البحث فور الاقتران أو عند مغادرة التطبيق';

  @override
  String get togetherNetContinue => 'متابعة';

  @override
  String get togetherNetNotNow => 'ليس الآن';

  @override
  String get togetherNetPermDenied => 'لا يستطيع مَدار البحث دون هذا الإذن';

  @override
  String get togetherNetPermDeniedForever =>
      'رُفض الإذن. فعّلاه من إعدادات التطبيق ← الأذونات.';

  @override
  String get togetherNetOpenSettings => 'فتح الإعدادات';

  @override
  String get togetherNetLocationOff => 'خدمات الموقع متوقفة';

  @override
  String get togetherNetLocationOffBody =>
      'على هذا الإصدار من أندرويد يحتاج البحث عن الأجهزة إلى تشغيلها. لا يقرأ مَدار موقعكما.';

  @override
  String get togetherNetSearchAnyway => 'ابحث على أي حال';

  @override
  String get togetherNetFailRadio =>
      'شغّلا البلوتوث والواي فاي ثم حاولا مجددًا';

  @override
  String get togetherNetFailDeclined => 'لم يؤكّد الهاتف الآخر';

  @override
  String get togetherNetFailNotFound => 'لا توجد غرفة مفتوحة بهذا الرمز';

  @override
  String get togetherNetFailExpired =>
      'انتهت صلاحية الرمز — أنشئا رمزًا جديدًا';

  @override
  String get togetherNetFailTaken => 'انضمّ هاتف آخر بهذا الرمز';

  @override
  String get togetherNetFailDifferentGame => 'هذا الرمز للعبة أخرى';

  @override
  String get togetherNetFailNetwork => 'لا اتصال بالإنترنت';

  @override
  String get togetherNetFailSetup =>
      'رفض Firebase إعدادات المشروع — راجعاها في «اللعب عبر الإنترنت»';

  @override
  String get togetherNetFailSignIn =>
      'تعذّر الدخول المجهول — فعّلاه في مشروع Firebase';

  @override
  String get togetherNetFailRules =>
      'رفضت قاعدة البيانات الوصول — الصقا قواعد الأمان';

  @override
  String get togetherNetFailRulesOpen =>
      'قاعدة البيانات مفتوحة للجميع — الصقا قواعد الأمان قبل اللعب';

  @override
  String get togetherNetFailPeerLeft => 'غادر الطرف الآخر';

  @override
  String get togetherNetFailUnknown => 'حدث خطأ غير متوقع';

  @override
  String get togetherNetCreateCode => 'إنشاء رمز';

  @override
  String get togetherNetEnterCode => 'إدخال رمز';

  @override
  String get togetherNetOnlineIntro =>
      'أحدكما يُنشئ رمزًا والآخر يكتبه على هاتفه. لا يُحفظ في مشروعكما على Firebase إلا حالة اللعبة، وتُحذف عند المغادرة.';

  @override
  String get togetherNetYourCode => 'رمز الغرفة';

  @override
  String get togetherNetCodeHint =>
      'اكتبا هذا الرمز على الهاتف الآخر في «إدخال رمز»';

  @override
  String togetherNetCodeValid(String time) {
    return 'صالح حتى $time';
  }

  @override
  String get togetherNetCopyCode => 'نسخ الرمز';

  @override
  String get togetherNetCopied => 'نُسخ';

  @override
  String get togetherNetWaitingJoin => 'بانتظار انضمام الهاتف الآخر…';

  @override
  String togetherNetJoinRequest(String name) {
    return 'طلب انضمام من $name';
  }

  @override
  String get togetherNetJoinRequestBody =>
      'هل هذا الطرف الآخر فعلًا؟ إن لم يكن فارفضا وسنُنشئ رمزًا جديدًا.';

  @override
  String get togetherNetAccept => 'ابدأ اللعب';

  @override
  String get togetherNetDecline => 'رفض';

  @override
  String get togetherNetCodeField => 'الرمز (ستة أرقام)';

  @override
  String get togetherNetJoin => 'انضمام';

  @override
  String get togetherNetJoining => 'نتحقّق من الرمز…';

  @override
  String togetherNetWaitingAccept(String name) {
    return 'بانتظار قبول $name…';
  }

  @override
  String get togetherNetSigningIn => 'نتصل بمشروعكما…';

  @override
  String get togetherNetNeedsSetup => 'اللعب عبر الإنترنت غير مُفعَّل';

  @override
  String get togetherNetNeedsSetupBody =>
      'يعمل عبر مشروع Firebase مجاني خاص بكما، ويبقى مطفأً حتى تفعّلاه.';

  @override
  String get togetherNetSetUp => 'إعداد اللعب عبر الإنترنت';

  @override
  String togetherNetQrLabel(String code) {
    return 'رمز QR للغرفة $code';
  }

  @override
  String get togetherNetOnlineIntroSheet =>
      'للّعب من مكانين مختلفين يستخدم مَدار مشروع Firebase المجاني الخاص بكما — لا خادم لمَدار. لا يُحفظ فيه إلا حالة اللعبة، ومعها اسم العرض والصورة واللون، لساعات قليلة ثم يُحذف.';

  @override
  String get togetherNetEnable => 'تفعيل اللعب عبر الإنترنت';

  @override
  String get togetherNetEnableHint =>
      'مطفأ افتراضيًا. يحتاج إعدادات مشروع صالحة.';

  @override
  String get togetherNetEnableNeedsConfig => 'احفظا إعدادات المشروع أولًا';

  @override
  String get togetherNetStepsTitle => 'الإعداد مرة واحدة';

  @override
  String get togetherNetStep1 =>
      'أنشئا مشروعًا مجانيًا في console.firebase.google.com';

  @override
  String get togetherNetStep2 =>
      'أضيفا تطبيق أندرويد باسم الحزمة app.madar.orbit';

  @override
  String get togetherNetStep3 =>
      'فعّلا الدخول المجهول: Authentication › Sign-in method › Anonymous';

  @override
  String get togetherNetStep4 =>
      'أنشئا Realtime Database والصقا قواعد الأمان في تبويب Rules';

  @override
  String get togetherNetStep5 =>
      'انقلا القيم إلى الحقول هنا، أو الصقا ملف google-services.json كاملًا';

  @override
  String get togetherNetCopyRules => 'نسخ قواعد الأمان';

  @override
  String get togetherNetRulesCopied => 'نُسخت قواعد الأمان';

  @override
  String get togetherNetPasteConfig => 'لصق من الحافظة';

  @override
  String get togetherNetPasteNothing => 'لا إعدادات في الحافظة';

  @override
  String get togetherNetPasted => 'مُلئت الحقول من الحافظة';

  @override
  String get togetherNetFieldApiKey => 'مفتاح الواجهة (API key)';

  @override
  String get togetherNetFieldAppId => 'معرّف التطبيق (App ID)';

  @override
  String get togetherNetFieldProjectId => 'معرّف المشروع (Project ID)';

  @override
  String get togetherNetFieldDatabaseUrl => 'رابط قاعدة البيانات';

  @override
  String get togetherNetFieldSenderId => 'رقم المُرسِل (Sender ID)';

  @override
  String get togetherNetErrMissing => 'مطلوب';

  @override
  String get togetherNetErrFormat => 'الصيغة غير صحيحة';

  @override
  String get togetherNetErrMismatch => 'لا يطابق رقم المشروع في معرّف التطبيق';

  @override
  String get togetherNetSave => 'حفظ';

  @override
  String get togetherNetSaved => 'حُفظت الإعدادات';

  @override
  String get togetherNetTest => 'اختبار الاتصال';

  @override
  String get togetherNetTesting => 'نختبر…';

  @override
  String get togetherNetTestOk => 'يعمل! الدخول المجهول وقواعد الأمان جاهزة';

  @override
  String get togetherNetRemove => 'حذف الإعدادات';

  @override
  String get togetherNetRemoved => 'حُذفت إعدادات المشروع';

  @override
  String get togetherNetStoredSecurely =>
      'تُحفظ في التخزين الآمن لهذا الهاتف فقط، ولا تُرسل إلى أي مكان سوى مشروعكما.';

  @override
  String get togetherNetOnlineOn => 'مُفعَّل';

  @override
  String get togetherNetOnlineOff => 'مطفأ';

  @override
  String get togetherNetOnlineNotSetUp => 'غير مُعدّ';

  @override
  String get togetherNetTurnGroup => 'اللعب معًا';

  @override
  String get togetherNetTurnChannel => 'دورك';

  @override
  String get togetherNetTurnChannelBody => 'حين يلعب الطرف الآخر من هاتف بعيد';

  @override
  String togetherNetTurnTitle(String game) {
    return 'دورك في $game';
  }

  @override
  String togetherNetTurnBody(String name) {
    return 'انتهى دور $name — حان دورك';
  }
}
