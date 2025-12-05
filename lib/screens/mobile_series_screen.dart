import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/channel.dart';
import '../services/database_service.dart';
import '../services/tmdb_service.dart';
import 'mobile_series_detail_screen.dart';

class MobileSeriesScreen extends StatefulWidget {
  const MobileSeriesScreen({Key? key}) : super(key: key);

  @override
  State<MobileSeriesScreen> createState() => _MobileSeriesScreenState();
}

class _MobileSeriesScreenState extends State<MobileSeriesScreen> {
  Map<String, List<Channel>> _groupedSeries = {};
  Map<String, Channel> _seriesRepresentatives = {};
  Map<String, List<String>> _groupedByCategory = {};
  List<String> _seriesTitles = [];
  List<String> _filteredSeriesTitles = [];
  String? _selectedCategory;
  String _searchQuery = '';
  String _sortBy = 'added';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSeries();
  }

  Future<void> _loadSeries() async {
    final allChannels = await DatabaseService.getAllChannels();
    final series = allChannels
        .where((c) => c.contentType == ContentType.series)
        .toList();

    // Group episodes by series name (extract base name without season/episode info)
    final Map<String, List<Channel>> groupedBySeriesName = {};
    final Map<String, Channel> representatives = {};

    for (final episode in series) {
      // Extract series name (remove season/episode patterns)
      final seriesName = _extractSeriesName(episode.name);

      if (!groupedBySeriesName.containsKey(seriesName)) {
        groupedBySeriesName[seriesName] = [];
        // Use first episode as representative for the series
        representatives[seriesName] = episode;
      }

      groupedBySeriesName[seriesName]!.add(episode);
    }

    // Sort episodes within each series
    for (final episodes in groupedBySeriesName.values) {
      episodes.sort((a, b) => a.name.compareTo(b.name));
    }

    final seriesTitles = groupedBySeriesName.keys.toList();

    // Group series by category
    final Map<String, List<String>> groupedByCategory = {};
    for (final seriesName in seriesTitles) {
      final category = representatives[seriesName]?.group ?? 'Sin categoría';
      if (!groupedByCategory.containsKey(category)) {
        groupedByCategory[category] = [];
      }
      groupedByCategory[category]!.add(seriesName);
    }

    if (mounted) {
      setState(() {
        _groupedSeries = groupedBySeriesName;
        _seriesRepresentatives = representatives;
        _groupedByCategory = groupedByCategory;
        _seriesTitles = seriesTitles;
        _filteredSeriesTitles = seriesTitles;
        _isLoading = false;
      });

      // Load ratings in background
      _loadRatings(representatives.values.toList());
    }
  }

  String _extractSeriesName(String fullName) {
    // Remove common patterns like S01E01, 1x01, Episode 1, etc.
    String cleaned = fullName;

    // Remove patterns like "S01E01", "S1E1", etc.
    cleaned = cleaned.replaceAll(RegExp(r'\s*[Ss]\d+[Ee]\d+.*'), '');

    // Remove patterns like "1x01", "1x1", etc.
    cleaned = cleaned.replaceAll(RegExp(r'\s*\d+x\d+.*'), '');

    // Remove patterns like "Episode 1", "Ep 1", "Episodio 1", etc.
    cleaned = cleaned.replaceAll(RegExp(r'\s*[Ee]p(isode|isodio)?\s*\d+.*', caseSensitive: false), '');

    // Remove patterns like "Temporada 1", "Season 1", etc.
    cleaned = cleaned.replaceAll(RegExp(r'\s*[Tt]emporada\s*\d+.*'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s*[Ss]eason\s*\d+.*'), '');

    // Remove trailing numbers and dashes
    cleaned = cleaned.replaceAll(RegExp(r'\s*[-:]\s*\d+.*'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s*\d+\s*$'), '');

    return cleaned.trim();
  }

  Future<void> _loadRatings(List<Channel> representatives) async {
    for (final show in representatives) {
      if (!mounted) return;

      if (show.rating == 0) {
        final cleanedName = TmdbService.cleanContentName(show.name);
        final rating = await TmdbService.getMovieRatingFromApi(cleanedName);

        if (rating != null && rating > 0) {
          await DatabaseService.updateChannelRating(show, rating);
          if (mounted) {
            setState(() {
              show.rating = rating;
            });
          }
        }
      }

      if (show.description == null || show.description!.isEmpty) {
        final cleanedName = TmdbService.cleanContentName(show.name);
        final description = await TmdbService.getMovieDescription(cleanedName);

        if (description != null && description.isNotEmpty) {
          show.description = description;
          await DatabaseService.isar.writeTxn(() async {
            await DatabaseService.isar.channels.put(show);
          });
          if (mounted) {
            setState(() {});
          }
        }
      }
    }
  }

  void _filterSeries() {
    List<String> filtered = _seriesTitles;

    // Filter by category
    if (_selectedCategory != null && _selectedCategory != 'All') {
      filtered = filtered
          .where((title) => _seriesRepresentatives[title]?.group == _selectedCategory)
          .toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((title) =>
              title.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // Sort
    switch (_sortBy) {
      case 'name':
        filtered.sort((a, b) => a.compareTo(b));
        break;
      case 'rating':
        filtered.sort((a, b) {
          final ratingA = _seriesRepresentatives[a]?.rating ?? 0;
          final ratingB = _seriesRepresentatives[b]?.rating ?? 0;
          return ratingB.compareTo(ratingA);
        });
        break;
      case 'added':
      default:
        break;
    }

    setState(() {
      _filteredSeriesTitles = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1A2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F2537),
        elevation: 0,
        title: Text(
          l10n.series,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort, color: Colors.white),
            onSelected: (value) {
              setState(() {
                _sortBy = value;
              });
              _filterSeries();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'added',
                child: Text(l10n.sortByAdded),
              ),
              PopupMenuItem(
                value: 'name',
                child: Text(l10n.sortByName),
              ),
              PopupMenuItem(
                value: 'rating',
                child: Text(l10n.sortByRating),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Container(
              padding: const EdgeInsets.all(16),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                  _filterSeries();
                },
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: l10n.search,
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
                  filled: true,
                  fillColor: const Color(0xFF1A3A52).withOpacity(0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),

            // Category filter chips
            if (_groupedByCategory.isNotEmpty)
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildCategoryChip('All', l10n.all),
                    ..._groupedByCategory.keys.map((category) =>
                      _buildCategoryChip(category, category)
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // Series grid
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF5DD3E5),
                      ),
                    )
                  : _filteredSeriesTitles.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.video_library_outlined,
                                size: 64,
                                color: Colors.white.withOpacity(0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.noSeries,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.65,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: _filteredSeriesTitles.length,
                          itemBuilder: (context, index) {
                            final seriesTitle = _filteredSeriesTitles[index];
                            final representative = _seriesRepresentatives[seriesTitle]!;
                            final episodes = _groupedSeries[seriesTitle]!;
                            return _buildSeriesCard(seriesTitle, representative, episodes);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeriesCard(String seriesTitle, Channel representative, List<Channel> episodes) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MobileSeriesDetailScreen(
                series: representative,
                episodes: episodes,
                seriesTitle: seriesTitle,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1A3A52).withOpacity(0.6),
                const Color(0xFF0D2235).withOpacity(0.4),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF2D5F8D).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Poster
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A5F).withOpacity(0.3),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: representative.logo != null && representative.logo!.isNotEmpty
                            ? Image.network(
                                representative.logo!,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.video_library,
                                  color: Colors.white.withOpacity(0.3),
                                  size: 48,
                                ),
                              )
                            : Icon(
                                Icons.video_library,
                                color: Colors.white.withOpacity(0.3),
                                size: 48,
                              ),
                      ),
                      // Rating badge
                      if (representative.rating > 0)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getRatingColor(representative.rating),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Colors.white,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  representative.rating.toStringAsFixed(1),
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
                      // Episodes count badge
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5DD3E5).withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.video_library,
                                color: Colors.white,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${episodes.length} eps',
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
              ),
              // Series info
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      seriesTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (representative.group != null && representative.group!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        representative.group!,
                        style: TextStyle(
                          color: const Color(0xFF5DD3E5).withOpacity(0.8),
                          fontSize: 12,
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
      ),
    );
  }

  Widget _buildCategoryChip(String value, String label) {
    final isSelected = _selectedCategory == value;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedCategory = selected ? value : null;
          });
          _filterSeries();
        },
        backgroundColor: const Color(0xFF1A3A52).withOpacity(0.5),
        selectedColor: const Color(0xFF5DD3E5),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
        checkmarkColor: Colors.white,
      ),
    );
  }

  Color _getRatingColor(double rating) {
    if (rating >= 8.0) {
      return const Color(0xFF4CAF50);
    } else if (rating >= 7.0) {
      return const Color(0xFF8BC34A);
    } else if (rating >= 6.0) {
      return const Color(0xFFFFC107);
    } else if (rating >= 5.0) {
      return const Color(0xFFFF9800);
    } else {
      return const Color(0xFFF44336);
    }
  }
}
