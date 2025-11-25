import 'package:flutter/material.dart';
import '../models/series.dart';
import '../models/channel.dart';
import '../models/playlist.dart';
import '../services/tmdb_service.dart';
import '../services/database_service.dart';
import '../services/xtream_service.dart';
import '../services/preferences_service.dart';
import 'video_player_screen.dart';

class SeriesDetailScreen extends StatefulWidget {
  final Series series;

  const SeriesDetailScreen({Key? key, required this.series}) : super(key: key);

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  int _selectedSeasonIndex = 0;
  Future<String?>? _descriptionFuture;
  bool _loadingEpisodes = false;
  List<Season> _loadedSeasons = [];

  @override
  void initState() {
    super.initState();
    _descriptionFuture = _loadDescription();
    _loadedSeasons = List.from(widget.series.seasons);

    // Si no hay episodios, intentar cargarlos de Xtream
    if (_loadedSeasons.isEmpty) {
      _loadXtreamEpisodes();
    }
  }

  Future<String?> _loadDescription() async {
    if (widget.series.plot != null && widget.series.plot!.isNotEmpty) {
      return widget.series.plot;
    }
    final cleanedName = TmdbService.cleanContentName(widget.series.name);
    final description = await TmdbService.getSeriesDescription(cleanedName);
    return description;
  }

