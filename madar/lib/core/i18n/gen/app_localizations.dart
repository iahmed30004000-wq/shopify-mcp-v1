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

  /// Name of the Lapis sound profile (glass bells)
  ///
  /// In ar, this message translates to:
  /// **'أجراسٌ بلّورية'**
  String get soundProfileLapis;

  /// Name of the Emerald sound profile (wood and kalimba)
  ///
  /// In ar, this message translates to:
  /// **'خشبٌ دافئ'**
  String get soundProfileEmerald;

  /// Name of the Desert sound profile
  ///
  /// In ar, this message translates to:
  /// **'عودٌ ودفّ'**
  String get soundProfileDesert;

  /// Name of the Aurora sound profile (airy synth)
  ///
  /// In ar, this message translates to:
  /// **'وميض الشفق'**
  String get soundProfileAurora;

  /// Name of the Pearl sound profile (delicate crystal pings)
  ///
  /// In ar, this message translates to:
  /// **'رنين اللؤلؤ'**
  String get soundProfilePearl;

  /// No description provided for @soundProfileLapisDescription.
  ///
  /// In ar, this message translates to:
  /// **'أجراسٌ زجاجية صافية على مقام الراست'**
  String get soundProfileLapisDescription;

  /// No description provided for @soundProfileEmeraldDescription.
  ///
  /// In ar, this message translates to:
  /// **'كاليمبا وخشبٌ دافئ على مقام البياتي'**
  String get soundProfileEmeraldDescription;

  /// No description provided for @soundProfileDesertDescription.
  ///
  /// In ar, this message translates to:
  /// **'نقراتُ عودٍ ودفٌّ هادئ على مقام الحجاز'**
  String get soundProfileDesertDescription;

  /// No description provided for @soundProfileAuroraDescription.
  ///
  /// In ar, this message translates to:
  /// **'بريقٌ سماويّ هادئ على مقام العجم'**
  String get soundProfileAuroraDescription;

  /// No description provided for @soundProfilePearlDescription.
  ///
  /// In ar, this message translates to:
  /// **'رنينٌ بلّوريّ رقيق على مقام النهاوند'**
  String get soundProfilePearlDescription;

  /// Volume slider: taps, toggles, sheets
  ///
  /// In ar, this message translates to:
  /// **'أصوات الواجهة'**
  String get soundCategoryUi;

  /// Volume slider: deep-space ambient soundscape
  ///
  /// In ar, this message translates to:
  /// **'أجواء الفضاء'**
  String get soundCategoryAmbient;

  /// Volume slider: games music and effects
  ///
  /// In ar, this message translates to:
  /// **'الألعاب'**
  String get soundCategoryGames;

  /// Volume slider: adhan and prayer sounds
  ///
  /// In ar, this message translates to:
  /// **'الأذان والصلاة'**
  String get soundCategoryPrayer;

  /// No description provided for @soundPrayerMuteNote.
  ///
  /// In ar, this message translates to:
  /// **'تهدأ الأجواء والألعاب وقت الأذان والصلاة، وتبقى أصوات الواجهة الخافتة.'**
  String get soundPrayerMuteNote;

  /// Button that plays a sample of a sound profile
  ///
  /// In ar, this message translates to:
  /// **'استمع'**
  String get soundPreview;

  /// No description provided for @soundUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'الصوت غير متاح على هذا الجهاز'**
  String get soundUnavailable;

  /// Semantic label of the long-press context menu
  ///
  /// In ar, this message translates to:
  /// **'خيارات العنصر'**
  String get interactionMenuLabel;

  /// Barrier label of the context menu
  ///
  /// In ar, this message translates to:
  /// **'إغلاق القائمة'**
  String get interactionMenuDismiss;

  /// Semantic action that reveals the swipe tray
  ///
  /// In ar, this message translates to:
  /// **'إجراءات سريعة'**
  String get interactionQuickActions;

  /// Accessibility hint on swipe-to-complete rows
  ///
  /// In ar, this message translates to:
  /// **'اسحب نحو اليمين للإنجاز'**
  String get interactionSwipeToComplete;

  /// Semantic label of a drag handle
  ///
  /// In ar, this message translates to:
  /// **'اسحب لإعادة الترتيب'**
  String get interactionReorderHandle;

  /// No description provided for @interactionUndoAvailable.
  ///
  /// In ar, this message translates to:
  /// **'{seconds, plural, =0{انتهت مهلة التراجع} =1{يمكنك التراجع خلال ثانية واحدة} =2{يمكنك التراجع خلال ثانيتين} few{يمكنك التراجع خلال {seconds} ثوانٍ} many{يمكنك التراجع خلال {seconds} ثانية} other{يمكنك التراجع خلال {seconds} ثانية}}'**
  String interactionUndoAvailable(int seconds);

  /// Announced after an undo
  ///
  /// In ar, this message translates to:
  /// **'تمّ التراجع'**
  String get interactionUndone;

  /// No description provided for @interactionSheetGrabber.
  ///
  /// In ar, this message translates to:
  /// **'اسحب للأسفل للإغلاق'**
  String get interactionSheetGrabber;

  /// No description provided for @interactionDiscardTitle.
  ///
  /// In ar, this message translates to:
  /// **'تجاهُل التعديلات؟'**
  String get interactionDiscardTitle;

  /// No description provided for @interactionDiscardBody.
  ///
  /// In ar, this message translates to:
  /// **'لم تُحفَظ تعديلاتك بعد.'**
  String get interactionDiscardBody;

  /// No description provided for @interactionDiscardConfirm.
  ///
  /// In ar, this message translates to:
  /// **'تجاهُل'**
  String get interactionDiscardConfirm;

  /// No description provided for @interactionKeepEditing.
  ///
  /// In ar, this message translates to:
  /// **'متابعة التعديل'**
  String get interactionKeepEditing;

  /// No description provided for @interactionSaveDisabledHint.
  ///
  /// In ar, this message translates to:
  /// **'أكمل الحقول المطلوبة أولًا'**
  String get interactionSaveDisabledHint;

  /// No description provided for @interactionFieldOptional.
  ///
  /// In ar, this message translates to:
  /// **'اختياري'**
  String get interactionFieldOptional;

  /// No description provided for @interactionFieldMin.
  ///
  /// In ar, this message translates to:
  /// **'لا يقلّ عن {min}'**
  String interactionFieldMin(String min);

  /// No description provided for @interactionFieldMax.
  ///
  /// In ar, this message translates to:
  /// **'لا يزيد على {max}'**
  String interactionFieldMax(String max);

  /// No description provided for @interactionFieldDecimals.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{أدخل عددًا صحيحًا دون كسور} =1{منزلة عشرية واحدة كحدّ أقصى} =2{منزلتان عشريتان كحدّ أقصى} few{{count} منازل عشرية كحدّ أقصى} many{{count} منزلة عشرية كحدّ أقصى} other{{count} منزلة عشرية كحدّ أقصى}}'**
  String interactionFieldDecimals(int count);

  /// No description provided for @interactionFieldTooLong.
  ///
  /// In ar, this message translates to:
  /// **'النص أطول من {max} حرفًا'**
  String interactionFieldTooLong(int max);

  /// No description provided for @interactionFieldSelectAtLeast.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{اختر خيارًا واحدًا على الأقل} =2{اختر خيارين على الأقل} few{اختر {count} خيارات على الأقل} many{اختر {count} خيارًا على الأقل} other{اختر {count} خيار على الأقل}}'**
  String interactionFieldSelectAtLeast(int count);

  /// No description provided for @interactionFieldSelectAtMost.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{اختر خيارًا واحدًا فقط} =2{خياران على الأكثر} few{{count} خيارات على الأكثر} many{{count} خيارًا على الأكثر} other{{count} خيار على الأكثر}}'**
  String interactionFieldSelectAtMost(int count);

  /// No description provided for @interactionFieldDateRange.
  ///
  /// In ar, this message translates to:
  /// **'التاريخ خارج النطاق المسموح'**
  String get interactionFieldDateRange;

  /// No description provided for @interactionFieldPickDate.
  ///
  /// In ar, this message translates to:
  /// **'اختر تاريخًا'**
  String get interactionFieldPickDate;

  /// No description provided for @interactionFieldPickTime.
  ///
  /// In ar, this message translates to:
  /// **'اختر وقتًا'**
  String get interactionFieldPickTime;

  /// No description provided for @interactionFieldClear.
  ///
  /// In ar, this message translates to:
  /// **'مسح'**
  String get interactionFieldClear;

  /// No description provided for @interactionFieldAddTime.
  ///
  /// In ar, this message translates to:
  /// **'إضافة وقت'**
  String get interactionFieldAddTime;

  /// No description provided for @interactionFieldTimeExists.
  ///
  /// In ar, this message translates to:
  /// **'هذا الوقت مضاف مسبقًا'**
  String get interactionFieldTimeExists;

  /// No description provided for @interactionFieldAddOption.
  ///
  /// In ar, this message translates to:
  /// **'خيار جديد'**
  String get interactionFieldAddOption;

  /// No description provided for @interactionFieldAddOptionHint.
  ///
  /// In ar, this message translates to:
  /// **'اكتب الخيار ثم اضغط إضافة'**
  String get interactionFieldAddOptionHint;

  /// No description provided for @interactionFieldRemove.
  ///
  /// In ar, this message translates to:
  /// **'إزالة {label}'**
  String interactionFieldRemove(String label);

  /// No description provided for @interactionFieldRating.
  ///
  /// In ar, this message translates to:
  /// **'{count} من {max}'**
  String interactionFieldRating(int count, int max);

  /// No description provided for @interactionFieldIncrease.
  ///
  /// In ar, this message translates to:
  /// **'زيادة'**
  String get interactionFieldIncrease;

  /// No description provided for @interactionFieldDecrease.
  ///
  /// In ar, this message translates to:
  /// **'إنقاص'**
  String get interactionFieldDecrease;

  /// No description provided for @interactionFieldColor.
  ///
  /// In ar, this message translates to:
  /// **'لون {index}'**
  String interactionFieldColor(int index);

  /// No description provided for @interactionFieldAmount.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ'**
  String get interactionFieldAmount;

  /// No description provided for @interactionFieldCurrency.
  ///
  /// In ar, this message translates to:
  /// **'العملة'**
  String get interactionFieldCurrency;

  /// No description provided for @interactionTimeHour.
  ///
  /// In ar, this message translates to:
  /// **'الساعة'**
  String get interactionTimeHour;

  /// No description provided for @interactionTimeMinute.
  ///
  /// In ar, this message translates to:
  /// **'الدقيقة'**
  String get interactionTimeMinute;

  /// No description provided for @interactionDateToday.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get interactionDateToday;

  /// No description provided for @interactionDateTomorrow.
  ///
  /// In ar, this message translates to:
  /// **'غدًا'**
  String get interactionDateTomorrow;

  /// No description provided for @interactionDateDayAfter.
  ///
  /// In ar, this message translates to:
  /// **'بعد غد'**
  String get interactionDateDayAfter;

  /// No description provided for @interactionDateYesterday.
  ///
  /// In ar, this message translates to:
  /// **'أمس'**
  String get interactionDateYesterday;

  /// No description provided for @interactionCurrencyJOD.
  ///
  /// In ar, this message translates to:
  /// **'دينار أردني'**
  String get interactionCurrencyJOD;

  /// No description provided for @interactionCurrencyUSD.
  ///
  /// In ar, this message translates to:
  /// **'دولار أمريكي'**
  String get interactionCurrencyUSD;

  /// No description provided for @interactionCurrencySYP.
  ///
  /// In ar, this message translates to:
  /// **'ليرة سورية'**
  String get interactionCurrencySYP;

  /// No description provided for @interactionCurrencyEGP.
  ///
  /// In ar, this message translates to:
  /// **'جنيه مصري'**
  String get interactionCurrencyEGP;

  /// No description provided for @interactionCurrencyLYD.
  ///
  /// In ar, this message translates to:
  /// **'دينار ليبي'**
  String get interactionCurrencyLYD;

  /// No description provided for @interactionCurrencySymbolJOD.
  ///
  /// In ar, this message translates to:
  /// **'د.أ'**
  String get interactionCurrencySymbolJOD;

  /// No description provided for @interactionCurrencySymbolUSD.
  ///
  /// In ar, this message translates to:
  /// **'\$'**
  String get interactionCurrencySymbolUSD;

  /// No description provided for @interactionCurrencySymbolSYP.
  ///
  /// In ar, this message translates to:
  /// **'ل.س'**
  String get interactionCurrencySymbolSYP;

  /// No description provided for @interactionCurrencySymbolEGP.
  ///
  /// In ar, this message translates to:
  /// **'ج.م'**
  String get interactionCurrencySymbolEGP;

  /// No description provided for @interactionCurrencySymbolLYD.
  ///
  /// In ar, this message translates to:
  /// **'د.ل'**
  String get interactionCurrencySymbolLYD;

  /// No description provided for @interactionMoveSearch.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن وجهة'**
  String get interactionMoveSearch;

  /// No description provided for @interactionMoveCurrent.
  ///
  /// In ar, this message translates to:
  /// **'الحالي'**
  String get interactionMoveCurrent;

  /// No description provided for @interactionMoveEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا وجهة تطابق بحثك'**
  String get interactionMoveEmpty;

  /// No description provided for @interactionReminderTitle.
  ///
  /// In ar, this message translates to:
  /// **'متى أذكّرك؟'**
  String get interactionReminderTitle;

  /// No description provided for @interactionReminderKindOnce.
  ///
  /// In ar, this message translates to:
  /// **'مرة واحدة'**
  String get interactionReminderKindOnce;

  /// No description provided for @interactionReminderKindDaily.
  ///
  /// In ar, this message translates to:
  /// **'يوميًا'**
  String get interactionReminderKindDaily;

  /// No description provided for @interactionReminderKindWeekly.
  ///
  /// In ar, this message translates to:
  /// **'أسبوعيًا'**
  String get interactionReminderKindWeekly;

  /// No description provided for @interactionReminderKindPrayer.
  ///
  /// In ar, this message translates to:
  /// **'مع الصلاة'**
  String get interactionReminderKindPrayer;

  /// No description provided for @interactionReminderKindBeforeDue.
  ///
  /// In ar, this message translates to:
  /// **'قبل الموعد'**
  String get interactionReminderKindBeforeDue;

  /// No description provided for @interactionReminderDate.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get interactionReminderDate;

  /// No description provided for @interactionReminderTime.
  ///
  /// In ar, this message translates to:
  /// **'الوقت'**
  String get interactionReminderTime;

  /// No description provided for @interactionReminderDays.
  ///
  /// In ar, this message translates to:
  /// **'الأيام'**
  String get interactionReminderDays;

  /// No description provided for @interactionReminderPrayer.
  ///
  /// In ar, this message translates to:
  /// **'الصلاة'**
  String get interactionReminderPrayer;

  /// No description provided for @interactionReminderOffset.
  ///
  /// In ar, this message translates to:
  /// **'التوقيت حول الصلاة'**
  String get interactionReminderOffset;

  /// No description provided for @interactionReminderLead.
  ///
  /// In ar, this message translates to:
  /// **'قبل الموعد بـ'**
  String get interactionReminderLead;

  /// No description provided for @interactionReminderPast.
  ///
  /// In ar, this message translates to:
  /// **'هذا الوقت مضى، اختر وقتًا قادمًا'**
  String get interactionReminderPast;

  /// No description provided for @interactionReminderNoDays.
  ///
  /// In ar, this message translates to:
  /// **'اختر يومًا واحدًا على الأقل'**
  String get interactionReminderNoDays;

  /// No description provided for @interactionReminderPrayerAt.
  ///
  /// In ar, this message translates to:
  /// **'عند {prayer}'**
  String interactionReminderPrayerAt(String prayer);

  /// No description provided for @interactionReminderPrayerAfter.
  ///
  /// In ar, this message translates to:
  /// **'بعد {prayer} بـ{duration}'**
  String interactionReminderPrayerAfter(String prayer, String duration);

  /// No description provided for @interactionReminderPrayerBefore.
  ///
  /// In ar, this message translates to:
  /// **'قبل {prayer} بـ{duration}'**
  String interactionReminderPrayerBefore(String prayer, String duration);

  /// No description provided for @interactionReminderBefore.
  ///
  /// In ar, this message translates to:
  /// **'قبل {duration}'**
  String interactionReminderBefore(String duration);

  /// No description provided for @interactionReminderDaily.
  ///
  /// In ar, this message translates to:
  /// **'كل يوم الساعة {time}'**
  String interactionReminderDaily(String time);

  /// No description provided for @interactionReminderOnce.
  ///
  /// In ar, this message translates to:
  /// **'{date} الساعة {time}'**
  String interactionReminderOnce(String date, String time);

  /// No description provided for @interactionDurationMinutes.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{دقيقة} =2{دقيقتين} few{{count} دقائق} many{{count} دقيقة} other{{count} دقيقة}}'**
  String interactionDurationMinutes(int count);

  /// No description provided for @interactionDurationHours.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{ساعة} =2{ساعتين} few{{count} ساعات} many{{count} ساعة} other{{count} ساعة}}'**
  String interactionDurationHours(int count);

  /// No description provided for @interactionDurationDays.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{يوم} =2{يومين} few{{count} أيام} many{{count} يومًا} other{{count} يوم}}'**
  String interactionDurationDays(int count);

  /// No description provided for @interactionDurationWeeks.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{أسبوع} =2{أسبوعين} few{{count} أسابيع} many{{count} أسبوعًا} other{{count} أسبوع}}'**
  String interactionDurationWeeks(int count);

  /// No description provided for @interactionWeekdayMon.
  ///
  /// In ar, this message translates to:
  /// **'إثنين'**
  String get interactionWeekdayMon;

  /// No description provided for @interactionWeekdayTue.
  ///
  /// In ar, this message translates to:
  /// **'ثلاثاء'**
  String get interactionWeekdayTue;

  /// No description provided for @interactionWeekdayWed.
  ///
  /// In ar, this message translates to:
  /// **'أربعاء'**
  String get interactionWeekdayWed;

  /// No description provided for @interactionWeekdayThu.
  ///
  /// In ar, this message translates to:
  /// **'خميس'**
  String get interactionWeekdayThu;

  /// No description provided for @interactionWeekdayFri.
  ///
  /// In ar, this message translates to:
  /// **'جمعة'**
  String get interactionWeekdayFri;

  /// No description provided for @interactionWeekdaySat.
  ///
  /// In ar, this message translates to:
  /// **'سبت'**
  String get interactionWeekdaySat;

  /// No description provided for @interactionWeekdaySun.
  ///
  /// In ar, this message translates to:
  /// **'أحد'**
  String get interactionWeekdaySun;

  /// No description provided for @interactionQuickAddHint.
  ///
  /// In ar, this message translates to:
  /// **'اكتب ما يدور في بالك… «صرفت ٥ دنانير قهوة»'**
  String get interactionQuickAddHint;

  /// No description provided for @interactionQuickAddLabel.
  ///
  /// In ar, this message translates to:
  /// **'إضافة سريعة'**
  String get interactionQuickAddLabel;

  /// No description provided for @interactionQuickAddUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'الإضافة السريعة ليست جاهزة بعد'**
  String get interactionQuickAddUnavailable;

  /// No description provided for @interactionQuickAddFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّرت الإضافة، حاول مرة أخرى'**
  String get interactionQuickAddFailed;

  /// No description provided for @interactionQuickAddEmpty.
  ///
  /// In ar, this message translates to:
  /// **'اكتب شيئًا أولًا'**
  String get interactionQuickAddEmpty;

  /// No description provided for @interactionQuickAddAdded.
  ///
  /// In ar, this message translates to:
  /// **'أُضيف إلى مداره'**
  String get interactionQuickAddAdded;

  /// No description provided for @interactionQuickAddAt.
  ///
  /// In ar, this message translates to:
  /// **'الساعة {time}'**
  String interactionQuickAddAt(String time);

  /// No description provided for @interactionQuickAddMl.
  ///
  /// In ar, this message translates to:
  /// **'{ml} مل'**
  String interactionQuickAddMl(String ml);

  /// No description provided for @interactionQuickAddScore.
  ///
  /// In ar, this message translates to:
  /// **'{score} من {max}'**
  String interactionQuickAddScore(String score, int max);

  /// No description provided for @interactionKindTask.
  ///
  /// In ar, this message translates to:
  /// **'مهمة'**
  String get interactionKindTask;

  /// No description provided for @interactionKindExpense.
  ///
  /// In ar, this message translates to:
  /// **'مصروف'**
  String get interactionKindExpense;

  /// No description provided for @interactionKindIncome.
  ///
  /// In ar, this message translates to:
  /// **'دخل'**
  String get interactionKindIncome;

  /// No description provided for @interactionKindWater.
  ///
  /// In ar, this message translates to:
  /// **'ماء'**
  String get interactionKindWater;

  /// No description provided for @interactionKindPain.
  ///
  /// In ar, this message translates to:
  /// **'ألم'**
  String get interactionKindPain;

  /// No description provided for @interactionKindMood.
  ///
  /// In ar, this message translates to:
  /// **'مزاج'**
  String get interactionKindMood;

  /// No description provided for @interactionKindContact.
  ///
  /// In ar, this message translates to:
  /// **'تواصل'**
  String get interactionKindContact;

  /// No description provided for @interactionKindNote.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة'**
  String get interactionKindNote;
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
