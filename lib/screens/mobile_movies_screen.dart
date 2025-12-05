import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/channel.dart';
import '../services/database_service.dart';
import '../services/m3u_parser.dart';
import '../services/tmdb_service.dart';
import 'mobile_movie_detail_screen.dart';

class MobileMoviesScreen extends StatefulWidget {
  const MobileMoviesScreen({Key? key}) : super(key: key);

  @override
  State<MobileMoviesScreen> createState() => _MobileMoviesScreenState();
}

class _MobileMoviesScreenState extends State<MobileMoviesScreen> {
  List<Channel> _allMovies = [];
  List<Channel> _filteredMovies = [];
  List<Channel> _trendingMovies = [];
  List<Channel> _recentMovies = [];
  List<Channel> _favoriteMovies = [];
  Map<String, List<Channel>> _groupedMovies = {};
  String? _selectedCategory;
  String _searchQuery = '';
  String _sortBy = 'added';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMovies();
  }

  Future<void> _loadMovies() async {
    final allChannels = await DatabaseService.getAllChannels();
    final movies = allChannels
        .where((c) => c.contentType == ContentType.movie)
        .toList();

    final grouped = M3UParser.groupChannels(movies);

    // Trending: Top rated movies (rating >= 7.0)
    final trending = movies.where((m) => m.rating >= 7.0).toList()
      ..sort((a, b) => b.rating.compareTo(a.rating));
    final trendingList = trending.take(20).toList();

    // Recent: Last watched movies
    final recent = movies.where((m) => m.playCount > 0).toList()
      ..sort((a, b) => b.playCount.compareTo(a.playCount));
    final recentList = recent.take(20).toList();

    // Favorites
    final favorites = movies.where((m) => m.isFavorite).toList();

    if (mounted) {
      setState(() {
        _allMovies = movies;
        _filteredMovies = movies;
        _groupedMovies = grouped;
        _trendingMovies = trendingList;
        _recentMovies = recentList;
        _favoriteMovies = favorites;
        _isLoading = false;
      });

      // Load ratings in background
      _loadRatings(movies);
    }
  }

  Future<void> _loadRatings(List<Channel> movies) async {
    for (final movie in movies) {
      if (!mounted) return;

      if (movie.rating == 0) {
        final cleanedName = TmdbService.cleanContentName(movie.name);
        final rating = await TmdbService.getMovieRatingFromApi(cleanedName);

        if (rating != null && rating > 0) {
          await DatabaseService.updateChannelRating(movie, rating);
          if (mounted) {
            setState(() {
              movie.rating = rating;
            });
          }
        }
      }

      if (movie.description == null || movie.description!.isEmpty) {
        final cleanedName = TmdbService.cleanContentName(movie.name);
        final description = await TmdbService.getMovieDescription(cleanedName);

        if (description != null && description.isNotEmpty) {
          movie.description = description;
          await DatabaseService.isar.writeTxn(() async {
            await DatabaseService.isar.channels.put(movie);
          });
          if (mounted) {
            setState(() {});
          }
        }
      }
    }
  }

  void _filterMovies() {
    List<Channel> filtered = _allMovies;

    if (_selectedCategory != null && _selectedCategory != 'All') {
      filtered = filtered
          .where((c) => c.group == _selectedCategory)
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((c) =>
              c.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // Sort
    switch (_sortBy) {
      case 'name':
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'rating':
        filtered.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'added':
      default:
        break;
    }

    setState(() {
      _filteredMovies = filtered;
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
          l10n.movies,
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
              _filterMovies();
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
                  _filterMovies();
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
            if (_groupedMovies.isNotEmpty)
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildCategoryChip('All', l10n.all),
                    ..._groupedMovies.keys.map((category) =>
                      _buildCategoryChip(category, category)
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // Movies content - Netflix style for "All", Grid for specific category
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF5DD3E5),
                      ),
                    )
                  : _searchQuery.isNotEmpty || (_selectedCategory != null && _selectedCategory != 'All')
                      ? _buildGridView(l10n)
                      : _buildNetflixStyleView(l10n),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetflixStyleView(AppLocalizations l10n) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En Tendencia (Trending)
          if (_trendingMovies.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_fire_department,
                    color: Colors.red,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'En Tendencia',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            _buildHorizontalMovieList(_trendingMovies),
            const SizedBox(height: 24),
          ],

          // Visto Recientemente (Recently Watched)
          if (_recentMovies.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.history,
                    color: Color(0xFF5DD3E5),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Visto Recientemente',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            _buildHorizontalMovieList(_recentMovies),
            const SizedBox(height: 24),
          ],

          // Mis Favoritos (My Favorites)
          if (_favoriteMovies.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.favorite,
                    color: Colors.red,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.myFavorites,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            _buildHorizontalMovieList(_favoriteMovies),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildHorizontalMovieList(List<Channel> movies) {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: movies.length,
        itemBuilder: (context, index) {
          final movie = movies[index];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _buildHorizontalMovieCard(movie),
          );
        },
      ),
    );
  }

  Widget _buildHorizontalMovieCard(Channel movie) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MobileMovieDetailScreen(movie: movie),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 140,
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
              color: const Color(0xFF5DD3E5).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster
              Container(
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  color: const Color(0xFF1A3A52).withOpacity(0.3),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        Icons.movie,
                        size: 48,
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                    if (movie.rating > 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getRatingColor(movie.rating),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, color: Colors.white, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                movie.rating.toStringAsFixed(1),
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
              // Movie info
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (movie.group != null && movie.group!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        movie.group!,
                        style: TextStyle(
                          color: const Color(0xFF5DD3E5).withOpacity(0.8),
                          fontSize: 11,
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

  Widget _buildGridView(AppLocalizations l10n) {
    if (_filteredMovies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.movie_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noMovies,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _filteredMovies.length,
      itemBuilder: (context, index) {
        final movie = _filteredMovies[index];
        return _buildMovieCard(movie);
      },
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
          _filterMovies();
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

  Widget _buildMovieCard(Channel movie) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MobileMovieDetailScreen(movie: movie),
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
                        child: movie.logo != null && movie.logo!.isNotEmpty
                            ? Image.network(
                                movie.logo!,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.movie,
                                  color: Colors.white.withOpacity(0.3),
                                  size: 48,
                                ),
                              )
                            : Icon(
                                Icons.movie,
                                color: Colors.white.withOpacity(0.3),
                                size: 48,
                              ),
                      ),
                      // Rating badge
                      if (movie.rating > 0)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getRatingColor(movie.rating),
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
                                  movie.rating.toStringAsFixed(1),
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
                      // Play button overlay
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5DD3E5).withOpacity(0.9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Movie info
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (movie.group != null && movie.group!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        movie.group!,
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
