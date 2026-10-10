// The Android side of the location flow (geolocator reads the manifest to
// decide which permission to request).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the manifest asks for approximate location only', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    // geolocator_android requests exactly the location permissions the
    // manifest declares: coarse only keeps the system dialog at
    // "approximate", as the in-app rationale promises.
    expect(manifest, contains('android.permission.ACCESS_COARSE_LOCATION'));
    expect(manifest, isNot(contains('android.permission.ACCESS_FINE_LOCATION')));
    expect(manifest, isNot(contains('android.permission.ACCESS_BACKGROUND_LOCATION')));
  });
}
