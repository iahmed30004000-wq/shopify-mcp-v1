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
}
