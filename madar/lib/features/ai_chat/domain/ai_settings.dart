/// The AI chat's settings: provider, the editable model list per provider,
/// response length and temperature. Stored as JSON in the encrypted
/// database (`key_values`, [AiSettings.storageKey]). API keys are NOT part
/// of this – they live only in secure storage. Pure Dart.
library;

import 'package:meta/meta.dart';

import 'ai_models.dart';

@immutable
class AiSettings {
  const AiSettings({
    this.provider = AiProviderId.anthropic,
    this.selected = defaultSelected,
    this.models = defaultModels,
    this.fetched = const {},
    this.temperature,
    this.maxTokens = defaultMaxTokens,
  });

  /// `key_values` key.
  static const String storageKey = 'aiChat.settings';

  /// The starting list per provider (the user can add, remove and reset).
  static const Map<AiProviderId, List<String>> defaultModels = {
    AiProviderId.anthropic: ['claude-opus-5-5', 'claude-sonnet-5-5', 'claude-haiku-4-5-20251001', 'claude-fable-5-1'],
    AiProviderId.openai: ['gpt-6.1-sol', 'gpt-6-astra', 'gpt-6-luna', 'gpt-5.6-terra'],
  };

  /// Balanced defaults: capable, quick and kind to the user's bill.
  static const Map<AiProviderId, String> defaultSelected = {
    AiProviderId.anthropic: 'claude-sonnet-5-5',
    AiProviderId.openai: 'gpt-6.1-sol',
  };

  static const int defaultMaxTokens = 4096;

  /// Reply length choices (tokens; includes any hidden reasoning).
  static const List<int> maxTokenChoices = [1024, 2048, 4096, 8192, 16000];

  /// Longest custom model id accepted.
  static const int maxModelIdLength = 120;

  /// Most models kept per provider list.
  static const int maxModels = 40;

  final AiProviderId provider;
  final Map<AiProviderId, String> selected;
  final Map<AiProviderId, List<String>> models;

  /// What "Refresh models" last returned (only when the user tapped it).
  final Map<AiProviderId, List<AiModelInfo>> fetched;

  /// Null = the model's default. Models released after Claude Opus 4.6 and
  /// OpenAI reasoning models reject any other value.
  final double? temperature;
  final int maxTokens;

  /// The model chosen for [p] (falls back to the first of its list).
  String modelFor(AiProviderId p) {
    final s = selected[p];
    if (s != null && s.isNotEmpty) return s;
    final list = modelsFor(p);
    return list.isNotEmpty ? list.first : defaultSelected[p]!;
  }

  String get model => modelFor(provider);

  List<String> modelsFor(AiProviderId p) => models[p] ?? defaultModels[p] ?? const [];

  List<AiModelInfo> fetchedFor(AiProviderId p) => fetched[p] ?? const [];

  /// A friendly name for [id] when the provider told us one.
  String? displayNameOf(AiProviderId p, String id) {
    for (final m in fetchedFor(p)) {
      if (m.id == id) return m.displayName;
    }
    return null;
  }

