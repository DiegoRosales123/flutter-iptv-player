import 'package:flutter/material.dart';
import '../models/channel.dart';
import '../l10n/app_localizations.dart';
import 'android_video_player_screen.dart';

class MobileSeriesDetailScreen extends StatelessWidget {
  final Channel series;
  final List<Channel> episodes;
  final String seriesTitle;

  const MobileSeriesDetailScreen({
    Key? key,
    required this.series,
    required this.episodes,
    required this.seriesTitle,
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
            expandedHeight: 250,
            pinned: true,
            backgroundColor: const Color(0xFF0F2537),
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Poster image
                  if (series.logo != null && series.logo!.isNotEmpty)
                    Image.network(
                      series.logo!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF1E3A5F),
                        child: const Icon(
                          Icons.video_library,
                          size: 80,
                          color: Colors.white30,
                        ),
                      ),
                    )
                  else
                    Container(
                      color: const Color(0xFF1E3A5F),
                      child: const Icon(
                        Icons.video_library,
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
                  if (series.rating > 0)
                    Positioned(
                      top: 50,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getRatingColor(series.rating),
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
                              series.rating.toStringAsFixed(1),
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
                    seriesTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Episodes count
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
                      '${episodes.length} episodios',
                      style: const TextStyle(
                        color: Color(0xFF5DD3E5),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Description
                  if (series.description != null && series.description!.isNotEmpty) ...[
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
                      series.description!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Episodes title
                  Row(
                    children: [
                      const Icon(
                        Icons.video_library,
                        color: Color(0xFF5DD3E5),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Episodios',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Episodes list
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final episode = episodes[index];
                return _buildEpisodeCard(context, episode, index + 1);
              },
              childCount: episodes.length,
            ),
          ),

          // Bottom padding
          const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
        ],
      ),
    );
  }

  Widget _buildEpisodeCard(BuildContext context, Channel episode, int number) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AndroidVideoPlayerScreen(channel: episode),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
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
              children: [
                // Episode number circle
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF5DD3E5).withOpacity(0.2),
                    border: Border.all(
                      color: const Color(0xFF5DD3E5),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$number',
                      style: const TextStyle(
                        color: Color(0xFF5DD3E5),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Episode info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        episode.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (episode.watchedMilliseconds > 0 && episode.totalMilliseconds > 0) ...[
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: episode.watchedMilliseconds / episode.totalMilliseconds,
                          backgroundColor: Colors.white.withOpacity(0.1),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF5DD3E5)),
                          minHeight: 3,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Play icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5DD3E5).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Color(0xFF5DD3E5),
                    size: 24,
                  ),
                ),
              ],
            ),
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
