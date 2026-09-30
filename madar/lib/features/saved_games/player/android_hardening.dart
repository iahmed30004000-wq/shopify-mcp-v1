import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
// webview_flutter_android is resolved through webview_flutter (federated
// plugin). The lead adds it to pubspec.yaml as a direct dependency; until
// then the lint below is expected.
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Android-only lock-down of a game's WebView (no-op elsewhere / in tests):
/// no file or content:// access, no geolocation, no file chooser, media only
/// after a user gesture, no mixed content, fixed text zoom.
Future<void> hardenGameWebView(WebViewController controller) async {
  final p = controller.platform;
  if (p is! AndroidWebViewController) return;
  Future<void> quiet(Future<void> Function() call) async {
    try {
      await call();
    } on Object {
      // Older WebView: keep the platform default.
    }
  }

  await quiet(() => p.setAllowFileAccess(false));
  await quiet(() => p.setAllowContentAccess(false));
  await quiet(() => p.setGeolocationEnabled(false));
  await quiet(() => p.setMediaPlaybackRequiresUserGesture(true));
  await quiet(() => p.setMixedContentMode(MixedContentMode.neverAllow));
  await quiet(() => p.setTextZoom(100));
  await quiet(() => p.setOnShowFileSelector((_) async => const <String>[]));
  await quiet(
    () => p.setGeolocationPermissionsPromptCallbacks(
      onShowPrompt: (_) async => const GeolocationPermissionsResponse(allow: false, retain: false),
    ),
  );
}

/// Tests: stands in for the native identifier of a (fake) WebView.
@visibleForTesting
int? Function(WebViewController controller)? debugNativeWebViewId;

/// The native WebView's identifier (for the host's pause / harden hooks and
/// renderer-gone reports), or null off Android or when it is unknown.
int? nativeWebViewId(WebViewController controller) {
  final debug = debugNativeWebViewId;
  if (debug != null) return debug(controller);
  final p = controller.platform;
  if (p is! AndroidWebViewController) return null;
  try {
    return p.webViewIdentifier;
  } on Object {
    return null; // not (or no longer) registered with the plugin
  }
}
