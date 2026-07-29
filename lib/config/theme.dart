import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';
import 'constants.dart';

class AppTheme {
  // ╔══════════════════════════════════════════════════════════════╗
  // ║  LIGHT THEME — "Stormy Morning" Palette                    ║
  // ║                                                              ║
  // ║  #88BDF2  Sky Blue       → primary / FAB / active UI        ║
  // ║  #384959  Dark Slate     → primary text / appBar / icons    ║
  // ║  #6A89A7  Muted Blue-Grey → secondary text / borders       ║
  // ║  #BDDDFC  Light Ice Blue → highlight backgrounds           ║
  // ║  #FFFFFF / #F9FBFD       → scaffold & card backgrounds     ║
  // ╚══════════════════════════════════════════════════════════════╝
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // ── Color Scheme ──────────────────────────────────────────
      colorScheme: const ColorScheme.light(
        primary: AppColors.stormySkyBlue, // #88BDF2
        onPrimary: AppColors.textWhite, // white text on primary
        primaryContainer: AppColors.stormyIceBlue, // #BDDDFC
        onPrimaryContainer: AppColors.stormyDarkSlate, // #384959

        secondary: AppColors.stormyMutedBlueGrey, // #6A89A7
        onSecondary: AppColors.textWhite,
        secondaryContainer: AppColors.stormyIceBlue,
        onSecondaryContainer: AppColors.stormyDarkSlate,

        tertiary: AppColors.stormyDarkSlate, // #384959
        onTertiary: AppColors.textWhite,

        surface: AppColors.backgroundWhite, // #FFFFFF
        onSurface: AppColors.stormyDarkSlate, // #384959
        onSurfaceVariant: AppColors.stormyMutedBlueGrey, // #6A89A7

        outline: AppColors.stormyMutedBlueGrey, // #6A89A7
        outlineVariant: AppColors.stormyIceBlue, // #BDDDFC

        error: AppColors.error,
        onError: AppColors.textWhite,
      ),

      // ── Scaffold Background ───────────────────────────────────
      scaffoldBackgroundColor: AppColors.stormyOffWhite, // #F9FBFD
      splashColor: AppColors.stormySkyBlue.withValues(alpha: 0.1),
      highlightColor: AppColors.stormySkyBlue.withValues(alpha: 0.05),

