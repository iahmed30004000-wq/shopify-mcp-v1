import '../../../core/db/repositories/key_value_repository.dart';
import '../domain/iqama_settings.dart';

/// [IqamaSettings] in the encrypted `key_values` table
/// (`iqama.settings`, JSON) – the same place and the same shape as the
/// adhan's own settings, so a backup carries every offset and the sound
/// choice and a restore brings them back. Missing or unreadable →
/// defaults.
class IqamaSettingsRepository {
  IqamaSettingsRepository(this.keyValues);

  final KeyValueRepository keyValues;

  Future<IqamaSettings> load() async => IqamaSettings.fromJson(await keyValues.getJson(IqamaSettings.storageKey));

  Stream<IqamaSettings> watch() => keyValues.watchJson(IqamaSettings.storageKey).map(IqamaSettings.fromJson).distinct();

  Future<void> save(IqamaSettings settings) => keyValues.setJson(IqamaSettings.storageKey, settings.toJson());
}
