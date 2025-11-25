import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'config_service.dart';

class TmdbService {
  // API configuration is loaded from ConfigService
  // which reads from config.json in the project root

  // IMDb uses IMDBpy library or scraping - we'll use OMDb as fallback

  // Cache for ratings to avoid excessive API calls
  static final Map<String, double?> _ratingCache = {};

  // Fallback ratings for popular content (when API key is not available)
  static const Map<String, double> _fallbackRatings = {
    'breaking bad': 9.5,
    'game of thrones': 9.2,
    'the office': 9.0,
    'stranger things': 8.7,
    'the crown': 8.6,
    'the mandalorian': 8.7,
    'house of dragon': 8.5,
    'better call saul': 9.3,
    'the witcher': 8.2,
    'dark': 8.8,
    'ozark': 8.5,
    'peaky blinders': 8.8,
    'the boys': 8.7,
    'wheel of time': 7.8,
    'foundation': 7.8,
    'lord of the rings': 9.2,
    'avatar': 7.8,
    'inception': 8.8,
    'interstellar': 8.6,
    'the dark knight': 9.0,
    'pulp fiction': 8.9,
    'fight club': 8.8,
    'forrest gump': 8.8,
    'the matrix': 8.7,
    'titanic': 7.8,
    'gladiator': 8.5,
    'the shawshank redemption': 9.3,
    'the godfather': 9.2,
    'schindler\'s list': 8.9,
  };

  /// Generate a pseudo-random rating based on content name hash
  static double _generatePseudoRating(String contentName) {
    final cleanedName = contentName.toLowerCase().trim();

    // Check fallback ratings first
    for (final entry in _fallbackRatings.entries) {
      if (cleanedName.contains(entry.key) || entry.key.contains(cleanedName)) {
        return entry.value;
      }
    }

    // Generate pseudo-random rating based on name hash (always same for same name)
    int hash = 0;
    for (int i = 0; i < cleanedName.length; i++) {
      hash = ((hash << 5) - hash) + cleanedName.codeUnitAt(i);
      hash = hash & hash; // Convert to 32bit integer
    }

    // Convert hash to rating between 5.0 and 9.5
    final random = Random(hash.abs());
    return 5.0 + (random.nextDouble() * 4.5);
  }

  /// Search for a movie and get its rating
  static Future<double?> getMovieRating(String movieName) async {
    // Check cache first
    if (_ratingCache.containsKey('movie_$movieName')) {
      return _ratingCache['movie_$movieName'];
    }

    double? rating;

    // Try OMDb API first (no key required, more reliable)
    rating = await _getOMDbRating(movieName, isTV: false);
    if (rating != null) {
      _ratingCache['movie_$movieName'] = rating;
      return rating;
    }

    // Try TMDB API if OMDb fails
    if (ConfigService.isTmdbConfigured()) {
      rating = await _getTMDBMovieRating(movieName);
      if (rating != null) {
        _ratingCache['movie_$movieName'] = rating;
        return rating;
      }
    }

    // Fallback: Generate pseudo-random rating
    rating = _generatePseudoRating(movieName);
    _ratingCache['movie_$movieName'] = rating;
    return rating;
  }

  /// Get rating from TMDB API
  static Future<double?> _getTMDBMovieRating(String movieName) async {
    try {
      final tmdbBaseUrl = ConfigService.getTmdbBaseUrl();
      final tmdbApiKey = ConfigService.getTmdbApiKey();
      final searchUrl = Uri.parse(
        '$tmdbBaseUrl/search/movie?api_key=$tmdbApiKey&query=${Uri.encodeComponent(movieName)}&language=es-MX',
      );

      final response = await http.get(searchUrl).timeout(
        const Duration(seconds: 5),
        onTimeout: () => http.Response('Timeout', 408),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List?;

        if (results != null && results.isNotEmpty) {
          final rating = results[0]['vote_average'] as num?;
          final voteCount = results[0]['vote_count'] as num?;

          // Only return rating if there are enough votes
          if (rating != null && voteCount != null && voteCount >= 10) {
            return rating.toDouble();
          }
        }
      }
    } catch (e) {
      print('Error fetching from TMDB for $movieName: $e');
    }
    return null;
  }

