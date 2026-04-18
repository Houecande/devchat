import 'package:flutter/material.dart';

class AppTheme {
  // Couleur par défaut pour les widgets qui ne peuvent pas utiliser le contexte
  static const Color primary = Color(0xFF818CF8); 
  static const Color background = Color(0xFF111111);
  static const Color surface = Color(0xFF181818); 
  static const Color surfaceVariant = Color(0xFF242424);
  static const Color textPrimary = Color(0xFFF3F4F6);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color codeBackground = Color(0xFF0D1117);
  static const Color success = Color(0xFF34D399);
  static const Color error = Color(0xFFF87171);

  static ThemeData dynamicTheme(Color primaryColor, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bgColor = isDark ? background : Colors.grey[50]!;
    final surfColor = isDark ? surface : Colors.white;
    final surfVarColor = isDark ? surfaceVariant : Colors.grey[200]!;
    final txtPrimary = isDark ? textPrimary : Colors.black87;
    final txtSecondary = isDark ? textSecondary : Colors.black54;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bgColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        brightness: brightness,
        surface: surfColor,
        error: error,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfVarColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
        labelStyle: TextStyle(color: txtSecondary, fontSize: 14),
        prefixIconColor: txtSecondary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(color: txtPrimary, fontSize: 18, fontWeight: FontWeight.w600),
      ),
    );
  }

  static ThemeData get dark => dynamicTheme(primary, Brightness.dark);
}
