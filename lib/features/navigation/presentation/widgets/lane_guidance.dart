import 'package:flutter/material.dart';

import 'package:drivelink/app/theme/colors.dart';

/// Indicates which lane(s) the driver should use for the upcoming manoeuvre.
///
/// Each lane is drawn as a small arrow; active lanes are highlighted in the
/// primary colour, inactive lanes are dimmed.
class LaneGuidance extends StatelessWidget {
  const LaneGuidance({
    super.key,
    required this.lanes,
  });

  /// Each entry describes one lane: `(direction, isRecommended)`.
  ///
  /// Direction values: 'left', 'right', 'straight', 'slightLeft', 'slightRight'.
  final List<({String direction, bool isRecommended})> lanes;

  @override
  Widget build(BuildContext context) {
    if (lanes.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withAlpha(220),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < lanes.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 28,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: AppColors.divider,
              ),
            _LaneArrow(
              direction: lanes[i].direction,
              isRecommended: lanes[i].isRecommended,
            ),
          ],
        ],
      ),
    );
  }
}

class _LaneArrow extends StatelessWidget {
  const _LaneArrow({
    required this.direction,
    required this.isRecommended,
  });

  final String direction;
  final bool isRecommended;

  @override
  Widget build(BuildContext context) {
    final color = isRecommended ? AppColors.primary : AppColors.textDisabled;

    return SizedBox(
      width: 32,
      height: 32,
      child: Transform.rotate(
        angle: _rotationAngle,
        child: Icon(
          Icons.arrow_upward_rounded,
          color: color,
          size: 24,
        ),
      ),
    );
  }

  double get _rotationAngle => switch (direction) {
        'left' => -1.5708, // -90 deg
        'slightLeft' => -0.7854, // -45 deg
        'straight' => 0,
        'slightRight' => 0.7854, // 45 deg
        'right' => 1.5708, // 90 deg
        _ => 0,
      };
}
