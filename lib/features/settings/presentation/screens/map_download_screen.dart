import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/core/services/turkey_package_service.dart'
    show
        ManifestNotPublishedException,
        TurkeyPackInfo,
        TurkeyPackManifest,
        TurkeyPackStatus,
        turkeyPackInfoProvider,
        turkeyPackInstalledProvider,
        turkeyPackageServiceProvider;
import 'package:drivelink/shared/widgets/responsive_page_body.dart';

/// Single-pack Turkey download screen.
///
/// Workflow:
///   1. Fetch remote manifest (version, sizes, SHA-256).
///   2. User taps "İndir" → stream download with progress.
///   3. Verify hashes, atomic install to app documents directory.
///   4. User can uninstall / re-download.
class MapDownloadScreen extends ConsumerStatefulWidget {
  const MapDownloadScreen({super.key});

  @override
  ConsumerState<MapDownloadScreen> createState() => _MapDownloadScreenState();
}

class _MapDownloadScreenState extends ConsumerState<MapDownloadScreen> {
  TurkeyPackManifest? _manifest;
  Object? _manifestError;
  bool _loadingManifest = false;

  StreamSubscription<double>? _downloadSub;
  double _progress = 0;
  bool _downloading = false;
  Object? _downloadError;

  @override
  void initState() {
    super.initState();
    _loadManifest();
  }

  @override
  void dispose() {
    _downloadSub?.cancel();
    super.dispose();
  }

  Future<void> _loadManifest() async {
    setState(() {
      _loadingManifest = true;
      _manifestError = null;
    });
    try {
      final svc = ref.read(turkeyPackageServiceProvider);
      final m = await svc.fetchManifest();
      if (!mounted) return;
      setState(() {
        _manifest = m;
        _loadingManifest = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _manifestError = e;
        _loadingManifest = false;
      });
    }
  }

  Future<void> _startDownload() async {
    final manifest = _manifest;
    if (manifest == null || _downloading) return;

    setState(() {
      _downloading = true;
      _progress = 0;
      _downloadError = null;
    });

    final svc = ref.read(turkeyPackageServiceProvider);
    _downloadSub = svc.download(manifest).listen(
      (p) {
        if (!mounted) return;
        setState(() => _progress = p);
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _downloading = false;
          _downloadError = e;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('İndirme başarısız: $e'),
          backgroundColor: AppColors.error,
        ));
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          _downloading = false;
          _progress = 1.0;
        });
        ref.invalidate(turkeyPackInfoProvider);
        ref.invalidate(turkeyPackInstalledProvider);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Türkiye paketi kuruldu'),
          backgroundColor: AppColors.success,
        ));
      },
    );
  }

  void _cancelDownload() {
    ref.read(turkeyPackageServiceProvider).cancel();
    _downloadSub?.cancel();
    if (mounted) {
      setState(() {
        _downloading = false;
        _progress = 0;
      });
    }
  }

  Future<void> _uninstall() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Paketi Sil',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Türkiye offline paketi (harita + rota + adres) silinecek. '
          'Navigasyon için tekrar indirmen gerekir.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Iptal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    await ref.read(turkeyPackageServiceProvider).uninstall();
    ref.invalidate(turkeyPackInfoProvider);
    ref.invalidate(turkeyPackInstalledProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Paket silindi'),
        backgroundColor: AppColors.success,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final infoAsync = ref.watch(turkeyPackInfoProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Offline Harita', style: TextStyle(fontSize: 16)),
        backgroundColor: AppColors.surface,
      ),
      body: ResponsivePageBody(
        maxWidth: 720,
        child: infoAsync.when(
          data: (info) => _buildBody(info),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text('Durum okunamadı: $e',
                style: TextStyle(color: AppColors.error)),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(TurkeyPackInfo info) {
    final installed = info.status == TurkeyPackStatus.installed;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _PackCard(
          info: info,
          manifest: _manifest,
          loadingManifest: _loadingManifest,
          manifestError: _manifestError,
          downloading: _downloading,
          progress: _progress,
          downloadError: _downloadError,
          onDownload: _manifest == null || installed ? null : _startDownload,
          onCancel: _downloading ? _cancelDownload : null,
          onUninstall: installed && !_downloading ? _uninstall : null,
          onRetryManifest: _manifestError != null ? _loadManifest : null,
        ),
        const SizedBox(height: 24),
        _InfoBox(info: info, manifest: _manifest),
      ],
    );
  }
}

