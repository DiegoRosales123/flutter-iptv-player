import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/channel.dart';
import '../models/vod_item.dart';
import '../services/database_service.dart';
import '../services/m3u_parser.dart';
import '../services/tmdb_service.dart';
import '../providers/content_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/app_theme.dart';
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
  List<Channel> _trendingContent = [];
  List<Channel> _recentContent = [];
  List<Channel> _favoriteContent = [];
  Map<String, List<Channel>> _groupedContent = {};
  String? _selectedCategory;
  String _searchQuery = '';
  String _sortBy = 'added';
  Channel? _featuredContent;
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadContent() async {
    final allChannels = await DatabaseService.getAllChannels();
    final content = allChannels
        .where((c) => c.contentType == widget.contentType)
        .toList();

    final grouped = M3UParser.groupChannels(content);

    // Trending: Top rated content (rating >= 7.0)
    final trending = content.where((c) => c.rating >= 7.0).toList()
      ..sort((a, b) => b.rating.compareTo(a.rating));
    final trendingList = trending.take(20).toList();

    // Recent: Last watched content
    final recent = content.where((c) => c.playCount > 0).toList()
      ..sort((a, b) => b.playCount.compareTo(a.playCount));
    final recentList = recent.take(20).toList();

    // Favorites
    final favorites = content.where((c) => c.isFavorite).toList();

    // Select featured content (random from trending or first with logo)
    Channel? featured;
    if (trendingList.isNotEmpty) {
      final withLogo = trendingList.where((c) => c.logo != null && c.logo!.isNotEmpty).toList();
      if (withLogo.isNotEmpty) {
        featured = withLogo[Random().nextInt(withLogo.length)];
      } else {
        featured = trendingList.first;
      }
    } else if (content.isNotEmpty) {
      final withLogo = content.where((c) => c.logo != null && c.logo!.isNotEmpty).toList();
      if (withLogo.isNotEmpty) {
        featured = withLogo[Random().nextInt(min(10, withLogo.length))];
      }
    }

    setState(() {
      _allContent = content;
      _filteredContent = content;
      _groupedContent = grouped;
      _trendingContent = trendingList;
      _recentContent = recentList;
      _favoriteContent = favorites;
      _featuredContent = featured;
      _isLoading = false;
    });

    // Load ratings in the background
    _loadRatings(content);
  }

  Future<void> _loadRatings(List<Channel> content) async {
    for (final channel in content) {
      if (!mounted) return;
      final cleanedName = TmdbService.cleanContentName(channel.name);

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
      _filteredContent = filtered;
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

        final categories = ['All', ..._groupedContent.keys];

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
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
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
                      _filterContent();
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
                          ? _allContent.length
                          : (_groupedContent[category]?.length ?? 0);

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
                            _filterContent();
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

              // Right side - Content with Netflix style
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
                              _filterContent();
                            },
                          ),
                        ),
                      ),

                      const Spacer(),

                      // Total count
                      Text(
                        '${_filteredContent.length} títulos',
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
        if (_trendingContent.isNotEmpty) ...[
          _buildSectionHeader('En Tendencia', Icons.whatshot, theme),
          _buildHorizontalCarousel(_trendingContent, theme, isLarge: true, showRank: true),
        ],

        // Recently Watched
        if (_recentContent.isNotEmpty) ...[
          _buildSectionHeader('Continuar Viendo', Icons.history, theme),
          _buildHorizontalCarousel(_recentContent, theme, showProgress: true),
        ],

        // Favorites
        if (_favoriteContent.isNotEmpty) ...[
          _buildSectionHeader('Mi Lista', Icons.favorite, theme),
          _buildHorizontalCarousel(_favoriteContent, theme),
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
    if (_featuredContent == null) {
      return const SizedBox(height: 80);
    }

    return Container(
      height: 450,
      margin: const EdgeInsets.only(bottom: 20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          if (_featuredContent!.logo != null)
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
                _featuredContent!.logo!,
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
                    'DESTACADO',
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
                  _featuredContent!.name,
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

                // Rating and category
                Row(
                  children: [
                    if (_featuredContent!.rating > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.getRatingColor(_featuredContent!.rating),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              _featuredContent!.rating.toStringAsFixed(1),
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
                    if (_featuredContent!.group != null)
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
                          _featuredContent!.group!,
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
                if (_featuredContent!.description != null &&
                    _featuredContent!.description!.isNotEmpty)
                  Text(
                    _featuredContent!.description!,
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
                      onPressed: () => _playContent(_featuredContent!),
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
                      onPressed: () => _showDetails(_featuredContent!),
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
                          _featuredContent!.isFavorite
                              ? Icons.check
                              : Icons.add,
                          color: theme.accentPrimary,
                        ),
                        onPressed: () async {
                          _featuredContent!.isFavorite = !_featuredContent!.isFavorite;
                          await DatabaseService.isar.writeTxn(() async {
                            await DatabaseService.isar.channels.put(_featuredContent!);
                          });
                          setState(() {});
                        },
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
    List<Channel> items,
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
    Channel content,
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
          onTap: () => _showDetails(content),
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
                            child: content.logo != null
                                ? Image.network(
                                    content.logo!,
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
                          if (content.rating > 0)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.getRatingColor(content.rating),
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
                                      content.rating.toStringAsFixed(1),
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

                          // Progress bar
                          if (showProgress && content.watchedMilliseconds > 0)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  color: theme.backgroundTertiary,
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(8),
                                    bottomRight: Radius.circular(8),
                                  ),
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: content.totalMilliseconds > 0
                                      ? (content.watchedMilliseconds /
                                              content.totalMilliseconds)
                                          .clamp(0.0, 1.0)
                                      : 0.0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: theme.accentPrimary,
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          // Hover effect
                          Positioned.fill(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _showDetails(content),
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
                            content.name,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isLarge ? 13 : 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (content.group != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              content.group!,
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
          Icons.movie,
          size: isLarge ? 50 : 36,
          color: Colors.white.withOpacity(0.2),
        ),
      ),
    );
  }

  List<Widget> _buildCategoryCarousels(AppThemeType theme) {
    final List<Widget> sections = [];
    final sortedCategories = _groupedContent.keys.toList()
      ..sort((a, b) => (_groupedContent[b]?.length ?? 0)
          .compareTo(_groupedContent[a]?.length ?? 0));

    // Show top 8 categories as carousels
    for (final category in sortedCategories.take(8)) {
      final items = _groupedContent[category] ?? [];
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
      itemCount: _filteredContent.length,
      itemBuilder: (context, index) {
        return _buildNetflixCard(
          _filteredContent[index],
          theme,
          width: 160,
        );
      },
    );
  }

  void _playContent(Channel content) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(channel: content),
      ),
    );
    _loadContent();
  }

  void _showDetails(Channel content) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MovieDetailScreen(movie: content),
      ),
    );
    _loadContent();
  }
}
