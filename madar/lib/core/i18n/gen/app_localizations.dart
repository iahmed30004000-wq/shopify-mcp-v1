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

  /// Pill on the orbit scene shown whenever the view differs from the default overview (turned, tilted, zoomed, or the worlds drifted into each other); puts the camera and the worlds back exactly as on a fresh start
  ///
  /// In ar, this message translates to:
  /// **'إعادة ضبط العرض'**
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

  /// Hint under the lock screen astrolabe when the fingerprint prompt is not showing (after a cancel), above the large "Use fingerprint" button
  ///
  /// In ar, this message translates to:
  /// **'افتح مَدار ببصمتك'**
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

  /// Large button on the lock screen that opens the fingerprint prompt again (after a cancel or an error)
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
  /// **'انقطع التحقّق بالبصمة. حاول مجددًا.'**
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

  /// Title of the medications screen
  ///
  /// In ar, this message translates to:
  /// **'الأدوية والمكمّلات'**
  String get medsTitle;

  /// No description provided for @medsTabToday.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get medsTabToday;

  /// No description provided for @medsTabMeds.
  ///
  /// In ar, this message translates to:
  /// **'أدويتي'**
  String get medsTabMeds;

  /// Tab of treatment / injection courses
  ///
  /// In ar, this message translates to:
  /// **'الدورات'**
  String get medsTabCourses;

  /// No description provided for @medsSettingsOpen.
  ///
  /// In ar, this message translates to:
  /// **'إعدادات الأدوية'**
  String get medsSettingsOpen;

  /// No description provided for @medsAddMed.
  ///
  /// In ar, this message translates to:
  /// **'دواء جديد'**
  String get medsAddMed;

  /// No description provided for @medsAddCourse.
  ///
  /// In ar, this message translates to:
  /// **'دورة علاجية جديدة'**
  String get medsAddCourse;

  /// No description provided for @medsAddRule.
  ///
  /// In ar, this message translates to:
  /// **'قاعدة توقيت جديدة'**
  String get medsAddRule;

  /// No description provided for @medsKindMedication.
  ///
  /// In ar, this message translates to:
  /// **'دواء'**
  String get medsKindMedication;

  /// No description provided for @medsKindSupplement.
  ///
  /// In ar, this message translates to:
  /// **'مكمّل'**
  String get medsKindSupplement;

  /// No description provided for @medsKindInjection.
  ///
  /// In ar, this message translates to:
  /// **'حقنة'**
  String get medsKindInjection;

  /// No description provided for @medsKindOther.
  ///
  /// In ar, this message translates to:
  /// **'أخرى'**
  String get medsKindOther;

  /// No description provided for @medsWithEmptyStomach.
  ///
  /// In ar, this message translates to:
  /// **'على الريق'**
  String get medsWithEmptyStomach;

  /// No description provided for @medsWithBreakfast.
  ///
  /// In ar, this message translates to:
  /// **'مع الفطور'**
  String get medsWithBreakfast;

  /// No description provided for @medsWithLunch.
  ///
  /// In ar, this message translates to:
  /// **'مع الغداء'**
  String get medsWithLunch;

  /// No description provided for @medsWithDinner.
  ///
  /// In ar, this message translates to:
  /// **'مع العشاء'**
  String get medsWithDinner;

  /// No description provided for @medsWithBedtime.
  ///
  /// In ar, this message translates to:
  /// **'قبل النوم'**
  String get medsWithBedtime;

  /// No description provided for @medsWithOther.
  ///
  /// In ar, this message translates to:
  /// **'أخرى'**
  String get medsWithOther;

  /// No description provided for @medsWithPerCourse.
  ///
  /// In ar, this message translates to:
  /// **'حسب الدورة'**
  String get medsWithPerCourse;

  /// No description provided for @medsWithAnytime.
  ///
  /// In ar, this message translates to:
  /// **'في أي وقت'**
  String get medsWithAnytime;

  /// No description provided for @medsMealBreakfast.
  ///
  /// In ar, this message translates to:
  /// **'الفطور'**
  String get medsMealBreakfast;

  /// No description provided for @medsMealLunch.
  ///
  /// In ar, this message translates to:
  /// **'الغداء'**
  String get medsMealLunch;

  /// No description provided for @medsMealDinner.
  ///
  /// In ar, this message translates to:
  /// **'وجبة العشاء'**
  String get medsMealDinner;

  /// No description provided for @medsMealBedtime.
  ///
  /// In ar, this message translates to:
  /// **'النوم'**
  String get medsMealBedtime;

  /// No description provided for @medsMealBreakfastTitle.
  ///
  /// In ar, this message translates to:
  /// **'الفطور'**
  String get medsMealBreakfastTitle;

  /// No description provided for @medsMealLunchTitle.
  ///
  /// In ar, this message translates to:
  /// **'الغداء'**
  String get medsMealLunchTitle;

  /// No description provided for @medsMealDinnerTitle.
  ///
  /// In ar, this message translates to:
  /// **'العشاء'**
  String get medsMealDinnerTitle;

  /// No description provided for @medsMealBedtimeTitle.
  ///
  /// In ar, this message translates to:
  /// **'النوم'**
  String get medsMealBedtimeTitle;

  /// No description provided for @medsAnchorAtPrayer.
  ///
  /// In ar, this message translates to:
  /// **'عند {place}'**
  String medsAnchorAtPrayer(String place);

  /// No description provided for @medsAnchorWithMeal.
  ///
  /// In ar, this message translates to:
  /// **'مع {place}'**
  String medsAnchorWithMeal(String place);

  /// No description provided for @medsAnchorBefore.
  ///
  /// In ar, this message translates to:
  /// **'قبل {place} بـ{duration}'**
  String medsAnchorBefore(String place, String duration);

  /// No description provided for @medsAnchorAfter.
  ///
  /// In ar, this message translates to:
  /// **'بعد {place} بـ{duration}'**
  String medsAnchorAfter(String place, String duration);

  /// No description provided for @medsAnchorBedtime.
  ///
  /// In ar, this message translates to:
  /// **'عند النوم'**
  String get medsAnchorBedtime;

  /// No description provided for @medsTimes.
  ///
  /// In ar, this message translates to:
  /// **'مواعيد الجرعات'**
  String get medsTimes;

  /// No description provided for @medsTimesHint.
  ///
  /// In ar, this message translates to:
  /// **'وقت ثابت، أو موعد يتبع صلاة أو وجبة ويتحرّك معها كل يوم'**
  String get medsTimesHint;

  /// No description provided for @medsAddFixedTime.
  ///
  /// In ar, this message translates to:
  /// **'وقت ثابت'**
  String get medsAddFixedTime;

  /// No description provided for @medsAddAnchoredTime.
  ///
  /// In ar, this message translates to:
  /// **'مع صلاة أو وجبة'**
  String get medsAddAnchoredTime;

  /// No description provided for @medsTimeToday.
  ///
  /// In ar, this message translates to:
  /// **'اليوم {time}'**
  String medsTimeToday(String time);

  /// No description provided for @medsRemoveTime.
  ///
  /// In ar, this message translates to:
  /// **'إزالة الموعد'**
  String get medsRemoveTime;

  /// No description provided for @medsOffsetBefore.
  ///
  /// In ar, this message translates to:
  /// **'قبل'**
  String get medsOffsetBefore;

  /// No description provided for @medsOffsetAt.
  ///
  /// In ar, this message translates to:
  /// **'عند'**
  String get medsOffsetAt;

  /// No description provided for @medsOffsetAfter.
  ///
  /// In ar, this message translates to:
  /// **'بعد'**
  String get medsOffsetAfter;

  /// No description provided for @medsAnchorPrayers.
  ///
  /// In ar, this message translates to:
  /// **'الصلوات'**
  String get medsAnchorPrayers;

  /// No description provided for @medsAnchorMeals.
  ///
  /// In ar, this message translates to:
  /// **'الوجبات'**
  String get medsAnchorMeals;

  /// No description provided for @medsAnchorPick.
  ///
  /// In ar, this message translates to:
  /// **'يتبع'**
  String get medsAnchorPick;

  /// No description provided for @medsAnchorOffset.
  ///
  /// In ar, this message translates to:
  /// **'التوقيت'**
  String get medsAnchorOffset;

  /// No description provided for @medsAnchorDone.
  ///
  /// In ar, this message translates to:
  /// **'تم'**
  String get medsAnchorDone;

  /// No description provided for @medsNoTimesAsNeeded.
  ///
  /// In ar, this message translates to:
  /// **'بلا مواعيد: تُسجَّل الجرعة عند أخذها'**
  String get medsNoTimesAsNeeded;

  /// No description provided for @medsEditorNew.
  ///
  /// In ar, this message translates to:
  /// **'دواء جديد'**
  String get medsEditorNew;

  /// No description provided for @medsEditorEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الدواء'**
  String get medsEditorEdit;

  /// No description provided for @medsFieldName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get medsFieldName;

  /// No description provided for @medsFieldNameHint.
  ///
  /// In ar, this message translates to:
  /// **'كما هو على العلبة'**
  String get medsFieldNameHint;

  /// No description provided for @medsFieldNameRequired.
  ///
  /// In ar, this message translates to:
  /// **'اكتب الاسم'**
  String get medsFieldNameRequired;

  /// No description provided for @medsFieldKind.
  ///
  /// In ar, this message translates to:
  /// **'النوع'**
  String get medsFieldKind;

  /// No description provided for @medsFieldDose.
  ///
  /// In ar, this message translates to:
  /// **'الجرعة'**
  String get medsFieldDose;

  /// No description provided for @medsFieldDoseHint.
  ///
  /// In ar, this message translates to:
  /// **'كما في الوصفة، مثلًا: ١٠ ملغ أو حبّتان'**
  String get medsFieldDoseHint;

  /// No description provided for @medsFieldAmount.
  ///
  /// In ar, this message translates to:
  /// **'الكمية'**
  String get medsFieldAmount;

  /// No description provided for @medsFieldUnit.
  ///
  /// In ar, this message translates to:
  /// **'الوحدة'**
  String get medsFieldUnit;

  /// No description provided for @medsUnitTab.
  ///
  /// In ar, this message translates to:
  /// **'حبة'**
  String get medsUnitTab;

  /// No description provided for @medsUnitCap.
  ///
  /// In ar, this message translates to:
  /// **'كبسولة'**
  String get medsUnitCap;

  /// No description provided for @medsUnitMg.
  ///
  /// In ar, this message translates to:
  /// **'ملغ'**
  String get medsUnitMg;

  /// No description provided for @medsUnitMl.
  ///
  /// In ar, this message translates to:
  /// **'مل'**
  String get medsUnitMl;

  /// No description provided for @medsUnitIu.
  ///
  /// In ar, this message translates to:
  /// **'وحدة'**
  String get medsUnitIu;

  /// No description provided for @medsUnitDrop.
  ///
  /// In ar, this message translates to:
  /// **'نقطة'**
  String get medsUnitDrop;

  /// No description provided for @medsUnitPuff.
  ///
  /// In ar, this message translates to:
  /// **'بخة'**
  String get medsUnitPuff;

  /// No description provided for @medsUnitAmp.
  ///
  /// In ar, this message translates to:
  /// **'أمبولة'**
  String get medsUnitAmp;

  /// No description provided for @medsFieldTakenWith.
  ///
  /// In ar, this message translates to:
  /// **'يؤخذ'**
  String get medsFieldTakenWith;

  /// No description provided for @medsFieldTakenWithNote.
  ///
  /// In ar, this message translates to:
  /// **'توضيح'**
  String get medsFieldTakenWithNote;

  /// No description provided for @medsFieldNotes.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات'**
  String get medsFieldNotes;

  /// No description provided for @medsFieldStock.
  ///
  /// In ar, this message translates to:
  /// **'المتبقي'**
  String get medsFieldStock;

  /// No description provided for @medsFieldRefillAt.
  ///
  /// In ar, this message translates to:
  /// **'نبّهني عند'**
  String get medsFieldRefillAt;

  /// No description provided for @medsStockHint.
  ///
  /// In ar, this message translates to:
  /// **'ينقص مع كل «أخذتُها» بقدر الجرعة'**
  String get medsStockHint;

  /// No description provided for @medsFieldColor.
  ///
  /// In ar, this message translates to:
  /// **'اللون'**
  String get medsFieldColor;

  /// No description provided for @medsFieldActive.
  ///
  /// In ar, this message translates to:
  /// **'نشط'**
  String get medsFieldActive;

  /// No description provided for @medsFieldActiveHint.
  ///
  /// In ar, this message translates to:
  /// **'أوقفه مؤقتًا دون أن تفقد سجلّه'**
  String get medsFieldActiveHint;

  /// No description provided for @medsFieldCourse.
  ///
  /// In ar, this message translates to:
  /// **'الدورة العلاجية'**
  String get medsFieldCourse;

  /// No description provided for @medsNoCourse.
  ///
  /// In ar, this message translates to:
  /// **'بلا دورة'**
  String get medsNoCourse;

  /// No description provided for @medsCourseLinkedHint.
  ///
  /// In ar, this message translates to:
  /// **'جرعاته تتبع مراحل الدورة'**
  String get medsCourseLinkedHint;

  /// No description provided for @medsTitration.
  ///
  /// In ar, this message translates to:
  /// **'جدول التدرّج'**
  String get medsTitration;

  /// No description provided for @medsTitrationHint.
  ///
  /// In ar, this message translates to:
  /// **'الجرعة التي حدّدها طبيبك لكل فترة، من تاريخ إلى آخر'**
  String get medsTitrationHint;

  /// No description provided for @medsTitrationAdd.
  ///
  /// In ar, this message translates to:
  /// **'خطوة جديدة'**
  String get medsTitrationAdd;

  /// No description provided for @medsTitrationFrom.
  ///
  /// In ar, this message translates to:
  /// **'من {date}'**
  String medsTitrationFrom(String date);

  /// No description provided for @medsTitrationStop.
  ///
  /// In ar, this message translates to:
  /// **'توقّف'**
  String get medsTitrationStop;

  /// No description provided for @medsTitrationStopLine.
  ///
  /// In ar, this message translates to:
  /// **'تتوقف الجرعات'**
  String get medsTitrationStopLine;

  /// No description provided for @medsTitrationStepDose.
  ///
  /// In ar, this message translates to:
  /// **'الجرعة من هذا التاريخ'**
  String get medsTitrationStepDose;

  /// No description provided for @medsTitrationStepTitle.
  ///
  /// In ar, this message translates to:
  /// **'خطوة تدرّج'**
  String get medsTitrationStepTitle;

  /// No description provided for @medsTitrationNow.
  ///
  /// In ar, this message translates to:
  /// **'الحالية'**
  String get medsTitrationNow;

  /// No description provided for @medsSave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get medsSave;

  /// No description provided for @medsDelete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get medsDelete;

  /// No description provided for @medsMore.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل إضافية'**
  String get medsMore;

  /// No description provided for @medsTodayHeader.
  ///
  /// In ar, this message translates to:
  /// **'جرعات اليوم'**
  String get medsTodayHeader;

  /// No description provided for @medsTodayCount.
  ///
  /// In ar, this message translates to:
  /// **'أُخذت {taken} من {total}'**
  String medsTodayCount(String taken, String total);

  /// No description provided for @medsNextDose.
  ///
  /// In ar, this message translates to:
  /// **'التالية: {name} · {time}'**
  String medsNextDose(String name, String time);

  /// No description provided for @medsDueNowCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{جرعة تنتظرك الآن} =2{جرعتان تنتظرانك الآن} few{{count} جرعات تنتظرك الآن} many{{count} جرعة تنتظرك الآن} other{{count} جرعة تنتظرك الآن}}'**
  String medsDueNowCount(int count);

  /// No description provided for @medsAllAnswered.
  ///
  /// In ar, this message translates to:
  /// **'أجبتَ عن كل جرعات اليوم'**
  String get medsAllAnswered;

  /// No description provided for @medsNoDosesToday.
  ///
  /// In ar, this message translates to:
  /// **'لا جرعات مجدولة اليوم'**
  String get medsNoDosesToday;

  /// No description provided for @medsEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا أدوية بعد'**
  String get medsEmptyTitle;

  /// No description provided for @medsEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'أضف دواءً أو مكمّلًا بمواعيده، وسيرتّب مَدار جرعاتك حول صلواتك ووجباتك.'**
  String get medsEmptyBody;

  /// No description provided for @medsAsNeeded.
  ///
  /// In ar, this message translates to:
  /// **'عند الحاجة'**
  String get medsAsNeeded;

  /// No description provided for @medsLogNow.
  ///
  /// In ar, this message translates to:
  /// **'سجّل جرعة الآن'**
  String get medsLogNow;

  /// No description provided for @medsAnytimeGroup.
  ///
  /// In ar, this message translates to:
  /// **'بلا نافذة'**
  String get medsAnytimeGroup;

  /// No description provided for @medsStateUpcoming.
  ///
  /// In ar, this message translates to:
  /// **'قادمة'**
  String get medsStateUpcoming;

  /// No description provided for @medsStateDue.
  ///
  /// In ar, this message translates to:
  /// **'حان وقتها'**
  String get medsStateDue;

  /// No description provided for @medsStateLate.
  ///
  /// In ar, this message translates to:
  /// **'متأخرة'**
  String get medsStateLate;

  /// No description provided for @medsStateMissed.
  ///
  /// In ar, this message translates to:
  /// **'فاتت'**
  String get medsStateMissed;

  /// No description provided for @medsStateTakenAt.
  ///
  /// In ar, this message translates to:
  /// **'أُخذت {time}'**
  String medsStateTakenAt(String time);

  /// No description provided for @medsStateSkipped.
  ///
  /// In ar, this message translates to:
  /// **'تُخطّيت'**
  String get medsStateSkipped;

  /// No description provided for @medsStateSnoozedUntil.
  ///
  /// In ar, this message translates to:
  /// **'مؤجّلة حتى {time}'**
  String medsStateSnoozedUntil(String time);

  /// No description provided for @medsTake.
  ///
  /// In ar, this message translates to:
  /// **'أخذتُها'**
  String get medsTake;

  /// No description provided for @medsSnooze.
  ///
  /// In ar, this message translates to:
  /// **'غفوة'**
  String get medsSnooze;

  /// No description provided for @medsSnoozeFor.
  ///
  /// In ar, this message translates to:
  /// **'غفوة {duration}'**
  String medsSnoozeFor(String duration);

  /// No description provided for @medsSkip.
  ///
  /// In ar, this message translates to:
  /// **'تخطّي'**
  String get medsSkip;

  /// No description provided for @medsReset.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الإجابة'**
  String get medsReset;

  /// No description provided for @medsTookToast.
  ///
  /// In ar, this message translates to:
  /// **'سُجّلت جرعة {name}'**
  String medsTookToast(String name);

  /// No description provided for @medsSkippedToast.
  ///
  /// In ar, this message translates to:
  /// **'تُخطّيت جرعة {name}'**
  String medsSkippedToast(String name);

  /// No description provided for @medsSnoozedToast.
  ///
  /// In ar, this message translates to:
  /// **'جرعة {name} مؤجّلة حتى {time}'**
  String medsSnoozedToast(String name, String time);

  /// No description provided for @medsResetToast.
  ///
  /// In ar, this message translates to:
  /// **'أُلغيت الإجابة'**
  String get medsResetToast;

  /// No description provided for @medsShiftedLater.
  ///
  /// In ar, this message translates to:
  /// **'أُخّرت {duration} لقاعدة توقيت'**
  String medsShiftedLater(String duration);

  /// No description provided for @medsShiftedEarlier.
  ///
  /// In ar, this message translates to:
  /// **'قُدّمت {duration} لقاعدة توقيت'**
  String medsShiftedEarlier(String duration);

  /// No description provided for @medsPinnedToMeal.
  ///
  /// In ar, this message translates to:
  /// **'على موعد الطعام'**
  String get medsPinnedToMeal;

  /// No description provided for @medsPastMidnight.
  ///
  /// In ar, this message translates to:
  /// **'بعد منتصف الليل'**
  String get medsPastMidnight;

  /// No description provided for @medsPartOfCourse.
  ///
  /// In ar, this message translates to:
  /// **'ضمن {name}'**
  String medsPartOfCourse(String name);

  /// No description provided for @medsDoseSemantics.
  ///
  /// In ar, this message translates to:
  /// **'{name}، {dose}، {time}، {state}'**
  String medsDoseSemantics(String name, String dose, String time, String state);

  /// No description provided for @medsRefillBanner.
  ///
  /// In ar, this message translates to:
  /// **'بقي {count} من {name} — حان وقت إعادة التعبئة'**
  String medsRefillBanner(String name, String count);

  /// No description provided for @medsRefilled.
  ///
  /// In ar, this message translates to:
  /// **'أعدتُ التعبئة'**
  String get medsRefilled;

  /// No description provided for @medsRefillSheetTitle.
  ///
  /// In ar, this message translates to:
  /// **'إعادة تعبئة {name}'**
  String medsRefillSheetTitle(String name);

  /// No description provided for @medsRefillAdded.
  ///
  /// In ar, this message translates to:
  /// **'الوحدات المضافة'**
  String get medsRefillAdded;

  /// No description provided for @medsStockUpdated.
  ///
  /// In ar, this message translates to:
  /// **'حُدّث المتبقي من {name}'**
  String medsStockUpdated(String name);

  /// No description provided for @medsStockLine.
  ///
  /// In ar, this message translates to:
  /// **'المتبقي {count}'**
  String medsStockLine(String count);

  /// No description provided for @medsRefillAtLine.
  ///
  /// In ar, this message translates to:
  /// **'التنبيه عند {count}'**
  String medsRefillAtLine(String count);

  /// No description provided for @medsLowStock.
  ///
  /// In ar, this message translates to:
  /// **'قارب على النفاد'**
  String get medsLowStock;

  /// No description provided for @medsConflictsTitle.
  ///
  /// In ar, this message translates to:
  /// **'قواعد لم تتحقق'**
  String get medsConflictsTitle;

  /// No description provided for @medsConflictSeparation.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر ترك {required} بين {a} و{b}؛ الفاصل الآن {actual}.'**
  String medsConflictSeparation(
    String a,
    String b,
    String required,
    String actual,
  );

  /// No description provided for @medsConflictNoMeal.
  ///
  /// In ar, this message translates to:
  /// **'لا وجبة متاحة لجرعة إضافية من {name}؛ بقيت في موعدها.'**
  String medsConflictNoMeal(String name);

  /// No description provided for @medsConflictClash.
  ///
  /// In ar, this message translates to:
  /// **'لدى {name} قاعدتا طعام مختلفتان؛ طُبّقت الأولى.'**
  String medsConflictClash(String name);

  /// No description provided for @medsAtTheSameTime.
  ///
  /// In ar, this message translates to:
  /// **'في الوقت نفسه'**
  String get medsAtTheSameTime;

  /// No description provided for @medsAlertsTitle.
  ///
  /// In ar, this message translates to:
  /// **'تنبيهات دائمة'**
  String get medsAlertsTitle;

  /// No description provided for @medsAdherence.
  ///
  /// In ar, this message translates to:
  /// **'الالتزام'**
  String get medsAdherence;

  /// No description provided for @medsAdherenceRate.
  ///
  /// In ar, this message translates to:
  /// **'أُخذت {percent} من الجرعات'**
  String medsAdherenceRate(String percent);

  /// No description provided for @medsLastDays.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{آخر يوم} =2{آخر يومين} few{آخر {count} أيام} many{آخر {count} يومًا} other{آخر {count} يوم}}'**
  String medsLastDays(int count);

  /// No description provided for @medsNoAdherence.
  ///
  /// In ar, this message translates to:
  /// **'لا جرعات مستحقة في هذه الفترة'**
  String get medsNoAdherence;

  /// No description provided for @medsStatTaken.
  ///
  /// In ar, this message translates to:
  /// **'أُخذت'**
  String get medsStatTaken;

  /// No description provided for @medsStatSkipped.
  ///
  /// In ar, this message translates to:
  /// **'تُخطّيت'**
  String get medsStatSkipped;

  /// No description provided for @medsStatMissed.
  ///
  /// In ar, this message translates to:
  /// **'فاتت'**
  String get medsStatMissed;

  /// No description provided for @medsStatLate.
  ///
  /// In ar, this message translates to:
  /// **'متأخرة'**
  String get medsStatLate;

  /// No description provided for @medsStreakDays.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا أيام كاملة متتالية بعد} =1{يوم كامل} =2{يومان كاملان متتاليان} few{{count} أيام كاملة متتالية} many{{count} يومًا كاملًا متتاليًا} other{{count} يوم كامل متتالٍ}}'**
  String medsStreakDays(int count);

  /// No description provided for @medsDayBarSemantics.
  ///
  /// In ar, this message translates to:
  /// **'{date}: {taken} من {total}'**
  String medsDayBarSemantics(String date, String taken, String total);

  /// No description provided for @medsDayNothingDue.
  ///
  /// In ar, this message translates to:
  /// **'{date}: لا جرعات'**
  String medsDayNothingDue(String date);

  /// No description provided for @medsHistory.
  ///
  /// In ar, this message translates to:
  /// **'السجل'**
  String get medsHistory;

  /// No description provided for @medsHistoryTitle.
  ///
  /// In ar, this message translates to:
  /// **'سجل {name}'**
  String medsHistoryTitle(String name);

  /// No description provided for @medsNoHistory.
  ///
  /// In ar, this message translates to:
  /// **'لا سجل بعد'**
  String get medsNoHistory;

  /// No description provided for @medsOffSchedule.
  ///
  /// In ar, this message translates to:
  /// **'خارج المواعيد'**
  String get medsOffSchedule;

  /// No description provided for @medsRecent.
  ///
  /// In ar, this message translates to:
  /// **'آخر الجرعات'**
  String get medsRecent;

  /// No description provided for @medsPaused.
  ///
  /// In ar, this message translates to:
  /// **'متوقف مؤقتًا'**
  String get medsPaused;

  /// No description provided for @medsPausedSection.
  ///
  /// In ar, this message translates to:
  /// **'متوقفة مؤقتًا'**
  String get medsPausedSection;

  /// No description provided for @medsPause.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف مؤقت'**
  String get medsPause;

  /// No description provided for @medsResume.
  ///
  /// In ar, this message translates to:
  /// **'استئناف'**
  String get medsResume;

  /// No description provided for @medsDuplicate.
  ///
  /// In ar, this message translates to:
  /// **'نسخ'**
  String get medsDuplicate;

  /// No description provided for @medsEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get medsEdit;

  /// No description provided for @medsDeletedToast.
  ///
  /// In ar, this message translates to:
  /// **'حُذف {name}'**
  String medsDeletedToast(String name);

  /// No description provided for @medsPausedToast.
  ///
  /// In ar, this message translates to:
  /// **'أُوقف {name} مؤقتًا'**
  String medsPausedToast(String name);

  /// No description provided for @medsResumedToast.
  ///
  /// In ar, this message translates to:
  /// **'استُؤنف {name}'**
  String medsResumedToast(String name);

  /// No description provided for @medsDuplicatedToast.
  ///
  /// In ar, this message translates to:
  /// **'نُسخ {name}'**
  String medsDuplicatedToast(String name);

  /// No description provided for @medsCopyName.
  ///
  /// In ar, this message translates to:
  /// **'{name} (نسخة)'**
  String medsCopyName(String name);

  /// No description provided for @medsTimesPerDay.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{بلا مواعيد} =1{مرة يوميًا} =2{مرتان يوميًا} few{{count} مرات يوميًا} many{{count} مرة يوميًا} other{{count} مرة يوميًا}}'**
  String medsTimesPerDay(int count);

  /// No description provided for @medsRulesTitle.
  ///
  /// In ar, this message translates to:
  /// **'قواعد التوقيت'**
  String get medsRulesTitle;

  /// No description provided for @medsRulesEmpty.
  ///
  /// In ar, this message translates to:
  /// **'القواعد تُبقي الجرعات على التوقيت الذي حدّدتَه: فاصل بين دواءين، أو موعد قبل الطعام أو بعده.'**
  String get medsRulesEmpty;

  /// No description provided for @medsRuleKindSeparate.
  ///
  /// In ar, this message translates to:
  /// **'فاصل بين دواءين'**
  String get medsRuleKindSeparate;

  /// No description provided for @medsRuleKindNotWith.
  ///
  /// In ar, this message translates to:
  /// **'لا يؤخذان معًا'**
  String get medsRuleKindNotWith;

  /// No description provided for @medsRuleKindBeforeFood.
  ///
  /// In ar, this message translates to:
  /// **'قبل الطعام'**
  String get medsRuleKindBeforeFood;

  /// No description provided for @medsRuleKindAfterFood.
  ///
  /// In ar, this message translates to:
  /// **'بعد الطعام'**
  String get medsRuleKindAfterFood;

  /// No description provided for @medsRuleKindWithFood.
  ///
  /// In ar, this message translates to:
  /// **'مع الطعام'**
  String get medsRuleKindWithFood;

  /// No description provided for @medsRuleKindCustom.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة'**
  String get medsRuleKindCustom;

  /// No description provided for @medsRuleSeparateText.
  ///
  /// In ar, this message translates to:
  /// **'{duration} على الأقل بين {a} و{b}'**
  String medsRuleSeparateText(String a, String b, String duration);

  /// No description provided for @medsRuleBeforeFoodText.
  ///
  /// In ar, this message translates to:
  /// **'{a} قبل الطعام بـ{duration}'**
  String medsRuleBeforeFoodText(String a, String duration);

  /// No description provided for @medsRuleAfterFoodText.
  ///
  /// In ar, this message translates to:
  /// **'{a} بعد الطعام بـ{duration}'**
  String medsRuleAfterFoodText(String a, String duration);

  /// No description provided for @medsRuleWithFoodText.
  ///
  /// In ar, this message translates to:
  /// **'{a} مع الطعام'**
  String medsRuleWithFoodText(String a);

  /// No description provided for @medsRuleCustomText.
  ///
  /// In ar, this message translates to:
  /// **'{a}: {note}'**
  String medsRuleCustomText(String a, String note);

  /// No description provided for @medsRuleEditorNew.
  ///
  /// In ar, this message translates to:
  /// **'قاعدة توقيت جديدة'**
  String get medsRuleEditorNew;

  /// No description provided for @medsRuleEditorEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل القاعدة'**
  String get medsRuleEditorEdit;

  /// No description provided for @medsRuleKind.
  ///
  /// In ar, this message translates to:
  /// **'نوع القاعدة'**
  String get medsRuleKind;

  /// No description provided for @medsRuleMedA.
  ///
  /// In ar, this message translates to:
  /// **'الدواء'**
  String get medsRuleMedA;

  /// No description provided for @medsRuleMedB.
  ///
  /// In ar, this message translates to:
  /// **'والدواء الآخر'**
  String get medsRuleMedB;

  /// No description provided for @medsRuleMinutes.
  ///
  /// In ar, this message translates to:
  /// **'المدة'**
  String get medsRuleMinutes;

  /// No description provided for @medsRuleNote.
  ///
  /// In ar, this message translates to:
  /// **'الملاحظة'**
  String get medsRuleNote;

  /// No description provided for @medsRuleNeedTwo.
  ///
  /// In ar, this message translates to:
  /// **'اختر دواءين مختلفين'**
  String get medsRuleNeedTwo;

  /// No description provided for @medsRuleNeedMed.
  ///
  /// In ar, this message translates to:
  /// **'اختر الدواء'**
  String get medsRuleNeedMed;

  /// No description provided for @medsRuleNeedMeds.
  ///
  /// In ar, this message translates to:
  /// **'أضف دواءً أولًا'**
  String get medsRuleNeedMeds;

  /// No description provided for @medsRuleNeedNote.
  ///
  /// In ar, this message translates to:
  /// **'اكتب الملاحظة'**
  String get medsRuleNeedNote;

  /// No description provided for @medsRuleFoodHint.
  ///
  /// In ar, this message translates to:
  /// **'أوقات الطعام من «أوقات الوجبات» في الإعدادات'**
  String get medsRuleFoodHint;

  /// No description provided for @medsRuleDeleted.
  ///
  /// In ar, this message translates to:
  /// **'حُذفت القاعدة'**
  String get medsRuleDeleted;

  /// No description provided for @medsCoursesEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا دورات علاجية'**
  String get medsCoursesEmptyTitle;

  /// No description provided for @medsCoursesEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'للحقن والعلاجات على مراحل، مثل: يوميًا، ثم أسبوعيًا، ثم شهريًا.'**
  String get medsCoursesEmptyBody;

  /// No description provided for @medsCourseEditorNew.
  ///
  /// In ar, this message translates to:
  /// **'دورة علاجية جديدة'**
  String get medsCourseEditorNew;

  /// No description provided for @medsCourseEditorEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الدورة'**
  String get medsCourseEditorEdit;

  /// No description provided for @medsCourseName.
  ///
  /// In ar, this message translates to:
  /// **'اسم الدورة'**
  String get medsCourseName;

  /// No description provided for @medsCourseNameRequired.
  ///
  /// In ar, this message translates to:
  /// **'اكتب اسم الدورة'**
  String get medsCourseNameRequired;

  /// No description provided for @medsCourseMed.
  ///
  /// In ar, this message translates to:
  /// **'الدواء'**
  String get medsCourseMed;

  /// No description provided for @medsCourseStart.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ البدء'**
  String get medsCourseStart;

  /// No description provided for @medsCoursePhases.
  ///
  /// In ar, this message translates to:
  /// **'المراحل'**
  String get medsCoursePhases;

  /// No description provided for @medsCourseAddPhase.
  ///
  /// In ar, this message translates to:
  /// **'مرحلة جديدة'**
  String get medsCourseAddPhase;

  /// No description provided for @medsCoursePhaseN.
  ///
  /// In ar, this message translates to:
  /// **'المرحلة {n}'**
  String medsCoursePhaseN(String n);

  /// No description provided for @medsCourseNeedsPhase.
  ///
  /// In ar, this message translates to:
  /// **'أضف مرحلة واحدة على الأقل'**
  String get medsCourseNeedsPhase;

  /// No description provided for @medsFreqDaily.
  ///
  /// In ar, this message translates to:
  /// **'يومي'**
  String get medsFreqDaily;

  /// No description provided for @medsFreqWeekly.
  ///
  /// In ar, this message translates to:
  /// **'أسبوعي'**
  String get medsFreqWeekly;

  /// No description provided for @medsFreqMonthly.
  ///
  /// In ar, this message translates to:
  /// **'شهري'**
  String get medsFreqMonthly;

  /// No description provided for @medsEveryDays.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{يوميًا} =2{كل يومين} few{كل {count} أيام} many{كل {count} يومًا} other{كل {count} يوم}}'**
  String medsEveryDays(int count);

  /// No description provided for @medsEveryWeeks.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{أسبوعيًا} =2{كل أسبوعين} few{كل {count} أسابيع} many{كل {count} أسبوعًا} other{كل {count} أسبوع}}'**
  String medsEveryWeeks(int count);

  /// No description provided for @medsEveryMonths.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{شهريًا} =2{كل شهرين} few{كل {count} أشهر} many{كل {count} شهرًا} other{كل {count} شهر}}'**
  String medsEveryMonths(int count);

  /// No description provided for @medsPhaseInterval.
  ///
  /// In ar, this message translates to:
  /// **'كل'**
  String get medsPhaseInterval;

  /// No description provided for @medsPhaseCount.
  ///
  /// In ar, this message translates to:
  /// **'عدد الجرعات'**
  String get medsPhaseCount;

  /// No description provided for @medsPhaseOngoing.
  ///
  /// In ar, this message translates to:
  /// **'مستمرة'**
  String get medsPhaseOngoing;

  /// No description provided for @medsPhaseDose.
  ///
  /// In ar, this message translates to:
  /// **'جرعة المرحلة'**
  String get medsPhaseDose;

  /// No description provided for @medsPhaseTimes.
  ///
  /// In ar, this message translates to:
  /// **'{freq} × {count}'**
  String medsPhaseTimes(String freq, String count);

  /// No description provided for @medsPhaseOngoingLine.
  ///
  /// In ar, this message translates to:
  /// **'{freq} باستمرار'**
  String medsPhaseOngoingLine(String freq);

  /// No description provided for @medsCourseDoneOf.
  ///
  /// In ar, this message translates to:
  /// **'{done} من {total} جرعة'**
  String medsCourseDoneOf(String done, String total);

  /// No description provided for @medsCourseDosesSoFar.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لم تبدأ الجرعات} =1{جرعة واحدة حتى الآن} =2{جرعتان حتى الآن} few{{count} جرعات حتى الآن} many{{count} جرعة حتى الآن} other{{count} جرعة حتى الآن}}'**
  String medsCourseDosesSoFar(int count);

  /// No description provided for @medsCoursePhaseProgress.
  ///
  /// In ar, this message translates to:
  /// **'المرحلة {phase}: {done} من {total}'**
  String medsCoursePhaseProgress(String phase, String done, String total);

  /// No description provided for @medsCoursePhaseOngoingProgress.
  ///
  /// In ar, this message translates to:
  /// **'المرحلة {phase} (مستمرة)'**
  String medsCoursePhaseOngoingProgress(String phase);

  /// No description provided for @medsCourseNext.
  ///
  /// In ar, this message translates to:
  /// **'الجرعة التالية {date}'**
  String medsCourseNext(String date);

  /// No description provided for @medsCourseStarts.
  ///
  /// In ar, this message translates to:
  /// **'تبدأ {date}'**
  String medsCourseStarts(String date);

  /// No description provided for @medsCourseFinished.
  ///
  /// In ar, this message translates to:
  /// **'اكتملت في {date}'**
  String medsCourseFinished(String date);

  /// No description provided for @medsCourseNoMed.
  ///
  /// In ar, this message translates to:
  /// **'اربطها بدواء لتظهر جرعاتها في اليوم'**
  String get medsCourseNoMed;

  /// No description provided for @medsCourseDeleted.
  ///
  /// In ar, this message translates to:
  /// **'حُذفت الدورة'**
  String get medsCourseDeleted;

  /// No description provided for @medsCoursePaused.
  ///
  /// In ar, this message translates to:
  /// **'متوقفة'**
  String get medsCoursePaused;

  /// No description provided for @medsCourseActive.
  ///
  /// In ar, this message translates to:
  /// **'الدورة نشطة'**
  String get medsCourseActive;

  /// No description provided for @medsCourseTimeline.
  ///
  /// In ar, this message translates to:
  /// **'مواعيد الدورة'**
  String get medsCourseTimeline;

  /// No description provided for @medsCourseMoreDates.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{وموعد آخر} =2{وموعدان آخران} few{و{count} مواعيد أخرى} many{و{count} موعدًا آخر} other{و{count} موعد آخر}}'**
  String medsCourseMoreDates(int count);

  /// No description provided for @medsToday.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get medsToday;

  /// No description provided for @medsSettingsTitle.
  ///
  /// In ar, this message translates to:
  /// **'إعدادات الأدوية'**
  String get medsSettingsTitle;

  /// No description provided for @medsMealTimes.
  ///
  /// In ar, this message translates to:
  /// **'أوقات الوجبات'**
  String get medsMealTimes;

  /// No description provided for @medsMealTimesHint.
  ///
  /// In ar, this message translates to:
  /// **'تربط «مع الفطور» وقواعد الطعام بيومك'**
  String get medsMealTimesHint;

  /// No description provided for @medsEmptyStomachLead.
  ///
  /// In ar, this message translates to:
  /// **'مدة «على الريق» قبل الفطور'**
  String get medsEmptyStomachLead;

  /// No description provided for @medsReminders.
  ///
  /// In ar, this message translates to:
  /// **'التذكير بالجرعات'**
  String get medsReminders;

  /// No description provided for @medsRemindersHint.
  ///
  /// In ar, this message translates to:
  /// **'إشعار في موعد كل جرعة، فيه: أخذتُها، غفوة، تخطّي'**
  String get medsRemindersHint;

  /// No description provided for @medsSnoozeDefault.
  ///
  /// In ar, this message translates to:
  /// **'غفوة الإشعار'**
  String get medsSnoozeDefault;

  /// No description provided for @medsLateAfter.
  ///
  /// In ar, this message translates to:
  /// **'تُعدّ متأخرة بعد'**
  String get medsLateAfter;

  /// No description provided for @medsNotifyGroup.
  ///
  /// In ar, this message translates to:
  /// **'الأدوية'**
  String get medsNotifyGroup;

  /// No description provided for @medsNotifyChannel.
  ///
  /// In ar, this message translates to:
  /// **'مواعيد الجرعات'**
  String get medsNotifyChannel;

  /// No description provided for @medsNotifyChannelDescription.
  ///
  /// In ar, this message translates to:
  /// **'تذكير في موعد كل جرعة، مع أزرار: أخذتُها، غفوة، تخطّي'**
  String get medsNotifyChannelDescription;

  /// No description provided for @medsNotifyTitle.
  ///
  /// In ar, this message translates to:
  /// **'حان موعد {name}'**
  String medsNotifyTitle(String name);

  /// No description provided for @medsNotifyAgainTitle.
  ///
  /// In ar, this message translates to:
  /// **'تذكير: {name}'**
  String medsNotifyAgainTitle(String name);

  /// No description provided for @medsNotifyRefillTitle.
  ///
  /// In ar, this message translates to:
  /// **'{name}: الكمية تقارب النفاد'**
  String medsNotifyRefillTitle(String name);

  /// No description provided for @medsNotifyRefillBody.
  ///
  /// In ar, this message translates to:
  /// **'بقي {count}. حان وقت إعادة التعبئة.'**
  String medsNotifyRefillBody(String count);

  /// No description provided for @medsNotifyFailedTitle.
  ///
  /// In ar, this message translates to:
  /// **'لم تُسجَّل الجرعة'**
  String get medsNotifyFailedTitle;

  /// No description provided for @medsNotifyFailedBody.
  ///
  /// In ar, this message translates to:
  /// **'افتح مَدار لتسجيلها.'**
  String get medsNotifyFailedBody;

  /// Medical record screen title
  ///
  /// In ar, this message translates to:
  /// **'السجل الطبي'**
  String get recordTitle;

  /// Record tab
  ///
  /// In ar, this message translates to:
  /// **'التحاليل'**
  String get recordTabLabs;

  /// Record tab
  ///
  /// In ar, this message translates to:
  /// **'المواعيد'**
  String get recordTabAppointments;

  /// Record tab
  ///
  /// In ar, this message translates to:
  /// **'الحالات'**
  String get recordTabConditions;

  /// Record tab
  ///
  /// In ar, this message translates to:
  /// **'الأسئلة'**
  String get recordTabQuestions;

  /// No description provided for @recordAdd.
  ///
  /// In ar, this message translates to:
  /// **'إضافة'**
  String get recordAdd;

  /// No description provided for @recordSave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get recordSave;

  /// No description provided for @recordDelete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get recordDelete;

  /// No description provided for @recordNotes.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات'**
  String get recordNotes;

  /// No description provided for @recordDate.
  ///
  /// In ar, this message translates to:
  /// **'التاريخ'**
  String get recordDate;

  /// No description provided for @recordTime.
  ///
  /// In ar, this message translates to:
  /// **'الوقت'**
  String get recordTime;

  /// Separator between list items (keep the trailing space)
  ///
  /// In ar, this message translates to:
  /// **'، '**
  String get recordListSeparator;

  /// No description provided for @recordToday.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get recordToday;

  /// No description provided for @recordTomorrow.
  ///
  /// In ar, this message translates to:
  /// **'غدًا'**
  String get recordTomorrow;

  /// No description provided for @recordYesterday.
  ///
  /// In ar, this message translates to:
  /// **'أمس'**
  String get recordYesterday;

  /// Relative future day; n = formatted count
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{بعد يوم} =2{بعد يومين} few{بعد {n} أيام} many{بعد {n} يومًا} other{بعد {n} يوم}}'**
  String recordInDays(int count, String n);

  /// Relative past day
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{قبل يوم} =2{قبل يومين} few{قبل {n} أيام} many{قبل {n} يومًا} other{قبل {n} يوم}}'**
  String recordDaysAgo(int count, String n);

  /// Action / sheet title: build the PDF for the doctor
  ///
  /// In ar, this message translates to:
  /// **'تقرير للطبيب'**
  String get recordDoctorReport;

  /// No description provided for @recordSettingsTitle.
  ///
  /// In ar, this message translates to:
  /// **'إعدادات السجل'**
  String get recordSettingsTitle;

  /// Lab flag: below the user's own low limit (neutral label)
  ///
  /// In ar, this message translates to:
  /// **'منخفض'**
  String get recordFlagLow;

  /// Lab flag: above the user's own high limit
  ///
  /// In ar, this message translates to:
  /// **'مرتفع'**
  String get recordFlagHigh;

  /// Short lab flag: within range but close to a limit
  ///
  /// In ar, this message translates to:
  /// **'حدّي'**
  String get recordFlagBorderline;

  /// Lab flag, full form
  ///
  /// In ar, this message translates to:
  /// **'قرب الحدّ الأدنى'**
  String get recordFlagBorderlineLow;

  /// Lab flag, full form
  ///
  /// In ar, this message translates to:
  /// **'قرب الحدّ الأعلى'**
  String get recordFlagBorderlineHigh;

  /// Lab flag: inside the user's own range
  ///
  /// In ar, this message translates to:
  /// **'ضمن المدى'**
  String get recordFlagInRange;

  /// Lab flag: test has no reference range
  ///
  /// In ar, this message translates to:
  /// **'بلا مدى'**
  String get recordFlagNoRange;

  /// Lab flag: a qualitative (text) result
  ///
  /// In ar, this message translates to:
  /// **'وصفية'**
  String get recordFlagQualitative;

  /// Standing alert importance
  ///
  /// In ar, this message translates to:
  /// **'بالغ الأهمية'**
  String get recordSeverityCritical;

  /// Standing alert importance
  ///
  /// In ar, this message translates to:
  /// **'تنبيه'**
  String get recordSeverityWarning;

  /// Standing alert importance
  ///
  /// In ar, this message translates to:
  /// **'للعلم'**
  String get recordSeverityInfo;

  /// Reference range
  ///
  /// In ar, this message translates to:
  /// **'{low} – {high}'**
  String recordRangeBetween(String low, String high);

  /// Reference range with only a high limit
  ///
  /// In ar, this message translates to:
  /// **'حتى {high}'**
  String recordRangeUpTo(String high);

  /// Reference range with only a low limit
  ///
  /// In ar, this message translates to:
  /// **'من {low} فأكثر'**
  String recordRangeAtLeast(String low);

  /// No description provided for @recordTakenWithEmptyStomach.
  ///
  /// In ar, this message translates to:
  /// **'على معدة فارغة'**
  String get recordTakenWithEmptyStomach;

  /// No description provided for @recordTakenWithBreakfast.
  ///
  /// In ar, this message translates to:
  /// **'مع الفطور'**
  String get recordTakenWithBreakfast;

  /// No description provided for @recordTakenWithLunch.
  ///
  /// In ar, this message translates to:
  /// **'مع الغداء'**
  String get recordTakenWithLunch;

  /// No description provided for @recordTakenWithDinner.
  ///
  /// In ar, this message translates to:
  /// **'مع العشاء'**
  String get recordTakenWithDinner;

  /// No description provided for @recordTakenWithBedtime.
  ///
  /// In ar, this message translates to:
  /// **'قبل النوم'**
  String get recordTakenWithBedtime;

  /// No description provided for @recordTakenWithOther.
  ///
  /// In ar, this message translates to:
  /// **'أخرى'**
  String get recordTakenWithOther;

  /// No description provided for @recordTakenWithPerCourse.
  ///
  /// In ar, this message translates to:
  /// **'حسب الكورس'**
  String get recordTakenWithPerCourse;

  /// No description provided for @recordTakenWithAnytime.
  ///
  /// In ar, this message translates to:
  /// **'في أي وقت'**
  String get recordTakenWithAnytime;

  /// Period chip
  ///
  /// In ar, this message translates to:
  /// **'شهر'**
  String get recordPeriod1m;

  /// Period chip: the last n months
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{شهر} =2{شهران} few{{n} أشهر} many{{n} شهرًا} other{{n} شهر}}'**
  String recordPeriodMonths(int count, String n);

  /// Period chip
  ///
  /// In ar, this message translates to:
  /// **'سنة'**
  String get recordPeriod12m;

  /// Period chip: every reading
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get recordPeriodAll;

  /// No description provided for @recordSectionAlerts.
  ///
  /// In ar, this message translates to:
  /// **'تنبيهات دائمة'**
  String get recordSectionAlerts;

  /// No description provided for @recordSectionConditions.
  ///
  /// In ar, this message translates to:
  /// **'الحالات الصحية'**
  String get recordSectionConditions;

  /// No description provided for @recordSectionMedications.
  ///
  /// In ar, this message translates to:
  /// **'الأدوية والمكمّلات الحالية'**
  String get recordSectionMedications;

  /// No description provided for @recordSectionLabs.
  ///
  /// In ar, this message translates to:
  /// **'نتائج التحاليل'**
  String get recordSectionLabs;

  /// No description provided for @recordSectionPain.
  ///
  /// In ar, this message translates to:
  /// **'ملخّص الألم'**
  String get recordSectionPain;

  /// No description provided for @recordSectionMood.
  ///
  /// In ar, this message translates to:
  /// **'ملخّص المزاج والتوتر'**
  String get recordSectionMood;

  /// No description provided for @recordSectionQuestions.
  ///
  /// In ar, this message translates to:
  /// **'أسئلة للطبيب'**
  String get recordSectionQuestions;

  /// Reminder offset
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{قبل أسبوع} =2{قبل أسبوعين} few{قبل {n} أسابيع} many{قبل {n} أسبوعًا} other{قبل {n} أسبوع}}'**
  String recordOffsetWeeks(int count, String n);

  /// Reminder offset
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{قبل يوم} =2{قبل يومين} few{قبل {n} أيام} many{قبل {n} يومًا} other{قبل {n} يوم}}'**
  String recordOffsetDays(int count, String n);

  /// Reminder offset
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{قبل ساعة} =2{قبل ساعتين} few{قبل {n} ساعات} many{قبل {n} ساعة} other{قبل {n} ساعة}}'**
  String recordOffsetHours(int count, String n);

  /// Reminder offset
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{قبل دقيقة} =2{قبل دقيقتين} few{قبل {n} دقائق} many{قبل {n} دقيقة} other{قبل {n} دقيقة}}'**
  String recordOffsetMinutes(int count, String n);

  /// PDF title
  ///
  /// In ar, this message translates to:
  /// **'ملخّص صحي للطبيب'**
  String get recordReportTitle;

  /// PDF header label
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get recordReportNameLabel;

  /// PDF header
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الإعداد {date}'**
  String recordReportGenerated(String date);

  /// PDF header
  ///
  /// In ar, this message translates to:
  /// **'الفترة من {from} إلى {to}'**
  String recordReportPeriodLine(String from, String to);

  /// PDF header
  ///
  /// In ar, this message translates to:
  /// **'السجل كاملًا حتى {date}'**
  String recordReportPeriodAll(String date);

  /// PDF footer
  ///
  /// In ar, this message translates to:
  /// **'سجلّ شخصي يدوّنه صاحبه على جهازه. لا يتضمّن تشخيصًا ولا توصية علاجية.'**
  String get recordReportFooter;

  /// PDF footer
  ///
  /// In ar, this message translates to:
  /// **'صفحة {page} من {total}'**
  String recordReportPage(String page, String total);

  /// No description provided for @recordReportNothing.
  ///
  /// In ar, this message translates to:
  /// **'لا شيء مسجّل لهذه الفترة.'**
  String get recordReportNothing;

  /// No description provided for @recordConditionSince.
  ///
  /// In ar, this message translates to:
  /// **'منذ {date}'**
  String recordConditionSince(String date);

  /// Medication table column
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get recordReportColName;

  /// Medication table column
  ///
  /// In ar, this message translates to:
  /// **'الجرعة'**
  String get recordReportColDose;

  /// Medication table column
  ///
  /// In ar, this message translates to:
  /// **'المواعيد'**
  String get recordReportColTimes;

  /// Medication table column (with food / bedtime …)
  ///
  /// In ar, this message translates to:
  /// **'طريقة الأخذ'**
  String get recordReportColWith;

  /// Medication table: a supplement
  ///
  /// In ar, this message translates to:
  /// **'{name} – مكمّل'**
  String recordReportSupplementName(String name);

  /// Lab table column
  ///
  /// In ar, this message translates to:
  /// **'التحليل'**
  String get recordReportColTest;

  /// Lab table column
  ///
  /// In ar, this message translates to:
  /// **'آخر نتيجة'**
  String get recordReportColLatest;

  /// Lab table column
  ///
  /// In ar, this message translates to:
  /// **'المدى المرجعي'**
  String get recordReportColRange;

  /// Lab table column (sparkline)
  ///
  /// In ar, this message translates to:
  /// **'المسار'**
  String get recordReportColTrend;

  /// Lab table column
  ///
  /// In ar, this message translates to:
  /// **'نتائج سابقة'**
  String get recordReportColHistory;

  /// PDF lab legend
  ///
  /// In ar, this message translates to:
  /// **'تُقارَن كل نتيجة بالمدى المرجعي الذي أدخلتُه للتحليل. «حدّي» تعني ضمن المدى وعلى بُعد {margin} من عرضه عن أحد الحدّين.'**
  String recordReportLabLegend(String margin);

  /// No description provided for @recordReportEntries.
  ///
  /// In ar, this message translates to:
  /// **'عدد التسجيلات'**
  String get recordReportEntries;

  /// No description provided for @recordReportDaysLogged.
  ///
  /// In ar, this message translates to:
  /// **'أيام فيها تسجيل'**
  String get recordReportDaysLogged;

  /// No description provided for @recordReportPainAverage.
  ///
  /// In ar, this message translates to:
  /// **'متوسط الشدة من {max}'**
  String recordReportPainAverage(String max);

  /// No description provided for @recordReportPainHighest.
  ///
  /// In ar, this message translates to:
  /// **'أعلى شدة سُجّلت'**
  String get recordReportPainHighest;

  /// No description provided for @recordReportTopLocations.
  ///
  /// In ar, this message translates to:
  /// **'أكثر المواضع تكرارًا'**
  String get recordReportTopLocations;

  /// No description provided for @recordReportTopTriggers.
  ///
  /// In ar, this message translates to:
  /// **'أكثر المحفّزات تكرارًا'**
  String get recordReportTopTriggers;

  /// No description provided for @recordReportMoodAverage.
  ///
  /// In ar, this message translates to:
  /// **'متوسط المزاج من {max}'**
  String recordReportMoodAverage(String max);

  /// No description provided for @recordReportStressAverage.
  ///
  /// In ar, this message translates to:
  /// **'متوسط التوتر من {max}'**
  String recordReportStressAverage(String max);

  /// No description provided for @recordReportAnxietyAverage.
  ///
  /// In ar, this message translates to:
  /// **'متوسط القلق من {max}'**
  String recordReportAnxietyAverage(String max);

  /// No description provided for @recordReportEnergyAverage.
  ///
  /// In ar, this message translates to:
  /// **'متوسط الطاقة من {max}'**
  String recordReportEnergyAverage(String max);

  /// No description provided for @recordReportSleepAverage.
  ///
  /// In ar, this message translates to:
  /// **'متوسط ساعات النوم'**
  String get recordReportSleepAverage;

  /// No description provided for @recordReportCaffeineAverage.
  ///
  /// In ar, this message translates to:
  /// **'متوسط أكواب الكافيين'**
  String get recordReportCaffeineAverage;

  /// No description provided for @recordReportTopFactors.
  ///
  /// In ar, this message translates to:
  /// **'العوامل الأكثر تكرارًا'**
  String get recordReportTopFactors;

  /// No description provided for @recordReportQuestionFor.
  ///
  /// In ar, this message translates to:
  /// **'لموعد {title} في {date}'**
  String recordReportQuestionFor(String title, String date);

  /// Lab category heading for tests without a category
  ///
  /// In ar, this message translates to:
  /// **'أخرى'**
  String get recordLabUncategorized;

  /// Notification title
  ///
  /// In ar, this message translates to:
  /// **'موعد طبي: {title}'**
  String recordReminderTitle(String title);

  /// Relative time until the appointment
  ///
  /// In ar, this message translates to:
  /// **'بعد {duration}'**
  String recordReminderIn(String duration);

  /// Notification channel group
  ///
  /// In ar, this message translates to:
  /// **'الصحة'**
  String get recordReminderGroup;

  /// Notification channel name
  ///
  /// In ar, this message translates to:
  /// **'مواعيد الطبيب'**
  String get recordReminderChannelName;

  /// Notification channel description
  ///
  /// In ar, this message translates to:
  /// **'تذكير قبل مواعيدك الطبية'**
  String get recordReminderChannelDescription;

  /// A day and a time, e.g. "Tuesday, 6 October at 10:30 AM"
  ///
  /// In ar, this message translates to:
  /// **'{date}، الساعة {time}'**
  String recordDateAtTime(String date, String time);

  /// No description provided for @recordSavedToast.
  ///
  /// In ar, this message translates to:
  /// **'حُفظت التعديلات'**
  String get recordSavedToast;

  /// No description provided for @recordReorder.
  ///
  /// In ar, this message translates to:
  /// **'ترتيب'**
  String get recordReorder;

  /// No description provided for @recordReorderDone.
  ///
  /// In ar, this message translates to:
  /// **'تمّ الترتيب'**
  String get recordReorderDone;

  /// No description provided for @recordReordered.
  ///
  /// In ar, this message translates to:
  /// **'تغيّر الترتيب'**
  String get recordReordered;

  /// No description provided for @recordAlertAdd.
  ///
  /// In ar, this message translates to:
  /// **'إضافة تنبيه دائم'**
  String get recordAlertAdd;

  /// No description provided for @recordAlertEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل التنبيه'**
  String get recordAlertEdit;

  /// No description provided for @recordAlertSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'ما يجب أن يعرفه أي طبيب قبل كل شيء'**
  String get recordAlertSubtitle;

  /// No description provided for @recordAlertBody.
  ///
  /// In ar, this message translates to:
  /// **'نص التنبيه'**
  String get recordAlertBody;

  /// No description provided for @recordAlertBodyHint.
  ///
  /// In ar, this message translates to:
  /// **'مثلًا: حساسية من البنسلين'**
  String get recordAlertBodyHint;

  /// No description provided for @recordAlertSeverity.
  ///
  /// In ar, this message translates to:
  /// **'الأهمية'**
  String get recordAlertSeverity;

  /// No description provided for @recordAlertPinned.
  ///
  /// In ar, this message translates to:
  /// **'مثبّت في أعلى صفحات الصحة'**
  String get recordAlertPinned;

  /// No description provided for @recordAlertPinnedHint.
  ///
  /// In ar, this message translates to:
  /// **'يظهر دائمًا فوق شاشات الصحة'**
  String get recordAlertPinnedHint;

  /// No description provided for @recordAlertUnpin.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء التثبيت'**
  String get recordAlertUnpin;

  /// No description provided for @recordAlertAdded.
  ///
  /// In ar, this message translates to:
  /// **'أُضيف التنبيه'**
  String get recordAlertAdded;

  /// No description provided for @recordAlertDeleted.
  ///
  /// In ar, this message translates to:
  /// **'حُذف التنبيه'**
  String get recordAlertDeleted;

  /// No description provided for @recordAlertPinnedToast.
  ///
  /// In ar, this message translates to:
  /// **'ثُبّت التنبيه في الأعلى'**
  String get recordAlertPinnedToast;

  /// No description provided for @recordAlertUnpinnedToast.
  ///
  /// In ar, this message translates to:
  /// **'أُلغي تثبيت التنبيه'**
  String get recordAlertUnpinnedToast;

  /// No description provided for @recordAlertsManage.
  ///
  /// In ar, this message translates to:
  /// **'إدارة'**
  String get recordAlertsManage;

  /// No description provided for @recordAlertsManagerSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'اسحب لترتيبها، وثبّت ما تريد رؤيته دائمًا'**
  String get recordAlertsManagerSubtitle;

  /// No description provided for @recordAlertsEmptyHint.
  ///
  /// In ar, this message translates to:
  /// **'حساسية، أو دواء لا يناسبك، أو معلومة يجب ألّا تغيب عن أي طبيب.'**
  String get recordAlertsEmptyHint;

  /// Pill under the banner
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{تنبيه آخر} =2{تنبيهان آخران} few{{n} تنبيهات أخرى} many{{n} تنبيهًا آخر} other{{n} تنبيه آخر}}'**
  String recordAlertsMore(int count, String n);

  /// No description provided for @recordConditionAdd.
  ///
  /// In ar, this message translates to:
  /// **'إضافة حالة'**
  String get recordConditionAdd;

  /// No description provided for @recordConditionEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الحالة'**
  String get recordConditionEdit;

  /// No description provided for @recordConditionName.
  ///
  /// In ar, this message translates to:
  /// **'الحالة'**
  String get recordConditionName;

  /// No description provided for @recordConditionSinceLabel.
  ///
  /// In ar, this message translates to:
  /// **'منذ'**
  String get recordConditionSinceLabel;

  /// No description provided for @recordConditionActive.
  ///
  /// In ar, this message translates to:
  /// **'نشطة حاليًا'**
  String get recordConditionActive;

  /// No description provided for @recordConditionInactive.
  ///
  /// In ar, this message translates to:
  /// **'غير نشطة'**
  String get recordConditionInactive;

  /// No description provided for @recordConditionMarkInactive.
  ///
  /// In ar, this message translates to:
  /// **'تعليمها غير نشطة'**
  String get recordConditionMarkInactive;

  /// No description provided for @recordConditionMarkActive.
  ///
  /// In ar, this message translates to:
  /// **'تعليمها نشطة'**
  String get recordConditionMarkActive;

  /// No description provided for @recordConditionMarkedInactive.
  ///
  /// In ar, this message translates to:
  /// **'صارت الحالة غير نشطة'**
  String get recordConditionMarkedInactive;

  /// No description provided for @recordConditionMarkedActive.
  ///
  /// In ar, this message translates to:
  /// **'صارت الحالة نشطة'**
  String get recordConditionMarkedActive;

  /// No description provided for @recordConditionAdded.
  ///
  /// In ar, this message translates to:
  /// **'أُضيفت الحالة'**
  String get recordConditionAdded;

  /// No description provided for @recordConditionDeleted.
  ///
  /// In ar, this message translates to:
  /// **'حُذفت الحالة'**
  String get recordConditionDeleted;

  /// No description provided for @recordConditionsEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا حالات مسجّلة'**
  String get recordConditionsEmpty;

  /// No description provided for @recordConditionsEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'سجّل حالاتك الصحية مع تاريخ بدايتها وملاحظاتك، لتكون حاضرة في أي زيارة.'**
  String get recordConditionsEmptyBody;

  /// No description provided for @recordConditionsInactiveHeader.
  ///
  /// In ar, this message translates to:
  /// **'حالات غير نشطة'**
  String get recordConditionsInactiveHeader;

  /// No description provided for @recordLabVisit.
  ///
  /// In ar, this message translates to:
  /// **'زيارة مختبر'**
  String get recordLabVisit;

  /// No description provided for @recordLabVisitSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'نتائج عدة تحاليل بتاريخ واحد'**
  String get recordLabVisitSubtitle;

  /// No description provided for @recordLabVisitDate.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ التحاليل'**
  String get recordLabVisitDate;

  /// No description provided for @recordLabVisitSaveNone.
  ///
  /// In ar, this message translates to:
  /// **'أدخل نتيجة واحدة على الأقل'**
  String get recordLabVisitSaveNone;

  /// No description provided for @recordLabVisitSave.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{حفظ نتيجة واحدة} =2{حفظ نتيجتين} few{حفظ {n} نتائج} many{حفظ {n} نتيجة} other{حفظ {n} نتيجة}}'**
  String recordLabVisitSave(int count, String n);

  /// No description provided for @recordLabVisitSaved.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{حُفظت نتيجة واحدة} =2{حُفظت نتيجتان} few{حُفظت {n} نتائج} many{حُفظت {n} نتيجة} other{حُفظت {n} نتيجة}}'**
  String recordLabVisitSaved(int count, String n);

  /// No description provided for @recordLabAddTest.
  ///
  /// In ar, this message translates to:
  /// **'تحليل جديد'**
  String get recordLabAddTest;

  /// No description provided for @recordLabEditTest.
  ///
  /// In ar, this message translates to:
  /// **'تعديل التحليل'**
  String get recordLabEditTest;

  /// No description provided for @recordLabTestSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'اكتب المدى المرجعي كما في ورقة مختبرك'**
  String get recordLabTestSubtitle;

  /// No description provided for @recordLabTestName.
  ///
  /// In ar, this message translates to:
  /// **'اسم التحليل'**
  String get recordLabTestName;

  /// No description provided for @recordLabUnit.
  ///
  /// In ar, this message translates to:
  /// **'الوحدة'**
  String get recordLabUnit;

  /// No description provided for @recordLabUnitHint.
  ///
  /// In ar, this message translates to:
  /// **'مثلًا mg/dL'**
  String get recordLabUnitHint;

  /// No description provided for @recordLabLow.
  ///
  /// In ar, this message translates to:
  /// **'الحدّ الأدنى للمدى'**
  String get recordLabLow;

  /// No description provided for @recordLabHigh.
  ///
  /// In ar, this message translates to:
  /// **'الحدّ الأعلى للمدى'**
  String get recordLabHigh;

  /// No description provided for @recordLabRangeInvalid.
  ///
  /// In ar, this message translates to:
  /// **'الحدّ الأدنى أكبر من الأعلى'**
  String get recordLabRangeInvalid;

  /// No description provided for @recordLabCategory.
  ///
  /// In ar, this message translates to:
  /// **'الفئة'**
  String get recordLabCategory;

  /// No description provided for @recordLabTestAdded.
  ///
  /// In ar, this message translates to:
  /// **'أُضيف التحليل'**
  String get recordLabTestAdded;

  /// No description provided for @recordLabTestDeleted.
  ///
  /// In ar, this message translates to:
  /// **'حُذف التحليل مع نتائجه'**
  String get recordLabTestDeleted;

  /// No description provided for @recordLabTestGone.
  ///
  /// In ar, this message translates to:
  /// **'لم يعد هذا التحليل موجودًا'**
  String get recordLabTestGone;

  /// No description provided for @recordLabAddReading.
  ///
  /// In ar, this message translates to:
  /// **'إضافة نتيجة'**
  String get recordLabAddReading;

  /// No description provided for @recordLabEditReading.
  ///
  /// In ar, this message translates to:
  /// **'تعديل النتيجة'**
  String get recordLabEditReading;

  /// No description provided for @recordLabValue.
  ///
  /// In ar, this message translates to:
  /// **'النتيجة'**
  String get recordLabValue;

  /// No description provided for @recordLabValueWithUnit.
  ///
  /// In ar, this message translates to:
  /// **'النتيجة بوحدة {unit}'**
  String recordLabValueWithUnit(String unit);

  /// No description provided for @recordLabValueHint.
  ///
  /// In ar, this message translates to:
  /// **'رقم، أو نتيجة وصفية مثل «سلبي»'**
  String get recordLabValueHint;

  /// No description provided for @recordLabNote.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة'**
  String get recordLabNote;

  /// No description provided for @recordLabReadingAdded.
  ///
  /// In ar, this message translates to:
  /// **'أُضيفت النتيجة'**
  String get recordLabReadingAdded;

  /// No description provided for @recordLabReadingDeleted.
  ///
  /// In ar, this message translates to:
  /// **'حُذفت النتيجة'**
  String get recordLabReadingDeleted;

  /// No description provided for @recordLabsEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا تحاليل بعد'**
  String get recordLabsEmpty;

  /// No description provided for @recordLabsEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'أنشئ تحاليلك مرة واحدة بمداها المرجعي، ثم سجّل نتائج كل زيارة لترى مسارها.'**
  String get recordLabsEmptyBody;

  /// No description provided for @recordLabNoReadings.
  ///
  /// In ar, this message translates to:
  /// **'لا نتائج'**
  String get recordLabNoReadings;

  /// No description provided for @recordLabNoReadingsBody.
  ///
  /// In ar, this message translates to:
  /// **'لم تُسجَّل نتائج لهذا التحليل بعد.'**
  String get recordLabNoReadingsBody;

  /// No description provided for @recordLabNoRange.
  ///
  /// In ar, this message translates to:
  /// **'بلا مدى مرجعي'**
  String get recordLabNoRange;

  /// No description provided for @recordLabRangeLabel.
  ///
  /// In ar, this message translates to:
  /// **'المدى المرجعي'**
  String get recordLabRangeLabel;

  /// No description provided for @recordLabLatest.
  ///
  /// In ar, this message translates to:
  /// **'آخر نتيجة'**
  String get recordLabLatest;

  /// Neutral difference to the previous reading
  ///
  /// In ar, this message translates to:
  /// **'{delta} عن النتيجة السابقة'**
  String recordLabChange(String delta);

  /// No description provided for @recordLabHistory.
  ///
  /// In ar, this message translates to:
  /// **'كل النتائج'**
  String get recordLabHistory;

  /// No description provided for @recordLabChartEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا نتائج رقمية في هذه الفترة'**
  String get recordLabChartEmpty;

  /// Screen-reader label of the chart
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{مسار {name}: نتيجة واحدة} =2{مسار {name}: نتيجتان} few{مسار {name}: {n} نتائج} many{مسار {name}: {n} نتيجة} other{مسار {name}: {n} نتيجة}}'**
  String recordLabChartSemantics(String name, int count, String n);

  /// No description provided for @recordLabReadingsCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا نتائج} =1{نتيجة واحدة} =2{نتيجتان} few{{n} نتائج} many{{n} نتيجة} other{{n} نتيجة}}'**
  String recordLabReadingsCount(int count, String n);

  /// No description provided for @recordLabTestsCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{تحليل واحد} =2{تحليلان} few{{n} تحاليل} many{{n} تحليلًا} other{{n} تحليل}}'**
  String recordLabTestsCount(int count, String n);

  /// No description provided for @recordLabMarginNote.
  ///
  /// In ar, this message translates to:
  /// **'«حدّي» يعني: ضمن المدى وعلى بُعد {margin} من عرضه عن أحد الحدّين. يمكنك تغيير النسبة من إعدادات السجل.'**
  String recordLabMarginNote(String margin);

  /// No description provided for @recordLabFlagsTitle.
  ///
  /// In ar, this message translates to:
  /// **'التحاليل'**
  String get recordLabFlagsTitle;

  /// Hub card: latest results flagged low/high/borderline
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{نتيجة خارج المدى أو قربه} =2{نتيجتان خارج المدى أو قربه} few{{n} نتائج خارج المدى أو قربه} many{{n} نتيجة خارج المدى أو قربه} other{{n} نتيجة خارج المدى أو قربه}}'**
  String recordLabFlaggedCount(int count, String n);

  /// No description provided for @recordLabAllInRange.
  ///
  /// In ar, this message translates to:
  /// **'آخر نتائج تحاليلك كلها ضمن المدى الذي أدخلته.'**
  String get recordLabAllInRange;

  /// No description provided for @recordAppointmentsTitle.
  ///
  /// In ar, this message translates to:
  /// **'المواعيد الطبية'**
  String get recordAppointmentsTitle;

  /// No description provided for @recordAppointmentAdd.
  ///
  /// In ar, this message translates to:
  /// **'موعد جديد'**
  String get recordAppointmentAdd;

  /// No description provided for @recordAppointmentEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الموعد'**
  String get recordAppointmentEdit;

  /// No description provided for @recordAppointmentTitleField.
  ///
  /// In ar, this message translates to:
  /// **'الموعد'**
  String get recordAppointmentTitleField;

  /// No description provided for @recordAppointmentTitleHint.
  ///
  /// In ar, this message translates to:
  /// **'مثلًا: مراجعة دورية'**
  String get recordAppointmentTitleHint;

  /// No description provided for @recordAppointmentDoctor.
  ///
  /// In ar, this message translates to:
  /// **'الطبيب'**
  String get recordAppointmentDoctor;

  /// No description provided for @recordAppointmentPlace.
  ///
  /// In ar, this message translates to:
  /// **'المكان'**
  String get recordAppointmentPlace;

  /// No description provided for @recordAppointmentDone.
  ///
  /// In ar, this message translates to:
  /// **'تمّ'**
  String get recordAppointmentDone;

  /// No description provided for @recordAppointmentMarkDone.
  ///
  /// In ar, this message translates to:
  /// **'تمّ الموعد'**
  String get recordAppointmentMarkDone;

  /// No description provided for @recordAppointmentMarkUndone.
  ///
  /// In ar, this message translates to:
  /// **'لم يتمّ بعد'**
  String get recordAppointmentMarkUndone;

  /// No description provided for @recordAppointmentDoneToast.
  ///
  /// In ar, this message translates to:
  /// **'سُجّل الموعد كمنجز'**
  String get recordAppointmentDoneToast;

  /// No description provided for @recordAppointmentUndoneToast.
  ///
  /// In ar, this message translates to:
  /// **'أُعيد الموعد إلى القادمة'**
  String get recordAppointmentUndoneToast;

  /// No description provided for @recordAppointmentAdded.
  ///
  /// In ar, this message translates to:
  /// **'أُضيف الموعد'**
  String get recordAppointmentAdded;

  /// No description provided for @recordAppointmentDeleted.
  ///
  /// In ar, this message translates to:
  /// **'حُذف الموعد، وبقيت أسئلته'**
  String get recordAppointmentDeleted;

  /// No description provided for @recordAppointmentUpcoming.
  ///
  /// In ar, this message translates to:
  /// **'القادمة'**
  String get recordAppointmentUpcoming;

  /// No description provided for @recordAppointmentPast.
  ///
  /// In ar, this message translates to:
  /// **'السابقة'**
  String get recordAppointmentPast;

  /// No description provided for @recordAppointmentShowAll.
  ///
  /// In ar, this message translates to:
  /// **'كل المواعيد'**
  String get recordAppointmentShowAll;

  /// No description provided for @recordAppointmentsEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا مواعيد قادمة'**
  String get recordAppointmentsEmpty;

  /// No description provided for @recordAppointmentsEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'أضف موعدك القادم لتصلك تذكرة قبله، وتبقى أسئلتك للطبيب معه.'**
  String get recordAppointmentsEmptyBody;

  /// No description provided for @recordNextAppointment.
  ///
  /// In ar, this message translates to:
  /// **'الموعد القادم'**
  String get recordNextAppointment;

  /// No description provided for @recordAppointmentQuestions.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{سؤال واحد بانتظاره} =2{سؤالان بانتظاره} few{{n} أسئلة بانتظاره} many{{n} سؤالًا بانتظاره} other{{n} سؤال بانتظاره}}'**
  String recordAppointmentQuestions(int count, String n);

  /// No description provided for @recordQuestionAdd.
  ///
  /// In ar, this message translates to:
  /// **'سؤال جديد'**
  String get recordQuestionAdd;

  /// No description provided for @recordQuestionAddForVisit.
  ///
  /// In ar, this message translates to:
  /// **'أضف سؤالًا لهذه الزيارة'**
  String get recordQuestionAddForVisit;

  /// No description provided for @recordQuestionEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل السؤال'**
  String get recordQuestionEdit;

  /// No description provided for @recordQuestionField.
  ///
  /// In ar, this message translates to:
  /// **'السؤال'**
  String get recordQuestionField;

  /// No description provided for @recordQuestionAppointment.
  ///
  /// In ar, this message translates to:
  /// **'لأي موعد؟'**
  String get recordQuestionAppointment;

  /// No description provided for @recordQuestionGeneral.
  ///
  /// In ar, this message translates to:
  /// **'سؤال عام'**
  String get recordQuestionGeneral;

  /// No description provided for @recordQuestionAnswered.
  ///
  /// In ar, this message translates to:
  /// **'تمّت الإجابة'**
  String get recordQuestionAnswered;

  /// No description provided for @recordQuestionAnswer.
  ///
  /// In ar, this message translates to:
  /// **'الإجابة'**
  String get recordQuestionAnswer;

  /// No description provided for @recordQuestionAnswerOptional.
  ///
  /// In ar, this message translates to:
  /// **'الإجابة (اختياري)'**
  String get recordQuestionAnswerOptional;

  /// No description provided for @recordQuestionMarkAnswered.
  ///
  /// In ar, this message translates to:
  /// **'أُجيب عنه'**
  String get recordQuestionMarkAnswered;

  /// No description provided for @recordQuestionReopen.
  ///
  /// In ar, this message translates to:
  /// **'إعادة فتح السؤال'**
  String get recordQuestionReopen;

  /// No description provided for @recordQuestionAdded.
  ///
  /// In ar, this message translates to:
  /// **'أُضيف السؤال'**
  String get recordQuestionAdded;

  /// No description provided for @recordQuestionDeleted.
  ///
  /// In ar, this message translates to:
  /// **'حُذف السؤال'**
  String get recordQuestionDeleted;

  /// No description provided for @recordQuestionAnsweredToast.
  ///
  /// In ar, this message translates to:
  /// **'سُجّلت الإجابة'**
  String get recordQuestionAnsweredToast;

  /// No description provided for @recordQuestionReopened.
  ///
  /// In ar, this message translates to:
  /// **'أُعيد فتح السؤال'**
  String get recordQuestionReopened;

  /// No description provided for @recordQuestionsEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا أسئلة بعد'**
  String get recordQuestionsEmpty;

  /// No description provided for @recordQuestionsEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'دوّن ما تريد سؤاله حين يخطر لك، حتى لا يضيع في العيادة.'**
  String get recordQuestionsEmptyBody;

  /// No description provided for @recordQuestionsGeneralHeader.
  ///
  /// In ar, this message translates to:
  /// **'أسئلة عامة'**
  String get recordQuestionsGeneralHeader;

  /// No description provided for @recordQuestionsAnsweredHeader.
  ///
  /// In ar, this message translates to:
  /// **'أُجيب عنها'**
  String get recordQuestionsAnsweredHeader;

  /// No description provided for @recordQuestionsMore.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{وسؤال آخر} =2{وسؤالان آخران} few{و{n} أسئلة أخرى} many{و{n} سؤالًا آخر} other{و{n} سؤال آخر}}'**
  String recordQuestionsMore(int count, String n);

  /// No description provided for @recordReportSheetSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'ملف PDF مرتّب للطباعة أو المشاركة'**
  String get recordReportSheetSubtitle;

  /// No description provided for @recordReportNameField.
  ///
  /// In ar, this message translates to:
  /// **'الاسم في رأس التقرير'**
  String get recordReportNameField;

  /// No description provided for @recordReportNameHint.
  ///
  /// In ar, this message translates to:
  /// **'يُطبع فقط، ولا يُحفظ'**
  String get recordReportNameHint;

  /// No description provided for @recordReportRememberName.
  ///
  /// In ar, this message translates to:
  /// **'تذكّر الاسم'**
  String get recordReportRememberName;

  /// No description provided for @recordReportRememberHint.
  ///
  /// In ar, this message translates to:
  /// **'يُحفظ على هذا الجهاز فقط'**
  String get recordReportRememberHint;

  /// No description provided for @recordReportPeriodField.
  ///
  /// In ar, this message translates to:
  /// **'الفترة'**
  String get recordReportPeriodField;

  /// No description provided for @recordReportSectionsField.
  ///
  /// In ar, this message translates to:
  /// **'الأقسام'**
  String get recordReportSectionsField;

  /// No description provided for @recordReportPrivacyNote.
  ///
  /// In ar, this message translates to:
  /// **'يُنشأ التقرير على جهازك، ولا يغادره إلا إذا شاركته بنفسك.'**
  String get recordReportPrivacyNote;

  /// No description provided for @recordReportShare.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة'**
  String get recordReportShare;

  /// No description provided for @recordReportSave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ ملف'**
  String get recordReportSave;

  /// No description provided for @recordReportBuilding.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ إعداد التقرير…'**
  String get recordReportBuilding;

  /// No description provided for @recordReportSaved.
  ///
  /// In ar, this message translates to:
  /// **'حُفظ التقرير'**
  String get recordReportSaved;

  /// No description provided for @recordReportFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر إعداد التقرير، حاول مجددًا'**
  String get recordReportFailed;

  /// No description provided for @recordSettingsMargin.
  ///
  /// In ar, this message translates to:
  /// **'هامش «حدّي» قرب كل حدّ'**
  String get recordSettingsMargin;

  /// No description provided for @recordSettingsReminders.
  ///
  /// In ar, this message translates to:
  /// **'تذكير المواعيد'**
  String get recordSettingsReminders;

  /// No description provided for @recordSettingsRemindersHint.
  ///
  /// In ar, this message translates to:
  /// **'إشعار قبل كل موعد طبي'**
  String get recordSettingsRemindersHint;

  /// No description provided for @recordSettingsReminderTimes.
  ///
  /// In ar, this message translates to:
  /// **'متى أُذكَّر'**
  String get recordSettingsReminderTimes;

  /// Wellbeing screen title
  ///
  /// In ar, this message translates to:
  /// **'العافية'**
  String get wbTitle;

  /// No description provided for @wbTabToday.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get wbTabToday;

  /// No description provided for @wbTabPain.
  ///
  /// In ar, this message translates to:
  /// **'الألم'**
  String get wbTabPain;

  /// No description provided for @wbTabHabits.
  ///
  /// In ar, this message translates to:
  /// **'العادات'**
  String get wbTabHabits;

  /// No description provided for @wbTabWorries.
  ///
  /// In ar, this message translates to:
  /// **'الهموم'**
  String get wbTabWorries;

  /// No description provided for @wbTabInsights.
  ///
  /// In ar, this message translates to:
  /// **'رؤى'**
  String get wbTabInsights;

  /// No description provided for @wbAdd.
  ///
  /// In ar, this message translates to:
  /// **'إضافة'**
  String get wbAdd;

  /// No description provided for @wbCancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get wbCancel;

  /// No description provided for @wbSave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get wbSave;

  /// No description provided for @wbDelete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get wbDelete;

  /// No description provided for @wbEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get wbEdit;

  /// No description provided for @wbClose.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get wbClose;

  /// No description provided for @wbOpen.
  ///
  /// In ar, this message translates to:
  /// **'فتح'**
  String get wbOpen;

  /// No description provided for @wbEditList.
  ///
  /// In ar, this message translates to:
  /// **'تعديل القائمة'**
  String get wbEditList;

  /// No description provided for @wbShowAll.
  ///
  /// In ar, this message translates to:
  /// **'عرض الكل'**
  String get wbShowAll;

  /// No description provided for @wbShowLess.
  ///
  /// In ar, this message translates to:
  /// **'عرض أقل'**
  String get wbShowLess;

  /// No description provided for @wbNotes.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات'**
  String get wbNotes;

  /// No description provided for @wbWhen.
  ///
  /// In ar, this message translates to:
  /// **'الوقت'**
  String get wbWhen;

  /// No description provided for @wbNow.
  ///
  /// In ar, this message translates to:
  /// **'الآن'**
  String get wbNow;

  /// No description provided for @wbToday.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get wbToday;

  /// No description provided for @wbYesterday.
  ///
  /// In ar, this message translates to:
  /// **'أمس'**
  String get wbYesterday;

  /// No description provided for @wbDayAtTime.
  ///
  /// In ar, this message translates to:
  /// **'{day}، {time}'**
  String wbDayAtTime(String day, String time);

  /// Separator between list items (keep the trailing space)
  ///
  /// In ar, this message translates to:
  /// **'، '**
  String get wbListSeparator;

  /// No description provided for @wbLess.
  ///
  /// In ar, this message translates to:
  /// **'أقل'**
  String get wbLess;

  /// No description provided for @wbMore.
  ///
  /// In ar, this message translates to:
  /// **'أكثر'**
  String get wbMore;

  /// A score out of a maximum, e.g. 6 of 10
  ///
  /// In ar, this message translates to:
  /// **'{value} من {max}'**
  String wbOutOf(String value, String max);

  /// Unit after a number, e.g. of 10
  ///
  /// In ar, this message translates to:
  /// **'من {max}'**
  String wbOutOfMax(String max);

  /// No description provided for @wbFraction.
  ///
  /// In ar, this message translates to:
  /// **'{done} من {total}'**
  String wbFraction(String done, String total);

  /// No description provided for @wbMetricMood.
  ///
  /// In ar, this message translates to:
  /// **'المزاج'**
  String get wbMetricMood;

  /// No description provided for @wbMetricStress.
  ///
  /// In ar, this message translates to:
  /// **'التوتر'**
  String get wbMetricStress;

  /// No description provided for @wbMetricAnxiety.
  ///
  /// In ar, this message translates to:
  /// **'القلق'**
  String get wbMetricAnxiety;

  /// No description provided for @wbMetricEnergy.
  ///
  /// In ar, this message translates to:
  /// **'الطاقة'**
  String get wbMetricEnergy;

  /// No description provided for @wbMetricSleep.
  ///
  /// In ar, this message translates to:
  /// **'النوم'**
  String get wbMetricSleep;

  /// No description provided for @wbMetricCaffeine.
  ///
  /// In ar, this message translates to:
  /// **'الكافيين'**
  String get wbMetricCaffeine;

  /// No description provided for @wbMetricPain.
  ///
  /// In ar, this message translates to:
  /// **'الألم'**
  String get wbMetricPain;

  /// A metric as 'your X' inside insight sentences
  ///
  /// In ar, this message translates to:
  /// **'{metric, select, mood{تقييم مزاجك} stress{توترك} anxiety{قلقك} energy{طاقتك} sleep{ساعات نومك} caffeine{أكواب الكافيين} pain{ألمك} other{القيمة}}'**
  String wbMetricYour(String metric);

  /// Mood 1 of 5 (lowest)
  ///
  /// In ar, this message translates to:
  /// **'ثقيل'**
  String get wbMood1;

  /// No description provided for @wbMood2.
  ///
  /// In ar, this message translates to:
  /// **'منخفض'**
  String get wbMood2;

  /// No description provided for @wbMood3.
  ///
  /// In ar, this message translates to:
  /// **'معتدل'**
  String get wbMood3;

  /// No description provided for @wbMood4.
  ///
  /// In ar, this message translates to:
  /// **'طيّب'**
  String get wbMood4;

  /// Mood 5 of 5 (highest)
  ///
  /// In ar, this message translates to:
  /// **'مُشرق'**
  String get wbMood5;

  /// No description provided for @wbMoodQuestion.
  ///
  /// In ar, this message translates to:
  /// **'كيف حالك اليوم؟'**
  String get wbMoodQuestion;

  /// No description provided for @wbCheckInPrompt.
  ///
  /// In ar, this message translates to:
  /// **'اختر وجهًا لتسجيل سريع، أو سجّل التوتر والنوم والطاقة معًا.'**
  String get wbCheckInPrompt;

  /// No description provided for @wbCheckInFull.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل كامل'**
  String get wbCheckInFull;

  /// No description provided for @wbCheckInTitle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل المزاج والتوتر'**
  String get wbCheckInTitle;

  /// No description provided for @wbCheckInEditTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعديل التسجيل'**
  String get wbCheckInEditTitle;

  /// No description provided for @wbCheckInSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'كل الحقول اختيارية؛ سجّل ما يناسبك.'**
  String get wbCheckInSubtitle;

  /// No description provided for @wbCheckInAnother.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل آخر'**
  String get wbCheckInAnother;

  /// No description provided for @wbCheckedIn.
  ///
  /// In ar, this message translates to:
  /// **'تم التسجيل'**
  String get wbCheckedIn;

  /// No description provided for @wbTodayCheckIn.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل اليوم'**
  String get wbTodayCheckIn;

  /// No description provided for @wbCheckInDeleted.
  ///
  /// In ar, this message translates to:
  /// **'حُذف التسجيل'**
  String get wbCheckInDeleted;

  /// No description provided for @wbMoodNotesHint.
  ///
  /// In ar, this message translates to:
  /// **'ما الذي أثّر في يومك؟'**
  String get wbMoodNotesHint;

  /// No description provided for @wbScaleCalm.
  ///
  /// In ar, this message translates to:
  /// **'هادئ'**
  String get wbScaleCalm;

  /// No description provided for @wbScaleVeryHigh.
  ///
  /// In ar, this message translates to:
  /// **'مرتفع جدًا'**
  String get wbScaleVeryHigh;

  /// No description provided for @wbScaleNone.
  ///
  /// In ar, this message translates to:
  /// **'لا شيء'**
  String get wbScaleNone;

  /// No description provided for @wbScaleDrained.
  ///
  /// In ar, this message translates to:
  /// **'مستنزَف'**
  String get wbScaleDrained;

  /// No description provided for @wbScaleFull.
  ///
  /// In ar, this message translates to:
  /// **'ممتلئ'**
  String get wbScaleFull;

  /// No description provided for @wbSleepHours.
  ///
  /// In ar, this message translates to:
  /// **'ساعات النوم'**
  String get wbSleepHours;

  /// No description provided for @wbCaffeine.
  ///
  /// In ar, this message translates to:
  /// **'أكواب الكافيين'**
  String get wbCaffeine;

  /// No description provided for @wbFactors.
  ///
  /// In ar, this message translates to:
  /// **'ما الذي أثّر'**
  String get wbFactors;

  /// Hours (sleep), abbreviated
  ///
  /// In ar, this message translates to:
  /// **'{n} س'**
  String wbHours(String n);

  /// No description provided for @wbCups.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا أكواب} =1{كوب واحد} =2{كوبان} few{{n} أكواب} many{{n} كوبًا} other{{n} كوب}}'**
  String wbCups(int count, String n);

  /// Chart range chip
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{يوم} =2{يومان} few{{n} أيام} many{{n} يومًا} other{{n} يوم}}'**
  String wbDaysRange(int count, String n);

  /// No description provided for @wbDayCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{يوم واحد} =2{يومان} few{{n} أيام} many{{n} يومًا} other{{n} يوم}}'**
  String wbDayCount(int count, String n);

  /// No description provided for @wbMinutes.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{دقيقة} =2{دقيقتان} few{{n} دقائق} many{{n} دقيقة} other{{n} دقيقة}}'**
  String wbMinutes(int count, String n);

  /// No description provided for @wbTimes.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{مرة واحدة} =2{مرتان} few{{n} مرات} many{{n} مرة} other{{n} مرة}}'**
  String wbTimes(int count, String n);

  /// No description provided for @wbPointsCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{نقطة على الخريطة} =2{نقطتان على الخريطة} few{{n} نقاط على الخريطة} many{{n} نقطة على الخريطة} other{{n} نقطة على الخريطة}}'**
  String wbPointsCount(int count, String n);

  /// No description provided for @wbPainLogTitle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل ألم'**
  String get wbPainLogTitle;

  /// No description provided for @wbPainEditTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعديل تسجيل الألم'**
  String get wbPainEditTitle;

  /// No description provided for @wbPainLogSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'من «لا ألم» إلى «أشدّ ما يكون»'**
  String get wbPainLogSubtitle;

  /// No description provided for @wbPainScore.
  ///
  /// In ar, this message translates to:
  /// **'شدة الألم'**
  String get wbPainScore;

  /// No description provided for @wbPainNone.
  ///
  /// In ar, this message translates to:
  /// **'لا ألم'**
  String get wbPainNone;

  /// No description provided for @wbPainMild.
  ///
  /// In ar, this message translates to:
  /// **'خفيف'**
  String get wbPainMild;

  /// No description provided for @wbPainModerate.
  ///
  /// In ar, this message translates to:
  /// **'متوسط'**
  String get wbPainModerate;

  /// No description provided for @wbPainSevere.
  ///
  /// In ar, this message translates to:
  /// **'شديد'**
  String get wbPainSevere;

  /// No description provided for @wbPainWorst.
  ///
  /// In ar, this message translates to:
  /// **'أشدّ ما يكون'**
  String get wbPainWorst;

  /// No description provided for @wbBodyMap.
  ///
  /// In ar, this message translates to:
  /// **'خريطة الجسم'**
  String get wbBodyMap;

  /// No description provided for @wbBodyMapHint.
  ///
  /// In ar, this message translates to:
  /// **'المس موضع الألم لتضع نقطة، والمسها ثانيةً لإزالتها.'**
  String get wbBodyMapHint;

  /// No description provided for @wbBodyMapSemantics.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{خريطة الجسم من الأمام والخلف، بلا نقاط} =1{خريطة الجسم، عليها نقطة واحدة} =2{خريطة الجسم، عليها نقطتان} few{خريطة الجسم، عليها {count} نقاط} many{خريطة الجسم، عليها {count} نقطة} other{خريطة الجسم، عليها {count} نقطة}}'**
  String wbBodyMapSemantics(int count);

  /// No description provided for @wbClearPoints.
  ///
  /// In ar, this message translates to:
  /// **'مسح النقاط'**
  String get wbClearPoints;

  /// No description provided for @wbFront.
  ///
  /// In ar, this message translates to:
  /// **'أمام'**
  String get wbFront;

  /// No description provided for @wbBack.
  ///
  /// In ar, this message translates to:
  /// **'خلف'**
  String get wbBack;

  /// No description provided for @wbLocations.
  ///
  /// In ar, this message translates to:
  /// **'الأماكن'**
  String get wbLocations;

  /// No description provided for @wbTriggers.
  ///
  /// In ar, this message translates to:
  /// **'المحفزات'**
  String get wbTriggers;

  /// No description provided for @wbPainNotesHint.
  ///
  /// In ar, this message translates to:
  /// **'كيف كان الألم؟ وما الذي سبقه؟'**
  String get wbPainNotesHint;

  /// No description provided for @wbPainNowQuestion.
  ///
  /// In ar, this message translates to:
  /// **'كم ألمك الآن؟'**
  String get wbPainNowQuestion;

  /// No description provided for @wbQuickLog.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل سريع'**
  String get wbQuickLog;

  /// No description provided for @wbWithDetails.
  ///
  /// In ar, this message translates to:
  /// **'مع التفاصيل'**
  String get wbWithDetails;

  /// No description provided for @wbPainLogged.
  ///
  /// In ar, this message translates to:
  /// **'سُجّل ألم بدرجة {score}'**
  String wbPainLogged(String score);

  /// No description provided for @wbPainDeleted.
  ///
  /// In ar, this message translates to:
  /// **'حُذف تسجيل الألم'**
  String get wbPainDeleted;

  /// No description provided for @wbPainOverTime.
  ///
  /// In ar, this message translates to:
  /// **'الألم عبر الأيام'**
  String get wbPainOverTime;

  /// No description provided for @wbPainChartEmpty.
  ///
  /// In ar, this message translates to:
  /// **'يظهر الرسم بعد تسجيل الألم في يومين على الأقل.'**
  String get wbPainChartEmpty;

  /// No description provided for @wbPainDailyMax.
  ///
  /// In ar, this message translates to:
  /// **'أعلى درجة في اليوم'**
  String get wbPainDailyMax;

  /// No description provided for @wbPainDailyMean.
  ///
  /// In ar, this message translates to:
  /// **'متوسط اليوم'**
  String get wbPainDailyMean;

  /// No description provided for @wbPainAvgMax.
  ///
  /// In ar, this message translates to:
  /// **'متوسط الأعلى'**
  String get wbPainAvgMax;

  /// No description provided for @wbPainPeak.
  ///
  /// In ar, this message translates to:
  /// **'الذروة'**
  String get wbPainPeak;

  /// No description provided for @wbPainDaysLogged.
  ///
  /// In ar, this message translates to:
  /// **'أيام مسجّلة'**
  String get wbPainDaysLogged;

  /// No description provided for @wbWhereItHurt.
  ///
  /// In ar, this message translates to:
  /// **'مواضع الألم'**
  String get wbWhereItHurt;

  /// No description provided for @wbHeatEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا نقاط على الخريطة في هذه المدة بعد.'**
  String get wbHeatEmpty;

  /// No description provided for @wbHeatLess.
  ///
  /// In ar, this message translates to:
  /// **'أقل'**
  String get wbHeatLess;

  /// No description provided for @wbHeatMore.
  ///
  /// In ar, this message translates to:
  /// **'أشد'**
  String get wbHeatMore;

  /// No description provided for @wbHeatSemantics.
  ///
  /// In ar, this message translates to:
  /// **'خريطة الألم؛ أكثر المواضع تكرارًا: {places}'**
  String wbHeatSemantics(String places);

  /// No description provided for @wbTriggersFrequent.
  ///
  /// In ar, this message translates to:
  /// **'المحفزات الأكثر تكرارًا'**
  String get wbTriggersFrequent;

  /// No description provided for @wbTriggersEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لم تُسجَّل محفزات في هذه المدة.'**
  String get wbTriggersEmpty;

  /// No description provided for @wbLocationsFrequent.
  ///
  /// In ar, this message translates to:
  /// **'الأماكن الأكثر تكرارًا'**
  String get wbLocationsFrequent;

  /// No description provided for @wbLocationsEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لم تُسجَّل أماكن في هذه المدة.'**
  String get wbLocationsEmpty;

  /// No description provided for @wbManageTriggers.
  ///
  /// In ar, this message translates to:
  /// **'تعديل قائمة المحفزات'**
  String get wbManageTriggers;

  /// No description provided for @wbManageLocations.
  ///
  /// In ar, this message translates to:
  /// **'تعديل قائمة الأماكن'**
  String get wbManageLocations;

  /// No description provided for @wbHistoryPain.
  ///
  /// In ar, this message translates to:
  /// **'سجل الألم'**
  String get wbHistoryPain;

  /// No description provided for @wbPainHistoryEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا تسجيلات بعد.'**
  String get wbPainHistoryEmpty;

  /// No description provided for @wbLogPain.
  ///
  /// In ar, this message translates to:
  /// **'سجّل ألمًا'**
  String get wbLogPain;

  /// No description provided for @wbNoPainToday.
  ///
  /// In ar, this message translates to:
  /// **'لا تسجيل اليوم'**
  String get wbNoPainToday;

  /// No description provided for @wbLastPain.
  ///
  /// In ar, this message translates to:
  /// **'{score} عند {time}'**
  String wbLastPain(String score, String time);

  /// No description provided for @wbRegionLegs.
  ///
  /// In ar, this message translates to:
  /// **'الساقان'**
  String get wbRegionLegs;

  /// No description provided for @wbTagKindLocations.
  ///
  /// In ar, this message translates to:
  /// **'أماكن الألم'**
  String get wbTagKindLocations;

  /// No description provided for @wbTagKindTriggers.
  ///
  /// In ar, this message translates to:
  /// **'محفزات الألم'**
  String get wbTagKindTriggers;

  /// No description provided for @wbTagKindFactors.
  ///
  /// In ar, this message translates to:
  /// **'عوامل المزاج'**
  String get wbTagKindFactors;

  /// No description provided for @wbTagKindGeneric.
  ///
  /// In ar, this message translates to:
  /// **'الوسوم'**
  String get wbTagKindGeneric;

  /// No description provided for @wbTagAddTitle.
  ///
  /// In ar, this message translates to:
  /// **'إضافة إلى {list}'**
  String wbTagAddTitle(String list);

  /// No description provided for @wbTagName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get wbTagName;

  /// No description provided for @wbTagRenameTitle.
  ///
  /// In ar, this message translates to:
  /// **'إعادة التسمية'**
  String get wbTagRenameTitle;

  /// No description provided for @wbTagDeleted.
  ///
  /// In ar, this message translates to:
  /// **'حُذف «{name}» من القائمة'**
  String wbTagDeleted(String name);

  /// No description provided for @wbTagManagerSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'اسحب لإعادة الترتيب، والمس لإعادة التسمية (تتبعها التسجيلات السابقة)، واضغط مطوّلًا للحذف.'**
  String get wbTagManagerSubtitle;

  /// No description provided for @wbTagAdd.
  ///
  /// In ar, this message translates to:
  /// **'إضافة عنصر'**
  String get wbTagAdd;

  /// No description provided for @wbTagEmpty.
  ///
  /// In ar, this message translates to:
  /// **'القائمة فارغة؛ أضف ما يناسبك.'**
  String get wbTagEmpty;

  /// No description provided for @wbTrends.
  ///
  /// In ar, this message translates to:
  /// **'مسار الأيام'**
  String get wbTrends;

  /// No description provided for @wbTrendsNone.
  ///
  /// In ar, this message translates to:
  /// **'بعد بضعة تسجيلات يظهر هنا مسار مزاجك وتوترك ونومك عبر الأيام.'**
  String get wbTrendsNone;

  /// No description provided for @wbTrendsEmpty.
  ///
  /// In ar, this message translates to:
  /// **'يظهر مسار {metric} بعد تسجيله في يومين على الأقل.'**
  String wbTrendsEmpty(String metric);

  /// No description provided for @wbChartSemantics.
  ///
  /// In ar, this message translates to:
  /// **'رسم {metric} خلال {range}'**
  String wbChartSemantics(String metric, String range);

  /// No description provided for @wbAverageOver.
  ///
  /// In ar, this message translates to:
  /// **'المتوسط {value} عبر {days}'**
  String wbAverageOver(String value, String days);

  /// No description provided for @wbFactorsFrequent.
  ///
  /// In ar, this message translates to:
  /// **'العوامل الأكثر حضورًا'**
  String get wbFactorsFrequent;

  /// No description provided for @wbHistoryCheckIns.
  ///
  /// In ar, this message translates to:
  /// **'التسجيلات السابقة'**
  String get wbHistoryCheckIns;

  /// No description provided for @wbHistoryEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا تسجيلات بعد؛ يكفي وجه واحد لتبدأ.'**
  String get wbHistoryEmpty;

  /// No description provided for @wbHabitsToday.
  ///
  /// In ar, this message translates to:
  /// **'عادات اليوم'**
  String get wbHabitsToday;

  /// No description provided for @wbHabitsSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'خطوات صغيرة اخترتها ليومك.'**
  String get wbHabitsSubtitle;

  /// No description provided for @wbHabitsAllDone.
  ///
  /// In ar, this message translates to:
  /// **'أتممتها كلها اليوم.'**
  String get wbHabitsAllDone;

  /// No description provided for @wbBestStreakNow.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{أطول سلسلة الآن: يوم واحد} =2{أطول سلسلة الآن: يومان} few{أطول سلسلة الآن: {n} أيام} many{أطول سلسلة الآن: {n} يومًا} other{أطول سلسلة الآن: {n} يوم}}'**
  String wbBestStreakNow(int count, String n);

  /// No description provided for @wbStreak.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{يوم واحد متتالٍ} =2{يومان متتاليان} few{{n} أيام متتالية} many{{n} يومًا متتاليًا} other{{n} يوم متتالٍ}}'**
  String wbStreak(int count, String n);

  /// No description provided for @wbStreakNone.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ اليوم'**
  String get wbStreakNone;

  /// No description provided for @wbHabitDoneState.
  ///
  /// In ar, this message translates to:
  /// **'أُنجزت اليوم'**
  String get wbHabitDoneState;

  /// No description provided for @wbHabitOpenState.
  ///
  /// In ar, this message translates to:
  /// **'لم تُنجز بعد'**
  String get wbHabitOpenState;

  /// No description provided for @wbHabitPausedState.
  ///
  /// In ar, this message translates to:
  /// **'متوقفة مؤقتًا'**
  String get wbHabitPausedState;

  /// No description provided for @wbHabitMarkDone.
  ///
  /// In ar, this message translates to:
  /// **'إنجاز'**
  String get wbHabitMarkDone;

  /// No description provided for @wbHabitUndo.
  ///
  /// In ar, this message translates to:
  /// **'تراجع'**
  String get wbHabitUndo;

  /// No description provided for @wbHabitDone.
  ///
  /// In ar, this message translates to:
  /// **'أُنجزت: {name}'**
  String wbHabitDone(String name);

  /// No description provided for @wbHabitUndone.
  ///
  /// In ar, this message translates to:
  /// **'أُلغي الإنجاز'**
  String get wbHabitUndone;

  /// No description provided for @wbHabitPause.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف مؤقت'**
  String get wbHabitPause;

  /// No description provided for @wbHabitResume.
  ///
  /// In ar, this message translates to:
  /// **'استئناف'**
  String get wbHabitResume;

  /// No description provided for @wbHabitPaused.
  ///
  /// In ar, this message translates to:
  /// **'أُوقفت العادة مؤقتًا'**
  String get wbHabitPaused;

  /// No description provided for @wbHabitResumed.
  ///
  /// In ar, this message translates to:
  /// **'استُؤنفت العادة'**
  String get wbHabitResumed;

  /// No description provided for @wbHabitDeleted.
  ///
  /// In ar, this message translates to:
  /// **'حُذفت: {name}'**
  String wbHabitDeleted(String name);

  /// No description provided for @wbHabitEditTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعديل العادة'**
  String get wbHabitEditTitle;

  /// No description provided for @wbHabitAddTitle.
  ///
  /// In ar, this message translates to:
  /// **'عادة جديدة'**
  String get wbHabitAddTitle;

  /// No description provided for @wbHabitAddSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'خطوة صغيرة تختارها لنفسك كل يوم.'**
  String get wbHabitAddSubtitle;

  /// No description provided for @wbHabitName.
  ///
  /// In ar, this message translates to:
  /// **'العادة'**
  String get wbHabitName;

  /// No description provided for @wbHabitsEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا عادات بعد'**
  String get wbHabitsEmptyTitle;

  /// No description provided for @wbHabitsEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'أضف عادات صغيرة تودّ متابعتها يوميًا.'**
  String get wbHabitsEmptyBody;

  /// No description provided for @wbHabitsHint.
  ///
  /// In ar, this message translates to:
  /// **'المس للإنجاز، واسحب لإعادة الترتيب، واضغط مطوّلًا للمزيد.'**
  String get wbHabitsHint;

  /// No description provided for @wbHabitsShort.
  ///
  /// In ar, this message translates to:
  /// **'العادات'**
  String get wbHabitsShort;

  /// No description provided for @wbWorriesShort.
  ///
  /// In ar, this message translates to:
  /// **'مركونة'**
  String get wbWorriesShort;

  /// No description provided for @wbWorryWindowTitle.
  ///
  /// In ar, this message translates to:
  /// **'نافذة القلق'**
  String get wbWorryWindowTitle;

  /// No description provided for @wbWorryWindowExplain.
  ///
  /// In ar, this message translates to:
  /// **'وقت قصير كل يوم تراجع فيه ما يشغل بالك. وحتى يحين، اركن الهموم هنا لتعود إليها في موعدها.'**
  String get wbWorryWindowExplain;

  /// No description provided for @wbWorryWindowSet.
  ///
  /// In ar, this message translates to:
  /// **'حدّد النافذة'**
  String get wbWorryWindowSet;

  /// No description provided for @wbWorryWindowEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل النافذة'**
  String get wbWorryWindowEdit;

  /// No description provided for @wbWorryWindowEnabled.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل نافذة القلق'**
  String get wbWorryWindowEnabled;

  /// No description provided for @wbWorryWindowStart.
  ///
  /// In ar, this message translates to:
  /// **'وقت البدء'**
  String get wbWorryWindowStart;

  /// No description provided for @wbWorryWindowLength.
  ///
  /// In ar, this message translates to:
  /// **'المدة'**
  String get wbWorryWindowLength;

  /// No description provided for @wbWorryWindowRemind.
  ///
  /// In ar, this message translates to:
  /// **'تذكير عند البدء'**
  String get wbWorryWindowRemind;

  /// No description provided for @wbWorryWindowRemindHint.
  ///
  /// In ar, this message translates to:
  /// **'إشعار هادئ حين تُفتح النافذة.'**
  String get wbWorryWindowRemindHint;

  /// No description provided for @wbWorryWindowAbout.
  ///
  /// In ar, this message translates to:
  /// **'تبقى همومك على هذا الجهاز وحده، مشفّرة.'**
  String get wbWorryWindowAbout;

  /// No description provided for @wbWorryWindowSummary.
  ///
  /// In ar, this message translates to:
  /// **'كل يوم عند {time} · {length}'**
  String wbWorryWindowSummary(String time, String length);

  /// No description provided for @wbWorryWindowOff.
  ///
  /// In ar, this message translates to:
  /// **'غير مفعّلة'**
  String get wbWorryWindowOff;

  /// No description provided for @wbWorryWindowOpenNow.
  ///
  /// In ar, this message translates to:
  /// **'النافذة مفتوحة الآن؛ بقي {left}'**
  String wbWorryWindowOpenNow(String left);

  /// No description provided for @wbWorryWindowOpensIn.
  ///
  /// In ar, this message translates to:
  /// **'تُفتح بعد {left}'**
  String wbWorryWindowOpensIn(String left);

  /// No description provided for @wbWorryReviewStart.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{راجع همًّا واحدًا} =2{راجع همّين} few{راجع {n} هموم} many{راجع {n} همًّا} other{راجع {n} همّ}}'**
  String wbWorryReviewStart(int count, String n);

  /// No description provided for @wbWorryReviewNothing.
  ///
  /// In ar, this message translates to:
  /// **'لا هموم مركونة'**
  String get wbWorryReviewNothing;

  /// No description provided for @wbWorryParkTitle.
  ///
  /// In ar, this message translates to:
  /// **'اركن همًّا'**
  String get wbWorryParkTitle;

  /// No description provided for @wbWorryParkExplain.
  ///
  /// In ar, this message translates to:
  /// **'اكتبه كما هو، ثم دعه ينتظر نافذتك. لا حاجة إلى حلّه الآن.'**
  String get wbWorryParkExplain;

  /// No description provided for @wbWorryParkHint.
  ///
  /// In ar, this message translates to:
  /// **'ما الذي يشغل بالك؟'**
  String get wbWorryParkHint;

  /// No description provided for @wbWorryPark.
  ///
  /// In ar, this message translates to:
  /// **'اركنه'**
  String get wbWorryPark;

  /// No description provided for @wbWorriesParked.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{الهموم المركونة} =1{همّ مركون واحد} =2{همّان مركونان} few{{n} هموم مركونة} many{{n} همًّا مركونًا} other{{n} همّ مركون}}'**
  String wbWorriesParked(int count, String n);

  /// No description provided for @wbWorriesNone.
  ///
  /// In ar, this message translates to:
  /// **'لا شيء مركون الآن.'**
  String get wbWorriesNone;

  /// No description provided for @wbWorriesResolved.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{همّ انتهى أمره} =2{همّان انتهى أمرهما} few{{n} هموم انتهى أمرها} many{{n} همًّا انتهى أمرها} other{{n} همّ انتهى أمرها}}'**
  String wbWorriesResolved(int count, String n);

  /// No description provided for @wbWorryParkedOn.
  ///
  /// In ar, this message translates to:
  /// **'رُكن: {date}'**
  String wbWorryParkedOn(String date);

  /// No description provided for @wbWorryEditTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الهمّ'**
  String get wbWorryEditTitle;

  /// No description provided for @wbWorryBody.
  ///
  /// In ar, this message translates to:
  /// **'الهمّ'**
  String get wbWorryBody;

  /// No description provided for @wbWorryDeleted.
  ///
  /// In ar, this message translates to:
  /// **'حُذف الهمّ'**
  String get wbWorryDeleted;

  /// No description provided for @wbWorryMarkedResolved.
  ///
  /// In ar, this message translates to:
  /// **'انتهى أمره'**
  String get wbWorryMarkedResolved;

  /// No description provided for @wbWorryReopened.
  ///
  /// In ar, this message translates to:
  /// **'أُعيد إلى المركونة'**
  String get wbWorryReopened;

  /// No description provided for @wbWorryResolved.
  ///
  /// In ar, this message translates to:
  /// **'انتهى أمره'**
  String get wbWorryResolved;

  /// No description provided for @wbWorryReopen.
  ///
  /// In ar, this message translates to:
  /// **'اركنه من جديد'**
  String get wbWorryReopen;

  /// No description provided for @wbWorryKeep.
  ///
  /// In ar, this message translates to:
  /// **'أبقِه لاحقًا'**
  String get wbWorryKeep;

  /// No description provided for @wbWorryReviewTitle.
  ///
  /// In ar, this message translates to:
  /// **'مراجعة الهموم'**
  String get wbWorryReviewTitle;

  /// No description provided for @wbWorryReviewSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'واحدًا تلو الآخر، بلا عجلة.'**
  String get wbWorryReviewSubtitle;

  /// No description provided for @wbWorryReviewProgress.
  ///
  /// In ar, this message translates to:
  /// **'{index} من {total}'**
  String wbWorryReviewProgress(String index, String total);

  /// No description provided for @wbWorryReviewQuestion.
  ///
  /// In ar, this message translates to:
  /// **'هل انتهى أمره، أم تبقيه لنافذة قادمة؟'**
  String get wbWorryReviewQuestion;

  /// No description provided for @wbWorryAddReflection.
  ///
  /// In ar, this message translates to:
  /// **'أضف تأمّلًا'**
  String get wbWorryAddReflection;

  /// No description provided for @wbWorryReflection.
  ///
  /// In ar, this message translates to:
  /// **'تأمّل'**
  String get wbWorryReflection;

  /// No description provided for @wbWorryReflectionHint.
  ///
  /// In ar, this message translates to:
  /// **'كيف تراه الآن؟'**
  String get wbWorryReflectionHint;

  /// No description provided for @wbWorryEarlierReflection.
  ///
  /// In ar, this message translates to:
  /// **'تأمّل سابق: {text}'**
  String wbWorryEarlierReflection(String text);

  /// No description provided for @wbWorryReviewEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا هموم مركونة للمراجعة الآن.'**
  String get wbWorryReviewEmpty;

  /// No description provided for @wbWorryReviewDoneTitle.
  ///
  /// In ar, this message translates to:
  /// **'انتهت المراجعة'**
  String get wbWorryReviewDoneTitle;

  /// No description provided for @wbWorryReviewDoneBody.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{راجعت همًّا واحدًا، وانتهى أمر {resolved}.} =2{راجعت همّين، وانتهى أمر {resolved} منهما.} few{راجعت {n} هموم، وانتهى أمر {resolved} منها.} many{راجعت {n} همًّا، وانتهى أمر {resolved} منها.} other{راجعت {n} همّ، وانتهى أمر {resolved} منها.}}'**
  String wbWorryReviewDoneBody(int count, String n, String resolved);

  /// No description provided for @wbWorryNotifyTitle.
  ///
  /// In ar, this message translates to:
  /// **'حان وقت نافذة القلق'**
  String get wbWorryNotifyTitle;

  /// No description provided for @wbWorryNotifyBody.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{همّ واحد مركون ينتظرك.} =2{همّان مركونان ينتظرانك.} few{{n} هموم مركونة تنتظرك.} many{{n} همًّا مركونًا ينتظرك.} other{{n} همّ مركون ينتظرك.}}'**
  String wbWorryNotifyBody(int count, String n);

  /// No description provided for @wbWorryNotifyBodyEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا شيء مركون اليوم؛ لحظة هدوء لك.'**
  String get wbWorryNotifyBodyEmpty;

  /// No description provided for @wbNotifyGroup.
  ///
  /// In ar, this message translates to:
  /// **'الصحة'**
  String get wbNotifyGroup;

  /// No description provided for @wbNotifyChannel.
  ///
  /// In ar, this message translates to:
  /// **'نافذة القلق'**
  String get wbNotifyChannel;

  /// No description provided for @wbNotifyChannelDescription.
  ///
  /// In ar, this message translates to:
  /// **'تذكير هادئ حين يحين وقت مراجعة الهموم المركونة.'**
  String get wbNotifyChannelDescription;

  /// No description provided for @wbInsightsIntro.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات محايدة تُحسب على جهازك من بياناتك وحدها خلال آخر {days}. هي أرقام للتأمل، لا تشخيص فيها ولا نصيحة، وتزامن أمرين لا يعني أن أحدهما سبب الآخر.'**
  String wbInsightsIntro(String days);

  /// No description provided for @wbInsightsNotYetTitle.
  ///
  /// In ar, this message translates to:
  /// **'الرؤى في الطريق'**
  String get wbInsightsNotYetTitle;

  /// No description provided for @wbInsightsNotYetBody.
  ///
  /// In ar, this message translates to:
  /// **'تظهر الملاحظات حين تتجمّع بيانات {needed} أيام على الأقل. لديك الآن {logged} من {needed}.'**
  String wbInsightsNotYetBody(String needed, String logged);

  /// No description provided for @wbInsightsNoneTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا أنماط واضحة بعد'**
  String get wbInsightsNoneTitle;

  /// No description provided for @wbInsightsNoneBody.
  ///
  /// In ar, this message translates to:
  /// **'لم تظهر في بياناتك حتى الآن فروق أو ارتباطات واضحة بما يكفي، وستظهر هنا إن ظهرت.'**
  String get wbInsightsNoneBody;

  /// No description provided for @wbInsightBasis.
  ///
  /// In ar, this message translates to:
  /// **'بناءً على {days} من بياناتك'**
  String wbInsightBasis(String days);

  /// No description provided for @wbInsightCorrelationNote.
  ///
  /// In ar, this message translates to:
  /// **'الارتباط يصف تزامنًا فقط، لا سببًا.'**
  String get wbInsightCorrelationNote;

  /// No description provided for @wbInsightThoseDays.
  ///
  /// In ar, this message translates to:
  /// **'تلك الأيام'**
  String get wbInsightThoseDays;

  /// No description provided for @wbInsightOtherDays.
  ///
  /// In ar, this message translates to:
  /// **'بقية الأيام'**
  String get wbInsightOtherDays;

  /// No description provided for @wbCorrelationOpposite.
  ///
  /// In ar, this message translates to:
  /// **'عكسي'**
  String get wbCorrelationOpposite;

  /// No description provided for @wbCorrelationNone.
  ///
  /// In ar, this message translates to:
  /// **'لا ارتباط'**
  String get wbCorrelationNone;

  /// No description provided for @wbCorrelationTogether.
  ///
  /// In ar, this message translates to:
  /// **'معًا'**
  String get wbCorrelationTogether;

  /// No description provided for @wbAverages30.
  ///
  /// In ar, this message translates to:
  /// **'متوسطات آخر {days}'**
  String wbAverages30(String days);

  /// No description provided for @wbInsightSplit.
  ///
  /// In ar, this message translates to:
  /// **'{condition}، {comparison}: {a} مقابل {b} في بقية الأيام.'**
  String wbInsightSplit(
    String condition,
    String comparison,
    String a,
    String b,
  );

  /// No description provided for @wbAvgHigher.
  ///
  /// In ar, this message translates to:
  /// **'كان متوسط {metric} أعلى {amount}'**
  String wbAvgHigher(String metric, String amount);

  /// No description provided for @wbAvgLower.
  ///
  /// In ar, this message translates to:
  /// **'كان متوسط {metric} أقل {amount}'**
  String wbAvgLower(String metric, String amount);

  /// No description provided for @wbByPoints.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{بدرجة واحدة} =2{بدرجتين} few{بـ{n} درجات} many{بـ{n} درجة} other{بـ{n} درجة}}'**
  String wbByPoints(int count, String n);

  /// No description provided for @wbByPointsFraction.
  ///
  /// In ar, this message translates to:
  /// **'بـ{n} درجة'**
  String wbByPointsFraction(String n);

  /// No description provided for @wbByHours.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{بساعة واحدة} =2{بساعتين} few{بـ{n} ساعات} many{بـ{n} ساعة} other{بـ{n} ساعة}}'**
  String wbByHours(int count, String n);

  /// No description provided for @wbByHoursFraction.
  ///
  /// In ar, this message translates to:
  /// **'بـ{n} ساعة'**
  String wbByHoursFraction(String n);

  /// No description provided for @wbWhenSleptUnder.
  ///
  /// In ar, this message translates to:
  /// **'في الأيام التي نمت فيها أقل من {hours} ساعات ({days})'**
  String wbWhenSleptUnder(String hours, String days);

  /// No description provided for @wbWhenCaffeineAtLeast.
  ///
  /// In ar, this message translates to:
  /// **'في الأيام التي شربت فيها {cups} أكواب كافيين أو أكثر ({days})'**
  String wbWhenCaffeineAtLeast(String cups, String days);

  /// No description provided for @wbWhenStressAtLeast.
  ///
  /// In ar, this message translates to:
  /// **'في الأيام التي كان توترك فيها {level} فأكثر ({days})'**
  String wbWhenStressAtLeast(String level, String days);

  /// No description provided for @wbWhenMetricAtLeast.
  ///
  /// In ar, this message translates to:
  /// **'في الأيام التي بلغ فيها {metric} {level} فأكثر ({days})'**
  String wbWhenMetricAtLeast(String metric, String level, String days);

  /// No description provided for @wbInsightCorrelation.
  ///
  /// In ar, this message translates to:
  /// **'{when}، {then} في الغالب (معامل الارتباط {r} على مدى {days}).'**
  String wbInsightCorrelation(String when, String then, String r, String days);

  /// No description provided for @wbWhenHigher.
  ///
  /// In ar, this message translates to:
  /// **'{metric, select, mood{في الأيام التي ارتفع فيها تقييم مزاجك} stress{في الأيام التي ارتفع فيها توترك} anxiety{في الأيام التي ارتفع فيها قلقك} energy{في الأيام التي ارتفعت فيها طاقتك} sleep{في الأيام التي طال فيها نومك} caffeine{في الأيام التي زادت فيها أكواب الكافيين} pain{في الأيام التي اشتدّ فيها ألمك} other{في الأيام التي ارتفعت فيها القيمة}}'**
  String wbWhenHigher(String metric);

  /// No description provided for @wbThenHigher.
  ///
  /// In ar, this message translates to:
  /// **'{metric, select, mood{كان تقييم مزاجك أعلى} stress{كان توترك أعلى} anxiety{كان قلقك أعلى} energy{كانت طاقتك أعلى} sleep{كان نومك أطول} caffeine{كانت أكواب الكافيين أكثر} pain{كان ألمك أشدّ} other{كانت القيمة أعلى}}'**
  String wbThenHigher(String metric);

  /// No description provided for @wbThenLower.
  ///
  /// In ar, this message translates to:
  /// **'{metric, select, mood{كان تقييم مزاجك أقل} stress{كان توترك أقل} anxiety{كان قلقك أقل} energy{كانت طاقتك أقل} sleep{كان نومك أقصر} caffeine{كانت أكواب الكافيين أقل} pain{كان ألمك أخفّ} other{كانت القيمة أقل}}'**
  String wbThenLower(String metric);

  /// No description provided for @wbSupportTitle.
  ///
  /// In ar, this message translates to:
  /// **'لست وحدك'**
  String get wbSupportTitle;

  /// No description provided for @wbSupportBody.
  ///
  /// In ar, this message translates to:
  /// **'سجّلت مزاجًا منخفضًا في {low} من آخر {total} تسجيلات. إن احتجت إلى مساعدة عاجلة، فخط الطوارئ متاح على مدار الساعة.'**
  String wbSupportBody(String low, String total);

  /// No description provided for @wbSupportCall.
  ///
  /// In ar, this message translates to:
  /// **'اتصال بـ {number}'**
  String wbSupportCall(String number);

  /// No description provided for @wbSupportHideWeek.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء لأسبوع'**
  String get wbSupportHideWeek;

  /// No description provided for @wbSupportCompact.
  ///
  /// In ar, this message translates to:
  /// **'سجّلت مزاجًا منخفضًا مؤخرًا. الطوارئ متاحة دائمًا.'**
  String get wbSupportCompact;

  /// No description provided for @wbDialFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح الهاتف. رقم الطوارئ: {number}'**
  String wbDialFailed(String number);

  /// No description provided for @wbSettingsTitle.
  ///
  /// In ar, this message translates to:
  /// **'إعدادات العافية'**
  String get wbSettingsTitle;

  /// Settings entry subtitle (for the app settings screen)
  ///
  /// In ar, this message translates to:
  /// **'رقم الطوارئ، ونافذة القلق، وصوت التنفّس'**
  String get wbSettingsSubtitle;

  /// No description provided for @wbSettingsSupportNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم الطوارئ'**
  String get wbSettingsSupportNumber;

  /// No description provided for @wbSettingsSupportNumberHint.
  ///
  /// In ar, this message translates to:
  /// **'يظهر في لافتة الدعم. في الأردن {number}؛ غيّره إن كنت تقيم في بلد آخر.'**
  String wbSettingsSupportNumberHint(String number);

  /// No description provided for @wbSettingsNumberInvalid.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رقمًا صالحًا'**
  String get wbSettingsNumberInvalid;

  /// No description provided for @wbSettingsResetNumber.
  ///
  /// In ar, this message translates to:
  /// **'استعادة {number}'**
  String wbSettingsResetNumber(String number);

  /// No description provided for @wbSettingsBreathingSound.
  ///
  /// In ar, this message translates to:
  /// **'صوت هادئ للتنفّس'**
  String get wbSettingsBreathingSound;

  /// No description provided for @wbSettingsBreathingSoundHint.
  ///
  /// In ar, this message translates to:
  /// **'نغمة خفيفة عند كل مرحلة؛ الاهتزاز يعمل دائمًا.'**
  String get wbSettingsBreathingSoundHint;

  /// No description provided for @wbBreathTitle.
  ///
  /// In ar, this message translates to:
  /// **'تنفّس'**
  String get wbBreathTitle;

  /// No description provided for @wbBreatheShort.
  ///
  /// In ar, this message translates to:
  /// **'تنفّس'**
  String get wbBreatheShort;

  /// Name of the 4-7-8 breathing pattern (descriptive of its long out-breath; never a promise of an effect)
  ///
  /// In ar, this message translates to:
  /// **'الزفير الطويل'**
  String get wbBreath478;

  /// Name of box breathing (4-4-4-4)
  ///
  /// In ar, this message translates to:
  /// **'الصندوق'**
  String get wbBreathBox;

  /// No description provided for @wbBreathIn.
  ///
  /// In ar, this message translates to:
  /// **'شهيق'**
  String get wbBreathIn;

  /// No description provided for @wbBreathHold.
  ///
  /// In ar, this message translates to:
  /// **'احبس'**
  String get wbBreathHold;

  /// No description provided for @wbBreathOut.
  ///
  /// In ar, this message translates to:
  /// **'زفير'**
  String get wbBreathOut;

  /// No description provided for @wbBreathRest.
  ///
  /// In ar, this message translates to:
  /// **'توقّف'**
  String get wbBreathRest;

  /// No description provided for @wbBreathReady.
  ///
  /// In ar, this message translates to:
  /// **'إيقاع {rhythm} ثوانٍ. ابدأ حين تكون مستعدًا.'**
  String wbBreathReady(String rhythm);

  /// No description provided for @wbBreathDone.
  ///
  /// In ar, this message translates to:
  /// **'اكتملت الجلسة'**
  String get wbBreathDone;

  /// No description provided for @wbBreathDoneBody.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{أتممت دورة واحدة.} =2{أتممت دورتين.} few{أتممت {n} دورات.} many{أتممت {n} دورة.} other{أتممت {n} دورة.}}'**
  String wbBreathDoneBody(int count, String n);

  /// No description provided for @wbBreathCycle.
  ///
  /// In ar, this message translates to:
  /// **'الدورة {index} من {total}'**
  String wbBreathCycle(String index, String total);

  /// No description provided for @wbBreathPaused.
  ///
  /// In ar, this message translates to:
  /// **'متوقف مؤقتًا'**
  String get wbBreathPaused;

  /// No description provided for @wbBreathCycles.
  ///
  /// In ar, this message translates to:
  /// **'عدد الدورات'**
  String get wbBreathCycles;

  /// No description provided for @wbBreathStart.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ'**
  String get wbBreathStart;

  /// No description provided for @wbBreathAgain.
  ///
  /// In ar, this message translates to:
  /// **'مرة أخرى'**
  String get wbBreathAgain;

  /// No description provided for @wbBreathStop.
  ///
  /// In ar, this message translates to:
  /// **'إنهاء'**
  String get wbBreathStop;

  /// No description provided for @wbBreathPause.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف مؤقت'**
  String get wbBreathPause;

  /// No description provided for @wbBreathResume.
  ///
  /// In ar, this message translates to:
  /// **'متابعة'**
  String get wbBreathResume;

  /// No description provided for @wbBreathSoundOn.
  ///
  /// In ar, this message translates to:
  /// **'الصوت مفعّل'**
  String get wbBreathSoundOn;

  /// No description provided for @wbBreathSoundOff.
  ///
  /// In ar, this message translates to:
  /// **'الصوت مغلق'**
  String get wbBreathSoundOff;

  /// No description provided for @wbBreathGentleNote.
  ///
  /// In ar, this message translates to:
  /// **'خذ الإيقاع بلطف، ويمكنك التوقف في أي لحظة.'**
  String get wbBreathGentleNote;

  /// No description provided for @wbTodayCardTitle.
  ///
  /// In ar, this message translates to:
  /// **'العافية اليوم'**
  String get wbTodayCardTitle;

  /// Health page: section of today's doses, wellbeing and pain
  ///
  /// In ar, this message translates to:
  /// **'عنايتك اليوم'**
  String get healthHubTodayTitle;

  /// Health page: section of appointments, questions and lab results
  ///
  /// In ar, this message translates to:
  /// **'مع طبيبك'**
  String get healthHubDoctorTitle;

  /// Health page: action opening the whole medical record
  ///
  /// In ar, this message translates to:
  /// **'السجل'**
  String get healthHubRecordAction;

  /// Health page: section of links to the health screens
  ///
  /// In ar, this message translates to:
  /// **'أدوات الصحة'**
  String get healthHubToolsTitle;

  /// Health page: quick pain log card title
  ///
  /// In ar, this message translates to:
  /// **'الألم الآن'**
  String get healthHubPainTitle;

  /// Pain card: nothing logged today
  ///
  /// In ar, this message translates to:
  /// **'لا ألم مسجّل اليوم'**
  String get healthHubPainNone;

  /// Pain card: today's entries and the highest score (numbers only)
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{تسجيل واحد اليوم بدرجة {max}} =2{تسجيلان اليوم، أعلاهما {max}} few{{n} تسجيلات اليوم، أعلاها {max}} many{{n} تسجيلًا اليوم، أعلاها {max}} other{{n} تسجيل اليوم، أعلاها {max}}}'**
  String healthHubPainToday(int count, String n, String max);

  /// Pain card: button opening the full pain log (body map, triggers, notes)
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل'**
  String get healthHubPainWhere;

  /// Pain card: screen-reader label of the details button
  ///
  /// In ar, this message translates to:
  /// **'تسجيل كامل: موضع الألم على الجسم والمحفّزات والملاحظات'**
  String get healthHubPainWhereHint;

  /// Pain card: label under score 0
  ///
  /// In ar, this message translates to:
  /// **'لا ألم'**
  String get healthHubPainLow;

  /// Pain card: label under score 10
  ///
  /// In ar, this message translates to:
  /// **'أشدّ ألم'**
  String get healthHubPainHigh;

  /// Pain card: screen-reader label of one score bead
  ///
  /// In ar, this message translates to:
  /// **'سجّل ألمًا بدرجة {score} من {max}'**
  String healthHubPainLogScore(String score, String max);

  /// Health page: open questions card title
  ///
  /// In ar, this message translates to:
  /// **'أسئلة لطبيبك'**
  String get healthHubQuestionsTitle;

  /// Questions card: how many are still open
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{سؤال واحد بانتظار الإجابة} =2{سؤالان بانتظار الإجابة} few{{n} أسئلة بانتظار الإجابة} many{{n} سؤالًا بانتظار الإجابة} other{{n} سؤال بانتظار الإجابة}}'**
  String healthHubQuestionsCount(int count, String n);

  /// Questions card: the appointment a question is for
  ///
  /// In ar, this message translates to:
  /// **'لموعد {title}'**
  String healthHubQuestionFor(String title);

  /// Health tool: medications & supplements
  ///
  /// In ar, this message translates to:
  /// **'الأدوية'**
  String get healthHubToolMeds;

  /// Health tool hint: medications
  ///
  /// In ar, this message translates to:
  /// **'الجرعات والدورات وقواعد التوقيت'**
  String get healthHubToolMedsHint;

  /// Health tool: lab results (the record)
  ///
  /// In ar, this message translates to:
  /// **'التحاليل'**
  String get healthHubToolLabs;

  /// Health tool hint: labs
  ///
  /// In ar, this message translates to:
  /// **'النتائج ومساراتها ومداك المرجعي'**
  String get healthHubToolLabsHint;

  /// Health tool: appointments
  ///
  /// In ar, this message translates to:
  /// **'المواعيد'**
  String get healthHubToolAppointments;

  /// Health tool hint: appointments
  ///
  /// In ar, this message translates to:
  /// **'المواعيد القادمة والسابقة وأسئلتها'**
  String get healthHubToolAppointmentsHint;

  /// Health tool: wellbeing
  ///
  /// In ar, this message translates to:
  /// **'العافية'**
  String get healthHubToolWellbeing;

  /// Health tool hint: wellbeing
  ///
  /// In ar, this message translates to:
  /// **'المزاج والألم والعادات والهموم'**
  String get healthHubToolWellbeingHint;

  /// Health tool: guided breathing
  ///
  /// In ar, this message translates to:
  /// **'تنفّس'**
  String get healthHubToolBreathe;

  /// Health tool hint: breathing
  ///
  /// In ar, this message translates to:
  /// **'تنفّس موجَّه بإيقاع هادئ'**
  String get healthHubToolBreatheHint;

  /// Health tool: the doctor report (PDF)
  ///
  /// In ar, this message translates to:
  /// **'ملخّص للطبيب'**
  String get healthHubToolReport;

  /// Health tool hint: doctor report
  ///
  /// In ar, this message translates to:
  /// **'ملف PDF تطبعه أو تشاركه'**
  String get healthHubToolReportHint;

  /// Settings section: health
  ///
  /// In ar, this message translates to:
  /// **'الصحة'**
  String get healthHubSettingsSection;

  /// Settings section hint: health
  ///
  /// In ar, this message translates to:
  /// **'الأدوية والمواعيد والعافية، وكلها على جهازك'**
  String get healthHubSettingsSectionHint;

  /// Settings › Health page title and entry
  ///
  /// In ar, this message translates to:
  /// **'إعدادات الصحة'**
  String get healthHubSettingsTitle;

  /// Settings entry: how many health reminders are on (doses, appointments, worry window)
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{تذكيرات الصحة متوقفة} =1{تذكير واحد مفعّل} =2{تذكيران مفعّلان} few{{n} تذكيرات مفعّلة} many{{n} تذكيرًا مفعّلًا} other{{n} تذكير مفعّل}}'**
  String healthHubSettingsRemindersOn(int count, String n);

  /// Settings entry subtitle: reminders on and the emergency number
  ///
  /// In ar, this message translates to:
  /// **'{reminders}، والطوارئ {number}'**
  String healthHubSettingsEntrySummary(String reminders, String number);

  /// Settings › Health: section of appointment reminders and lab flags
  ///
  /// In ar, this message translates to:
  /// **'المواعيد والتحاليل'**
  String get healthHubSettingsRecordSection;

  /// Settings › Health: what the borderline margin means (no advice)
  ///
  /// In ar, this message translates to:
  /// **'جزء من عرض المدى الذي أدخلته لكل تحليل؛ النتيجة ضمنه قرب أحد الحدّين تُعلَّم «حدّية».'**
  String get healthHubSettingsMarginHint;

  /// Settings › Health: section of the PDF report defaults
  ///
  /// In ar, this message translates to:
  /// **'ملخّص الطبيب'**
  String get healthHubSettingsReportSection;

  /// Settings › Health: the report's default look-back period
  ///
  /// In ar, this message translates to:
  /// **'الفترة المعتادة'**
  String get healthHubSettingsReportPeriod;

  /// Settings › Health: the report's default sections
  ///
  /// In ar, this message translates to:
  /// **'الأقسام المضمّنة'**
  String get healthHubSettingsReportSections;

  /// Settings › Health: every report section selected
  ///
  /// In ar, this message translates to:
  /// **'كل الأقسام'**
  String get healthHubSettingsReportSectionsAll;

  /// Settings › Health: no name remembered for the report
  ///
  /// In ar, this message translates to:
  /// **'لا يُحفظ اسم، يُكتب عند كل تقرير'**
  String get healthHubSettingsReportNameNone;

  /// Settings › Health: the remembered report name
  ///
  /// In ar, this message translates to:
  /// **'{name}، على هذا الجهاز فقط'**
  String healthHubSettingsReportNameKept(String name);

  /// Settings › Health: hint of the report name field
  ///
  /// In ar, this message translates to:
  /// **'اتركه فارغًا كي لا يُحفظ أي اسم'**
  String get healthHubSettingsReportNameHint;

  /// Settings › Health: the emergency number and where it appears
  ///
  /// In ar, this message translates to:
  /// **'{number}، ويظهر في رسالة الدعم حين يتكرّر المزاج المنخفض'**
  String healthHubSettingsEmergencyHint(String number);

  /// Settings › Health: notification permission refused
  ///
  /// In ar, this message translates to:
  /// **'إشعارات مَدار متوقفة في إعدادات الهاتف، فلن تصل التذكيرات.'**
  String get healthHubSettingsDenied;

  /// Settings › Health: privacy and tracking-only note
  ///
  /// In ar, this message translates to:
  /// **'كل ما في الصحة يبقى على هذا الجهاز مشفّرًا. مَدار يسجّل ويعرض فقط؛ لا يشخّص ولا ينصح بعلاج.'**
  String get healthHubSettingsPrivacy;

  /// Settings › Health: appointment reminders are off
  ///
  /// In ar, this message translates to:
  /// **'متوقفة'**
  String get healthHubSettingsOff;

  /// Settings › Health: the worry window's time and length (no middle dot: it reads as a zero next to Arabic digits)
  ///
  /// In ar, this message translates to:
  /// **'يوميًا عند {time}، لمدة {length}'**
  String healthHubSettingsWorrySummary(String time, String length);

  /// Title of the ledger hub screen
  ///
  /// In ar, this message translates to:
  /// **'المحافظ والحركات'**
  String get ledgerTitle;

  /// Label above the total of all wallets in the base currency
  ///
  /// In ar, this message translates to:
  /// **'صافي الرصيد'**
  String get ledgerNetBalance;

  /// Wallet kind: personal money
  ///
  /// In ar, this message translates to:
  /// **'شخصي'**
  String get ledgerPersonal;

  /// Wallet kind: business money (the e-commerce side)
  ///
  /// In ar, this message translates to:
  /// **'تجاري'**
  String get ledgerBusiness;

  /// An amount converted to the base currency
  ///
  /// In ar, this message translates to:
  /// **'≈ {amount}'**
  String ledgerApprox(String amount);

  /// Section / card title: the wallets
  ///
  /// In ar, this message translates to:
  /// **'المحافظ'**
  String get ledgerWallets;

  /// Button: create a wallet
  ///
  /// In ar, this message translates to:
  /// **'محفظة جديدة'**
  String get ledgerAddWallet;

  /// Collapsed group of archived wallets; count already formatted
  ///
  /// In ar, this message translates to:
  /// **'المؤرشفة ({count})'**
  String ledgerArchivedCount(String count);

  /// Section title: latest transactions
  ///
  /// In ar, this message translates to:
  /// **'آخر الحركات'**
  String get ledgerRecent;

  /// Action: open the full transactions list
  ///
  /// In ar, this message translates to:
  /// **'عرض الكل'**
  String get ledgerSeeAll;

  /// Action / screen title: currencies and exchange rates
  ///
  /// In ar, this message translates to:
  /// **'العملات وأسعار الصرف'**
  String get ledgerCurrencies;

  /// Search field hint / action
  ///
  /// In ar, this message translates to:
  /// **'ابحث في الحركات'**
  String get ledgerSearch;

  /// Button / sheet title: add a transaction
  ///
  /// In ar, this message translates to:
  /// **'حركة جديدة'**
  String get ledgerAddTx;

  /// Empty ledger title
  ///
  /// In ar, this message translates to:
  /// **'ابدأ بمحفظتك الأولى'**
  String get ledgerEmptyTitle;

  /// Empty ledger body
  ///
  /// In ar, this message translates to:
  /// **'أنشئ محفظة لكل مكان يوجد فيه مالك: نقدًا، في البنك، أو عهدة لدى شركة التوصيل.'**
  String get ledgerEmptyBody;

  /// Empty transactions title
  ///
  /// In ar, this message translates to:
  /// **'لا حركات بعد'**
  String get ledgerNoTxTitle;

  /// Empty transactions body
  ///
  /// In ar, this message translates to:
  /// **'سجّل مصروفًا أو دخلًا وسيظهر هنا.'**
  String get ledgerNoTxBody;

  /// Empty search / filter result title
  ///
  /// In ar, this message translates to:
  /// **'لا حركات مطابقة'**
  String get ledgerNoResults;

  /// Empty search / filter result body
  ///
  /// In ar, this message translates to:
  /// **'جرّب كلمة أخرى أو أزل بعض عوامل التصفية.'**
  String get ledgerNoResultsBody;

  /// Warning: currencies without a rate are excluded from base totals
  ///
  /// In ar, this message translates to:
  /// **'بلا سعر صرف، فلم تُحسب في المجموع: {codes}'**
  String ledgerMissingRate(String codes);

  /// Banner while seeded rates are unchanged
  ///
  /// In ar, this message translates to:
  /// **'أسعار الصرف ما زالت تقديرية. راجعها لتكون المجاميع دقيقة.'**
  String get ledgerRatesDefaults;

  /// Banner action: open the currencies screen
  ///
  /// In ar, this message translates to:
  /// **'مراجعة'**
  String get ledgerReview;

  /// Transaction kind
  ///
  /// In ar, this message translates to:
  /// **'مصروف'**
  String get ledgerKindExpense;

  /// Transaction kind
  ///
  /// In ar, this message translates to:
  /// **'دخل'**
  String get ledgerKindIncome;

  /// Transaction kind
  ///
  /// In ar, this message translates to:
  /// **'تحويل'**
  String get ledgerKindTransfer;

  /// Transaction kind: balance correction
  ///
  /// In ar, this message translates to:
  /// **'تسوية'**
  String get ledgerKindAdjustment;

  /// Day header
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get ledgerToday;

  /// Day header / date chip
  ///
  /// In ar, this message translates to:
  /// **'أمس'**
  String get ledgerYesterday;

  /// Transfer title: source and destination wallet names (already isolated)
  ///
  /// In ar, this message translates to:
  /// **'{from} ← {to}'**
  String ledgerTransferRoute(String from, String to);

  /// Transfer seen from its source wallet
  ///
  /// In ar, this message translates to:
  /// **'تحويل إلى {wallet}'**
  String ledgerTransferOut(String wallet);

  /// Transfer seen from its destination wallet
  ///
  /// In ar, this message translates to:
  /// **'تحويل من {wallet}'**
  String ledgerTransferIn(String wallet);

  /// Title of an adjustment entry
  ///
  /// In ar, this message translates to:
  /// **'تسوية الرصيد'**
  String get ledgerAdjustmentTitle;

  /// Expense or income without a budget item
  ///
  /// In ar, this message translates to:
  /// **'بلا بند'**
  String get ledgerUnassigned;

  /// Running balance after an entry
  ///
  /// In ar, this message translates to:
  /// **'الرصيد {amount}'**
  String ledgerBalanceAfter(String amount);

  /// Menu action
  ///
  /// In ar, this message translates to:
  /// **'تكرار لليوم'**
  String get ledgerDuplicateToday;

  /// Undo toast
  ///
  /// In ar, this message translates to:
  /// **'حُذفت الحركة'**
  String get ledgerDeleted;

  /// Undo toast
  ///
  /// In ar, this message translates to:
  /// **'تكررت الحركة بتاريخ اليوم'**
  String get ledgerDuplicated;

  /// Undo toast
  ///
  /// In ar, this message translates to:
  /// **'نُقلت إلى {wallet}'**
  String ledgerMoved(String wallet);

  /// Undo toast when the amount was converted
  ///
  /// In ar, this message translates to:
  /// **'نُقلت إلى {wallet} بمبلغ {amount}'**
  String ledgerMovedConverted(String wallet, String amount);

  /// Toast after adding
  ///
  /// In ar, this message translates to:
  /// **'حُفظت الحركة'**
  String get ledgerSaved;

  /// Toast after editing
  ///
  /// In ar, this message translates to:
  /// **'عُدّلت الحركة'**
  String get ledgerUpdated;

  /// Move sheet title
  ///
  /// In ar, this message translates to:
  /// **'نقل الحركة إلى…'**
  String get ledgerMoveTitle;

  /// Sheet title
  ///
  /// In ar, this message translates to:
  /// **'تعديل الحركة'**
  String get ledgerEditTx;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'المحفظة'**
  String get ledgerWallet;

  /// Transfer source label
  ///
  /// In ar, this message translates to:
  /// **'من'**
  String get ledgerFrom;

  /// Transfer destination label
  ///
  /// In ar, this message translates to:
  /// **'إلى'**
  String get ledgerTo;

  /// Transfer amount leaving the source
  ///
  /// In ar, this message translates to:
  /// **'المُرسَل'**
  String get ledgerSent;

  /// Transfer amount reaching the destination
  ///
  /// In ar, this message translates to:
  /// **'المستلَم'**
  String get ledgerReceived;

  /// Reset the received amount to the converted one
  ///
  /// In ar, this message translates to:
  /// **'حسب سعر الصرف'**
  String get ledgerUseRate;

  /// An exchange rate line; one and rate are formatted numbers, from/to symbols
  ///
  /// In ar, this message translates to:
  /// **'{one} {from} = {rate} {to}'**
  String ledgerRateLine(String one, String from, String rate, String to);

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'البند'**
  String get ledgerBudgetItem;

  /// Picker placeholder
  ///
  /// In ar, this message translates to:
  /// **'اختر بندًا'**
  String get ledgerChooseItem;

  /// Picker when the budget is empty
  ///
  /// In ar, this message translates to:
  /// **'لا بنود في الميزانية بعد'**
  String get ledgerNoBudget;

  /// Budget picker search hint
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن بند'**
  String get ledgerSearchItems;

  /// Budget item remaining this period
  ///
  /// In ar, this message translates to:
  /// **'متبقٍّ {amount}'**
  String ledgerItemLeft(String amount);

  /// Budget item overspent this period
  ///
  /// In ar, this message translates to:
  /// **'تجاوز {amount}'**
  String ledgerItemOver(String amount);

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'التاريخ'**
  String get ledgerDate;

  /// Date chip opening a calendar
  ///
  /// In ar, this message translates to:
  /// **'يوم آخر'**
  String get ledgerOtherDay;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة'**
  String get ledgerNote;

  /// Note hint
  ///
  /// In ar, this message translates to:
  /// **'مثلًا: خضار من السوق'**
  String get ledgerNoteHint;

  /// Field label / filter
  ///
  /// In ar, this message translates to:
  /// **'الوسوم'**
  String get ledgerTags;

  /// Tag input hint
  ///
  /// In ar, this message translates to:
  /// **'أضف وسمًا'**
  String get ledgerTagHint;

  /// Adjustment mode: type the real balance
  ///
  /// In ar, this message translates to:
  /// **'الرصيد الفعلي'**
  String get ledgerSetBalance;

  /// Adjustment mode / preview: the change
  ///
  /// In ar, this message translates to:
  /// **'الفرق'**
  String get ledgerDifference;

  /// Adjustment preview
  ///
  /// In ar, this message translates to:
  /// **'الرصيد الحالي'**
  String get ledgerCurrentBalance;

  /// Toggle: the typed amount is negative
  ///
  /// In ar, this message translates to:
  /// **'سالب'**
  String get ledgerNegative;

  /// Validation
  ///
  /// In ar, this message translates to:
  /// **'اختر محفظة'**
  String get ledgerErrNoWallet;

  /// Validation
  ///
  /// In ar, this message translates to:
  /// **'أدخل المبلغ'**
  String get ledgerErrNoAmount;

  /// Validation
  ///
  /// In ar, this message translates to:
  /// **'اختر المحفظة المستلِمة'**
  String get ledgerErrNoDestination;

  /// Validation: transfer to itself
  ///
  /// In ar, this message translates to:
  /// **'اختر محفظة مختلفة'**
  String get ledgerErrSameWallet;

  /// Validation
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد سعر صرف، أدخل المبلغ المستلَم'**
  String get ledgerErrNoRate;

  /// Validation
  ///
  /// In ar, this message translates to:
  /// **'الرصيد مطابق أصلًا'**
  String get ledgerErrNoChange;

  /// Transaction sheet without wallets
  ///
  /// In ar, this message translates to:
  /// **'أنشئ محفظة أولًا لتسجيل الحركات'**
  String get ledgerNeedWallet;

  /// Keypad key (screen reader)
  ///
  /// In ar, this message translates to:
  /// **'فاصلة عشرية'**
  String get ledgerKeyDecimal;

  /// Keypad key (screen reader)
  ///
  /// In ar, this message translates to:
  /// **'حذف آخر رقم'**
  String get ledgerKeyBackspace;

  /// Amount display (screen reader)
  ///
  /// In ar, this message translates to:
  /// **'المبلغ'**
  String get ledgerAmount;

  /// Sheet title
  ///
  /// In ar, this message translates to:
  /// **'تعديل المحفظة'**
  String get ledgerWalletEdit;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get ledgerWalletName;

  /// Wallet name hint
  ///
  /// In ar, this message translates to:
  /// **'مثلًا: الصندوق، البنك، عهدة المندوب'**
  String get ledgerWalletNameHint;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'الرصيد الافتتاحي والعملة'**
  String get ledgerOpening;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'نوع المحفظة'**
  String get ledgerWalletKind;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'اللون'**
  String get ledgerColor;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'الأيقونة'**
  String get ledgerIcon;

  /// Validation
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن تغيير العملة بعد تسجيل حركات في المحفظة'**
  String get ledgerCurrencyLocked;

  /// Menu action
  ///
  /// In ar, this message translates to:
  /// **'أرشفة'**
  String get ledgerArchive;

  /// Menu action
  ///
  /// In ar, this message translates to:
  /// **'إعادة من الأرشيف'**
  String get ledgerUnarchive;

  /// Undo toast
  ///
  /// In ar, this message translates to:
  /// **'أُرشفت المحفظة'**
  String get ledgerArchivedToast;

  /// Undo toast
  ///
  /// In ar, this message translates to:
  /// **'أُعيدت المحفظة'**
  String get ledgerUnarchivedToast;

  /// Undo toast
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{حُذفت المحفظة} =1{حُذفت المحفظة وحركة واحدة} =2{حُذفت المحفظة وحركتان} few{حُذفت المحفظة و{count} حركات} many{حُذفت المحفظة و{count} حركة} other{حُذفت المحفظة و{count} حركة}}'**
  String ledgerWalletDeleted(int count);

  /// Toast
  ///
  /// In ar, this message translates to:
  /// **'حُفظت المحفظة'**
  String get ledgerWalletSaved;

  /// Label
  ///
  /// In ar, this message translates to:
  /// **'الرصيد'**
  String get ledgerBalance;

  /// Chart title
  ///
  /// In ar, this message translates to:
  /// **'تطوّر الرصيد'**
  String get ledgerBalanceHistory;

  /// Chart range: one month
  ///
  /// In ar, this message translates to:
  /// **'شهر'**
  String get ledgerRange1M;

  /// Chart range: three months
  ///
  /// In ar, this message translates to:
  /// **'٣ أشهر'**
  String get ledgerRange3M;

  /// Chart range: one year
  ///
  /// In ar, this message translates to:
  /// **'سنة'**
  String get ledgerRange1Y;

  /// Chart range: everything
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get ledgerRangeAll;

  /// Screen / section title
  ///
  /// In ar, this message translates to:
  /// **'الحركات'**
  String get ledgerTransactions;

  /// Wallet screen for a deleted wallet
  ///
  /// In ar, this message translates to:
  /// **'لم نجد هذه المحفظة'**
  String get ledgerWalletMissing;

  /// Footer of a wallet's list
  ///
  /// In ar, this message translates to:
  /// **'رصيد افتتاحي {amount}'**
  String ledgerOpeningLine(String amount);

  /// Filter chip
  ///
  /// In ar, this message translates to:
  /// **'المحفظة'**
  String get ledgerFilterWallet;

  /// Filter chip
  ///
  /// In ar, this message translates to:
  /// **'النوع'**
  String get ledgerFilterKind;

  /// Filter chip
  ///
  /// In ar, this message translates to:
  /// **'البند'**
  String get ledgerFilterItem;

  /// Filter chip
  ///
  /// In ar, this message translates to:
  /// **'الوسم'**
  String get ledgerFilterTag;

  /// Filter chip
  ///
  /// In ar, this message translates to:
  /// **'الفترة'**
  String get ledgerFilterDate;

  /// Filter chip: personal / business
  ///
  /// In ar, this message translates to:
  /// **'النطاق'**
  String get ledgerFilterScope;

  /// Filter chip
  ///
  /// In ar, this message translates to:
  /// **'مسح التصفية'**
  String get ledgerFilterClear;

  /// Chip label with several selections; count formatted
  ///
  /// In ar, this message translates to:
  /// **'{first} +{count}'**
  String ledgerFilterMore(String first, String count);

  /// Selection: everything
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get ledgerAll;

  /// Chart scope
  ///
  /// In ar, this message translates to:
  /// **'كل المحافظ'**
  String get ledgerAllWallets;

  /// Date preset
  ///
  /// In ar, this message translates to:
  /// **'هذا الأسبوع'**
  String get ledgerThisWeek;

  /// Date preset
  ///
  /// In ar, this message translates to:
  /// **'هذا الشهر'**
  String get ledgerThisMonth;

  /// Date preset
  ///
  /// In ar, this message translates to:
  /// **'الشهر الماضي'**
  String get ledgerLastMonth;

  /// Date preset
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{آخر يوم} =2{آخر يومين} few{آخر {count} أيام} many{آخر {count} يومًا} other{آخر {count} يوم}}'**
  String ledgerLastDays(int count);

  /// Date preset
  ///
  /// In ar, this message translates to:
  /// **'مدة مخصّصة'**
  String get ledgerCustomRange;

  /// A date range (formatted dates)
  ///
  /// In ar, this message translates to:
  /// **'{from} – {to}'**
  String ledgerRangeLabel(String from, String to);

  /// Totals strip
  ///
  /// In ar, this message translates to:
  /// **'الدخل'**
  String get ledgerIncomeTotal;

  /// Totals strip
  ///
  /// In ar, this message translates to:
  /// **'المصروف'**
  String get ledgerExpenseTotal;

  /// Totals strip
  ///
  /// In ar, this message translates to:
  /// **'الصافي'**
  String get ledgerNet;

  /// Count of transactions
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا حركات} =1{حركة واحدة} =2{حركتان} few{{count} حركات} many{{count} حركة} other{{count} حركة}}'**
  String ledgerTxCount(int count);

  /// Chart title
  ///
  /// In ar, this message translates to:
  /// **'الإنفاق'**
  String get ledgerSpending;

  /// Chart toggle
  ///
  /// In ar, this message translates to:
  /// **'حسب البند'**
  String get ledgerByItem;

  /// Chart toggle
  ///
  /// In ar, this message translates to:
  /// **'حسب المحفظة'**
  String get ledgerByWallet;

  /// Chart period toggle
  ///
  /// In ar, this message translates to:
  /// **'شهري'**
  String get ledgerPeriodMonth;

  /// Chart period toggle
  ///
  /// In ar, this message translates to:
  /// **'أسبوعي'**
  String get ledgerPeriodWeek;

  /// Button (screen reader)
  ///
  /// In ar, this message translates to:
  /// **'الفترة السابقة'**
  String get ledgerPrevPeriod;

  /// Button (screen reader)
  ///
  /// In ar, this message translates to:
  /// **'الفترة التالية'**
  String get ledgerNextPeriod;

  /// Empty chart
  ///
  /// In ar, this message translates to:
  /// **'لا مصاريف في هذه الفترة'**
  String get ledgerNoSpending;

  /// Chart title
  ///
  /// In ar, this message translates to:
  /// **'الدخل والإنفاق'**
  String get ledgerTrend;

  /// Trend chart subtitle
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{آخر شهر} =2{آخر شهرين} few{آخر {count} أشهر} many{آخر {count} شهرًا} other{آخر {count} شهر}}'**
  String ledgerTrendSubtitle(int count);

  /// Chart note; code already isolated
  ///
  /// In ar, this message translates to:
  /// **'بالعملة الأساسية {code}'**
  String ledgerInBase(String code);

  /// Chart centre label
  ///
  /// In ar, this message translates to:
  /// **'المجموع'**
  String get ledgerTotal;

  /// Chart slice grouping small items
  ///
  /// In ar, this message translates to:
  /// **'أخرى'**
  String get ledgerOther;

  /// Screen-reader summary of the spending chart
  ///
  /// In ar, this message translates to:
  /// **'الإنفاق {period}: المجموع {total}. {slices}'**
  String ledgerChartSpendingSemantics(
    String period,
    String total,
    String slices,
  );

  /// Screen-reader text for one trend bar group
  ///
  /// In ar, this message translates to:
  /// **'{period}: دخل {income}، إنفاق {expense}'**
  String ledgerChartTrendSemantics(
    String period,
    String income,
    String expense,
  );

  /// Screen title
  ///
  /// In ar, this message translates to:
  /// **'العملات'**
  String get ledgerCurrenciesTitle;

  /// Label
  ///
  /// In ar, this message translates to:
  /// **'العملة الأساسية'**
  String get ledgerBaseCurrency;

  /// Base currency explanation
  ///
  /// In ar, this message translates to:
  /// **'تُعرض بها كل المجاميع والرسوم البيانية'**
  String get ledgerBaseHint;

  /// Action
  ///
  /// In ar, this message translates to:
  /// **'تغيير العملة الأساسية'**
  String get ledgerChangeBase;

  /// Section title
  ///
  /// In ar, this message translates to:
  /// **'عملات أخرى'**
  String get ledgerOtherCurrencies;

  /// Action
  ///
  /// In ar, this message translates to:
  /// **'إضافة عملة'**
  String get ledgerAddCurrency;

  /// Sheet title
  ///
  /// In ar, this message translates to:
  /// **'عملة جديدة'**
  String get ledgerNewCurrency;

  /// Sheet title
  ///
  /// In ar, this message translates to:
  /// **'تعديل العملة'**
  String get ledgerEditCurrency;

  /// Field label (ISO-like code)
  ///
  /// In ar, this message translates to:
  /// **'الرمز الدولي'**
  String get ledgerCode;

  /// Code hint
  ///
  /// In ar, this message translates to:
  /// **'مثل EUR'**
  String get ledgerCodeHint;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'الاسم بالعربية'**
  String get ledgerNameAr;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'الاسم بالإنجليزية'**
  String get ledgerNameEn;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'الرمز المختصر'**
  String get ledgerSymbol;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'المنازل العشرية'**
  String get ledgerDecimals;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'سعر الصرف'**
  String get ledgerRate;

  /// Rate field hint
  ///
  /// In ar, this message translates to:
  /// **'يُدخَل يدويًا، دون اتصال بالإنترنت'**
  String get ledgerRateHint;

  /// Validation
  ///
  /// In ar, this message translates to:
  /// **'استخدم حروفًا لاتينية (مثل EUR)'**
  String get ledgerErrCode;

  /// Validation
  ///
  /// In ar, this message translates to:
  /// **'هذه العملة موجودة'**
  String get ledgerErrCodeExists;

  /// Validation
  ///
  /// In ar, this message translates to:
  /// **'أدخل سعرًا أكبر من صفر'**
  String get ledgerErrRate;

  /// Validation
  ///
  /// In ar, this message translates to:
  /// **'أدخل اسمًا'**
  String get ledgerErrName;

  /// Why a currency cannot be deleted
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{مستخدمة في محفظة واحدة} =2{مستخدمة في محفظتين} few{مستخدمة في {count} محافظ} many{مستخدمة في {count} محفظة} other{مستخدمة في {count} محفظة}}'**
  String ledgerCurrencyInUse(int count);

  /// Undo toast
  ///
  /// In ar, this message translates to:
  /// **'حُذفت العملة'**
  String get ledgerCurrencyDeleted;

  /// Undo toast
  ///
  /// In ar, this message translates to:
  /// **'حُفظت العملة'**
  String get ledgerCurrencySaved;

  /// Currency without a usable rate
  ///
  /// In ar, this message translates to:
  /// **'بلا سعر'**
  String get ledgerNoRate;

  /// Sheet title
  ///
  /// In ar, this message translates to:
  /// **'عملة أساسية جديدة'**
  String get ledgerRebaseTitle;

  /// Rebase explanation; code already isolated
  ///
  /// In ar, this message translates to:
  /// **'تُعاد كتابة كل الأسعار نسبةً إلى {code} بدقة، فتبقى القيم المحوّلة كما هي.'**
  String ledgerRebaseExplain(String code);

  /// Rebase preview column
  ///
  /// In ar, this message translates to:
  /// **'الآن'**
  String get ledgerRebaseNow;

  /// Rebase preview column
  ///
  /// In ar, this message translates to:
  /// **'بعد التغيير'**
  String get ledgerRebaseAfter;

  /// Confirm button
  ///
  /// In ar, this message translates to:
  /// **'اعتماد {code}'**
  String ledgerRebaseConfirm(String code);

  /// Undo toast
  ///
  /// In ar, this message translates to:
  /// **'أصبحت {code} العملة الأساسية'**
  String ledgerRebaseDone(String code);

  /// Rebase sheet subtitle
  ///
  /// In ar, this message translates to:
  /// **'اختر العملة الأساسية الجديدة'**
  String get ledgerRebaseChoose;

  /// Summary card empty title
  ///
  /// In ar, this message translates to:
  /// **'لا محافظ بعد'**
  String get ledgerSummaryEmpty;

  /// Summary card footer
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{ومحفظة أخرى} =2{ومحفظتان أخريان} few{و{count} محافظ أخرى} many{و{count} محفظة أخرى} other{و{count} محفظة أخرى}}'**
  String ledgerMoreWallets(int count);

  /// Screen-reader label of a wallet
  ///
  /// In ar, this message translates to:
  /// **'{name}، الرصيد {amount}'**
  String ledgerWalletSemantics(String name, String amount);

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'تطبيق'**
  String get ledgerApply;

  /// Tag filter without tags
  ///
  /// In ar, this message translates to:
  /// **'لا وسوم بعد'**
  String get ledgerNoTags;

  /// Suffix of compact chart amounts (thousands)
  ///
  /// In ar, this message translates to:
  /// **'ألف'**
  String get ledgerCompactThousand;

  /// Suffix of compact chart amounts (millions)
  ///
  /// In ar, this message translates to:
  /// **'مليون'**
  String get ledgerCompactMillion;

  /// Currency menu action
  ///
  /// In ar, this message translates to:
  /// **'اعتمادها عملة أساسية'**
  String get ledgerMakeBase;

  /// Currencies screen footnote
  ///
  /// In ar, this message translates to:
  /// **'الأسعار يدوية؛ حدّثها حين يتغيّر السوق'**
  String get ledgerRatesStale;

  /// Hint of the note field when adding income
  ///
  /// In ar, this message translates to:
  /// **'مثلًا: تحصيل من شركة الشحن'**
  String get ledgerNoteHintIncome;

  /// Hint of the note field when adding a transfer
  ///
  /// In ar, this message translates to:
  /// **'مثلًا: إيداع في البنك'**
  String get ledgerNoteHintTransfer;

  /// Hint of the note field when adding a balance adjustment
  ///
  /// In ar, this message translates to:
  /// **'مثلًا: بعد عدّ النقود'**
  String get ledgerNoteHintAdjust;

  /// Source of a wallet entry written by a savings jar deposit or withdrawal; also the label of its tag
  ///
  /// In ar, this message translates to:
  /// **'حصّالة'**
  String get ledgerLinkJar;

  /// Source of a wallet entry written by a debt payment; also the label of its tag
  ///
  /// In ar, this message translates to:
  /// **'دَين'**
  String get ledgerLinkDebt;

  /// Source of a wallet entry written when a recurring obligation is marked paid; also the label of its tag
  ///
  /// In ar, this message translates to:
  /// **'التزام'**
  String get ledgerLinkObligation;

  /// Menu action on a wallet entry that belongs to a savings jar
  ///
  /// In ar, this message translates to:
  /// **'فتح الحصّالة'**
  String get ledgerOpenJar;

  /// Menu action on a wallet entry that belongs to a debt
  ///
  /// In ar, this message translates to:
  /// **'فتح الدَّين'**
  String get ledgerOpenDebt;

  /// Menu action on a wallet entry that belongs to a recurring obligation
  ///
  /// In ar, this message translates to:
  /// **'فتح الالتزام'**
  String get ledgerOpenObligation;

  /// Accessibility hint: this entry is edited from its savings jar, debt or obligation
  ///
  /// In ar, this message translates to:
  /// **'تُعدَّل من {source}'**
  String ledgerLinkedHint(String source);

  /// Status shown on an archived wallet
  ///
  /// In ar, this message translates to:
  /// **'مؤرشفة'**
  String get ledgerArchivedBadge;

  /// Notice on the currencies screen when wallets use currency codes missing from the list (e.g. created by quick add)
  ///
  /// In ar, this message translates to:
  /// **'بعض المحافظ بعملات غير موجودة في قائمتك بعد. أضِفها مع سعر صرف لتدخل في المجاميع.'**
  String get ledgerUnknownCurrencies;

  /// Chip adding a missing currency by its code
  ///
  /// In ar, this message translates to:
  /// **'إضافة {code}'**
  String ledgerAddCode(String code);

  /// Action next to the warning that some currencies have no exchange rate
  ///
  /// In ar, this message translates to:
  /// **'ضبط الأسعار'**
  String get ledgerFixRates;

  /// Title of the budget screen and card
  ///
  /// In ar, this message translates to:
  /// **'الميزانية'**
  String get budgetTitle;

  /// Budget tab: the nested plan editor
  ///
  /// In ar, this message translates to:
  /// **'الخطة'**
  String get budgetTabPlan;

  /// Budget tab: spend vs plan
  ///
  /// In ar, this message translates to:
  /// **'الإنفاق'**
  String get budgetTabSpending;

  /// Button / FAB: add a top-level budget item
  ///
  /// In ar, this message translates to:
  /// **'إضافة بند'**
  String get budgetAddItem;

  /// Label above the monthly budget total
  ///
  /// In ar, this message translates to:
  /// **'الخطة الشهرية'**
  String get budgetMonthlyPlan;

  /// Weekly equivalent of the total (amount formatted)
  ///
  /// In ar, this message translates to:
  /// **'≈ {amount} في الأسبوع'**
  String budgetWeeklyEquivalent(String amount);

  /// Chip showing the weeks-per-month setting
  ///
  /// In ar, this message translates to:
  /// **'أسابيع الشهر: {weeks}'**
  String budgetWeeksPerMonthChip(String weeks);

  /// Semantics / title of the allocation strip
  ///
  /// In ar, this message translates to:
  /// **'توزيع الخطة'**
  String get budgetAllocation;

  /// Shown when the budget has no warnings
  ///
  /// In ar, this message translates to:
  /// **'كل البنود متوازنة'**
  String get budgetBalanced;

  /// Title of the warnings summary
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{أمر واحد يحتاج انتباهك} =2{أمران يحتاجان انتباهك} few{{count} أمور تحتاج انتباهك} many{{count} أمرًا يحتاج انتباهك} other{{count} أمر يحتاج انتباهك}}'**
  String budgetWarningsTitle(int count);

  /// Collapsed tail of the warnings summary
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{وأمر آخر} =2{وأمران آخران} few{و{count} أمور أخرى} many{و{count} أمرًا آخر} other{و{count} أمر آخر}}'**
  String budgetWarningsMore(int count);

  /// Collapses the warnings summary
  ///
  /// In ar, this message translates to:
  /// **'عرض أقل'**
  String get budgetShowLess;

  /// Warning: children sum below the parent
  ///
  /// In ar, this message translates to:
  /// **'بنود «{name}» الفرعية أقلّ منه بـ{amount}'**
  String budgetIssueChildrenUnder(String name, String amount);

  /// Warning: children sum above the parent
  ///
  /// In ar, this message translates to:
  /// **'بنود «{name}» الفرعية تتجاوزه بـ{amount}'**
  String budgetIssueChildrenOver(String name, String amount);

  /// Warning: an item set above 100 percent
  ///
  /// In ar, this message translates to:
  /// **'نسبة «{name}» أكبر من أصلها: {percent}'**
  String budgetIssuePercentSelf(String name, String percent);

  /// Warning: children percentages above 100 percent
  ///
  /// In ar, this message translates to:
  /// **'نِسب بنود «{name}» الفرعية مجموعها {percent}'**
  String budgetIssuePercentChildren(String name, String percent);

  /// Warning: root percentages of the total above 100 percent
  ///
  /// In ar, this message translates to:
  /// **'البنود المحدّدة بنسبة من الإجمالي مجموعها {percent}'**
  String budgetIssuePercentTotal(String percent);

  /// Warning: circular percentages
  ///
  /// In ar, this message translates to:
  /// **'نِسب «{name}» تعتمد على بعضها فتعذّر حسابها'**
  String budgetIssueCircular(String name);

  /// Warning: root percentages of the total equal 100 percent
  ///
  /// In ar, this message translates to:
  /// **'البنود المحدّدة بنسبة من الإجمالي تستهلكه كلّه'**
  String get budgetIssueCircularTotal;

  /// Warning: parent loop
  ///
  /// In ar, this message translates to:
  /// **'«{name}» كان داخل نفسه، فيظهر في المستوى الأعلى'**
  String budgetIssueCircularParent(String name);

  /// Warning: missing parent
  ///
  /// In ar, this message translates to:
  /// **'البند الأب لـ«{name}» غير موجود، فيظهر في المستوى الأعلى'**
  String budgetIssueOrphan(String name);

  /// Warning: missing exchange rate
  ///
  /// In ar, this message translates to:
  /// **'لا سعر صرف مسجّل لـ{currency}، فاحتُسب واحدًا بواحد'**
  String budgetIssueMissingRate(String currency);

  /// Warning: overspent this month
  ///
  /// In ar, this message translates to:
  /// **'تجاوز «{name}» خطّته بـ{amount} هذا الشهر'**
  String budgetIssueOverspent(String name, String amount);

  /// Badge: children leave this much of the parent unallocated
  ///
  /// In ar, this message translates to:
  /// **'{amount} غير موزّع'**
  String budgetBadgeUnder(String amount);

  /// Badge: children exceed the parent
  ///
  /// In ar, this message translates to:
  /// **'زيادة {amount}'**
  String budgetBadgeOver(String amount);

  /// Badge on an item whose own percentage is above 100 percent
  ///
  /// In ar, this message translates to:
  /// **'{percent} أكبر من الأصل'**
  String budgetBadgePercent(String percent);

  /// Badge on a parent whose sub-items' percentages add up to more than 100 percent
  ///
  /// In ar, this message translates to:
  /// **'مجموع نِسب الفروع {percent}'**
  String budgetBadgePercentChildren(String percent);

  /// Badge: circular percentages
  ///
  /// In ar, this message translates to:
  /// **'نِسب متداخلة'**
  String get budgetBadgeCircular;

  /// Badge: parent missing or loop
  ///
  /// In ar, this message translates to:
  /// **'نُقل للأعلى'**
  String get budgetBadgeMoved;

  /// Badge: missing exchange rate
  ///
  /// In ar, this message translates to:
  /// **'بلا سعر صرف'**
  String get budgetBadgeNoRate;

  /// Badge: overspent this month
  ///
  /// In ar, this message translates to:
  /// **'تجاوز بـ{amount}'**
  String budgetBadgeOverspent(String amount);

  /// Share of the parent item
  ///
  /// In ar, this message translates to:
  /// **'{percent} من «{name}»'**
  String budgetPercentOf(String percent, String name);

  /// Share of the total budget
  ///
  /// In ar, this message translates to:
  /// **'{percent} من الإجمالي'**
  String budgetPercentOfTotal(String percent);

  /// Amount per month
  ///
  /// In ar, this message translates to:
  /// **'{amount} شهريًا'**
  String budgetPerMonth(String amount);

  /// Amount per week
  ///
  /// In ar, this message translates to:
  /// **'{amount} أسبوعيًا'**
  String budgetPerWeek(String amount);

  /// Monthly equivalent in the base currency
  ///
  /// In ar, this message translates to:
  /// **'≈ {amount} شهريًا'**
  String budgetApproxMonthly(String amount);

  /// Item whose plan is the sum of its children
  ///
  /// In ar, this message translates to:
  /// **'مجموع البنود الفرعية'**
  String get budgetSumOfChildren;

  /// Children sum vs the parent plan
  ///
  /// In ar, this message translates to:
  /// **'الفروع: {sum} من {plan}'**
  String budgetChildrenSum(String sum, String plan);

  /// Semantics: item set by an amount
  ///
  /// In ar, this message translates to:
  /// **'محدّد بالمبلغ'**
  String get budgetSetByAmount;

  /// Semantics: item set by a percentage
  ///
  /// In ar, this message translates to:
  /// **'محدّد بالنسبة'**
  String get budgetSetByPercent;

  /// Hint under the tree
  ///
  /// In ar, this message translates to:
  /// **'اسحب المقبض لترتيب البنود داخل مجموعتها'**
  String get budgetDragHint;

  /// Menu: add a child item
  ///
  /// In ar, this message translates to:
  /// **'إضافة بند فرعي'**
  String get budgetAddChild;

  /// Menu: add a sibling item right after this one
  ///
  /// In ar, this message translates to:
  /// **'إضافة بند مجاور'**
  String get budgetAddSibling;

  /// Title of the move sheet
  ///
  /// In ar, this message translates to:
  /// **'نقل «{name}»'**
  String budgetMoveTitle(String name);

  /// Subtitle of the move sheet
  ///
  /// In ar, this message translates to:
  /// **'يبقى مبلغه كما هو'**
  String get budgetMoveSubtitle;

  /// No parent
  ///
  /// In ar, this message translates to:
  /// **'المستوى الأعلى'**
  String get budgetTopLevel;

  /// Undo toast after deleting an item with its sub-items
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{حُذف البند} =1{حُذف البند وبند فرعي} =2{حُذف البند وبندان فرعيان} few{حُذف البند و{count} بنود فرعية} many{حُذف البند و{count} بندًا فرعيًا} other{حُذف البند و{count} بند فرعي}}'**
  String budgetDeletedWithChildren(int count);

  /// Undo toast after editing an item
  ///
  /// In ar, this message translates to:
  /// **'حُفظ البند'**
  String get budgetSaved;

  /// Undo toast after adding an item
  ///
  /// In ar, this message translates to:
  /// **'أُضيف البند'**
  String get budgetAdded;

  /// Empty plan title
  ///
  /// In ar, this message translates to:
  /// **'لا ميزانية بعد'**
  String get budgetEmptyTitle;

  /// Empty plan body
  ///
  /// In ar, this message translates to:
  /// **'خطّط بالمبلغ أو بالنسبة، وضع البنود داخل بعضها، ثم قارن إنفاقك بالخطة.'**
  String get budgetEmptyBody;

  /// Empty plan action
  ///
  /// In ar, this message translates to:
  /// **'أضف أول بند'**
  String get budgetEmptyAction;

  /// Title of the weeks-per-month sheet
  ///
  /// In ar, this message translates to:
  /// **'أسابيع الشهر'**
  String get budgetWeeksTitle;

  /// Subtitle of the weeks-per-month sheet
  ///
  /// In ar, this message translates to:
  /// **'تُضرب البنود الأسبوعية في هذا العدد لحساب خطتها الشهرية'**
  String get budgetWeeksSubtitle;

  /// Preset: 4 weeks per month
  ///
  /// In ar, this message translates to:
  /// **'أسابيع كاملة'**
  String get budgetWeeksRound;

  /// Preset: 4.345 weeks per month
  ///
  /// In ar, this message translates to:
  /// **'متوسط التقويم'**
  String get budgetWeeksCalendar;

  /// Custom weeks-per-month field label
  ///
  /// In ar, this message translates to:
  /// **'عدد آخر'**
  String get budgetWeeksCustom;

  /// Weeks-per-month validation
  ///
  /// In ar, this message translates to:
  /// **'أدخل عددًا بين {min} و{max}'**
  String budgetWeeksInvalid(String min, String max);

  /// Live example of the conversion
  ///
  /// In ar, this message translates to:
  /// **'{weekly} أسبوعيًا = {monthly} شهريًا'**
  String budgetWeeksExample(String weekly, String monthly);

  /// Undo toast after changing weeks per month
  ///
  /// In ar, this message translates to:
  /// **'تغيّر عدد أسابيع الشهر'**
  String get budgetWeeksSaved;

  /// Item sheet title: new top-level item
  ///
  /// In ar, this message translates to:
  /// **'بند جديد'**
  String get budgetNewItem;

  /// Item sheet title: new child
  ///
  /// In ar, this message translates to:
  /// **'بند فرعي في «{name}»'**
  String budgetNewChild(String name);

  /// Item sheet title: edit
  ///
  /// In ar, this message translates to:
  /// **'تعديل البند'**
  String get budgetEditItem;

  /// Item sheet: name field
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get budgetFieldName;

  /// Item sheet: name hint
  ///
  /// In ar, this message translates to:
  /// **'مثل: البقالة'**
  String get budgetFieldNameHint;

  /// Item sheet: parent picker
  ///
  /// In ar, this message translates to:
  /// **'ضمن'**
  String get budgetFieldParent;

  /// Item sheet: amount / percent / sum switch
  ///
  /// In ar, this message translates to:
  /// **'يُحدَّد بـ'**
  String get budgetFieldSetBy;

  /// Mode: amount
  ///
  /// In ar, this message translates to:
  /// **'مبلغ'**
  String get budgetModeAmount;

  /// Mode: percentage
  ///
  /// In ar, this message translates to:
  /// **'نسبة'**
  String get budgetModePercent;

  /// Mode: sum of the sub-items
  ///
  /// In ar, this message translates to:
  /// **'مجموع الفروع'**
  String get budgetModeSum;

  /// Item sheet: amount field
  ///
  /// In ar, this message translates to:
  /// **'المبلغ'**
  String get budgetFieldAmount;

  /// Item sheet: percentage field
  ///
  /// In ar, this message translates to:
  /// **'النسبة'**
  String get budgetFieldPercent;

  /// Percent base chip: of the parent
  ///
  /// In ar, this message translates to:
  /// **'من «{name}»'**
  String budgetOfParent(String name);

  /// Percent base chip: of the total
  ///
  /// In ar, this message translates to:
  /// **'من الإجمالي'**
  String get budgetOfTotal;

  /// Tag on the value derived from the other one
  ///
  /// In ar, this message translates to:
  /// **'محسوب'**
  String get budgetCalculated;

  /// Item sheet: period field
  ///
  /// In ar, this message translates to:
  /// **'الفترة'**
  String get budgetFieldPeriod;

  /// Period: monthly
  ///
  /// In ar, this message translates to:
  /// **'شهري'**
  String get budgetMonthly;

  /// Period: weekly
  ///
  /// In ar, this message translates to:
  /// **'أسبوعي'**
  String get budgetWeekly;

  /// Item sheet: currency field
  ///
  /// In ar, this message translates to:
  /// **'العملة'**
  String get budgetFieldCurrency;

  /// Currency chip of the base currency
  ///
  /// In ar, this message translates to:
  /// **'{code} · الأساس'**
  String budgetBaseCurrency(String code);

  /// Item sheet: live preview header
  ///
  /// In ar, this message translates to:
  /// **'في الميزانية'**
  String get budgetPreviewTitle;

  /// Item sheet: invalid amount
  ///
  /// In ar, this message translates to:
  /// **'أدخل مبلغًا صحيحًا، صفرًا أو أكثر'**
  String get budgetAmountInvalid;

  /// Item sheet: invalid percentage
  ///
  /// In ar, this message translates to:
  /// **'أدخل نسبة صحيحة، صفرًا أو أكثر'**
  String get budgetPercentInvalid;

  /// Item sheet: explanation of the sum mode
  ///
  /// In ar, this message translates to:
  /// **'يساوي مجموع بنوده الفرعية ويتغيّر معها'**
  String get budgetSumHint;

  /// Budget picker title
  ///
  /// In ar, this message translates to:
  /// **'بند الميزانية'**
  String get budgetPickerTitle;

  /// Budget picker search hint
  ///
  /// In ar, this message translates to:
  /// **'ابحث في البنود'**
  String get budgetPickerSearch;

  /// Budget picker: clear the item
  ///
  /// In ar, this message translates to:
  /// **'بلا بند'**
  String get budgetPickerNone;

  /// Budget picker: empty budget
  ///
  /// In ar, this message translates to:
  /// **'لا بنود في الميزانية بعد'**
  String get budgetPickerEmpty;

  /// Budget picker: search found nothing
  ///
  /// In ar, this message translates to:
  /// **'لا بنود مطابقة'**
  String get budgetPickerNoResults;

  /// Budget picker field placeholder
  ///
  /// In ar, this message translates to:
  /// **'اختر بندًا'**
  String get budgetPickerPlaceholder;

  /// Remaining amount
  ///
  /// In ar, this message translates to:
  /// **'متبقٍّ {amount}'**
  String budgetLeft(String amount);

  /// Overspent amount
  ///
  /// In ar, this message translates to:
  /// **'تجاوز {amount}'**
  String budgetOverBy(String amount);

  /// Marks the current choice in the picker
  ///
  /// In ar, this message translates to:
  /// **'الحالي'**
  String get budgetCurrentBadge;

  /// Semantics: go to the previous period
  ///
  /// In ar, this message translates to:
  /// **'الفترة السابقة'**
  String get budgetPreviousPeriod;

  /// Semantics: go to the next period
  ///
  /// In ar, this message translates to:
  /// **'الفترة التالية'**
  String get budgetNextPeriod;

  /// Label: spent
  ///
  /// In ar, this message translates to:
  /// **'المصروف'**
  String get budgetSpent;

  /// Under the spent amount: of the plan
  ///
  /// In ar, this message translates to:
  /// **'من {amount}'**
  String budgetOfPlan(String amount);

  /// Label: remaining
  ///
  /// In ar, this message translates to:
  /// **'المتبقي'**
  String get budgetRemaining;

  /// Label: amount over the plan
  ///
  /// In ar, this message translates to:
  /// **'فوق الخطة'**
  String get budgetOverPlan;

  /// Label: projected end-of-period spend
  ///
  /// In ar, this message translates to:
  /// **'بهذا المعدّل'**
  String get budgetProjection;

  /// Projected spend by the end of the month
  ///
  /// In ar, this message translates to:
  /// **'{amount} بنهاية الشهر'**
  String budgetProjectionMonth(String amount);

  /// Projected spend by the end of the week
  ///
  /// In ar, this message translates to:
  /// **'{amount} بنهاية الأسبوع'**
  String budgetProjectionWeek(String amount);

  /// Progress through the period
  ///
  /// In ar, this message translates to:
  /// **'اليوم {day} من {days}'**
  String budgetDayOf(String day, String days);

  /// Shown for a past period
  ///
  /// In ar, this message translates to:
  /// **'فترة منتهية'**
  String get budgetPeriodClosed;

  /// Expenses booked to no item
  ///
  /// In ar, this message translates to:
  /// **'خارج الميزانية'**
  String get budgetUnassigned;

  /// Spend status
  ///
  /// In ar, this message translates to:
  /// **'ضمن الخطة'**
  String get budgetStatusCalm;

  /// Spend status
  ///
  /// In ar, this message translates to:
  /// **'قارب النفاد'**
  String get budgetStatusNear;

  /// Spend status
  ///
  /// In ar, this message translates to:
  /// **'في طريقه للتجاوز'**
  String get budgetStatusAtRisk;

  /// Spend status
  ///
  /// In ar, this message translates to:
  /// **'تجاوز الخطة'**
  String get budgetStatusOver;

  /// Spend status
  ///
  /// In ar, this message translates to:
  /// **'بلا خطة'**
  String get budgetStatusUnplanned;

  /// Spent of planned
  ///
  /// In ar, this message translates to:
  /// **'{spent} من {plan}'**
  String budgetSpentOf(String spent, String plan);

  /// Section title: per-item bars
  ///
  /// In ar, this message translates to:
  /// **'حسب البند'**
  String get budgetByItem;

  /// Section title: history of months
  ///
  /// In ar, this message translates to:
  /// **'الأشهر السابقة'**
  String get budgetHistoryMonths;

  /// Section title: history of weeks
  ///
  /// In ar, this message translates to:
  /// **'الأسابيع السابقة'**
  String get budgetHistoryWeeks;

  /// Chart legend: plan
  ///
  /// In ar, this message translates to:
  /// **'الخطة'**
  String get budgetLegendPlan;

  /// Chart legend: spent
  ///
  /// In ar, this message translates to:
  /// **'المصروف'**
  String get budgetLegendSpent;

  /// Note under the history chart
  ///
  /// In ar, this message translates to:
  /// **'تُقارن الفترات السابقة بخطة اليوم'**
  String get budgetHistoryNote;

  /// Spending tab: nothing spent
  ///
  /// In ar, this message translates to:
  /// **'لا مصروفات في هذه الفترة بعد'**
  String get budgetNoSpending;

  /// Semantics of a history bar
  ///
  /// In ar, this message translates to:
  /// **'{period}: {spent} من {plan}'**
  String budgetHistoryBar(String period, String spent, String plan);

  /// Status card: spent of plan
  ///
  /// In ar, this message translates to:
  /// **'صُرف {spent} من {plan}'**
  String budgetCardSpentOf(String spent, String plan);

  /// Status card: no budget yet
  ///
  /// In ar, this message translates to:
  /// **'خطّط ميزانيتك بالمبلغ أو بالنسبة'**
  String get budgetCardEmpty;

  /// Status card: warnings count
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{تنبيه واحد} =2{تنبيهان} few{{count} تنبيهات} many{{count} تنبيهًا} other{{count} تنبيه}}'**
  String budgetCardWarnings(int count);

  /// Goals screen title (jars, debts, recurring obligations)
  ///
  /// In ar, this message translates to:
  /// **'المدّخرات والالتزامات'**
  String get goalsTitle;

  /// No description provided for @goalsTabJars.
  ///
  /// In ar, this message translates to:
  /// **'الحصّالات'**
  String get goalsTabJars;

  /// No description provided for @goalsTabDebts.
  ///
  /// In ar, this message translates to:
  /// **'الديون'**
  String get goalsTabDebts;

  /// No description provided for @goalsTabObligations.
  ///
  /// In ar, this message translates to:
  /// **'الالتزامات'**
  String get goalsTabObligations;

  /// No description provided for @goalsDebtsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الديون'**
  String get goalsDebtsTitle;

  /// No description provided for @goalsObligationsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الالتزامات الدورية'**
  String get goalsObligationsTitle;

  /// No description provided for @goalsUpcomingTitle.
  ///
  /// In ar, this message translates to:
  /// **'مستحقات قريبة'**
  String get goalsUpcomingTitle;

  /// No description provided for @goalsSeeAll.
  ///
  /// In ar, this message translates to:
  /// **'عرض الكل'**
  String get goalsSeeAll;

  /// No description provided for @goalsCreate.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء'**
  String get goalsCreate;

  /// No description provided for @goalsGone.
  ///
  /// In ar, this message translates to:
  /// **'لم يعد هذا العنصر موجودًا.'**
  String get goalsGone;

  /// No description provided for @goalsShow.
  ///
  /// In ar, this message translates to:
  /// **'إظهار'**
  String get goalsShow;

  /// No description provided for @goalsHide.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء'**
  String get goalsHide;

  /// No description provided for @goalsFilterAll.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get goalsFilterAll;

  /// No description provided for @goalsAmountPositive.
  ///
  /// In ar, this message translates to:
  /// **'أدخل مبلغًا أكبر من صفر'**
  String get goalsAmountPositive;

  /// No description provided for @goalsFieldAmount.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ'**
  String get goalsFieldAmount;

  /// No description provided for @goalsFieldDate.
  ///
  /// In ar, this message translates to:
  /// **'التاريخ'**
  String get goalsFieldDate;

  /// No description provided for @goalsFieldNote.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة'**
  String get goalsFieldNote;

  /// No description provided for @goalsFieldFromWallet.
  ///
  /// In ar, this message translates to:
  /// **'من محفظة'**
  String get goalsFieldFromWallet;

  /// No description provided for @goalsFieldToWallet.
  ///
  /// In ar, this message translates to:
  /// **'إلى محفظة'**
  String get goalsFieldToWallet;

  /// No description provided for @goalsNoWallet.
  ///
  /// In ar, this message translates to:
  /// **'بلا محفظة'**
  String get goalsNoWallet;

  /// Between a saved amount and its target: "120 of 500"
  ///
  /// In ar, this message translates to:
  /// **'من'**
  String get goalsOf;

  /// No description provided for @goalsOfTotal.
  ///
  /// In ar, this message translates to:
  /// **'من {amount}'**
  String goalsOfTotal(String amount);

  /// No description provided for @goalsSavedOfTarget.
  ///
  /// In ar, this message translates to:
  /// **'{saved} من {target}'**
  String goalsSavedOfTarget(String saved, String target);

  /// A jar deposit taken from a wallet
  ///
  /// In ar, this message translates to:
  /// **'من {name}'**
  String goalsFromWallet(String name);

  /// A jar withdrawal paid into a wallet
  ///
  /// In ar, this message translates to:
  /// **'إلى {name}'**
  String goalsToWallet(String name);

  /// No description provided for @goalsMissingRates.
  ///
  /// In ar, this message translates to:
  /// **'لا سعر صرف لـ{codes}، فحُسبت بقيمتها الاسمية.'**
  String goalsMissingRates(String codes);

  /// No description provided for @goalsDueToday.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get goalsDueToday;

  /// No description provided for @goalsDueTomorrow.
  ///
  /// In ar, this message translates to:
  /// **'غدًا'**
  String get goalsDueTomorrow;

  /// No description provided for @goalsDueInDays.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{بعد يوم} =2{بعد يومين} few{بعد {n} أيام} many{بعد {n} يومًا} other{بعد {n} يوم}}'**
  String goalsDueInDays(int count, String n);

  /// No description provided for @goalsOverdueDays.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{متأخر يومًا} =2{متأخر يومين} few{متأخر {n} أيام} many{متأخر {n} يومًا} other{متأخر {n} يوم}}'**
  String goalsOverdueDays(int count, String n);

  /// No description provided for @goalsDueOn.
  ///
  /// In ar, this message translates to:
  /// **'في {date}'**
  String goalsDueOn(String date);

  /// No description provided for @goalsEveryWeeks.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{كل أسبوع} =2{كل أسبوعين} few{كل {n} أسابيع} many{كل {n} أسبوعًا} other{كل {n} أسبوع}}'**
  String goalsEveryWeeks(int count, String n);

  /// No description provided for @goalsEveryMonths.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{كل شهر} =2{كل شهرين} few{كل {n} أشهر} many{كل {n} شهرًا} other{كل {n} شهر}}'**
  String goalsEveryMonths(int count, String n);

  /// No description provided for @goalsEveryYears.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{كل سنة} =2{كل سنتين} few{كل {n} سنوات} many{كل {n} سنةً} other{كل {n} سنة}}'**
  String goalsEveryYears(int count, String n);

  /// No description provided for @goalsJarNew.
  ///
  /// In ar, this message translates to:
  /// **'حصّالة جديدة'**
  String get goalsJarNew;

  /// No description provided for @goalsJarNewSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'هدف ادّخار له مبلغ وموعد'**
  String get goalsJarNewSubtitle;

  /// No description provided for @goalsJarEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الحصّالة'**
  String get goalsJarEdit;

  /// No description provided for @goalsFieldJarName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get goalsFieldJarName;

  /// No description provided for @goalsFieldJarNameHint.
  ///
  /// In ar, this message translates to:
  /// **'مثلًا: السفر'**
  String get goalsFieldJarNameHint;

  /// No description provided for @goalsFieldTarget.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ المستهدف'**
  String get goalsFieldTarget;

  /// No description provided for @goalsFieldDeadline.
  ///
  /// In ar, this message translates to:
  /// **'الموعد النهائي'**
  String get goalsFieldDeadline;

  /// No description provided for @goalsFieldIcon.
  ///
  /// In ar, this message translates to:
  /// **'الرمز'**
  String get goalsFieldIcon;

  /// No description provided for @goalsFieldColor.
  ///
  /// In ar, this message translates to:
  /// **'اللون'**
  String get goalsFieldColor;

  /// No description provided for @goalsDeposit.
  ///
  /// In ar, this message translates to:
  /// **'إيداع'**
  String get goalsDeposit;

  /// No description provided for @goalsWithdraw.
  ///
  /// In ar, this message translates to:
  /// **'سحب'**
  String get goalsWithdraw;

  /// No description provided for @goalsDepositTo.
  ///
  /// In ar, this message translates to:
  /// **'إيداع في {name}'**
  String goalsDepositTo(String name);

  /// No description provided for @goalsWithdrawFrom.
  ///
  /// In ar, this message translates to:
  /// **'سحب من {name}'**
  String goalsWithdrawFrom(String name);

  /// No description provided for @goalsWithdrawTooMuch.
  ///
  /// In ar, this message translates to:
  /// **'المدّخر {amount} فقط'**
  String goalsWithdrawTooMuch(String amount);

  /// No description provided for @goalsJarReached.
  ///
  /// In ar, this message translates to:
  /// **'بلغت {name} هدفها!'**
  String goalsJarReached(String name);

  /// No description provided for @goalsDeposited.
  ///
  /// In ar, this message translates to:
  /// **'أُودِع {amount}'**
  String goalsDeposited(String amount);

  /// No description provided for @goalsWithdrawn.
  ///
  /// In ar, this message translates to:
  /// **'سُحب {amount}'**
  String goalsWithdrawn(String amount);

  /// No description provided for @goalsJarArchived.
  ///
  /// In ar, this message translates to:
  /// **'أُرشفت الحصّالة'**
  String get goalsJarArchived;

  /// No description provided for @goalsJarRestored.
  ///
  /// In ar, this message translates to:
  /// **'أُعيدت الحصّالة'**
  String get goalsJarRestored;

  /// No description provided for @goalsArchive.
  ///
  /// In ar, this message translates to:
  /// **'أرشفة'**
  String get goalsArchive;

  /// No description provided for @goalsUnarchive.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الأرشفة'**
  String get goalsUnarchive;

  /// No description provided for @goalsArchivedJars.
  ///
  /// In ar, this message translates to:
  /// **'حصّالات مؤرشفة'**
  String get goalsArchivedJars;

  /// No description provided for @goalsJarsEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا حصّالات بعد'**
  String get goalsJarsEmptyTitle;

  /// No description provided for @goalsJarsEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'خصّص حصّالة لكل هدف – سفر، طوارئ، هدية – وراقبها تمتلئ.'**
  String get goalsJarsEmptyBody;

  /// No description provided for @goalsJarsHint.
  ///
  /// In ar, this message translates to:
  /// **'اسحب الحصّالة لإيداع سريع، واضغط مطوّلًا لبقية الخيارات، واسحب المقبض لترتيبها.'**
  String get goalsJarsHint;

  /// No description provided for @goalsJarsReachedCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{حصّالة بلغت هدفها} =2{حصّالتان بلغتا هدفيهما} few{{n} حصّالات بلغت أهدافها} many{{n} حصّالةً بلغت أهدافها} other{{n} حصّالة بلغت أهدافها}}'**
  String goalsJarsReachedCount(int count, String n);

  /// No description provided for @goalsSavedInJars.
  ///
  /// In ar, this message translates to:
  /// **'المدّخر في الحصّالات'**
  String get goalsSavedInJars;

  /// No description provided for @goalsNeededThisMonth.
  ///
  /// In ar, this message translates to:
  /// **'المطلوب هذا الشهر'**
  String get goalsNeededThisMonth;

  /// No description provided for @goalsOfTargets.
  ///
  /// In ar, this message translates to:
  /// **'من الأهداف'**
  String get goalsOfTargets;

  /// No description provided for @goalsOverallProgress.
  ///
  /// In ar, this message translates to:
  /// **'التقدّم الكلّي {percent}'**
  String goalsOverallProgress(String percent);

  /// No description provided for @goalsNeedPerMonth.
  ///
  /// In ar, this message translates to:
  /// **'{amount} شهريًا'**
  String goalsNeedPerMonth(String amount);

  /// No description provided for @goalsDeadlineOn.
  ///
  /// In ar, this message translates to:
  /// **'حتى {date}'**
  String goalsDeadlineOn(String date);

  /// No description provided for @goalsSurplus.
  ///
  /// In ar, this message translates to:
  /// **'فائض {amount}'**
  String goalsSurplus(String amount);

  /// No description provided for @goalsTargetOf.
  ///
  /// In ar, this message translates to:
  /// **'الهدف {amount}'**
  String goalsTargetOf(String amount);

  /// No description provided for @goalsNoDeadlineHint.
  ///
  /// In ar, this message translates to:
  /// **'أضف موعدًا لتعرف المطلوب شهريًا'**
  String get goalsNoDeadlineHint;

  /// No description provided for @goalsPaceReached.
  ///
  /// In ar, this message translates to:
  /// **'بلغت الهدف'**
  String get goalsPaceReached;

  /// No description provided for @goalsPaceOnTrack.
  ///
  /// In ar, this message translates to:
  /// **'على المسار'**
  String get goalsPaceOnTrack;

  /// No description provided for @goalsPaceBehind.
  ///
  /// In ar, this message translates to:
  /// **'متأخرة عن الخطة'**
  String get goalsPaceBehind;

  /// No description provided for @goalsPaceOverdue.
  ///
  /// In ar, this message translates to:
  /// **'فات الموعد'**
  String get goalsPaceOverdue;

  /// No description provided for @goalsPaceOpen.
  ///
  /// In ar, this message translates to:
  /// **'بلا موعد'**
  String get goalsPaceOpen;

  /// No description provided for @goalsBalanceAfter.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد بعدها: {amount}'**
  String goalsBalanceAfter(String amount);

  /// No description provided for @goalsPercentOfTarget.
  ///
  /// In ar, this message translates to:
  /// **'{percent} من الهدف'**
  String goalsPercentOfTarget(String percent);

  /// No description provided for @goalsWalletAmount.
  ///
  /// In ar, this message translates to:
  /// **'بعملة المحفظة: {amount}'**
  String goalsWalletAmount(String amount);

  /// No description provided for @goalsTrajectory.
  ///
  /// In ar, this message translates to:
  /// **'مسار الادّخار'**
  String get goalsTrajectory;

  /// No description provided for @goalsHistory.
  ///
  /// In ar, this message translates to:
  /// **'السجلّ'**
  String get goalsHistory;

  /// No description provided for @goalsNoMovements.
  ///
  /// In ar, this message translates to:
  /// **'لا إيداعات بعد'**
  String get goalsNoMovements;

  /// No description provided for @goalsDeleteJar.
  ///
  /// In ar, this message translates to:
  /// **'حذف الحصّالة'**
  String get goalsDeleteJar;

  /// No description provided for @goalsAlidadeHint.
  ///
  /// In ar, this message translates to:
  /// **'المؤشّر الذهبي يدلّ على موضعك المفترض اليوم ({percent})'**
  String goalsAlidadeHint(String percent);

  /// No description provided for @goalsRemaining.
  ///
  /// In ar, this message translates to:
  /// **'المتبقّي'**
  String get goalsRemaining;

  /// No description provided for @goalsSurplusLabel.
  ///
  /// In ar, this message translates to:
  /// **'فوق الهدف'**
  String get goalsSurplusLabel;

  /// No description provided for @goalsNeededNow.
  ///
  /// In ar, this message translates to:
  /// **'المطلوب الآن'**
  String get goalsNeededNow;

  /// No description provided for @goalsPerMonth.
  ///
  /// In ar, this message translates to:
  /// **'المطلوب شهريًا'**
  String get goalsPerMonth;

  /// No description provided for @goalsPerWeekCaption.
  ///
  /// In ar, this message translates to:
  /// **'أو {amount} أسبوعيًا'**
  String goalsPerWeekCaption(String amount);

  /// No description provided for @goalsDaysLeft.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{ينتهي اليوم} =1{باقٍ يوم واحد} =2{باقٍ يومان} few{باقٍ {n} أيام} many{باقٍ {n} يومًا} other{باقٍ {n} يوم}}'**
  String goalsDaysLeft(int count, String n);

  /// No description provided for @goalsAtYourPace.
  ///
  /// In ar, this message translates to:
  /// **'بوتيرتك الحالية'**
  String get goalsAtYourPace;

  /// No description provided for @goalsAfterDeadline.
  ///
  /// In ar, this message translates to:
  /// **'بعد الموعد'**
  String get goalsAfterDeadline;

  /// No description provided for @goalsBeforeDeadline.
  ///
  /// In ar, this message translates to:
  /// **'قبل الموعد'**
  String get goalsBeforeDeadline;

  /// No description provided for @goalsSavedTotal.
  ///
  /// In ar, this message translates to:
  /// **'مدّخر {amount}'**
  String goalsSavedTotal(String amount);

  /// No description provided for @goalsDebtNew.
  ///
  /// In ar, this message translates to:
  /// **'دين جديد'**
  String get goalsDebtNew;

  /// No description provided for @goalsDebtEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الدين'**
  String get goalsDebtEdit;

  /// No description provided for @goalsFieldDirection.
  ///
  /// In ar, this message translates to:
  /// **'الاتجاه'**
  String get goalsFieldDirection;

  /// Debt direction: money I owe someone
  ///
  /// In ar, this message translates to:
  /// **'عليّ'**
  String get goalsIOwe;

  /// Debt direction: money someone owes me
  ///
  /// In ar, this message translates to:
  /// **'لي'**
  String get goalsOwedToMe;

  /// No description provided for @goalsDebtIOweSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'دين عليّ'**
  String get goalsDebtIOweSubtitle;

  /// No description provided for @goalsDebtOwedSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'دين لي عنده'**
  String get goalsDebtOwedSubtitle;

  /// No description provided for @goalsFieldPerson.
  ///
  /// In ar, this message translates to:
  /// **'الشخص'**
  String get goalsFieldPerson;

  /// No description provided for @goalsFieldPersonHint.
  ///
  /// In ar, this message translates to:
  /// **'اسم الشخص أو الجهة'**
  String get goalsFieldPersonHint;

  /// No description provided for @goalsFieldDueDate.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الاستحقاق'**
  String get goalsFieldDueDate;

  /// No description provided for @goalsIOweTo.
  ///
  /// In ar, this message translates to:
  /// **'أنا مدين لـ{person}'**
  String goalsIOweTo(String person);

  /// No description provided for @goalsOwedBy.
  ///
  /// In ar, this message translates to:
  /// **'{person} مدين لي'**
  String goalsOwedBy(String person);

  /// No description provided for @goalsRemainingOf.
  ///
  /// In ar, this message translates to:
  /// **'يتبقّى {remaining} من {total}'**
  String goalsRemainingOf(String remaining, String total);

  /// No description provided for @goalsSettle.
  ///
  /// In ar, this message translates to:
  /// **'تسوية'**
  String get goalsSettle;

  /// No description provided for @goalsReopen.
  ///
  /// In ar, this message translates to:
  /// **'إعادة فتح'**
  String get goalsReopen;

  /// No description provided for @goalsSettled.
  ///
  /// In ar, this message translates to:
  /// **'مُسوّى'**
  String get goalsSettled;

  /// No description provided for @goalsSettledOn.
  ///
  /// In ar, this message translates to:
  /// **'سُوّي في {date}'**
  String goalsSettledOn(String date);

  /// No description provided for @goalsSettledWrittenOff.
  ///
  /// In ar, this message translates to:
  /// **'سُوّي في {date}، وسُومح بـ{amount}'**
  String goalsSettledWrittenOff(String date, String amount);

  /// No description provided for @goalsNoDueDate.
  ///
  /// In ar, this message translates to:
  /// **'بلا موعد'**
  String get goalsNoDueDate;

  /// No description provided for @goalsRecordPayment.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل دفعة'**
  String get goalsRecordPayment;

  /// No description provided for @goalsPayTo.
  ///
  /// In ar, this message translates to:
  /// **'دفعة إلى {person}'**
  String goalsPayTo(String person);

  /// No description provided for @goalsReceiveFrom.
  ///
  /// In ar, this message translates to:
  /// **'دفعة من {person}'**
  String goalsReceiveFrom(String person);

  /// No description provided for @goalsDebtPaidOff.
  ///
  /// In ar, this message translates to:
  /// **'سُدّد الحساب مع {person} بالكامل'**
  String goalsDebtPaidOff(String person);

  /// No description provided for @goalsPaymentRecorded.
  ///
  /// In ar, this message translates to:
  /// **'سُجّلت دفعة {amount}'**
  String goalsPaymentRecorded(String amount);

  /// No description provided for @goalsDebtSettled.
  ///
  /// In ar, this message translates to:
  /// **'سُوّي الدين مع {person}'**
  String goalsDebtSettled(String person);

  /// No description provided for @goalsDebtReopened.
  ///
  /// In ar, this message translates to:
  /// **'أُعيد فتح الدين'**
  String get goalsDebtReopened;

  /// No description provided for @goalsPayments.
  ///
  /// In ar, this message translates to:
  /// **'الدفعات'**
  String get goalsPayments;

  /// No description provided for @goalsNoPayments.
  ///
  /// In ar, this message translates to:
  /// **'لا دفعات بعد'**
  String get goalsNoPayments;

  /// No description provided for @goalsPaidSoFar.
  ///
  /// In ar, this message translates to:
  /// **'دُفع حتى الآن {amount}'**
  String goalsPaidSoFar(String amount);

  /// No description provided for @goalsPaysOff.
  ///
  /// In ar, this message translates to:
  /// **'هذه الدفعة تُنهي الدين'**
  String get goalsPaysOff;

  /// No description provided for @goalsRemainingAfter.
  ///
  /// In ar, this message translates to:
  /// **'يتبقّى بعدها {amount}'**
  String goalsRemainingAfter(String amount);

  /// No description provided for @goalsPaidOfTotal.
  ///
  /// In ar, this message translates to:
  /// **'{paid} من {total}'**
  String goalsPaidOfTotal(String paid, String total);

  /// No description provided for @goalsDebtsEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا ديون مسجّلة'**
  String get goalsDebtsEmptyTitle;

  /// No description provided for @goalsDebtsEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'سجّل ما عليك وما لك عند الآخرين، مع مواعيد السداد والدفعات الجزئية.'**
  String get goalsDebtsEmptyBody;

  /// No description provided for @goalsNoOpenDebts.
  ///
  /// In ar, this message translates to:
  /// **'لا ديون مفتوحة هنا'**
  String get goalsNoOpenDebts;

  /// No description provided for @goalsSettledDebts.
  ///
  /// In ar, this message translates to:
  /// **'ديون مُسوّاة'**
  String get goalsSettledDebts;

  /// No description provided for @goalsDebtsHint.
  ///
  /// In ar, this message translates to:
  /// **'اسحب الدين لتسويته فورًا، ويمكنك التراجع.'**
  String get goalsDebtsHint;

  /// No description provided for @goalsDebtsCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا ديون مفتوحة} =1{دين مفتوح واحد} =2{دينان مفتوحان} few{{n} ديون مفتوحة} many{{n} دينًا مفتوحًا} other{{n} دين مفتوح}}'**
  String goalsDebtsCount(int count, String n);

  /// No description provided for @goalsNetEven.
  ///
  /// In ar, this message translates to:
  /// **'الكفّتان متعادلتان'**
  String get goalsNetEven;

  /// No description provided for @goalsNetOwedToMe.
  ///
  /// In ar, this message translates to:
  /// **'الصافي لك: {amount}'**
  String goalsNetOwedToMe(String amount);

  /// No description provided for @goalsNetIOwe.
  ///
  /// In ar, this message translates to:
  /// **'الصافي عليك: {amount}'**
  String goalsNetIOwe(String amount);

  /// No description provided for @goalsOverdueCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{متأخر واحد} =2{متأخران} few{{n} متأخرة} many{{n} متأخرًا} other{{n} متأخر}}'**
  String goalsOverdueCount(int count, String n);

  /// No description provided for @goalsObligationNew.
  ///
  /// In ar, this message translates to:
  /// **'التزام جديد'**
  String get goalsObligationNew;

  /// No description provided for @goalsObligationNewSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'إيجار، قسط، اشتراك، مصروف… أي دفعة تتكرر'**
  String get goalsObligationNewSubtitle;

  /// No description provided for @goalsObligationEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الالتزام'**
  String get goalsObligationEdit;

  /// No description provided for @goalsFieldObligationName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get goalsFieldObligationName;

  /// No description provided for @goalsFieldObligationNameHint.
  ///
  /// In ar, this message translates to:
  /// **'مثلًا: الإيجار'**
  String get goalsFieldObligationNameHint;

  /// No description provided for @goalsFieldFrequency.
  ///
  /// In ar, this message translates to:
  /// **'يتكرر'**
  String get goalsFieldFrequency;

  /// No description provided for @goalsWeekly.
  ///
  /// In ar, this message translates to:
  /// **'أسبوعيًا'**
  String get goalsWeekly;

  /// No description provided for @goalsMonthly.
  ///
  /// In ar, this message translates to:
  /// **'شهريًا'**
  String get goalsMonthly;

  /// No description provided for @goalsYearly.
  ///
  /// In ar, this message translates to:
  /// **'سنويًا'**
  String get goalsYearly;

  /// No description provided for @goalsFieldInterval.
  ///
  /// In ar, this message translates to:
  /// **'كل كم فترة'**
  String get goalsFieldInterval;

  /// No description provided for @goalsFieldIntervalHint.
  ///
  /// In ar, this message translates to:
  /// **'واحد: كل فترة، اثنان: كل فترتين…'**
  String get goalsFieldIntervalHint;

  /// No description provided for @goalsFieldNextDue.
  ///
  /// In ar, this message translates to:
  /// **'الاستحقاق القادم'**
  String get goalsFieldNextDue;

  /// No description provided for @goalsFieldPayFromWallet.
  ///
  /// In ar, this message translates to:
  /// **'يُدفع من محفظة'**
  String get goalsFieldPayFromWallet;

  /// No description provided for @goalsFieldBudgetItem.
  ///
  /// In ar, this message translates to:
  /// **'بند الميزانية'**
  String get goalsFieldBudgetItem;

  /// No description provided for @goalsNoBudgetItem.
  ///
  /// In ar, this message translates to:
  /// **'بلا بند'**
  String get goalsNoBudgetItem;

  /// No description provided for @goalsFieldPaidOn.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الدفع'**
  String get goalsFieldPaidOn;

  /// No description provided for @goalsMarkPaid.
  ///
  /// In ar, this message translates to:
  /// **'دُفع'**
  String get goalsMarkPaid;

  /// No description provided for @goalsMarkPaidFor.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل دفع {name}'**
  String goalsMarkPaidFor(String name);

  /// No description provided for @goalsPayOther.
  ///
  /// In ar, this message translates to:
  /// **'دفع بمبلغ آخر'**
  String get goalsPayOther;

  /// No description provided for @goalsPayOtherShort.
  ///
  /// In ar, this message translates to:
  /// **'مبلغ آخر'**
  String get goalsPayOtherShort;

  /// No description provided for @goalsPayObligation.
  ///
  /// In ar, this message translates to:
  /// **'دفع {name}'**
  String goalsPayObligation(String name);

  /// No description provided for @goalsForDue.
  ///
  /// In ar, this message translates to:
  /// **'عن استحقاق {date}'**
  String goalsForDue(String date);

  /// No description provided for @goalsSkip.
  ///
  /// In ar, this message translates to:
  /// **'تخطّي'**
  String get goalsSkip;

  /// No description provided for @goalsSkippedEntry.
  ///
  /// In ar, this message translates to:
  /// **'تم التخطّي'**
  String get goalsSkippedEntry;

  /// No description provided for @goalsPause.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف مؤقت'**
  String get goalsPause;

  /// No description provided for @goalsResume.
  ///
  /// In ar, this message translates to:
  /// **'استئناف'**
  String get goalsResume;

  /// No description provided for @goalsPaused.
  ///
  /// In ar, this message translates to:
  /// **'موقوف'**
  String get goalsPaused;

  /// No description provided for @goalsObligationPaid.
  ///
  /// In ar, this message translates to:
  /// **'سُجّل الدفع، والموعد القادم {date}'**
  String goalsObligationPaid(String date);

  /// No description provided for @goalsObligationSkipped.
  ///
  /// In ar, this message translates to:
  /// **'تم التخطّي، والموعد القادم {date}'**
  String goalsObligationSkipped(String date);

  /// No description provided for @goalsObligationPaused.
  ///
  /// In ar, this message translates to:
  /// **'أُوقف الالتزام مؤقتًا'**
  String get goalsObligationPaused;

  /// No description provided for @goalsObligationResumed.
  ///
  /// In ar, this message translates to:
  /// **'استُؤنف الالتزام'**
  String get goalsObligationResumed;

  /// No description provided for @goalsObligationsEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا التزامات دورية'**
  String get goalsObligationsEmptyTitle;

  /// No description provided for @goalsObligationsEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'أضف ما يتكرر – الإيجار، الأقساط، الاشتراكات – وستصلك تذكرة قبل موعده، ويسجّل «دُفع» المصروف وينقلك إلى الموعد التالي.'**
  String get goalsObligationsEmptyBody;

  /// No description provided for @goalsObligationsHint.
  ///
  /// In ar, this message translates to:
  /// **'اسحب الالتزام لتسجيل دفعه، ويمكنك التراجع.'**
  String get goalsObligationsHint;

  /// No description provided for @goalsMonthlyCommitments.
  ///
  /// In ar, this message translates to:
  /// **'الالتزامات شهريًا'**
  String get goalsMonthlyCommitments;

  /// No description provided for @goalsActiveCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا التزامات نشطة} =1{التزام نشط واحد} =2{التزامان نشطان} few{{n} التزامات نشطة} many{{n} التزامًا نشطًا} other{{n} التزام نشط}}'**
  String goalsActiveCount(int count, String n);

  /// No description provided for @goalsDueSoonCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{مستحق خلال أسبوع} =2{مستحقان خلال أسبوع} few{{n} مستحقة خلال أسبوع} many{{n} مستحقًا خلال أسبوع} other{{n} مستحق خلال أسبوع}}'**
  String goalsDueSoonCount(int count, String n);

  /// No description provided for @goalsSectionOverdue.
  ///
  /// In ar, this message translates to:
  /// **'متأخرة'**
  String get goalsSectionOverdue;

  /// No description provided for @goalsSectionThisWeek.
  ///
  /// In ar, this message translates to:
  /// **'خلال أسبوع'**
  String get goalsSectionThisWeek;

  /// No description provided for @goalsSectionLater.
  ///
  /// In ar, this message translates to:
  /// **'لاحقًا'**
  String get goalsSectionLater;

  /// No description provided for @goalsSectionPaused.
  ///
  /// In ar, this message translates to:
  /// **'موقوفة'**
  String get goalsSectionPaused;

  /// No description provided for @goalsNextDue.
  ///
  /// In ar, this message translates to:
  /// **'الاستحقاق القادم'**
  String get goalsNextDue;

  /// No description provided for @goalsComingUp.
  ///
  /// In ar, this message translates to:
  /// **'المواعيد التالية'**
  String get goalsComingUp;

  /// No description provided for @goalsNoHistory.
  ///
  /// In ar, this message translates to:
  /// **'لم يُسجّل دفع بعد'**
  String get goalsNoHistory;

  /// No description provided for @goalsPaidOnForDue.
  ///
  /// In ar, this message translates to:
  /// **'دُفع في {paid} عن {due}'**
  String goalsPaidOnForDue(String paid, String due);

  /// No description provided for @goalsPaidFrom.
  ///
  /// In ar, this message translates to:
  /// **'يُدفع من {wallet}'**
  String goalsPaidFrom(String wallet);

  /// No description provided for @goalsCountsToward.
  ///
  /// In ar, this message translates to:
  /// **'يُحسب على بند {item}'**
  String goalsCountsToward(String item);

  /// No description provided for @goalsNoWalletHint.
  ///
  /// In ar, this message translates to:
  /// **'بلا محفظة: «دُفع» يسجّل الدفعة دون حركة في المحافظ.'**
  String get goalsNoWalletHint;

  /// No description provided for @goalsRecordedInLedger.
  ///
  /// In ar, this message translates to:
  /// **'مسجّل في دفتر الحركات'**
  String get goalsRecordedInLedger;

  /// No description provided for @goalsPeriodsDue.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{فترة مستحقة} =2{فترتان مستحقتان} few{{n} فترات مستحقة} many{{n} فترةً مستحقة} other{{n} فترة مستحقة}}'**
  String goalsPeriodsDue(int count, String n);

  /// No description provided for @goalsNextDates.
  ///
  /// In ar, this message translates to:
  /// **'التالي: {dates}'**
  String goalsNextDates(String dates);

  /// No description provided for @goalsAboutPerMonth.
  ///
  /// In ar, this message translates to:
  /// **'قرابة {amount} شهريًا'**
  String goalsAboutPerMonth(String amount);

  /// No description provided for @goalsNothingDue.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{لا شيء مستحق غدًا} =2{لا شيء مستحق خلال يومين} few{لا شيء مستحق خلال {n} أيام} many{لا شيء مستحق خلال {n} يومًا} other{لا شيء مستحق خلال {n} يوم}}'**
  String goalsNothingDue(int count, String n);

  /// No description provided for @goalsMoreDues.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{وواحد آخر} =2{واثنان آخران} few{و{n} أخرى} many{و{n} أخرى} other{و{n} أخرى}}'**
  String goalsMoreDues(int count, String n);

  /// No description provided for @goalsRemindersTitle.
  ///
  /// In ar, this message translates to:
  /// **'تذكير المستحقات'**
  String get goalsRemindersTitle;

  /// No description provided for @goalsRemindersSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'للديون والالتزامات الدورية'**
  String get goalsRemindersSubtitle;

  /// No description provided for @goalsRemindersEnabled.
  ///
  /// In ar, this message translates to:
  /// **'التذكيرات'**
  String get goalsRemindersEnabled;

  /// No description provided for @goalsRemindersEnabledHint.
  ///
  /// In ar, this message translates to:
  /// **'تنبيه هادئ قبل الموعد وفي يومه'**
  String get goalsRemindersEnabledHint;

  /// No description provided for @goalsRemindersLead.
  ///
  /// In ar, this message translates to:
  /// **'تذكير مبكر'**
  String get goalsRemindersLead;

  /// No description provided for @goalsRemindersLeadNone.
  ///
  /// In ar, this message translates to:
  /// **'بلا تذكير مبكر'**
  String get goalsRemindersLeadNone;

  /// No description provided for @goalsRemindersLeadDays.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{قبل يوم} =2{قبل يومين} few{قبل {n} أيام} many{قبل {n} يومًا} other{قبل {n} يوم}}'**
  String goalsRemindersLeadDays(int count, String n);

  /// No description provided for @goalsRemindersOnDueDay.
  ///
  /// In ar, this message translates to:
  /// **'وفي يوم الاستحقاق أيضًا'**
  String get goalsRemindersOnDueDay;

  /// No description provided for @goalsRemindersTime.
  ///
  /// In ar, this message translates to:
  /// **'الوقت'**
  String get goalsRemindersTime;

  /// Notification channel group (system settings)
  ///
  /// In ar, this message translates to:
  /// **'المال'**
  String get goalsNotifyGroup;

  /// Notification channel name (system settings)
  ///
  /// In ar, this message translates to:
  /// **'مواعيد الاستحقاق'**
  String get goalsNotifyChannel;

  /// No description provided for @goalsNotifyChannelDescription.
  ///
  /// In ar, this message translates to:
  /// **'تذكير بالديون والالتزامات الدورية قبل موعدها'**
  String get goalsNotifyChannelDescription;

  /// No description provided for @goalsNotifyObligationTitle.
  ///
  /// In ar, this message translates to:
  /// **'استحقاق {name}'**
  String goalsNotifyObligationTitle(String name);

  /// No description provided for @goalsNotifyObligationBody.
  ///
  /// In ar, this message translates to:
  /// **'{when} – المبلغ {amount}'**
  String goalsNotifyObligationBody(String when, String amount);

  /// No description provided for @goalsNotifyDebtIOweTitle.
  ///
  /// In ar, this message translates to:
  /// **'سداد لـ{person}'**
  String goalsNotifyDebtIOweTitle(String person);

  /// No description provided for @goalsNotifyDebtIOweBody.
  ///
  /// In ar, this message translates to:
  /// **'{when} – يُستحق عليك {amount}'**
  String goalsNotifyDebtIOweBody(String when, String amount);

  /// No description provided for @goalsNotifyDebtOwedTitle.
  ///
  /// In ar, this message translates to:
  /// **'دين على {person}'**
  String goalsNotifyDebtOwedTitle(String person);

  /// No description provided for @goalsNotifyDebtOwedBody.
  ///
  /// In ar, this message translates to:
  /// **'{when} – يُستحق لك {amount}'**
  String goalsNotifyDebtOwedBody(String when, String amount);

  /// Debt editor: the wallet the lent / borrowed money went through
  ///
  /// In ar, this message translates to:
  /// **'عبر محفظة'**
  String get goalsFieldDebtWallet;

  /// Debt editor preview (owed to me, with a wallet)
  ///
  /// In ar, this message translates to:
  /// **'خرج المبلغ من {wallet}، فينقص رصيدها {amount}'**
  String goalsDebtLentFrom(String wallet, String amount);

  /// Debt editor preview (I owe, with a wallet)
  ///
  /// In ar, this message translates to:
  /// **'دخل المبلغ إلى {wallet}، فيزيد رصيدها {amount}'**
  String goalsDebtBorrowedInto(String wallet, String amount);

  /// Debt editor preview without a wallet
  ///
  /// In ar, this message translates to:
  /// **'بلا محفظة: تبقى أرصدة المحافظ كما هي.'**
  String get goalsDebtNoWalletHint;

  /// Money page: title of the net worth card (wallets + jars + owed to you − you owe, in the base currency)
  ///
  /// In ar, this message translates to:
  /// **'صافي ثروتك'**
  String get moneyHubNetWorthTitle;

  /// Money page: the base currency the net worth is shown in
  ///
  /// In ar, this message translates to:
  /// **'بعملة {code}'**
  String moneyHubNetWorthIn(String code);

  /// Money page: net worth card on a fresh install
  ///
  /// In ar, this message translates to:
  /// **'أضف محفظتك الأولى ليظهر هنا صافي ثروتك بعملتك الأساسية.'**
  String get moneyHubNetWorthEmpty;

  /// Money page: part of the net worth – the wallets' balances
  ///
  /// In ar, this message translates to:
  /// **'المحافظ'**
  String get moneyHubPartWallets;

  /// Money page: part of the net worth – money in savings jars
  ///
  /// In ar, this message translates to:
  /// **'الحصّالات'**
  String get moneyHubPartJars;

  /// Money page: part of the net worth – open debts owed to the user
  ///
  /// In ar, this message translates to:
  /// **'لك عند الناس'**
  String get moneyHubPartOwedToMe;

  /// Money page: part of the net worth – open debts the user owes (subtracted)
  ///
  /// In ar, this message translates to:
  /// **'عليك'**
  String get moneyHubPartIOwe;

  /// Money page: screen-reader summary of the net worth card
  ///
  /// In ar, this message translates to:
  /// **'صافي ثروتك {total}: المحافظ {wallets}، الحصّالات {jars}، لك {owed}، عليك {owe}'**
  String moneyHubNetWorthSemantics(
    String total,
    String wallets,
    String jars,
    String owed,
    String owe,
  );

  /// Money page: button on the net worth card opening currencies and rates
  ///
  /// In ar, this message translates to:
  /// **'العملات'**
  String get moneyHubRatesAction;

  /// Money page: title of the quick add row (expense, income, transfer)
  ///
  /// In ar, this message translates to:
  /// **'سجّل حركة'**
  String get moneyHubQuickTitle;

  /// Money page: screen-reader label of the quick expense button
  ///
  /// In ar, this message translates to:
  /// **'سجّل مصروفًا'**
  String get moneyHubAddExpenseHint;

  /// Money page: screen-reader label of the quick income button
  ///
  /// In ar, this message translates to:
  /// **'سجّل دخلًا'**
  String get moneyHubAddIncomeHint;

  /// Money page: screen-reader label of the quick transfer button
  ///
  /// In ar, this message translates to:
  /// **'حوّل بين محفظتين'**
  String get moneyHubAddTransferHint;

  /// Money page: section of the wallets summary
  ///
  /// In ar, this message translates to:
  /// **'محافظك'**
  String get moneyHubWalletsTitle;

  /// Money page: section action opening the ledger
  ///
  /// In ar, this message translates to:
  /// **'الدفتر'**
  String get moneyHubLedgerAction;

  /// Money page: section of the budget status (plan vs spent, warnings)
  ///
  /// In ar, this message translates to:
  /// **'خطة هذا الشهر'**
  String get moneyHubPlanTitle;

  /// Money page: section action opening the budget
  ///
  /// In ar, this message translates to:
  /// **'الميزانية'**
  String get moneyHubBudgetAction;

  /// Money page: section of upcoming dues (bills, debts) and savings jars
  ///
  /// In ar, this message translates to:
  /// **'المستحقات والادّخار'**
  String get moneyHubDuesTitle;

  /// Money page: section action opening savings, debts and bills
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get moneyHubGoalsAction;

  /// Money page: section of links to the money screens
  ///
  /// In ar, this message translates to:
  /// **'أدوات المال'**
  String get moneyHubToolsTitle;

  /// Money tool: the ledger (wallets, balances, recent entries)
  ///
  /// In ar, this message translates to:
  /// **'الدفتر'**
  String get moneyHubToolLedger;

  /// Money tool hint (screen readers)
  ///
  /// In ar, this message translates to:
  /// **'المحافظ وأرصدتها وآخر الحركات'**
  String get moneyHubToolLedgerHint;

  /// Money tool: every transaction
  ///
  /// In ar, this message translates to:
  /// **'الحركات'**
  String get moneyHubToolTransactions;

  /// Money tool hint (screen readers)
  ///
  /// In ar, this message translates to:
  /// **'كل الحركات مع البحث والتصفية'**
  String get moneyHubToolTransactionsHint;

  /// Money tool: the nested budget
  ///
  /// In ar, this message translates to:
  /// **'الميزانية'**
  String get moneyHubToolBudget;

  /// Money tool hint (screen readers)
  ///
  /// In ar, this message translates to:
  /// **'الخطة المتداخلة والإنفاق مقابلها'**
  String get moneyHubToolBudgetHint;

  /// Money tool: savings jars
  ///
  /// In ar, this message translates to:
  /// **'الحصّالات'**
  String get moneyHubToolJars;

  /// Money tool hint (screen readers)
  ///
  /// In ar, this message translates to:
  /// **'الأهداف والمواعيد والإيداعات'**
  String get moneyHubToolJarsHint;

  /// Money tool: debts (I owe / owed to me)
  ///
  /// In ar, this message translates to:
  /// **'الديون'**
  String get moneyHubToolDebts;

  /// Money tool hint (screen readers)
  ///
  /// In ar, this message translates to:
  /// **'ما عليك وما لك، ومواعيد السداد'**
  String get moneyHubToolDebtsHint;

  /// Money tool: recurring obligations
  ///
  /// In ar, this message translates to:
  /// **'الالتزامات'**
  String get moneyHubToolBills;

  /// Money tool hint (screen readers)
  ///
  /// In ar, this message translates to:
  /// **'الالتزامات المتكررة؛ «دُفع» ينقل الموعد التالي'**
  String get moneyHubToolBillsHint;

  /// Wallet moon sheet: button opening the wallet's screen
  ///
  /// In ar, this message translates to:
  /// **'افتح المحفظة'**
  String get moneyHubMoonOpenWallet;

  /// Settings: section of the money preferences
  ///
  /// In ar, this message translates to:
  /// **'المال'**
  String get moneyHubSettingsSection;

  /// Settings: subtitle of the money section
  ///
  /// In ar, this message translates to:
  /// **'العملات وأسابيع الشهر وبداية الأسبوع وتذكير المستحقات'**
  String get moneyHubSettingsSectionHint;

  /// Settings › Money: entry opening the currencies and manual exchange rates
  ///
  /// In ar, this message translates to:
  /// **'العملة الأساسية والأسعار'**
  String get moneyHubSettingsCurrencies;

  /// Settings › Money: how many currencies are set up
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{عملة واحدة} =2{عملتان} few{{n} عملات} many{{n} عملة} other{{n} عملة}}'**
  String moneyHubSettingsCurrencyCount(int count, String n);

  /// Settings › Money: weeks per month (weekly ↔ monthly budget conversion)
  ///
  /// In ar, this message translates to:
  /// **'أسابيع الشهر'**
  String get moneyHubSettingsWeeks;

  /// Settings › Money: the weeks-per-month value
  ///
  /// In ar, this message translates to:
  /// **'{weeks} · للتحويل بين الأسبوعي والشهري'**
  String moneyHubSettingsWeeksSummary(String weeks);

  /// Settings › Money: first day of the week in weekly budgets and reports
  ///
  /// In ar, this message translates to:
  /// **'بداية الأسبوع'**
  String get moneyHubSettingsWeekStart;

  /// Settings › Money: hint under the week start choice
  ///
  /// In ar, this message translates to:
  /// **'للبنود الأسبوعية في الميزانية وتقارير الأسبوع في الدفتر'**
  String get moneyHubSettingsWeekStartHint;

  /// Week start choice
  ///
  /// In ar, this message translates to:
  /// **'السبت'**
  String get moneyHubWeekSaturday;

  /// Week start choice
  ///
  /// In ar, this message translates to:
  /// **'الأحد'**
  String get moneyHubWeekSunday;

  /// Week start choice
  ///
  /// In ar, this message translates to:
  /// **'الإثنين'**
  String get moneyHubWeekMonday;

  /// Settings › Money: entry opening the debt and bill due reminder options
  ///
  /// In ar, this message translates to:
  /// **'تذكير المستحقات'**
  String get moneyHubSettingsReminders;

  /// Settings › Money: due reminders switched off
  ///
  /// In ar, this message translates to:
  /// **'متوقف'**
  String get moneyHubSettingsRemindersOff;

  /// Settings › Money: reminders only on the due day
  ///
  /// In ar, this message translates to:
  /// **'في يوم الاستحقاق'**
  String get moneyHubSettingsRemindersOnDay;

  /// Settings › Money: an early reminder and one on the due day
  ///
  /// In ar, this message translates to:
  /// **'{lead} وفي يومه'**
  String moneyHubSettingsRemindersBoth(String lead);

  /// Settings › Money: when the due reminders arrive
  ///
  /// In ar, this message translates to:
  /// **'{when} · الساعة {time}'**
  String moneyHubSettingsRemindersAt(String when, String time);

  /// Work planet screen title
  ///
  /// In ar, this message translates to:
  /// **'العمل'**
  String get workTitle;

  /// Section: kanban boards
  ///
  /// In ar, this message translates to:
  /// **'اللوحات'**
  String get workBoards;

  /// Section / screen: projects
  ///
  /// In ar, this message translates to:
  /// **'المشاريع'**
  String get workProjects;

  /// Link to the projects screen
  ///
  /// In ar, this message translates to:
  /// **'كل المشاريع'**
  String get workAllProjects;

  /// Compact card link: open the Work screen
  ///
  /// In ar, this message translates to:
  /// **'فتح العمل'**
  String get workOpenAll;

  /// List separator (Arabic comma: a middle dot reads as the digit zero ٠)
  ///
  /// In ar, this message translates to:
  /// **'، '**
  String get workSep;

  /// Sheet button: save
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get workSave;

  /// Sheet button: create
  ///
  /// In ar, this message translates to:
  /// **'إضافة'**
  String get workCreate;

  /// Day chip / due badge: today
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get workToday;

  /// Day chip / due badge: tomorrow
  ///
  /// In ar, this message translates to:
  /// **'غدًا'**
  String get workTomorrow;

  /// Day chip: open a date picker
  ///
  /// In ar, this message translates to:
  /// **'تاريخ آخر…'**
  String get workPickDate;

  /// Day chip: no date
  ///
  /// In ar, this message translates to:
  /// **'بلا موعد'**
  String get workNoDate;

  /// Button: clear a field
  ///
  /// In ar, this message translates to:
  /// **'مسح'**
  String get workClear;

  /// Button / sheet title: new board
  ///
  /// In ar, this message translates to:
  /// **'لوحة جديدة'**
  String get workNewBoard;

  /// Sheet title / menu: edit a board
  ///
  /// In ar, this message translates to:
  /// **'تعديل اللوحة'**
  String get workEditBoard;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'اسم اللوحة'**
  String get workBoardName;

  /// Field hint (generic example)
  ///
  /// In ar, this message translates to:
  /// **'مثلًا: المتجر الإلكتروني'**
  String get workBoardNameHint;

  /// Field label: what the board is for
  ///
  /// In ar, this message translates to:
  /// **'البلد أو النشاط'**
  String get workBoardCountry;

  /// Field hint
  ///
  /// In ar, this message translates to:
  /// **'اختر بلدًا أو اكتب وصفًا قصيرًا'**
  String get workBoardCountryHint;

  /// Field label: board colour
  ///
  /// In ar, this message translates to:
  /// **'اللون'**
  String get workBoardColor;

  /// App bar button: board menu
  ///
  /// In ar, this message translates to:
  /// **'خيارات اللوحة'**
  String get workBoardOptions;

  /// Menu: archive a board
  ///
  /// In ar, this message translates to:
  /// **'أرشفة'**
  String get workArchive;

  /// Menu: unarchive a board
  ///
  /// In ar, this message translates to:
  /// **'إعادة من الأرشيف'**
  String get workUnarchive;

  /// Section title
  ///
  /// In ar, this message translates to:
  /// **'اللوحات المؤرشفة'**
  String get workArchivedSection;

  /// Undo toast
  ///
  /// In ar, this message translates to:
  /// **'أُرشفت اللوحة'**
  String get workBoardArchived;

  /// Undo toast
  ///
  /// In ar, this message translates to:
  /// **'عادت اللوحة من الأرشيف'**
  String get workBoardRestored;

  /// Undo toast
  ///
  /// In ar, this message translates to:
  /// **'حُذفت اللوحة وبطاقاتها'**
  String get workBoardDeleted;

  /// Empty state title
  ///
  /// In ar, this message translates to:
  /// **'ابدأ لوحتك الأولى'**
  String get workBoardsEmptyTitle;

  /// Empty state body (generic examples)
  ///
  /// In ar, this message translates to:
  /// **'لوحة لكل بلد أو نشاط — مثلًا «المتجر الإلكتروني» أو «فريق التوصيل» — بأعمدة: المطلوب، قيد التنفيذ، تمّ.'**
  String get workBoardsEmptyBody;

  /// Board screen: deleted board
  ///
  /// In ar, this message translates to:
  /// **'لم تعد هذه اللوحة موجودة'**
  String get workBoardMissing;

  /// Board tile: open cards
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا بطاقات مفتوحة} =1{بطاقة مفتوحة} =2{بطاقتان مفتوحتان} few{{count} بطاقات مفتوحة} many{{count} بطاقة مفتوحة} other{{count} بطاقة مفتوحة}}'**
  String workOpenCount(int count);

  /// Board tile: done cards
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا منجز} =1{واحدة منجزة} =2{اثنتان منجزتان} few{{count} منجزة} many{{count} منجزة} other{{count} منجزة}}'**
  String workDoneCount(int count);

  /// Board tile / today card: cards due today
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{واحدة مستحقة اليوم} =2{اثنتان مستحقتان اليوم} few{{count} مستحقة اليوم} many{{count} مستحقة اليوم} other{{count} مستحقة اليوم}}'**
  String workDueTodayCount(int count);

  /// Board tile / today card: overdue cards
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{واحدة متأخرة} =2{اثنتان متأخرتان} few{{count} متأخرة} many{{count} متأخرة} other{{count} متأخرة}}'**
  String workOverdueCount(int count);

  /// Column / board: number of cards
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا بطاقات} =1{بطاقة واحدة} =2{بطاقتان} few{{count} بطاقات} many{{count} بطاقة} other{{count} بطاقة}}'**
  String workCardsCount(int count);

  /// Collapsed archived section
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{لوحة مؤرشفة} =2{لوحتان مؤرشفتان} few{{count} لوحات مؤرشفة} many{{count} لوحة مؤرشفة} other{{count} لوحة مؤرشفة}}'**
  String workArchivedCount(int count);

  /// Default column: to do
  ///
  /// In ar, this message translates to:
  /// **'المطلوب'**
  String get workColTodo;

  /// Default column: in progress
  ///
  /// In ar, this message translates to:
  /// **'قيد التنفيذ'**
  String get workColDoing;

  /// Default column: done
  ///
  /// In ar, this message translates to:
  /// **'تمّ'**
  String get workColDone;

  /// Fallback name of an unnamed column
  ///
  /// In ar, this message translates to:
  /// **'عمود'**
  String get workColumnUntitled;

  /// Menu / sheet title
  ///
  /// In ar, this message translates to:
  /// **'تعديل الأعمدة'**
  String get workEditColumns;

  /// Sheet subtitle
  ///
  /// In ar, this message translates to:
  /// **'اسحب لإعادة الترتيب، واختر عمود الإنجاز'**
  String get workEditColumnsHint;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'إضافة عمود'**
  String get workAddColumn;

  /// Field label / hint
  ///
  /// In ar, this message translates to:
  /// **'اسم العمود'**
  String get workColumnName;

  /// Button: rename a column
  ///
  /// In ar, this message translates to:
  /// **'إعادة تسمية'**
  String get workRenameColumn;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'حذف العمود'**
  String get workDeleteColumn;

  /// Badge / toggle: the column whose cards count as done
  ///
  /// In ar, this message translates to:
  /// **'عمود الإنجاز'**
  String get workDoneColumn;

  /// Explanation of the done column
  ///
  /// In ar, this message translates to:
  /// **'البطاقات فيه تُعدّ منجزة وتُنعش كوكب العمل'**
  String get workDoneColumnHint;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'اجعله عمود الإنجاز'**
  String get workMakeDoneColumn;

  /// Error: cannot delete the last column
  ///
  /// In ar, this message translates to:
  /// **'تحتاج اللوحة عمودًا واحدًا على الأقل'**
  String get workNeedOneColumn;

  /// Undo toast
  ///
  /// In ar, this message translates to:
  /// **'حُذف العمود ونُقلت بطاقاته إلى «{column}»'**
  String workColumnDeleted(String column);

  /// Undo toast
  ///
  /// In ar, this message translates to:
  /// **'حُفظت الأعمدة'**
  String get workColumnsSaved;

  /// Empty column
  ///
  /// In ar, this message translates to:
  /// **'لا بطاقات هنا بعد'**
  String get workColumnEmpty;

  /// Drop target hint while dragging
  ///
  /// In ar, this message translates to:
  /// **'أفلِت البطاقة هنا'**
  String get workDropHere;

  /// Column footer / FAB
  ///
  /// In ar, this message translates to:
  /// **'إضافة بطاقة'**
  String get workAddCard;

  /// Sheet title
  ///
  /// In ar, this message translates to:
  /// **'بطاقة جديدة'**
  String get workNewCard;

  /// Sheet title
  ///
  /// In ar, this message translates to:
  /// **'تعديل البطاقة'**
  String get workEditCard;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'العنوان'**
  String get workCardTitle;

  /// Field hint
  ///
  /// In ar, this message translates to:
  /// **'ما المطلوب إنجازه؟'**
  String get workCardTitleHint;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات'**
  String get workCardNotes;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'المسؤول'**
  String get workCardAssignee;

  /// Field hint
  ///
  /// In ar, this message translates to:
  /// **'من سيتولّاها؟'**
  String get workCardAssigneeHint;

  /// Field label / menu
  ///
  /// In ar, this message translates to:
  /// **'موعد الاستحقاق'**
  String get workCardDue;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'العمود'**
  String get workCardColumn;

  /// Field label: prayer window placement
  ///
  /// In ar, this message translates to:
  /// **'وقت العمل عليها'**
  String get workCardWindow;

  /// Field hint
  ///
  /// In ar, this message translates to:
  /// **'تظهر في قائمة ذلك الوقت على الشاشة الرئيسية'**
  String get workCardWindowHint;

  /// Window chip: not placed in a window
  ///
  /// In ar, this message translates to:
  /// **'غير محدد'**
  String get workNotPlaced;

  /// Undo toast
  ///
  /// In ar, this message translates to:
  /// **'حُذفت البطاقة'**
  String get workCardDeleted;

  /// Undo toast
  ///
  /// In ar, this message translates to:
  /// **'نُسخت البطاقة'**
  String get workCardDuplicated;

  /// Undo toast
  ///
  /// In ar, this message translates to:
  /// **'نُقلت إلى «{column}»'**
  String workCardMovedTo(String column);

  /// Undo toast
  ///
  /// In ar, this message translates to:
  /// **'نُقلت إلى لوحة «{board}»'**
  String workCardMovedBoard(String board);

  /// Undo toast: card completed
  ///
  /// In ar, this message translates to:
  /// **'أُنجزت، بارك الله فيك'**
  String get workCardDoneToast;

  /// Undo toast
  ///
  /// In ar, this message translates to:
  /// **'أُعيدت إلى «{column}»'**
  String workCardReopened(String column);

  /// Undo toast
  ///
  /// In ar, this message translates to:
  /// **'حُفظت البطاقة'**
  String get workCardSaved;

  /// Menu / sheet title
  ///
  /// In ar, this message translates to:
  /// **'نقل إلى لوحة'**
  String get workMoveToBoard;

  /// Menu / sheet title
  ///
  /// In ar, this message translates to:
  /// **'نقل إلى عمود'**
  String get workMoveToColumn;

  /// Swipe / action: next column
  ///
  /// In ar, this message translates to:
  /// **'تقديم إلى «{column}»'**
  String workMoveForward(String column);

  /// Swipe / action: previous column
  ///
  /// In ar, this message translates to:
  /// **'إرجاع إلى «{column}»'**
  String workMoveBack(String column);

  /// Menu / sheet title
  ///
  /// In ar, this message translates to:
  /// **'ضعها في وقت صلاة'**
  String get workPlaceInWindow;

  /// Menu / chip
  ///
  /// In ar, this message translates to:
  /// **'أزلها من وقت الصلاة'**
  String get workRemoveFromWindow;

  /// Undo toast
  ///
  /// In ar, this message translates to:
  /// **'وُضعت في «{window}»'**
  String workPlacedToast(String window);

  /// Undo toast
  ///
  /// In ar, this message translates to:
  /// **'أُزيلت من وقت الصلاة'**
  String get workUnplacedToast;

  /// Undo toast
  ///
  /// In ar, this message translates to:
  /// **'حُدّد موعد الاستحقاق'**
  String get workDueSetToast;

  /// Screen reader label of a card
  ///
  /// In ar, this message translates to:
  /// **'{title}، في عمود {column}'**
  String workCardSemantics(String title, String column);

  /// Screen reader hint on a card
  ///
  /// In ar, this message translates to:
  /// **'اسحب نحو العمود التالي لتقديمها أو السابق لإرجاعها، واضغط مطوّلًا لسحبها أو لفتح الخيارات'**
  String get workSwipeHint;

  /// Filter chip
  ///
  /// In ar, this message translates to:
  /// **'بلا مسؤول'**
  String get workUnassigned;

  /// Card badge
  ///
  /// In ar, this message translates to:
  /// **'منجزة'**
  String get workDoneBadge;

  /// Due badge: overdue by N days
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{تأخّر يومًا} =2{تأخّر يومين} few{تأخّر {count} أيام} many{تأخّر {count} يومًا} other{تأخّر {count} يوم}}'**
  String workLateDays(int count);

  /// Card chip: placed in a window
  ///
  /// In ar, this message translates to:
  /// **'{window}'**
  String workInWindow(String window);

  /// Card chip: window on a given day
  ///
  /// In ar, this message translates to:
  /// **'{window}، {day}'**
  String workWindowOnDay(String window, String day);

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'تصفية'**
  String get workFilter;

  /// Filter chip
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get workFilterAll;

  /// Filter chip
  ///
  /// In ar, this message translates to:
  /// **'المتأخرة'**
  String get workFilterOverdue;

  /// Filter chip
  ///
  /// In ar, this message translates to:
  /// **'مستحقة اليوم'**
  String get workFilterToday;

  /// Filter chip
  ///
  /// In ar, this message translates to:
  /// **'هذا الأسبوع'**
  String get workFilterWeek;

  /// Filter chip
  ///
  /// In ar, this message translates to:
  /// **'بلا موعد'**
  String get workFilterNoDate;

  /// Filter group label
  ///
  /// In ar, this message translates to:
  /// **'المسؤول'**
  String get workFilterAssignee;

  /// Filter group label
  ///
  /// In ar, this message translates to:
  /// **'الموعد'**
  String get workFilterDue;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'إلغاء التصفية'**
  String get workFilterClear;

  /// Empty column while filtering
  ///
  /// In ar, this message translates to:
  /// **'لا بطاقات تطابق التصفية'**
  String get workFilterNoMatch;

  /// Top 3 card title
  ///
  /// In ar, this message translates to:
  /// **'أهم ثلاث اليوم'**
  String get workTop3Title;

  /// Top 3 card subtitle
  ///
  /// In ar, this message translates to:
  /// **'ثلاث أولويات تكفي ليوم مبارك'**
  String get workTop3Subtitle;

  /// Top 3 empty state
  ///
  /// In ar, this message translates to:
  /// **'اختر ما يستحق تركيزك اليوم — ثلاثة أشياء تكفي.'**
  String get workTop3Empty;

  /// Button: choose Top 3 items
  ///
  /// In ar, this message translates to:
  /// **'اختر'**
  String get workTop3Choose;

  /// Picker sheet title
  ///
  /// In ar, this message translates to:
  /// **'اختر أهم ثلاث'**
  String get workTop3ChooseTitle;

  /// Picker subtitle
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{اكتملت الثلاث} =1{بقي مكان واحد} =2{بقي مكانان} few{بقيت {count} أماكن} many{بقي {count} مكانًا} other{بقي {count} مكان}}'**
  String workTop3SlotsLeft(int count);

  /// Picker empty
  ///
  /// In ar, this message translates to:
  /// **'لا بطاقات أو مهام مفتوحة لتختار منها'**
  String get workTop3NoCandidates;

  /// Top 3 progress (numbers pre-formatted)
  ///
  /// In ar, this message translates to:
  /// **'{done} من {total}'**
  String workTop3Progress(String done, String total);

  /// Top 3 all done
  ///
  /// In ar, this message translates to:
  /// **'أنجزت أهم ثلاث اليوم — بارك الله في وقتك'**
  String get workTop3AllDone;

  /// Menu action
  ///
  /// In ar, this message translates to:
  /// **'أضف إلى أهم ثلاث'**
  String get workTop3Add;

  /// Menu action
  ///
  /// In ar, this message translates to:
  /// **'أزل من أهم ثلاث'**
  String get workTop3Remove;

  /// Undo toast
  ///
  /// In ar, this message translates to:
  /// **'أُضيفت إلى أهم ثلاث'**
  String get workTop3Added;

  /// Undo toast
  ///
  /// In ar, this message translates to:
  /// **'أُزيلت من أهم ثلاث'**
  String get workTop3Removed;

  /// Card sheet toggle
  ///
  /// In ar, this message translates to:
  /// **'من أهم ثلاث اليوم'**
  String get workTop3Toggle;

  /// Swap sheet title
  ///
  /// In ar, this message translates to:
  /// **'أهم ثلاث مكتملة'**
  String get workTop3FullTitle;

  /// Swap sheet subtitle
  ///
  /// In ar, this message translates to:
  /// **'اختر ما تستبدله بـ«{title}»'**
  String workTop3FullBody(String title);

  /// Undo toast
  ///
  /// In ar, this message translates to:
  /// **'استُبدلت في أهم ثلاث'**
  String get workTop3Swapped;

  /// Toggle hint when full
  ///
  /// In ar, this message translates to:
  /// **'أهم ثلاث مكتملة'**
  String get workTop3FullShort;

  /// Carry-over prompt title
  ///
  /// In ar, this message translates to:
  /// **'من تركيز الأمس'**
  String get workCarryTitle;

  /// Carry-over prompt body
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{بقي أمر واحد لم يكتمل. أتنقله إلى اليوم؟} =2{بقي أمران لم يكتملا. أتنقلهما إلى اليوم؟} few{بقيت {count} أمور لم تكتمل. أتنقلها إلى اليوم؟} many{بقي {count} أمرًا لم يكتمل. أتنقلها إلى اليوم؟} other{بقي {count} أمر لم يكتمل. أتنقلها إلى اليوم؟}}'**
  String workCarryBody(int count);

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'انقلها إلى اليوم'**
  String get workCarryOver;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'ابدأ من جديد'**
  String get workStartFresh;

  /// Undo toast
  ///
  /// In ar, this message translates to:
  /// **'انتقلت إلى تركيز اليوم'**
  String get workCarriedToast;

  /// Undo toast
  ///
  /// In ar, this message translates to:
  /// **'بداية جديدة لليوم'**
  String get workFreshToast;

  /// Focus item kind: a task
  ///
  /// In ar, this message translates to:
  /// **'مهمة'**
  String get workKindTask;

  /// Undo toast: item completed
  ///
  /// In ar, this message translates to:
  /// **'أُنجزت'**
  String get workItemDoneToast;

  /// Undo toast: item reopened
  ///
  /// In ar, this message translates to:
  /// **'أُعيد فتحها'**
  String get workItemReopenedToast;

  /// Compact card title
  ///
  /// In ar, this message translates to:
  /// **'العمل اليوم'**
  String get workTodayTitle;

  /// Compact card: nothing due
  ///
  /// In ar, this message translates to:
  /// **'لا شيء مستحق اليوم'**
  String get workTodayAllClear;

  /// Compact card: Top 3 label
  ///
  /// In ar, this message translates to:
  /// **'أهم ثلاث'**
  String get workTodayTop3;

  /// Compact card: Top 3 progress (numbers pre-formatted)
  ///
  /// In ar, this message translates to:
  /// **'أهم ثلاث: {done} من {total}'**
  String workTodayTop3Line(String done, String total);

  /// Button / sheet title
  ///
  /// In ar, this message translates to:
  /// **'مشروع جديد'**
  String get workNewProject;

  /// Sheet title / menu
  ///
  /// In ar, this message translates to:
  /// **'تعديل المشروع'**
  String get workEditProject;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'اسم المشروع'**
  String get workProjectName;

  /// Field hint (generic example)
  ///
  /// In ar, this message translates to:
  /// **'مثلًا: إطلاق منتج جديد'**
  String get workProjectNameHint;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'الوصف'**
  String get workProjectDescription;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'الموعد النهائي'**
  String get workProjectDeadline;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'الحالة'**
  String get workProjectStatus;

  /// Project status
  ///
  /// In ar, this message translates to:
  /// **'نشط'**
  String get workStatusActive;

  /// Project status
  ///
  /// In ar, this message translates to:
  /// **'متوقف مؤقتًا'**
  String get workStatusPaused;

  /// Project status
  ///
  /// In ar, this message translates to:
  /// **'مكتمل'**
  String get workStatusDone;

  /// Field label: planet the project feeds
  ///
  /// In ar, this message translates to:
  /// **'الكوكب'**
  String get workProjectPlanet;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'اللون'**
  String get workProjectColor;

  /// Section title
  ///
  /// In ar, this message translates to:
  /// **'قائمة الخطوات'**
  String get workChecklist;

  /// Inline add field hint
  ///
  /// In ar, this message translates to:
  /// **'أضف خطوة…'**
  String get workAddItemHint;

  /// Button semantics
  ///
  /// In ar, this message translates to:
  /// **'إضافة خطوة'**
  String get workAddItem;

  /// Sheet title
  ///
  /// In ar, this message translates to:
  /// **'تعديل الخطوة'**
  String get workEditItem;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'الخطوة'**
  String get workItemBody;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'موعد الخطوة'**
  String get workItemDue;

  /// Undo toast
  ///
  /// In ar, this message translates to:
  /// **'حُذفت الخطوة'**
  String get workItemDeleted;

  /// Empty checklist
  ///
  /// In ar, this message translates to:
  /// **'قسّم المشروع إلى خطوات صغيرة — تبدأ الرحلة بخطوة.'**
  String get workChecklistEmpty;

  /// Section title
  ///
  /// In ar, this message translates to:
  /// **'مهام المشروع'**
  String get workProjectTasks;

  /// Empty project tasks
  ///
  /// In ar, this message translates to:
  /// **'المهام التي تضعها للمشروع في أوقات الصلاة تظهر هنا'**
  String get workProjectTasksEmpty;

  /// Button / sheet title
  ///
  /// In ar, this message translates to:
  /// **'مهمة في وقت صلاة'**
  String get workAddProjectTask;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'المهمة'**
  String get workTaskTitle;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'الوقت'**
  String get workTaskWindow;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get workTaskDay;

  /// Undo toast
  ///
  /// In ar, this message translates to:
  /// **'حُذف المشروع'**
  String get workProjectDeleted;

  /// Undo toast
  ///
  /// In ar, this message translates to:
  /// **'نُسخ المشروع'**
  String get workProjectDuplicated;

  /// Celebration toast at 100 %
  ///
  /// In ar, this message translates to:
  /// **'اكتمل المشروع، ما شاء الله!'**
  String get workProjectComplete;

  /// Project screen: deleted
  ///
  /// In ar, this message translates to:
  /// **'لم يعد هذا المشروع موجودًا'**
  String get workProjectMissing;

  /// Empty state title
  ///
  /// In ar, this message translates to:
  /// **'لا مشاريع بعد'**
  String get workProjectsEmptyTitle;

  /// Empty state body (generic examples)
  ///
  /// In ar, this message translates to:
  /// **'مشروع بخطوات وموعد نهائي — مثلًا «إطلاق منتج جديد» أو «تجديد الموقع».'**
  String get workProjectsEmptyBody;

  /// Undo toast
  ///
  /// In ar, this message translates to:
  /// **'الحالة: {status}'**
  String workStatusChanged(String status);

  /// Menu / sheet title
  ///
  /// In ar, this message translates to:
  /// **'تغيير الحالة'**
  String get workSetStatus;

  /// Countdown: days left (e.g. ١٢ يومًا)
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{يوم واحد} =2{يومان} few{{count} أيام} many{{count} يومًا} other{{count} يوم}}'**
  String workDaysLeft(int count);

  /// Countdown caption under the number
  ///
  /// In ar, this message translates to:
  /// **'حتى الموعد النهائي'**
  String get workDaysLeftCaption;

  /// Countdown: due today
  ///
  /// In ar, this message translates to:
  /// **'الموعد النهائي اليوم'**
  String get workDueTodayCaption;

  /// Countdown: due tomorrow
  ///
  /// In ar, this message translates to:
  /// **'الموعد النهائي غدًا'**
  String get workDueTomorrowCaption;

  /// Countdown: overdue
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{فات الموعد بيوم} =2{فات الموعد بيومين} few{فات الموعد بـ{count} أيام} many{فات الموعد بـ{count} يومًا} other{فات الموعد بـ{count} يوم}}'**
  String workOverdueDays(int count);

  /// Project without deadline
  ///
  /// In ar, this message translates to:
  /// **'بلا موعد نهائي'**
  String get workNoDeadline;

  /// Deadline date line
  ///
  /// In ar, this message translates to:
  /// **'الموعد: {date}'**
  String workDeadlineOn(String date);

  /// Checklist progress (numbers pre-formatted)
  ///
  /// In ar, this message translates to:
  /// **'{done} من {total} خطوات'**
  String workItemsProgress(String done, String total);

  /// Country name (JO)
  ///
  /// In ar, this message translates to:
  /// **'الأردن'**
  String get workCountryJO;

  /// Country name (SA)
  ///
  /// In ar, this message translates to:
  /// **'السعودية'**
  String get workCountrySA;

  /// Country name (AE)
  ///
  /// In ar, this message translates to:
  /// **'الإمارات'**
  String get workCountryAE;

  /// Country name (KW)
  ///
  /// In ar, this message translates to:
  /// **'الكويت'**
  String get workCountryKW;

  /// Country name (QA)
  ///
  /// In ar, this message translates to:
  /// **'قطر'**
  String get workCountryQA;

  /// Country name (BH)
  ///
  /// In ar, this message translates to:
  /// **'البحرين'**
  String get workCountryBH;

  /// Country name (OM)
  ///
  /// In ar, this message translates to:
  /// **'عُمان'**
  String get workCountryOM;

  /// Country name (IQ)
  ///
  /// In ar, this message translates to:
  /// **'العراق'**
  String get workCountryIQ;

  /// Country name (SY)
  ///
  /// In ar, this message translates to:
  /// **'سوريا'**
  String get workCountrySY;

  /// Country name (LB)
  ///
  /// In ar, this message translates to:
  /// **'لبنان'**
  String get workCountryLB;

  /// Country name (PS)
  ///
  /// In ar, this message translates to:
  /// **'فلسطين'**
  String get workCountryPS;

  /// Country name (EG)
  ///
  /// In ar, this message translates to:
  /// **'مصر'**
  String get workCountryEG;

  /// Country name (LY)
  ///
  /// In ar, this message translates to:
  /// **'ليبيا'**
  String get workCountryLY;

  /// Country name (TN)
  ///
  /// In ar, this message translates to:
  /// **'تونس'**
  String get workCountryTN;

  /// Country name (DZ)
  ///
  /// In ar, this message translates to:
  /// **'الجزائر'**
  String get workCountryDZ;

  /// Country name (MA)
  ///
  /// In ar, this message translates to:
  /// **'المغرب'**
  String get workCountryMA;

  /// Country name (SD)
  ///
  /// In ar, this message translates to:
  /// **'السودان'**
  String get workCountrySD;

  /// Country name (YE)
  ///
  /// In ar, this message translates to:
  /// **'اليمن'**
  String get workCountryYE;

  /// Country name (TR)
  ///
  /// In ar, this message translates to:
  /// **'تركيا'**
  String get workCountryTR;

  /// Title of the Family screen (people and contact rhythm)
  ///
  /// In ar, this message translates to:
  /// **'العائلة والأحبّة'**
  String get familyTitle;

  /// Title of the compact card on the Family planet
  ///
  /// In ar, this message translates to:
  /// **'صلة اليوم'**
  String get familyTodayTitle;

  /// No description provided for @familyOpenAll.
  ///
  /// In ar, this message translates to:
  /// **'عرض الكل'**
  String get familyOpenAll;

  /// No description provided for @familyAddPerson.
  ///
  /// In ar, this message translates to:
  /// **'إضافة شخص'**
  String get familyAddPerson;

  /// No description provided for @familyEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'دائرتك القريبة تبدأ هنا'**
  String get familyEmptyTitle;

  /// No description provided for @familyEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'أضف من تحبّ أن تبقى على صلة به، واختر كل كم يومًا تتواصل — مثلًا: «أمي، كل يومين».'**
  String get familyEmptyBody;

  /// No description provided for @familySortUrgency.
  ///
  /// In ar, this message translates to:
  /// **'حسب الأولوية'**
  String get familySortUrgency;

  /// No description provided for @familySortManual.
  ///
  /// In ar, this message translates to:
  /// **'ترتيبي الخاص'**
  String get familySortManual;

  /// No description provided for @familySortLabel.
  ///
  /// In ar, this message translates to:
  /// **'طريقة الترتيب'**
  String get familySortLabel;

  /// No description provided for @familyRemindersTitle.
  ///
  /// In ar, this message translates to:
  /// **'تذكيرات الصلة'**
  String get familyRemindersTitle;

  /// No description provided for @familyGroupOverdue.
  ///
  /// In ar, this message translates to:
  /// **'فات موعدهم'**
  String get familyGroupOverdue;

  /// No description provided for @familyGroupDueToday.
  ///
  /// In ar, this message translates to:
  /// **'موعدهم اليوم'**
  String get familyGroupDueToday;

  /// No description provided for @familyGroupThisWeek.
  ///
  /// In ar, this message translates to:
  /// **'خلال هذا الأسبوع'**
  String get familyGroupThisWeek;

  /// No description provided for @familyGroupInTouch.
  ///
  /// In ar, this message translates to:
  /// **'على تواصل'**
  String get familyGroupInTouch;

  /// No description provided for @familyGroupNoRhythm.
  ///
  /// In ar, this message translates to:
  /// **'بلا موعد محدّد'**
  String get familyGroupNoRhythm;

  /// No description provided for @familyHeroWaiting.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا أحد ينتظر} =1{شخص واحد ينتظر سؤالك} =2{شخصان ينتظران سؤالك} few{{count} أشخاص ينتظرون سؤالك} many{{count} شخصًا ينتظرون سؤالك} other{{count} شخص ينتظرون سؤالك}}'**
  String familyHeroWaiting(int count);

  /// No description provided for @familyHeroAllGood.
  ///
  /// In ar, this message translates to:
  /// **'الجميع على تواصل'**
  String get familyHeroAllGood;

  /// No description provided for @familyHeroBlessing.
  ///
  /// In ar, this message translates to:
  /// **'بارك الله في وصلك'**
  String get familyHeroBlessing;

  /// No description provided for @familyHeroInTouch.
  ///
  /// In ar, this message translates to:
  /// **'{inTouch} من {total} على تواصل'**
  String familyHeroInTouch(String inTouch, String total);

  /// No description provided for @familyHeroNoRhythm.
  ///
  /// In ar, this message translates to:
  /// **'حدّد كل كم تتواصل مع كل شخص لتظهر هنا مواعيدهم'**
  String get familyHeroNoRhythm;

  /// No description provided for @familyStatusOverdue.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{فات الموعد بيوم} =2{فات الموعد بيومين} few{فات الموعد بـ{count} أيام} many{فات الموعد بـ{count} يومًا} other{فات الموعد بـ{count} يوم}}'**
  String familyStatusOverdue(int count);

  /// No description provided for @familyStatusDueToday.
  ///
  /// In ar, this message translates to:
  /// **'موعد السؤال اليوم'**
  String get familyStatusDueToday;

  /// No description provided for @familyStatusDueIn.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{الموعد غدًا} =2{الموعد بعد يومين} few{الموعد بعد {count} أيام} many{الموعد بعد {count} يومًا} other{الموعد بعد {count} يوم}}'**
  String familyStatusDueIn(int count);

  /// No description provided for @familyStatusNoRhythm.
  ///
  /// In ar, this message translates to:
  /// **'بلا موعد'**
  String get familyStatusNoRhythm;

  /// No description provided for @familyLastNever.
  ///
  /// In ar, this message translates to:
  /// **'لم يُسجَّل تواصل بعد'**
  String get familyLastNever;

  /// No description provided for @familyLastDaysAgo.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{آخر تواصل اليوم} =1{آخر تواصل أمس} =2{آخر تواصل قبل يومين} few{آخر تواصل قبل {count} أيام} many{آخر تواصل قبل {count} يومًا} other{آخر تواصل قبل {count} يوم}}'**
  String familyLastDaysAgo(int count);

  /// No description provided for @familyInDays.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{اليوم} =1{غدًا} =2{بعد يومين} few{بعد {count} أيام} many{بعد {count} يومًا} other{بعد {count} يوم}}'**
  String familyInDays(int count);

  /// No description provided for @familyDaysAgo.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{اليوم} =1{أمس} =2{قبل يومين} few{قبل {count} أيام} many{قبل {count} يومًا} other{قبل {count} يوم}}'**
  String familyDaysAgo(int count);

  /// No description provided for @familyDaysCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{{count} يوم} =1{يوم واحد} =2{يومان} few{{count} أيام} many{{count} يومًا} other{{count} يوم}}'**
  String familyDaysCount(int count);

  /// No description provided for @familyRhythmEvery.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{يوميًا} =2{كل يومين} few{كل {count} أيام} many{كل {count} يومًا} other{كل {count} يوم}}'**
  String familyRhythmEvery(int count);

  /// No description provided for @familyRhythmWeekly.
  ///
  /// In ar, this message translates to:
  /// **'أسبوعيًا'**
  String get familyRhythmWeekly;

  /// No description provided for @familyRhythmBiweekly.
  ///
  /// In ar, this message translates to:
  /// **'كل أسبوعين'**
  String get familyRhythmBiweekly;

  /// No description provided for @familyRhythmMonthly.
  ///
  /// In ar, this message translates to:
  /// **'شهريًا'**
  String get familyRhythmMonthly;

  /// No description provided for @familyRhythmNone.
  ///
  /// In ar, this message translates to:
  /// **'بلا إيقاع'**
  String get familyRhythmNone;

  /// No description provided for @familyRhythmCustom.
  ///
  /// In ar, this message translates to:
  /// **'عدد آخر'**
  String get familyRhythmCustom;

  /// No description provided for @familyRhythmCustomLabel.
  ///
  /// In ar, this message translates to:
  /// **'كل كم يومًا؟'**
  String get familyRhythmCustomLabel;

  /// No description provided for @familyUnitDays.
  ///
  /// In ar, this message translates to:
  /// **'يوم'**
  String get familyUnitDays;

  /// No description provided for @familyChannelCall.
  ///
  /// In ar, this message translates to:
  /// **'مكالمة'**
  String get familyChannelCall;

  /// No description provided for @familyChannelVisit.
  ///
  /// In ar, this message translates to:
  /// **'زيارة'**
  String get familyChannelVisit;

  /// No description provided for @familyChannelMessage.
  ///
  /// In ar, this message translates to:
  /// **'رسالة'**
  String get familyChannelMessage;

  /// No description provided for @familyChannelOther.
  ///
  /// In ar, this message translates to:
  /// **'أخرى'**
  String get familyChannelOther;

  /// No description provided for @familyContacted.
  ///
  /// In ar, this message translates to:
  /// **'تواصلت'**
  String get familyContacted;

  /// No description provided for @familyContactedDetails.
  ///
  /// In ar, this message translates to:
  /// **'تواصلت… مع التفاصيل'**
  String get familyContactedDetails;

  /// No description provided for @familyCall.
  ///
  /// In ar, this message translates to:
  /// **'اتصال'**
  String get familyCall;

  /// No description provided for @familySms.
  ///
  /// In ar, this message translates to:
  /// **'رسالة نصية'**
  String get familySms;

  /// No description provided for @familyWhatsApp.
  ///
  /// In ar, this message translates to:
  /// **'واتساب'**
  String get familyWhatsApp;

  /// No description provided for @familyLaunchFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح التطبيق على هذا الجهاز'**
  String get familyLaunchFailed;

  /// No description provided for @familyMoonShow.
  ///
  /// In ar, this message translates to:
  /// **'أظهِر في المدار'**
  String get familyMoonShow;

  /// No description provided for @familyMoonHide.
  ///
  /// In ar, this message translates to:
  /// **'أخفِ من المدار'**
  String get familyMoonHide;

  /// No description provided for @familyOpenProfile.
  ///
  /// In ar, this message translates to:
  /// **'فتح الملف'**
  String get familyOpenProfile;

  /// No description provided for @familyEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get familyEdit;

  /// No description provided for @familyDelete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get familyDelete;

  /// No description provided for @familyContactedToast.
  ///
  /// In ar, this message translates to:
  /// **'سُجِّل تواصلك مع {name}'**
  String familyContactedToast(String name);

  /// No description provided for @familyDeletedToast.
  ///
  /// In ar, this message translates to:
  /// **'حُذف {name}'**
  String familyDeletedToast(String name);

  /// No description provided for @familySavedToast.
  ///
  /// In ar, this message translates to:
  /// **'حُفظ {name}'**
  String familySavedToast(String name);

  /// No description provided for @familyContactDeletedToast.
  ///
  /// In ar, this message translates to:
  /// **'حُذف التواصل من السجل'**
  String get familyContactDeletedToast;

  /// No description provided for @familyContactUpdatedToast.
  ///
  /// In ar, this message translates to:
  /// **'عُدِّل التواصل'**
  String get familyContactUpdatedToast;

  /// No description provided for @familyMoonShownToast.
  ///
  /// In ar, this message translates to:
  /// **'أُضيف {name} إلى المدار'**
  String familyMoonShownToast(String name);

  /// No description provided for @familyMoonHiddenToast.
  ///
  /// In ar, this message translates to:
  /// **'أُخفي {name} من المدار'**
  String familyMoonHiddenToast(String name);

  /// No description provided for @familyNewPerson.
  ///
  /// In ar, this message translates to:
  /// **'شخص جديد'**
  String get familyNewPerson;

  /// No description provided for @familyNewPersonSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'من تحبّ أن تبقى قريبًا منه'**
  String get familyNewPersonSubtitle;

  /// No description provided for @familyEditTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعديل {name}'**
  String familyEditTitle(String name);

  /// No description provided for @familyFieldName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get familyFieldName;

  /// No description provided for @familyFieldNameHint.
  ///
  /// In ar, this message translates to:
  /// **'مثلًا: أمي، أحمد'**
  String get familyFieldNameHint;

  /// No description provided for @familyFieldNameRequired.
  ///
  /// In ar, this message translates to:
  /// **'اكتب الاسم'**
  String get familyFieldNameRequired;

  /// No description provided for @familyFieldRelation.
  ///
  /// In ar, this message translates to:
  /// **'صلة القرابة'**
  String get familyFieldRelation;

  /// No description provided for @familyFieldRelationHint.
  ///
  /// In ar, this message translates to:
  /// **'اختر أو اكتب'**
  String get familyFieldRelationHint;

  /// No description provided for @familyFieldRhythm.
  ///
  /// In ar, this message translates to:
  /// **'كل كم تتواصل؟'**
  String get familyFieldRhythm;

  /// No description provided for @familyFieldLastContact.
  ///
  /// In ar, this message translates to:
  /// **'آخر تواصل'**
  String get familyFieldLastContact;

  /// No description provided for @familyFieldPhone.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف'**
  String get familyFieldPhone;

  /// No description provided for @familyFieldPhoneHint.
  ///
  /// In ar, this message translates to:
  /// **'مع رمز الدولة ليعمل واتساب'**
  String get familyFieldPhoneHint;

  /// No description provided for @familyFieldBirthday.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الميلاد'**
  String get familyFieldBirthday;

  /// No description provided for @familyBirthdayYearUnknown.
  ///
  /// In ar, this message translates to:
  /// **'السنة غير معروفة'**
  String get familyBirthdayYearUnknown;

  /// No description provided for @familyBirthdayNone.
  ///
  /// In ar, this message translates to:
  /// **'بلا تاريخ'**
  String get familyBirthdayNone;

  /// No description provided for @familyFieldNotes.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات'**
  String get familyFieldNotes;

  /// No description provided for @familyFieldNotesHint.
  ///
  /// In ar, this message translates to:
  /// **'اهتمامات، مناسبات، أفكار هدايا…'**
  String get familyFieldNotesHint;

  /// No description provided for @familyFieldColor.
  ///
  /// In ar, this message translates to:
  /// **'اللون'**
  String get familyFieldColor;

  /// No description provided for @familyFieldMoon.
  ///
  /// In ar, this message translates to:
  /// **'قمر في المدار'**
  String get familyFieldMoon;

  /// No description provided for @familyFieldMoonHint.
  ///
  /// In ar, this message translates to:
  /// **'يظهر قمرًا حول كوكب العائلة في الرئيسية'**
  String get familyFieldMoonHint;

  /// No description provided for @familyMoreDetails.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل أكثر'**
  String get familyMoreDetails;

  /// No description provided for @familyFewerDetails.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل أقل'**
  String get familyFewerDetails;

  /// No description provided for @familySave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get familySave;

  /// No description provided for @familyWhenNow.
  ///
  /// In ar, this message translates to:
  /// **'الآن'**
  String get familyWhenNow;

  /// No description provided for @familyWhenToday.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get familyWhenToday;

  /// No description provided for @familyWhenEarlierToday.
  ///
  /// In ar, this message translates to:
  /// **'في وقت سابق اليوم'**
  String get familyWhenEarlierToday;

  /// No description provided for @familyWhenYesterday.
  ///
  /// In ar, this message translates to:
  /// **'أمس'**
  String get familyWhenYesterday;

  /// No description provided for @familyWhenWeekAgo.
  ///
  /// In ar, this message translates to:
  /// **'قبل أسبوع'**
  String get familyWhenWeekAgo;

  /// No description provided for @familyWhenUnknown.
  ///
  /// In ar, this message translates to:
  /// **'لا أذكر'**
  String get familyWhenUnknown;

  /// No description provided for @familyWhenPick.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ آخر'**
  String get familyWhenPick;

  /// No description provided for @familyContactedTitle.
  ///
  /// In ar, this message translates to:
  /// **'تواصلت مع {name}'**
  String familyContactedTitle(String name);

  /// No description provided for @familyContactedSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'سجّل كيف ومتى — ولو بكلمة'**
  String get familyContactedSubtitle;

  /// No description provided for @familyEditContactTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعديل التواصل'**
  String get familyEditContactTitle;

  /// No description provided for @familyFieldChannel.
  ///
  /// In ar, this message translates to:
  /// **'الطريقة'**
  String get familyFieldChannel;

  /// No description provided for @familyFieldWhen.
  ///
  /// In ar, this message translates to:
  /// **'متى'**
  String get familyFieldWhen;

  /// No description provided for @familyFieldNote.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة'**
  String get familyFieldNote;

  /// No description provided for @familyFieldNoteHint.
  ///
  /// In ar, this message translates to:
  /// **'عمّ تحدّثتما؟'**
  String get familyFieldNoteHint;

  /// No description provided for @familyFutureError.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن تسجيل تواصل في المستقبل'**
  String get familyFutureError;

  /// No description provided for @familyLog.
  ///
  /// In ar, this message translates to:
  /// **'سجّل'**
  String get familyLog;

  /// No description provided for @familyRhythmCardTitle.
  ///
  /// In ar, this message translates to:
  /// **'إيقاع الصلة'**
  String get familyRhythmCardTitle;

  /// No description provided for @familyStatAverage.
  ///
  /// In ar, this message translates to:
  /// **'متوسط الفاصل'**
  String get familyStatAverage;

  /// No description provided for @familyStatOnRhythm.
  ///
  /// In ar, this message translates to:
  /// **'في الموعد'**
  String get familyStatOnRhythm;

  /// No description provided for @familyStatLongestGap.
  ///
  /// In ar, this message translates to:
  /// **'أطول انقطاع'**
  String get familyStatLongestGap;

  /// No description provided for @familyStatRecent.
  ///
  /// In ar, this message translates to:
  /// **'آخر ٩٠ يومًا'**
  String get familyStatRecent;

  /// No description provided for @familyStatTimes.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا مرّات} =1{مرّة واحدة} =2{مرّتان} few{{count} مرّات} many{{count} مرّة} other{{count} مرّة}}'**
  String familyStatTimes(int count);

  /// No description provided for @familyVsRhythm.
  ///
  /// In ar, this message translates to:
  /// **'الإيقاع: {rhythm}'**
  String familyVsRhythm(String rhythm);

  /// No description provided for @familyChartCaption.
  ///
  /// In ar, this message translates to:
  /// **'الفواصل بين آخر مرّات التواصل'**
  String get familyChartCaption;

  /// No description provided for @familyStatsEmpty.
  ///
  /// In ar, this message translates to:
  /// **'بعد مرّتين أو ثلاث من التواصل تظهر هنا إحصاءاتك'**
  String get familyStatsEmpty;

  /// No description provided for @familyHistoryTitle.
  ///
  /// In ar, this message translates to:
  /// **'سجل التواصل'**
  String get familyHistoryTitle;

  /// No description provided for @familyHistoryEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا تواصل مسجّل بعد. اضغط «تواصلت» بعد كل مكالمة أو زيارة.'**
  String get familyHistoryEmpty;

  /// No description provided for @familyNotesTitle.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات'**
  String get familyNotesTitle;

  /// No description provided for @familyNotesAdd.
  ///
  /// In ar, this message translates to:
  /// **'أضف ملاحظة'**
  String get familyNotesAdd;

  /// No description provided for @familyBirthdayTitle.
  ///
  /// In ar, this message translates to:
  /// **'ذكرى الميلاد'**
  String get familyBirthdayTitle;

  /// No description provided for @familyBirthdayTodayBadge.
  ///
  /// In ar, this message translates to:
  /// **'اليوم!'**
  String get familyBirthdayTodayBadge;

  /// No description provided for @familyAgeTurning.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{عام واحد} =2{عامان} few{{count} أعوام} many{{count} عامًا} other{{count} عام}}'**
  String familyAgeTurning(int count);

  /// No description provided for @familyBirthdayUpcoming.
  ///
  /// In ar, this message translates to:
  /// **'ذكرى ميلاد {name} {when}'**
  String familyBirthdayUpcoming(String name, String when);

  /// No description provided for @familyCardMore.
  ///
  /// In ar, this message translates to:
  /// **'و{count} غيرهم'**
  String familyCardMore(String count);

  /// No description provided for @familyCardEmpty.
  ///
  /// In ar, this message translates to:
  /// **'أضف أحبّتك لتبقى على صلة بهم'**
  String get familyCardEmpty;

  /// No description provided for @familyDigestTitle.
  ///
  /// In ar, this message translates to:
  /// **'ملخّص يومي لطيف'**
  String get familyDigestTitle;

  /// No description provided for @familyDigestHint.
  ///
  /// In ar, this message translates to:
  /// **'إشعار واحد في اليوم بمن حان موعد السؤال عنهم — لا إشعار لكل شخص'**
  String get familyDigestHint;

  /// No description provided for @familyDigestTime.
  ///
  /// In ar, this message translates to:
  /// **'وقت الملخّص'**
  String get familyDigestTime;

  /// No description provided for @familyBirthdayReminders.
  ///
  /// In ar, this message translates to:
  /// **'تذكير بذكرى الميلاد'**
  String get familyBirthdayReminders;

  /// No description provided for @familyBirthdayRemindersHint.
  ///
  /// In ar, this message translates to:
  /// **'قبلها بيوم وفي يومها'**
  String get familyBirthdayRemindersHint;

  /// No description provided for @familyBirthdayTime.
  ///
  /// In ar, this message translates to:
  /// **'وقت تذكير الميلاد'**
  String get familyBirthdayTime;

  /// No description provided for @familyNotifyGroup.
  ///
  /// In ar, this message translates to:
  /// **'العائلة والأحبّة'**
  String get familyNotifyGroup;

  /// No description provided for @familyNotifyChannel.
  ///
  /// In ar, this message translates to:
  /// **'تذكيرات الصلة'**
  String get familyNotifyChannel;

  /// No description provided for @familyNotifyChannelDescription.
  ///
  /// In ar, this message translates to:
  /// **'ملخّص الصلة اليومي وتذكيرات ذكرى الميلاد'**
  String get familyNotifyChannelDescription;

  /// No description provided for @familyDigestNotifyTitle.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{شخص واحد ينتظر سؤالك اليوم} =2{شخصان ينتظران سؤالك اليوم} few{{count} أشخاص ينتظرون سؤالك اليوم} many{{count} شخصًا ينتظرون سؤالك اليوم} other{{count} شخص ينتظرون سؤالك اليوم}}'**
  String familyDigestNotifyTitle(int count);

  /// No description provided for @familyDigestNotifyBody.
  ///
  /// In ar, this message translates to:
  /// **'{names} — مكالمة قصيرة تكفي.'**
  String familyDigestNotifyBody(String names);

  /// No description provided for @familyBirthdayEveTitle.
  ///
  /// In ar, this message translates to:
  /// **'غدًا ذكرى ميلاد {name}'**
  String familyBirthdayEveTitle(String name);

  /// No description provided for @familyBirthdayEveBody.
  ///
  /// In ar, this message translates to:
  /// **'جهّز كلمة طيبة أو هدية صغيرة.'**
  String get familyBirthdayEveBody;

  /// No description provided for @familyBirthdayDayTitle.
  ///
  /// In ar, this message translates to:
  /// **'اليوم ذكرى ميلاد {name}'**
  String familyBirthdayDayTitle(String name);

  /// No description provided for @familyBirthdayDayBody.
  ///
  /// In ar, this message translates to:
  /// **'بادِر بالتهنئة.'**
  String get familyBirthdayDayBody;

  /// Separator between names in a list
  ///
  /// In ar, this message translates to:
  /// **'، '**
  String get familyListSep;

  /// Separator between facts on one line
  ///
  /// In ar, this message translates to:
  /// **' · '**
  String get familyDot;

  /// No description provided for @familyRelFather.
  ///
  /// In ar, this message translates to:
  /// **'أبي'**
  String get familyRelFather;

  /// No description provided for @familyRelMother.
  ///
  /// In ar, this message translates to:
  /// **'أمي'**
  String get familyRelMother;

  /// No description provided for @familyRelWife.
  ///
  /// In ar, this message translates to:
  /// **'زوجتي'**
  String get familyRelWife;

  /// No description provided for @familyRelHusband.
  ///
  /// In ar, this message translates to:
  /// **'زوجي'**
  String get familyRelHusband;

  /// No description provided for @familyRelSon.
  ///
  /// In ar, this message translates to:
  /// **'ابني'**
  String get familyRelSon;

  /// No description provided for @familyRelDaughter.
  ///
  /// In ar, this message translates to:
  /// **'ابنتي'**
  String get familyRelDaughter;

  /// No description provided for @familyRelBrother.
  ///
  /// In ar, this message translates to:
  /// **'أخي'**
  String get familyRelBrother;

  /// No description provided for @familyRelSister.
  ///
  /// In ar, this message translates to:
  /// **'أختي'**
  String get familyRelSister;

  /// No description provided for @familyRelGrandfather.
  ///
  /// In ar, this message translates to:
  /// **'جدّي'**
  String get familyRelGrandfather;

  /// No description provided for @familyRelGrandmother.
  ///
  /// In ar, this message translates to:
  /// **'جدّتي'**
  String get familyRelGrandmother;

  /// No description provided for @familyRelUncle.
  ///
  /// In ar, this message translates to:
  /// **'عمّي'**
  String get familyRelUncle;

  /// No description provided for @familyRelMaternalUncle.
  ///
  /// In ar, this message translates to:
  /// **'خالي'**
  String get familyRelMaternalUncle;

  /// No description provided for @familyRelAunt.
  ///
  /// In ar, this message translates to:
  /// **'عمّتي'**
  String get familyRelAunt;

  /// No description provided for @familyRelMaternalAunt.
  ///
  /// In ar, this message translates to:
  /// **'خالتي'**
  String get familyRelMaternalAunt;

  /// No description provided for @familyRelInLaw.
  ///
  /// In ar, this message translates to:
  /// **'نسيبي'**
  String get familyRelInLaw;

  /// No description provided for @familyRelRelative.
  ///
  /// In ar, this message translates to:
  /// **'قريبي'**
  String get familyRelRelative;

  /// No description provided for @familyRelFriend.
  ///
  /// In ar, this message translates to:
  /// **'صديقي'**
  String get familyRelFriend;

  /// No description provided for @familyRelColleague.
  ///
  /// In ar, this message translates to:
  /// **'زميلي'**
  String get familyRelColleague;

  /// No description provided for @familyRelPartner.
  ///
  /// In ar, this message translates to:
  /// **'شريكي'**
  String get familyRelPartner;

  /// No description provided for @familyRelNeighbour.
  ///
  /// In ar, this message translates to:
  /// **'جاري'**
  String get familyRelNeighbour;

  /// No description provided for @familyRelTeacher.
  ///
  /// In ar, this message translates to:
  /// **'معلّمي'**
  String get familyRelTeacher;

  /// Title of the travel screen
  ///
  /// In ar, this message translates to:
  /// **'السفر'**
  String get travelTitle;

  /// No description provided for @travelTabTrips.
  ///
  /// In ar, this message translates to:
  /// **'الرحلات'**
  String get travelTabTrips;

  /// No description provided for @travelTabDocuments.
  ///
  /// In ar, this message translates to:
  /// **'الوثائق'**
  String get travelTabDocuments;

  /// No description provided for @travelTabTemplates.
  ///
  /// In ar, this message translates to:
  /// **'قوائم التجهيز'**
  String get travelTabTemplates;

  /// No description provided for @travelAddTrip.
  ///
  /// In ar, this message translates to:
  /// **'رحلة جديدة'**
  String get travelAddTrip;

  /// No description provided for @travelAddDocument.
  ///
  /// In ar, this message translates to:
  /// **'وثيقة جديدة'**
  String get travelAddDocument;

  /// No description provided for @travelAddTemplate.
  ///
  /// In ar, this message translates to:
  /// **'قائمة جديدة'**
  String get travelAddTemplate;

  /// No description provided for @travelSectionCurrent.
  ///
  /// In ar, this message translates to:
  /// **'في الطريق الآن'**
  String get travelSectionCurrent;

  /// No description provided for @travelSectionUpcoming.
  ///
  /// In ar, this message translates to:
  /// **'رحلات قادمة'**
  String get travelSectionUpcoming;

  /// No description provided for @travelSectionPast.
  ///
  /// In ar, this message translates to:
  /// **'رحلات سابقة'**
  String get travelSectionPast;

  /// No description provided for @travelTripsEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا رحلات بعد'**
  String get travelTripsEmptyTitle;

  /// No description provided for @travelTripsEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'خطّط لرحلتك القادمة: الوجهة والمواعيد وقائمة التجهيز، وأوقات الصلاة والقبلة هناك.'**
  String get travelTripsEmptyBody;

  /// No description provided for @travelTripsEmptyExample.
  ///
  /// In ar, this message translates to:
  /// **'مثلًا: عمرة في الشتاء، أو رحلة عمل قصيرة'**
  String get travelTripsEmptyExample;

  /// No description provided for @travelShowPast.
  ///
  /// In ar, this message translates to:
  /// **'عرض الرحلات السابقة ({n})'**
  String travelShowPast(String n);

  /// No description provided for @travelHidePast.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء الرحلات السابقة'**
  String get travelHidePast;

  /// No description provided for @travelCountdownToday.
  ///
  /// In ar, this message translates to:
  /// **'السفر اليوم'**
  String get travelCountdownToday;

  /// No description provided for @travelCountdownTomorrow.
  ///
  /// In ar, this message translates to:
  /// **'السفر غدًا'**
  String get travelCountdownTomorrow;

  /// No description provided for @travelCountdownIn.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{بعد يوم واحد} =2{بعد يومين} few{بعد {n} أيام} many{بعد {n} يومًا} other{بعد {n} يوم}}'**
  String travelCountdownIn(int count, String n);

  /// No description provided for @travelCountdownDayOf.
  ///
  /// In ar, this message translates to:
  /// **'اليوم {day} من {total}'**
  String travelCountdownDayOf(String day, String total);

  /// No description provided for @travelCountdownDay.
  ///
  /// In ar, this message translates to:
  /// **'اليوم {day}'**
  String travelCountdownDay(String day);

  /// No description provided for @travelCountdownEnded.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{انتهت أمس} =2{انتهت قبل يومين} few{انتهت قبل {n} أيام} many{انتهت قبل {n} يومًا} other{انتهت قبل {n} يوم}}'**
  String travelCountdownEnded(int count, String n);

  /// No description provided for @travelCountdownFinished.
  ///
  /// In ar, this message translates to:
  /// **'انتهت'**
  String get travelCountdownFinished;

  /// No description provided for @travelCountdownUndated.
  ///
  /// In ar, this message translates to:
  /// **'بلا موعد بعد'**
  String get travelCountdownUndated;

  /// No description provided for @travelDays.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{يوم واحد} =2{يومان} few{{n} أيام} many{{n} يومًا} other{{n} يوم}}'**
  String travelDays(int count, String n);

  /// No description provided for @travelOpenEnded.
  ///
  /// In ar, this message translates to:
  /// **'بلا موعد عودة'**
  String get travelOpenEnded;

  /// No description provided for @travelStatusPlanned.
  ///
  /// In ar, this message translates to:
  /// **'مخطّط لها'**
  String get travelStatusPlanned;

  /// No description provided for @travelStatusActive.
  ///
  /// In ar, this message translates to:
  /// **'جارية'**
  String get travelStatusActive;

  /// No description provided for @travelStatusDone.
  ///
  /// In ar, this message translates to:
  /// **'منتهية'**
  String get travelStatusDone;

  /// No description provided for @travelStatusAuto.
  ///
  /// In ar, this message translates to:
  /// **'حسب التواريخ'**
  String get travelStatusAuto;

  /// No description provided for @travelStatusAutoHint.
  ///
  /// In ar, this message translates to:
  /// **'تتغيّر الحالة وحدها مع التواريخ: الآن «{status}»'**
  String travelStatusAutoHint(String status);

  /// No description provided for @travelStatusManualHint.
  ///
  /// In ar, this message translates to:
  /// **'حالة يدوية لا تتبع التواريخ'**
  String get travelStatusManualHint;

  /// No description provided for @travelMarkDone.
  ///
  /// In ar, this message translates to:
  /// **'أنهِ الرحلة'**
  String get travelMarkDone;

  /// No description provided for @travelFollowDates.
  ///
  /// In ar, this message translates to:
  /// **'اتبع التواريخ'**
  String get travelFollowDates;

  /// No description provided for @travelSheetNewTitle.
  ///
  /// In ar, this message translates to:
  /// **'رحلة جديدة'**
  String get travelSheetNewTitle;

  /// No description provided for @travelSheetEditTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الرحلة'**
  String get travelSheetEditTitle;

  /// No description provided for @travelSheetSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'الوجهة والمواعيد، وأوقات الصلاة هناك'**
  String get travelSheetSubtitle;

  /// No description provided for @travelFieldDestination.
  ///
  /// In ar, this message translates to:
  /// **'الوجهة'**
  String get travelFieldDestination;

  /// No description provided for @travelFieldDestinationHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن مدينة أو اكتب أي وجهة'**
  String get travelFieldDestinationHint;

  /// No description provided for @travelDestinationRequired.
  ///
  /// In ar, this message translates to:
  /// **'اكتب الوجهة'**
  String get travelDestinationRequired;

  /// No description provided for @travelDestinationFree.
  ///
  /// In ar, this message translates to:
  /// **'استخدم «{name}» كما كتبتها'**
  String travelDestinationFree(String name);

  /// No description provided for @travelDestinationFreeHint.
  ///
  /// In ar, this message translates to:
  /// **'بلا أوقات صلاة ولا قبلة؛ اختر مدينة من القائمة لتظهر'**
  String get travelDestinationFreeHint;

  /// No description provided for @travelDestinationChange.
  ///
  /// In ar, this message translates to:
  /// **'تغيير'**
  String get travelDestinationChange;

  /// No description provided for @travelDestinationCity.
  ///
  /// In ar, this message translates to:
  /// **'{zone}، القبلة وأوقات الصلاة متاحة'**
  String travelDestinationCity(String zone);

  /// No description provided for @travelFieldStart.
  ///
  /// In ar, this message translates to:
  /// **'المغادرة'**
  String get travelFieldStart;

  /// No description provided for @travelFieldEnd.
  ///
  /// In ar, this message translates to:
  /// **'العودة'**
  String get travelFieldEnd;

  /// No description provided for @travelFieldEndHint.
  ///
  /// In ar, this message translates to:
  /// **'اتركها فارغة إن لم تحدّد العودة بعد'**
  String get travelFieldEndHint;

  /// No description provided for @travelEndBeforeStart.
  ///
  /// In ar, this message translates to:
  /// **'العودة قبل المغادرة'**
  String get travelEndBeforeStart;

  /// No description provided for @travelFieldStatus.
  ///
  /// In ar, this message translates to:
  /// **'الحالة'**
  String get travelFieldStatus;

  /// No description provided for @travelFieldColor.
  ///
  /// In ar, this message translates to:
  /// **'اللون'**
  String get travelFieldColor;

  /// No description provided for @travelFieldNotes.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات'**
  String get travelFieldNotes;

  /// No description provided for @travelFieldNotesHint.
  ///
  /// In ar, this message translates to:
  /// **'الحجوزات، العناوين، ما يجب تذكّره…'**
  String get travelFieldNotesHint;

  /// No description provided for @travelSave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get travelSave;

  /// No description provided for @travelCreate.
  ///
  /// In ar, this message translates to:
  /// **'أضف الرحلة'**
  String get travelCreate;

  /// No description provided for @travelNoDate.
  ///
  /// In ar, this message translates to:
  /// **'لم يُحدَّد'**
  String get travelNoDate;

  /// No description provided for @travelLocalTime.
  ///
  /// In ar, this message translates to:
  /// **'الساعة هناك'**
  String get travelLocalTime;

  /// No description provided for @travelTimeAhead.
  ///
  /// In ar, this message translates to:
  /// **'تسبق هاتفك بـ{duration}'**
  String travelTimeAhead(String duration);

  /// No description provided for @travelTimeBehind.
  ///
  /// In ar, this message translates to:
  /// **'تتأخر عن هاتفك {duration}'**
  String travelTimeBehind(String duration);

  /// No description provided for @travelTimeSame.
  ///
  /// In ar, this message translates to:
  /// **'بتوقيت هاتفك نفسه'**
  String get travelTimeSame;

  /// No description provided for @travelHours.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{ساعة} =2{ساعتين} few{{n} ساعات} many{{n} ساعة} other{{n} ساعة}}'**
  String travelHours(int count, String n);

  /// No description provided for @travelHoursMinutes.
  ///
  /// In ar, this message translates to:
  /// **'{hm} ساعة'**
  String travelHoursMinutes(String hm);

  /// No description provided for @travelTripDates.
  ///
  /// In ar, this message translates to:
  /// **'المواعيد'**
  String get travelTripDates;

  /// No description provided for @travelPackingTitle.
  ///
  /// In ar, this message translates to:
  /// **'قائمة التجهيز'**
  String get travelPackingTitle;

  /// No description provided for @travelPackedCount.
  ///
  /// In ar, this message translates to:
  /// **'{packed} من {total}'**
  String travelPackedCount(String packed, String total);

  /// No description provided for @travelPackingEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا شيء في القائمة بعد'**
  String get travelPackingEmptyTitle;

  /// No description provided for @travelPackingEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'أضف ما ستحتاجه، أو ابدأ من قائمة جاهزة.'**
  String get travelPackingEmptyBody;

  /// No description provided for @travelPackingAllDone.
  ///
  /// In ar, this message translates to:
  /// **'اكتملت الحقيبة، سفرًا موفّقًا'**
  String get travelPackingAllDone;

  /// No description provided for @travelPackingRemaining.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{بقي غرض واحد} =2{بقي غرضان} few{بقيت {n} أغراض} many{بقي {n} غرضًا} other{بقي {n} غرض}}'**
  String travelPackingRemaining(int count, String n);

  /// No description provided for @travelAddItem.
  ///
  /// In ar, this message translates to:
  /// **'أضف غرضًا'**
  String get travelAddItem;

  /// No description provided for @travelAddItemHint.
  ///
  /// In ar, this message translates to:
  /// **'مثلًا: شاحن الهاتف'**
  String get travelAddItemHint;

  /// No description provided for @travelAddItemTo.
  ///
  /// In ar, this message translates to:
  /// **'أضف إلى «{category}»…'**
  String travelAddItemTo(String category);

  /// No description provided for @travelAddItemIn.
  ///
  /// In ar, this message translates to:
  /// **'إلى: {category}'**
  String travelAddItemIn(String category);

  /// No description provided for @travelFromTemplate.
  ///
  /// In ar, this message translates to:
  /// **'من قائمة جاهزة'**
  String get travelFromTemplate;

  /// No description provided for @travelSaveAsTemplate.
  ///
  /// In ar, this message translates to:
  /// **'احفظها قائمة جاهزة'**
  String get travelSaveAsTemplate;

  /// No description provided for @travelUnpackAll.
  ///
  /// In ar, this message translates to:
  /// **'أفرغ الحقيبة'**
  String get travelUnpackAll;

  /// No description provided for @travelTemplatesApplied.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{كل الأغراض موجودة في القائمة أصلًا} =1{أُضيف غرض واحد} =2{أُضيف غرضان} few{أُضيفت {n} أغراض} many{أُضيف {n} غرضًا} other{أُضيف {n} غرض}}'**
  String travelTemplatesApplied(int count, String n);

  /// No description provided for @travelPickTemplatesTitle.
  ///
  /// In ar, this message translates to:
  /// **'اختر قوائم جاهزة'**
  String get travelPickTemplatesTitle;

  /// No description provided for @travelPickTemplatesHint.
  ///
  /// In ar, this message translates to:
  /// **'تُدمج القوائم دون تكرار ما في حقيبتك'**
  String get travelPickTemplatesHint;

  /// No description provided for @travelPickTemplatesAdd.
  ///
  /// In ar, this message translates to:
  /// **'أضف إلى الرحلة'**
  String get travelPickTemplatesAdd;

  /// No description provided for @travelTemplateNameTitle.
  ///
  /// In ar, this message translates to:
  /// **'احفظها قائمة جاهزة'**
  String get travelTemplateNameTitle;

  /// No description provided for @travelTemplateSaved.
  ///
  /// In ar, this message translates to:
  /// **'حُفظت «{name}»'**
  String travelTemplateSaved(String name);

  /// No description provided for @travelItemNewTitle.
  ///
  /// In ar, this message translates to:
  /// **'غرض جديد'**
  String get travelItemNewTitle;

  /// No description provided for @travelItemEditTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الغرض'**
  String get travelItemEditTitle;

  /// No description provided for @travelFieldItem.
  ///
  /// In ar, this message translates to:
  /// **'الغرض'**
  String get travelFieldItem;

  /// No description provided for @travelItemRequired.
  ///
  /// In ar, this message translates to:
  /// **'اكتب الغرض'**
  String get travelItemRequired;

  /// No description provided for @travelFieldCategory.
  ///
  /// In ar, this message translates to:
  /// **'الفئة'**
  String get travelFieldCategory;

  /// No description provided for @travelMoveToCategory.
  ///
  /// In ar, this message translates to:
  /// **'انقل إلى فئة'**
  String get travelMoveToCategory;

  /// No description provided for @travelItemPacked.
  ///
  /// In ar, this message translates to:
  /// **'في الحقيبة'**
  String get travelItemPacked;

  /// No description provided for @travelItemNotPacked.
  ///
  /// In ar, this message translates to:
  /// **'لم يُحزم بعد'**
  String get travelItemNotPacked;

  /// No description provided for @travelPack.
  ///
  /// In ar, this message translates to:
  /// **'في الحقيبة'**
  String get travelPack;

  /// No description provided for @travelUnpack.
  ///
  /// In ar, this message translates to:
  /// **'أخرِجه'**
  String get travelUnpack;

  /// No description provided for @travelCatDocuments.
  ///
  /// In ar, this message translates to:
  /// **'الأوراق والمال'**
  String get travelCatDocuments;

  /// No description provided for @travelCatClothes.
  ///
  /// In ar, this message translates to:
  /// **'الملابس'**
  String get travelCatClothes;

  /// No description provided for @travelCatToiletries.
  ///
  /// In ar, this message translates to:
  /// **'العناية الشخصية'**
  String get travelCatToiletries;

  /// No description provided for @travelCatHealth.
  ///
  /// In ar, this message translates to:
  /// **'الصحة والأدوية'**
  String get travelCatHealth;

  /// No description provided for @travelCatElectronics.
  ///
  /// In ar, this message translates to:
  /// **'الأجهزة والشواحن'**
  String get travelCatElectronics;

  /// No description provided for @travelCatPrayer.
  ///
  /// In ar, this message translates to:
  /// **'العبادة'**
  String get travelCatPrayer;

  /// No description provided for @travelCatMisc.
  ///
  /// In ar, this message translates to:
  /// **'أغراض أخرى'**
  String get travelCatMisc;

  /// No description provided for @travelCatNew.
  ///
  /// In ar, this message translates to:
  /// **'فئة جديدة'**
  String get travelCatNew;

  /// No description provided for @travelCatNewHint.
  ///
  /// In ar, this message translates to:
  /// **'اسم الفئة'**
  String get travelCatNewHint;

  /// No description provided for @travelPrayerTitle.
  ///
  /// In ar, this message translates to:
  /// **'الصلاة في {place}'**
  String travelPrayerTitle(String place);

  /// No description provided for @travelPrayerMethodNote.
  ///
  /// In ar, this message translates to:
  /// **'بطريقة الحساب في إعداداتك، على توقيت الوجهة'**
  String get travelPrayerMethodNote;

  /// No description provided for @travelPrayerNext.
  ///
  /// In ar, this message translates to:
  /// **'{prayer} بعد {duration}'**
  String travelPrayerNext(String prayer, String duration);

  /// No description provided for @travelPrayerUseHere.
  ///
  /// In ar, this message translates to:
  /// **'اعتمدها موقعًا لصلاتي أثناء السفر'**
  String get travelPrayerUseHere;

  /// No description provided for @travelPrayerIsLocation.
  ///
  /// In ar, this message translates to:
  /// **'هذه وجهة صلاتك الآن'**
  String get travelPrayerIsLocation;

  /// No description provided for @travelPrayerUsed.
  ///
  /// In ar, this message translates to:
  /// **'صارت أوقات صلاتك على توقيت {place}'**
  String travelPrayerUsed(String place);

  /// No description provided for @travelPrayerNoPlace.
  ///
  /// In ar, this message translates to:
  /// **'اختر الوجهة من قائمة المدن لتظهر أوقات الصلاة والقبلة هناك.'**
  String get travelPrayerNoPlace;

  /// No description provided for @travelPrayerPickCity.
  ///
  /// In ar, this message translates to:
  /// **'اختر المدينة'**
  String get travelPrayerPickCity;

  /// No description provided for @travelPrayerToday.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get travelPrayerToday;

  /// No description provided for @travelQiblaTitle.
  ///
  /// In ar, this message translates to:
  /// **'القبلة من هناك'**
  String get travelQiblaTitle;

  /// No description provided for @travelQiblaBearing.
  ///
  /// In ar, this message translates to:
  /// **'{bearing} من الشمال'**
  String travelQiblaBearing(String bearing);

  /// No description provided for @travelQiblaDistance.
  ///
  /// In ar, this message translates to:
  /// **'{distance} إلى الكعبة'**
  String travelQiblaDistance(String distance);

  /// No description provided for @travelQiblaAtKaaba.
  ///
  /// In ar, this message translates to:
  /// **'أنت عند الكعبة'**
  String get travelQiblaAtKaaba;

  /// No description provided for @travelQiblaSemantics.
  ///
  /// In ar, this message translates to:
  /// **'اتجاه القبلة {bearing}'**
  String travelQiblaSemantics(String bearing);

  /// No description provided for @travelWarnBeforeTrip.
  ///
  /// In ar, this message translates to:
  /// **'{doc}: الصلاحية تنتهي قبل السفر ({date})'**
  String travelWarnBeforeTrip(String doc, String date);

  /// No description provided for @travelWarnDuringTrip.
  ///
  /// In ar, this message translates to:
  /// **'{doc}: الصلاحية تنتهي أثناء الرحلة ({date})'**
  String travelWarnDuringTrip(String doc, String date);

  /// No description provided for @travelWarnValidity.
  ///
  /// In ar, this message translates to:
  /// **'{doc}: تنتهي الصلاحية بعد عودتك بأقل من {months} أشهر، ودول كثيرة تشترط مدة أطول'**
  String travelWarnValidity(String doc, String months);

  /// No description provided for @travelWarnTrip.
  ///
  /// In ar, this message translates to:
  /// **'رحلة {destination}'**
  String travelWarnTrip(String destination);

  /// No description provided for @travelDocsEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا وثائق بعد'**
  String get travelDocsEmptyTitle;

  /// No description provided for @travelDocsEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'سجّل الجوازات والتأشيرات والرخص ليذكّرك مدار قبل انتهائها، وينبّهك إن انتهت قبل رحلة.'**
  String get travelDocsEmptyBody;

  /// No description provided for @travelDocNew.
  ///
  /// In ar, this message translates to:
  /// **'وثيقة جديدة'**
  String get travelDocNew;

  /// No description provided for @travelDocEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الوثيقة'**
  String get travelDocEdit;

  /// No description provided for @travelDocSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'تذكير قبل الانتهاء بالمدة التي تختارها'**
  String get travelDocSubtitle;

  /// No description provided for @travelDocName.
  ///
  /// In ar, this message translates to:
  /// **'الوثيقة'**
  String get travelDocName;

  /// No description provided for @travelDocNameHint.
  ///
  /// In ar, this message translates to:
  /// **'جواز السفر، تأشيرة، رخصة قيادة…'**
  String get travelDocNameHint;

  /// No description provided for @travelDocNameRequired.
  ///
  /// In ar, this message translates to:
  /// **'اكتب اسم الوثيقة'**
  String get travelDocNameRequired;

  /// No description provided for @travelDocHolder.
  ///
  /// In ar, this message translates to:
  /// **'صاحبها'**
  String get travelDocHolder;

  /// No description provided for @travelDocHolderHint.
  ///
  /// In ar, this message translates to:
  /// **'لمن هذه الوثيقة؟'**
  String get travelDocHolderHint;

  /// No description provided for @travelDocNumber.
  ///
  /// In ar, this message translates to:
  /// **'الرقم'**
  String get travelDocNumber;

  /// No description provided for @travelDocExpiry.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الانتهاء'**
  String get travelDocExpiry;

  /// No description provided for @travelDocRemind.
  ///
  /// In ar, this message translates to:
  /// **'ذكّرني'**
  String get travelDocRemind;

  /// No description provided for @travelDocNumberShort.
  ///
  /// In ar, this message translates to:
  /// **'رقم {last}'**
  String travelDocNumberShort(String last);

  /// No description provided for @travelRemindOnDay.
  ///
  /// In ar, this message translates to:
  /// **'يوم الانتهاء فقط'**
  String get travelRemindOnDay;

  /// No description provided for @travelRemindWeek.
  ///
  /// In ar, this message translates to:
  /// **'قبل أسبوع'**
  String get travelRemindWeek;

  /// No description provided for @travelRemindTwoWeeks.
  ///
  /// In ar, this message translates to:
  /// **'قبل أسبوعين'**
  String get travelRemindTwoWeeks;

  /// No description provided for @travelRemindMonth.
  ///
  /// In ar, this message translates to:
  /// **'قبل شهر'**
  String get travelRemindMonth;

  /// No description provided for @travelRemindTwoMonths.
  ///
  /// In ar, this message translates to:
  /// **'قبل شهرين'**
  String get travelRemindTwoMonths;

  /// No description provided for @travelRemindMonths.
  ///
  /// In ar, this message translates to:
  /// **'قبل {n} أشهر'**
  String travelRemindMonths(String n);

  /// No description provided for @travelRemindDays.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{يوم الانتهاء فقط} =1{قبل يوم} =2{قبل يومين} few{قبل {n} أيام} many{قبل {n} يومًا} other{قبل {n} يوم}}'**
  String travelRemindDays(int count, String n);

  /// No description provided for @travelRemindSummary.
  ///
  /// In ar, this message translates to:
  /// **'التذكير: {when}'**
  String travelRemindSummary(String when);

  /// No description provided for @travelExpiresToday.
  ///
  /// In ar, this message translates to:
  /// **'الانتهاء اليوم'**
  String get travelExpiresToday;

  /// No description provided for @travelExpiresInDays.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{الانتهاء غدًا} =2{الانتهاء بعد يومين} few{الانتهاء بعد {n} أيام} many{الانتهاء بعد {n} يومًا} other{الانتهاء بعد {n} يوم}}'**
  String travelExpiresInDays(int count, String n);

  /// No description provided for @travelExpiresInMonths.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{الانتهاء بعد شهر} =2{الانتهاء بعد شهرين} few{الانتهاء بعد {n} أشهر} many{الانتهاء بعد {n} شهرًا} other{الانتهاء بعد {n} شهر}}'**
  String travelExpiresInMonths(int count, String n);

  /// No description provided for @travelExpiresInYears.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{الانتهاء بعد سنة} =2{الانتهاء بعد سنتين} few{الانتهاء بعد {n} سنوات} many{الانتهاء بعد {n} سنة} other{الانتهاء بعد {n} سنة}}'**
  String travelExpiresInYears(int count, String n);

  /// No description provided for @travelExpiredAgo.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{انتهت الصلاحية أمس} =2{انتهت الصلاحية منذ يومين} few{انتهت الصلاحية منذ {n} أيام} many{انتهت الصلاحية منذ {n} يومًا} other{انتهت الصلاحية منذ {n} يوم}}'**
  String travelExpiredAgo(int count, String n);

  /// No description provided for @travelExpiredOn.
  ///
  /// In ar, this message translates to:
  /// **'انتهت الصلاحية في {date}'**
  String travelExpiredOn(String date);

  /// No description provided for @travelNoExpiry.
  ///
  /// In ar, this message translates to:
  /// **'بلا تاريخ انتهاء'**
  String get travelNoExpiry;

  /// No description provided for @travelDocKindPassport.
  ///
  /// In ar, this message translates to:
  /// **'جواز سفر'**
  String get travelDocKindPassport;

  /// No description provided for @travelDocKindVisa.
  ///
  /// In ar, this message translates to:
  /// **'تأشيرة'**
  String get travelDocKindVisa;

  /// No description provided for @travelDocKindLicence.
  ///
  /// In ar, this message translates to:
  /// **'رخصة'**
  String get travelDocKindLicence;

  /// No description provided for @travelDocKindId.
  ///
  /// In ar, this message translates to:
  /// **'هوية'**
  String get travelDocKindId;

  /// No description provided for @travelDocKindInsurance.
  ///
  /// In ar, this message translates to:
  /// **'تأمين'**
  String get travelDocKindInsurance;

  /// No description provided for @travelDocKindOther.
  ///
  /// In ar, this message translates to:
  /// **'وثيقة'**
  String get travelDocKindOther;

  /// No description provided for @travelDocAffects.
  ///
  /// In ar, this message translates to:
  /// **'يمسّ رحلة {destination}'**
  String travelDocAffects(String destination);

  /// No description provided for @travelNoticeGroup.
  ///
  /// In ar, this message translates to:
  /// **'السفر'**
  String get travelNoticeGroup;

  /// No description provided for @travelNoticeChannel.
  ///
  /// In ar, this message translates to:
  /// **'انتهاء الوثائق'**
  String get travelNoticeChannel;

  /// No description provided for @travelNoticeChannelDescription.
  ///
  /// In ar, this message translates to:
  /// **'تذكير قبل انتهاء الجوازات والتأشيرات والرخص'**
  String get travelNoticeChannelDescription;

  /// No description provided for @travelNoticeTitle.
  ///
  /// In ar, this message translates to:
  /// **'{doc}: {when}'**
  String travelNoticeTitle(String doc, String when);

  /// No description provided for @travelNoticeAheadBody.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الانتهاء {date}. ابدأ التجديد مبكرًا حتى لا تتعطّل رحلاتك.'**
  String travelNoticeAheadBody(String date);

  /// No description provided for @travelNoticeOnDayBody.
  ///
  /// In ar, this message translates to:
  /// **'تنتهي صلاحيتها اليوم. جدّدها قبل سفرك القادم.'**
  String get travelNoticeOnDayBody;

  /// No description provided for @travelDocWithHolder.
  ///
  /// In ar, this message translates to:
  /// **'{doc} ({holder})'**
  String travelDocWithHolder(String doc, String holder);

  /// No description provided for @travelTemplatesTitle.
  ///
  /// In ar, this message translates to:
  /// **'قوائم التجهيز الجاهزة'**
  String get travelTemplatesTitle;

  /// No description provided for @travelTemplatesEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا قوائم جاهزة بعد'**
  String get travelTemplatesEmptyTitle;

  /// No description provided for @travelTemplatesEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'القائمة الجاهزة تملأ حقيبة أي رحلة بلمسة، وتحفظ ما تنساه عادةً.'**
  String get travelTemplatesEmptyBody;

  /// No description provided for @travelTemplatesStarter.
  ///
  /// In ar, this message translates to:
  /// **'أضف قوائم مقترحة'**
  String get travelTemplatesStarter;

  /// No description provided for @travelTemplatesStarterAdded.
  ///
  /// In ar, this message translates to:
  /// **'أُضيفت القوائم المقترحة، عدّلها كما تشاء'**
  String get travelTemplatesStarterAdded;

  /// No description provided for @travelTemplateItems.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا أغراض} =1{غرض واحد} =2{غرضان} few{{n} أغراض} many{{n} غرضًا} other{{n} غرض}}'**
  String travelTemplateItems(int count, String n);

  /// No description provided for @travelTemplateNew.
  ///
  /// In ar, this message translates to:
  /// **'قائمة جديدة'**
  String get travelTemplateNew;

  /// No description provided for @travelTemplateRename.
  ///
  /// In ar, this message translates to:
  /// **'إعادة التسمية'**
  String get travelTemplateRename;

  /// No description provided for @travelTemplateName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get travelTemplateName;

  /// No description provided for @travelTemplateNameHint.
  ///
  /// In ar, this message translates to:
  /// **'مثلًا: رحلة عمل'**
  String get travelTemplateNameHint;

  /// No description provided for @travelTemplateNameRequired.
  ///
  /// In ar, this message translates to:
  /// **'اكتب اسمًا'**
  String get travelTemplateNameRequired;

  /// No description provided for @travelTemplateEmptyItems.
  ///
  /// In ar, this message translates to:
  /// **'أضف أغراض هذه القائمة، ورتّبها بالسحب.'**
  String get travelTemplateEmptyItems;

  /// No description provided for @travelTemplateCopy.
  ///
  /// In ar, this message translates to:
  /// **'{name} (نسخة)'**
  String travelTemplateCopy(String name);

  /// No description provided for @travelStarterEssentials.
  ///
  /// In ar, this message translates to:
  /// **'الأساسيات'**
  String get travelStarterEssentials;

  /// No description provided for @travelStarterBusiness.
  ///
  /// In ar, this message translates to:
  /// **'رحلة عمل'**
  String get travelStarterBusiness;

  /// No description provided for @travelStarterUmrah.
  ///
  /// In ar, this message translates to:
  /// **'العمرة'**
  String get travelStarterUmrah;

  /// No description provided for @travelStarterWinter.
  ///
  /// In ar, this message translates to:
  /// **'سفر الشتاء'**
  String get travelStarterWinter;

  /// No description provided for @travelSeedPassport.
  ///
  /// In ar, this message translates to:
  /// **'جواز السفر'**
  String get travelSeedPassport;

  /// No description provided for @travelSeedTickets.
  ///
  /// In ar, this message translates to:
  /// **'التذاكر والحجوزات'**
  String get travelSeedTickets;

  /// No description provided for @travelSeedWallet.
  ///
  /// In ar, this message translates to:
  /// **'المحفظة والبطاقات'**
  String get travelSeedWallet;

  /// No description provided for @travelSeedCash.
  ///
  /// In ar, this message translates to:
  /// **'نقود بعملة البلد'**
  String get travelSeedCash;

  /// No description provided for @travelSeedClothes.
  ///
  /// In ar, this message translates to:
  /// **'ملابس لأيام الرحلة'**
  String get travelSeedClothes;

  /// No description provided for @travelSeedSleepwear.
  ///
  /// In ar, this message translates to:
  /// **'ملابس النوم'**
  String get travelSeedSleepwear;

  /// No description provided for @travelSeedToothbrush.
  ///
  /// In ar, this message translates to:
  /// **'فرشاة ومعجون الأسنان'**
  String get travelSeedToothbrush;

  /// No description provided for @travelSeedMiswak.
  ///
  /// In ar, this message translates to:
  /// **'سواك'**
  String get travelSeedMiswak;

  /// No description provided for @travelSeedDeodorant.
  ///
  /// In ar, this message translates to:
  /// **'مزيل العرق'**
  String get travelSeedDeodorant;

  /// No description provided for @travelSeedMeds.
  ///
  /// In ar, this message translates to:
  /// **'أدويتي المعتادة'**
  String get travelSeedMeds;

  /// No description provided for @travelSeedFirstAid.
  ///
  /// In ar, this message translates to:
  /// **'إسعافات أولية'**
  String get travelSeedFirstAid;

  /// No description provided for @travelSeedCharger.
  ///
  /// In ar, this message translates to:
  /// **'شاحن الهاتف'**
  String get travelSeedCharger;

  /// No description provided for @travelSeedPowerBank.
  ///
  /// In ar, this message translates to:
  /// **'بطارية متنقلة'**
  String get travelSeedPowerBank;

  /// No description provided for @travelSeedAdapter.
  ///
  /// In ar, this message translates to:
  /// **'محوّل كهرباء'**
  String get travelSeedAdapter;

  /// No description provided for @travelSeedPrayerMat.
  ///
  /// In ar, this message translates to:
  /// **'سجادة صلاة للسفر'**
  String get travelSeedPrayerMat;

  /// No description provided for @travelSeedQuran.
  ///
  /// In ar, this message translates to:
  /// **'مصحف الجيب'**
  String get travelSeedQuran;

  /// No description provided for @travelSeedLaptop.
  ///
  /// In ar, this message translates to:
  /// **'الحاسوب وشاحنه'**
  String get travelSeedLaptop;

  /// No description provided for @travelSeedFormal.
  ///
  /// In ar, this message translates to:
  /// **'ملابس رسمية'**
  String get travelSeedFormal;

  /// No description provided for @travelSeedCards.
  ///
  /// In ar, this message translates to:
  /// **'بطاقات العمل'**
  String get travelSeedCards;

  /// No description provided for @travelSeedNotebook.
  ///
  /// In ar, this message translates to:
  /// **'دفتر وقلم'**
  String get travelSeedNotebook;

  /// No description provided for @travelSeedIhram.
  ///
  /// In ar, this message translates to:
  /// **'ملابس الإحرام'**
  String get travelSeedIhram;

  /// No description provided for @travelSeedIhramBelt.
  ///
  /// In ar, this message translates to:
  /// **'حزام الإحرام'**
  String get travelSeedIhramBelt;

  /// No description provided for @travelSeedUnscented.
  ///
  /// In ar, this message translates to:
  /// **'صابون بلا عطر'**
  String get travelSeedUnscented;

  /// No description provided for @travelSeedSandals.
  ///
  /// In ar, this message translates to:
  /// **'نعال مريحة'**
  String get travelSeedSandals;

  /// No description provided for @travelSeedShoeBag.
  ///
  /// In ar, this message translates to:
  /// **'كيس للأحذية'**
  String get travelSeedShoeBag;

  /// No description provided for @travelSeedUmbrella.
  ///
  /// In ar, this message translates to:
  /// **'مظلة للشمس'**
  String get travelSeedUmbrella;

  /// No description provided for @travelSeedDuas.
  ///
  /// In ar, this message translates to:
  /// **'كتيّب الأدعية'**
  String get travelSeedDuas;

  /// No description provided for @travelSeedWater.
  ///
  /// In ar, this message translates to:
  /// **'قارورة ماء'**
  String get travelSeedWater;

  /// No description provided for @travelSeedPermit.
  ///
  /// In ar, this message translates to:
  /// **'تصريح العمرة'**
  String get travelSeedPermit;

  /// No description provided for @travelSeedCoat.
  ///
  /// In ar, this message translates to:
  /// **'معطف ثقيل'**
  String get travelSeedCoat;

  /// No description provided for @travelSeedScarf.
  ///
  /// In ar, this message translates to:
  /// **'وشاح وقفازات'**
  String get travelSeedScarf;

  /// No description provided for @travelSeedThermal.
  ///
  /// In ar, this message translates to:
  /// **'ملابس حرارية'**
  String get travelSeedThermal;

  /// No description provided for @travelSeedLipBalm.
  ///
  /// In ar, this message translates to:
  /// **'مرطّب شفاه'**
  String get travelSeedLipBalm;

  /// No description provided for @travelCardNoTrips.
  ///
  /// In ar, this message translates to:
  /// **'لا رحلات قادمة'**
  String get travelCardNoTrips;

  /// No description provided for @travelCardPacked.
  ///
  /// In ar, this message translates to:
  /// **'{packed}/{total} في الحقيبة'**
  String travelCardPacked(String packed, String total);

  /// No description provided for @travelCardNoPacking.
  ///
  /// In ar, this message translates to:
  /// **'لم تبدأ قائمة التجهيز'**
  String get travelCardNoPacking;

  /// Hub card line under the trip under way: the next trip and its countdown
  ///
  /// In ar, this message translates to:
  /// **'الرحلة التالية: {destination} · {countdown}'**
  String travelCardNext(String destination, String countdown);

  /// No description provided for @travelCardDocsAttention.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{وثيقة تحتاج انتباهك} =2{وثيقتان تحتاجان انتباهك} few{{n} وثائق تحتاج انتباهك} many{{n} وثيقة تحتاج انتباهك} other{{n} وثيقة تحتاج انتباهك}}'**
  String travelCardDocsAttention(int count, String n);

  /// No description provided for @travelUndoTripDeleted.
  ///
  /// In ar, this message translates to:
  /// **'حُذفت الرحلة'**
  String get travelUndoTripDeleted;

  /// No description provided for @travelUndoTripDuplicated.
  ///
  /// In ar, this message translates to:
  /// **'نُسخت الرحلة'**
  String get travelUndoTripDuplicated;

  /// No description provided for @travelUndoItemDeleted.
  ///
  /// In ar, this message translates to:
  /// **'حُذف الغرض'**
  String get travelUndoItemDeleted;

  /// No description provided for @travelUndoPacked.
  ///
  /// In ar, this message translates to:
  /// **'في الحقيبة'**
  String get travelUndoPacked;

  /// No description provided for @travelUndoUnpacked.
  ///
  /// In ar, this message translates to:
  /// **'أُخرج من الحقيبة'**
  String get travelUndoUnpacked;

  /// No description provided for @travelUndoMoved.
  ///
  /// In ar, this message translates to:
  /// **'نُقل إلى {category}'**
  String travelUndoMoved(String category);

  /// No description provided for @travelUndoDocDeleted.
  ///
  /// In ar, this message translates to:
  /// **'حُذفت الوثيقة'**
  String get travelUndoDocDeleted;

  /// No description provided for @travelUndoDocDuplicated.
  ///
  /// In ar, this message translates to:
  /// **'نُسخت الوثيقة'**
  String get travelUndoDocDuplicated;

  /// No description provided for @travelUndoTemplateDeleted.
  ///
  /// In ar, this message translates to:
  /// **'حُذفت القائمة'**
  String get travelUndoTemplateDeleted;

  /// No description provided for @travelUndoTemplateDuplicated.
  ///
  /// In ar, this message translates to:
  /// **'نُسخت القائمة'**
  String get travelUndoTemplateDuplicated;

  /// No description provided for @travelUndoStatus.
  ///
  /// In ar, this message translates to:
  /// **'الرحلة الآن: {status}'**
  String travelUndoStatus(String status);

  /// No description provided for @travelUndoUnpackedAll.
  ///
  /// In ar, this message translates to:
  /// **'أُفرغت الحقيبة'**
  String get travelUndoUnpackedAll;

  /// No description provided for @travelUndoSaved.
  ///
  /// In ar, this message translates to:
  /// **'حُفظت التعديلات'**
  String get travelUndoSaved;

  /// No description provided for @travelUndoReminder.
  ///
  /// In ar, this message translates to:
  /// **'التذكير: {when}'**
  String travelUndoReminder(String when);

  /// No description provided for @travelOpenTrip.
  ///
  /// In ar, this message translates to:
  /// **'افتح رحلة {destination}'**
  String travelOpenTrip(String destination);

  /// No description provided for @travelMore.
  ///
  /// In ar, this message translates to:
  /// **'المزيد'**
  String get travelMore;

  /// No description provided for @travelEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get travelEdit;

  /// No description provided for @travelTripNotFound.
  ///
  /// In ar, this message translates to:
  /// **'لم تعد هذه الرحلة موجودة'**
  String get travelTripNotFound;

  /// Growth screen title
  ///
  /// In ar, this message translates to:
  /// **'أهداف التعلّم'**
  String get growthTitle;

  /// Goal sheet title / add button
  ///
  /// In ar, this message translates to:
  /// **'هدف جديد'**
  String get growthNewGoal;

  /// Goal sheet title when editing
  ///
  /// In ar, this message translates to:
  /// **'تعديل الهدف'**
  String get growthEditGoal;

  /// Empty state title
  ///
  /// In ar, this message translates to:
  /// **'ابدأ رحلة تعلّم'**
  String get growthEmptyTitle;

  /// Empty state body with generic examples
  ///
  /// In ar, this message translates to:
  /// **'ضع هدفًا تقيسه وسجّل تقدّمك أولًا بأول: كقراءة كتاب من ثلاثمئة صفحة، أو إنهاء دورة من اثني عشر درسًا.'**
  String get growthEmptyBody;

  /// Empty state button
  ///
  /// In ar, this message translates to:
  /// **'أضف أول هدف'**
  String get growthEmptyAction;

  /// Section: active goals
  ///
  /// In ar, this message translates to:
  /// **'قيد التعلّم'**
  String get growthSectionActive;

  /// Section: completed goals
  ///
  /// In ar, this message translates to:
  /// **'أهداف مكتملة'**
  String get growthSectionCompleted;

  /// Section: paused goals
  ///
  /// In ar, this message translates to:
  /// **'متوقفة مؤقتًا'**
  String get growthSectionPaused;

  /// Hint under the active list
  ///
  /// In ar, this message translates to:
  /// **'اسحب المقبض لترتيب أهدافك'**
  String get growthSectionHint;

  /// Overview panel title
  ///
  /// In ar, this message translates to:
  /// **'مسيرة التعلّم'**
  String get growthOverviewTitle;

  /// Number of active goals
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا أهداف نشطة} =1{هدف نشط واحد} =2{هدفان نشطان} few{{count} أهداف نشطة} many{{count} هدفًا نشطًا} other{{count} هدف نشط}}'**
  String growthActiveGoals(int count);

  /// Number of completed goals
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا أهداف مكتملة} =1{هدف مكتمل} =2{هدفان مكتملان} few{{count} أهداف مكتملة} many{{count} هدفًا مكتملًا} other{{count} هدف مكتمل}}'**
  String growthCompletedGoals(int count);

  /// Overview: goals with a log today (pre-formatted numbers)
  ///
  /// In ar, this message translates to:
  /// **'سجّلتَ اليوم في {done} من {total}'**
  String growthLoggedToday(String done, String total);

  /// Overview: no log today
  ///
  /// In ar, this message translates to:
  /// **'لم تسجّل شيئًا اليوم بعد'**
  String get growthNothingToday;

  /// Overview ring label
  ///
  /// In ar, this message translates to:
  /// **'المتوسط'**
  String get growthAverageLabel;

  /// Label of the 7-day activity strip
  ///
  /// In ar, this message translates to:
  /// **'الأيام السبعة الأخيرة'**
  String get growthLastSevenDays;

  /// Semantics of a lit day in the strip
  ///
  /// In ar, this message translates to:
  /// **'{day}: سُجّل تقدّم'**
  String growthDayActive(String day);

  /// Semantics of an unlit day in the strip
  ///
  /// In ar, this message translates to:
  /// **'{day}: لا تقدّم'**
  String growthDayIdle(String day);

  /// Stat label: consecutive days
  ///
  /// In ar, this message translates to:
  /// **'السلسلة'**
  String get growthStreakLabel;

  /// Streak length
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا سلسلة بعد} =1{يوم واحد متتالٍ} =2{يومان متتاليان} few{{count} أيام متتالية} many{{count} يومًا متتاليًا} other{{count} يوم متتالٍ}}'**
  String growthStreakDays(int count);

  /// Longest streak caption
  ///
  /// In ar, this message translates to:
  /// **'الأطول: {days}'**
  String growthBestStreak(String days);

  /// Streak not yet extended today
  ///
  /// In ar, this message translates to:
  /// **'سجّل اليوم لتحافظ على سلسلتك'**
  String get growthStreakAtRisk;

  /// Stat label: days with any log
  ///
  /// In ar, this message translates to:
  /// **'أيام النشاط'**
  String get growthActiveDaysLabel;

  /// A number of days
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{{count} يوم} =1{يوم واحد} =2{يومان} few{{count} أيام} many{{count} يومًا} other{{count} يوم}}'**
  String growthDays(int count);

  /// Unit name
  ///
  /// In ar, this message translates to:
  /// **'صفحات'**
  String get growthUnitPagesName;

  /// Whole pages
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{{count} صفحة} =1{صفحة واحدة} =2{صفحتان} few{{count} صفحات} many{{count} صفحة} other{{count} صفحة}}'**
  String growthUnitPages(int count);

  /// Fractional pages
  ///
  /// In ar, this message translates to:
  /// **'{amount} صفحة'**
  String growthUnitPagesDecimal(String amount);

  /// Unit name
  ///
  /// In ar, this message translates to:
  /// **'دروس'**
  String get growthUnitLessonsName;

  /// Whole lessons
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{{count} درس} =1{درس واحد} =2{درسان} few{{count} دروس} many{{count} درسًا} other{{count} درس}}'**
  String growthUnitLessons(int count);

  /// Fractional lessons
  ///
  /// In ar, this message translates to:
  /// **'{amount} درس'**
  String growthUnitLessonsDecimal(String amount);

  /// Unit name
  ///
  /// In ar, this message translates to:
  /// **'ساعات'**
  String get growthUnitHoursName;

  /// Whole hours
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{{count} ساعة} =1{ساعة واحدة} =2{ساعتان} few{{count} ساعات} many{{count} ساعة} other{{count} ساعة}}'**
  String growthUnitHours(int count);

  /// Fractional hours
  ///
  /// In ar, this message translates to:
  /// **'{amount} ساعة'**
  String growthUnitHoursDecimal(String amount);

  /// Unit name
  ///
  /// In ar, this message translates to:
  /// **'فصول'**
  String get growthUnitChaptersName;

  /// Whole chapters
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{{count} فصل} =1{فصل واحد} =2{فصلان} few{{count} فصول} many{{count} فصلًا} other{{count} فصل}}'**
  String growthUnitChapters(int count);

  /// Fractional chapters
  ///
  /// In ar, this message translates to:
  /// **'{amount} فصل'**
  String growthUnitChaptersDecimal(String amount);

  /// Unit name
  ///
  /// In ar, this message translates to:
  /// **'دورات'**
  String get growthUnitCoursesName;

  /// Whole courses
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{{count} دورة} =1{دورة واحدة} =2{دورتان} few{{count} دورات} many{{count} دورة} other{{count} دورة}}'**
  String growthUnitCourses(int count);

  /// Fractional courses
  ///
  /// In ar, this message translates to:
  /// **'{amount} دورة'**
  String growthUnitCoursesDecimal(String amount);

  /// Unit name
  ///
  /// In ar, this message translates to:
  /// **'كلمات'**
  String get growthUnitWordsName;

  /// Whole words
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{{count} كلمة} =1{كلمة واحدة} =2{كلمتان} few{{count} كلمات} many{{count} كلمة} other{{count} كلمة}}'**
  String growthUnitWords(int count);

  /// Fractional words
  ///
  /// In ar, this message translates to:
  /// **'{amount} كلمة'**
  String growthUnitWordsDecimal(String amount);

  /// Unit name
  ///
  /// In ar, this message translates to:
  /// **'كتب'**
  String get growthUnitBooksName;

  /// Whole books
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{{count} كتاب} =1{كتاب واحد} =2{كتابان} few{{count} كتب} many{{count} كتابًا} other{{count} كتاب}}'**
  String growthUnitBooks(int count);

  /// Fractional books
  ///
  /// In ar, this message translates to:
  /// **'{amount} كتاب'**
  String growthUnitBooksDecimal(String amount);

  /// Unit name
  ///
  /// In ar, this message translates to:
  /// **'محاضرات'**
  String get growthUnitLecturesName;

  /// Whole lectures
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{{count} محاضرة} =1{محاضرة واحدة} =2{محاضرتان} few{{count} محاضرات} many{{count} محاضرة} other{{count} محاضرة}}'**
  String growthUnitLectures(int count);

  /// Fractional lectures
  ///
  /// In ar, this message translates to:
  /// **'{amount} محاضرة'**
  String growthUnitLecturesDecimal(String amount);

  /// Unit name
  ///
  /// In ar, this message translates to:
  /// **'دقائق'**
  String get growthUnitMinutesName;

  /// Whole minutes
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{{count} دقيقة} =1{دقيقة واحدة} =2{دقيقتان} few{{count} دقائق} many{{count} دقيقة} other{{count} دقيقة}}'**
  String growthUnitMinutes(int count);

  /// Fractional minutes
  ///
  /// In ar, this message translates to:
  /// **'{amount} دقيقة'**
  String growthUnitMinutesDecimal(String amount);

  /// Unit name
  ///
  /// In ar, this message translates to:
  /// **'مقالات'**
  String get growthUnitArticlesName;

  /// Whole articles
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{{count} مقال} =1{مقال واحد} =2{مقالان} few{{count} مقالات} many{{count} مقالًا} other{{count} مقال}}'**
  String growthUnitArticles(int count);

  /// Fractional articles
  ///
  /// In ar, this message translates to:
  /// **'{amount} مقال'**
  String growthUnitArticlesDecimal(String amount);

  /// An amount in the user's own unit
  ///
  /// In ar, this message translates to:
  /// **'{amount} {unit}'**
  String growthAmountCustom(String amount, String unit);

  /// Progress, e.g. 120 of 300 pages
  ///
  /// In ar, this message translates to:
  /// **'{current} من {target}'**
  String growthProgressOf(String current, String target);

  /// What is left
  ///
  /// In ar, this message translates to:
  /// **'تبقّى {amount}'**
  String growthRemaining(String amount);

  /// Overshoot
  ///
  /// In ar, this message translates to:
  /// **'تجاوزتَ الهدف بـ{amount}'**
  String growthExceeded(String amount);

  /// Starting value
  ///
  /// In ar, this message translates to:
  /// **'بدأتَ من {amount}'**
  String growthStartedFrom(String amount);

  /// A daily rate
  ///
  /// In ar, this message translates to:
  /// **'{amount} يوميًا'**
  String growthRatePerDay(String amount);

  /// A weekly rate
  ///
  /// In ar, this message translates to:
  /// **'{amount} أسبوعيًا'**
  String growthRatePerWeek(String amount);

  /// Status pill
  ///
  /// In ar, this message translates to:
  /// **'مكتمل'**
  String get growthPaceCompleted;

  /// Status pill
  ///
  /// In ar, this message translates to:
  /// **'متوقف مؤقتًا'**
  String get growthPacePaused;

  /// Status pill
  ///
  /// In ar, this message translates to:
  /// **'لم يبدأ بعد'**
  String get growthPaceNotStarted;

  /// Status pill: no deadline
  ///
  /// In ar, this message translates to:
  /// **'بلا موعد'**
  String get growthPaceNoDeadline;

  /// Status pill
  ///
  /// In ar, this message translates to:
  /// **'متقدّم'**
  String get growthPaceAhead;

  /// Status pill
  ///
  /// In ar, this message translates to:
  /// **'على المسار'**
  String get growthPaceOnTrack;

  /// Status pill
  ///
  /// In ar, this message translates to:
  /// **'متأخّر'**
  String get growthPaceBehind;

  /// Status pill
  ///
  /// In ar, this message translates to:
  /// **'فات الموعد'**
  String get growthPaceOverdue;

  /// Pace line: needed rate until the deadline
  ///
  /// In ar, this message translates to:
  /// **'تحتاج {rate} حتى {date}'**
  String growthLineNeed(String rate, String date);

  /// Pace line when ahead
  ///
  /// In ar, this message translates to:
  /// **'متقدّم بوتيرة {rate}'**
  String growthLineAhead(String rate);

  /// Pace line before the first log
  ///
  /// In ar, this message translates to:
  /// **'{rate} تكفيك حتى {date}'**
  String growthLineStart(String rate, String date);

  /// Pace line: no deadline, no log
  ///
  /// In ar, this message translates to:
  /// **'سجّل أول تقدّم لتبدأ'**
  String get growthLineFirstLog;

  /// Pace line without a deadline
  ///
  /// In ar, this message translates to:
  /// **'وتيرتك {rate}'**
  String growthLineOpen(String rate);

  /// Pace line without a deadline, with a projection
  ///
  /// In ar, this message translates to:
  /// **'وتيرتك {rate}، تُنهيه في {date}'**
  String growthLineOpenFinish(String rate, String date);

  /// Pace line: no recent pace
  ///
  /// In ar, this message translates to:
  /// **'لا تقدّم في الأسبوعين الأخيرين'**
  String get growthLineQuiet;

  /// Pace line after the deadline
  ///
  /// In ar, this message translates to:
  /// **'متأخّر {days}، تبقّى {amount}'**
  String growthLineOverdue(String days, String amount);

  /// Pace line on the deadline day
  ///
  /// In ar, this message translates to:
  /// **'الموعد اليوم، تبقّى {amount}'**
  String growthLineDueToday(String amount);

  /// Completed goal line
  ///
  /// In ar, this message translates to:
  /// **'اكتمل في {date}'**
  String growthLineCompleted(String date);

  /// Paused goal line
  ///
  /// In ar, this message translates to:
  /// **'متوقف مؤقتًا، استأنفه متى شئت'**
  String get growthLinePaused;

  /// Pace comparison: needed rate
  ///
  /// In ar, this message translates to:
  /// **'المطلوب'**
  String get growthNeededLabel;

  /// Pace comparison: actual rate
  ///
  /// In ar, this message translates to:
  /// **'وتيرتك'**
  String get growthActualLabel;

  /// Window of the actual pace
  ///
  /// In ar, this message translates to:
  /// **'آخر {days}'**
  String growthActualWindow(String days);

  /// Needed pace caption
  ///
  /// In ar, this message translates to:
  /// **'حتى {date}'**
  String growthNeededUntil(String date);

  /// No recent logs
  ///
  /// In ar, this message translates to:
  /// **'لا وتيرة بعد'**
  String get growthNoPaceYet;

  /// Projection label
  ///
  /// In ar, this message translates to:
  /// **'الإنهاء المتوقع'**
  String get growthProjectedLabel;

  /// Projection before the deadline
  ///
  /// In ar, this message translates to:
  /// **'قبل الموعد بـ{days}'**
  String growthProjectionEarly(String days);

  /// Projection after the deadline
  ///
  /// In ar, this message translates to:
  /// **'بعد الموعد بـ{days}'**
  String growthProjectionLate(String days);

  /// Projection on the deadline day
  ///
  /// In ar, this message translates to:
  /// **'في الموعد تمامًا'**
  String get growthProjectionOnDay;

  /// No projection
  ///
  /// In ar, this message translates to:
  /// **'سجّل تقدّمًا لنتوقّع موعد إنهائك'**
  String get growthProjectionNone;

  /// Pace card without deadline
  ///
  /// In ar, this message translates to:
  /// **'بلا موعد نهائي، تقدّم بالوتيرة التي تناسبك'**
  String get growthPaceNoDeadlineHint;

  /// Pace card when completed
  ///
  /// In ar, this message translates to:
  /// **'بلغتَ هدفك، ويمكنك مواصلة التسجيل'**
  String get growthPaceDoneHint;

  /// Behind the straight-line plan
  ///
  /// In ar, this message translates to:
  /// **'خلف الخطة بـ{amount}'**
  String growthPlanBehind(String amount);

  /// Ahead of the straight-line plan
  ///
  /// In ar, this message translates to:
  /// **'أمام الخطة بـ{amount}'**
  String growthPlanAhead(String amount);

  /// Days until the deadline
  ///
  /// In ar, this message translates to:
  /// **'بقي {days}'**
  String growthDaysLeft(String days);

  /// Deadline caption
  ///
  /// In ar, this message translates to:
  /// **'الموعد'**
  String get growthDeadlineLabel;

  /// Chart title
  ///
  /// In ar, this message translates to:
  /// **'المسار'**
  String get growthChartTitle;

  /// Chart legend
  ///
  /// In ar, this message translates to:
  /// **'التقدّم'**
  String get growthChartActual;

  /// Chart legend: straight-line plan
  ///
  /// In ar, this message translates to:
  /// **'الخطة'**
  String get growthChartPlan;

  /// Chart legend: target line
  ///
  /// In ar, this message translates to:
  /// **'الهدف'**
  String get growthChartTarget;

  /// Chart legend: projection
  ///
  /// In ar, this message translates to:
  /// **'التوقّع'**
  String get growthChartProjection;

  /// Chart semantics
  ///
  /// In ar, this message translates to:
  /// **'مخطط التقدّم: {current} من {target}'**
  String growthChartSemantics(String current, String target);

  /// History section title
  ///
  /// In ar, this message translates to:
  /// **'سجلّ التقدّم'**
  String get growthHistoryTitle;

  /// History empty
  ///
  /// In ar, this message translates to:
  /// **'لا سجلات بعد. خطوة صغيرة اليوم تصنع الفرق.'**
  String get growthHistoryEmpty;

  /// Day label
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get growthToday;

  /// Day label
  ///
  /// In ar, this message translates to:
  /// **'أمس'**
  String get growthYesterday;

  /// Running total after a log
  ///
  /// In ar, this message translates to:
  /// **'المجموع {amount}'**
  String growthRunningTotal(String amount);

  /// Sum of a day's logs
  ///
  /// In ar, this message translates to:
  /// **'{amount} في هذا اليوم'**
  String growthDayTotal(String amount);

  /// Button / sheet title
  ///
  /// In ar, this message translates to:
  /// **'سجّل تقدّمًا'**
  String get growthLogProgress;

  /// Log sheet title when editing
  ///
  /// In ar, this message translates to:
  /// **'تعديل السجل'**
  String get growthEditLog;

  /// Chip: open the log sheet
  ///
  /// In ar, this message translates to:
  /// **'مقدار آخر'**
  String get growthLogOther;

  /// Quick log action label
  ///
  /// In ar, this message translates to:
  /// **'سجّل {amount}'**
  String growthLogQuick(String amount);

  /// Log sheet field
  ///
  /// In ar, this message translates to:
  /// **'المقدار'**
  String get growthLogAmount;

  /// Log sheet field
  ///
  /// In ar, this message translates to:
  /// **'الوقت'**
  String get growthLogWhen;

  /// Log sheet: date picker label
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get growthLogDate;

  /// Log sheet: time picker label
  ///
  /// In ar, this message translates to:
  /// **'الساعة'**
  String get growthLogTime;

  /// Log sheet: reset to now
  ///
  /// In ar, this message translates to:
  /// **'الآن'**
  String get growthLogNow;

  /// Log sheet field
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة'**
  String get growthLogNote;

  /// Log note hint
  ///
  /// In ar, this message translates to:
  /// **'ماذا تعلّمت؟'**
  String get growthLogNoteHint;

  /// Log sheet preview
  ///
  /// In ar, this message translates to:
  /// **'المجموع بعدها {total} ({percent})'**
  String growthLogNewTotal(String total, String percent);

  /// Log sheet preview when the target is reached
  ///
  /// In ar, this message translates to:
  /// **'بهذا تُتمّ هدفك!'**
  String get growthLogWillComplete;

  /// Log sheet save button
  ///
  /// In ar, this message translates to:
  /// **'سجّل'**
  String get growthLogSave;

  /// Stepper minus
  ///
  /// In ar, this message translates to:
  /// **'أنقِص'**
  String get growthDecrease;

  /// Stepper plus
  ///
  /// In ar, this message translates to:
  /// **'زِد'**
  String get growthIncrease;

  /// Validation
  ///
  /// In ar, this message translates to:
  /// **'أدخل مقدارًا أكبر من صفر'**
  String get growthErrorAmount;

  /// Goal sheet field
  ///
  /// In ar, this message translates to:
  /// **'اسم الهدف'**
  String get growthFieldName;

  /// Generic example
  ///
  /// In ar, this message translates to:
  /// **'مثال: قراءة كتاب في الإدارة'**
  String get growthFieldNameHint;

  /// Goal sheet field
  ///
  /// In ar, this message translates to:
  /// **'الوحدة'**
  String get growthFieldUnit;

  /// Unit hint
  ///
  /// In ar, this message translates to:
  /// **'اختر أو اكتب وحدتك'**
  String get growthFieldUnitHint;

  /// Goal sheet field
  ///
  /// In ar, this message translates to:
  /// **'المستهدف'**
  String get growthFieldTarget;

  /// Goal sheet field
  ///
  /// In ar, this message translates to:
  /// **'نقطة البداية'**
  String get growthFieldInitial;

  /// Starting value hint
  ///
  /// In ar, this message translates to:
  /// **'ما أنجزته من قبل'**
  String get growthFieldInitialHint;

  /// Goal sheet field
  ///
  /// In ar, this message translates to:
  /// **'الموعد النهائي'**
  String get growthFieldDeadline;

  /// Deadline placeholder
  ///
  /// In ar, this message translates to:
  /// **'بلا موعد'**
  String get growthFieldNoDeadline;

  /// Goal sheet field
  ///
  /// In ar, this message translates to:
  /// **'اللون'**
  String get growthFieldColor;

  /// Goal sheet toggle
  ///
  /// In ar, this message translates to:
  /// **'هدف نشط'**
  String get growthFieldActive;

  /// Toggle hint
  ///
  /// In ar, this message translates to:
  /// **'أوقفه مؤقتًا دون أن تخسر تقدّمك'**
  String get growthFieldActiveHint;

  /// Deadline preset
  ///
  /// In ar, this message translates to:
  /// **'بعد شهر'**
  String get growthInMonth;

  /// Deadline preset
  ///
  /// In ar, this message translates to:
  /// **'بعد ثلاثة أشهر'**
  String get growthInThreeMonths;

  /// Deadline preset
  ///
  /// In ar, this message translates to:
  /// **'نهاية السنة'**
  String get growthEndOfYear;

  /// Validation
  ///
  /// In ar, this message translates to:
  /// **'اكتب اسمًا للهدف'**
  String get growthErrorName;

  /// Validation
  ///
  /// In ar, this message translates to:
  /// **'أدخل مقدارًا أكبر من صفر'**
  String get growthErrorTarget;

  /// Validation
  ///
  /// In ar, this message translates to:
  /// **'يجب أن تكون البداية أقل من المستهدف'**
  String get growthErrorInitial;

  /// Goal sheet preview
  ///
  /// In ar, this message translates to:
  /// **'{rate} تكفيك لتبلغ هدفك في {date}'**
  String growthPreviewNeed(String rate, String date);

  /// Goal sheet preview
  ///
  /// In ar, this message translates to:
  /// **'بلا موعد: سجّل تقدّمك بالوتيرة التي تناسبك'**
  String get growthPreviewOpen;

  /// Goal sheet preview
  ///
  /// In ar, this message translates to:
  /// **'هذا الموعد مضى؛ اختر موعدًا قادمًا'**
  String get growthPreviewPast;

  /// Goal sheet save (new)
  ///
  /// In ar, this message translates to:
  /// **'أنشئ الهدف'**
  String get growthCreate;

  /// Goal sheet save (edit)
  ///
  /// In ar, this message translates to:
  /// **'احفظ'**
  String get growthSave;

  /// Sheet cancel
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get growthCancel;

  /// Action
  ///
  /// In ar, this message translates to:
  /// **'إيقاف مؤقت'**
  String get growthPause;

  /// Action
  ///
  /// In ar, this message translates to:
  /// **'استئناف'**
  String get growthResume;

  /// Action
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get growthDelete;

  /// Action
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get growthEdit;

  /// Duplicated goal name
  ///
  /// In ar, this message translates to:
  /// **'{name} (نسخة)'**
  String growthCopyName(String name);

  /// Toast
  ///
  /// In ar, this message translates to:
  /// **'سُجّل {amount}، {goal}'**
  String growthLogged(String amount, String goal);

  /// Toast
  ///
  /// In ar, this message translates to:
  /// **'عُدّل السجل'**
  String get growthLogUpdated;

  /// Toast
  ///
  /// In ar, this message translates to:
  /// **'حُذف السجل'**
  String get growthLogDeleted;

  /// Toast
  ///
  /// In ar, this message translates to:
  /// **'أُضيف الهدف: {name}'**
  String growthGoalCreated(String name);

  /// Toast
  ///
  /// In ar, this message translates to:
  /// **'حُفظت التعديلات'**
  String get growthGoalSaved;

  /// Toast
  ///
  /// In ar, this message translates to:
  /// **'حُذف الهدف: {name}'**
  String growthGoalDeleted(String name);

  /// Toast
  ///
  /// In ar, this message translates to:
  /// **'نُسخ الهدف'**
  String get growthGoalDuplicated;

  /// Toast
  ///
  /// In ar, this message translates to:
  /// **'أُوقف الهدف مؤقتًا'**
  String get growthGoalPaused;

  /// Toast
  ///
  /// In ar, this message translates to:
  /// **'استُؤنف الهدف'**
  String get growthGoalResumed;

  /// Goal screen after delete
  ///
  /// In ar, this message translates to:
  /// **'لم يعد هذا الهدف موجودًا'**
  String get growthGoalMissing;

  /// Celebration title
  ///
  /// In ar, this message translates to:
  /// **'ما شاء الله، أتممتَ هدفك!'**
  String get growthCelebrateTitle;

  /// Celebration body under the goal name
  ///
  /// In ar, this message translates to:
  /// **'{amount} خلال {days}'**
  String growthCelebrateBody(String amount, String days);

  /// Celebration close
  ///
  /// In ar, this message translates to:
  /// **'الحمد لله'**
  String get growthCelebrateThanks;

  /// Celebration: new goal
  ///
  /// In ar, this message translates to:
  /// **'هدف جديد'**
  String get growthCelebrateNext;

  /// Today card title
  ///
  /// In ar, this message translates to:
  /// **'النمو اليوم'**
  String get growthCardTitle;

  /// Today card link
  ///
  /// In ar, this message translates to:
  /// **'كل الأهداف'**
  String get growthCardOpenAll;

  /// Today card empty
  ///
  /// In ar, this message translates to:
  /// **'لا أهداف تعلّم بعد. أضف هدفًا وتابِع تقدّمك هنا.'**
  String get growthCardEmpty;

  /// Today card: all complete
  ///
  /// In ar, this message translates to:
  /// **'أتممتَ كل أهدافك النشطة، بارك الله فيك'**
  String get growthCardAllDone;

  /// Semantics
  ///
  /// In ar, this message translates to:
  /// **'افتح الهدف'**
  String get growthOpenGoal;

  /// Goal tile semantics
  ///
  /// In ar, this message translates to:
  /// **'{name}، {progress}، {status}'**
  String growthGoalSemantics(String name, String progress, String status);

  /// List separator (Arabic comma: a middle dot reads as the digit zero ٠)
  ///
  /// In ar, this message translates to:
  /// **'، '**
  String get growthSep;

  /// Pace card title
  ///
  /// In ar, this message translates to:
  /// **'الوتيرة'**
  String get growthPaceTitle;

  /// Stats: no deadline
  ///
  /// In ar, this message translates to:
  /// **'بلا موعد'**
  String get growthStatsDeadlineNone;

  /// Goal start date
  ///
  /// In ar, this message translates to:
  /// **'بدأ في {date}'**
  String growthStartedOn(String date);

  /// Growth screen: no active goals left
  ///
  /// In ar, this message translates to:
  /// **'لا أهداف قيد التعلّم الآن. ما خطوتك التالية؟'**
  String get growthAllActiveDone;

  /// Days past the deadline
  ///
  /// In ar, this message translates to:
  /// **'فات الموعد منذ {days}'**
  String growthOverdueBy(String days);

  /// Active days out of the goal's days
  ///
  /// In ar, this message translates to:
  /// **'من {days}'**
  String growthOfDays(String days);

  /// Body planet screen title
  ///
  /// In ar, this message translates to:
  /// **'الجسد'**
  String get bodyTitle;

  /// No description provided for @bodyTabToday.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get bodyTabToday;

  /// No description provided for @bodyTabPlan.
  ///
  /// In ar, this message translates to:
  /// **'الخطة'**
  String get bodyTabPlan;

  /// No description provided for @bodyTabFasting.
  ///
  /// In ar, this message translates to:
  /// **'الصيام'**
  String get bodyTabFasting;

  /// No description provided for @bodyTabWater.
  ///
  /// In ar, this message translates to:
  /// **'الماء'**
  String get bodyTabWater;

  /// No description provided for @bodyTabAvoid.
  ///
  /// In ar, this message translates to:
  /// **'تجنّب'**
  String get bodyTabAvoid;

  /// No description provided for @bodySave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get bodySave;

  /// No description provided for @bodyCancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get bodyCancel;

  /// No description provided for @bodyDelete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get bodyDelete;

  /// No description provided for @bodyNameRequired.
  ///
  /// In ar, this message translates to:
  /// **'اكتب اسمًا'**
  String get bodyNameRequired;

  /// No description provided for @bodyKg.
  ///
  /// In ar, this message translates to:
  /// **'{value} كغ'**
  String bodyKg(String value);

  /// No description provided for @bodyMinutes.
  ///
  /// In ar, this message translates to:
  /// **'{value} د'**
  String bodyMinutes(String value);

  /// No description provided for @bodyHours.
  ///
  /// In ar, this message translates to:
  /// **'{value} س'**
  String bodyHours(String value);

  /// No description provided for @bodyRepsValue.
  ///
  /// In ar, this message translates to:
  /// **'{value} تكرار'**
  String bodyRepsValue(String value);

  /// No description provided for @bodySetsReps.
  ///
  /// In ar, this message translates to:
  /// **'{sets} × {reps}'**
  String bodySetsReps(String sets, String reps);

  /// No description provided for @bodyMl.
  ///
  /// In ar, this message translates to:
  /// **'{value} مل'**
  String bodyMl(String value);

  /// No description provided for @bodyLiters.
  ///
  /// In ar, this message translates to:
  /// **'{value} لتر'**
  String bodyLiters(String value);

  /// No description provided for @bodyFraction.
  ///
  /// In ar, this message translates to:
  /// **'{done} من {total}'**
  String bodyFraction(String done, String total);

  /// No description provided for @bodyDaysInRow.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا سلسلة بعد} =1{يوم واحد متتالٍ} =2{يومان متتاليان} few{{n} أيام متتالية} many{{n} يومًا متتاليًا} other{{n} يوم متتالٍ}}'**
  String bodyDaysInRow(int count, String n);

  /// No description provided for @bodyExercisesCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا تمارين} =1{تمرين واحد} =2{تمرينان} few{{n} تمارين} many{{n} تمرينًا} other{{n} تمرين}}'**
  String bodyExercisesCount(int count, String n);

  /// No description provided for @bodyPerWeek.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{بلا أيام محددة} =1{مرة في الأسبوع} =2{مرتان في الأسبوع} few{{n} مرات في الأسبوع} many{{n} مرة في الأسبوع} other{{n} مرة في الأسبوع}}'**
  String bodyPerWeek(int count, String n);

  /// No description provided for @bodyTodaySession.
  ///
  /// In ar, this message translates to:
  /// **'تمرين اليوم'**
  String get bodyTodaySession;

  /// No description provided for @bodyRestDay.
  ///
  /// In ar, this message translates to:
  /// **'يوم راحة'**
  String get bodyRestDay;

  /// No description provided for @bodyRestDayBody.
  ///
  /// In ar, this message translates to:
  /// **'لا شيء في خطة اليوم. خذ قسطك من الراحة.'**
  String get bodyRestDayBody;

  /// No description provided for @bodyNextSession.
  ///
  /// In ar, this message translates to:
  /// **'التمرين القادم: {day}'**
  String bodyNextSession(String day);

  /// No description provided for @bodySessionDone.
  ///
  /// In ar, this message translates to:
  /// **'أنهيت تمرين اليوم — أحسنت!'**
  String get bodySessionDone;

  /// No description provided for @bodySessionKeepGoing.
  ///
  /// In ar, this message translates to:
  /// **'خطوة بخطوة، اسحب التمرين لتسجيله.'**
  String get bodySessionKeepGoing;

  /// No description provided for @bodyNoPlanTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا خطة تمارين بعد'**
  String get bodyNoPlanTitle;

  /// No description provided for @bodyNoPlanBody.
  ///
  /// In ar, this message translates to:
  /// **'أضف تمارينك وأيامها من تبويب «الخطة»، وستظهر هنا في يومها.'**
  String get bodyNoPlanBody;

  /// No description provided for @bodyOpenPlan.
  ///
  /// In ar, this message translates to:
  /// **'إلى الخطة'**
  String get bodyOpenPlan;

  /// No description provided for @bodyAlsoToday.
  ///
  /// In ar, this message translates to:
  /// **'أيضًا اليوم'**
  String get bodyAlsoToday;

  /// No description provided for @bodyLogExtra.
  ///
  /// In ar, this message translates to:
  /// **'سجّل تمرينًا'**
  String get bodyLogExtra;

  /// No description provided for @bodyMarkDone.
  ///
  /// In ar, this message translates to:
  /// **'أنجزته'**
  String get bodyMarkDone;

  /// No description provided for @bodyUnmark.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الإنجاز'**
  String get bodyUnmark;

  /// No description provided for @bodyLogged.
  ///
  /// In ar, this message translates to:
  /// **'أنجزت: {summary}'**
  String bodyLogged(String summary);

  /// No description provided for @bodyLoggedToast.
  ///
  /// In ar, this message translates to:
  /// **'سُجّل «{name}»'**
  String bodyLoggedToast(String name);

  /// No description provided for @bodyUnloggedToast.
  ///
  /// In ar, this message translates to:
  /// **'أُلغي تسجيل «{name}»'**
  String bodyUnloggedToast(String name);

  /// No description provided for @bodyLogDetails.
  ///
  /// In ar, this message translates to:
  /// **'سجّل بالتفاصيل'**
  String get bodyLogDetails;

  /// No description provided for @bodyAvoidReminder.
  ///
  /// In ar, this message translates to:
  /// **'تذكّر أن تتجنّب'**
  String get bodyAvoidReminder;

  /// No description provided for @bodyStateDone.
  ///
  /// In ar, this message translates to:
  /// **'أُنجز'**
  String get bodyStateDone;

  /// No description provided for @bodyStateOpen.
  ///
  /// In ar, this message translates to:
  /// **'لم يُنجز بعد'**
  String get bodyStateOpen;

  /// No description provided for @bodyPlanWeek.
  ///
  /// In ar, this message translates to:
  /// **'هذا الأسبوع'**
  String get bodyPlanWeek;

  /// No description provided for @bodyPlanHint.
  ///
  /// In ar, this message translates to:
  /// **'اسحب المقبض لإعادة الترتيب، واضغط مطوّلًا لبقية الخيارات.'**
  String get bodyPlanHint;

  /// No description provided for @bodyPlanEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'خطتك فارغة'**
  String get bodyPlanEmptyTitle;

  /// No description provided for @bodyPlanEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'أضف تمارينك وأيامها — مثلًا: تمرين ضغط، السبت والإثنين والأربعاء، ٣ × ١٢.'**
  String get bodyPlanEmptyBody;

  /// No description provided for @bodyAddExercise.
  ///
  /// In ar, this message translates to:
  /// **'تمرين جديد'**
  String get bodyAddExercise;

  /// No description provided for @bodyEditExercise.
  ///
  /// In ar, this message translates to:
  /// **'تعديل التمرين'**
  String get bodyEditExercise;

  /// No description provided for @bodyExerciseSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'حدّد أيامه وما تريد إنجازه في كل مرة.'**
  String get bodyExerciseSubtitle;

  /// No description provided for @bodyExerciseName.
  ///
  /// In ar, this message translates to:
  /// **'اسم التمرين'**
  String get bodyExerciseName;

  /// No description provided for @bodyExerciseNameHint.
  ///
  /// In ar, this message translates to:
  /// **'مثلًا: مشي سريع'**
  String get bodyExerciseNameHint;

  /// No description provided for @bodyWeekdays.
  ///
  /// In ar, this message translates to:
  /// **'أيام التمرين'**
  String get bodyWeekdays;

  /// No description provided for @bodyEveryDay.
  ///
  /// In ar, this message translates to:
  /// **'كل يوم'**
  String get bodyEveryDay;

  /// No description provided for @bodyClearDays.
  ///
  /// In ar, this message translates to:
  /// **'مسح'**
  String get bodyClearDays;

  /// Joins the last item of a list (weekday names)
  ///
  /// In ar, this message translates to:
  /// **'{head} و{last}'**
  String bodyListAnd(String head, String last);

  /// Between list items (keep the trailing space)
  ///
  /// In ar, this message translates to:
  /// **'، '**
  String get bodyListSep;

  /// Between parts of a summary like 3 × 12 · 20 kg (keep the spaces; a middle dot beside Arabic-Indic digits reads as a zero)
  ///
  /// In ar, this message translates to:
  /// **'، '**
  String get bodyPartsSep;

  /// No description provided for @bodyNoDays.
  ///
  /// In ar, this message translates to:
  /// **'بلا أيام محددة — لن يظهر في «اليوم».'**
  String get bodyNoDays;

  /// No description provided for @bodyTarget.
  ///
  /// In ar, this message translates to:
  /// **'في كل مرة'**
  String get bodyTarget;

  /// No description provided for @bodySets.
  ///
  /// In ar, this message translates to:
  /// **'المجموعات'**
  String get bodySets;

  /// No description provided for @bodyReps.
  ///
  /// In ar, this message translates to:
  /// **'التكرارات'**
  String get bodyReps;

  /// No description provided for @bodyWeight.
  ///
  /// In ar, this message translates to:
  /// **'الوزن'**
  String get bodyWeight;

  /// No description provided for @bodyDuration.
  ///
  /// In ar, this message translates to:
  /// **'المدة'**
  String get bodyDuration;

  /// No description provided for @bodyNotes.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات'**
  String get bodyNotes;

  /// No description provided for @bodyNotesHint.
  ///
  /// In ar, this message translates to:
  /// **'مثلًا: ركّز على الوضعية'**
  String get bodyNotesHint;

  /// No description provided for @bodyUnitKg.
  ///
  /// In ar, this message translates to:
  /// **'كغ'**
  String get bodyUnitKg;

  /// No description provided for @bodyUnitMin.
  ///
  /// In ar, this message translates to:
  /// **'دقيقة'**
  String get bodyUnitMin;

  /// No description provided for @bodyUnitMl.
  ///
  /// In ar, this message translates to:
  /// **'مل'**
  String get bodyUnitMl;

  /// No description provided for @bodyUnitHours.
  ///
  /// In ar, this message translates to:
  /// **'ساعة'**
  String get bodyUnitHours;

  /// No description provided for @bodyStepperDecrease.
  ///
  /// In ar, this message translates to:
  /// **'إنقاص {label}'**
  String bodyStepperDecrease(String label);

  /// No description provided for @bodyStepperIncrease.
  ///
  /// In ar, this message translates to:
  /// **'زيادة {label}'**
  String bodyStepperIncrease(String label);

  /// No description provided for @bodyNotSet.
  ///
  /// In ar, this message translates to:
  /// **'—'**
  String get bodyNotSet;

  /// No description provided for @bodyExerciseHistory.
  ///
  /// In ar, this message translates to:
  /// **'السجل والتقدّم'**
  String get bodyExerciseHistory;

  /// No description provided for @bodyPause.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف مؤقت'**
  String get bodyPause;

  /// No description provided for @bodyResume.
  ///
  /// In ar, this message translates to:
  /// **'استئناف'**
  String get bodyResume;

  /// No description provided for @bodyPaused.
  ///
  /// In ar, this message translates to:
  /// **'متوقف مؤقتًا'**
  String get bodyPaused;

  /// No description provided for @bodyCopyName.
  ///
  /// In ar, this message translates to:
  /// **'{name} (نسخة)'**
  String bodyCopyName(String name);

  /// No description provided for @bodyDeletedName.
  ///
  /// In ar, this message translates to:
  /// **'حُذف «{name}»'**
  String bodyDeletedName(String name);

  /// No description provided for @bodyDuplicatedName.
  ///
  /// In ar, this message translates to:
  /// **'نُسخ «{name}»'**
  String bodyDuplicatedName(String name);

  /// No description provided for @bodyPausedName.
  ///
  /// In ar, this message translates to:
  /// **'أُوقف «{name}» مؤقتًا'**
  String bodyPausedName(String name);

  /// No description provided for @bodyResumedName.
  ///
  /// In ar, this message translates to:
  /// **'عاد «{name}» إلى الخطة'**
  String bodyResumedName(String name);

  /// No description provided for @bodyLogTitle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل التمرين'**
  String get bodyLogTitle;

  /// No description provided for @bodyLogEditTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعديل السجل'**
  String get bodyLogEditTitle;

  /// No description provided for @bodyLogSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'القيم من خطتك — عدّلها لما أنجزته فعلًا.'**
  String get bodyLogSubtitle;

  /// No description provided for @bodyLogExtraSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'تمرين خارج الخطة؟ سجّله هنا.'**
  String get bodyLogExtraSubtitle;

  /// No description provided for @bodyYesterday.
  ///
  /// In ar, this message translates to:
  /// **'أمس'**
  String get bodyYesterday;

  /// No description provided for @bodyLogWhen.
  ///
  /// In ar, this message translates to:
  /// **'متى'**
  String get bodyLogWhen;

  /// No description provided for @bodyLogSave.
  ///
  /// In ar, this message translates to:
  /// **'سجّل'**
  String get bodyLogSave;

  /// No description provided for @bodyWorkoutName.
  ///
  /// In ar, this message translates to:
  /// **'التمرين'**
  String get bodyWorkoutName;

  /// No description provided for @bodyWorkoutNameHint.
  ///
  /// In ar, this message translates to:
  /// **'مثلًا: سباحة'**
  String get bodyWorkoutNameHint;

  /// No description provided for @bodyLogVolume.
  ///
  /// In ar, this message translates to:
  /// **'الحجم: {value}'**
  String bodyLogVolume(String value);

  /// No description provided for @bodyHistoryEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا سجلات بعد. عندما تنجز هذا التمرين يظهر تقدّمك هنا.'**
  String get bodyHistoryEmpty;

  /// No description provided for @bodyHistoryOneDay.
  ///
  /// In ar, this message translates to:
  /// **'يظهر المنحنى بعد يومين من السجلات.'**
  String get bodyHistoryOneDay;

  /// No description provided for @bodyMetricWeight.
  ///
  /// In ar, this message translates to:
  /// **'الوزن'**
  String get bodyMetricWeight;

  /// No description provided for @bodyMetricVolume.
  ///
  /// In ar, this message translates to:
  /// **'الحجم'**
  String get bodyMetricVolume;

  /// No description provided for @bodyMetricReps.
  ///
  /// In ar, this message translates to:
  /// **'التكرارات'**
  String get bodyMetricReps;

  /// No description provided for @bodyMetricMinutes.
  ///
  /// In ar, this message translates to:
  /// **'الدقائق'**
  String get bodyMetricMinutes;

  /// No description provided for @bodyBest.
  ///
  /// In ar, this message translates to:
  /// **'الأفضل'**
  String get bodyBest;

  /// No description provided for @bodyChange.
  ///
  /// In ar, this message translates to:
  /// **'التغيّر'**
  String get bodyChange;

  /// No description provided for @bodySessions.
  ///
  /// In ar, this message translates to:
  /// **'الجلسات'**
  String get bodySessions;

  /// No description provided for @bodyVolumeHint.
  ///
  /// In ar, this message translates to:
  /// **'الحجم = المجموعات × التكرارات × الوزن'**
  String get bodyVolumeHint;

  /// No description provided for @bodyLogs.
  ///
  /// In ar, this message translates to:
  /// **'السجلات'**
  String get bodyLogs;

  /// No description provided for @bodyLogDeleted.
  ///
  /// In ar, this message translates to:
  /// **'حُذف السجل'**
  String get bodyLogDeleted;

  /// No description provided for @bodyLogUpdated.
  ///
  /// In ar, this message translates to:
  /// **'حُدّث السجل'**
  String get bodyLogUpdated;

  /// No description provided for @bodyFastingTitle.
  ///
  /// In ar, this message translates to:
  /// **'الصيام المتقطّع'**
  String get bodyFastingTitle;

  /// No description provided for @bodyFastPhaseFasting.
  ///
  /// In ar, this message translates to:
  /// **'صائم'**
  String get bodyFastPhaseFasting;

  /// No description provided for @bodyFastPhaseEating.
  ///
  /// In ar, this message translates to:
  /// **'نافذة الأكل'**
  String get bodyFastPhaseEating;

  /// No description provided for @bodyFastPhaseWaiting.
  ///
  /// In ar, this message translates to:
  /// **'خارج الصيام'**
  String get bodyFastPhaseWaiting;

  /// No description provided for @bodyFastRemaining.
  ///
  /// In ar, this message translates to:
  /// **'بقي {time}'**
  String bodyFastRemaining(String time);

  /// No description provided for @bodyFastGoalAt.
  ///
  /// In ar, this message translates to:
  /// **'الهدف {time}'**
  String bodyFastGoalAt(String time);

  /// No description provided for @bodyFastReached.
  ///
  /// In ar, this message translates to:
  /// **'بلغت هدفك!'**
  String get bodyFastReached;

  /// No description provided for @bodyFastOvertime.
  ///
  /// In ar, this message translates to:
  /// **'{time} فوق الهدف'**
  String bodyFastOvertime(String time);

  /// No description provided for @bodyFastTimeNow.
  ///
  /// In ar, this message translates to:
  /// **'حان وقت صيامك'**
  String get bodyFastTimeNow;

  /// No description provided for @bodyEatingOpenSince.
  ///
  /// In ar, this message translates to:
  /// **'مفتوحة منذ {time}'**
  String bodyEatingOpenSince(String time);

  /// No description provided for @bodyEatingClosesAt.
  ///
  /// In ar, this message translates to:
  /// **'آخر وجبة {time}'**
  String bodyEatingClosesAt(String time);

  /// No description provided for @bodyNextFastAt.
  ///
  /// In ar, this message translates to:
  /// **'الصيام القادم {time}'**
  String bodyNextFastAt(String time);

  /// No description provided for @bodyWindowOpensAt.
  ///
  /// In ar, this message translates to:
  /// **'تُفتح نافذة الأكل {time}'**
  String bodyWindowOpensAt(String time);

  /// No description provided for @bodyStartFast.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ الصيام'**
  String get bodyStartFast;

  /// No description provided for @bodyEndFast.
  ///
  /// In ar, this message translates to:
  /// **'أنهِ الصيام'**
  String get bodyEndFast;

  /// No description provided for @bodyStartedEarlier.
  ///
  /// In ar, this message translates to:
  /// **'بدأت قبل الآن؟'**
  String get bodyStartedEarlier;

  /// No description provided for @bodyFastStartTitle.
  ///
  /// In ar, this message translates to:
  /// **'متى بدأ صيامك؟'**
  String get bodyFastStartTitle;

  /// No description provided for @bodyFastStarted.
  ///
  /// In ar, this message translates to:
  /// **'بدأ صيامك — بالتوفيق'**
  String get bodyFastStarted;

  /// No description provided for @bodyFastEnded.
  ///
  /// In ar, this message translates to:
  /// **'انتهى صيامك: {duration}'**
  String bodyFastEnded(String duration);

  /// No description provided for @bodyFastPlan.
  ///
  /// In ar, this message translates to:
  /// **'خطة الصيام'**
  String get bodyFastPlan;

  /// No description provided for @bodyFastHours.
  ///
  /// In ar, this message translates to:
  /// **'ساعات الصيام'**
  String get bodyFastHours;

  /// No description provided for @bodyFastCustom.
  ///
  /// In ar, this message translates to:
  /// **'مخصّص'**
  String get bodyFastCustom;

  /// No description provided for @bodyFastCustomTitle.
  ///
  /// In ar, this message translates to:
  /// **'ساعات صيام مخصّصة'**
  String get bodyFastCustomTitle;

  /// No description provided for @bodyFastCustomHint.
  ///
  /// In ar, this message translates to:
  /// **'من ساعة إلى ٧٢ ساعة'**
  String get bodyFastCustomHint;

  /// No description provided for @bodyFastRatioHint.
  ///
  /// In ar, this message translates to:
  /// **'صيام {fast} س، ثم نافذة أكل {eat} س'**
  String bodyFastRatioHint(String fast, String eat);

  /// No description provided for @bodyFastLongHint.
  ///
  /// In ar, this message translates to:
  /// **'صيام {fast} ساعة، بلا نافذة أكل يومية'**
  String bodyFastLongHint(String fast);

  /// No description provided for @bodyLastMeal.
  ///
  /// In ar, this message translates to:
  /// **'آخر وجبة'**
  String get bodyLastMeal;

  /// No description provided for @bodyLastMealHint.
  ///
  /// In ar, this message translates to:
  /// **'يبدأ صيامك المخطط عندها.'**
  String get bodyLastMealHint;

  /// No description provided for @bodyNotifyGoal.
  ///
  /// In ar, this message translates to:
  /// **'نبّهني عند بلوغ الهدف'**
  String get bodyNotifyGoal;

  /// No description provided for @bodyNotifyEating.
  ///
  /// In ar, this message translates to:
  /// **'ذكّرني قبل إغلاق نافذة الأكل'**
  String get bodyNotifyEating;

  /// No description provided for @bodyLeadBefore.
  ///
  /// In ar, this message translates to:
  /// **'قبلها بـ{n} د'**
  String bodyLeadBefore(String n);

  /// No description provided for @bodyLeadAtTime.
  ///
  /// In ar, this message translates to:
  /// **'في وقتها'**
  String get bodyLeadAtTime;

  /// No description provided for @bodyStatStreak.
  ///
  /// In ar, this message translates to:
  /// **'السلسلة'**
  String get bodyStatStreak;

  /// No description provided for @bodyStatLongest.
  ///
  /// In ar, this message translates to:
  /// **'الأطول'**
  String get bodyStatLongest;

  /// No description provided for @bodyStatAverage.
  ///
  /// In ar, this message translates to:
  /// **'المتوسط'**
  String get bodyStatAverage;

  /// No description provided for @bodyStatCompleted.
  ///
  /// In ar, this message translates to:
  /// **'بلغت الهدف'**
  String get bodyStatCompleted;

  /// No description provided for @bodyFastHistory.
  ///
  /// In ar, this message translates to:
  /// **'سجل الصيام'**
  String get bodyFastHistory;

  /// No description provided for @bodyFastHistoryEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا صيام مسجّل بعد. اضغط «ابدأ الصيام» بعد آخر وجبة.'**
  String get bodyFastHistoryEmpty;

  /// No description provided for @bodyFastGoalBadge.
  ///
  /// In ar, this message translates to:
  /// **'الهدف {hours} س'**
  String bodyFastGoalBadge(String hours);

  /// No description provided for @bodyFastEditTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الصيام'**
  String get bodyFastEditTitle;

  /// No description provided for @bodyFastStartDate.
  ///
  /// In ar, this message translates to:
  /// **'يوم البدء'**
  String get bodyFastStartDate;

  /// No description provided for @bodyFastStartTime.
  ///
  /// In ar, this message translates to:
  /// **'وقت البدء'**
  String get bodyFastStartTime;

  /// No description provided for @bodyFastEndDate.
  ///
  /// In ar, this message translates to:
  /// **'يوم الانتهاء'**
  String get bodyFastEndDate;

  /// No description provided for @bodyFastEndTime.
  ///
  /// In ar, this message translates to:
  /// **'وقت الانتهاء'**
  String get bodyFastEndTime;

  /// No description provided for @bodyFastGoalHours.
  ///
  /// In ar, this message translates to:
  /// **'الهدف'**
  String get bodyFastGoalHours;

  /// No description provided for @bodyFastNote.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة'**
  String get bodyFastNote;

  /// No description provided for @bodyFastNoteHint.
  ///
  /// In ar, this message translates to:
  /// **'مثلًا: صيام رمضان، صيام تطوّع'**
  String get bodyFastNoteHint;

  /// No description provided for @bodyFastEndBeforeStart.
  ///
  /// In ar, this message translates to:
  /// **'الانتهاء قبل البدء'**
  String get bodyFastEndBeforeStart;

  /// No description provided for @bodyFastInFuture.
  ///
  /// In ar, this message translates to:
  /// **'هذا الوقت لم يأتِ بعد'**
  String get bodyFastInFuture;

  /// No description provided for @bodyFastDeleted.
  ///
  /// In ar, this message translates to:
  /// **'حُذف الصيام'**
  String get bodyFastDeleted;

  /// No description provided for @bodyFastUpdated.
  ///
  /// In ar, this message translates to:
  /// **'حُدّث الصيام'**
  String get bodyFastUpdated;

  /// No description provided for @bodyFastRingSemantics.
  ///
  /// In ar, this message translates to:
  /// **'{phase}: {detail}'**
  String bodyFastRingSemantics(String phase, String detail);

  /// No description provided for @bodyWaterTitle.
  ///
  /// In ar, this message translates to:
  /// **'الماء'**
  String get bodyWaterTitle;

  /// No description provided for @bodyWaterOf.
  ///
  /// In ar, this message translates to:
  /// **'من {target}'**
  String bodyWaterOf(String target);

  /// No description provided for @bodyAddAmount.
  ///
  /// In ar, this message translates to:
  /// **'+{amount}'**
  String bodyAddAmount(String amount);

  /// No description provided for @bodyAddWaterSemantics.
  ///
  /// In ar, this message translates to:
  /// **'أضف {amount}'**
  String bodyAddWaterSemantics(String amount);

  /// No description provided for @bodyWaterCustom.
  ///
  /// In ar, this message translates to:
  /// **'كمية أخرى'**
  String get bodyWaterCustom;

  /// No description provided for @bodyWaterCustomTitle.
  ///
  /// In ar, this message translates to:
  /// **'كم شربت؟'**
  String get bodyWaterCustomTitle;

  /// No description provided for @bodyWaterAmount.
  ///
  /// In ar, this message translates to:
  /// **'الكمية'**
  String get bodyWaterAmount;

  /// No description provided for @bodyWaterTarget.
  ///
  /// In ar, this message translates to:
  /// **'الهدف اليومي'**
  String get bodyWaterTarget;

  /// No description provided for @bodyWaterTargetTitle.
  ///
  /// In ar, this message translates to:
  /// **'هدف الماء اليومي'**
  String get bodyWaterTargetTitle;

  /// No description provided for @bodyWaterTargetSaved.
  ///
  /// In ar, this message translates to:
  /// **'الهدف الآن {amount}'**
  String bodyWaterTargetSaved(String amount);

  /// No description provided for @bodyWaterGoalMet.
  ///
  /// In ar, this message translates to:
  /// **'بلغت هدف اليوم!'**
  String get bodyWaterGoalMet;

  /// No description provided for @bodyWaterLeft.
  ///
  /// In ar, this message translates to:
  /// **'بقي {amount}'**
  String bodyWaterLeft(String amount);

  /// No description provided for @bodyWaterWeek.
  ///
  /// In ar, this message translates to:
  /// **'الأسبوع الأخير'**
  String get bodyWaterWeek;

  /// No description provided for @bodyWaterAverage.
  ///
  /// In ar, this message translates to:
  /// **'المتوسط {amount}'**
  String bodyWaterAverage(String amount);

  /// No description provided for @bodyWaterToday.
  ///
  /// In ar, this message translates to:
  /// **'سجل اليوم'**
  String get bodyWaterToday;

  /// No description provided for @bodyWaterEmptyToday.
  ///
  /// In ar, this message translates to:
  /// **'لم تسجّل ماءً اليوم بعد — كوب واحد بداية جيدة.'**
  String get bodyWaterEmptyToday;

  /// No description provided for @bodyWaterAdded.
  ///
  /// In ar, this message translates to:
  /// **'أُضيف {amount}'**
  String bodyWaterAdded(String amount);

  /// No description provided for @bodyWaterRemoved.
  ///
  /// In ar, this message translates to:
  /// **'حُذف {amount}'**
  String bodyWaterRemoved(String amount);

  /// No description provided for @bodyWaterEditTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الكمية'**
  String get bodyWaterEditTitle;

  /// No description provided for @bodyWaterUpdated.
  ///
  /// In ar, this message translates to:
  /// **'حُدّثت الكمية'**
  String get bodyWaterUpdated;

  /// No description provided for @bodyAvoidTitle.
  ///
  /// In ar, this message translates to:
  /// **'قائمة التجنّب'**
  String get bodyAvoidTitle;

  /// No description provided for @bodyAvoidSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'حركات وأطعمة اخترت أن تبتعد عنها، مع أسبابك أنت.'**
  String get bodyAvoidSubtitle;

  /// No description provided for @bodyAvoidAdd.
  ///
  /// In ar, this message translates to:
  /// **'أضف إلى القائمة'**
  String get bodyAvoidAdd;

  /// No description provided for @bodyAvoidEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل البند'**
  String get bodyAvoidEdit;

  /// No description provided for @bodyAvoidWhat.
  ///
  /// In ar, this message translates to:
  /// **'ماذا تتجنّب؟'**
  String get bodyAvoidWhat;

  /// No description provided for @bodyAvoidWhatHint.
  ///
  /// In ar, this message translates to:
  /// **'مثلًا: رفع الأثقال فوق الرأس'**
  String get bodyAvoidWhatHint;

  /// No description provided for @bodyAvoidReason.
  ///
  /// In ar, this message translates to:
  /// **'السبب'**
  String get bodyAvoidReason;

  /// No description provided for @bodyAvoidReasonHint.
  ///
  /// In ar, this message translates to:
  /// **'مثلًا: بحسب نصيحة المختص'**
  String get bodyAvoidReasonHint;

  /// No description provided for @bodyAvoidEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'القائمة فارغة'**
  String get bodyAvoidEmptyTitle;

  /// No description provided for @bodyAvoidEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'دوّن ما تريد تجنّبه ولماذا — مثلًا: المشروبات الغازية، أو القرفصاء العميقة.'**
  String get bodyAvoidEmptyBody;

  /// No description provided for @bodyAvoidRemoved.
  ///
  /// In ar, this message translates to:
  /// **'حُذف من القائمة'**
  String get bodyAvoidRemoved;

  /// No description provided for @bodyAvoidNoReason.
  ///
  /// In ar, this message translates to:
  /// **'بلا سبب مكتوب'**
  String get bodyAvoidNoReason;

  /// No description provided for @bodyCardTitle.
  ///
  /// In ar, this message translates to:
  /// **'الجسد اليوم'**
  String get bodyCardTitle;

  /// No description provided for @bodyCardTraining.
  ///
  /// In ar, this message translates to:
  /// **'التمرين'**
  String get bodyCardTraining;

  /// No description provided for @bodyCardFasting.
  ///
  /// In ar, this message translates to:
  /// **'الصيام'**
  String get bodyCardFasting;

  /// No description provided for @bodyCardWater.
  ///
  /// In ar, this message translates to:
  /// **'الماء'**
  String get bodyCardWater;

  /// No description provided for @bodyNotifyGroup.
  ///
  /// In ar, this message translates to:
  /// **'الجسد'**
  String get bodyNotifyGroup;

  /// No description provided for @bodyNotifyChannel.
  ///
  /// In ar, this message translates to:
  /// **'تنبيهات الصيام'**
  String get bodyNotifyChannel;

  /// No description provided for @bodyNotifyChannelDescription.
  ///
  /// In ar, this message translates to:
  /// **'بلوغ هدف الصيام واقتراب إغلاق نافذة الأكل'**
  String get bodyNotifyChannelDescription;

  /// No description provided for @bodyNotifyGoalTitle.
  ///
  /// In ar, this message translates to:
  /// **'بلغت هدف صيامك'**
  String get bodyNotifyGoalTitle;

  /// No description provided for @bodyNotifyGoalBody.
  ///
  /// In ar, this message translates to:
  /// **'أتممت هدف صيامك ({hours} س) — أحسنت.'**
  String bodyNotifyGoalBody(String hours);

  /// No description provided for @bodyNotifyEatingTitle.
  ///
  /// In ar, this message translates to:
  /// **'نافذة الأكل تُغلق قريبًا'**
  String get bodyNotifyEatingTitle;

  /// No description provided for @bodyNotifyEatingBody.
  ///
  /// In ar, this message translates to:
  /// **'آخر وجبة عند {time}.'**
  String bodyNotifyEatingBody(String time);

  /// No description provided for @bodyNotifyHint.
  ///
  /// In ar, this message translates to:
  /// **'يحتاج إذن الإشعارات على الهاتف.'**
  String get bodyNotifyHint;

  /// Custom modules screen title
  ///
  /// In ar, this message translates to:
  /// **'متتبّعات وقوائم'**
  String get cmodTitle;

  /// No description provided for @cmodNewModule.
  ///
  /// In ar, this message translates to:
  /// **'وحدة جديدة'**
  String get cmodNewModule;

  /// No description provided for @cmodModulesCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا وحدات بعد} =1{وحدة واحدة} =2{وحدتان} few{{count} وحدات} many{{count} وحدة} other{{count} وحدة}}'**
  String cmodModulesCount(int count);

  /// No description provided for @cmodLoggedToday.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لم تسجّل شيئًا اليوم بعد} =1{إدخال واحد اليوم} =2{إدخالان اليوم} few{{count} إدخالات اليوم} many{{count} إدخالًا اليوم} other{{count} إدخال اليوم}}'**
  String cmodLoggedToday(int count);

  /// No description provided for @cmodEntriesCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا إدخالات} =1{إدخال واحد} =2{إدخالان} few{{count} إدخالات} many{{count} إدخالًا} other{{count} إدخال}}'**
  String cmodEntriesCount(int count);

  /// No description provided for @cmodItemsCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا عناصر} =1{عنصر واحد} =2{عنصران} few{{count} عناصر} many{{count} عنصرًا} other{{count} عنصر}}'**
  String cmodItemsCount(int count);

  /// No description provided for @cmodItemsProgress.
  ///
  /// In ar, this message translates to:
  /// **'{done} من {total} منجز'**
  String cmodItemsProgress(String done, String total);

  /// No description provided for @cmodOpenItems.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا شيء متبقٍّ} =1{عنصر واحد متبقٍّ} =2{عنصران متبقيان} few{{count} عناصر متبقية} many{{count} عنصرًا متبقيًا} other{{count} عنصر متبقٍّ}}'**
  String cmodOpenItems(int count);

  /// No description provided for @cmodEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'اصنع متتبّعك الأول'**
  String get cmodEmptyTitle;

  /// No description provided for @cmodEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'تتبّع ما يهمّك بحقولك أنت: سجلّ قراءة، أذكار بعد الصلاة، قائمة عادات… ويظهر كل ذلك في كواكبك.'**
  String get cmodEmptyBody;

  /// No description provided for @cmodEmptyAction.
  ///
  /// In ar, this message translates to:
  /// **'أنشئ وحدة'**
  String get cmodEmptyAction;

  /// No description provided for @cmodArchivedSection.
  ///
  /// In ar, this message translates to:
  /// **'المؤرشفة'**
  String get cmodArchivedSection;

  /// No description provided for @cmodKindTracker.
  ///
  /// In ar, this message translates to:
  /// **'متتبّع'**
  String get cmodKindTracker;

  /// No description provided for @cmodKindList.
  ///
  /// In ar, this message translates to:
  /// **'قائمة'**
  String get cmodKindList;

  /// No description provided for @cmodKindTrackerHint.
  ///
  /// In ar, this message translates to:
  /// **'قيم تسجّلها مع الأيام، برسوم بيانية'**
  String get cmodKindTrackerHint;

  /// No description provided for @cmodKindListHint.
  ///
  /// In ar, this message translates to:
  /// **'عناصر تشطبها وترتّبها'**
  String get cmodKindListHint;

  /// No description provided for @cmodLastToday.
  ///
  /// In ar, this message translates to:
  /// **'آخر إدخال اليوم'**
  String get cmodLastToday;

  /// No description provided for @cmodLastYesterday.
  ///
  /// In ar, this message translates to:
  /// **'آخر إدخال أمس'**
  String get cmodLastYesterday;

  /// No description provided for @cmodLastDaysAgo.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{آخر إدخال قبل يوم} =2{آخر إدخال قبل يومين} few{آخر إدخال قبل {count} أيام} many{آخر إدخال قبل {count} يومًا} other{آخر إدخال قبل {count} يوم}}'**
  String cmodLastDaysAgo(int count);

  /// No description provided for @cmodNoEntries.
  ///
  /// In ar, this message translates to:
  /// **'لا إدخالات بعد'**
  String get cmodNoEntries;

  /// No description provided for @cmodStreakBadge.
  ///
  /// In ar, this message translates to:
  /// **'سلسلة {count}'**
  String cmodStreakBadge(String count);

  /// No description provided for @cmodActionArchive.
  ///
  /// In ar, this message translates to:
  /// **'أرشفة'**
  String get cmodActionArchive;

  /// No description provided for @cmodActionUnarchive.
  ///
  /// In ar, this message translates to:
  /// **'إعادة من الأرشيف'**
  String get cmodActionUnarchive;

  /// No description provided for @cmodActionAddEntry.
  ///
  /// In ar, this message translates to:
  /// **'إدخال جديد'**
  String get cmodActionAddEntry;

  /// No description provided for @cmodActionOpen.
  ///
  /// In ar, this message translates to:
  /// **'فتح'**
  String get cmodActionOpen;

  /// No description provided for @cmodActionExport.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة كملف CSV'**
  String get cmodActionExport;

  /// No description provided for @cmodActionUncheck.
  ///
  /// In ar, this message translates to:
  /// **'إعادة فتح'**
  String get cmodActionUncheck;

  /// No description provided for @cmodActionCheck.
  ///
  /// In ar, this message translates to:
  /// **'إنجاز'**
  String get cmodActionCheck;

  /// No description provided for @cmodToastArchived.
  ///
  /// In ar, this message translates to:
  /// **'أُرشفت «{name}»'**
  String cmodToastArchived(String name);

  /// No description provided for @cmodToastUnarchived.
  ///
  /// In ar, this message translates to:
  /// **'عادت «{name}» من الأرشيف'**
  String cmodToastUnarchived(String name);

  /// No description provided for @cmodToastDeleted.
  ///
  /// In ar, this message translates to:
  /// **'حُذفت «{name}»'**
  String cmodToastDeleted(String name);

  /// No description provided for @cmodToastDuplicated.
  ///
  /// In ar, this message translates to:
  /// **'نُسخت «{name}»'**
  String cmodToastDuplicated(String name);

  /// No description provided for @cmodToastLogged.
  ///
  /// In ar, this message translates to:
  /// **'سُجّل في «{name}»'**
  String cmodToastLogged(String name);

  /// No description provided for @cmodToastUnchecked.
  ///
  /// In ar, this message translates to:
  /// **'أُلغي تسجيل اليوم'**
  String get cmodToastUnchecked;

  /// No description provided for @cmodToastEntryDeleted.
  ///
  /// In ar, this message translates to:
  /// **'حُذف الإدخال'**
  String get cmodToastEntryDeleted;

  /// No description provided for @cmodToastEntryDuplicated.
  ///
  /// In ar, this message translates to:
  /// **'نُسخ الإدخال'**
  String get cmodToastEntryDuplicated;

  /// No description provided for @cmodToastItemDone.
  ///
  /// In ar, this message translates to:
  /// **'أُنجز العنصر'**
  String get cmodToastItemDone;

  /// No description provided for @cmodToastItemReopened.
  ///
  /// In ar, this message translates to:
  /// **'أُعيد فتح العنصر'**
  String get cmodToastItemReopened;

  /// No description provided for @cmodToastCleared.
  ///
  /// In ar, this message translates to:
  /// **'مُسحت العناصر المنجزة'**
  String get cmodToastCleared;

  /// No description provided for @cmodToastSaved.
  ///
  /// In ar, this message translates to:
  /// **'حُفظت «{name}»'**
  String cmodToastSaved(String name);

  /// No description provided for @cmodToastReminderDeleted.
  ///
  /// In ar, this message translates to:
  /// **'حُذف التذكير'**
  String get cmodToastReminderDeleted;

  /// No description provided for @cmodToastReminderAdded.
  ///
  /// In ar, this message translates to:
  /// **'أُضيف التذكير'**
  String get cmodToastReminderAdded;

  /// No description provided for @cmodQuickDone.
  ///
  /// In ar, this message translates to:
  /// **'تمّ اليوم'**
  String get cmodQuickDone;

  /// No description provided for @cmodQuickDoneHint.
  ///
  /// In ar, this message translates to:
  /// **'سجّل إنجاز اليوم بلمسة'**
  String get cmodQuickDoneHint;

  /// No description provided for @cmodQuickChecked.
  ///
  /// In ar, this message translates to:
  /// **'أُنجز اليوم'**
  String get cmodQuickChecked;

  /// No description provided for @cmodQuickCheckedHint.
  ///
  /// In ar, this message translates to:
  /// **'المس لإلغاء تسجيل اليوم'**
  String get cmodQuickCheckedHint;

  /// No description provided for @cmodQuickAddOne.
  ///
  /// In ar, this message translates to:
  /// **'سجّل مرّة'**
  String get cmodQuickAddOne;

  /// No description provided for @cmodQuickRate.
  ///
  /// In ar, this message translates to:
  /// **'قيّم اليوم'**
  String get cmodQuickRate;

  /// No description provided for @cmodRateStars.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{نجمة واحدة} =2{نجمتان} few{{count} نجوم} many{{count} نجمة} other{{count} نجمة}}'**
  String cmodRateStars(int count);

  /// No description provided for @cmodBuilderNewTitle.
  ///
  /// In ar, this message translates to:
  /// **'وحدة جديدة'**
  String get cmodBuilderNewTitle;

  /// No description provided for @cmodBuilderEditTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الوحدة'**
  String get cmodBuilderEditTitle;

  /// No description provided for @cmodSectionBasics.
  ///
  /// In ar, this message translates to:
  /// **'الأساسيات'**
  String get cmodSectionBasics;

  /// No description provided for @cmodName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get cmodName;

  /// No description provided for @cmodNameHint.
  ///
  /// In ar, this message translates to:
  /// **'مثال: سجلّ القراءة'**
  String get cmodNameHint;

  /// No description provided for @cmodKind.
  ///
  /// In ar, this message translates to:
  /// **'النوع'**
  String get cmodKind;

  /// No description provided for @cmodIcon.
  ///
  /// In ar, this message translates to:
  /// **'الأيقونة'**
  String get cmodIcon;

  /// No description provided for @cmodColor.
  ///
  /// In ar, this message translates to:
  /// **'اللون'**
  String get cmodColor;

  /// No description provided for @cmodPlanet.
  ///
  /// In ar, this message translates to:
  /// **'الكوكب'**
  String get cmodPlanet;

  /// No description provided for @cmodPlanetNone.
  ///
  /// In ar, this message translates to:
  /// **'بلا كوكب'**
  String get cmodPlanetNone;

  /// No description provided for @cmodPlanetHint.
  ///
  /// In ar, this message translates to:
  /// **'كل إدخال يُنعش هذا الكوكب في المدار، ويدور حوله قمرًا'**
  String get cmodPlanetHint;

  /// No description provided for @cmodWindow.
  ///
  /// In ar, this message translates to:
  /// **'وقت الصلاة'**
  String get cmodWindow;

  /// No description provided for @cmodWindowHint.
  ///
  /// In ar, this message translates to:
  /// **'متى تتوقّع أن تسجّل عادةً'**
  String get cmodWindowHint;

  /// No description provided for @cmodSectionFields.
  ///
  /// In ar, this message translates to:
  /// **'الحقول'**
  String get cmodSectionFields;

  /// No description provided for @cmodAddField.
  ///
  /// In ar, this message translates to:
  /// **'أضف حقلًا'**
  String get cmodAddField;

  /// No description provided for @cmodFieldsEmptyTracker.
  ///
  /// In ar, this message translates to:
  /// **'بلا حقول يصبح المتتبّع عدّادًا بلمسة واحدة'**
  String get cmodFieldsEmptyTracker;

  /// No description provided for @cmodFieldsEmptyList.
  ///
  /// In ar, this message translates to:
  /// **'أضف حقلًا واحدًا على الأقل، كاسم العنصر'**
  String get cmodFieldsEmptyList;

  /// No description provided for @cmodHiddenFields.
  ///
  /// In ar, this message translates to:
  /// **'حقول مخفية'**
  String get cmodHiddenFields;

  /// No description provided for @cmodHiddenFieldsHint.
  ///
  /// In ar, this message translates to:
  /// **'أُزيلت من النموذج، وبياناتها القديمة محفوظة'**
  String get cmodHiddenFieldsHint;

  /// No description provided for @cmodRestoreField.
  ///
  /// In ar, this message translates to:
  /// **'إظهار'**
  String get cmodRestoreField;

  /// No description provided for @cmodSectionChart.
  ///
  /// In ar, this message translates to:
  /// **'الرسم البياني'**
  String get cmodSectionChart;

  /// No description provided for @cmodChartField.
  ///
  /// In ar, this message translates to:
  /// **'ما يُرسم'**
  String get cmodChartField;

  /// No description provided for @cmodChartEntries.
  ///
  /// In ar, this message translates to:
  /// **'عدد الإدخالات'**
  String get cmodChartEntries;

  /// No description provided for @cmodChartStyle.
  ///
  /// In ar, this message translates to:
  /// **'الشكل'**
  String get cmodChartStyle;

  /// No description provided for @cmodChartRange.
  ///
  /// In ar, this message translates to:
  /// **'المدة'**
  String get cmodChartRange;

  /// No description provided for @cmodChartLine.
  ///
  /// In ar, this message translates to:
  /// **'خط'**
  String get cmodChartLine;

  /// No description provided for @cmodChartBar.
  ///
  /// In ar, this message translates to:
  /// **'أعمدة'**
  String get cmodChartBar;

  /// No description provided for @cmodChartHeat.
  ///
  /// In ar, this message translates to:
  /// **'تقويم'**
  String get cmodChartHeat;

  /// No description provided for @cmodChartStreak.
  ///
  /// In ar, this message translates to:
  /// **'سلسلة'**
  String get cmodChartStreak;

  /// No description provided for @cmodChartEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا بيانات في هذه المدة بعد'**
  String get cmodChartEmpty;

  /// No description provided for @cmodRangeDays.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{يوم} =2{يومان} few{{count} أيام} many{{count} يومًا} other{{count} يوم}}'**
  String cmodRangeDays(int count);

  /// No description provided for @cmodSave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get cmodSave;

  /// No description provided for @cmodCreate.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء'**
  String get cmodCreate;

  /// No description provided for @cmodCancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cmodCancel;

  /// No description provided for @cmodDiscardTitle.
  ///
  /// In ar, this message translates to:
  /// **'تجاهل التغييرات؟'**
  String get cmodDiscardTitle;

  /// No description provided for @cmodDiscardBody.
  ///
  /// In ar, this message translates to:
  /// **'لم تُحفظ تعديلاتك على هذه الوحدة.'**
  String get cmodDiscardBody;

  /// No description provided for @cmodDiscard.
  ///
  /// In ar, this message translates to:
  /// **'تجاهل'**
  String get cmodDiscard;

  /// No description provided for @cmodKeepEditing.
  ///
  /// In ar, this message translates to:
  /// **'متابعة التعديل'**
  String get cmodKeepEditing;

  /// No description provided for @cmodPreviewUntitled.
  ///
  /// In ar, this message translates to:
  /// **'وحدة بلا اسم'**
  String get cmodPreviewUntitled;

  /// No description provided for @cmodIssueNameMissing.
  ///
  /// In ar, this message translates to:
  /// **'اكتب اسمًا للوحدة'**
  String get cmodIssueNameMissing;

  /// No description provided for @cmodIssueNameTooLong.
  ///
  /// In ar, this message translates to:
  /// **'الاسم طويل جدًا'**
  String get cmodIssueNameTooLong;

  /// No description provided for @cmodIssueNoFields.
  ///
  /// In ar, this message translates to:
  /// **'أضف حقلًا واحدًا على الأقل'**
  String get cmodIssueNoFields;

  /// No description provided for @cmodIssueTooManyFields.
  ///
  /// In ar, this message translates to:
  /// **'الحد الأقصى {max} حقلًا'**
  String cmodIssueTooManyFields(String max);

  /// No description provided for @cmodIssueLabelMissing.
  ///
  /// In ar, this message translates to:
  /// **'حقل بلا اسم'**
  String get cmodIssueLabelMissing;

  /// No description provided for @cmodIssueLabelDuplicate.
  ///
  /// In ar, this message translates to:
  /// **'اسم الحقل مكرّر'**
  String get cmodIssueLabelDuplicate;

  /// No description provided for @cmodIssueNoOptions.
  ///
  /// In ar, this message translates to:
  /// **'أضف خيارًا واحدًا على الأقل'**
  String get cmodIssueNoOptions;

  /// No description provided for @cmodIssueOptionLabelMissing.
  ///
  /// In ar, this message translates to:
  /// **'خيار بلا اسم'**
  String get cmodIssueOptionLabelMissing;

  /// No description provided for @cmodIssueOptionDuplicate.
  ///
  /// In ar, this message translates to:
  /// **'خيار مكرّر'**
  String get cmodIssueOptionDuplicate;

  /// No description provided for @cmodIssueRangeInverted.
  ///
  /// In ar, this message translates to:
  /// **'الحد الأدنى أكبر من الأعلى'**
  String get cmodIssueRangeInverted;

  /// No description provided for @cmodIssueCurrencyCode.
  ///
  /// In ar, this message translates to:
  /// **'رمز العملة غير صالح'**
  String get cmodIssueCurrencyCode;

  /// No description provided for @cmodMigrationTitle.
  ///
  /// In ar, this message translates to:
  /// **'قبل الحفظ'**
  String get cmodMigrationTitle;

  /// No description provided for @cmodMigrationBlockedTitle.
  ///
  /// In ar, this message translates to:
  /// **'هذا التغيير سيضيّع بيانات'**
  String get cmodMigrationBlockedTitle;

  /// No description provided for @cmodMigrationBlockedBody.
  ///
  /// In ar, this message translates to:
  /// **'لم يُحفظ شيء. أعد النوع كما كان، أو أضف حقلًا جديدًا بالنوع الذي تريده.'**
  String get cmodMigrationBlockedBody;

  /// No description provided for @cmodMigrationOk.
  ///
  /// In ar, this message translates to:
  /// **'حسنًا'**
  String get cmodMigrationOk;

  /// No description provided for @cmodMigTypeBlocked.
  ///
  /// In ar, this message translates to:
  /// **'«{field}»: {entries} لا تصلح بنوع «{type}»'**
  String cmodMigTypeBlocked(String field, String entries, String type);

  /// No description provided for @cmodMigRatingBlocked.
  ///
  /// In ar, this message translates to:
  /// **'«{field}»: {entries} فيها نجوم أكثر من المقياس الجديد'**
  String cmodMigRatingBlocked(String field, String entries);

  /// No description provided for @cmodMigFieldHidden.
  ///
  /// In ar, this message translates to:
  /// **'«{field}» سيُخفى، وتبقى قيمه في {entries}'**
  String cmodMigFieldHidden(String field, String entries);

  /// No description provided for @cmodMigOptionHidden.
  ///
  /// In ar, this message translates to:
  /// **'الخيارات المحذوفة من «{field}» والمستخدمة ستُخفى ولن تُحذف'**
  String cmodMigOptionHidden(String field);

  /// No description provided for @cmodMigConverted.
  ///
  /// In ar, this message translates to:
  /// **'قيم «{field}» في {entries} ستتحوّل إلى «{type}»'**
  String cmodMigConverted(String field, String entries, String type);

  /// No description provided for @cmodMigOutOfRange.
  ///
  /// In ar, this message translates to:
  /// **'{entries} في «{field}» خارج الحدود الجديدة وستبقى كما هي'**
  String cmodMigOutOfRange(String field, String entries);

  /// No description provided for @cmodMigNewlyRequired.
  ///
  /// In ar, this message translates to:
  /// **'{entries} بلا قيمة لـ«{field}» الذي صار مطلوبًا'**
  String cmodMigNewlyRequired(String field, String entries);

  /// No description provided for @cmodTypeText.
  ///
  /// In ar, this message translates to:
  /// **'نص'**
  String get cmodTypeText;

  /// No description provided for @cmodTypeNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم'**
  String get cmodTypeNumber;

  /// No description provided for @cmodTypeDate.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ'**
  String get cmodTypeDate;

  /// No description provided for @cmodTypeTime.
  ///
  /// In ar, this message translates to:
  /// **'وقت'**
  String get cmodTypeTime;

  /// No description provided for @cmodTypeCheckbox.
  ///
  /// In ar, this message translates to:
  /// **'خانة إنجاز'**
  String get cmodTypeCheckbox;

  /// No description provided for @cmodTypeSingle.
  ///
  /// In ar, this message translates to:
  /// **'اختيار واحد'**
  String get cmodTypeSingle;

  /// No description provided for @cmodTypeMulti.
  ///
  /// In ar, this message translates to:
  /// **'اختيارات متعددة'**
  String get cmodTypeMulti;

  /// No description provided for @cmodTypeRating.
  ///
  /// In ar, this message translates to:
  /// **'تقييم بالنجوم'**
  String get cmodTypeRating;

  /// No description provided for @cmodTypeCurrency.
  ///
  /// In ar, this message translates to:
  /// **'مبلغ'**
  String get cmodTypeCurrency;

  /// No description provided for @cmodTypeTextHint.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة، عنوان كتاب…'**
  String get cmodTypeTextHint;

  /// No description provided for @cmodTypeNumberHint.
  ///
  /// In ar, this message translates to:
  /// **'صفحات، دقائق، مرّات…'**
  String get cmodTypeNumberHint;

  /// No description provided for @cmodTypeDateHint.
  ///
  /// In ar, this message translates to:
  /// **'موعد أو مناسبة'**
  String get cmodTypeDateHint;

  /// No description provided for @cmodTypeTimeHint.
  ///
  /// In ar, this message translates to:
  /// **'وقت النوم، وقت البدء…'**
  String get cmodTypeTimeHint;

  /// No description provided for @cmodTypeCheckboxHint.
  ///
  /// In ar, this message translates to:
  /// **'تمّ أو لم يتمّ'**
  String get cmodTypeCheckboxHint;

  /// No description provided for @cmodTypeSingleHint.
  ///
  /// In ar, this message translates to:
  /// **'خيار واحد من قائمتك'**
  String get cmodTypeSingleHint;

  /// No description provided for @cmodTypeMultiHint.
  ///
  /// In ar, this message translates to:
  /// **'عدّة خيارات من قائمتك'**
  String get cmodTypeMultiHint;

  /// No description provided for @cmodTypeRatingHint.
  ///
  /// In ar, this message translates to:
  /// **'من نجمتين إلى عشر'**
  String get cmodTypeRatingHint;

  /// No description provided for @cmodTypeCurrencyHint.
  ///
  /// In ar, this message translates to:
  /// **'مبلغ بعملة تختارها'**
  String get cmodTypeCurrencyHint;

  /// No description provided for @cmodPickType.
  ///
  /// In ar, this message translates to:
  /// **'نوع الحقل'**
  String get cmodPickType;

  /// No description provided for @cmodFieldNew.
  ///
  /// In ar, this message translates to:
  /// **'حقل جديد'**
  String get cmodFieldNew;

  /// No description provided for @cmodFieldEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الحقل'**
  String get cmodFieldEdit;

  /// No description provided for @cmodFieldLabel.
  ///
  /// In ar, this message translates to:
  /// **'اسم الحقل'**
  String get cmodFieldLabel;

  /// No description provided for @cmodFieldLabelHint.
  ///
  /// In ar, this message translates to:
  /// **'مثال: الصفحات'**
  String get cmodFieldLabelHint;

  /// No description provided for @cmodFieldRequired.
  ///
  /// In ar, this message translates to:
  /// **'مطلوب'**
  String get cmodFieldRequired;

  /// No description provided for @cmodFieldRequiredHint.
  ///
  /// In ar, this message translates to:
  /// **'لا يُحفظ الإدخال دونه'**
  String get cmodFieldRequiredHint;

  /// No description provided for @cmodFieldUnit.
  ///
  /// In ar, this message translates to:
  /// **'الوحدة'**
  String get cmodFieldUnit;

  /// No description provided for @cmodFieldUnitHint.
  ///
  /// In ar, this message translates to:
  /// **'صفحة، دقيقة، كغ…'**
  String get cmodFieldUnitHint;

  /// No description provided for @cmodFieldMin.
  ///
  /// In ar, this message translates to:
  /// **'الحد الأدنى'**
  String get cmodFieldMin;

  /// No description provided for @cmodFieldMax.
  ///
  /// In ar, this message translates to:
  /// **'الحد الأعلى'**
  String get cmodFieldMax;

  /// No description provided for @cmodFieldNoLimit.
  ///
  /// In ar, this message translates to:
  /// **'بلا حد'**
  String get cmodFieldNoLimit;

  /// No description provided for @cmodFieldDecimals.
  ///
  /// In ar, this message translates to:
  /// **'الخانات العشرية'**
  String get cmodFieldDecimals;

  /// No description provided for @cmodFieldScale.
  ///
  /// In ar, this message translates to:
  /// **'المقياس'**
  String get cmodFieldScale;

  /// No description provided for @cmodFieldCurrency.
  ///
  /// In ar, this message translates to:
  /// **'العملة'**
  String get cmodFieldCurrency;

  /// No description provided for @cmodFieldOptions.
  ///
  /// In ar, this message translates to:
  /// **'الخيارات'**
  String get cmodFieldOptions;

  /// No description provided for @cmodAddOption.
  ///
  /// In ar, this message translates to:
  /// **'أضف خيارًا'**
  String get cmodAddOption;

  /// No description provided for @cmodOptionHint.
  ///
  /// In ar, this message translates to:
  /// **'اسم الخيار'**
  String get cmodOptionHint;

  /// No description provided for @cmodRemoveOption.
  ///
  /// In ar, this message translates to:
  /// **'احذف الخيار'**
  String get cmodRemoveOption;

  /// No description provided for @cmodFieldMultiline.
  ///
  /// In ar, this message translates to:
  /// **'نص طويل'**
  String get cmodFieldMultiline;

  /// No description provided for @cmodFieldMultilineHint.
  ///
  /// In ar, this message translates to:
  /// **'يتّسع لعدّة أسطر'**
  String get cmodFieldMultilineHint;

  /// No description provided for @cmodFieldDelete.
  ///
  /// In ar, this message translates to:
  /// **'احذف الحقل'**
  String get cmodFieldDelete;

  /// No description provided for @cmodFieldCopyLabel.
  ///
  /// In ar, this message translates to:
  /// **'{label} (نسخة)'**
  String cmodFieldCopyLabel(String label);

  /// No description provided for @cmodFieldTypeNote.
  ///
  /// In ar, this message translates to:
  /// **'إن غيّرت النوع تتحوّل القيم القديمة حين يمكن ذلك، وإلا لا يُحفظ التغيير.'**
  String get cmodFieldTypeNote;

  /// No description provided for @cmodFieldOptionsCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{بلا خيارات} =1{خيار واحد} =2{خياران} few{{count} خيارات} many{{count} خيارًا} other{{count} خيار}}'**
  String cmodFieldOptionsCount(int count);

  /// No description provided for @cmodFieldRange.
  ///
  /// In ar, this message translates to:
  /// **'{min} – {max}'**
  String cmodFieldRange(String min, String max);

  /// No description provided for @cmodFieldAtLeast.
  ///
  /// In ar, this message translates to:
  /// **'من {min}'**
  String cmodFieldAtLeast(String min);

  /// No description provided for @cmodFieldAtMost.
  ///
  /// In ar, this message translates to:
  /// **'حتى {max}'**
  String cmodFieldAtMost(String max);

  /// No description provided for @cmodFieldDeleted.
  ///
  /// In ar, this message translates to:
  /// **'حُذف «{name}» من النموذج'**
  String cmodFieldDeleted(String name);

  /// No description provided for @cmodFieldDuplicated.
  ///
  /// In ar, this message translates to:
  /// **'نُسخ الحقل'**
  String get cmodFieldDuplicated;

  /// No description provided for @cmodGalleryTitle.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ وحدة'**
  String get cmodGalleryTitle;

  /// No description provided for @cmodGallerySubtitle.
  ///
  /// In ar, this message translates to:
  /// **'من الصفر أو من قالب، وكل شيء قابل للتعديل'**
  String get cmodGallerySubtitle;

  /// No description provided for @cmodBlankTracker.
  ///
  /// In ar, this message translates to:
  /// **'متتبّع فارغ'**
  String get cmodBlankTracker;

  /// No description provided for @cmodBlankList.
  ///
  /// In ar, this message translates to:
  /// **'قائمة فارغة'**
  String get cmodBlankList;

  /// No description provided for @cmodTemplatesHeader.
  ///
  /// In ar, this message translates to:
  /// **'قوالب للبدء'**
  String get cmodTemplatesHeader;

  /// No description provided for @cmodTplReadingLog.
  ///
  /// In ar, this message translates to:
  /// **'سجلّ القراءة'**
  String get cmodTplReadingLog;

  /// No description provided for @cmodTplReadingLogDesc.
  ///
  /// In ar, this message translates to:
  /// **'الكتاب والصفحات وتقييمك'**
  String get cmodTplReadingLogDesc;

  /// No description provided for @cmodTplDhikr.
  ///
  /// In ar, this message translates to:
  /// **'أذكار بعد الصلاة'**
  String get cmodTplDhikr;

  /// No description provided for @cmodTplDhikrDesc.
  ///
  /// In ar, this message translates to:
  /// **'كم مرّة ذكرت الله، وبعد أي صلاة'**
  String get cmodTplDhikrDesc;

  /// No description provided for @cmodTplHabit.
  ///
  /// In ar, this message translates to:
  /// **'عادة يومية'**
  String get cmodTplHabit;

  /// No description provided for @cmodTplHabitDesc.
  ///
  /// In ar, this message translates to:
  /// **'لمسة واحدة كل يوم، وسلسلة تكبر'**
  String get cmodTplHabitDesc;

  /// No description provided for @cmodTplHabitList.
  ///
  /// In ar, this message translates to:
  /// **'قائمة عادات'**
  String get cmodTplHabitList;

  /// No description provided for @cmodTplHabitListDesc.
  ///
  /// In ar, this message translates to:
  /// **'عادات تريد بناءها وكم تتكرّر'**
  String get cmodTplHabitListDesc;

  /// No description provided for @cmodTplSleep.
  ///
  /// In ar, this message translates to:
  /// **'سجلّ النوم'**
  String get cmodTplSleep;

  /// No description provided for @cmodTplSleepDesc.
  ///
  /// In ar, this message translates to:
  /// **'النوم والاستيقاظ والساعات والجودة'**
  String get cmodTplSleepDesc;

  /// No description provided for @cmodTplGifts.
  ///
  /// In ar, this message translates to:
  /// **'أفكار هدايا'**
  String get cmodTplGifts;

  /// No description provided for @cmodTplGiftsDesc.
  ///
  /// In ar, this message translates to:
  /// **'الفكرة ولمن والميزانية والمناسبة'**
  String get cmodTplGiftsDesc;

  /// No description provided for @cmodTplBook.
  ///
  /// In ar, this message translates to:
  /// **'الكتاب'**
  String get cmodTplBook;

  /// No description provided for @cmodTplPages.
  ///
  /// In ar, this message translates to:
  /// **'الصفحات'**
  String get cmodTplPages;

  /// No description provided for @cmodTplRating.
  ///
  /// In ar, this message translates to:
  /// **'التقييم'**
  String get cmodTplRating;

  /// No description provided for @cmodTplUnitPages.
  ///
  /// In ar, this message translates to:
  /// **'صفحة'**
  String get cmodTplUnitPages;

  /// No description provided for @cmodTplAfterPrayer.
  ///
  /// In ar, this message translates to:
  /// **'بعد صلاة'**
  String get cmodTplAfterPrayer;

  /// No description provided for @cmodTplCount.
  ///
  /// In ar, this message translates to:
  /// **'العدد'**
  String get cmodTplCount;

  /// No description provided for @cmodTplUnitTimes.
  ///
  /// In ar, this message translates to:
  /// **'مرّة'**
  String get cmodTplUnitTimes;

  /// No description provided for @cmodTplDone.
  ///
  /// In ar, this message translates to:
  /// **'تمّ'**
  String get cmodTplDone;

  /// No description provided for @cmodTplNote.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة'**
  String get cmodTplNote;

  /// No description provided for @cmodTplHabitItem.
  ///
  /// In ar, this message translates to:
  /// **'العادة'**
  String get cmodTplHabitItem;

  /// No description provided for @cmodTplFrequency.
  ///
  /// In ar, this message translates to:
  /// **'التكرار'**
  String get cmodTplFrequency;

  /// No description provided for @cmodTplDaily.
  ///
  /// In ar, this message translates to:
  /// **'يوميًا'**
  String get cmodTplDaily;

  /// No description provided for @cmodTplWeekly.
  ///
  /// In ar, this message translates to:
  /// **'أسبوعيًا'**
  String get cmodTplWeekly;

  /// No description provided for @cmodTplMonthly.
  ///
  /// In ar, this message translates to:
  /// **'شهريًا'**
  String get cmodTplMonthly;

  /// No description provided for @cmodTplBedtime.
  ///
  /// In ar, this message translates to:
  /// **'وقت النوم'**
  String get cmodTplBedtime;

  /// No description provided for @cmodTplWake.
  ///
  /// In ar, this message translates to:
  /// **'وقت الاستيقاظ'**
  String get cmodTplWake;

  /// No description provided for @cmodTplHours.
  ///
  /// In ar, this message translates to:
  /// **'ساعات النوم'**
  String get cmodTplHours;

  /// No description provided for @cmodTplUnitHours.
  ///
  /// In ar, this message translates to:
  /// **'ساعة'**
  String get cmodTplUnitHours;

  /// No description provided for @cmodTplQuality.
  ///
  /// In ar, this message translates to:
  /// **'الجودة'**
  String get cmodTplQuality;

  /// No description provided for @cmodTplIdea.
  ///
  /// In ar, this message translates to:
  /// **'الفكرة'**
  String get cmodTplIdea;

  /// No description provided for @cmodTplFor.
  ///
  /// In ar, this message translates to:
  /// **'لمن'**
  String get cmodTplFor;

  /// No description provided for @cmodTplBudget.
  ///
  /// In ar, this message translates to:
  /// **'الميزانية'**
  String get cmodTplBudget;

  /// No description provided for @cmodTplOccasion.
  ///
  /// In ar, this message translates to:
  /// **'المناسبة'**
  String get cmodTplOccasion;

  /// No description provided for @cmodTplNotes.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات'**
  String get cmodTplNotes;

  /// No description provided for @cmodAddEntry.
  ///
  /// In ar, this message translates to:
  /// **'إدخال جديد'**
  String get cmodAddEntry;

  /// No description provided for @cmodAddItem.
  ///
  /// In ar, this message translates to:
  /// **'عنصر جديد'**
  String get cmodAddItem;

  /// No description provided for @cmodEntriesSection.
  ///
  /// In ar, this message translates to:
  /// **'الإدخالات'**
  String get cmodEntriesSection;

  /// No description provided for @cmodItemsSection.
  ///
  /// In ar, this message translates to:
  /// **'العناصر'**
  String get cmodItemsSection;

  /// No description provided for @cmodDoneSection.
  ///
  /// In ar, this message translates to:
  /// **'المنجزة'**
  String get cmodDoneSection;

  /// No description provided for @cmodClearDone.
  ///
  /// In ar, this message translates to:
  /// **'امسح المنجزة'**
  String get cmodClearDone;

  /// No description provided for @cmodToday.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get cmodToday;

  /// No description provided for @cmodYesterday.
  ///
  /// In ar, this message translates to:
  /// **'أمس'**
  String get cmodYesterday;

  /// No description provided for @cmodEntriesEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا إدخالات بعد. أول إدخال يبدأ الحكاية.'**
  String get cmodEntriesEmpty;

  /// No description provided for @cmodItemsEmpty.
  ///
  /// In ar, this message translates to:
  /// **'القائمة فارغة. أضف أول عنصر.'**
  String get cmodItemsEmpty;

  /// No description provided for @cmodAllDone.
  ///
  /// In ar, this message translates to:
  /// **'أنجزت كل شيء، ما شاء الله'**
  String get cmodAllDone;

  /// No description provided for @cmodStatStreak.
  ///
  /// In ar, this message translates to:
  /// **'السلسلة'**
  String get cmodStatStreak;

  /// No description provided for @cmodStatBest.
  ///
  /// In ar, this message translates to:
  /// **'الأفضل'**
  String get cmodStatBest;

  /// No description provided for @cmodStatTotal.
  ///
  /// In ar, this message translates to:
  /// **'المجموع'**
  String get cmodStatTotal;

  /// No description provided for @cmodStatAverage.
  ///
  /// In ar, this message translates to:
  /// **'المتوسط'**
  String get cmodStatAverage;

  /// No description provided for @cmodStatActive.
  ///
  /// In ar, this message translates to:
  /// **'أيام نشطة'**
  String get cmodStatActive;

  /// No description provided for @cmodStatEntries.
  ///
  /// In ar, this message translates to:
  /// **'الإدخالات'**
  String get cmodStatEntries;

  /// No description provided for @cmodStatRate.
  ///
  /// In ar, this message translates to:
  /// **'نسبة الإنجاز'**
  String get cmodStatRate;

  /// No description provided for @cmodDays.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{٠ يوم} =1{يوم} =2{يومان} few{{count} أيام} many{{count} يومًا} other{{count} يوم}}'**
  String cmodDays(int count);

  /// No description provided for @cmodReminders.
  ///
  /// In ar, this message translates to:
  /// **'التذكيرات'**
  String get cmodReminders;

  /// No description provided for @cmodAddReminder.
  ///
  /// In ar, this message translates to:
  /// **'أضف تذكيرًا'**
  String get cmodAddReminder;

  /// No description provided for @cmodRemindersEmpty.
  ///
  /// In ar, this message translates to:
  /// **'ذكّرني بعد صلاة أو في وقت أحدّده'**
  String get cmodRemindersEmpty;

  /// No description provided for @cmodReminderPaused.
  ///
  /// In ar, this message translates to:
  /// **'متوقّف'**
  String get cmodReminderPaused;

  /// No description provided for @cmodReminderToggle.
  ///
  /// In ar, this message translates to:
  /// **'تشغيل التذكير'**
  String get cmodReminderToggle;

  /// No description provided for @cmodModuleMenu.
  ///
  /// In ar, this message translates to:
  /// **'خيارات الوحدة'**
  String get cmodModuleMenu;

  /// No description provided for @cmodHiddenValue.
  ///
  /// In ar, this message translates to:
  /// **'{label} (مخفي)'**
  String cmodHiddenValue(String label);

  /// No description provided for @cmodNotifyGroup.
  ///
  /// In ar, this message translates to:
  /// **'المتتبّعات والقوائم'**
  String get cmodNotifyGroup;

  /// No description provided for @cmodNotifyChannel.
  ///
  /// In ar, this message translates to:
  /// **'تذكيرات المتتبّعات والقوائم'**
  String get cmodNotifyChannel;

  /// No description provided for @cmodNotifyChannelDescription.
  ///
  /// In ar, this message translates to:
  /// **'تذكيرات لطيفة لتسجيل متتبّعاتك ومراجعة قوائمك'**
  String get cmodNotifyChannelDescription;

  /// No description provided for @cmodNotifyBodyTracker.
  ///
  /// In ar, this message translates to:
  /// **'حان وقت التسجيل'**
  String get cmodNotifyBodyTracker;

  /// No description provided for @cmodNotifyBodyList.
  ///
  /// In ar, this message translates to:
  /// **'ألقِ نظرة على قائمتك'**
  String get cmodNotifyBodyList;

  /// No description provided for @cmodEntryNew.
  ///
  /// In ar, this message translates to:
  /// **'إدخال جديد'**
  String get cmodEntryNew;

  /// No description provided for @cmodEntryEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الإدخال'**
  String get cmodEntryEdit;

  /// No description provided for @cmodItemNew.
  ///
  /// In ar, this message translates to:
  /// **'عنصر جديد'**
  String get cmodItemNew;

  /// No description provided for @cmodItemEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل العنصر'**
  String get cmodItemEdit;

  /// No description provided for @cmodEntryWhen.
  ///
  /// In ar, this message translates to:
  /// **'متى'**
  String get cmodEntryWhen;

  /// No description provided for @cmodEntryDone.
  ///
  /// In ar, this message translates to:
  /// **'منجز'**
  String get cmodEntryDone;

  /// No description provided for @cmodEntryCounter.
  ///
  /// In ar, this message translates to:
  /// **'هذه الوحدة عدّاد: الحفظ يسجّل مرّة واحدة.'**
  String get cmodEntryCounter;

  /// No description provided for @cmodErrRequired.
  ///
  /// In ar, this message translates to:
  /// **'هذا الحقل مطلوب'**
  String get cmodErrRequired;

  /// No description provided for @cmodErrNumber.
  ///
  /// In ar, this message translates to:
  /// **'اكتب رقمًا'**
  String get cmodErrNumber;

  /// No description provided for @cmodErrWhole.
  ///
  /// In ar, this message translates to:
  /// **'رقم صحيح فقط'**
  String get cmodErrWhole;

  /// No description provided for @cmodErrPrecise.
  ///
  /// In ar, this message translates to:
  /// **'{count} خانات عشرية على الأكثر'**
  String cmodErrPrecise(String count);

  /// No description provided for @cmodErrMin.
  ///
  /// In ar, this message translates to:
  /// **'لا يقلّ عن {value}'**
  String cmodErrMin(String value);

  /// No description provided for @cmodErrMax.
  ///
  /// In ar, this message translates to:
  /// **'لا يزيد على {value}'**
  String cmodErrMax(String value);

  /// No description provided for @cmodErrDate.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ غير صالح'**
  String get cmodErrDate;

  /// No description provided for @cmodErrTime.
  ///
  /// In ar, this message translates to:
  /// **'وقت غير صالح'**
  String get cmodErrTime;

  /// No description provided for @cmodErrOption.
  ///
  /// In ar, this message translates to:
  /// **'اختر من القائمة'**
  String get cmodErrOption;

  /// No description provided for @cmodErrScale.
  ///
  /// In ar, this message translates to:
  /// **'خارج المقياس'**
  String get cmodErrScale;

  /// No description provided for @cmodErrTooLong.
  ///
  /// In ar, this message translates to:
  /// **'النص طويل جدًا'**
  String get cmodErrTooLong;

  /// No description provided for @cmodPickDate.
  ///
  /// In ar, this message translates to:
  /// **'اختر تاريخًا'**
  String get cmodPickDate;

  /// No description provided for @cmodPickTime.
  ///
  /// In ar, this message translates to:
  /// **'اختر وقتًا'**
  String get cmodPickTime;

  /// No description provided for @cmodClear.
  ///
  /// In ar, this message translates to:
  /// **'مسح'**
  String get cmodClear;

  /// No description provided for @cmodYes.
  ///
  /// In ar, this message translates to:
  /// **'نعم'**
  String get cmodYes;

  /// No description provided for @cmodNo.
  ///
  /// In ar, this message translates to:
  /// **'لا'**
  String get cmodNo;

  /// No description provided for @cmodChecked.
  ///
  /// In ar, this message translates to:
  /// **'تمّ'**
  String get cmodChecked;

  /// No description provided for @cmodUnchecked.
  ///
  /// In ar, this message translates to:
  /// **'لم يتمّ'**
  String get cmodUnchecked;

  /// No description provided for @cmodCardTitle.
  ///
  /// In ar, this message translates to:
  /// **'متتبّعاتك هنا'**
  String get cmodCardTitle;

  /// No description provided for @cmodCardSeeAll.
  ///
  /// In ar, this message translates to:
  /// **'عرض الكل'**
  String get cmodCardSeeAll;

  /// No description provided for @cmodCardEmpty.
  ///
  /// In ar, this message translates to:
  /// **'أنشئ متتبّعًا لهذا الكوكب'**
  String get cmodCardEmpty;

  /// No description provided for @cmodCardEmptyHint.
  ///
  /// In ar, this message translates to:
  /// **'عدّاد، أو سجلّ، أو قائمة: بحقولك أنت'**
  String get cmodCardEmptyHint;

  /// No description provided for @cmodExportDate.
  ///
  /// In ar, this message translates to:
  /// **'التاريخ'**
  String get cmodExportDate;

  /// No description provided for @cmodExportTime.
  ///
  /// In ar, this message translates to:
  /// **'الوقت'**
  String get cmodExportTime;

  /// No description provided for @cmodExportDone.
  ///
  /// In ar, this message translates to:
  /// **'منجز'**
  String get cmodExportDone;

  /// No description provided for @cmodExportEntries.
  ///
  /// In ar, this message translates to:
  /// **'الإدخالات'**
  String get cmodExportEntries;

  /// No description provided for @cmodExportLastEntry.
  ///
  /// In ar, this message translates to:
  /// **'آخر إدخال'**
  String get cmodExportLastEntry;

  /// No description provided for @cmodExportOpen.
  ///
  /// In ar, this message translates to:
  /// **'متبقٍّ'**
  String get cmodExportOpen;

  /// No description provided for @cmodExportLastDays.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{آخر يوم} =2{آخر يومين} few{آخر {count} أيام} many{آخر {count} يومًا} other{آخر {count} يوم}}'**
  String cmodExportLastDays(int count);

  /// No description provided for @cmodExportActiveDays.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا أيام نشطة} =1{يوم نشط واحد} =2{يومان نشطان} few{{count} أيام نشطة} many{{count} يومًا نشطًا} other{{count} يوم نشط}}'**
  String cmodExportActiveDays(int count);

  /// No description provided for @cmodExportTotal.
  ///
  /// In ar, this message translates to:
  /// **'المجموع {value}'**
  String cmodExportTotal(String value);

  /// No description provided for @cmodExportAverage.
  ///
  /// In ar, this message translates to:
  /// **'المتوسط {value}'**
  String cmodExportAverage(String value);

  /// No description provided for @cmodExportStreak.
  ///
  /// In ar, this message translates to:
  /// **'السلسلة {current} (الأفضل {best})'**
  String cmodExportStreak(String current, String best);

  /// No description provided for @cmodExportHidden.
  ///
  /// In ar, this message translates to:
  /// **'مخفي'**
  String get cmodExportHidden;

  /// Name of the games hub
  ///
  /// In ar, this message translates to:
  /// **'سينما مدار'**
  String get cinemaTitle;

  /// No description provided for @cinemaHallSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'ألعاب أصلية بروح السينما الكلاسيكية'**
  String get cinemaHallSubtitle;

  /// Tier 1 games section
  ///
  /// In ar, this message translates to:
  /// **'الأفلام الطويلة'**
  String get cinemaFeatures;

  /// Tier 2 games section
  ///
  /// In ar, this message translates to:
  /// **'الأفلام القصيرة'**
  String get cinemaShorts;

  /// No description provided for @cinemaComingSoon.
  ///
  /// In ar, this message translates to:
  /// **'قريبًا'**
  String get cinemaComingSoon;

  /// No description provided for @cinemaPlay.
  ///
  /// In ar, this message translates to:
  /// **'إلى العرض'**
  String get cinemaPlay;

  /// No description provided for @cinemaGameViewLabel.
  ///
  /// In ar, this message translates to:
  /// **'شاشة اللعبة'**
  String get cinemaGameViewLabel;

  /// No description provided for @cinemaPause.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف مؤقت'**
  String get cinemaPause;

  /// Pause card title
  ///
  /// In ar, this message translates to:
  /// **'استراحة'**
  String get cinemaIntermission;

  /// No description provided for @cinemaResume.
  ///
  /// In ar, this message translates to:
  /// **'متابعة العرض'**
  String get cinemaResume;

  /// No description provided for @cinemaRestart.
  ///
  /// In ar, this message translates to:
  /// **'من البداية'**
  String get cinemaRestart;

  /// No description provided for @cinemaLeave.
  ///
  /// In ar, this message translates to:
  /// **'مغادرة القاعة'**
  String get cinemaLeave;

  /// No description provided for @cinemaPlayAgain.
  ///
  /// In ar, this message translates to:
  /// **'عرض آخر'**
  String get cinemaPlayAgain;

  /// No description provided for @cinemaTheEnd.
  ///
  /// In ar, this message translates to:
  /// **'النهاية'**
  String get cinemaTheEnd;

  /// Game over card
  ///
  /// In ar, this message translates to:
  /// **'انتهى العرض'**
  String get cinemaGameOver;

  /// No description provided for @cinemaScoreLine.
  ///
  /// In ar, this message translates to:
  /// **'النتيجة: {score}'**
  String cinemaScoreLine(String score);

  /// No description provided for @cinemaBestLine.
  ///
  /// In ar, this message translates to:
  /// **'أفضل نتيجة: {score}'**
  String cinemaBestLine(String score);

  /// No description provided for @cinemaEraSilent.
  ///
  /// In ar, this message translates to:
  /// **'العشرينيات الصامتة'**
  String get cinemaEraSilent;

  /// No description provided for @cinemaEraRubberHose.
  ///
  /// In ar, this message translates to:
  /// **'كرتون الثلاثينيات'**
  String get cinemaEraRubberHose;

  /// No description provided for @cinemaEraNoir.
  ///
  /// In ar, this message translates to:
  /// **'نوار الأربعينيات'**
  String get cinemaEraNoir;

  /// No description provided for @cinemaEraTechnicolor.
  ///
  /// In ar, this message translates to:
  /// **'ألوان الخمسينيات'**
  String get cinemaEraTechnicolor;

  /// No description provided for @cinemaEraGrindhouse.
  ///
  /// In ar, this message translates to:
  /// **'سينما السبعينيات'**
  String get cinemaEraGrindhouse;

  /// No description provided for @cinemaEraVhs.
  ///
  /// In ar, this message translates to:
  /// **'فيديو الثمانينيات'**
  String get cinemaEraVhs;

  /// Engine demo scene
  ///
  /// In ar, this message translates to:
  /// **'بروفة'**
  String get cinemaDemoTitle;

  /// No description provided for @cinemaDemoTagline.
  ///
  /// In ar, this message translates to:
  /// **'مشهد تجريبي لمحرّك بكرة الفيلم'**
  String get cinemaDemoTagline;

  /// No description provided for @cinemaDemoOpening.
  ///
  /// In ar, this message translates to:
  /// **'المشهد الأول'**
  String get cinemaDemoOpening;

  /// No description provided for @cinemaDemoOpeningSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'المس الشاشة لتقفز فوق البراميل!'**
  String get cinemaDemoOpeningSubtitle;

  /// No description provided for @cinemaFlappyOrbitTitle.
  ///
  /// In ar, this message translates to:
  /// **'رفرفة المدار'**
  String get cinemaFlappyOrbitTitle;

  /// No description provided for @cinemaFlappyOrbitTagline.
  ///
  /// In ar, this message translates to:
  /// **'رفرف بين الكواكب على أنغام السوينغ'**
  String get cinemaFlappyOrbitTagline;

  /// No description provided for @cinemaFlappyOrbitHomage.
  ///
  /// In ar, this message translates to:
  /// **'تحية لرسوم الخرطوم المطاطي في الثلاثينيات'**
  String get cinemaFlappyOrbitHomage;

  /// No description provided for @cinemaMetropolisTitle.
  ///
  /// In ar, this message translates to:
  /// **'آلة المتروبوليس'**
  String get cinemaMetropolisTitle;

  /// No description provided for @cinemaMetropolisTagline.
  ///
  /// In ar, this message translates to:
  /// **'واجه الآلات العملاقة واحدة تلو الأخرى'**
  String get cinemaMetropolisTagline;

  /// No description provided for @cinemaMetropolisHomage.
  ///
  /// In ar, this message translates to:
  /// **'تحية لفيلم «متروبوليس» الصامت من العشرينيات'**
  String get cinemaMetropolisHomage;

  /// No description provided for @cinemaCaravanTitle.
  ///
  /// In ar, this message translates to:
  /// **'سباق القافلة'**
  String get cinemaCaravanTitle;

  /// No description provided for @cinemaCaravanTagline.
  ///
  /// In ar, this message translates to:
  /// **'اعبر الكثبان بألوان التكنيكولور'**
  String get cinemaCaravanTagline;

  /// No description provided for @cinemaCaravanHomage.
  ///
  /// In ar, this message translates to:
  /// **'تحية لملاحم الصحراء في الخمسينيات'**
  String get cinemaCaravanHomage;

  /// No description provided for @cinemaNoirTitle.
  ///
  /// In ar, this message translates to:
  /// **'أسطح النوار'**
  String get cinemaNoirTitle;

  /// No description provided for @cinemaNoirTagline.
  ///
  /// In ar, this message translates to:
  /// **'طارد الظلال فوق أسطح المدينة الممطرة'**
  String get cinemaNoirTagline;

  /// No description provided for @cinemaNoirHomage.
  ///
  /// In ar, this message translates to:
  /// **'تحية لأفلام النوار في الأربعينيات'**
  String get cinemaNoirHomage;

  /// No description provided for @cinemaNeonSoukTitle.
  ///
  /// In ar, this message translates to:
  /// **'متسابق سوق النيون'**
  String get cinemaNeonSoukTitle;

  /// No description provided for @cinemaNeonSoukTagline.
  ///
  /// In ar, this message translates to:
  /// **'انطلق عبر سوق من أضواء النيون'**
  String get cinemaNeonSoukTagline;

  /// No description provided for @cinemaNeonSoukHomage.
  ///
  /// In ar, this message translates to:
  /// **'تحية لأفلام الخيال العلمي على أشرطة الفيديو'**
  String get cinemaNeonSoukHomage;

  /// No description provided for @cinemaSavedGames.
  ///
  /// In ar, this message translates to:
  /// **'ألعابي المحفوظة'**
  String get cinemaSavedGames;

  /// No description provided for @cinemaSavedGamesEmpty.
  ///
  /// In ar, this message translates to:
  /// **'أضف لعبة ويب برابطها لتلعبها هنا بملء الشاشة.'**
  String get cinemaSavedGamesEmpty;

  /// No description provided for @cinemaSavedGamesNote.
  ///
  /// In ar, this message translates to:
  /// **'تُفتح الألعاب من رابطها الأصلي، ولا يُنسخ شيء منها داخل التطبيق.'**
  String get cinemaSavedGamesNote;

  /// No description provided for @cinemaAddGame.
  ///
  /// In ar, this message translates to:
  /// **'إضافة لعبة'**
  String get cinemaAddGame;

  /// No description provided for @cinemaGameName.
  ///
  /// In ar, this message translates to:
  /// **'اسم اللعبة'**
  String get cinemaGameName;

  /// No description provided for @cinemaGameUrl.
  ///
  /// In ar, this message translates to:
  /// **'رابط اللعبة'**
  String get cinemaGameUrl;

  /// No description provided for @cinemaInvalidUrl.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رابطًا صحيحًا يبدأ بـ https://'**
  String get cinemaInvalidUrl;

  /// No description provided for @cinemaRemoveGame.
  ///
  /// In ar, this message translates to:
  /// **'إزالة'**
  String get cinemaRemoveGame;

  /// No description provided for @cinemaOpenGameFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح الرابط'**
  String get cinemaOpenGameFailed;

  /// No description provided for @cinemaSave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get cinemaSave;

  /// No description provided for @cinemaCancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cinemaCancel;

  /// Projector check card that shows the film look of an era
  ///
  /// In ar, this message translates to:
  /// **'بطاقة المعايرة'**
  String get cinemaFxTestCard;

  /// Setting: strength and quality of the old-film effect in Madar Cinema
  ///
  /// In ar, this message translates to:
  /// **'مظهر الفيلم'**
  String get cinemaFxFilmLook;

  /// Film look quality: cheapest
  ///
  /// In ar, this message translates to:
  /// **'توفير الطاقة'**
  String get cinemaFxQualityLowPower;

  /// Film look quality: default
  ///
  /// In ar, this message translates to:
  /// **'متوازن'**
  String get cinemaFxQualityBalanced;

  /// Film look quality: best
  ///
  /// In ar, this message translates to:
  /// **'أعلى دقة'**
  String get cinemaFxQualityFull;

  /// Label on a film-leader card before a reel number
  ///
  /// In ar, this message translates to:
  /// **'بكرة'**
  String get cinemaFxReelLabel;

  /// Heading of the list of original Madar Cinema characters
  ///
  /// In ar, this message translates to:
  /// **'طاقم التمثيل'**
  String get cinemaRigCast;

  /// Name of the star-bird hero of Flappy Orbit (means 'little star')
  ///
  /// In ar, this message translates to:
  /// **'نُجيم'**
  String get cinemaRigNujaym;

  /// No description provided for @cinemaRigNujaymRole.
  ///
  /// In ar, this message translates to:
  /// **'طائر النجمة الشجاع، بطل «رفرفة المدار»'**
  String get cinemaRigNujaymRole;

  /// Name of the clockwork boss of Metropolis Machine (zunbruk = mainspring)
  ///
  /// In ar, this message translates to:
  /// **'البارون زُنبُرك'**
  String get cinemaRigZunbruk;

  /// No description provided for @cinemaRigZunbrukRole.
  ///
  /// In ar, this message translates to:
  /// **'رئيس العمّال الآلي في «آلة المتروبوليس»'**
  String get cinemaRigZunbrukRole;

  /// Name of the camel courier of Caravan Dash (means 'messenger')
  ///
  /// In ar, this message translates to:
  /// **'زاجل'**
  String get cinemaRigZajil;

  /// No description provided for @cinemaRigZajilRole.
  ///
  /// In ar, this message translates to:
  /// **'الجمل ساعي البريد في «سباق القافلة»'**
  String get cinemaRigZajilRole;

  /// Name of the detective cat of Noir Rooftops
  ///
  /// In ar, this message translates to:
  /// **'المفتش مِشمِش'**
  String get cinemaRigMishmish;

  /// No description provided for @cinemaRigMishmishRole.
  ///
  /// In ar, this message translates to:
  /// **'القط المحقق ذو المعطف في «أسطح النوار»'**
  String get cinemaRigMishmishRole;

  /// Name of the hover-bike rider of Neon Souk Racer (means 'mirage')
  ///
  /// In ar, this message translates to:
  /// **'سراب'**
  String get cinemaRigSarab;

  /// No description provided for @cinemaRigSarabRole.
  ///
  /// In ar, this message translates to:
  /// **'راكبة الدراجة الطائرة في «متسابق سوق النيون»'**
  String get cinemaRigSarabRole;

  /// Name of the bean-shaped hero of the engine demo
  ///
  /// In ar, this message translates to:
  /// **'حبّة'**
  String get cinemaRigBean;

  /// No description provided for @cinemaRigBeanRole.
  ///
  /// In ar, this message translates to:
  /// **'نجم البروفة، حبّة فاصولياء بقفازين أبيضين'**
  String get cinemaRigBeanRole;

  /// Data centre screen title
  ///
  /// In ar, this message translates to:
  /// **'بياناتك'**
  String get dataCentreTitle;

  /// No description provided for @dataHeroTitle.
  ///
  /// In ar, this message translates to:
  /// **'بياناتك تبقى معك'**
  String get dataHeroTitle;

  /// No description provided for @dataHeroBody.
  ///
  /// In ar, this message translates to:
  /// **'يحفظ مَدار كل شيء مشفّرًا على هذا الهاتف، ولا يرفع شيئًا إلى أي مكان. لا يغادر ملفٌّ التطبيقَ إلا حين تشاركه أو تحفظه بنفسك.'**
  String get dataHeroBody;

  /// No description provided for @dataStatRecords.
  ///
  /// In ar, this message translates to:
  /// **'السجلات'**
  String get dataStatRecords;

  /// No description provided for @dataStatLastBackup.
  ///
  /// In ar, this message translates to:
  /// **'آخر نسخة احتياطية'**
  String get dataStatLastBackup;

  /// No description provided for @dataLastBackupNever.
  ///
  /// In ar, this message translates to:
  /// **'لم تُنشأ بعد'**
  String get dataLastBackupNever;

  /// No description provided for @dataLastBackupToday.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get dataLastBackupToday;

  /// No description provided for @dataLastBackupDaysAgo.
  ///
  /// In ar, this message translates to:
  /// **'{days, plural, =1{أمس} =2{قبل يومين} few{قبل {days} أيام} many{قبل {days} يومًا} other{قبل {days} يوم}}'**
  String dataLastBackupDaysAgo(int days);

  /// No description provided for @dataBackupSection.
  ///
  /// In ar, this message translates to:
  /// **'النسخ الاحتياطي'**
  String get dataBackupSection;

  /// No description provided for @dataBackupSectionHint.
  ///
  /// In ar, this message translates to:
  /// **'ملف واحد مشفّر لنقل بياناتك أو حفظها بأمان'**
  String get dataBackupSectionHint;

  /// No description provided for @dataBackupCreateTitle.
  ///
  /// In ar, this message translates to:
  /// **'نسخة احتياطية مشفّرة'**
  String get dataBackupCreateTitle;

  /// No description provided for @dataBackupCreateBody.
  ///
  /// In ar, this message translates to:
  /// **'ملف واحد يُقفَل بعبارة مرور لا يعرفها أحد غيرك. احتفظ به في مكان آمن لتنقل بياناتك إلى هاتف جديد.'**
  String get dataBackupCreateBody;

  /// No description provided for @dataBackupCreateAction.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء نسخة احتياطية'**
  String get dataBackupCreateAction;

  /// No description provided for @dataRestoreTitle.
  ///
  /// In ar, this message translates to:
  /// **'الاستعادة من نسخة احتياطية'**
  String get dataRestoreTitle;

  /// No description provided for @dataRestoreBody.
  ///
  /// In ar, this message translates to:
  /// **'تستبدل كل ما في مَدار بمحتوى ملف النسخة. نحفظ أولًا نسخة أمان من بياناتك الحالية على الهاتف.'**
  String get dataRestoreBody;

  /// No description provided for @dataRestoreAction.
  ///
  /// In ar, this message translates to:
  /// **'اختيار ملف النسخة'**
  String get dataRestoreAction;

  /// No description provided for @dataSafetyCopiesLine.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{نسخة أمان واحدة على الهاتف} =2{نسختا أمان على الهاتف} few{{count} نسخ أمان على الهاتف} many{{count} نسخة أمان على الهاتف} other{{count} نسخة أمان على الهاتف}} · آخرها {date}'**
  String dataSafetyCopiesLine(int count, String date);

  /// No description provided for @dataExportSection.
  ///
  /// In ar, this message translates to:
  /// **'التصدير'**
  String get dataExportSection;

  /// No description provided for @dataExportSectionHint.
  ///
  /// In ar, this message translates to:
  /// **'نسخ مقروءة لبياناتك – غير مشفّرة'**
  String get dataExportSectionHint;

  /// No description provided for @dataExportSummaryTitle.
  ///
  /// In ar, this message translates to:
  /// **'ملخّص جاهز للذكاء الاصطناعي'**
  String get dataExportSummaryTitle;

  /// No description provided for @dataExportSummaryBody.
  ///
  /// In ar, this message translates to:
  /// **'نظرة موجزة بصيغة Markdown تراجعها قسمًا قسمًا قبل مشاركتها.'**
  String get dataExportSummaryBody;

  /// No description provided for @dataExportCsvTitle.
  ///
  /// In ar, this message translates to:
  /// **'جداول (CSV)'**
  String get dataExportCsvTitle;

  /// No description provided for @dataExportCsvBody.
  ///
  /// In ar, this message translates to:
  /// **'التحاليل والمعاملات والألم والمزاج، لتفتحها في برامج الجداول.'**
  String get dataExportCsvBody;

  /// No description provided for @dataExportJsonTitle.
  ///
  /// In ar, this message translates to:
  /// **'كل البيانات (JSON)'**
  String get dataExportJsonTitle;

  /// No description provided for @dataExportJsonBody.
  ///
  /// In ar, this message translates to:
  /// **'كل السجلات في ملف واحد، لأرشيفك الخاص أو لتطبيقات أخرى.'**
  String get dataExportJsonBody;

  /// No description provided for @dataExportPlainWarning.
  ///
  /// In ar, this message translates to:
  /// **'ملفات التصدير غير مشفّرة: من يحصل عليها يستطيع قراءتها. شاركها مع من تثق به فقط.'**
  String get dataExportPlainWarning;

  /// No description provided for @dataImportSection.
  ///
  /// In ar, this message translates to:
  /// **'الاستيراد'**
  String get dataImportSection;

  /// No description provided for @dataImportTitle.
  ///
  /// In ar, this message translates to:
  /// **'الاستيراد من نموذج مَدار الأول'**
  String get dataImportTitle;

  /// No description provided for @dataImportBody.
  ///
  /// In ar, this message translates to:
  /// **'أدخل البيانات التي صدّرتها من النسخة الأولى من مَدار.'**
  String get dataImportBody;

  /// No description provided for @dataFooter.
  ///
  /// In ar, this message translates to:
  /// **'لا يرفع مَدار بياناتك إلى أي خادم. أنت وحدك تقرّر أين تذهب ملفاتك.'**
  String get dataFooter;

  /// No description provided for @dataAreaOther.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات والسجلّ'**
  String get dataAreaOther;

  /// No description provided for @dataShareAction.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة'**
  String get dataShareAction;

  /// No description provided for @dataSaveAction.
  ///
  /// In ar, this message translates to:
  /// **'حفظ في…'**
  String get dataSaveAction;

  /// No description provided for @dataCopyAction.
  ///
  /// In ar, this message translates to:
  /// **'نسخ'**
  String get dataCopyAction;

  /// No description provided for @dataDoneAction.
  ///
  /// In ar, this message translates to:
  /// **'تم'**
  String get dataDoneAction;

  /// No description provided for @dataCancelAction.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get dataCancelAction;

  /// No description provided for @dataTryAgainAction.
  ///
  /// In ar, this message translates to:
  /// **'حاول مجددًا'**
  String get dataTryAgainAction;

  /// No description provided for @dataFileReadyTitle.
  ///
  /// In ar, this message translates to:
  /// **'ملفّك جاهز'**
  String get dataFileReadyTitle;

  /// No description provided for @dataFileReadySubtitle.
  ///
  /// In ar, this message translates to:
  /// **'اختر أين يذهب – لا شيء يُرسَل تلقائيًا'**
  String get dataFileReadySubtitle;

  /// No description provided for @dataFileEncryptedNote.
  ///
  /// In ar, this message translates to:
  /// **'مشفّر بعبارة المرور. لا يُفتح إلا بها – احتفظ بها بعيدًا عن الملف.'**
  String get dataFileEncryptedNote;

  /// No description provided for @dataFilePlainNote.
  ///
  /// In ar, this message translates to:
  /// **'غير مشفّر: من يحصل على هذا الملف يستطيع قراءته.'**
  String get dataFilePlainNote;

  /// No description provided for @dataFileShared.
  ///
  /// In ar, this message translates to:
  /// **'أُرسل إلى قائمة المشاركة.'**
  String get dataFileShared;

  /// No description provided for @dataFileSaved.
  ///
  /// In ar, this message translates to:
  /// **'حُفظ في المكان الذي اخترته.'**
  String get dataFileSaved;

  /// No description provided for @dataFileSendFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر ذلك. لم يُرسَل شيء – حاول مجددًا.'**
  String get dataFileSendFailed;

  /// No description provided for @dataExportFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تجهيز الملف. بياناتك لم تتغيّر.'**
  String get dataExportFailed;

  /// No description provided for @dataRecordsCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا سجلات} =1{سجل واحد} =2{سجلّان} few{{count} سجلات} many{{count} سجلًّا} other{{count} سجل}}'**
  String dataRecordsCount(int count);

  /// No description provided for @dataSizeBytes.
  ///
  /// In ar, this message translates to:
  /// **'{size} بايت'**
  String dataSizeBytes(String size);

  /// No description provided for @dataSizeKb.
  ///
  /// In ar, this message translates to:
  /// **'{size} ك.ب'**
  String dataSizeKb(String size);

  /// No description provided for @dataSizeMb.
  ///
  /// In ar, this message translates to:
  /// **'{size} م.ب'**
  String dataSizeMb(String size);

  /// No description provided for @dataBackupSheetTitle.
  ///
  /// In ar, this message translates to:
  /// **'نسخة احتياطية مشفّرة'**
  String get dataBackupSheetTitle;

  /// No description provided for @dataBackupSheetSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'AES-256 · تُشتقّ المفاتيح بـArgon2id على هاتفك'**
  String get dataBackupSheetSubtitle;

  /// No description provided for @dataBackupSheetBody.
  ///
  /// In ar, this message translates to:
  /// **'اختر عبارة مرور تقفل ملف النسخة. لا يحفظها مَدار ولا يستطيع استرجاعها، فاكتبها في مكان تثق به.'**
  String get dataBackupSheetBody;

  /// No description provided for @dataPassphraseLabel.
  ///
  /// In ar, this message translates to:
  /// **'عبارة المرور'**
  String get dataPassphraseLabel;

  /// No description provided for @dataPassphraseConfirmLabel.
  ///
  /// In ar, this message translates to:
  /// **'أعد كتابة عبارة المرور'**
  String get dataPassphraseConfirmLabel;

  /// No description provided for @dataPassphraseMismatch.
  ///
  /// In ar, this message translates to:
  /// **'العبارتان غير متطابقتين.'**
  String get dataPassphraseMismatch;

  /// No description provided for @dataPassphraseShow.
  ///
  /// In ar, this message translates to:
  /// **'إظهار عبارة المرور'**
  String get dataPassphraseShow;

  /// No description provided for @dataPassphraseHide.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء عبارة المرور'**
  String get dataPassphraseHide;

  /// No description provided for @dataPassphraseNeverStored.
  ///
  /// In ar, this message translates to:
  /// **'لا تُحفظ عبارة المرور في أي مكان. بدونها لا يمكن فتح النسخة – ولا حتى بواسطتنا.'**
  String get dataPassphraseNeverStored;

  /// No description provided for @dataStrengthLabel.
  ///
  /// In ar, this message translates to:
  /// **'القوة'**
  String get dataStrengthLabel;

  /// No description provided for @dataStrengthEmpty.
  ///
  /// In ar, this message translates to:
  /// **'—'**
  String get dataStrengthEmpty;

  /// No description provided for @dataStrengthVeryWeak.
  ///
  /// In ar, this message translates to:
  /// **'ضعيفة جدًا'**
  String get dataStrengthVeryWeak;

  /// No description provided for @dataStrengthWeak.
  ///
  /// In ar, this message translates to:
  /// **'ضعيفة'**
  String get dataStrengthWeak;

  /// No description provided for @dataStrengthFair.
  ///
  /// In ar, this message translates to:
  /// **'مقبولة'**
  String get dataStrengthFair;

  /// No description provided for @dataStrengthStrong.
  ///
  /// In ar, this message translates to:
  /// **'قوية'**
  String get dataStrengthStrong;

  /// No description provided for @dataStrengthVeryStrong.
  ///
  /// In ar, this message translates to:
  /// **'قوية جدًا'**
  String get dataStrengthVeryStrong;

  /// No description provided for @dataStrengthHintShort.
  ///
  /// In ar, this message translates to:
  /// **'استخدم {min} أحرف على الأقل – جملة قصيرة تفي بالغرض.'**
  String dataStrengthHintShort(String min);

  /// No description provided for @dataStrengthHintCommon.
  ///
  /// In ar, this message translates to:
  /// **'هذه عبارة شائعة يسهل تخمينها.'**
  String get dataStrengthHintCommon;

  /// No description provided for @dataStrengthHintPattern.
  ///
  /// In ar, this message translates to:
  /// **'تجنّب التكرار والتسلسلات مثل 1234 أو aaaa.'**
  String get dataStrengthHintPattern;

  /// No description provided for @dataStrengthHintDigits.
  ///
  /// In ar, this message translates to:
  /// **'الأرقام وحدها سهلة التخمين؛ أضف كلمات.'**
  String get dataStrengthHintDigits;

  /// No description provided for @dataStrengthHintWords.
  ///
  /// In ar, this message translates to:
  /// **'جيدة. كلمة أو كلمتان إضافيتان تجعلانها أقوى بكثير.'**
  String get dataStrengthHintWords;

  /// No description provided for @dataBackupWorking.
  ///
  /// In ar, this message translates to:
  /// **'نقفل بياناتك…'**
  String get dataBackupWorking;

  /// No description provided for @dataBackupWorkingHint.
  ///
  /// In ar, this message translates to:
  /// **'يستغرق هذا بضع ثوانٍ عن قصد، ليصعب تخمين عبارة المرور.'**
  String get dataBackupWorkingHint;

  /// No description provided for @dataBackupReadyTitle.
  ///
  /// In ar, this message translates to:
  /// **'النسخة الاحتياطية جاهزة'**
  String get dataBackupReadyTitle;

  /// No description provided for @dataBackupReadySubtitle.
  ///
  /// In ar, this message translates to:
  /// **'شاركها أو احفظها في مكان آمن'**
  String get dataBackupReadySubtitle;

  /// No description provided for @dataBackupReadyHint.
  ///
  /// In ar, this message translates to:
  /// **'احفظ الملف وعبارة المرور في مكانين مختلفين. ستحتاج إلى كليهما للاستعادة.'**
  String get dataBackupReadyHint;

  /// No description provided for @dataBackupShareSubject.
  ///
  /// In ar, this message translates to:
  /// **'نسخة مَدار الاحتياطية'**
  String get dataBackupShareSubject;

  /// No description provided for @dataBackupFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر إنشاء النسخة. بياناتك كما هي – حاول مجددًا.'**
  String get dataBackupFailed;

  /// No description provided for @dataBackupMadeOn.
  ///
  /// In ar, this message translates to:
  /// **'أُنشئت في {date}'**
  String dataBackupMadeOn(String date);

  /// No description provided for @dataCsvSheetTitle.
  ///
  /// In ar, this message translates to:
  /// **'تصدير جدول'**
  String get dataCsvSheetTitle;

  /// No description provided for @dataCsvSheetSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'ملف CSV يُفتح في برامج الجداول'**
  String get dataCsvSheetSubtitle;

  /// No description provided for @dataCsvWhat.
  ///
  /// In ar, this message translates to:
  /// **'ماذا'**
  String get dataCsvWhat;

  /// No description provided for @dataCsvWhen.
  ///
  /// In ar, this message translates to:
  /// **'الفترة'**
  String get dataCsvWhen;

  /// No description provided for @dataCsvLabs.
  ///
  /// In ar, this message translates to:
  /// **'التحاليل'**
  String get dataCsvLabs;

  /// No description provided for @dataCsvTransactions.
  ///
  /// In ar, this message translates to:
  /// **'المعاملات'**
  String get dataCsvTransactions;

  /// No description provided for @dataCsvPain.
  ///
  /// In ar, this message translates to:
  /// **'الألم'**
  String get dataCsvPain;

  /// No description provided for @dataCsvMood.
  ///
  /// In ar, this message translates to:
  /// **'المزاج'**
  String get dataCsvMood;

  /// No description provided for @dataRange30.
  ///
  /// In ar, this message translates to:
  /// **'30 يومًا'**
  String get dataRange30;

  /// No description provided for @dataRange90.
  ///
  /// In ar, this message translates to:
  /// **'90 يومًا'**
  String get dataRange90;

  /// No description provided for @dataRangeYear.
  ///
  /// In ar, this message translates to:
  /// **'12 شهرًا'**
  String get dataRangeYear;

  /// No description provided for @dataRangeAll.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get dataRangeAll;

  /// No description provided for @dataRangeCustom.
  ///
  /// In ar, this message translates to:
  /// **'مخصّصة…'**
  String get dataRangeCustom;

  /// No description provided for @dataRangeAllTime.
  ///
  /// In ar, this message translates to:
  /// **'كل السجلات منذ البداية'**
  String get dataRangeAllTime;

  /// No description provided for @dataRangeFromTo.
  ///
  /// In ar, this message translates to:
  /// **'من {from} إلى {to}'**
  String dataRangeFromTo(String from, String to);

  /// No description provided for @dataCsvFormatNote.
  ///
  /// In ar, this message translates to:
  /// **'التواريخ بصيغة {example} والأرقام بنقطة عشرية، فيفتحها أي برنامج جداول كما هي.'**
  String dataCsvFormatNote(String example);

  /// No description provided for @dataCsvCreate.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء الملف'**
  String get dataCsvCreate;

  /// No description provided for @dataCsvCreateRows.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا صفوف في هذه الفترة} =1{إنشاء الملف (صف واحد)} =2{إنشاء الملف (صفّان)} few{إنشاء الملف ({count} صفوف)} many{إنشاء الملف ({count} صفًّا)} other{إنشاء الملف ({count} صف)}}'**
  String dataCsvCreateRows(int count);

  /// No description provided for @dataCsvDate.
  ///
  /// In ar, this message translates to:
  /// **'التاريخ'**
  String get dataCsvDate;

  /// No description provided for @dataCsvTime.
  ///
  /// In ar, this message translates to:
  /// **'الوقت'**
  String get dataCsvTime;

  /// No description provided for @dataCsvTest.
  ///
  /// In ar, this message translates to:
  /// **'التحليل'**
  String get dataCsvTest;

  /// No description provided for @dataCsvCategory.
  ///
  /// In ar, this message translates to:
  /// **'الفئة'**
  String get dataCsvCategory;

  /// No description provided for @dataCsvValue.
  ///
  /// In ar, this message translates to:
  /// **'القيمة'**
  String get dataCsvValue;

  /// No description provided for @dataCsvTextResult.
  ///
  /// In ar, this message translates to:
  /// **'نتيجة نصية'**
  String get dataCsvTextResult;

  /// No description provided for @dataCsvUnit.
  ///
  /// In ar, this message translates to:
  /// **'الوحدة'**
  String get dataCsvUnit;

  /// No description provided for @dataCsvRangeLow.
  ///
  /// In ar, this message translates to:
  /// **'الحد الأدنى'**
  String get dataCsvRangeLow;

  /// No description provided for @dataCsvRangeHigh.
  ///
  /// In ar, this message translates to:
  /// **'الحد الأعلى'**
  String get dataCsvRangeHigh;

  /// No description provided for @dataCsvFlag.
  ///
  /// In ar, this message translates to:
  /// **'العلامة'**
  String get dataCsvFlag;

  /// No description provided for @dataCsvNote.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة'**
  String get dataCsvNote;

  /// No description provided for @dataCsvNotes.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات'**
  String get dataCsvNotes;

  /// No description provided for @dataCsvKind.
  ///
  /// In ar, this message translates to:
  /// **'النوع'**
  String get dataCsvKind;

  /// No description provided for @dataCsvWallet.
  ///
  /// In ar, this message translates to:
  /// **'المحفظة'**
  String get dataCsvWallet;

  /// No description provided for @dataCsvCurrency.
  ///
  /// In ar, this message translates to:
  /// **'العملة'**
  String get dataCsvCurrency;

  /// No description provided for @dataCsvAmount.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ'**
  String get dataCsvAmount;

  /// No description provided for @dataCsvAmountBase.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ بالعملة الأساسية'**
  String get dataCsvAmountBase;

  /// No description provided for @dataCsvBaseCurrency.
  ///
  /// In ar, this message translates to:
  /// **'العملة الأساسية'**
  String get dataCsvBaseCurrency;

  /// No description provided for @dataCsvBudgetItem.
  ///
  /// In ar, this message translates to:
  /// **'بند الميزانية'**
  String get dataCsvBudgetItem;

  /// No description provided for @dataCsvToWallet.
  ///
  /// In ar, this message translates to:
  /// **'إلى المحفظة'**
  String get dataCsvToWallet;

  /// No description provided for @dataCsvToAmount.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ المستلم'**
  String get dataCsvToAmount;

  /// No description provided for @dataCsvToCurrency.
  ///
  /// In ar, this message translates to:
  /// **'عملة الاستلام'**
  String get dataCsvToCurrency;

  /// No description provided for @dataCsvTags.
  ///
  /// In ar, this message translates to:
  /// **'الوسوم'**
  String get dataCsvTags;

  /// No description provided for @dataCsvPainScore.
  ///
  /// In ar, this message translates to:
  /// **'شدة الألم (0-10)'**
  String get dataCsvPainScore;

  /// No description provided for @dataCsvLocations.
  ///
  /// In ar, this message translates to:
  /// **'المواضع'**
  String get dataCsvLocations;

  /// No description provided for @dataCsvTriggers.
  ///
  /// In ar, this message translates to:
  /// **'المحفّزات'**
  String get dataCsvTriggers;

  /// No description provided for @dataCsvBodyPoints.
  ///
  /// In ar, this message translates to:
  /// **'نقاط خريطة الجسم'**
  String get dataCsvBodyPoints;

  /// No description provided for @dataCsvMoodScore.
  ///
  /// In ar, this message translates to:
  /// **'المزاج (1-5)'**
  String get dataCsvMoodScore;

  /// No description provided for @dataCsvStress.
  ///
  /// In ar, this message translates to:
  /// **'التوتر (0-10)'**
  String get dataCsvStress;

  /// No description provided for @dataCsvAnxiety.
  ///
  /// In ar, this message translates to:
  /// **'القلق (0-10)'**
  String get dataCsvAnxiety;

  /// No description provided for @dataCsvEnergy.
  ///
  /// In ar, this message translates to:
  /// **'الطاقة (0-10)'**
  String get dataCsvEnergy;

  /// No description provided for @dataCsvSleepHours.
  ///
  /// In ar, this message translates to:
  /// **'ساعات النوم'**
  String get dataCsvSleepHours;

  /// No description provided for @dataCsvCaffeine.
  ///
  /// In ar, this message translates to:
  /// **'أكواب الكافيين'**
  String get dataCsvCaffeine;

  /// No description provided for @dataCsvFactors.
  ///
  /// In ar, this message translates to:
  /// **'العوامل'**
  String get dataCsvFactors;

  /// No description provided for @dataFlagLow.
  ///
  /// In ar, this message translates to:
  /// **'منخفض'**
  String get dataFlagLow;

  /// No description provided for @dataFlagBorderlineLow.
  ///
  /// In ar, this message translates to:
  /// **'على الحد الأدنى'**
  String get dataFlagBorderlineLow;

  /// No description provided for @dataFlagInRange.
  ///
  /// In ar, this message translates to:
  /// **'ضمن المعدل'**
  String get dataFlagInRange;

  /// No description provided for @dataFlagBorderlineHigh.
  ///
  /// In ar, this message translates to:
  /// **'على الحد الأعلى'**
  String get dataFlagBorderlineHigh;

  /// No description provided for @dataFlagHigh.
  ///
  /// In ar, this message translates to:
  /// **'مرتفع'**
  String get dataFlagHigh;

  /// No description provided for @dataTxExpense.
  ///
  /// In ar, this message translates to:
  /// **'مصروف'**
  String get dataTxExpense;

  /// No description provided for @dataTxIncome.
  ///
  /// In ar, this message translates to:
  /// **'دخل'**
  String get dataTxIncome;

  /// No description provided for @dataTxTransfer.
  ///
  /// In ar, this message translates to:
  /// **'تحويل'**
  String get dataTxTransfer;

  /// No description provided for @dataTxAdjustment.
  ///
  /// In ar, this message translates to:
  /// **'تسوية'**
  String get dataTxAdjustment;

  /// No description provided for @dataSummarySubtitle.
  ///
  /// In ar, this message translates to:
  /// **'يُعدّ على هاتفك · راجع كل قسم قبل المشاركة'**
  String get dataSummarySubtitle;

  /// No description provided for @dataSummaryIntro.
  ///
  /// In ar, this message translates to:
  /// **'لا يُرسَل شيء إلى أي مكان حتى تختار. ما تراه في المعاينة أدناه هو بالضبط ما سيخرج، ولا تُضمَّن الملاحظات أو أرقام الهواتف أو أرقام الوثائق والحسابات.'**
  String get dataSummaryIntro;

  /// No description provided for @dataSummaryPreparing.
  ///
  /// In ar, this message translates to:
  /// **'نجهّز الملخّص على هاتفك…'**
  String get dataSummaryPreparing;

  /// No description provided for @dataSummarySections.
  ///
  /// In ar, this message translates to:
  /// **'الأقسام المضمَّنة'**
  String get dataSummarySections;

  /// No description provided for @dataSummarySectionsOf.
  ///
  /// In ar, this message translates to:
  /// **'{selected} من {total} أقسام'**
  String dataSummarySectionsOf(String selected, String total);

  /// No description provided for @dataSummaryTokens.
  ///
  /// In ar, this message translates to:
  /// **'≈ {count} رمز'**
  String dataSummaryTokens(String count);

  /// No description provided for @dataSummaryNoData.
  ///
  /// In ar, this message translates to:
  /// **'لا بيانات بعد'**
  String get dataSummaryNoData;

  /// No description provided for @dataSummaryProfileHint.
  ///
  /// In ar, this message translates to:
  /// **'اختياري'**
  String get dataSummaryProfileHint;

  /// No description provided for @dataSummaryPreviewTitle.
  ///
  /// In ar, this message translates to:
  /// **'ما سيُشارَك بالضبط'**
  String get dataSummaryPreviewTitle;

  /// No description provided for @dataSummaryCopied.
  ///
  /// In ar, this message translates to:
  /// **'نُسخ الملخّص إلى الحافظة.'**
  String get dataSummaryCopied;

  /// No description provided for @dataSummaryUse.
  ///
  /// In ar, this message translates to:
  /// **'استخدام هذا الملخّص'**
  String get dataSummaryUse;

  /// No description provided for @dataProfileChoose.
  ///
  /// In ar, this message translates to:
  /// **'اختر ما يُذكر عنك:'**
  String get dataProfileChoose;

  /// No description provided for @dataProfileAboutHint.
  ///
  /// In ar, this message translates to:
  /// **'مثلًا: العمر أو ما يهمّك أن يعرفه المساعد'**
  String get dataProfileAboutHint;

  /// No description provided for @dataRestoreFlowTitle.
  ///
  /// In ar, this message translates to:
  /// **'الاستعادة'**
  String get dataRestoreFlowTitle;

  /// No description provided for @dataRestoreChooseTitle.
  ///
  /// In ar, this message translates to:
  /// **'استعادة بياناتك'**
  String get dataRestoreChooseTitle;

  /// No description provided for @dataRestoreChooseBody.
  ///
  /// In ar, this message translates to:
  /// **'اختر ملف نسخة ينتهي بـ {ext}. سترى ما فيه قبل أن يتغيّر أي شيء.'**
  String dataRestoreChooseBody(String ext);

  /// No description provided for @dataRestorePickFile.
  ///
  /// In ar, this message translates to:
  /// **'اختيار ملف النسخة'**
  String get dataRestorePickFile;

  /// No description provided for @dataRestoreNothingChanges.
  ///
  /// In ar, this message translates to:
  /// **'لن يتغيّر شيء في بياناتك الحالية حتى تؤكّد الاستبدال في الخطوة الأخيرة.'**
  String get dataRestoreNothingChanges;

  /// No description provided for @dataSafetyCopiesTitle.
  ///
  /// In ar, this message translates to:
  /// **'نسخ الأمان على هذا الهاتف'**
  String get dataSafetyCopiesTitle;

  /// No description provided for @dataSafetyCopiesHint.
  ///
  /// In ar, this message translates to:
  /// **'تُنشأ تلقائيًا قبل كل استعادة، وتُفتح بعبارة المرور التي استُخدمت حينها.'**
  String get dataSafetyCopiesHint;

  /// No description provided for @dataRestoreUnlockBody.
  ///
  /// In ar, this message translates to:
  /// **'اكتب عبارة المرور التي أقفلت بها هذه النسخة.'**
  String get dataRestoreUnlockBody;

  /// No description provided for @dataRestoreUnlockAction.
  ///
  /// In ar, this message translates to:
  /// **'فتح النسخة'**
  String get dataRestoreUnlockAction;

  /// No description provided for @dataRestoreOtherFile.
  ///
  /// In ar, this message translates to:
  /// **'اختيار ملف آخر'**
  String get dataRestoreOtherFile;

  /// No description provided for @dataRestoreOpening.
  ///
  /// In ar, this message translates to:
  /// **'نتحقق من النسخة…'**
  String get dataRestoreOpening;

  /// No description provided for @dataRestoreOpeningHint.
  ///
  /// In ar, this message translates to:
  /// **'نتأكد أن الملف سليم ولم يُعدَّل، ثم نفكّ تشفيره على هاتفك.'**
  String get dataRestoreOpeningHint;

  /// No description provided for @dataRestorePreviewTitle.
  ///
  /// In ar, this message translates to:
  /// **'النسخة سليمة'**
  String get dataRestorePreviewTitle;

  /// No description provided for @dataRestoreInBackup.
  ///
  /// In ar, this message translates to:
  /// **'في النسخة'**
  String get dataRestoreInBackup;

  /// No description provided for @dataRestoreOnPhone.
  ///
  /// In ar, this message translates to:
  /// **'على الهاتف الآن'**
  String get dataRestoreOnPhone;

  /// No description provided for @dataRestoreWhatsInside.
  ///
  /// In ar, this message translates to:
  /// **'ما في هذه النسخة'**
  String get dataRestoreWhatsInside;

  /// No description provided for @dataRestoreReplaceWarning.
  ///
  /// In ar, this message translates to:
  /// **'ستحلّ هذه النسخة محلّ كل البيانات الموجودة في مَدار الآن. قبل ذلك نحفظ بياناتك الحالية نسخةَ أمان على هذا الهاتف، تُفتح بعبارة المرور نفسها.'**
  String get dataRestoreReplaceWarning;

  /// No description provided for @dataRestoreUnderstand.
  ///
  /// In ar, this message translates to:
  /// **'فهمت أن بياناتي الحالية ستُستبدل'**
  String get dataRestoreUnderstand;

  /// No description provided for @dataRestoreConfirmAction.
  ///
  /// In ar, this message translates to:
  /// **'استبدال بياناتي'**
  String get dataRestoreConfirmAction;

  /// No description provided for @dataRestoreSavingSafety.
  ///
  /// In ar, this message translates to:
  /// **'نحفظ نسخة أمان من بياناتك الحالية…'**
  String get dataRestoreSavingSafety;

  /// No description provided for @dataRestoreRestoring.
  ///
  /// In ar, this message translates to:
  /// **'نستعيد بياناتك…'**
  String get dataRestoreRestoring;

  /// No description provided for @dataRestoreKeepOpen.
  ///
  /// In ar, this message translates to:
  /// **'أبقِ التطبيق مفتوحًا لحظات.'**
  String get dataRestoreKeepOpen;

  /// No description provided for @dataRestoreDoneTitle.
  ///
  /// In ar, this message translates to:
  /// **'تمت الاستعادة'**
  String get dataRestoreDoneTitle;

  /// No description provided for @dataRestoreDoneBody.
  ///
  /// In ar, this message translates to:
  /// **'عادت سجلاتك ({count}) إلى مَدار.'**
  String dataRestoreDoneBody(String count);

  /// No description provided for @dataRestoreSafetyKept.
  ///
  /// In ar, this message translates to:
  /// **'نسخة أمان من بياناتك السابقة محفوظة على هذا الهاتف، وتُفتح بعبارة المرور نفسها.'**
  String get dataRestoreSafetyKept;

  /// No description provided for @dataSafetyCopySave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ نسخة الأمان في مكان آخر'**
  String get dataSafetyCopySave;

  /// No description provided for @dataSafetyCopyTitle.
  ///
  /// In ar, this message translates to:
  /// **'نسخة الأمان'**
  String get dataSafetyCopyTitle;

  /// No description provided for @dataNothingChanged.
  ///
  /// In ar, this message translates to:
  /// **'لم يتغيّر شيء في بياناتك.'**
  String get dataNothingChanged;

  /// No description provided for @dataErrWrongPassphrase.
  ///
  /// In ar, this message translates to:
  /// **'عبارة المرور هذه لا تفتح النسخة. تحقّق من الأحرف وحاول مجددًا.'**
  String get dataErrWrongPassphrase;

  /// No description provided for @dataErrNotBackupTitle.
  ///
  /// In ar, this message translates to:
  /// **'هذا ليس ملف نسخة من مَدار'**
  String get dataErrNotBackupTitle;

  /// No description provided for @dataErrNotBackupBody.
  ///
  /// In ar, this message translates to:
  /// **'اختر ملفًا ينتهي بـ {ext} أنشأته من «إنشاء نسخة احتياطية».'**
  String dataErrNotBackupBody(String ext);

  /// No description provided for @dataErrNewerTitle.
  ///
  /// In ar, this message translates to:
  /// **'أُنشئت بإصدار أحدث من مَدار'**
  String get dataErrNewerTitle;

  /// No description provided for @dataErrNewerBody.
  ///
  /// In ar, this message translates to:
  /// **'حدّث مَدار على هذا الهاتف ثم حاول مجددًا.'**
  String get dataErrNewerBody;

  /// No description provided for @dataErrTruncatedTitle.
  ///
  /// In ar, this message translates to:
  /// **'الملف غير مكتمل'**
  String get dataErrTruncatedTitle;

  /// No description provided for @dataErrTruncatedBody.
  ///
  /// In ar, this message translates to:
  /// **'ربما لم يكتمل نسخه أو تنزيله. انسخه مرة أخرى ثم حاول.'**
  String get dataErrTruncatedBody;

  /// No description provided for @dataErrCorruptedTitle.
  ///
  /// In ar, this message translates to:
  /// **'الملف تالف'**
  String get dataErrCorruptedTitle;

  /// No description provided for @dataErrCorruptedBody.
  ///
  /// In ar, this message translates to:
  /// **'تغيّر الملف أو تلف بعد إنشائه، فلا يمكن الوثوق به.'**
  String get dataErrCorruptedBody;

  /// No description provided for @dataErrUnreadableTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعذّرت قراءة الملف'**
  String get dataErrUnreadableTitle;

  /// No description provided for @dataErrUnreadableBody.
  ///
  /// In ar, this message translates to:
  /// **'جرّب ملفًا آخر أو انسخه إلى الهاتف أولًا.'**
  String get dataErrUnreadableBody;

  /// No description provided for @dataErrSafetyTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر حفظ نسخة الأمان'**
  String get dataErrSafetyTitle;

  /// No description provided for @dataErrSafetyBody.
  ///
  /// In ar, this message translates to:
  /// **'لذلك لم نستبدل بياناتك. وفّر بعض المساحة ثم حاول مجددًا.'**
  String get dataErrSafetyBody;

  /// No description provided for @dataErrRejectedTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعذّرت استعادة هذه النسخة'**
  String get dataErrRejectedTitle;

  /// No description provided for @dataErrRejectedBody.
  ///
  /// In ar, this message translates to:
  /// **'لم تجتز بياناتها فحوص السلامة.'**
  String get dataErrRejectedBody;

  /// No description provided for @dataSumHeading.
  ///
  /// In ar, this message translates to:
  /// **'ملخّص مَدار — {date}'**
  String dataSumHeading(String date);

  /// No description provided for @dataSumPreamble.
  ///
  /// In ar, this message translates to:
  /// **'بيانات متابعة شخصية من تطبيق مَدار، أُعدّت على هاتف المستخدم نفسه. التواريخ بصيغة سنة-شهر-يوم والكسور العشرية بنقطة. لا تُضمَّن الملاحظات ولا أرقام الهواتف ولا أرقام الوثائق أو الحسابات.'**
  String get dataSumPreamble;

  /// No description provided for @dataSumNoData.
  ///
  /// In ar, this message translates to:
  /// **'لا بيانات بعد.'**
  String get dataSumNoData;

  /// No description provided for @dataSumListSep.
  ///
  /// In ar, this message translates to:
  /// **'، '**
  String get dataSumListSep;

  /// No description provided for @dataSumLastDays.
  ///
  /// In ar, this message translates to:
  /// **'{days, plural, =1{اليوم} =2{آخر يومين} few{آخر {days} أيام} many{آخر {days} يومًا} other{آخر {days} يوم}}'**
  String dataSumLastDays(int days);

  /// No description provided for @dataSumPreviousDays.
  ///
  /// In ar, this message translates to:
  /// **'الأيام الـ{days} السابقة'**
  String dataSumPreviousDays(String days);

  /// No description provided for @dataSumMore.
  ///
  /// In ar, this message translates to:
  /// **'غير معروضة: {count}'**
  String dataSumMore(String count);

  /// No description provided for @dataSumProfile.
  ///
  /// In ar, this message translates to:
  /// **'نبذة شخصية'**
  String get dataSumProfile;

  /// No description provided for @dataSumFaith.
  ///
  /// In ar, this message translates to:
  /// **'الإيمان'**
  String get dataSumFaith;

  /// No description provided for @dataSumHealth.
  ///
  /// In ar, this message translates to:
  /// **'الصحة'**
  String get dataSumHealth;

  /// No description provided for @dataSumMoney.
  ///
  /// In ar, this message translates to:
  /// **'المال'**
  String get dataSumMoney;

  /// No description provided for @dataSumFamily.
  ///
  /// In ar, this message translates to:
  /// **'العائلة'**
  String get dataSumFamily;

  /// No description provided for @dataSumWork.
  ///
  /// In ar, this message translates to:
  /// **'العمل'**
  String get dataSumWork;

  /// No description provided for @dataSumGrowth.
  ///
  /// In ar, this message translates to:
  /// **'النمو'**
  String get dataSumGrowth;

  /// No description provided for @dataSumBody.
  ///
  /// In ar, this message translates to:
  /// **'الجسد'**
  String get dataSumBody;

  /// No description provided for @dataSumTravel.
  ///
  /// In ar, this message translates to:
  /// **'السفر'**
  String get dataSumTravel;

  /// No description provided for @dataSumCustom.
  ///
  /// In ar, this message translates to:
  /// **'متتبّعات مخصّصة'**
  String get dataSumCustom;

  /// No description provided for @dataSumCity.
  ///
  /// In ar, this message translates to:
  /// **'المدينة'**
  String get dataSumCity;

  /// No description provided for @dataSumTimeZone.
  ///
  /// In ar, this message translates to:
  /// **'المنطقة الزمنية'**
  String get dataSumTimeZone;

  /// No description provided for @dataSumBaseCurrency.
  ///
  /// In ar, this message translates to:
  /// **'العملة الأساسية'**
  String get dataSumBaseCurrency;

  /// No description provided for @dataSumLanguage.
  ///
  /// In ar, this message translates to:
  /// **'لغة التطبيق'**
  String get dataSumLanguage;

  /// No description provided for @dataSumLanguageName.
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get dataSumLanguageName;

  /// No description provided for @dataSumAboutMe.
  ///
  /// In ar, this message translates to:
  /// **'عنّي'**
  String get dataSumAboutMe;

  /// No description provided for @dataSumPrayersTitle.
  ///
  /// In ar, this message translates to:
  /// **'الصلاة'**
  String get dataSumPrayersTitle;

  /// No description provided for @dataSumObligatory.
  ///
  /// In ar, this message translates to:
  /// **'{window} (الفرائض)'**
  String dataSumObligatory(String window);

  /// No description provided for @dataSumLogged.
  ///
  /// In ar, this message translates to:
  /// **'المسجّل: {logged}/{expected}'**
  String dataSumLogged(String logged, String expected);

  /// No description provided for @dataSumOnTime.
  ///
  /// In ar, this message translates to:
  /// **'في وقتها: {count}'**
  String dataSumOnTime(String count);

  /// No description provided for @dataSumLate.
  ///
  /// In ar, this message translates to:
  /// **'متأخرة: {count}'**
  String dataSumLate(String count);

  /// No description provided for @dataSumMadeUp.
  ///
  /// In ar, this message translates to:
  /// **'قضاء: {count}'**
  String dataSumMadeUp(String count);

  /// No description provided for @dataSumMissed.
  ///
  /// In ar, this message translates to:
  /// **'فائتة: {count}'**
  String dataSumMissed(String count);

  /// No description provided for @dataSumInCongregation.
  ///
  /// In ar, this message translates to:
  /// **'جماعة: {count}'**
  String dataSumInCongregation(String count);

  /// No description provided for @dataSumVoluntary.
  ///
  /// In ar, this message translates to:
  /// **'{window} (النوافل)'**
  String dataSumVoluntary(String window);

  /// No description provided for @dataSumQuranTitle.
  ///
  /// In ar, this message translates to:
  /// **'القرآن والورد'**
  String get dataSumQuranTitle;

  /// No description provided for @dataSumSessions.
  ///
  /// In ar, this message translates to:
  /// **'الجلسات: {count}'**
  String dataSumSessions(String count);

  /// No description provided for @dataSumPages.
  ///
  /// In ar, this message translates to:
  /// **'الصفحات: {count}'**
  String dataSumPages(String count);

  /// No description provided for @dataSumMinutes.
  ///
  /// In ar, this message translates to:
  /// **'{count} د'**
  String dataSumMinutes(String count);

  /// No description provided for @dataSumLastSession.
  ///
  /// In ar, this message translates to:
  /// **'آخر جلسة: {date}'**
  String dataSumLastSession(String date);

  /// No description provided for @dataSumWird.
  ///
  /// In ar, this message translates to:
  /// **'الورد «{name}»'**
  String dataSumWird(String name);

  /// No description provided for @dataSumPerDay.
  ///
  /// In ar, this message translates to:
  /// **'{unit} يوميًا: {amount}'**
  String dataSumPerDay(String amount, String unit);

  /// No description provided for @dataSumUnitPages.
  ///
  /// In ar, this message translates to:
  /// **'الصفحات'**
  String get dataSumUnitPages;

  /// No description provided for @dataSumUnitJuz.
  ///
  /// In ar, this message translates to:
  /// **'الأجزاء'**
  String get dataSumUnitJuz;

  /// No description provided for @dataSumUnitHizb.
  ///
  /// In ar, this message translates to:
  /// **'الأحزاب'**
  String get dataSumUnitHizb;

  /// No description provided for @dataSumUnitAyat.
  ///
  /// In ar, this message translates to:
  /// **'الآيات'**
  String get dataSumUnitAyat;

  /// No description provided for @dataSumSince.
  ///
  /// In ar, this message translates to:
  /// **'منذ {date}'**
  String dataSumSince(String date);

  /// No description provided for @dataSumBy.
  ///
  /// In ar, this message translates to:
  /// **'حتى {date}'**
  String dataSumBy(String date);

  /// No description provided for @dataSumHifzTitle.
  ///
  /// In ar, this message translates to:
  /// **'الحفظ'**
  String get dataSumHifzTitle;

  /// No description provided for @dataSumItems.
  ///
  /// In ar, this message translates to:
  /// **'المحفوظات: {count}'**
  String dataSumItems(String count);

  /// No description provided for @dataSumNew.
  ///
  /// In ar, this message translates to:
  /// **'جديدة: {count}'**
  String dataSumNew(String count);

  /// No description provided for @dataSumDueToday.
  ///
  /// In ar, this message translates to:
  /// **'مستحقة للمراجعة اليوم: {count}'**
  String dataSumDueToday(String count);

  /// No description provided for @dataSumReviews.
  ///
  /// In ar, this message translates to:
  /// **'المراجعات: {count}'**
  String dataSumReviews(String count);

  /// No description provided for @dataSumAvgGrade.
  ///
  /// In ar, this message translates to:
  /// **'متوسط التقييم: {value}/5'**
  String dataSumAvgGrade(String value);

  /// No description provided for @dataSumAlertsTitle.
  ///
  /// In ar, this message translates to:
  /// **'تنبيهات دائمة'**
  String get dataSumAlertsTitle;

  /// No description provided for @dataSumSeverityCritical.
  ///
  /// In ar, this message translates to:
  /// **'حرج'**
  String get dataSumSeverityCritical;

  /// No description provided for @dataSumSeverityWarning.
  ///
  /// In ar, this message translates to:
  /// **'تنبيه'**
  String get dataSumSeverityWarning;

  /// No description provided for @dataSumSeverityInfo.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة'**
  String get dataSumSeverityInfo;

  /// No description provided for @dataSumConditionsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الحالات الصحية'**
  String get dataSumConditionsTitle;

  /// No description provided for @dataSumMedsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الأدوية الحالية'**
  String get dataSumMedsTitle;

  /// No description provided for @dataSumKindSupplement.
  ///
  /// In ar, this message translates to:
  /// **'مكمّل'**
  String get dataSumKindSupplement;

  /// No description provided for @dataSumKindInjection.
  ///
  /// In ar, this message translates to:
  /// **'حقنة'**
  String get dataSumKindInjection;

  /// No description provided for @dataSumWithEmptyStomach.
  ///
  /// In ar, this message translates to:
  /// **'على معدة فارغة'**
  String get dataSumWithEmptyStomach;

  /// No description provided for @dataSumWithBreakfast.
  ///
  /// In ar, this message translates to:
  /// **'مع الفطور'**
  String get dataSumWithBreakfast;

  /// No description provided for @dataSumWithLunch.
  ///
  /// In ar, this message translates to:
  /// **'مع الغداء'**
  String get dataSumWithLunch;

  /// No description provided for @dataSumWithDinner.
  ///
  /// In ar, this message translates to:
  /// **'مع العشاء'**
  String get dataSumWithDinner;

  /// No description provided for @dataSumWithBedtime.
  ///
  /// In ar, this message translates to:
  /// **'قبل النوم'**
  String get dataSumWithBedtime;

  /// No description provided for @dataSumWithCourse.
  ///
  /// In ar, this message translates to:
  /// **'حسب خطة العلاج'**
  String get dataSumWithCourse;

  /// No description provided for @dataSumLabsTitle.
  ///
  /// In ar, this message translates to:
  /// **'أحدث التحاليل'**
  String get dataSumLabsTitle;

  /// No description provided for @dataSumLabsWindow.
  ///
  /// In ar, this message translates to:
  /// **'آخر نتيجة لكل تحليل خلال آخر {months} شهرًا؛ العلامة مقارنةً بالمعدل المحفوظ في التطبيق.'**
  String dataSumLabsWindow(String months);

  /// No description provided for @dataSumColTest.
  ///
  /// In ar, this message translates to:
  /// **'التحليل'**
  String get dataSumColTest;

  /// No description provided for @dataSumColDate.
  ///
  /// In ar, this message translates to:
  /// **'التاريخ'**
  String get dataSumColDate;

  /// No description provided for @dataSumColResult.
  ///
  /// In ar, this message translates to:
  /// **'النتيجة'**
  String get dataSumColResult;

  /// No description provided for @dataSumColRange.
  ///
  /// In ar, this message translates to:
  /// **'المعدل'**
  String get dataSumColRange;

  /// No description provided for @dataSumColFlag.
  ///
  /// In ar, this message translates to:
  /// **'العلامة'**
  String get dataSumColFlag;

  /// No description provided for @dataSumColPrevious.
  ///
  /// In ar, this message translates to:
  /// **'السابقة'**
  String get dataSumColPrevious;

  /// No description provided for @dataSumPainTitle.
  ///
  /// In ar, this message translates to:
  /// **'الألم (متابعة)'**
  String get dataSumPainTitle;

  /// No description provided for @dataSumEntries.
  ///
  /// In ar, this message translates to:
  /// **'الإدخالات: {count}'**
  String dataSumEntries(String count);

  /// No description provided for @dataSumAverageOf.
  ///
  /// In ar, this message translates to:
  /// **'المتوسط: {value}/{max}'**
  String dataSumAverageOf(String value, String max);

  /// No description provided for @dataSumHighest.
  ///
  /// In ar, this message translates to:
  /// **'الأعلى: {value}/{max}'**
  String dataSumHighest(String value, String max);

  /// No description provided for @dataSumTopPlaces.
  ///
  /// In ar, this message translates to:
  /// **'أكثر المواضع تسجيلًا'**
  String get dataSumTopPlaces;

  /// No description provided for @dataSumTopTriggers.
  ///
  /// In ar, this message translates to:
  /// **'أكثر المحفّزات تسجيلًا'**
  String get dataSumTopTriggers;

  /// No description provided for @dataSumMoodTitle.
  ///
  /// In ar, this message translates to:
  /// **'المزاج (متابعة)'**
  String get dataSumMoodTitle;

  /// No description provided for @dataSumMoodAvg.
  ///
  /// In ar, this message translates to:
  /// **'المزاج: {value}/5'**
  String dataSumMoodAvg(String value);

  /// No description provided for @dataSumStressAvg.
  ///
  /// In ar, this message translates to:
  /// **'التوتر: {value}/10'**
  String dataSumStressAvg(String value);

  /// No description provided for @dataSumAnxietyAvg.
  ///
  /// In ar, this message translates to:
  /// **'القلق: {value}/10'**
  String dataSumAnxietyAvg(String value);

  /// No description provided for @dataSumEnergyAvg.
  ///
  /// In ar, this message translates to:
  /// **'الطاقة: {value}/10'**
  String dataSumEnergyAvg(String value);

  /// No description provided for @dataSumSleepAvg.
  ///
  /// In ar, this message translates to:
  /// **'النوم: {value} س'**
  String dataSumSleepAvg(String value);

  /// No description provided for @dataSumCaffeineAvg.
  ///
  /// In ar, this message translates to:
  /// **'الكافيين: {value} كوب'**
  String dataSumCaffeineAvg(String value);

  /// No description provided for @dataSumTopFactors.
  ///
  /// In ar, this message translates to:
  /// **'العوامل الأكثر تكرارًا'**
  String get dataSumTopFactors;

  /// No description provided for @dataSumWalletsTitle.
  ///
  /// In ar, this message translates to:
  /// **'المحافظ'**
  String get dataSumWalletsTitle;

  /// No description provided for @dataSumConvertedTo.
  ///
  /// In ar, this message translates to:
  /// **'محوّلة إلى {code} بأسعار الصرف المحفوظة في التطبيق.'**
  String dataSumConvertedTo(String code);

  /// No description provided for @dataSumColWallet.
  ///
  /// In ar, this message translates to:
  /// **'المحفظة'**
  String get dataSumColWallet;

  /// No description provided for @dataSumColBalance.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد'**
  String get dataSumColBalance;

  /// No description provided for @dataSumColInBase.
  ///
  /// In ar, this message translates to:
  /// **'بـ{code}'**
  String dataSumColInBase(String code);

  /// No description provided for @dataSumTotal.
  ///
  /// In ar, this message translates to:
  /// **'الإجمالي: {amount}'**
  String dataSumTotal(String amount);

  /// No description provided for @dataSumBudgetTitle.
  ///
  /// In ar, this message translates to:
  /// **'الميزانية — {month}'**
  String dataSumBudgetTitle(String month);

  /// No description provided for @dataSumPlanned.
  ///
  /// In ar, this message translates to:
  /// **'المخطط: {amount}'**
  String dataSumPlanned(String amount);

  /// No description provided for @dataSumSpent.
  ///
  /// In ar, this message translates to:
  /// **'المصروف: {amount}'**
  String dataSumSpent(String amount);

  /// No description provided for @dataSumRemaining.
  ///
  /// In ar, this message translates to:
  /// **'المتبقي: {amount}'**
  String dataSumRemaining(String amount);

  /// No description provided for @dataSumOverPlan.
  ///
  /// In ar, this message translates to:
  /// **'تجاوز الخطة'**
  String get dataSumOverPlan;

  /// No description provided for @dataSumUnassigned.
  ///
  /// In ar, this message translates to:
  /// **'مصروف بلا بند: {amount}'**
  String dataSumUnassigned(String amount);

  /// No description provided for @dataSumDueTitle.
  ///
  /// In ar, this message translates to:
  /// **'المستحق خلال الأيام الـ{days} القادمة'**
  String dataSumDueTitle(String days);

  /// No description provided for @dataSumDueOn.
  ///
  /// In ar, this message translates to:
  /// **'يستحق {date}'**
  String dataSumDueOn(String date);

  /// No description provided for @dataSumOverdueSince.
  ///
  /// In ar, this message translates to:
  /// **'متأخر منذ {date}'**
  String dataSumOverdueSince(String date);

  /// No description provided for @dataSumDebtsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الديون'**
  String get dataSumDebtsTitle;

  /// No description provided for @dataSumIOwe.
  ///
  /// In ar, this message translates to:
  /// **'عليّ لـ{person}: المتبقي {left} من {total}'**
  String dataSumIOwe(String person, String left, String total);

  /// No description provided for @dataSumOwedToMe.
  ///
  /// In ar, this message translates to:
  /// **'لي عند {person}: المتبقي {left} من {total}'**
  String dataSumOwedToMe(String person, String left, String total);

  /// No description provided for @dataSumJarsTitle.
  ///
  /// In ar, this message translates to:
  /// **'حصّالات الادخار'**
  String get dataSumJarsTitle;

  /// No description provided for @dataSumJar.
  ///
  /// In ar, this message translates to:
  /// **'{name}: {saved} من {target} ({percent}%)'**
  String dataSumJar(String name, String saved, String target, String percent);

  /// No description provided for @dataSumEvery.
  ///
  /// In ar, this message translates to:
  /// **'الإيقاع (أيام): {days}'**
  String dataSumEvery(String days);

  /// No description provided for @dataSumLastContact.
  ///
  /// In ar, this message translates to:
  /// **'أيام منذ آخر تواصل: {days}'**
  String dataSumLastContact(String days);

  /// No description provided for @dataSumNeverContacted.
  ///
  /// In ar, this message translates to:
  /// **'لم يُسجَّل تواصل بعد'**
  String get dataSumNeverContacted;

  /// No description provided for @dataSumOverdueBy.
  ///
  /// In ar, this message translates to:
  /// **'متأخر (أيام): {days}'**
  String dataSumOverdueBy(String days);

  /// No description provided for @dataSumDueTodayStatus.
  ///
  /// In ar, this message translates to:
  /// **'مستحق اليوم'**
  String get dataSumDueTodayStatus;

  /// No description provided for @dataSumDueIn.
  ///
  /// In ar, this message translates to:
  /// **'يستحق بعد (أيام): {days}'**
  String dataSumDueIn(String days);

  /// No description provided for @dataSumNoRhythm.
  ///
  /// In ar, this message translates to:
  /// **'آخرون بلا إيقاع تواصل: {count}'**
  String dataSumNoRhythm(int count);

  /// No description provided for @dataSumPeopleNoRhythm.
  ///
  /// In ar, this message translates to:
  /// **'أشخاص بلا إيقاع تواصل: {count}'**
  String dataSumPeopleNoRhythm(int count);

  /// No description provided for @dataSumTop3Title.
  ///
  /// In ar, this message translates to:
  /// **'أهم 3'**
  String get dataSumTop3Title;

  /// No description provided for @dataSumOnBoard.
  ///
  /// In ar, this message translates to:
  /// **'اللوحة: {board}'**
  String dataSumOnBoard(String board);

  /// No description provided for @dataSumBoardsTitle.
  ///
  /// In ar, this message translates to:
  /// **'اللوحات'**
  String get dataSumBoardsTitle;

  /// No description provided for @dataSumOther.
  ///
  /// In ar, this message translates to:
  /// **'أخرى'**
  String get dataSumOther;

  /// No description provided for @dataSumProjectsTitle.
  ///
  /// In ar, this message translates to:
  /// **'المشاريع'**
  String get dataSumProjectsTitle;

  /// No description provided for @dataSumStatusActive.
  ///
  /// In ar, this message translates to:
  /// **'نشط'**
  String get dataSumStatusActive;

  /// No description provided for @dataSumStatusPaused.
  ///
  /// In ar, this message translates to:
  /// **'متوقف مؤقتًا'**
  String get dataSumStatusPaused;

  /// No description provided for @dataSumDoneOf.
  ///
  /// In ar, this message translates to:
  /// **'المنجز: {done}/{total}'**
  String dataSumDoneOf(String done, String total);

  /// No description provided for @dataSumDeadline.
  ///
  /// In ar, this message translates to:
  /// **'الموعد النهائي: {date}'**
  String dataSumDeadline(String date);

  /// No description provided for @dataSumProgress.
  ///
  /// In ar, this message translates to:
  /// **'{current} من {target} {unit}'**
  String dataSumProgress(String current, String target, String unit);

  /// No description provided for @dataSumRecentGain.
  ///
  /// In ar, this message translates to:
  /// **'{window}: {amount}'**
  String dataSumRecentGain(String amount, String window);

  /// No description provided for @dataSumExercisePlanTitle.
  ///
  /// In ar, this message translates to:
  /// **'خطة التمارين'**
  String get dataSumExercisePlanTitle;

  /// Seven comma-separated weekday names, Monday first
  ///
  /// In ar, this message translates to:
  /// **'الإثنين,الثلاثاء,الأربعاء,الخميس,الجمعة,السبت,الأحد'**
  String get dataSumWeekdays;

  /// No description provided for @dataSumSets.
  ///
  /// In ar, this message translates to:
  /// **'المجموعات: {count}'**
  String dataSumSets(String count);

  /// No description provided for @dataSumKg.
  ///
  /// In ar, this message translates to:
  /// **'{value} كغ'**
  String dataSumKg(String value);

  /// No description provided for @dataSumWorkouts.
  ///
  /// In ar, this message translates to:
  /// **'التمارين المنجزة: {count}'**
  String dataSumWorkouts(String count);

  /// No description provided for @dataSumFasting.
  ///
  /// In ar, this message translates to:
  /// **'الصيام: {count} · المتوسط: {hours} س'**
  String dataSumFasting(String count, String hours);

  /// No description provided for @dataSumTargetHours.
  ///
  /// In ar, this message translates to:
  /// **'الهدف: {hours} س'**
  String dataSumTargetHours(String hours);

  /// No description provided for @dataSumWater.
  ///
  /// In ar, this message translates to:
  /// **'الماء خلال آخر {days} أيام: {ml} مل يوميًا في المتوسط'**
  String dataSumWater(String days, String ml);

  /// No description provided for @dataSumTargetMl.
  ///
  /// In ar, this message translates to:
  /// **'الهدف: {ml} مل'**
  String dataSumTargetMl(String ml);

  /// No description provided for @dataSumAvoidTitle.
  ///
  /// In ar, this message translates to:
  /// **'تجنّب'**
  String get dataSumAvoidTitle;

  /// No description provided for @dataSumTripsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الرحلات القادمة'**
  String get dataSumTripsTitle;

  /// No description provided for @dataSumTripPlanned.
  ///
  /// In ar, this message translates to:
  /// **'مخطط لها'**
  String get dataSumTripPlanned;

  /// No description provided for @dataSumTripUnderWay.
  ///
  /// In ar, this message translates to:
  /// **'جارية الآن'**
  String get dataSumTripUnderWay;

  /// No description provided for @dataSumDocumentsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الوثائق (لا تُضمَّن أرقامها أبدًا)'**
  String get dataSumDocumentsTitle;

  /// No description provided for @dataSumExpiresIn.
  ///
  /// In ar, this message translates to:
  /// **'تنتهي {date} (الأيام المتبقية: {days})'**
  String dataSumExpiresIn(String date, String days);

  /// No description provided for @dataSumExpired.
  ///
  /// In ar, this message translates to:
  /// **'انتهت {date}'**
  String dataSumExpired(String date);

  /// No description provided for @dataSumNoExpiry.
  ///
  /// In ar, this message translates to:
  /// **'بلا تاريخ انتهاء'**
  String get dataSumNoExpiry;

  /// No description provided for @dataSumModuleTracker.
  ///
  /// In ar, this message translates to:
  /// **'متتبّع'**
  String get dataSumModuleTracker;

  /// No description provided for @dataSumModuleList.
  ///
  /// In ar, this message translates to:
  /// **'قائمة'**
  String get dataSumModuleList;

  /// No description provided for @dataSumOpen.
  ///
  /// In ar, this message translates to:
  /// **'مفتوحة: {count}'**
  String dataSumOpen(String count);

  /// No description provided for @dataSumDone.
  ///
  /// In ar, this message translates to:
  /// **'منجزة: {count}'**
  String dataSumDone(String count);

  /// No description provided for @dataSumInWindow.
  ///
  /// In ar, this message translates to:
  /// **'{window}: {count}'**
  String dataSumInWindow(String count, String window);

  /// No description provided for @dataSumLastOn.
  ///
  /// In ar, this message translates to:
  /// **'الأخير: {date}'**
  String dataSumLastOn(String date);

  /// No description provided for @dataSumAverage.
  ///
  /// In ar, this message translates to:
  /// **'المتوسط: {value}'**
  String dataSumAverage(String value);

  /// No description provided for @dataSumMin.
  ///
  /// In ar, this message translates to:
  /// **'الأدنى: {value}'**
  String dataSumMin(String value);

  /// No description provided for @dataSumMax.
  ///
  /// In ar, this message translates to:
  /// **'الأعلى: {value}'**
  String dataSumMax(String value);

  /// No description provided for @dataSumSum.
  ///
  /// In ar, this message translates to:
  /// **'المجموع: {value}'**
  String dataSumSum(String value);

  /// No description provided for @dataSumTicked.
  ///
  /// In ar, this message translates to:
  /// **'مؤشَّر عليها: {count}/{total}'**
  String dataSumTicked(String count, String total);

  /// Global search screen title
  ///
  /// In ar, this message translates to:
  /// **'البحث'**
  String get searchTitle;

  /// No description provided for @searchFieldHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث في المهام والملاحظات والأشخاص والآيات…'**
  String get searchFieldHint;

  /// Compact search launcher on home / app bars
  ///
  /// In ar, this message translates to:
  /// **'ابحث في مَدار'**
  String get searchLauncherHint;

  /// No description provided for @searchLauncherTooltip.
  ///
  /// In ar, this message translates to:
  /// **'البحث في كل شيء'**
  String get searchLauncherTooltip;

  /// No description provided for @searchClear.
  ///
  /// In ar, this message translates to:
  /// **'مسح النص'**
  String get searchClear;

  /// No description provided for @searchRecentTitle.
  ///
  /// In ar, this message translates to:
  /// **'عمليات البحث الأخيرة'**
  String get searchRecentTitle;

  /// No description provided for @searchRecentClear.
  ///
  /// In ar, this message translates to:
  /// **'مسح السجل'**
  String get searchRecentClear;

  /// No description provided for @searchRecentRemove.
  ///
  /// In ar, this message translates to:
  /// **'حذف «{query}» من السجل'**
  String searchRecentRemove(String query);

  /// No description provided for @searchIntroTitle.
  ///
  /// In ar, this message translates to:
  /// **'ابحث في مدارك كله'**
  String get searchIntroTitle;

  /// No description provided for @searchIntroBody.
  ///
  /// In ar, this message translates to:
  /// **'المهام والملاحظات والأشخاص والمال والآيات في مكان واحد. يجري البحث على هاتفك فقط.'**
  String get searchIntroBody;

  /// No description provided for @searchPreparing.
  ///
  /// In ar, this message translates to:
  /// **'نُجهّز فهرس البحث…'**
  String get searchPreparing;

  /// No description provided for @searchNoResultsTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا نتائج لـ «{query}»'**
  String searchNoResultsTitle(String query);

  /// No description provided for @searchNoResultsBody.
  ///
  /// In ar, this message translates to:
  /// **'جرّب كلمات أقل أو تهجئة أخرى.'**
  String get searchNoResultsBody;

  /// No description provided for @searchNoResultsFiltered.
  ///
  /// In ar, this message translates to:
  /// **'لا شيء هنا ضمن التصفية الحالية.'**
  String get searchNoResultsFiltered;

  /// No description provided for @searchClearFilters.
  ///
  /// In ar, this message translates to:
  /// **'إزالة التصفية'**
  String get searchClearFilters;

  /// No description provided for @searchAll.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get searchAll;

  /// No description provided for @searchResultsCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا نتائج} =1{نتيجة واحدة} =2{نتيجتان} few{{count} نتائج} many{{count} نتيجة} other{{count} نتيجة}}'**
  String searchResultsCount(int count);

  /// No description provided for @searchShowAll.
  ///
  /// In ar, this message translates to:
  /// **'عرض الكل ({count})'**
  String searchShowAll(String count);

  /// No description provided for @searchGroupSemantics.
  ///
  /// In ar, this message translates to:
  /// **'{module}، {count}'**
  String searchGroupSemantics(String module, String count);

  /// No description provided for @searchPartial.
  ///
  /// In ar, this message translates to:
  /// **'لم نجد كل الكلمات معًا؛ هذه أقرب النتائج.'**
  String get searchPartial;

  /// No description provided for @searchCannotOpen.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن فتح هذه النتيجة من هنا بعد.'**
  String get searchCannotOpen;

  /// No description provided for @searchToday.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get searchToday;

  /// No description provided for @searchYesterday.
  ///
  /// In ar, this message translates to:
  /// **'أمس'**
  String get searchYesterday;

  /// No description provided for @searchTomorrow.
  ///
  /// In ar, this message translates to:
  /// **'غدًا'**
  String get searchTomorrow;

  /// No description provided for @searchFilterPlanets.
  ///
  /// In ar, this message translates to:
  /// **'التصفية حسب الكوكب'**
  String get searchFilterPlanets;

  /// No description provided for @searchFilterModules.
  ///
  /// In ar, this message translates to:
  /// **'التصفية حسب القسم'**
  String get searchFilterModules;

  /// No description provided for @searchPlanetCustom.
  ///
  /// In ar, this message translates to:
  /// **'وحدات مخصصة'**
  String get searchPlanetCustom;

  /// No description provided for @searchKeyboardHint.
  ///
  /// In ar, this message translates to:
  /// **'↑ ↓ للتنقل، Enter للفتح، Esc للمسح'**
  String get searchKeyboardHint;

  /// No description provided for @searchDone.
  ///
  /// In ar, this message translates to:
  /// **'منجزة'**
  String get searchDone;

  /// No description provided for @searchArchived.
  ///
  /// In ar, this message translates to:
  /// **'مؤرشفة'**
  String get searchArchived;

  /// No description provided for @searchTxExpense.
  ///
  /// In ar, this message translates to:
  /// **'مصروف'**
  String get searchTxExpense;

  /// No description provided for @searchTxIncome.
  ///
  /// In ar, this message translates to:
  /// **'دخل'**
  String get searchTxIncome;

  /// No description provided for @searchTxTransfer.
  ///
  /// In ar, this message translates to:
  /// **'تحويل'**
  String get searchTxTransfer;

  /// No description provided for @searchTxAdjustment.
  ///
  /// In ar, this message translates to:
  /// **'تسوية'**
  String get searchTxAdjustment;

  /// No description provided for @searchDebtIOwe.
  ///
  /// In ar, this message translates to:
  /// **'دين عليّ'**
  String get searchDebtIOwe;

  /// No description provided for @searchDebtOwedToMe.
  ///
  /// In ar, this message translates to:
  /// **'دين لي'**
  String get searchDebtOwedToMe;

  /// No description provided for @searchChannelCall.
  ///
  /// In ar, this message translates to:
  /// **'مكالمة'**
  String get searchChannelCall;

  /// No description provided for @searchChannelVisit.
  ///
  /// In ar, this message translates to:
  /// **'زيارة'**
  String get searchChannelVisit;

  /// No description provided for @searchChannelMessage.
  ///
  /// In ar, this message translates to:
  /// **'رسالة'**
  String get searchChannelMessage;

  /// No description provided for @searchChannelOther.
  ///
  /// In ar, this message translates to:
  /// **'تواصل'**
  String get searchChannelOther;

  /// No description provided for @searchPainTitle.
  ///
  /// In ar, this message translates to:
  /// **'ألم {score}/{max}'**
  String searchPainTitle(String score, String max);

  /// No description provided for @searchMoodTitle.
  ///
  /// In ar, this message translates to:
  /// **'المزاج'**
  String get searchMoodTitle;

  /// No description provided for @searchFastingTitle.
  ///
  /// In ar, this message translates to:
  /// **'صيام'**
  String get searchFastingTitle;

  /// No description provided for @searchAyahPlace.
  ///
  /// In ar, this message translates to:
  /// **'{surah}، الآية {ayah}'**
  String searchAyahPlace(String surah, String ayah);

  /// No description provided for @searchAyahRange.
  ///
  /// In ar, this message translates to:
  /// **'{surah} {from}–{to}'**
  String searchAyahRange(String surah, String from, String to);

  /// No description provided for @searchSurahNumber.
  ///
  /// In ar, this message translates to:
  /// **'سورة {number}'**
  String searchSurahNumber(String number);

  /// No description provided for @searchSourceTasks.
  ///
  /// In ar, this message translates to:
  /// **'المهام'**
  String get searchSourceTasks;

  /// No description provided for @searchSourcePrayerLogs.
  ///
  /// In ar, this message translates to:
  /// **'سجل الصلوات'**
  String get searchSourcePrayerLogs;

  /// No description provided for @searchSourceMedications.
  ///
  /// In ar, this message translates to:
  /// **'الأدوية'**
  String get searchSourceMedications;

  /// No description provided for @searchSourceMedCourses.
  ///
  /// In ar, this message translates to:
  /// **'الكورسات العلاجية'**
  String get searchSourceMedCourses;

  /// No description provided for @searchSourceMedDoses.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات الجرعات'**
  String get searchSourceMedDoses;

  /// No description provided for @searchSourceConditions.
  ///
  /// In ar, this message translates to:
  /// **'الحالات الصحية'**
  String get searchSourceConditions;

  /// No description provided for @searchSourceHealthAlerts.
  ///
  /// In ar, this message translates to:
  /// **'التنبيهات الصحية'**
  String get searchSourceHealthAlerts;

  /// No description provided for @searchSourceLabTests.
  ///
  /// In ar, this message translates to:
  /// **'التحاليل'**
  String get searchSourceLabTests;

  /// No description provided for @searchSourceLabReadings.
  ///
  /// In ar, this message translates to:
  /// **'نتائج التحاليل'**
  String get searchSourceLabReadings;

  /// No description provided for @searchSourceAppointments.
  ///
  /// In ar, this message translates to:
  /// **'المواعيد'**
  String get searchSourceAppointments;

  /// No description provided for @searchSourceDoctorQuestions.
  ///
  /// In ar, this message translates to:
  /// **'أسئلة الطبيب'**
  String get searchSourceDoctorQuestions;

  /// No description provided for @searchSourcePain.
  ///
  /// In ar, this message translates to:
  /// **'سجل الألم'**
  String get searchSourcePain;

  /// No description provided for @searchSourceMood.
  ///
  /// In ar, this message translates to:
  /// **'سجل المزاج'**
  String get searchSourceMood;

  /// No description provided for @searchSourceHabits.
  ///
  /// In ar, this message translates to:
  /// **'العادات'**
  String get searchSourceHabits;

  /// No description provided for @searchSourceWorries.
  ///
  /// In ar, this message translates to:
  /// **'المخاوف'**
  String get searchSourceWorries;

  /// No description provided for @searchSourceWallets.
  ///
  /// In ar, this message translates to:
  /// **'المحافظ'**
  String get searchSourceWallets;

  /// No description provided for @searchSourceTransactions.
  ///
  /// In ar, this message translates to:
  /// **'المعاملات'**
  String get searchSourceTransactions;

  /// No description provided for @searchSourceBudget.
  ///
  /// In ar, this message translates to:
  /// **'الميزانية'**
  String get searchSourceBudget;

  /// No description provided for @searchSourceJars.
  ///
  /// In ar, this message translates to:
  /// **'الحصّالات'**
  String get searchSourceJars;

  /// No description provided for @searchSourceJarDeposits.
  ///
  /// In ar, this message translates to:
  /// **'إيداعات الحصّالات'**
  String get searchSourceJarDeposits;

  /// No description provided for @searchSourceDebts.
  ///
  /// In ar, this message translates to:
  /// **'الديون'**
  String get searchSourceDebts;

  /// No description provided for @searchSourceDebtPayments.
  ///
  /// In ar, this message translates to:
  /// **'سداد الديون'**
  String get searchSourceDebtPayments;

  /// No description provided for @searchSourceObligations.
  ///
  /// In ar, this message translates to:
  /// **'الالتزامات'**
  String get searchSourceObligations;

  /// No description provided for @searchSourcePeople.
  ///
  /// In ar, this message translates to:
  /// **'الأشخاص'**
  String get searchSourcePeople;

  /// No description provided for @searchSourceContactLogs.
  ///
  /// In ar, this message translates to:
  /// **'سجل التواصل'**
  String get searchSourceContactLogs;

  /// No description provided for @searchSourceProjects.
  ///
  /// In ar, this message translates to:
  /// **'المشاريع'**
  String get searchSourceProjects;

  /// No description provided for @searchSourceProjectItems.
  ///
  /// In ar, this message translates to:
  /// **'بنود المشاريع'**
  String get searchSourceProjectItems;

  /// No description provided for @searchSourceBoards.
  ///
  /// In ar, this message translates to:
  /// **'اللوحات'**
  String get searchSourceBoards;

  /// No description provided for @searchSourceCards.
  ///
  /// In ar, this message translates to:
  /// **'البطاقات'**
  String get searchSourceCards;

  /// No description provided for @searchSourceTrips.
  ///
  /// In ar, this message translates to:
  /// **'الرحلات'**
  String get searchSourceTrips;

  /// No description provided for @searchSourceTripItems.
  ///
  /// In ar, this message translates to:
  /// **'أغراض الرحلات'**
  String get searchSourceTripItems;

  /// No description provided for @searchSourcePackingTemplates.
  ///
  /// In ar, this message translates to:
  /// **'قوائم التجهيز'**
  String get searchSourcePackingTemplates;

  /// No description provided for @searchSourceTravelDocuments.
  ///
  /// In ar, this message translates to:
  /// **'وثائق السفر'**
  String get searchSourceTravelDocuments;

  /// No description provided for @searchSourceLearningGoals.
  ///
  /// In ar, this message translates to:
  /// **'أهداف التعلّم'**
  String get searchSourceLearningGoals;

  /// No description provided for @searchSourceGoalLogs.
  ///
  /// In ar, this message translates to:
  /// **'سجل الأهداف'**
  String get searchSourceGoalLogs;

  /// No description provided for @searchSourceExercises.
  ///
  /// In ar, this message translates to:
  /// **'التمارين'**
  String get searchSourceExercises;

  /// No description provided for @searchSourceWorkouts.
  ///
  /// In ar, this message translates to:
  /// **'سجل التمارين'**
  String get searchSourceWorkouts;

  /// No description provided for @searchSourceAvoidItems.
  ///
  /// In ar, this message translates to:
  /// **'قائمة التجنّب'**
  String get searchSourceAvoidItems;

  /// No description provided for @searchSourceFasting.
  ///
  /// In ar, this message translates to:
  /// **'الصيام المتقطع'**
  String get searchSourceFasting;

  /// No description provided for @searchSourceCustomModules.
  ///
  /// In ar, this message translates to:
  /// **'الوحدات المخصصة'**
  String get searchSourceCustomModules;

  /// No description provided for @searchSourceCustomEntries.
  ///
  /// In ar, this message translates to:
  /// **'سجلات الوحدات'**
  String get searchSourceCustomEntries;

  /// No description provided for @searchSourceQuranAyat.
  ///
  /// In ar, this message translates to:
  /// **'آيات القرآن'**
  String get searchSourceQuranAyat;

  /// No description provided for @searchSourceQuranBookmarks.
  ///
  /// In ar, this message translates to:
  /// **'علامات المصحف'**
  String get searchSourceQuranBookmarks;

  /// No description provided for @searchSourceWirdPlans.
  ///
  /// In ar, this message translates to:
  /// **'خطط الورد'**
  String get searchSourceWirdPlans;

  /// No description provided for @searchSourceHifz.
  ///
  /// In ar, this message translates to:
  /// **'الحفظ'**
  String get searchSourceHifz;

  /// No description provided for @searchSourcePlanets.
  ///
  /// In ar, this message translates to:
  /// **'الكواكب'**
  String get searchSourcePlanets;

  /// Title of the notification center
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات'**
  String get ncTitle;

  /// Notification center tab: scheduled notifications
  ///
  /// In ar, this message translates to:
  /// **'القادمة'**
  String get ncTabUpcoming;

  /// Notification center tab: delivered notifications
  ///
  /// In ar, this message translates to:
  /// **'الأخيرة'**
  String get ncTabRecent;

  /// Screen-reader label of a tab with its count
  ///
  /// In ar, this message translates to:
  /// **'{label}، {count}'**
  String ncTabWithCount(String label, String count);

  /// No description provided for @ncOpenSettings.
  ///
  /// In ar, this message translates to:
  /// **'إعدادات الإشعارات'**
  String get ncOpenSettings;

  /// No description provided for @ncUpcomingEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا شيء مجدول'**
  String get ncUpcomingEmptyTitle;

  /// No description provided for @ncUpcomingEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'ما تفعّله من أذان وتذكيرات سيصطفّ هنا للأيام السبعة القادمة.'**
  String get ncUpcomingEmptyBody;

  /// No description provided for @ncRecentEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا جديد'**
  String get ncRecentEmptyTitle;

  /// No description provided for @ncRecentEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'ما يصلك من إشعارات يبقى هنا أسبوعين، لتعود إليه متى شئت.'**
  String get ncRecentEmptyBody;

  /// No description provided for @ncClearAll.
  ///
  /// In ar, this message translates to:
  /// **'مسح الكل'**
  String get ncClearAll;

  /// No description provided for @ncClearedAll.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{مُسح إشعار واحد} =2{مُسح إشعاران} few{مُسحت {count} إشعارات} many{مُسح {count} إشعارًا} other{مُسح {count} إشعار}}'**
  String ncClearedAll(int count);

  /// No description provided for @ncDismissed.
  ///
  /// In ar, this message translates to:
  /// **'أُزيل من القائمة'**
  String get ncDismissed;

  /// No description provided for @ncSkippedToast.
  ///
  /// In ar, this message translates to:
  /// **'لن يصل هذا التذكير'**
  String get ncSkippedToast;

  /// No description provided for @ncRestoredToast.
  ///
  /// In ar, this message translates to:
  /// **'سيصل في وقته'**
  String get ncRestoredToast;

  /// No description provided for @ncShowMore.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{عرض واحد آخر} =2{عرض اثنين آخرين} few{عرض {count} أخرى} many{عرض {count} أخرى} other{عرض {count} أخرى}}'**
  String ncShowMore(int count);

  /// No description provided for @ncShowLess.
  ///
  /// In ar, this message translates to:
  /// **'عرض أقل'**
  String get ncShowLess;

  /// Screen-reader label of a group section
  ///
  /// In ar, this message translates to:
  /// **'{group}، {count}'**
  String ncSectionLabel(String group, String count);

  /// No description provided for @ncGroupPrayer.
  ///
  /// In ar, this message translates to:
  /// **'الصلاة والأذان'**
  String get ncGroupPrayer;

  /// No description provided for @ncGroupAdhkar.
  ///
  /// In ar, this message translates to:
  /// **'الأذكار'**
  String get ncGroupAdhkar;

  /// No description provided for @ncGroupMedications.
  ///
  /// In ar, this message translates to:
  /// **'الأدوية'**
  String get ncGroupMedications;

  /// No description provided for @ncGroupHealth.
  ///
  /// In ar, this message translates to:
  /// **'الصحة'**
  String get ncGroupHealth;

  /// No description provided for @ncGroupMoney.
  ///
  /// In ar, this message translates to:
  /// **'المستحقات المالية'**
  String get ncGroupMoney;

  /// No description provided for @ncGroupFamily.
  ///
  /// In ar, this message translates to:
  /// **'العائلة'**
  String get ncGroupFamily;

  /// No description provided for @ncGroupTravel.
  ///
  /// In ar, this message translates to:
  /// **'وثائق السفر'**
  String get ncGroupTravel;

  /// No description provided for @ncGroupWird.
  ///
  /// In ar, this message translates to:
  /// **'الوِرد'**
  String get ncGroupWird;

  /// No description provided for @ncGroupCustom.
  ///
  /// In ar, this message translates to:
  /// **'الوحدات المخصّصة'**
  String get ncGroupCustom;

  /// No description provided for @ncGroupOther.
  ///
  /// In ar, this message translates to:
  /// **'أخرى'**
  String get ncGroupOther;

  /// No description provided for @ncKindAdhan.
  ///
  /// In ar, this message translates to:
  /// **'أذان {prayer}'**
  String ncKindAdhan(String prayer);

  /// A reminder some minutes before a prayer
  ///
  /// In ar, this message translates to:
  /// **'{prayer} بعد {minutes}'**
  String ncKindPreAdhan(String prayer, String minutes);

  /// No description provided for @ncKindPreAdhanShort.
  ///
  /// In ar, this message translates to:
  /// **'تذكير قبل {prayer}'**
  String ncKindPreAdhanShort(String prayer);

  /// No description provided for @ncKindSunrise.
  ///
  /// In ar, this message translates to:
  /// **'الشروق'**
  String get ncKindSunrise;

  /// No description provided for @ncKindAdhanTest.
  ///
  /// In ar, this message translates to:
  /// **'أذان تجريبي'**
  String get ncKindAdhanTest;

  /// No description provided for @ncKindAdhkarMorning.
  ///
  /// In ar, this message translates to:
  /// **'أذكار الصباح'**
  String get ncKindAdhkarMorning;

  /// No description provided for @ncKindAdhkarEvening.
  ///
  /// In ar, this message translates to:
  /// **'أذكار المساء'**
  String get ncKindAdhkarEvening;

  /// No description provided for @ncKindAdhkar.
  ///
  /// In ar, this message translates to:
  /// **'تذكير بالأذكار'**
  String get ncKindAdhkar;

  /// No description provided for @ncKindDose.
  ///
  /// In ar, this message translates to:
  /// **'موعد جرعة'**
  String get ncKindDose;

  /// No description provided for @ncKindRefill.
  ///
  /// In ar, this message translates to:
  /// **'حان وقت إعادة التعبئة'**
  String get ncKindRefill;

  /// No description provided for @ncKindMedsNotice.
  ///
  /// In ar, this message translates to:
  /// **'إجابة لم تُسجَّل'**
  String get ncKindMedsNotice;

  /// No description provided for @ncKindAppointment.
  ///
  /// In ar, this message translates to:
  /// **'موعد طبي'**
  String get ncKindAppointment;

  /// No description provided for @ncKindWorry.
  ///
  /// In ar, this message translates to:
  /// **'نافذة القلق'**
  String get ncKindWorry;

  /// No description provided for @ncKindFastGoal.
  ///
  /// In ar, this message translates to:
  /// **'هدف الصيام'**
  String get ncKindFastGoal;

  /// No description provided for @ncKindEatingClose.
  ///
  /// In ar, this message translates to:
  /// **'نافذة الأكل تُغلق'**
  String get ncKindEatingClose;

  /// No description provided for @ncKindDebt.
  ///
  /// In ar, this message translates to:
  /// **'دَين مستحق'**
  String get ncKindDebt;

  /// No description provided for @ncKindObligation.
  ///
  /// In ar, this message translates to:
  /// **'التزام مستحق'**
  String get ncKindObligation;

  /// No description provided for @ncKindFamilyDigest.
  ///
  /// In ar, this message translates to:
  /// **'صلة الرحم'**
  String get ncKindFamilyDigest;

  /// No description provided for @ncKindBirthdayEve.
  ///
  /// In ar, this message translates to:
  /// **'عيد ميلاد غدًا'**
  String get ncKindBirthdayEve;

  /// No description provided for @ncKindBirthday.
  ///
  /// In ar, this message translates to:
  /// **'عيد ميلاد اليوم'**
  String get ncKindBirthday;

  /// No description provided for @ncKindDocAhead.
  ///
  /// In ar, this message translates to:
  /// **'وثيقة تقترب من الانتهاء'**
  String get ncKindDocAhead;

  /// No description provided for @ncKindDocToday.
  ///
  /// In ar, this message translates to:
  /// **'وثيقة تنتهي اليوم'**
  String get ncKindDocToday;

  /// No description provided for @ncKindWird.
  ///
  /// In ar, this message translates to:
  /// **'الوِرد اليومي'**
  String get ncKindWird;

  /// No description provided for @ncKindCustom.
  ///
  /// In ar, this message translates to:
  /// **'تذكير وحدة'**
  String get ncKindCustom;

  /// No description provided for @ncKindOther.
  ///
  /// In ar, this message translates to:
  /// **'إشعار'**
  String get ncKindOther;

  /// No description provided for @ncAtTime.
  ///
  /// In ar, this message translates to:
  /// **'الساعة {time}'**
  String ncAtTime(String time);

  /// No description provided for @ncStateMuted.
  ///
  /// In ar, this message translates to:
  /// **'مكتوم'**
  String get ncStateMuted;

  /// No description provided for @ncStateSkipped.
  ///
  /// In ar, this message translates to:
  /// **'متخطّى'**
  String get ncStateSkipped;

  /// No description provided for @ncStateSnoozedUntil.
  ///
  /// In ar, this message translates to:
  /// **'مؤجّل حتى {time}'**
  String ncStateSnoozedUntil(String time);

  /// No description provided for @ncStateLive.
  ///
  /// In ar, this message translates to:
  /// **'ظاهر الآن'**
  String get ncStateLive;

  /// No description provided for @ncStateSilenced.
  ///
  /// In ar, this message translates to:
  /// **'وصل صامتًا'**
  String get ncStateSilenced;

  /// No description provided for @ncStateOpened.
  ///
  /// In ar, this message translates to:
  /// **'فُتح'**
  String get ncStateOpened;

  /// No description provided for @ncStateAnswered.
  ///
  /// In ar, this message translates to:
  /// **'أُجيب: {action}'**
  String ncStateAnswered(String action);

  /// No description provided for @ncStateSnoozed.
  ///
  /// In ar, this message translates to:
  /// **'أُجّل'**
  String get ncStateSnoozed;

  /// No description provided for @ncStateNew.
  ///
  /// In ar, this message translates to:
  /// **'جديد'**
  String get ncStateNew;

  /// No description provided for @ncTimeNow.
  ///
  /// In ar, this message translates to:
  /// **'الآن'**
  String get ncTimeNow;

  /// No description provided for @ncTimeIn.
  ///
  /// In ar, this message translates to:
  /// **'بعد {duration}'**
  String ncTimeIn(String duration);

  /// No description provided for @ncTimeAgo.
  ///
  /// In ar, this message translates to:
  /// **'قبل {duration}'**
  String ncTimeAgo(String duration);

  /// No description provided for @ncTimeToday.
  ///
  /// In ar, this message translates to:
  /// **'اليوم {time}'**
  String ncTimeToday(String time);

  /// No description provided for @ncTimeTomorrow.
  ///
  /// In ar, this message translates to:
  /// **'غدًا {time}'**
  String ncTimeTomorrow(String time);

  /// No description provided for @ncTimeYesterday.
  ///
  /// In ar, this message translates to:
  /// **'أمس {time}'**
  String ncTimeYesterday(String time);

  /// No description provided for @ncTimeOnDay.
  ///
  /// In ar, this message translates to:
  /// **'{day} {time}'**
  String ncTimeOnDay(String day, String time);

  /// Dose answered from the notification center
  ///
  /// In ar, this message translates to:
  /// **'أخذتها'**
  String get ncActionTaken;

  /// No description provided for @ncActionSnooze.
  ///
  /// In ar, this message translates to:
  /// **'أجِّل'**
  String get ncActionSnooze;

  /// No description provided for @ncActionSkip.
  ///
  /// In ar, this message translates to:
  /// **'تخطَّ'**
  String get ncActionSkip;

  /// Stops a sounding adhan
  ///
  /// In ar, this message translates to:
  /// **'إيقاف'**
  String get ncActionStop;

  /// No description provided for @ncActionOpen.
  ///
  /// In ar, this message translates to:
  /// **'افتح'**
  String get ncActionOpen;

  /// No description provided for @ncActionSkipOne.
  ///
  /// In ar, this message translates to:
  /// **'لا ترسل هذا'**
  String get ncActionSkipOne;

  /// No description provided for @ncActionRestore.
  ///
  /// In ar, this message translates to:
  /// **'أعِده'**
  String get ncActionRestore;

  /// No description provided for @ncActionSnoozeFor.
  ///
  /// In ar, this message translates to:
  /// **'أجِّل {duration}'**
  String ncActionSnoozeFor(String duration);

  /// No description provided for @ncActionMuteGroup.
  ///
  /// In ar, this message translates to:
  /// **'اكتم {group}'**
  String ncActionMuteGroup(String group);

  /// No description provided for @ncActionUnmute.
  ///
  /// In ar, this message translates to:
  /// **'ألغِ الكتم'**
  String get ncActionUnmute;

  /// No description provided for @ncActionSettings.
  ///
  /// In ar, this message translates to:
  /// **'إعدادات التذكير'**
  String get ncActionSettings;

  /// No description provided for @ncActionDismiss.
  ///
  /// In ar, this message translates to:
  /// **'أزِل'**
  String get ncActionDismiss;

  /// No description provided for @ncActionFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر ذلك الآن، حاول مرة أخرى'**
  String get ncActionFailed;

  /// No description provided for @ncSnoozedToast.
  ///
  /// In ar, this message translates to:
  /// **'أُجّل حتى {time}'**
  String ncSnoozedToast(String time);

  /// No description provided for @ncMutedToast.
  ///
  /// In ar, this message translates to:
  /// **'{group} مكتوم حتى {when}'**
  String ncMutedToast(String group, String when);

  /// No description provided for @ncUnmutedToast.
  ///
  /// In ar, this message translates to:
  /// **'عاد {group} إلى وضعه'**
  String ncUnmutedToast(String group);

  /// No description provided for @ncMuteTitle.
  ///
  /// In ar, this message translates to:
  /// **'اكتم {group}'**
  String ncMuteTitle(String group);

  /// No description provided for @ncMuteSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'لن يصدر شيء من هذه المجموعة خلال المدة، وستجده هنا في القائمة.'**
  String get ncMuteSubtitle;

  /// No description provided for @ncMuteForHours.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{ساعة} =2{ساعتين} few{{count} ساعات} many{{count} ساعة} other{{count} ساعة}}'**
  String ncMuteForHours(int count);

  /// No description provided for @ncMuteUntilMorning.
  ///
  /// In ar, this message translates to:
  /// **'حتى صباح الغد'**
  String get ncMuteUntilMorning;

  /// No description provided for @ncMuteWeek.
  ///
  /// In ar, this message translates to:
  /// **'أسبوعًا'**
  String get ncMuteWeek;

  /// No description provided for @ncMutedUntil.
  ///
  /// In ar, this message translates to:
  /// **'مكتوم حتى {when}'**
  String ncMutedUntil(String when);

  /// No description provided for @ncSettingsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات'**
  String get ncSettingsTitle;

  /// No description provided for @ncSettingsSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'ما يرسله كل جزء من مَدار، في مكان واحد'**
  String get ncSettingsSubtitle;

  /// No description provided for @ncSettingsOn.
  ///
  /// In ar, this message translates to:
  /// **'مفعّلة'**
  String get ncSettingsOn;

  /// No description provided for @ncSettingsOff.
  ///
  /// In ar, this message translates to:
  /// **'متوقفة'**
  String get ncSettingsOff;

  /// No description provided for @ncSettingsSome.
  ///
  /// In ar, this message translates to:
  /// **'{on} من {total} مفعّلة'**
  String ncSettingsSome(String on, String total);

  /// No description provided for @ncSettingsPerItem.
  ///
  /// In ar, this message translates to:
  /// **'تُضبط لكل عنصر'**
  String get ncSettingsPerItem;

  /// No description provided for @ncSettingsComing.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا شيء قادم} =1{واحد قادم} =2{اثنان قادمان} few{{count} قادمة} many{{count} قادمًا} other{{count} قادم}}'**
  String ncSettingsComing(int count);

  /// No description provided for @ncSettingsOpen.
  ///
  /// In ar, this message translates to:
  /// **'افتح إعدادات {group}'**
  String ncSettingsOpen(String group);

  /// No description provided for @ncSettingsMute.
  ///
  /// In ar, this message translates to:
  /// **'اكتم'**
  String get ncSettingsMute;

  /// No description provided for @ncPermissionOff.
  ///
  /// In ar, this message translates to:
  /// **'إشعارات مَدار متوقفة من إعدادات الهاتف، فلن يصل شيء مما هنا.'**
  String get ncPermissionOff;

  /// No description provided for @ncPermissionTurnOn.
  ///
  /// In ar, this message translates to:
  /// **'فعّلها'**
  String get ncPermissionTurnOn;

  /// Screen-reader label of the notification bell
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{الإشعارات} =1{الإشعارات، واحد جديد} =2{الإشعارات، اثنان جديدان} few{الإشعارات، {count} جديدة} many{الإشعارات، {count} جديدًا} other{الإشعارات، {count} جديد}}'**
  String ncBellLabel(int count);

  /// No description provided for @ncActionCancelSnooze.
  ///
  /// In ar, this message translates to:
  /// **'ألغِ التأجيل'**
  String get ncActionCancelSnooze;

  /// No description provided for @ncActionSnoozeMenu.
  ///
  /// In ar, this message translates to:
  /// **'أجِّل…'**
  String get ncActionSnoozeMenu;

  /// No description provided for @ncSnoozeTitle.
  ///
  /// In ar, this message translates to:
  /// **'أعِده بعد قليل'**
  String get ncSnoozeTitle;

  /// No description provided for @ncSnoozeSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'يختفي الآن، ثم يصلك من جديد في الوقت الذي تختاره.'**
  String get ncSnoozeSubtitle;

  /// No description provided for @ncOptionUntil.
  ///
  /// In ar, this message translates to:
  /// **'حتى {time}'**
  String ncOptionUntil(String time);

  /// No description provided for @ncOptionAt.
  ///
  /// In ar, this message translates to:
  /// **'يعود {time}'**
  String ncOptionAt(String time);

  /// No description provided for @ncRecentCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{إشعار واحد} =2{إشعاران} few{{count} إشعارات} many{{count} إشعارًا} other{{count} إشعار}}'**
  String ncRecentCount(int count);

  /// No description provided for @ncUpcomingCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا شيء في الأيام السبعة القادمة} =1{إشعار واحد في الأيام السبعة القادمة} =2{إشعاران في الأيام السبعة القادمة} few{{count} إشعارات في الأيام السبعة القادمة} many{{count} إشعارًا في الأيام السبعة القادمة} other{{count} إشعار في الأيام السبعة القادمة}}'**
  String ncUpcomingCount(int count);

  /// No description provided for @ncNewCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{واحد جديد} =2{اثنان جديدان} few{{count} جديدة} many{{count} جديدًا} other{{count} جديد}}'**
  String ncNewCount(int count);

  /// End of a mute or snooze tomorrow, after 'until'
  ///
  /// In ar, this message translates to:
  /// **'غدًا {time}'**
  String ncUntilTomorrow(String time);

  /// AI chat screen title
  ///
  /// In ar, this message translates to:
  /// **'المحادثة الذكية'**
  String get aiChatTitle;

  /// No description provided for @aiChatNewChat.
  ///
  /// In ar, this message translates to:
  /// **'محادثة جديدة'**
  String get aiChatNewChat;

  /// No description provided for @aiChatListTitle.
  ///
  /// In ar, this message translates to:
  /// **'المحادثات'**
  String get aiChatListTitle;

  /// No description provided for @aiChatSettingsTitle.
  ///
  /// In ar, this message translates to:
  /// **'إعدادات الذكاء الاصطناعي'**
  String get aiChatSettingsTitle;

  /// Subtitle of the Settings row that opens the AI settings
  ///
  /// In ar, this message translates to:
  /// **'المفاتيح والنموذج وطول الرد'**
  String get aiChatSettingsRowSubtitle;

  /// Entry point on hubs
  ///
  /// In ar, this message translates to:
  /// **'اسأل الذكاء الاصطناعي'**
  String get aiChatAskAi;

  /// No description provided for @aiChatAskAiSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'بمفتاحك الخاص، وأنت تختار ما يُرسل'**
  String get aiChatAskAiSubtitle;

  /// No description provided for @aiChatAskAbout.
  ///
  /// In ar, this message translates to:
  /// **'اسأل عن {area}'**
  String aiChatAskAbout(String area);

  /// No description provided for @aiChatMenu.
  ///
  /// In ar, this message translates to:
  /// **'المزيد'**
  String get aiChatMenu;

  /// No description provided for @aiChatOpenList.
  ///
  /// In ar, this message translates to:
  /// **'كل المحادثات'**
  String get aiChatOpenList;

  /// No description provided for @aiChatInputHint.
  ///
  /// In ar, this message translates to:
  /// **'اكتب رسالتك…'**
  String get aiChatInputHint;

  /// No description provided for @aiChatSend.
  ///
  /// In ar, this message translates to:
  /// **'إرسال'**
  String get aiChatSend;

  /// No description provided for @aiChatStop.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف'**
  String get aiChatStop;

  /// No description provided for @aiChatThinking.
  ///
  /// In ar, this message translates to:
  /// **'يفكّر…'**
  String get aiChatThinking;

  /// No description provided for @aiChatWriting.
  ///
  /// In ar, this message translates to:
  /// **'يكتب الرد'**
  String get aiChatWriting;

  /// No description provided for @aiChatWillSend.
  ///
  /// In ar, this message translates to:
  /// **'سيُرسل'**
  String get aiChatWillSend;

  /// No description provided for @aiChatContextReviewFirst.
  ///
  /// In ar, this message translates to:
  /// **'ستراجع ملخّصك قبل الإرسال'**
  String get aiChatContextReviewFirst;

  /// No description provided for @aiChatContextNone.
  ///
  /// In ar, this message translates to:
  /// **'بلا سياق شخصي'**
  String get aiChatContextNone;

  /// No description provided for @aiChatContextSections.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا أقسام} =1{قسم واحد من ملخّصك} =2{قسمان من ملخّصك} few{{count} أقسام من ملخّصك} many{{count} قسمًا من ملخّصك} other{{count} قسم من ملخّصك}}'**
  String aiChatContextSections(int count);

  /// No description provided for @aiChatMessagesCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا رسائل} =1{رسالة واحدة} =2{رسالتان} few{{count} رسائل} many{{count} رسالة} other{{count} رسالة}}'**
  String aiChatMessagesCount(int count);

  /// No description provided for @aiChatApproxTokens.
  ///
  /// In ar, this message translates to:
  /// **'≈ {count} رمز'**
  String aiChatApproxTokens(String count);

  /// No description provided for @aiChatStripSemantics.
  ///
  /// In ar, this message translates to:
  /// **'سيُرسل: {summary}. انقر للمراجعة أو التغيير'**
  String aiChatStripSemantics(String summary);

  /// No description provided for @aiChatOmitted.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{رسالة أقدم لن تُرسل} =2{رسالتان أقدم لن تُرسلا} few{{count} رسائل أقدم لن تُرسل} many{{count} رسالة أقدم لن تُرسل} other{{count} رسالة أقدم لن تُرسل}}'**
  String aiChatOmitted(int count);

  /// No description provided for @aiChatContextTitle.
  ///
  /// In ar, this message translates to:
  /// **'ما الذي سيُرسل'**
  String get aiChatContextTitle;

  /// No description provided for @aiChatContextSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'لا يُرسل شيء إلا حين تضغط «إرسال»'**
  String get aiChatContextSubtitle;

  /// No description provided for @aiChatContextFromSummary.
  ///
  /// In ar, this message translates to:
  /// **'من ملخّصك'**
  String get aiChatContextFromSummary;

  /// No description provided for @aiChatContextChange.
  ///
  /// In ar, this message translates to:
  /// **'مراجعة الأقسام'**
  String get aiChatContextChange;

  /// No description provided for @aiChatContextChoose.
  ///
  /// In ar, this message translates to:
  /// **'اختيار الأقسام'**
  String get aiChatContextChoose;

  /// No description provided for @aiChatContextNoneHint.
  ///
  /// In ar, this message translates to:
  /// **'لن يُرسل شيء من بياناتك، فقط رسائل هذه المحادثة.'**
  String get aiChatContextNoneHint;

  /// No description provided for @aiChatContextUnsetHint.
  ///
  /// In ar, this message translates to:
  /// **'عند أول إرسال ستظهر معاينة الملخّص لتختار الأقسام أو تستبعد ما تشاء.'**
  String get aiChatContextUnsetHint;

  /// Confirm button of the summary preview opened from the AI chat
  ///
  /// In ar, this message translates to:
  /// **'استخدمه في المحادثة'**
  String get aiChatContextUse;

  /// Confirm button of the summary preview opened by the first Send
  ///
  /// In ar, this message translates to:
  /// **'استخدمه وأرسل'**
  String get aiChatContextUseAndSend;

  /// No description provided for @aiChatContextReviewed.
  ///
  /// In ar, this message translates to:
  /// **'راجعته {when}'**
  String aiChatContextReviewed(String when);

  /// No description provided for @aiChatContextCancelled.
  ///
  /// In ar, this message translates to:
  /// **'لم يُرسل شيء.'**
  String get aiChatContextCancelled;

  /// No description provided for @aiChatServiceModel.
  ///
  /// In ar, this message translates to:
  /// **'{service} · {model}'**
  String aiChatServiceModel(String service, String model);

  /// No description provided for @aiChatViewPayload.
  ///
  /// In ar, this message translates to:
  /// **'عرض الطلب كما سيُرسل'**
  String get aiChatViewPayload;

  /// No description provided for @aiChatDone.
  ///
  /// In ar, this message translates to:
  /// **'تم'**
  String get aiChatDone;

  /// No description provided for @aiChatPayloadTitle.
  ///
  /// In ar, this message translates to:
  /// **'الطلب كما سيُرسل'**
  String get aiChatPayloadTitle;

  /// No description provided for @aiChatPayloadEndpoint.
  ///
  /// In ar, this message translates to:
  /// **'العنوان'**
  String get aiChatPayloadEndpoint;

  /// No description provided for @aiChatPayloadHeaders.
  ///
  /// In ar, this message translates to:
  /// **'الترويسات (المفتاح مخفي)'**
  String get aiChatPayloadHeaders;

  /// No description provided for @aiChatPayloadSystem.
  ///
  /// In ar, this message translates to:
  /// **'التعليمات والسياق'**
  String get aiChatPayloadSystem;

  /// No description provided for @aiChatPayloadMessages.
  ///
  /// In ar, this message translates to:
  /// **'الرسائل'**
  String get aiChatPayloadMessages;

  /// No description provided for @aiChatPayloadRaw.
  ///
  /// In ar, this message translates to:
  /// **'النص الكامل (JSON)'**
  String get aiChatPayloadRaw;

  /// No description provided for @aiChatPayloadDraftNote.
  ///
  /// In ar, this message translates to:
  /// **'يشمل رسالتك الجاري كتابتها. لن يُرسل إلا حين تضغط «إرسال».'**
  String get aiChatPayloadDraftNote;

  /// No description provided for @aiChatPayloadNoDraft.
  ///
  /// In ar, this message translates to:
  /// **'اكتب رسالة لترى الطلب كاملًا.'**
  String get aiChatPayloadNoDraft;

  /// No description provided for @aiChatPayloadSize.
  ///
  /// In ar, this message translates to:
  /// **'{size} · ≈ {tokens} رمز'**
  String aiChatPayloadSize(String size, String tokens);

  /// No description provided for @aiChatBytes.
  ///
  /// In ar, this message translates to:
  /// **'{count} بايت'**
  String aiChatBytes(String count);

  /// No description provided for @aiChatKiloBytes.
  ///
  /// In ar, this message translates to:
  /// **'{count} ك.ب'**
  String aiChatKiloBytes(String count);

  /// No description provided for @aiChatRoleUser.
  ///
  /// In ar, this message translates to:
  /// **'أنت'**
  String get aiChatRoleUser;

  /// No description provided for @aiChatRoleAssistant.
  ///
  /// In ar, this message translates to:
  /// **'المساعد'**
  String get aiChatRoleAssistant;

  /// No description provided for @aiChatCopy.
  ///
  /// In ar, this message translates to:
  /// **'نسخ'**
  String get aiChatCopy;

  /// No description provided for @aiChatCopied.
  ///
  /// In ar, this message translates to:
  /// **'نُسخ'**
  String get aiChatCopied;

  /// No description provided for @aiChatCopyCode.
  ///
  /// In ar, this message translates to:
  /// **'نسخ الشيفرة'**
  String get aiChatCopyCode;

  /// No description provided for @aiChatRegenerate.
  ///
  /// In ar, this message translates to:
  /// **'إعادة كتابة الرد'**
  String get aiChatRegenerate;

  /// No description provided for @aiChatRetry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get aiChatRetry;

  /// No description provided for @aiChatStopped.
  ///
  /// In ar, this message translates to:
  /// **'أوقفتَ الرد'**
  String get aiChatStopped;

  /// No description provided for @aiChatCutShort.
  ///
  /// In ar, this message translates to:
  /// **'توقّف الرد عند حدّ الطول. يمكنك رفعه من الإعدادات.'**
  String get aiChatCutShort;

  /// No description provided for @aiChatRefused.
  ///
  /// In ar, this message translates to:
  /// **'امتنع النموذج عن الإجابة.'**
  String get aiChatRefused;

  /// No description provided for @aiChatFiltered.
  ///
  /// In ar, this message translates to:
  /// **'أوقف مرشّح المحتوى الرد.'**
  String get aiChatFiltered;

  /// No description provided for @aiChatHealthNote.
  ///
  /// In ar, this message translates to:
  /// **'للمتابعة فقط وليس نصيحة طبية؛ استشر طبيبك في أي قرار صحي.'**
  String get aiChatHealthNote;

  /// No description provided for @aiChatOpenLink.
  ///
  /// In ar, this message translates to:
  /// **'فتح الرابط {url}'**
  String aiChatOpenLink(String url);

  /// No description provided for @aiChatLinkFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح الرابط.'**
  String get aiChatLinkFailed;

  /// No description provided for @aiChatErrorNoKey.
  ///
  /// In ar, this message translates to:
  /// **'أضف مفتاح {service} أولًا.'**
  String aiChatErrorNoKey(String service);

  /// No description provided for @aiChatErrorBadKey.
  ///
  /// In ar, this message translates to:
  /// **'رفضت {service} المفتاح. تحقّق منه أو استبدله في الإعدادات.'**
  String aiChatErrorBadKey(String service);

  /// No description provided for @aiChatErrorForbidden.
  ///
  /// In ar, this message translates to:
  /// **'لا يملك هذا المفتاح صلاحية استخدام هذا النموذج.'**
  String get aiChatErrorForbidden;

  /// No description provided for @aiChatErrorRateLimited.
  ///
  /// In ar, this message translates to:
  /// **'طلبات كثيرة الآن. انتظر قليلًا ثم أعد المحاولة.'**
  String get aiChatErrorRateLimited;

  /// No description provided for @aiChatErrorRetryAfter.
  ///
  /// In ar, this message translates to:
  /// **'يمكنك المحاولة بعد {seconds} ث.'**
  String aiChatErrorRetryAfter(String seconds);

  /// No description provided for @aiChatErrorQuota.
  ///
  /// In ar, this message translates to:
  /// **'نفد الرصيد أو بلغتَ حدّ الإنفاق لدى {service}.'**
  String aiChatErrorQuota(String service);

  /// No description provided for @aiChatErrorOverloaded.
  ///
  /// In ar, this message translates to:
  /// **'{service} مشغولة الآن. أعد المحاولة بعد قليل.'**
  String aiChatErrorOverloaded(String service);

  /// No description provided for @aiChatErrorServer.
  ///
  /// In ar, this message translates to:
  /// **'حدث خلل لدى {service}. أعد المحاولة.'**
  String aiChatErrorServer(String service);

  /// No description provided for @aiChatErrorModelNotFound.
  ///
  /// In ar, this message translates to:
  /// **'النموذج «{model}» غير متاح لهذا المفتاح. اختر نموذجًا آخر.'**
  String aiChatErrorModelNotFound(String model);

  /// No description provided for @aiChatErrorTemperature.
  ///
  /// In ar, this message translates to:
  /// **'لا يقبل هذا النموذج درجة حرارة مخصّصة. اجعلها «افتراضي النموذج» في الإعدادات.'**
  String get aiChatErrorTemperature;

  /// No description provided for @aiChatErrorContextTooLong.
  ///
  /// In ar, this message translates to:
  /// **'المحادثة أطول مما يحتمله النموذج. ابدأ محادثة جديدة أو شارك أقسامًا أقل.'**
  String get aiChatErrorContextTooLong;

  /// No description provided for @aiChatErrorBadRequest.
  ///
  /// In ar, this message translates to:
  /// **'رفضت {service} الطلب.'**
  String aiChatErrorBadRequest(String service);

  /// No description provided for @aiChatErrorNetwork.
  ///
  /// In ar, this message translates to:
  /// **'لا اتصال بالإنترنت، أو انقطع الاتصال.'**
  String get aiChatErrorNetwork;

  /// No description provided for @aiChatErrorTimeout.
  ///
  /// In ar, this message translates to:
  /// **'لم يصل ردّ في الوقت المناسب.'**
  String get aiChatErrorTimeout;

  /// No description provided for @aiChatErrorBadResponse.
  ///
  /// In ar, this message translates to:
  /// **'وصل ردّ تعذّرت قراءته.'**
  String get aiChatErrorBadResponse;

  /// No description provided for @aiChatErrorUnknown.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ غير متوقّع.'**
  String get aiChatErrorUnknown;

  /// No description provided for @aiChatOpenSettings.
  ///
  /// In ar, this message translates to:
  /// **'فتح الإعدادات'**
  String get aiChatOpenSettings;

  /// No description provided for @aiChatSetupTitle.
  ///
  /// In ar, this message translates to:
  /// **'اربط مفتاحك الخاص'**
  String get aiChatSetupTitle;

  /// No description provided for @aiChatSetupBody.
  ///
  /// In ar, this message translates to:
  /// **'تعمل المحادثة بمفتاح API منك لدى Anthropic أو OpenAI. يُحفظ مشفّرًا على هذا الهاتف فقط، ولا يدخل النسخ الاحتياطية ولا التصدير.'**
  String get aiChatSetupBody;

  /// No description provided for @aiChatSetupAdd.
  ///
  /// In ar, this message translates to:
  /// **'إضافة مفتاح {service}'**
  String aiChatSetupAdd(String service);

  /// No description provided for @aiChatSetupPrivacy.
  ///
  /// In ar, this message translates to:
  /// **'لا يُرسل شيء إلا حين تضغط «إرسال»، وترى قبلها ما سيُرسل بالضبط.'**
  String get aiChatSetupPrivacy;

  /// No description provided for @aiChatEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'بمَ أساعدك اليوم؟'**
  String get aiChatEmptyTitle;

  /// No description provided for @aiChatEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'اسأل عن يومك أو صلاتك أو ميزانيتك أو أهدافك. تختار ما يُشارك من ملخّصك قبل الإرسال.'**
  String get aiChatEmptyBody;

  /// No description provided for @aiChatSuggestWeek.
  ///
  /// In ar, this message translates to:
  /// **'لخّص أسبوعي في نقاط قليلة'**
  String get aiChatSuggestWeek;

  /// No description provided for @aiChatSuggestBudget.
  ///
  /// In ar, this message translates to:
  /// **'كيف أحسّن ميزانيتي هذا الشهر؟'**
  String get aiChatSuggestBudget;

  /// No description provided for @aiChatSuggestPlan.
  ///
  /// In ar, this message translates to:
  /// **'ساعدني أخطّط لغدٍ متوازن'**
  String get aiChatSuggestPlan;

  /// No description provided for @aiChatSuggestPrayer.
  ///
  /// In ar, this message translates to:
  /// **'كيف أحافظ على الصلاة في وقتها؟'**
  String get aiChatSuggestPrayer;

  /// No description provided for @aiChatListEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا محادثات بعد'**
  String get aiChatListEmptyTitle;

  /// No description provided for @aiChatListEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ محادثة، وتُحفظ هنا مشفّرة على هاتفك.'**
  String get aiChatListEmptyBody;

  /// No description provided for @aiChatRename.
  ///
  /// In ar, this message translates to:
  /// **'إعادة التسمية'**
  String get aiChatRename;

  /// No description provided for @aiChatRenameField.
  ///
  /// In ar, this message translates to:
  /// **'اسم المحادثة'**
  String get aiChatRenameField;

  /// No description provided for @aiChatRenameSave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ الاسم'**
  String get aiChatRenameSave;

  /// No description provided for @aiChatDelete.
  ///
  /// In ar, this message translates to:
  /// **'حذف المحادثة'**
  String get aiChatDelete;

  /// No description provided for @aiChatDeleted.
  ///
  /// In ar, this message translates to:
  /// **'حُذفت المحادثة'**
  String get aiChatDeleted;

  /// No description provided for @aiChatDeleteAll.
  ///
  /// In ar, this message translates to:
  /// **'حذف كل المحادثات'**
  String get aiChatDeleteAll;

  /// No description provided for @aiChatDeletedAll.
  ///
  /// In ar, this message translates to:
  /// **'حُذفت كل المحادثات'**
  String get aiChatDeletedAll;

  /// No description provided for @aiChatUntitled.
  ///
  /// In ar, this message translates to:
  /// **'محادثة بلا عنوان'**
  String get aiChatUntitled;

  /// No description provided for @aiChatListLimitNote.
  ///
  /// In ar, this message translates to:
  /// **'تُحفظ آخر {count} محادثة؛ الأقدم يُحذف تلقائيًا.'**
  String aiChatListLimitNote(String count);

  /// No description provided for @aiChatListUpdated.
  ///
  /// In ar, this message translates to:
  /// **'{when} · {messages}'**
  String aiChatListUpdated(String when, String messages);

  /// No description provided for @aiChatToday.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get aiChatToday;

  /// No description provided for @aiChatYesterday.
  ///
  /// In ar, this message translates to:
  /// **'أمس'**
  String get aiChatYesterday;

  /// No description provided for @aiChatSettingsService.
  ///
  /// In ar, this message translates to:
  /// **'الخدمة'**
  String get aiChatSettingsService;

  /// No description provided for @aiChatSettingsServiceModel.
  ///
  /// In ar, this message translates to:
  /// **'الخدمة والنموذج'**
  String get aiChatSettingsServiceModel;

  /// No description provided for @aiChatServiceAnthropic.
  ///
  /// In ar, this message translates to:
  /// **'Anthropic'**
  String get aiChatServiceAnthropic;

  /// No description provided for @aiChatServiceOpenai.
  ///
  /// In ar, this message translates to:
  /// **'OpenAI'**
  String get aiChatServiceOpenai;

  /// No description provided for @aiChatSettingsKeys.
  ///
  /// In ar, this message translates to:
  /// **'مفاتيح API'**
  String get aiChatSettingsKeys;

  /// No description provided for @aiChatKeyTitle.
  ///
  /// In ar, this message translates to:
  /// **'مفتاح {service}'**
  String aiChatKeyTitle(String service);

  /// No description provided for @aiChatKeySaved.
  ///
  /// In ar, this message translates to:
  /// **'محفوظ · {mask}'**
  String aiChatKeySaved(String mask);

  /// No description provided for @aiChatKeyNotSet.
  ///
  /// In ar, this message translates to:
  /// **'لم يُضف بعد'**
  String get aiChatKeyNotSet;

  /// No description provided for @aiChatKeySheetSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'يُحفظ مشفّرًا على هذا الهاتف فقط.'**
  String get aiChatKeySheetSubtitle;

  /// No description provided for @aiChatKeyCurrent.
  ///
  /// In ar, this message translates to:
  /// **'المفتاح الحالي'**
  String get aiChatKeyCurrent;

  /// No description provided for @aiChatKeyField.
  ///
  /// In ar, this message translates to:
  /// **'المفتاح'**
  String get aiChatKeyField;

  /// No description provided for @aiChatKeyFieldHint.
  ///
  /// In ar, this message translates to:
  /// **'الصق المفتاح هنا'**
  String get aiChatKeyFieldHint;

  /// No description provided for @aiChatKeyPaste.
  ///
  /// In ar, this message translates to:
  /// **'لصق'**
  String get aiChatKeyPaste;

  /// No description provided for @aiChatKeySave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ المفتاح'**
  String get aiChatKeySave;

  /// No description provided for @aiChatKeyReplace.
  ///
  /// In ar, this message translates to:
  /// **'استبدال المفتاح'**
  String get aiChatKeyReplace;

  /// No description provided for @aiChatKeyDelete.
  ///
  /// In ar, this message translates to:
  /// **'حذف المفتاح'**
  String get aiChatKeyDelete;

  /// No description provided for @aiChatKeyDeleted.
  ///
  /// In ar, this message translates to:
  /// **'حُذف المفتاح'**
  String get aiChatKeyDeleted;

  /// No description provided for @aiChatKeySavedNotice.
  ///
  /// In ar, this message translates to:
  /// **'حُفظ المفتاح.'**
  String get aiChatKeySavedNotice;

  /// No description provided for @aiChatKeyTest.
  ///
  /// In ar, this message translates to:
  /// **'اختبار المفتاح'**
  String get aiChatKeyTest;

  /// No description provided for @aiChatKeyTestOk.
  ///
  /// In ar, this message translates to:
  /// **'المفتاح يعمل.'**
  String get aiChatKeyTestOk;

  /// No description provided for @aiChatKeyTestNote.
  ///
  /// In ar, this message translates to:
  /// **'الاختبار يطلب قائمة النماذج فقط، ولا يرسل أي بيانات منك.'**
  String get aiChatKeyTestNote;

  /// No description provided for @aiChatKeyWhere.
  ///
  /// In ar, this message translates to:
  /// **'أين أجد مفتاحي؟'**
  String get aiChatKeyWhere;

  /// No description provided for @aiChatKeyProblemEmpty.
  ///
  /// In ar, this message translates to:
  /// **'الصق المفتاح أولًا.'**
  String get aiChatKeyProblemEmpty;

  /// No description provided for @aiChatKeyProblemShort.
  ///
  /// In ar, this message translates to:
  /// **'هذا أقصر من أن يكون مفتاحًا.'**
  String get aiChatKeyProblemShort;

  /// No description provided for @aiChatKeyProblemSpaces.
  ///
  /// In ar, this message translates to:
  /// **'في المفتاح مسافات؛ انسخه مرة أخرى.'**
  String get aiChatKeyProblemSpaces;

  /// No description provided for @aiChatKeyProblemProvider.
  ///
  /// In ar, this message translates to:
  /// **'هذا المفتاح خاص بخدمة {service}، لذا لم يُحفظ هنا حتى لا يُرسل إلى خدمة أخرى. أضِفه ضمن {service}.'**
  String aiChatKeyProblemProvider(String service);

  /// No description provided for @aiChatSettingsModel.
  ///
  /// In ar, this message translates to:
  /// **'النموذج'**
  String get aiChatSettingsModel;

  /// No description provided for @aiChatModelPickerTitle.
  ///
  /// In ar, this message translates to:
  /// **'اختر النموذج'**
  String get aiChatModelPickerTitle;

  /// No description provided for @aiChatModelYourList.
  ///
  /// In ar, this message translates to:
  /// **'قائمتك'**
  String get aiChatModelYourList;

  /// No description provided for @aiChatModelsAvailable.
  ///
  /// In ar, this message translates to:
  /// **'متاح لدى {service}'**
  String aiChatModelsAvailable(String service);

  /// No description provided for @aiChatModelCustom.
  ///
  /// In ar, this message translates to:
  /// **'إضافة معرّف نموذج'**
  String get aiChatModelCustom;

  /// No description provided for @aiChatModelCustomField.
  ///
  /// In ar, this message translates to:
  /// **'معرّف النموذج'**
  String get aiChatModelCustomField;

  /// No description provided for @aiChatModelCustomHint.
  ///
  /// In ar, this message translates to:
  /// **'مثل claude-sonnet-5-5'**
  String get aiChatModelCustomHint;

  /// No description provided for @aiChatModelInvalid.
  ///
  /// In ar, this message translates to:
  /// **'معرّف غير صالح.'**
  String get aiChatModelInvalid;

  /// No description provided for @aiChatModelUse.
  ///
  /// In ar, this message translates to:
  /// **'استخدام'**
  String get aiChatModelUse;

  /// No description provided for @aiChatModelRefresh.
  ///
  /// In ar, this message translates to:
  /// **'تحديث قائمة النماذج'**
  String get aiChatModelRefresh;

  /// No description provided for @aiChatModelRefreshed.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا نماذج متاحة} =1{نموذج واحد متاح} =2{نموذجان متاحان} few{{count} نماذج متاحة} many{{count} نموذجًا متاحًا} other{{count} نموذج متاح}}'**
  String aiChatModelRefreshed(int count);

  /// No description provided for @aiChatModelRefreshNote.
  ///
  /// In ar, this message translates to:
  /// **'يطلب القائمة من {service} حين تضغط فقط.'**
  String aiChatModelRefreshNote(String service);

  /// No description provided for @aiChatModelReset.
  ///
  /// In ar, this message translates to:
  /// **'استعادة القائمة الأصلية'**
  String get aiChatModelReset;

  /// No description provided for @aiChatModelRemove.
  ///
  /// In ar, this message translates to:
  /// **'إزالة {model} من القائمة'**
  String aiChatModelRemove(String model);

  /// No description provided for @aiChatModelSelected.
  ///
  /// In ar, this message translates to:
  /// **'المختار'**
  String get aiChatModelSelected;

  /// No description provided for @aiChatModelChip.
  ///
  /// In ar, this message translates to:
  /// **'النموذج: {model}. انقر للتغيير'**
  String aiChatModelChip(String model);

  /// No description provided for @aiChatSettingsReply.
  ///
  /// In ar, this message translates to:
  /// **'الرد'**
  String get aiChatSettingsReply;

  /// No description provided for @aiChatMaxTokens.
  ///
  /// In ar, this message translates to:
  /// **'أقصى طول للرد'**
  String get aiChatMaxTokens;

  /// No description provided for @aiChatMaxTokensNote.
  ///
  /// In ar, this message translates to:
  /// **'بالرموز، ويشمل تفكير النموذج إن وُجد.'**
  String get aiChatMaxTokensNote;

  /// No description provided for @aiChatTemperature.
  ///
  /// In ar, this message translates to:
  /// **'درجة الحرارة'**
  String get aiChatTemperature;

  /// No description provided for @aiChatTemperatureDefault.
  ///
  /// In ar, this message translates to:
  /// **'افتراضي النموذج (موصى به)'**
  String get aiChatTemperatureDefault;

  /// No description provided for @aiChatTemperatureNote.
  ///
  /// In ar, this message translates to:
  /// **'النماذج الأحدث لا تقبل إلا القيمة الافتراضية. قيمة أقل = ردود أثبت.'**
  String get aiChatTemperatureNote;

  /// No description provided for @aiChatSettingsPrivacy.
  ///
  /// In ar, this message translates to:
  /// **'الخصوصية'**
  String get aiChatSettingsPrivacy;

  /// No description provided for @aiChatPrivacyKeys.
  ///
  /// In ar, this message translates to:
  /// **'المفاتيح في التخزين المشفّر للهاتف، لا في قاعدة البيانات ولا في النسخ الاحتياطية أو التصدير.'**
  String get aiChatPrivacyKeys;

  /// No description provided for @aiChatPrivacyCalls.
  ///
  /// In ar, this message translates to:
  /// **'لا يتصل التطبيق بالخدمة إلا حين تضغط «إرسال» أو «إعادة كتابة الرد» أو «إعادة المحاولة» أو «اختبار المفتاح» أو «تحديث قائمة النماذج». لا شيء في الخلفية.'**
  String get aiChatPrivacyCalls;

  /// No description provided for @aiChatPrivacyHistory.
  ///
  /// In ar, this message translates to:
  /// **'تُحفظ المحادثات مشفّرة على هاتفك (آخر {count})، مع الملخّص الذي وافقت عليه لكل محادثة. وتدخل في نسختك الاحتياطية وفي تصدير بياناتك الكامل.'**
  String aiChatPrivacyHistory(String count);

  /// No description provided for @aiChatKeyProblemChars.
  ///
  /// In ar, this message translates to:
  /// **'في المفتاح رموز لا تكون في المفاتيح (ربما من النسخ)؛ انسخه مرة أخرى.'**
  String get aiChatKeyProblemChars;

  /// Sheet shown before a link in an AI reply opens
  ///
  /// In ar, this message translates to:
  /// **'فتح هذا الرابط؟'**
  String get aiChatLinkTitle;

  /// No description provided for @aiChatLinkBody.
  ///
  /// In ar, this message translates to:
  /// **'يُفتح خارج مَدار، وكل ما في العنوان يصل إلى ذلك الموقع. افتحه فقط إن كنت تثق به.'**
  String get aiChatLinkBody;

  /// No description provided for @aiChatLinkOpen.
  ///
  /// In ar, this message translates to:
  /// **'فتح الرابط'**
  String get aiChatLinkOpen;
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
