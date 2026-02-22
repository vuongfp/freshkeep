import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService instance = SettingsService._internal();
  SettingsService._internal();

  static const _keyGeminiApiKey = 'gemini_api_key';
  static const _keyApiKeySet = 'gemini_api_key_set';

  /// Returns true if a custom API key has been saved by the user
  Future<bool> hasCustomApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyApiKeySet) ?? false;
  }

  /// Returns the stored API key, or null if not set
  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyGeminiApiKey);
  }

  /// Saves a new API key — does NOT expose existing key
  Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGeminiApiKey, key.trim());
    await prefs.setBool(_keyApiKeySet, true);
  }

  /// Clears the custom API key (reverts to server-side key)
  Future<void> clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyGeminiApiKey);
    await prefs.setBool(_keyApiKeySet, false);
  }
}
