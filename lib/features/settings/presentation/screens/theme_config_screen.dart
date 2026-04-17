import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/features/settings/presentation/providers/theme_prefs_provider.dart';
import 'package:drivelink/features/settings/presentation/widgets/rgb_color_wheel.dart';
import 'package:drivelink/shared/widgets/glass_panel.dart';

class ThemeConfigScreen extends ConsumerWidget {
  const ThemeConfigScreen({super.key});

  static const _defaultAccent = AppColors.defaultPrimary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs =
        ref.watch(themePrefsProvider).valueOrNull ?? const ThemePrefs();
    final notifier = ref.read(themePrefsProvider.notifier);
    final selectedColor = prefs.accentColor;
    final isDefault = selectedColor.value == _defaultAccent.value;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Tema')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth = constraints.maxWidth > 1120
              ? 1120.0
              : constraints.maxWidth;

          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: contentWidth,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: LayoutBuilder(
                  builder: (context, innerConstraints) {
                    final isWide = innerConstraints.maxWidth >= 920;
                    final panelWidth = isWide
                        ? (innerConstraints.maxWidth - 16) / 2
                        : innerConstraints.maxWidth;
                    final wheelSize = isWide ? 212.0 : 196.0;

                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: panelWidth,
                          child: Column(
                            children: [
                              _ThemeModeCard(
                                mode: prefs.mode,
                                onChanged: notifier.setMode,
                                accent: selectedColor,
                              ),
                              const SizedBox(height: 16),
                              _buildSummaryCard(
                                context,
                                selectedColor,
                                isDefault,
                                onReset: isDefault
                                    ? null
                                    : () => notifier.setAccentColor(
                                        _defaultAccent,
                                      ),
                              ),
                              const SizedBox(height: 16),
                              _buildWheelCard(
                                selectedColor,
                                notifier,
                                wheelSize,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: panelWidth,
                          child: Column(
                            children: [
                              _RgbSliderSection(
                                color: selectedColor,
                                onPreview: notifier.previewAccentColor,
                                onCommit: (color) {
                                  notifier.setAccentColor(color);
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildPreviewCard(selectedColor),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    Color selectedColor,
    bool isDefault, {
    VoidCallback? onReset,
  }) {
    return GlassPanel(
      borderRadius: 24,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      glowColor: selectedColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Color.lerp(selectedColor, Colors.white, 0.22)!,
                      selectedColor,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: selectedColor.withAlpha(90),
                      blurRadius: 22,
                      spreadRadius: -4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Renk Profili',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Sectiginiz vurgu rengi tum arayuzde aninda kullanilir.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ValueChip(label: 'HEX', value: _hex(selectedColor)),
              _ValueChip(label: 'RGB', value: _rgbLabel(selectedColor)),
              _ValueChip(
                label: 'Durum',
                value: isDefault ? 'Varsayilan' : 'Ozel',
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Ana Renge Sifirla'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWheelCard(
    Color selectedColor,
    ThemePrefsNotifier notifier,
    double wheelSize,
  ) {
    return GlassPanel(
      borderRadius: 24,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      glowColor: selectedColor,
      child: Column(
        children: [
          Text(
            'RGB Renk Tekerlegi',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ton secin, sonra RGB kaydiricilarla ince ayar verin.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          RgbColorWheel(
            color: selectedColor,
            size: wheelSize,
            ringWidth: wheelSize < 200 ? 20 : 22,
            onChanged: notifier.previewAccentColor,
            onChangeEnd: (color) {
              notifier.setAccentColor(color);
            },
          ),
          const SizedBox(height: 18),
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: selectedColor,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withAlpha(34), width: 1),
              boxShadow: [
                BoxShadow(
                  color: selectedColor.withAlpha(120),
                  blurRadius: 26,
                  spreadRadius: -6,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard(Color selectedColor) {
    return GlassPanel(
      borderRadius: 24,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      glowColor: selectedColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Canli Onizleme',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selectedColor.withAlpha(55),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: [
                        Color.lerp(selectedColor, Colors.white, 0.2)!,
                        selectedColor,
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.equalizer_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DriveLink Arayuzu',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Butonlar, cubuklar ve aktif durumlar bu renk ile vurgulanir.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: Icon(Icons.tune_rounded, color: selectedColor),
                  label: Text(
                    'Ikincil',
                    style: TextStyle(color: selectedColor),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Birincil'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _hex(Color color) {
    final value = color.value.toRadixString(16).padLeft(8, '0').toUpperCase();
    return '#${value.substring(2)}';
  }

  static String _rgbLabel(Color color) {
    return '${color.red}, ${color.green}, ${color.blue}';
  }
}

class _RgbSliderSection extends StatelessWidget {
  const _RgbSliderSection({
    required this.color,
    required this.onPreview,
    required this.onCommit,
  });

  final Color color;
  final ValueChanged<Color> onPreview;
  final ValueChanged<Color> onCommit;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      borderRadius: 24,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      glowColor: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RGB Ince Ayar',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          _RgbSlider(
            label: 'Kirmizi',
            value: color.red,
            tint: const Color(0xFFFF5B5B),
            onChanged: (value) => onPreview(
              Color.fromARGB(color.alpha, value, color.green, color.blue),
            ),
            onChangeEnd: (value) => onCommit(
              Color.fromARGB(color.alpha, value, color.green, color.blue),
            ),
          ),
          const SizedBox(height: 12),
          _RgbSlider(
            label: 'Yesil',
            value: color.green,
            tint: const Color(0xFF4ADE80),
            onChanged: (value) => onPreview(
              Color.fromARGB(color.alpha, color.red, value, color.blue),
            ),
            onChangeEnd: (value) => onCommit(
              Color.fromARGB(color.alpha, color.red, value, color.blue),
            ),
          ),
          const SizedBox(height: 12),
          _RgbSlider(
            label: 'Mavi',
            value: color.blue,
            tint: const Color(0xFF60A5FA),
            onChanged: (value) => onPreview(
              Color.fromARGB(color.alpha, color.red, color.green, value),
            ),
            onChangeEnd: (value) => onCommit(
              Color.fromARGB(color.alpha, color.red, color.green, value),
            ),
          ),
        ],
      ),
    );
  }
}

class _RgbSlider extends StatelessWidget {
  const _RgbSlider({
    required this.label,
    required this.value,
    required this.tint,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final String label;
  final int value;
  final Color tint;
  final ValueChanged<int> onChanged;
  final ValueChanged<int> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '$value',
              style: TextStyle(
                color: tint,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: tint,
            thumbColor: tint,
            overlayColor: tint.withAlpha(30),
          ),
          child: Slider(
            min: 0,
            max: 255,
            value: value.toDouble(),
            onChanged: (next) => onChanged(next.round()),
            onChangeEnd: (next) => onChangeEnd(next.round()),
          ),
        ),
      ],
    );
  }
}

class _ValueChip extends StatelessWidget {
  const _ValueChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withAlpha(35),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textDisabled,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Theme mode selector ────────────────────────────────────────────────

class _ThemeModeCard extends StatelessWidget {
  const _ThemeModeCard({
    required this.mode,
    required this.onChanged,
    required this.accent,
  });

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    const entries = [
      (mode: ThemeMode.system, label: 'Sistem', icon: Icons.brightness_auto_rounded),
      (mode: ThemeMode.light, label: 'Acik', icon: Icons.light_mode_rounded),
      (mode: ThemeMode.dark, label: 'Koyu', icon: Icons.dark_mode_rounded),
    ];

    return GlassPanel(
      borderRadius: 24,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      glowColor: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tema Modu',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Sistem ayarlarini takip edebilir veya acik/koyu modu sabitleyebilirsiniz.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _ModeTile(
                    label: entries[i].label,
                    icon: entries[i].icon,
                    selected: mode == entries[i].mode,
                    accent: accent,
                    onTap: () => onChanged(entries[i].mode),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: selected
                ? accent.withAlpha(28)
                : AppColors.surfaceVariant.withAlpha(120),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? accent.withAlpha(140) : AppColors.border,
              width: selected ? 1.2 : 0.6,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? accent : AppColors.textSecondary,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? accent : AppColors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
