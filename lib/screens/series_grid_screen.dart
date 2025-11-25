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
import 'series_detail_screen.dart';

class SeriesGridScreen extends StatefulWidget {
  const SeriesGridScreen({Key? key}) : super(key: key);

  @override
  State<SeriesGridScreen> createState() => _SeriesGridScreenState();
}

class _SeriesGridScreenState extends State<SeriesGridScreen> {
  Map<String, Series> _allSeries = {};
  List<Series> _filteredSeries = [];
  Map<String, int> _categories = {}; // category -> count
  String? _selectedCategory;
  String _searchQuery = '';
  String _sortBy = 'added';

  @override
  void initState() {
    super.initState();
    _loadSeries();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // No longer need Xtream-specific loading - everything is in database
  }

  Future<void> _loadSeries() async {
    final allChannels = await DatabaseService.getAllChannels();
    final seriesChannels = allChannels
        .where((c) => c.contentType == ContentType.series)
        .toList();

    // Separar series de Xtream (URL empieza con "xtream://") y series normales (M3U)
    final xtreamSeries = seriesChannels.where((c) => c.url.startsWith('xtream://series/')).toList();
    final m3uSeries = seriesChannels.where((c) => !c.url.startsWith('xtream://series/')).toList();

    // Procesar series M3U normalmente (con episodios en la base de datos)
    final seriesMap = SeriesParser.groupIntoSeries(m3uSeries);

    // Para series de Xtream, crear objetos Series sin episodios (se cargarán bajo demanda)
    for (var channel in xtreamSeries) {
      final key = '${channel.group ?? "Uncategorized"}_${channel.name}';
      seriesMap[key] = Series(
        name: channel.name,
        poster: channel.logo,
        backdrop: channel.logo,
        plot: channel.description,
        seasons: [], // Sin episodios por ahora
        rating: 0.0, // Se asignará después
      );
    }

    // Assign ratings to series
    _assignRatingsToSeries(seriesMap.values.toList());

    // Extract unique categories (groups) from channels
    final categoryCount = <String, int>{};
    for (var channel in seriesChannels) {
      final category = channel.group ?? 'Uncategorized';
      categoryCount[category] = (categoryCount[category] ?? 0) + 1;
    }

    setState(() {
      _allSeries = seriesMap;
      _filteredSeries = seriesMap.values.toList();
      _categories = categoryCount;
    });
  }

  /// Assign ratings to series
  void _assignRatingsToSeries(List<Series> series) {
    for (final s in series) {
      if (s.rating == null || s.rating == 0) {
        final cleanedName = TmdbService.cleanContentName(s.name);
        final rating = _getRatingSync(cleanedName);
        s.rating = rating;
      }
    }

    // Load ratings from TMDB in the background
    _loadRatingsFromTmdb(series);
  }

