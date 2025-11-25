import 'package:flutter/foundation.dart';
import '../models/vod_item.dart';
import '../models/series_item.dart';
import '../services/xtream_service.dart';

/// Provider for managing VOD (Movies) and Series content
class ContentProvider with ChangeNotifier {
  XtreamService? _apiClient;

  // VOD
  List<VodItem> _vodItems = [];
  List<Map<String, dynamic>> _vodCategories = [];
  String? _selectedVodCategoryId;
  bool _isLoadingVod = false;

  // Series
  List<SeriesItem> _seriesItems = [];
  List<Map<String, dynamic>> _seriesCategories = [];
  String? _selectedSeriesCategoryId;
  bool _isLoadingSeries = false;

  // Favorites
  final Set<String> _favoriteVodIds = {};
  final Set<String> _favoriteSeriesIds = {};

  ContentProvider(this._apiClient);

  /// Update the API client
  void updateApiClient(XtreamService? apiClient) {
    if (_apiClient != apiClient) {
      _apiClient = apiClient;
      notifyListeners();
    }
  }

  /// Check if API client is available
  bool get hasApiClient => _apiClient != null;

  // VOD Getters
  List<VodItem> get vodItems => _vodItems;
  List<Map<String, dynamic>> get vodCategories => _vodCategories;
  String? get selectedVodCategoryId => _selectedVodCategoryId;
  bool get isLoadingVod => _isLoadingVod;

  List<VodItem> get filteredVodItems {
    if (_selectedVodCategoryId == null || _selectedVodCategoryId == 'all') {
      return _vodItems;
    }
    return _vodItems.where((item) => item.categoryId == _selectedVodCategoryId).toList();
  }

  List<VodItem> get favoriteVodItems {
    return _vodItems.where((item) => _favoriteVodIds.contains(item.id)).toList();
  }

  // Series Getters
  List<SeriesItem> get seriesItems => _seriesItems;
  List<Map<String, dynamic>> get seriesCategories => _seriesCategories;
  String? get selectedSeriesCategoryId => _selectedSeriesCategoryId;
  bool get isLoadingSeries => _isLoadingSeries;

  List<SeriesItem> get filteredSeriesItems {
    if (_selectedSeriesCategoryId == null || _selectedSeriesCategoryId == 'all') {
      return _seriesItems;
    }
    return _seriesItems.where((item) => item.categoryId == _selectedSeriesCategoryId).toList();
  }

  List<SeriesItem> get favoriteSeriesItems {
    return _seriesItems.where((item) => _favoriteSeriesIds.contains(item.id)).toList();
  }

  /// Load VOD items (movies)
  Future<void> loadVodItems({String? categoryId}) async {
    if (_apiClient == null) {
      return;
    }

    _isLoadingVod = true;
    notifyListeners();

    try {
      final result = await _apiClient!.getMovies();

      if (result['success'] == true) {
        final movies = result['movies'] as List<VodItem>;

        // Filter by category if specified
        if (categoryId != null && categoryId != 'all') {
          _vodItems = movies.where((m) => m.categoryId == categoryId).toList();
        } else {
          _vodItems = movies;
        }
      } else {
        _vodItems = [];
      }

      notifyListeners();
    } catch (e) {
      _vodItems = [];
      notifyListeners();
    } finally {
      _isLoadingVod = false;
      notifyListeners();
    }
  }

  /// Load VOD categories
  Future<void> loadVodCategories() async {
    if (_apiClient == null) {
      return;
    }

    try {
      final result = await _apiClient!.getMovies();

      if (result['success'] == true) {
        final movies = result['movies'] as List<VodItem>;

        // Extract unique categories from movies
        final categoryMap = <String, String>{};
        for (var movie in movies) {
          if (!categoryMap.containsKey(movie.categoryId)) {
            categoryMap[movie.categoryId] = movie.categoryName;
          }
        }

        // Convert to list and add "All" at the beginning
        _vodCategories = [
          {
            'category_id': 'all',
            'category_name': 'All Movies',
            'parent_id': 0,
          },
          ...categoryMap.entries.map((e) => {
            'category_id': e.key,
            'category_name': e.value,
            'parent_id': 0,
          }).toList(),
        ];
      } else {
        _vodCategories = [];
      }

      notifyListeners();
    } catch (e) {
      _vodCategories = [];
      notifyListeners();
    }
  }

