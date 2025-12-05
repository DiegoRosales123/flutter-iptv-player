import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider para gestionar el tema de la aplicación
class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'app_theme';

  AppThemeType _currentTheme = AppThemeType.original;

  AppThemeType get currentTheme => _currentTheme;

  ThemeProvider() {
    _loadTheme();
  }

  /// Cargar tema guardado
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString(_themeKey) ?? 'original';
    _currentTheme = AppThemeType.values.firstWhere(
      (t) => t.name == themeName,
      orElse: () => AppThemeType.original,
    );
    notifyListeners();
  }

  /// Cambiar tema
  Future<void> setTheme(AppThemeType theme) async {
    _currentTheme = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, theme.name);
    notifyListeners();
  }

  /// Alternar entre temas
  Future<void> toggleTheme() async {
    final nextTheme = _currentTheme == AppThemeType.original
        ? AppThemeType.netflix
        : AppThemeType.original;
    await setTheme(nextTheme);
  }
}

/// Tipos de temas disponibles
enum AppThemeType {
  original,
  netflix,
}

/// Extensión para obtener colores según el tema
extension AppThemeTypeExtension on AppThemeType {
  String get displayName {
    switch (this) {
      case AppThemeType.original:
        return 'Original';
      case AppThemeType.netflix:
        return 'Netflix Dark';
    }
  }

  // Colores principales
  Color get backgroundPrimary {
    switch (this) {
      case AppThemeType.original:
        return const Color(0xFF0B1A2A);
      case AppThemeType.netflix:
        return const Color(0xFF141414);
    }
  }

  Color get backgroundSecondary {
    switch (this) {
      case AppThemeType.original:
        return const Color(0xFF0F2438);
      case AppThemeType.netflix:
        return const Color(0xFF1A1A1A);
    }
  }

  Color get backgroundTertiary {
    switch (this) {
      case AppThemeType.original:
        return const Color(0xFF0F1E2B);
      case AppThemeType.netflix:
        return const Color(0xFF2D2D2D);
    }
  }

  Color get sidebarBackground {
    switch (this) {
      case AppThemeType.original:
        return const Color(0xFF1A2B3C);
      case AppThemeType.netflix:
        return const Color(0xFF1A1A1A);
    }
  }

  Color get cardBackground {
    switch (this) {
      case AppThemeType.original:
        return const Color(0xFF1A3A52);
      case AppThemeType.netflix:
        return const Color(0xFF2D2D2D);
    }
  }

  Color get cardBackgroundLight {
    switch (this) {
      case AppThemeType.original:
        return const Color(0xFF2D4A5E);
      case AppThemeType.netflix:
        return const Color(0xFF3D3D3D);
    }
  }

  Color get borderPrimary {
    switch (this) {
      case AppThemeType.original:
        return const Color(0xFF2D5F8D);
      case AppThemeType.netflix:
        return const Color(0xFF404040);
    }
  }

  Color get accentPrimary {
    switch (this) {
      case AppThemeType.original:
        return const Color(0xFF5DD3E5);
      case AppThemeType.netflix:
        return const Color(0xFFE50914);
    }
  }

  Color get accentSecondary {
    switch (this) {
      case AppThemeType.original:
        return const Color(0xFFE50914);
      case AppThemeType.netflix:
        return const Color(0xFFE50914);
    }
  }
}