  Future<void> _loadRatingsFromTmdb(List<Series> series) async {
    for (final s in series) {
      if (!mounted) return; // Stop if widget is disposed
      final cleanedName = TmdbService.cleanContentName(s.name);
      // Load only from real APIs (not fallback/pseudo-random)
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

  /// Get rating synchronously (from fallback or pseudo-random)
  double _getRatingSync(String contentName) {
    final cleanedName = contentName.toLowerCase().trim();

    // Check fallback ratings
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

    // Generate pseudo-random rating based on hash
    int hash = 0;
    for (int i = 0; i < cleanedName.length; i++) {
      hash = ((hash << 5) - hash) + cleanedName.codeUnitAt(i);
      hash = hash & hash;
    }

    final random = Random(hash.abs());
    return 5.0 + (random.nextDouble() * 4.5);
  }

  void _filterSeries() {
    // Filter by category first from the map keys
    Map<String, Series> filteredMap = {};

    if (_selectedCategory != null) {
      // Filter series that belong to selected category
      // Keys are in format: "category_seriesName"
      _allSeries.forEach((key, series) {
        if (key.startsWith('${_selectedCategory}_')) {
          filteredMap[key] = series;
        }
      });
    } else {
      filteredMap = Map.from(_allSeries);
    }

    List<Series> filtered = filteredMap.values.toList();

    // Filter by search
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((s) =>
              s.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // Sort
    switch (_sortBy) {
      case 'name':
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'rating':
        filtered.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
        break;
      case 'added':
      default:
        // Keep original order
        break;
    }

    setState(() {
      _filteredSeries = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Everything is now in database - no need for Xtream-specific logic
    final categories = ['All', ..._categories.keys];

    return Scaffold(
      backgroundColor: const Color(0xFF0F1E2B),
      body: Row(
        children: [
          // Left Sidebar
          Container(
            width: 380,
            decoration: BoxDecoration(
              color: const Color(0xFF1A2B3C),
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
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'IPTV',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Series',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Search box
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.5)),
                      filled: true,
                      fillColor: const Color(0xFF0F1E2B),
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

                // Categories list
                Expanded(
                  child: ListView(
                    children: [
                      // All category
                      Material(
                        color: _selectedCategory == null
                            ? const Color(0xFF2D4A5E)
                            : Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedCategory = null;
                            });
                            _filterSeries();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'All',
                                  style: TextStyle(
                                    color: _selectedCategory == null
                                        ? const Color(0xFF5DD3E5)
                                        : Colors.white,
                                    fontSize: 14,
                                    fontWeight: _selectedCategory == null
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                Text(
                                  _allSeries.length.toString(),
                                  style: TextStyle(
                                    color: _selectedCategory == null
                                        ? const Color(0xFF5DD3E5)
                                        : Colors.white54,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Category items
                      ..._categories.entries.map((entry) {
                              final category = entry.key;
                              final count = entry.value;
                              final isSelected = _selectedCategory == category;

                              return Material(
                                color: isSelected
                                    ? const Color(0xFF2D4A5E)
                                    : Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedCategory = category;
                                    });
                                    _filterSeries();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 16,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            category.toUpperCase(),
                                            style: TextStyle(
                                              color: isSelected
                                                  ? const Color(0xFF5DD3E5)
                                                  : Colors.white,
                                              fontSize: 13,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          count.toString(),
                                          style: TextStyle(
                                            color: isSelected
                                                ? const Color(0xFF5DD3E5)
                                                : Colors.white54,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Right side - Series Grid
          Expanded(
            child: Column(
              children: [
                // Top bar with search and filters
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2B3C),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Search bar
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D4A5E),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: TextField(
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Search',
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: Colors.white.withOpacity(0.5),
                              ),
                              border: InputBorder.none,
                            ),
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                              });
                              _filterSeries();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Sort dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D4A5E),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          value: _sortBy,
                          dropdownColor: const Color(0xFF2D4A5E),
                          underline: Container(),
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                          style: const TextStyle(color: Colors.white),
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

                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.grid_view, color: Colors.white),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today, color: Colors.white),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(Icons.play_circle_outline,
                            color: Colors.white),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(Icons.view_module, color: Color(0xFF5DD3E5)),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),

                // Series Grid with Sections
                Expanded(
                  child: _selectedCategory == null
                          ? CustomScrollView(
                              slivers: [
                                // Trending Section
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                                    child: _buildSectionHeader('En Tendencia', Icons.whatshot),
                                  ),
                                ),
                                SliverToBoxAdapter(
                                  child: SizedBox(
                                    height: 280,
                                    child: _allSeries.isEmpty
                                        ? Center(
                                            child: Text(
                                              'Sin contenido',
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.5),
                                                fontSize: 14,
                                              ),
                                            ),
                                          )
                                        : ListView.builder(
                                            scrollDirection: Axis.horizontal,
                                            padding: const EdgeInsets.symmetric(horizontal: 16),
                                            itemCount: _getTrendingSeries().length,
                                            itemBuilder: (context, index) {
                                              final series = _getTrendingSeries()[index];
                                              return _buildTrendingSeriesCard(series, index + 1);
                                            },
                                          ),
                                  ),
                                ),

                                // Recently Watched Section
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 32, 16, 12),
                                    child: _buildSectionHeader('Visto Recientemente', Icons.history),
                                  ),
                                ),
                                SliverToBoxAdapter(
                                  child: SizedBox(
                                    height: 220,
                                    child: _allSeries.values
                                            .where((s) => s.seasons.isNotEmpty && s.seasons.first.episodes.isNotEmpty && s.seasons.first.episodes.first.watchedMilliseconds > 0)
                                            .isEmpty
                                        ? Center(
                                            child: Text(
                                              'Sin contenido',
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.5),
                                                fontSize: 14,
                                              ),
                                            ),
                                          )
                                        : ListView.builder(
                                            scrollDirection: Axis.horizontal,
                                            padding: const EdgeInsets.symmetric(horizontal: 16),
                                            itemCount: _allSeries.values
                                                .where((s) => s.seasons.isNotEmpty && s.seasons.first.episodes.isNotEmpty && s.seasons.first.episodes.first.watchedMilliseconds > 0)
                                                .length,
                                            itemBuilder: (context, index) {
                                              final recentlyWatched = _allSeries.values
                                                  .where((s) => s.seasons.isNotEmpty && s.seasons.first.episodes.isNotEmpty && s.seasons.first.episodes.first.watchedMilliseconds > 0)
                                                  .toList();
                                              if (index < recentlyWatched.length) {
                                                return _buildHorizontalSeriesCard(recentlyWatched[index]);
                                              }
                                              return const SizedBox.shrink();
                                            },
                                          ),
                                  ),
                                ),

                                // Favorites Section
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 32, 16, 12),
                                    child: _buildSectionHeader('Mis Favoritos', Icons.favorite),
                                  ),
                                ),
                                SliverToBoxAdapter(
                                  child: SizedBox(
                                    height: 220,
                                    child: _allSeries.values
                                            .where((s) => s.seasons.isNotEmpty && s.seasons.first.episodes.isNotEmpty && s.seasons.first.episodes.first.watchedMilliseconds > 0)
                                            .isEmpty
                                        ? Center(
                                            child: Text(
                                              'Sin favoritos',
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.5),
                                                fontSize: 14,
                                              ),
                                            ),
                                          )
                                        : ListView.builder(
                                            scrollDirection: Axis.horizontal,
                                            padding: const EdgeInsets.symmetric(horizontal: 16),
                                            itemCount: _allSeries.values
                                                .where((s) => s.seasons.isNotEmpty && s.seasons.first.episodes.isNotEmpty && s.seasons.first.episodes.first.watchedMilliseconds > 0)
                                                .length,
                                            itemBuilder: (context, index) {
                                              final favorites = _allSeries.values
                                                  .where((s) => s.seasons.isNotEmpty && s.seasons.first.episodes.isNotEmpty && s.seasons.first.episodes.first.watchedMilliseconds > 0)
                                                  .toList();
                                              if (index < favorites.length) {
                                                return _buildHorizontalSeriesCard(favorites[index]);
                                              }
                                              return const SizedBox.shrink();
                                            },
                                          ),
                                  ),
                                ),

