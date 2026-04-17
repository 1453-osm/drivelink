import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/core/database/downloaded_regions_repository.dart';
import 'package:drivelink/core/services/region_coverage_service.dart';
import 'package:drivelink/features/navigation/presentation/widgets/map_widget.dart';
import 'package:drivelink/core/services/offline_map_service.dart';
import 'package:drivelink/features/navigation/data/datasources/nominatim_source.dart';
import 'package:drivelink/features/navigation/data/datasources/osm_tile_source.dart';
import 'package:drivelink/features/settings/data/region_tree.dart';
import 'package:drivelink/shared/widgets/responsive_page_body.dart';

// ─── Providers ───────────────────────────────────────────────────────────

final _nominatimProvider = Provider<NominatimSource>((_) => NominatimSource());
final _downloadingProvider = StateProvider<String?>((_) => null);
final _progressProvider = StateProvider<double>((_) => 0);

final _totalSizeProvider = FutureProvider<double>((ref) async {
  final repo = ref.read(downloadedRegionsRepositoryProvider);
  final regions = await repo.getAll();
  return regions.fold<double>(0, (sum, r) => sum + r.sizeKiB);
});

final _downloadedProvider = FutureProvider<List<DownloadedRegion>>((ref) async {
  final repo = ref.read(downloadedRegionsRepositoryProvider);
  return repo.getAll();
});

// ─── Screen ──────────────────────────────────────────────────────────────

class MapDownloadScreen extends ConsumerStatefulWidget {
  const MapDownloadScreen({super.key});

  @override
  ConsumerState<MapDownloadScreen> createState() => _MapDownloadScreenState();
}

class _MapDownloadScreenState extends ConsumerState<MapDownloadScreen> {
  // Navigation path through the tree.
  final List<RegionNode> _path = [];

  // Search state.
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<_SearchResult> _searchResults = [];
  bool _isSearching = false;
  bool _searchMode = false;

  List<RegionNode> get _currentChildren =>
      _path.isEmpty ? regionTree : (_path.last.children ?? []);

  String get _title {
    if (_searchMode) return 'Bolge Ara';
    if (_path.isEmpty) return 'Offline Haritalar';
    return _path.map((n) => n.name).join(' > ');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _pushNode(RegionNode node) {
    if (node.isLeaf) return;
    setState(() {
      _path.add(node);
      _searchMode = false;
    });
  }

  void _popNode() {
    if (_searchMode) {
      setState(() {
        _searchMode = false;
        _searchCtrl.clear();
        _searchResults = [];
      });
      return;
    }
    if (_path.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _path.removeLast());
  }

  void _toggleSearch() {
    setState(() {
      _searchMode = !_searchMode;
      if (!_searchMode) {
        _searchCtrl.clear();
        _searchResults = [];
      }
    });
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () => _doSearch(q));
  }

  Future<void> _doSearch(String q) async {
    setState(() => _isSearching = true);
    final query = q.trim().toLowerCase();

    // 1. Local tree search.
    final local = <_SearchResult>[];
    void walkTree(List<RegionNode> nodes, String path) {
      for (final n in nodes) {
        if (n.name.toLowerCase().contains(query)) {
          local.add(_SearchResult(name: n.name, subtitle: path, node: n));
        }
        if (n.children != null) {
          walkTree(n.children!, path.isEmpty ? n.name : '$path > ${n.name}');
        }
      }
    }

    walkTree(regionTree, '');

    // 2. Nominatim remote search.
    final nominatim = ref.read(_nominatimProvider);
    final remotePlaces = await nominatim.searchPlaces(q, limit: 8);
    final remote = remotePlaces.map((p) {
      final parts = p.displayName.split(',').map((s) => s.trim()).toList();
      final shortName = parts.first;
      final sub = parts.length > 1 ? parts.sublist(1).join(', ') : p.type;

      final latSpan = (p.north - p.south).abs();
      final lngSpan = (p.east - p.west).abs();
      final area = latSpan * lngSpan;
      int minZ, maxZ;
      String est;
      if (area > 100) {
        minZ = 3;
        maxZ = 8;
        est = '~3+ GB';
      } else if (area > 20) {
        minZ = 4;
        maxZ = 10;
        est = '~2+ GB';
      } else if (area > 5) {
        minZ = 5;
        maxZ = 10;
        est = '~1-2 GB';
      } else if (area > 1) {
        minZ = 6;
        maxZ = 12;
        est = '~500 MB-1 GB';
      } else if (area > 0.1) {
        minZ = 8;
        maxZ = 14;
        est = '~100-400 MB';
      } else {
        minZ = 10;
        maxZ = 16;
        est = '~20-100 MB';
      }

      return _SearchResult(
        name: shortName,
        subtitle: sub,
        node: RegionNode(
          name: shortName,
          north: p.north,
          south: p.south,
          east: p.east,
          west: p.west,
          minZoom: minZ,
          maxZoom: maxZ,
          estimatedSize: est,
        ),
      );
    }).toList();

    if (!mounted) return;
    setState(() {
      // Merge: locals first, then remote (deduplicated).
      final seen = local.map((r) => r.name.toLowerCase()).toSet();
      _searchResults = [
        ...local,
        ...remote.where((r) => !seen.contains(r.name.toLowerCase())),
      ];
      _isSearching = false;
    });
  }

