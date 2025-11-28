import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WelcomeDialog extends StatelessWidget {
  static const String _firstLaunchKey = 'first_launch';

  const WelcomeDialog({super.key});

  Future<void> _launchGitHub() async {
    final Uri url = Uri.parse('https://github.com/DiegoRosales123/flutter-iptv-player');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  Future<void> _onContinue(BuildContext context) async {
    // Mark as not first launch anymore
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstLaunchKey, false);

    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Heart Icon
            const Icon(
              Icons.favorite,
              color: Colors.red,
              size: 60,
            ),
            const SizedBox(height: 20),

            // Title
            const Text(
              '¡Bienvenido! / Welcome! / Добро пожаловать! / 欢迎!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // Spanish
            _buildMessage(
              '🇪🇸 Si llegaste hasta aquí, déjame una estrella en GitHub para seguir actualizando este hermoso proyecto ❤️',
            ),
            const SizedBox(height: 16),

            // English
            _buildMessage(
              '🇬🇧 If you made it this far, leave me a star on GitHub to keep updating this beautiful project ❤️',
            ),
            const SizedBox(height: 16),

            // Russian
            _buildMessage(
              '🇷🇺 Если вы зашли так далеко, оставьте мне звезду на GitHub, чтобы я продолжал обновлять этот прекрасный проект ❤️',
            ),
            const SizedBox(height: 16),

            // Chinese
            _buildMessage(
              '🇨🇳 如果你能看到这里，请在 GitHub 上给我一个星标，以便我继续更新这个美丽的项目 ❤️',
            ),
            const SizedBox(height: 24),

            // GitHub Link Button
            ElevatedButton.icon(
              onPressed: _launchGitHub,
              icon: const Icon(Icons.star, color: Colors.amber),
              label: const Text(
                'GitHub ⭐',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // GitHub URL text
            GestureDetector(
              onTap: _launchGitHub,
              child: const Text(
                'github.com/DiegoRosales123/flutter-iptv-player',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Close button
            TextButton(
              onPressed: () => _onContinue(context),
              child: const Text(
                'Continuar / Continue / Продолжить / 继续',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 14,
        height: 1.5,
      ),
    );
  }
}
