import 'package:flutter/material.dart';
import 'live_tv_screen.dart';
import 'playlist_manager_screen.dart';
import 'settings_screen.dart';
import 'content_grid_screen.dart';
import 'series_grid_screen.dart';
import 'profiles_screen.dart';
import 'epg_screen.dart';
import '../models/channel.dart';
import '../models/profile.dart';
import '../services/database_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Profile? _activeProfile;

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
  }

  Future<void> _loadActiveProfile() async {
    final profile = await DatabaseService.getActiveProfile();
    setState(() => _activeProfile = profile);
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
      backgroundColor: const Color(0xFF0A1929),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                // Logo
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.tv,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'IPTV',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // Current time
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _getCurrentTime(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    Text(
                      _getCurrentDate(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                // Action icons
                _buildIconButton(Icons.search, () {
                  // TODO: Implement global search
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Búsqueda global próximamente')),
                  );
                }),
                _buildIconButton(Icons.notifications_outlined, () {
                  // TODO: Implement notifications
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
                      title: const Text('Salir'),
                      content: const Text('¿Estás seguro que deseas cerrar la aplicación?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () {
                            // Close the app
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // Top row - Main categories
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
                      const SizedBox(width: 16),
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
                      const SizedBox(width: 16),
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

                  // Dedication message
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Aplicacion Inspirada en TvMate y Creada por mi desde 0 en Flutter.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.favorite,
                          color: Colors.red.withOpacity(0.8),
                          size: 20,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Bottom row - Secondary options
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
                      const SizedBox(width: 16),
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
                      const SizedBox(width: 16),
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
      margin: const EdgeInsets.only(left: 8),
      child: Material(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(50),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(50),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(
              icon,
              color: Colors.white,
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
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 280,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 80,
                color: Colors.white,
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: Colors.white,
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
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
}
