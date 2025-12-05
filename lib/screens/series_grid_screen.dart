import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../models/channel.dart';
import '../models/series.dart';
import '../models/series_item.dart';
import '../services/database_service.dart';
import '../services/series_parser.dart';
import '../services/tmdb_service.dart';
import '../providers/content_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/app_theme.dart';
import 'series_detail_screen.dart';

class SeriesGridScreen extends StatefulWidget {
  const SeriesGridScreen({Key? key}) : super(key: key);

  @override
  State<SeriesGridScreen> createState() => _SeriesGridScreenState();
}

class _SeriesGridScreenState extends State<SeriesGridScreen> {
  Map<String, Series> _allSeries = {};
  List<Series> _filteredSeries = [];
  List<Series> _trendingSeries = [];
  List<Series> _recentSeries = [];
  List<Series> _favoriteSeries = [];
  Map<String, int> _categories = {};
  Map<String, List<Series>> _categorizedSeries = {};
  String? _selectedCategory;
  String _searchQuery = '';
  String _sortBy = 'added';
  Series? _featuredSeries;
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadSeries();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSeries() async {
    final allChannels = await DatabaseService.getAllChannels();
    final seriesChannels = allChannels
        .where((c) => c.contentType == ContentType.series)
        .toList();

    final xtreamSeries = seriesChannels.where((c) => c.url.startsWith('xtream://series/')).toList();
    final m3uSeries = seriesChannels.where((c) => !c.url.startsWith('xtream://series/')).toList();

    final seriesMap = SeriesParser.groupIntoSeries(m3uSeries);

    for (var channel in xtreamSeries) {
      final key = '${channel.group ?? "Uncategorized"}_${channel.name}';
      seriesMap[key] = Series(
        name: channel.name,
        poster: channel.logo,
        backdrop: channel.logo,
        plot: channel.description,
        seasons: [],
        rating: 0.0,
      );
    }

    _assignRatingsToSeries(seriesMap.values.toList());

    final categoryCount = <String, int>{};
    final categorizedSeries = <String, List<Series>>{};

    seriesMap.forEach((key, series) {
      final category = key.split('_').first;
      categoryCount[category] = (categoryCount[category] ?? 0) + 1;
      categorizedSeries.putIfAbsent(category, () => []);
      categorizedSeries[category]!.add(series);
    });

    final trending = seriesMap.values.where((s) => (s.rating ?? 0) >= 7.0).toList()
      ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    final trendingList = trending.take(20).toList();

    // Recent: Series with watched episodes
    final recent = seriesMap.values.where((s) {
      return s.seasons.any((season) =>
        season.episodes.any((ep) => ep.watchedMilliseconds > 0));
    }).toList()
      ..sort((a, b) {
        int getMaxWatched(Series series) {
          int maxWatched = 0;
          for (var season in series.seasons) {
            for (var ep in season.episodes) {
              if (ep.watchedMilliseconds > maxWatched) {
                maxWatched = ep.watchedMilliseconds;
              }
            }
          }
          return maxWatched;
        }
        return getMaxWatched(b).compareTo(getMaxWatched(a));
      });
    final recentList = recent.take(20).toList();

    // Favorites: We'll just use trending for now since Episode doesn't have isFavorite
    final favorites = <Series>[];

    // Select featured series
    Series? featured;
    if (trendingList.isNotEmpty) {
      final withPoster = trendingList.where((s) => s.poster != null && s.poster!.isNotEmpty).toList();
      if (withPoster.isNotEmpty) {
        featured = withPoster[Random().nextInt(withPoster.length)];
      } else {
        featured = trendingList.first;
      }
    } else if (seriesMap.isNotEmpty) {
      final withPoster = seriesMap.values.where((s) => s.poster != null && s.poster!.isNotEmpty).toList();
      if (withPoster.isNotEmpty) {
        featured = withPoster.toList()[Random().nextInt(min(10, withPoster.length))];
      }
    }

    setState(() {
      _allSeries = seriesMap;
      _filteredSeries = seriesMap.values.toList();
      _categories = categoryCount;
      _categorizedSeries = categorizedSeries;
      _trendingSeries = trendingList;
      _recentSeries = recentList;
      _favoriteSeries = favorites;
      _featuredSeries = featured;
      _isLoading = false;
    });
  }

