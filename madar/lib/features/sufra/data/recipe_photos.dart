/// The photos she adds to a dish, as files of Madar's own.
///
/// `recipes.photos` holds **file names only** (`a1b2c3d4.jpg`), never a
/// path into the gallery and never a URL: the picked image is copied into
/// Madar's private folder the moment she picks it, so deleting the
/// original later changes nothing, and the dish's photos travel with the
/// backup instead of pointing at a file that may be gone.
///
/// Nothing in here touches the network, reads metadata or looks at any
/// other picture on the phone.
library;

import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// An image she picked.
@immutable
class PickedPhoto {
  const PickedPhoto({required this.name, required this.read});

  /// File name as the picker reports it (with its extension).
  final String name;
  final Future<Uint8List> Function() read;
}

/// Opens the system image picker (file_picker in production).
abstract interface class PhotoPicker {
  Future<PickedPhoto?> pick();
}

class SystemPhotoPicker implements PhotoPicker {
  const SystemPhotoPicker();

  @override
  Future<PickedPhoto?> pick() async {
    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null) return null;
    return PickedPhoto(name: file.name, read: file.readAsBytes);
  }
}

/// Why a photo did not make it in.
enum PhotoError {
  /// She closed the picker.
  cancelled,

  /// Not a picture Madar can show.
  unsupported,

  /// Bigger than [RecipePhotos.maxBytes].
  tooLarge,

  /// The file could not be read or written.
  unreadable,
}

/// The outcome of [RecipePhotos.pickAndImport].
@immutable
class PhotoImport {
  const PhotoImport.ok(String this.fileName) : error = null;
  const PhotoImport.failed(PhotoError this.error) : fileName = null;

  /// What to store in `recipes.photos`.
  final String? fileName;
  final PhotoError? error;

  bool get ok => fileName != null;
}

/// Madar's own folder of dish photos: copying one in, resolving one to a
/// file, and deleting the ones a dish took with it.
class RecipePhotos {
  RecipePhotos({this.picker = const SystemPhotoPicker(), Future<Directory> Function()? directory, Random? random})
    : _directory = directory ?? _supportDirectory,
      _random = random ?? Random.secure();

  /// A store over one folder (tests).
  factory RecipePhotos.at(Directory dir, {PhotoPicker picker = const SystemPhotoPicker(), Random? random}) =>
      RecipePhotos(picker: picker, directory: () async => dir, random: random);

  final PhotoPicker picker;
  final Future<Directory> Function() _directory;
  final Random _random;

  /// What Android and Flutter can both show without a plugin.
  static const Set<String> extensions = {'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'heic'};

  /// A dish photo is a phone photo: a few megabytes.
  static const int maxBytes = 12 * 1024 * 1024;

  static Future<Directory> _supportDirectory() async =>
      Directory('${(await getApplicationSupportDirectory()).path}/sufra_photos');

  /// The folder, created if it is not there yet.
  Future<Directory> folder() async {
    final dir = await _directory();
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// The lower-case extension of [name] when Madar can show it, else null.
  static String? extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return null;
    final ext = name.substring(dot + 1).toLowerCase();
    return extensions.contains(ext) ? ext : null;
  }

  String _newName(String ext) {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final id = String.fromCharCodes([
      for (var i = 0; i < 12; i++) alphabet.codeUnitAt(_random.nextInt(alphabet.length)),
    ]);
    return '$id.$ext';
  }

  /// Picks an image and copies it in. The caller stores the returned file
  /// name on the dish (`SufraService.setPhotos`).
  Future<PhotoImport> pickAndImport() async {
    final PickedPhoto? picked;
    try {
      picked = await picker.pick();
    } on Object catch (e) {
      debugPrint('RecipePhotos: picker failed: $e');
      return const PhotoImport.failed(PhotoError.unreadable);
    }
    if (picked == null) return const PhotoImport.failed(PhotoError.cancelled);
    return import(picked);
  }

  /// Copies [picked] into the folder under a fresh name.
  Future<PhotoImport> import(PickedPhoto picked) async {
    final ext = extensionOf(picked.name);
    if (ext == null) return const PhotoImport.failed(PhotoError.unsupported);
    final Uint8List bytes;
    try {
      bytes = await picked.read();
    } on Object catch (e) {
      debugPrint('RecipePhotos: read failed: $e');
      return const PhotoImport.failed(PhotoError.unreadable);
    }
    if (bytes.lengthInBytes > maxBytes) return const PhotoImport.failed(PhotoError.tooLarge);
    if (bytes.isEmpty) return const PhotoImport.failed(PhotoError.unreadable);
    try {
      final dir = await folder();
      final name = _newName(ext);
      File('${dir.path}/$name').writeAsBytesSync(bytes);
      return PhotoImport.ok(name);
    } on Object catch (e) {
      debugPrint('RecipePhotos: write failed: $e');
      return const PhotoImport.failed(PhotoError.unreadable);
    }
  }

  /// The file a stored photo name points at, or null while the folder has
  /// not been read yet. A name with a separator in it is taken as a full
  /// path (an older row, or one that came in with a backup).
  Future<File?> fileOf(String stored) async {
    final name = stored.trim();
    if (name.isEmpty) return null;
    if (name.contains('/') || name.contains(r'\')) {
      final file = File(name);
      return file.existsSync() ? file : null;
    }
    final file = File('${(await folder()).path}/$name');
    return file.existsSync() ? file : null;
  }

  /// Deletes the files of [stored] – what a deleted dish takes with it.
  /// A name Madar does not own (a full path from somewhere else) is left
  /// alone: it is not ours to delete.
  Future<void> remove(Iterable<String> stored) async {
    final dir = await folder();
    for (final name in stored) {
      final n = name.trim();
      if (n.isEmpty || n.contains('/') || n.contains(r'\')) continue;
      final file = File('${dir.path}/$n');
      try {
        if (file.existsSync()) file.deleteSync();
      } on Object catch (e) {
        debugPrint('RecipePhotos: delete failed: $e');
      }
    }
  }
}

/// Madar's folder of dish photos (overridden by tests with a temp folder
/// and a scripted picker).
final recipePhotosProvider = Provider<RecipePhotos>((ref) => RecipePhotos());
