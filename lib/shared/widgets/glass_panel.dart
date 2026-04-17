import 'package:flutter/material.dart';

import 'package:drivelink/app/theme/colors.dart';

/// A premium glass-morphism panel that creates depth with gradient background,
/// luminescent border, ambient glow, and a top-edge highlight line.
///
/// Use this as the surface treatment for all cards, tiles, and containers
/// throughout the app to create a cohesive premium cockpit aesthetic.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.padding,
    this.glowColor,
    this.glowIntensity = 0.06,
    this.showTopHighlight = true,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;

  /// The color used for the ambient glow and border tint.
  /// Defaults to [AppColors.primary] (electric cyan).
  final Color? glowColor;

  /// Glow opacity multiplier (0.0 – 1.0). Default 0.06.
  final double glowIntensity;

  /// Whether to show the thin highlight line at the top edge.
  final bool showTopHighlight;

  @override
  Widget build(BuildContext context) {
    final glow = glowColor ?? Theme.of(context).colorScheme.primary;
    final radius = BorderRadius.circular(borderRadius);
    final glowAlpha = (255 * glowIntensity).round();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceVariant,
            AppColors.surface,
            Color.lerp(AppColors.surface, AppColors.background, 0.6)!,
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
        borderRadius: radius,
        border: Border.all(
          color: glow.withAlpha(20),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: glow.withAlpha(glowAlpha),
            blurRadius: 24,
            spreadRadius: -4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: padding ?? EdgeInsets.zero,
              child: child,
            ),
            if (showTopHighlight)
              Positioned(
                top: 0,
                left: borderRadius,
                right: borderRadius,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        glow.withAlpha(38),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
