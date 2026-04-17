import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import 'package:drivelink/app/theme/colors.dart';

/// Horizontal volume slider with mute toggle and compact percentage label.
class VolumeControl extends StatelessWidget {
  const VolumeControl({
    super.key,
    required this.volume,
    required this.onChanged,
    this.onMuteToggle,
    this.isMuted = false,
  });

  final double volume;
  final ValueChanged<double> onChanged;
  final VoidCallback? onMuteToggle;
  final bool isMuted;

  IconData get _icon {
    if (isMuted || volume == 0) return Icons.volume_off;
    if (volume < 0.4) return Icons.volume_down;
    return Icons.volume_up;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface.withAlpha(160),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onMuteToggle,
              splashColor: primary.withAlpha(30),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  _icon,
                  color: isMuted ? AppColors.textDisabled : primary,
                  size: 20,
                ),
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: primary,
                inactiveTrackColor: AppColors.border,
                thumbColor: primary,
                overlayColor: primary.withAlpha(40),
                trackHeight: 2.5,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 5,
                  elevation: 2,
                ),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: isMuted ? 0 : volume,
                onChanged: (v) => onChanged(v),
                min: 0,
                max: 1,
              ),
            ),
          ),
          SizedBox(
            width: 34,
            child: Text(
              '${(volume * 100).round()}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