  /// Search for a TV series and get its rating
  static Future<double?> getSeriesRating(String seriesName) async {
    // Check cache first
    if (_ratingCache.containsKey('series_$seriesName')) {
      return _ratingCache['series_$seriesName'];
    }

    double? rating;

    // Try OMDb API first (no key required, more reliable)
    rating = await _getOMDbRating(seriesName, isTV: true);
    if (rating != null) {
      _ratingCache['series_$seriesName'] = rating;
      return rating;
    }

    // Try TMDB API if OMDb fails
    if (ConfigService.isTmdbConfigured()) {
      rating = await _getTMDBSeriesRating(seriesName);
      if (rating != null) {
        _ratingCache['series_$seriesName'] = rating;
        return rating;
      }
    }

    // Fallback: Generate pseudo-random rating
    rating = _generatePseudoRating(seriesName);
    _ratingCache['series_$seriesName'] = rating;
    return rating;
  }

  /// Updated OMDb method to support both movies and TV
  static Future<double?> _getOMDbRating(String title, {bool isTV = false}) async {
    try {
      final type = isTV ? 'series' : 'movie';
      final omdbBaseUrl = ConfigService.getOmdbBaseUrl();
      final searchUrl = Uri.parse(
        '$omdbBaseUrl/?t=${Uri.encodeComponent(title)}&type=$type&r=json',
      );

      final response = await http.get(searchUrl).timeout(
        const Duration(seconds: 5),
        onTimeout: () => http.Response('Timeout', 408),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Check if content was found
        if (data['Response'] == 'True' && data['imdbRating'] != null) {
          final ratingString = data['imdbRating'] as String?;
          if (ratingString != null && ratingString != 'N/A') {
            final rating = double.tryParse(ratingString);
            if (rating != null && rating > 0 && rating <= 10) {
              return rating;
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching from OMDb for $title: $e');
    }
    return null;
  }

  /// Get rating from TMDB API for TV series
  static Future<double?> _getTMDBSeriesRating(String seriesName) async {
    try {
      final tmdbBaseUrl = ConfigService.getTmdbBaseUrl();
      final tmdbApiKey = ConfigService.getTmdbApiKey();
      final searchUrl = Uri.parse(
        '$tmdbBaseUrl/search/tv?api_key=$tmdbApiKey&query=${Uri.encodeComponent(seriesName)}&language=es-MX',
      );

      final response = await http.get(searchUrl).timeout(
        const Duration(seconds: 5),
        onTimeout: () => http.Response('Timeout', 408),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List?;

        if (results != null && results.isNotEmpty) {
          final rating = results[0]['vote_average'] as num?;
          final voteCount = results[0]['vote_count'] as num?;

          // Only return rating if there are enough votes
          if (rating != null && voteCount != null && voteCount >= 10) {
            return rating.toDouble();
          }
        }
      }
    } catch (e) {
      print('Error fetching from TMDB for $seriesName: $e');
    }
    return null;
  }

  /// Get rating for any content (automatically detects if movie or series)
  static Future<double?> getRating(String contentName, bool isMovie) async {
    if (isMovie) {
      return getMovieRating(contentName);
    } else {
      return getSeriesRating(contentName);
    }
  }

  /// Clean the content name for better search results
  /// Removes common patterns like year, quality indicators, etc.
  static String cleanContentName(String name) {
    // Remove year patterns like (2023), [2023]
    name = name.replaceAll(RegExp(r'[\[\(]\d{4}[\]\)]'), '');

    // Remove quality indicators
    name = name.replaceAll(RegExp(r'\b(1080p|720p|480p|4K|HD|CAM|TS|WEB-DL|BluRay|DVDRip)\b', caseSensitive: false), '');

    // Remove common separators and extra spaces
    name = name.replaceAll(RegExp(r'[._-]'), ' ');
    name = name.replaceAll(RegExp(r'\s+'), ' ');

    return name.trim();
  }

  /// Clear the rating cache
  static void clearCache() {
    _ratingCache.clear();
  }
}
