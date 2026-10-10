/// The health rule of the AI bridge, in one place.
///
/// A suggestion may only ever be something to **track** or to **practise**.
/// It may never be a diagnosis, a treatment, a medicine, a dose, or a nudge
/// to start, stop or change a medicine. Nothing in Madar diagnoses and
/// nothing in Madar treats – not the app, and not an AI the owner asked.
///
/// The guard reads every text of every item (title, reason, evidence and
/// every string inside `data`), of **every kind**: a dose hidden in a task
/// title is still a dose. A hit rejects that one item with the word it hit
/// on, so he sees exactly why.
///
/// It is deliberately a small, explicit lexicon rather than anything clever:
/// a false alarm costs one refused suggestion he can ask for again in other
/// words, while a miss would put a dose in his data.
///
/// Pure Dart.
library;

import 'package:meta/meta.dart';

/// Why the guard refused.
enum HealthFlagKind {
  /// Names a diagnosis or claims to tell him what he has.
  diagnosis,

  /// Claims to treat, cure or fix an illness.
  treatment,

  /// Names a medicine, a supplement regimen or an injection.
  medicine,

  /// Carries a dose or a strength.
  dose,

  /// Tells him to start, stop or change a medicine.
  medicationChange,
}

/// One hit: what kind, and the exact text it matched.
@immutable
class HealthFlag {
  const HealthFlag(this.kind, this.match);

  final HealthFlagKind kind;

  /// The word or number+unit the guard matched, for the plain-Arabic reason.
  final String match;

  @override
  String toString() => 'HealthFlag(${kind.name}, $match)';
}

abstract final class HealthGuard {
  // Arabic is folded first (diacritics removed, alef/yeh/teh-marbuta
  // unified) and Arabic-Indic digits folded to Western, so «جرعة» and
  // «جُرعة», «٦٠٠ ملغ» and «600 mg» all match.

  static const List<String> _diagnosis = [
    'تشخيص',
    'مشخص',
    'انت مصاب',
    'عندك مرض',
    'عندك التهاب',
    'هاد مرض',
    'مرضك',
    'حالتك المرضيه',
    'diagnos',
    'you have diabetes',
    'you have hypertension',
    'likely cause of your illness',
  ];

  static const List<String> _treatment = [
    'يعالج',
    'بيعالج',
    'علاج المرض',
    'العلاج هو',
    'يشفي',
    'بيشفي',
    'شفاء تام',
    'يقضي على المرض',
    'cure',
    'cures',
    'treats',
    'treatment for',
    'therapy for',
    'heals',
  ];

  static const List<String> _medicine = [
    'دواء',
    'ادويه',
    'مضاد حيوي',
    'كبسوله',
    'كبسولات',
    'حبوب دوا',
    'ابره',
    'حقنه',
    'امبول',
    'تحميله',
    'مكمل غذاي',
    'مجم',
    'ميكروغرام',
    'وحده دوليه',
    'antibiotic',
    'capsule',
    'capsules',
    'injection',
    'ampoule',
    'supplement stack',
    'prescription',
    'prescribe',
  ];

  static const List<String> _medicationChange = [
    'اوقف الدوا',
    'وقف الدوا',
    'بلاش دوا',
    'استغني عن الدوا',
    'بدل الدوا',
    'زيد الجرعه',
    'قلل الجرعه',
    'بدون دوا',
    'stop taking',
    'stop your medication',
    'change your dose',
    'increase the dose',
    'reduce your medication',
    'off your meds',
  ];

  /// Dose words on their own (no number needed).
  static const List<String> _doseWords = ['جرعه', 'جرعات', 'الجرعه', 'dosage', 'dose', 'doses', 'mg/kg', 'iu/day'];

  /// Number + strength unit: `600 mg`, `٦٠٠ ملغ`, `5000 IU`, `10 mcg`.
  /// `\b` is ASCII-only, so Arabic units get their own pattern (no word
  /// boundary) and Latin ones a lookahead instead.
  static final RegExp _doseAmount = RegExp(
    r'(\d+(?:[.,]\d+)?)\s*(?:(?:mg|mcg|iu)(?![a-z])|ملغم|ملغ|مجم|ميكروغرام|وحده دوليه)',
  );

  static final RegExp _arabicMarks = RegExp('[ً-ٰٟـۖ-ۭ]');

  /// Folds Arabic spelling and digits so the lexicon can stay short:
  /// diacritics and tatweel dropped, `أإآٱ→ا`, `ة→ه`, `ى→ي`, `ؤ→و`,
  /// `ئ→ي`, Arabic-Indic digits → Western, lower-cased, whitespace
  /// collapsed.
  static String fold(String input) {
    final out = StringBuffer();
    for (final c in input.replaceAll(_arabicMarks, '').toLowerCase().codeUnits) {
      out.writeCharCode(switch (c) {
        0x0623 || 0x0625 || 0x0622 || 0x0671 => 0x0627,
        0x0629 => 0x0647,
        0x0649 => 0x064A,
        0x0624 => 0x0648,
        0x0626 => 0x064A,
        >= 0x0660 && <= 0x0669 => c - 0x0660 + 0x30,
        >= 0x06F0 && <= 0x06F9 => c - 0x06F0 + 0x30,
        _ => c,
      });
    }
    return out.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// The first thing wrong with [texts], or null when every one of them is
  /// tracking-and-practising talk.
  static HealthFlag? scan(Iterable<String> texts) {
    for (final raw in texts) {
      final flag = scanOne(raw);
      if (flag != null) return flag;
    }
    return null;
  }

  static HealthFlag? scanOne(String raw) {
    if (raw.trim().isEmpty) return null;
    final text = fold(raw);
    final amount = _doseAmount.firstMatch(text);
    if (amount != null) return HealthFlag(HealthFlagKind.dose, amount[0]!.trim());
    for (final w in _doseWords) {
      if (text.contains(w)) return HealthFlag(HealthFlagKind.dose, w);
    }
    for (final w in _medicationChange) {
      if (text.contains(w)) return HealthFlag(HealthFlagKind.medicationChange, w);
    }
    for (final w in _diagnosis) {
      if (text.contains(w)) return HealthFlag(HealthFlagKind.diagnosis, w);
    }
    for (final w in _treatment) {
      if (text.contains(w)) return HealthFlag(HealthFlagKind.treatment, w);
    }
    for (final w in _medicine) {
      if (text.contains(w)) return HealthFlag(HealthFlagKind.medicine, w);
    }
    return null;
  }
}
