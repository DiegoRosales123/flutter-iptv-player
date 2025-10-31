import 'package:flutter/material.dart';
import '../models/channel.dart';
import '../models/playlist.dart';
import '../services/database_service.dart';
import '../services/m3u_parser.dart';
import 'video_player_screen.dart';
import 'playlist_manager_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Channel> _channels = [];
  List<Channel> _filteredChannels = [];
  List<String> _groups = [];
  String? _selectedGroup;
  bool _showFavoritesOnly = false;
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  Future<void> _loadChannels() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final channels = await DatabaseService.getAllChannels();
      final groups = M3UParser.extractGroups(channels);

      setState(() {
        _channels = channels;
        _filteredChannels = channels;
        _groups = groups;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading channels: $e')),
        );
      }
    }
  }

  void _filterChannels() {
    List<Channel> filtered = _channels;

    // Filter by favorites
    if (_showFavoritesOnly) {
      filtered = filtered.where((c) => c.isFavorite).toList();
    }

    // Filter by group
    if (_selectedGroup != null) {
      filtered = filtered.where((c) => c.group == _selectedGroup).toList();
    }

    // Filter by search query
    if (_searchController.text.isNotEmpty) {
      filtered = filtered
          .where((c) => c.name
              .toLowerCase()
              .contains(_searchController.text.toLowerCase()))
          .toList();
    }

    setState(() {
      _filteredChannels = filtered;
    });
  }

  void _openChannel(Channel channel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          channel: channel,
          playlist: _filteredChannels,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IPTV Player'),
        actions: [
          IconButton(
            icon: Icon(
              _showFavoritesOnly ? Icons.favorite : Icons.favorite_border,
              color: _showFavoritesOnly ? Colors.red : null,
            ),
            onPressed: () {
              setState(() {
                _showFavoritesOnly = !_showFavoritesOnly;
              });
              _filterChannels();
            },
          ),
          IconButton(
            icon: const Icon(Icons.playlist_add),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PlaylistManagerScreen(),
                ),
              );
              _loadChannels();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadChannels,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search channels...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterChannels();
                        },
                      )
                    : null,
              ),
              onChanged: (value) => _filterChannels(),
            ),
          ),

          // Group Filter
          if (_groups.isNotEmpty)
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: _groups.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: const Text('All'),
                        selected: _selectedGroup == null,
                        onSelected: (selected) {
                          setState(() {
                            _selectedGroup = null;
                          });
                          _filterChannels();
                        },
                      ),
                    );
                  }
                  final group = _groups[index - 1];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(group),
                      selected: _selectedGroup == group,
                      onSelected: (selected) {
                        setState(() {
                          _selectedGroup = selected ? group : null;
                        });
                        _filterChannels();
                      },
                    ),
                  );
                },
              ),
            ),

          // Channel List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredChannels.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.tv_off,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _channels.isEmpty
                                  ? 'No channels found.\nAdd a playlist to get started.'
                                  : 'No channels match your filters.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                            if (_channels.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.playlist_add),
                                  label: const Text('Add Playlist'),
                                  onPressed: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const PlaylistManagerScreen(),
                                      ),
                                    );
                                    _loadChannels();
                                  },
                                ),
                              ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredChannels.length,
                        itemBuilder: (context, index) {
                          final channel = _filteredChannels[index];
                          return ListTile(
                            leading: channel.logo != null
                                ? Image.network(
                                    channel.logo!,
                                    width: 50,
                                    height: 50,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(Icons.tv);
                                    },
                                  )
                                : const Icon(Icons.tv),
                            title: Text(channel.name),
                            subtitle: Text(channel.group ?? 'Uncategorized'),
                            trailing: IconButton(
                              icon: Icon(
                                channel.isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color:
                                    channel.isFavorite ? Colors.red : null,
                              ),
                              onPressed: () async {
                                await DatabaseService.toggleFavorite(channel);
                                setState(() {});
                              },
                            ),
                            onTap: () => _openChannel(channel),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
