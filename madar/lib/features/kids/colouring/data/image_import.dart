// Bringing a picture from the phone into a colouring page.
//
// Everything here stays on the device: no network client is ever created (a
// test installs an HttpOverrides that fails on any attempt), the picked file
// is only read, and the page is made from a downscaled copy.
//
// Accepts images only. The file is checked by what is INSIDE it (its first
// bytes), never by its name, and rejected softly when it is not a picture,
// is bigger than [kMaxImageBytes], or declares absurd dimensions.
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../domain/flood_fill.dart';
import '../domain/outline.dart';

/// The largest file accepted (a phone photo is a few megabytes).
const int kMaxImageBytes = 15 * 1024 * 1024;

/// The most pixels a file may declare (about 64 megapixels).
const int kMaxImagePixels = 64 * 1000 * 1000;

enum ImportError {
  /// The file is not a picture (by its content).
  notImage,

  /// Too many bytes, or too many pixels.
  tooBig,

  /// It looks like a picture but could not be opened.
  unreadable,
}

class ImportFailure implements Exception {
  const ImportFailure(this.error);
  final ImportError error;

  @override
  String toString() => 'ImportFailure($error)';
}

/// A file the parent picked.
@immutable
class PickedImage {
  const PickedImage({required this.name, required this.read, this.sizeBytes});

  final String name;
  final Future<Uint8List> Function() read;

  /// Size as the picker reports it, when it does: lets a huge file be refused
  /// before a single byte is read.
  final int? sizeBytes;
}

/// Opens the system picker for images (file_picker in production).
abstract interface class ColouringImagePicker {
  Future<PickedImage?> pick();
}

class SystemColouringImagePicker implements ColouringImagePicker {
  const SystemColouringImagePicker();

  @override
  Future<PickedImage?> pick() async {
    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null) return null;
    return PickedImage(name: file.name, read: file.readAsBytes, sizeBytes: file.lengthSync());
  }
}

enum ImageKind {
  png('png'),
  jpeg('jpg'),
  gif('gif'),
  webp('webp'),
  bmp('bmp');

  const ImageKind(this.extension);
  final String extension;
}

@immutable
class ImageHeader {
  const ImageHeader(this.kind, {this.width, this.height});

  final ImageKind kind;

  /// Declared size, when the header could be read.
  final int? width, height;
}