  /// Set selected VOD category and reload items
  Future<void> setVodCategory(String? categoryId) async {
    if (_selectedVodCategoryId != categoryId) {
      _selectedVodCategoryId = categoryId;
      notifyListeners();

      if (_apiClient != null) {
        await loadVodItems(categoryId: categoryId == 'all' ? null : categoryId);
      }
    }
  }

  /// Load Series items
  Future<void> loadSeriesItems({String? categoryId}) async {
    if (_apiClient == null) {
      return;
    }

    _isLoadingSeries = true;
    notifyListeners();

    try {
      final result = await _apiClient!.getSeries();

      if (result['success'] == true) {
        final series = result['series'] as List<SeriesItem>;

        // Filter by category if specified
        if (categoryId != null && categoryId != 'all') {
          _seriesItems = series.where((s) => s.categoryId == categoryId).toList();
        } else {
          _seriesItems = series;
        }
      } else {
        _seriesItems = [];
      }

      notifyListeners();
    } catch (e) {
      _seriesItems = [];
      notifyListeners();
    } finally {
      _isLoadingSeries = false;
      notifyListeners();
    }
  }

  /// Load Series categories
  Future<void> loadSeriesCategories() async {
    if (_apiClient == null) {
      return;
    }

    try {
      final result = await _apiClient!.getSeries();

      if (result['success'] == true) {
        final seriesList = result['series'] as List<SeriesItem>;

        // Extract unique categories from series
        final categoryMap = <String, String>{};
        for (var item in seriesList) {
          if (!categoryMap.containsKey(item.categoryId)) {
            categoryMap[item.categoryId] = item.categoryName;
          }
        }

        // Convert to list and add "All" at the beginning
        _seriesCategories = [
          {
            'category_id': 'all',
            'category_name': 'All Series',
            'parent_id': 0,
          },
          ...categoryMap.entries.map((e) => {
            'category_id': e.key,
            'category_name': e.value,
            'parent_id': 0,
          }).toList(),
        ];
      } else {
        _seriesCategories = [];
      }

      notifyListeners();
    } catch (e) {
      _seriesCategories = [];
      notifyListeners();
    }
  }

  /// Set selected Series category and reload items
  Future<void> setSeriesCategory(String? categoryId) async {
    if (_selectedSeriesCategoryId != categoryId) {
      _selectedSeriesCategoryId = categoryId;
      notifyListeners();

      if (_apiClient != null) {
        await loadSeriesItems(categoryId: categoryId == 'all' ? null : categoryId);
      }
    }
  }

  /// Toggle VOD favorite
  void toggleVodFavorite(String vodId) {
    if (_favoriteVodIds.contains(vodId)) {
      _favoriteVodIds.remove(vodId);
    } else {
      _favoriteVodIds.add(vodId);
    }
    notifyListeners();
  }

  /// Toggle Series favorite
  void toggleSeriesFavorite(String seriesId) {
    if (_favoriteSeriesIds.contains(seriesId)) {
      _favoriteSeriesIds.remove(seriesId);
    } else {
      _favoriteSeriesIds.add(seriesId);
    }
    notifyListeners();
  }

  /// Clear all data
  void clear() {
    _vodItems = [];
    _vodCategories = [];
    _selectedVodCategoryId = null;
    _seriesItems = [];
    _seriesCategories = [];
    _selectedSeriesCategoryId = null;
    _favoriteVodIds.clear();
    _favoriteSeriesIds.clear();
    notifyListeners();
  }
}
