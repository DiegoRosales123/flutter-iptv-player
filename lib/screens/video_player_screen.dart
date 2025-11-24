import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final FocusNode _focusNode = FocusNode();
  Timer? _hideControlsTimer;

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
      // Disable subtitles by default
      player.setSubtitleTrack(SubtitleTrack.no());
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

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _focusNode.dispose();
    player.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final key = event.logicalKey;

    // Space bar - Play/Pause
    if (key == LogicalKeyboardKey.space) {
      player.playOrPause();
      _showControlsTemporarily();
    }
    // Left arrow - Rewind 10 seconds
    else if (key == LogicalKeyboardKey.arrowLeft) {
      final currentPosition = player.state.position;
      player.seek(currentPosition - const Duration(seconds: 10));
      _showControlsTemporarily();
    }
    // Right arrow - Forward 10 seconds
    else if (key == LogicalKeyboardKey.arrowRight) {
      final currentPosition = player.state.position;
      player.seek(currentPosition + const Duration(seconds: 10));
      _showControlsTemporarily();
    }
    // Up arrow - Volume up
    else if (key == LogicalKeyboardKey.arrowUp) {
      final currentVolume = player.state.volume;
      player.setVolume((currentVolume + 10).clamp(0, 100));
      _showControlsTemporarily();
    }
    // Down arrow - Volume down
    else if (key == LogicalKeyboardKey.arrowDown) {
      final currentVolume = player.state.volume;
      player.setVolume((currentVolume - 10).clamp(0, 100));
      _showControlsTemporarily();
    }
    // Escape - Go back
    else if (key == LogicalKeyboardKey.escape) {
      Navigator.pop(context);
    }
  }

  void _showControlsTemporarily() {
    setState(() {
      _isControlsVisible = true;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _isControlsVisible) {
        setState(() {
          _isControlsVisible = false;
        });
      }
    });
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

  void _toggleFavorite() async {
    await DatabaseService.toggleFavorite(widget.channel);
    setState(() {});
  }

  void _showAudioTrackDialog() {
    final audioTracks = player.state.tracks.audio;
    final currentTrack = player.state.track.audio;

    if (audioTracks.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF141414),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: const Text(
            'Pistas de Audio',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'No hay pistas de audio disponibles',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 15,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Cerrar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text(
          'Pistas de Audio',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: SizedBox(
          width: 400,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: audioTracks.length,
            itemBuilder: (context, index) {
              final track = audioTracks[index];
              final isSelected = track.id == currentTrack.id;
              final trackName = track.title ?? track.language ?? 'Pista ${index + 1}';

              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFE50914).withOpacity(0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ListTile(
                  leading: Icon(
                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isSelected ? const Color(0xFFE50914) : Colors.white54,
                    size: 22,
                  ),
                  title: Text(
                    trackName,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.9),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: track.language != null && track.title != null
                      ? Text(
                          track.language!,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 13,
                          ),
                        )
                      : null,
                  onTap: () {
                    player.setAudioTrack(track);
                    Navigator.pop(context);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Cerrar',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSubtitleTrackDialog() {
    final allSubtitleTracks = player.state.tracks.subtitle;
    final currentTrack = player.state.track.subtitle;

    // Filter out 'no' and 'auto' tracks - we show 'Desactivados' manually
    final subtitleTracks = allSubtitleTracks.where((t) =>
      t.id != 'no' && t.id != 'auto' && t.id.isNotEmpty
    ).toList();

    // Check if subtitles are disabled
    final isDisabled = currentTrack.id == 'no' || currentTrack.id == 'auto' || currentTrack.id.isEmpty;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text(
          'Subtítulos',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: SizedBox(
          width: 400,
          child: ListView(
            shrinkWrap: true,
            children: [
              // Option to disable subtitles
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: isDisabled
                      ? const Color(0xFFE50914).withOpacity(0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ListTile(
                  leading: Icon(
                    isDisabled ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isDisabled ? const Color(0xFFE50914) : Colors.white54,
                    size: 22,
                  ),
                  title: Text(
                    'Desactivados',
                    style: TextStyle(
                      color: isDisabled ? Colors.white : Colors.white.withOpacity(0.9),
                      fontWeight: isDisabled ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 15,
                    ),
                  ),
                  onTap: () {
                    player.setSubtitleTrack(SubtitleTrack.no());
                    Navigator.pop(context);
                  },
                ),
              ),
              // Available subtitle tracks
              ...subtitleTracks.asMap().entries.map((entry) {
                final index = entry.key;
                final track = entry.value;
                final isSelected = track.id == currentTrack.id;
                final trackName = track.title ?? track.language ?? 'Subtítulo ${index + 1}';

                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFE50914).withOpacity(0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ListTile(
                    leading: Icon(
                      isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: isSelected ? const Color(0xFFE50914) : Colors.white54,
                      size: 22,
                    ),
                    title: Text(
                      trackName,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white.withOpacity(0.9),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: track.language != null && track.title != null
                        ? Text(
                            track.language!,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 13,
                            ),
                          )
                        : null,
                    onTap: () {
                      player.setSubtitleTrack(track);
                      Navigator.pop(context);
                    },
                  ),
                );
              }).toList(),
              if (subtitleTracks.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No hay subtítulos disponibles',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Cerrar',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
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
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: MouseRegion(
          onHover: (_) => _showControls(),
          onEnter: (_) => _showControls(),
          child: GestureDetector(
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
              child: IgnorePointer(
                ignoring: !_isControlsVisible,
                child: AnimatedOpacity(
                  opacity: _isControlsVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.black.withOpacity(0.4),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.channel.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.channel.group != null)
                              const SizedBox(height: 4),
                            if (widget.channel.group != null)
                              Text(
                                widget.channel.group!,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 13,
                                  letterSpacing: 0.2,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Volume control
                      StreamBuilder<double>(
                        stream: player.stream.volume,
                        builder: (context, snapshot) {
                          final volume = snapshot.data ?? 100.0;
                          final isMuted = volume == 0.0;

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
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
                                    size: 20,
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
                                  width: 80,
                                  child: SliderTheme(
                                    data: SliderThemeData(
                                      trackHeight: 3,
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 5,
                                      ),
                                      overlayShape: const RoundSliderOverlayShape(
                                        overlayRadius: 10,
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
                                      inactiveColor: Colors.white.withOpacity(0.2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      // Audio track button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.audiotrack, color: Colors.white, size: 20),
                          tooltip: 'Pistas de Audio',
                          onPressed: _showAudioTrackDialog,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Subtitle button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.subtitles, color: Colors.white, size: 20),
                          tooltip: 'Subtítulos',
                          onPressed: _showSubtitleTrackDialog,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: widget.channel.isFavorite
                              ? const Color(0xFFE50914).withOpacity(0.3)
                              : Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: Icon(
                            widget.channel.isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: widget.channel.isFavorite
                                ? const Color(0xFFE50914)
                                : Colors.white,
                            size: 20,
                          ),
                          onPressed: _toggleFavorite,
                        ),
                      ),
                    ],
                  ),
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
              child: IgnorePointer(
                ignoring: !_isControlsVisible,
                child: AnimatedOpacity(
                  opacity: _isControlsVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 48, 24, 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.8),
                        Colors.black.withOpacity(0.4),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Control buttons (moved above progress bar for Netflix style)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.replay_10,
                                    color: Colors.white, size: 26),
                                onPressed: () {
                                  final currentPosition = player.state.position;
                                  player.seek(currentPosition - const Duration(seconds: 10));
                                },
                              ),
                            ),
                            const SizedBox(width: 20),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.skip_previous,
                                    color: Colors.white, size: 28),
                                onPressed: () {
                                  // Previous episode logic
                                },
                              ),
                            ),
                            const SizedBox(width: 20),
                            StreamBuilder<bool>(
                              stream: player.stream.playing,
                              builder: (context, snapshot) {
                                final isPlaying = snapshot.data ?? false;
                                return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.95),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: Icon(
                                      isPlaying ? Icons.pause : Icons.play_arrow,
                                      color: Colors.black,
                                      size: 40,
                                    ),
                                    onPressed: () {
                                      player.playOrPause();
                                    },
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 20),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.skip_next,
                                    color: Colors.white, size: 28),
                                onPressed: () {
                                  // Next episode logic
                                },
                              ),
                            ),
                            const SizedBox(width: 20),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.forward_10,
                                    color: Colors.white, size: 26),
                                onPressed: () {
                                  final currentPosition = player.state.position;
                                  player.seek(currentPosition + const Duration(seconds: 10));
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
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
                                    // Seekbar
                                    SliderTheme(
                                      data: SliderThemeData(
                                        trackHeight: 4,
                                        thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 6,
                                        ),
                                        overlayShape: const RoundSliderOverlayShape(
                                          overlayRadius: 14,
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
                                        activeColor: const Color(0xFFE50914),
                                        inactiveColor: Colors.white.withOpacity(0.25),
                                      ),
                                    ),
                                    // Time labels
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _formatDuration(position),
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.9),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            _formatDuration(duration),
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.9),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
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
                      ],
                    ),
                  ),
                ),
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
}
