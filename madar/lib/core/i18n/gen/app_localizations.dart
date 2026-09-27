import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L10n
/// returned by `L10n.of(context)`.
///
/// Applications need to include `L10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L10n.localizationsDelegates,
///   supportedLocales: L10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L10n.supportedLocales
/// property.
abstract class L10n {
  L10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n)!;
  }

  static const LocalizationsDelegate<L10n> delegate = _L10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// Application name
  ///
  /// In ar, this message translates to:
  /// **'مَدار'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In ar, this message translates to:
  /// **'حياتك تدور حول الصلاة'**
  String get appTagline;

  /// No description provided for @actionSave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get actionSave;

  /// No description provided for @actionCancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get actionCancel;

  /// No description provided for @actionAdd.
  ///
  /// In ar, this message translates to:
  /// **'إضافة'**
  String get actionAdd;

  /// No description provided for @actionEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get actionEdit;

  /// No description provided for @actionDuplicate.
  ///
  /// In ar, this message translates to:
  /// **'تكرار'**
  String get actionDuplicate;

  /// No description provided for @actionMove.
  ///
  /// In ar, this message translates to:
  /// **'نقل'**
  String get actionMove;

  /// No description provided for @actionSetReminder.
  ///
  /// In ar, this message translates to:
  /// **'تذكير'**
  String get actionSetReminder;

  /// No description provided for @actionDelete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get actionDelete;

  /// No description provided for @actionUndo.
  ///
  /// In ar, this message translates to:
  /// **'تراجع'**
  String get actionUndo;

  /// No description provided for @actionDone.
  ///
  /// In ar, this message translates to:
  /// **'تم'**
  String get actionDone;

  /// No description provided for @actionClose.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get actionClose;

  /// No description provided for @actionBack.
  ///
  /// In ar, this message translates to:
  /// **'رجوع'**
  String get actionBack;

  /// No description provided for @actionContinue.
  ///
  /// In ar, this message translates to:
  /// **'متابعة'**
  String get actionContinue;

  /// No description provided for @actionComplete.
  ///
  /// In ar, this message translates to:
  /// **'إنجاز'**
  String get actionComplete;

  /// No description provided for @actionSearch.
  ///
  /// In ar, this message translates to:
  /// **'بحث'**
  String get actionSearch;

  /// No description provided for @itemDeleted.
  ///
  /// In ar, this message translates to:
  /// **'تم الحذف'**
  String get itemDeleted;

  /// No description provided for @itemDuplicated.
  ///
  /// In ar, this message translates to:
  /// **'تم التكرار'**
  String get itemDuplicated;

  /// No description provided for @itemMoved.
  ///
  /// In ar, this message translates to:
  /// **'تم النقل'**
  String get itemMoved;

  /// No description provided for @itemSaved.
  ///
  /// In ar, this message translates to:
  /// **'تم الحفظ'**
  String get itemSaved;

  /// No description provided for @fieldRequired.
  ///
  /// In ar, this message translates to:
  /// **'هذا الحقل مطلوب'**
  String get fieldRequired;

  /// No description provided for @fieldInvalidNumber.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رقمًا صحيحًا'**
  String get fieldInvalidNumber;

  /// No description provided for @windowFajr.
  ///
  /// In ar, this message translates to:
  /// **'بعد الفجر'**
  String get windowFajr;

  /// No description provided for @windowDuha.
  ///
  /// In ar, this message translates to:
  /// **'الضحى'**
  String get windowDuha;

  /// No description provided for @windowDhuhr.
  ///
  /// In ar, this message translates to:
  /// **'الظهر ← العصر'**
  String get windowDhuhr;

  /// No description provided for @windowAsr.
  ///
  /// In ar, this message translates to:
  /// **'العصر ← المغرب'**
  String get windowAsr;

  /// No description provided for @windowMaghrib.
  ///
  /// In ar, this message translates to:
  /// **'المغرب ← العشاء'**
  String get windowMaghrib;

  /// No description provided for @windowIsha.
  ///
  /// In ar, this message translates to:
  /// **'بعد العشاء'**
  String get windowIsha;

  /// No description provided for @windowAnytime.
  ///
  /// In ar, this message translates to:
  /// **'أي وقت'**
  String get windowAnytime;

  /// No description provided for @prayerFajr.
  ///
  /// In ar, this message translates to:
  /// **'الفجر'**
  String get prayerFajr;

  /// No description provided for @prayerSunrise.
  ///
  /// In ar, this message translates to:
  /// **'الشروق'**
  String get prayerSunrise;

  /// No description provided for @prayerDhuhr.
  ///
  /// In ar, this message translates to:
  /// **'الظهر'**
  String get prayerDhuhr;

  /// No description provided for @prayerAsr.
  ///
  /// In ar, this message translates to:
  /// **'العصر'**
  String get prayerAsr;

  /// No description provided for @prayerMaghrib.
  ///
  /// In ar, this message translates to:
  /// **'المغرب'**
  String get prayerMaghrib;

  /// No description provided for @prayerIsha.
  ///
  /// In ar, this message translates to:
  /// **'العشاء'**
  String get prayerIsha;

  /// No description provided for @planetFaith.
  ///
  /// In ar, this message translates to:
  /// **'الإيمان'**
  String get planetFaith;

  /// No description provided for @planetHealth.
  ///
  /// In ar, this message translates to:
  /// **'الصحة'**
  String get planetHealth;

  /// No description provided for @planetFamily.
  ///
  /// In ar, this message translates to:
  /// **'العائلة'**
  String get planetFamily;

  /// No description provided for @planetWork.
  ///
  /// In ar, this message translates to:
  /// **'العمل'**
  String get planetWork;

  /// No description provided for @planetMoney.
  ///
  /// In ar, this message translates to:
  /// **'المال'**
  String get planetMoney;

  /// No description provided for @planetGrowth.
  ///
  /// In ar, this message translates to:
  /// **'النمو'**
  String get planetGrowth;

  /// No description provided for @planetBody.
  ///
  /// In ar, this message translates to:
  /// **'الجسد'**
  String get planetBody;

  /// No description provided for @planetTravel.
  ///
  /// In ar, this message translates to:
  /// **'السفر'**
  String get planetTravel;

  /// No description provided for @itemsCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا عناصر} =1{عنصر واحد} =2{عنصران} few{{count} عناصر} many{{count} عنصرًا} other{{count} عنصر}}'**
  String itemsCount(int count);

  /// Semantic label of the orbit loader / loading buttons
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التحميل'**
  String get designLoading;

  /// No description provided for @designEmptyListTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا شيء هنا بعد'**
  String get designEmptyListTitle;

  /// No description provided for @designEmptyListBody.
  ///
  /// In ar, this message translates to:
  /// **'أضف أول عنصر، ودَعْ مداره يبدأ بالدوران.'**
  String get designEmptyListBody;

  /// No description provided for @designNoDataTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا بيانات بعد'**
  String get designNoDataTitle;

  /// No description provided for @designNoDataBody.
  ///
  /// In ar, this message translates to:
  /// **'ستظهر الرسوم هنا حين تتجمّع لديك بضعة أيام.'**
  String get designNoDataBody;

  /// No description provided for @designNoResultsTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا نتائج'**
  String get designNoResultsTitle;

  /// No description provided for @designNoResultsBody.
  ///
  /// In ar, this message translates to:
  /// **'جرّب كلمة أخرى، أو وسّع نطاق البحث.'**
  String get designNoResultsBody;

  /// No description provided for @designGalleryTitle.
  ///
  /// In ar, this message translates to:
  /// **'معرض التصميم'**
  String get designGalleryTitle;

  /// No description provided for @designGallerySubtitle.
  ///
  /// In ar, this message translates to:
  /// **'مكوّنات مَدار كلّها في مكان واحد'**
  String get designGallerySubtitle;

  /// No description provided for @designGalleryTheme.
  ///
  /// In ar, this message translates to:
  /// **'السِّمة'**
  String get designGalleryTheme;

  /// No description provided for @designGalleryDirection.
  ///
  /// In ar, this message translates to:
  /// **'اتجاه الكتابة'**
  String get designGalleryDirection;

  /// No description provided for @designDirectionRtl.
  ///
  /// In ar, this message translates to:
  /// **'من اليمين'**
  String get designDirectionRtl;

  /// No description provided for @designDirectionLtr.
  ///
  /// In ar, this message translates to:
  /// **'من اليسار'**
  String get designDirectionLtr;

  /// No description provided for @designThemeLapis.
  ///
  /// In ar, this message translates to:
  /// **'لازَوَرد'**
  String get designThemeLapis;

  /// No description provided for @designThemeEmerald.
  ///
  /// In ar, this message translates to:
  /// **'زُمُرُّد'**
  String get designThemeEmerald;

  /// No description provided for @designThemeDesert.
  ///
  /// In ar, this message translates to:
  /// **'صحراء'**
  String get designThemeDesert;

  /// No description provided for @designThemeAurora.
  ///
  /// In ar, this message translates to:
  /// **'شَفَق'**
  String get designThemeAurora;

  /// No description provided for @designThemePearl.
  ///
  /// In ar, this message translates to:
  /// **'لؤلؤ'**
  String get designThemePearl;

  /// No description provided for @designSectionSurfaces.
  ///
  /// In ar, this message translates to:
  /// **'الأسطح الزجاجية'**
  String get designSectionSurfaces;

  /// No description provided for @designSectionButtons.
  ///
  /// In ar, this message translates to:
  /// **'الأزرار'**
  String get designSectionButtons;

  /// No description provided for @designSectionChips.
  ///
  /// In ar, this message translates to:
  /// **'الاختيارات'**
  String get designSectionChips;

  /// No description provided for @designSectionToggles.
  ///
  /// In ar, this message translates to:
  /// **'المفاتيح'**
  String get designSectionToggles;

  /// No description provided for @designSectionProgress.
  ///
  /// In ar, this message translates to:
  /// **'التقدّم'**
  String get designSectionProgress;

  /// No description provided for @designSectionStats.
  ///
  /// In ar, this message translates to:
  /// **'الإحصاءات'**
  String get designSectionStats;

  /// No description provided for @designSectionOrnaments.
  ///
  /// In ar, this message translates to:
  /// **'الزخارف'**
  String get designSectionOrnaments;

  /// No description provided for @designSectionLoaders.
  ///
  /// In ar, this message translates to:
  /// **'الانتظار'**
  String get designSectionLoaders;

  /// No description provided for @designSectionEmpty.
  ///
  /// In ar, this message translates to:
  /// **'الحالات الفارغة'**
  String get designSectionEmpty;

  /// No description provided for @designSectionType.
  ///
  /// In ar, this message translates to:
  /// **'الخطوط والألوان'**
  String get designSectionType;

  /// No description provided for @designSeeAll.
  ///
  /// In ar, this message translates to:
  /// **'عرض الكل'**
  String get designSeeAll;

  /// No description provided for @designPanelTitle.
  ///
  /// In ar, this message translates to:
  /// **'لوحة زجاجية'**
  String get designPanelTitle;

  /// No description provided for @designPanelBody.
  ///
  /// In ar, this message translates to:
  /// **'ضبابية حقيقية فوق الكون الحيّ، بإطار ذهبي رفيع ولمعة تنساب على مهل.'**
  String get designPanelBody;

  /// No description provided for @designCardBody.
  ///
  /// In ar, this message translates to:
  /// **'زجاج مُحاكى للقوائم الطويلة: بلا ضبابية، وبالأناقة نفسها.'**
  String get designCardBody;

  /// No description provided for @designButtonPrimary.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ يومك'**
  String get designButtonPrimary;

  /// No description provided for @designButtonSecondary.
  ///
  /// In ar, this message translates to:
  /// **'لاحقًا'**
  String get designButtonSecondary;

  /// No description provided for @designButtonGhost.
  ///
  /// In ar, this message translates to:
  /// **'التفاصيل'**
  String get designButtonGhost;

  /// No description provided for @designChipsSingle.
  ///
  /// In ar, this message translates to:
  /// **'اختيار واحد'**
  String get designChipsSingle;

  /// No description provided for @designChipsMulti.
  ///
  /// In ar, this message translates to:
  /// **'اختيارات متعددة'**
  String get designChipsMulti;

  /// No description provided for @designToggleSound.
  ///
  /// In ar, this message translates to:
  /// **'أصوات الواجهة'**
  String get designToggleSound;

  /// No description provided for @designToggleHaptics.
  ///
  /// In ar, this message translates to:
  /// **'الاهتزاز اللمسي'**
  String get designToggleHaptics;

  /// No description provided for @designToggleReduceMotion.
  ///
  /// In ar, this message translates to:
  /// **'تقليل الحركة'**
  String get designToggleReduceMotion;

  /// No description provided for @designRingDaily.
  ///
  /// In ar, this message translates to:
  /// **'هدف اليوم'**
  String get designRingDaily;

  /// No description provided for @designRingPrayers.
  ///
  /// In ar, this message translates to:
  /// **'الصلوات'**
  String get designRingPrayers;

  /// No description provided for @designRingDone.
  ///
  /// In ar, this message translates to:
  /// **'اكتمل'**
  String get designRingDone;

  /// No description provided for @designStatStreak.
  ///
  /// In ar, this message translates to:
  /// **'سلسلة الصلاة'**
  String get designStatStreak;

  /// No description provided for @designStatSteps.
  ///
  /// In ar, this message translates to:
  /// **'الخطوات'**
  String get designStatSteps;

  /// No description provided for @designStatWater.
  ///
  /// In ar, this message translates to:
  /// **'الماء'**
  String get designStatWater;

  /// No description provided for @designStatFocus.
  ///
  /// In ar, this message translates to:
  /// **'التركيز'**
  String get designStatFocus;

  /// No description provided for @designStatVsLastWeek.
  ///
  /// In ar, this message translates to:
  /// **'مقارنةً بالأسبوع الماضي'**
  String get designStatVsLastWeek;

  /// No description provided for @designUnitDays.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{يوم} =1{يوم} =2{يومان} few{أيام} many{يومًا} other{يوم}}'**
  String designUnitDays(int count);

  /// No description provided for @designUnitLitres.
  ///
  /// In ar, this message translates to:
  /// **'لتر'**
  String get designUnitLitres;

  /// No description provided for @designUnitHours.
  ///
  /// In ar, this message translates to:
  /// **'ساعة'**
  String get designUnitHours;

  /// No description provided for @designOrnamentStar.
  ///
  /// In ar, this message translates to:
  /// **'نجمة ثُمانية'**
  String get designOrnamentStar;

  /// No description provided for @designOrnamentStar12.
  ///
  /// In ar, this message translates to:
  /// **'نجمة اثنا عشرية'**
  String get designOrnamentStar12;

  /// No description provided for @designOrnamentRub.
  ///
  /// In ar, this message translates to:
  /// **'ربع الحزب'**
  String get designOrnamentRub;

  /// No description provided for @designOrnamentRosette.
  ///
  /// In ar, this message translates to:
  /// **'وردة هندسية متشابكة'**
  String get designOrnamentRosette;

  /// No description provided for @designOrnamentAstrolabe.
  ///
  /// In ar, this message translates to:
  /// **'حلقة الأسطرلاب'**
  String get designOrnamentAstrolabe;

  /// No description provided for @designOrnamentArabesque.
  ///
  /// In ar, this message translates to:
  /// **'إفريز الأرابيسك'**
  String get designOrnamentArabesque;

  /// No description provided for @designTypeSample.
  ///
  /// In ar, this message translates to:
  /// **'يتنفّس الخطّ العربي هنا براحة: سطور رحبة، وتشكيل واضح، وأرقام منتظمة.'**
  String get designTypeSample;

  /// Seeded currency name (JOD)
  ///
  /// In ar, this message translates to:
  /// **'دينار أردني'**
  String get dbCurrencyJod;

  /// Seeded currency name (USD)
  ///
  /// In ar, this message translates to:
  /// **'دولار أمريكي'**
  String get dbCurrencyUsd;

  /// Seeded currency name (SYP)
  ///
  /// In ar, this message translates to:
  /// **'ليرة سورية'**
  String get dbCurrencySyp;

  /// Seeded currency name (EGP)
  ///
  /// In ar, this message translates to:
  /// **'جنيه مصري'**
  String get dbCurrencyEgp;

  /// Seeded currency name (LYD)
  ///
  /// In ar, this message translates to:
  /// **'دينار ليبي'**
  String get dbCurrencyLyd;

  /// Default pain location
  ///
  /// In ar, this message translates to:
  /// **'الرأس'**
  String get dbSeedPainHead;

  /// Default pain location
  ///
  /// In ar, this message translates to:
  /// **'الرقبة'**
  String get dbSeedPainNeck;

  /// Default pain location
  ///
  /// In ar, this message translates to:
  /// **'الكتفان'**
  String get dbSeedPainShoulders;

  /// Default pain location
  ///
  /// In ar, this message translates to:
  /// **'أعلى الظهر'**
  String get dbSeedPainUpperBack;

  /// Default pain location
  ///
  /// In ar, this message translates to:
  /// **'أسفل الظهر'**
  String get dbSeedPainLowerBack;

  /// Default pain location
  ///
  /// In ar, this message translates to:
  /// **'الصدر'**
  String get dbSeedPainChest;

  /// Default pain location
  ///
  /// In ar, this message translates to:
  /// **'البطن'**
  String get dbSeedPainAbdomen;

  /// Default pain location
  ///
  /// In ar, this message translates to:
  /// **'الذراعان'**
  String get dbSeedPainArms;

  /// Default pain location
  ///
  /// In ar, this message translates to:
  /// **'اليدان والأصابع'**
  String get dbSeedPainHands;

  /// Default pain location
  ///
  /// In ar, this message translates to:
  /// **'الوركان'**
  String get dbSeedPainHips;

  /// Default pain location
  ///
  /// In ar, this message translates to:
  /// **'الركبتان'**
  String get dbSeedPainKnees;

  /// Default pain location
  ///
  /// In ar, this message translates to:
  /// **'القدمان والكاحلان'**
  String get dbSeedPainFeet;

  /// Default pain location
  ///
  /// In ar, this message translates to:
  /// **'المفاصل عمومًا'**
  String get dbSeedPainJoints;

  /// Default pain trigger
  ///
  /// In ar, this message translates to:
  /// **'قلّة النوم'**
  String get dbSeedTriggerSleep;

  /// Default pain trigger
  ///
  /// In ar, this message translates to:
  /// **'التوتر والضغط'**
  String get dbSeedTriggerStress;

  /// Default pain trigger
  ///
  /// In ar, this message translates to:
  /// **'الجلوس الطويل'**
  String get dbSeedTriggerSitting;

  /// Default pain trigger
  ///
  /// In ar, this message translates to:
  /// **'الوقوف الطويل'**
  String get dbSeedTriggerStanding;

  /// Default pain trigger
  ///
  /// In ar, this message translates to:
  /// **'مجهود بدني زائد'**
  String get dbSeedTriggerExertion;

  /// Default pain trigger
  ///
  /// In ar, this message translates to:
  /// **'البرد'**
  String get dbSeedTriggerCold;

  /// Default pain trigger
  ///
  /// In ar, this message translates to:
  /// **'تقلّب الطقس'**
  String get dbSeedTriggerWeather;

  /// Default pain trigger
  ///
  /// In ar, this message translates to:
  /// **'طعام بعينه'**
  String get dbSeedTriggerFood;

  /// Default pain trigger
  ///
  /// In ar, this message translates to:
  /// **'قلّة شرب الماء'**
  String get dbSeedTriggerWater;

  /// Default pain trigger
  ///
  /// In ar, this message translates to:
  /// **'نسيان جرعة الدواء'**
  String get dbSeedTriggerMissedDose;

  /// Default pain trigger
  ///
  /// In ar, this message translates to:
  /// **'طول النظر إلى الشاشات'**
  String get dbSeedTriggerScreens;

  /// Default mood factor
  ///
  /// In ar, this message translates to:
  /// **'النوم'**
  String get dbSeedMoodSleep;

  /// Default mood factor
  ///
  /// In ar, this message translates to:
  /// **'الصلاة والذكر'**
  String get dbSeedMoodPrayer;

  /// Default mood factor
  ///
  /// In ar, this message translates to:
  /// **'العائلة'**
  String get dbSeedMoodFamily;

  /// Default mood factor
  ///
  /// In ar, this message translates to:
  /// **'العمل'**
  String get dbSeedMoodWork;

  /// Default mood factor
  ///
  /// In ar, this message translates to:
  /// **'المال'**
  String get dbSeedMoodMoney;

  /// Default mood factor
  ///
  /// In ar, this message translates to:
  /// **'الصحة'**
  String get dbSeedMoodHealth;

  /// Default mood factor
  ///
  /// In ar, this message translates to:
  /// **'الحركة والرياضة'**
  String get dbSeedMoodExercise;

  /// Default mood factor
  ///
  /// In ar, this message translates to:
  /// **'الأصدقاء'**
  String get dbSeedMoodFriends;

  /// Default mood factor
  ///
  /// In ar, this message translates to:
  /// **'الكافيين'**
  String get dbSeedMoodCaffeine;

  /// Default mood factor
  ///
  /// In ar, this message translates to:
  /// **'الطقس'**
  String get dbSeedMoodWeather;

  /// Default mood factor
  ///
  /// In ar, this message translates to:
  /// **'الأخبار'**
  String get dbSeedMoodNews;

  /// Default mood factor
  ///
  /// In ar, this message translates to:
  /// **'الوحدة'**
  String get dbSeedMoodLoneliness;

  /// Default stress-reduction habit
  ///
  /// In ar, this message translates to:
  /// **'خمس دقائق من التنفّس العميق'**
  String get dbSeedHabitBreathing;

  /// Default stress-reduction habit
  ///
  /// In ar, this message translates to:
  /// **'مشيٌ هادئ في الهواء الطلق'**
  String get dbSeedHabitWalk;

  /// Default stress-reduction habit
  ///
  /// In ar, this message translates to:
  /// **'أذكار الصباح والمساء'**
  String get dbSeedHabitAdhkar;

  /// Default stress-reduction habit
  ///
  /// In ar, this message translates to:
  /// **'ثلاث نِعَم أحمد الله عليها اليوم'**
  String get dbSeedHabitGratitude;

  /// Default stress-reduction habit
  ///
  /// In ar, this message translates to:
  /// **'ساعة بلا شاشات قبل النوم'**
  String get dbSeedHabitScreens;

  /// Default stress-reduction habit
  ///
  /// In ar, this message translates to:
  /// **'النوم في وقت مبكر'**
  String get dbSeedHabitSleep;

  /// Default stress-reduction habit
  ///
  /// In ar, this message translates to:
  /// **'شرب الماء على مدار اليوم'**
  String get dbSeedHabitWater;

  /// Default stress-reduction habit
  ///
  /// In ar, this message translates to:
  /// **'لا كافيين بعد العصر'**
  String get dbSeedHabitCaffeine;

  /// Default stress-reduction habit
  ///
  /// In ar, this message translates to:
  /// **'تمارين إطالة خفيفة'**
  String get dbSeedHabitStretch;

  /// Default stress-reduction habit
  ///
  /// In ar, this message translates to:
  /// **'تدوين ما يشغل البال'**
  String get dbSeedHabitJournal;

  /// Default stress-reduction habit
  ///
  /// In ar, this message translates to:
  /// **'التواصل مع شخص عزيز'**
  String get dbSeedHabitConnect;

  /// SQLCipher missing on device
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تفعيل تشفير البيانات على هذا الجهاز، ولن يحفظ مَدار بياناتك دون تشفير.'**
  String get dbErrorCipherUnavailable;

  /// Wrong database key or corrupted file
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح بياناتك: مفتاح التشفير لا يطابق الملف، أو أن الملف تالف.'**
  String get dbErrorWrongKey;

  /// Key missing while a database file exists
  ///
  /// In ar, this message translates to:
  /// **'مفتاح التشفير غير موجود في المخزن الآمن، لذلك لا يمكن فتح البيانات المحفوظة.'**
  String get dbErrorKeyMissing;

  /// Stored key isn't 64 hex chars
  ///
  /// In ar, this message translates to:
  /// **'مفتاح التشفير المحفوظ تالف.'**
  String get dbErrorKeyMalformed;

  /// Secure storage read/write failed
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الوصول إلى المخزن الآمن في الجهاز.'**
  String get dbErrorKeyStorage;

  /// Snapshot has the wrong shape
  ///
  /// In ar, this message translates to:
  /// **'هذا الملف ليس نسخة احتياطية صالحة من مَدار.'**
  String get dbErrorSnapshotInvalid;

  /// Snapshot schemaVersion is newer than the app
  ///
  /// In ar, this message translates to:
  /// **'هذه النسخة الاحتياطية من إصدار أحدث من مَدار. حدّث التطبيق ثم أعد المحاولة.'**
  String get dbErrorSnapshotNewer;

  /// Restore failed and was rolled back
  ///
  /// In ar, this message translates to:
  /// **'تعذّرت استعادة النسخة الاحتياطية، وبقيت بياناتك الحالية كما هي.'**
  String get dbErrorSnapshotRejected;

  /// Fallback database error
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ غير متوقّع في حفظ البيانات.'**
  String get dbErrorUnknown;
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  Future<L10n> load(Locale locale) {
    return SynchronousFuture<L10n>(lookupL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_L10nDelegate old) => false;
}

L10n lookupL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return L10nAr();
    case 'en':
      return L10nEn();
  }

  throw FlutterError(
    'L10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
