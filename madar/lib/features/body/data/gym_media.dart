/// The machine's picture and the movement's video, and the one rule that
/// tells them apart: **a picture is copied in, a video never is.**
///
/// `exercises.photo` holds a **file name only** (`a1b2c3d4.jpg`), never a
/// path into the gallery: the picked image is copied into Madar's own
/// private folder the moment he picks it, so deleting the original later
/// changes nothing and the picture travels with the backup. This is the
/// same contract as the dish photos of «السفرة»
/// (`features/sufra/data/recipe_photos.dart`); it is written again here,
/// against its own folder, rather than reaching across into the kitchen's
/// files for a ten-line picker.
///
/// `exercises.video` holds **where the clip is**, exactly as he gave it: a
/// link, or a path to his own file on the phone. It is deliberately not
/// copied. One clip of a movement is tens to hundreds of megabytes; copying
/// it would double what the phone holds for no gain and would put the same
/// weight into every backup file. So Madar remembers the place, shows the
/// clip's name, and says plainly when the file is no longer there.
///
/// Nothing in here touches the network, reads metadata, or looks at any
/// other picture or video on the phone.
library;

import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;

/// A file he picked.
@immutable
class PickedGymFile {
  const PickedGymFile({required this.name, required this.read, this.path});

  /// File name as the picker reports it (with its extension).
  final String name;

  /// Where it sits on the phone, when the picker says (a video keeps this
  /// and nothing else).
  final String? path;
  final Future<Uint8List> Function() read;
}

/// Opens the system picker (file_picker in production).
abstract interface class GymFilePicker {
  Future<PickedGymFile?> pickImage();

  Future<PickedGymFile?> pickVideo();
}

class SystemGymFilePicker implements GymFilePicker {
  const SystemGymFilePicker();

  Future<PickedGymFile?> _pick(FileType type) async {
    final file = await FilePicker.pickFile(type: type);
    if (file == null) return null;
    return PickedGymFile(name: file.name, path: file.path, read: file.readAsBytes);
  }

  @override
  Future<PickedGymFile?> pickImage() => _pick(FileType.image);

  @override
  Future<PickedGymFile?> pickVideo() => _pick(FileType.video);
}

/// Why a picture did not make it in.
enum GymMediaError {
  /// He closed the picker.
  cancelled,

  /// Not a picture Madar can show.
  unsupported,

  /// Bigger than [GymMedia.maxPhotoBytes].
  tooLarge,

  /// The file could not be read or written.
  unreadable,

  /// The picker gave no path, so there is nothing to remember (a video).
  noPath,
}

/// The outcome of a pick.
@immutable
class GymMediaResult {
  const GymMediaResult.ok(String this.value) : error = null;
  const GymMediaResult.failed(GymMediaError this.error) : value = null;

  /// What to store on the exercise: a file name for a photo, a path or a
  /// link for a video.
  final String? value;
  final GymMediaError? error;

  bool get ok => value != null;
}

/// What a stored `exercises.video` turns out to be.
enum GymVideoKind {
  /// `https://…` – a link he pasted.
  link,

  /// A path to his own file on the phone.
  file,
}

/// A stored video: what it is, and the name worth showing.
@immutable
class GymVideo {
  const GymVideo({required this.raw, required this.kind});

  final String raw;
  final GymVideoKind kind;

  /// Reads a stored value. Null for nothing stored. A value that begins
  /// with `http://`, `https://` or looks like `host/path` is a link;
  /// anything else is taken as a path on the phone.
  static GymVideo? parse(String? stored) {
    final s = stored?.trim();
    if (s == null || s.isEmpty) return null;
    final lower = s.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return GymVideo(raw: s, kind: GymVideoKind.link);
    }
    if (!s.startsWith('/') && !s.contains(r'\')) {
      final slash = s.indexOf('/');
      final host = slash < 0 ? s : s.substring(0, slash);
      if (host.contains('.') && !host.contains(' ')) return GymVideo(raw: 'https://$s', kind: GymVideoKind.link);
    }
    return GymVideo(raw: s, kind: GymVideoKind.file);
  }

  /// The last part of a path, or the host of a link: what is worth reading
  /// on a one-line row.
  String get label {
    if (kind == GymVideoKind.link) {
      final uri = Uri.tryParse(raw);
      final host = uri?.host ?? '';
      return host.isEmpty ? raw : host;
    }
    final parts = raw.split(RegExp(r'[/\\]'));
    return parts.isEmpty ? raw : parts.last;
  }

  Uri get uri => kind == GymVideoKind.link ? Uri.parse(raw) : Uri.file(raw);

  /// Whether a stored file is still on the phone. Always true for a link
  /// (Madar never goes near the network to find out).
  bool get exists => kind == GymVideoKind.link || File(raw).existsSync();
}

/// Madar's own folder of machine pictures: copying one in, resolving one to
/// a file, and deleting the ones a deleted exercise took with it.
class GymMedia {
  GymMedia({this.picker = const SystemGymFilePicker(), Future<Directory> Function()? directory, Random? random})
    : _directory = directory ?? _supportDirectory,
      _random = random ?? Random.secure();

  /// A store over one folder (tests).
  factory GymMedia.at(Directory dir, {GymFilePicker picker = const SystemGymFilePicker(), Random? random}) =>
      GymMedia(picker: picker, directory: () async => dir, random: random);

  final GymFilePicker picker;
  final Future<Directory> Function() _directory;
  final Random _random;

