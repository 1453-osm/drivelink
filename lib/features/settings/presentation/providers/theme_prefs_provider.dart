import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/core/database/settings_repository.dart';

class ThemePrefs {
  const ThemePrefs({
    this.brightness = 1.0,
    this.accentColor = AppColors.defaultPrimary,
    this.mode = ThemeMode.dark,
  });

  final double brightness;
  final Color accentColor;
  final ThemeMode mode;

  ThemePrefs copyWith({
    double? brightness,
    Color? accentColor,
    ThemeMode? mode,
  }) {
    return ThemePrefs(
      brightness: brightness ?? this.brightness,
      accentColor: accentColor ?? this.accentColor,
      mode: mode ?? this.mode,
    );
  }
}

const _kThemeBrightness = 'theme_brightness';

ThemeMode _parseMode(String? raw) => switch (raw) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };

String _modeString(ThemeMode mode) => switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
      ThemeMode.dark => 'dark',
    };

final themePrefsProvider =
    AsyncNotifierProvider<ThemePrefsNotifier, ThemePrefs>(
  ThemePrefsNotifier.new,
);

class ThemePrefsNotifier extends AsyncNotifier<ThemePrefs> {
  @override
  Future<ThemePrefs> build() async {
    final repo = ref.read(settingsRepositoryProvider);

    final brightnessStr = await repo.get(_kThemeBrightness);
    final colorStr = await repo.get(SettingsKeys.themeAccentColor);
    final modeStr = await repo.get(SettingsKeys.themeMode);

    return ThemePrefs(
      brightness: brightnessStr != null
          ? double.tryParse(brightnessStr) ?? 1.0
          : 1.0,
      accentColor: colorStr != null
          ? Color(int.tryParse(colorStr) ?? AppColors.defaultPrimary.value)
          : AppColors.defaultPrimary,
      mode: _parseMode(modeStr),
    );
  }

  Future<void> setBrightness(double value) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.set(_kThemeBrightness, value.toString());
    final prev = state.valueOrNull ?? const ThemePrefs();
    state = AsyncData(prev.copyWith(brightness: value));
  }

  void previewAccentColor(Color color) {
    final prev = state.valueOrNull ?? const ThemePrefs();
    state = AsyncData(prev.copyWith(accentColor: color));
  }

  Future<void> setAccentColor(Color color) async {
    previewAccentColor(color);
    final repo = ref.read(settingsRepositoryProvider);
    await repo.set(SettingsKeys.themeAccentColor, color.value.toString());
  }

  Future<void> setMode(ThemeMode mode) async {
    final prev = state.valueOrNull ?? const ThemePrefs();
    state = AsyncData(prev.copyWith(mode: mode));
    final repo = ref.read(settingsRepositoryProvider);
    await repo.set(SettingsKeys.themeMode, _modeString(mode));
  }
}
