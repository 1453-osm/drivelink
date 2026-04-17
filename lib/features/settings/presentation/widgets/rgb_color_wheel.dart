import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:drivelink/app/theme/colors.dart';

class RgbColorWheel extends StatefulWidget {
  const RgbColorWheel({
    super.key,
    required this.color,
    required this.onChanged,
    this.onChangeEnd,
    this.size = 220,
    this.ringWidth = 22,
  });

  final Color color;
  final ValueChanged<Color> onChanged;
  final ValueChanged<Color>? onChangeEnd;
  final double size;
  final double ringWidth;

  @override
  State<RgbColorWheel> createState() => _RgbColorWheelState();
}

class _RgbColorWheelState extends State<RgbColorWheel> {
  Color? _pendingColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) => _update(details.localPosition),
        onPanUpdate: (details) => _update(details.localPosition),
        onPanEnd: (_) => _commitPending(),
        onPanCancel: _commitPending,
        onTapDown: (details) {
          final next = _colorFor(details.localPosition);
          if (next == null) return;
          widget.onChanged(next);
          widget.onChangeEnd?.call(next);
        },
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _RgbColorWheelPainter(
              color: widget.color,
              ringWidth: widget.ringWidth,
            ),
          ),
        ),
      ),
    );
  }

  void _update(Offset localPosition) {
    final next = _colorFor(localPosition);
    if (next == null) return;
    if (_pendingColor?.value == next.value ||
        widget.color.value == next.value) {
      return;
    }
    _pendingColor = next;
    widget.onChanged(next);
  }

  void _commitPending() {
    final next = _pendingColor;
    _pendingColor = null;
    if (next != null) {
      widget.onChangeEnd?.call(next);
    }
  }

  Color? _colorFor(Offset localPosition) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final vector = localPosition - center;
    final distance = vector.distance;
    final radius = widget.size / 2;
    final innerRadius = radius - widget.ringWidth;
    const tolerance = 10.0;

    if (distance < innerRadius - tolerance || distance > radius + tolerance) {
      return null;
    }

    final angle =
        (math.atan2(vector.dy, vector.dx) + math.pi * 2) % (math.pi * 2);
    final hue = angle * 180 / math.pi;
    final hsv = HSVColor.fromColor(widget.color);
    return hsv.withHue(hue).toColor();
  }
}

class _RgbColorWheelPainter extends CustomPainter {
  const _RgbColorWheelPainter({required this.color, required this.ringWidth});

  final Color color;
  final double ringWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = size.shortestSide / 2;
    final center = rect.center;
    final innerRadius = radius - ringWidth;
    final hue = HSVColor.fromColor(color).hue;
    final theta = hue * math.pi / 180;

    final wheelPaint = Paint()
      ..shader = SweepGradient(
        colors: const [
          Color(0xFFFF3B30),
          Color(0xFFFF9500),
          Color(0xFFFFCC00),
          Color(0xFF34C759),
          Color(0xFF00C7BE),
          Color(0xFF007AFF),
          Color(0xFF5856D6),
          Color(0xFFFF2D55),
          Color(0xFFFF3B30),
        ],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth;

    canvas.drawCircle(center, innerRadius + ringWidth / 2, wheelPaint);

    final plateRect = Rect.fromCircle(center: center, radius: innerRadius - 6);
    final platePaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, color, color.withAlpha(0)],
        stops: const [0.0, 0.68, 1.0],
      ).createShader(plateRect);

    canvas.drawCircle(center, innerRadius - 6, platePaint);
    canvas.drawCircle(
      center,
      innerRadius - 6,
      Paint()..color = AppColors.background.withAlpha(30),
    );

    final handleCenter = Offset(
      center.dx + math.cos(theta) * (innerRadius + ringWidth / 2),
      center.dy + math.sin(theta) * (innerRadius + ringWidth / 2),
    );

    canvas.drawCircle(
      handleCenter,
      11,
      Paint()..color = Colors.black.withAlpha(70),
    );
    canvas.drawCircle(handleCenter, 9, Paint()..color = color);
    canvas.drawCircle(
      handleCenter,
      11,
      Paint()
        ..color = Colors.white.withAlpha(220)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _RgbColorWheelPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.ringWidth != ringWidth;
  }
}