/// What the first bytes say the file is, or null when it is not a picture.
ImageHeader? sniffImage(Uint8List b) {
  bool at(int o, List<int> sig) {
    if (b.length < o + sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (b[o + i] != sig[i]) return false;
    }
    return true;
  }

  int be32(int o) => b[o] << 24 | b[o + 1] << 16 | b[o + 2] << 8 | b[o + 3];
  int le16(int o) => b[o] | b[o + 1] << 8;
  int le32(int o) => b[o] | b[o + 1] << 8 | b[o + 2] << 16 | b[o + 3] << 24;

  if (at(0, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    if (b.length >= 24 && at(12, const [0x49, 0x48, 0x44, 0x52])) {
      return ImageHeader(ImageKind.png, width: be32(16), height: be32(20));
    }
    return const ImageHeader(ImageKind.png);
  }
  if (at(0, const [0xFF, 0xD8, 0xFF])) {
    // Walk the segments to the first start-of-frame marker.
    var i = 2;
    while (i + 9 < b.length) {
      if (b[i] != 0xFF) {
        i++;
        continue;
      }
      final m = b[i + 1];
      if (m == 0xFF) {
        i++;
        continue;
      }
      if (m == 0xD8 || m == 0x01 || (m >= 0xD0 && m <= 0xD7)) {
        i += 2;
        continue;
      }
      final len = b[i + 2] << 8 | b[i + 3];
      final isSof = m >= 0xC0 && m <= 0xCF && m != 0xC4 && m != 0xC8 && m != 0xCC;
      if (isSof) {
        return ImageHeader(ImageKind.jpeg, height: b[i + 5] << 8 | b[i + 6], width: b[i + 7] << 8 | b[i + 8]);
      }
      if (len < 2) break;
      i += 2 + len;
    }
    return const ImageHeader(ImageKind.jpeg);
  }
  if (at(0, const [0x47, 0x49, 0x46, 0x38]) && b.length >= 10 && (b[4] == 0x37 || b[4] == 0x39) && b[5] == 0x61) {
    return ImageHeader(ImageKind.gif, width: le16(6), height: le16(8));
  }
  if (at(0, const [0x42, 0x4D]) && b.length >= 26) {
    final w = le32(18);
    final h = le32(22).abs();
    return ImageHeader(ImageKind.bmp, width: w, height: h);
  }
  if (at(0, const [0x52, 0x49, 0x46, 0x46]) && at(8, const [0x57, 0x45, 0x42, 0x50])) {
    if (at(12, const [0x56, 0x50, 0x38, 0x58]) && b.length >= 30) {
      final w = 1 + (b[24] | b[25] << 8 | b[26] << 16);
      final h = 1 + (b[27] | b[28] << 8 | b[29] << 16);
      return ImageHeader(ImageKind.webp, width: w, height: h);
    }
    if (at(12, const [0x56, 0x50, 0x38, 0x20]) && b.length >= 30) {
      return ImageHeader(ImageKind.webp, width: le16(26) & 0x3FFF, height: le16(28) & 0x3FFF);
    }
    if (at(12, const [0x56, 0x50, 0x38, 0x4C]) && b.length >= 25) {
      final bits = le32(21);
      return ImageHeader(ImageKind.webp, width: 1 + (bits & 0x3FFF), height: 1 + ((bits >> 14) & 0x3FFF));
    }
    return const ImageHeader(ImageKind.webp);
  }
  return null;
}

/// A picture that passed the checks, downscaled, ready to become a page.
class ImportCandidate {
  ImportCandidate({
    required this.originalBytes,
    required this.kind,
    required this.art,
    required this.sourceWidth,
    required this.sourceHeight,
  }) : isPhoto = looksLikePhoto(art);

  /// The file exactly as picked (what is copied into the private folder).
  final Uint8List originalBytes;
  final ImageKind kind;

  /// The downscaled grey picture (longest side at most [kMaxPictureSide]).
  final LineArt art;
  final int sourceWidth, sourceHeight;

  /// Looks like a photograph: the screen suggests turning it into lines.
  final bool isPhoto;

  /// The picture's own lines kept as they are (light greys become paper).
  LineArt asIs() => art.cleaned();

  /// An automatic outline (Sobel in a background isolate).
  Future<LineArt> outline(OutlineLevel level) => outlineInBackground(art, level: level);
}

/// Checks a picked file and decodes it, softly: every problem is an
/// [ImportFailure] with a reason, never a crash.
class ImageImporter {
  const ImageImporter();

  Future<ImportCandidate> inspect(PickedImage picked) async {
    final declared = picked.sizeBytes;
    if (declared != null && declared > kMaxImageBytes) throw const ImportFailure(ImportError.tooBig);
    final Uint8List bytes;
    try {
      bytes = await picked.read();
    } catch (_) {
      throw const ImportFailure(ImportError.unreadable);
    }
    if (bytes.length > kMaxImageBytes) throw const ImportFailure(ImportError.tooBig);
    final header = sniffImage(bytes);
    if (header == null) throw const ImportFailure(ImportError.notImage);
    final w = header.width, h = header.height;
    if (w != null && h != null) {
      if (w <= 0 || h <= 0) throw const ImportFailure(ImportError.unreadable);
      if (w * h > kMaxImagePixels) throw const ImportFailure(ImportError.tooBig);
    }
    try {
      final decoded = await _decode(bytes, w, h);
      final art = LineArt.fromRgba(decoded.rgba, decoded.width, decoded.height);
      return ImportCandidate(
        originalBytes: bytes,
        kind: header.kind,
        art: art,
        sourceWidth: w ?? decoded.width,
        sourceHeight: h ?? decoded.height,
      );
    } on ImportFailure {
      rethrow;
    } catch (_) {
      throw const ImportFailure(ImportError.unreadable);
    }
  }

  Future<({Uint8List rgba, int width, int height})> _decode(Uint8List bytes, int? w, int? h) async {
    int? targetW, targetH;
    if (w != null && h != null && (w > kMaxPictureSide || h > kMaxPictureSide)) {
      if (w >= h) {
        targetW = kMaxPictureSide;
      } else {
        targetH = kMaxPictureSide;
      }
    } else if (w == null || h == null) {
      targetW = kMaxPictureSide;
    }
    var image = await _frame(bytes, targetW, targetH);
    if (image.width > kMaxPictureSide || image.height > kMaxPictureSide) {
      // Dimensions were unknown and the picture is tall: decode once more
      // at the right size.
      final tall = image.height > image.width;
      image.dispose();
      image = await _frame(bytes, tall ? null : kMaxPictureSide, tall ? kMaxPictureSide : null);
    }
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
      if (data == null) throw const ImportFailure(ImportError.unreadable);
      return (
        rgba: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        width: image.width,
        height: image.height,
      );
    } finally {
      image.dispose();
    }
  }

  Future<ui.Image> _frame(Uint8List bytes, int? targetW, int? targetH) async {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: targetW,
      targetHeight: targetH,
      allowUpscaling: false,
    );
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  }
}
