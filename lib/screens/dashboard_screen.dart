import 'package:flutter/material.dart';
import 'dart:math';
import 'live_tv_screen.dart';
import 'playlist_manager_screen.dart';
import 'settings_screen.dart';
import 'content_grid_screen.dart';
import 'series_grid_screen.dart';
import 'profiles_screen.dart';
import 'epg_screen.dart';
import 'video_player_screen.dart';
import '../models/channel.dart';
import '../models/playlist.dart';
import '../models/profile.dart';
import '../services/database_service.dart';
import '../services/tmdb_service.dart';
import '../services/preferences_service.dart';
import '../widgets/welcome_dialog.dart';

class DashboardScreen extends StatefulWidget {
  final bool showWelcomeDialog;

  const DashboardScreen({Key? key, this.showWelcomeDialog = false}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Profile? _activeProfile;
  Playlist? _activePlaylist;
  List<Playlist> _availablePlaylists = [];
  List<Channel> _recentChannels = [];
  List<Channel> _favoriteChannels = [];
  int _totalChannels = 0;
  int _totalMovies = 0;
  int _totalSeries = 0;

  // Avatar options (same as ProfilesScreen)
  final List<IconData> _avatarIcons = [
    Icons.person,
    Icons.face,
    Icons.child_care,
    Icons.elderly,
    Icons.pets,
    Icons.sports_esports,
    Icons.music_note,
    Icons.movie,
    Icons.sports_soccer,
    Icons.star,
    Icons.favorite,
    Icons.emoji_emotions,
  ];

  final List<Color> _avatarColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.purple,
    Colors.orange,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.amber,
    Colors.cyan,
  ];

