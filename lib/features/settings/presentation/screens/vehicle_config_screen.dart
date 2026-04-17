import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/core/database/settings_repository.dart';
import 'package:drivelink/shared/widgets/responsive_page_body.dart';

/// Supported vehicle profiles.
///
/// Each profile determines VAN-bus message IDs and OBD PID mappings.
enum VehicleProfile {
  peugeot206('Peugeot 206', 'PSA VAN bus'),
  peugeot307('Peugeot 307', 'PSA VAN bus'),
  peugeot407('Peugeot 407', 'PSA VAN / CAN bus'),
  citroenC3('Citroen C3', 'PSA VAN bus'),
  citroenC4('Citroen C4', 'PSA CAN bus'),
  genericObd('Generic OBD-II', 'Standard OBD-II PIDs only');

  const VehicleProfile(this.displayName, this.busInfo);
  final String displayName;
  final String busInfo;

  /// Look up a profile by its enum name, falling back to [peugeot206].
  static VehicleProfile fromName(String? name) {
    if (name == null) return VehicleProfile.peugeot206;
    return VehicleProfile.values.firstWhere(
      (p) => p.name == name,
      orElse: () => VehicleProfile.peugeot206,
    );
  }
}

// ---------------------------------------------------------------------------
// AsyncNotifier — loads from DB on startup, persists on change
// ---------------------------------------------------------------------------

class VehicleProfileNotifier extends AsyncNotifier<VehicleProfile> {
  @override
  FutureOr<VehicleProfile> build() async {
    final repo = ref.read(settingsRepositoryProvider);
    final saved = await repo.get(SettingsKeys.selectedVehicleProfile);
    return VehicleProfile.fromName(saved);
  }

  Future<void> select(VehicleProfile profile) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.set(SettingsKeys.selectedVehicleProfile, profile.name);
    state = AsyncData(profile);
  }
}

final vehicleProfileProvider =
    AsyncNotifierProvider<VehicleProfileNotifier, VehicleProfile>(
      VehicleProfileNotifier.new,
    );

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Screen for selecting the user's vehicle model.
class VehicleConfigScreen extends ConsumerWidget {
  const VehicleConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(vehicleProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Vehicle Profile'),
        backgroundColor: AppColors.surface,
      ),
      body: ResponsivePageBody(
        maxWidth: 920,
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
          ),
          data: (selected) => ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: VehicleProfile.values.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final profile = VehicleProfile.values[index];
              final isSelected = profile == selected;

              return ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withAlpha(30)
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.directions_car,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textDisabled,
                    size: 24,
                  ),
                ),
                title: Text(
                  profile.displayName,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textPrimary,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    fontSize: 15,
                  ),
                ),
                subtitle: Text(
                  profile.busInfo,
                  style: TextStyle(
                    color: AppColors.textDisabled,
                    fontSize: 12,
                  ),
                ),
                trailing: isSelected
                    ? Icon(
                        Icons.check_circle,
                        color: AppColors.primary,
                        size: 22,
                      )
                    : null,
                onTap: () {
                  ref.read(vehicleProfileProvider.notifier).select(profile);
                },
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
