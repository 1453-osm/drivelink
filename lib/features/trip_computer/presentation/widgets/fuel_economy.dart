import 'package:flutter/material.dart';

import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/shared/widgets/animated_value.dart';

/// Displays fuel economy metrics: current consumption, trip average, and total consumed.
class FuelEconomy extends StatelessWidget {
  const FuelEconomy({
    super.key,
    required this.currentLper100km,
    required this.averageLper100km,
    required this.totalConsumedLitres,
  });

  /// Instantaneous fuel consumption in L/100km.
  final double currentLper100km;

  /// Average fuel consumption over the current trip in L/100km.
  final double averageLper100km;

  /// Total fuel consumed during the trip in litres.
  final double totalConsumedLitres;

  Color _consumptionColor(double value) {
    if (value <= 6) return AppColors.success;
    if (value <= 9) return AppColors.warning;
    return AppColors.error;
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
                Icon(Icons.local_gas_station, color: AppColors.accent, size: 20),
                SizedBox(width: 8),
                Text(
                  'Fuel Economy',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Metric tiles ───────────────────────────────────────────
            Row(
              children: [
                _FuelTile(
                  label: 'Current',
                  child: AnimatedValue(
                    value: currentLper100km,
                    fractionDigits: 1,
                    style: TextStyle(
                      color: _consumptionColor(currentLper100km),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  unit: 'L/100km',
                ),
                _divider(),
                _FuelTile(
                  label: 'Average',
                  child: AnimatedValue(
                    value: averageLper100km,
                    fractionDigits: 1,
                    style: TextStyle(
                      color: _consumptionColor(averageLper100km),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  unit: 'L/100km',
                ),
                _divider(),
                _FuelTile(
                  label: 'Total Used',
                  child: AnimatedValue(
                    value: totalConsumedLitres,
                    fractionDigits: 1,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  unit: 'litres',
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

class _FuelTile extends StatelessWidget {
  const _FuelTile({
    required this.label,
    required this.child,
    required this.unit,
  });

  final String label;
  final Widget child;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          child,
          const SizedBox(height: 2),
          Text(
            unit,
            style: TextStyle(
              color: AppColors.textDisabled,
              fontSize: 10,
            ),
          ),
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