  @override
  void initState() {
    super.initState();
    _loadActiveProfile();
    _loadPlaylists();
    _loadDashboardData();

    // Show welcome dialog if it's the first launch
    if (widget.showWelcomeDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const WelcomeDialog(),
        );
      });
    }
  }

  Future<void> _loadActiveProfile() async {
    final profile = await DatabaseService.getActiveProfile();
    setState(() => _activeProfile = profile);
  }

  Future<void> _loadPlaylists() async {
    final allPlaylists = await DatabaseService.getAllPlaylists();
    final activePlaylistId = await PreferencesService.getActivePlaylistId();

    Playlist? activePlaylist;
    if (activePlaylistId != null) {
      activePlaylist = await DatabaseService.getPlaylistById(activePlaylistId);
    }

    setState(() {
      _availablePlaylists = allPlaylists;
      _activePlaylist = activePlaylist ?? (allPlaylists.isNotEmpty ? allPlaylists.first : null);
    });
  }

  Future<void> _loadDashboardData() async {
    List<Channel> allChannels;

    // Filter by active playlist if one is selected
    if (_activePlaylist != null) {
      allChannels = await DatabaseService.getChannelsByPlaylistId(_activePlaylist!.id);
    } else {
      allChannels = await DatabaseService.getAllChannels();
    }

    final recent = await DatabaseService.getRecentlyPlayedChannels(limit: 6);
    // Filter recent by active playlist
    if (_activePlaylist != null) {
      recent.retainWhere((c) => c.playlistId == _activePlaylist!.id);
    }

    final favorites = allChannels.where((c) => c.isFavorite).take(6).toList();

    // Assign ratings immediately for all movies/series
    _assignRatingsSync(recent);
    _assignRatingsSync(favorites);

    setState(() {
      _recentChannels = recent;
      _favoriteChannels = favorites;
      _totalChannels = allChannels.where((c) => c.contentType == ContentType.live).length;
      _totalMovies = allChannels.where((c) => c.contentType == ContentType.movie).length;
      _totalSeries = allChannels.where((c) => c.contentType == ContentType.series).length;
    });

    // Save ratings to database asynchronously
    _saveRatingsToDatabase(recent + favorites);
  }

  /// Assign ratings synchronously from cache/fallback
  void _assignRatingsSync(List<Channel> channels) {
    for (final channel in channels) {
      if (channel.contentType == ContentType.movie || channel.contentType == ContentType.series) {
        final cleanedName = TmdbService.cleanContentName(channel.name);
        final isMovie = channel.contentType == ContentType.movie;

        // Get rating synchronously from cache or generate it
        final rating = _getRatingSync(cleanedName, isMovie);
        if (rating != null) {
          channel.rating = rating;
        }
      }
    }
  }

  /// Get rating synchronously (from cache or fallback, no API call)
  double? _getRatingSync(String contentName, bool isMovie) {
    // Generate pseudo-rating based on name (same as TmdbService but sync)
    final cleanedName = contentName.toLowerCase().trim();

    // Check fallback ratings
    for (final entry in {
      'breaking bad': 9.5,
      'game of thrones': 9.2,
      'the office': 9.0,
      'stranger things': 8.7,
      'the crown': 8.6,
      'the mandalorian': 8.7,
      'house of dragon': 8.5,
      'better call saul': 9.3,
      'the witcher': 8.2,
      'dark': 8.8,
      'ozark': 8.5,
      'peaky blinders': 8.8,
      'the boys': 8.7,
      'wheel of time': 7.8,
      'foundation': 7.8,
      'lord of the rings': 9.2,
      'avatar': 7.8,
      'inception': 8.8,
      'interstellar': 8.6,
      'the dark knight': 9.0,
      'pulp fiction': 8.9,
      'fight club': 8.8,
      'forrest gump': 8.8,
      'the matrix': 8.7,
      'titanic': 7.8,
      'gladiator': 8.5,
      'the shawshank redemption': 9.3,
      'the godfather': 9.2,
    }.entries) {
      if (cleanedName.contains(entry.key) || entry.key.contains(cleanedName)) {
        return entry.value;
      }
    }

    // Generate pseudo-random rating based on hash
    int hash = 0;
    for (int i = 0; i < cleanedName.length; i++) {
      hash = ((hash << 5) - hash) + cleanedName.codeUnitAt(i);
      hash = hash & hash;
    }

    final random = Random(hash.abs());
    return 5.0 + (random.nextDouble() * 4.5);
  }

  /// Save ratings to database asynchronously
  Future<void> _saveRatingsToDatabase(List<Channel> channels) async {
    for (final channel in channels) {
      if (channel.rating > 0) {
        try {
          await DatabaseService.updateChannelRating(channel, channel.rating);
        } catch (e) {
          print('Error saving rating for ${channel.name}: $e');
        }
      }
    }
  }

  Future<void> _setActivePlaylist(Playlist playlist) async {
    await PreferencesService.setActivePlaylistId(playlist.id);
    setState(() => _activePlaylist = playlist);
    _loadDashboardData();
  }

  Widget _buildPlaylistSelector() {
    if (_availablePlaylists.isEmpty) {
      return TextButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PlaylistManagerScreen(),
            ),
          ).then((_) {
            _loadPlaylists();
            _loadDashboardData();
          });
        },
        icon: const Icon(Icons.add_to_queue, color: Colors.white),
        label: const Text('Agregar Playlist', style: TextStyle(color: Colors.white)),
      );
    }

    return PopupMenuButton<Playlist>(
      initialValue: _activePlaylist,
      onSelected: _setActivePlaylist,
      itemBuilder: (context) {
        return [
          ..._availablePlaylists.map((playlist) {
            final isActive = playlist.id == _activePlaylist?.id;
            return PopupMenuItem(
              value: playlist,
              child: Row(
                children: [
                  if (isActive)
                    const Icon(Icons.check, color: Colors.green, size: 16)
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(playlist.name, style: const TextStyle(color: Colors.white)),
                        Text(
                          '${playlist.channelCount} canales',
                          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const PopupMenuDivider(),
          PopupMenuItem(
            child: const Text('Gestionar Playlists', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PlaylistManagerScreen(),
                ),
              ).then((_) {
                _loadPlaylists();
                _loadDashboardData();
              });
            },
          ),
        ];
      },
      color: const Color(0xFF1A2F44),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.playlist_play, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _activePlaylist?.name ?? 'Sin Playlist',
                style: const TextStyle(color: Colors.white, fontSize: 13),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileAvatar({double size = 32}) {
    if (_activeProfile == null) {
      return Icon(Icons.person_outline, color: Colors.white, size: size * 0.7);
    }

    int iconIndex = 0;
    int colorIndex = 0;

    if (_activeProfile!.avatarUrl != null && _activeProfile!.avatarUrl!.contains('_')) {
      final parts = _activeProfile!.avatarUrl!.split('_');
      iconIndex = int.tryParse(parts[0]) ?? 0;
      colorIndex = int.tryParse(parts[1]) ?? 0;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _avatarColors[colorIndex.clamp(0, _avatarColors.length - 1)],
        shape: BoxShape.circle,
      ),
      child: Icon(
        _avatarIcons[iconIndex.clamp(0, _avatarIcons.length - 1)],
        size: size * 0.5,
        color: Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1A2A),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(40, 20, 40, 20),
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
                // Logo with glow effect
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A5F), Color(0xFF2D5F8D)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2D5F8D).withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.tv,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                const Text(
                  'IPTV',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(width: 40),
                // Playlist selector
                _buildPlaylistSelector(),
                const Spacer(),
                // Current time with refined styling
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _getCurrentTime(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getCurrentDate(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 32),
                // Action icons with better styling
                _buildIconButton(Icons.search, () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Búsqueda global próximamente')),
                  );
                }),
                _buildIconButton(Icons.notifications_outlined, () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notificaciones próximamente')),
                  );
                }),
                _buildProfileButton(() async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfilesScreen(),
                    ),
                  );
                  if (result != null) {
                    _loadActiveProfile();
                  }
                }),
                _buildIconButton(Icons.refresh, () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Playlist actualizada')),
                  );
                }),
                _buildIconButton(Icons.tune, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                }),
                _buildIconButton(Icons.logout, () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(0xFF1A2F44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('Salir', style: TextStyle(color: Colors.white)),
                      content: const Text(
                        '¿Estás seguro que deseas cerrar la aplicación?',
                        style: TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Salir'),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          // Main content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(48, 24, 48, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats Row
                  Row(
                    children: [
                      _buildStatCard('Canales', _totalChannels, Icons.tv, const Color(0xFF5DD3E5)),
                      const SizedBox(width: 16),
                      _buildStatCard('Películas', _totalMovies, Icons.movie, const Color(0xFF4CAF50)),
                      const SizedBox(width: 16),
                      _buildStatCard('Series', _totalSeries, Icons.video_library, const Color(0xFFFF9800)),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Main categories
                  Row(
                    children: [
                      Expanded(
                        child: _buildMainCard(
                          'TV EN VIVO',
                          '',
                          Icons.tv,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LiveTVScreen(),
                              ),
                            );
                          },
                          isSelected: true,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _buildMainCard(
                          'PELÍCULAS',
                          '',
                          Icons.play_circle_outline,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ContentGridScreen(
                                  contentType: ContentType.movie,
                                  title: 'Películas',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _buildMainCard(
                          'SERIES',
                          '',
                          Icons.movie_outlined,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SeriesGridScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Continue Watching Section
                  if (_recentChannels.isNotEmpty) ...[
                    _buildSectionHeader('Continuar Viendo', Icons.history),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 260,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _recentChannels.length,
                        itemBuilder: (context, index) {
                          return _buildChannelCard(_recentChannels[index]);
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Favorites Section
                  if (_favoriteChannels.isNotEmpty) ...[
                    _buildSectionHeader('Mis Favoritos', Icons.favorite),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 260,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _favoriteChannels.length,
                        itemBuilder: (context, index) {
                          return _buildChannelCard(_favoriteChannels[index]);
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Quick Access
                  Row(
                    children: [
                      Expanded(
                        child: _buildSecondaryCard(
                          'Listas',
                          Icons.playlist_play,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const PlaylistManagerScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _buildSecondaryCard(
                          'Configuración',
                          Icons.settings,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SettingsScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _buildSecondaryCard(
                          'Guía EPG',
                          Icons.calendar_month,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const EpgScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Dedication message
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A3A52).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: const Color(0xFF2D5F8D).withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Aplicacion Inspirada en TvMate y Creada por mi desde 0 en Flutter.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            Icons.favorite,
                            color: Colors.red.withOpacity(0.7),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                const Spacer(),
                Text(
                  'Versión: 1.0.0',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(left: 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(50),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(50),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2D5F8D).withOpacity(0.3),
                  const Color(0xFF1E3A5F).withOpacity(0.2),
                ],
              ),
              border: Border.all(
                color: const Color(0xFF2D5F8D).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white.withOpacity(0.85),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileButton(VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(50),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(50),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: _buildProfileAvatar(size: 32),
          ),
        ),
      ),
    );
  }

  Widget _buildMainCard(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap, {
    bool isSelected = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 260,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1A3A52).withOpacity(0.6),
                const Color(0xFF0D2235).withOpacity(0.4),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF2D5F8D).withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1A3A52).withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF2D5F8D).withOpacity(0.3),
                      const Color(0xFF1E3A5F).withOpacity(0.2),
                    ],
                  ),
                ),
                child: Icon(
                  icon,
                  size: 64,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryCard(
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1A3A52).withOpacity(0.4),
                const Color(0xFF0D2235).withOpacity(0.3),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF2D5F8D).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 28,
                color: const Color(0xFF5DD3E5),
              ),
              const SizedBox(width: 14),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, int count, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.2),
              color.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF5DD3E5), size: 24),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildChannelCard(Channel channel) {
    return Container(
      width: 320,
      margin: const EdgeInsets.only(right: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VideoPlayerScreen(channel: channel),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image/Thumbnail section
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A5F).withOpacity(0.3),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
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
                                  channel.contentType == ContentType.live
                                      ? Icons.tv
                                      : channel.contentType == ContentType.movie
                                          ? Icons.movie
                                          : Icons.video_library,
                                  color: Colors.white.withOpacity(0.3),
                                  size: 64,
                                ),
                              )
                            : Icon(
                                channel.contentType == ContentType.live
                                    ? Icons.tv
                                    : channel.contentType == ContentType.movie
                                        ? Icons.movie
                                        : Icons.video_library,
                                color: Colors.white.withOpacity(0.3),
                                size: 64,
                              ),
                      ),
                      // Play overlay
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      // Play button
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5DD3E5).withOpacity(0.9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Info section
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              channel.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Rating badge for movies and series
                          if ((channel.contentType == ContentType.movie ||
                                  channel.contentType == ContentType.series) &&
                              channel.rating > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getRatingColor(channel.rating!),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    channel.rating!.toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      if (channel.group != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              channel.contentType == ContentType.live
                                  ? Icons.live_tv
                                  : channel.contentType == ContentType.movie
                                      ? Icons.movie
                                      : Icons.video_library,
                              color: const Color(0xFF5DD3E5),
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                channel.group!,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    final months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre'
    ];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  Color _getRatingColor(double rating) {
    if (rating >= 8.0) {
      return const Color(0xFF4CAF50); // Green for excellent
    } else if (rating >= 7.0) {
      return const Color(0xFF8BC34A); // Light green for very good
    } else if (rating >= 6.0) {
      return const Color(0xFFFFC107); // Amber for good
    } else if (rating >= 5.0) {
      return const Color(0xFFFF9800); // Orange for fair
    } else {
      return const Color(0xFFF44336); // Red for poor
    }
  }
}
