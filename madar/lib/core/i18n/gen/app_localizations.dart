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

  /// Joins short facts on one line (e.g. a time and a reminder). Arabic uses a comma: a middle dot beside Arabic-Indic digits reads as the zero (٠)
  ///
  /// In ar, this message translates to:
  /// **'، '**
  String get commonFactSeparator;

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
  /// **'{max, plural, =1{الحدّ الأقصى حرف واحد} =2{الحدّ الأقصى حرفان} few{الحدّ الأقصى {max} أحرف} many{الحدّ الأقصى {max} حرفًا} other{الحدّ الأقصى {max} حرف}}'**
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

  /// Spoken label of the n-th icon in the icon picker
  ///
  /// In ar, this message translates to:
  /// **'أيقونة {index}'**
  String interactionFieldIcon(int index);

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
  /// **'ل.د'**
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

  /// Badge on the theme used while the device is in light mode (follow the device)
  ///
  /// In ar, this message translates to:
  /// **'للوضع الفاتح'**
  String get settingsThemeLightMode;

  /// Badge on the theme used while the device is in dark mode (follow the device)
  ///
  /// In ar, this message translates to:
  /// **'للوضع الداكن'**
  String get settingsThemeDarkMode;

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

  /// No description provided for @settingsAccentCustomHint.
  ///
  /// In ar, this message translates to:
  /// **'اسحب على الطيف لاختيار أي لون؛ يُضبط سطوعه تلقائيًا ليبقى مقروءًا في كل سمة.'**
  String get settingsAccentCustomHint;

  /// No description provided for @settingsAccentPlanet.
  ///
  /// In ar, this message translates to:
  /// **'لون {planet}'**
  String settingsAccentPlanet(String planet);

  /// No description provided for @settingsAccentHueValue.
  ///
  /// In ar, this message translates to:
  /// **'درجة اللون {degrees}°'**
  String settingsAccentHueValue(String degrees);

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

  /// Settings section holding the motion and power-mode choices (the motion tile keeps its own title)
  ///
  /// In ar, this message translates to:
  /// **'الحركة والطاقة'**
  String get settingsSectionMotionPower;

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
  /// **'خطوط حرّة مرخّصة برخصة SIL للخطوط المفتوحة {version}'**
  String settingsFontsBody(String version);

  /// No description provided for @settingsLicenses.
  ///
  /// In ar, this message translates to:
  /// **'تراخيص البرمجيات المفتوحة'**
  String get settingsLicenses;

  /// No description provided for @settingsLicensesBody.
  ///
  /// In ar, this message translates to:
  /// **'SQLCipher وOpenSSL وFlutter وكل حزمة بُني بها مَدار'**
  String get settingsLicensesBody;

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

  /// Settings section: prayer, adhan, Quran, recitation and reminders
  ///
  /// In ar, this message translates to:
  /// **'الإيمان'**
  String get settingsFaithSection;

  /// Subtitle of the Faith settings section
  ///
  /// In ar, this message translates to:
  /// **'الصلاة والقرآن والتذكير'**
  String get settingsFaithSectionHint;

  /// Settings entry opening the prayer-time settings
  ///
  /// In ar, this message translates to:
  /// **'المواقيت وطريقة الحساب'**
  String get settingsPrayerTimes;

  /// Settings entry opening the adhan settings
  ///
  /// In ar, this message translates to:
  /// **'الأذان والإشعارات'**
  String get settingsAdhan;

  /// Settings section title
  ///
  /// In ar, this message translates to:
  /// **'تذكير الأذكار'**
  String get settingsAdhkarReminders;

  /// Switch: remind of the morning adhkar after Fajr
  ///
  /// In ar, this message translates to:
  /// **'أذكار الصباح بعد الفجر'**
  String get settingsAdhkarMorning;

  /// Switch: remind of the evening adhkar after Asr
  ///
  /// In ar, this message translates to:
  /// **'أذكار المساء بعد العصر'**
  String get settingsAdhkarEvening;

  /// Subtitle of an enabled adhkar reminder; offset is e.g. "20 min"
  ///
  /// In ar, this message translates to:
  /// **'بعد الأذان بـ{offset}'**
  String settingsAdhkarAfter(String offset);

  /// Subtitle of a disabled adhkar reminder
  ///
  /// In ar, this message translates to:
  /// **'لا تذكير'**
  String get settingsAdhkarOff;

  /// Settings section title
  ///
  /// In ar, this message translates to:
  /// **'الخصوصية والأمان'**
  String get settingsSecuritySection;

  /// Settings entry opening the security page
  ///
  /// In ar, this message translates to:
  /// **'قفل التطبيق'**
  String get settingsAppLock;

  /// App lock entry subtitle when no lock is set
  ///
  /// In ar, this message translates to:
  /// **'متوقف؛ اضبط رمزًا ليحمي مَدار'**
  String get settingsAppLockOff;

  /// App lock entry subtitle: PIN only
  ///
  /// In ar, this message translates to:
  /// **'مفعّل بالرمز'**
  String get settingsAppLockOn;

  /// App lock entry subtitle: fingerprint and PIN
  ///
  /// In ar, this message translates to:
  /// **'مفعّل بالبصمة والرمز'**
  String get settingsAppLockOnBio;

  /// Note on the security page
  ///
  /// In ar, this message translates to:
  /// **'يحجب القفلُ ما على الشاشة كلما غبت عن مَدار، أمّا بياناتك فمشفّرة على جهازك دائمًا، مقفلًا كان أو مفتوحًا.'**
  String get settingsSecurityNote;

  /// Settings entry / page listing the bundled fonts and content sources
  ///
  /// In ar, this message translates to:
  /// **'الخطوط والمصادر'**
  String get settingsCredits;

  /// Subtitle of the fonts & sources entry
  ///
  /// In ar, this message translates to:
  /// **'الخطوط المفتوحة، ومصادر القرآن والحديث والأذكار والمدن والنغمات'**
  String get settingsCreditsBody;

  /// Section header on the credits page
  ///
  /// In ar, this message translates to:
  /// **'المحتوى ومصادره'**
  String get settingsCreditsContent;

  /// Intro of the content credits
  ///
  /// In ar, this message translates to:
  /// **'كل نصّ وبيانات وصوت في مَدار مرخّصٌ ترخيصًا مفتوحًا أو من صنعه، وهذه مصادره كاملة.'**
  String get settingsCreditsContentBody;

  /// Content credit title
  ///
  /// In ar, this message translates to:
  /// **'الأذكار — حصن المسلم'**
  String get settingsCreditAdhkar;

  /// Content credit subtitle
  ///
  /// In ar, this message translates to:
  /// **'بيانات مفتوحة (MIT)، ونص القرآن من quran-api'**
  String get settingsCreditAdhkarRole;

  /// Content credit title
  ///
  /// In ar, this message translates to:
  /// **'قائمة المدن'**
  String get settingsCreditCities;

  /// Content credit subtitle
  ///
  /// In ar, this message translates to:
  /// **'Natural Earth وGeoNames وIANA وUnicode CLDR'**
  String get settingsCreditCitiesRole;

  /// Content credit title
  ///
  /// In ar, this message translates to:
  /// **'نغمات الأذان'**
  String get settingsCreditAdhan;

  /// Content credit subtitle
  ///
  /// In ar, this message translates to:
  /// **'من صنع مَدار، ولا تسجيلات صوتية مضمّنة'**
  String get settingsCreditAdhanRole;

  /// Onboarding step: location for prayer times
  ///
  /// In ar, this message translates to:
  /// **'أين تصلّي؟'**
  String get onboardingLocationTitle;

  /// No description provided for @onboardingLocationBody.
  ///
  /// In ar, this message translates to:
  /// **'تُحسب مواقيت الصلاة على جهازك من موقعك، دون إنترنت. اختر مدينتك، أو استخدم موقعك التقريبي مرة واحدة.'**
  String get onboardingLocationBody;

  /// Button opening the location sheet
  ///
  /// In ar, this message translates to:
  /// **'اختر موقعك'**
  String get onboardingLocationSet;

  /// Button opening the location sheet once a place is set
  ///
  /// In ar, this message translates to:
  /// **'غيّر الموقع'**
  String get onboardingLocationChange;

  /// The place prayer times are calculated for
  ///
  /// In ar, this message translates to:
  /// **'مواقيتك في {place}'**
  String onboardingLocationFor(String place);

  /// Onboarding step: adhan permissions
  ///
  /// In ar, this message translates to:
  /// **'الأذان في وقته'**
  String get onboardingAdhanTitle;

  /// No description provided for @onboardingAdhanBody.
  ///
  /// In ar, this message translates to:
  /// **'ليُرفَع الأذان في دقيقته ولو كان الهاتف مقفلًا، يحتاج مَدار بعض أذونات أندرويد. امنحها الآن أو لاحقًا من الإعدادات.'**
  String get onboardingAdhanBody;

  /// Onboarding step: optional app lock
  ///
  /// In ar, this message translates to:
  /// **'احمِ مَدار'**
  String get onboardingLockTitle;

  /// No description provided for @onboardingLockBody.
  ///
  /// In ar, this message translates to:
  /// **'قفلٌ برمز وبصمة يُغلق مَدار كلما غبت عنه. لا حساب ولا خادم؛ يبقى الرمز على جهازك وحده.'**
  String get onboardingLockBody;

  /// Button opening the PIN setup sheet
  ///
  /// In ar, this message translates to:
  /// **'اضبط رمزًا'**
  String get onboardingLockSet;

  /// Shown once a PIN is set during onboarding
  ///
  /// In ar, this message translates to:
  /// **'القفل مفعّل بالرمز'**
  String get onboardingLockOn;

  /// Shown once a PIN and fingerprint are set during onboarding
  ///
  /// In ar, this message translates to:
  /// **'القفل مفعّل بالبصمة والرمز'**
  String get onboardingLockOnBio;

  /// Hint under optional onboarding steps
  ///
  /// In ar, this message translates to:
  /// **'خطوة اختيارية، ويمكنك ضبطها لاحقًا من الإعدادات'**
  String get onboardingOptional;

  /// Home header: the Gregorian date then the Hijri date
  ///
  /// In ar, this message translates to:
  /// **'{gregorian} — {hijri}'**
  String homeDateWithHijri(String gregorian, String hijri);

  /// Chip after the prayer windows opening the prayer times page
  ///
  /// In ar, this message translates to:
  /// **'كل المواقيت'**
  String get homeAllTimes;

  /// Settings entry / page: the Quran reader's settings
  ///
  /// In ar, this message translates to:
  /// **'القراءة والمصحف'**
  String get settingsQuran;

  /// Quran settings entry subtitle part: tajweed colours on
  ///
  /// In ar, this message translates to:
  /// **'بألوان التجويد'**
  String get settingsQuranTajweedOn;

  /// Quran settings entry subtitle part: tajweed colours off
  ///
  /// In ar, this message translates to:
  /// **'بلا ألوان التجويد'**
  String get settingsQuranTajweedOff;

  /// Quran settings: section of layout and text size
  ///
  /// In ar, this message translates to:
  /// **'القراءة'**
  String get settingsQuranReading;

  /// Screen-reader label of the text-size preview
  ///
  /// In ar, this message translates to:
  /// **'معاينة حجم الخط'**
  String get settingsQuranPreviewLabel;

  /// Quran settings: how many suras have the Quran.com tajweed / translation on the device
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لم يُنزَّل شيء بعد} =1{نُزِّل لسورة واحدة} =2{نُزِّل لسورتين} few{نُزِّل لـ{count} سور} many{نُزِّل لـ{count} سورة} other{نُزِّل لـ{count} سورة}}'**
  String settingsQuranDownloaded(int count);

  /// Quran settings: note on downloads
  ///
  /// In ar, this message translates to:
  /// **'تُنزَّل الترجمة وتجويد Quran.com سورةً سورة من إعدادات القارئ، ولا يتصل مَدار بالإنترنت إلا حين تطلب.'**
  String get settingsQuranDownloadNote;

  /// Quran settings: where the text comes from
  ///
  /// In ar, this message translates to:
  /// **'نص المصحف العثماني برواية حفص من مشروع تنزيل، مضمَّن في التطبيق ويعمل دون إنترنت.'**
  String get settingsQuranSourceNote;

  /// Settings entry opening the recitation settings
  ///
  /// In ar, this message translates to:
  /// **'التلاوة والقرّاء'**
  String get settingsRecitation;

  /// Settings entry / page: adhkar and wird reminders
  ///
  /// In ar, this message translates to:
  /// **'التذكيرات'**
  String get settingsReminders;

  /// Subtitle of the reminders entry
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا تذكير مفعّل} =1{تذكير واحد مفعّل} =2{تذكيران مفعّلان} few{{count} تذكيرات مفعّلة} many{{count} تذكيرًا مفعّلًا} other{{count} تذكير مفعّل}}'**
  String settingsRemindersCount(int count);

  /// Settings section title
  ///
  /// In ar, this message translates to:
  /// **'تذكير الوِرد'**
  String get settingsWirdReminders;

  /// Wird reminders when there is no plan
  ///
  /// In ar, this message translates to:
  /// **'لا خطة وِرد بعد. ابدأ خطة، ويصلك تذكيرها بعد الصلاة التي تختارها.'**
  String get settingsWirdNoPlans;

  /// Settings tile opening the wird screen
  ///
  /// In ar, this message translates to:
  /// **'خطط الوِرد'**
  String get settingsWirdOpen;

  /// Wird reminder subtitle: the plan has no prayer window
  ///
  /// In ar, this message translates to:
  /// **'اختر للخطة صلاةً ليصلك تذكيرها'**
  String get settingsWirdNoWindow;

  /// Wird reminder subtitle: the plan is paused
  ///
  /// In ar, this message translates to:
  /// **'الخطة متوقفة، فلا تذكير'**
  String get settingsWirdPaused;

  /// Button: open the plan editor to pick a prayer
  ///
  /// In ar, this message translates to:
  /// **'عدّل الخطة'**
  String get settingsWirdEditPlan;

  /// Note under the wird reminders
  ///
  /// In ar, this message translates to:
  /// **'يصل التذكير بعد الصلاة التي اخترتها للخطة، ولا يصل يومَ تقرأ وِردك قبله.'**
  String get settingsWirdReminderNote;

  /// Content credit title
  ///
  /// In ar, this message translates to:
  /// **'القرآن الكريم — تنزيل'**
  String get settingsCreditQuran;

  /// Content credit subtitle
  ///
  /// In ar, this message translates to:
  /// **'النص العثماني وبياناته، وعلامات التجويد — تراخيص المشاع الإبداعي'**
  String get settingsCreditQuranRole;

  /// Content credit title
  ///
  /// In ar, this message translates to:
  /// **'الأربعون النووية'**
  String get settingsCreditHadith;

  /// Content credit subtitle
  ///
  /// In ar, this message translates to:
  /// **'النص العربي من hadith-api، ملكٌ عام'**
  String get settingsCreditHadithRole;

  /// Content credit title
  ///
  /// In ar, this message translates to:
  /// **'التلاوات — EveryAyah'**
  String get settingsCreditRecitation;

  /// Content credit subtitle
  ///
  /// In ar, this message translates to:
  /// **'تُبثّ أو تُنزَّل بطلبك فقط، ولا صوت مضمَّن'**
  String get settingsCreditRecitationRole;

  /// Content credit title
  ///
  /// In ar, this message translates to:
  /// **'بوصلة القبلة — النموذج المغناطيسي العالمي'**
  String get settingsCreditQibla;

  /// Content credit subtitle
  ///
  /// In ar, this message translates to:
  /// **'نموذج WMM من NOAA وBGS، ملكٌ عام'**
  String get settingsCreditQiblaRole;

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
  /// **'التواصل مع الناس'**
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

  /// Implicit score source: how recently anything was done for a planet that has no other data
  ///
  /// In ar, this message translates to:
  /// **'النشاط المسجَّل'**
  String get orbitSourceActivity;

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

  /// Screen-reader label of a data moon (a person, wallet, board, trip or module orbiting its planet)
  ///
  /// In ar, this message translates to:
  /// **'{name}، قمرٌ يدور حول {planet}'**
  String orbitMoonSemantics(String name, String planet);

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

  /// Customisation error: empty planet name
  ///
  /// In ar, this message translates to:
  /// **'اكتب اسمًا للكوكب'**
  String get orbitPlanetNeedsName;

  /// Customisation error: a score source that does not exist
  ///
  /// In ar, this message translates to:
  /// **'مصدر البيانات هذا غير متاح'**
  String get orbitUnknownSource;

  /// Customisation error: the planet was deleted meanwhile (a stale sheet)
  ///
  /// In ar, this message translates to:
  /// **'لم يعُد هذا الكوكب في مدارك'**
  String get orbitPlanetGone;

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

  /// Star name engraved on the astrolabe rete pointer (traditional Arabic star name)
  ///
  /// In ar, this message translates to:
  /// **'ذنب قيطس'**
  String get astrolabeStarDenebKaitos;

  /// Star name engraved on the astrolabe rete pointer (traditional Arabic star name)
  ///
  /// In ar, this message translates to:
  /// **'منخر قيطس'**
  String get astrolabeStarMenkar;

  /// Star name engraved on the astrolabe rete pointer (traditional Arabic star name)
  ///
  /// In ar, this message translates to:
  /// **'الدبران'**
  String get astrolabeStarAldebaran;

  /// Star name engraved on the astrolabe rete pointer (traditional Arabic star name)
  ///
  /// In ar, this message translates to:
  /// **'رجل الجبار'**
  String get astrolabeStarRigel;

  /// Star name engraved on the astrolabe rete pointer (traditional Arabic star name)
  ///
  /// In ar, this message translates to:
  /// **'يد الجوزاء'**
  String get astrolabeStarBetelgeuse;

  /// Star name engraved on the astrolabe rete pointer (traditional Arabic star name)
  ///
  /// In ar, this message translates to:
  /// **'الشعرى اليمانية'**
  String get astrolabeStarSirius;

  /// Star name engraved on the astrolabe rete pointer (traditional Arabic star name)
  ///
  /// In ar, this message translates to:
  /// **'الشعرى الشامية'**
  String get astrolabeStarProcyon;

  /// Star name engraved on the astrolabe rete pointer (traditional Arabic star name)
  ///
  /// In ar, this message translates to:
  /// **'فرد الشجاع'**
  String get astrolabeStarAlphard;

  /// Star name engraved on the astrolabe rete pointer (traditional Arabic star name)
  ///
  /// In ar, this message translates to:
  /// **'قلب الأسد'**
  String get astrolabeStarRegulus;

  /// Star name engraved on the astrolabe rete pointer (traditional Arabic star name)
  ///
  /// In ar, this message translates to:
  /// **'ذنب الأسد'**
  String get astrolabeStarDenebola;

  /// Star name engraved on the astrolabe rete pointer (traditional Arabic star name)
  ///
  /// In ar, this message translates to:
  /// **'السماك الأعزل'**
  String get astrolabeStarSpica;

  /// Star name engraved on the astrolabe rete pointer (traditional Arabic star name)
  ///
  /// In ar, this message translates to:
  /// **'السماك الرامح'**
  String get astrolabeStarArcturus;

  /// Star name engraved on the astrolabe rete pointer (traditional Arabic star name)
  ///
  /// In ar, this message translates to:
  /// **'عنق الحية'**
  String get astrolabeStarUnukalhai;

  /// Star name engraved on the astrolabe rete pointer (traditional Arabic star name)
  ///
  /// In ar, this message translates to:
  /// **'رأس الحوّاء'**
  String get astrolabeStarRasAlhague;

  /// Star name engraved on the astrolabe rete pointer (traditional Arabic star name)
  ///
  /// In ar, this message translates to:
  /// **'النسر الطائر'**
  String get astrolabeStarAltair;

  /// Star name engraved on the astrolabe rete pointer (traditional Arabic star name)
  ///
  /// In ar, this message translates to:
  /// **'ذنب الجدي'**
  String get astrolabeStarDenebAlgedi;

  /// Star name engraved on the astrolabe rete pointer (traditional Arabic star name)
  ///
  /// In ar, this message translates to:
  /// **'مركب الفرس'**
  String get astrolabeStarMarkab;

  /// Zodiac sign engraved on the astrolabe ecliptic ring (traditional Arabic name)
  ///
  /// In ar, this message translates to:
  /// **'الحمل'**
  String get astrolabeZodiacAries;

  /// Zodiac sign engraved on the astrolabe ecliptic ring (traditional Arabic name)
  ///
  /// In ar, this message translates to:
  /// **'الثور'**
  String get astrolabeZodiacTaurus;

  /// Zodiac sign engraved on the astrolabe ecliptic ring (traditional Arabic name)
  ///
  /// In ar, this message translates to:
  /// **'الجوزاء'**
  String get astrolabeZodiacGemini;

  /// Zodiac sign engraved on the astrolabe ecliptic ring (traditional Arabic name)
  ///
  /// In ar, this message translates to:
  /// **'السرطان'**
  String get astrolabeZodiacCancer;

  /// Zodiac sign engraved on the astrolabe ecliptic ring (traditional Arabic name)
  ///
  /// In ar, this message translates to:
  /// **'الأسد'**
  String get astrolabeZodiacLeo;

  /// Zodiac sign engraved on the astrolabe ecliptic ring (traditional Arabic name)
  ///
  /// In ar, this message translates to:
  /// **'السنبلة'**
  String get astrolabeZodiacVirgo;

  /// Zodiac sign engraved on the astrolabe ecliptic ring (traditional Arabic name)
  ///
  /// In ar, this message translates to:
  /// **'الميزان'**
  String get astrolabeZodiacLibra;

  /// Zodiac sign engraved on the astrolabe ecliptic ring (traditional Arabic name)
  ///
  /// In ar, this message translates to:
  /// **'العقرب'**
  String get astrolabeZodiacScorpio;

  /// Zodiac sign engraved on the astrolabe ecliptic ring (traditional Arabic name)
  ///
  /// In ar, this message translates to:
  /// **'القوس'**
  String get astrolabeZodiacSagittarius;

  /// Zodiac sign engraved on the astrolabe ecliptic ring (traditional Arabic name)
  ///
  /// In ar, this message translates to:
  /// **'الجدي'**
  String get astrolabeZodiacCapricorn;

  /// Zodiac sign engraved on the astrolabe ecliptic ring (traditional Arabic name)
  ///
  /// In ar, this message translates to:
  /// **'الدلو'**
  String get astrolabeZodiacAquarius;

  /// Zodiac sign engraved on the astrolabe ecliptic ring (traditional Arabic name)
  ///
  /// In ar, this message translates to:
  /// **'الحوت'**
  String get astrolabeZodiacPisces;

  /// Lower band of a small astrolabe hub under the engraved clock: which prayer the countdown runs to, e.g. «حتى العصر»
  ///
  /// In ar, this message translates to:
  /// **'حتى {prayer}'**
  String astrolabeCountdownUntil(String prayer);

  /// Lower band of a small astrolabe hub (under the prayer name) the moment the prayer begins
  ///
  /// In ar, this message translates to:
  /// **'حان وقتها'**
  String get astrolabeCountdownNowBand;

  /// Screen-reader description of the living sky behind the orbit, e.g. «السماء الآن: ليل. القمر بدر، مضاء بنسبة ٩٨٪»
  ///
  /// In ar, this message translates to:
  /// **'السماء الآن: {sky}. {moon}'**
  String skySemantics(String sky, String moon);

  /// Look of the sky: full night
  ///
  /// In ar, this message translates to:
  /// **'ليل'**
  String get skyMoodNight;

  /// Look of the sky: morning twilight (from Fajr)
  ///
  /// In ar, this message translates to:
  /// **'فجر'**
  String get skyMoodDawn;

  /// Look of the sky: the sun rising
  ///
  /// In ar, this message translates to:
  /// **'شروق'**
  String get skyMoodSunrise;

  /// Look of the sky: daylight
  ///
  /// In ar, this message translates to:
  /// **'نهار صافٍ'**
  String get skyMoodDay;

  /// Look of the sky: the low warm sun before sunset
  ///
  /// In ar, this message translates to:
  /// **'الساعة الذهبية'**
  String get skyMoodGoldenHour;

  /// Look of the sky: the sun setting (Maghrib)
  ///
  /// In ar, this message translates to:
  /// **'غروب'**
  String get skyMoodSunset;

  /// Look of the sky: evening twilight after Maghrib
  ///
  /// In ar, this message translates to:
  /// **'شفق المغرب'**
  String get skyMoodDusk;

  /// Screen-reader note when the moon has not risen
  ///
  /// In ar, this message translates to:
  /// **'القمر تحت الأفق'**
  String get skyMoonBelow;

  /// Moon phase and illuminated fraction, e.g. «القمر بدر، مضاء بنسبة ٩٨٪»
  ///
  /// In ar, this message translates to:
  /// **'القمر {phase}، مضاء بنسبة {percent}'**
  String skyMoonPhase(String phase, String percent);

  /// Moon phase name
  ///
  /// In ar, this message translates to:
  /// **'محاق'**
  String get skyMoonNew;

  /// Moon phase name
  ///
  /// In ar, this message translates to:
  /// **'هلال متزايد'**
  String get skyMoonWaxingCrescent;

  /// Moon phase name
  ///
  /// In ar, this message translates to:
  /// **'تربيع أول'**
  String get skyMoonFirstQuarter;

  /// Moon phase name
  ///
  /// In ar, this message translates to:
  /// **'أحدب متزايد'**
  String get skyMoonWaxingGibbous;

  /// Moon phase name
  ///
  /// In ar, this message translates to:
  /// **'بدر'**
  String get skyMoonFull;

  /// Moon phase name
  ///
  /// In ar, this message translates to:
  /// **'أحدب متناقص'**
  String get skyMoonWaningGibbous;

  /// Moon phase name
  ///
  /// In ar, this message translates to:
  /// **'تربيع أخير'**
  String get skyMoonLastQuarter;

  /// Moon phase name
  ///
  /// In ar, this message translates to:
  /// **'هلال متناقص'**
  String get skyMoonWaningCrescent;

  /// Toggle: show the traditional names of the brightest stars in the sky
  ///
  /// In ar, this message translates to:
  /// **'أسماء النجوم'**
  String get skyStarNames;

  /// Explanation under the star-names toggle
  ///
  /// In ar, this message translates to:
  /// **'تُنقش الأسماء العربية لألمع النجوم في سماء الليل'**
  String get skyStarNamesHint;

  /// Screen-reader label of the planet layer of the orbit (n = count formatted with the user's digits)
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{مدار حياتك بلا عوالم ظاهرة} =1{مدار حياتك: عالم واحد يدور حول نجمك} =2{مدار حياتك: عالمان يدوران حول نجمك} few{مدار حياتك: {n} عوالم تدور حول نجمك} many{مدار حياتك: {n} عالمًا يدور حول نجمك} other{مدار حياتك: {n} عالم يدور حول نجمك}}'**
  String planetsSystemSemantics(int count, String n);

  /// Screen-reader hint for tapping a planet (a cinematic fly-in opens its module)
  ///
  /// In ar, this message translates to:
  /// **'ادخل إلى هذا العالم'**
  String get planetsOpenHint;

  /// Screen-reader hint for long-pressing a planet (opens its customisation sheet)
  ///
  /// In ar, this message translates to:
  /// **'خصّص هذا العالم'**
  String get planetsCustomizeHint;

  /// Screen-reader hint for tapping a data moon (opens that person, wallet, board or trip)
  ///
  /// In ar, this message translates to:
  /// **'افتح'**
  String get planetsMoonOpenHint;

  /// How many data moons orbit a planet, read after the planet's label (n = count formatted with the user's digits)
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{بلا أقمار} =1{قمر واحد} =2{قمران} few{{n} أقمار} many{{n} قمرًا} other{{n} قمر}}'**
  String planetsMoonsCount(int count, String n);

  /// Screen-reader hint of the whole orbit scene on home
  ///
  /// In ar, this message translates to:
  /// **'اسحب لتدوير المدار، وباعد بإصبعين للاقتراب من عالم'**
  String get orbitUiSceneHint;

  /// Button shown after rotating or zooming the orbit; returns the camera to the overview
  ///
  /// In ar, this message translates to:
  /// **'العودة إلى المدار كاملًا'**
  String get orbitUiRecenter;

  /// Neglect Radar when no planet has a neglect reason
  ///
  /// In ar, this message translates to:
  /// **'عوالمك كلها في توازن — لا شيء يحتاج انتباهك الآن'**
  String get orbitUiRadarClear;

  /// Neglect Radar before any planet has data
  ///
  /// In ar, this message translates to:
  /// **'سيبدأ الرادار عمله حين تسجّل أول أنشطتك'**
  String get orbitUiRadarWaiting;

  /// Screen-reader label of one Neglect Radar entry
  ///
  /// In ar, this message translates to:
  /// **'{planet}: {reason}'**
  String orbitUiRadarEntrySemantics(String planet, String reason);

  /// Screen-reader hint of a Neglect Radar entry
  ///
  /// In ar, this message translates to:
  /// **'انتقل إلى هذا العالم'**
  String get orbitUiRadarOpenHint;

  /// Caption under a planet's score ring
  ///
  /// In ar, this message translates to:
  /// **'التوازن'**
  String get orbitUiBalanceLabel;

  /// How much a planet counts in the overall balance (weight already formatted)
  ///
  /// In ar, this message translates to:
  /// **'وزنه في توازنك ×{weight}'**
  String orbitUiPlanetWeight(String weight);

  /// Planet with weight 0
  ///
  /// In ar, this message translates to:
  /// **'لا يُحتسب في توازنك'**
  String get orbitUiPlanetNotCounted;

  /// Section title on a planet page listing its neglect reasons
  ///
  /// In ar, this message translates to:
  /// **'ما يحتاج عنايتك'**
  String get orbitUiReasonsTitle;

  /// Planet page when the planet has no neglect reasons
  ///
  /// In ar, this message translates to:
  /// **'لا شيء متأخر هنا — أحسنت'**
  String get orbitUiReasonsNone;

  /// Planet page when the planet has no data yet
  ///
  /// In ar, this message translates to:
  /// **'هذا العالم هادئ بانتظار أول بياناتك'**
  String get orbitUiReasonsDormant;

  /// Section title listing the score sources of a planet
  ///
  /// In ar, this message translates to:
  /// **'ما يغذّي هذا التوازن'**
  String get orbitUiSourcesTitle;

  /// Section title listing the data moons of a planet
  ///
  /// In ar, this message translates to:
  /// **'الأقمار'**
  String get orbitUiMoonsTitle;

  /// Planet page with no data moons
  ///
  /// In ar, this message translates to:
  /// **'لا أقمار تدور حول هذا العالم بعد'**
  String get orbitUiMoonsNone;

  /// Kind of a data moon: a person around Family
  ///
  /// In ar, this message translates to:
  /// **'شخص'**
  String get orbitUiMoonKindPerson;

  /// Kind of a data moon: a wallet around Money
  ///
  /// In ar, this message translates to:
  /// **'محفظة'**
  String get orbitUiMoonKindWallet;

  /// Kind of a data moon: a work board around Work
  ///
  /// In ar, this message translates to:
  /// **'لوحة عمل'**
  String get orbitUiMoonKindBoard;

  /// Kind of a data moon: a trip around Travel
  ///
  /// In ar, this message translates to:
  /// **'رحلة'**
  String get orbitUiMoonKindTrip;

  /// Kind of a data moon: a custom module
  ///
  /// In ar, this message translates to:
  /// **'وحدة'**
  String get orbitUiMoonKindModule;

  /// How fresh / attended a data moon is (percent formatted)
  ///
  /// In ar, this message translates to:
  /// **'حيويته {percent}'**
  String orbitUiMoonFreshness(String percent);

  /// Badge on the moon row that was tapped in the orbit
  ///
  /// In ar, this message translates to:
  /// **'القمر الذي اخترته'**
  String get orbitUiMoonSelected;

  /// Button opening the planet customisation sheet
  ///
  /// In ar, this message translates to:
  /// **'تخصيص'**
  String get orbitUiCustomize;

  /// Title of the planet customisation sheet
  ///
  /// In ar, this message translates to:
  /// **'تخصيص {planet}'**
  String orbitUiCustomizeTitle(String planet);

  /// Subtitle of the planet customisation sheet
  ///
  /// In ar, this message translates to:
  /// **'كل تغيير يمكن التراجع عنه'**
  String get orbitUiCustomizeSubtitle;

  /// Customisation action: rename, recolour, restyle
  ///
  /// In ar, this message translates to:
  /// **'الاسم والمظهر'**
  String get orbitUiEditLook;

  /// Customisation action: planet weight
  ///
  /// In ar, this message translates to:
  /// **'أهميته في التوازن'**
  String get orbitUiEditWeight;

  /// Customisation action: which data feeds the score and how much
  ///
  /// In ar, this message translates to:
  /// **'مصادر البيانات'**
  String get orbitUiEditSources;

  /// Customisation action: reorder the planet among the orbits
  ///
  /// In ar, this message translates to:
  /// **'نقل مداره'**
  String get orbitUiMoveOrbit;

  /// Customisation action: hide the planet (its data stays)
  ///
  /// In ar, this message translates to:
  /// **'إخفاء من المدار'**
  String get orbitUiHide;

  /// Customisation action: reset a built-in planet
  ///
  /// In ar, this message translates to:
  /// **'استعادة الإعدادات الأصلية'**
  String get orbitUiReset;

  /// Customisation action: delete a user-added planet
  ///
  /// In ar, this message translates to:
  /// **'حذف هذا العالم'**
  String get orbitUiDelete;

  /// Customisation action: add a planet
  ///
  /// In ar, this message translates to:
  /// **'إضافة عالم جديد'**
  String get orbitUiAddPlanet;

  /// Customisation action / sheet title: show a hidden planet again
  ///
  /// In ar, this message translates to:
  /// **'العوالم المخفية'**
  String get orbitUiHiddenWorlds;

  /// Field: planet name
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get orbitUiFieldName;

  /// Field: planet colour
  ///
  /// In ar, this message translates to:
  /// **'اللون'**
  String get orbitUiFieldColor;

  /// Field: planet archetype (surface look)
  ///
  /// In ar, this message translates to:
  /// **'طراز العالم'**
  String get orbitUiFieldStyle;

  /// Field: planet weight slider
  ///
  /// In ar, this message translates to:
  /// **'الأهمية'**
  String get orbitUiFieldWeight;

  /// Weight slider label at 0
  ///
  /// In ar, this message translates to:
  /// **'لا يُحتسب'**
  String get orbitUiWeightNone;

  /// Weight slider label at 1×
  ///
  /// In ar, this message translates to:
  /// **'عادي'**
  String get orbitUiWeightNormal;

  /// Weight slider label at the maximum
  ///
  /// In ar, this message translates to:
  /// **'الأهم'**
  String get orbitUiWeightMost;

  /// Subtitle of the data sources sheet
  ///
  /// In ar, this message translates to:
  /// **'حرّك المصدر إلى الصفر لإيقافه'**
  String get orbitUiSourcesHint;

  /// Source weight slider label at 0
  ///
  /// In ar, this message translates to:
  /// **'متوقف'**
  String get orbitUiSourceOff;

  /// Title of the move-orbit sheet
  ///
  /// In ar, this message translates to:
  /// **'موضع المدار'**
  String get orbitUiMoveTitle;

  /// Subtitle of the move-orbit sheet
  ///
  /// In ar, this message translates to:
  /// **'الأقرب إلى نجمك أولًا'**
  String get orbitUiMoveSubtitle;

  /// Move-orbit target: put the planet just inside another one
  ///
  /// In ar, this message translates to:
  /// **'قبل {planet}'**
  String orbitUiMoveBefore(String planet);

  /// Move-orbit target: the last orbit
  ///
  /// In ar, this message translates to:
  /// **'المدار الأبعد'**
  String get orbitUiMoveLast;

  /// Subtitle of a move target: its orbit number (n formatted)
  ///
  /// In ar, this message translates to:
  /// **'المدار {n}'**
  String orbitUiOrbitNumber(String n);

  /// Subtitle of the prayer sheet (time formatted)
  ///
  /// In ar, this message translates to:
  /// **'وقتها {time}'**
  String orbitUiPrayerAt(String time);

  /// Prayer sheet action: log as prayed on time
  ///
  /// In ar, this message translates to:
  /// **'صلّيتها'**
  String get orbitUiPrayerPrayed;

  /// Prayer sheet action: log as prayed late
  ///
  /// In ar, this message translates to:
  /// **'صلّيتها متأخرة'**
  String get orbitUiPrayerLate;

  /// Prayer sheet action: log as missed
  ///
  /// In ar, this message translates to:
  /// **'فاتتني'**
  String get orbitUiPrayerMissed;

  /// Prayer sheet action: remove today's log of this prayer
  ///
  /// In ar, this message translates to:
  /// **'إلغاء التسجيل'**
  String get orbitUiPrayerClear;

  /// Prayer sheet: the prayer is still upcoming
  ///
  /// In ar, this message translates to:
  /// **'لم يدخل وقتها بعد'**
  String get orbitUiPrayerNotYet;

  /// Undo toast after logging a prayer
  ///
  /// In ar, this message translates to:
  /// **'سُجّلت صلاة {prayer}'**
  String orbitUiPrayerLogged(String prayer);

  /// Undo toast after clearing a prayer log
  ///
  /// In ar, this message translates to:
  /// **'أُلغي تسجيل {prayer}'**
  String orbitUiPrayerCleared(String prayer);

  /// Screen-reader hint of a prayer pointer on the astrolabe
  ///
  /// In ar, this message translates to:
  /// **'سجّل هذه الصلاة'**
  String get orbitUiPrayerHint;

  /// Planet page opened for a planet that was hidden or deleted
  ///
  /// In ar, this message translates to:
  /// **'هذا العالم لم يعد في مدارك'**
  String get orbitUiPlanetMissing;

  /// Back button of a planet page (screen reader and missing-planet state)
  ///
  /// In ar, this message translates to:
  /// **'العودة إلى المدار'**
  String get orbitUiBackToOrbit;

  /// Countdown on the next prayer's window chip (duration formatted, e.g. ١ س ٢٣ د)
  ///
  /// In ar, this message translates to:
  /// **'بعد {duration}'**
  String orbitUiInDuration(String duration);

  /// Prayer sheet: the achieved state of a prayer already logged as prayed (shown with a lit flame and a check)
  ///
  /// In ar, this message translates to:
  /// **'صُلّيت {time}'**
  String orbitUiPrayerPrayedAt(String time);

  /// Prayer sheet: the achieved state of a prayer logged as prayed late
  ///
  /// In ar, this message translates to:
  /// **'صُلّيت متأخرة {time}'**
  String orbitUiPrayerLateAt(String time);

  /// Moon sheet subtitle: what the record is and which world it orbits
  ///
  /// In ar, this message translates to:
  /// **'{kind} في {planet}'**
  String orbitUiMoonOf(String kind, String planet);

  /// Moon sheet action for a person: log that you were in touch today
  ///
  /// In ar, this message translates to:
  /// **'تواصلت اليوم'**
  String get orbitUiMoonInTouch;

  /// Undo toast after logging contact with a person
  ///
  /// In ar, this message translates to:
  /// **'سُجّل تواصلك مع {name}'**
  String orbitUiMoonInTouchLogged(String name);

  /// Moon sheet action: rename the record
  ///
  /// In ar, this message translates to:
  /// **'إعادة التسمية'**
  String get orbitUiMoonRename;

  /// Undo toast after renaming a record from its moon
  ///
  /// In ar, this message translates to:
  /// **'تمت إعادة التسمية'**
  String get orbitUiMoonRenamed;

  /// Moon sheet detail line for a person
  ///
  /// In ar, this message translates to:
  /// **'آخر تواصل: {when}'**
  String orbitUiMoonLastContact(String when);

  /// Moon sheet detail line for a trip
  ///
  /// In ar, this message translates to:
  /// **'تبدأ في {date}'**
  String orbitUiMoonTripStarts(String date);

  /// Moon sheet: no last-contact date yet
  ///
  /// In ar, this message translates to:
  /// **'لم يُسجَّل بعد'**
  String get orbitUiMoonNever;

  /// Joins two short parts of one line (e.g. a state and a percentage); keeps the separator translatable
  ///
  /// In ar, this message translates to:
  /// **'{a} · {b}'**
  String orbitUiListSeparator(String a, String b);

  /// Compact progress inside a small ring, e.g. «١/٢» tasks done
  ///
  /// In ar, this message translates to:
  /// **'{done}/{total}'**
  String orbitUiFraction(String done, String total);

  /// Prayer sheet: the achieved state of a prayer logged as prayed when the log time is unknown (imported or back-filled)
  ///
  /// In ar, this message translates to:
  /// **'صُلّيت'**
  String get orbitUiPrayerDone;

  /// Prayer sheet: the achieved state of a prayer logged as prayed late when the log time is unknown
  ///
  /// In ar, this message translates to:
  /// **'صُلّيت متأخرة'**
  String get orbitUiPrayerLateDone;

  /// Screen-reader label of the home panel's grabber while the panel peeks (tap expands it)
  ///
  /// In ar, this message translates to:
  /// **'عرض مهام هذا الوقت ورادار الإهمال'**
  String get orbitUiPanelExpand;

  /// Screen-reader label of the home panel's grabber while the panel is expanded (tap folds it)
  ///
  /// In ar, this message translates to:
  /// **'طيّ اللوحة وإظهار المدار'**
  String get orbitUiPanelCollapse;

  /// Joins a planet's name and its neglect reason on the one-line Neglect Radar (keep the spaces)
  ///
  /// In ar, this message translates to:
  /// **' — '**
  String get orbitUiRadarLineJoin;

  /// Section on the Faith planet page: today's five prayers on a small dial
  ///
  /// In ar, this message translates to:
  /// **'صلوات اليوم'**
  String get orbitUiTodayPrayersTitle;

  /// Centre of the Faith page's prayer dial / its screen-reader summary (numbers already formatted)
  ///
  /// In ar, this message translates to:
  /// **'صلّيت {done} من {total}'**
  String orbitUiPrayersProgress(String done, String total);

  /// Status of one prayer on the Faith page
  ///
  /// In ar, this message translates to:
  /// **'صُلّيت'**
  String get orbitUiPrayerStatusPrayed;

  /// Status of one prayer on the Faith page
  ///
  /// In ar, this message translates to:
  /// **'حان وقتها'**
  String get orbitUiPrayerStatusDue;

  /// Status of one prayer on the Faith page
  ///
  /// In ar, this message translates to:
  /// **'فاتت'**
  String get orbitUiPrayerStatusMissed;

  /// Status of one prayer on the Faith page
  ///
  /// In ar, this message translates to:
  /// **'قادمة'**
  String get orbitUiPrayerStatusUpcoming;

  /// Section on the Faith planet page: Quran wird and adhkar progress
  ///
  /// In ar, this message translates to:
  /// **'الورد والأذكار'**
  String get orbitUiWirdTitle;

  /// Section on a planet page listing today's tasks attached to the planet
  ///
  /// In ar, this message translates to:
  /// **'اليوم في هذا العالم'**
  String get orbitUiWorldTasksTitle;

  /// A planet page with no tasks today
  ///
  /// In ar, this message translates to:
  /// **'لا شيء مخطّط لهذا العالم اليوم'**
  String get orbitUiWorldTasksNone;

  /// Screen-reader label of one score source bar on a planet page (value already formatted)
  ///
  /// In ar, this message translates to:
  /// **'{source}: {value}'**
  String orbitUiSourceSemantics(String source, String value);

  /// A data moon's meter when it has had no attention at all (instead of a lone 0 %)
  ///
  /// In ar, this message translates to:
  /// **'بانتظارك'**
  String get orbitUiMoonWaiting;

  /// Line under the app name on the lock screen
  ///
  /// In ar, this message translates to:
  /// **'بياناتك مشفّرة ومحفوظة على هاتفك'**
  String get lockScreenSubtitle;

  /// No description provided for @lockHoldHint.
  ///
  /// In ar, this message translates to:
  /// **'اضغط مطوّلًا على الأسطرلاب لتفتح مَدار'**
  String get lockHoldHint;

  /// No description provided for @lockHoldingHint.
  ///
  /// In ar, this message translates to:
  /// **'أبقِ إصبعك… الأسطرلاب يكتمل'**
  String get lockHoldingHint;

  /// No description provided for @lockReadingHint.
  ///
  /// In ar, this message translates to:
  /// **'المس مستشعر البصمة'**
  String get lockReadingHint;

  /// No description provided for @lockReleasedEarly.
  ///
  /// In ar, this message translates to:
  /// **'أبقِ إصبعك حتى يكتمل الأسطرلاب'**
  String get lockReleasedEarly;

  /// No description provided for @lockWelcome.
  ///
  /// In ar, this message translates to:
  /// **'أهلًا بعودتك'**
  String get lockWelcome;

  /// No description provided for @lockPinHint.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رمز مَدار'**
  String get lockPinHint;

  /// No description provided for @lockPinChecking.
  ///
  /// In ar, this message translates to:
  /// **'نتحقّق…'**
  String get lockPinChecking;

  /// count selects the plural; n is the same number formatted for display
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{رمز غير صحيح} =1{رمز غير صحيح · تبقّت محاولة واحدة قبل الإيقاف المؤقت} =2{رمز غير صحيح · تبقّت محاولتان قبل الإيقاف المؤقت} few{رمز غير صحيح · تبقّت {n} محاولات قبل الإيقاف المؤقت} many{رمز غير صحيح · تبقّت {n} محاولة قبل الإيقاف المؤقت} other{رمز غير صحيح · تبقّت {n} محاولة قبل الإيقاف المؤقت}}'**
  String lockPinWrong(int count, String n);

  /// time is a pre-formatted m:ss countdown
  ///
  /// In ar, this message translates to:
  /// **'محاولات كثيرة. حاول مجددًا بعد {time}'**
  String lockLockedOut(String time);

  /// count selects the plural; n is the same number formatted for display
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{ثانية واحدة} =2{ثانيتين} few{{n} ثوانٍ} many{{n} ثانية} other{{n} ثانية}}'**
  String lockSeconds(int count, String n);

  /// No description provided for @lockUsePin.
  ///
  /// In ar, this message translates to:
  /// **'استخدم الرمز'**
  String get lockUsePin;

  /// No description provided for @lockUseFingerprint.
  ///
  /// In ar, this message translates to:
  /// **'استخدم البصمة'**
  String get lockUseFingerprint;

  /// No description provided for @lockForgotPin.
  ///
  /// In ar, this message translates to:
  /// **'نسيت الرمز؟'**
  String get lockForgotPin;

  /// Title of the system fingerprint prompt (max 60 characters)
  ///
  /// In ar, this message translates to:
  /// **'افتح مَدار'**
  String get lockPromptTitle;

  /// Subtitle of the system fingerprint prompt (max 60 characters)
  ///
  /// In ar, this message translates to:
  /// **'استخدم بصمتك'**
  String get lockPromptHint;

  /// No description provided for @lockPromptReason.
  ///
  /// In ar, this message translates to:
  /// **'تحقّق من هويتك لتفتح بياناتك'**
  String get lockPromptReason;

  /// No description provided for @lockPromptSettingsReason.
  ///
  /// In ar, this message translates to:
  /// **'تحقّق من هويتك لتغيير إعدادات القفل'**
  String get lockPromptSettingsReason;

  /// Negative button of the system fingerprint prompt (max 30 characters)
  ///
  /// In ar, this message translates to:
  /// **'استخدم الرمز'**
  String get lockPromptCancel;

  /// Negative button of the fingerprint prompt in settings (max 30 characters)
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get lockPromptCancelPlain;

  /// No description provided for @lockStorageError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّرت قراءة الخزنة الآمنة على هاتفك.'**
  String get lockStorageError;

  /// No description provided for @lockRetry.
  ///
  /// In ar, this message translates to:
  /// **'أعِد المحاولة'**
  String get lockRetry;

  /// No description provided for @lockAstrolabeSemantics.
  ///
  /// In ar, this message translates to:
  /// **'الأسطرلاب. اضغط مطوّلًا لتفتح القفل بالبصمة'**
  String get lockAstrolabeSemantics;

  /// No description provided for @lockAstrolabeAction.
  ///
  /// In ar, this message translates to:
  /// **'افتح بالبصمة'**
  String get lockAstrolabeAction;

  /// No description provided for @lockPinProgress.
  ///
  /// In ar, this message translates to:
  /// **'أُدخل {count} من {total}'**
  String lockPinProgress(String count, String total);

  /// No description provided for @lockPinProgressOpen.
  ///
  /// In ar, this message translates to:
  /// **'أُدخل {count}'**
  String lockPinProgressOpen(String count);

  /// No description provided for @lockKeyDelete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get lockKeyDelete;

  /// No description provided for @lockKeyFingerprint.
  ///
  /// In ar, this message translates to:
  /// **'البصمة'**
  String get lockKeyFingerprint;

  /// No description provided for @lockKeyDone.
  ///
  /// In ar, this message translates to:
  /// **'تم'**
  String get lockKeyDone;

  /// No description provided for @lockShieldSemantics.
  ///
  /// In ar, this message translates to:
  /// **'مَدار مخفيّ حتى تعود'**
  String get lockShieldSemantics;

  /// No description provided for @lockForgotTitle.
  ///
  /// In ar, this message translates to:
  /// **'نسيت الرمز؟'**
  String get lockForgotTitle;

  /// No description provided for @lockForgotBody.
  ///
  /// In ar, this message translates to:
  /// **'لا حساب في مَدار ولا خادم: بياناتك مشفّرة ومحفوظة على هذا الهاتف وحده، لذلك لا يمكن استرجاع الرمز ولا إعادة تعيينه عن بُعد.'**
  String get lockForgotBody;

  /// No description provided for @lockForgotBiometric.
  ///
  /// In ar, this message translates to:
  /// **'تحقّق ببصمتك، ثم اختر رمزًا جديدًا.'**
  String get lockForgotBiometric;

  /// No description provided for @lockForgotBiometricAction.
  ///
  /// In ar, this message translates to:
  /// **'تحقّق بالبصمة'**
  String get lockForgotBiometricAction;

  /// No description provided for @lockForgotNoBiometric.
  ///
  /// In ar, this message translates to:
  /// **'من دون الرمز يبقى مَدار مقفلًا. إن تعذّر عليك تذكّره فالسبيل الوحيد مسح بيانات مَدار من إعدادات الهاتف (التطبيقات ← مَدار ← التخزين ← مسح البيانات) والبدء من جديد، وسيضيع كل ما ليس في نسخة احتياطية.'**
  String get lockForgotNoBiometric;

  /// No description provided for @lockForgotBack.
  ///
  /// In ar, this message translates to:
  /// **'رجوع'**
  String get lockForgotBack;

  /// No description provided for @lockNewPinTitle.
  ///
  /// In ar, this message translates to:
  /// **'اختر رمزًا جديدًا'**
  String get lockNewPinTitle;

  /// No description provided for @lockPinCreateTitle.
  ///
  /// In ar, this message translates to:
  /// **'اختر رمزًا لمَدار'**
  String get lockPinCreateTitle;

  /// No description provided for @lockPinCreateBody.
  ///
  /// In ar, this message translates to:
  /// **'من {min} إلى {max} أرقام، يفتح مَدار متى تعذّرت البصمة.'**
  String lockPinCreateBody(String min, String max);

  /// No description provided for @lockPinConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'أكّد الرمز'**
  String get lockPinConfirmTitle;

  /// No description provided for @lockPinConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'أدخله مرة أخرى للتأكّد.'**
  String get lockPinConfirmBody;

  /// No description provided for @lockPinMismatch.
  ///
  /// In ar, this message translates to:
  /// **'الرمزان مختلفان. لنبدأ من جديد.'**
  String get lockPinMismatch;

  /// No description provided for @lockPinWeak.
  ///
  /// In ar, this message translates to:
  /// **'هذا الرمز سهل التخمين. يُفضَّل اختيار غيره.'**
  String get lockPinWeak;

  /// No description provided for @lockPinCurrentTitle.
  ///
  /// In ar, this message translates to:
  /// **'أدخل الرمز الحالي'**
  String get lockPinCurrentTitle;

  /// No description provided for @lockPinSaved.
  ///
  /// In ar, this message translates to:
  /// **'حُفظ الرمز، وصار مَدار مقفلًا لك وحدك.'**
  String get lockPinSaved;

  /// No description provided for @lockPinChanged.
  ///
  /// In ar, this message translates to:
  /// **'تغيّر الرمز'**
  String get lockPinChanged;

  /// No description provided for @lockConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'تحقّق من هويتك'**
  String get lockConfirmTitle;

  /// No description provided for @lockConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رمز مَدار للمتابعة.'**
  String get lockConfirmBody;

  /// No description provided for @lockBioOfferTitle.
  ///
  /// In ar, this message translates to:
  /// **'والفتح بالبصمة أيضًا؟'**
  String get lockBioOfferTitle;

  /// No description provided for @lockBioOfferBody.
  ///
  /// In ar, this message translates to:
  /// **'أسرع في كل مرة، ويبقى الرمز بديلًا متى احتجت إليه.'**
  String get lockBioOfferBody;

  /// No description provided for @lockBioOfferEnable.
  ///
  /// In ar, this message translates to:
  /// **'فعّل البصمة'**
  String get lockBioOfferEnable;

  /// No description provided for @lockBioOfferSkip.
  ///
  /// In ar, this message translates to:
  /// **'ليس الآن'**
  String get lockBioOfferSkip;

  /// No description provided for @lockSettingsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الأمان'**
  String get lockSettingsTitle;

  /// No description provided for @lockSettingsLock.
  ///
  /// In ar, this message translates to:
  /// **'قفل التطبيق'**
  String get lockSettingsLock;

  /// No description provided for @lockSettingsLockOn.
  ///
  /// In ar, this message translates to:
  /// **'يُطلب عند كل تشغيل وبعد الغياب'**
  String get lockSettingsLockOn;

  /// No description provided for @lockSettingsLockOff.
  ///
  /// In ar, this message translates to:
  /// **'احمِ بياناتك برمز وبصمة'**
  String get lockSettingsLockOff;

  /// No description provided for @lockSettingsBiometric.
  ///
  /// In ar, this message translates to:
  /// **'الفتح بالبصمة'**
  String get lockSettingsBiometric;

  /// No description provided for @lockSettingsBiometricHint.
  ///
  /// In ar, this message translates to:
  /// **'ويبقى الرمز بديلًا دائمًا'**
  String get lockSettingsBiometricHint;

  /// No description provided for @lockSettingsBiometricNotEnrolled.
  ///
  /// In ar, this message translates to:
  /// **'سجّل بصمة في إعدادات الهاتف أولًا'**
  String get lockSettingsBiometricNotEnrolled;

  /// No description provided for @lockSettingsBiometricUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'مستشعر البصمة غير متاح الآن'**
  String get lockSettingsBiometricUnavailable;

  /// No description provided for @lockSettingsChangePin.
  ///
  /// In ar, this message translates to:
  /// **'تغيير الرمز'**
  String get lockSettingsChangePin;

  /// No description provided for @lockSettingsChangePinHint.
  ///
  /// In ar, this message translates to:
  /// **'رمز من {min} إلى {max} أرقام'**
  String lockSettingsChangePinHint(String min, String max);

  /// No description provided for @lockSettingsLockAfter.
  ///
  /// In ar, this message translates to:
  /// **'القفل بعد مغادرة التطبيق'**
  String get lockSettingsLockAfter;

  /// No description provided for @lockSettingsLockAfterHint.
  ///
  /// In ar, this message translates to:
  /// **'وعند كل تشغيل جديد دائمًا'**
  String get lockSettingsLockAfterHint;

  /// No description provided for @lockAfterImmediately.
  ///
  /// In ar, this message translates to:
  /// **'فورًا'**
  String get lockAfterImmediately;

  /// count selects the plural; n is the same number formatted for display
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{دقيقة} =2{دقيقتان} few{{n} دقائق} many{{n} دقيقة} other{{n} دقيقة}}'**
  String lockAfterMinutes(int count, String n);

  /// No description provided for @lockSettingsRemovePin.
  ///
  /// In ar, this message translates to:
  /// **'إزالة الرمز'**
  String get lockSettingsRemovePin;

  /// No description provided for @lockSettingsRemovePinHint.
  ///
  /// In ar, this message translates to:
  /// **'يوقف قفل التطبيق والفتح بالبصمة'**
  String get lockSettingsRemovePinHint;

  /// No description provided for @lockRemoveTitle.
  ///
  /// In ar, this message translates to:
  /// **'إزالة الرمز؟'**
  String get lockRemoveTitle;

  /// No description provided for @lockRemoveBody.
  ///
  /// In ar, this message translates to:
  /// **'سيُفتح مَدار دون قفل حتى تختار رمزًا جديدًا.'**
  String get lockRemoveBody;

  /// No description provided for @lockRemoveConfirm.
  ///
  /// In ar, this message translates to:
  /// **'أزِل الرمز'**
  String get lockRemoveConfirm;

  /// No description provided for @lockSettingsNote.
  ///
  /// In ar, this message translates to:
  /// **'لا حساب ولا خادم: بياناتك مشفّرة على هذا الهاتف وحده، ولا يمكن استرجاع الرمز عن بُعد، فاحفظه جيدًا.'**
  String get lockSettingsNote;

  /// No description provided for @lockSettingsSaveFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الحفظ في الخزنة الآمنة. حاول مجددًا.'**
  String get lockSettingsSaveFailed;

  /// No description provided for @lockBioLockedOut.
  ///
  /// In ar, this message translates to:
  /// **'توقّفت البصمة مؤقتًا بعد محاولات كثيرة. استخدم الرمز.'**
  String get lockBioLockedOut;

  /// No description provided for @lockBioLockedOutPermanently.
  ///
  /// In ar, this message translates to:
  /// **'البصمة مقفلة حتى تفتح هاتفك بقفل شاشته. استخدم رمز مَدار الآن.'**
  String get lockBioLockedOutPermanently;

  /// No description provided for @lockBioNotEnrolled.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد بصمة مسجّلة على هذا الهاتف. استخدم الرمز.'**
  String get lockBioNotEnrolled;

  /// No description provided for @lockBioNoHardware.
  ///
  /// In ar, this message translates to:
  /// **'لا يدعم هذا الهاتف البصمة. استخدم الرمز.'**
  String get lockBioNoHardware;

  /// No description provided for @lockBioUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'مستشعر البصمة غير متاح الآن. استخدم الرمز.'**
  String get lockBioUnavailable;

  /// No description provided for @lockBioError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر التحقّق بالبصمة. حاول مجددًا أو استخدم الرمز.'**
  String get lockBioError;

  /// No description provided for @lockBioInterrupted.
  ///
  /// In ar, this message translates to:
  /// **'انقطع التحقّق. اضغط مطوّلًا لتعيد المحاولة.'**
  String get lockBioInterrupted;

  /// Prayer times screen title
  ///
  /// In ar, this message translates to:
  /// **'مواقيت الصلاة'**
  String get ptTitle;

  /// No description provided for @ptSettingsTitle.
  ///
  /// In ar, this message translates to:
  /// **'إعدادات المواقيت'**
  String get ptSettingsTitle;

  /// Tooltip of the settings button on the prayer times screen
  ///
  /// In ar, this message translates to:
  /// **'إعدادات المواقيت'**
  String get ptOpenSettings;

  /// No description provided for @ptFajr.
  ///
  /// In ar, this message translates to:
  /// **'الفجر'**
  String get ptFajr;

  /// No description provided for @ptSunrise.
  ///
  /// In ar, this message translates to:
  /// **'الشروق'**
  String get ptSunrise;

  /// No description provided for @ptDuha.
  ///
  /// In ar, this message translates to:
  /// **'الضحى'**
  String get ptDuha;

  /// No description provided for @ptDhuhr.
  ///
  /// In ar, this message translates to:
  /// **'الظهر'**
  String get ptDhuhr;

  /// Dhuhr on Fridays
  ///
  /// In ar, this message translates to:
  /// **'الجمعة'**
  String get ptJumuah;

  /// No description provided for @ptAsr.
  ///
  /// In ar, this message translates to:
  /// **'العصر'**
  String get ptAsr;

  /// No description provided for @ptMaghrib.
  ///
  /// In ar, this message translates to:
  /// **'المغرب'**
  String get ptMaghrib;

  /// No description provided for @ptIsha.
  ///
  /// In ar, this message translates to:
  /// **'العشاء'**
  String get ptIsha;

  /// No description provided for @ptMidnight.
  ///
  /// In ar, this message translates to:
  /// **'منتصف الليل'**
  String get ptMidnight;

  /// No description provided for @ptLastThird.
  ///
  /// In ar, this message translates to:
  /// **'الثلث الأخير'**
  String get ptLastThird;

  /// No description provided for @ptSunriseHint.
  ///
  /// In ar, this message translates to:
  /// **'ينتهي وقت الفجر'**
  String get ptSunriseHint;

  /// No description provided for @ptDuhaHint.
  ///
  /// In ar, this message translates to:
  /// **'بعد الشروق بربع ساعة'**
  String get ptDuhaHint;

  /// No description provided for @ptMidnightHint.
  ///
  /// In ar, this message translates to:
  /// **'منتصف ما بين المغرب والفجر'**
  String get ptMidnightHint;

  /// No description provided for @ptLastThirdHint.
  ///
  /// In ar, this message translates to:
  /// **'وقت قيام الليل'**
  String get ptLastThirdHint;

  /// No description provided for @ptNightSection.
  ///
  /// In ar, this message translates to:
  /// **'الليل وقيامه'**
  String get ptNightSection;

  /// No description provided for @ptNow.
  ///
  /// In ar, this message translates to:
  /// **'الآن'**
  String get ptNow;

  /// No description provided for @ptNextPrayer.
  ///
  /// In ar, this message translates to:
  /// **'الصلاة القادمة'**
  String get ptNextPrayer;

  /// Followed by a live countdown
  ///
  /// In ar, this message translates to:
  /// **'يحين وقت {prayer} بعد'**
  String ptNextIn(String prayer);

  /// No description provided for @ptAtTime.
  ///
  /// In ar, this message translates to:
  /// **'عند {time}'**
  String ptAtTime(String time);

  /// No description provided for @ptItsTime.
  ///
  /// In ar, this message translates to:
  /// **'حان وقت {prayer}'**
  String ptItsTime(String prayer);

  /// No description provided for @ptCurrentWindow.
  ///
  /// In ar, this message translates to:
  /// **'الوقت الحالي: {window}'**
  String ptCurrentWindow(String window);

  /// No description provided for @ptCountdownSemantics.
  ///
  /// In ar, this message translates to:
  /// **'يحين وقت {prayer} بعد {duration}'**
  String ptCountdownSemantics(String prayer, String duration);

  /// No description provided for @ptToday.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get ptToday;

  /// No description provided for @ptTomorrow.
  ///
  /// In ar, this message translates to:
  /// **'غدًا'**
  String get ptTomorrow;

  /// No description provided for @ptYesterday.
  ///
  /// In ar, this message translates to:
  /// **'أمس'**
  String get ptYesterday;

  /// Day-view title of the night still running after midnight (the previous date's prayer day, until Fajr)
  ///
  /// In ar, this message translates to:
  /// **'الليلة'**
  String get ptTonight;

  /// No description provided for @ptPrevDay.
  ///
  /// In ar, this message translates to:
  /// **'اليوم السابق'**
  String get ptPrevDay;

  /// No description provided for @ptNextDay.
  ///
  /// In ar, this message translates to:
  /// **'اليوم التالي'**
  String get ptNextDay;

  /// No description provided for @ptBackToToday.
  ///
  /// In ar, this message translates to:
  /// **'العودة إلى اليوم'**
  String get ptBackToToday;

  /// Segment: one day's times
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get ptViewDay;

  /// Segment: the month table
  ///
  /// In ar, this message translates to:
  /// **'الشهر'**
  String get ptViewMonth;

  /// No description provided for @ptPrevMonth.
  ///
  /// In ar, this message translates to:
  /// **'الشهر السابق'**
  String get ptPrevMonth;

  /// No description provided for @ptNextMonth.
  ///
  /// In ar, this message translates to:
  /// **'الشهر التالي'**
  String get ptNextMonth;

  /// Month table: the date column
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get ptMonthDay;

  /// No description provided for @ptMonthHijriSpan.
  ///
  /// In ar, this message translates to:
  /// **'{from} – {to}'**
  String ptMonthHijriSpan(String from, String to);

  /// No description provided for @ptAm.
  ///
  /// In ar, this message translates to:
  /// **'ص'**
  String get ptAm;

  /// No description provided for @ptPm.
  ///
  /// In ar, this message translates to:
  /// **'م'**
  String get ptPm;

  /// No description provided for @ptClockHours.
  ///
  /// In ar, this message translates to:
  /// **'{hours} ساعة'**
  String ptClockHours(String hours);

  /// No description provided for @ptMinutesSigned.
  ///
  /// In ar, this message translates to:
  /// **'{minutes} د'**
  String ptMinutesSigned(String minutes);

  /// No description provided for @ptHijriDate.
  ///
  /// In ar, this message translates to:
  /// **'{day} {month} {year} هـ'**
  String ptHijriDate(String day, String month, String year);

  /// No description provided for @ptHijriDayMonth.
  ///
  /// In ar, this message translates to:
  /// **'{day} {month}'**
  String ptHijriDayMonth(String day, String month);

  /// No description provided for @ptHijriMonth1.
  ///
  /// In ar, this message translates to:
  /// **'محرّم'**
  String get ptHijriMonth1;

  /// No description provided for @ptHijriMonth2.
  ///
  /// In ar, this message translates to:
  /// **'صفر'**
  String get ptHijriMonth2;

  /// No description provided for @ptHijriMonth3.
  ///
  /// In ar, this message translates to:
  /// **'ربيع الأول'**
  String get ptHijriMonth3;

  /// No description provided for @ptHijriMonth4.
  ///
  /// In ar, this message translates to:
  /// **'ربيع الآخر'**
  String get ptHijriMonth4;

  /// No description provided for @ptHijriMonth5.
  ///
  /// In ar, this message translates to:
  /// **'جمادى الأولى'**
  String get ptHijriMonth5;

  /// No description provided for @ptHijriMonth6.
  ///
  /// In ar, this message translates to:
  /// **'جمادى الآخرة'**
  String get ptHijriMonth6;

  /// No description provided for @ptHijriMonth7.
  ///
  /// In ar, this message translates to:
  /// **'رجب'**
  String get ptHijriMonth7;

  /// No description provided for @ptHijriMonth8.
  ///
  /// In ar, this message translates to:
  /// **'شعبان'**
  String get ptHijriMonth8;

  /// No description provided for @ptHijriMonth9.
  ///
  /// In ar, this message translates to:
  /// **'رمضان'**
  String get ptHijriMonth9;

  /// No description provided for @ptHijriMonth10.
  ///
  /// In ar, this message translates to:
  /// **'شوّال'**
  String get ptHijriMonth10;

  /// No description provided for @ptHijriMonth11.
  ///
  /// In ar, this message translates to:
  /// **'ذو القعدة'**
  String get ptHijriMonth11;

  /// No description provided for @ptHijriMonth12.
  ///
  /// In ar, this message translates to:
  /// **'ذو الحجة'**
  String get ptHijriMonth12;

  /// No description provided for @ptLocationTitle.
  ///
  /// In ar, this message translates to:
  /// **'موقعك'**
  String get ptLocationTitle;

  /// No description provided for @ptLocationSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'تُحسب المواقيت على جهازك، دون إنترنت'**
  String get ptLocationSubtitle;

  /// No description provided for @ptLocationDefault.
  ///
  /// In ar, this message translates to:
  /// **'{city} (افتراضي)'**
  String ptLocationDefault(String city);

  /// No description provided for @ptLocationNear.
  ///
  /// In ar, this message translates to:
  /// **'قرب {city}'**
  String ptLocationNear(String city);

  /// No description provided for @ptPlaceWithCountry.
  ///
  /// In ar, this message translates to:
  /// **'{city}، {country}'**
  String ptPlaceWithCountry(String city, String country);

  /// No description provided for @ptPinnedLocation.
  ///
  /// In ar, this message translates to:
  /// **'موقع محدّد'**
  String get ptPinnedLocation;

  /// Name of the generic default location
  ///
  /// In ar, this message translates to:
  /// **'عمّان'**
  String get ptDefaultCityName;

  /// No description provided for @ptSourceGps.
  ///
  /// In ar, this message translates to:
  /// **'من موقعك الحالي'**
  String get ptSourceGps;

  /// No description provided for @ptSourceCity.
  ///
  /// In ar, this message translates to:
  /// **'مدينة مختارة'**
  String get ptSourceCity;

  /// No description provided for @ptSourceDefault.
  ///
  /// In ar, this message translates to:
  /// **'الموقع الافتراضي – اختر موقعك'**
  String get ptSourceDefault;

  /// No description provided for @ptCoordinates.
  ///
  /// In ar, this message translates to:
  /// **'{lat}، {lon}'**
  String ptCoordinates(String lat, String lon);

  /// No description provided for @ptTimeZoneLabel.
  ///
  /// In ar, this message translates to:
  /// **'المنطقة الزمنية: {zone}'**
  String ptTimeZoneLabel(String zone);

  /// No description provided for @ptTimeZoneDevice.
  ///
  /// In ar, this message translates to:
  /// **'توقيت الجهاز'**
  String get ptTimeZoneDevice;

  /// No description provided for @ptZoneOffset.
  ///
  /// In ar, this message translates to:
  /// **'غرينتش {offset}'**
  String ptZoneOffset(String offset);

  /// No description provided for @ptZoneDiffers.
  ///
  /// In ar, this message translates to:
  /// **'المواقيت بتوقيت {place}'**
  String ptZoneDiffers(String place);

  /// No description provided for @ptUseCurrentLocation.
  ///
  /// In ar, this message translates to:
  /// **'استخدم موقعي الحالي'**
  String get ptUseCurrentLocation;

  /// No description provided for @ptUseCurrentLocationHint.
  ///
  /// In ar, this message translates to:
  /// **'تحديد تقريبي لمرة واحدة، يبقى على جهازك'**
  String get ptUseCurrentLocationHint;

  /// No description provided for @ptChooseCity.
  ///
  /// In ar, this message translates to:
  /// **'اختر مدينة'**
  String get ptChooseCity;

  /// No description provided for @ptChooseCityHint.
  ///
  /// In ar, this message translates to:
  /// **'بحث بالعربية أو الإنجليزية، دون إنترنت'**
  String get ptChooseCityHint;

  /// No description provided for @ptRationaleTitle.
  ///
  /// In ar, this message translates to:
  /// **'نحتاج موقعك التقريبي'**
  String get ptRationaleTitle;

  /// No description provided for @ptRationaleBody.
  ///
  /// In ar, this message translates to:
  /// **'ليحسب مَدار مواقيت الصلاة بدقة يطلب موقعك مرة واحدة. يُحفظ مشفّرًا على جهازك ولا يُرسَل إلى أي مكان.'**
  String get ptRationaleBody;

  /// No description provided for @ptRationaleAllow.
  ///
  /// In ar, this message translates to:
  /// **'السماح بالموقع'**
  String get ptRationaleAllow;

  /// No description provided for @ptRequesting.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار إذنك…'**
  String get ptRequesting;

  /// No description provided for @ptLocating.
  ///
  /// In ar, this message translates to:
  /// **'نحدّد موقعك…'**
  String get ptLocating;

  /// No description provided for @ptDeniedTitle.
  ///
  /// In ar, this message translates to:
  /// **'لم يُمنح إذن الموقع'**
  String get ptDeniedTitle;

  /// No description provided for @ptDeniedBody.
  ///
  /// In ar, this message translates to:
  /// **'يمكنك المحاولة مجددًا، أو اختيار مدينتك من القائمة.'**
  String get ptDeniedBody;

  /// No description provided for @ptTryAgain.
  ///
  /// In ar, this message translates to:
  /// **'حاول مجددًا'**
  String get ptTryAgain;

  /// No description provided for @ptDeniedForeverTitle.
  ///
  /// In ar, this message translates to:
  /// **'إذن الموقع مغلق'**
  String get ptDeniedForeverTitle;

  /// No description provided for @ptDeniedForeverBody.
  ///
  /// In ar, this message translates to:
  /// **'فعّله من إعدادات التطبيق في النظام، أو اختر مدينتك يدويًا.'**
  String get ptDeniedForeverBody;

  /// No description provided for @ptOpenAppSettings.
  ///
  /// In ar, this message translates to:
  /// **'فتح إعدادات التطبيق'**
  String get ptOpenAppSettings;

  /// No description provided for @ptServiceOffTitle.
  ///
  /// In ar, this message translates to:
  /// **'خدمة الموقع متوقفة'**
  String get ptServiceOffTitle;

  /// No description provided for @ptServiceOffBody.
  ///
  /// In ar, this message translates to:
  /// **'شغّل الموقع من إعدادات الجهاز ثم عُد إلى هنا، أو اختر مدينتك.'**
  String get ptServiceOffBody;

  /// No description provided for @ptOpenLocationSettings.
  ///
  /// In ar, this message translates to:
  /// **'إعدادات الموقع'**
  String get ptOpenLocationSettings;

  /// No description provided for @ptUnsupportedBody.
  ///
  /// In ar, this message translates to:
  /// **'تحديد الموقع غير متاح على هذا الجهاز. اختر مدينتك من القائمة.'**
  String get ptUnsupportedBody;

  /// No description provided for @ptFailedTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحديد الموقع'**
  String get ptFailedTitle;

  /// No description provided for @ptFailedBody.
  ///
  /// In ar, this message translates to:
  /// **'قد تكون الإشارة ضعيفة. حاول مجددًا في مكان مكشوف، أو اختر مدينتك.'**
  String get ptFailedBody;

  /// No description provided for @ptLocationChanged.
  ///
  /// In ar, this message translates to:
  /// **'صار الموقع: {place}'**
  String ptLocationChanged(String place);

  /// No description provided for @ptCitySearchHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن مدينة…'**
  String get ptCitySearchHint;

  /// No description provided for @ptCitySearchEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا مدينة بهذا الاسم'**
  String get ptCitySearchEmpty;

  /// No description provided for @ptCitySearchEmptyHint.
  ///
  /// In ar, this message translates to:
  /// **'جرّب اسمًا آخر أو كتابة أقصر'**
  String get ptCitySearchEmptyHint;

  /// No description provided for @ptCitySuggestions.
  ///
  /// In ar, this message translates to:
  /// **'مدن مقترحة'**
  String get ptCitySuggestions;

  /// No description provided for @ptCityResults.
  ///
  /// In ar, this message translates to:
  /// **'النتائج'**
  String get ptCityResults;

  /// No description provided for @ptCitySelected.
  ///
  /// In ar, this message translates to:
  /// **'المختارة'**
  String get ptCitySelected;

  /// No description provided for @ptSectionLocation.
  ///
  /// In ar, this message translates to:
  /// **'الموقع'**
  String get ptSectionLocation;

  /// No description provided for @ptSectionMethod.
  ///
  /// In ar, this message translates to:
  /// **'طريقة الحساب'**
  String get ptSectionMethod;

  /// No description provided for @ptSectionMethodHint.
  ///
  /// In ar, this message translates to:
  /// **'تختلف الطرق أساسًا في زاويتي الفجر والعشاء'**
  String get ptSectionMethodHint;

  /// No description provided for @ptSectionAsr.
  ///
  /// In ar, this message translates to:
  /// **'صلاة العصر'**
  String get ptSectionAsr;

  /// No description provided for @ptAsrStandard.
  ///
  /// In ar, this message translates to:
  /// **'الجمهور'**
  String get ptAsrStandard;

  /// No description provided for @ptAsrHanafi.
  ///
  /// In ar, this message translates to:
  /// **'الحنفي'**
  String get ptAsrHanafi;

  /// No description provided for @ptAsrNote.
  ///
  /// In ar, this message translates to:
  /// **'عند الجمهور (الشافعية والمالكية والحنابلة) يبدأ العصر حين يصير ظل الشيء مثله، وعند الحنفية مثليه.'**
  String get ptAsrNote;

  /// No description provided for @ptSectionHighLat.
  ///
  /// In ar, this message translates to:
  /// **'خطوط العرض العليا'**
  String get ptSectionHighLat;

  /// No description provided for @ptHighLatAuto.
  ///
  /// In ar, this message translates to:
  /// **'تلقائي'**
  String get ptHighLatAuto;

  /// No description provided for @ptHighLatMiddle.
  ///
  /// In ar, this message translates to:
  /// **'منتصف الليل'**
  String get ptHighLatMiddle;

  /// No description provided for @ptHighLatSeventh.
  ///
  /// In ar, this message translates to:
  /// **'سُبع الليل'**
  String get ptHighLatSeventh;

  /// No description provided for @ptHighLatAngle.
  ///
  /// In ar, this message translates to:
  /// **'زاوية الشفق'**
  String get ptHighLatAngle;

  /// No description provided for @ptHighLatNote.
  ///
  /// In ar, this message translates to:
  /// **'حيث لا يغيب الشفق صيفًا يُقدَّر الفجر والعشاء بجزء من الليل. التلقائي يختار سُبع الليل شمال خط العرض {degrees} تقريبًا.'**
  String ptHighLatNote(String degrees);

  /// No description provided for @ptSectionAdjustments.
  ///
  /// In ar, this message translates to:
  /// **'تعديلات يدوية'**
  String get ptSectionAdjustments;

  /// No description provided for @ptAdjustmentsNote.
  ///
  /// In ar, this message translates to:
  /// **'أضِف دقائق أو اطرحها لتوافق تقويم مسجدك.'**
  String get ptAdjustmentsNote;

  /// No description provided for @ptResetAdjustments.
  ///
  /// In ar, this message translates to:
  /// **'تصفير'**
  String get ptResetAdjustments;

  /// No description provided for @ptAdjustmentsReset.
  ///
  /// In ar, this message translates to:
  /// **'صُفّرت التعديلات اليدوية'**
  String get ptAdjustmentsReset;

  /// No description provided for @ptSectionHijri.
  ///
  /// In ar, this message translates to:
  /// **'التاريخ الهجري'**
  String get ptSectionHijri;

  /// No description provided for @ptHijriOffset.
  ///
  /// In ar, this message translates to:
  /// **'تعديل اليوم الهجري'**
  String get ptHijriOffset;

  /// No description provided for @ptHijriOffsetNote.
  ///
  /// In ar, this message translates to:
  /// **'حسب تقويم أم القرى؛ عدّله يومًا أو يومين ليوافق رؤية الهلال في بلدك.'**
  String get ptHijriOffsetNote;

  /// No description provided for @ptHijriAtMaghrib.
  ///
  /// In ar, this message translates to:
  /// **'يبدأ اليوم الهجري عند المغرب'**
  String get ptHijriAtMaghrib;

  /// No description provided for @ptHijriAtMaghribHint.
  ///
  /// In ar, this message translates to:
  /// **'كما يُحسب اليوم شرعًا، من غروب إلى غروب'**
  String get ptHijriAtMaghribHint;

  /// No description provided for @ptSectionDisplay.
  ///
  /// In ar, this message translates to:
  /// **'العرض'**
  String get ptSectionDisplay;

  /// No description provided for @ptClockFormat.
  ///
  /// In ar, this message translates to:
  /// **'نظام الساعة'**
  String get ptClockFormat;

  /// No description provided for @ptPreviewTitle.
  ///
  /// In ar, this message translates to:
  /// **'مواقيت اليوم'**
  String get ptPreviewTitle;

  /// No description provided for @ptPreviewHint.
  ///
  /// In ar, this message translates to:
  /// **'تتحدّث مع كل تغيير'**
  String get ptPreviewHint;

  /// No description provided for @ptMethodSheetTitle.
  ///
  /// In ar, this message translates to:
  /// **'طريقة الحساب'**
  String get ptMethodSheetTitle;

  /// No description provided for @ptMethodSuggested.
  ///
  /// In ar, this message translates to:
  /// **'مقترحة لموقعك'**
  String get ptMethodSuggested;

  /// No description provided for @ptMethodDefault.
  ///
  /// In ar, this message translates to:
  /// **'الافتراضية'**
  String get ptMethodDefault;

  /// Undo toast after picking a calculation method
  ///
  /// In ar, this message translates to:
  /// **'صارت طريقة الحساب: {method}'**
  String ptMethodChanged(String method);

  /// No description provided for @ptMethodJordan.
  ///
  /// In ar, this message translates to:
  /// **'وزارة الأوقاف الأردنية'**
  String get ptMethodJordan;

  /// No description provided for @ptMethodMuslimWorldLeague.
  ///
  /// In ar, this message translates to:
  /// **'رابطة العالم الإسلامي'**
  String get ptMethodMuslimWorldLeague;

  /// No description provided for @ptMethodUmmAlQura.
  ///
  /// In ar, this message translates to:
  /// **'أم القرى – مكة المكرمة'**
  String get ptMethodUmmAlQura;

  /// No description provided for @ptMethodEgyptian.
  ///
  /// In ar, this message translates to:
  /// **'الهيئة المصرية العامة للمساحة'**
  String get ptMethodEgyptian;

  /// No description provided for @ptMethodKarachi.
  ///
  /// In ar, this message translates to:
  /// **'جامعة العلوم الإسلامية – كراتشي'**
  String get ptMethodKarachi;

  /// No description provided for @ptMethodNorthAmerica.
  ///
  /// In ar, this message translates to:
  /// **'الجمعية الإسلامية لأمريكا الشمالية'**
  String get ptMethodNorthAmerica;

  /// No description provided for @ptMethodDubai.
  ///
  /// In ar, this message translates to:
  /// **'دبي – الإمارات'**
  String get ptMethodDubai;

  /// No description provided for @ptMethodKuwait.
  ///
  /// In ar, this message translates to:
  /// **'الكويت'**
  String get ptMethodKuwait;

  /// No description provided for @ptMethodQatar.
  ///
  /// In ar, this message translates to:
  /// **'قطر'**
  String get ptMethodQatar;

  /// No description provided for @ptMethodTurkiye.
  ///
  /// In ar, this message translates to:
  /// **'رئاسة الشؤون الدينية التركية'**
  String get ptMethodTurkiye;

  /// No description provided for @ptMethodSingapore.
  ///
  /// In ar, this message translates to:
  /// **'سنغافورة'**
  String get ptMethodSingapore;

  /// No description provided for @ptMethodTehran.
  ///
  /// In ar, this message translates to:
  /// **'معهد الجيوفيزياء – طهران'**
  String get ptMethodTehran;

  /// No description provided for @ptMethodGulfRegion.
  ///
  /// In ar, this message translates to:
  /// **'منطقة الخليج'**
  String get ptMethodGulfRegion;

  /// No description provided for @ptMethodMoonsightingCommittee.
  ///
  /// In ar, this message translates to:
  /// **'لجنة رؤية الهلال'**
  String get ptMethodMoonsightingCommittee;

  /// No description provided for @ptMethodAlgerian.
  ///
  /// In ar, this message translates to:
  /// **'وزارة الشؤون الدينية الجزائرية'**
  String get ptMethodAlgerian;

  /// No description provided for @ptMethodMorocco.
  ///
  /// In ar, this message translates to:
  /// **'وزارة الأوقاف المغربية'**
  String get ptMethodMorocco;

  /// No description provided for @ptMethodTunisia.
  ///
  /// In ar, this message translates to:
  /// **'وزارة الشؤون الدينية التونسية'**
  String get ptMethodTunisia;

  /// No description provided for @ptMethodFrance.
  ///
  /// In ar, this message translates to:
  /// **'اتحاد المنظمات الإسلامية في فرنسا'**
  String get ptMethodFrance;

  /// No description provided for @ptMethodRussia.
  ///
  /// In ar, this message translates to:
  /// **'الإدارة الدينية لمسلمي روسيا'**
  String get ptMethodRussia;

  /// No description provided for @ptMethodIndonesian.
  ///
  /// In ar, this message translates to:
  /// **'وزارة الشؤون الدينية الإندونيسية'**
  String get ptMethodIndonesian;

  /// No description provided for @ptMethodJafari.
  ///
  /// In ar, this message translates to:
  /// **'الجعفري – معهد ليفا، قم'**
  String get ptMethodJafari;

  /// No description provided for @ptMethodCustom.
  ///
  /// In ar, this message translates to:
  /// **'زوايا مخصّصة'**
  String get ptMethodCustom;

  /// No description provided for @ptMethodCustomHint.
  ///
  /// In ar, this message translates to:
  /// **'حدّد زاويتي الفجر والعشاء بنفسك'**
  String get ptMethodCustomHint;

  /// No description provided for @ptSummaryAngle.
  ///
  /// In ar, this message translates to:
  /// **'{prayer} {angle}'**
  String ptSummaryAngle(String prayer, String angle);

  /// No description provided for @ptSummaryIshaInterval.
  ///
  /// In ar, this message translates to:
  /// **'العشاء بعد المغرب بـ{minutes} د'**
  String ptSummaryIshaInterval(String minutes);

  /// No description provided for @ptSummaryRamadan.
  ///
  /// In ar, this message translates to:
  /// **'في رمضان بعد المغرب بـ{minutes} د'**
  String ptSummaryRamadan(String minutes);

  /// No description provided for @ptSummaryOffset.
  ///
  /// In ar, this message translates to:
  /// **'{prayer} {minutes} د'**
  String ptSummaryOffset(String prayer, String minutes);

  /// No description provided for @ptSummaryMaghribAngle.
  ///
  /// In ar, this message translates to:
  /// **'المغرب {angle}'**
  String ptSummaryMaghribAngle(String angle);

  /// No description provided for @ptCustomFajrAngle.
  ///
  /// In ar, this message translates to:
  /// **'زاوية الفجر'**
  String get ptCustomFajrAngle;

  /// No description provided for @ptCustomIshaAngle.
  ///
  /// In ar, this message translates to:
  /// **'زاوية العشاء'**
  String get ptCustomIshaAngle;

  /// No description provided for @ptCustomIshaByInterval.
  ///
  /// In ar, this message translates to:
  /// **'العشاء بعد المغرب بمدة ثابتة'**
  String get ptCustomIshaByInterval;

  /// No description provided for @ptCustomIshaInterval.
  ///
  /// In ar, this message translates to:
  /// **'المدة بعد المغرب'**
  String get ptCustomIshaInterval;

  /// No description provided for @ptIncrease.
  ///
  /// In ar, this message translates to:
  /// **'زيادة'**
  String get ptIncrease;

  /// No description provided for @ptDecrease.
  ///
  /// In ar, this message translates to:
  /// **'إنقاص'**
  String get ptDecrease;

  /// No description provided for @ptUndoSettings.
  ///
  /// In ar, this message translates to:
  /// **'أُعيدت الإعدادات السابقة'**
  String get ptUndoSettings;

  /// No description provided for @ptAsrRule.
  ///
  /// In ar, this message translates to:
  /// **'بداية وقت العصر'**
  String get ptAsrRule;

  /// No description provided for @ptHighLatRule.
  ///
  /// In ar, this message translates to:
  /// **'طريقة التقدير'**
  String get ptHighLatRule;

  /// A zero adjustment (Hijri day offset or prayer minutes)
  ///
  /// In ar, this message translates to:
  /// **'بلا تعديل'**
  String get ptNoAdjustment;

  /// A signed day offset, e.g. +1
  ///
  /// In ar, this message translates to:
  /// **'{days} يوم'**
  String ptDayUnit(String days);

  /// No description provided for @ptAdjustTitle.
  ///
  /// In ar, this message translates to:
  /// **'ضبط وقت {prayer}'**
  String ptAdjustTitle(String prayer);

  /// No description provided for @ptAdjustHint.
  ///
  /// In ar, this message translates to:
  /// **'اضغط مطوّلًا على أي وقت لضبطه بالدقائق'**
  String get ptAdjustHint;

  /// No description provided for @ptAdjustCalculated.
  ///
  /// In ar, this message translates to:
  /// **'المحسوب: {time}'**
  String ptAdjustCalculated(String time);

  /// No description provided for @ptAdjustDone.
  ///
  /// In ar, this message translates to:
  /// **'تم'**
  String get ptAdjustDone;

  /// No description provided for @ptAdjusted.
  ///
  /// In ar, this message translates to:
  /// **'عُدّل وقت {prayer}'**
  String ptAdjusted(String prayer);

  /// Adhan settings screen title / settings entry
  ///
  /// In ar, this message translates to:
  /// **'الأذان'**
  String get adhanSettingsTitle;

  /// Subtitle of the Adhan entry in Settings
  ///
  /// In ar, this message translates to:
  /// **'الأذان في وقته، والمؤذّن، والتذكير قبله'**
  String get adhanSettingsSubtitle;

  /// A number of minutes after 'in' / 'before' (genitive in Arabic)
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{الآن} =1{دقيقة} =2{دقيقتين} few{{count} دقائق} many{{count} دقيقة} other{{count} دقيقة}}'**
  String adhanMinutes(int count);

  /// Compact minutes on a chip; number pre-formatted
  ///
  /// In ar, this message translates to:
  /// **'{minutes} د'**
  String adhanMinutesShort(String minutes);

  /// No description provided for @adhanSeconds.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لحظات} =1{ثانية} =2{ثانيتين} few{{count} ثوانٍ} many{{count} ثانية} other{{count} ثانية}}'**
  String adhanSeconds(int count);

  /// Adhan notification title
  ///
  /// In ar, this message translates to:
  /// **'حان الآن وقت صلاة {prayer}'**
  String adhanNotifCallTitle(String prayer);

  /// Adhan notification body; time pre-formatted
  ///
  /// In ar, this message translates to:
  /// **'{time} · حيّ على الصلاة'**
  String adhanNotifCallBody(String time);

  /// Pre-adhan reminder title, e.g. Maghrib in 10 minutes
  ///
  /// In ar, this message translates to:
  /// **'{prayer} بعد {minutes}'**
  String adhanNotifPreTitle(String prayer, String minutes);

  /// No description provided for @adhanNotifPreBody.
  ///
  /// In ar, this message translates to:
  /// **'استعدّ للصلاة؛ يُرفَع الأذان عند {time}'**
  String adhanNotifPreBody(String time);

  /// No description provided for @adhanNotifSunriseTitle.
  ///
  /// In ar, this message translates to:
  /// **'أشرقت الشمس'**
  String get adhanNotifSunriseTitle;

  /// No description provided for @adhanNotifSunriseBody.
  ///
  /// In ar, this message translates to:
  /// **'انتهى وقت صلاة الفجر'**
  String get adhanNotifSunriseBody;

  /// No description provided for @adhanNotifSunriseSoonTitle.
  ///
  /// In ar, this message translates to:
  /// **'الشروق بعد {minutes}'**
  String adhanNotifSunriseSoonTitle(String minutes);

  /// No description provided for @adhanNotifSunriseSoonBody.
  ///
  /// In ar, this message translates to:
  /// **'يوشك وقت الفجر أن ينتهي؛ صلِّ قبل {time}'**
  String adhanNotifSunriseSoonBody(String time);

  /// No description provided for @adhanNotifTestTitle.
  ///
  /// In ar, this message translates to:
  /// **'تجربة: أذان {prayer}'**
  String adhanNotifTestTitle(String prayer);

  /// No description provided for @adhanNotifTestBody.
  ///
  /// In ar, this message translates to:
  /// **'هكذا سيبدو الأذان ويُسمَع في وقته'**
  String get adhanNotifTestBody;

  /// Android notification channel group
  ///
  /// In ar, this message translates to:
  /// **'الصلاة والأذان'**
  String get adhanChannelGroup;

  /// Android channel name of an adhan sound
  ///
  /// In ar, this message translates to:
  /// **'الأذان · {sound}'**
  String adhanChannelCall(String sound);

  /// No description provided for @adhanChannelCallHint.
  ///
  /// In ar, this message translates to:
  /// **'الأذان عند دخول وقت كل صلاة'**
  String get adhanChannelCallHint;

  /// No description provided for @adhanChannelReminder.
  ///
  /// In ar, this message translates to:
  /// **'تذكير قبل الأذان'**
  String get adhanChannelReminder;

  /// No description provided for @adhanChannelSunrise.
  ///
  /// In ar, this message translates to:
  /// **'الشروق'**
  String get adhanChannelSunrise;

  /// No description provided for @adhanToneDawn.
  ///
  /// In ar, this message translates to:
  /// **'نور الفجر'**
  String get adhanToneDawn;

  /// No description provided for @adhanToneDawnHint.
  ///
  /// In ar, this message translates to:
  /// **'توهّج بلّوري يعلو فوق نغمة دافئة، كأول الضوء'**
  String get adhanToneDawnHint;

  /// No description provided for @adhanToneBrass.
  ///
  /// In ar, this message translates to:
  /// **'نحاس الأسطرلاب'**
  String get adhanToneBrass;

  /// No description provided for @adhanToneBrassHint.
  ///
  /// In ar, this message translates to:
  /// **'أجراس هادئة كساعة برجٍ بعيدة'**
  String get adhanToneBrassHint;

  /// No description provided for @adhanToneBowl.
  ///
  /// In ar, this message translates to:
  /// **'سكينة'**
  String get adhanToneBowl;

  /// No description provided for @adhanToneBowlHint.
  ///
  /// In ar, this message translates to:
  /// **'ثلاث قرعات على وعاءٍ غنائي'**
  String get adhanToneBowlHint;

  /// No description provided for @adhanToneChime.
  ///
  /// In ar, this message translates to:
  /// **'جرس التذكير'**
  String get adhanToneChime;

  /// No description provided for @adhanToneSunrise.
  ///
  /// In ar, this message translates to:
  /// **'بلّور الشروق'**
  String get adhanToneSunrise;

  /// No description provided for @adhanToneChimeHint.
  ///
  /// In ar, this message translates to:
  /// **'رنّة زجاجية قصيرة'**
  String get adhanToneChimeHint;

  /// No description provided for @adhanSilent.
  ///
  /// In ar, this message translates to:
  /// **'بلا صوت'**
  String get adhanSilent;

  /// No description provided for @adhanSilentHint.
  ///
  /// In ar, this message translates to:
  /// **'إشعار واهتزاز دون صوت'**
  String get adhanSilentHint;

  /// Small line above the big prayer name on the adhan screen
  ///
  /// In ar, this message translates to:
  /// **'حان الآن وقت صلاة'**
  String get adhanScreenOverlineCall;

  /// No description provided for @adhanScreenOverlinePre.
  ///
  /// In ar, this message translates to:
  /// **'استعدّ لصلاة'**
  String get adhanScreenOverlinePre;

  /// No description provided for @adhanScreenOverlineSunrise.
  ///
  /// In ar, this message translates to:
  /// **'انتهى وقت الفجر'**
  String get adhanScreenOverlineSunrise;

  /// No description provided for @adhanScreenOverlineSunriseSoon.
  ///
  /// In ar, this message translates to:
  /// **'يوشك وقت الفجر أن ينتهي'**
  String get adhanScreenOverlineSunriseSoon;

  /// No description provided for @adhanScreenSunriseIn.
  ///
  /// In ar, this message translates to:
  /// **'الشروق بعد {duration}'**
  String adhanScreenSunriseIn(String duration);

  /// No description provided for @adhanScreenOverlineTest.
  ///
  /// In ar, this message translates to:
  /// **'تجربة أذان'**
  String get adhanScreenOverlineTest;

  /// No description provided for @adhanScreenAdhanIn.
  ///
  /// In ar, this message translates to:
  /// **'الأذان بعد {duration}'**
  String adhanScreenAdhanIn(String duration);

  /// No description provided for @adhanScreenAdhanAt.
  ///
  /// In ar, this message translates to:
  /// **'يُرفَع الأذان عند {time}'**
  String adhanScreenAdhanAt(String time);

  /// No description provided for @adhanScreenSoundingCall.
  ///
  /// In ar, this message translates to:
  /// **'يُرفَع الأذان الآن'**
  String get adhanScreenSoundingCall;

  /// No description provided for @adhanScreenSoundingTone.
  ///
  /// In ar, this message translates to:
  /// **'التنبيه يصدح الآن'**
  String get adhanScreenSoundingTone;

  /// No description provided for @adhanScreenSilent.
  ///
  /// In ar, this message translates to:
  /// **'أذان صامت'**
  String get adhanScreenSilent;

  /// No description provided for @adhanScreenSemantics.
  ///
  /// In ar, this message translates to:
  /// **'أذان {prayer}، {time}'**
  String adhanScreenSemantics(String prayer, String time);

  /// No description provided for @adhanDuaTitle.
  ///
  /// In ar, this message translates to:
  /// **'دعاء ما بعد الأذان'**
  String get adhanDuaTitle;

  /// Arabic: when it is said; English: a translation of the supplication (the Arabic text itself is shown from code)
  ///
  /// In ar, this message translates to:
  /// **'يُقال بعد الأذان، مع الصلاة على النبي ﷺ'**
  String get adhanDuaMeaning;

  /// Hadith reference; number pre-formatted
  ///
  /// In ar, this message translates to:
  /// **'رواه البخاري ({number})'**
  String adhanDuaSource(String number);

  /// No description provided for @adhanStop.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف الأذان'**
  String get adhanStop;

  /// No description provided for @adhanPrayed.
  ///
  /// In ar, this message translates to:
  /// **'صلّيتُ'**
  String get adhanPrayed;

  /// No description provided for @adhanPrayedNamed.
  ///
  /// In ar, this message translates to:
  /// **'صلّيتُ {prayer}'**
  String adhanPrayedNamed(String prayer);

  /// No description provided for @adhanPrayedDone.
  ///
  /// In ar, this message translates to:
  /// **'تقبّل الله منك'**
  String get adhanPrayedDone;

  /// No description provided for @adhanPrayedFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تسجيل الصلاة'**
  String get adhanPrayedFailed;

  /// No description provided for @adhanClose.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get adhanClose;

  /// No description provided for @adhanSnooze.
  ///
  /// In ar, this message translates to:
  /// **'ذكّرني بعد {minutes}'**
  String adhanSnooze(String minutes);

  /// No description provided for @adhanSnoozed.
  ///
  /// In ar, this message translates to:
  /// **'سأذكّرك بعد {minutes}'**
  String adhanSnoozed(String minutes);

  /// No description provided for @adhanNextTitle.
  ///
  /// In ar, this message translates to:
  /// **'الأذان القادم'**
  String get adhanNextTitle;

  /// No description provided for @adhanNextIn.
  ///
  /// In ar, this message translates to:
  /// **'بعد {duration}'**
  String adhanNextIn(String duration);

  /// No description provided for @adhanNextNone.
  ///
  /// In ar, this message translates to:
  /// **'لا أذان مفعّل'**
  String get adhanNextNone;

  /// No description provided for @adhanScheduledCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا تنبيهات مجدولة} =1{تنبيه واحد مجدول} =2{تنبيهان مجدولان} few{{count} تنبيهات مجدولة} many{{count} تنبيهًا مجدولًا} other{{count} تنبيه مجدول}}'**
  String adhanScheduledCount(int count);

  /// No description provided for @adhanScheduleWeek.
  ///
  /// In ar, this message translates to:
  /// **'يبقى الأذان يعمل أسبوعًا كاملًا دون فتح مَدار، وبعد إعادة التشغيل'**
  String get adhanScheduleWeek;

  /// No description provided for @adhanScheduleInexact.
  ///
  /// In ar, this message translates to:
  /// **'المنبّهات الدقيقة غير مسموحة؛ قد يتأخر الأذان دقائق'**
  String get adhanScheduleInexact;

  /// No description provided for @adhanSectionPrayers.
  ///
  /// In ar, this message translates to:
  /// **'الصلوات'**
  String get adhanSectionPrayers;

  /// No description provided for @adhanSectionPrayersHint.
  ///
  /// In ar, this message translates to:
  /// **'الأذان عند دخول الوقت، وتذكير قبله إن شئت'**
  String get adhanSectionPrayersHint;

  /// No description provided for @adhanPrayerOff.
  ///
  /// In ar, this message translates to:
  /// **'الأذان متوقف'**
  String get adhanPrayerOff;

  /// No description provided for @adhanPrayerReminder.
  ///
  /// In ar, this message translates to:
  /// **'تذكير قبل {minutes}'**
  String adhanPrayerReminder(String minutes);

  /// No description provided for @adhanPrayerToggle.
  ///
  /// In ar, this message translates to:
  /// **'أذان {prayer}'**
  String adhanPrayerToggle(String prayer);

  /// No description provided for @adhanAlertSheetTitle.
  ///
  /// In ar, this message translates to:
  /// **'أذان {prayer}'**
  String adhanAlertSheetTitle(String prayer);

  /// No description provided for @adhanAlertCall.
  ///
  /// In ar, this message translates to:
  /// **'رفع الأذان عند دخول الوقت'**
  String get adhanAlertCall;

  /// No description provided for @adhanAlertReminder.
  ///
  /// In ar, this message translates to:
  /// **'تذكير قبل الأذان'**
  String get adhanAlertReminder;

  /// No description provided for @adhanReminderNone.
  ///
  /// In ar, this message translates to:
  /// **'بلا'**
  String get adhanReminderNone;

  /// No description provided for @adhanTestThis.
  ///
  /// In ar, this message translates to:
  /// **'جرّب هذا الأذان'**
  String get adhanTestThis;

  /// No description provided for @adhanSunrise.
  ///
  /// In ar, this message translates to:
  /// **'تنبيه الشروق'**
  String get adhanSunrise;

  /// No description provided for @adhanSunriseHint.
  ///
  /// In ar, this message translates to:
  /// **'تنبيه لطيف حين ينتهي وقت الفجر'**
  String get adhanSunriseHint;

  /// No description provided for @adhanSunriseAt.
  ///
  /// In ar, this message translates to:
  /// **'عند الشروق'**
  String get adhanSunriseAt;

  /// No description provided for @adhanSunriseBefore.
  ///
  /// In ar, this message translates to:
  /// **'قبله بـ{minutes}'**
  String adhanSunriseBefore(String minutes);

  /// No description provided for @adhanSectionMuezzin.
  ///
  /// In ar, this message translates to:
  /// **'المؤذّن'**
  String get adhanSectionMuezzin;

  /// No description provided for @adhanSectionMuezzinHint.
  ///
  /// In ar, this message translates to:
  /// **'للفجر صوتٌ خاص إن شئت'**
  String get adhanSectionMuezzinHint;

  /// No description provided for @adhanMuezzinFajr.
  ///
  /// In ar, this message translates to:
  /// **'أذان الفجر'**
  String get adhanMuezzinFajr;

  /// No description provided for @adhanMuezzinOthers.
  ///
  /// In ar, this message translates to:
  /// **'الظهر والعصر والمغرب والعشاء'**
  String get adhanMuezzinOthers;

  /// No description provided for @adhanPickerTitleFajr.
  ///
  /// In ar, this message translates to:
  /// **'صوت أذان الفجر'**
  String get adhanPickerTitleFajr;

  /// No description provided for @adhanPickerTitleOthers.
  ///
  /// In ar, this message translates to:
  /// **'صوت الأذان'**
  String get adhanPickerTitleOthers;

  /// No description provided for @adhanPickerTones.
  ///
  /// In ar, this message translates to:
  /// **'نغمات مَدار'**
  String get adhanPickerTones;

  /// No description provided for @adhanPickerTonesHint.
  ///
  /// In ar, this message translates to:
  /// **'تنبيهات مركّبة إجرائيًا من أجراس وأوعية غنائية؛ لا صوت بشري فيها ولا لحن أذان'**
  String get adhanPickerTonesHint;

  /// No description provided for @adhanPickerYours.
  ///
  /// In ar, this message translates to:
  /// **'تسجيلاتك'**
  String get adhanPickerYours;

  /// No description provided for @adhanPickerYoursHint.
  ///
  /// In ar, this message translates to:
  /// **'أرفِق تسجيل أذانٍ تحبّه؛ يُنسخ إلى مَدار ويبقى على جهازك وحده'**
  String get adhanPickerYoursHint;

  /// No description provided for @adhanPickerEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لم تُرفِق أي تسجيل بعد'**
  String get adhanPickerEmpty;

  /// No description provided for @adhanPickerAttach.
  ///
  /// In ar, this message translates to:
  /// **'إرفاق تسجيل'**
  String get adhanPickerAttach;

  /// No description provided for @adhanPickerNote.
  ///
  /// In ar, this message translates to:
  /// **'لا يأتي مَدار بتسجيلات أذانٍ بأصوات بشرية، إذ لم نجد تسجيلًا بترخيصٍ مفتوح يمكن التحقّق منه'**
  String get adhanPickerNote;

  /// No description provided for @adhanListen.
  ///
  /// In ar, this message translates to:
  /// **'استماع'**
  String get adhanListen;

  /// No description provided for @adhanListenStop.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف الاستماع'**
  String get adhanListenStop;

  /// No description provided for @adhanSelected.
  ///
  /// In ar, this message translates to:
  /// **'مختار'**
  String get adhanSelected;

  /// No description provided for @adhanDone.
  ///
  /// In ar, this message translates to:
  /// **'تم'**
  String get adhanDone;

  /// No description provided for @adhanTestSlotHint.
  ///
  /// In ar, this message translates to:
  /// **'بصوت {sound}'**
  String adhanTestSlotHint(String sound);

  /// No description provided for @adhanMuezzinRename.
  ///
  /// In ar, this message translates to:
  /// **'إعادة التسمية'**
  String get adhanMuezzinRename;

  /// No description provided for @adhanMuezzinRenameTitle.
  ///
  /// In ar, this message translates to:
  /// **'اسم التسجيل'**
  String get adhanMuezzinRenameTitle;

  /// No description provided for @adhanMuezzinNameField.
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get adhanMuezzinNameField;

  /// No description provided for @adhanMuezzinAdded.
  ///
  /// In ar, this message translates to:
  /// **'أُضيف «{name}»'**
  String adhanMuezzinAdded(String name);

  /// No description provided for @adhanMuezzinDeleted.
  ///
  /// In ar, this message translates to:
  /// **'حُذف «{name}»'**
  String adhanMuezzinDeleted(String name);

  /// No description provided for @adhanMuezzinUnsupported.
  ///
  /// In ar, this message translates to:
  /// **'صيغة غير مدعومة؛ اختر ملفًا صوتيًا شائعًا'**
  String get adhanMuezzinUnsupported;

  /// No description provided for @adhanMuezzinTooLarge.
  ///
  /// In ar, this message translates to:
  /// **'الملف كبير جدًا'**
  String get adhanMuezzinTooLarge;

  /// No description provided for @adhanMuezzinUnreadable.
  ///
  /// In ar, this message translates to:
  /// **'تعذّرت قراءة الملف'**
  String get adhanMuezzinUnreadable;

  /// No description provided for @adhanMuezzinNoPreview.
  ///
  /// In ar, this message translates to:
  /// **'تُسمَع هذه الصيغة مع الأذان نفسه؛ جرّبها بـ«جرّب الأذان الآن»'**
  String get adhanMuezzinNoPreview;

  /// No description provided for @adhanMuezzinMissing.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل محذوف'**
  String get adhanMuezzinMissing;

  /// No description provided for @adhanSectionAlert.
  ///
  /// In ar, this message translates to:
  /// **'التنبيه'**
  String get adhanSectionAlert;

  /// No description provided for @adhanVibrate.
  ///
  /// In ar, this message translates to:
  /// **'الاهتزاز'**
  String get adhanVibrate;

  /// No description provided for @adhanVibrateHint.
  ///
  /// In ar, this message translates to:
  /// **'يهتزّ الهاتف مع الأذان والتذكير'**
  String get adhanVibrateHint;

  /// No description provided for @adhanFullScreen.
  ///
  /// In ar, this message translates to:
  /// **'شاشة الأذان الكاملة'**
  String get adhanFullScreen;

  /// No description provided for @adhanFullScreenHint.
  ///
  /// In ar, this message translates to:
  /// **'تظهر فوق شاشة القفل وتوقظ الشاشة عند الأذان'**
  String get adhanFullScreenHint;

  /// No description provided for @adhanQuiet.
  ///
  /// In ar, this message translates to:
  /// **'سكون الصلاة'**
  String get adhanQuiet;

  /// No description provided for @adhanQuietHint.
  ///
  /// In ar, this message translates to:
  /// **'تصمت موسيقى الألعاب وأصوات الأجواء مع الأذان وأثناء الصلاة'**
  String get adhanQuietHint;

  /// No description provided for @adhanQuietAdhanOnly.
  ///
  /// In ar, this message translates to:
  /// **'مع الأذان فقط'**
  String get adhanQuietAdhanOnly;

  /// No description provided for @adhanSnoozeLength.
  ///
  /// In ar, this message translates to:
  /// **'مدة التأجيل'**
  String get adhanSnoozeLength;

  /// No description provided for @adhanAlarmVolume.
  ///
  /// In ar, this message translates to:
  /// **'مستوى صوت المنبّه'**
  String get adhanAlarmVolume;

  /// No description provided for @adhanAlarmVolumeHint.
  ///
  /// In ar, this message translates to:
  /// **'يُرفَع الأذان على مستوى صوت المنبّه في هاتفك'**
  String get adhanAlarmVolumeHint;

  /// No description provided for @adhanAlarmMuted.
  ///
  /// In ar, this message translates to:
  /// **'صوت المنبّه مكتوم؛ لن يُسمَع الأذان'**
  String get adhanAlarmMuted;

  /// No description provided for @adhanOpenSoundSettings.
  ///
  /// In ar, this message translates to:
  /// **'إعدادات الصوت'**
  String get adhanOpenSoundSettings;

  /// No description provided for @adhanSectionTry.
  ///
  /// In ar, this message translates to:
  /// **'تجربة'**
  String get adhanSectionTry;

  /// No description provided for @adhanTestNow.
  ///
  /// In ar, this message translates to:
  /// **'جرّب الأذان الآن'**
  String get adhanTestNow;

  /// No description provided for @adhanTestHint.
  ///
  /// In ar, this message translates to:
  /// **'أذانٌ حقيقي بعد لحظات؛ أقفل الشاشة لترى عرضه الكامل'**
  String get adhanTestHint;

  /// No description provided for @adhanTestScheduled.
  ///
  /// In ar, this message translates to:
  /// **'سيُرفَع الأذان بعد {seconds}'**
  String adhanTestScheduled(String seconds);

  /// No description provided for @adhanTestFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّرت جدولة التجربة؛ تحقّق من الأذونات'**
  String get adhanTestFailed;

  /// No description provided for @adhanPermTitle.
  ///
  /// In ar, this message translates to:
  /// **'ليُرفَع الأذان في وقته'**
  String get adhanPermTitle;

  /// No description provided for @adhanPermSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'بضعة أذونات من أندرويد؛ لا يغادر شيءٌ جهازك'**
  String get adhanPermSubtitle;

  /// No description provided for @adhanPermReady.
  ///
  /// In ar, this message translates to:
  /// **'الأذان جاهز؛ كل ما يحتاجه مسموح'**
  String get adhanPermReady;

  /// No description provided for @adhanPermNotifications.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات'**
  String get adhanPermNotifications;

  /// No description provided for @adhanPermNotificationsHint.
  ///
  /// In ar, this message translates to:
  /// **'ليُسمَع الأذان ويظهر'**
  String get adhanPermNotificationsHint;

  /// No description provided for @adhanPermExact.
  ///
  /// In ar, this message translates to:
  /// **'المنبّهات الدقيقة'**
  String get adhanPermExact;

  /// No description provided for @adhanPermExactHint.
  ///
  /// In ar, this message translates to:
  /// **'ليُرفَع الأذان في الدقيقة نفسها، لا بعدها'**
  String get adhanPermExactHint;

  /// No description provided for @adhanPermFullScreen.
  ///
  /// In ar, this message translates to:
  /// **'الظهور فوق شاشة القفل'**
  String get adhanPermFullScreen;

  /// No description provided for @adhanPermFullScreenHint.
  ///
  /// In ar, this message translates to:
  /// **'لتظهر شاشة الأذان والهاتف مقفل'**
  String get adhanPermFullScreenHint;

  /// No description provided for @adhanPermBattery.
  ///
  /// In ar, this message translates to:
  /// **'استثناء من توفير البطارية'**
  String get adhanPermBattery;

  /// No description provided for @adhanPermBatteryHint.
  ///
  /// In ar, this message translates to:
  /// **'كي لا يوقف النظامُ الأذانَ لتوفير الطاقة'**
  String get adhanPermBatteryHint;

  /// No description provided for @adhanPermAllow.
  ///
  /// In ar, this message translates to:
  /// **'اسمح'**
  String get adhanPermAllow;

  /// No description provided for @adhanPermAllowed.
  ///
  /// In ar, this message translates to:
  /// **'مسموح'**
  String get adhanPermAllowed;

  /// Button on a permission the user refused in the system dialog: opens the system settings page for it
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get adhanPermOpenSettings;

  /// Line under a permission the user refused in the system dialog
  ///
  /// In ar, this message translates to:
  /// **'رفضتَه في نافذة أندرويد؛ فعّله من الإعدادات متى شئت'**
  String get adhanPermRefusedHint;

  /// No description provided for @adhanPermRequired.
  ///
  /// In ar, this message translates to:
  /// **'ضروري'**
  String get adhanPermRequired;

  /// No description provided for @adhanPermDeniedHint.
  ///
  /// In ar, this message translates to:
  /// **'إن رفضتَ الطلب من قبل، فعّله من إعدادات التطبيق'**
  String get adhanPermDeniedHint;

  /// Title of the prayer tracker screen
  ///
  /// In ar, this message translates to:
  /// **'متتبّع الصلاة'**
  String get trackerTitle;

  /// Prayer tracker tab: today's prayers
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get trackerTabToday;

  /// Prayer tracker tab: history, streaks and the qada ledger
  ///
  /// In ar, this message translates to:
  /// **'السجلّ'**
  String get trackerTabHistory;

  /// Marks today in the week strip
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get trackerTodayLabel;

  /// Section title: the five obligatory prayers
  ///
  /// In ar, this message translates to:
  /// **'الفرائض'**
  String get trackerObligatory;

  /// Hint under the obligatory prayers section
  ///
  /// In ar, this message translates to:
  /// **'اضغط لتبديل الحالة، واسحب يمينًا لتسجيلها في وقتها'**
  String get trackerObligatoryHint;

  /// Section title: Duha, Witr and Qiyam
  ///
  /// In ar, this message translates to:
  /// **'النوافل'**
  String get trackerVoluntary;

  /// Title of today's summary / the compact card
  ///
  /// In ar, this message translates to:
  /// **'صلوات اليوم'**
  String get trackerTodayPrayed;

  /// Under the big count in the progress ring (number already formatted)
  ///
  /// In ar, this message translates to:
  /// **'من {total}'**
  String trackerOfTotal(String total);

  /// Progress of the obligatory prayers (numbers already formatted)
  ///
  /// In ar, this message translates to:
  /// **'صلّيت {done} من {total}'**
  String trackerProgress(String done, String total);

  /// Banner when all five obligatory prayers of the day are prayed
  ///
  /// In ar, this message translates to:
  /// **'اكتملت صلواتك الخمس، تقبّل الله'**
  String get trackerAllDone;

  /// Countdown to the next prayer (duration already formatted)
  ///
  /// In ar, this message translates to:
  /// **'{prayer} بعد {duration}'**
  String trackerNextIn(String prayer, String duration);

  /// Summary line after Isha when nothing is upcoming
  ///
  /// In ar, this message translates to:
  /// **'حان وقت الصلوات الخمس كلها، والليل للنوافل'**
  String get trackerNightLeft;

  /// A streak length in days
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا سلسلة بعد} =1{يوم واحد} =2{يومان} few{{count} أيام} many{{count} يومًا} other{{count} يوم}}'**
  String trackerStreakDays(int count);

  /// Streak chip on the Today view and the compact card
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{ابدأ سلسلتك اليوم} =1{سلسلة يوم واحد} =2{سلسلة يومين} few{سلسلة {count} أيام} many{سلسلة {count} يومًا} other{سلسلة {count} يوم}}'**
  String trackerStreakChip(int count);

  /// The unit next to a big streak number (the number is shown separately)
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{يوم} =1{يوم} =2{يومان} few{أيام} many{يومًا} other{يوم}}'**
  String trackerDaysUnit(int count);

  /// How many of today's prayers were in jamaah (number already formatted)
  ///
  /// In ar, this message translates to:
  /// **'{count} في جماعة'**
  String trackerJamaahCount(String count);

  /// Status: prayed on time
  ///
  /// In ar, this message translates to:
  /// **'في وقتها'**
  String get trackerStatusPrayed;

  /// Status: prayed late
  ///
  /// In ar, this message translates to:
  /// **'متأخرة'**
  String get trackerStatusLate;

  /// Status: missed
  ///
  /// In ar, this message translates to:
  /// **'فاتت'**
  String get trackerStatusMissed;

  /// Status: a missed prayer made up (qada)
  ///
  /// In ar, this message translates to:
  /// **'قُضيت'**
  String get trackerStatusQada;

  /// Status: its time is running and it is not logged yet
  ///
  /// In ar, this message translates to:
  /// **'حان وقتها'**
  String get trackerStatusDue;

  /// Status: its time ended without a log
  ///
  /// In ar, this message translates to:
  /// **'لم تُسجَّل'**
  String get trackerStatusUnlogged;

  /// Status: its time has not come yet
  ///
  /// In ar, this message translates to:
  /// **'لم يحن وقتها'**
  String get trackerStatusUpcoming;

  /// Status of a voluntary prayer that was prayed
  ///
  /// In ar, this message translates to:
  /// **'صلّيتها'**
  String get trackerStatusVoluntaryDone;

  /// Status of a voluntary prayer not logged
  ///
  /// In ar, this message translates to:
  /// **'لم تُصلَّ بعد'**
  String get trackerStatusVoluntaryOpen;

  /// How long until a prayer is due (duration already formatted)
  ///
  /// In ar, this message translates to:
  /// **'بعد {duration}'**
  String trackerUpcomingIn(String duration);

  /// How long the current prayer's time still runs (duration already formatted)
  ///
  /// In ar, this message translates to:
  /// **'يبقى {duration}'**
  String trackerTimeLeft(String duration);

  /// Menu action: log as prayed on time
  ///
  /// In ar, this message translates to:
  /// **'صلّيتها في وقتها'**
  String get trackerActionPrayed;

  /// Menu action: log as prayed late
  ///
  /// In ar, this message translates to:
  /// **'صلّيتها متأخرة'**
  String get trackerActionLate;

  /// Menu action: log as missed
  ///
  /// In ar, this message translates to:
  /// **'فاتتني'**
  String get trackerActionMissed;

  /// Action: record that a missed prayer was made up
  ///
  /// In ar, this message translates to:
  /// **'قضيتها'**
  String get trackerActionMadeUp;

  /// Menu action: remove the log
  ///
  /// In ar, this message translates to:
  /// **'إلغاء التسجيل'**
  String get trackerActionClear;

  /// Menu action: mark as prayed in congregation
  ///
  /// In ar, this message translates to:
  /// **'صلّيتها في جماعة'**
  String get trackerActionJamaahOn;

  /// Menu action: unmark congregation
  ///
  /// In ar, this message translates to:
  /// **'لم أصلّها في جماعة'**
  String get trackerActionJamaahOff;

  /// Menu action: mark as prayed at the mosque
  ///
  /// In ar, this message translates to:
  /// **'صلّيتها في المسجد'**
  String get trackerActionMosqueOn;

  /// Menu action: unmark mosque
  ///
  /// In ar, this message translates to:
  /// **'لم أصلّها في المسجد'**
  String get trackerActionMosqueOff;

  /// Qada ledger: record every listed prayer as made up
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{قضيتها} =2{قضيتهما} other{قضيتها كلها}}'**
  String trackerActionMakeUpAll(int count);

  /// Toggle chip: prayed in congregation
  ///
  /// In ar, this message translates to:
  /// **'جماعة'**
  String get trackerJamaah;

  /// Toggle chip: prayed at the mosque
  ///
  /// In ar, this message translates to:
  /// **'المسجد'**
  String get trackerMosque;

  /// Screen-reader label of the swipe-to-log action
  ///
  /// In ar, this message translates to:
  /// **'صلّيتها'**
  String get trackerSwipePrayed;

  /// Undo toast after changing a prayer's status
  ///
  /// In ar, this message translates to:
  /// **'{prayer}: {status}'**
  String trackerUndoStatus(String prayer, String status);

  /// Undo toast after clearing a log
  ///
  /// In ar, this message translates to:
  /// **'أُلغي تسجيل {prayer}'**
  String trackerUndoCleared(String prayer);

  /// Undo toast after marking jamaah
  ///
  /// In ar, this message translates to:
  /// **'{prayer} في جماعة'**
  String trackerUndoJamaahOn(String prayer);

  /// Undo toast after unmarking jamaah
  ///
  /// In ar, this message translates to:
  /// **'{prayer} من غير جماعة'**
  String trackerUndoJamaahOff(String prayer);

  /// Undo toast after marking mosque
  ///
  /// In ar, this message translates to:
  /// **'{prayer} في المسجد'**
  String trackerUndoMosqueOn(String prayer);

  /// Undo toast after unmarking mosque
  ///
  /// In ar, this message translates to:
  /// **'{prayer} خارج المسجد'**
  String trackerUndoMosqueOff(String prayer);

  /// Undo toast after logging a voluntary prayer
  ///
  /// In ar, this message translates to:
  /// **'تمّ تسجيل {prayer}'**
  String trackerUndoVoluntaryOn(String prayer);

  /// Undo toast after removing a voluntary prayer
  ///
  /// In ar, this message translates to:
  /// **'أُلغي تسجيل {prayer}'**
  String trackerUndoVoluntaryOff(String prayer);

  /// Undo toast after making up a missed prayer (date already formatted)
  ///
  /// In ar, this message translates to:
  /// **'قُضيت صلاة {prayer} ليوم {date}'**
  String trackerUndoMadeUp(String prayer, String date);

  /// Undo toast after making up several prayers
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{قُضيت صلاة واحدة} =2{قُضيت صلاتان} few{قُضيت {count} صلوات} many{قُضيت {count} صلاة} other{قُضيت {count} صلاة}}'**
  String trackerUndoMadeUpAll(int count);

  /// Feedback when tapping a prayer whose time has not come
  ///
  /// In ar, this message translates to:
  /// **'لم يدخل وقت {prayer} بعد'**
  String trackerNotYet(String prayer);

  /// The two rak'ahs before Fajr
  ///
  /// In ar, this message translates to:
  /// **'سنّة الفجر'**
  String get trackerSunnahFajr;

  /// The rawatib of Dhuhr
  ///
  /// In ar, this message translates to:
  /// **'راتبة الظهر'**
  String get trackerSunnahDhuhr;

  /// The rawatib of Maghrib
  ///
  /// In ar, this message translates to:
  /// **'راتبة المغرب'**
  String get trackerSunnahMaghrib;

  /// The rawatib of Isha
  ///
  /// In ar, this message translates to:
  /// **'راتبة العشاء'**
  String get trackerSunnahIsha;

  /// The forenoon prayer
  ///
  /// In ar, this message translates to:
  /// **'الضحى'**
  String get trackerDuha;

  /// The odd-numbered night prayer
  ///
  /// In ar, this message translates to:
  /// **'الوتر'**
  String get trackerWitr;

  /// Qiyam al-layl
  ///
  /// In ar, this message translates to:
  /// **'قيام الليل'**
  String get trackerQiyam;

  /// Title of the sunnah chip under a fard
  ///
  /// In ar, this message translates to:
  /// **'السنّة الراتبة'**
  String get trackerSunnahLabel;

  /// Rak'ahs of a sunnah before its fard
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{ركعة قبلها} =2{ركعتان قبلها} few{{count} ركعات قبلها} many{{count} ركعة قبلها} other{{count} ركعة قبلها}}'**
  String trackerRakahBefore(int count);

  /// Rak'ahs of a sunnah after its fard
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{ركعة بعدها} =2{ركعتان بعدها} few{{count} ركعات بعدها} many{{count} ركعة بعدها} other{{count} ركعة بعدها}}'**
  String trackerRakahAfter(int count);

  /// Joins the rak'ahs before and after (both already formatted)
  ///
  /// In ar, this message translates to:
  /// **'{before} و{after}'**
  String trackerRakahBoth(String before, String after);

  /// When Duha is prayed
  ///
  /// In ar, this message translates to:
  /// **'من ارتفاع الشمس إلى الظهر'**
  String get trackerDuhaWindow;

  /// When Witr and the night prayer are prayed
  ///
  /// In ar, this message translates to:
  /// **'من العشاء إلى الفجر'**
  String get trackerNightWindow;

  /// History: the current streak
  ///
  /// In ar, this message translates to:
  /// **'السلسلة الحالية'**
  String get trackerStreakCurrent;

  /// History: the longest streak
  ///
  /// In ar, this message translates to:
  /// **'أطول سلسلة'**
  String get trackerStreakBest;

  /// How streaks are counted
  ///
  /// In ar, this message translates to:
  /// **'يُحتسب اليوم في السلسلة حين تُصلّى الفرائض الخمس أو تُقضى'**
  String get trackerStreakRule;

  /// History: the week strip
  ///
  /// In ar, this message translates to:
  /// **'آخر سبعة أيام'**
  String get trackerWeekTitle;

  /// History: the month heatmap
  ///
  /// In ar, this message translates to:
  /// **'خريطة الشهر'**
  String get trackerHeatmapTitle;

  /// Heatmap legend: fewer prayers
  ///
  /// In ar, this message translates to:
  /// **'أقل'**
  String get trackerLegendLess;

  /// Heatmap legend: all five prayed
  ///
  /// In ar, this message translates to:
  /// **'الخمس'**
  String get trackerLegendMore;

  /// Heatmap legend: the dots in a cell count the prayers in jamaah
  ///
  /// In ar, this message translates to:
  /// **'النقاط: صلوات الجماعة'**
  String get trackerLegendJamaah;

  /// Heatmap navigation
  ///
  /// In ar, this message translates to:
  /// **'الشهر السابق'**
  String get trackerPrevMonth;

  /// Heatmap navigation
  ///
  /// In ar, this message translates to:
  /// **'الشهر التالي'**
  String get trackerNextMonth;

  /// Screen-reader label of a day cell (all values already formatted)
  ///
  /// In ar, this message translates to:
  /// **'{date}: صلّيت {done} من {total}، منها {jamaah} في جماعة'**
  String trackerDaySemantics(
    String date,
    String done,
    String total,
    String jamaah,
  );

  /// History: totals of the shown month (month name already formatted)
  ///
  /// In ar, this message translates to:
  /// **'حصاد {month}'**
  String trackerTotalsTitle(String month);

  /// Total: share prayed on time
  ///
  /// In ar, this message translates to:
  /// **'في وقتها'**
  String get trackerTotalOnTime;

  /// Total: share prayed in jamaah
  ///
  /// In ar, this message translates to:
  /// **'في جماعة'**
  String get trackerTotalJamaah;

  /// Total: share prayed at the mosque
  ///
  /// In ar, this message translates to:
  /// **'في المسجد'**
  String get trackerTotalMosque;

  /// Total: days with all five prayed
  ///
  /// In ar, this message translates to:
  /// **'أيام مكتملة'**
  String get trackerTotalCompleteDays;

  /// Total: sunnah rawatib prayed
  ///
  /// In ar, this message translates to:
  /// **'الرواتب'**
  String get trackerTotalRawatib;

  /// Heading of the sunnah counts
  ///
  /// In ar, this message translates to:
  /// **'النوافل والسنن'**
  String get trackerTotalSunnahTitle;

  /// History: stacked bars per obligatory prayer
  ///
  /// In ar, this message translates to:
  /// **'كل صلاة على حدة'**
  String get trackerBreakdownTitle;

  /// History: empty month
  ///
  /// In ar, this message translates to:
  /// **'لا سجلات في هذا الشهر بعد'**
  String get trackerNoMonthData;

  /// History: missed prayers waiting to be made up
  ///
  /// In ar, this message translates to:
  /// **'دفتر القضاء'**
  String get trackerQadaTitle;

  /// Qada ledger summary
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا صلوات بانتظار القضاء} =1{صلاة واحدة بانتظار القضاء} =2{صلاتان بانتظار القضاء} few{{count} صلوات بانتظار القضاء} many{{count} صلاة بانتظار القضاء} other{{count} صلاة بانتظار القضاء}}'**
  String trackerQadaOutstanding(int count);

  /// Qada ledger: prayers already made up (number already formatted)
  ///
  /// In ar, this message translates to:
  /// **'قُضيت حتى الآن: {count}'**
  String trackerQadaMadeUpSoFar(String count);

  /// Qada ledger: empty
  ///
  /// In ar, this message translates to:
  /// **'لا صلوات فائتة تنتظر القضاء، بارك الله فيك'**
  String get trackerQadaEmpty;

  /// Qada ledger: empty for the selected prayer
  ///
  /// In ar, this message translates to:
  /// **'لا قضاء لصلاة {prayer}'**
  String trackerQadaEmptyFiltered(String prayer);

  /// Qada ledger row: the day it was missed (date already formatted)
  ///
  /// In ar, this message translates to:
  /// **'فاتت يوم {date}'**
  String trackerQadaMissedOn(String date);

  /// Qada ledger: reveals the next rows of a long backlog
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{اعرض صلاة أخرى} =2{اعرض صلاتين أخريين} few{اعرض {count} صلوات أخرى} many{اعرض {count} صلاة أخرى} other{اعرض {count} صلاة أخرى}}'**
  String trackerQadaShowMore(int count);

  /// Qada ledger filter: every prayer
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get trackerFilterAll;

  /// Compact card: open the prayer tracker
  ///
  /// In ar, this message translates to:
  /// **'افتح المتتبّع'**
  String get trackerCardOpen;

  /// Screen-reader label of a prayer row (all parts already formatted)
  ///
  /// In ar, this message translates to:
  /// **'{prayer}، {time}، {status}'**
  String trackerSlotSemantics(String prayer, String time, String status);

  /// Joins two short labels
  ///
  /// In ar, this message translates to:
  /// **'{first}، {second}'**
  String trackerMarks(String first, String second);

  /// When a voluntary prayer's time ends (time already formatted)
  ///
  /// In ar, this message translates to:
  /// **'حتى {time}'**
  String trackerUntil(String time);

  /// Status of a prayer whose time is running (duration already formatted)
  ///
  /// In ar, this message translates to:
  /// **'حان وقتها · يبقى {duration}'**
  String trackerDueNow(String duration);

  /// Screen-reader label of a figure (value already formatted)
  ///
  /// In ar, this message translates to:
  /// **'{label}: {value}'**
  String trackerValueOf(String label, String value);

  /// Title of the adhkar home screen
  ///
  /// In ar, this message translates to:
  /// **'الأذكار'**
  String get adhkarTitle;

  /// Header of today's adhkar progress (home hero and the Faith card)
  ///
  /// In ar, this message translates to:
  /// **'أذكار اليوم'**
  String get adhkarTodayTitle;

  /// Sets finished today, e.g. 2 of 5 (numbers pre-formatted)
  ///
  /// In ar, this message translates to:
  /// **'{done} من {total}'**
  String adhkarSetsDoneOf(String done, String total);

  /// Caption under the sets-done count in the hero ring
  ///
  /// In ar, this message translates to:
  /// **'مجموعات مكتملة'**
  String get adhkarSetsDoneCaption;

  /// Adhkar set name
  ///
  /// In ar, this message translates to:
  /// **'أذكار الصباح'**
  String get adhkarCategoryMorning;

  /// Adhkar set name
  ///
  /// In ar, this message translates to:
  /// **'أذكار المساء'**
  String get adhkarCategoryEvening;

  /// Adhkar set name
  ///
  /// In ar, this message translates to:
  /// **'أذكار بعد الصلاة'**
  String get adhkarCategoryAfterPrayer;

  /// Adhkar set name
  ///
  /// In ar, this message translates to:
  /// **'أذكار النوم'**
  String get adhkarCategorySleep;

  /// Adhkar set name
  ///
  /// In ar, this message translates to:
  /// **'أذكار الاستيقاظ'**
  String get adhkarCategoryWaking;

  /// When the morning adhkar are said
  ///
  /// In ar, this message translates to:
  /// **'من الفجر حتى الضحى'**
  String get adhkarCategoryMorningHint;

  /// When the evening adhkar are said
  ///
  /// In ar, this message translates to:
  /// **'من العصر إلى ما بعد المغرب'**
  String get adhkarCategoryEveningHint;

  /// When the after-prayer adhkar are said
  ///
  /// In ar, this message translates to:
  /// **'عقب السلام من كل فريضة'**
  String get adhkarCategoryAfterPrayerHint;

  /// When the sleep adhkar are said
  ///
  /// In ar, this message translates to:
  /// **'حين تأوي إلى فراشك'**
  String get adhkarCategorySleepHint;

  /// When the waking adhkar are said
  ///
  /// In ar, this message translates to:
  /// **'حين تستيقظ من نومك'**
  String get adhkarCategoryWakingHint;

  /// Suggestion in the morning windows
  ///
  /// In ar, this message translates to:
  /// **'حان وقت أذكار الصباح'**
  String get adhkarSuggestMorning;

  /// Suggestion in the Asr and Maghrib windows
  ///
  /// In ar, this message translates to:
  /// **'حان وقت أذكار المساء'**
  String get adhkarSuggestEvening;

  /// Suggestion after Isha
  ///
  /// In ar, this message translates to:
  /// **'أذكار النوم قبل أن تأوي إلى فراشك'**
  String get adhkarSuggestSleep;

  /// Suggestion for the waking set
  ///
  /// In ar, this message translates to:
  /// **'أذكار الاستيقاظ'**
  String get adhkarSuggestWaking;

  /// Suggestion after an obligatory prayer
  ///
  /// In ar, this message translates to:
  /// **'أذكار ما بعد صلاة {prayer}'**
  String adhkarSuggestAfterPrayer(String prayer);

  /// Hero line when every set is done
  ///
  /// In ar, this message translates to:
  /// **'أتممتَ أذكار يومك — تقبّل الله'**
  String get adhkarSuggestAllDone;

  /// Opens a set from the start
  ///
  /// In ar, this message translates to:
  /// **'ابدأ'**
  String get adhkarStart;

  /// Resumes a started set
  ///
  /// In ar, this message translates to:
  /// **'تابِع'**
  String get adhkarContinue;

  /// Resume hint on a set card (position pre-formatted)
  ///
  /// In ar, this message translates to:
  /// **'تابِع من الذكر {position}'**
  String adhkarContinueAt(String position);

  /// Badge on a finished set
  ///
  /// In ar, this message translates to:
  /// **'تمّت اليوم'**
  String get adhkarDoneToday;

  /// After-prayer sets finished today (numbers pre-formatted)
  ///
  /// In ar, this message translates to:
  /// **'{done} من {total} صلوات'**
  String adhkarAfterPrayerProgress(String done, String total);

  /// Number of adhkar in a set
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{ذكر واحد} =2{ذكران} few{{count} أذكار} many{{count} ذكرًا} other{{count} ذكر}}'**
  String adhkarItemsCount(int count);

  /// Long-press / swipe action on a set card
  ///
  /// In ar, this message translates to:
  /// **'تمّت قراءتها'**
  String get adhkarMarkDone;

  /// Undo toast after marking a set done
  ///
  /// In ar, this message translates to:
  /// **'{name}: تمّت — تقبّل الله'**
  String adhkarMarkedDone(String name);

  /// Action that clears today's progress of a set
  ///
  /// In ar, this message translates to:
  /// **'البدء من جديد'**
  String get adhkarRestart;

  /// Undo toast after restarting a set
  ///
  /// In ar, this message translates to:
  /// **'بدأت {name} من جديد'**
  String adhkarRestarted(String name);

  /// Content credit at the foot of the adhkar home
  ///
  /// In ar, this message translates to:
  /// **'من «حصن المسلم» لسعيد بن علي بن وهف القحطاني'**
  String get adhkarSourceCredit;

  /// Shown if the bundled adhkar cannot be read
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل الأذكار'**
  String get adhkarLoadError;

  /// Title of the tasbeeh counter
  ///
  /// In ar, this message translates to:
  /// **'المسبحة'**
  String get adhkarTasbeehTitle;

  /// Subtitle of the tasbeeh entry card
  ///
  /// In ar, this message translates to:
  /// **'حلقة من الخرز تتقدّم مع كل تسبيحة'**
  String get adhkarTasbeehCardSubtitle;

  /// Tasbeeh total today (number pre-formatted)
  ///
  /// In ar, this message translates to:
  /// **'اليوم: {count}'**
  String adhkarTasbeehToday(String count);

  /// Section header of the adhkar reminders
  ///
  /// In ar, this message translates to:
  /// **'التذكير'**
  String get adhkarRemindersTitle;

  /// Switch
  ///
  /// In ar, this message translates to:
  /// **'ذكّرني بأذكار الصباح بعد الفجر'**
  String get adhkarReminderMorningLabel;

  /// Switch
  ///
  /// In ar, this message translates to:
  /// **'ذكّرني بأذكار المساء بعد العصر'**
  String get adhkarReminderEveningLabel;

  /// Reminder offset pill: how long after the adhan (shown under the caption adhkarReminderOffsetCaption)
  ///
  /// In ar, this message translates to:
  /// **'{minutes, plural, =0{مع الأذان} =1{دقيقة} =2{دقيقتان} few{{minutes} دقائق} many{{minutes} دقيقة} other{{minutes} دقيقة}}'**
  String adhkarReminderOffset(int minutes);

  /// Caption above the reminder offset pills
  ///
  /// In ar, this message translates to:
  /// **'موعد التذكير بعد الأذان'**
  String get adhkarReminderOffsetCaption;

  /// Footnote of the reminders section
  ///
  /// In ar, this message translates to:
  /// **'تصلك التذكيرات على الجهاز فقط، متى سمحتَ لمَدار بالإشعارات.'**
  String get adhkarReminderNote;

  /// Notification title
  ///
  /// In ar, this message translates to:
  /// **'أذكار الصباح'**
  String get adhkarReminderMorningTitle;

  /// Notification body
  ///
  /// In ar, this message translates to:
  /// **'حان وقت أذكار الصباح — ابدأ يومك بذكر الله'**
  String get adhkarReminderMorningBody;

  /// Notification title
  ///
  /// In ar, this message translates to:
  /// **'أذكار المساء'**
  String get adhkarReminderEveningTitle;

  /// Notification body
  ///
  /// In ar, this message translates to:
  /// **'حان وقت أذكار المساء — طمأنينةٌ تختم بها نهارك'**
  String get adhkarReminderEveningBody;

  /// Position of the dhikr in its set (numbers pre-formatted)
  ///
  /// In ar, this message translates to:
  /// **'{index} من {total}'**
  String adhkarReaderPosition(String index, String total);

  /// Caption under the remaining count in the counter ring
  ///
  /// In ar, this message translates to:
  /// **'متبقٍّ'**
  String get adhkarRemaining;

  /// Caption in the counter ring when the dhikr is finished
  ///
  /// In ar, this message translates to:
  /// **'تمّ'**
  String get adhkarCounterDone;

  /// Hint under the counter
  ///
  /// In ar, this message translates to:
  /// **'انقر في أي مكان للعدّ'**
  String get adhkarCounterHint;

  /// Screen-reader label of the counter ring
  ///
  /// In ar, this message translates to:
  /// **'عُدّ مرة — {done} من {total}'**
  String adhkarCounterSemantics(String done, String total);

  /// How many times a dhikr is said
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{مرة واحدة} =2{مرتان} few{{count} مرات} many{{count} مرة} other{{count} مرة}}'**
  String adhkarRepeat(int count);

  /// Button that ticks off a reading item (whole surahs)
  ///
  /// In ar, this message translates to:
  /// **'قرأتُها'**
  String get adhkarReadingDone;

  /// Label of the virtue under a dhikr
  ///
  /// In ar, this message translates to:
  /// **'فضلها'**
  String get adhkarVirtue;

  /// Label of the hadith reference
  ///
  /// In ar, this message translates to:
  /// **'المصدر'**
  String get adhkarReference;

  /// Label of the English meaning
  ///
  /// In ar, this message translates to:
  /// **'المعنى'**
  String get adhkarMeaning;

  /// Quran reference under verses, e.g. Surat al-Baqarah · 255 (ayahs pre-formatted)
  ///
  /// In ar, this message translates to:
  /// **'سورة {surah}: {ayahs}'**
  String adhkarQuranRef(String surah, String ayahs);

  /// Surah name
  ///
  /// In ar, this message translates to:
  /// **'البقرة'**
  String get adhkarSurah2;

  /// Surah name
  ///
  /// In ar, this message translates to:
  /// **'آل عمران'**
  String get adhkarSurah3;

  /// Surah name
  ///
  /// In ar, this message translates to:
  /// **'الإخلاص'**
  String get adhkarSurah112;

  /// Surah name
  ///
  /// In ar, this message translates to:
  /// **'الفلق'**
  String get adhkarSurah113;

  /// Surah name
  ///
  /// In ar, this message translates to:
  /// **'الناس'**
  String get adhkarSurah114;

  /// Fallback surah label (number pre-formatted)
  ///
  /// In ar, this message translates to:
  /// **'رقم {number}'**
  String adhkarSurahNumber(String number);

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'الذكر السابق'**
  String get adhkarPrevious;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'الذكر التالي'**
  String get adhkarNext;

  /// Screen-reader label of a progress dot (numbers pre-formatted)
  ///
  /// In ar, this message translates to:
  /// **'الذكر {index} من {total}'**
  String adhkarDhikrSemantics(String index, String total);

  /// Title of the reader options sheet
  ///
  /// In ar, this message translates to:
  /// **'خيارات القراءة'**
  String get adhkarOptionsTitle;

  /// Reader option
  ///
  /// In ar, this message translates to:
  /// **'حجم الخط'**
  String get adhkarTextSize;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'تصغير الخط'**
  String get adhkarTextSizeSmaller;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'تكبير الخط'**
  String get adhkarTextSizeLarger;

  /// Reader option (English UI only)
  ///
  /// In ar, this message translates to:
  /// **'إظهار المعنى بالإنجليزية'**
  String get adhkarShowTranslation;

  /// Reader option
  ///
  /// In ar, this message translates to:
  /// **'إظهار الفضل والمصدر'**
  String get adhkarShowVirtue;

  /// Reader option
  ///
  /// In ar, this message translates to:
  /// **'إعادة عدّ هذا الذكر'**
  String get adhkarRecountCurrent;

  /// Reader option
  ///
  /// In ar, this message translates to:
  /// **'البدء من أول المجموعة'**
  String get adhkarRestartSet;

  /// Reader option that marks the set done
  ///
  /// In ar, this message translates to:
  /// **'قرأتُ المجموعة كلّها'**
  String get adhkarMarkSetDone;

  /// Prayer chip of the after-prayer reader
  ///
  /// In ar, this message translates to:
  /// **'بعد صلاة {prayer}'**
  String adhkarAfterPrayerFor(String prayer);

  /// Title of the prayer picker of the after-prayer reader
  ///
  /// In ar, this message translates to:
  /// **'بعد أي صلاة؟'**
  String get adhkarChoosePrayer;

  /// Title of the set-complete view
  ///
  /// In ar, this message translates to:
  /// **'تقبّل الله منك'**
  String get adhkarSetCompleteTitle;

  /// Body of the set-complete view
  ///
  /// In ar, this message translates to:
  /// **'اكتملت {name}'**
  String adhkarSetCompleteBody(String name);

  /// Button on the set-complete view
  ///
  /// In ar, this message translates to:
  /// **'مراجعة الأذكار'**
  String get adhkarSetCompleteReview;

  /// Title of the per-dhikr audio sheet
  ///
  /// In ar, this message translates to:
  /// **'التسجيل الصوتي'**
  String get adhkarAudioTitle;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'إرفاق تسجيل'**
  String get adhkarAudioAttach;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'استبدال'**
  String get adhkarAudioReplace;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'إزالة'**
  String get adhkarAudioRemove;

  /// Undo toast
  ///
  /// In ar, this message translates to:
  /// **'أُزيل التسجيل'**
  String get adhkarAudioRemoved;

  /// Toast after attaching
  ///
  /// In ar, this message translates to:
  /// **'أُرفق التسجيل'**
  String get adhkarAudioAttached;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'تشغيل التسجيل'**
  String get adhkarAudioPlay;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'إيقاف التسجيل'**
  String get adhkarAudioStop;

  /// Empty state of the audio sheet
  ///
  /// In ar, this message translates to:
  /// **'لا تسجيل لهذا الذكر بعد. أرفق ملفًا صوتيًا من جهازك (MP3 أو WAV أو FLAC) لتسمعه هنا.'**
  String get adhkarAudioNone;

  /// Policy note on the audio sheet
  ///
  /// In ar, this message translates to:
  /// **'لا يستخدم مَدار أصواتًا مولّدة آليًّا للقرآن أو الأذكار؛ أرفق تسجيلًا تثق به، ويبقى على جهازك.'**
  String get adhkarAudioPolicy;

  /// Error
  ///
  /// In ar, this message translates to:
  /// **'هذا الملف ليس بصيغة مدعومة (MP3 أو WAV أو FLAC)'**
  String get adhkarAudioUnsupported;

  /// Error
  ///
  /// In ar, this message translates to:
  /// **'الملف أكبر من ٣٠ ميغابايت'**
  String get adhkarAudioTooLarge;

  /// Error
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تشغيل الصوت على هذا الجهاز'**
  String get adhkarAudioUnavailable;

  /// Attached file line (duration pre-formatted)
  ///
  /// In ar, this message translates to:
  /// **'{name}، {duration}'**
  String adhkarAudioFile(String name, String duration);

  /// Label of the target choice
  ///
  /// In ar, this message translates to:
  /// **'عدد الدورة'**
  String get adhkarTasbeehTarget;

  /// Custom target choice
  ///
  /// In ar, this message translates to:
  /// **'مخصّص'**
  String get adhkarTasbeehCustom;

  /// Title of the custom target sheet
  ///
  /// In ar, this message translates to:
  /// **'عدد مخصّص للدورة'**
  String get adhkarTasbeehCustomTitle;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'العدد في كل دورة'**
  String get adhkarTasbeehCustomField;

  /// Validation
  ///
  /// In ar, this message translates to:
  /// **'أدخل عددًا من ١ إلى ٩٩٩٩'**
  String get adhkarTasbeehCustomInvalid;

  /// Current round (number pre-formatted)
  ///
  /// In ar, this message translates to:
  /// **'الدورة {round}'**
  String adhkarTasbeehRound(String round);

  /// Under the count (number pre-formatted)
  ///
  /// In ar, this message translates to:
  /// **'من {target}'**
  String adhkarTasbeehOf(String target);

  /// Total taps of the session (number pre-formatted)
  ///
  /// In ar, this message translates to:
  /// **'المجموع {count}'**
  String adhkarTasbeehTotal(String count);

  /// Hint under the ring
  ///
  /// In ar, this message translates to:
  /// **'انقر للتسبيح، واضغط مطوّلًا لإعادة العدّ'**
  String get adhkarTasbeehTapHint;

  /// Screen-reader label of the ring (numbers pre-formatted)
  ///
  /// In ar, this message translates to:
  /// **'{phrase}: {count} من {target}، الدورة {round}'**
  String adhkarTasbeehCountSemantics(
    String phrase,
    String count,
    String target,
    String round,
  );

  /// Screen-reader hint of the ring
  ///
  /// In ar, this message translates to:
  /// **'انقر نقرتين للتسبيح'**
  String get adhkarTasbeehCountHint;

  /// Title of the reset confirmation
  ///
  /// In ar, this message translates to:
  /// **'إعادة العدّ؟'**
  String get adhkarTasbeehResetTitle;

  /// Body of the reset confirmation (number pre-formatted)
  ///
  /// In ar, this message translates to:
  /// **'يُحفظ عددك ({count}) في السجل، ثم يبدأ العدّ من الصفر.'**
  String adhkarTasbeehResetBody(String count);

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'إعادة العدّ'**
  String get adhkarTasbeehReset;

  /// Title of the phrase editor
  ///
  /// In ar, this message translates to:
  /// **'أذكار المسبحة'**
  String get adhkarTasbeehPhrases;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'تعديل الأذكار'**
  String get adhkarTasbeehEditPhrases;

  /// Button / sheet title
  ///
  /// In ar, this message translates to:
  /// **'إضافة ذكر'**
  String get adhkarTasbeehAddPhrase;

  /// Sheet title
  ///
  /// In ar, this message translates to:
  /// **'تعديل الذكر'**
  String get adhkarTasbeehEditPhrase;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'نص الذكر'**
  String get adhkarTasbeehPhraseField;

  /// Undo toast
  ///
  /// In ar, this message translates to:
  /// **'حُذف الذكر'**
  String get adhkarTasbeehPhraseDeleted;

  /// Empty state
  ///
  /// In ar, this message translates to:
  /// **'أضف ذكرًا لتبدأ التسبيح'**
  String get adhkarTasbeehNoPhrases;

  /// Title of the history sheet
  ///
  /// In ar, this message translates to:
  /// **'سجلّ التسبيح'**
  String get adhkarTasbeehHistory;

  /// Empty history
  ///
  /// In ar, this message translates to:
  /// **'لم تُسجَّل جلسات بعد'**
  String get adhkarTasbeehHistoryEmpty;

  /// Undo toast
  ///
  /// In ar, this message translates to:
  /// **'حُذفت الجلسة'**
  String get adhkarTasbeehSessionDeleted;

  /// Rounds of a history session
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{دون دورة كاملة} =1{دورة واحدة} =2{دورتان} few{{count} دورات} many{{count} دورة} other{{count} دورة}}'**
  String adhkarTasbeehRounds(int count);

  /// English meaning of a built-in tasbeeh phrase (shown in the English UI)
  ///
  /// In ar, this message translates to:
  /// **'سبحان الله'**
  String get adhkarPhraseSubhanallah;

  /// English meaning of a built-in tasbeeh phrase
  ///
  /// In ar, this message translates to:
  /// **'الحمد لله'**
  String get adhkarPhraseAlhamdulillah;

  /// English meaning of a built-in tasbeeh phrase
  ///
  /// In ar, this message translates to:
  /// **'الله أكبر'**
  String get adhkarPhraseAllahuakbar;

  /// English meaning of a built-in tasbeeh phrase
  ///
  /// In ar, this message translates to:
  /// **'لا إله إلا الله'**
  String get adhkarPhraseTahlil;

  /// English meaning of a built-in tasbeeh phrase
  ///
  /// In ar, this message translates to:
  /// **'أستغفر الله'**
  String get adhkarPhraseIstighfar;

  /// English meaning of a built-in tasbeeh phrase
  ///
  /// In ar, this message translates to:
  /// **'سبحان الله وبحمده'**
  String get adhkarPhraseSubhanallahWaBihamdihi;

  /// English meaning of a built-in tasbeeh phrase
  ///
  /// In ar, this message translates to:
  /// **'سبحان الله العظيم'**
  String get adhkarPhraseSubhanallahilAzim;

  /// English meaning of a built-in tasbeeh phrase
  ///
  /// In ar, this message translates to:
  /// **'لا حول ولا قوة إلا بالله'**
  String get adhkarPhraseHawqala;

  /// English meaning of a built-in tasbeeh phrase
  ///
  /// In ar, this message translates to:
  /// **'اللهم صل وسلم على نبينا محمد'**
  String get adhkarPhraseSalawat;

  /// Link from the Faith card to the adhkar home
  ///
  /// In ar, this message translates to:
  /// **'كل الأذكار'**
  String get adhkarAllAdhkar;

  /// Short set label under a small ring (Faith card)
  ///
  /// In ar, this message translates to:
  /// **'الصباح'**
  String get adhkarShortMorning;

  /// Short set label
  ///
  /// In ar, this message translates to:
  /// **'المساء'**
  String get adhkarShortEvening;

  /// Short set label
  ///
  /// In ar, this message translates to:
  /// **'بعد الصلاة'**
  String get adhkarShortAfterPrayer;

  /// Short set label
  ///
  /// In ar, this message translates to:
  /// **'النوم'**
  String get adhkarShortSleep;

  /// Short set label
  ///
  /// In ar, this message translates to:
  /// **'الاستيقاظ'**
  String get adhkarShortWaking;

  /// Joins two short facts on one line. Arabic uses a comma because a middle dot reads like the Arabic-Indic zero
  ///
  /// In ar, this message translates to:
  /// **'{first}، {second}'**
  String adhkarJoin(String first, String second);

  /// Chip on the Faith card with today's tasbeeh total (number pre-formatted)
  ///
  /// In ar, this message translates to:
  /// **'المسبحة: {count}'**
  String adhkarTasbeehChip(String count);

  /// Faith card line: the suggested set plus how many sets are finished (numbers pre-formatted)
  ///
  /// In ar, this message translates to:
  /// **'{suggestion} (أُنجز {done} من {total})'**
  String adhkarTodayLine(String suggestion, String done, String total);

  /// Android notification channel name (system settings) of the adhkar reminders
  ///
  /// In ar, this message translates to:
  /// **'تذكير الأذكار'**
  String get adhkarReminderChannelName;

  /// Android notification channel description of the adhkar reminders
  ///
  /// In ar, this message translates to:
  /// **'تذكيرٌ بأذكار الصباح بعد الفجر وبأذكار المساء بعد العصر'**
  String get adhkarReminderChannelDescription;

  /// Shown in the reminders card when a reminder is on but notifications were refused
  ///
  /// In ar, this message translates to:
  /// **'إشعارات مَدار متوقفة، فلن يصلك التذكير. يمكنك تفعيلها من إعدادات الجهاز.'**
  String get adhkarReminderPermissionDenied;

  /// Hero line when the set that fits the moment is already finished (set = morning | evening | sleep | waking | afterPrayer)
  ///
  /// In ar, this message translates to:
  /// **'{set, select, morning{أتممتَ أذكار الصباح — تقبّل الله} evening{أتممتَ أذكار المساء — تقبّل الله} sleep{أتممتَ أذكار النوم — تصبح على خير} waking{أتممتَ أذكار الاستيقاظ — يومٌ مبارك} other{أتممتَ الأذكار — تقبّل الله}}'**
  String adhkarSuggestDone(String set);

  /// Hero line when the after-prayer adhkar of the prayer just due are finished
  ///
  /// In ar, this message translates to:
  /// **'أتممتَ أذكار ما بعد صلاة {prayer} — تقبّل الله'**
  String adhkarSuggestAfterPrayerDone(String prayer);

  /// Next prayer card: the prayer time
  ///
  /// In ar, this message translates to:
  /// **'عند {time}'**
  String faithHubAt(String time);

  /// Link: the tracker history tab
  ///
  /// In ar, this message translates to:
  /// **'سجلّ الصلوات'**
  String get faithHubHistory;

  /// Link hint: tracker history
  ///
  /// In ar, this message translates to:
  /// **'السلاسل والقضاء والإحصاءات'**
  String get faithHubHistoryHint;

  /// Link hint: adhkar
  ///
  /// In ar, this message translates to:
  /// **'حصن المسلم'**
  String get faithHubAdhkarHint;

  /// Link hint: tasbeeh
  ///
  /// In ar, this message translates to:
  /// **'عدّاد بالخرز'**
  String get faithHubTasbeehHint;

  /// Link hint: adhan settings
  ///
  /// In ar, this message translates to:
  /// **'المؤذّن والتذكير والأذونات'**
  String get faithHubAdhanHint;

  /// Faith page: section of today's prayers and adhkar
  ///
  /// In ar, this message translates to:
  /// **'يومك'**
  String get faithHubTodayTitle;

  /// Faith page: section of continue reading, the wird and Hifz
  ///
  /// In ar, this message translates to:
  /// **'مع القرآن'**
  String get faithHubQuranTitle;

  /// Faith page: action opening the Quran's index
  ///
  /// In ar, this message translates to:
  /// **'الفهرس'**
  String get faithHubQuranIndex;

  /// Faith page: section of the qibla and the faith tools
  ///
  /// In ar, this message translates to:
  /// **'أدوات'**
  String get faithHubToolsTitle;

  /// Tool hint: the Quran home
  ///
  /// In ar, this message translates to:
  /// **'الفهرس والبحث والعلامات'**
  String get faithHubMushafHint;

  /// Tool hint: Hifz
  ///
  /// In ar, this message translates to:
  /// **'مراجعة بالتكرار المتباعد'**
  String get faithHubHifzHint;

  /// Tool hint: recitation settings
  ///
  /// In ar, this message translates to:
  /// **'القرّاء والتكرار والتنزيل'**
  String get faithHubRecitationHint;

  /// Tool: the adhan settings
  ///
  /// In ar, this message translates to:
  /// **'الأذان'**
  String get faithHubAdhanTool;

  /// Toast: add to Hifz found nothing new
  ///
  /// In ar, this message translates to:
  /// **'هذه الآيات في حفظك من قبل'**
  String get faithHubHifzAlready;

  /// Title of the Quran home screen
  ///
  /// In ar, this message translates to:
  /// **'القرآن الكريم'**
  String get quranTitle;

  /// A sura's title, e.g. Surah Al-Baqarah
  ///
  /// In ar, this message translates to:
  /// **'سورة {name}'**
  String quranSurahTitle(String name);

  /// Sura revealed in Makkah
  ///
  /// In ar, this message translates to:
  /// **'مكية'**
  String get quranMakki;

  /// Sura revealed in Madinah
  ///
  /// In ar, this message translates to:
  /// **'مدنية'**
  String get quranMadani;

  /// Number of ayat (digits localised by the caller)
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا آيات} =1{آية واحدة} =2{آيتان} few{{count} آيات} many{{count} آية} other{{count} آية}}'**
  String quranAyatCount(int count);

  /// Mushaf page number (pre-formatted)
  ///
  /// In ar, this message translates to:
  /// **'صفحة {page}'**
  String quranPageLabel(String page);

  /// Position in the 604-page mushaf
  ///
  /// In ar, this message translates to:
  /// **'صفحة {page} من {total}'**
  String quranPageCounter(String page, String total);

  /// Juz number (pre-formatted)
  ///
  /// In ar, this message translates to:
  /// **'الجزء {juz}'**
  String quranJuzLabel(String juz);

  /// Hizb number (pre-formatted)
  ///
  /// In ar, this message translates to:
  /// **'الحزب {hizb}'**
  String quranHizbLabel(String hizb);

  /// Ayah number (pre-formatted)
  ///
  /// In ar, this message translates to:
  /// **'الآية {ayah}'**
  String quranAyahLabel(String ayah);

  /// A place in the Quran: sura name and ayah number
  ///
  /// In ar, this message translates to:
  /// **'{surah}، الآية {ayah}'**
  String quranAyahOfSurah(String surah, String ayah);

  /// Mushaf page header: juz and hizb
  ///
  /// In ar, this message translates to:
  /// **'الجزء {juz}، الحزب {hizb}'**
  String quranJuzHizb(String juz, String hizb);

  /// Second quarter of a hizb
  ///
  /// In ar, this message translates to:
  /// **'ربع الحزب {hizb}'**
  String quranQuarter1(String hizb);

  /// Middle of a hizb
  ///
  /// In ar, this message translates to:
  /// **'نصف الحزب {hizb}'**
  String quranQuarter2(String hizb);

  /// Last quarter of a hizb
  ///
  /// In ar, this message translates to:
  /// **'ثلاثة أرباع الحزب {hizb}'**
  String quranQuarter3(String hizb);

  /// Reference after a copied / shared ayah: sura name and ayah number (pre-formatted)
  ///
  /// In ar, this message translates to:
  /// **'[{surah}: {ayah}]'**
  String quranShareRef(String surah, String ayah);

  /// The bundled Quran data failed to load
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل المصحف'**
  String get quranLoadError;

  /// Retry button
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get quranRetry;

  /// Home tab: list of suras
  ///
  /// In ar, this message translates to:
  /// **'السور'**
  String get quranTabSurahs;

  /// Home tab: juz and hizb list
  ///
  /// In ar, this message translates to:
  /// **'الأجزاء'**
  String get quranTabJuz;

  /// Home tab: bookmarks
  ///
  /// In ar, this message translates to:
  /// **'العلامات'**
  String get quranTabBookmarks;

  /// Placeholder of the search entry
  ///
  /// In ar, this message translates to:
  /// **'ابحث في القرآن…'**
  String get quranSearchHint;

  /// Button: jump to a sura / ayah / page
  ///
  /// In ar, this message translates to:
  /// **'انتقال'**
  String get quranGoTo;

  /// Title of the go-to sheet
  ///
  /// In ar, this message translates to:
  /// **'انتقل إلى'**
  String get quranGoToTitle;

  /// Examples under the go-to field (numbers pre-formatted)
  ///
  /// In ar, this message translates to:
  /// **'مثل {a} أو «البقرة {b}» أو «صفحة {c}»'**
  String quranGoToHint(String a, String b, String c);

  /// Go-to found nothing
  ///
  /// In ar, this message translates to:
  /// **'لا نتيجة — جرّب رقم سورة وآية مثل {example}'**
  String quranGoToNone(String example);

  /// Open a go-to result
  ///
  /// In ar, this message translates to:
  /// **'فتح'**
  String get quranGoToOpen;

  /// Empty bookmarks tab title
  ///
  /// In ar, this message translates to:
  /// **'لا علامات بعد'**
  String get quranBookmarksEmptyTitle;

  /// Empty bookmarks tab body
  ///
  /// In ar, this message translates to:
  /// **'المس آية في المصحف ثم اختر «علامة» لتحفظ موضعها.'**
  String get quranBookmarksEmptyBody;

  /// Undo toast after deleting a bookmark
  ///
  /// In ar, this message translates to:
  /// **'حُذفت العلامة'**
  String get quranBookmarkDeleted;

  /// Toast after saving a bookmark
  ///
  /// In ar, this message translates to:
  /// **'حُفظت العلامة'**
  String get quranBookmarkSaved;

  /// Title / action: edit a bookmark
  ///
  /// In ar, this message translates to:
  /// **'تعديل العلامة'**
  String get quranBookmarkEdit;

  /// Title of the new-bookmark sheet
  ///
  /// In ar, this message translates to:
  /// **'علامة جديدة'**
  String get quranBookmarkNew;

  /// Bookmark label field
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get quranBookmarkLabel;

  /// Hint of the bookmark label field
  ///
  /// In ar, this message translates to:
  /// **'مثل: وِرد الفجر'**
  String get quranBookmarkLabelHint;

  /// Bookmark note field
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة'**
  String get quranBookmarkNote;

  /// Bookmark colour field
  ///
  /// In ar, this message translates to:
  /// **'اللون'**
  String get quranBookmarkColor;

  /// Delete a bookmark
  ///
  /// In ar, this message translates to:
  /// **'إزالة العلامة'**
  String get quranBookmarkRemove;

  /// Semantic label: expand a juz into its hizb quarters
  ///
  /// In ar, this message translates to:
  /// **'أرباع الجزء'**
  String get quranJuzQuarters;

  /// Continue-reading card title
  ///
  /// In ar, this message translates to:
  /// **'تابع القراءة'**
  String get quranContinueTitle;

  /// Continue card when nothing was read yet
  ///
  /// In ar, this message translates to:
  /// **'ابدأ رحلتك مع كتاب الله'**
  String get quranContinueEmpty;

  /// Continue card action when nothing was read yet
  ///
  /// In ar, this message translates to:
  /// **'ابدأ بالفاتحة'**
  String get quranContinueStart;

  /// Continue card action
  ///
  /// In ar, this message translates to:
  /// **'تابع'**
  String get quranContinueAction;

  /// When the reader was last open (a formatted date)
  ///
  /// In ar, this message translates to:
  /// **'آخر قراءة {when}'**
  String quranLastReadAt(String when);

  /// Reader layout: mushaf pages
  ///
  /// In ar, this message translates to:
  /// **'المصحف'**
  String get quranModeMushaf;

  /// Reader layout: verse list
  ///
  /// In ar, this message translates to:
  /// **'الآيات'**
  String get quranModeList;

  /// Switch the reader to the verse list
  ///
  /// In ar, this message translates to:
  /// **'عرض الآيات'**
  String get quranShowList;

  /// Switch the reader to mushaf pages
  ///
  /// In ar, this message translates to:
  /// **'عرض المصحف'**
  String get quranShowMushaf;

  /// Reader settings sheet title / button
  ///
  /// In ar, this message translates to:
  /// **'إعدادات القراءة'**
  String get quranSettingsTitle;

  /// Reader settings: layout
  ///
  /// In ar, this message translates to:
  /// **'طريقة العرض'**
  String get quranReaderLayout;

  /// Reader settings: Quran text size
  ///
  /// In ar, this message translates to:
  /// **'حجم الخط'**
  String get quranFontSize;

  /// Increase the Quran text size
  ///
  /// In ar, this message translates to:
  /// **'تكبير الخط'**
  String get quranFontLarger;

  /// Decrease the Quran text size
  ///
  /// In ar, this message translates to:
  /// **'تصغير الخط'**
  String get quranFontSmaller;

  /// Reader settings: colour tajweed rules
  ///
  /// In ar, this message translates to:
  /// **'ألوان التجويد'**
  String get quranTajweedColors;

  /// Reader settings: tajweed section title
  ///
  /// In ar, this message translates to:
  /// **'التجويد'**
  String get quranTajweedSection;

  /// Open the tajweed colour legend
  ///
  /// In ar, this message translates to:
  /// **'دليل الألوان'**
  String get quranTajweedLegend;

  /// Reader settings: where tajweed colours come from
  ///
  /// In ar, this message translates to:
  /// **'مصدر التجويد'**
  String get quranTajweedSource;

  /// Tajweed from the bundled offline data
  ///
  /// In ar, this message translates to:
  /// **'مدمج في التطبيق'**
  String get quranTajweedSourceBundled;

  /// Tajweed from downloaded Quran.com text
  ///
  /// In ar, this message translates to:
  /// **'Quran.com عند تنزيله'**
  String get quranTajweedSourceQuranCom;

  /// Explicit download of the Quran.com tajweed text
  ///
  /// In ar, this message translates to:
  /// **'تنزيل تجويد هذه السورة من Quran.com'**
  String get quranDownloadTajweed;

  /// Reader settings: translation section
  ///
  /// In ar, this message translates to:
  /// **'الترجمة'**
  String get quranTranslation;

  /// Reader settings: translation toggle
  ///
  /// In ar, this message translates to:
  /// **'إظهار الترجمة تحت الآيات'**
  String get quranTranslationShow;

  /// Name of the translation offered
  ///
  /// In ar, this message translates to:
  /// **'الإنجليزية — صحيح إنترناشونال'**
  String get quranTranslationName;

  /// Verse list: translation not on the device
  ///
  /// In ar, this message translates to:
  /// **'ترجمة هذه السورة غير منزّلة بعد'**
  String get quranTranslationMissing;

  /// Button: download the translation of this sura
  ///
  /// In ar, this message translates to:
  /// **'تنزيل الترجمة'**
  String get quranDownloadTranslation;

  /// Explains a download (network only on this tap)
  ///
  /// In ar, this message translates to:
  /// **'يُنزَّل من Quran.com مرة واحدة ويبقى على جهازك.'**
  String get quranDownloadNote;

  /// A download is running
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التنزيل…'**
  String get quranDownloading;

  /// A download is on the device
  ///
  /// In ar, this message translates to:
  /// **'مُنزَّل'**
  String get quranDownloaded;

  /// Download failed: offline
  ///
  /// In ar, this message translates to:
  /// **'لا اتصال بالإنترنت — حاول لاحقًا'**
  String get quranDownloadOffline;

  /// Download failed: server / format
  ///
  /// In ar, this message translates to:
  /// **'تعذّر التنزيل، حاول مرة أخرى'**
  String get quranDownloadFailed;

  /// Button at the end of a sura's verse list
  ///
  /// In ar, this message translates to:
  /// **'التالية: {name}'**
  String quranNextSurah(String name);

  /// Button at the start of a sura's verse list
  ///
  /// In ar, this message translates to:
  /// **'السابقة: {name}'**
  String quranPrevSurah(String name);

  /// Marks the ayah being recited
  ///
  /// In ar, this message translates to:
  /// **'تُتلى الآن'**
  String get quranNowReciting;

  /// Marks a sajdah ayah
  ///
  /// In ar, this message translates to:
  /// **'سجدة تلاوة'**
  String get quranSajdah;

  /// Screen reader label of an ayah
  ///
  /// In ar, this message translates to:
  /// **'الآية {ayah} من سورة {surah}'**
  String quranAyahSemantics(String ayah, String surah);

  /// Ayah action: recite from this ayah
  ///
  /// In ar, this message translates to:
  /// **'استمع من هنا'**
  String get quranActionPlay;

  /// Ayah action: repeat this ayah
  ///
  /// In ar, this message translates to:
  /// **'كرّر الآية'**
  String get quranActionRepeat;

  /// How many times to repeat an ayah (digits localised by the caller)
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{مرة} =2{مرتين} few{{count} مرات} many{{count} مرة} other{{count} مرة}}'**
  String quranRepeatTimes(int count);

  /// Ayah action: bookmark
  ///
  /// In ar, this message translates to:
  /// **'علامة'**
  String get quranActionBookmark;

  /// Ayah action: copy the text
  ///
  /// In ar, this message translates to:
  /// **'نسخ'**
  String get quranActionCopy;

  /// Toast after copying an ayah
  ///
  /// In ar, this message translates to:
  /// **'نُسخت الآية'**
  String get quranCopied;

  /// Ayah action: share the text
  ///
  /// In ar, this message translates to:
  /// **'مشاركة'**
  String get quranActionShare;

  /// Ayah action: add to memorisation
  ///
  /// In ar, this message translates to:
  /// **'أضف إلى الحفظ'**
  String get quranActionHifz;

  /// Toast after adding an ayah to Hifz
  ///
  /// In ar, this message translates to:
  /// **'أُضيفت إلى الحفظ'**
  String get quranHifzAdded;

  /// Ayah action: tafsir
  ///
  /// In ar, this message translates to:
  /// **'التفسير'**
  String get quranActionTafsir;

  /// Tafsir is not available yet
  ///
  /// In ar, this message translates to:
  /// **'التفسير قادم قريبًا بإذن الله'**
  String get quranTafsirSoon;

  /// Badge on a feature that is not ready
  ///
  /// In ar, this message translates to:
  /// **'قريبًا'**
  String get quranSoon;

  /// Search screen title
  ///
  /// In ar, this message translates to:
  /// **'البحث في القرآن'**
  String get quranSearchTitle;

  /// Search field placeholder
  ///
  /// In ar, this message translates to:
  /// **'كلمة أو جزء من آية'**
  String get quranSearchFieldHint;

  /// Explains how the search matches
  ///
  /// In ar, this message translates to:
  /// **'يبحث في النص العربي متجاهلًا التشكيل والهمزات وصور الألف.'**
  String get quranSearchIntro;

  /// Number of ayat found (digits localised by the caller)
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا نتائج} =1{آية واحدة} =2{آيتان} few{{count} آيات} many{{count} آية} other{{count} آية}}'**
  String quranSearchResults(int count);

  /// Number of places the words occur (digits localised by the caller)
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا مواضع} =1{موضع واحد} =2{موضعان} few{{count} مواضع} many{{count} موضعًا} other{{count} موضع}}'**
  String quranSearchOccurrences(int count);

  /// The result list is capped (number pre-formatted)
  ///
  /// In ar, this message translates to:
  /// **'تُعرض أول {count}'**
  String quranSearchShowingFirst(String count);

  /// Search query too short
  ///
  /// In ar, this message translates to:
  /// **'اكتب حرفين على الأقل'**
  String get quranSearchTooShort;

  /// Search found nothing
  ///
  /// In ar, this message translates to:
  /// **'لا توجد آية بهذه الكلمات'**
  String get quranSearchNoResults;

  /// Search index is being built
  ///
  /// In ar, this message translates to:
  /// **'يُجهَّز فهرس البحث…'**
  String get quranSearchPreparing;

  /// Legend sheet title
  ///
  /// In ar, this message translates to:
  /// **'دليل ألوان التجويد'**
  String get quranLegendTitle;

  /// Legend sheet note
  ///
  /// In ar, this message translates to:
  /// **'الألوان عون على التعلّم، والتلقي من قارئ متقن هو الأصل.'**
  String get quranLegendNote;

  /// Credits line in the legend sheet
  ///
  /// In ar, this message translates to:
  /// **'النص القرآني من مشروع تنزيل، وعلامات التجويد من مشروع quran-tajweed (CC BY).'**
  String get quranLegendCredits;

  /// Legend group
  ///
  /// In ar, this message translates to:
  /// **'ما لا يُنطق'**
  String get quranFamilySilent;

  /// Legend group
  ///
  /// In ar, this message translates to:
  /// **'المدود'**
  String get quranFamilyMadd;

  /// Legend group
  ///
  /// In ar, this message translates to:
  /// **'الغنة'**
  String get quranFamilyGhunnah;

  /// Legend group
  ///
  /// In ar, this message translates to:
  /// **'الإدغام بلا غنة'**
  String get quranFamilyMerge;

  /// Legend group
  ///
  /// In ar, this message translates to:
  /// **'القلقلة'**
  String get quranFamilyQalqalah;

  /// Tajweed rule name
  ///
  /// In ar, this message translates to:
  /// **'همزة الوصل'**
  String get quranRuleHamzatWasl;

  /// Tajweed rule: short explanation
  ///
  /// In ar, this message translates to:
  /// **'تُكتب ولا تُنطق عند وصل الكلام'**
  String get quranRuleHamzatWaslHint;

  /// Tajweed rule name
  ///
  /// In ar, this message translates to:
  /// **'اللام الشمسية'**
  String get quranRuleLamShamsiyyah;

  /// Tajweed rule: short explanation
  ///
  /// In ar, this message translates to:
  /// **'لام «ال» لا تُنطق قبل الحرف الشمسي'**
  String get quranRuleLamShamsiyyahHint;

  /// Tajweed rule name
  ///
  /// In ar, this message translates to:
  /// **'حرف لا يُنطق'**
  String get quranRuleSilent;

  /// Tajweed rule: short explanation
  ///
  /// In ar, this message translates to:
  /// **'يُكتب ولا يُقرأ'**
  String get quranRuleSilentHint;

  /// Tajweed rule name
  ///
  /// In ar, this message translates to:
  /// **'مد طبيعي'**
  String get quranRuleMaddNatural;

  /// Tajweed rule: short explanation
  ///
  /// In ar, this message translates to:
  /// **'حركتان'**
  String get quranRuleMaddNaturalHint;

  /// Tajweed rule name
  ///
  /// In ar, this message translates to:
  /// **'مد عارض أو لين'**
  String get quranRuleMaddPermissible;

  /// Tajweed rule: short explanation
  ///
  /// In ar, this message translates to:
  /// **'حركتان أو أربع أو ست عند الوقف'**
  String get quranRuleMaddPermissibleHint;

  /// Tajweed rule name
  ///
  /// In ar, this message translates to:
  /// **'مد جائز منفصل'**
  String get quranRuleMaddSeparated;

  /// Tajweed rule: short explanation
  ///
  /// In ar, this message translates to:
  /// **'أربع أو خمس حركات'**
  String get quranRuleMaddSeparatedHint;

  /// Tajweed rule name
  ///
  /// In ar, this message translates to:
  /// **'مد واجب متصل'**
  String get quranRuleMaddConnected;

  /// Tajweed rule: short explanation
  ///
  /// In ar, this message translates to:
  /// **'أربع أو خمس حركات'**
  String get quranRuleMaddConnectedHint;

  /// Tajweed rule name
  ///
  /// In ar, this message translates to:
  /// **'مد لازم'**
  String get quranRuleMaddNecessary;

  /// Tajweed rule: short explanation
  ///
  /// In ar, this message translates to:
  /// **'ست حركات'**
  String get quranRuleMaddNecessaryHint;

  /// Tajweed rule name
  ///
  /// In ar, this message translates to:
  /// **'قلقلة'**
  String get quranRuleQalqalah;

  /// Tajweed rule: short explanation
  ///
  /// In ar, this message translates to:
  /// **'اضطراب الصوت في حروف «قطب جد» الساكنة'**
  String get quranRuleQalqalahHint;

  /// Tajweed rule name
  ///
  /// In ar, this message translates to:
  /// **'غنة'**
  String get quranRuleGhunnah;

  /// Tajweed rule: short explanation
  ///
  /// In ar, this message translates to:
  /// **'النون والميم المشددتان بغنة حركتين'**
  String get quranRuleGhunnahHint;

  /// Tajweed rule name
  ///
  /// In ar, this message translates to:
  /// **'إخفاء'**
  String get quranRuleIkhfa;

  /// Tajweed rule: short explanation
  ///
  /// In ar, this message translates to:
  /// **'إخفاء النون الساكنة والتنوين مع الغنة'**
  String get quranRuleIkhfaHint;

  /// Tajweed rule name
  ///
  /// In ar, this message translates to:
  /// **'إخفاء شفوي'**
  String get quranRuleIkhfaShafawi;

  /// Tajweed rule: short explanation
  ///
  /// In ar, this message translates to:
  /// **'الميم الساكنة قبل الباء'**
  String get quranRuleIkhfaShafawiHint;

  /// Tajweed rule name
  ///
  /// In ar, this message translates to:
  /// **'إقلاب'**
  String get quranRuleIqlab;

  /// Tajweed rule: short explanation
  ///
  /// In ar, this message translates to:
  /// **'النون الساكنة والتنوين تُقلب ميمًا قبل الباء'**
  String get quranRuleIqlabHint;

  /// Tajweed rule name
  ///
  /// In ar, this message translates to:
  /// **'إدغام بغنة'**
  String get quranRuleIdghamGhunnah;

  /// Tajweed rule: short explanation
  ///
  /// In ar, this message translates to:
  /// **'في حروف «ينمو»'**
  String get quranRuleIdghamGhunnahHint;

  /// Tajweed rule name
  ///
  /// In ar, this message translates to:
  /// **'إدغام شفوي'**
  String get quranRuleIdghamShafawi;

  /// Tajweed rule: short explanation
  ///
  /// In ar, this message translates to:
  /// **'الميم الساكنة في الميم'**
  String get quranRuleIdghamShafawiHint;

  /// Tajweed rule name
  ///
  /// In ar, this message translates to:
  /// **'إدغام بلا غنة'**
  String get quranRuleIdghamNoGhunnah;

  /// Tajweed rule: short explanation
  ///
  /// In ar, this message translates to:
  /// **'في اللام والراء'**
  String get quranRuleIdghamNoGhunnahHint;

  /// Tajweed rule name
  ///
  /// In ar, this message translates to:
  /// **'إدغام متجانسين'**
  String get quranRuleIdghamMutajanisayn;

  /// Tajweed rule: short explanation
  ///
  /// In ar, this message translates to:
  /// **'حرفان اتفقا مخرجًا واختلفا صفة'**
  String get quranRuleIdghamMutajanisaynHint;

  /// Tajweed rule name
  ///
  /// In ar, this message translates to:
  /// **'إدغام متقاربين'**
  String get quranRuleIdghamMutaqaribayn;

  /// Tajweed rule: short explanation
  ///
  /// In ar, this message translates to:
  /// **'حرفان تقاربا مخرجًا'**
  String get quranRuleIdghamMutaqaribaynHint;

  /// Recitation settings: screen title
  ///
  /// In ar, this message translates to:
  /// **'التلاوة'**
  String get recitationTitle;

  /// Android notification channel of the recitation player
  ///
  /// In ar, this message translates to:
  /// **'تلاوة القرآن'**
  String get recitationChannelName;

  /// Media notification: album line
  ///
  /// In ar, this message translates to:
  /// **'القرآن الكريم'**
  String get recitationAlbum;

  /// Label above the chosen reciter
  ///
  /// In ar, this message translates to:
  /// **'القارئ'**
  String get recitationReciterLabel;

  /// Settings section: reciters
  ///
  /// In ar, this message translates to:
  /// **'القرّاء'**
  String get recitationSectionReciters;

  /// Reciters section subtitle
  ///
  /// In ar, this message translates to:
  /// **'أصوات قرّاء حقيقيين من everyayah.com – لا أصوات مولَّدة للقرآن أبدًا'**
  String get recitationSectionRecitersHint;

  /// Recitation style: mujawwad
  ///
  /// In ar, this message translates to:
  /// **'مجوَّد'**
  String get recitationStyleMujawwad;

  /// Recitation style: murattal
  ///
  /// In ar, this message translates to:
  /// **'مرتَّل'**
  String get recitationStyleMurattal;

  /// Recitation style: the teaching recitation
  ///
  /// In ar, this message translates to:
  /// **'معلِّم'**
  String get recitationStyleMuallim;

  /// Style explanation: mujawwad
  ///
  /// In ar, this message translates to:
  /// **'تلاوة متأنّية منغَّمة بأحكام التجويد كاملة'**
  String get recitationStyleMujawwadHint;

  /// Style explanation: murattal
  ///
  /// In ar, this message translates to:
  /// **'ترتيل متّصل هادئ'**
  String get recitationStyleMurattalHint;

  /// Style explanation: muallim
  ///
  /// In ar, this message translates to:
  /// **'تلاوة تعليمية واضحة للحفظ'**
  String get recitationStyleMuallimHint;

  /// Audio quality of a reciter's files
  ///
  /// In ar, this message translates to:
  /// **'{kbps} كيلوبت/ث'**
  String recitationBitrate(String kbps);

  /// Button: play a short sample of the reciter
  ///
  /// In ar, this message translates to:
  /// **'استمع إلى عيّنة'**
  String get recitationSample;

  /// Button: stop the sample
  ///
  /// In ar, this message translates to:
  /// **'إيقاف العيّنة'**
  String get recitationSampleStop;

  /// Screen reader: sample button of a reciter
  ///
  /// In ar, this message translates to:
  /// **'عيّنة من تلاوة {name}'**
  String recitationSampleOf(String name);

  /// Screen reader: the selected reciter
  ///
  /// In ar, this message translates to:
  /// **'القارئ المختار'**
  String get recitationChosen;

  /// Screen reader: choose a reciter
  ///
  /// In ar, this message translates to:
  /// **'اختيار {name}'**
  String recitationChoose(String name);

  /// How many surahs of a reciter are on the phone
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا سور محمّلة} =1{سورة واحدة محمّلة} =2{سورتان محمّلتان} few{{count} سور محمّلة} many{{count} سورة محمّلة} other{{count} سورة محمّلة}}'**
  String recitationSurahsDownloaded(int count);

  /// All 114 surahs of a reciter are downloaded
  ///
  /// In ar, this message translates to:
  /// **'المصحف كاملًا محمّل'**
  String get recitationWholeMushafDownloaded;

  /// Settings section: repeats and playback
  ///
  /// In ar, this message translates to:
  /// **'التكرار والتشغيل'**
  String get recitationSectionPlayback;

  /// Playback section subtitle
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات الافتراضية لكل تلاوة جديدة'**
  String get recitationSectionPlaybackHint;

  /// Setting: times each ayah is recited
  ///
  /// In ar, this message translates to:
  /// **'تكرار كل آية'**
  String get recitationRepeatAyah;

  /// Setting: passes over the whole range
  ///
  /// In ar, this message translates to:
  /// **'تكرار المقطع'**
  String get recitationRepeatRange;

  /// A repeat count
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{مرة واحدة} =2{مرتان} few{{count} مرات} many{{count} مرة} other{{count} مرة}}'**
  String recitationTimes(int count);

  /// Repeat the passage until stopped
  ///
  /// In ar, this message translates to:
  /// **'بلا توقّف'**
  String get recitationEndless;

  /// Setting: silence after each ayah (to repeat after the reciter)
  ///
  /// In ar, this message translates to:
  /// **'مهلة بعد كل تلاوة'**
  String get recitationGap;

  /// Gap setting explanation
  ///
  /// In ar, this message translates to:
  /// **'وقت لتردّد الآية بعد القارئ'**
  String get recitationGapHint;

  /// No gap
  ///
  /// In ar, this message translates to:
  /// **'بلا مهلة'**
  String get recitationGapNone;

  /// A number of seconds
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{ثانية} =2{ثانيتان} few{{count} ثوانٍ} many{{count} ثانية} other{{count} ثانية}}'**
  String recitationSeconds(int count);

  /// Setting: playback speed
  ///
  /// In ar, this message translates to:
  /// **'السرعة'**
  String get recitationSpeed;

  /// A playback speed like 1.25×
  ///
  /// In ar, this message translates to:
  /// **'{value}×'**
  String recitationSpeedValue(String value);

  /// Setting: play the basmala before ayah 1
  ///
  /// In ar, this message translates to:
  /// **'البسملة قبل السور'**
  String get recitationBasmala;

  /// Basmala setting explanation
  ///
  /// In ar, this message translates to:
  /// **'كما في المصحف – عدا الفاتحة (البسملة آيتها الأولى) والتوبة'**
  String get recitationBasmalaHint;

  /// Settings section: downloads
  ///
  /// In ar, this message translates to:
  /// **'الاستماع دون اتصال'**
  String get recitationSectionDownloads;

  /// Downloads section subtitle
  ///
  /// In ar, this message translates to:
  /// **'لا يبدأ أي تنزيل إلا حين تطلبه'**
  String get recitationSectionDownloadsHint;

  /// Total size of downloads
  ///
  /// In ar, this message translates to:
  /// **'المساحة المستخدمة: {size}'**
  String recitationStorageUsed(String size);

  /// Setting: downloads only on Wi-Fi
  ///
  /// In ar, this message translates to:
  /// **'التنزيل عبر Wi-Fi فقط'**
  String get recitationWifiOnly;

  /// Wi-Fi only explanation
  ///
  /// In ar, this message translates to:
  /// **'يتوقف التنزيل حين لا تكون على شبكة Wi-Fi'**
  String get recitationWifiOnlyHint;

  /// Download card title
  ///
  /// In ar, this message translates to:
  /// **'المصحف كاملًا بصوت {name}'**
  String recitationMushafFor(String name);

  /// Estimated download size
  ///
  /// In ar, this message translates to:
  /// **'نحو {size}'**
  String recitationAbout(String size);

  /// Button: download all 114 surahs
  ///
  /// In ar, this message translates to:
  /// **'تنزيل المصحف'**
  String get recitationDownloadMushaf;

  /// Button: open the per-surah download list
  ///
  /// In ar, this message translates to:
  /// **'اختيار السور'**
  String get recitationChooseSurahs;

  /// Download progress in surahs
  ///
  /// In ar, this message translates to:
  /// **'{done} من {total} سورة'**
  String recitationSurahProgress(String done, String total);

  /// Download progress in files
  ///
  /// In ar, this message translates to:
  /// **'{done} من {total} ملف'**
  String recitationFilesProgress(String done, String total);

  /// Button: pause downloads
  ///
  /// In ar, this message translates to:
  /// **'إيقاف مؤقت'**
  String get recitationPauseDownloads;

  /// Button: resume downloads
  ///
  /// In ar, this message translates to:
  /// **'استئناف'**
  String get recitationResumeDownloads;

  /// Button: cancel and remove a download
  ///
  /// In ar, this message translates to:
  /// **'إلغاء التنزيل'**
  String get recitationCancelDownload;

  /// Button: delete downloaded files
  ///
  /// In ar, this message translates to:
  /// **'حذف التنزيلات'**
  String get recitationDeleteDownloads;

  /// Delete confirmation title
  ///
  /// In ar, this message translates to:
  /// **'حذف تلاوة {name} من الهاتف؟'**
  String recitationDeleteConfirm(String name);

  /// Delete confirmation body
  ///
  /// In ar, this message translates to:
  /// **'تُحذف {size}. يمكنك تنزيلها مرة أخرى متى شئت.'**
  String recitationDeleteConfirmHint(String size);

  /// Delete one surah confirmation
  ///
  /// In ar, this message translates to:
  /// **'حذف سورة {surah}؟'**
  String recitationDeleteSurahConfirm(String surah);

  /// Heading: downloads of reciters not currently chosen
  ///
  /// In ar, this message translates to:
  /// **'تنزيلات قرّاء آخرين'**
  String get recitationOtherDownloads;

  /// Per-surah downloads screen title
  ///
  /// In ar, this message translates to:
  /// **'تنزيلات {name}'**
  String recitationDownloadsTitle(String name);

  /// Number of ayat in a surah
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{آية واحدة} =2{آيتان} few{{count} آيات} many{{count} آية} other{{count} آية}}'**
  String recitationAyatCount(int count);

  /// Button: download one surah
  ///
  /// In ar, this message translates to:
  /// **'تنزيل السورة'**
  String get recitationDownloadSurah;

  /// Download status
  ///
  /// In ar, this message translates to:
  /// **'في الانتظار'**
  String get recitationStatusQueued;

  /// Download status
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التنزيل'**
  String get recitationStatusDownloading;

  /// Download status
  ///
  /// In ar, this message translates to:
  /// **'متوقّف مؤقتًا'**
  String get recitationStatusPaused;

  /// Download status: Wi-Fi only and not on Wi-Fi
  ///
  /// In ar, this message translates to:
  /// **'بانتظار Wi-Fi'**
  String get recitationStatusWifi;

  /// Download status
  ///
  /// In ar, this message translates to:
  /// **'تعذّر التنزيل'**
  String get recitationStatusFailed;

  /// Download status: complete
  ///
  /// In ar, this message translates to:
  /// **'محمّلة'**
  String get recitationStatusComplete;

  /// Download error: network
  ///
  /// In ar, this message translates to:
  /// **'تحقّق من الاتصال ثم استأنف'**
  String get recitationErrorNetwork;

  /// Download error: 404
  ///
  /// In ar, this message translates to:
  /// **'الملف غير متوفر لدى المصدر'**
  String get recitationErrorNotFound;

  /// Download error: storage
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مساحة كافية على الهاتف'**
  String get recitationErrorStorage;

  /// A size in megabytes
  ///
  /// In ar, this message translates to:
  /// **'{size} ميغابايت'**
  String recitationSizeMb(String size);

  /// A size in gigabytes
  ///
  /// In ar, this message translates to:
  /// **'{size} غيغابايت'**
  String recitationSizeGb(String size);

  /// A size in kilobytes
  ///
  /// In ar, this message translates to:
  /// **'{size} كيلوبايت'**
  String recitationSizeKb(String size);

  /// Credit line under the downloads section
  ///
  /// In ar, this message translates to:
  /// **'التلاوات من everyayah.com – تُبثّ عند التشغيل أو تُنزَّل بطلبك'**
  String get recitationSourceCredit;

  /// Fallback surah name
  ///
  /// In ar, this message translates to:
  /// **'سورة {number}'**
  String recitationSurahNumber(String number);

  /// Media title: surah and ayah
  ///
  /// In ar, this message translates to:
  /// **'{surah}، الآية {ayah}'**
  String recitationTitleAyah(String surah, String ayah);

  /// Media title: the basmala before a surah
  ///
  /// In ar, this message translates to:
  /// **'{surah}، البسملة'**
  String recitationTitleBasmala(String surah);

  /// The ayah being recited
  ///
  /// In ar, this message translates to:
  /// **'الآية {ayah}'**
  String recitationAyahNumber(String ayah);

  /// The basmala is being recited
  ///
  /// In ar, this message translates to:
  /// **'البسملة'**
  String get recitationBasmalaNow;

  /// Full player: title
  ///
  /// In ar, this message translates to:
  /// **'يُتلى الآن'**
  String get recitationNowPlaying;

  /// Player button
  ///
  /// In ar, this message translates to:
  /// **'تشغيل'**
  String get recitationPlay;

  /// Player button
  ///
  /// In ar, this message translates to:
  /// **'إيقاف مؤقت'**
  String get recitationPause;

  /// Player button
  ///
  /// In ar, this message translates to:
  /// **'الآية التالية'**
  String get recitationNextAyah;

  /// Player button
  ///
  /// In ar, this message translates to:
  /// **'الآية السابقة'**
  String get recitationPreviousAyah;

  /// Player button
  ///
  /// In ar, this message translates to:
  /// **'إيقاف التلاوة'**
  String get recitationStop;

  /// Screen reader: mini player opens the full player
  ///
  /// In ar, this message translates to:
  /// **'فتح المشغّل'**
  String get recitationOpenPlayer;

  /// Player status
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التحميل…'**
  String get recitationLoading;

  /// Player status: paused because the adhan started
  ///
  /// In ar, this message translates to:
  /// **'توقّفت للأذان – اضغط للمتابعة'**
  String get recitationPausedPrayer;

  /// Player status: another app took the audio
  ///
  /// In ar, this message translates to:
  /// **'متوقّفة مؤقتًا'**
  String get recitationPausedInterruption;

  /// Player status
  ///
  /// In ar, this message translates to:
  /// **'توقّفت بعد فصل السمّاعات'**
  String get recitationPausedNoisy;

  /// Player status
  ///
  /// In ar, this message translates to:
  /// **'انتهى مؤقّت النوم'**
  String get recitationPausedSleep;

  /// Player error: network
  ///
  /// In ar, this message translates to:
  /// **'لا اتصال – نزّل السورة للاستماع دون اتصال'**
  String get recitationPlaybackNetwork;

  /// Player error: 404
  ///
  /// In ar, this message translates to:
  /// **'هذه الآية غير متوفرة لهذا القارئ'**
  String get recitationPlaybackNotFound;

  /// Player error
  ///
  /// In ar, this message translates to:
  /// **'تعذّر التشغيل'**
  String get recitationPlaybackFailed;

  /// Player button after an error
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get recitationRetry;

  /// Chip: playing from downloaded files
  ///
  /// In ar, this message translates to:
  /// **'من التنزيلات'**
  String get recitationOffline;

  /// Chip: streaming from the internet
  ///
  /// In ar, this message translates to:
  /// **'بثّ'**
  String get recitationStreaming;

  /// Which repetition of the ayah
  ///
  /// In ar, this message translates to:
  /// **'التكرار {pass} من {total}'**
  String recitationAyahPass(String pass, String total);

  /// Which pass over the passage
  ///
  /// In ar, this message translates to:
  /// **'الدورة {pass} من {total}'**
  String recitationRangePass(String pass, String total);

  /// Which pass over an endless passage
  ///
  /// In ar, this message translates to:
  /// **'الدورة {pass}'**
  String recitationRangePassEndless(String pass);

  /// Full player: repeat control label for each ayah
  ///
  /// In ar, this message translates to:
  /// **'الآية'**
  String get recitationRepeatAyahShort;

  /// Full player: repeat control label for the passage
  ///
  /// In ar, this message translates to:
  /// **'المقطع'**
  String get recitationRepeatRangeShort;

  /// Stepper: increase
  ///
  /// In ar, this message translates to:
  /// **'زيادة'**
  String get recitationMore;

  /// Stepper: decrease
  ///
  /// In ar, this message translates to:
  /// **'إنقاص'**
  String get recitationLess;

  /// Full player: sleep timer
  ///
  /// In ar, this message translates to:
  /// **'مؤقّت النوم'**
  String get recitationSleepTimer;

  /// Sleep timer off
  ///
  /// In ar, this message translates to:
  /// **'بلا'**
  String get recitationSleepOff;

  /// Sleep timer: stop after the current ayah
  ///
  /// In ar, this message translates to:
  /// **'بعد هذه الآية'**
  String get recitationSleepAfterAyah;

  /// Sleep timer minutes
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{دقيقة} =2{دقيقتان} few{{count} دقائق} many{{count} دقيقة} other{{count} دقيقة}}'**
  String recitationMinutes(int count);

  /// Sleep timer running
  ///
  /// In ar, this message translates to:
  /// **'يتوقف {time}'**
  String recitationSleepUntil(String time);

  /// Full player: open the reciter picker
  ///
  /// In ar, this message translates to:
  /// **'تغيير القارئ'**
  String get recitationChangeReciter;

  /// Screen reader: progress ring
  ///
  /// In ar, this message translates to:
  /// **'{percent} من المقطع'**
  String recitationProgress(String percent);

  /// The queued range
  ///
  /// In ar, this message translates to:
  /// **'من {from} إلى {to}'**
  String recitationRangeLabel(String from, String to);

  /// The queued range inside one surah (e.g. الملك ١–٣٠); numbers pre-formatted
  ///
  /// In ar, this message translates to:
  /// **'{surah} {from}–{to}'**
  String recitationRangeInSurah(String surah, String from, String to);

  /// Full player: background playback unavailable
  ///
  /// In ar, this message translates to:
  /// **'يعمل ما دام مَدار مفتوحًا'**
  String get recitationBackgroundOff;

  /// List separator (Arabic comma: a middle dot reads as the digit zero ٠)
  ///
  /// In ar, this message translates to:
  /// **'، '**
  String get wirdSep;

  /// Wird screen title
  ///
  /// In ar, this message translates to:
  /// **'الوِرد اليومي'**
  String get wirdTitle;

  /// Card / section: today's portion
  ///
  /// In ar, this message translates to:
  /// **'وِرد اليوم'**
  String get wirdTodayTitle;

  /// Button: open the reader at today's portion
  ///
  /// In ar, this message translates to:
  /// **'اقرأ الآن'**
  String get wirdReadNow;

  /// Button: open the reader where the user stopped
  ///
  /// In ar, this message translates to:
  /// **'أكمِل القراءة'**
  String get wirdContinue;

  /// Button: record today's portion as read
  ///
  /// In ar, this message translates to:
  /// **'أتممتُه'**
  String get wirdMarkDone;

  /// Button: record partial reading
  ///
  /// In ar, this message translates to:
  /// **'توقّفتُ عند…'**
  String get wirdStoppedAt;

  /// Sheet title: partial reading
  ///
  /// In ar, this message translates to:
  /// **'أين توقّفت؟'**
  String get wirdStoppedAtTitle;

  /// Sheet subtitle: partial reading
  ///
  /// In ar, this message translates to:
  /// **'حرّك المؤشّر إلى آخر آية قرأتها'**
  String get wirdStoppedAtHint;

  /// Sheet button: save partial reading
  ///
  /// In ar, this message translates to:
  /// **'سجّل'**
  String get wirdSaveProgress;

  /// Toast after marking done
  ///
  /// In ar, this message translates to:
  /// **'سُجّل وِرد اليوم، تقبّل الله'**
  String get wirdDoneToast;

  /// Toast after partial reading
  ///
  /// In ar, this message translates to:
  /// **'سُجّلت قراءتك حتى {ayah}'**
  String wirdPartialToast(String ayah);

  /// Status: today's portion read
  ///
  /// In ar, this message translates to:
  /// **'أتممتَ وِرد اليوم، تقبّل الله منك'**
  String get wirdMetToday;

  /// Status: ahead, nothing owed
  ///
  /// In ar, this message translates to:
  /// **'لا شيء عليك اليوم، فأنت متقدّم على خطّتك'**
  String get wirdRestToday;

  /// Status: plan paused
  ///
  /// In ar, this message translates to:
  /// **'الخطة متوقّفة مؤقتًا'**
  String get wirdPausedNote;

  /// Status: plan starts later
  ///
  /// In ar, this message translates to:
  /// **'تبدأ الخطة {date}'**
  String wirdNotStarted(String date);

  /// Status: khatma finished
  ///
  /// In ar, this message translates to:
  /// **'ختمتَ القرآن، تقبّل الله منك'**
  String get wirdKhatmaDone;

  /// Status: behind, spread
  ///
  /// In ar, this message translates to:
  /// **'متأخّر بمقدار {amount}، ووُزِّع على الأيام القادمة'**
  String wirdBehindSpread(String amount);

  /// Status: behind, all today
  ///
  /// In ar, this message translates to:
  /// **'متأخّر بمقدار {amount}، وأُضيف إلى وِرد اليوم'**
  String wirdBehindAll(String amount);

  /// Status: ahead
  ///
  /// In ar, this message translates to:
  /// **'متقدّم بمقدار {amount}، أحسنت'**
  String wirdAhead(String amount);

  /// Short status: behind
  ///
  /// In ar, this message translates to:
  /// **'متأخّر {amount}'**
  String wirdBehindShort(String amount);

  /// Short status: ahead
  ///
  /// In ar, this message translates to:
  /// **'متقدّم {amount}'**
  String wirdAheadShort(String amount);

  /// Plan tile: today's portion
  ///
  /// In ar, this message translates to:
  /// **'اليوم: {range}'**
  String wirdTodayLine(String range);

  /// Plan tile: where an open-ended plan stands
  ///
  /// In ar, this message translates to:
  /// **'عند ص {page}'**
  String wirdPagePosition(String page);

  /// Status: remaining today
  ///
  /// In ar, this message translates to:
  /// **'بقي {amount}'**
  String wirdLeftToday(String amount);

  /// An ayah: surah name and ayah number
  ///
  /// In ar, this message translates to:
  /// **'{surah} {ayah}'**
  String wirdAyahRef(String surah, String ayah);

  /// Ayah range inside one surah
  ///
  /// In ar, this message translates to:
  /// **'{surah} {from}–{to}'**
  String wirdRangeSameSurah(String surah, String from, String to);

  /// Ayah range across surahs
  ///
  /// In ar, this message translates to:
  /// **'{from} – {to}'**
  String wirdRangeCross(String from, String to);

  /// Mushaf page range
  ///
  /// In ar, this message translates to:
  /// **'ص {from}–{to}'**
  String wirdPageRange(String from, String to);

  /// One mushaf page
  ///
  /// In ar, this message translates to:
  /// **'ص {page}'**
  String wirdPageSingle(String page);

  /// Whole pages
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا صفحات} =1{صفحة واحدة} =2{صفحتان} few{{count} صفحات} many{{count} صفحة} other{{count} صفحة}}'**
  String wirdUnitPages(int count);

  /// Whole juz
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا أجزاء} =1{جزء واحد} =2{جزآن} few{{count} أجزاء} many{{count} جزءًا} other{{count} جزء}}'**
  String wirdUnitJuz(int count);

  /// Whole hizb
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا أحزاب} =1{حزب واحد} =2{حزبان} few{{count} أحزاب} many{{count} حزبًا} other{{count} حزب}}'**
  String wirdUnitHizb(int count);

  /// Ayat count
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا آيات} =1{آية واحدة} =2{آيتان} few{{count} آيات} many{{count} آية} other{{count} آية}}'**
  String wirdUnitAyat(int count);

  /// Fractional pages, e.g. 20.1
  ///
  /// In ar, this message translates to:
  /// **'{amount} صفحة'**
  String wirdUnitPagesDecimal(String amount);

  /// Fractional juz
  ///
  /// In ar, this message translates to:
  /// **'{amount} جزء'**
  String wirdUnitJuzDecimal(String amount);

  /// Fractional hizb
  ///
  /// In ar, this message translates to:
  /// **'{amount} حزب'**
  String wirdUnitHizbDecimal(String amount);

  /// A number of days
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا أيام} =1{يوم واحد} =2{يومان} few{{count} أيام} many{{count} يومًا} other{{count} يوم}}'**
  String wirdDays(int count);

  /// Plan type: finish the Quran in N days
  ///
  /// In ar, this message translates to:
  /// **'ختمة'**
  String get wirdTemplateKhatma;

  /// Plan type: N pages a day
  ///
  /// In ar, this message translates to:
  /// **'صفحات'**
  String get wirdTemplatePages;

  /// Plan type: N juz a day
  ///
  /// In ar, this message translates to:
  /// **'أجزاء'**
  String get wirdTemplateJuz;

  /// Plan type: N hizb a day
  ///
  /// In ar, this message translates to:
  /// **'أحزاب'**
  String get wirdTemplateHizb;

  /// Plan type: N ayat a day
  ///
  /// In ar, this message translates to:
  /// **'آيات'**
  String get wirdTemplateAyat;

  /// Plan summary line (khatma)
  ///
  /// In ar, this message translates to:
  /// **'ختمة في {days}، {amount} يوميًا'**
  String wirdSummaryKhatma(String days, String amount);

  /// Plan summary line (daily amount)
  ///
  /// In ar, this message translates to:
  /// **'{amount} يوميًا'**
  String wirdSummaryDaily(String amount);

  /// Default plan name (khatma)
  ///
  /// In ar, this message translates to:
  /// **'ختمة في {days}'**
  String wirdDefaultNameKhatma(String days);

  /// Default plan name (daily amount)
  ///
  /// In ar, this message translates to:
  /// **'{amount} كل يوم'**
  String wirdDefaultNameDaily(String amount);

  /// Plan window: after a prayer
  ///
  /// In ar, this message translates to:
  /// **'بعد {prayer}'**
  String wirdWindowAfter(String prayer);

  /// Plan window: duha
  ///
  /// In ar, this message translates to:
  /// **'وقت الضحى'**
  String get wirdWindowDuha;

  /// Plan window: none
  ///
  /// In ar, this message translates to:
  /// **'أي وقت'**
  String get wirdWindowAnytime;

  /// Section: the plans list
  ///
  /// In ar, this message translates to:
  /// **'خططي'**
  String get wirdPlansTitle;

  /// Button: add a plan
  ///
  /// In ar, this message translates to:
  /// **'خطة جديدة'**
  String get wirdAddPlan;

  /// Badge: the primary plan
  ///
  /// In ar, this message translates to:
  /// **'الأساسية'**
  String get wirdPrimary;

  /// Action: make a plan primary
  ///
  /// In ar, this message translates to:
  /// **'اجعلها الأساسية'**
  String get wirdMakePrimary;

  /// Action: pause a plan
  ///
  /// In ar, this message translates to:
  /// **'إيقاف مؤقت'**
  String get wirdPause;

  /// Action: resume a plan
  ///
  /// In ar, this message translates to:
  /// **'استئناف'**
  String get wirdResume;

  /// Badge: paused plan
  ///
  /// In ar, this message translates to:
  /// **'متوقّفة'**
  String get wirdPaused;

  /// Action: edit a plan
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get wirdEdit;

  /// Action: delete a plan
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get wirdDelete;

  /// Undo toast: plan deleted
  ///
  /// In ar, this message translates to:
  /// **'حُذفت الخطة'**
  String get wirdDeletedToast;

  /// Undo toast: plan paused
  ///
  /// In ar, this message translates to:
  /// **'أُوقفت الخطة مؤقتًا'**
  String get wirdPausedToast;

  /// Undo toast: plan resumed
  ///
  /// In ar, this message translates to:
  /// **'استُؤنفت الخطة'**
  String get wirdResumedToast;

  /// Undo toast: primary changed
  ///
  /// In ar, this message translates to:
  /// **'صارت «{name}» خطّتك الأساسية'**
  String wirdPrimaryToast(String name);

  /// Undo toast: plan edited
  ///
  /// In ar, this message translates to:
  /// **'حُفظت الخطة'**
  String get wirdSavedToast;

  /// Undo toast: plan created
  ///
  /// In ar, this message translates to:
  /// **'بدأت خطة «{name}»، يسّر الله لك'**
  String wirdCreatedToast(String name);

  /// Empty state title
  ///
  /// In ar, this message translates to:
  /// **'لا خطة وِرد بعد'**
  String get wirdEmptyTitle;

  /// Empty state body
  ///
  /// In ar, this message translates to:
  /// **'اختر ختمة في ثلاثين يومًا أو قدرًا يوميًا يناسبك، ونذكّرك به بعد الصلاة.'**
  String get wirdEmptyBody;

  /// Empty state button
  ///
  /// In ar, this message translates to:
  /// **'ابدأ خطة'**
  String get wirdEmptyAction;

  /// Stat label: streak
  ///
  /// In ar, this message translates to:
  /// **'السلسلة'**
  String get wirdStreak;

  /// Stat caption: best streak
  ///
  /// In ar, this message translates to:
  /// **'الأطول: {days}'**
  String wirdBestStreak(String days);

  /// Stat label: projected finish
  ///
  /// In ar, this message translates to:
  /// **'الختم المتوقّع'**
  String get wirdFinish;

  /// Stat caption: khatma target date
  ///
  /// In ar, this message translates to:
  /// **'الموعد {date}'**
  String wirdTargetDate(String date);

  /// Stat label: overall progress
  ///
  /// In ar, this message translates to:
  /// **'التقدّم'**
  String get wirdProgress;

  /// Stat caption: khatmas finished
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لم تُختم بعد} =1{ختمة واحدة} =2{ختمتان} few{{count} ختمات} many{{count} ختمة} other{{count} ختمة}}'**
  String wirdKhatmas(int count);

  /// Stat value: no projection
  ///
  /// In ar, this message translates to:
  /// **'لم يتّضح بعد'**
  String get wirdNoProjection;

  /// Progress ring value
  ///
  /// In ar, this message translates to:
  /// **'{done} من {quota}'**
  String wirdProgressOf(String done, String quota);

  /// Ring caption under the number read
  ///
  /// In ar, this message translates to:
  /// **'من {quota}'**
  String wirdProgressOfShort(String quota);

  /// Section: history calendar
  ///
  /// In ar, this message translates to:
  /// **'السجلّ'**
  String get wirdHistoryTitle;

  /// Calendar legend: met
  ///
  /// In ar, this message translates to:
  /// **'أُتمّ'**
  String get wirdLegendMet;

  /// Calendar legend: partial
  ///
  /// In ar, this message translates to:
  /// **'بعضه'**
  String get wirdLegendPartial;

  /// Calendar legend: missed
  ///
  /// In ar, this message translates to:
  /// **'فات'**
  String get wirdLegendMissed;

  /// Calendar legend: rest
  ///
  /// In ar, this message translates to:
  /// **'لا شيء عليه'**
  String get wirdLegendRest;

  /// Calendar legend: paused
  ///
  /// In ar, this message translates to:
  /// **'متوقّف'**
  String get wirdLegendPaused;

  /// Calendar button
  ///
  /// In ar, this message translates to:
  /// **'الشهر السابق'**
  String get wirdPrevMonth;

  /// Calendar button
  ///
  /// In ar, this message translates to:
  /// **'الشهر التالي'**
  String get wirdNextMonth;

  /// Plan sheet title (new)
  ///
  /// In ar, this message translates to:
  /// **'خطة وِرد جديدة'**
  String get wirdNewPlanTitle;

  /// Plan sheet title (edit)
  ///
  /// In ar, this message translates to:
  /// **'تعديل الخطة'**
  String get wirdEditPlanTitle;

  /// Plan sheet subtitle
  ///
  /// In ar, this message translates to:
  /// **'قليلٌ دائم خيرٌ من كثيرٍ منقطع'**
  String get wirdPlanSheetSubtitle;

  /// Plan field
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get wirdFieldName;

  /// Plan field
  ///
  /// In ar, this message translates to:
  /// **'نوع الخطة'**
  String get wirdFieldType;

  /// Plan field: khatma length
  ///
  /// In ar, this message translates to:
  /// **'المدّة'**
  String get wirdFieldDays;

  /// Choice: custom duration / amount
  ///
  /// In ar, this message translates to:
  /// **'أخرى'**
  String get wirdFieldCustom;

  /// Plan field
  ///
  /// In ar, this message translates to:
  /// **'المقدار اليومي'**
  String get wirdFieldAmount;

  /// Plan field
  ///
  /// In ar, this message translates to:
  /// **'نقطة البداية'**
  String get wirdFieldStart;

  /// Plan field
  ///
  /// In ar, this message translates to:
  /// **'تاريخ البدء'**
  String get wirdFieldStartDate;

  /// Start date choice
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get wirdStartToday;

  /// Start date choice
  ///
  /// In ar, this message translates to:
  /// **'غدًا'**
  String get wirdStartTomorrow;

  /// Plan sheet: computed finish date
  ///
  /// In ar, this message translates to:
  /// **'تختم يوم {date}'**
  String wirdFinishesOn(String date);

  /// Plan sheet: computed daily amount
  ///
  /// In ar, this message translates to:
  /// **'نحو {amount} كل يوم'**
  String wirdPerDayPreview(String amount);

  /// Plan field: prayer window
  ///
  /// In ar, this message translates to:
  /// **'وقت الوِرد'**
  String get wirdFieldWindow;

  /// Plan field: catch-up mode
  ///
  /// In ar, this message translates to:
  /// **'إذا فاتك شيء'**
  String get wirdFieldCatchUp;

  /// Catch-up choice
  ///
  /// In ar, this message translates to:
  /// **'وزّعه على الأيام'**
  String get wirdCatchUpSpread;

  /// Catch-up choice
  ///
  /// In ar, this message translates to:
  /// **'أضِفه إلى اليوم'**
  String get wirdCatchUpAll;

  /// Catch-up hint
  ///
  /// In ar, this message translates to:
  /// **'يُقسَّم ما فاتك على الأيام القادمة فلا يثقل عليك يوم'**
  String get wirdCatchUpSpreadHint;

  /// Catch-up hint
  ///
  /// In ar, this message translates to:
  /// **'يُضاف ما فاتك كلّه إلى وِرد اليوم التالي'**
  String get wirdCatchUpAllHint;

  /// Plan field: reminder
  ///
  /// In ar, this message translates to:
  /// **'ذكّرني بعد الصلاة'**
  String get wirdFieldRemind;

  /// Reminder offset choice
  ///
  /// In ar, this message translates to:
  /// **'بعد {minutes}'**
  String wirdRemindAfter(String minutes);

  /// Minutes
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{دقيقة} =2{دقيقتين} few{{count} دقائق} many{{count} دقيقة} other{{count} دقيقة}}'**
  String wirdMinutes(int count);

  /// Stepper button
  ///
  /// In ar, this message translates to:
  /// **'إنقاص'**
  String get wirdDecrease;

  /// Stepper button
  ///
  /// In ar, this message translates to:
  /// **'زيادة'**
  String get wirdIncrease;

  /// Field: surah
  ///
  /// In ar, this message translates to:
  /// **'السورة'**
  String get wirdSurah;

  /// Field: ayah
  ///
  /// In ar, this message translates to:
  /// **'الآية'**
  String get wirdAyah;

  /// Start shortcut label
  ///
  /// In ar, this message translates to:
  /// **'أول الجزء'**
  String get wirdStartJuzShortcut;

  /// A juz
  ///
  /// In ar, this message translates to:
  /// **'الجزء {n}'**
  String wirdJuzNumber(String n);

  /// Surah picker title
  ///
  /// In ar, this message translates to:
  /// **'اختر السورة'**
  String get wirdChooseSurah;

  /// Surah picker search hint
  ///
  /// In ar, this message translates to:
  /// **'ابحث باسم السورة أو رقمها'**
  String get wirdSearchSurah;

  /// Plan sheet button (new)
  ///
  /// In ar, this message translates to:
  /// **'ابدأ الخطة'**
  String get wirdCreate;

  /// Plan sheet button (edit)
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get wirdSave;

  /// Validation
  ///
  /// In ar, this message translates to:
  /// **'اكتب اسمًا للخطة'**
  String get wirdNameRequired;

  /// Notification channel name
  ///
  /// In ar, this message translates to:
  /// **'تذكير الوِرد'**
  String get wirdReminderChannelName;

  /// Notification channel description
  ///
  /// In ar, this message translates to:
  /// **'تذكير بوِردك اليومي بعد الصلاة التي تختارها'**
  String get wirdReminderChannelDescription;

  /// Reminder title
  ///
  /// In ar, this message translates to:
  /// **'حان وقت وِردك'**
  String get wirdReminderTitle;

  /// Reminder body naming today's portion
  ///
  /// In ar, this message translates to:
  /// **'{plan}: {range}'**
  String wirdReminderBodyToday(String plan, String range);

  /// Reminder body
  ///
  /// In ar, this message translates to:
  /// **'{plan} — {window}'**
  String wirdReminderBody(String plan, String window);

  /// Error: catalog unavailable
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل بيانات المصحف'**
  String get wirdCatalogError;

  /// Overall progress caption
  ///
  /// In ar, this message translates to:
  /// **'{percent} من الختمة'**
  String wirdOverallOf(String percent);

  /// Open-ended progress caption
  ///
  /// In ar, this message translates to:
  /// **'{percent} من المصحف'**
  String wirdPositionIn(String percent);

  /// Card link: wird screen
  ///
  /// In ar, this message translates to:
  /// **'كل الخطط'**
  String get wirdOpenAll;

  /// Card: no plan yet
  ///
  /// In ar, this message translates to:
  /// **'ابدأ وِردًا يوميًا'**
  String get wirdStartPlanCta;

  /// Calendar day for screen readers
  ///
  /// In ar, this message translates to:
  /// **'{date}: {status}'**
  String wirdDayStatusSemantics(String date, String status);

  /// Hifz screen title
  ///
  /// In ar, this message translates to:
  /// **'الحفظ'**
  String get hifzTitle;

  /// Hifz card title
  ///
  /// In ar, this message translates to:
  /// **'مراجعة الحفظ'**
  String get hifzTodayTitle;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'ابدأ المراجعة'**
  String get hifzStartReview;

  /// Button when some reviews are done today
  ///
  /// In ar, this message translates to:
  /// **'واصل المراجعة'**
  String get hifzContinueReview;

  /// Status
  ///
  /// In ar, this message translates to:
  /// **'لا مراجعة اليوم'**
  String get hifzNothingDue;

  /// Status
  ///
  /// In ar, this message translates to:
  /// **'راجعتَ كلّ ما استحقّ اليوم، بارك الله فيك'**
  String get hifzAllCaughtUp;

  /// Count of due items
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا مراجعة} =1{مقطع للمراجعة} =2{مقطعان للمراجعة} few{{count} مقاطع للمراجعة} many{{count} مقطعًا للمراجعة} other{{count} مقطع للمراجعة}}'**
  String hifzDueCount(int count);

  /// Count of new items
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا جديد} =1{مقطع جديد} =2{مقطعان جديدان} few{{count} مقاطع جديدة} many{{count} مقطعًا جديدًا} other{{count} مقطع جديد}}'**
  String hifzNewCount(int count);

  /// Tab
  ///
  /// In ar, this message translates to:
  /// **'المستحق'**
  String get hifzTabDue;

  /// Tab
  ///
  /// In ar, this message translates to:
  /// **'الجديد'**
  String get hifzTabNew;

  /// Tab
  ///
  /// In ar, this message translates to:
  /// **'المحفوظ'**
  String get hifzTabLearned;

  /// Stat label
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get hifzStatDue;

  /// Stat label
  ///
  /// In ar, this message translates to:
  /// **'محفوظ'**
  String get hifzStatLearned;

  /// Stat label: share of reviews recalled
  ///
  /// In ar, this message translates to:
  /// **'التذكّر'**
  String get hifzStatRetention;

  /// Stat label
  ///
  /// In ar, this message translates to:
  /// **'السلسلة'**
  String get hifzStatStreak;

  /// Stat caption: the retention window (days is a formatted number)
  ///
  /// In ar, this message translates to:
  /// **'آخر {days} يومًا'**
  String hifzRetentionCaption(String days);

  /// Forecast chart title
  ///
  /// In ar, this message translates to:
  /// **'المراجعات في الأسبوع القادم'**
  String get hifzForecastTitle;

  /// Forecast: today column
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get hifzForecastToday;

  /// Item kind
  ///
  /// In ar, this message translates to:
  /// **'آيات'**
  String get hifzKindAyat;

  /// Item kind
  ///
  /// In ar, this message translates to:
  /// **'حديث'**
  String get hifzKindHadith;

  /// Item kind
  ///
  /// In ar, this message translates to:
  /// **'نص'**
  String get hifzKindCustom;

  /// When an item is due
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{اليوم} =1{غدًا} =2{بعد يومين} few{بعد {count} أيام} many{بعد {count} يومًا} other{بعد {count} يوم}}'**
  String hifzDueIn(int count);

  /// Overdue item
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{فات موعده أمس} =2{فات موعده منذ يومين} few{فات موعده منذ {count} أيام} many{فات موعده منذ {count} يومًا} other{فات موعده منذ {count} يوم}}'**
  String hifzOverdue(int count);

  /// Reviews count
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لم يُراجَع بعد} =1{مراجعة واحدة} =2{مراجعتان} few{{count} مراجعات} many{{count} مراجعة} other{{count} مراجعة}}'**
  String hifzReviews(int count);

  /// Lapses count
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{نُسي مرة} =2{نُسي مرتين} few{نُسي {count} مرات} many{نُسي {count} مرة} other{نُسي {count} مرة}}'**
  String hifzLapses(int count);

  /// Badge
  ///
  /// In ar, this message translates to:
  /// **'جديد'**
  String get hifzNewBadge;

  /// Badge
  ///
  /// In ar, this message translates to:
  /// **'معلّق'**
  String get hifzSuspendedBadge;

  /// Button: add items
  ///
  /// In ar, this message translates to:
  /// **'أضِف'**
  String get hifzAdd;

  /// Add sheet title
  ///
  /// In ar, this message translates to:
  /// **'إضافة إلى الحفظ'**
  String get hifzAddTitle;

  /// Add sheet subtitle
  ///
  /// In ar, this message translates to:
  /// **'ما تحفظه اليوم يعود إليك قبل أن يُنسى'**
  String get hifzAddSubtitle;

  /// Add choice
  ///
  /// In ar, this message translates to:
  /// **'آيات من القرآن'**
  String get hifzAddAyat;

  /// Add choice hint
  ///
  /// In ar, this message translates to:
  /// **'اختر سورة وآيات، وتُقسَّم إلى مقاطع قصيرة'**
  String get hifzAddAyatHint;

  /// Add choice
  ///
  /// In ar, this message translates to:
  /// **'حديث من الأربعين النووية'**
  String get hifzAddHadith;

  /// Add choice hint
  ///
  /// In ar, this message translates to:
  /// **'اثنان وأربعون حديثًا من جوامع الكلم'**
  String get hifzAddHadithHint;

  /// Add choice
  ///
  /// In ar, this message translates to:
  /// **'نصّ من اختيارك'**
  String get hifzAddCustom;

  /// Add choice hint
  ///
  /// In ar, this message translates to:
  /// **'دعاء أو متن أو أيّ نصّ تريد حفظه'**
  String get hifzAddCustomHint;

  /// Field
  ///
  /// In ar, this message translates to:
  /// **'من الآية'**
  String get hifzFromAyah;

  /// Field
  ///
  /// In ar, this message translates to:
  /// **'إلى الآية'**
  String get hifzToAyah;

  /// Field
  ///
  /// In ar, this message translates to:
  /// **'آيات كل مقطع'**
  String get hifzChunkSize;

  /// Chunk count
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا مقاطع} =1{مقطع واحد} =2{مقطعان} few{{count} مقاطع} many{{count} مقطعًا} other{{count} مقطع}}'**
  String hifzChunks(int count);

  /// Chunk preview line
  ///
  /// In ar, this message translates to:
  /// **'{chunks}: {ranges}'**
  String hifzChunkPreview(String chunks, String ranges);

  /// Sheet button
  ///
  /// In ar, this message translates to:
  /// **'أضِف إلى الحفظ'**
  String get hifzAddButton;

  /// Undo toast: items added
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{أُضيف مقطع إلى الحفظ} =2{أُضيف مقطعان إلى الحفظ} few{أُضيفت {count} مقاطع إلى الحفظ} many{أُضيف {count} مقطعًا إلى الحفظ} other{أُضيف {count} مقطع إلى الحفظ}}'**
  String hifzAdded(int count);

  /// Badge: hadith already added
  ///
  /// In ar, this message translates to:
  /// **'في الحفظ'**
  String get hifzInHifz;

  /// Field
  ///
  /// In ar, this message translates to:
  /// **'العنوان'**
  String get hifzCustomTitle;

  /// Field hint
  ///
  /// In ar, this message translates to:
  /// **'مثلًا: دعاء الاستخارة'**
  String get hifzCustomTitleHint;

  /// Field
  ///
  /// In ar, this message translates to:
  /// **'النص'**
  String get hifzCustomBody;

  /// Field
  ///
  /// In ar, this message translates to:
  /// **'المصدر (اختياري)'**
  String get hifzCustomSource;

  /// Validation
  ///
  /// In ar, this message translates to:
  /// **'اكتب النصّ الذي تريد حفظه'**
  String get hifzBodyRequired;

  /// Action
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get hifzEdit;

  /// Sheet title
  ///
  /// In ar, this message translates to:
  /// **'تعديل المقطع'**
  String get hifzEditTitle;

  /// Action: stop scheduling an item
  ///
  /// In ar, this message translates to:
  /// **'تعليق'**
  String get hifzSuspend;

  /// Action: unsuspend
  ///
  /// In ar, this message translates to:
  /// **'إعادة إلى المراجعة'**
  String get hifzUnsuspend;

  /// Action: reset SM-2 state
  ///
  /// In ar, this message translates to:
  /// **'البدء فيه من جديد'**
  String get hifzResetProgress;

  /// Action
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get hifzDelete;

  /// Action: review one item
  ///
  /// In ar, this message translates to:
  /// **'راجِعه الآن'**
  String get hifzReviewNow;

  /// Undo toast
  ///
  /// In ar, this message translates to:
  /// **'حُذف من الحفظ'**
  String get hifzDeletedToast;

  /// Undo toast
  ///
  /// In ar, this message translates to:
  /// **'عُلّق المقطع'**
  String get hifzSuspendedToast;

  /// Undo toast
  ///
  /// In ar, this message translates to:
  /// **'عاد المقطع إلى المراجعة'**
  String get hifzUnsuspendedToast;

  /// Undo toast
  ///
  /// In ar, this message translates to:
  /// **'عاد المقطع جديدًا'**
  String get hifzResetToast;

  /// Undo toast
  ///
  /// In ar, this message translates to:
  /// **'حُفظت التعديلات'**
  String get hifzSavedToast;

  /// Review screen title
  ///
  /// In ar, this message translates to:
  /// **'المراجعة'**
  String get hifzReviewTitle;

  /// Review progress
  ///
  /// In ar, this message translates to:
  /// **'{done} من {total}'**
  String hifzReviewProgress(String done, String total);

  /// Review hint
  ///
  /// In ar, this message translates to:
  /// **'اقرأ من حفظك، ثم اكشف النصّ وقيّم نفسك بصدق'**
  String get hifzRecitePrompt;

  /// Reveal stage
  ///
  /// In ar, this message translates to:
  /// **'أوائل الكلمات'**
  String get hifzRevealFirstLetters;

  /// Reveal button
  ///
  /// In ar, this message translates to:
  /// **'الكلمة التالية'**
  String get hifzRevealNextWord;

  /// Reveal button
  ///
  /// In ar, this message translates to:
  /// **'أظهِر النصّ'**
  String get hifzRevealAll;

  /// Reveal button
  ///
  /// In ar, this message translates to:
  /// **'أخفِ'**
  String get hifzRevealHide;

  /// Button: play recitation
  ///
  /// In ar, this message translates to:
  /// **'استمع'**
  String get hifzListen;

  /// Button: stop recitation
  ///
  /// In ar, this message translates to:
  /// **'أوقِف'**
  String get hifzListenStop;

  /// Repeat count
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{مرة} =2{مرتين} few{{count} مرات} many{{count} مرة} other{{count} مرة}}'**
  String hifzRepeatTimes(int count);

  /// Badge: same-session re-drill
  ///
  /// In ar, this message translates to:
  /// **'نعيده حتى يبلغ «جيد»'**
  String get hifzRedrill;

  /// Badge: first review
  ///
  /// In ar, this message translates to:
  /// **'مقطع جديد'**
  String get hifzNewItem;

  /// Grade prompt
  ///
  /// In ar, this message translates to:
  /// **'كيف كان استحضارك؟'**
  String get hifzGradePrompt;

  /// SM-2 grade 0
  ///
  /// In ar, this message translates to:
  /// **'نسيته'**
  String get hifzGrade0;

  /// SM-2 grade 0 meaning
  ///
  /// In ar, this message translates to:
  /// **'لم أستحضر شيئًا'**
  String get hifzGrade0Hint;

  /// SM-2 grade 1
  ///
  /// In ar, this message translates to:
  /// **'أخطأت'**
  String get hifzGrade1;

  /// SM-2 grade 1 meaning
  ///
  /// In ar, this message translates to:
  /// **'أخطأت، وعرفته حين رأيته'**
  String get hifzGrade1Hint;

  /// SM-2 grade 2
  ///
  /// In ar, this message translates to:
  /// **'قريب'**
  String get hifzGrade2;

  /// SM-2 grade 2 meaning
  ///
  /// In ar, this message translates to:
  /// **'أخطأت، وبدا سهلًا حين رأيته'**
  String get hifzGrade2Hint;

  /// SM-2 grade 3
  ///
  /// In ar, this message translates to:
  /// **'بصعوبة'**
  String get hifzGrade3;

  /// SM-2 grade 3 meaning
  ///
  /// In ar, this message translates to:
  /// **'صحيح بجهدٍ كبير'**
  String get hifzGrade3Hint;

  /// SM-2 grade 4
  ///
  /// In ar, this message translates to:
  /// **'جيد'**
  String get hifzGrade4;

  /// SM-2 grade 4 meaning
  ///
  /// In ar, this message translates to:
  /// **'صحيح بعد تردّد يسير'**
  String get hifzGrade4Hint;

  /// SM-2 grade 5
  ///
  /// In ar, this message translates to:
  /// **'متقَن'**
  String get hifzGrade5;

  /// SM-2 grade 5 meaning
  ///
  /// In ar, this message translates to:
  /// **'صحيح بلا تردّد'**
  String get hifzGrade5Hint;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'تراجع عن التقييم'**
  String get hifzUndoGrade;

  /// After grading
  ///
  /// In ar, this message translates to:
  /// **'المراجعة القادمة {when}'**
  String hifzNextReview(String when);

  /// Button: end session early
  ///
  /// In ar, this message translates to:
  /// **'إنهاء'**
  String get hifzFinish;

  /// Summary title
  ///
  /// In ar, this message translates to:
  /// **'أتممتَ المراجعة'**
  String get hifzSummaryTitle;

  /// Summary subtitle (hadith)
  ///
  /// In ar, this message translates to:
  /// **'«خيرُكم من تعلّم القرآن وعلّمه»'**
  String get hifzSummarySubtitle;

  /// Summary stat
  ///
  /// In ar, this message translates to:
  /// **'راجعت'**
  String get hifzSummaryReviewed;

  /// Summary stat
  ///
  /// In ar, this message translates to:
  /// **'جديد'**
  String get hifzSummaryNew;

  /// Summary stat: re-drills
  ///
  /// In ar, this message translates to:
  /// **'أُعيد'**
  String get hifzSummaryAgain;

  /// Summary stat: share graded ≥3
  ///
  /// In ar, this message translates to:
  /// **'تذكّرت'**
  String get hifzSummaryRecall;

  /// Summary: due tomorrow
  ///
  /// In ar, this message translates to:
  /// **'غدًا: {count}'**
  String hifzSummaryTomorrow(String count);

  /// Summary button
  ///
  /// In ar, this message translates to:
  /// **'تمّ'**
  String get hifzSummaryDone;

  /// Review screen empty
  ///
  /// In ar, this message translates to:
  /// **'لا شيء للمراجعة الآن'**
  String get hifzEmptySession;

  /// Empty state
  ///
  /// In ar, this message translates to:
  /// **'ابدأ رحلة الحفظ'**
  String get hifzEmptyTitle;

  /// Empty state
  ///
  /// In ar, this message translates to:
  /// **'أضِف آيات أو حديثًا، ويعيدها التكرار المتباعد إليك قبل أن تُنسى.'**
  String get hifzEmptyBody;

  /// Empty tab
  ///
  /// In ar, this message translates to:
  /// **'لا شيء مستحقّ اليوم'**
  String get hifzEmptyDue;

  /// Empty tab
  ///
  /// In ar, this message translates to:
  /// **'لا مقاطع جديدة تنتظر'**
  String get hifzEmptyNew;

  /// Empty tab
  ///
  /// In ar, this message translates to:
  /// **'تظهر هنا المقاطع بعد أول مراجعة لها'**
  String get hifzEmptyLearned;

  /// Settings sheet title
  ///
  /// In ar, this message translates to:
  /// **'إعدادات الحفظ'**
  String get hifzSettingsTitle;

  /// Setting
  ///
  /// In ar, this message translates to:
  /// **'مقاطع جديدة كل يوم'**
  String get hifzNewPerDay;

  /// Setting
  ///
  /// In ar, this message translates to:
  /// **'تكرار الاستماع لكل آية'**
  String get hifzListenRepeat;

  /// Hadith number
  ///
  /// In ar, this message translates to:
  /// **'الحديث {n}'**
  String hifzHadithNumber(String n);

  /// Hadith source line
  ///
  /// In ar, this message translates to:
  /// **'{collection}، {n}'**
  String hifzHadithSource(String collection, String n);

  /// Error
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل بيانات المصحف'**
  String get hifzCatalogError;

  /// SM-2 ease factor
  ///
  /// In ar, this message translates to:
  /// **'السهولة {value}'**
  String hifzEase(String value);

  /// SM-2 interval of one day
  ///
  /// In ar, this message translates to:
  /// **'كل يوم'**
  String get hifzEveryDay;

  /// SM-2 interval
  ///
  /// In ar, this message translates to:
  /// **'كل {days}'**
  String hifzInterval(String days);

  /// Card link
  ///
  /// In ar, this message translates to:
  /// **'كل المقاطع'**
  String get hifzOpenAll;

  /// Card: nothing added yet
  ///
  /// In ar, this message translates to:
  /// **'ابدأ الحفظ'**
  String get hifzStartCta;

  /// Qibla screen title
  ///
  /// In ar, this message translates to:
  /// **'القبلة'**
  String get qiblaTitle;

  /// Status: the phone points at the qibla (±3°)
  ///
  /// In ar, this message translates to:
  /// **'اتجاهك الآن إلى القبلة'**
  String get qiblaFacing;

  /// Status: turn clockwise by degrees (pre-formatted, e.g. ٤٥°)
  ///
  /// In ar, this message translates to:
  /// **'استدر يمينًا {degrees}'**
  String qiblaTurnRight(String degrees);

  /// Status: turn counter-clockwise by degrees
  ///
  /// In ar, this message translates to:
  /// **'استدر يسارًا {degrees}'**
  String qiblaTurnLeft(String degrees);

  /// Status: waiting for the first compass reading
  ///
  /// In ar, this message translates to:
  /// **'جارٍ قراءة البوصلة…'**
  String get qiblaReading;

  /// Hint when the phone points at the ground
  ///
  /// In ar, this message translates to:
  /// **'أمسك الهاتف مستويًا أمامك'**
  String get qiblaHoldFlat;

  /// Info tile label: the qibla bearing from true north
  ///
  /// In ar, this message translates to:
  /// **'اتجاه القبلة'**
  String get qiblaBearing;

  /// Info tile label
  ///
  /// In ar, this message translates to:
  /// **'المسافة إلى الكعبة'**
  String get qiblaDistance;

  /// Distance in kilometres (number pre-formatted)
  ///
  /// In ar, this message translates to:
  /// **'{distance} كم'**
  String qiblaKm(String distance);

  /// Info tile label: where the phone points (true north)
  ///
  /// In ar, this message translates to:
  /// **'اتجاهك'**
  String get qiblaYourHeading;

  /// Info tile label: the sun's azimuth
  ///
  /// In ar, this message translates to:
  /// **'اتجاه الشمس'**
  String get qiblaSunBearing;

  /// Footnote: magnetic declination (value pre-formatted, direction = qiblaEast/qiblaWest)
  ///
  /// In ar, this message translates to:
  /// **'الانحراف المغناطيسي هنا {value} {direction}، ويُصحَّح تلقائيًّا بنموذج المجال المغناطيسي العالمي.'**
  String qiblaDeclination(String value, String direction);

  /// Declination direction: east
  ///
  /// In ar, this message translates to:
  /// **'شرقًا'**
  String get qiblaEast;

  /// Declination direction: west
  ///
  /// In ar, this message translates to:
  /// **'غربًا'**
  String get qiblaWest;

  /// Compass accuracy level
  ///
  /// In ar, this message translates to:
  /// **'دقة عالية'**
  String get qiblaAccuracyHigh;

  /// Compass accuracy level
  ///
  /// In ar, this message translates to:
  /// **'دقة متوسطة'**
  String get qiblaAccuracyMedium;

  /// Compass accuracy level
  ///
  /// In ar, this message translates to:
  /// **'دقة منخفضة'**
  String get qiblaAccuracyLow;

  /// Compass accuracy level
  ///
  /// In ar, this message translates to:
  /// **'قراءة غير موثوقة'**
  String get qiblaAccuracyUnreliable;

  /// Accuracy chip: level and the estimated error, pre-formatted (e.g. ±٤°)
  ///
  /// In ar, this message translates to:
  /// **'{level}، {error}'**
  String qiblaAccuracyChip(String level, String error);

  /// Calibration prompt title
  ///
  /// In ar, this message translates to:
  /// **'عايِر البوصلة'**
  String get qiblaCalibrateTitle;

  /// Calibration prompt body; {eight} is the digit 8 in the user's digits
  ///
  /// In ar, this message translates to:
  /// **'حرّك الهاتف في الهواء على شكل الرقم {eight} مرّاتٍ قليلة، بعيدًا عن المعادن والمغانط.'**
  String qiblaCalibrateBody(String eight);

  /// Calibration prompt body when the field strength is far off
  ///
  /// In ar, this message translates to:
  /// **'المجال المغناطيسي هنا مضطرب: ابتعد عن المعادن والأجهزة والمغانط (ومنها أغطية الهاتف المغناطيسية)، ثم حرّك الهاتف على شكل الرقم {eight}.'**
  String qiblaInterferenceBody(String eight);

  /// Button: hide the calibration prompt
  ///
  /// In ar, this message translates to:
  /// **'لاحقًا'**
  String get qiblaCalibrateLater;

  /// Toast when the calibration prompt resolves
  ///
  /// In ar, this message translates to:
  /// **'تمّت معايرة البوصلة'**
  String get qiblaCalibrated;

  /// Button: show the calibration prompt again
  ///
  /// In ar, this message translates to:
  /// **'معايرة'**
  String get qiblaCalibrateAction;

  /// Sun mode title
  ///
  /// In ar, this message translates to:
  /// **'بوصلة الشمس'**
  String get qiblaSunTitle;

  /// Sun mode instructions
  ///
  /// In ar, this message translates to:
  /// **'قف والشمس أمامك، ووجّه أعلى الهاتف نحوها دون أن تنظر إليها مباشرة؛ عندئذٍ تشير الإبرة الذهبية إلى القبلة.'**
  String get qiblaSunHowTo;

  /// Sun mode: qibla relative to the sun
  ///
  /// In ar, this message translates to:
  /// **'القبلة إلى يمين الشمس بزاوية {degrees}'**
  String qiblaSunRightOf(String degrees);

  /// Sun mode: qibla relative to the sun
  ///
  /// In ar, this message translates to:
  /// **'القبلة إلى يسار الشمس بزاوية {degrees}'**
  String qiblaSunLeftOf(String degrees);

  /// Sun mode: qibla within 3° of the sun
  ///
  /// In ar, this message translates to:
  /// **'القبلة في جهة الشمس تمامًا'**
  String get qiblaSunAhead;

  /// Sun mode caveat near noon
  ///
  /// In ar, this message translates to:
  /// **'الشمس عالية الآن، فالتصويب نحوها أقلّ دقة.'**
  String get qiblaSunHigh;

  /// Diagram mode title
  ///
  /// In ar, this message translates to:
  /// **'مخطط الاتجاه'**
  String get qiblaDiagramTitle;

  /// Diagram instructions (northern hemisphere)
  ///
  /// In ar, this message translates to:
  /// **'حدّد الشمال ببوصلة، أو ليلًا بالنجم القطبي (الجُدَيّ)، ثم استدر {degrees} باتجاه عقارب الساعة.'**
  String qiblaDiagramHowTo(String degrees);

  /// Diagram instructions (southern hemisphere)
  ///
  /// In ar, this message translates to:
  /// **'حدّد الشمال ببوصلة، أو ليلًا بكوكبة الصليب الجنوبي التي تدلّ على الجنوب، ثم استدر {degrees} من الشمال باتجاه عقارب الساعة.'**
  String qiblaDiagramHowToSouth(String degrees);

  /// Fallback reason
  ///
  /// In ar, this message translates to:
  /// **'لا يحتوي هذا الهاتف على بوصلة (مستشعر مغناطيسي).'**
  String get qiblaNoSensor;

  /// Fallback reason
  ///
  /// In ar, this message translates to:
  /// **'تعذّرت قراءة البوصلة.'**
  String get qiblaSensorError;

  /// Fallback reason
  ///
  /// In ar, this message translates to:
  /// **'لا تصل قراءات من البوصلة.'**
  String get qiblaNoReadings;

  /// Button: switch to the sun compass
  ///
  /// In ar, this message translates to:
  /// **'استعن بالشمس'**
  String get qiblaUseSun;

  /// Button: back to the live compass
  ///
  /// In ar, this message translates to:
  /// **'عُد إلى البوصلة'**
  String get qiblaUseCompass;

  /// Button: retry the compass
  ///
  /// In ar, this message translates to:
  /// **'أعد المحاولة'**
  String get qiblaRetry;

  /// Shown within 200 m of the Kaaba
  ///
  /// In ar, this message translates to:
  /// **'أنت عند الكعبة المشرّفة، فتوجّه إليها مباشرة.'**
  String get qiblaAtKaaba;

  /// Faith hub card title
  ///
  /// In ar, this message translates to:
  /// **'اتجاه القبلة'**
  String get qiblaCardTitle;

  /// Card action / semantics hint
  ///
  /// In ar, this message translates to:
  /// **'افتح البوصلة'**
  String get qiblaCardOpen;

  /// The place the qibla is computed from
  ///
  /// In ar, this message translates to:
  /// **'من {place}'**
  String qiblaFromPlace(String place);

  /// Compass point abbreviation N (Arabic: ش شمال، ق شرق، ج جنوب، غ غرب)
  ///
  /// In ar, this message translates to:
  /// **'ش'**
  String get qiblaPointN;

  /// Compass point abbreviation NE (Arabic: ش شمال، ق شرق، ج جنوب، غ غرب)
  ///
  /// In ar, this message translates to:
  /// **'ش ق'**
  String get qiblaPointNE;

  /// Compass point abbreviation E (Arabic: ش شمال، ق شرق، ج جنوب، غ غرب)
  ///
  /// In ar, this message translates to:
  /// **'ق'**
  String get qiblaPointE;

  /// Compass point abbreviation SE (Arabic: ش شمال، ق شرق، ج جنوب، غ غرب)
  ///
  /// In ar, this message translates to:
  /// **'ج ق'**
  String get qiblaPointSE;

  /// Compass point abbreviation S (Arabic: ش شمال، ق شرق، ج جنوب، غ غرب)
  ///
  /// In ar, this message translates to:
  /// **'ج'**
  String get qiblaPointS;

  /// Compass point abbreviation SW (Arabic: ش شمال، ق شرق، ج جنوب، غ غرب)
  ///
  /// In ar, this message translates to:
  /// **'ج غ'**
  String get qiblaPointSW;

  /// Compass point abbreviation W (Arabic: ش شمال، ق شرق، ج جنوب، غ غرب)
  ///
  /// In ar, this message translates to:
  /// **'غ'**
  String get qiblaPointW;

  /// Compass point abbreviation NW (Arabic: ش شمال، ق شرق، ج جنوب، غ غرب)
  ///
  /// In ar, this message translates to:
  /// **'ش غ'**
  String get qiblaPointNW;

  /// Compass point full name N (screen readers)
  ///
  /// In ar, this message translates to:
  /// **'الشمال'**
  String get qiblaPointNameN;

  /// Compass point full name NE (screen readers)
  ///
  /// In ar, this message translates to:
  /// **'الشمال الشرقي'**
  String get qiblaPointNameNE;

  /// Compass point full name E (screen readers)
  ///
  /// In ar, this message translates to:
  /// **'الشرق'**
  String get qiblaPointNameE;

  /// Compass point full name SE (screen readers)
  ///
  /// In ar, this message translates to:
  /// **'الجنوب الشرقي'**
  String get qiblaPointNameSE;

  /// Compass point full name S (screen readers)
  ///
  /// In ar, this message translates to:
  /// **'الجنوب'**
  String get qiblaPointNameS;

  /// Compass point full name SW (screen readers)
  ///
  /// In ar, this message translates to:
  /// **'الجنوب الغربي'**
  String get qiblaPointNameSW;

  /// Compass point full name W (screen readers)
  ///
  /// In ar, this message translates to:
  /// **'الغرب'**
  String get qiblaPointNameW;

  /// Compass point full name NW (screen readers)
  ///
  /// In ar, this message translates to:
  /// **'الشمال الغربي'**
  String get qiblaPointNameNW;

  /// Semantics label of the dial
  ///
  /// In ar, this message translates to:
  /// **'بوصلة القبلة: القبلة على {bearing} نحو {point}.'**
  String qiblaDialLabel(String bearing, String point);
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
