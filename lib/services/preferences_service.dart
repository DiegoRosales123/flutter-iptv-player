import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage application preferences
class PreferencesService {
  static const String _activePlaylistIdKey = 'active_playlist_id';

  /// Get the currently active playlist ID
  static Future<int?> getActivePlaylistId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_activePlaylistIdKey);
    return id;
  }

  /// Set the active playlist ID
  static Future<void> setActivePlaylistId(int? playlistId) async {
    final prefs = await SharedPreferences.getInstance();
    if (playlistId == null) {
      await prefs.remove(_activePlaylistIdKey);
    } else {
      await prefs.setInt(_activePlaylistIdKey, playlistId);
    }
  }

  /// Clear the active playlist (deactivate all)
  static Future<void> clearActivePlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activePlaylistIdKey);
  }
}
