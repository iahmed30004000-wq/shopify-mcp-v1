import '../../../core/db/repositories/key_value_repository.dart';
import '../domain/adhan_settings.dart';

/// [AdhanSettings] in the encrypted `key_values` table
/// (`adhan.settings`, JSON). Missing or unreadable → defaults.
class AdhanSettingsRepository {
  AdhanSettingsRepository(this.keyValues);

  final KeyValueRepository keyValues;

  Future<AdhanSettings> load() async => AdhanSettings.fromJson(await keyValues.getJson(AdhanSettings.storageKey));

  Stream<AdhanSettings> watch() => keyValues.watchJson(AdhanSettings.storageKey).map(AdhanSettings.fromJson).distinct();

  Future<void> save(AdhanSettings settings) => keyValues.setJson(AdhanSettings.storageKey, settings.toJson());
}
