import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/channel.dart';
import '../services/database_service.dart';

class MobileVideoPlayerScreen extends StatefulWidget {
  final Channel channel;

  const MobileVideoPlayerScreen({
    Key? key,
    required this.channel,
  }) : super(key: key);

  @override
  State<MobileVideoPlayerScreen> createState() => _MobileVideoPlayerScreenState();
}

class _MobileVideoPlayerScreenState extends State<MobileVideoPlayerScreen> {
  late final Player player;
  late final VideoController controller;
  bool _isControlsVisible = true;
  bool _isLoading = true;
  String? _error;
  bool _isFullscreen = false;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    // Set fullscreen by default on mobile
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _initializePlayer() async {
    player = Player(
      configuration: const PlayerConfiguration(
        title: 'IPTV Player',
      ),
    );

    controller = VideoController(
      player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );

    try {
      print('🎬 Opening media: ${widget.channel.url}');
      await player.open(Media(widget.channel.url));
      print('✅ Media opened successfully');

      // Disable subtitles by default
      player.setSubtitleTrack(SubtitleTrack.no());

      // Resume from saved progress if available
      if (widget.channel.watchedMilliseconds > 0) {
        await player.seek(Duration(milliseconds: widget.channel.watchedMilliseconds));
      }

      await DatabaseService.updateChannelPlayCount(widget.channel);

      // Listen to player state
      player.stream.error.listen((error) {
        print('❌ Player error: $error');
        if (mounted) {
          setState(() {
            _error = 'Error del reproductor: $error';
          });
        }
      });

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      print('🎥 Player initialized, loading = false');
    } catch (e, stackTrace) {
      print('❌ Error initializing player: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _error = 'Error al cargar el stream: $e';
          _isLoading = false;
        });
      }
    }

    // Auto-hide controls after 3 seconds
    _startHideControlsTimer();
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isControlsVisible) {
        setState(() {
          _isControlsVisible = false;
        });
      }
    });
  }

  void _showControls() {
    if (!_isControlsVisible) {
      setState(() {
        _isControlsVisible = true;
      });
    }
    _startHideControlsTimer();
  }

  void _toggleControls() {
    setState(() {
      _isControlsVisible = !_isControlsVisible;
    });

    if (_isControlsVisible) {
      _startHideControlsTimer();
    } else {
      _hideControlsTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();

    // Restore orientation and system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Save watch progress before disposing
    _saveWatchProgress();

    player.dispose();
    super.dispose();
  }

  Future<void> _saveWatchProgress() async {
    final duration = player.state.duration;
    final position = player.state.position;

    if (duration != null && position != null) {
      widget.channel.watchedMilliseconds = position.inMilliseconds;
      widget.channel.totalMilliseconds = duration.inMilliseconds;
      await DatabaseService.isar.writeTxn(() async {
        await DatabaseService.isar.channels.put(widget.channel);
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
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            else if (_error != null)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              )
            else
              Center(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Video(
                    controller: controller,
                    controls: NoVideoControls,
                  ),
                ),
              ),

            // Controls Overlay
            if (_isControlsVisible && !_isLoading)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: SafeArea(
                  child: Column(
                    children: [
                      // Top bar
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                            Expanded(
                              child: Text(
                                widget.channel.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
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

                      const Spacer(),

                      // Center play/pause button
                      StreamBuilder<bool>(
                        stream: player.stream.playing,
                        builder: (context, snapshot) {
                          final isPlaying = snapshot.data ?? false;
                          return IconButton(
                            icon: Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                              size: 64,
                            ),
                            onPressed: () {
                              player.playOrPause();
                            },
                          );
                        },
                      ),

                      // Only show progress bar for VOD content (movies/series)
                      if (widget.channel.contentType != ContentType.live) ...[
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: StreamBuilder<Duration>(
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
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ] else
                        const Spacer(),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
