import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import '../l10n/app_localizations.dart';
import '../models/channel.dart';
import '../models/playlist.dart';
import '../models/profile.dart';
import '../services/database_service.dart';
import '../services/preferences_service.dart';
import '../widgets/language_selector.dart';
import 'mobile_live_tv_screen.dart';
import 'mobile_movies_screen.dart';
import 'mobile_series_screen.dart';
import 'playlist_manager_screen.dart';
import 'settings_screen.dart';
import 'profiles_screen.dart';
import 'epg_screen.dart';
import 'android_video_player_screen.dart';

class MobileDashboardScreen extends StatefulWidget {
  final bool showWelcomeDialog;

  const MobileDashboardScreen({Key? key, this.showWelcomeDialog = false}) : super(key: key);

  @override
  State<MobileDashboardScreen> createState() => _MobileDashboardScreenState();
}

class _MobileDashboardScreenState extends State<MobileDashboardScreen> {
  Profile? _activeProfile;
  Playlist? _activePlaylist;
  List<Playlist> _availablePlaylists = [];
  List<Channel> _recentChannels = [];
  List<Channel> _favoriteChannels = [];
  int _totalChannels = 0;
  int _totalMovies = 0;
  int _totalSeries = 0;

  final List<IconData> _avatarIcons = [
    Icons.person,
    Icons.face,
    Icons.child_care,
    Icons.elderly,
    Icons.pets,
    Icons.sports_esports,
    Icons.music_note,
    Icons.movie,
  ];

  final List<Color> _avatarColors = [
    const Color(0xFF5DD3E5),
    const Color(0xFF4CAF50),
    const Color(0xFFFF9800),
    const Color(0xFFE91E63),
    const Color(0xFF9C27B0),
    const Color(0xFF2196F3),
    const Color(0xFFFFC107),
    const Color(0xFFFF5722),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final activePlaylistId = await PreferencesService.getActivePlaylistId();
    final profiles = await DatabaseService.getAllProfiles();

    Profile? activeProfile;
    if (profiles.isNotEmpty) {
      activeProfile = profiles.first;
    }

    final playlists = await DatabaseService.getAllPlaylists();
    Playlist? activePlaylist;
    if (playlists.isNotEmpty) {
      activePlaylist = playlists.first;
    }

    final allChannels = await DatabaseService.getAllChannels();
    final recent = await DatabaseService.getRecentlyPlayedChannels(limit: 10);
    final favorites = await DatabaseService.getFavoriteChannels();

    if (mounted) {
      setState(() {
        _activeProfile = activeProfile;
        _activePlaylist = activePlaylist;
        _availablePlaylists = playlists;
        _recentChannels = recent;
        _favoriteChannels = favorites;
        _totalChannels = allChannels.where((c) => c.contentType == ContentType.live).length;
        _totalMovies = allChannels.where((c) => c.contentType == ContentType.movie).length;
        _totalSeries = allChannels.where((c) => c.contentType == ContentType.series).length;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0B1A2A),
      drawer: _buildDrawer(l10n),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(l10n),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats cards
                    _buildStatCard(l10n.channels, _totalChannels, Icons.tv, const Color(0xFF5DD3E5)),
                    const SizedBox(height: 12),
                    _buildStatCard(l10n.movies, _totalMovies, Icons.movie, const Color(0xFF4CAF50)),
                    const SizedBox(height: 12),
                    _buildStatCard(l10n.series, _totalSeries, Icons.video_library, const Color(0xFFFF9800)),

                    const SizedBox(height: 24),

                    // Main category buttons in a row
                    Row(
                      children: [
                        Expanded(
                          child: _buildCategoryButton(
                            l10n.liveTV,
                            Icons.tv,
                            const Color(0xFF5DD3E5),
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const MobileLiveTVScreen()),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildCategoryButton(
                            l10n.movies,
                            Icons.movie,
                            const Color(0xFF4CAF50),
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const MobileMoviesScreen()),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildCategoryButton(
                            l10n.series,
                            Icons.video_library,
                            const Color(0xFFFF9800),
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const MobileSeriesScreen()),
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Recent channels
                    if (_recentChannels.isNotEmpty) ...[
                      _buildSectionHeader(l10n.continueWatching, Icons.history),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 140,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _recentChannels.length,
                          itemBuilder: (context, index) {
                            return _buildRecentChannelCard(_recentChannels[index]);
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Favorites
                    if (_favoriteChannels.isNotEmpty) ...[
                      _buildSectionHeader(l10n.myFavorites, Icons.favorite),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 140,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _favoriteChannels.length,
                          itemBuilder: (context, index) {
                            return _buildRecentChannelCard(_favoriteChannels[index]);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0F2438),
            const Color(0xFF0B1A2A),
          ],
        ),
      ),
      child: Row(
        children: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.tv, color: Color(0xFF5DD3E5), size: 28),
          const SizedBox(width: 8),
          const Text(
            'IPTV',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.language, color: Colors.white),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const LanguageSelector(),
              );
            },
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilesScreen()),
              );
              _loadData();
            },
            child: _buildProfileAvatar(),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar() {
    if (_activeProfile == null || _activeProfile!.avatarUrl == null) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF5DD3E5),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
        ),
        child: const Icon(Icons.person, color: Colors.white, size: 20),
      );
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF5DD3E5),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
      ),
      child: const Icon(Icons.person, color: Colors.white, size: 20),
    );
  }

  Widget _buildStatCard(String label, int count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.3),
                color.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.4), width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF5DD3E5), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentChannelCard(Channel channel) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      child: Material(
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
          borderRadius: BorderRadius.circular(8),
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
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF2D5F8D).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A5F).withOpacity(0.3),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                    child: Center(
                      child: channel.logo != null && channel.logo!.isNotEmpty
                          ? Image.network(
                              channel.logo!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.tv,
                                color: Colors.white.withOpacity(0.3),
                                size: 32,
                              ),
                            )
                          : Icon(
                              Icons.tv,
                              color: Colors.white.withOpacity(0.3),
                              size: 32,
                            ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    channel.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(AppLocalizations l10n) {
    return Drawer(
      backgroundColor: const Color(0xFF0F2438),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1E3A5F),
                  const Color(0xFF2D5F8D),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.tv, color: Colors.white, size: 48),
                const SizedBox(height: 8),
                const Text(
                  'IPTV Player Pro',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_activeProfile != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _activeProfile!.name,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
          _buildDrawerItem(
            icon: Icons.home,
            title: l10n.dashboard,
            onTap: () => Navigator.pop(context),
          ),
          _buildDrawerItem(
            icon: Icons.tv,
            title: l10n.liveTV,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MobileLiveTVScreen()),
              );
            },
          ),
          _buildDrawerItem(
            icon: Icons.movie,
            title: l10n.movies,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MobileMoviesScreen()),
              );
            },
          ),
          _buildDrawerItem(
            icon: Icons.video_library,
            title: l10n.series,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MobileSeriesScreen()),
              );
            },
          ),
          _buildDrawerItem(
            icon: Icons.playlist_play,
            title: l10n.playlists,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PlaylistManagerScreen()),
              );
            },
          ),
          _buildDrawerItem(
            icon: Icons.calendar_month,
            title: l10n.epgGuide,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EpgScreen()),
              );
            },
          ),
          _buildDrawerItem(
            icon: Icons.settings,
            title: l10n.settings,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
      ),
      onTap: onTap,
    );
  }
}
