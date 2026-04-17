import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

/// Builds the light [ThemeData] used by DriveLink.
///
/// Mirrors the dark theme's structure and component styling, but uses the
/// light palette via [AppColors]. Accent/foreground handling is inverted
/// for proper contrast in daylight use.
ThemeData buildLightTheme({Color accentColor = AppColors.defaultPrimary}) {
  final accentGlow = Color.lerp(accentColor, Colors.white, 0.35)!;
  final accentDeep = Color.lerp(accentColor, Colors.black, 0.25)!;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: accentColor,
    brightness: Brightness.light,
    surface: AppColors.surface,
    primary: accentColor,
    secondary: AppColors.accent,
    error: AppColors.error,
  );

  final baseText = GoogleFonts.jetBrainsMonoTextTheme(
    ThemeData(brightness: Brightness.light).textTheme,
  );

  final textTheme = baseText.copyWith(
    headlineLarge: baseText.headlineLarge?.copyWith(
      color: AppColors.textPrimary,
      fontSize: 32,
      fontWeight: FontWeight.bold,
      letterSpacing: -0.5,
    ),
    headlineMedium: baseText.headlineMedium?.copyWith(
      color: AppColors.textPrimary,
      fontSize: 24,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.25,
    ),
    titleLarge: baseText.titleLarge?.copyWith(
      color: AppColors.textPrimary,
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: baseText.titleMedium?.copyWith(
      color: AppColors.textPrimary,
      fontSize: 16,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
    ),
    titleSmall: baseText.titleSmall?.copyWith(
      color: AppColors.textSecondary,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    bodyLarge: baseText.bodyLarge?.copyWith(
      color: AppColors.textPrimary,
      fontSize: 16,
      height: 1.5,
    ),
    bodyMedium: baseText.bodyMedium?.copyWith(
      color: AppColors.textSecondary,
      fontSize: 14,
      height: 1.5,
    ),
    bodySmall: baseText.bodySmall?.copyWith(
      color: AppColors.textDisabled,
      fontSize: 12,
    ),
    labelLarge: baseText.labelLarge?.copyWith(
      color: AppColors.textPrimary,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
    labelMedium: baseText.labelMedium?.copyWith(
      color: AppColors.textSecondary,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.4,
    ),
    labelSmall: baseText.labelSmall?.copyWith(
      color: AppColors.textDisabled,
      fontSize: 11,
      fontWeight: FontWeight.w500,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
    textTheme: textTheme,

    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleTextStyle: GoogleFonts.jetBrainsMono(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.25,
      ),
      shape: Border(
        bottom: BorderSide(color: accentColor.withAlpha(32), width: 0.5),
      ),
    ),

    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border.withAlpha(80)),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: accentColor,
      unselectedItemColor: AppColors.textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      elevation: 0,
      height: 68,
      indicatorColor: accentColor.withAlpha(28),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return GoogleFonts.jetBrainsMono(
          fontSize: 11,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? accentColor : AppColors.textDisabled,
          letterSpacing: 0.3,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? accentColor : AppColors.textSecondary,
          size: selected ? 24 : 22,
        );
      }),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.jetBrainsMono(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: accentColor,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        side: BorderSide(color: accentColor.withAlpha(120)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: accentColor),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: accentColor,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    iconTheme: IconThemeData(color: AppColors.textPrimary, size: 24),

    dividerTheme: DividerThemeData(
      color: AppColors.divider.withAlpha(180),
      thickness: 0.5,
      space: 0.5,
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      modalBackgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      showDragHandle: true,
      dragHandleColor: AppColors.surfaceBright,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceBright,
      contentTextStyle: GoogleFonts.jetBrainsMono(
        color: AppColors.textPrimary,
        fontSize: 14,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
    ),

    inputDecorationTheme: InputDecorationTheme(
      fillColor: AppColors.surfaceVariant,
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border.withAlpha(80)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accentColor, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),

    sliderTheme: SliderThemeData(
      activeTrackColor: accentColor,
      inactiveTrackColor: AppColors.surfaceVariant,
      thumbColor: accentColor,
      overlayColor: accentColor.withAlpha(30),
      trackHeight: 3,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
    ),

    tabBarTheme: TabBarThemeData(
      indicatorColor: accentColor,
      labelColor: accentColor,
      unselectedLabelColor: AppColors.textSecondary,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: accentColor.withAlpha(24),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: accentColor,
      circularTrackColor: AppColors.surfaceVariant,
    ),

    listTileTheme: ListTileThemeData(
      iconColor: AppColors.textSecondary,
      textColor: AppColors.textPrimary,
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return accentColor;
        return AppColors.textDisabled;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return accentGlow.withAlpha(110);
        }
        return AppColors.surfaceVariant;
      }),
    ),

    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.surfaceBright,
        border: Border.all(color: accentColor.withAlpha(40), width: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      shadowColor: accentDeep.withAlpha(40),
    ),
  );
}
