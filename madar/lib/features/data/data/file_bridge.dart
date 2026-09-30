import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'data_repository.dart';

/// A file the user picked (name and contents).
typedef PickedDataFile = ({String name, Uint8List bytes});

/// Where files leave Madar – only ever on an explicit user action: the
/// Android share sheet, a save-as dialog, or the clipboard. Nothing is ever
/// uploaded by Madar itself.
abstract interface class DataFileBridge {
  /// Opens the share sheet with [file]. True unless the user dismissed it.
  Future<bool> share(DataFile file, {String? subject});

  /// Save-as dialog. True when the user chose a place and it was written.
  Future<bool> save(DataFile file);

  /// Lets the user pick a backup file (null when cancelled).
  Future<PickedDataFile?> pickFile();

  Future<void> copyText(String text);
}

class PlatformDataFileBridge implements DataFileBridge {
  const PlatformDataFileBridge();

  /// Files handed to the share sheet live here briefly (app cache) and are
  /// deleted the next time anything is shared or the data centre opens.
  static Future<Directory> shareDirectory() async => Directory('${(await getTemporaryDirectory()).path}/madar_share');

  /// Deletes shared files older than [age] (a receiving app may still be
  /// reading a very recent one).
  static Future<void> cleanShareCache({Duration age = const Duration(minutes: 10)}) async {
    try {
      final dir = await shareDirectory();
      if (!await dir.exists()) return;
      final limit = DateTime.now().subtract(age);
      await for (final e in dir.list()) {
        if (e is File && (await e.lastModified()).isBefore(limit)) await e.delete();
      }
    } catch (_) {}
  }

  @override
  Future<bool> share(DataFile file, {String? subject}) async {
    await cleanShareCache();
    final dir = await shareDirectory();
    await dir.create(recursive: true);
    final out = File('${dir.path}/${file.name}');
    await out.writeAsBytes(file.bytes, flush: true);
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(out.path, mimeType: file.mimeType, name: file.name)],
        fileNameOverrides: [file.name],
        subject: subject,
        title: subject,
      ),
    );
    return result.status != ShareResultStatus.dismissed;
  }

  @override
  Future<bool> save(DataFile file) async {
    final uri = await FilePicker.saveFile(fileName: file.name, bytes: file.bytes, mimeType: file.mimeType);
    return uri != null;
  }

  @override
  Future<PickedDataFile?> pickFile() async {
    final file = await FilePicker.pickFile(type: FileType.any);
    if (file == null) return null;
    return (name: file.name, bytes: Uint8List.fromList(await file.readAsBytes()));
  }

  @override
  Future<void> copyText(String text) => Clipboard.setData(ClipboardData(text: text));
}

/// Records every hand-off (tests, previews).
class RecordingDataFileBridge implements DataFileBridge {
  RecordingDataFileBridge({this.picked});

  final List<DataFile> shared = [];
  final List<DataFile> saved = [];
  final List<String> copied = [];

  /// What [pickFile] returns.
  PickedDataFile? picked;
  bool saveResult = true;

  @override
  Future<bool> share(DataFile file, {String? subject}) async {
    shared.add(file);
    return true;
  }

  @override
  Future<bool> save(DataFile file) async {
    saved.add(file);
    return saveResult;
  }

  @override
  Future<PickedDataFile?> pickFile() async => picked;

  @override
  Future<void> copyText(String text) async => copied.add(text);
}
