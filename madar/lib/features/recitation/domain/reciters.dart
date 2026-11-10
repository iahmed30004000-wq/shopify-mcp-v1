import 'package:meta/meta.dart';

import '../../../core/quran/ayah.dart';

/// How a recitation is performed.
enum ReciterStyle {
  /// Mujawwad – slow, melodic, with the full tajweed ornaments.
  mujawwad,

  /// Murattal – measured, flowing recitation.
  murattal,

  /// Muʿallim – the teaching recitation (clear and slow, made for learning
  /// by heart).
  muallim;

  /// Rough full-mushaf length, for the download size estimate only.
  Duration get approxMushafLength => switch (this) {
    ReciterStyle.murattal => const Duration(hours: 20),
    ReciterStyle.mujawwad => const Duration(hours: 40),
    ReciterStyle.muallim => const Duration(hours: 50),
  };
}

/// A human reciter's recording on everyayah.com (per-ayah MP3 files). Madar
/// never uses generated voices for the Quran.
@immutable
class Reciter {
  const Reciter({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.style,
    required this.folder,
    required this.bitrate,
  });

  /// Stable id stored in settings (`husary.mujawwad`).
  final String id;
  final String nameAr;
  final String nameEn;
  final ReciterStyle style;

  /// everyayah.com data folder (`Husary_128kbps_Mujawwad`).
  final String folder;

  /// kbit/s of the files.
  final int bitrate;

  String name({required bool arabic}) => arabic ? nameAr : nameEn;

  /// Approximate size of the whole mushaf in bytes (estimate).
  int get approxMushafBytes => style.approxMushafLength.inSeconds * bitrate * 1000 ~/ 8;

  @override
  bool operator ==(Object other) => other is Reciter && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Reciter($id)';
}

/// The reciters Madar offers. Every [Reciter.folder] was checked against two
/// published copies of everyayah.com's recitation list (risan/quran-json
/// `data/audio/everyayah.json` and Alfanous `configs/recitations.json`);
/// those marked "list 1" appear only in the first, newer copy.
abstract final class Reciters {
  static const abdulBasitMujawwad = Reciter(
    id: 'abdulbasit.mujawwad',
    nameAr: 'عبد الباسط عبد الصمد',
    nameEn: 'Abdul Basit Abdus-Samad',
    style: ReciterStyle.mujawwad,
    folder: 'Abdul_Basit_Mujawwad_128kbps',
    bitrate: 128,
  );
  static const minshawiMujawwad = Reciter(
    id: 'minshawi.mujawwad',
    nameAr: 'محمد صدّيق المنشاوي',
    nameEn: 'Mohamed Siddiq al-Minshawi',
    style: ReciterStyle.mujawwad,
    folder: 'Minshawy_Mujawwad_192kbps',
    bitrate: 192,
  );
  static const husaryMujawwad = Reciter(
    id: 'husary.mujawwad',
    nameAr: 'محمود خليل الحصري',
    nameEn: 'Mahmoud Khalil al-Husary',
    style: ReciterStyle.mujawwad,
    folder: 'Husary_128kbps_Mujawwad',
    bitrate: 128,
  );
  static const abdulBasitMurattal = Reciter(
    id: 'abdulbasit.murattal',
    nameAr: 'عبد الباسط عبد الصمد',
    nameEn: 'Abdul Basit Abdus-Samad',
    style: ReciterStyle.murattal,
    folder: 'Abdul_Basit_Murattal_192kbps',
    bitrate: 192,
  );
  static const minshawiMurattal = Reciter(
    id: 'minshawi.murattal',
    nameAr: 'محمد صدّيق المنشاوي',
    nameEn: 'Mohamed Siddiq al-Minshawi',
    style: ReciterStyle.murattal,
    folder: 'Minshawy_Murattal_128kbps',
    bitrate: 128,
  );
  static const husaryMurattal = Reciter(
    id: 'husary.murattal',
    nameAr: 'محمود خليل الحصري',
    nameEn: 'Mahmoud Khalil al-Husary',
    style: ReciterStyle.murattal,
    folder: 'Husary_128kbps',
    bitrate: 128,
  );

