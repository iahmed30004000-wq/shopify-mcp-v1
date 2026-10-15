import 'package:meta/meta.dart';

/// Madar's own procedurally synthesised "tanbih" (alert) tones – struck
/// bowls, bells and chimes, never a voice and never a melody imitating the
/// adhan. Rendered by `TanbihSynth` (lib/features/adhan/sound/) into
/// `android/app/src/main/res/raw/<rawName>.wav` by
/// `dart run tool/generate_adhan_tones.dart`, and at run time for in-app
/// previews.
enum TanbihTone {
  /// Dawn: a soft crystal glow rising over a warm drone – for Fajr.
  dawn('madar_tanbih_dawn', Duration(milliseconds: 16300)),

  /// Astrolabe brass: two neutral-third bell pairs, like a quiet tower clock.
  brass('madar_tanbih_brass', Duration(milliseconds: 15500)),

  /// Serenity: three singing-bowl strikes in a slow fifth.
  bowl('madar_tanbih_bowl', Duration(milliseconds: 16300)),

  /// Short two-note glass chime for pre-adhan reminders.
  chime('madar_tanbih_chime', Duration(milliseconds: 2400)),

  /// Short rising crystal pair for the sunrise alert.
  sunrise('madar_tanbih_sunrise', Duration(milliseconds: 2100));

  const TanbihTone(this.rawName, this.length);

  /// Raw resource name (file name without `.wav`).
  final String rawName;

  /// Approximate rendered length (tail included).
  final Duration length;

  /// The tones offered as a muezzin replacement (long calls).
  static const calls = [dawn, brass, bowl];

  static TanbihTone? byName(Object? name) {
    for (final t in values) {
      if (t.name == name) return t;
    }
    return null;
  }
}

enum AdhanSoundKind { tone, file, silent }

/// Which sound an adhan plays: a built-in [TanbihTone], a recording the user
/// attached ([CustomMuezzin]), or silence (visual + vibration only).
@immutable
class AdhanSoundRef {
  const AdhanSoundRef._(this.kind, this.id);

  const AdhanSoundRef.tone(TanbihTone tone) : this._(AdhanSoundKind.tone, tone);

  /// A user-attached recording ([CustomMuezzin.id]).
  const AdhanSoundRef.file(String id) : this._(AdhanSoundKind.file, id);

  const AdhanSoundRef.silent() : this._(AdhanSoundKind.silent, null);

  final AdhanSoundKind kind;

  /// A [TanbihTone] or a custom file id.
  final Object? id;

  TanbihTone? get tone => kind == AdhanSoundKind.tone ? id as TanbihTone : null;
  String? get fileId => kind == AdhanSoundKind.file ? id as String : null;

  /// Stable string form (`tone:dawn`, `file:<id>`, `silent`) – stored in
  /// settings and part of the channel id.
  String get key => switch (kind) {
    AdhanSoundKind.tone => 'tone:${(id as TanbihTone).name}',
    AdhanSoundKind.file => 'file:$id',
    AdhanSoundKind.silent => 'silent',
  };

  static AdhanSoundRef? parse(Object? raw) {
    if (raw is! String) return null;
    if (raw == 'silent') return const AdhanSoundRef.silent();
    final i = raw.indexOf(':');
    if (i <= 0) return null;
    final head = raw.substring(0, i), tail = raw.substring(i + 1);
    switch (head) {
      case 'tone':
        final t = TanbihTone.byName(tail);
        return t == null ? null : AdhanSoundRef.tone(t);
      case 'file':
        return tail.isEmpty || !CustomMuezzin.isValidId(tail) ? null : AdhanSoundRef.file(tail);
    }
    return null;
  }

  @override
  bool operator ==(Object other) => other is AdhanSoundRef && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);

  @override
  String toString() => 'AdhanSoundRef($key)';
}

/// A recording the user attached (their own muezzin): copied into Madar's
/// private sound folder, played in-app with flutter_soloud and by the system
/// through Madar's sound provider for the notification channel.
@immutable
class CustomMuezzin {
  const CustomMuezzin({
    required this.id,
    required this.name,
    required this.fileName,
    this.length,
    required this.addedAt,
  });

  /// Lower-case letters and digits only (part of a channel id and a file
  /// name).
  final String id;

  /// User-editable display name (defaults to the picked file's name).
  final String name;

  /// File name inside the sound folder (`<id>.<ext>`).
  final String fileName;

  /// Length when it could be read from the file.
  final Duration? length;
  final DateTime addedAt;

  static final _idPattern = RegExp(r'^[a-z0-9]{4,40}$');

  static bool isValidId(String id) => _idPattern.hasMatch(id);

  String get extension {
    final dot = fileName.lastIndexOf('.');
    return dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
  }

  /// flutter_soloud decodes these in-app (Madar ships it without the Xiph
  /// codecs); other formats still play as the notification sound.
  bool get playableInApp => extension == 'mp3' || extension == 'wav';

  CustomMuezzin copyWith({String? name, Duration? length}) => CustomMuezzin(
    id: id,
    name: name ?? this.name,
    fileName: fileName,
    length: length ?? this.length,
    addedAt: addedAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'fileName': fileName,
    if (length != null) 'lengthMs': length!.inMilliseconds,
    'addedAt': addedAt.toUtc().toIso8601String(),
  };

  static CustomMuezzin? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'], name = raw['name'], file = raw['fileName'];
    if (id is! String || !isValidId(id) || name is! String || file is! String) return null;
    if (file.contains('/') || file.contains('\\') || !file.startsWith(id)) return null;
    final ms = raw['lengthMs'];
    return CustomMuezzin(
      id: id,
      name: name,
      fileName: file,
      length: ms is int && ms > 0 ? Duration(milliseconds: ms) : null,
      addedAt: DateTime.tryParse('${raw['addedAt']}')?.toUtc() ?? DateTime.utc(2026),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CustomMuezzin &&
      other.id == id &&
      other.name == name &&
      other.fileName == fileName &&
      other.length == length &&
      other.addedAt == addedAt;

  @override
  int get hashCode => Object.hash(id, name, fileName, length, addedAt);
}