class _PackCard extends StatelessWidget {
  const _PackCard({
    required this.info,
    required this.manifest,
    required this.loadingManifest,
    required this.manifestError,
    required this.downloading,
    required this.progress,
    required this.downloadError,
    required this.onDownload,
    required this.onCancel,
    required this.onUninstall,
    required this.onRetryManifest,
  });

  final TurkeyPackInfo info;
  final TurkeyPackManifest? manifest;
  final bool loadingManifest;
  final Object? manifestError;
  final bool downloading;
  final double progress;
  final Object? downloadError;
  final VoidCallback? onDownload;
  final VoidCallback? onCancel;
  final VoidCallback? onUninstall;
  final VoidCallback? onRetryManifest;

  @override
  Widget build(BuildContext context) {
    final installed = info.status == TurkeyPackStatus.installed;
    final statusLabel = installed
        ? 'Kurulu'
        : downloading
            ? 'Indiriliyor...'
            : 'Kurulu degil';
    final statusColor = installed
        ? AppColors.success
        : downloading
            ? AppColors.primary
            : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: installed ? AppColors.success.withAlpha(60) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                installed ? Icons.map : Icons.map_outlined,
                color: installed ? AppColors.success : AppColors.primary,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Türkiye',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Harita + rota + adres arama',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (loadingManifest) ...[
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ] else if (manifestError is ManifestNotPublishedException) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withAlpha(80)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.hourglass_empty,
                      color: AppColors.warning, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Paket henüz yayınlanmadı',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Türkiye offline paketi GitHub Release olarak '
                          'yayınlandığında buradan indirilebilecek.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onRetryManifest,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Tekrar dene'),
            ),
          ] else if (manifestError != null) ...[
            Text(
              'Paket bilgisi alınamadı: $manifestError',
              style: TextStyle(color: AppColors.error, fontSize: 12),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onRetryManifest,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Tekrar dene'),
            ),
          ] else if (manifest != null) ...[
            _MetaRow(
                label: 'Sürüm',
                value: manifest!.version,
                icon: Icons.sell_outlined),
            _MetaRow(
                label: 'Toplam boyut',
                value: _fmtBytes(manifest!.totalBytes),
                icon: Icons.storage),
            _MetaRow(
                label: 'Yayın tarihi',
                value: _fmtDate(manifest!.generatedAt),
                icon: Icons.calendar_today),
          ],

          if (downloading) ...[
            const SizedBox(height: 16),
            Text(
              '${(progress * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress > 0 ? progress : null,
                backgroundColor: AppColors.surfaceVariant,
                color: AppColors.primary,
                minHeight: 5,
              ),
            ),
          ],

          const SizedBox(height: 20),
          Row(
            children: [
              if (onDownload != null)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onDownload,
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Indir'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              if (onCancel != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.stop, size: 18),
                    label: const Text('Iptal'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              if (onUninstall != null) ...[
                if (onDownload != null || onCancel != null)
                  const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onUninstall,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Sil'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error.withAlpha(100)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textDisabled, size: 14),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              )),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.info, required this.manifest});

  final TurkeyPackInfo info;
  final TurkeyPackManifest? manifest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline,
                  color: AppColors.textSecondary, size: 16),
              const SizedBox(width: 8),
              Text(
                'Paket hakkında',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Bu paket Türkiye\'nin tüm harita kaplamasını, offline rota '
            'hesaplama grafiğini ve adres arama veritabanını içerir. '
            'Bir kez indirildikten sonra internet bağlantısı gerekmez.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
          ),
          if (info.status == TurkeyPackStatus.installed) ...[
            const SizedBox(height: 10),
            Divider(color: AppColors.border, height: 16),
            _MetaRow(
                label: 'Harita (pmtiles)',
                value: _fmtBytes(info.pmtilesSize),
                icon: Icons.map_outlined),
            _MetaRow(
                label: 'Rota grafı',
                value: _fmtBytes(info.graphSize),
                icon: Icons.route),
            _MetaRow(
                label: 'Adres veritabanı',
                value: _fmtBytes(info.addressesSize),
                icon: Icons.search),
            if (info.version != null)
              _MetaRow(
                  label: 'Kurulu sürüm',
                  value: info.version!,
                  icon: Icons.sell_outlined),
            if (info.installedAt != null)
              _MetaRow(
                  label: 'Kurulum tarihi',
                  value: _fmtDate(info.installedAt!),
                  icon: Icons.schedule),
          ],
        ],
      ),
    );
  }
}

String _fmtBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
  return '${(mb / 1024).toStringAsFixed(2)} GB';
}

String _fmtDate(DateTime d) {
  final local = d.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}
