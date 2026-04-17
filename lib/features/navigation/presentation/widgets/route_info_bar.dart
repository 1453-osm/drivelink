import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/features/navigation/domain/models/route_model.dart';

/// A bottom bar showing real-time route information: speed, ETA, remaining
/// distance, and arrival time.
class RouteInfoBar extends StatelessWidget {
  const RouteInfoBar({
    super.key,
    required this.route,
    this.currentSpeedKmh = 0,
  });

  final RouteModel route;
  final double currentSpeedKmh;

  @override
  Widget build(BuildContext context) {
    final arrivalTime = DateFormat('HH:mm').format(route.estimatedArrival);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withAlpha(230),
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _InfoTile(
              icon: Icons.speed,
              value: '${currentSpeedKmh.round()}',
              unit: 'km/h',
            ),
            _divider(),
            _InfoTile(
              icon: Icons.timer_outlined,
              value: route.formattedDuration,
              unit: 'sure',
            ),
            _divider(),
            _InfoTile(
              icon: Icons.straighten,
              value: route.formattedDistance,
              unit: 'kalan',
            ),
            _divider(),
            _InfoTile(
              icon: Icons.flag_outlined,
              value: arrivalTime,
              unit: 'varis',
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 36,
      color: AppColors.divider,
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.value,
    required this.unit,
  });

  final IconData icon;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          unit,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
