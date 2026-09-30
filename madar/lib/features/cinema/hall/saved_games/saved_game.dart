import 'package:flutter/foundation.dart';

/// A web game the user added by URL. Madar stores only the title and the
/// link; the game always runs from its original address in an in-app
/// browser – no third-party code is ever copied or bundled.
@immutable
class SavedGame {
  const SavedGame({required this.id, required this.title, required this.url, required this.addedAt});

  factory SavedGame.fromJson(Map<String, Object?> json) => SavedGame(
    id: json['id']! as String,
    title: json['title']! as String,
    url: Uri.parse(json['url']! as String),
    addedAt: DateTime.parse(json['addedAt']! as String),
  );

  final String id;
  final String title;
  final Uri url;
  final DateTime addedAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'url': url.toString(),
    'addedAt': addedAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is SavedGame && other.id == id && other.title == title && other.url == url && other.addedAt == addedAt;

  @override
  int get hashCode => Object.hash(id, title, url, addedAt);
}

/// Parses user input into a game link: trims, adds `https://` when no scheme
/// was typed, accepts only http(s) with a host. Returns `null` if invalid.
Uri? parseGameUrl(String input) {
  var text = input.trim();
  if (text.isEmpty || text.contains(' ')) return null;
  if (!text.contains('://')) text = 'https://$text';
  final uri = Uri.tryParse(text);
  if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) return null;
  if (uri.host.isEmpty || !uri.host.contains('.')) return null;
  return uri;
}