      // ── AppBar Theme ──────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.backgroundWhite, // white / transparent
        foregroundColor: AppColors.stormyDarkSlate, // #384959
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.stormyDarkSlate),
        actionsIconTheme: IconThemeData(color: AppColors.stormyDarkSlate),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.stormyDarkSlate, // #384959
        ),
      ),

      // ── Card Theme ────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: AppColors.backgroundWhite,
        elevation: 1,
        shadowColor: AppColors.shadowLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          side: const BorderSide(
            color: AppColors.stormyMutedBlueGrey, // #6A89A7 border
            width: 0.8,
          ),
        ),
      ),

      // ── Input Decoration Theme ────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.backgroundWhite,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingMedium,
          vertical: AppConstants.paddingMedium,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          borderSide: const BorderSide(color: AppColors.stormyMutedBlueGrey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          borderSide: const BorderSide(color: AppColors.stormyMutedBlueGrey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          borderSide: const BorderSide(
            color: AppColors.stormySkyBlue, // #88BDF2 focus
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        hintStyle: const TextStyle(
          color: AppColors.stormyMutedBlueGrey, // #6A89A7
          fontSize: 14,
        ),
      ),

      // ── Elevated Button Theme ─────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          enableFeedback: false,
          backgroundColor: AppColors.stormySkyBlue, // #88BDF2
          foregroundColor: AppColors.textWhite,
          elevation: 2,
          shadowColor: AppColors.shadowMedium,
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingLarge,
            vertical: AppConstants.paddingMedium,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Text Button Theme ─────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          enableFeedback: false,
          foregroundColor: AppColors.stormySkyBlue, // #88BDF2
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Floating Action Button Theme ──────────────────────────
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        enableFeedback: false,
        backgroundColor: AppColors.stormySkyBlue, // #88BDF2
        foregroundColor: AppColors.textWhite, // white icon
        elevation: 4,
        shape: CircleBorder(),
      ),

      // ── Bottom Navigation Bar Theme ───────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        enableFeedback: false,
        backgroundColor: AppColors.backgroundWhite,
        selectedItemColor: AppColors.stormyDarkSlate, // #384959 active
        unselectedItemColor: AppColors.stormyMutedBlueGrey, // #6A89A7 inactive
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // ── Drawer Theme ──────────────────────────────────────────
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.backgroundWhite,
      ),

      // ── Dialog Theme ──────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.backgroundWhite,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.stormyDarkSlate, // #384959
        ),
        contentTextStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: AppColors.stormyMutedBlueGrey, // #6A89A7
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusXLarge),
        ),
      ),

      // ── Divider Theme ─────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.stormyIceBlue, // #BDDDFC
        thickness: 1,
        space: AppConstants.paddingMedium,
      ),

      // ── Chip Theme ────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.stormyIceBlue, // #BDDDFC highlight bg
        deleteIconColor: AppColors.stormyDarkSlate,
        labelStyle: const TextStyle(
          color: AppColors.stormyDarkSlate, // #384959
          fontSize: 12,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingSmall,
          vertical: AppConstants.paddingSmall / 2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
        ),
      ),

      // ── Text Theme ────────────────────────────────────────────
      textTheme: GoogleFonts.poppinsTextTheme().copyWith(
        displayLarge: GoogleFonts.poppins(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.stormyDarkSlate, // #384959
        ),
        displayMedium: GoogleFonts.poppins(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppColors.stormyDarkSlate,
        ),
        displaySmall: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.stormyDarkSlate,
        ),
        headlineLarge: GoogleFonts.poppins(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.stormyDarkSlate,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.stormyDarkSlate,
        ),
        titleLarge: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.stormyDarkSlate,
        ),
        titleMedium: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.stormyDarkSlate,
        ),
        titleSmall: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.stormyDarkSlate,
        ),
        bodyLarge: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: AppColors.stormyDarkSlate, // #384959
        ),
        bodyMedium: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: AppColors.stormyMutedBlueGrey, // #6A89A7
        ),
        bodySmall: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: AppColors.stormyMutedBlueGrey, // #6A89A7
        ),
      ),

      // ── Icon Theme ────────────────────────────────────────────
      iconTheme: const IconThemeData(
        color: AppColors.stormyDarkSlate, // #384959
        size: AppConstants.iconMedium,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(enableFeedback: false),
      ),

      // ── Checkbox Theme ────────────────────────────────────────
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.stormySkyBlue; // #88BDF2 when checked
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(AppColors.textWhite),
        side: const BorderSide(color: AppColors.stormyMutedBlueGrey),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      listTileTheme: const ListTileThemeData(enableFeedback: false),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryPink,
        secondary: AppColors.primaryPurple,
        tertiary: AppColors.primaryBlue,
        surface: AppColors.stormyDarkSlate,
        error: AppColors.error,
        onPrimary: AppColors.textWhite,
        onSecondary: AppColors.textWhite,
        onSurface: AppColors.textWhite,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.stormySkyBlue,
        selectionColor: AppColors.stormySkyBlue.withValues(alpha: 0.3),
        selectionHandleColor: AppColors.stormySkyBlue,
      ),
      scaffoldBackgroundColor: AppColors.stormyNightBackground,
      cardColor: AppColors.stormyDarkSlate,
      splashColor: AppColors.stormySkyBlue.withValues(alpha: 0.1),
      highlightColor: AppColors.stormySkyBlue.withValues(alpha: 0.05),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.stormyDarkSlate, // #384959
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingMedium,
          vertical: AppConstants.paddingMedium,
        ),
        hintStyle: const TextStyle(
          color: AppColors.stormyMutedBlueGrey,
        ), // #6A89A7
        labelStyle: TextStyle(
          color: AppColors.textWhite.withValues(alpha: 0.7),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          borderSide: const BorderSide(
            color: AppColors.stormySkyBlue, // #88BDF2
            width: 2,
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.stormyNightBackground,
        foregroundColor: AppColors.textWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textWhite,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.stormyMutedBlueGrey,
        contentTextStyle: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        behavior: SnackBarBehavior.fixed,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        enableFeedback: false,
        backgroundColor: AppColors.primaryPink,
        foregroundColor: AppColors.textWhite,
        elevation: 4,
        shape: CircleBorder(),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        enableFeedback: false,
        backgroundColor: Color(0xFF121212),
        selectedItemColor: AppColors.primaryPink,
        unselectedItemColor: AppColors.textLight,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF121212),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.stormyDarkSlate,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.stormyDarkSlate,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.textWhite,
        ),
        contentTextStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: AppColors.textWhite.withValues(alpha: 0.82),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusXLarge),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          enableFeedback: false,
          backgroundColor: AppColors.primaryPink,
          foregroundColor: AppColors.textWhite,
          elevation: 2,
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingLarge,
            vertical: AppConstants.paddingMedium,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          enableFeedback: false,
          foregroundColor: AppColors.primaryPink,
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(enableFeedback: false),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: const Color(0xFF181818),
        headerBackgroundColor: AppColors.stormyDarkSlate,
        headerForegroundColor: Colors.white,
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.stormySkyBlue;
          }
          return null;
        }),
        dayOverlayColor: WidgetStateProperty.all(
          AppColors.stormySkyBlue.withValues(alpha: 0.2),
        ),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.stormyNightBackground;
          }
          return Colors.white;
        }),
        dayStyle: GoogleFonts.poppins(),
        yearStyle: GoogleFonts.poppins(),
        yearForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.stormyNightBackground;
          }
          return Colors.white;
        }),
        yearOverlayColor: WidgetStateProperty.all(
          AppColors.stormySkyBlue.withValues(alpha: 0.2),
        ),
        todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.stormySkyBlue;
          }
          return null;
        }),
        todayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.stormyNightBackground;
          }
          return AppColors.stormySkyBlue;
        }),
        todayBorder: const BorderSide(color: AppColors.stormySkyBlue),
        cancelButtonStyle: TextButton.styleFrom(
          foregroundColor: AppColors.stormyMutedBlueGrey,
        ),
        confirmButtonStyle: TextButton.styleFrom(
          foregroundColor: AppColors.stormySkyBlue,
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: const Color(0xFF181818),
        hourMinuteColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.stormySkyBlue
              : AppColors.stormyDarkSlate,
        ),
        hourMinuteTextColor: WidgetStateColor.resolveWith(
          (states) => Colors.white,
        ),
        dialHandColor: AppColors.stormySkyBlue,
        dialBackgroundColor: AppColors.stormyDarkSlate,
        dialTextColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.stormyNightBackground
              : Colors.white,
        ),
        entryModeIconColor: AppColors.stormyMutedBlueGrey,
        helpTextStyle: GoogleFonts.poppins(color: Colors.white),
        cancelButtonStyle: TextButton.styleFrom(
          foregroundColor: AppColors.stormyMutedBlueGrey,
        ),
        confirmButtonStyle: TextButton.styleFrom(
          foregroundColor: AppColors.stormySkyBlue,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.stormySkyBlue, width: 2),
          ),
        ),
      ),
      textTheme: GoogleFonts.poppinsTextTheme().copyWith(
        displayLarge: GoogleFonts.poppins(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.textWhite,
        ),
        displayMedium: GoogleFonts.poppins(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppColors.textWhite,
        ),
        displaySmall: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.textWhite,
        ),
        headlineLarge: GoogleFonts.poppins(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.textWhite,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textWhite,
        ),
        titleLarge: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textWhite,
        ),
        titleMedium: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textWhite,
        ),
        titleSmall: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textWhite,
        ),
        bodyLarge: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: AppColors.textWhite,
        ),
        bodyMedium: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: AppColors.textWhite.withValues(alpha: 0.82),
        ),
        bodySmall: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: AppColors.textWhite.withValues(alpha: 0.68),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.stormySkyBlue;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(AppColors.textWhite),
        side: const BorderSide(color: AppColors.stormyMutedBlueGrey),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      listTileTheme: const ListTileThemeData(enableFeedback: false),
    );
  }
}