  void _assignRatingsToSeries(List<Series> series) {
    for (final s in series) {
      if (s.rating == null || s.rating == 0) {
        final cleanedName = TmdbService.cleanContentName(s.name);
        final rating = _getRatingSync(cleanedName);
        s.rating = rating;
      }
    }
    _loadRatingsFromTmdb(series);
  }

  Future<void> _loadRatingsFromTmdb(List<Series> series) async {
    for (final s in series) {
      if (!mounted) return;
      final cleanedName = TmdbService.cleanContentName(s.name);
      final rating = await TmdbService.getSeriesRatingFromApi(cleanedName);
      if (rating != null && rating > 0) {
        if (mounted) {
          setState(() {
            s.rating = rating;
          });
        }
      }
    }
  }

  double _getRatingSync(String contentName) {
    final cleanedName = contentName.toLowerCase().trim();

    final fallbackRatings = {
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
    };

    for (final entry in fallbackRatings.entries) {
      if (cleanedName.contains(entry.key) || entry.key.contains(cleanedName)) {
        return entry.value;
      }
    }

    int hash = 0;
    for (int i = 0; i < cleanedName.length; i++) {
      hash = ((hash << 5) - hash) + cleanedName.codeUnitAt(i);
      hash = hash & hash;
    }

    final random = Random(hash.abs());
    return 5.0 + (random.nextDouble() * 4.5);
  }

  void _filterSeries() {
    Map<String, Series> filteredMap = {};

    if (_selectedCategory != null) {
      _allSeries.forEach((key, series) {
        if (key.startsWith('${_selectedCategory}_')) {
          filteredMap[key] = series;
        }
      });
    } else {
      filteredMap = Map.from(_allSeries);
    }

    List<Series> filtered = filteredMap.values.toList();

    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((s) =>
              s.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    switch (_sortBy) {
      case 'name':
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'rating':
        filtered.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
        break;
      case 'added':
      default:
        break;
    }

    setState(() {
      _filteredSeries = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final theme = themeProvider.currentTheme;

        if (_isLoading) {
          return Scaffold(
            backgroundColor: theme.backgroundPrimary,
            body: Center(
              child: CircularProgressIndicator(
                color: theme.accentPrimary,
              ),
            ),
          );
        }

        final categories = ['All', ..._categories.keys];

        return Scaffold(
          backgroundColor: theme.backgroundPrimary,
          body: Row(
            children: [
              // Left Sidebar - Categories
              Container(
            width: 280,
            decoration: BoxDecoration(
              color: theme.sidebarBackground,
              border: Border(
                right: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                // Logo and Back button
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.accentPrimary, width: 2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'IPTV',
                          style: TextStyle(
                            color: theme.accentPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Series',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // Search box
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.5)),
                      filled: true,
                      fillColor: theme.backgroundTertiary,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                      _filterSeries();
                    },
                  ),
                ),

                const SizedBox(height: 8),

                // Categories list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final count = category == 'All'
                          ? _allSeries.length
                          : (_categories[category] ?? 0);

                      final isSelected = (_selectedCategory == category ||
                          (_selectedCategory == null && category == 'All'));

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedCategory =
                                  category == 'All' ? null : category;
                            });
                            _filterSeries();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: isSelected
                                      ? theme.accentPrimary
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                              color: isSelected
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.transparent,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    category,
                                    style: TextStyle(
                                      color: isSelected
                                          ? theme.accentPrimary
                                          : Colors.white.withOpacity(0.7),
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? theme.accentPrimary.withOpacity(0.2)
                                        : theme.backgroundTertiary,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    count.toString(),
                                    style: TextStyle(
                                      color: isSelected
                                          ? theme.accentPrimary
                                          : Colors.white.withOpacity(0.5),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
              ),

              // Right side - Content
              Expanded(
            child: Column(
              children: [
                // Top bar with sort options
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.backgroundPrimary,
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Sort dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: theme.sidebarBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.borderPrimary.withOpacity(0.3)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _sortBy,
                            dropdownColor: theme.sidebarBackground,
                            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            items: const [
                              DropdownMenuItem(
                                value: 'added',
                                child: Text('Ordenar por agregado'),
                              ),
                              DropdownMenuItem(
                                value: 'name',
                                child: Text('Ordenar por nombre'),
                              ),
                              DropdownMenuItem(
                                value: 'rating',
                                child: Text('Ordenar por calificación'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _sortBy = value!;
                              });
                              _filterSeries();
                            },
                          ),
                        ),
                      ),

                      const Spacer(),

                      // Total count
                      Text(
                        '${_filteredSeries.length} series',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // Main content area
                Expanded(
                  child: _selectedCategory == null && _searchQuery.isEmpty
                      ? _buildNetflixHomeView(theme)
                      : _buildFilteredGridView(theme),
                ),
              ],
            ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNetflixHomeView(AppThemeType theme) {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // Hero Banner
        SliverToBoxAdapter(
          child: _buildHeroBanner(theme),
        ),

        // Trending Section
        if (_trendingSeries.isNotEmpty) ...[
          _buildSectionHeader('En Tendencia', Icons.whatshot, theme),
          _buildHorizontalCarousel(_trendingSeries, theme, isLarge: true, showRank: true),
        ],

        // Recently Watched
        if (_recentSeries.isNotEmpty) ...[
          _buildSectionHeader('Continuar Viendo', Icons.history, theme),
          _buildHorizontalCarousel(_recentSeries, theme, showProgress: true),
        ],

        // Favorites
        if (_favoriteSeries.isNotEmpty) ...[
          _buildSectionHeader('Mi Lista', Icons.favorite, theme),
          _buildHorizontalCarousel(_favoriteSeries, theme),
        ],

        // Category carousels
        ..._buildCategoryCarousels(theme),

        // Bottom padding
        const SliverToBoxAdapter(
          child: SizedBox(height: 40),
        ),
      ],
    );
  }

  Widget _buildHeroBanner(AppThemeType theme) {
    if (_featuredSeries == null) {
      return const SizedBox(height: 80);
    }

    return Container(
      height: 450,
      margin: const EdgeInsets.only(bottom: 20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          if (_featuredSeries!.poster != null)
            ShaderMask(
              shaderCallback: (rect) {
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black,
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ).createShader(rect);
              },
              blendMode: BlendMode.dstIn,
              child: Image.network(
                _featuredSeries!.poster!,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          theme.cardBackground,
                          theme.backgroundPrimary,
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          // Gradient overlays
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  theme.backgroundPrimary.withOpacity(0.8),
                  theme.backgroundPrimary,
                ],
                stops: const [0.2, 0.7, 1.0],
              ),
            ),
          ),

          // Left gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  theme.backgroundPrimary.withOpacity(0.9),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.6],
              ),
            ),
          ),

