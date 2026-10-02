import 'package:shared_preferences/shared_preferences.dart';

/// Wrapper around [SharedPreferences] for app-specific local storage.
class StorageService {
  final SharedPreferences _prefs;

  StorageService(this._prefs);

  // ─── First time / Onboarding ─────────────────────
  static const _keyFirstTime = 'is_first_time';

  bool get isFirstTime => _prefs.getBool(_keyFirstTime) ?? true;

  Future<void> setFirstTimeCompleted() async {
    await _prefs.setBool(_keyFirstTime, false);
  }

  // ─── Theme ────────────────────────────────────────
  static const _keyThemeMode = 'theme_mode';

  String? getThemeMode() => _prefs.getString(_keyThemeMode);

  Future<void> saveThemeMode(String mode) async {
    await _prefs.setString(_keyThemeMode, mode);
  }

  // ─── Selected ID (generic multi-purpose) ──────────
  static const _keySelectedId = 'selected_id';

  String? getSelectedId() => _prefs.getString(_keySelectedId);

  Future<void> saveSelectedId(String id) async {
    await _prefs.setString(_keySelectedId, id);
  }

  Future<void> clearSelectedId() async {
    await _prefs.remove(_keySelectedId);
  }
}
