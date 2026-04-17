import 'package:flutter/material.dart';

import 'colors.dart';
import 'dark_theme.dart';
import 'light_theme.dart';

/// Central access point for all DriveLink themes.
abstract final class AppTheme {
  static ThemeData dark({Color accentColor = AppColors.defaultPrimary}) {
    return buildDarkTheme(accentColor: accentColor);
  }

  static ThemeData light({Color accentColor = AppColors.defaultPrimary}) {
    return buildLightTheme(accentColor: accentColor);
  }
}
