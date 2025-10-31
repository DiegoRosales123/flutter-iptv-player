import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/channel.dart';
import '../services/database_service.dart';
import '../services/m3u_parser.dart';

class LiveTVScreen extends StatefulWidget {
  const LiveTVScreen({Key? key}) : super(key: key);

  @override
  State<LiveTVScreen> createState() => _LiveTVScreenState();
}

class _LiveTVScreenState extends State<LiveTVScreen> {
  List<Channel> _allChannels = [];
  List<Channel> _filteredChannels = [];
  Map<String, List<Channel>> _groupedChannels = {};
  String? _selectedCategory;
  String _searchQuery = '';
  Channel? _selectedChannel;

  // Video player
  Player? player;
  VideoController? controller;
  bool _isPlayerInitialized = false;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  @override
  void dispose() {
    player?.dispose();
    super.dispose();
  }

  Future<void> _loadChannels() async {
    final allChannels = await DatabaseService.getAllChannels();
    final liveChannels = allChannels
        .where((c) => c.contentType == ContentType.live)
        .toList();

    final grouped = M3UParser.groupChannels(liveChannels);

    setState(() {
      _allChannels = liveChannels;
      _filteredChannels = liveChannels;
      _groupedChannels = grouped;

      // Auto-select first channel
      if (liveChannels.isNotEmpty) {
        _playChannel(liveChannels.first);
      }
    });
  }

  void _filterChannels() {
    List<Channel> filtered = _allChannels;

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

    setState(() {
      _filteredChannels = filtered;
    });
  }

  Future<void> _playChannel(Channel channel) async {
    // Dispose old player
    await player?.dispose();

    // Create new player
    final newPlayer = Player();
    final newController = VideoController(newPlayer);

    setState(() {
      _selectedChannel = channel;
      player = newPlayer;
      controller = newController;
      _isPlayerInitialized = false;
    });

    try {
      await newPlayer.open(Media(channel.url));
      await DatabaseService.updateChannelPlayCount(channel);
      setState(() {
        _isPlayerInitialized = true;
      });
    } catch (e) {
      print('Error playing channel: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ['All', ..._groupedChannels.keys];

    return Scaffold(
      backgroundColor: const Color(0xFF0F1E2B),
      body: Row(
        children: [
          // Left Sidebar - Categories
          if (!_isFullscreen)
            Container(
              width: 220,
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
                // Header
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
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'IPTV',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Live TV',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
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
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                      prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.5), size: 18),
                      filled: true,
                      fillColor: const Color(0xFF0F1E2B),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                      _filterChannels();
                    },
                  ),
                ),

                // Categories list
                Expanded(
                  child: ListView.builder(
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final isSelected = _selectedCategory == category ||
                          (_selectedCategory == null && category == 'All');
                      final count = category == 'All'
                          ? _allChannels.length
                          : _groupedChannels[category]?.length ?? 0;

                      return Material(
                        color: isSelected
                            ? const Color(0xFF2D4A5E)
                            : Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedCategory = category == 'All' ? null : category;
                            });
                            _filterChannels();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
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
                                      fontSize: 13,
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
                                        : Colors.white54,
                                    fontSize: 12,
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

          // Middle - Channel list
          if (!_isFullscreen)
            Container(
              width: 380,
            decoration: BoxDecoration(
              color: const Color(0xFF0F1E2B),
              border: Border(
                right: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                // Top bar with search
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
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D4A5E),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: TextField(
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Search',
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: Colors.white.withOpacity(0.5),
                                size: 20,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                              });
                              _filterChannels();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.grid_view, color: Colors.white, size: 20),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today, color: Colors.white, size: 20),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(Icons.play_circle_outline, color: Colors.white, size: 20),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(Icons.view_module, color: Color(0xFF5DD3E5), size: 20),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),

                // Channel list
                Expanded(
                  child: ListView.builder(
                    itemCount: _filteredChannels.length,
                    itemBuilder: (context, index) {
                      final channel = _filteredChannels[index];
                      final isSelected = _selectedChannel?.id == channel.id;

                      return Material(
                        color: isSelected
                            ? const Color(0xFF2D4A5E)
                            : Colors.transparent,
                        child: InkWell(
                          onTap: () => _playChannel(channel),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                // Channel number
                                Container(
                                  width: 35,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF5DD3E5)
                                        : const Color(0xFF1A2B3C),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: isSelected ? Colors.black : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Channel logo
                                if (channel.logo != null)
                                  Container(
                                    width: 35,
                                    height: 35,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      color: Colors.white.withOpacity(0.1),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.network(
                                        channel.logo!,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Icon(
                                            Icons.tv,
                                            color: Colors.white.withOpacity(0.3),
                                            size: 18,
                                          );
                                        },
                                      ),
                                    ),
                                  ),

                                // Channel name
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        channel.name,
                                        style: TextStyle(
                                          color: isSelected
                                              ? const Color(0xFF5DD3E5)
                                              : Colors.white,
                                          fontSize: 13,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (channel.group != null)
                                        Text(
                                          channel.group!,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.5),
                                            fontSize: 10,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
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

          // Right side - Video Player
          Expanded(
            child: Container(
              color: Colors.black,
              child: _selectedChannel == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.tv,
                            size: 64,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Selecciona un canal',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Channel info bar
                        Container(
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
                          child: Row(
                            children: [
                              if (_selectedChannel!.logo != null)
                                Container(
                                  width: 40,
                                  height: 40,
                                  margin: const EdgeInsets.only(right: 12),
                                  child: Image.network(
                                    _selectedChannel!.logo!,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(
                                        Icons.tv,
                                        color: Colors.white,
                                      );
                                    },
                                  ),
                                ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedChannel!.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (_selectedChannel!.group != null)
                                      Text(
                                        _selectedChannel!.group!,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 14,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // Volume control
                              if (player != null)
                                StreamBuilder<double>(
                                  stream: player!.stream.volume,
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
                                              player!.setVolume(100);
                                            } else {
                                              player!.setVolume(0);
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
                                                player!.setVolume(value);
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
                              IconButton(
                                icon: Icon(
                                  _selectedChannel!.isFavorite
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: _selectedChannel!.isFavorite
                                      ? Colors.red
                                      : Colors.white,
                                ),
                                onPressed: () async {
                                  await DatabaseService.toggleFavorite(_selectedChannel!);
                                  setState(() {});
                                },
                              ),
                              IconButton(
                                icon: Icon(
                                  _isFullscreen
                                      ? Icons.fullscreen_exit
                                      : Icons.fullscreen,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isFullscreen = !_isFullscreen;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),

                        // Video player
                        Expanded(
                          child: controller != null && _isPlayerInitialized
                              ? Video(
                                  controller: controller!,
                                  controls: NoVideoControls,
                                )
                              : Center(
                                  child: CircularProgressIndicator(
                                    color: const Color(0xFF5DD3E5),
                                  ),
                                ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
