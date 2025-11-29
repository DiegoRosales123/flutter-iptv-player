import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/language_service.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.language,
                  size: 32,
                  color: Colors.blue,
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Select Language / Seleccionar Idioma',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Language options
            ...languageService.availableLanguages.map((lang) {
              final bool isSelected = languageService.currentLocale.languageCode == lang['code'];

              return InkWell(
                onTap: () {
                  languageService.changeLanguage(lang['code']!);
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.grey.withOpacity(0.3),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(
                        lang['flag']!,
                        style: const TextStyle(fontSize: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang['name']!,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.blue : null,
                              ),
                            ),
                            Text(
                              lang['code']!.toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle,
                          color: Colors.blue,
                          size: 28,
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
