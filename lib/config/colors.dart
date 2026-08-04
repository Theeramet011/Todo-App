import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors (Legacy — ยังใช้ใน Dark Mode)
  static const Color primaryPink = Color(0xFFFF6B8A);
  static const Color primaryPurple = Color(0xFF9B5DE5);
  static const Color primaryBlue = Color(0xFF3ABEF9);
  static const Color primaryGreen = Color(0xFF00D9A5);

  // ── Stormy Morning Palette (Light Mode) ──────────────────────
  /// #88BDF2 — Primary / FAB / Active UI elements
  static const Color stormySkyBlue = Color(0xFF88BDF2);

  /// #3877EE — Deep Royal Blue for Level Progress Bar in Light Mode
  static const Color stormyDeepBlue = Color(0xFF3877EE);

  /// #384959 — Primary Text / AppBar Text / Active Icons
  static const Color stormyDarkSlate = Color(0xFF384959);

  /// #6A89A7 — Secondary Text / Unselected Icons / Card Borders
  static const Color stormyMutedBlueGrey = Color(0xFF6A89A7);

  /// #BDDDFC — Highlight Backgrounds (Chips, Selected BottomNav Pill)
  static const Color stormyIceBlue = Color(0xFFBDDDFC);

  /// Very subtle off-white for scaffold / card backgrounds
  static const Color stormyOffWhite = Color(0xFFF9FBFD);

  // ── Stormy Night Palette (Dark Mode) ──────────────────────
  /// #1A2530 — Background for Scaffold in Dark Mode
  static const Color stormyNightBackground = Color(0xFF1A2530);

  // Accent Colors
  static const Color accentOrange = Color(0xFFFFB347);
  static const Color accentRed = Color(0xFFFF6B6B);
  static const Color accentYellow = Color(0xFFFFE66D);

  // Background Colors
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  static const Color backgroundLightGrey = Color(0xFFF8F9FA);
  static const Color backgroundGrey = Color(0xFFF0F2F5);
  static const Color backgroundDarkGrey = Color(0xFFE9ECEF);

  // Text Colors
  static const Color textPrimary = Color(0xFF2D3436);
  static const Color textSecondary = Color(0xFF636E72);
  static const Color textLight = Color(0xFFB2BEC3);
  static const Color textWhite = Color(0xFFFFFFFF);

  // Status Colors
  static const Color success = Color(0xFF00D9A5);
  static const Color warning = Color(0xFFFFB347);
  static const Color error = Color(0xFFFF6B6B);
  static const Color info = Color(0xFF3ABEF9);

  // Task Colors
  static const Color taskPink = Color(0xFFFFE0E6);
  static const Color taskPurple = Color(0xFFEBD6F9);
  static const Color taskBlue = Color(0xFFD4F0FA);
  static const Color taskGreen = Color(0xFFD4F9ED);

  // Shadow Colors
  static const Color shadowLight = Color(0x1A000000);
  static const Color shadowMedium = Color(0x26000000);

  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryPink, primaryPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [backgroundWhite, backgroundLightGrey],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
