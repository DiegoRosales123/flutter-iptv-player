import 'package:flutter/material.dart';

/// App theme colors and constants
/// Este archivo centraliza todos los colores y estilos de la aplicación
class AppTheme {
  // Colores principales del tema oscuro azul (Original)
  static const Color backgroundPrimary = Color(0xFF0B1A2A);
  static const Color backgroundSecondary = Color(0xFF0F2438);
  static const Color backgroundTertiary = Color(0xFF0F1E2B);

  // Colores de sidebar y cards
  static const Color sidebarBackground = Color(0xFF1A2B3C);
  static const Color cardBackground = Color(0xFF1A3A52);
  static const Color cardBackgroundLight = Color(0xFF2D4A5E);

  // Colores de borde
  static const Color borderPrimary = Color(0xFF2D5F8D);
  static const Color borderLight = Color(0xFF1E3A5F);

  // Colores de acento
  static const Color accentCyan = Color(0xFF5DD3E5);
  static const Color accentRed = Color(0xFFE50914);
  static const Color accentGreen = Color(0xFF4CAF50);
  static const Color accentOrange = Color(0xFFFF9800);
  static const Color accentAmber = Color(0xFFFFC107);

  // Colores de rating (iguales para todos los temas)
  static const Color ratingExcellent = Color(0xFF4CAF50);
  static const Color ratingVeryGood = Color(0xFF8BC34A);
  static const Color ratingGood = Color(0xFFFFC107);
  static const Color ratingFair = Color(0xFFFF9800);
  static const Color ratingPoor = Color(0xFFF44336);

  // Obtener color según rating
  static Color getRatingColor(double rating) {
    if (rating >= 8.0) {
      return ratingExcellent;
    } else if (rating >= 7.0) {
      return ratingVeryGood;
    } else if (rating >= 6.0) {
      return ratingGood;
    } else if (rating >= 5.0) {
      return ratingFair;
    } else {
      return ratingPoor;
    }
  }

  // Gradientes comunes
  static LinearGradient get backgroundGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      backgroundSecondary,
      backgroundPrimary,
    ],
  );

  static LinearGradient get cardGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      cardBackground.withOpacity(0.6),
      backgroundTertiary.withOpacity(0.4),
    ],
  );

  static LinearGradient get sidebarGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      sidebarBackground,
      backgroundTertiary,
    ],
  );

  // Box decorations comunes
  static BoxDecoration get cardDecoration => BoxDecoration(
    gradient: cardGradient,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: borderPrimary.withOpacity(0.3),
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: cardBackground.withOpacity(0.2),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ],
  );

  static BoxDecoration sidebarDecoration({bool showRightBorder = true}) => BoxDecoration(
    color: sidebarBackground,
    border: showRightBorder ? Border(
      right: BorderSide(
        color: Colors.white.withOpacity(0.1),
        width: 1,
      ),
    ) : null,
  );

  // Text styles
  static const TextStyle titleLarge = TextStyle(
    color: Colors.white,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
  );

  static const TextStyle titleMedium = TextStyle(
    color: Colors.white,
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle titleSmall = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle bodyMedium = TextStyle(
    color: Colors.white,
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  static TextStyle bodyMediumSecondary = TextStyle(
    color: Colors.white.withOpacity(0.7),
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle labelSmall = TextStyle(
    color: Colors.white,
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  // Input decoration
  static InputDecoration searchInputDecoration({String hintText = 'Search'}) => InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
    prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.5)),
    filled: true,
    fillColor: backgroundTertiary,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(25),
      borderSide: BorderSide.none,
    ),
  );

  // Button styles
  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: accentCyan,
    foregroundColor: Colors.black,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  );

  static ButtonStyle get secondaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: cardBackgroundLight.withOpacity(0.8),
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  );
}
