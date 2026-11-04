import 'package:shared_preferences/shared_preferences.dart';

/// Where the SDK keeps the reporter key and which replies were read. Implement it to use
/// your app's own storage.
abstract interface class SeaproofStorage {
  /// The value for [key], or null.
  Future<String?> read(String key);

  /// Stores [value] under [key].
  Future<void> write(String key, String value);
}

/// Shared preferences: the default. Survives app restarts, not reinstalls.
final class PreferencesSeaproofStorage implements SeaproofStorage {
  // Created on first use: the plugin is not available everywhere, for example in widget tests.
  late final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  @override
  Future<String?> read(String key) => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) => _preferences.setString(key, value);
}

/// Kept in memory only, for tests or when nothing may be stored.
final class MemorySeaproofStorage implements SeaproofStorage {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}
