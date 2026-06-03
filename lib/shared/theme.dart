import 'package:flutter/material.dart';

class AppTheme {
  // ── Palette ──────────────────────────────────────────────────────────────
  static const Color bg        = Color(0xFF080808);
  static const Color surface   = Color(0xFF111111);
  static const Color card      = Color(0xFF1A1A1A);
  static const Color border    = Color(0xFF2A2A2A);

  static const Color accent    = Color(0xFFE8001C); // Ferrari red
  static const Color orange    = Color(0xFFFF6D00);
  static const Color green     = Color(0xFF00C853);
  static const Color blue      = Color(0xFF2979FF);

  static const Color textPri   = Color(0xFFFFFFFF);
  static const Color textSec   = Color(0xFF888888);
  static const Color textDim   = Color(0xFF444444);

  // ── Theme ─────────────────────────────────────────────────────────────────
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: const ColorScheme.dark(
      primary: accent,
      secondary: orange,
      surface: surface,
      onPrimary: textPri,
      onSurface: textPri,
    ),
    textTheme: const TextTheme(
      // Used for big numeric readouts
      displayLarge: TextStyle(
        fontFamily: 'monospace',
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: textPri,
        letterSpacing: -1,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'monospace',
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: textPri,
        letterSpacing: 3,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        color: textSec,
        letterSpacing: 0.5,
      ),
      labelSmall: TextStyle(
        fontFamily: 'monospace',
        fontSize: 10,
        color: textDim,
        letterSpacing: 2,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card,
      hintStyle: const TextStyle(color: textDim, fontFamily: 'monospace'),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: accent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(
          fontFamily: 'monospace',
          fontWeight: FontWeight.w800,
          letterSpacing: 2.5,
          fontSize: 13,
        ),
      ),
    ),
  );
}