                                const SliverToBoxAdapter(child: SizedBox(height: 32)),
                              ],
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                childAspectRatio: 0.65,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemCount: _filteredSeries.length,
                              itemBuilder: (context, index) {
                                return _buildSeriesCard(_filteredSeries[index]);
                              },
                            )
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Series> _getTrendingSeries() {
    // Sort by rating from ALL series (not filtered) - trending = highest rated
    final sorted = List<Series>.from(_filteredSeries.isEmpty ? _allSeries.values.toList() : _filteredSeries);
    sorted.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    return sorted.take(10).toList();
  }

  Widget _buildTrendingSeriesCard(Series series, int position) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SeriesDetailScreen(series: series),
              ),
            );
            _loadSeries();
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: const Color(0xFF1A2B3C),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Background image
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: const Color(0xFF2D4A5E),
                  ),
                  child: series.poster != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            series.poster!,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Icon(
                                  Icons.movie,
                                  size: 60,
                                  color: Colors.white.withOpacity(0.2),
                                ),
                              );
                            },
                          ),
                        )
                      : Center(
                          child: Icon(
                            Icons.movie,
                            size: 60,
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                ),

                // Dark gradient overlay
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
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

                // Top 10 badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE50914),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.6),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Text(
                      'TOP $position',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),

                // Rating badge
                if (series.rating != null && series.rating! > 0)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getRatingColor(series.rating ?? 0),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.6),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star,
                            color: Colors.white,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            (series.rating ?? 0).toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Title at bottom
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(14),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.8),
                        ],
                      ),
                    ),
                    child: Text(
                      series.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFE50914), size: 28),
          const SizedBox(width: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalSeriesCard(Series series) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SeriesDetailScreen(series: series),
              ),
            );
            _loadSeries();
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFF1A2B3C),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Poster image
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          color: const Color(0xFF2D4A5E),
                        ),
                        child: series.poster != null
                            ? ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12),
                                ),
                                child: Image.network(
                                  series.poster!,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Icon(
                                        Icons.movie,
                                        size: 40,
                                        color: Colors.white.withOpacity(0.3),
                                      ),
                                    );
                                  },
                                ),
                              )
                            : Center(
                                child: Icon(
                                  Icons.movie,
                                  size: 40,
                                  color: Colors.white.withOpacity(0.3),
                                ),
                              ),
                      ),
                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.3),
                            ],
                          ),
                        ),
                      ),
                      // Rating badge
                      if (series.rating != null && series.rating! > 0)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getRatingColor(series.rating ?? 0),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Colors.white,
                                  size: 11,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  (series.rating ?? 0.0).toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
                  child: Text(
                    series.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSeriesCard(Series series) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SeriesDetailScreen(series: series),
            ),
          );
          // Reload series when returning from detail screen to show updated progress
          _loadSeries();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFF1A2B3C),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster image
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                        color: const Color(0xFF2D4A5E),
                      ),
                      child: series.poster != null
                          ? ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8),
                              ),
                              child: Image.network(
                                series.poster!,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Icon(
                                      Icons.movie,
                                      size: 48,
                                      color: Colors.white.withOpacity(0.3),
                                    ),
                                  );
                                },
                              ),
                            )
                          : Center(
                              child: Icon(
                                Icons.movie,
                                size: 48,
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                    ),

                    // Rating badge (show only if rating > 0)
                    if (series.rating != null && series.rating! > 0)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getRatingColor(series.rating ?? 0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.white,
                                size: 12,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                (series.rating ?? 0.0).toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  series.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getRatingColor(double rating) {
    if (rating >= 8.0) {
      return const Color(0xFF4CAF50); // Green for excellent
    } else if (rating >= 7.0) {
      return const Color(0xFF8BC34A); // Light green for very good
    } else if (rating >= 6.0) {
      return const Color(0xFFFFC107); // Amber for good
    } else if (rating >= 5.0) {
      return const Color(0xFFFF9800); // Orange for fair
    } else {
      return const Color(0xFFF44336); // Red for poor
    }
  }

  Widget _buildXtreamGrid(ContentProvider contentProvider) {
    if (contentProvider.isLoadingSeries) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final items = contentProvider.filteredSeriesItems;

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.tv_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Sin series',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.65,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _buildXtreamSeriesCard(items[index], contentProvider);
      },
    );
  }

  Widget _buildXtreamSeriesCard(SeriesItem series, ContentProvider contentProvider) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          // For now, just show a message that series playback is not yet implemented
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Series detail view coming soon'),
              duration: Duration(seconds: 1),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFF1A2B3C),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster image
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                        color: const Color(0xFF2D4A5E),
                      ),
                      child: series.posterUrl != null
                          ? ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8),
                              ),
                              child: Image.network(
                                series.posterUrl!,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Icon(
                                      Icons.tv,
                                      size: 48,
                                      color: Colors.white.withOpacity(0.3),
                                    ),
                                  );
                                },
                              ),
                            )
                          : Center(
                              child: Icon(
                                Icons.tv,
                                size: 48,
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                    ),
                    // Favorite button
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        icon: Icon(
                          series.isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: series.isFavorite ? Colors.red : Colors.white,
                          size: 20,
                        ),
                        onPressed: () {
                          contentProvider.toggleSeriesFavorite(series.id);
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  series.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
