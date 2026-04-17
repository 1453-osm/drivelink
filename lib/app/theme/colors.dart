import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Internal immutable palette holder.
@immutable
class _Palette {
  const _Palette({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.surfaceBright,
    required this.primary,
    required this.primaryVariant,
    required this.accent,
    required this.accentVariant,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.gaugeNormal,
    required this.gaugeWarning,
    required this.gaugeDanger,
    required this.gaugeSweep,
    required this.gaugeTrack,
    required this.divider,
    required this.border,
  });

  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color surfaceBright;
  final Color primary;
  final Color primaryVariant;
  final Color accent;
  final Color accentVariant;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color gaugeNormal;
  final Color gaugeWarning;
  final Color gaugeDanger;
  final Color gaugeSweep;
  final Color gaugeTrack;
  final Color divider;
  final Color border;
}

// ─── Palettes ──────────────────────────────────────────────────────────

const _Palette _darkPalette = _Palette(
  background: Color(0xFF060A12),
  surface: Color(0xFF0C1220),
  surfaceVariant: Color(0xFF141C2E),
  surfaceBright: Color(0xFF1E2940),
  primary: Color(0xFF00D4FF),
  primaryVariant: Color(0xFF0088AA),
  accent: Color(0xFFFF6B35),
  accentVariant: Color(0xFFE55A2B),
  success: Color(0xFF00E676),
  warning: Color(0xFFFFAB40),
  error: Color(0xFFFF3D71),
  info: Color(0xFF40C4FF),
  textPrimary: Color(0xFFF0F4FA),
  textSecondary: Color(0xFF6B7D99),
  textDisabled: Color(0xFF3A4A60),
  gaugeNormal: Color(0xFF00E676),
  gaugeWarning: Color(0xFFFFD740),
  gaugeDanger: Color(0xFFFF3D71),
  gaugeSweep: Color(0xFF00D4FF),
  gaugeTrack: Color(0xFF0E1726),
  divider: Color(0xFF141C2E),
  border: Color(0xFF1A2844),
);

const _Palette _lightPalette = _Palette(
  background: Color(0xFFF4F6FB),
  surface: Color(0xFFFFFFFF),
  surfaceVariant: Color(0xFFEAEEF5),
  surfaceBright: Color(0xFFDCE3EE),
  primary: Color(0xFF0088AA),
  primaryVariant: Color(0xFF006680),
  accent: Color(0xFFE5531F),
  accentVariant: Color(0xFFC04314),
  success: Color(0xFF0E9F52),
  warning: Color(0xFFC77700),
  error: Color(0xFFD32F4E),
  info: Color(0xFF0077B3),
  textPrimary: Color(0xFF101828),
  textSecondary: Color(0xFF556377),
  textDisabled: Color(0xFFA3ADBD),
  gaugeNormal: Color(0xFF0E9F52),
  gaugeWarning: Color(0xFFD8900B),
  gaugeDanger: Color(0xFFD32F4E),
  gaugeSweep: Color(0xFF0088AA),
  gaugeTrack: Color(0xFFDCE3EE),
  divider: Color(0xFFD7DDE7),
  border: Color(0xFFC7CEDB),
);

/// DriveLink color palette — electric automotive theme.
///
/// Fields are runtime getters that read the active mode palette. Call
/// [setBrightness] when the theme mode changes (from the root widget).
abstract final class AppColors {
  static _Palette _active = _darkPalette;

  /// Current active brightness. Widgets can listen to trigger rebuilds.
  static final ValueNotifier<Brightness> brightnessListenable =
      ValueNotifier<Brightness>(Brightness.dark);

  static Brightness get brightness => brightnessListenable.value;
  static bool get isLight => brightness == Brightness.light;
  static bool get isDark => brightness == Brightness.dark;

  /// Switch the active palette. Idempotent.
  static void setBrightness(Brightness value) {
    if (brightnessListenable.value == value) return;
    _active = value == Brightness.dark ? _darkPalette : _lightPalette;
    brightnessListenable.value = value;
  }

  // ── Backgrounds ──────────────────────────────────────────────────────
  static Color get background => _active.background;
  static Color get surface => _active.surface;
  static Color get surfaceVariant => _active.surfaceVariant;
  static Color get surfaceBright => _active.surfaceBright;

  // ── Brand ────────────────────────────────────────────────────────────
  static Color get primary => _active.primary;
  static Color get primaryVariant => _active.primaryVariant;
  static Color get accent => _active.accent;
  static Color get accentVariant => _active.accentVariant;

  // ── Semantic ─────────────────────────────────────────────────────────
  static Color get success => _active.success;
  static Color get warning => _active.warning;
  static Color get error => _active.error;
  static Color get info => _active.info;

  // ── Text ─────────────────────────────────────────────────────────────
  static Color get textPrimary => _active.textPrimary;
  static Color get textSecondary => _active.textSecondary;
  static Color get textDisabled => _active.textDisabled;

  // ── Gauge / OBD ──────────────────────────────────────────────────────
  static Color get gaugeNormal => _active.gaugeNormal;
  static Color get gaugeWarning => _active.gaugeWarning;
  static Color get gaugeDanger => _active.gaugeDanger;
  static Color get gaugeSweep => _active.gaugeSweep;
  static Color get gaugeTrack => _active.gaugeTrack;

  // ── Divider / Border ─────────────────────────────────────────────────
  static Color get divider => _active.divider;
  static Color get border => _active.border;

  /// The fixed default primary (electric cyan), regardless of theme mode —
  /// used as the baseline before any user accent override is applied.
  static const Color defaultPrimary = Color(0xFF00D4FF);
}
