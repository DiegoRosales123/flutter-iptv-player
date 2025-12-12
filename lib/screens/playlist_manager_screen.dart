import 'package:flutter/material.dart';
import '../models/playlist.dart';
import '../models/channel.dart';
import '../services/database_service.dart';
import '../services/m3u_parser.dart';
import '../services/epg_service.dart';
import '../services/xtream_service.dart';
import '../services/preferences_service.dart';
import '../l10n/app_localizations.dart';

class PlaylistManagerScreen extends StatefulWidget {
  const PlaylistManagerScreen({Key? key}) : super(key: key);

  @override
  State<PlaylistManagerScreen> createState() => _PlaylistManagerScreenState();
}

class _PlaylistManagerScreenState extends State<PlaylistManagerScreen> {
  List<Playlist> _playlists = [];
  bool _isLoading = true;
  int? _activePlaylistId;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
    _loadActivePlaylistId();
  }

  Future<void> _loadActivePlaylistId() async {
    final id = await PreferencesService.getActivePlaylistId();
    setState(() => _activePlaylistId = id);
  }

  Future<void> _loadPlaylists() async {
    setState(() => _isLoading = true);
    final playlists = await DatabaseService.getAllPlaylists();
    setState(() {
      _playlists = playlists;
      _isLoading = false;
    });
  }

  Future<void> _addPlaylist() async {
    final result = await showDialog<Playlist>(
      context: context,
      builder: (context) => const PlaylistDialog(),
    );

    if (result != null) {
      await _processPlaylist(result);
    }
  }

  Future<void> _editPlaylist(Playlist playlist) async {
    final result = await showDialog<Playlist>(
      context: context,
      builder: (context) => PlaylistDialog(playlist: playlist),
    );

    if (result != null) {
      await _processPlaylist(result, isEdit: true);
    }
  }

  Future<void> _processPlaylist(Playlist playlist, {bool isEdit = false}) async {
    print('=== Processing Playlist ===');
    print('Name: ${playlist.name}');
    print('URL: ${playlist.url}');
    print('Source Type: ${playlist.sourceType}');
    print('Is Xtream: ${playlist.isXtreamCodes}');
    print('Username: ${playlist.username}');
    print('Password: ${playlist.password != null ? "***" : "null"}');

    // Mostrar diálogo de progreso
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _LoadingDialog(
        playlist: playlist,
        isEdit: isEdit,
      ),
    );

    try {
      List<Channel> channels = [];

      if (playlist.isXtreamCodes) {
        print('Processing as Xtream Codes...');
        // Handle Xtream Codes source
        final service = XtreamService(
          baseUrl: playlist.url,
          username: playlist.username!,
          password: playlist.password!,
        );

        print('Fetching ALL content from Xtream (live, movies, series)...');

        // Fetch LIVE CHANNELS
        print('1/3 - Fetching live channels...');
        final liveResult = await service.getLiveChannels();
        print('Live channels result: ${liveResult['success']}');

        if (liveResult['success'] == true) {
          channels.addAll(liveResult['channels'] as List<Channel>);
          print('Got ${channels.length} live channels');
        } else {
          print('Failed to get live channels: ${liveResult['message']}');
        }

        // Fetch MOVIES (VOD)
        print('2/3 - Fetching movies...');
        final moviesResult = await service.getMovies();
        print('Movies result: ${moviesResult['success']}');

        if (moviesResult['success'] == true) {
          final movies = moviesResult['movies'] as List;
          print('Converting ${movies.length} movies to channels...');

          for (var movie in movies) {
            final channel = Channel()
              ..name = movie.name
              ..url = movie.streamUrl
              ..logo = movie.posterUrl
              ..group = movie.categoryName
              ..description = movie.plot
              ..contentType = ContentType.movie;
            channels.add(channel);
          }
          print('Total after movies: ${channels.length}');
        } else {
          print('Failed to get movies: ${moviesResult['message']}');
        }

        // Fetch SERIES
        print('3/3 - Fetching series...');
        final seriesResult = await service.getSeries();
        print('Series result: ${seriesResult['success']}');

        if (seriesResult['success'] == true) {
          final seriesList = seriesResult['series'] as List;
          print('Converting ${seriesList.length} series to channels...');

          // Para Xtream Codes, guardamos solo UN canal por serie (la metadata)
          // Los episodios se cargarán bajo demanda cuando el usuario entre a series_grid_screen
          for (var series in seriesList) {
            // Usamos una URL especial para identificar que es una serie de Xtream
            // El formato es: xtream://series/SERIES_ID
            final channel = Channel()
              ..name = series.name
              ..url = 'xtream://series/${series.id}'
              ..logo = series.posterUrl
              ..group = series.categoryName
              ..description = series.plot
              ..tvgId = int.tryParse(series.id) // Guardamos el series_id aquí
              ..contentType = ContentType.series;
            channels.add(channel);
          }
          print('Total after series: ${channels.length}');
        } else {
          print('Failed to get series: ${seriesResult['message']}');
        }

        print('Xtream Codes processing complete: ${channels.length} total items');
      } else {
        print('Processing as M3U...');
        // Handle M3U source
        channels = await M3UParser.parseFromUrl(playlist.getFullUrl());
        print('Got ${channels.length} channels from M3U');
      }

      // Guardar playlist primero para obtener su ID
      playlist.channelCount = channels.length;
      playlist.lastUpdated = DateTime.now();
      await DatabaseService.addPlaylist(playlist);

      // Si es nueva playlist, establecerla como activa
      if (!isEdit) {
        // Asociar canales con la playlist
        for (var channel in channels) {
          channel.playlistId = playlist.id;
        }
        await DatabaseService.addChannels(channels);

        // Set this playlist as active
        await PreferencesService.setActivePlaylistId(playlist.id);
      } else {
        // Si es edición, actualizar los canales existentes
        for (var channel in channels) {
          channel.playlistId = playlist.id;
        }
        await DatabaseService.addChannels(channels);
      }

      // Intentar cargar EPG automáticamente (solo para M3U)
      String epgMessage = '';
      if (!playlist.isXtreamCodes) {
        final epgResult = await EpgService.loadEpgFromPlaylistUrl(playlist.getFullUrl());
        if (epgResult['success'] == true) {
          epgMessage = '\nEPG: ${epgResult['programs']} programas cargados';
        }
      }

      if (mounted) {
        Navigator.pop(context); // Cerrar diálogo de carga

        // Count by content type
        final liveCount = channels.where((c) => c.contentType == ContentType.live).length;
        final movieCount = channels.where((c) => c.contentType == ContentType.movie).length;
        final seriesCount = channels.where((c) => c.contentType == ContentType.series).length;

        String message;
        if (playlist.isXtreamCodes) {
          message = isEdit
            ? 'Playlist Xtream actualizada:\n$liveCount canales en vivo\n$movieCount películas\n$seriesCount series'
            : 'Playlist Xtream agregada:\n$liveCount canales en vivo\n$movieCount películas\n$seriesCount series';
        } else {
          message = isEdit
            ? 'Playlist actualizada: ${channels.length} canales$epgMessage'
            : 'Playlist agregada: ${channels.length} canales$epgMessage';
        }

        _showSuccessSnackBar(message);
      }

      _loadPlaylists();
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Cerrar diálogo de carga
        _showErrorSnackBar('Error: $e');
      }
    }
  }

  Future<void> _refreshPlaylist(Playlist playlist) async {
    await _processPlaylist(playlist, isEdit: true);
  }

  Future<void> _deletePlaylist(Playlist playlist) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2A3A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'Eliminar Playlist',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Estás seguro que deseas eliminar "${playlist.name}"?',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Esta acción eliminará ${playlist.channelCount} canales asociados.',
              style: TextStyle(color: Colors.red.shade300, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseService.deletePlaylist(playlist.id);
      _showSuccessSnackBar('Playlist eliminada');
      _loadPlaylists();
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showPlaylistOptions(Playlist playlist) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E2A3A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Playlist info header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade700],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.playlist_play, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playlist.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${playlist.channelCount} canales',
                          style: TextStyle(color: Colors.white.withOpacity(0.6)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white12, height: 1),

            // Options
            _buildOptionTile(
              icon: Icons.edit_outlined,
              label: 'Editar playlist',
              onTap: () {
                Navigator.pop(context);
                _editPlaylist(playlist);
              },
            ),
            _buildOptionTile(
              icon: Icons.refresh,
              label: 'Actualizar canales',
              onTap: () {
                Navigator.pop(context);
                _refreshPlaylist(playlist);
              },
            ),
            _buildOptionTile(
              icon: Icons.calendar_month,
              label: 'Actualizar EPG',
              onTap: () async {
                Navigator.pop(context);
                _updateEpg(playlist);
              },
            ),
            _buildOptionTile(
              icon: Icons.info_outline,
              label: 'Ver información',
              onTap: () {
                Navigator.pop(context);
                _showPlaylistInfo(playlist);
              },
            ),
            _buildOptionTile(
              icon: Icons.delete_outline,
              label: 'Eliminar playlist',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _deletePlaylist(playlist);
              },
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.white70),
      title: Text(
        label,
        style: TextStyle(color: color ?? Colors.white),
      ),
      onTap: onTap,
    );
  }

  Future<void> _updateEpg(Playlist playlist) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2A3A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: const Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Actualizando EPG...', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );

    try {
      final result = await EpgService.loadEpgFromPlaylistUrl(playlist.getFullUrl());
      Navigator.pop(context);

      if (result['success'] == true) {
        _showSuccessSnackBar('EPG actualizado: ${result['programs']} programas');
      } else {
        _showErrorSnackBar(result['message'] ?? 'No se pudo cargar el EPG');
      }
    } catch (e) {
      Navigator.pop(context);
      _showErrorSnackBar('Error al actualizar EPG: $e');
    }
  }

  void _showPlaylistInfo(Playlist playlist) {
    showDialog(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          backgroundColor: const Color(0xFF1E2A3A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue),
              const SizedBox(width: 12),
              Text(
                l10n.information,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow(l10n.name, playlist.name),
              _infoRow(l10n.channelsCount, '${playlist.channelCount}'),
              _infoRow(l10n.updated, _formatDateTime(playlist.lastUpdated, l10n)),
              _infoRow(l10n.authentication, playlist.username != null ? l10n.yes : l10n.no),
            const SizedBox(height: 12),
            Text(
              l10n.url,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                playlist.url,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
          ),
        ],
        );
      },
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0A1929),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1929),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.playlistManagement,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white54),
            onPressed: () => _showHelp(l10n),
            tooltip: l10n.help,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _playlists.isEmpty
              ? _buildEmptyState(l10n)
              : _buildPlaylistList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPlaylist,
        backgroundColor: Colors.blue,
        icon: const Icon(Icons.add),
        label: Text(l10n.newPlaylist),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.playlist_add,
              size: 60,
              color: Colors.white.withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.noPlaylists,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.addFirstPlaylist,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _addPlaylist,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.add),
            label: Text(l10n.addPlaylist),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistList() {
    final l10n = AppLocalizations.of(context);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _playlists.length,
      itemBuilder: (context, index) {
        final playlist = _playlists[index];
        return _buildPlaylistCard(playlist, l10n);
      },
    );
  }

  Widget _buildPlaylistCard(Playlist playlist, AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E2A3A),
            const Color(0xFF1E2A3A).withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showPlaylistOptions(playlist),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.blue.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.playlist_play, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildInfoChip(
                            Icons.tv,
                            '${playlist.channelCount} ${l10n.channelsLowercase}',
                          ),
                          const SizedBox(width: 12),
                          if (playlist.username != null)
                            _buildInfoChip(
                              Icons.lock,
                              l10n.authenticated,
                              color: Colors.green,
                            ),
                          const SizedBox(width: 12),
                          if (playlist.id == _activePlaylistId)
                            _buildInfoChip(
                              Icons.check_circle,
                              l10n.active,
                              color: Colors.blue,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Actualizado: ${_formatDate(playlist.lastUpdated, l10n)}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // Actions
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white54),
                      onPressed: () => _refreshPlaylist(playlist),
                      tooltip: l10n.refresh,
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert, color: Colors.white54),
                      onPressed: () => _showPlaylistOptions(playlist),
                      tooltip: l10n.moreOptions,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color ?? Colors.white54),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color ?? Colors.white54,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _showHelp(AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2A3A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.help_outline, color: Colors.blue),
            const SizedBox(width: 12),
            Text(l10n.help, style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _helpItem(l10n.supportedFormats, l10n.supportedFormatsDesc),
            _helpItem(l10n.xtreamUrl, l10n.xtreamUrlDesc),
            _helpItem(l10n.epg, l10n.epgDesc),
            _helpItem(l10n.update, l10n.updateDesc),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.understood),
          ),
        ],
      ),
    );
  }

  Widget _helpItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          Text(description, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date, AppLocalizations l10n) {
    if (date == null) return l10n.never;
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime? date, AppLocalizations l10n) {
    if (date == null) return l10n.never;
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// Diálogo de carga con progreso
class _LoadingDialog extends StatelessWidget {
  final Playlist playlist;
  final bool isEdit;

  const _LoadingDialog({required this.playlist, required this.isEdit});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      backgroundColor: const Color(0xFF1E2A3A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            isEdit ? l10n.updatingPlaylist : l10n.loadingPlaylist,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            playlist.name,
            style: TextStyle(color: Colors.white.withOpacity(0.6)),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.downloadingChannels,
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// Diálogo para agregar/editar playlist
class PlaylistDialog extends StatefulWidget {
  final Playlist? playlist;

  const PlaylistDialog({Key? key, this.playlist}) : super(key: key);

  @override
  State<PlaylistDialog> createState() => _PlaylistDialogState();
}

class _PlaylistDialogState extends State<PlaylistDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _urlController;
  late TextEditingController _hostController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late PlaylistSourceType _sourceType;
  bool _isVerifying = false;
  bool _showPassword = false;
  String? _verificationMessage;

  bool get isEditing => widget.playlist != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.playlist?.name ?? '');
    _urlController = TextEditingController(text: widget.playlist?.url ?? '');
    _usernameController = TextEditingController(text: widget.playlist?.username ?? '');
    _passwordController = TextEditingController(text: widget.playlist?.password ?? '');
    _hostController = TextEditingController(text: widget.playlist?.url ?? '');
    _sourceType = widget.playlist?.sourceType ?? PlaylistSourceType.m3u;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _hostController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _verifyXtreamCredentials() async {
    final l10n = AppLocalizations.of(context);

    if (_hostController.text.isEmpty || _usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _verificationMessage = l10n.completeAllFields);
      return;
    }

    setState(() {
      _isVerifying = true;
      _verificationMessage = null;
    });

    try {
      final service = XtreamService(
        baseUrl: _hostController.text.replaceAll(RegExp(r'/*$'), ''),
        username: _usernameController.text,
        password: _passwordController.text,
      );

      final isValid = await service.verifyCredentials();

      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() {
          _isVerifying = false;
          _verificationMessage = isValid ? l10n.credentialsVerified : l10n.credentialsInvalid;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _verificationMessage = 'Error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Dialog(
      backgroundColor: const Color(0xFF1E2A3A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isEditing ? Icons.edit : Icons.playlist_add,
                      color: Colors.blue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditing ? l10n.editPlaylist : l10n.newPlaylist,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isEditing ? l10n.modifyPlaylistSubtitle : l10n.addNewPlaylistSubtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Name field
              _buildTextField(
                controller: _nameController,
                label: l10n.playlistNameLabel,
                hint: l10n.playlistNameHint,
                icon: Icons.label_outline,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.playlistNameValidation;
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Source Type Selector
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _sourceType = PlaylistSourceType.m3u),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _sourceType == PlaylistSourceType.m3u
                                ? Colors.blue.withOpacity(0.3)
                                : Colors.transparent,
                            borderRadius: BorderRadius.horizontal(
                              left: Radius.circular(_sourceType == PlaylistSourceType.m3u ? 12 : 8),
                            ),
                          ),
                          child: const Text(
                            'M3U',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _sourceType = PlaylistSourceType.xtreamCodes),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _sourceType == PlaylistSourceType.xtreamCodes
                                ? Colors.blue.withOpacity(0.3)
                                : Colors.transparent,
                            borderRadius: BorderRadius.horizontal(
                              right: Radius.circular(_sourceType == PlaylistSourceType.xtreamCodes ? 12 : 8),
                            ),
                          ),
                          child: const Text(
                            'Xtream Codes',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // M3U Form
              if (_sourceType == PlaylistSourceType.m3u) ...[
                _buildTextField(
                  controller: _urlController,
                  label: l10n.playlistUrlLabel,
                  hint: l10n.playlistUrlHint,
                  icon: Icons.link,
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.playlistUrlValidation;
                    }
                    if (!value.startsWith('http://') && !value.startsWith('https://')) {
                      return l10n.urlValidationProtocol;
                    }
                    return null;
                  },
                ),
              ],

              // Xtream Codes Form
              if (_sourceType == PlaylistSourceType.xtreamCodes) ...[
                _buildTextField(
                  controller: _hostController,
                  label: l10n.serverHostLabel,
                  hint: l10n.serverHostHint,
                  icon: Icons.storage,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.serverHostValidation;
                    }
                    if (!value.startsWith('http://') && !value.startsWith('https://')) {
                      return l10n.protocolValidation;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _usernameController,
                        label: l10n.usernameLabel,
                        hint: l10n.usernameHint,
                        icon: Icons.person_outline,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return l10n.usernameValidation;
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _passwordController,
                        label: l10n.passwordLabel,
                        hint: l10n.passwordHint,
                        icon: Icons.lock_outline,
                        obscureText: !_showPassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showPassword ? Icons.visibility_off : Icons.visibility,
                            color: Colors.white54,
                          ),
                          onPressed: () => setState(() => _showPassword = !_showPassword),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return l10n.passwordValidation;
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Verification button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isVerifying ? null : _verifyXtreamCredentials,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      disabledBackgroundColor: Colors.grey.withOpacity(0.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isVerifying
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            l10n.verifyCredentials,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                if (_verificationMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _verificationMessage!.contains('verificadas')
                          ? Colors.green.withOpacity(0.2)
                          : Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _verificationMessage!.contains('verificadas')
                            ? Colors.green.withOpacity(0.5)
                            : Colors.red.withOpacity(0.5),
                      ),
                    ),
                    child: Text(
                      _verificationMessage!,
                      style: TextStyle(
                        color: _verificationMessage!.contains('verificadas') ? Colors.green : Colors.red,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: Text(l10n.cancel),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(isEditing ? Icons.save : Icons.add),
                    label: Text(isEditing ? l10n.save : l10n.add),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
        prefixIcon: Icon(icon, color: Colors.white54),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
      validator: validator,
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final playlist = widget.playlist ?? Playlist();
      playlist.name = _nameController.text.trim();
      playlist.sourceType = _sourceType;

      if (_sourceType == PlaylistSourceType.m3u) {
        playlist.url = _urlController.text.trim();
        playlist.username = null;
        playlist.password = null;
      } else {
        playlist.url = _hostController.text.replaceAll(RegExp(r'/*$'), '');
        playlist.username = _usernameController.text.trim();
        playlist.password = _passwordController.text.trim();
      }

      playlist.lastUpdated = DateTime.now();

      if (widget.playlist == null) {
        playlist.isActive = true;
      }

      Navigator.pop(context, playlist);
    }
  }
}
