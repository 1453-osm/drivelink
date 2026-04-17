import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:drivelink/app/theme/colors.dart';

/// A single recorded trip summary.
class TripRecord {
  const TripRecord({
    required this.date,
    required this.distanceKm,
    required this.durationMinutes,
    required this.avgSpeedKmh,
    required this.avgConsumption,
  });

  final DateTime date;
  final double distanceKm;
  final double durationMinutes;
  final double avgSpeedKmh;
  final double avgConsumption;

  String get formattedDuration {
    final h = durationMinutes ~/ 60;
    final m = (durationMinutes % 60).round();
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

/// Scrollable list of past trip records.
class TripHistory extends StatelessWidget {
  const TripHistory({
    super.key,
    required this.trips,
    this.onTripTap,
  });

  final List<TripRecord> trips;
  final ValueChanged<TripRecord>? onTripTap;

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history, color: AppColors.textDisabled, size: 48),
              SizedBox(height: 12),
              Text(
                'No trip history yet',
                style: TextStyle(color: AppColors.textDisabled, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: trips.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final trip = trips[index];
        return _TripTile(
          trip: trip,
          onTap: () => onTripTap?.call(trip),
        );
      },
    );
  }
}

class _TripTile extends StatelessWidget {
  const _TripTile({required this.trip, this.onTap});
  final TripRecord trip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd MMM, HH:mm').format(trip.date);

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.route, color: AppColors.primary, size: 22),
      ),
      title: Row(
        children: [
          Text(
            '${trip.distanceKm.toStringAsFixed(1)} km',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            trip.formattedDuration,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
      subtitle: Text(
        dateStr,
        style: TextStyle(
          color: AppColors.textDisabled,
          fontSize: 12,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${trip.avgSpeedKmh.round()} km/h',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${trip.avgConsumption.toStringAsFixed(1)} L/100',
            style: TextStyle(
              color: trip.avgConsumption <= 7
                  ? AppColors.success
                  : trip.avgConsumption <= 9
                      ? AppColors.warning
                      : AppColors.error,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