  /// list 1.
  static const husaryMuallim = Reciter(
    id: 'husary.muallim',
    nameAr: 'محمود خليل الحصري',
    nameEn: 'Mahmoud Khalil al-Husary',
    style: ReciterStyle.muallim,
    folder: 'Husary_Muallim_128kbps',
    bitrate: 128,
  );
  static const alafasy = Reciter(
    id: 'alafasy',
    nameAr: 'مشاري راشد العفاسي',
    nameEn: 'Mishary Rashid Alafasy',
    style: ReciterStyle.murattal,
    folder: 'Alafasy_128kbps',
    bitrate: 128,
  );
  static const sudais = Reciter(
    id: 'sudais',
    nameAr: 'عبد الرحمن السديس',
    nameEn: 'Abdul Rahman al-Sudais',
    style: ReciterStyle.murattal,
    folder: 'Abdurrahmaan_As-Sudais_192kbps',
    bitrate: 192,
  );
  static const shuraim = Reciter(
    id: 'shuraim',
    nameAr: 'سعود الشريم',
    nameEn: 'Saud al-Shuraim',
    style: ReciterStyle.murattal,
    folder: 'Saood_ash-Shuraym_128kbps',
    bitrate: 128,
  );
  static const muaiqly = Reciter(
    id: 'muaiqly',
    nameAr: 'ماهر المعيقلي',
    nameEn: 'Maher al-Muaiqly',
    style: ReciterStyle.murattal,
    folder: 'MaherAlMuaiqly128kbps',
    bitrate: 128,
  );
  static const shatri = Reciter(
    id: 'shatri',
    nameAr: 'أبو بكر الشاطري',
    nameEn: 'Abu Bakr al-Shatri',
    style: ReciterStyle.murattal,
    folder: 'Abu_Bakr_Ash-Shaatree_128kbps',
    bitrate: 128,
  );
  static const hudhaifi = Reciter(
    id: 'hudhaifi',
    nameAr: 'علي الحذيفي',
    nameEn: 'Ali al-Hudhaifi',
    style: ReciterStyle.murattal,
    folder: 'Hudhaify_128kbps',
    bitrate: 128,
  );
  static const ayyub = Reciter(
    id: 'ayyub',
    nameAr: 'محمد أيوب',
    nameEn: 'Muhammad Ayyub',
    style: ReciterStyle.murattal,
    folder: 'Muhammad_Ayyoub_128kbps',
    bitrate: 128,
  );

  /// list 1.
  static const dosari = Reciter(
    id: 'dosari',
    nameAr: 'ياسر الدوسري',
    nameEn: 'Yasser al-Dosari',
    style: ReciterStyle.murattal,
    folder: 'Yasser_Ad-Dussary_128kbps',
    bitrate: 128,
  );
  static const jibreel = Reciter(
    id: 'jibreel',
    nameAr: 'محمد جبريل',
    nameEn: 'Muhammad Jibreel',
    style: ReciterStyle.murattal,
    folder: 'Muhammad_Jibreel_128kbps',
    bitrate: 128,
  );
  static const basfar = Reciter(
    id: 'basfar',
    nameAr: 'عبد الله بصفر',
    nameEn: 'Abdullah Basfar',
    style: ReciterStyle.murattal,
    folder: 'Abdullah_Basfar_192kbps',
    bitrate: 192,
  );

  /// list 1.
  static const qatami = Reciter(
    id: 'qatami',
    nameAr: 'ناصر القطامي',
    nameEn: 'Nasser al-Qatami',
    style: ReciterStyle.murattal,
    folder: 'Nasser_Alqatami_128kbps',
    bitrate: 128,
  );
  static const ghamdi = Reciter(
    id: 'ghamdi',
    nameAr: 'سعد الغامدي',
    nameEn: 'Saad al-Ghamdi',
    style: ReciterStyle.murattal,
    folder: 'Ghamadi_40kbps',
    bitrate: 40,
  );

  /// In display order: the mujawwad masters first, then murattal.
  static const List<Reciter> all = [
    abdulBasitMujawwad,
    minshawiMujawwad,
    husaryMujawwad,
    abdulBasitMurattal,
    minshawiMurattal,
    husaryMurattal,
    husaryMuallim,
    alafasy,
    sudais,
    shuraim,
    muaiqly,
    shatri,
    hudhaifi,
    ayyub,
    dosari,
    jibreel,
    basfar,
    qatami,
    ghamdi,
  ];

  static const Reciter fallback = abdulBasitMujawwad;

  static Reciter? byIdOrNull(String? id) {
    for (final r in all) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// [id]'s reciter, or [fallback] for an unknown id.
  static Reciter byId(String? id) => byIdOrNull(id) ?? fallback;
}

/// everyayah.com's file conventions.
abstract final class EveryAyah {
  static const String host = 'everyayah.com';

  /// `https://everyayah.com/data/<folder>/<SSSAAA>.mp3`.
  static Uri urlFor(Reciter reciter, AyahRef ayah) => Uri.https(host, '/data/${reciter.folder}/${fileName(ayah)}');

  /// `002255.mp3`.
  static String fileName(AyahRef ayah) => '${ayah.fileKey}.mp3';

  /// The file recited as the basmala before other surahs: al-Fatihah's
  /// first ayah (everyayah has no separate basmala file).
  static const AyahRef basmala = AyahRef(1, 1);

  /// Whether a surah opens with a recited basmala that is not one of its
  /// numbered ayat: every surah but al-Fatihah (where it is ayah 1) and
  /// at-Tawbah (which has none).
  static bool surahNeedsBasmala(int surah) => surah != 1 && surah != 9;
}
