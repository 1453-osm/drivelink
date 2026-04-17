import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:drivelink/app/theme/colors.dart';

/// A reusable radial gauge for displaying vehicle metrics (speed, RPM, temp, etc.).
///
/// Renders a 270-degree arc with an optional animated needle.
class GaugeWidget extends StatelessWidget {
  const GaugeWidget({
    super.key,
    required this.value,
    this.minValue = 0,
    this.maxValue = 100,
    this.label = '',
    this.unit = '',
    this.size = 200,
    this.trackWidth = 12,
    this.showNeedle = true,
    this.gradientColors,
    this.warningThreshold,
    this.dangerThreshold,
  });

  /// Current value to display on the gauge.
  final double value;

  /// Minimum scale value.
  final double minValue;

  /// Maximum scale value.
  final double maxValue;

  /// Primary label shown below the value (e.g. "Speed").
  final String label;

  /// Unit text drawn next to the numeric readout (e.g. "km/h").
  final String unit;

  /// Overall widget size (width & height).
  final double size;

  /// Thickness of the arc track.
  final double trackWidth;

  /// Whether to draw the needle indicator.
  final bool showNeedle;

  /// Custom gradient colors along the arc. If null, a default green-yellow-red
  /// gradient is used based on [warningThreshold] and [dangerThreshold].
  final List<Color>? gradientColors;

  /// Value above which the gauge shows a warning color.
  final double? warningThreshold;

  /// Value above which the gauge shows a danger color.
  final double? dangerThreshold;

  @override
  Widget build(BuildContext context) {
    final clampedValue = value.clamp(minValue, maxValue);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GaugePainter(
          value: clampedValue,
          minValue: minValue,
          maxValue: maxValue,
          trackWidth: trackWidth,
          showNeedle: showNeedle,
          gradientColors: gradientColors ??
              _defaultGradient(clampedValue),
          warningThreshold: warningThreshold,
          dangerThreshold: dangerThreshold,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                clampedValue.toStringAsFixed(
                    clampedValue == clampedValue.roundToDouble() ? 0 : 1),
                style: TextStyle(
                  color: _valueColor(clampedValue),
                  fontSize: size * 0.22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (unit.isNotEmpty)
                Text(
                  unit,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: size * 0.08,
                  ),
                ),
              if (label.isNotEmpty) ...[
                SizedBox(height: size * 0.02),
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: size * 0.07,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Color> _defaultGradient(double val) {
    return [
      AppColors.gaugeNormal,
      AppColors.gaugeWarning,
      AppColors.gaugeDanger,
    ];
  }

  Color _valueColor(double val) {
    if (dangerThreshold != null && val >= dangerThreshold!) {
      return AppColors.gaugeDanger;
    }
    if (warningThreshold != null && val >= warningThreshold!) {
      return AppColors.gaugeWarning;
    }
    return AppColors.textPrimary;
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.trackWidth,
    required this.showNeedle,
    required this.gradientColors,
    this.warningThreshold,
    this.dangerThreshold,
  });

  final double value;
  final double minValue;
  final double maxValue;
  final double trackWidth;
  final bool showNeedle;
  final List<Color> gradientColors;
  final double? warningThreshold;
  final double? dangerThreshold;

  /// The gauge arc spans 270 degrees, starting from 135 degrees (bottom-left).
  static const double _startAngle = 135 * (math.pi / 180);
  static const double _sweepAngle = 270 * (math.pi / 180);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - trackWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // ── Track (background arc) ─────────────────────────────────────────
    final trackPaint = Paint()
      ..color = AppColors.gaugeTrack
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, _startAngle, _sweepAngle, false, trackPaint);

    // ── Value arc (foreground) ─────────────────────────────────────────
    final fraction = (value - minValue) / (maxValue - minValue);
    final valueSweep = _sweepAngle * fraction;

    final gradient = SweepGradient(
      startAngle: _startAngle,
      endAngle: _startAngle + _sweepAngle,
      colors: gradientColors,
    );

    final valuePaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, _startAngle, valueSweep, false, valuePaint);

    // ── Needle ─────────────────────────────────────────────────────────
    if (showNeedle) {
      final needleAngle = _startAngle + valueSweep;
      final needleLength = radius - trackWidth;
      final needleEnd = Offset(
        center.dx + needleLength * math.cos(needleAngle),
        center.dy + needleLength * math.sin(needleAngle),
      );

      final needlePaint = Paint()
        ..color = AppColors.textPrimary
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(center, needleEnd, needlePaint);

      // Center knob
      final knobPaint = Paint()..color = AppColors.textPrimary;
      canvas.drawCircle(center, 5, knobPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue;
  }
}
