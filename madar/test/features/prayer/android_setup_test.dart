// The Android side of the location flow (geolocator reads the manifest to
// decide which permission to request).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifest =
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

  test('the manifest asks for approximate location, with no background access', () {
    // geolocator_android requests exactly the location permissions the
    // manifest declares. Coarse is the only unbounded one, so on every
    // supported Android the prayer flow's system dialog can be answered with
    // "approximate", as the in-app rationale promises.
    expect(manifest, contains('android.permission.ACCESS_COARSE_LOCATION'));
    expect(manifest, isNot(contains('android.permission.ACCESS_BACKGROUND_LOCATION')));
    // Coarse carries no maxSdkVersion: the line declaring it must be plain.
    expect(
      manifest,
      contains(
        '<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />',
      ),
    );
  });

  test('precise location, if declared at all, is only for Nearby on old Android', () {
    // Together Mode's Nearby discovery needs ACCESS_FINE_LOCATION on API 29-32
    // (a BLE scan there is treated as a location scan). It is bounded to
    // maxSdkVersion="32", so Android 13 and newer never see it in the merged
    // manifest and geolocator can only ever ask for approximate there.
    //
    // If the Nearby transport is ever dropped, delete the permission rather
    // than relaxing this test: nothing else in Madar may ask for precise
    // location, and nothing may ask for it on a current Android.
    final fine = RegExp(
      r'<uses-permission\s+android:name="android\.permission\.ACCESS_FINE_LOCATION"[^>]*>',
    ).allMatches(manifest).map((m) => m.group(0)!).toList();
    if (fine.isEmpty) return;
    expect(fine, hasLength(1), reason: 'precise location is declared once or not at all');
    expect(
      fine.single,
      contains('android:maxSdkVersion="32"'),
      reason: 'precise location must never reach Android 13+',
    );
  });
}
