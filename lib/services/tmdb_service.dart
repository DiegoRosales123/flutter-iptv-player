import 'dart:convert';
import 'package:http/http.dart' as http;

class TmdbService {
  // Free TMDB API key - Replace with your own from https://www.themoviedb.org/settings/api
  static const String _apiKey = '1234567890abcdef1234567890abcdef'; // You'll need to get a real key
  static const String _baseUrl = 'https://api.themoviedb.org/3';

  // Cache for ratings to avoid excessive API calls
  static final Map<String, double?> _ratingCache = {};

  /// Search for a movie and get its rating
  static Future<double?> getMovieRating(String movieName) async {
    // Check cache first
    if (_ratingCache.containsKey('movie_$movieName')) {
      return _ratingCache['movie_$movieName'];
    }

    try {
      final searchUrl = Uri.parse(
        '$_baseUrl/search/movie?api_key=$_apiKey&query=${Uri.encodeComponent(movieName)}&language=es-MX',
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

          // Only return rating if there are enough votes (at least 10)
          if (rating != null && voteCount != null && voteCount >= 10) {
            final ratingValue = rating.toDouble();
            _ratingCache['movie_$movieName'] = ratingValue;
            return ratingValue;
          }
        }
      }
    } catch (e) {
      // Silently fail and return null
      print('Error fetching movie rating for $movieName: $e');
    }

    _ratingCache['movie_$movieName'] = null;
    return null;
  }

  /// Search for a TV series and get its rating
  static Future<double?> getSeriesRating(String seriesName) async {
    // Check cache first
    if (_ratingCache.containsKey('series_$seriesName')) {
      return _ratingCache['series_$seriesName'];
    }

    try {
      final searchUrl = Uri.parse(
        '$_baseUrl/search/tv?api_key=$_apiKey&query=${Uri.encodeComponent(seriesName)}&language=es-MX',
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

          // Only return rating if there are enough votes (at least 10)
          if (rating != null && voteCount != null && voteCount >= 10) {
            final ratingValue = rating.toDouble();
            _ratingCache['series_$seriesName'] = ratingValue;
            return ratingValue;
          }
        }
      }
    } catch (e) {
      // Silently fail and return null
      print('Error fetching series rating for $seriesName: $e');
    }

    _ratingCache['series_$seriesName'] = null;
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
