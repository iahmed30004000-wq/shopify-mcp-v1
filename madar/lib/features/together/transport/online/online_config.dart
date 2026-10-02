/// The user's own Firebase project for online play – entered in the app,
/// never bundled (no google-services.json, no Google Services plugin), kept
/// in the Android Keystore-backed secure storage.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../core/db/encryption.dart' show SecretStore;

enum OnlineConfigField { apiKey, appId, projectId, databaseUrl, senderId }

enum OnlineConfigProblem {
  /// Required and empty.
  missing,

  /// Not in the expected format.
  format,

  /// The sender id does not match the app id's project number.
  mismatch,
}

/// A Firebase project's client settings (all public identifiers – the
/// security comes from the database rules and anonymous sign-in).
@immutable
final class OnlineConfig {
  const OnlineConfig({
    required this.apiKey,
    required this.appId,
    required this.projectId,
    required this.databaseUrl,
    this.messagingSenderId = '',
  });

  final String apiKey;

  /// `1:<project number>:android:<hex>` (or a web app's id).
  final String appId;
  final String projectId;

  /// `https://<db>.firebaseio.com` or `https://<db>.<region>.firebasedatabase.app`.
  final String databaseUrl;

  /// Optional: the project number (taken from [appId] when empty).
  final String messagingSenderId;

  static final RegExp _apiKey = RegExp(r'^AIza[0-9A-Za-z_\-]{35}$');
  static final RegExp _appId = RegExp(r'^1:([0-9]{5,20}):(android|web|ios):[0-9a-f]{8,40}$');
  static final RegExp _projectId = RegExp(r'^[a-z][a-z0-9\-]{4,28}[a-z0-9]$');
  static final RegExp _databaseUrl = RegExp(
    r'^https://[a-z0-9](?:[a-z0-9\-]{0,61}[a-z0-9])?(?:\.[a-z0-9\-]+)*\.(?:firebaseio\.com|firebasedatabase\.app)$',
  );
  static final RegExp _sender = RegExp(r'^[0-9]{5,20}$');

  /// The project number used as the messaging sender id.
  String get senderId => messagingSenderId.isNotEmpty ? messagingSenderId : (_appId.firstMatch(appId)?.group(1) ?? '');

  static String _clean(String v) => v.trim().replaceAll(RegExp(r'\s'), '');

  static String _cleanUrl(String v) {
    var u = _clean(v);
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u.toLowerCase();
  }

  /// What is wrong with the typed values (empty: valid).
  static Map<OnlineConfigField, OnlineConfigProblem> validate({
    required String apiKey,
    required String appId,
    required String projectId,
    required String databaseUrl,
    String senderId = '',
  }) {
    final problems = <OnlineConfigField, OnlineConfigProblem>{};
    void check(OnlineConfigField f, String v, RegExp re, {bool optional = false}) {
      if (v.isEmpty) {
        if (!optional) problems[f] = OnlineConfigProblem.missing;
      } else if (!re.hasMatch(v)) {
        problems[f] = OnlineConfigProblem.format;
      }
    }

    final app = _clean(appId);
    final sender = _clean(senderId);
    check(OnlineConfigField.apiKey, _clean(apiKey), _apiKey);
    check(OnlineConfigField.appId, app, _appId);
    check(OnlineConfigField.projectId, _clean(projectId), _projectId);
    check(OnlineConfigField.databaseUrl, _cleanUrl(databaseUrl), _databaseUrl);
    check(OnlineConfigField.senderId, sender, _sender, optional: true);
    final number = _appId.firstMatch(app)?.group(1);
    if (sender.isNotEmpty && number != null && !problems.containsKey(OnlineConfigField.senderId) && sender != number) {
      problems[OnlineConfigField.senderId] = OnlineConfigProblem.mismatch;
    }
    return problems;
  }

  /// A valid config from typed values, or null.
  static OnlineConfig? tryCreate({
    required String apiKey,
    required String appId,
    required String projectId,
    required String databaseUrl,
    String senderId = '',
  }) {
    final problems = validate(
      apiKey: apiKey,
      appId: appId,
      projectId: projectId,
      databaseUrl: databaseUrl,
      senderId: senderId,
    );
    if (problems.isNotEmpty) return null;
    return OnlineConfig(
      apiKey: _clean(apiKey),
      appId: _clean(appId),
      projectId: _clean(projectId),
      databaseUrl: _cleanUrl(databaseUrl),
      messagingSenderId: _clean(senderId),
    );
  }

