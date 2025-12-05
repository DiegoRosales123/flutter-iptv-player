import 'package:flutter/material.dart';
import '../models/channel.dart';
import '../l10n/app_localizations.dart';
import 'android_video_player_screen.dart';

class MobileMovieDetailScreen extends StatelessWidget {
  final Channel movie;

  const MobileMovieDetailScreen({
    Key? key,
    required this.movie,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1A2A),
      body: CustomScrollView(
        slivers: [
          // App bar with poster background
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: const Color(0xFF0F2537),
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Poster image
                  if (movie.logo != null && movie.logo!.isNotEmpty)
                    Image.network(
                      movie.logo!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF1E3A5F),
                        child: const Icon(
                          Icons.movie,
                          size: 80,
                          color: Colors.white30,
                        ),
                      ),
                    )
                  else
                    Container(
                      color: const Color(0xFF1E3A5F),
                      child: const Icon(
                        Icons.movie,
                        size: 80,
                        color: Colors.white30,
                      ),
                    ),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          const Color(0xFF0B1A2A).withOpacity(0.7),
                          const Color(0xFF0B1A2A),
                        ],
                        stops: const [0.0, 0.7, 1.0],
                      ),
                    ),
                  ),
                  // Rating badge
                  if (movie.rating > 0)
                    Positioned(
                      top: 50,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getRatingColor(movie.rating),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              movie.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
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

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    movie.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Category
                  if (movie.group != null && movie.group!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5DD3E5).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF5DD3E5),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        movie.group!,
                        style: const TextStyle(
                          color: Color(0xFF5DD3E5),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Play button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AndroidVideoPlayerScreen(channel: movie),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5DD3E5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.play_arrow, size: 28),
                          const SizedBox(width: 8),
                          Text(
                            l10n.play,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Description
                  if (movie.description != null && movie.description!.isNotEmpty) ...[
                    Text(
                      l10n.overview,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      movie.description!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Stats
                  if (movie.playCount > 0 || movie.rating > 0)
                    Container(
                      padding: const EdgeInsets.all(16),
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          if (movie.playCount > 0)
                            Column(
                              children: [
                                const Icon(
                                  Icons.play_circle_outline,
                                  color: Color(0xFF5DD3E5),
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${movie.playCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  l10n.views,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          if (movie.rating > 0)
                            Column(
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Color(0xFFFFC107),
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  movie.rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  l10n.rating,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
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
