import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/channel.dart';
import '../models/vod_item.dart';
import '../services/database_service.dart';
import '../services/m3u_parser.dart';
import '../services/tmdb_service.dart';
import '../providers/content_provider.dart';
import 'movie_detail_screen.dart';
import 'video_player_screen.dart';

class ContentGridScreen extends StatefulWidget {
  final ContentType contentType;
  final String title;

  const ContentGridScreen({
    Key? key,
    required this.contentType,
    required this.title,
  }) : super(key: key);

  @override
  State<ContentGridScreen> createState() => _ContentGridScreenState();
}

class _ContentGridScreenState extends State<ContentGridScreen> {
  List<Channel> _allContent = [];
  List<Channel> _filteredContent = [];
  Map<String, List<Channel>> _groupedContent = {};
  String? _selectedCategory;
  String _searchQuery = '';
  String _sortBy = 'added'; // added, name, rating

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // No longer need Xtream-specific loading - everything is in database
  }

  Future<void> _loadContent() async {
    final allChannels = await DatabaseService.getAllChannels();
    final content = allChannels
        .where((c) => c.contentType == widget.contentType)
        .toList();

    final grouped = M3UParser.groupChannels(content);

    setState(() {
      _allContent = content;
      _filteredContent = content;
      _groupedContent = grouped;
    });

    // Load ratings in the background
    _loadRatings(content);
  }

  Future<void> _loadRatings(List<Channel> content) async {
    for (final channel in content) {
      if (!mounted) return; // Stop if widget is disposed
      final cleanedName = TmdbService.cleanContentName(channel.name);

      // Load rating only from real APIs (not fallback/pseudo-random)
      if (channel.rating == 0) {
        final rating = await TmdbService.getMovieRatingFromApi(cleanedName);
        if (rating != null && rating > 0) {
          await DatabaseService.updateChannelRating(channel, rating);
          if (mounted) {
            setState(() {
              channel.rating = rating;
            });
          }
        }
      }

      // Load description
      if (channel.description == null || channel.description!.isEmpty) {
        final description = await TmdbService.getMovieDescription(cleanedName);
        if (description != null && description.isNotEmpty) {
          channel.description = description;
          await DatabaseService.isar.writeTxn(() async {
            await DatabaseService.isar.channels.put(channel);
          });
          if (mounted) {
            setState(() {});
          }
        }
      }
    }
  }

  void _filterContent() {
    List<Channel> filtered = _allContent;

    // Filter by category
    if (_selectedCategory != null && _selectedCategory != 'All') {
      filtered = filtered
          .where((c) => c.group == _selectedCategory)
          .toList();
    }

    // Filter by search
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
        // Already in order
        break;
    }

    setState(() {
      _filteredContent = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Everything is now in database - no need for Xtream-specific logic
    final categories = ['All', ..._groupedContent.keys];

    return Scaffold(
      backgroundColor: const Color(0xFF0F1E2B),
      body: Row(
        children: [
          // Left Sidebar - Categories
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
                      Text(
                        widget.title,
                        style: const TextStyle(
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
                      _filterContent();
                    },
                  ),
                ),

                // Categories list
                Expanded(
                  child: ListView.builder(
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final count = category == 'All'
                          ? _allContent.length
                          : (_groupedContent[category]?.length ?? 0);

                      final isSelected = (_selectedCategory == category ||
                          (_selectedCategory == null && category == 'All'));

                      return Material(
                        color: isSelected
                            ? const Color(0xFF2D4A5E)
                            : Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedCategory =
                                  category == 'All' ? null : category;
                            });
                            _filterContent();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    category,
                                    style: TextStyle(
                                      color: isSelected
                                          ? const Color(0xFF5DD3E5)
                                          : Colors.white,
                                      fontSize: 14,
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
                                        : Colors.white.withOpacity(0.5),
                                    fontSize: 14,
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

          // Right side - Content Grid
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
                              _filterContent();
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
                            _filterContent();
                          },
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Grid/List toggle
                      IconButton(
                        icon: const Icon(Icons.grid_view, color: Colors.white),
                        onPressed: () {},
                      ),

                      // Action icons
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

                // Content Grid with Sections
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
                                    child: _allContent.isEmpty
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
                                            itemCount: _getTrendingContent().length,
                                            itemBuilder: (context, index) {
                                              final content = _getTrendingContent()[index];
                                              return _buildTrendingCard(content, index + 1);
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
                                    child: _allContent
                                            .where((c) => c.lastPlayed != null)
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
                                            itemCount: _allContent
                                                .where((c) => c.lastPlayed != null)
                                                .length,
                                            itemBuilder: (context, index) {
                                              final recentlyWatched = _allContent
                                                  .where((c) => c.lastPlayed != null)
                                                  .toList();
                                              if (index < recentlyWatched.length) {
                                                return _buildHorizontalCard(recentlyWatched[index]);
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
                                    child: _allContent
                                            .where((c) => c.isFavorite)
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
                                            itemCount: _allContent
                                                .where((c) => c.isFavorite)
                                                .length,
                                            itemBuilder: (context, index) {
                                              final favorites = _allContent
                                                  .where((c) => c.isFavorite)
                                                  .toList();
                                              if (index < favorites.length) {
                                                return _buildHorizontalCard(favorites[index]);
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
                              itemCount: _filteredContent.length,
                              itemBuilder: (context, index) {
                                return _buildContentCard(_filteredContent[index]);
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

  List<Channel> _getTrendingContent() {
    // Sort by rating from ALL content (not filtered) - trending = highest rated
    final sorted = List<Channel>.from(_allContent);
    sorted.sort((a, b) => (b.rating).compareTo(a.rating));
    return sorted.take(10).toList();
  }

  Widget _buildTrendingCard(Channel content, int position) {
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
                builder: (context) => MovieDetailScreen(movie: content),
              ),
            );
            _loadContent();
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
                  child: content.logo != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            content.logo!,
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
                if (content.rating > 0)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getRatingColor(content.rating),
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
                            content.rating.toStringAsFixed(1),
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
                      content.name,
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

  Widget _buildHorizontalCard(Channel content) {
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
                builder: (context) => MovieDetailScreen(movie: content),
              ),
            );
            _loadContent();
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
                        child: content.logo != null
                            ? ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12),
                                ),
                                child: Image.network(
                                  content.logo!,
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
                      if (content.rating > 0)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getRatingColor(content.rating),
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
                                  content.rating.toStringAsFixed(1),
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
                    content.name,
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

  Widget _buildContentCard(Channel content) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MovieDetailScreen(movie: content),
            ),
          );
          // Reload content when returning from detail screen to show updated progress
          _loadContent();
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
                      child: content.logo != null
                          ? ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8),
                              ),
                              child: Image.network(
                                content.logo!,
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
                    if (content.rating > 0)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getRatingColor(content.rating),
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
                                content.rating.toStringAsFixed(1),
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
                  content.name,
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
    if (contentProvider.isLoadingVod) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final items = contentProvider.filteredVodItems;

    if (items.isEmpty) {
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
              'Sin películas',
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
        return _buildVodCard(items[index], contentProvider);
      },
    );
  }

  Widget _buildVodCard(VodItem movie, ContentProvider contentProvider) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          // Create a temporary Channel object from VodItem
          final tempChannel = Channel()
            ..name = movie.name
            ..url = movie.streamUrl
            ..logo = movie.posterUrl
            ..group = movie.categoryName
            ..contentType = ContentType.movie;

          // Navigate to video player with the movie
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VideoPlayerScreen(
                channel: tempChannel,
              ),
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
                      child: movie.posterUrl != null
                          ? ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8),
                              ),
                              child: Image.network(
                                movie.posterUrl!,
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
                    // Favorite button
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        icon: Icon(
                          movie.isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: movie.isFavorite ? Colors.red : Colors.white,
                          size: 20,
                        ),
                        onPressed: () {
                          contentProvider.toggleVodFavorite(movie.id);
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
                  movie.name,
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
