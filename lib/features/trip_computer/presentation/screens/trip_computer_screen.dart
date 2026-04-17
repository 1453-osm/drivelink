import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/core/services/trip_service.dart';
import 'package:drivelink/features/trip_computer/presentation/widgets/fuel_economy.dart';
import 'package:drivelink/features/trip_computer/presentation/widgets/trip_history.dart';
import 'package:drivelink/features/trip_computer/presentation/widgets/trip_stats.dart';

/// Full-screen trip computer — shows live trip stats, fuel economy, and
/// a history of completed trips.
class TripComputerScreen extends ConsumerWidget {
  const TripComputerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripData = ref.watch(currentTripDataProvider);
    final isActive = ref.watch(tripActiveProvider);
    final historyAsync = ref.watch(tripHistoryProvider);
    final history = historyAsync.valueOrNull ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Trip Computer'),
        backgroundColor: AppColors.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // ── Active trip stats ─────────────────────────────────────────
          TripStats(
            distanceKm: tripData.distanceKm,
            elapsedMinutes: tripData.elapsedMinutes,
            avgSpeedKmh: tripData.avgSpeedKmh,
            onReset: isActive
                ? null
                : () => ref.read(tripServiceProvider).resetTrip(),
          ),

          const SizedBox(height: 12),

          // ── Max speed badge ───────────────────────────────────────────
          if (tripData.maxSpeedKmh > 0)
            _MaxSpeedBadge(maxSpeed: tripData.maxSpeedKmh),

          if (tripData.maxSpeedKmh > 0) const SizedBox(height: 12),

          // ── Fuel economy ──────────────────────────────────────────────
          FuelEconomy(
            currentLper100km: tripData.currentConsumptionLper100km,
            averageLper100km: tripData.avgConsumptionLper100km,
            totalConsumedLitres: tripData.totalFuelLitres,
          ),

          const SizedBox(height: 20),

          // ── Start / Stop button ───────────────────────────────────────
          _TripToggleButton(
            isActive: isActive,
            onPressed: () {
              final service = ref.read(tripServiceProvider);
              if (isActive) {
                service.stopTrip();
              } else {
                service.startTrip();
              }
            },
          ),

          const SizedBox(height: 24),

          // ── Trip history ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Icon(Icons.history, color: AppColors.textSecondary, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Trip History (${history.length})',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Card(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.border),
            ),
            child: TripHistory(trips: history),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Max speed badge ──────────────────────────────────────────────────────────

class _MaxSpeedBadge extends StatelessWidget {
  const _MaxSpeedBadge({required this.maxSpeed});
  final double maxSpeed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.speed, color: AppColors.warning, size: 20),
          const SizedBox(width: 10),
          Text(
            'Max Speed',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            '${maxSpeed.round()} km/h',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Start / Stop button ──────────────────────────────────────────────────────

class _TripToggleButton extends StatelessWidget {
  const _TripToggleButton({
    required this.isActive,
    required this.onPressed,
  });

  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(
          isActive ? Icons.stop_rounded : Icons.play_arrow_rounded,
          size: 26,
        ),
        label: Text(
          isActive ? 'Stop Trip' : 'Start Trip',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: isActive ? AppColors.error : AppColors.primary,
          foregroundColor: AppColors.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