  void _refresh() {
    ref.invalidate(_downloadedProvider);
    ref.invalidate(_totalSizeProvider);
    ref.invalidate(downloadedRegionsListProvider);
    ref.invalidate(hasDownloadedRegionsProvider);
    // Clear repository cache so fresh data is read.
    ref.read(downloadedRegionsRepositoryProvider).clearCache();
  }

  // ─── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final downloading = ref.watch(_downloadingProvider);
    final progress = ref.watch(_progressProvider);
    final totalAsync = ref.watch(_totalSizeProvider);
    final downloadedAsync = ref.watch(_downloadedProvider);

    final downloadedStores = <String>{};
    downloadedAsync.whenData((list) {
      for (final r in list) {
        downloadedStores.add(r.storeName);
      }
    });

    return PopScope(
      canPop: _path.isEmpty && !_searchMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _popNode();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            _title,
            style: const TextStyle(fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: AppColors.surface,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _popNode,
          ),
          actions: [
            IconButton(
              icon: Icon(_searchMode ? Icons.close : Icons.search),
              tooltip: _searchMode ? 'Kapat' : 'Ara',
              onPressed: _toggleSearch,
            ),
          ],
        ),
        body: ResponsivePageBody(
          maxWidth: 1280,
          child: Column(
            children: [
              // Search bar (only in search mode).
              if (_searchMode)
                Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    onChanged: _onSearchChanged,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ulke, sehir veya bolge...',
                      hintStyle: TextStyle(
                        color: AppColors.textDisabled,
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      isDense: true,
                    ),
                  ),
                ),

              if (_isSearching)
                LinearProgressIndicator(
                  backgroundColor: AppColors.surface,
                  color: AppColors.primary,
                  minHeight: 2,
                ),

              // Content.
              Expanded(
                child: _searchMode
                    ? _buildSearchResults(
                        downloading,
                        progress,
                        downloadedStores,
                      )
                    : _buildTreeView(
                        downloading,
                        progress,
                        downloadedAsync,
                        downloadedStores,
                      ),
              ),

              // Bottom bar.
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: _BottomBar(totalAsync: totalAsync, onClear: _clearAll),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Tree view ─────────────────────────────────────────────────────

  Widget _buildTreeView(
    String? downloading,
    double progress,
    AsyncValue<List<DownloadedRegion>> downloadedAsync,
    Set<String> downloadedStores,
  ) {
    final children = _currentChildren;

    // If at root, show downloaded regions at top.
    final showDownloaded = _path.isEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
      children: [
        // Downloaded regions section (root only).
        if (showDownloaded)
          downloadedAsync.when(
            data: (list) {
              if (list.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel(
                    icon: Icons.download_done,
                    text: 'Indirilenler',
                  ),
                  ...list.map(
                    (r) => _DownloadedTile(
                      region: r,
                      onDelete: () => _deleteRegion(r),
                    ),
                  ),
                  Divider(color: AppColors.divider),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

        // Tree nodes.
        ...children.map((node) {
          if (node.isLeaf && node.isDownloadable) {
            final storeName =
                'region_${OsmTileSource.normalizeRegionName(node.name)}';
            final isDownloaded = downloadedStores.contains(storeName);
            final isDownloading = downloading == node.name;
            return _LeafTile(
              node: node,
              isDownloaded: isDownloaded,
              isDownloading: isDownloading,
              progress: isDownloading ? progress : 0,
              onDownload: downloading == null && !isDownloaded
                  ? () => _downloadNode(node)
                  : null,
            );
          }
          // Folder node.
          return _FolderTile(
            node: node,
            childCount: node.children?.length ?? 0,
            onTap: () => _pushNode(node),
          );
        }),
      ],
    );
  }

  // ─── Search results ────────────────────────────────────────────────

  Widget _buildSearchResults(
    String? downloading,
    double progress,
    Set<String> downloadedStores,
  ) {
    if (_searchResults.isEmpty && !_isSearching) {
      return Center(
        child: Text(
          _searchCtrl.text.length < 2
              ? 'En az 2 karakter yazin'
              : 'Sonuc bulunamadi',
          style: TextStyle(color: AppColors.textDisabled),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
      itemCount: _searchResults.length,
      itemBuilder: (_, i) {
        final r = _searchResults[i];
        final node = r.node;

        if (!node.isLeaf) {
          return _FolderTile(
            node: node,
            subtitle: r.subtitle,
            childCount: node.children?.length ?? 0,
            onTap: () {
              setState(() {
                _searchMode = false;
                _searchCtrl.clear();
                _searchResults = [];
                _path.clear();
                // Navigate to this folder's parent path (simplified: just push it)
                _path.add(node);
              });
            },
          );
        }

        final storeName =
            'region_${OsmTileSource.normalizeRegionName(node.name)}';
        final isDownloaded = downloadedStores.contains(storeName);
        final isDownloading = downloading == node.name;
        return _LeafTile(
          node: node,
          subtitle: r.subtitle,
          isDownloaded: isDownloaded,
          isDownloading: isDownloading,
          progress: isDownloading ? progress : 0,
          onDownload: downloading == null && !isDownloaded
              ? () => _downloadNode(node)
              : null,
        );
      },
    );
  }

  // ─── Actions ───────────────────────────────────────────────────────

  Future<void> _downloadNode(RegionNode node) async {
    if (!node.isDownloadable) return;
    ref.read(_downloadingProvider.notifier).state = node.name;
    ref.read(_progressProvider.notifier).state = 0;

    try {
      final svc = ref.read(offlineMapServiceProvider);
      final stream = svc.downloadRegion(
        regionName: node.name,
        north: node.north!,
        south: node.south!,
        east: node.east!,
        west: node.west!,
        minZoom: node.minZoom!.toDouble(),
        maxZoom: node.maxZoom!.toDouble(),
      );

      await for (final p in stream) {
        if (!mounted) return;
        ref.read(_progressProvider.notifier).state = p;
      }

      const sizeKiB = 0.0; // MapLibre doesn't expose per-region size

      // Determine subtitle from path.
      final sub = _path.map((n) => n.name).join(', ');

      final repo = ref.read(downloadedRegionsRepositoryProvider);
      await repo.add(
        DownloadedRegion(
          name: node.name,
          subtitle: sub,
          north: node.north!,
          south: node.south!,
          east: node.east!,
          west: node.west!,
          minZoom: node.minZoom!,
          maxZoom: node.maxZoom!,
          downloadedAt: DateTime.now(),
          sizeKiB: sizeKiB,
        ),
      );

      // Invalidate onboarding + coverage providers.
      ref.invalidate(hasDownloadedRegionsProvider);
      ref.invalidate(downloadedRegionsListProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${node.name} indirildi'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Indirme basarisiz: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        ref.read(_downloadingProvider.notifier).state = null;
        ref.read(_progressProvider.notifier).state = 0;
        _refresh();
      }
    }
  }

  Future<void> _deleteRegion(DownloadedRegion region) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Bolgeyi Sil',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          '${region.name} silinecek.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Iptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final svc = ref.read(offlineMapServiceProvider);
    await svc.deleteRegionByName(region.name);
    final repo = ref.read(downloadedRegionsRepositoryProvider);
    await repo.remove(region.storeName);
    _refresh();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${region.name} silindi'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _clearAll() async {
    final list = ref.read(_downloadedProvider).valueOrNull ?? [];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Hepsini Sil',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          list.isEmpty
              ? 'Onbellek temizlenecek.'
              : '${list.length} bolge ve onbellek silinecek.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Iptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Hepsini Sil'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final svc = ref.read(offlineMapServiceProvider);
    await svc.deleteAll();
    final repo = ref.read(downloadedRegionsRepositoryProvider);
    await repo.removeAll();
    _refresh();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tum veriler silindi'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }
}

// ─── Widgets ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Folder node — navigates deeper.
class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required this.node,
    required this.childCount,
    required this.onTap,
    this.subtitle,
  });

  final RegionNode node;
  final int childCount;
  final VoidCallback onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppColors.border),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: Icon(
          Icons.folder_outlined,
          color: AppColors.primary,
          size: 22,
        ),
        title: Text(
          node.name,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle ?? '$childCount bolge',
          style: TextStyle(color: AppColors.textDisabled, fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: AppColors.textSecondary,
          size: 20,
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Downloadable leaf node.
class _LeafTile extends StatelessWidget {
  const _LeafTile({
    required this.node,
    required this.isDownloaded,
    required this.isDownloading,
    required this.progress,
    required this.onDownload,
    this.subtitle,
  });

  final RegionNode node;
  final bool isDownloaded;
  final bool isDownloading;
  final double progress;
  final VoidCallback? onDownload;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isDownloaded
              ? AppColors.success.withAlpha(60)
              : AppColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  isDownloaded ? Icons.map_rounded : Icons.map_outlined,
                  color: isDownloaded
                      ? AppColors.success
                      : AppColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.name,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty)
                        Text(
                          subtitle!,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      Text(
                        '${node.estimatedSize ?? "?"}  •  Zoom ${node.minZoom}-${node.maxZoom}',
                        style: TextStyle(
                          color: AppColors.textDisabled,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isDownloaded)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Indirildi',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else if (isDownloading)
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: CircularProgressIndicator(
                        value: progress > 0 ? progress : null,
                        strokeWidth: 2.5,
                        color: AppColors.primary,
                      ),
                    ),
                  )
                else
                  IconButton(
                    onPressed: onDownload,
                    icon: Icon(
                      Icons.download_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
              ],
            ),
            if (isDownloading) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress > 0 ? progress : null,
                  backgroundColor: AppColors.surfaceVariant,
                  color: AppColors.primary,
                  minHeight: 3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Downloaded region tile with mini map preview.
class _DownloadedTile extends StatelessWidget {
  const _DownloadedTile({required this.region, required this.onDelete});

  final DownloadedRegion region;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final center = ml.LatLng(
      (region.north + region.south) / 2,
      (region.east + region.west) / 2,
    );
    // Estimate zoom from bounding box span.
    final latSpan = (region.north - region.south).abs();
    final zoom = latSpan > 10
        ? 4.0
        : latSpan > 3
        ? 6.0
        : latSpan > 1
        ? 8.0
        : 10.0;

    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.success.withAlpha(50)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            // Mini map preview.
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 64,
                height: 64,
                child: IgnorePointer(
                  child: MapWidget(
                    center: center,
                    zoom: zoom,
                    interactive: false,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Info.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    region.name,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (region.subtitle.isNotEmpty)
                    Text(
                      region.subtitle,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 2),
                  Text(
                    '${region.formattedSize}  •  Zoom ${region.minZoom}-${region.maxZoom}',
                    style: TextStyle(
                      color: AppColors.textDisabled,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: Icon(
                Icons.delete_outline,
                color: AppColors.error,
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom bar — total size + clear all.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.totalAsync, required this.onClear});

  final AsyncValue<double> totalAsync;
  final VoidCallback onClear;

  String _fmt(double kb) {
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    return '${(mb / 1024).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.storage, color: AppColors.primary, size: 16),
        const SizedBox(width: 6),
        Text(
          'Toplam: ',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        totalAsync.when(
          data: (s) => Text(
            _fmt(s),
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          loading: () => const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
          error: (_, __) => Text(
            'N/A',
            style: TextStyle(color: AppColors.textDisabled, fontSize: 12),
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: onClear,
          icon: const Icon(Icons.delete_sweep_outlined, size: 14),
          label: const Text('Hepsini Sil', style: TextStyle(fontSize: 11)),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.error,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
      ],
    );
  }
}

// ─── Search result model ─────────────────────────────────────────────────

class _SearchResult {
  final String name;
  final String subtitle;
  final RegionNode node;

  const _SearchResult({
    required this.name,
    required this.subtitle,
    required this.node,
  });
}