          // Content
          Positioned(
            left: 40,
            bottom: 60,
            right: MediaQuery.of(context).size.width * 0.35,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Featured badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.accentPrimary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'SERIE DESTACADA',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Title
                Text(
                  _featuredSeries!.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                    shadows: [
                      Shadow(
                        offset: Offset(2, 2),
                        blurRadius: 8,
                        color: Colors.black,
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // Rating and seasons info
                Row(
                  children: [
                    if (_featuredSeries!.rating != null && _featuredSeries!.rating! > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.getRatingColor(_featuredSeries!.rating!),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              _featuredSeries!.rating!.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    if (_featuredSeries!.seasons.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.accentPrimary.withOpacity(0.5)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${_featuredSeries!.seasons.length} temporada${_featuredSeries!.seasons.length > 1 ? 's' : ''}',
                          style: TextStyle(
                            color: theme.accentPrimary.withOpacity(0.9),
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Description
                if (_featuredSeries!.plot != null && _featuredSeries!.plot!.isNotEmpty)
                  Text(
                    _featuredSeries!.plot!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 20),

                // Action buttons
                Row(
                  children: [
                    // Play button
                    ElevatedButton.icon(
                      onPressed: () => _showDetails(_featuredSeries!),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.accentPrimary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow, size: 24),
                      label: const Text(
                        'Reproducir',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // More info button
                    ElevatedButton.icon(
                      onPressed: () => _showDetails(_featuredSeries!),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.cardBackgroundLight.withOpacity(0.8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.info_outline, size: 20),
                      label: const Text(
                        'Más info',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Add to list button
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.accentPrimary.withOpacity(0.5), width: 2),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.add,
                          color: theme.accentPrimary,
                        ),
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Age rating badge
          Positioned(
            right: 24,
            bottom: 70,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: theme.accentPrimary.withOpacity(0.5), width: 3),
                ),
                color: Colors.black.withOpacity(0.6),
              ),
              child: const Text(
                '16+',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  SliverToBoxAdapter _buildSectionHeader(String title, IconData icon, AppThemeType theme) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        child: Row(
          children: [
            Icon(icon, color: theme.accentPrimary, size: 22),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withOpacity(0.3),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildHorizontalCarousel(
    List<Series> items,
    AppThemeType theme, {
    bool isLarge = false,
    bool showProgress = false,
    bool showRank = false,
  }) {
    final cardWidth = isLarge ? 200.0 : 160.0;
    final cardHeight = isLarge ? 320.0 : 260.0;

    return SliverToBoxAdapter(
      child: SizedBox(
        height: cardHeight,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return _buildNetflixCard(
              items[index],
              theme,
              width: cardWidth,
              isLarge: isLarge,
              showProgress: showProgress,
              rank: showRank ? index + 1 : null,
            );
          },
        ),
      ),
    );
  }

  Widget _buildNetflixCard(
    Series series,
    AppThemeType theme, {
    required double width,
    bool isLarge = false,
    bool showProgress = false,
    int? rank,
  }) {
    return Container(
      width: width,
      margin: const EdgeInsets.only(right: 10),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _showDetails(series),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Main card
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.cardBackground.withOpacity(0.8),
                      theme.backgroundTertiary.withOpacity(0.6),
                    ],
                  ),
                  border: Border.all(
                    color: theme.borderPrimary.withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(8),
                            ),
                            child: series.poster != null
                                ? Image.network(
                                    series.poster!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return _buildPlaceholder(isLarge, theme);
                                    },
                                  )
                                : _buildPlaceholder(isLarge, theme),
                          ),

                          // Gradient overlay
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: 60,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.7),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Rating badge
                          if (series.rating != null && series.rating! > 0)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.getRatingColor(series.rating!),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: Colors.white,
                                      size: 11,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      series.rating!.toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Hover effect
                          Positioned.fill(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _showDetails(series),
                                hoverColor: theme.accentPrimary.withOpacity(0.1),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Title
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            series.name,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isLarge ? 13 : 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (series.seasons.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              '${series.seasons.length} temporada${series.seasons.length > 1 ? 's' : ''}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Rank number (TOP 10 style)
              if (rank != null && rank <= 10)
                Positioned(
                  left: -15,
                  bottom: 40,
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      color: theme.borderPrimary.withOpacity(0.5),
                      fontSize: 80,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      shadows: [
                        Shadow(
                          offset: const Offset(2, 2),
                          blurRadius: 4,
                          color: Colors.black.withOpacity(0.5),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(bool isLarge, AppThemeType theme) {
    return Container(
      color: theme.cardBackground,
      child: Center(
        child: Icon(
          Icons.tv,
          size: isLarge ? 50 : 36,
          color: Colors.white.withOpacity(0.2),
        ),
      ),
    );
  }

  List<Widget> _buildCategoryCarousels(AppThemeType theme) {
    final List<Widget> sections = [];
    final sortedCategories = _categorizedSeries.keys.toList()
      ..sort((a, b) => (_categorizedSeries[b]?.length ?? 0)
          .compareTo(_categorizedSeries[a]?.length ?? 0));

    // Show top 8 categories as carousels
    for (final category in sortedCategories.take(8)) {
      final items = _categorizedSeries[category] ?? [];
      if (items.isNotEmpty) {
        sections.add(_buildSectionHeader(category, Icons.category, theme));
        sections.add(_buildHorizontalCarousel(items.take(20).toList(), theme));
      }
    }

    return sections;
  }

  Widget _buildFilteredGridView(AppThemeType theme) {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 0.65,
        crossAxisSpacing: 16,
        mainAxisSpacing: 20,
      ),
      itemCount: _filteredSeries.length,
      itemBuilder: (context, index) {
        return _buildNetflixCard(
          _filteredSeries[index],
          theme,
          width: 160,
        );
      },
    );
  }

  void _showDetails(Series series) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SeriesDetailScreen(series: series),
      ),
    );
    _loadSeries();
  }
}
