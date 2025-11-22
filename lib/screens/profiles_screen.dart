import 'package:flutter/material.dart';
import '../models/profile.dart';
import '../services/database_service.dart';

class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({Key? key}) : super(key: key);

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  List<Profile> _profiles = [];
  Profile? _activeProfile;
  bool _isLoading = true;

  // Avatar options
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
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    setState(() => _isLoading = true);
    final profiles = await DatabaseService.getAllProfiles();
    final active = await DatabaseService.getActiveProfile();
    setState(() {
      _profiles = profiles;
      _activeProfile = active;
      _isLoading = false;
    });
  }

  Future<void> _selectProfile(Profile profile) async {
    await DatabaseService.setActiveProfile(profile);
    if (mounted) {
      Navigator.pop(context, profile);
    }
  }

  Future<void> _showAddProfileDialog() async {
    final nameController = TextEditingController();
    int selectedIconIndex = 0;
    int selectedColorIndex = 0;
    bool showAdultContent = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A2A3A),
          title: const Text(
            'Nuevo Perfil',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar preview
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: _avatarColors[selectedColorIndex],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _avatarIcons[selectedIconIndex],
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Name field
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Nombre del perfil',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.blue),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                  ),
                ),
                const SizedBox(height: 20),

                // Icon selector
                const Text(
                  'Selecciona un icono',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(_avatarIcons.length, (index) {
                    final isSelected = index == selectedIconIndex;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedIconIndex = index),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _avatarColors[selectedColorIndex]
                              : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 2)
                              : null,
                        ),
                        child: Icon(
                          _avatarIcons[index],
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),

                // Color selector
                const Text(
                  'Selecciona un color',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(_avatarColors.length, (index) {
                    final isSelected = index == selectedColorIndex;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColorIndex = index),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _avatarColors[index],
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : null,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),

                // Adult content toggle
                Row(
                  children: [
                    Checkbox(
                      value: showAdultContent,
                      onChanged: (value) {
                        setDialogState(() => showAdultContent = value ?? false);
                      },
                      activeColor: Colors.blue,
                    ),
                    const Text(
                      'Mostrar contenido adulto',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('El nombre es requerido')),
                  );
                  return;
                }

                final profile = Profile.create(
                  name: nameController.text.trim(),
                  avatarUrl: '${selectedIconIndex}_${selectedColorIndex}',
                );
                profile.showAdultContent = showAdultContent;

                await DatabaseService.addProfile(profile);
                Navigator.pop(context);
                _loadProfiles();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditProfileDialog(Profile profile) async {
    final nameController = TextEditingController(text: profile.name);

    // Parse avatar data
    int selectedIconIndex = 0;
    int selectedColorIndex = 0;
    if (profile.avatarUrl != null && profile.avatarUrl!.contains('_')) {
      final parts = profile.avatarUrl!.split('_');
      selectedIconIndex = int.tryParse(parts[0]) ?? 0;
      selectedColorIndex = int.tryParse(parts[1]) ?? 0;
    }

    bool showAdultContent = profile.showAdultContent;
    String videoQuality = profile.videoQuality;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A2A3A),
          title: const Text(
            'Editar Perfil',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar preview
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: _avatarColors[selectedColorIndex.clamp(0, _avatarColors.length - 1)],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _avatarIcons[selectedIconIndex.clamp(0, _avatarIcons.length - 1)],
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Name field
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Nombre del perfil',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.blue),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                  ),
                ),
                const SizedBox(height: 20),

                // Icon selector
                const Text(
                  'Selecciona un icono',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(_avatarIcons.length, (index) {
                    final isSelected = index == selectedIconIndex;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedIconIndex = index),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _avatarColors[selectedColorIndex.clamp(0, _avatarColors.length - 1)]
                              : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 2)
                              : null,
                        ),
                        child: Icon(
                          _avatarIcons[index],
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),

                // Color selector
                const Text(
                  'Selecciona un color',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(_avatarColors.length, (index) {
                    final isSelected = index == selectedColorIndex;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColorIndex = index),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _avatarColors[index],
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : null,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),

                // Video quality
                const Text(
                  'Calidad de video',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: videoQuality,
                    dropdownColor: const Color(0xFF1A2A3A),
                    isExpanded: true,
                    underline: const SizedBox(),
                    style: const TextStyle(color: Colors.white),
                    items: const [
                      DropdownMenuItem(value: 'auto', child: Text('Automática')),
                      DropdownMenuItem(value: '1080p', child: Text('1080p')),
                      DropdownMenuItem(value: '720p', child: Text('720p')),
                      DropdownMenuItem(value: '480p', child: Text('480p')),
                    ],
                    onChanged: (value) {
                      setDialogState(() => videoQuality = value ?? 'auto');
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Adult content toggle
                Row(
                  children: [
                    Checkbox(
                      value: showAdultContent,
                      onChanged: (value) {
                        setDialogState(() => showAdultContent = value ?? false);
                      },
                      activeColor: Colors.blue,
                    ),
                    const Text(
                      'Mostrar contenido adulto',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('El nombre es requerido')),
                  );
                  return;
                }

                profile.name = nameController.text.trim();
                profile.avatarUrl = '${selectedIconIndex}_${selectedColorIndex}';
                profile.showAdultContent = showAdultContent;
                profile.videoQuality = videoQuality;

                await DatabaseService.addProfile(profile);
                Navigator.pop(context);
                _loadProfiles();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteProfile(Profile profile) async {
    if (profile.isActive && _profiles.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No puedes eliminar el único perfil')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2A3A),
        title: const Text(
          'Eliminar Perfil',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '¿Estás seguro que deseas eliminar el perfil "${profile.name}"?',
          style: const TextStyle(color: Colors.white70),
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
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseService.deleteProfile(profile.id);
      _loadProfiles();
    }
  }

  Widget _buildProfileAvatar(Profile profile, {double size = 80}) {
    int iconIndex = 0;
    int colorIndex = 0;

    if (profile.avatarUrl != null && profile.avatarUrl!.contains('_')) {
      final parts = profile.avatarUrl!.split('_');
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
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1929),
        elevation: 0,
        title: const Text(
          '¿Quién está viendo?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(48),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Profiles grid
                    Wrap(
                      spacing: 32,
                      runSpacing: 32,
                      alignment: WrapAlignment.center,
                      children: [
                        ..._profiles.map((profile) => _buildProfileCard(profile)),
                        _buildAddProfileCard(),
                      ],
                    ),
                    const SizedBox(height: 48),

                    // Manage profiles button
                    TextButton.icon(
                      onPressed: () {
                        setState(() {});
                      },
                      icon: const Icon(Icons.edit, color: Colors.white54),
                      label: const Text(
                        'Administrar perfiles',
                        style: TextStyle(color: Colors.white54, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileCard(Profile profile) {
    final isActive = profile.id == _activeProfile?.id;

    return GestureDetector(
      onTap: () => _selectProfile(profile),
      onLongPress: () => _showProfileOptions(profile),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: isActive
                      ? Border.all(color: Colors.blue, width: 3)
                      : null,
                ),
                child: _buildProfileAvatar(profile, size: 120),
              ),
              if (isActive)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            profile.name,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white70,
              fontSize: 18,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (profile.showAdultContent)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '+18',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddProfileCard() {
    return GestureDetector(
      onTap: _showAddProfileDialog,
      child: Column(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
                style: BorderStyle.solid,
              ),
            ),
            child: const Icon(
              Icons.add,
              size: 48,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Agregar perfil',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  void _showProfileOptions(Profile profile) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A2A3A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _buildProfileAvatar(profile, size: 60),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Creado: ${_formatDate(profile.createdAt)}',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.white70),
              title: const Text(
                'Editar perfil',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _showEditProfileDialog(profile);
              },
            ),
            if (!profile.isActive)
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text(
                  'Activar perfil',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _selectProfile(profile);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Eliminar perfil',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteProfile(profile);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Desconocido';
    return '${date.day}/${date.month}/${date.year}';
  }
}
