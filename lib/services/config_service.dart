import 'dart:convert';
import 'package:flutter/services.dart';

class ConfigService {
  static late Map<String, dynamic> _config;
  static bool _initialized = false;

  /// Initialize the config service by loading config.json
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      final jsonString = await rootBundle.loadString('config.json');
      _config = jsonDecode(jsonString);
      _initialized = true;
    } catch (e) {
      print('Error loading config.json: $e');
      // Provide default values if config fails to load
      _config = {
        'apis': {
          'tmdb': {
            'apiKey': 'YOUR_TMDB_API_KEY_HERE',
            'baseUrl': 'https://api.themoviedb.org/3',
          },
          'omdb': {
            'baseUrl': 'http://www.omdbapi.com',
          },
        },
      };
      _initialized = true;
    }
  }

  /// Get TMDB API key
  static String getTmdbApiKey() {
    return _config['apis']['tmdb']['apiKey'] ?? 'YOUR_TMDB_API_KEY_HERE';
  }

  /// Get TMDB base URL
  static String getTmdbBaseUrl() {
    return _config['apis']['tmdb']['baseUrl'] ?? 'https://api.themoviedb.org/3';
  }

  /// Get OMDb base URL
  static String getOmdbBaseUrl() {
    return _config['apis']['omdb']['baseUrl'] ?? 'http://www.omdbapi.com';
  }

  /// Check if TMDB API key is configured
  static bool isTmdbConfigured() {
    final apiKey = getTmdbApiKey();
    return !apiKey.contains('YOUR_TMDB_API_KEY');
  }
}
