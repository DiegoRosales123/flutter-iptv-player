import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../l10n/app_localizations.dart';

class ThemeSelector extends StatelessWidget {
  const ThemeSelector({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final l10n = AppLocalizations.of(context);

    return Dialog(
      backgroundColor: const Color(0xFF1A2B3C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                const Icon(
                  Icons.palette,
                  color: Color(0xFF5DD3E5),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.selectTheme,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Theme options
            _ThemeOption(
              title: l10n.themeOriginal,
              description: l10n.themeOriginalDesc,
              isSelected: themeProvider.currentTheme == AppThemeType.original,
              colors: const [
                Color(0xFF0B1A2A),
                Color(0xFF1A3A52),
                Color(0xFF5DD3E5),
              ],
              onTap: () async {
                await themeProvider.setTheme(AppThemeType.original);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${l10n.themeOriginal} ${l10n.themeApplied}'),
                      duration: const Duration(seconds: 2),
                      backgroundColor: const Color(0xFF1A3A52),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 12),

            _ThemeOption(
              title: l10n.themeNetflix,
              description: l10n.themeNetflixDesc,
              isSelected: themeProvider.currentTheme == AppThemeType.netflix,
              colors: const [
                Color(0xFF141414),
                Color(0xFF2D2D2D),
                Color(0xFFE50914),
              ],
              onTap: () async {
                await themeProvider.setTheme(AppThemeType.netflix);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${l10n.themeNetflix} ${l10n.themeApplied}'),
                      duration: const Duration(seconds: 2),
                      backgroundColor: const Color(0xFF2D2D2D),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 24),

            // Close button
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  l10n.close,
                  style: const TextStyle(
                    color: Color(0xFF5DD3E5),
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String title;
  final String description;
  final bool isSelected;
  final List<Color> colors;
  final VoidCallback onTap;

  const _ThemeOption({
    Key? key,
    required this.title,
    required this.description,
    required this.isSelected,
    required this.colors,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF2D4A5E).withOpacity(0.5)
                : const Color(0xFF0F1E2B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF5DD3E5)
                  : Colors.white.withOpacity(0.1),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Color preview
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Text info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.check_circle,
                            color: Color(0xFF5DD3E5),
                            size: 20,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
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
