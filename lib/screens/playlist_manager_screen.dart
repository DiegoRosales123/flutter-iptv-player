import 'package:flutter/material.dart';
import '../models/playlist.dart';
import '../services/database_service.dart';
import '../services/m3u_parser.dart';
import '../services/epg_service.dart';

class PlaylistManagerScreen extends StatefulWidget {
  const PlaylistManagerScreen({Key? key}) : super(key: key);

  @override
  State<PlaylistManagerScreen> createState() => _PlaylistManagerScreenState();
}

class _PlaylistManagerScreenState extends State<PlaylistManagerScreen> {
  List<Playlist> _playlists = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
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
      // Parsear playlist
      final channels = await M3UParser.parseFromUrl(playlist.getFullUrl());

      // Guardar playlist y canales
      playlist.channelCount = channels.length;
      playlist.lastUpdated = DateTime.now();
      await DatabaseService.addPlaylist(playlist);

      if (!isEdit) {
        await DatabaseService.addChannels(channels);
      }

      // Intentar cargar EPG automáticamente
      String epgMessage = '';
      final epgResult = await EpgService.loadEpgFromPlaylistUrl(playlist.getFullUrl());
      if (epgResult['success'] == true) {
        epgMessage = '\nEPG: ${epgResult['programs']} programas cargados';
      }

      if (mounted) {
        Navigator.pop(context); // Cerrar diálogo de carga
        _showSuccessSnackBar(
          isEdit
            ? 'Playlist actualizada: ${channels.length} canales$epgMessage'
            : 'Playlist agregada: ${channels.length} canales$epgMessage',
        );
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
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2A3A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.blue),
            const SizedBox(width: 12),
            const Text(
              'Información',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Nombre', playlist.name),
            _infoRow('Canales', '${playlist.channelCount}'),
            _infoRow('Actualizado', _formatDateTime(playlist.lastUpdated)),
            _infoRow('Autenticación', playlist.username != null ? 'Sí' : 'No'),
            const SizedBox(height: 12),
            const Text(
              'URL:',
              style: TextStyle(color: Colors.white70, fontSize: 12),
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
            child: const Text('Cerrar'),
          ),
        ],
      ),
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
    return Scaffold(
      backgroundColor: const Color(0xFF0A1929),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1929),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Gestión de Playlists',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white54),
            onPressed: _showHelp,
            tooltip: 'Ayuda',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _playlists.isEmpty
              ? _buildEmptyState()
              : _buildPlaylistList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPlaylist,
        backgroundColor: Colors.blue,
        icon: const Icon(Icons.add),
        label: const Text('Nueva Playlist'),
      ),
    );
  }

  Widget _buildEmptyState() {
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
          const Text(
            'Sin playlists',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega tu primera playlist IPTV\npara comenzar a ver contenido',
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
            label: const Text('Agregar Playlist'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _playlists.length,
      itemBuilder: (context, index) {
        final playlist = _playlists[index];
        return _buildPlaylistCard(playlist);
      },
    );
  }

  Widget _buildPlaylistCard(Playlist playlist) {
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
                            '${playlist.channelCount} canales',
                          ),
                          const SizedBox(width: 12),
                          if (playlist.username != null)
                            _buildInfoChip(
                              Icons.lock,
                              'Autenticado',
                              color: Colors.green,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Actualizado: ${_formatDate(playlist.lastUpdated)}',
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
                      tooltip: 'Actualizar',
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert, color: Colors.white54),
                      onPressed: () => _showPlaylistOptions(playlist),
                      tooltip: 'Más opciones',
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

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2A3A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.help_outline, color: Colors.blue),
            const SizedBox(width: 12),
            const Text('Ayuda', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _helpItem('Formatos soportados:', 'M3U, M3U8, Xtream Codes API'),
            _helpItem('URL Xtream:', 'El sistema detecta automáticamente credenciales y carga el EPG'),
            _helpItem('EPG:', 'La guía de programación se carga automáticamente si está disponible'),
            _helpItem('Actualizar:', 'Usa el botón de refresh para recargar los canales'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
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

  String _formatDate(DateTime? date) {
    if (date == null) return 'Nunca';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) return 'Nunca';
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
            isEdit ? 'Actualizando playlist...' : 'Cargando playlist...',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            playlist.name,
            style: TextStyle(color: Colors.white.withOpacity(0.6)),
          ),
          const SizedBox(height: 16),
          Text(
            'Descargando y procesando canales...',
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
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  bool _requiresAuth = false;
  bool _showPassword = false;

  bool get isEditing => widget.playlist != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.playlist?.name ?? '');
    _urlController = TextEditingController(text: widget.playlist?.url ?? '');
    _usernameController = TextEditingController(text: widget.playlist?.username ?? '');
    _passwordController = TextEditingController(text: widget.playlist?.password ?? '');
    _requiresAuth = widget.playlist?.username != null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                        isEditing ? 'Editar Playlist' : 'Nueva Playlist',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isEditing ? 'Modifica los datos de tu playlist' : 'Agrega una nueva playlist IPTV',
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
                label: 'Nombre de la playlist',
                hint: 'Mi IPTV',
                icon: Icons.label_outline,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa un nombre';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // URL field
              _buildTextField(
                controller: _urlController,
                label: 'URL de la playlist',
                hint: 'http://servidor.com/get.php?username=X&password=Y&type=m3u_plus',
                icon: Icons.link,
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa la URL';
                  }
                  if (!value.startsWith('http://') && !value.startsWith('https://')) {
                    return 'La URL debe comenzar con http:// o https://';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Auth toggle
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SwitchListTile(
                  title: const Text(
                    'Autenticación adicional',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    'Si la URL no incluye credenciales',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                  ),
                  value: _requiresAuth,
                  onChanged: (value) => setState(() => _requiresAuth = value),
                  activeColor: Colors.blue,
                ),
              ),

              // Auth fields
              if (_requiresAuth) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _usernameController,
                        label: 'Usuario',
                        hint: 'username',
                        icon: Icons.person_outline,
                        validator: (value) {
                          if (_requiresAuth && (value == null || value.isEmpty)) {
                            return 'Requerido';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _passwordController,
                        label: 'Contraseña',
                        hint: '••••••',
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
                          if (_requiresAuth && (value == null || value.isEmpty)) {
                            return 'Requerido';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
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
                    child: const Text('Cancelar'),
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
                    label: Text(isEditing ? 'Guardar' : 'Agregar'),
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
      playlist.url = _urlController.text.trim();
      playlist.username = _requiresAuth ? _usernameController.text.trim() : null;
      playlist.password = _requiresAuth ? _passwordController.text.trim() : null;
      playlist.lastUpdated = DateTime.now();

      if (widget.playlist == null) {
        playlist.isActive = true;
      }

      Navigator.pop(context, playlist);
    }
  }
}
