import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import '../models/channel.dart';
import '../models/vod_item.dart';
import '../models/series_item.dart';

class XtreamService {
  final String baseUrl;
  final String username;
  final String password;

  // Cache for categories
  Map<String, String> _liveCategories = {};
  Map<String, String> _vodCategories = {};
  Map<String, String> _seriesCategories = {};

  XtreamService({
    required this.baseUrl,
    required this.username,
    required this.password,
  });

  /// Load live categories
  Future<void> _loadLiveCategories() async {
    try {
      final url = '$baseUrl/player_api.php?username=$username&password=$password&action=get_live_categories';
      print('XtreamService - Loading live categories...');

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        _liveCategories.clear();
        for (var cat in data) {
          final id = cat['category_id']?.toString() ?? '';
          final name = cat['category_name']?.toString() ?? 'Unknown';
          if (id.isNotEmpty) {
            _liveCategories[id] = name;
          }
        }
        print('XtreamService - Loaded ${_liveCategories.length} live categories');
      }
    } catch (e) {
      print('XtreamService - Error loading live categories: $e');
    }
  }

  /// Load VOD categories
  Future<void> _loadVodCategories() async {
    try {
      final url = '$baseUrl/player_api.php?username=$username&password=$password&action=get_vod_categories';
      print('XtreamService - Loading VOD categories...');

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        _vodCategories.clear();
        for (var cat in data) {
          final id = cat['category_id']?.toString() ?? '';
          final name = cat['category_name']?.toString() ?? 'Unknown';
          if (id.isNotEmpty) {
            _vodCategories[id] = name;
          }
        }
        print('XtreamService - Loaded ${_vodCategories.length} VOD categories');
      }
    } catch (e) {
      print('XtreamService - Error loading VOD categories: $e');
    }
  }

  /// Load series categories
  Future<void> _loadSeriesCategories() async {
    try {
      final url = '$baseUrl/player_api.php?username=$username&password=$password&action=get_series_categories';
      print('XtreamService - Loading series categories...');

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        _seriesCategories.clear();
        for (var cat in data) {
          final id = cat['category_id']?.toString() ?? '';
          final name = cat['category_name']?.toString() ?? 'Unknown';
          if (id.isNotEmpty) {
            _seriesCategories[id] = name;
          }
        }
        print('XtreamService - Loaded ${_seriesCategories.length} series categories');
      }
    } catch (e) {
      print('XtreamService - Error loading series categories: $e');
    }
  }

  /// Get live TV channels and categories
  Future<Map<String, dynamic>> getLiveChannels() async {
    try {
      // Load categories first
      await _loadLiveCategories();

      final url = '$baseUrl/player_api.php?username=$username&password=$password&action=get_live_streams';
      print('XtreamService - Fetching live channels from: $url');

      final response = await http.get(
        Uri.parse(url),
      ).timeout(const Duration(seconds: 30));

      print('XtreamService - Response status: ${response.statusCode}');
      print('XtreamService - Response body length: ${response.body.length}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        print('XtreamService - Parsed ${data.length} live streams');

        // Debug: Print first 3 items to see structure
        if (data.isNotEmpty) {
          print('XtreamService - Sample data (first 3 items):');
          for (var i = 0; i < min(3, data.length); i++) {
            print('  Item $i: name="${data[i]['name']}", category="${data[i]['category_name']}", category_id="${data[i]['category_id']}"');
          }
        }

        // Parse channels
        final channels = <Channel>[];
        final categorySet = <String>{};

        for (var item in data) {
          final channel = Channel();
          channel.name = item['name'] ?? 'Unknown';
          channel.url = '$baseUrl/live/$username/$password/${item['stream_id']}.ts';

          // Get category name from the map using category_id
          final categoryId = item['category_id']?.toString() ?? '';
          channel.group = _liveCategories[categoryId] ?? item['category_name'] ?? 'Uncategorized';

          channel.logo = item['stream_icon'];
          channel.tvgId = int.tryParse(item['stream_id']?.toString() ?? '0');
          channel.contentType = ContentType.live;
          channels.add(channel);

          // Track categories
          if (channel.group != null && channel.group!.isNotEmpty) {
            categorySet.add(channel.group!);
          }
        }

        print('XtreamService - Found ${categorySet.length} unique categories: ${categorySet.take(10).join(", ")}...');
        print('XtreamService - Channels with categories: ${channels.where((c) => c.group != null && c.group!.isNotEmpty).length}/${channels.length}');

        return {
          'success': true,
          'channels': channels,
          'message': 'Loaded ${channels.length} live channels',
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch live channels: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching live channels: $e',
      };
    }
  }

  /// Get VOD (Movies)
  Future<Map<String, dynamic>> getMovies() async {
    try {
      // Load categories first
      await _loadVodCategories();

      print('XtreamService - Fetching movies...');
      final response = await http.get(
        Uri.parse('$baseUrl/player_api.php?username=$username&password=$password&action=get_vod_streams'),
      ).timeout(const Duration(seconds: 30));

      print('XtreamService - Movies response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        print('XtreamService - Parsed ${data.length} movies');

        // Debug: Print first 3 items to see structure
        if (data.isNotEmpty) {
          print('XtreamService - Sample movie data (first 3 items):');
          for (var i = 0; i < min(3, data.length); i++) {
            print('  Item $i: name="${data[i]['name']}", category="${data[i]['category_name']}", category_id="${data[i]['category_id']}"');
          }
        }

        final movies = <VodItem>[];
        final categorySet = <String>{};

        for (var item in data) {
          final movie = VodItem.fromJson(item, baseUrl, username, password, categoryMap: _vodCategories);
          movies.add(movie);

          // Track categories
          if (movie.categoryName.isNotEmpty) {
            categorySet.add(movie.categoryName);
          }
        }

        print('XtreamService - Found ${categorySet.length} unique movie categories: ${categorySet.take(10).join(", ")}...');

        return {
          'success': true,
          'movies': movies,
          'message': 'Loaded ${movies.length} movies',
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch movies: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('XtreamService - Error fetching movies: $e');
      return {
        'success': false,
        'message': 'Error fetching movies: $e',
      };
    }
  }

  /// Get Series
  Future<Map<String, dynamic>> getSeries() async {
    try {
      // Load categories first
      await _loadSeriesCategories();

      print('XtreamService - Fetching series...');
      final response = await http.get(
        Uri.parse('$baseUrl/player_api.php?username=$username&password=$password&action=get_series'),
      ).timeout(const Duration(seconds: 30));

      print('XtreamService - Series response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        print('XtreamService - Parsed ${data.length} series');

        // Debug: Print first 3 items to see structure
        if (data.isNotEmpty) {
          print('XtreamService - Sample series data (first 3 items):');
          for (var i = 0; i < min(3, data.length); i++) {
            print('  Item $i: name="${data[i]['name']}", category="${data[i]['category_name']}", category_id="${data[i]['category_id']}"');
          }
        }

        final seriesList = <SeriesItem>[];
        final categorySet = <String>{};

        for (var item in data) {
          final series = SeriesItem.fromJson(item, categoryMap: _seriesCategories);
          seriesList.add(series);

          // Track categories
          if (series.categoryName.isNotEmpty) {
            categorySet.add(series.categoryName);
          }
        }

        print('XtreamService - Found ${categorySet.length} unique series categories: ${categorySet.take(10).join(", ")}...');

        return {
          'success': true,
          'series': seriesList,
          'message': 'Loaded ${seriesList.length} series',
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch series: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('XtreamService - Error fetching series: $e');
      return {
        'success': false,
        'message': 'Error fetching series: $e',
      };
    }
  }

  /// Get series information and episodes
  Future<Map<String, dynamic>> getSeriesInfo(int seriesId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/player_api.php?username=$username&password=$password&action=get_series_info&series_id=$seriesId'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        return {
          'success': true,
          'data': data,
          'message': 'Loaded series info',
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch series info: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching series info: $e',
      };
    }
  }

  /// Verify credentials by testing basic API call
  Future<bool> verifyCredentials() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/player_api.php?username=$username&password=$password&action=get_live_categories'),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Helper: Parse rating from various formats
  double? _parseRating(dynamic rating) {
    if (rating == null) return null;

    if (rating is num) {
      return rating.toDouble();
    }

    if (rating is String) {
      return double.tryParse(rating);
    }

    return null;
  }
}