  Future<void> _loadXtreamEpisodes() async {
    setState(() => _loadingEpisodes = true);

    try {
      // Buscar el canal de esta serie en la base de datos
      final allChannels = await DatabaseService.getAllChannels();
      final seriesChannel = allChannels.firstWhere(
        (c) => c.contentType == ContentType.series &&
               c.name == widget.series.name &&
               c.url.startsWith('xtream://series/'),
        orElse: () => Channel(),
      );

      if (seriesChannel.url.isEmpty) {
        // No es una serie de Xtream, salir
        setState(() => _loadingEpisodes = false);
        return;
      }

      // Extraer el series_id de la URL: xtream://series/123
      final seriesId = int.tryParse(seriesChannel.url.split('/').last);
      if (seriesId == null) {
        setState(() => _loadingEpisodes = false);
        return;
      }

      // Obtener la playlist activa para obtener credenciales
      final activePlaylistId = await PreferencesService.getActivePlaylistId();
      if (activePlaylistId == null) {
        setState(() => _loadingEpisodes = false);
        return;
      }

      final playlists = await DatabaseService.getAllPlaylists();
      final activePlaylist = playlists.firstWhere(
        (p) => p.id == activePlaylistId,
        orElse: () => Playlist()..name = ''..url = '',
      );

      if (!activePlaylist.isXtreamCodes) {
        setState(() => _loadingEpisodes = false);
        return;
      }

      // Crear servicio Xtream y cargar episodios
      final service = XtreamService(
        baseUrl: activePlaylist.url,
        username: activePlaylist.username!,
        password: activePlaylist.password!,
      );

      final result = await service.getSeriesInfo(seriesId);

      if (result['success'] == true) {
        final seriesInfo = result['data'];
        final episodes = seriesInfo['episodes'] as Map<String, dynamic>?;

        if (episodes != null && episodes.isNotEmpty) {
          final seasons = <Season>[];

          episodes.forEach((seasonNum, seasonData) {
            final episodesList = seasonData as List;
            final episodeObjects = <Episode>[];

            for (var episode in episodesList) {
              final episodeNum = int.tryParse(episode['episode_num']?.toString() ?? '0') ?? 0;
              final containerExt = episode['container_extension']?.toString() ?? 'mp4';
              final episodeId = episode['id']?.toString() ?? '';
              final episodeTitle = episode['title']?.toString() ?? 'Episode $episodeNum';

              final baseUrl = activePlaylist.url.split('/player_api.php')[0];
              final episodeUrl = '$baseUrl/series/${activePlaylist.username}/${activePlaylist.password}/$episodeId.$containerExt';

              episodeObjects.add(Episode(
                name: episodeTitle,
                url: episodeUrl,
                thumbnail: episode['info']?['movie_image'],
                episodeNumber: episodeNum,
                seasonNumber: int.tryParse(seasonNum) ?? 1,
                plot: episode['info']?['plot'],
                duration: episode['info']?['duration'],
              ));
            }

            // Ordenar episodios por número
            episodeObjects.sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));

            seasons.add(Season(
              seasonNumber: int.tryParse(seasonNum) ?? 1,
              episodes: episodeObjects,
            ));
          });

          // Ordenar temporadas por número
          seasons.sort((a, b) => a.seasonNumber.compareTo(b.seasonNumber));

          setState(() {
            _loadedSeasons = seasons;
            _loadingEpisodes = false;
          });
        } else {
          setState(() => _loadingEpisodes = false);
        }
      } else {
        setState(() => _loadingEpisodes = false);
      }
    } catch (e) {
      print('Error loading Xtream episodes: $e');
      setState(() => _loadingEpisodes = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedSeason = _loadedSeasons.isNotEmpty
        ? _loadedSeasons[_selectedSeasonIndex]
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1929),
      body: CustomScrollView(
        slivers: [
          // Backdrop header with gradient overlay
          SliverToBoxAdapter(
            child: Stack(
              children: [
                // Backdrop image
                Container(
                  height: 400,
                  decoration: BoxDecoration(
                    image: widget.series.backdrop != null
                        ? DecorationImage(
                            image: NetworkImage(widget.series.backdrop!),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: widget.series.backdrop == null
                        ? const Color(0xFF1F2937)
                        : null,
                  ),
                  child: widget.series.backdrop == null
                      ? const Center(
                          child: Icon(
                            Icons.tv,
                            size: 120,
                            color: Colors.white24,
                          ),
                        )
                      : null,
                ),
                // Gradient overlay
                Container(
                  height: 400,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.3),
                        const Color(0xFF0A1929),
                      ],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                ),
                // Back button
                Positioned(
                  top: 40,
                  left: 20,
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                // Title and metadata overlaid at bottom
                Positioned(
                  bottom: 20,
                  left: 40,
                  right: 40,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        widget.series.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      // Rating and year
                      Row(
                        children: [
                          if (widget.series.rating != null && widget.series.rating! > 0) ...[
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 24,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.series.rating!.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    color: Colors.black,
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (widget.series.releaseDate != null) ...[
                            const SizedBox(width: 16),
                            Text(
                              '• ${widget.series.releaseDate}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                shadows: const [
                                  Shadow(
                                    color: Colors.black,
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Description section
          SliverToBoxAdapter(
            child: _descriptionFuture == null
                ? const SizedBox.shrink()
                : FutureBuilder<String?>(
                    future: _descriptionFuture,
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(40, 24, 40, 24),
                          child: Text(
                            snapshot.data!,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 16,
                              height: 1.6,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
          ),

          // Action buttons: Add to Favorites + Play
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(40, 0, 40, 24),
              child: Row(
                children: [
                  // Add to Favorites button
                  ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Implement favorite toggle
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Agregado a favoritos'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    icon: const Icon(Icons.favorite_border, size: 20),
                    label: const Text(
                      'Añadir a favoritos',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.12),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Play button
                  ElevatedButton.icon(
                    onPressed: () {
                      if (selectedSeason != null &&
                          selectedSeason.episodes.isNotEmpty) {
                        _playEpisode(selectedSeason.episodes.first);
                      }
                    },
                    icon: const Icon(Icons.play_arrow, size: 24),
                    label: Text(
                      selectedSeason != null
                          ? 'Reproducir S${selectedSeason.seasonNumber.toString().padLeft(2, '0')}E01'
                          : 'Reproducir',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE50914),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 4,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Season selector
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(40, 0, 40, 20),
              child: Row(
                children: [
                  const Text(
                    'Temporada:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (_loadedSeasons.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                          width: 1,
                        ),
                      ),
                      child: _loadingEpisodes
                          ? const SizedBox(
                              width: 120,
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                              ),
                            )
                          : DropdownButton<int>(
                              value: _selectedSeasonIndex,
                              dropdownColor: const Color(0xFF1A2B3C),
                              underline: Container(),
                              icon: const Icon(
                                Icons.expand_more,
                                color: Colors.white,
                                size: 20,
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                              items: List.generate(
                                _loadedSeasons.length,
                                (index) => DropdownMenuItem(
                                  value: index,
                                  child: Text(
                                    'Temporada ${_loadedSeasons[index].seasonNumber}',
                                  ),
                                ),
                              ),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedSeasonIndex = value;
                                  });
                                }
                              },
                            ),
                    ),
                ],
              ),
            ),
          ),

          // Episodes section - Grid
          if (selectedSeason != null) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(40, 0, 40, 16),
                child: Text(
                  'Episodios',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 1.6,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final episode = selectedSeason.episodes[index];
                    return _buildEpisodeCard(episode);
                  },
                  childCount: selectedSeason.episodes.length,
                ),
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildEpisodeCard(Episode episode) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _playEpisode(episode),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F1A26),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                        color: const Color(0xFF374151),
                      ),
                      child: episode.thumbnail != null
                          ? ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8),
                              ),
                              child: Image.network(
                                episode.thumbnail!,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(
                                      Icons.play_circle_outline,
                                      size: 40,
                                      color: Colors.white38,
                                    ),
                                  );
                                },
                              ),
                            )
                          : const Center(
                              child: Icon(
                                Icons.play_circle_outline,
                                size: 40,
                                color: Colors.white38,
                              ),
                            ),
                    ),
                    // Episode number badge
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE50914),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Ep ${episode.episodeNumber}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Episode info
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        episode.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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

  Widget _buildEpisodeCardHorizontal(Episode episode) {
    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _playEpisode(episode),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F1A26),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                Stack(
                  children: [
                    Container(
                      height: 140,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        color: const Color(0xFF374151),
                      ),
                      child: episode.thumbnail != null
                          ? ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                              child: Image.network(
                                episode.thumbnail!,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(
                                      Icons.play_circle_outline,
                                      size: 64,
                                      color: Colors.white38,
                                    ),
                                  );
                                },
                              ),
                            )
                          : const Center(
                              child: Icon(
                                Icons.play_circle_outline,
                                size: 64,
                                color: Colors.white38,
                              ),
                            ),
                    ),
                    // Play overlay
                    Container(
                      height: 140,
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
                    // Episode number badge
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE50914),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Ep ${episode.episodeNumber}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // Episode info
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          episode.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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

  void _playEpisode(Episode episode) {
    final channel = Channel()
      ..name = episode.name
      ..url = episode.url
      ..logo = episode.thumbnail
      ..contentType = ContentType.series;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(channel: channel),
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
