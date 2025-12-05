import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../models/channel.dart';
import '../services/database_service.dart';

class AndroidVideoPlayerScreen extends StatefulWidget {
  final Channel channel;

  const AndroidVideoPlayerScreen({
    Key? key,
    required this.channel,
  }) : super(key: key);

  @override
  State<AndroidVideoPlayerScreen> createState() => _AndroidVideoPlayerScreenState();
}

class _AndroidVideoPlayerScreenState extends State<AndroidVideoPlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _error;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      print('🎬 Opening media: ${widget.channel.url}');

      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(widget.channel.url),
        httpHeaders: {
          'User-Agent': 'Mozilla/5.0',
        },
      );

      await _videoPlayerController.initialize();

      // Resume from saved progress if available (only for VOD)
      if (widget.channel.contentType != ContentType.live &&
          widget.channel.watchedMilliseconds > 0) {
        await _videoPlayerController.seekTo(
          Duration(milliseconds: widget.channel.watchedMilliseconds),
        );
      }

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: widget.channel.contentType == ContentType.live,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        fullScreenByDefault: true,
        // Enable subtitles and audio track selection
        subtitle: Subtitles([]),
        subtitleBuilder: (context, subtitle) => Container(
          padding: const EdgeInsets.all(10.0),
          child: Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              backgroundColor: Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        // Additional options
        additionalOptions: (context) {
          return <OptionItem>[
            // Audio tracks option
            OptionItem(
              onTap: (ctx) => _showAudioTracksDialog(ctx),
              iconData: Icons.audiotrack,
              title: 'Pistas de Audio',
            ),
            // Subtitles option
            OptionItem(
              onTap: (ctx) => _showSubtitlesDialog(ctx),
              iconData: Icons.subtitles,
              title: 'Subtítulos',
            ),
          ];
        },
        errorBuilder: (context, errorMessage) {
          return Center(
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
                    errorMessage,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Volver'),
                ),
              ],
            ),
          );
        },
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF5DD3E5),
          handleColor: const Color(0xFF5DD3E5),
          bufferedColor: Colors.white30,
          backgroundColor: Colors.white10,
        ),
      );

      // Update play count
      await DatabaseService.updateChannelPlayCount(widget.channel);

      // Start progress tracking timer for VOD content
      if (widget.channel.contentType != ContentType.live) {
        _startProgressTimer();
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      print('🎥 Player initialized');
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
  }

  void _showAudioTracksDialog(BuildContext context) {
    // Get available audio tracks
    // Note: video_player doesn't expose audio tracks directly,
    // but this is a placeholder for future implementation or when using a player that supports it
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pistas de Audio'),
        content: const Text(
          'Las pistas de audio se seleccionan automáticamente.\n\n'
          'Para cambiar la pista de audio, algunos streams IPTV incluyen '
          'múltiples variantes. El reproductor seleccionará la mejor disponible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSubtitlesDialog(BuildContext context) {
    // Placeholder for subtitles selection
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Subtítulos'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Desactivado'),
              leading: Radio(
                value: 0,
                groupValue: 0,
                onChanged: (value) {
                  Navigator.pop(context);
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Los subtítulos se mostrarán automáticamente si están '
                'incluidos en el stream.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _saveWatchProgress();
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();

    // Save watch progress before disposing
    _saveWatchProgress();

    _chewieController?.dispose();
    _videoPlayerController.dispose();

    // Restore orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    super.dispose();
  }

  Future<void> _saveWatchProgress() async {
    if (widget.channel.contentType == ContentType.live) return;

    final position = _videoPlayerController.value.position;
    final duration = _videoPlayerController.value.duration;

    if (position != Duration.zero && duration != Duration.zero) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF5DD3E5)),
            )
          : _error != null
              ? Center(
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
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Volver'),
                      ),
                    ],
                  ),
                )
              : SafeArea(
                  child: Stack(
                    children: [
                      // Chewie Player
                      Center(
                        child: _chewieController != null
                            ? Chewie(controller: _chewieController!)
                            : const CircularProgressIndicator(),
                      ),

                      // Top bar with back button, title and favorite
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
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
                      ),
                    ],
                  ),
                ),
    );
  }
}
