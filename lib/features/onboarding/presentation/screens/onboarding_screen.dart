import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/core/database/settings_repository.dart';
import 'package:drivelink/core/services/turkey_package_service.dart';
import 'package:drivelink/features/settings/presentation/screens/map_download_screen.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              Icon(Icons.directions_car,
                  color: AppColors.primary, size: 72),
              const SizedBox(height: 16),
              Text(
                'DriveLink',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Eski aracini akilli yap',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Icon(Icons.map_outlined,
                        color: AppColors.primary, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      'Offline Harita Gerekli',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Navigasyonun calismasi icin en az bir bolgenin '
                      'haritasini indirmelisiniz. Internet olmadan da '
                      'yolunuzu bulabilirsiniz.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const MapDownloadScreen(),
                          ));
                        },
                        icon: const Icon(Icons.download, size: 20),
                        label: const Text(
                          'Bolge Sec ve Indir',
                          style: TextStyle(fontSize: 16),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  final repo = ref.read(settingsRepositoryProvider);
                  await repo.set(SettingsKeys.mapSetupDone, 'skipped');
                  ref.invalidate(turkeyPackInstalledProvider);
                },
                child: Text(
                  'Haritasiz devam et',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
