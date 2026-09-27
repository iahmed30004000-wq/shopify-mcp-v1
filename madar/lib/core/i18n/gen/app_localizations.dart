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
  /// **'التاريخ'**
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

  /// No description provided for @interactionReminderRelBefore.
  ///
  /// In ar, this message translates to:
  /// **'قبلها'**
  String get interactionReminderRelBefore;

  /// No description provided for @interactionReminderRelAt.
  ///
  /// In ar, this message translates to:
  /// **'في وقتها'**
  String get interactionReminderRelAt;

  /// No description provided for @interactionReminderRelAfter.
  ///
  /// In ar, this message translates to:
  /// **'بعدها'**
  String get interactionReminderRelAfter;

  /// No description provided for @interactionReminderWeekly.
  ///
  /// In ar, this message translates to:
  /// **'{days} الساعة {time}'**
  String interactionReminderWeekly(String days, String time);

  /// No description provided for @interactionReminderWorkdays.
  ///
  /// In ar, this message translates to:
  /// **'أيام الدوام'**
  String get interactionReminderWorkdays;

  /// No description provided for @interactionReminderEveryDay.
  ///
  /// In ar, this message translates to:
  /// **'كل الأيام'**
  String get interactionReminderEveryDay;

  /// No description provided for @interactionReminderRemove.
  ///
  /// In ar, this message translates to:
  /// **'إزالة التذكير'**
  String get interactionReminderRemove;

  /// No description provided for @interactionReminderNoDue.
  ///
  /// In ar, this message translates to:
  /// **'لا موعد نهائي لهذا العنصر'**
  String get interactionReminderNoDue;

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

  /// Separator between items of an inline list
  ///
  /// In ar, this message translates to:
  /// **'، '**
  String get interactionListSeparator;

  /// No description provided for @interactionQuickAddPreview.
  ///
  /// In ar, this message translates to:
  /// **'هكذا فهمتُها'**
  String get interactionQuickAddPreview;

  /// No description provided for @interactionTrayLabel.
  ///
  /// In ar, this message translates to:
  /// **'إجراءات سريعة مفتوحة'**
  String get interactionTrayLabel;

  /// Import screen title
  ///
  /// In ar, this message translates to:
  /// **'استيراد البيانات'**
  String get importTitle;

  /// No description provided for @importHeroTitle.
  ///
  /// In ar, this message translates to:
  /// **'أعِد بياناتك إلى مَدارها'**
  String get importHeroTitle;

  /// No description provided for @importHeroBody.
  ///
  /// In ar, this message translates to:
  /// **'اختر ملف JSON الذي صدّرته من النسخة التجريبية، أو الصق محتواه. نحلّله أولًا ونريك كل شيء قبل أن يُكتب سطر واحد.'**
  String get importHeroBody;

  /// No description provided for @importPickFile.
  ///
  /// In ar, this message translates to:
  /// **'اختيار ملف JSON'**
  String get importPickFile;

  /// No description provided for @importPasteToggle.
  ///
  /// In ar, this message translates to:
  /// **'لصق نص JSON'**
  String get importPasteToggle;

  /// No description provided for @importPasteHint.
  ///
  /// In ar, this message translates to:
  /// **'الصق محتوى الملف هنا…'**
  String get importPasteHint;

  /// No description provided for @importAnalyzeAction.
  ///
  /// In ar, this message translates to:
  /// **'تحليل'**
  String get importAnalyzeAction;

  /// No description provided for @importAnalyzing.
  ///
  /// In ar, this message translates to:
  /// **'نقرأ ملفك ونرسم خريطته…'**
  String get importAnalyzing;

  /// No description provided for @importAcceptedHint.
  ///
  /// In ar, this message translates to:
  /// **'نقبل تصدير النسخة التجريبية (data و logs) أو أقسامًا مباشرة، بمفاتيح عربية أو إنجليزية. لا يضيع شيء: ما لا نعرفه يُحفظ في الأرشيف.'**
  String get importAcceptedHint;

  /// No description provided for @importFileLabel.
  ///
  /// In ar, this message translates to:
  /// **'الملف'**
  String get importFileLabel;

  /// No description provided for @importPastedLabel.
  ///
  /// In ar, this message translates to:
  /// **'نص ملصوق'**
  String get importPastedLabel;

  /// No description provided for @importPreviewTitle.
  ///
  /// In ar, this message translates to:
  /// **'ما وجدناه'**
  String get importPreviewTitle;

  /// Caption under the big record count (the number itself is shown above it)
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا سجلات للاستيراد} =1{سجل جاهز للاستيراد} =2{سجلان جاهزان للاستيراد} few{سجلات جاهزة للاستيراد} many{سجلًا جاهزًا للاستيراد} other{سجل جاهز للاستيراد}}'**
  String importRecordsReady(int count);

  /// No description provided for @importShapeTitle.
  ///
  /// In ar, this message translates to:
  /// **'بنية الملف'**
  String get importShapeTitle;

  /// No description provided for @importShapeWrapped.
  ///
  /// In ar, this message translates to:
  /// **'بيانات + سجلات'**
  String get importShapeWrapped;

  /// No description provided for @importShapeDataOnly.
  ///
  /// In ar, this message translates to:
  /// **'بيانات فقط'**
  String get importShapeDataOnly;

  /// No description provided for @importShapeLogsOnly.
  ///
  /// In ar, this message translates to:
  /// **'سجلات فقط'**
  String get importShapeLogsOnly;

  /// No description provided for @importShapeFlat.
  ///
  /// In ar, this message translates to:
  /// **'أقسام مباشرة'**
  String get importShapeFlat;

  /// No description provided for @importShapeList.
  ///
  /// In ar, this message translates to:
  /// **'قائمة سجلات'**
  String get importShapeList;

  /// No description provided for @importShapeNested.
  ///
  /// In ar, this message translates to:
  /// **'مجمّعة حسب المجال'**
  String get importShapeNested;

  /// No description provided for @importShapeDayKeyed.
  ///
  /// In ar, this message translates to:
  /// **'سجلات مرتّبة بالأيام'**
  String get importShapeDayKeyed;

  /// No description provided for @importShapeTyped.
  ///
  /// In ar, this message translates to:
  /// **'أحداث مصنّفة'**
  String get importShapeTyped;

  /// No description provided for @importShapeIdKeyed.
  ///
  /// In ar, this message translates to:
  /// **'مفهرسة بالمعرّفات'**
  String get importShapeIdKeyed;

  /// No description provided for @importKeysArabic.
  ///
  /// In ar, this message translates to:
  /// **'مفاتيح عربية'**
  String get importKeysArabic;

  /// No description provided for @importKeysCamel.
  ///
  /// In ar, this message translates to:
  /// **'مفاتيح camelCase'**
  String get importKeysCamel;

  /// No description provided for @importKeysSnake.
  ///
  /// In ar, this message translates to:
  /// **'مفاتيح snake_case'**
  String get importKeysSnake;

  /// No description provided for @importKeysMixed.
  ///
  /// In ar, this message translates to:
  /// **'مفاتيح مختلطة'**
  String get importKeysMixed;

  /// No description provided for @importSectionsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الأقسام'**
  String get importSectionsTitle;

  /// No description provided for @importBudgetTotal.
  ///
  /// In ar, this message translates to:
  /// **'مجموع الميزانية الشهرية: {amount}'**
  String importBudgetTotal(String amount);

  /// No description provided for @importModulesTitle.
  ///
  /// In ar, this message translates to:
  /// **'وحدات جديدة من بيانات غير معروفة'**
  String get importModulesTitle;

  /// No description provided for @importModulesBody.
  ///
  /// In ar, this message translates to:
  /// **'لم نتعرّف على هذه الأقسام، فحوّلناها إلى وحدات مخصّصة كي لا يضيع منها شيء.'**
  String get importModulesBody;

  /// No description provided for @importModuleEntries.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{بلا إدخالات} =1{إدخال واحد} =2{إدخالان} few{{count} إدخالات} many{{count} إدخالًا} other{{count} إدخال}}'**
  String importModuleEntries(int count);

  /// No description provided for @importWarningsTitle.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات قبل الاستيراد'**
  String get importWarningsTitle;

  /// No description provided for @importUnmappedTitle.
  ///
  /// In ar, this message translates to:
  /// **'محفوظ في الأرشيف'**
  String get importUnmappedTitle;

  /// No description provided for @importUnmappedBody.
  ///
  /// In ar, this message translates to:
  /// **'قيم لا مكان لها في مَدار بعد؛ تُحفظ كما هي مع النسخة الأصلية من الملف.'**
  String get importUnmappedBody;

  /// No description provided for @importTimesCount.
  ///
  /// In ar, this message translates to:
  /// **'×{count}'**
  String importTimesCount(String count);

  /// No description provided for @importDuplicateTitle.
  ///
  /// In ar, this message translates to:
  /// **'استوردت هذا الملف من قبل'**
  String get importDuplicateTitle;

  /// No description provided for @importDuplicateBody.
  ///
  /// In ar, this message translates to:
  /// **'كان ذلك في {date}. لن تتكرر السجلات الموجودة؛ ستُضاف الجديدة فقط.'**
  String importDuplicateBody(String date);

  /// No description provided for @importDuplicateAnyway.
  ///
  /// In ar, this message translates to:
  /// **'استيراد على أي حال'**
  String get importDuplicateAnyway;

  /// No description provided for @importStartAction.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{حفظ في الأرشيف} =1{استيراد سجل واحد} =2{استيراد سجلين} few{استيراد {count} سجلات} many{استيراد {count} سجلًا} other{استيراد {count} سجل}}'**
  String importStartAction(int count);

  /// No description provided for @importChooseAnother.
  ///
  /// In ar, this message translates to:
  /// **'ملف آخر'**
  String get importChooseAnother;

  /// No description provided for @importWriting.
  ///
  /// In ar, this message translates to:
  /// **'نكتب بياناتك في مَدارها…'**
  String get importWriting;

  /// No description provided for @importDoneTitle.
  ///
  /// In ar, this message translates to:
  /// **'اكتمل الاستيراد'**
  String get importDoneTitle;

  /// No description provided for @importDoneBody.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لم يُضف أي سجل جديد} =1{أُضيف سجل واحد} =2{أُضيف سجلان} few{أُضيفت {count} سجلات} many{أُضيف {count} سجلًا} other{أُضيف {count} سجل}}'**
  String importDoneBody(int count);

  /// No description provided for @importDoneExisting.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{سجل واحد كان موجودًا فتُرك كما هو} =2{سجلان كانا موجودَين فتُركا كما هما} few{{count} سجلات كانت موجودة فتُركت كما هي} many{{count} سجلًا كانت موجودة فتُركت كما هي} other{{count} سجل كانت موجودة فتُركت كما هي}}'**
  String importDoneExisting(int count);

  /// No description provided for @importDoneArchived.
  ///
  /// In ar, this message translates to:
  /// **'حُفظت نسخة أصلية كاملة من الملف في الأرشيف.'**
  String get importDoneArchived;

  /// No description provided for @importErrorInvalidJson.
  ///
  /// In ar, this message translates to:
  /// **'هذا ليس نص JSON صالحًا.'**
  String get importErrorInvalidJson;

  /// No description provided for @importErrorEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد محتوى لاستيراده.'**
  String get importErrorEmpty;

  /// No description provided for @importErrorNotObject.
  ///
  /// In ar, this message translates to:
  /// **'الملف لا يحتوي على بيانات قابلة للاستيراد.'**
  String get importErrorNotObject;

  /// No description provided for @importErrorRead.
  ///
  /// In ar, this message translates to:
  /// **'تعذّرت قراءة الملف.'**
  String get importErrorRead;

  /// No description provided for @importErrorCommit.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الاستيراد، ولم يتغيّر شيء في بياناتك.'**
  String get importErrorCommit;

  /// No description provided for @importNothingFound.
  ///
  /// In ar, this message translates to:
  /// **'لم نجد في هذا الملف بيانات نعرفها، لكنه سيُحفظ كاملًا في الأرشيف.'**
  String get importNothingFound;

  /// No description provided for @importTryAgain.
  ///
  /// In ar, this message translates to:
  /// **'حاول مجددًا'**
  String get importTryAgain;

  /// Name of the wallet created for imported transactions that name none
  ///
  /// In ar, this message translates to:
  /// **'المحفظة الرئيسية'**
  String get importDefaultWallet;

  /// Name of the board created for imported cards that name none
  ///
  /// In ar, this message translates to:
  /// **'العمل'**
  String get importDefaultBoard;

  /// Note of the deposit created from a jar's saved amount
  ///
  /// In ar, this message translates to:
  /// **'الرصيد الافتتاحي'**
  String get importOpeningBalance;

  /// No description provided for @importColumnTodo.
  ///
  /// In ar, this message translates to:
  /// **'للإنجاز'**
  String get importColumnTodo;

  /// No description provided for @importColumnDoing.
  ///
  /// In ar, this message translates to:
  /// **'قيد العمل'**
  String get importColumnDoing;

  /// No description provided for @importColumnDone.
  ///
  /// In ar, this message translates to:
  /// **'منجز'**
  String get importColumnDone;

  /// No description provided for @importSectionHealthAlerts.
  ///
  /// In ar, this message translates to:
  /// **'تنبيهات صحية'**
  String get importSectionHealthAlerts;

  /// No description provided for @importSectionConditions.
  ///
  /// In ar, this message translates to:
  /// **'الحالات الصحية'**
  String get importSectionConditions;

  /// No description provided for @importSectionMedications.
  ///
  /// In ar, this message translates to:
  /// **'الأدوية والمكمّلات'**
  String get importSectionMedications;

  /// No description provided for @importSectionMedDoses.
  ///
  /// In ar, this message translates to:
  /// **'سجل الجرعات'**
  String get importSectionMedDoses;

  /// No description provided for @importSectionLabTests.
  ///
  /// In ar, this message translates to:
  /// **'التحاليل'**
  String get importSectionLabTests;

  /// No description provided for @importSectionLabReadings.
  ///
  /// In ar, this message translates to:
  /// **'نتائج التحاليل'**
  String get importSectionLabReadings;

  /// No description provided for @importSectionAppointments.
  ///
  /// In ar, this message translates to:
  /// **'المواعيد الطبية'**
  String get importSectionAppointments;

  /// No description provided for @importSectionDoctorQuestions.
  ///
  /// In ar, this message translates to:
  /// **'أسئلة للطبيب'**
  String get importSectionDoctorQuestions;

  /// No description provided for @importSectionPainEntries.
  ///
  /// In ar, this message translates to:
  /// **'سجل الألم'**
  String get importSectionPainEntries;

  /// No description provided for @importSectionMoodEntries.
  ///
  /// In ar, this message translates to:
  /// **'المزاج والتوتر'**
  String get importSectionMoodEntries;

  /// No description provided for @importSectionHabits.
  ///
  /// In ar, this message translates to:
  /// **'العادات'**
  String get importSectionHabits;

  /// No description provided for @importSectionHabitLogs.
  ///
  /// In ar, this message translates to:
  /// **'سجل العادات'**
  String get importSectionHabitLogs;

  /// No description provided for @importSectionWorries.
  ///
  /// In ar, this message translates to:
  /// **'المخاوف'**
  String get importSectionWorries;

  /// No description provided for @importSectionCurrencies.
  ///
  /// In ar, this message translates to:
  /// **'العملات'**
  String get importSectionCurrencies;

  /// No description provided for @importSectionWallets.
  ///
  /// In ar, this message translates to:
  /// **'المحافظ'**
  String get importSectionWallets;

  /// No description provided for @importSectionBudgetItems.
  ///
  /// In ar, this message translates to:
  /// **'بنود الميزانية'**
  String get importSectionBudgetItems;

  /// No description provided for @importSectionTransactions.
  ///
  /// In ar, this message translates to:
  /// **'المعاملات'**
  String get importSectionTransactions;

  /// No description provided for @importSectionJars.
  ///
  /// In ar, this message translates to:
  /// **'الحصّالات'**
  String get importSectionJars;

  /// No description provided for @importSectionJarDeposits.
  ///
  /// In ar, this message translates to:
  /// **'إيداعات الحصّالات'**
  String get importSectionJarDeposits;

  /// No description provided for @importSectionDebts.
  ///
  /// In ar, this message translates to:
  /// **'الديون'**
  String get importSectionDebts;

  /// No description provided for @importSectionDebtPayments.
  ///
  /// In ar, this message translates to:
  /// **'سداد الديون'**
  String get importSectionDebtPayments;

  /// No description provided for @importSectionObligations.
  ///
  /// In ar, this message translates to:
  /// **'الالتزامات الدورية'**
  String get importSectionObligations;

  /// No description provided for @importSectionPeople.
  ///
  /// In ar, this message translates to:
  /// **'الأشخاص'**
  String get importSectionPeople;

  /// No description provided for @importSectionContactLogs.
  ///
  /// In ar, this message translates to:
  /// **'سجل التواصل'**
  String get importSectionContactLogs;

  /// No description provided for @importSectionProjects.
  ///
  /// In ar, this message translates to:
  /// **'المشاريع'**
  String get importSectionProjects;

  /// No description provided for @importSectionProjectItems.
  ///
  /// In ar, this message translates to:
  /// **'مهام المشاريع'**
  String get importSectionProjectItems;

  /// No description provided for @importSectionBoards.
  ///
  /// In ar, this message translates to:
  /// **'لوحات العمل'**
  String get importSectionBoards;

  /// No description provided for @importSectionBoardCards.
  ///
  /// In ar, this message translates to:
  /// **'بطاقات العمل'**
  String get importSectionBoardCards;

  /// No description provided for @importSectionTrips.
  ///
  /// In ar, this message translates to:
  /// **'الرحلات'**
  String get importSectionTrips;

  /// No description provided for @importSectionTripItems.
  ///
  /// In ar, this message translates to:
  /// **'قوائم التجهيز'**
  String get importSectionTripItems;

  /// No description provided for @importSectionTravelDocuments.
  ///
  /// In ar, this message translates to:
  /// **'وثائق السفر'**
  String get importSectionTravelDocuments;

  /// No description provided for @importSectionLearningGoals.
  ///
  /// In ar, this message translates to:
  /// **'أهداف التعلّم'**
  String get importSectionLearningGoals;

  /// No description provided for @importSectionGoalLogs.
  ///
  /// In ar, this message translates to:
  /// **'سجل التقدّم'**
  String get importSectionGoalLogs;

  /// No description provided for @importSectionExercises.
  ///
  /// In ar, this message translates to:
  /// **'التمارين'**
  String get importSectionExercises;

  /// No description provided for @importSectionWorkoutLogs.
  ///
  /// In ar, this message translates to:
  /// **'سجل التمارين'**
  String get importSectionWorkoutLogs;

  /// No description provided for @importSectionAvoidItems.
  ///
  /// In ar, this message translates to:
  /// **'قائمة التجنّب'**
  String get importSectionAvoidItems;

  /// No description provided for @importSectionFastingSessions.
  ///
  /// In ar, this message translates to:
  /// **'الصيام'**
  String get importSectionFastingSessions;

  /// No description provided for @importSectionWaterLogs.
  ///
  /// In ar, this message translates to:
  /// **'الماء'**
  String get importSectionWaterLogs;

  /// No description provided for @importSectionPrayerLogs.
  ///
  /// In ar, this message translates to:
  /// **'سجل الصلاة'**
  String get importSectionPrayerLogs;

  /// No description provided for @importSectionTasks.
  ///
  /// In ar, this message translates to:
  /// **'المهام'**
  String get importSectionTasks;

  /// No description provided for @importSectionCustomModules.
  ///
  /// In ar, this message translates to:
  /// **'وحدات مخصّصة'**
  String get importSectionCustomModules;

  /// No description provided for @importSectionCustomEntries.
  ///
  /// In ar, this message translates to:
  /// **'إدخالات الوحدات'**
  String get importSectionCustomEntries;

  /// No description provided for @importIssueInvalidJson.
  ///
  /// In ar, this message translates to:
  /// **'نص JSON غير صالح'**
  String get importIssueInvalidJson;

  /// No description provided for @importIssueEmptyInput.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد محتوى'**
  String get importIssueEmptyInput;

  /// No description provided for @importIssueNotAnObject.
  ///
  /// In ar, this message translates to:
  /// **'لا بيانات قابلة للاستيراد'**
  String get importIssueNotAnObject;

  /// No description provided for @importIssueUnparsedDate.
  ///
  /// In ar, this message translates to:
  /// **'تواريخ لم نستطع قراءتها'**
  String get importIssueUnparsedDate;

  /// No description provided for @importIssueUnparsedAmount.
  ///
  /// In ar, this message translates to:
  /// **'مبالغ لم نستطع قراءتها'**
  String get importIssueUnparsedAmount;

  /// No description provided for @importIssueUnparsedTime.
  ///
  /// In ar, this message translates to:
  /// **'أوقات لم نستطع قراءتها'**
  String get importIssueUnparsedTime;

  /// No description provided for @importIssueUnparsedNumber.
  ///
  /// In ar, this message translates to:
  /// **'أرقام لم نستطع قراءتها'**
  String get importIssueUnparsedNumber;

  /// No description provided for @importIssueInferredTime.
  ///
  /// In ar, this message translates to:
  /// **'أوقات استنتجناها من كلمات (صباحًا ← ٨:٠٠)'**
  String get importIssueInferredTime;

  /// No description provided for @importIssueMissingRequired.
  ///
  /// In ar, this message translates to:
  /// **'سجلات تنقصها قيمة أساسية فلم تُستورد، وهي محفوظة في الأرشيف'**
  String get importIssueMissingRequired;

  /// No description provided for @importIssueUnresolvedReference.
  ///
  /// In ar, this message translates to:
  /// **'إشارات إلى عناصر غير موجودة'**
  String get importIssueUnresolvedReference;

  /// No description provided for @importIssueCreatedReference.
  ///
  /// In ar, this message translates to:
  /// **'عناصر أنشأناها من أسمائها'**
  String get importIssueCreatedReference;

  /// No description provided for @importIssueUnknownValue.
  ///
  /// In ar, this message translates to:
  /// **'قيم غير معروفة استبدلنا بها الافتراضي'**
  String get importIssueUnknownValue;

  /// No description provided for @importIssueAssumedGlasses.
  ///
  /// In ar, this message translates to:
  /// **'كميات ماء قرأناها أكوابًا (٢٥٠ مل)'**
  String get importIssueAssumedGlasses;

  /// No description provided for @importIssueAssumedFastingTarget.
  ///
  /// In ar, this message translates to:
  /// **'أهداف صيام مفترضة'**
  String get importIssueAssumedFastingTarget;

  /// No description provided for @importIssueAssumedDate.
  ///
  /// In ar, this message translates to:
  /// **'تواريخ مفترضة'**
  String get importIssueAssumedDate;

  /// No description provided for @importIssueAssumedValue.
  ///
  /// In ar, this message translates to:
  /// **'قيم مفترضة'**
  String get importIssueAssumedValue;

  /// No description provided for @importIssueCurrencyWallet.
  ///
  /// In ar, this message translates to:
  /// **'محافظ أنشأناها لعملات مختلفة (دون تحويل)'**
  String get importIssueCurrencyWallet;

  /// No description provided for @importIssueMissingRate.
  ///
  /// In ar, this message translates to:
  /// **'عملات بلا سعر صرف (افترضنا ١) — عدّلها من الإعدادات'**
  String get importIssueMissingRate;

  /// No description provided for @importIssueDuplicateSourceId.
  ///
  /// In ar, this message translates to:
  /// **'معرّفات مكرّرة في الملف'**
  String get importIssueDuplicateSourceId;

  /// No description provided for @importIssueBudget.
  ///
  /// In ar, this message translates to:
  /// **'فحوص الميزانية'**
  String get importIssueBudget;

  /// No description provided for @importIssueDuplicateFile.
  ///
  /// In ar, this message translates to:
  /// **'ملف مستورد من قبل'**
  String get importIssueDuplicateFile;

  /// No description provided for @importIssueSettingRead.
  ///
  /// In ar, this message translates to:
  /// **'إعدادات قرأناها من الملف'**
  String get importIssueSettingRead;

  /// No description provided for @importBudgetChildrenUnder.
  ///
  /// In ar, this message translates to:
  /// **'بنود «{name}» أقل منه بـ {amount}'**
  String importBudgetChildrenUnder(String name, String amount);

  /// No description provided for @importBudgetChildrenOver.
  ///
  /// In ar, this message translates to:
  /// **'بنود «{name}» تزيد عليه بـ {amount}'**
  String importBudgetChildrenOver(String name, String amount);

  /// No description provided for @importBudgetPercentOver.
  ///
  /// In ar, this message translates to:
  /// **'نِسَب «{name}» تتجاوز ١٠٠٪ ({percent})'**
  String importBudgetPercentOver(String name, String percent);

  /// No description provided for @importBudgetCircular.
  ///
  /// In ar, this message translates to:
  /// **'نِسَب «{name}» تعتمد على نفسها'**
  String importBudgetCircular(String name);

  /// No description provided for @importBudgetStructure.
  ///
  /// In ar, this message translates to:
  /// **'«{name}» مرتبط ببند غير صالح، فجعلناه بندًا رئيسيًا'**
  String importBudgetStructure(String name);

  /// No description provided for @importBudgetMissingRate.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد سعر صرف لـ {currency}'**
  String importBudgetMissingRate(String currency);

  /// No description provided for @importBudgetWhole.
  ///
  /// In ar, this message translates to:
  /// **'الميزانية كلها'**
  String get importBudgetWhole;

  /// Splash caption while the encrypted database opens
  ///
  /// In ar, this message translates to:
  /// **'نُركّب أسطرلابك…'**
  String get shellSplashAssembling;

  /// Screen-reader label of the splash
  ///
  /// In ar, this message translates to:
  /// **'يجري فتح بياناتك المشفّرة'**
  String get shellSplashSemantics;

  /// Title of the database-unlock error view
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح مَدار'**
  String get shellGateErrorTitle;

  /// No description provided for @shellGateRetry.
  ///
  /// In ar, this message translates to:
  /// **'أعِد المحاولة'**
  String get shellGateRetry;

  /// Offers deleting the unreadable database
  ///
  /// In ar, this message translates to:
  /// **'ابدأ من جديد'**
  String get shellGateReset;

  /// No description provided for @shellGateResetTitle.
  ///
  /// In ar, this message translates to:
  /// **'حذف جميع البيانات؟'**
  String get shellGateResetTitle;

  /// No description provided for @shellGateResetBody.
  ///
  /// In ar, this message translates to:
  /// **'سيُحذف ملف البيانات المشفّر نهائيًا ويبدأ مَدار من الصفر، ولا يمكن التراجع عن ذلك. إن لم تكن لديك نسخة احتياطية فلن تعود بياناتك القديمة.'**
  String get shellGateResetBody;

  /// No description provided for @shellGateResetConfirm.
  ///
  /// In ar, this message translates to:
  /// **'احذف وابدأ من جديد'**
  String get shellGateResetConfirm;

  /// No description provided for @shellGateResetFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر حذف البيانات. أعد تشغيل التطبيق ثم حاول مجددًا.'**
  String get shellGateResetFailed;

  /// Compact duration; numbers are pre-formatted
  ///
  /// In ar, this message translates to:
  /// **'{hours} س {minutes} د'**
  String shellDurationHoursMinutes(String hours, String minutes);

  /// No description provided for @shellDurationHours.
  ///
  /// In ar, this message translates to:
  /// **'{hours} س'**
  String shellDurationHours(String hours);

  /// No description provided for @shellDurationMinutes.
  ///
  /// In ar, this message translates to:
  /// **'{minutes} د'**
  String shellDurationMinutes(String minutes);

  /// No description provided for @shellDurationLessThanMinute.
  ///
  /// In ar, this message translates to:
  /// **'أقل من دقيقة'**
  String get shellDurationLessThanMinute;

  /// Home header button
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get homeOpenSettings;

  /// Badge on the current prayer window
  ///
  /// In ar, this message translates to:
  /// **'الآن'**
  String get homeNow;

  /// Countdown to the next prayer
  ///
  /// In ar, this message translates to:
  /// **'{prayer} بعد {duration}'**
  String homeNextPrayer(String prayer, String duration);

  /// Marks the static placeholder prayer times
  ///
  /// In ar, this message translates to:
  /// **'مواقيت تقريبية'**
  String get homePlaceholderBadge;

  /// No description provided for @homePlaceholderNote.
  ///
  /// In ar, this message translates to:
  /// **'المواقيت الدقيقة لموقعك تصل قريبًا'**
  String get homePlaceholderNote;

  /// Screen-reader label of a window chip
  ///
  /// In ar, this message translates to:
  /// **'{window}، يبدأ {time}'**
  String homeWindowStarts(String window, String time);

  /// No description provided for @homeTasksCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا مهام بعد} =1{مهمة واحدة} =2{مهمتان} few{{count} مهام} many{{count} مهمة} other{{count} مهمة}}'**
  String homeTasksCount(int count);

  /// No description provided for @homeTasksProgress.
  ///
  /// In ar, this message translates to:
  /// **'أنجزت {done} من {total}'**
  String homeTasksProgress(String done, String total);

  /// No description provided for @homeAddTask.
  ///
  /// In ar, this message translates to:
  /// **'مهمة جديدة'**
  String get homeAddTask;

  /// No description provided for @homeEditTask.
  ///
  /// In ar, this message translates to:
  /// **'تعديل المهمة'**
  String get homeEditTask;

  /// No description provided for @homeTaskTitleField.
  ///
  /// In ar, this message translates to:
  /// **'المهمة'**
  String get homeTaskTitleField;

  /// No description provided for @homeTaskTitleHint.
  ///
  /// In ar, this message translates to:
  /// **'ماذا تودّ أن تنجز؟'**
  String get homeTaskTitleHint;

  /// No description provided for @homeTaskNotesField.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات'**
  String get homeTaskNotesField;

  /// No description provided for @homeTaskWindowField.
  ///
  /// In ar, this message translates to:
  /// **'وقتها من اليوم'**
  String get homeTaskWindowField;

  /// No description provided for @homeTaskDateField.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get homeTaskDateField;

  /// No description provided for @homeTaskPlanetField.
  ///
  /// In ar, this message translates to:
  /// **'الكوكب'**
  String get homeTaskPlanetField;

  /// No description provided for @homeTaskAdded.
  ///
  /// In ar, this message translates to:
  /// **'أُضيفت المهمة'**
  String get homeTaskAdded;

  /// No description provided for @homeTaskCompleted.
  ///
  /// In ar, this message translates to:
  /// **'أُنجزت المهمة'**
  String get homeTaskCompleted;

  /// No description provided for @homeTaskReopened.
  ///
  /// In ar, this message translates to:
  /// **'أُعيد فتح المهمة'**
  String get homeTaskReopened;

  /// Swipe action on a completed task
  ///
  /// In ar, this message translates to:
  /// **'إعادة فتح'**
  String get homeTaskReopen;

  /// Screen-reader state of a completed task
  ///
  /// In ar, this message translates to:
  /// **'منجزة'**
  String get homeTaskDone;

  /// No description provided for @homeMoveTitle.
  ///
  /// In ar, this message translates to:
  /// **'انقلها إلى وقت آخر'**
  String get homeMoveTitle;

  /// No description provided for @homeMoveSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'تبقى في اليوم نفسه'**
  String get homeMoveSubtitle;

  /// No description provided for @homeReminderSet.
  ///
  /// In ar, this message translates to:
  /// **'ضُبط التذكير'**
  String get homeReminderSet;

  /// No description provided for @homeReminderRemoved.
  ///
  /// In ar, this message translates to:
  /// **'أُزيل التذكير'**
  String get homeReminderRemoved;

  /// No description provided for @homeEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'هذا الوقت ما زال رحبًا'**
  String get homeEmptyTitle;

  /// No description provided for @homeEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'أضف مهمة، أو اكتب ما يدور في بالك في الشريط أدناه.'**
  String get homeEmptyBody;

  /// No description provided for @homeRadarTitle.
  ///
  /// In ar, this message translates to:
  /// **'رادار الإهمال'**
  String get homeRadarTitle;

  /// No description provided for @homeRadarBody.
  ///
  /// In ar, this message translates to:
  /// **'سيلفت نظرك بلطف إلى جوانب حياتك التي غبت عنها طويلًا، ويصل مع المدار الحيّ.'**
  String get homeRadarBody;

  /// No description provided for @homeRadarBadge.
  ///
  /// In ar, this message translates to:
  /// **'قريبًا'**
  String get homeRadarBadge;

  /// Name of the wallet created on demand by quick add
  ///
  /// In ar, this message translates to:
  /// **'المحفظة'**
  String get homeDefaultWallet;

  /// No description provided for @homeDialSemantics.
  ///
  /// In ar, this message translates to:
  /// **'أسطرلاب اليوم: {window}، و{next}'**
  String homeDialSemantics(String window, String next);

  /// No description provided for @settingsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settingsTitle;

  /// No description provided for @settingsPersonal.
  ///
  /// In ar, this message translates to:
  /// **'التخصيص'**
  String get settingsPersonal;

  /// No description provided for @settingsGeneral.
  ///
  /// In ar, this message translates to:
  /// **'عام'**
  String get settingsGeneral;

  /// No description provided for @settingsAppearance.
  ///
  /// In ar, this message translates to:
  /// **'المظهر'**
  String get settingsAppearance;

  /// No description provided for @settingsAppearanceSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'السمة ولون التمييز واللغة والأرقام'**
  String get settingsAppearanceSubtitle;

  /// No description provided for @settingsTheme.
  ///
  /// In ar, this message translates to:
  /// **'السمة'**
  String get settingsTheme;

  /// No description provided for @settingsThemeSelected.
  ///
  /// In ar, this message translates to:
  /// **'السمة الحالية'**
  String get settingsThemeSelected;

  /// No description provided for @settingsFollowSystem.
  ///
  /// In ar, this message translates to:
  /// **'اتّباع وضع الجهاز'**
  String get settingsFollowSystem;

  /// No description provided for @settingsFollowSystemHint.
  ///
  /// In ar, this message translates to:
  /// **'اللؤلؤ في الوضع الفاتح، وسمتك المختارة في الداكن'**
  String get settingsFollowSystemHint;

  /// No description provided for @settingsAccent.
  ///
  /// In ar, this message translates to:
  /// **'لون التمييز'**
  String get settingsAccent;

  /// No description provided for @settingsAccentDefault.
  ///
  /// In ar, this message translates to:
  /// **'لون السمة'**
  String get settingsAccentDefault;

  /// No description provided for @settingsAccentCustom.
  ///
  /// In ar, this message translates to:
  /// **'لون مخصّص'**
  String get settingsAccentCustom;

  /// No description provided for @settingsLanguage.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get settingsLanguage;

  /// Always shown in Arabic
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get settingsLanguageArabic;

  /// Always shown in English
  ///
  /// In ar, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsDigits.
  ///
  /// In ar, this message translates to:
  /// **'الأرقام'**
  String get settingsDigits;

  /// No description provided for @settingsDigitsAuto.
  ///
  /// In ar, this message translates to:
  /// **'تلقائية'**
  String get settingsDigitsAuto;

  /// No description provided for @settingsDigitsWestern.
  ///
  /// In ar, this message translates to:
  /// **'غربية'**
  String get settingsDigitsWestern;

  /// No description provided for @settingsDigitsArabicIndic.
  ///
  /// In ar, this message translates to:
  /// **'مشرقية'**
  String get settingsDigitsArabicIndic;

  /// No description provided for @settingsDigitsHint.
  ///
  /// In ar, this message translates to:
  /// **'التلقائية: مشرقية بالعربية وغربية بالإنجليزية'**
  String get settingsDigitsHint;

  /// No description provided for @settingsSound.
  ///
  /// In ar, this message translates to:
  /// **'الصوت واللمس'**
  String get settingsSound;

  /// No description provided for @settingsSoundSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'المؤثرات والأجواء ومستويات الصوت'**
  String get settingsSoundSubtitle;

  /// No description provided for @settingsSoundEnabled.
  ///
  /// In ar, this message translates to:
  /// **'الأصوات'**
  String get settingsSoundEnabled;

  /// No description provided for @settingsSoundEnabledHint.
  ///
  /// In ar, this message translates to:
  /// **'مفتاح عام لكل أصوات التطبيق'**
  String get settingsSoundEnabledHint;

  /// No description provided for @settingsHaptics.
  ///
  /// In ar, this message translates to:
  /// **'الاهتزاز اللمسي'**
  String get settingsHaptics;

  /// No description provided for @settingsHapticsHint.
  ///
  /// In ar, this message translates to:
  /// **'نبضة خفيفة ترافق كل صوت'**
  String get settingsHapticsHint;

  /// No description provided for @settingsAmbient.
  ///
  /// In ar, this message translates to:
  /// **'أجواء الفضاء'**
  String get settingsAmbient;

  /// No description provided for @settingsAmbientHint.
  ///
  /// In ar, this message translates to:
  /// **'طبقة صوتية هادئة تحت الواجهة'**
  String get settingsAmbientHint;

  /// No description provided for @settingsVolumes.
  ///
  /// In ar, this message translates to:
  /// **'مستويات الصوت'**
  String get settingsVolumes;

  /// No description provided for @settingsSoundProfile.
  ///
  /// In ar, this message translates to:
  /// **'طابع الأصوات'**
  String get settingsSoundProfile;

  /// No description provided for @settingsSoundProfileHint.
  ///
  /// In ar, this message translates to:
  /// **'يتبدّل مع السمة'**
  String get settingsSoundProfileHint;

  /// No description provided for @settingsMotion.
  ///
  /// In ar, this message translates to:
  /// **'الحركة'**
  String get settingsMotion;

  /// No description provided for @settingsMotionSystem.
  ///
  /// In ar, this message translates to:
  /// **'حسب الجهاز'**
  String get settingsMotionSystem;

  /// No description provided for @settingsMotionReduced.
  ///
  /// In ar, this message translates to:
  /// **'مخفّفة'**
  String get settingsMotionReduced;

  /// No description provided for @settingsMotionFull.
  ///
  /// In ar, this message translates to:
  /// **'كاملة'**
  String get settingsMotionFull;

  /// No description provided for @settingsMotionHint.
  ///
  /// In ar, this message translates to:
  /// **'المخفّفة تستبدل الانتقالات السينمائية بتلاشٍ هادئ'**
  String get settingsMotionHint;

  /// No description provided for @settingsPower.
  ///
  /// In ar, this message translates to:
  /// **'وضع الطاقة'**
  String get settingsPower;

  /// No description provided for @settingsPowerAuto.
  ///
  /// In ar, this message translates to:
  /// **'تلقائي'**
  String get settingsPowerAuto;

  /// No description provided for @settingsPowerSaver.
  ///
  /// In ar, this message translates to:
  /// **'توفير البطارية'**
  String get settingsPowerSaver;

  /// No description provided for @settingsPowerHint.
  ///
  /// In ar, this message translates to:
  /// **'توفير البطارية يُثبّت خلفية الفضاء ويخفّف العرض'**
  String get settingsPowerHint;

  /// No description provided for @settingsData.
  ///
  /// In ar, this message translates to:
  /// **'البيانات'**
  String get settingsData;

  /// No description provided for @settingsImport.
  ///
  /// In ar, this message translates to:
  /// **'استيراد من النموذج الأوّلي'**
  String get settingsImport;

  /// No description provided for @settingsImportHint.
  ///
  /// In ar, this message translates to:
  /// **'ملف JSON صدّرته من النسخة الأولى'**
  String get settingsImportHint;

  /// No description provided for @settingsPrivacyNote.
  ///
  /// In ar, this message translates to:
  /// **'بياناتك مشفّرة وتبقى على جهازك وحده.'**
  String get settingsPrivacyNote;

  /// No description provided for @settingsAbout.
  ///
  /// In ar, this message translates to:
  /// **'حول مَدار'**
  String get settingsAbout;

  /// No description provided for @settingsVersion.
  ///
  /// In ar, this message translates to:
  /// **'الإصدار {version}'**
  String settingsVersion(String version);

  /// No description provided for @settingsFonts.
  ///
  /// In ar, this message translates to:
  /// **'الخطوط'**
  String get settingsFonts;

  /// No description provided for @settingsFontsBody.
  ///
  /// In ar, this message translates to:
  /// **'خطوط حرّة مرخّصة برخصة SIL للخطوط المفتوحة 1.1'**
  String get settingsFontsBody;

  /// No description provided for @settingsFontRoleUi.
  ///
  /// In ar, this message translates to:
  /// **'خط الواجهة'**
  String get settingsFontRoleUi;

  /// No description provided for @settingsFontRoleDisplay.
  ///
  /// In ar, this message translates to:
  /// **'خط العناوين'**
  String get settingsFontRoleDisplay;

  /// No description provided for @settingsFontRoleQuran.
  ///
  /// In ar, this message translates to:
  /// **'نص القرآن الكريم'**
  String get settingsFontRoleQuran;

  /// No description provided for @settingsFontRoleNaskh.
  ///
  /// In ar, this message translates to:
  /// **'النصوص الكلاسيكية'**
  String get settingsFontRoleNaskh;

  /// Font name (proper noun)
  ///
  /// In ar, this message translates to:
  /// **'IBM Plex Sans Arabic'**
  String get settingsFontPlex;

  /// Font name (proper noun)
  ///
  /// In ar, this message translates to:
  /// **'Reem Kufi'**
  String get settingsFontReemKufi;

  /// Font name (proper noun)
  ///
  /// In ar, this message translates to:
  /// **'Amiri Quran'**
  String get settingsFontAmiriQuran;

  /// Font name (proper noun)
  ///
  /// In ar, this message translates to:
  /// **'Amiri'**
  String get settingsFontAmiri;

  /// No description provided for @settingsLicense.
  ///
  /// In ar, this message translates to:
  /// **'الترخيص'**
  String get settingsLicense;

  /// No description provided for @settingsLicenseUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل نص الترخيص'**
  String get settingsLicenseUnavailable;

  /// No description provided for @settingsGalleryHint.
  ///
  /// In ar, this message translates to:
  /// **'كل مكوّنات الواجهة في مكان واحد'**
  String get settingsGalleryHint;

  /// No description provided for @settingsDeveloper.
  ///
  /// In ar, this message translates to:
  /// **'للمطوّرين'**
  String get settingsDeveloper;

  /// No description provided for @settingsOpen.
  ///
  /// In ar, this message translates to:
  /// **'فتح {name}'**
  String settingsOpen(String name);

  /// No description provided for @onboardingWelcomeTagline.
  ///
  /// In ar, this message translates to:
  /// **'يومك يدور حول الصلوات الخمس'**
  String get onboardingWelcomeTagline;

  /// No description provided for @onboardingWelcomeBody.
  ///
  /// In ar, this message translates to:
  /// **'مهامك وصحتك ومالك وأهلك… لكلٍّ منها مداره، والصلاة هي المركز الذي يجمعها ويضبط إيقاعها.'**
  String get onboardingWelcomeBody;

  /// No description provided for @onboardingStyleTitle.
  ///
  /// In ar, this message translates to:
  /// **'لغتك وطابعك'**
  String get onboardingStyleTitle;

  /// No description provided for @onboardingStyleBody.
  ///
  /// In ar, this message translates to:
  /// **'جرّب وشاهد التغيير فورًا، ويمكنك تعديله متى شئت من الإعدادات.'**
  String get onboardingStyleBody;

  /// No description provided for @onboardingStartTitle.
  ///
  /// In ar, this message translates to:
  /// **'من أين نبدأ؟'**
  String get onboardingStartTitle;

  /// No description provided for @onboardingStartBody.
  ///
  /// In ar, this message translates to:
  /// **'بياناتك مشفّرة وتبقى على جهازك وحده.'**
  String get onboardingStartBody;

  /// No description provided for @onboardingStartFresh.
  ///
  /// In ar, this message translates to:
  /// **'بداية جديدة'**
  String get onboardingStartFresh;

  /// No description provided for @onboardingStartFreshBody.
  ///
  /// In ar, this message translates to:
  /// **'مدارٌ صافٍ ينتظر خطوتك الأولى'**
  String get onboardingStartFreshBody;

  /// No description provided for @onboardingImport.
  ///
  /// In ar, this message translates to:
  /// **'استيراد بياناتي'**
  String get onboardingImport;

  /// No description provided for @onboardingImportBody.
  ///
  /// In ar, this message translates to:
  /// **'من ملف JSON صدّرته من النموذج الأوّلي'**
  String get onboardingImportBody;

  /// No description provided for @onboardingBegin.
  ///
  /// In ar, this message translates to:
  /// **'لنبدأ'**
  String get onboardingBegin;

  /// No description provided for @onboardingSkip.
  ///
  /// In ar, this message translates to:
  /// **'تخطٍّ'**
  String get onboardingSkip;

  /// No description provided for @onboardingStep.
  ///
  /// In ar, this message translates to:
  /// **'الخطوة {current} من {total}'**
  String onboardingStep(String current, String total);

  /// Neglect Radar: a person whose contact rhythm is overdue. n = days formatted in the user's digits
  ///
  /// In ar, this message translates to:
  /// **'{name} — {days, plural, =1{متأخر يومًا واحدًا} =2{متأخر يومين} few{متأخر {n} أيام} many{متأخر {n} يومًا} other{متأخر {n} يوم}}'**
  String orbitReasonPersonOverdue(String name, int days, String n);

  /// Neglect Radar: medication doses due today that were not taken
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{جرعة فائتة} =2{جرعتان فائتتان} few{{n} جرعات فائتة} many{{n} جرعة فائتة} other{{n} جرعة فائتة}}'**
  String orbitReasonDosesPastDue(int count, String n);

  /// Neglect Radar: past-due doses of a single medication
  ///
  /// In ar, this message translates to:
  /// **'{name} — {count, plural, =1{جرعة فائتة} =2{جرعتان فائتتان} few{{n} جرعات فائتة} many{{n} جرعة فائتة} other{{n} جرعة فائتة}}'**
  String orbitReasonDosesPastDueNamed(String name, int count, String n);

  /// Neglect Radar: obligatory prayers of the last 7 days not logged as prayed
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{صلاة لم تُسجَّل هذا الأسبوع} =2{صلاتان لم تُسجَّلا هذا الأسبوع} few{{n} صلوات لم تُسجَّل هذا الأسبوع} many{{n} صلاةً لم تُسجَّل هذا الأسبوع} other{{n} صلاة لم تُسجَّل هذا الأسبوع}}'**
  String orbitReasonPrayersMissed(int count, String n);

  /// No description provided for @orbitReasonTasksOverdue.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{مهمة متأخرة} =2{مهمتان متأخرتان} few{{n} مهام متأخرة} many{{n} مهمة متأخرة} other{{n} مهمة متأخرة}}'**
  String orbitReasonTasksOverdue(int count, String n);

  /// Neglect Radar: overdue cards on one work board
  ///
  /// In ar, this message translates to:
  /// **'{board} — {count, plural, =1{بطاقة متأخرة} =2{بطاقتان متأخرتان} few{{n} بطاقات متأخرة} many{{n} بطاقة متأخرة} other{{n} بطاقة متأخرة}}'**
  String orbitReasonCardsOverdue(String board, int count, String n);

  /// Neglect Radar: a budget item overspent this month; percent is pre-formatted (e.g. 30%)
  ///
  /// In ar, this message translates to:
  /// **'{item} — تجاوز الميزانية بنسبة {percent}'**
  String orbitReasonBudgetOverspent(String item, String percent);

  /// Neglect Radar: a recurring bill / obligation past its due date
  ///
  /// In ar, this message translates to:
  /// **'{name} — {days, plural, =1{تأخّر السداد يومًا واحدًا} =2{تأخّر السداد يومين} few{تأخّر السداد {n} أيام} many{تأخّر السداد {n} يومًا} other{تأخّر السداد {n} يوم}}'**
  String orbitReasonObligationOverdue(String name, int days, String n);

  /// Neglect Radar: a debt the user owes, past its due date
  ///
  /// In ar, this message translates to:
  /// **'دَين {person} — {days, plural, =1{تأخّر السداد يومًا واحدًا} =2{تأخّر السداد يومين} few{تأخّر السداد {n} أيام} many{تأخّر السداد {n} يومًا} other{تأخّر السداد {n} يوم}}'**
  String orbitReasonDebtOverdue(String person, int days, String n);

  /// Neglect Radar: a learning goal behind its deadline pace
  ///
  /// In ar, this message translates to:
  /// **'{name} — أنجزتَ {percent} من المتوقَّع حتى الآن'**
  String orbitReasonGoalBehind(String name, String percent);

  /// Neglect Radar: a learning goal without deadline and no recent log
  ///
  /// In ar, this message translates to:
  /// **'{name} — {days, plural, =1{لا تقدّم منذ يوم} =2{لا تقدّم منذ يومين} few{لا تقدّم منذ {n} أيام} many{لا تقدّم منذ {n} يومًا} other{لا تقدّم منذ {n} يوم}}'**
  String orbitReasonGoalQuiet(String name, int days, String n);

  /// No description provided for @orbitReasonWorkoutsMissed.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{تمرين فائت هذا الأسبوع} =2{تمرينان فائتان هذا الأسبوع} few{{n} تمارين فائتة هذا الأسبوع} many{{n} تمرينًا فائتًا هذا الأسبوع} other{{n} تمرين فائت هذا الأسبوع}}'**
  String orbitReasonWorkoutsMissed(int count, String n);

  /// No description provided for @orbitReasonWaterLow.
  ///
  /// In ar, this message translates to:
  /// **'الماء — {percent} فقط من هدف اليوم'**
  String orbitReasonWaterLow(String percent);

  /// Neglect Radar: a travel document close to its expiry
  ///
  /// In ar, this message translates to:
  /// **'{name} — {days, plural, =1{انتهاء الصلاحية خلال يوم} =2{انتهاء الصلاحية خلال يومين} few{انتهاء الصلاحية خلال {n} أيام} many{انتهاء الصلاحية خلال {n} يومًا} other{انتهاء الصلاحية خلال {n} يوم}}'**
  String orbitReasonDocumentExpiring(String name, int days, String n);

  /// No description provided for @orbitReasonDocumentExpiresToday.
  ///
  /// In ar, this message translates to:
  /// **'{name} — انتهاء الصلاحية اليوم'**
  String orbitReasonDocumentExpiresToday(String name);

  /// No description provided for @orbitReasonDocumentExpired.
  ///
  /// In ar, this message translates to:
  /// **'{name} — انتهت الصلاحية'**
  String orbitReasonDocumentExpired(String name);

  /// Neglect Radar: an upcoming trip whose packing list is behind
  ///
  /// In ar, this message translates to:
  /// **'{destination} — {days, plural, =0{السفر اليوم} =1{السفر غدًا} =2{السفر بعد يومين} few{السفر بعد {n} أيام} many{السفر بعد {n} يومًا} other{السفر بعد {n} يوم}}، والتجهيز {percent} فقط'**
  String orbitReasonTripUnpacked(
    String destination,
    int days,
    String n,
    String percent,
  );

  /// Neglect Radar: a custom tracker without recent entries
  ///
  /// In ar, this message translates to:
  /// **'{name} — {days, plural, =1{لا إدخال منذ يوم} =2{لا إدخال منذ يومين} few{لا إدخال منذ {n} أيام} many{لا إدخال منذ {n} يومًا} other{لا إدخال منذ {n} يوم}}'**
  String orbitReasonModuleStale(String name, int days, String n);

  /// No description provided for @orbitReasonNoActivity.
  ///
  /// In ar, this message translates to:
  /// **'{days, plural, =1{لا نشاط منذ يوم} =2{لا نشاط منذ يومين} few{لا نشاط منذ {n} أيام} many{لا نشاط منذ {n} يومًا} other{لا نشاط منذ {n} يوم}}'**
  String orbitReasonNoActivity(int days, String n);

  /// No description provided for @orbitReasonHabitsSlipping.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{عادة متعثّرة هذا الأسبوع} =2{عادتان متعثّرتان هذا الأسبوع} few{{n} عادات متعثّرة هذا الأسبوع} many{{n} عادةً متعثّرة هذا الأسبوع} other{{n} عادة متعثّرة هذا الأسبوع}}'**
  String orbitReasonHabitsSlipping(int count, String n);

  /// Neglect Radar: one tracked habit not done recently
  ///
  /// In ar, this message translates to:
  /// **'{name} — {days, plural, =1{لم تُنجَز منذ يوم} =2{لم تُنجَز منذ يومين} few{لم تُنجَز منذ {n} أيام} many{لم تُنجَز منذ {n} يومًا} other{لم تُنجَز منذ {n} يوم}}'**
  String orbitReasonHabitSlipping(String name, int days, String n);

  /// No description provided for @orbitReasonProjectItemsOverdue.
  ///
  /// In ar, this message translates to:
  /// **'{project} — {count, plural, =1{بند متأخر} =2{بندان متأخران} few{{n} بنود متأخرة} many{{n} بندًا متأخرًا} other{{n} بند متأخر}}'**
  String orbitReasonProjectItemsOverdue(String project, int count, String n);

  /// Neglect Radar: a savings jar behind its deadline pace
  ///
  /// In ar, this message translates to:
  /// **'{name} — ادّخرتَ {percent} من المتوقَّع'**
  String orbitReasonJarBehind(String name, String percent);

  /// Neglect Radar: a data source (adhkar, Quran, spending) without recent entries
  ///
  /// In ar, this message translates to:
  /// **'{source} — {days, plural, =1{لا تسجيل منذ يوم} =2{لا تسجيل منذ يومين} few{لا تسجيل منذ {n} أيام} many{لا تسجيل منذ {n} يومًا} other{لا تسجيل منذ {n} يوم}}'**
  String orbitReasonSourceStale(String source, int days, String n);

  /// No description provided for @orbitSourcePrayers.
  ///
  /// In ar, this message translates to:
  /// **'الصلوات'**
  String get orbitSourcePrayers;

  /// No description provided for @orbitSourceAdhkar.
  ///
  /// In ar, this message translates to:
  /// **'الأذكار'**
  String get orbitSourceAdhkar;

  /// No description provided for @orbitSourceQuran.
  ///
  /// In ar, this message translates to:
  /// **'القرآن'**
  String get orbitSourceQuran;

  /// No description provided for @orbitSourceDoses.
  ///
  /// In ar, this message translates to:
  /// **'جرعات الأدوية'**
  String get orbitSourceDoses;

  /// No description provided for @orbitSourceHabits.
  ///
  /// In ar, this message translates to:
  /// **'العادات'**
  String get orbitSourceHabits;

  /// No description provided for @orbitSourceMood.
  ///
  /// In ar, this message translates to:
  /// **'المزاج'**
  String get orbitSourceMood;

  /// No description provided for @orbitSourcePain.
  ///
  /// In ar, this message translates to:
  /// **'الألم'**
  String get orbitSourcePain;

  /// No description provided for @orbitSourceAppointments.
  ///
  /// In ar, this message translates to:
  /// **'المواعيد الطبية'**
  String get orbitSourceAppointments;

  /// No description provided for @orbitSourceContacts.
  ///
  /// In ar, this message translates to:
  /// **'صلة الناس'**
  String get orbitSourceContacts;

  /// No description provided for @orbitSourceTasks.
  ///
  /// In ar, this message translates to:
  /// **'المهام'**
  String get orbitSourceTasks;

  /// No description provided for @orbitSourceCards.
  ///
  /// In ar, this message translates to:
  /// **'لوحات العمل'**
  String get orbitSourceCards;

  /// No description provided for @orbitSourceProjects.
  ///
  /// In ar, this message translates to:
  /// **'المشاريع'**
  String get orbitSourceProjects;

  /// No description provided for @orbitSourceBudget.
  ///
  /// In ar, this message translates to:
  /// **'الميزانية'**
  String get orbitSourceBudget;

  /// No description provided for @orbitSourceTransactions.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل المصروفات'**
  String get orbitSourceTransactions;

  /// No description provided for @orbitSourceJars.
  ///
  /// In ar, this message translates to:
  /// **'صناديق الادّخار'**
  String get orbitSourceJars;

  /// No description provided for @orbitSourceObligations.
  ///
  /// In ar, this message translates to:
  /// **'الالتزامات والفواتير'**
  String get orbitSourceObligations;

  /// No description provided for @orbitSourceDebts.
  ///
  /// In ar, this message translates to:
  /// **'الديون'**
  String get orbitSourceDebts;

  /// No description provided for @orbitSourceGoals.
  ///
  /// In ar, this message translates to:
  /// **'أهداف التعلّم'**
  String get orbitSourceGoals;

  /// No description provided for @orbitSourceWorkouts.
  ///
  /// In ar, this message translates to:
  /// **'التمارين'**
  String get orbitSourceWorkouts;

  /// No description provided for @orbitSourceFasting.
  ///
  /// In ar, this message translates to:
  /// **'الصيام'**
  String get orbitSourceFasting;

  /// No description provided for @orbitSourceWater.
  ///
  /// In ar, this message translates to:
  /// **'شرب الماء'**
  String get orbitSourceWater;

  /// No description provided for @orbitSourceDocuments.
  ///
  /// In ar, this message translates to:
  /// **'وثائق السفر'**
  String get orbitSourceDocuments;

  /// No description provided for @orbitSourceTrips.
  ///
  /// In ar, this message translates to:
  /// **'الرحلات'**
  String get orbitSourceTrips;

  /// No description provided for @orbitArchetypeFaith.
  ///
  /// In ar, this message translates to:
  /// **'قبّة ذهبية منقوشة'**
  String get orbitArchetypeFaith;

  /// No description provided for @orbitArchetypeOcean.
  ///
  /// In ar, this message translates to:
  /// **'محيط حيّ'**
  String get orbitArchetypeOcean;

  /// No description provided for @orbitArchetypeTerracotta.
  ///
  /// In ar, this message translates to:
  /// **'أرض فخّارية دافئة'**
  String get orbitArchetypeTerracotta;

  /// No description provided for @orbitArchetypeIndustrial.
  ///
  /// In ar, this message translates to:
  /// **'عالم صناعي مضيء'**
  String get orbitArchetypeIndustrial;

  /// No description provided for @orbitArchetypeCrystal.
  ///
  /// In ar, this message translates to:
  /// **'بلّور بعروق ذهبية'**
  String get orbitArchetypeCrystal;

  /// No description provided for @orbitArchetypeVerdant.
  ///
  /// In ar, this message translates to:
  /// **'عالم أخضر ينمو'**
  String get orbitArchetypeVerdant;

  /// No description provided for @orbitArchetypeVolcanic.
  ///
  /// In ar, this message translates to:
  /// **'عالم بركاني'**
  String get orbitArchetypeVolcanic;

  /// No description provided for @orbitArchetypeGasGiant.
  ///
  /// In ar, this message translates to:
  /// **'عملاق غازي بحلقات'**
  String get orbitArchetypeGasGiant;

  /// No description provided for @orbitArchetypeIce.
  ///
  /// In ar, this message translates to:
  /// **'عالم جليدي'**
  String get orbitArchetypeIce;

  /// No description provided for @orbitArchetypeDesert.
  ///
  /// In ar, this message translates to:
  /// **'عالم صحراوي'**
  String get orbitArchetypeDesert;

  /// No description provided for @orbitStateThriving.
  ///
  /// In ar, this message translates to:
  /// **'مزدهر'**
  String get orbitStateThriving;

  /// No description provided for @orbitStateSteady.
  ///
  /// In ar, this message translates to:
  /// **'مستقر'**
  String get orbitStateSteady;

  /// No description provided for @orbitStateNeglected.
  ///
  /// In ar, this message translates to:
  /// **'يحتاج إلى اهتمام'**
  String get orbitStateNeglected;

  /// No description provided for @orbitStateDormant.
  ///
  /// In ar, this message translates to:
  /// **'هادئ، لا بيانات بعد'**
  String get orbitStateDormant;

  /// Screen-reader label of a planet
  ///
  /// In ar, this message translates to:
  /// **'{name}، {state}، التوازن {percent}'**
  String orbitPlanetSemantics(String name, String state, String percent);

  /// Screen-reader label of the core star
  ///
  /// In ar, this message translates to:
  /// **'توازن حياتك {percent}'**
  String orbitBalanceSemantics(String percent);

  /// Moons that did not fit around a planet (beyond the cap of 12)
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{وقمر آخر} =2{وقمران آخران} few{و{n} أقمار أخرى} many{و{n} قمرًا آخر} other{و{n} قمر آخر}}'**
  String orbitMoonsMore(int count, String n);

  /// Countdown to the next prayer engraved on the astrolabe's inner ring
  ///
  /// In ar, this message translates to:
  /// **'{prayer} بعد {duration}'**
  String orbitCountdown(String prayer, String duration);

  /// No description provided for @orbitNewPlanetName.
  ///
  /// In ar, this message translates to:
  /// **'كوكب جديد'**
  String get orbitNewPlanetName;

  /// No description provided for @orbitBuiltInCannotDelete.
  ///
  /// In ar, this message translates to:
  /// **'الكواكب الأساسية تُخفى ولا تُحذف'**
  String get orbitBuiltInCannotDelete;

  /// No description provided for @orbitUndoRenamed.
  ///
  /// In ar, this message translates to:
  /// **'تغيّر اسم الكوكب'**
  String get orbitUndoRenamed;

  /// No description provided for @orbitUndoRecolored.
  ///
  /// In ar, this message translates to:
  /// **'تغيّر لون {name}'**
  String orbitUndoRecolored(String name);

  /// No description provided for @orbitUndoReordered.
  ///
  /// In ar, this message translates to:
  /// **'تغيّر ترتيب الكواكب'**
  String get orbitUndoReordered;

  /// No description provided for @orbitUndoHidden.
  ///
  /// In ar, this message translates to:
  /// **'أُخفي {name}'**
  String orbitUndoHidden(String name);

  /// No description provided for @orbitUndoShown.
  ///
  /// In ar, this message translates to:
  /// **'عاد {name} إلى المدار'**
  String orbitUndoShown(String name);

  /// No description provided for @orbitUndoWeight.
  ///
  /// In ar, this message translates to:
  /// **'تغيّرت أهمية {name}'**
  String orbitUndoWeight(String name);

  /// No description provided for @orbitUndoSources.
  ///
  /// In ar, this message translates to:
  /// **'تغيّرت مصادر {name}'**
  String orbitUndoSources(String name);

  /// No description provided for @orbitUndoStyle.
  ///
  /// In ar, this message translates to:
  /// **'تغيّر طراز {name}'**
  String orbitUndoStyle(String name);

  /// No description provided for @orbitUndoAdded.
  ///
  /// In ar, this message translates to:
  /// **'أُضيف {name} إلى المدار'**
  String orbitUndoAdded(String name);

  /// No description provided for @orbitUndoDeleted.
  ///
  /// In ar, this message translates to:
  /// **'حُذف {name}'**
  String orbitUndoDeleted(String name);

  /// No description provided for @orbitUndoReset.
  ///
  /// In ar, this message translates to:
  /// **'أُعيد {name} إلى أصله'**
  String orbitUndoReset(String name);

  /// Countdown engraved on the astrolabe's inner ring, e.g. «العصر بعد ١:٢٣:٠٥»
  ///
  /// In ar, this message translates to:
  /// **'{prayer} بعد {time}'**
  String astrolabeCountdown(String prayer, String time);

  /// Engraved on the inner ring in the moment the next prayer begins
  ///
  /// In ar, this message translates to:
  /// **'حان وقت {prayer}'**
  String astrolabeCountdownNow(String prayer);

  /// Screen-reader summary of the astrolabe centrepiece
  ///
  /// In ar, this message translates to:
  /// **'أسطرلاب يومك. {window}. {countdown}. صلّيت {done} من {total}.'**
  String astrolabeSemantics(
    String window,
    String countdown,
    String done,
    String total,
  );

  /// Current prayer window, used in the astrolabe's screen-reader summary
  ///
  /// In ar, this message translates to:
  /// **'الآن وقت {window}'**
  String astrolabeWindowNow(String window);

  /// No description provided for @astrolabePrayerPrayed.
  ///
  /// In ar, this message translates to:
  /// **'{prayer}: صلّيتها'**
  String astrolabePrayerPrayed(String prayer);

  /// No description provided for @astrolabePrayerDue.
  ///
  /// In ar, this message translates to:
  /// **'{prayer}: حان وقتها'**
  String astrolabePrayerDue(String prayer);

  /// No description provided for @astrolabePrayerUpcoming.
  ///
  /// In ar, this message translates to:
  /// **'{prayer}: الساعة {time}'**
  String astrolabePrayerUpcoming(String prayer, String time);

  /// No description provided for @astrolabePrayerMissed.
  ///
  /// In ar, this message translates to:
  /// **'{prayer}: فاتت'**
  String astrolabePrayerMissed(String prayer);

  /// Maker's mark engraved on the lower half of the astrolabe's inner ring (like a signed museum astrolabe)
  ///
  /// In ar, this message translates to:
  /// **'مَدار'**
  String get astrolabeMakersMark;
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