  /// What Android and Flutter can both show without a plugin.
  static const Set<String> photoExtensions = {'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'heic'};

  /// A machine picture is a phone photo: a few megabytes.
  static const int maxPhotoBytes = 12 * 1024 * 1024;

  static Future<Directory> _supportDirectory() async =>
      Directory('${(await getApplicationSupportDirectory()).path}/gym_photos');

  /// The folder, created if it is not there yet.
  Future<Directory> folder() async {
    final dir = await _directory();
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// The lower-case extension of [name] when Madar can show it, else null.
  static String? photoExtensionOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return null;
    final ext = name.substring(dot + 1).toLowerCase();
    return photoExtensions.contains(ext) ? ext : null;
  }

  String _newName(String ext) {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final id = String.fromCharCodes([
      for (var i = 0; i < 12; i++) alphabet.codeUnitAt(_random.nextInt(alphabet.length)),
    ]);
    return '$id.$ext';
  }

  /// Picks a picture of the machine and copies it in. The caller stores the
  /// returned file name on the exercise.
  Future<GymMediaResult> pickPhoto() async {
    final PickedGymFile? picked;
    try {
      picked = await picker.pickImage();
    } on Object catch (e) {
      debugPrint('GymMedia: picker failed: $e');
      return const GymMediaResult.failed(GymMediaError.unreadable);
    }
    if (picked == null) return const GymMediaResult.failed(GymMediaError.cancelled);
    return importPhoto(picked);
  }

  /// Copies [picked] into the folder under a fresh name.
  Future<GymMediaResult> importPhoto(PickedGymFile picked) async {
    final ext = photoExtensionOf(picked.name);
    if (ext == null) return const GymMediaResult.failed(GymMediaError.unsupported);
    final Uint8List bytes;
    try {
      bytes = await picked.read();
    } on Object catch (e) {
      debugPrint('GymMedia: read failed: $e');
      return const GymMediaResult.failed(GymMediaError.unreadable);
    }
    if (bytes.lengthInBytes > maxPhotoBytes) return const GymMediaResult.failed(GymMediaError.tooLarge);
    if (bytes.isEmpty) return const GymMediaResult.failed(GymMediaError.unreadable);
    try {
      final dir = await folder();
      final name = _newName(ext);
      File('${dir.path}/$name').writeAsBytesSync(bytes);
      return GymMediaResult.ok(name);
    } on Object catch (e) {
      debugPrint('GymMedia: write failed: $e');
      return const GymMediaResult.failed(GymMediaError.unreadable);
    }
  }

  /// Picks a video and returns **its path**, unread and uncopied — see the
  /// note at the top of this file.
  Future<GymMediaResult> pickVideo() async {
    final PickedGymFile? picked;
    try {
      picked = await picker.pickVideo();
    } on Object catch (e) {
      debugPrint('GymMedia: video picker failed: $e');
      return const GymMediaResult.failed(GymMediaError.unreadable);
    }
    if (picked == null) return const GymMediaResult.failed(GymMediaError.cancelled);
    final path = picked.path?.trim();
    if (path == null || path.isEmpty) return const GymMediaResult.failed(GymMediaError.noPath);
    return GymMediaResult.ok(path);
  }

  /// The file a stored photo name points at, or null while it is not there.
  /// A name with a separator in it is taken as a full path (a row that came
  /// in with a backup).
  Future<File?> photoFile(String stored) async {
    final name = stored.trim();
    if (name.isEmpty) return null;
    if (name.contains('/') || name.contains(r'\')) {
      final file = File(name);
      return file.existsSync() ? file : null;
    }
    final file = File('${(await folder()).path}/$name');
    return file.existsSync() ? file : null;
  }

  /// Deletes the pictures of [stored] – what a deleted exercise takes with
  /// it. A name Madar does not own (a full path from somewhere else) is
  /// left alone: it is not ours to delete. A video is never deleted: the
  /// file is his, in his own folder.
  Future<void> removePhotos(Iterable<String> stored) async {
    final dir = await folder();
    for (final name in stored) {
      final n = name.trim();
      if (n.isEmpty || n.contains('/') || n.contains(r'\')) continue;
      final file = File('${dir.path}/$n');
      try {
        if (file.existsSync()) file.deleteSync();
      } on Object catch (e) {
        debugPrint('GymMedia: delete failed: $e');
      }
    }
  }
}

/// Hands a video to whatever plays it on the phone. Tests record the call
/// instead of leaving the app.
abstract interface class GymVideoOpener {
  /// True when something took it.
  Future<bool> open(GymVideo video);
}

/// [GymVideoOpener] through url_launcher: a link goes to the browser or to
/// the app that owns it, a file to whatever plays videos. The phone may
/// refuse a file it has not been given access to; then this returns false
/// and the screen says so instead of pretending.
class UrlLauncherGymVideoOpener implements GymVideoOpener {
  const UrlLauncherGymVideoOpener();

  @override
  Future<bool> open(GymVideo video) async {
    try {
      return await launchUrl(video.uri, mode: LaunchMode.externalApplication);
    } on Object catch (e) {
      debugPrint('GymMedia: could not open the video: $e');
      return false;
    }
  }
}

/// Records what it was asked to open (tests, previews).
class RecordingGymVideoOpener implements GymVideoOpener {
  RecordingGymVideoOpener({this.succeed = true});

  final bool succeed;
  final List<GymVideo> opened = [];

  @override
  Future<bool> open(GymVideo video) async {
    opened.add(video);
    return succeed;
  }
}

/// Madar's folder of machine pictures (overridden by tests with a temp
/// folder and a scripted picker).
final gymMediaProvider = Provider<GymMedia>((ref) => GymMedia());

/// Hands a video to the phone (tests override it with
/// [RecordingGymVideoOpener]).
final gymVideoOpenerProvider = Provider<GymVideoOpener>((ref) => const UrlLauncherGymVideoOpener());
