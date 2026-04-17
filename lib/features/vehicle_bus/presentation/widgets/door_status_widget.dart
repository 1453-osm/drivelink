import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/features/vehicle_bus/domain/models/vehicle_state.dart';
import 'package:drivelink/features/vehicle_bus/presentation/providers/vehicle_bus_providers.dart';

/// A top-down car silhouette with door open/close indicators.
class DoorStatusWidget extends ConsumerWidget {
  const DoorStatusWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(vehicleStateProvider);

    return asyncState.when(
      loading: () => _buildBody(const DoorStatus()),
      error: (_, __) => _buildBody(const DoorStatus()),
      data: (state) => _buildBody(state.doorStatus),
    );
  }

  Widget _buildBody(DoorStatus doors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Doors',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 140,
            height: 220,
            child: CustomPaint(
              painter: _CarDoorPainter(doors),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            doors.allClosed ? 'All closed' : 'Door open!',
            style: TextStyle(
              color: doors.allClosed ? AppColors.success : AppColors.warning,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CarDoorPainter extends CustomPainter {
  _CarDoorPainter(this.doors);

  final DoorStatus doors;

  @override
  void paint(Canvas canvas, Size size) {
    final bodyPaint = Paint()
      ..color = AppColors.surfaceVariant
      ..style = PaintingStyle.fill;

    final outlinePaint = Paint()
      ..color = AppColors.textSecondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final doorClosedPaint = Paint()
      ..color = AppColors.success
      ..style = PaintingStyle.fill;

    final doorOpenPaint = Paint()
      ..color = AppColors.warning
      ..style = PaintingStyle.fill;

    // Car body — rounded rectangle (top-view)
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.2, 0, size.width * 0.6, size.height),
      const Radius.circular(20),
    );
    canvas.drawRRect(bodyRect, bodyPaint);
    canvas.drawRRect(bodyRect, outlinePaint);

    // Door indicators — small rectangles on each side
    const doorWidth = 8.0;
    const doorHeight = 36.0;

    // Front left
    _drawDoor(
      canvas,
      Rect.fromLTWH(
        size.width * 0.2 - doorWidth - 4,
        size.height * 0.22,
        doorWidth,
        doorHeight,
      ),
      doors.frontLeft,
      doorClosedPaint,
      doorOpenPaint,
      outlinePaint,
      isLeft: true,
    );

    // Front right
    _drawDoor(
      canvas,
      Rect.fromLTWH(
        size.width * 0.8 + 4,
        size.height * 0.22,
        doorWidth,
        doorHeight,
      ),
      doors.frontRight,
      doorClosedPaint,
      doorOpenPaint,
      outlinePaint,
      isLeft: false,
    );

    // Rear left
    _drawDoor(
      canvas,
      Rect.fromLTWH(
        size.width * 0.2 - doorWidth - 4,
        size.height * 0.52,
        doorWidth,
        doorHeight,
      ),
      doors.rearLeft,
      doorClosedPaint,
      doorOpenPaint,
      outlinePaint,
      isLeft: true,
    );

    // Rear right
    _drawDoor(
      canvas,
      Rect.fromLTWH(
        size.width * 0.8 + 4,
        size.height * 0.52,
        doorWidth,
        doorHeight,
      ),
      doors.rearRight,
      doorClosedPaint,
      doorOpenPaint,
      outlinePaint,
      isLeft: false,
    );

    // Windshield indicators
    final windshieldPaint = Paint()
      ..color = AppColors.textDisabled.withAlpha(80)
      ..style = PaintingStyle.fill;

    // Front windshield
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.28,
          size.height * 0.08,
          size.width * 0.44,
          size.height * 0.08,
        ),
        const Radius.circular(6),
      ),
      windshieldPaint,
    );

    // Rear windshield
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.28,
          size.height * 0.82,
          size.width * 0.44,
          size.height * 0.08,
        ),
        const Radius.circular(6),
      ),
      windshieldPaint,
    );
  }

  void _drawDoor(
    Canvas canvas,
    Rect rect,
    bool isOpen,
    Paint closedPaint,
    Paint openPaint,
    Paint outlinePaint, {
    required bool isLeft,
  }) {
    if (isOpen) {
      // Draw angled door (open state)
      canvas.save();
      final pivotX = isLeft ? rect.right : rect.left;
      final pivotY = rect.top;
      canvas.translate(pivotX, pivotY);
      canvas.rotate(isLeft ? -math.pi / 6 : math.pi / 6);
      canvas.translate(-pivotX, -pivotY);
      canvas.drawRect(rect, openPaint);
      canvas.restore();
    } else {
      canvas.drawRect(rect, closedPaint);
    }
  }

  @override
  bool shouldRepaint(_CarDoorPainter oldDelegate) =>
      doors.frontLeft != oldDelegate.doors.frontLeft ||
      doors.frontRight != oldDelegate.doors.frontRight ||
      doors.rearLeft != oldDelegate.doors.rearLeft ||
      doors.rearRight != oldDelegate.doors.rearRight;
}
