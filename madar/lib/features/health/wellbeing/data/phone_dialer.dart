import 'package:url_launcher/url_launcher.dart';

/// Opens the phone's dialer (never calls silently: the user presses call).
abstract interface class PhoneDialer {
  /// Opens the dialer with [number]; false when no dialer is available.
  Future<bool> dial(String number);
}

/// [PhoneDialer] through url_launcher's `tel:` scheme.
class UrlLauncherPhoneDialer implements PhoneDialer {
  const UrlLauncherPhoneDialer();

  @override
  Future<bool> dial(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }
}

/// Records dial requests (tests, previews).
class RecordingPhoneDialer implements PhoneDialer {
  RecordingPhoneDialer({this.succeed = true});

  final bool succeed;
  final List<String> dialed = [];

  @override
  Future<bool> dial(String number) async {
    dialed.add(number);
    return succeed;
  }
}
