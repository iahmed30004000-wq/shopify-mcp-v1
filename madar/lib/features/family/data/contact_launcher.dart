import 'package:url_launcher/url_launcher.dart';

import '../../../core/i18n/formatters.dart' show Digits;

/// Ways to reach a person from Madar (only ever on an explicit tap).
enum ContactLaunch { call, sms, whatsapp }

/// Deep links for [ContactLaunch] (pure).
abstract final class ContactUris {
  /// The dialable form of [phone]: Western digits, a leading `+` kept,
  /// spaces / dashes / brackets dropped; null when no digit is left.
  static String? dialable(String? phone) {
    if (phone == null) return null;
    final western = Digits.toWestern(phone.trim());
    final plus = western.startsWith('+');
    final digits = western.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return plus ? '+$digits' : digits;
  }

  /// wa.me wants the international number as digits only (no `+`, no
  /// `00`).
  static String? whatsappNumber(String? phone) {
    final d = dialable(phone);
    if (d == null) return null;
    var n = d.startsWith('+') ? d.substring(1) : d;
    if (n.startsWith('00')) n = n.substring(2);
    return n.isEmpty ? null : n;
  }

  static Uri? uri(ContactLaunch kind, String? phone) {
    switch (kind) {
      case ContactLaunch.call:
        final d = dialable(phone);
        return d == null ? null : Uri(scheme: 'tel', path: d);
      case ContactLaunch.sms:
        final d = dialable(phone);
        return d == null ? null : Uri(scheme: 'sms', path: d);
      case ContactLaunch.whatsapp:
        final n = whatsappNumber(phone);
        return n == null ? null : Uri.https('wa.me', '/$n');
    }
  }
}

/// Opens the dialer / messages / WhatsApp. Never calls or sends by itself:
/// the user finishes the action in the other app.
abstract interface class ContactLauncher {
  /// False when [phone] is unusable or no app can handle it.
  Future<bool> open(ContactLaunch kind, String phone);
}

/// [ContactLauncher] through url_launcher.
class UrlContactLauncher implements ContactLauncher {
  const UrlContactLauncher();

  @override
  Future<bool> open(ContactLaunch kind, String phone) async {
    final uri = ContactUris.uri(kind, phone);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }
}

/// Records launches (tests, previews).
class RecordingContactLauncher implements ContactLauncher {
  RecordingContactLauncher({this.succeed = true});

  final bool succeed;
  final List<Uri> opened = [];

  @override
  Future<bool> open(ContactLaunch kind, String phone) async {
    final uri = ContactUris.uri(kind, phone);
    if (uri == null) return false;
    opened.add(uri);
    return succeed;
  }
}
