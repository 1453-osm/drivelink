import 'dart:math';

import 'package:flutter/material.dart';
import 'package:drivelink/app/theme/colors.dart';

/// Animated microphone indicator that shows the current listening state.
///
/// - [idle]: Static microphone icon
/// - [listening]: Pulsing concentric rings animation
/// - [processing]: Rotating dots animation
class VoiceIndicator extends StatefulWidget {
  const VoiceIndicator({
    super.key,
    required this.isListening,
    required this.isProcessing,
    this.size = 120,
    this.onTap,
  });

  final bool isListening;
  final bool isProcessing;
  final double size;
  final VoidCallback? onTap;

  @override
  State<VoiceIndicator> createState() => _VoiceIndicatorState();
}

class _VoiceIndicatorState extends State<VoiceIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _rotateController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
  }

  @override
  void didUpdateWidget(VoiceIndicator old) {
    super.didUpdateWidget(old);

    if (widget.isListening && !old.isListening) {
      _pulseController.repeat();
      _rotateController.stop();
    } else if (widget.isProcessing && !old.isProcessing) {
      _pulseController.stop();
      _rotateController.repeat();
    } else if (!widget.isListening && !widget.isProcessing) {
      _pulseController.stop();
      _rotateController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isListening || widget.isProcessing;

    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Pulse rings (listening)
            if (widget.isListening)
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) => CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _PulseRingPainter(
                    progress: _pulseController.value,
                    color: AppColors.primary,
                  ),
                ),
              ),

            // Rotating dots (processing)
            if (widget.isProcessing)
              AnimatedBuilder(
                animation: _rotateController,
                builder: (context, child) => CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _ProcessingDotsPainter(
                    progress: _rotateController.value,
                    color: AppColors.accent,
                  ),
                ),
              ),

            // Center circle with mic icon
            Container(
              width: widget.size * 0.5,
              height: widget.size * 0.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : AppColors.surfaceVariant,
                border: Border.all(
                  color: isActive ? AppColors.primary : AppColors.border,
                  width: 2,
                ),
              ),
              child: Icon(
                widget.isListening
                    ? Icons.mic
                    : widget.isProcessing
                        ? Icons.hourglass_top
                        : Icons.mic_none,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
                size: widget.size * 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pulse ring painter ─────────────────────────────────────────────────

class _PulseRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _PulseRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < 3; i++) {
      final phase = (progress + i * 0.33) % 1.0;
      final radius = maxRadius * 0.3 + maxRadius * 0.7 * phase;
      final opacity = (1.0 - phase) * 0.4;

      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_PulseRingPainter old) => old.progress != progress;
}

// ── Processing dots painter ────────────────────────────────────────────

class _ProcessingDotsPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ProcessingDotsPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.38;
    const dotCount = 8;
    const dotRadius = 3.0;

    for (int i = 0; i < dotCount; i++) {
      final angle = (2 * pi * i / dotCount) + (progress * 2 * pi);
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      final opacity = 0.3 + 0.7 * ((i / dotCount + progress) % 1.0);

      canvas.drawCircle(
        Offset(x, y),
        dotRadius,
        Paint()..color = color.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_ProcessingDotsPainter old) => old.progress != progress;
}
