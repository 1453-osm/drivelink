import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/features/dashboard/domain/models/gauge_metric.dart';

/// Returns the zone color for a given value, using the current theme's
/// primary for the normal band and fixed warning/danger tones above.
Color _zoneColor(GaugeMetric metric, double value, Color themePrimary) {
  if (value >= metric.dangerValue) return AppColors.gaugeDanger;
  if (value >= metric.warningValue) return AppColors.gaugeWarning;
  return themePrimary;
}

/// Minimalist radial gauge with a 240° sweep and zone indicators.
class ConfigurableGauge extends StatelessWidget {
  const ConfigurableGauge({
    super.key,
    required this.metric,
    required this.value,
    this.onLongPress,
  });

  final GaugeMetric metric;
  final double value;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () {
        HapticFeedback.mediumImpact();
        onLongPress?.call();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final shortest = constraints.biggest.shortestSide;
          final compact = shortest < 170;
          final dense = shortest < 140;
          final clamped = value.clamp(metric.minValue, metric.maxValue);
          final themePrimary = Theme.of(context).colorScheme.primary;
          final color = _zoneColor(metric, clamped, themePrimary);

          final range = metric.maxValue - metric.minValue;
          final warnStop =
              ((metric.warningValue - metric.minValue) / range).clamp(0.0, 1.0);
          final dangerStop =
              ((metric.dangerValue - metric.minValue) / range).clamp(0.0, 1.0);
          final strokeWidth = dense ? 6.0 : (compact ? 7.5 : 9.0);

          return _GaugeShell(
            color: color,
            compact: compact,
            child: Padding(
              padding: EdgeInsets.all(dense ? 8 : (compact ? 10 : 14)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _GaugeLabel(
                    metric: metric,
                    color: color,
                    dense: dense,
                    compact: compact,
                  ),
                  SizedBox(height: dense ? 4 : (compact ? 6 : 8)),
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(end: clamped),
                          duration: const Duration(milliseconds: 450),
                          curve: Curves.easeOutCubic,
                          builder: (context, animatedValue, _) {
                            final progress =
                                ((animatedValue - metric.minValue) / range)
                                    .clamp(0.0, 1.0);
                            return CustomPaint(
                              size: Size.infinite,
                              painter: _GaugeArcPainter(
                                progress: progress,
                                warnStop: warnStop,
                                dangerStop: dangerStop,
                                color: color,
                                strokeWidth: strokeWidth,
                              ),
                            );
                          },
                        ),
                        _GaugeValue(
                          metric: metric,
                          value: clamped,
                          color: color,
                          dense: dense,
                          compact: compact,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Shell ──────────────────────────────────────────────────────────────

class _GaugeShell extends StatelessWidget {
  const _GaugeShell({
    required this.child,
    required this.color,
    required this.compact,
  });

  final Widget child;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 20 : 24),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.surfaceBright,
            AppColors.surface,
            Color.lerp(AppColors.surface, color, 0.03)!,
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
        border: Border.all(color: color.withAlpha(32), width: 0.6),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(22),
            blurRadius: compact ? 14 : 20,
            spreadRadius: -6,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(compact ? 20 : 24),
        child: Stack(
          children: [
            // Top highlight rim for depth
            Positioned(
              top: 0,
              left: compact ? 20 : 24,
              right: compact ? 20 : 24,
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      color.withAlpha(50),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

// ─── Label pill ─────────────────────────────────────────────────────────

class _GaugeLabel extends StatelessWidget {
  const _GaugeLabel({
    required this.metric,
    required this.color,
    required this.dense,
    required this.compact,
  });

  final GaugeMetric metric;
  final Color color;
  final bool dense;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : (compact ? 8 : 10),
        vertical: dense ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            metric.icon,
            color: color,
            size: dense ? 10 : (compact ? 11 : 13),
          ),
          if (!dense) ...[
            SizedBox(width: compact ? 4 : 6),
            Flexible(
              child: Text(
                metric.label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary.withAlpha(230),
                  fontSize: compact ? 8 : 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Center value ───────────────────────────────────────────────────────

class _GaugeValue extends StatelessWidget {
  const _GaugeValue({
    required this.metric,
    required this.value,
    required this.color,
    required this.dense,
    required this.compact,
  });

  final GaugeMetric metric;
  final double value;
  final Color color;
  final bool dense;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value.toStringAsFixed(metric.fractionDigits),
          style: GoogleFonts.jetBrainsMono(
            color: AppColors.textPrimary,
            fontSize: dense ? 22 : (compact ? 28 : 36),
            fontWeight: FontWeight.w500,
            height: 1,
            letterSpacing: -1.2,
            shadows: [Shadow(color: color.withAlpha(70), blurRadius: 14)],
          ),
        ),
        SizedBox(height: dense ? 3 : 5),
        Text(
          metric.unit,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: dense ? 8 : (compact ? 9 : 10),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

// ─── Arc painter ────────────────────────────────────────────────────────

class _GaugeArcPainter extends CustomPainter {
  _GaugeArcPainter({
    required this.progress,
    required this.warnStop,
    required this.dangerStop,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final double warnStop;
  final double dangerStop;
  final Color color;
  final double strokeWidth;

  static const double _startAngle = 150 * math.pi / 180;
  static const double _sweepAngle = 240 * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius =
        math.min(size.width, size.height) / 2 - strokeWidth / 2 - 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // ── Track ────────────────────────────────────────────────────
    final trackPaint = Paint()
      ..color = AppColors.gaugeTrack
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _startAngle, _sweepAngle, false, trackPaint);

    // ── Zone ticks (warning/danger) just outside track ───────────
    _drawZoneTick(canvas, center, radius, warnStop, AppColors.gaugeWarning);
    _drawZoneTick(canvas, center, radius, dangerStop, AppColors.gaugeDanger);

    if (progress <= 0) return;

    final sweep = _sweepAngle * progress;

    // ── Soft glow underlay ───────────────────────────────────────
    final glowPaint = Paint()
      ..color = color.withAlpha(70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawArc(rect, _startAngle, sweep, false, glowPaint);

    // ── Progress arc ─────────────────────────────────────────────
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _startAngle, sweep, false, progressPaint);

    // ── End-cap highlight dot ────────────────────────────────────
    final endAngle = _startAngle + sweep;
    final tipPos = Offset(
      center.dx + math.cos(endAngle) * radius,
      center.dy + math.sin(endAngle) * radius,
    );
    canvas.drawCircle(
      tipPos,
      strokeWidth * 0.55,
      Paint()..color = Colors.white.withAlpha(230),
    );
    canvas.drawCircle(
      tipPos,
      strokeWidth * 0.22,
      Paint()..color = color,
    );
  }

  void _drawZoneTick(
    Canvas canvas,
    Offset center,
    double radius,
    double stop,
    Color tickColor,
  ) {
    final angle = _startAngle + _sweepAngle * stop;
    final inner = Offset(
      center.dx + math.cos(angle) * (radius + strokeWidth / 2 + 2),
      center.dy + math.sin(angle) * (radius + strokeWidth / 2 + 2),
    );
    final outer = Offset(
      center.dx + math.cos(angle) * (radius + strokeWidth / 2 + 6),
      center.dy + math.sin(angle) * (radius + strokeWidth / 2 + 6),
    );
    final paint = Paint()
      ..color = tickColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(inner, outer, paint);
  }

  @override
  bool shouldRepaint(covariant _GaugeArcPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.warnStop != warnStop ||
      old.dangerStop != dangerStop ||
      old.strokeWidth != strokeWidth;
}
