import 'package:flutter/material.dart';

import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/shared/widgets/animated_value.dart';

/// Displays trip statistics: distance travelled, elapsed time, and average speed.
class TripStats extends StatelessWidget {
  const TripStats({
    super.key,
    required this.distanceKm,
    required this.elapsedMinutes,
    required this.avgSpeedKmh,
    this.onReset,
  });

  /// Distance travelled since trip reset, in kilometres.
  final double distanceKm;

  /// Time elapsed since trip reset, in minutes.
  final double elapsedMinutes;

  /// Average speed over the trip, in km/h.
  final double avgSpeedKmh;

  /// Called when the user taps "Reset trip".
  final VoidCallback? onReset;

  String _formatTime(double minutes) {
    final h = minutes ~/ 60;
    final m = (minutes % 60).round();
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────
            Row(
              children: [
                Icon(Icons.route, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Trip Stats',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (onReset != null)
                  TextButton.icon(
                    onPressed: onReset,
                    icon: const Icon(Icons.restart_alt, size: 16),
                    label: const Text('Reset', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textDisabled,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Stat tiles ─────────────────────────────────────────────
            Row(
              children: [
                _StatTile(
                  label: 'Distance',
                  child: AnimatedValue(
                    value: distanceKm,
                    fractionDigits: 1,
                    suffix: ' km',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _divider(),
                _StatTile(
                  label: 'Time',
                  child: Text(
                    _formatTime(elapsedMinutes),
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _divider(),
                _StatTile(
                  label: 'Avg Speed',
                  child: AnimatedValue(
                    value: avgSpeedKmh,
                    fractionDigits: 0,
                    suffix: ' km/h',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: AppColors.divider,
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          child,
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textDisabled,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