  Map<String, Object?> toJson() => {
    'v': 1,
    'apiKey': apiKey,
    'appId': appId,
    'projectId': projectId,
    'databaseURL': databaseUrl,
    if (messagingSenderId.isNotEmpty) 'messagingSenderId': messagingSenderId,
  };

  /// A stored config (re-validated), or null.
  static OnlineConfig? fromJson(Object? json) {
    if (json is! Map) return null;
    String s(String k) => json[k] is String ? json[k] as String : '';
    return tryCreate(
      apiKey: s('apiKey'),
      appId: s('appId'),
      projectId: s('projectId'),
      databaseUrl: s('databaseURL'),
      senderId: s('messagingSenderId'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is OnlineConfig &&
      other.apiKey == apiKey &&
      other.appId == appId &&
      other.projectId == projectId &&
      other.databaseUrl == databaseUrl &&
      other.messagingSenderId == messagingSenderId;

  @override
  int get hashCode => Object.hash(apiKey, appId, projectId, databaseUrl, messagingSenderId);

  @override
  String toString() => 'OnlineConfig($projectId)';
}

/// Values found in pasted text (any subset).
@immutable
final class OnlineConfigDraft {
  const OnlineConfigDraft({this.apiKey, this.appId, this.projectId, this.databaseUrl, this.senderId});

  final String? apiKey;
  final String? appId;
  final String? projectId;
  final String? databaseUrl;
  final String? senderId;

  bool get isEmpty => apiKey == null && appId == null && projectId == null && databaseUrl == null && senderId == null;

  /// Reads a pasted `google-services.json`, the web console's
  /// `firebaseConfig = {…}` snippet or `key: value` lines. Null when nothing
  /// usable is in [text].
  static OnlineConfigDraft? parse(String text, {String androidPackage = 'app.madar.orbit'}) {
    final draft = _fromGoogleServices(text, androidPackage) ?? _fromPairs(text);
    return draft == null || draft.isEmpty ? null : draft;
  }

  static OnlineConfigDraft? _fromGoogleServices(String text, String androidPackage) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      return null;
    }
    if (json is! Map) return null;
    final info = json['project_info'];
    final clients = json['client'];
    if (info is! Map || clients is! List) return null;
    Map<Object?, Object?>? client;
    for (final c in clients.whereType<Map<Object?, Object?>>()) {
      final pkg = ((c['client_info'] as Map?)?['android_client_info'] as Map?)?['package_name'];
      if (pkg == androidPackage) client = c;
    }
    client ??= clients.whereType<Map<Object?, Object?>>().firstOrNull;
    final keys = client?['api_key'];
    final key = keys is List && keys.isNotEmpty && keys.first is Map ? (keys.first as Map)['current_key'] : null;
    final appId = (client?['client_info'] as Map?)?['mobilesdk_app_id'];
    String? str(Object? v) => v is String && v.isNotEmpty ? v : null;
    return OnlineConfigDraft(
      apiKey: str(key),
      appId: str(appId),
      projectId: str(info['project_id']),
      databaseUrl: str(info['firebase_url']),
      senderId: str(info['project_number']),
    );
  }

  static final RegExp _pair = RegExp(r'''["']?([A-Za-z]+)["']?\s*[:=]\s*["']([^"'\s,]+)["']''');

  static OnlineConfigDraft? _fromPairs(String text) {
    final values = <String, String>{};
    for (final m in _pair.allMatches(text)) {
      values[m.group(1)!.toLowerCase()] = m.group(2)!;
    }
    if (values.isEmpty) return null;
    return OnlineConfigDraft(
      apiKey: values['apikey'],
      appId: values['appid'],
      projectId: values['projectid'],
      databaseUrl: values['databaseurl'],
      senderId: values['messagingsenderid'],
    );
  }
}

/// Keeps the [OnlineConfig] in secure storage (entry
/// [OnlineConfigStore.key]).
class OnlineConfigStore {
  const OnlineConfigStore(this.secrets);

  static const String key = 'together.online.config';

  final SecretStore secrets;

  Future<OnlineConfig?> read() async {
    final raw = await secrets.read(key);
    if (raw == null) return null;
    try {
      return OnlineConfig.fromJson(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  Future<void> write(OnlineConfig config) => secrets.write(key, jsonEncode(config.toJson()));

  Future<void> clear() => secrets.delete(key);
}
