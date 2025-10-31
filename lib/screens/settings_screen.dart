import 'package:flutter/material.dart';
import '../services/database_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _videoQuality = 'auto';
  bool _autoPlay = true;
  double _volume = 1.0;
  bool _showAdultContent = false;
  String _videoFit = 'contain';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Video Settings
          const ListTile(
            title: Text(
              'Video Settings',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.high_quality),
            title: const Text('Video Quality'),
            subtitle: Text(_videoQuality.toUpperCase()),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () async {
              final result = await showDialog<String>(
                context: context,
                builder: (context) => SimpleDialog(
                  title: const Text('Select Quality'),
                  children: [
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(context, 'auto'),
                      child: const Text('Auto'),
                    ),
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(context, '1080p'),
                      child: const Text('1080p'),
                    ),
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(context, '720p'),
                      child: const Text('720p'),
                    ),
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(context, '480p'),
                      child: const Text('480p'),
                    ),
                  ],
                ),
              );
              if (result != null) {
                setState(() {
                  _videoQuality = result;
                });
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.aspect_ratio),
            title: const Text('Video Fit'),
            subtitle: Text(_videoFit.toUpperCase()),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () async {
              final result = await showDialog<String>(
                context: context,
                builder: (context) => SimpleDialog(
                  title: const Text('Select Video Fit'),
                  children: [
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(context, 'contain'),
                      child: const Text('Fit'),
                    ),
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(context, 'cover'),
                      child: const Text('Fill'),
                    ),
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(context, 'fitWidth'),
                      child: const Text('Fit Width'),
                    ),
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(context, 'fitHeight'),
                      child: const Text('Fit Height'),
                    ),
                  ],
                ),
              );
              if (result != null) {
                setState(() {
                  _videoFit = result;
                });
              }
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.play_arrow),
            title: const Text('Auto-play on select'),
            value: _autoPlay,
            onChanged: (value) {
              setState(() {
                _autoPlay = value;
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.volume_up),
            title: const Text('Default Volume'),
            subtitle: Slider(
              value: _volume,
              min: 0.0,
              max: 1.0,
              divisions: 10,
              label: '${(_volume * 100).round()}%',
              onChanged: (value) {
                setState(() {
                  _volume = value;
                });
              },
            ),
          ),

          const Divider(),

          // Parental Controls
          const ListTile(
            title: Text(
              'Parental Controls',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.block),
            title: const Text('Show Adult Content'),
            subtitle: const Text('Requires PIN to enable'),
            value: _showAdultContent,
            onChanged: (value) {
              if (value) {
                // Show PIN dialog
                _showPinDialog();
              } else {
                setState(() {
                  _showAdultContent = false;
                });
              }
            },
          ),

          const Divider(),

          // Data Management
          const ListTile(
            title: Text(
              'Data Management',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Clear All Data'),
            subtitle: const Text('Delete all playlists and channels'),
            onTap: () => _showClearDataDialog(),
          ),

          const Divider(),

          // About
          const ListTile(
            title: Text(
              'About',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Version'),
            subtitle: Text('1.0.0'),
          ),
          const ListTile(
            leading: Icon(Icons.code),
            title: Text('Built with Flutter'),
            subtitle: Text('Powered by media_kit and Isar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPinDialog() async {
    final pin = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Enter PIN'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'Enter 4-digit PIN',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );

    // Simple PIN check (in production, use proper authentication)
    if (pin == '1234') {
      setState(() {
        _showAdultContent = true;
      });
    } else if (pin != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incorrect PIN'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showClearDataDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will delete all playlists, channels, and settings. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseService.clearAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data cleared')),
        );
        Navigator.pop(context);
      }
    }
  }
}
