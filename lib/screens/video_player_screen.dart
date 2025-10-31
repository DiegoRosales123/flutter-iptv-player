import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/channel.dart';
import '../services/database_service.dart';

class VideoPlayerScreen extends StatefulWidget {
  final Channel channel;
  final List<Channel>? playlist;

  const VideoPlayerScreen({
    Key? key,
    required this.channel,
    this.playlist,
  }) : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final Player player;
  late final VideoController controller;
  bool _isControlsVisible = true;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    player = Player();
    controller = VideoController(player);

    try {
      await player.open(Media(widget.channel.url));
      await DatabaseService.updateChannelPlayCount(widget.channel);
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load stream: $e';
        _isLoading = false;
      });
    }

    // Auto-hide controls after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isControlsVisible = false;
        });
      }
    });
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _isControlsVisible = !_isControlsVisible;
    });

    if (_isControlsVisible) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isControlsVisible) {
          setState(() {
            _isControlsVisible = false;
          });
        }
      });
    }
  }

  void _toggleFavorite() async {
    await DatabaseService.toggleFavorite(widget.channel);
    setState(() {});
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // Video Player
            Center(
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : _error != null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _error!,
                              style: const TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        )
                      : Video(
                          controller: controller,
                          controls: NoVideoControls,
                        ),
            ),

            // Top Controls
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: _isControlsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.channel.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.channel.group != null)
                              Text(
                                widget.channel.group!,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 14,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Volume control
                      StreamBuilder<double>(
                        stream: player.stream.volume,
                        builder: (context, snapshot) {
                          final volume = snapshot.data ?? 100.0;
                          final isMuted = volume == 0.0;

                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  isMuted
                                      ? Icons.volume_off
                                      : volume < 50
                                          ? Icons.volume_down
                                          : Icons.volume_up,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  if (isMuted) {
                                    player.setVolume(100);
                                  } else {
                                    player.setVolume(0);
                                  }
                                },
                              ),
                              SizedBox(
                                width: 100,
                                child: SliderTheme(
                                  data: SliderThemeData(
                                    trackHeight: 2,
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 4,
                                    ),
                                    overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 8,
                                    ),
                                  ),
                                  child: Slider(
                                    value: volume.clamp(0.0, 100.0),
                                    min: 0,
                                    max: 100,
                                    onChanged: (value) {
                                      player.setVolume(value);
                                    },
                                    activeColor: Colors.white,
                                    inactiveColor: Colors.white.withOpacity(0.3),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          widget.channel.isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: widget.channel.isFavorite
                              ? Colors.red
                              : Colors.white,
                        ),
                        onPressed: _toggleFavorite,
                      ),
                    ],
                  ),
                ),
              ),
              ),
            ),

            // Bottom Controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: _isControlsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Progress bar with time
                        StreamBuilder<Duration>(
                          stream: player.stream.position,
                          builder: (context, positionSnapshot) {
                            return StreamBuilder<Duration>(
                              stream: player.stream.duration,
                              builder: (context, durationSnapshot) {
                                final position = positionSnapshot.data ?? Duration.zero;
                                final duration = durationSnapshot.data ?? Duration.zero;
                                final progress = duration.inMilliseconds > 0
                                    ? position.inMilliseconds / duration.inMilliseconds
                                    : 0.0;

                                return Column(
                                  children: [
                                    // Time labels
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _formatDuration(position),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            _formatDuration(duration),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Seekbar
                                    SliderTheme(
                                      data: SliderThemeData(
                                        trackHeight: 3,
                                        thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 6,
                                        ),
                                        overlayShape: const RoundSliderOverlayShape(
                                          overlayRadius: 12,
                                        ),
                                      ),
                                      child: Slider(
                                        value: progress.clamp(0.0, 1.0),
                                        onChanged: (value) {
                                          final newPosition = Duration(
                                            milliseconds: (value * duration.inMilliseconds).round(),
                                          );
                                          player.seek(newPosition);
                                        },
                                        activeColor: Colors.red,
                                        inactiveColor: Colors.white.withOpacity(0.3),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                        // Control buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.replay_10,
                                  color: Colors.white, size: 28),
                              onPressed: () {
                                final currentPosition = player.state.position;
                                player.seek(currentPosition - const Duration(seconds: 10));
                              },
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              icon: const Icon(Icons.skip_previous,
                                  color: Colors.white, size: 32),
                              onPressed: () {
                                // Previous episode logic
                              },
                            ),
                            const SizedBox(width: 16),
                            StreamBuilder<bool>(
                              stream: player.stream.playing,
                              builder: (context, snapshot) {
                                final isPlaying = snapshot.data ?? false;
                                return IconButton(
                                  icon: Icon(
                                    isPlaying ? Icons.pause : Icons.play_arrow,
                                    color: Colors.white,
                                    size: 48,
                                  ),
                                  onPressed: () {
                                    player.playOrPause();
                                  },
                                );
                              },
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              icon: const Icon(Icons.skip_next,
                                  color: Colors.white, size: 32),
                              onPressed: () {
                                // Next episode logic
                              },
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              icon: const Icon(Icons.forward_10,
                                  color: Colors.white, size: 28),
                              onPressed: () {
                                final currentPosition = player.state.position;
                                player.seek(currentPosition + const Duration(seconds: 10));
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
