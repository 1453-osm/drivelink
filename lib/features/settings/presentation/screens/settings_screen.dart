import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:drivelink/app/router.dart';
import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/shared/widgets/responsive_page_body.dart';

/// Top-level settings screen — lists all configurable areas.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ayarlar'),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Geri',
                onPressed: () => context.pop(),
              )
            : null,
      ),
      body: ResponsivePageBody(
        maxWidth: 960,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            // ── Arac ──────────────────────────────────────────────────────
            const _SectionHeader(title: 'Arac'),
            _SettingsTile(
              icon: Icons.directions_car,
              title: 'Arac Profili',
              subtitle: 'VAN/OBD parametreleri icin arac modelinizi secin',
              onTap: () => context.push(AppRoutes.vehicleConfig),
            ),
            _SettingsTile(
              icon: Icons.usb,
              title: 'USB Yapilandirma',
              subtitle: 'Port atama, baud hizi, baglanti testi',
              onTap: () => context.push(AppRoutes.usbConfig),
            ),

            const SizedBox(height: 4),

            // ── Gorunum ───────────────────────────────────────────────────
            const _SectionHeader(title: 'Gorunum'),
            _SettingsTile(
              icon: Icons.palette_outlined,
              title: 'Tema',
              subtitle: 'Parlaklik, vurgu rengi',
              onTap: () => context.push(AppRoutes.themeConfig),
            ),

            const SizedBox(height: 4),

            // ── Haritalar ─────────────────────────────────────────────────
            const _SectionHeader(title: 'Haritalar'),
            _SettingsTile(
              icon: Icons.download_outlined,
              title: 'Cevrimdisi Harita',
              subtitle: 'Cevrimdisi kullanim icin harita indirin',
              onTap: () => context.push(AppRoutes.mapDownload),
            ),

            const SizedBox(height: 4),

            // ── Yapay Zeka ────────────────────────────────────────────────
            const _SectionHeader(title: 'Yapay Zeka'),
            _SettingsTile(
              icon: Icons.smart_toy_outlined,
              title: 'AI Asistan',
              subtitle: 'Ses tanima, wake word, LLM model yukle',
              onTap: () => context.push(AppRoutes.aiSettings),
            ),

            const SizedBox(height: 4),

            // ── Hakkinda ──────────────────────────────────────────────────
            const _SectionHeader(title: 'Hakkinda'),
            _SettingsTile(
              icon: Icons.info_outline,
              title: 'DriveLink Hakkinda',
              subtitle: 'Surum 1.0.0 — acik kaynakli arac bilgi-eglence',
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'DriveLink',
                  applicationVersion: '1.0.0',
                  applicationLegalese: 'GPL v3.0',
                  children: [
                    const SizedBox(height: 16),
                    const Text(
                      'Aracınız için açık kaynaklı bilgi-eğlence sistemi. '
                      'Çevrimdışı haritalar, OBD-II araç teşhisi, '
                      'VAN/CAN bus desteği ve daha fazlası.',
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return ListTile(
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: primary.withAlpha(12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primary.withAlpha(25)),
          boxShadow: [BoxShadow(color: primary.withAlpha(15), blurRadius: 12)],
        ),
        child: Icon(icon, color: primary, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: AppColors.textDisabled, fontSize: 12),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textDisabled.withAlpha(160),
        size: 20,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
