import 'package:flutter/material.dart';
import '../models/channel.dart';
import '../services/database_service.dart';
import '../services/tmdb_service.dart';
import 'video_player_screen.dart';

class MovieDetailScreen extends StatefulWidget {
  final Channel movie;

  const MovieDetailScreen({Key? key, required this.movie}) : super(key: key);

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  Future<String?>? _descriptionFuture;

  @override
  void initState() {
    super.initState();
    _descriptionFuture = _loadDescription();
  }

  Future<String?> _loadDescription() async {
    if (widget.movie.description != null && widget.movie.description!.isNotEmpty) {
      return widget.movie.description;
    }
    final cleanedName = TmdbService.cleanContentName(widget.movie.name);
    final description = await TmdbService.getMovieDescription(cleanedName);
    if (description != null && description.isNotEmpty) {
      widget.movie.description = description;
      await DatabaseService.isar.writeTxn(() async {
        await DatabaseService.isar.channels.put(widget.movie);
      });
    }
    return description;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1929),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // Poster as header
          SliverToBoxAdapter(
            child: Container(
              height: 320,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    const Color(0xFF0A1929),
                  ],
                ),
              ),
              child: Center(
                child: Container(
                  width: 200,
                  height: 300,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.7),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: widget.movie.logo != null
                        ? Image.network(
                            widget.movie.logo!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: const Color(0xFF1F2937),
                                child: Center(
                                  child: Icon(
                                    Icons.movie,
                                    size: 80,
                                    color: Colors.white.withOpacity(0.2),
                                  ),
                                ),
                              );
                            },
                          )
                        : Container(
                            color: const Color(0xFF1F2937),
                            child: Center(
                              child: Icon(
                                Icons.movie,
                                size: 80,
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),

          // Progress bar (if watched)
          SliverToBoxAdapter(
            child: widget.movie.watchedMilliseconds > 0 && widget.movie.totalMilliseconds > 0
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (widget.movie.watchedMilliseconds / widget.movie.totalMilliseconds).clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor: Colors.white.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          const Color(0xFFE50914),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // Title, badges and buttons
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    widget.movie.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),

                  // Rating and category badges
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      if (widget.movie.rating > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _getRatingColor(widget.movie.rating),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${widget.movie.rating.toStringAsFixed(1)}/10',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (widget.movie.group != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.movie.group!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Play and Favorite buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _playMovie,
                          icon: const Icon(Icons.play_arrow, size: 24),
                          label: const Text(
                            'Reproducir',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE50914),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                            width: 1,
                          ),
                        ),
                        child: IconButton(
                          onPressed: _toggleFavorite,
                          icon: Icon(
                            widget.movie.isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: widget.movie.isFavorite
                                ? const Color(0xFFE50914)
                                : Colors.white,
                            size: 28,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Stats section
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatCard(
                    'Reproducido',
                    '${widget.movie.playCount}',
                    'veces',
                    Icons.play_circle_outline,
                  ),
                  if (widget.movie.lastPlayed != null)
                    _buildStatCard(
                      'Última vez',
                      _formatDate(widget.movie.lastPlayed!),
                      '',
                      Icons.access_time,
                    ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // Description section
          SliverToBoxAdapter(
            child: _descriptionFuture == null
                ? const SizedBox.shrink()
                : FutureBuilder<String?>(
                    future: _descriptionFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Sinopsis',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Center(
                                child: SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white.withOpacity(0.4),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Sinopsis',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.08),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  snapshot.data!,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
                                    fontSize: 15,
                                    height: 1.8,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return const SizedBox.shrink();
                    },
                  ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // Information section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Detalles',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.08),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Título', widget.movie.name),
                        const SizedBox(height: 14),
                        if (widget.movie.group != null) ...[
                          _buildInfoRow('Categoría', widget.movie.group!),
                          const SizedBox(height: 14),
                        ],
                        _buildInfoRow(
                          'Calificación',
                          widget.movie.rating > 0
                              ? '${widget.movie.rating.toStringAsFixed(1)}/10'
                              : 'No disponible',
                        ),
                        const SizedBox(height: 14),
                        _buildInfoRow(
                          'Reproducciones',
                          widget.movie.playCount.toString(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String subtitle, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white.withOpacity(0.7),
              size: 22,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle.isEmpty ? value : '$value $subtitle',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  void _playMovie() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(channel: widget.movie),
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    await DatabaseService.toggleFavorite(widget.movie);
    setState(() {});
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Hoy';
    } else if (difference.inDays == 1) {
      return 'Ayer';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
