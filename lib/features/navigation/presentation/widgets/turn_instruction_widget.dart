import 'package:flutter/material.dart';

import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/features/navigation/domain/models/turn_instruction.dart';

/// A card showing the next turn manoeuvre — displayed at the top of the map.
///
/// Shows a large directional icon, distance to the manoeuvre, and the street
/// name to follow.
class TurnInstructionWidget extends StatelessWidget {
  const TurnInstructionWidget({
    super.key,
    required this.instruction,
  });

  final TurnInstruction instruction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withAlpha(230),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Turn icon ──────────────────────────────────────────────────
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _iconForType(instruction.type),
              color: AppColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(width: 14),

          // ── Distance + street name ─────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  instruction.formattedDistance,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  instruction.streetName.isNotEmpty
                      ? instruction.streetName
                      : instruction.type.label,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // ── Roundabout exit badge ──────────────────────────────────────
          if (instruction.type == TurnType.roundabout &&
              instruction.exitNumber != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Exit ${instruction.exitNumber}',
                style: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _iconForType(TurnType type) => switch (type) {
        TurnType.turnRight => Icons.turn_right,
        TurnType.turnLeft => Icons.turn_left,
        TurnType.roundabout => Icons.roundabout_right,
        TurnType.continue_ => Icons.arrow_upward,
        TurnType.arrive => Icons.flag,
        TurnType.uturn => Icons.u_turn_left,
        TurnType.mergeLeft => Icons.merge,
        TurnType.mergeRight => Icons.merge,
      };
}
