// What the colouring section needs from outside, all with safe defaults.
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/colouring_store.dart';
import '../data/image_import.dart';

/// Madar's own private folder for colouring (never the gallery, never shared).
final colouringStoreProvider = FutureProvider<ColouringStore>((ref) async {
  final base = await getApplicationSupportDirectory();
  return ColouringStore(Directory(p.join(base.path, 'kids_colouring')));
});

/// The system picker (replaced by a fake in tests).
final colouringPickerProvider = Provider<ColouringImagePicker>((ref) => const SystemColouringImagePicker());

final colouringImporterProvider = Provider<ImageImporter>((ref) => const ImageImporter());

/// Asks the parent (PIN or fingerprint) and says whether they passed.
typedef ParentGate = Future<bool> Function();

/// The kids shell owns the real gate; the integrator overrides this with it.
/// Until then it says NO to everything, so adding or deleting a picture is
/// impossible rather than open to the child.
final colouringParentGateProvider = Provider<ParentGate>(
  (ref) =>
      () async => false,
);
