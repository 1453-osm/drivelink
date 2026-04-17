import 'package:flutter/material.dart';

import 'package:drivelink/app/theme/colors.dart';

/// Smoothly animates between numeric values — ideal for speedometer, RPM, etc.
///
/// Uses an implicit [AnimatedWidget] so callers just update [value] and the
/// widget handles the tween automatically.
class AnimatedValue extends StatelessWidget {
  const AnimatedValue({
    super.key,
    required this.value,
    this.fractionDigits = 0,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeOutCubic,
  });

  /// The current numeric value to display.
  final double value;

  /// Decimal places to show (0 = integer display).
  final int fractionDigits;

  /// Optional text style; defaults to [TextTheme.headlineLarge].
  final TextStyle? style;

  /// Text prepended before the number (e.g. currency symbol).
  final String prefix;

  /// Text appended after the number (e.g. unit label like "km/h").
  final String suffix;

  /// Duration of the value-change animation.
  final Duration duration;

  /// Animation curve.
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ??
        Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            );

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value),
      duration: duration,
      curve: curve,
      builder: (context, animatedVal, _) {
        final formatted = animatedVal.toStringAsFixed(fractionDigits);
        return Text(
          '$prefix$formatted$suffix',
          style: effectiveStyle,
        );
      },
    );
  }
}
