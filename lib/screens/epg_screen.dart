import 'package:flutter/material.dart';
import '../models/channel.dart';
import '../models/epg.dart';
import '../services/database_service.dart';
import '../services/epg_service.dart';
import 'video_player_screen.dart';

class EpgScreen extends StatefulWidget {
  const EpgScreen({Key? key}) : super(key: key);

  @override
  State<EpgScreen> createState() => _EpgScreenState();
}

class _EpgScreenState extends State<EpgScreen> {
  List<Channel> _channels = [];
  Map<String, List<EpgProgram>> _programsByChannel = {};
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  final ScrollController _channelScrollController = ScrollController();
  final ScrollController _programScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  bool _isSyncingScroll = false;

  // Time grid settings
  final double _channelWidth = 200;
  final double _hourWidth = 200; // pixels per hour
  final double _rowHeight = 80;
  final int _hoursToShow = 24;

  @override
  void initState() {
    super.initState();
    _loadData();

    // Sync channel list scroll with program grid
    _channelScrollController.addListener(_syncFromChannelScroll);
    _programScrollController.addListener(_syncFromProgramScroll);

    // Scroll to current time
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentTime();
    });
  }

  void _syncFromChannelScroll() {
    if (_isSyncingScroll) return;
    if (!_programScrollController.hasClients) return;
    _isSyncingScroll = true;
    _programScrollController.jumpTo(_channelScrollController.offset);
    _isSyncingScroll = false;
  }

  void _syncFromProgramScroll() {
    if (_isSyncingScroll) return;
    if (!_channelScrollController.hasClients) return;
    _isSyncingScroll = true;
    _channelScrollController.jumpTo(_programScrollController.offset);
    _isSyncingScroll = false;
  }

  @override
  void dispose() {
    _channelScrollController.removeListener(_syncFromChannelScroll);
    _programScrollController.removeListener(_syncFromProgramScroll);
    _channelScrollController.dispose();
    _programScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    // Get live TV channels
    final allChannels = await DatabaseService.getAllChannels();
    final channels = allChannels
        .where((c) => c.contentType == ContentType.live)
        .toList();

    // Get all EPG channels for matching
    final epgChannels = await EpgService.getAllChannels();
    final epgChannelMap = <String, String>{}; // Map from various IDs to EPG channel ID

    for (final epgChannel in epgChannels) {
      // Map by channel ID
      epgChannelMap[epgChannel.channelId.toLowerCase()] = epgChannel.channelId;
      // Map by display name if available
      if (epgChannel.displayName != null) {
        epgChannelMap[epgChannel.displayName!.toLowerCase()] = epgChannel.channelId;
      }
    }

    print('EPG Screen - ${channels.length} canales de TV, ${epgChannels.length} canales EPG');

    // Get EPG data for each channel
    final programsByChannel = <String, List<EpgProgram>>{};
    final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    int matchedChannels = 0;
    for (final channel in channels) {
      // Try to find matching EPG channel
      String? epgChannelId;

      // Try tvgId as string (some EPGs use numeric IDs)
      if (channel.tvgId != null) {
        epgChannelId = epgChannelMap[channel.tvgId.toString()];
      }

      // Try tvgName
      if (epgChannelId == null && channel.tvgName != null && channel.tvgName!.isNotEmpty) {
        epgChannelId = epgChannelMap[channel.tvgName!.toLowerCase()];
      }

      // Try channel name
      if (epgChannelId == null) {
        epgChannelId = epgChannelMap[channel.name.toLowerCase()];
      }

      // Build channel key for storage
      final channelKey = channel.tvgName ?? channel.name;

      if (epgChannelId != null) {
        final programs = await EpgService.getProgramsInTimeRange(
          epgChannelId,
          startOfDay,
          endOfDay,
        );
        if (programs.isNotEmpty) {
          programsByChannel[channelKey] = programs;
          matchedChannels++;
        }
      }
    }

    print('EPG Screen - $matchedChannels canales con programación encontrada');

    if (!mounted) return;
    setState(() {
      _channels = channels;
      _programsByChannel = programsByChannel;
      _isLoading = false;
    });
  }

  void _scrollToCurrentTime() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final hoursSinceStart = now.difference(startOfDay).inMinutes / 60;
    final scrollPosition = (hoursSinceStart * _hourWidth - 100).clamp(0.0, _hourWidth * _hoursToShow);

    if (_horizontalScrollController.hasClients) {
      _horizontalScrollController.animateTo(
        scrollPosition,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _showLoadEpgDialog() async {
    final urlController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2A3A),
        title: const Text(
          'Cargar EPG',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ingresa la URL del archivo EPG (formato XMLTV):',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'https://ejemplo.com/epg.xml',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (urlController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ingresa una URL válida')),
                );
                return;
              }

              Navigator.pop(context);
              await _loadEpgFromUrl(urlController.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Cargar'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadEpgFromUrl(String url) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        backgroundColor: Color(0xFF1A2A3A),
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 24),
            Text(
              'Cargando EPG...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );

    try {
      await EpgService.loadEpgFromUrl(url);
      Navigator.pop(context);

      final stats = await EpgService.getEpgStats();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'EPG cargado: ${stats['channels']} canales, ${stats['programs']} programas',
          ),
        ),
      );

      _loadData();
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar EPG: $e')),
      );
    }
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1929),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1929),
        elevation: 0,
        title: const Text(
          'Guía de Programación (EPG)',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.today, color: Colors.white),
            onPressed: () {
              setState(() => _selectedDate = DateTime.now());
              _loadData();
              _scrollToCurrentTime();
            },
            tooltip: 'Ir a hoy',
          ),
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: _showLoadEpgDialog,
            tooltip: 'Cargar EPG',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF1A2A3A),
                  title: const Text('Limpiar EPG', style: TextStyle(color: Colors.white)),
                  content: const Text(
                    '¿Deseas eliminar todos los datos de EPG?',
                    style: TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Eliminar'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await EpgService.clearEpgData();
                _loadData();
              }
            },
            tooltip: 'Limpiar EPG',
          ),
        ],
      ),
      body: Column(
        children: [
          // Date selector
          _buildDateSelector(),

          // EPG Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _programsByChannel.isEmpty
                    ? _buildEmptyState()
                    : _buildEpgGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFF1A2A3A),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: () => _changeDate(-1),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 7)),
                lastDate: DateTime.now().add(const Duration(days: 7)),
                builder: (context, child) {
                  return Theme(
                    data: ThemeData.dark().copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: Colors.blue,
                        surface: Color(0xFF1A2A3A),
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
                _loadData();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.white70, size: 18),
                  const SizedBox(width: 12),
                  Text(
                    _formatDate(_selectedDate),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: () => _changeDate(1),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 24),
          Text(
            'No hay datos de EPG',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Carga un archivo EPG para ver la programación',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showLoadEpgDialog,
            icon: const Icon(Icons.download),
            label: const Text('Cargar EPG'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpgGrid() {
    final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

    return Row(
      children: [
        // Fixed channel column
        SizedBox(
          width: _channelWidth,
          child: Column(
            children: [
              // Header "Canal"
              Container(
                height: 40,
                color: const Color(0xFF1A2A3A),
                alignment: Alignment.center,
                child: const Text(
                  'Canal',
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                ),
              ),
              // Channel list
              Expanded(
                child: ListView.builder(
                  controller: _channelScrollController,
                  itemCount: _channels.length,
                  itemBuilder: (context, index) {
                    return _buildChannelCell(_channels[index]);
                  },
                ),
              ),
            ],
          ),
        ),
        // Scrollable programs area
        Expanded(
          child: SingleChildScrollView(
            controller: _horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: _hourWidth * _hoursToShow,
              child: Column(
                children: [
                  // Time header
                  SizedBox(
                    height: 40,
                    child: Row(
                      children: List.generate(_hoursToShow, (index) {
                        final hour = startOfDay.add(Duration(hours: index));
                        final isCurrentHour = _isCurrentHour(hour);

                        return Container(
                          width: _hourWidth,
                          decoration: BoxDecoration(
                            color: isCurrentHour
                                ? Colors.blue.withOpacity(0.3)
                                : const Color(0xFF1A2A3A),
                            border: Border(
                              left: BorderSide(
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${hour.hour.toString().padLeft(2, '0')}:00',
                            style: TextStyle(
                              color: isCurrentHour ? Colors.white : Colors.white70,
                              fontWeight: isCurrentHour ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  // Programs grid
                  Expanded(
                    child: ListView.builder(
                      controller: _programScrollController,
                      itemCount: _channels.length,
                      itemBuilder: (context, index) {
                        final channel = _channels[index];
                        final channelKey = channel.tvgName ?? channel.name;
                        final programs = _programsByChannel[channelKey] ?? [];
                        return SizedBox(
                          height: _rowHeight,
                          child: _buildProgramRowContent(channel, programs, startOfDay),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgramRowContent(Channel channel, List<EpgProgram> programs, DateTime startOfDay) {
    return Stack(
      children: [
        // Background
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D1F2D),
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
        ),
        // Current time indicator
        if (_isToday(_selectedDate)) _buildCurrentTimeIndicator(startOfDay),
        // Programs
        ...programs.map((program) => _buildProgramCell(channel, program, startOfDay)),
        // If no programs, show empty state
        if (programs.isEmpty)
          Center(
            child: Text(
              'Sin programación',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildChannelCell(Channel channel) {
    return Container(
      height: _rowHeight,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1F2D),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          // Channel logo
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: channel.logo != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      channel.logo!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.tv,
                        color: Colors.white54,
                        size: 24,
                      ),
                    ),
                  )
                : const Icon(Icons.tv, color: Colors.white54, size: 24),
          ),
          const SizedBox(width: 8),
          // Channel name
          Expanded(
            child: Text(
              channel.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgramCell(Channel channel, EpgProgram program, DateTime startOfDay) {
    final totalWidth = _hourWidth * _hoursToShow;
    final rawStartOffset = program.startTime.difference(startOfDay).inMinutes / 60 * _hourWidth;
    final rawDuration = program.durationMinutes / 60 * _hourWidth;

    // Skip programs outside visible range
    if (rawStartOffset >= totalWidth || rawStartOffset + rawDuration <= 0) {
      return const SizedBox.shrink();
    }

    // Clamp values to visible area
    final startOffset = rawStartOffset.clamp(0.0, totalWidth);
    final endOffset = (rawStartOffset + rawDuration).clamp(0.0, totalWidth);
    final width = (endOffset - startOffset).clamp(50.0, totalWidth);

    final isNowPlaying = program.isNowPlaying;

    return Positioned(
      left: startOffset,
      width: width,
      top: 4,
      bottom: 4,
      child: GestureDetector(
        onTap: () => _showProgramDetails(channel, program),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isNowPlaying
                ? Colors.blue.withOpacity(0.4)
                : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
            border: isNowPlaying
                ? Border.all(color: Colors.blue, width: 2)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                program.title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: isNowPlaying ? FontWeight.bold : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                program.formattedTimeRange,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 10,
                ),
              ),
              if (isNowPlaying) ...[
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: program.progress,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTimeIndicator(DateTime startOfDay) {
    final now = DateTime.now();
    final offset = now.difference(startOfDay).inMinutes / 60 * _hourWidth;

    return Positioned(
      left: offset,
      top: 0,
      bottom: 0,
      child: Container(
        width: 2,
        color: Colors.red,
      ),
    );
  }

  void _showProgramDetails(Channel channel, EpgProgram program) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A2A3A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Row(
              children: [
                if (program.isNowPlaying)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'EN VIVO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    program.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Channel and time
            Row(
              children: [
                const Icon(Icons.tv, color: Colors.white54, size: 16),
                const SizedBox(width: 8),
                Text(
                  channel.name,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(width: 24),
                const Icon(Icons.access_time, color: Colors.white54, size: 16),
                const SizedBox(width: 8),
                Text(
                  program.formattedTimeRange,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${program.durationMinutes} min)',
                  style: TextStyle(color: Colors.white.withOpacity(0.5)),
                ),
              ],
            ),

            if (program.category != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.category, color: Colors.white54, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    program.category!,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ],

            if (program.description != null) ...[
              const SizedBox(height: 16),
              Text(
                program.description!,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // Progress bar for current program
            if (program.isNowPlaying) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: program.progress,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    program.formattedStartTime,
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                  ),
                  Text(
                    '${(program.progress * 100).toInt()}%',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                  ),
                  Text(
                    program.formattedEndTime,
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VideoPlayerScreen(channel: channel),
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Ver canal'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: () {
                    // TODO: Add to favorites/reminders
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Recordatorios próximamente')),
                    );
                  },
                  icon: const Icon(Icons.notification_add, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _isCurrentHour(DateTime hour) {
    final now = DateTime.now();
    return _isToday(_selectedDate) &&
        now.hour == hour.hour;
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String _formatDate(DateTime date) {
    final days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];

    if (_isToday(date)) {
      return 'Hoy, ${date.day} de ${months[date.month - 1]}';
    }

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    if (date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day) {
      return 'Mañana, ${date.day} de ${months[date.month - 1]}';
    }

    return '${days[date.weekday - 1]}, ${date.day} de ${months[date.month - 1]}';
  }
}
