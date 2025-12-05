import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/channel.dart';
import '../services/database_service.dart';
import '../services/m3u_parser.dart';
import 'android_video_player_screen.dart';

class MobileLiveTVScreen extends StatefulWidget {
  const MobileLiveTVScreen({Key? key}) : super(key: key);

  @override
  State<MobileLiveTVScreen> createState() => _MobileLiveTVScreenState();
}

class _MobileLiveTVScreenState extends State<MobileLiveTVScreen> {
  List<Channel> _allChannels = [];
  List<Channel> _filteredChannels = [];
  Map<String, List<Channel>> _groupedChannels = {};
  String? _selectedCategory;
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  Future<void> _loadChannels() async {
    final allChannels = await DatabaseService.getAllChannels();
    final liveChannels = allChannels
        .where((c) => c.contentType == ContentType.live)
        .toList();

    final grouped = M3UParser.groupChannels(liveChannels);

    if (mounted) {
      setState(() {
        _allChannels = liveChannels;
        _filteredChannels = liveChannels;
        _groupedChannels = grouped;
        _isLoading = false;
      });
    }
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1A2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F2537),
        elevation: 0,
        title: Text(
          l10n.liveTV,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Container(
              padding: const EdgeInsets.all(16),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                  _filterChannels();
                },
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: l10n.search,
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
                  filled: true,
                  fillColor: const Color(0xFF1A3A52).withOpacity(0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),

            // Category filter chips
            if (_groupedChannels.isNotEmpty)
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildCategoryChip('All', l10n.all),
                    ..._groupedChannels.keys.map((category) =>
                      _buildCategoryChip(category, category)
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // Channels grid
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF5DD3E5),
                      ),
                    )
                  : _filteredChannels.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.tv_off,
                                size: 64,
                                color: Colors.white.withOpacity(0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.noChannels,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.75,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: _filteredChannels.length,
                          itemBuilder: (context, index) {
                            final channel = _filteredChannels[index];
                            return _buildChannelCard(channel);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String value, String label) {
    final isSelected = _selectedCategory == value;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedCategory = selected ? value : null;
          });
          _filterChannels();
        },
        backgroundColor: const Color(0xFF1A3A52).withOpacity(0.5),
        selectedColor: const Color(0xFF5DD3E5),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
        checkmarkColor: Colors.white,
      ),
    );
  }

  Widget _buildChannelCard(Channel channel) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AndroidVideoPlayerScreen(channel: channel),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Thumbnail
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A5F).withOpacity(0.3),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: channel.logo != null && channel.logo!.isNotEmpty
                            ? Image.network(
                                channel.logo!,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.tv,
                                  color: Colors.white.withOpacity(0.3),
                                  size: 48,
                                ),
                              )
                            : Icon(
                                Icons.tv,
                                color: Colors.white.withOpacity(0.3),
                                size: 48,
                              ),
                      ),
                      // Play button overlay
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5DD3E5).withOpacity(0.9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Channel info
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (channel.group != null && channel.group!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        channel.group!,
                        style: TextStyle(
                          color: const Color(0xFF5DD3E5).withOpacity(0.8),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
