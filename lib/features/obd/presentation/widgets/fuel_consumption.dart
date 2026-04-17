import 'package:flutter/material.dart';

import 'package:drivelink/app/theme/colors.dart';

/// Displays instantaneous fuel consumption in L/100 km.
///
/// Converts from fuel rate (L/h) and speed (km/h):
/// `L/100km = (fuelRate / speed) * 100`
class FuelConsumptionWidget extends StatelessWidget {
  const FuelConsumptionWidget({
    super.key,
    required this.fuelRateLph,
    required this.speedKmh,
  });

  /// Fuel rate in litres per hour (from PID 015E).
  final double? fuelRateLph;

  /// Vehicle speed in km/h.
  final double? speedKmh;

  double? get _litersPer100km {
    if (fuelRateLph == null || speedKmh == null) return null;
    if (speedKmh! <= 1) return null; // avoid division by zero / stationary
    return (fuelRateLph! / speedKmh!) * 100;
  }

  @override
  Widget build(BuildContext context) {
    final value = _litersPer100km;
    final display = value != null ? value.toStringAsFixed(1) : '--';
    final color = _consumptionColor(value);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_gas_station, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            display,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'L / 100 km',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          if (fuelRateLph != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${fuelRateLph!.toStringAsFixed(1)} L/h',
                style: TextStyle(
                  color: AppColors.textDisabled,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _consumptionColor(double? value) {
    if (value == null) return AppColors.textDisabled;
    if (value < 7) return AppColors.success;
    if (value < 12) return AppColors.warning;
    return AppColors.error;
  }
}