  /// Trims and validates a model id typed by the user; null when unusable.
  static String? cleanModelId(String raw) {
    final id = raw.trim();
    if (id.isEmpty || id.length > maxModelIdLength) return null;
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:/@\-]*$').hasMatch(id)) return null;
    return id;
  }

  AiSettings copyWith({
    AiProviderId? provider,
    Map<AiProviderId, String>? selected,
    Map<AiProviderId, List<String>>? models,
    Map<AiProviderId, List<AiModelInfo>>? fetched,
    double? Function()? temperature,
    int? maxTokens,
  }) => AiSettings(
    provider: provider ?? this.provider,
    selected: selected ?? this.selected,
    models: models ?? this.models,
    fetched: fetched ?? this.fetched,
    temperature: temperature != null ? temperature() : this.temperature,
    maxTokens: maxTokens ?? this.maxTokens,
  );

  /// Chooses [id] for [p] (added to the list when new).
  AiSettings selectModel(AiProviderId p, String id) {
    final clean = cleanModelId(id);
    if (clean == null) return this;
    final list = modelsFor(p);
    return copyWith(
      selected: {...selected, p: clean},
      models: list.contains(clean)
          ? null
          : {
              ...models,
              p: [...list, clean].take(maxModels).toList(),
            },
    );
  }

  /// Adds [id] to [p]'s list without selecting it.
  AiSettings addModel(AiProviderId p, String id) {
    final clean = cleanModelId(id);
    final list = modelsFor(p);
    if (clean == null || list.contains(clean) || list.length >= maxModels) return this;
    return copyWith(
      models: {
        ...models,
        p: [...list, clean],
      },
    );
  }

  /// Removes [id] from [p]'s list (the last model can't be removed; the
  /// selection moves to the first remaining one).
  AiSettings removeModel(AiProviderId p, String id) {
    final list = modelsFor(p);
    if (!list.contains(id) || list.length <= 1) return this;
    final next = [...list]..remove(id);
    return copyWith(models: {...models, p: next}, selected: modelFor(p) == id ? {...selected, p: next.first} : null);
  }

  /// Back to the starting list (keeps the selection when it is in it).
  AiSettings resetModels(AiProviderId p) {
    final defaults = defaultModels[p]!;
    return copyWith(
      models: {
        ...models,
        p: [...defaults],
      },
      selected: defaults.contains(modelFor(p)) ? null : {...selected, p: defaultSelected[p]!},
    );
  }

  AiSettings withFetched(AiProviderId p, List<AiModelInfo> list) => copyWith(fetched: {...fetched, p: list});

  Map<String, Object?> toJson() => {
    'v': 1,
    'provider': provider.name,
    'selected': {for (final e in selected.entries) e.key.name: e.value},
    'models': {for (final e in models.entries) e.key.name: e.value},
    'fetched': {
      for (final e in fetched.entries) e.key.name: [for (final m in e.value) m.toJson()],
    },
    'temperature': ?temperature,
    'maxTokens': maxTokens,
  };

  static AiSettings fromJson(Object? json) {
    if (json is! Map) return const AiSettings();
    Map<AiProviderId, V> byProvider<V>(Object? raw, V? Function(Object?) decode) {
      final out = <AiProviderId, V>{};
      if (raw is Map) {
        for (final e in raw.entries) {
          final p = AiProviderId.tryParse(e.key);
          final v = decode(e.value);
          if (p != null && v != null) out[p] = v;
        }
      }
      return out;
    }

    final selected = byProvider<String>(json['selected'], (v) => v is String ? cleanModelId(v) : null);
    final models = byProvider<List<String>>(json['models'], (v) {
      if (v is! List) return null;
      final list = <String>[];
      for (final x in v) {
        final id = x is String ? cleanModelId(x) : null;
        if (id != null && !list.contains(id)) list.add(id);
      }
      return list.isEmpty ? null : list.take(maxModels).toList();
    });
    final fetched = byProvider<List<AiModelInfo>>(json['fetched'], (v) {
      if (v is! List) return null;
      return [for (final x in v) ?AiModelInfo.fromJson(x)];
    });
    final t = json['temperature'];
    final m = json['maxTokens'];
    return AiSettings(
      provider: AiProviderId.tryParse(json['provider']) ?? AiProviderId.anthropic,
      selected: {...defaultSelected, ...selected},
      models: {...defaultModels, ...models},
      fetched: fetched,
      temperature: t is num ? t.toDouble().clamp(0.0, 1.0) : null,
      maxTokens: m is int && m >= 256 && m <= 64000 ? m : defaultMaxTokens,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AiSettings &&
      other.provider == provider &&
      other.temperature == temperature &&
      other.maxTokens == maxTokens &&
      _mapEq(other.selected, selected) &&
      _listMapEq(other.models, models) &&
      _listMapEq(other.fetched, fetched);

  @override
  int get hashCode => Object.hash(provider, temperature, maxTokens, selected.length, models.length);

  static bool _mapEq<V>(Map<AiProviderId, V> a, Map<AiProviderId, V> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }

  static bool _listMapEq<V>(Map<AiProviderId, List<V>> a, Map<AiProviderId, List<V>> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      final o = b[e.key];
      if (o == null || o.length != e.value.length) return false;
      for (var i = 0; i < o.length; i++) {
        if (o[i] != e.value[i]) return false;
      }
    }
    return true;
  }
}
