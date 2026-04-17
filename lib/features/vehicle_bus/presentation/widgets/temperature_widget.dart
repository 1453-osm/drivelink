import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/features/vehicle_bus/presentation/providers/vehicle_bus_providers.dart';

/// Displays the external temperature read from the VAN bus.
class TemperatureWidget extends ConsumerWidget {
  const TemperatureWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(vehicleStateProvider);

    return asyncState.when(
      loading: () => _buildCard(context, null),
      error: (_, __) => _buildCard(context, null),
      data: (state) => _buildCard(context, state.externalTemp),
    );
  }

  Widget _buildCard(BuildContext context, double? temp) {
    final displayTemp = temp != null ? '${temp.toStringAsFixed(1)}°C' : '--°C';
    final iconColor = _tempColor(temp);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.thermostat, color: iconColor, size: 28),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'External Temp',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                displayTemp,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _tempColor(double? temp) {
    if (temp == null) return AppColors.textDisabled;
    if (temp <= 3) return AppColors.info; // frost warning
    if (temp >= 40) return AppColors.error;
    return AppColors.success;
  }
}
