import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';
import 'database_provider.dart';

// ---------------------------------------------------------------------------
// Well-known settings keys
// ---------------------------------------------------------------------------

/// Constants for settings keys used throughout the app.
abstract class SettingsKeys {
  static const selectedVehicleProfile = 'selected_vehicle_profile';
  static const usbEsp32Port = 'usb_esp32_port';
  static const usbElm327Port = 'usb_elm327_port';
  static const esp32BaudRate = 'esp32_baud_rate';
  static const elm327BaudRate = 'elm327_baud_rate';
  static const themeAccentColor = 'theme_accent_color';
  static const themeMode = 'theme_mode';
  static const mapSetupDone = 'map_setup_done';
  static const geminiApiKey = 'gemini_api_key';
  static const geminiModel = 'gemini_model';
  static const openRouterApiKey = 'openrouter_api_key';
  static const openRouterModel = 'openrouter_model';
  static const groqApiKey = 'groq_api_key';
  static const groqModel = 'groq_model';
  static const claudeApiKey = 'claude_api_key';
  static const chatProvider =
      'chat_provider'; // kept for backward compatibility
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  /// Read a single setting by [key]. Returns `null` if not found.
  Future<String?> get(String key) async {
    final query = _db.select(_db.appSettings)..where((t) => t.key.equals(key));
    final row = await query.getSingleOrNull();
    return row?.value;
  }

  /// Write (insert or update) a setting.
  Future<void> set(String key, String value) async {
    await _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion(key: Value(key), value: Value(value)),
        );
  }

  /// Read a setting, returning [defaultValue] when the key does not exist.
  Future<String> getOrDefault(String key, String defaultValue) async {
    return (await get(key)) ?? defaultValue;
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(databaseProvider));
});
