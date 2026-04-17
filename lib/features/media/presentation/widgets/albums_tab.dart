import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/core/database/database.dart';
import 'package:drivelink/features/media/data/media_repository.dart';
import 'package:drivelink/features/media/providers/media_providers.dart';
import 'package:drivelink/features/media/presentation/widgets/track_edit_dialog.dart';
import 'package:drivelink/features/media/presentation/widgets/track_tile.dart';
import 'package:drivelink/shared/widgets/glass_panel.dart';

/// Tab showing albums (including M3U-imported ones) with create/edit/delete.
class AlbumsTab extends ConsumerStatefulWidget {
  const AlbumsTab({super.key, this.onPlayTracks});

  final void Function(List<MediaTrack> tracks, int startIndex)? onPlayTracks;

  @override
  ConsumerState<AlbumsTab> createState() => _AlbumsTabState();
}

class _AlbumsTabState extends ConsumerState<AlbumsTab> {
  int? _expandedAlbumId;

  @override
  Widget build(BuildContext context) {
    final albumsAsync = ref.watch(albumsProvider);
    final primary = Theme.of(context).colorScheme.primary;
    final primaryGlow = Color.lerp(primary, Colors.white, 0.18)!;

    return albumsAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: primary),
      ),
      error: (e, _) => Center(
        child: Text('Hata: $e',
            style: TextStyle(color: AppColors.error)),
      ),
      data: (albums) {
        if (albums.isEmpty) return _empty(context);

        final expanded = _expandedAlbumId == null
            ? null
            : albums.firstWhere(
                (a) => a.id == _expandedAlbumId,
                orElse: () => albums.first,
              );

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 16,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [primaryGlow, primary],
                        ),
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withAlpha(140),
                            blurRadius: 8,
                            spreadRadius: -1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${albums.length} album',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const Spacer(),
                    Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _showEditDialog(context, null),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: primary.withAlpha(22),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: primary.withAlpha(80),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, size: 16, color: primary),
                              const SizedBox(width: 4),
                              Text(
                                'Yeni',
                                style: TextStyle(
                                  color: primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.82,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final album = albums[index];
                    final isExpanded = _expandedAlbumId == album.id;
                    return _AlbumGridCard(
                      album: album,
                      isExpanded: isExpanded,
                      onTap: () {
                        setState(() {
                          _expandedAlbumId =
                              isExpanded ? null : album.id;
                        });
                      },
                      onEdit: () => _showEditDialog(context, album),
                      onDelete: () => _confirmDelete(context, album),
                    );
                  },
                  childCount: albums.length,
                ),
              ),
            ),
            if (expanded != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  child: _AlbumTrackList(
                    albumId: expanded.id,
                    albumName: expanded.name,
                    onPlayTracks: widget.onPlayTracks,
                  ),
                ),
              )
            else
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        );
      },
    );
  }

  Widget _empty(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final primaryGlow = Color.lerp(primary, Colors.white, 0.18)!;

    return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    primary.withAlpha(30),
                    primary.withAlpha(6),
                  ],
                ),
                border: Border.all(
                  color: primary.withAlpha(60),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primary.withAlpha(40),
                    blurRadius: 24,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Icon(Icons.album, size: 40, color: primary),
            ),
            const SizedBox(height: 20),
            Text(
              'Henuz album yok',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'M3U listesi tarayin ya da yeni album olusturun',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showEditDialog(context, null),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryGlow, primary],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withAlpha(120),
                        blurRadius: 16,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: Colors.white, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Yeni Album Olustur',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
  }

  Future<void> _showEditDialog(
      BuildContext context, MediaAlbum? existing) async {
    final primary = Theme.of(context).colorScheme.primary;
    final nameCtl = TextEditingController(text: existing?.name ?? '');
    String? cover = existing?.coverArt;

    Future<void> pickCover(StateSetter setDialogState) async {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.single.path;
      if (path == null) return;
      setDialogState(() => cover = path);
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            existing == null ? 'Yeni Album' : 'Albumu Duzenle',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => pickCover(setDialogState),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    image: _imageFor(cover),
                  ),
                  child: cover == null || !File(cover!).existsSync()
                      ? Icon(Icons.add_photo_alternate,
                          color: AppColors.textDisabled, size: 40)
                      : null,
                ),
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: () => pickCover(setDialogState),
                icon: const Icon(Icons.image, size: 16),
                label: const Text('Kapak Sec'),
                style: TextButton.styleFrom(
                  foregroundColor: primary,
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
              TextField(
                controller: nameCtl,
                autofocus: existing == null,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Album adi',
                  hintStyle: TextStyle(color: AppColors.textDisabled),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder:
                      UnderlineInputBorder(borderSide: BorderSide(color: primary)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Iptal',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Kaydet', style: TextStyle(color: primary)),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    final name = nameCtl.text.trim();
    if (name.isEmpty) return;

    final repo = ref.read(mediaRepositoryProvider);
    if (existing == null) {
      await repo.createAlbum(name, coverArt: cover);
    } else {
      await repo.updateAlbum(
        existing.id,
        name: name,
        coverArt: cover,
        clearCoverArt: cover == null,
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, MediaAlbum album) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Albumu Sil',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          '"${album.name}" albumu silinecek. Sarkilar kutuphaneden silinmez.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Iptal',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child:
                Text('Sil', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(mediaRepositoryProvider).deleteAlbum(album.id);
    if (_expandedAlbumId == album.id) {
      setState(() => _expandedAlbumId = null);
    }
  }
}

DecorationImage? _imageFor(String? path) {
  if (path == null || path.isEmpty) return null;
  final f = File(path);
  if (!f.existsSync()) return null;
  return DecorationImage(image: FileImage(f), fit: BoxFit.cover);
}

// ---------------------------------------------------------------------------
// Album grid card with big cover art
// ---------------------------------------------------------------------------

class _AlbumGridCard extends ConsumerWidget {
  const _AlbumGridCard({
    required this.album,
    required this.isExpanded,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final MediaAlbum album;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    final trackCount =
        ref.watch(albumTracksProvider(album.id)).valueOrNull?.length ?? 0;
    final cover = album.coverArt;
    final hasCover = cover != null && File(cover).existsSync();

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isExpanded
                ? primary.withAlpha(160)
                : primary.withAlpha(28),
            width: isExpanded ? 1.5 : 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: primary
                  .withAlpha(isExpanded ? 100 : 30),
              blurRadius: isExpanded ? 24 : 14,
              spreadRadius: isExpanded ? -2 : -6,
            ),
            const BoxShadow(
              color: Colors.black45,
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              // Cover fills the whole card
              Positioned.fill(
                child: hasCover
                    ? Image.file(File(cover), fit: BoxFit.cover)
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.surfaceBright,
                              AppColors.surfaceVariant,
                              AppColors.surface,
                            ],
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.album,
                            size: 64,
                            color: primary.withAlpha(120),
                          ),
                        ),
                      ),
              ),
              // Gradient overlay for text readability
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Color(0xCC000000),
                        Color(0xEE000000),
                      ],
                      stops: [0.0, 0.4, 0.75, 1.0],
                    ),
                  ),
                ),
              ),
              // More menu top-right
              Positioned(
                top: 4,
                right: 0,
                child: PopupMenuButton<String>(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(120),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.more_vert,
                        color: Colors.white, size: 16),
                  ),
                  color: AppColors.surface,
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text('Duzenle',
                          style: TextStyle(color: AppColors.textPrimary)),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Sil',
                          style: TextStyle(color: AppColors.error)),
                    ),
                  ],
                ),
              ),
              // Expanded indicator
              if (isExpanded)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withAlpha(140),
                          blurRadius: 10,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.visibility,
                            color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'Acik',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Bottom text
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      album.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        shadows: [
                          Shadow(blurRadius: 4, color: Colors.black54),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$trackCount parca',
                      style: TextStyle(
                        color: Colors.white.withAlpha(200),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Expanded track list for an album — glass panel card
// ---------------------------------------------------------------------------

class _AlbumTrackList extends ConsumerWidget {
  const _AlbumTrackList({
    required this.albumId,
    required this.albumName,
    this.onPlayTracks,
  });

  final int albumId;
  final String albumName;
  final void Function(List<MediaTrack> tracks, int startIndex)? onPlayTracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracksAsync = ref.watch(albumTracksProvider(albumId));
    final primary = Theme.of(context).colorScheme.primary;
    final primaryGlow = Color.lerp(primary, Colors.white, 0.18)!;

    return GlassPanel(
      borderRadius: 18,
      glowIntensity: 0.08,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: tracksAsync.when(
        loading: () => Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: CircularProgressIndicator(
                strokeWidth: 2, color: primary),
          ),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Hata: $e',
              style: TextStyle(color: AppColors.error)),
        ),
        data: (tracks) {
          if (tracks.isEmpty) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Bu album bos',
                  style:
                      TextStyle(color: AppColors.textDisabled, fontSize: 13),
                ),
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(20, 10, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            albumName,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${tracks.length} parca',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => onPlayTracks?.call(tracks, 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                primaryGlow,
                                primary,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: primary.withAlpha(140),
                                blurRadius: 14,
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow,
                                  color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Cal',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
              ...tracks.asMap().entries.map((e) {
                final idx = e.key;
                final track = e.value;
                return TrackTile(
                  track: track,
                  index: idx,
                  onTap: () => onPlayTracks?.call(tracks, idx),
                  onLongPress: () =>
                      TrackEditDialog.show(context, track),
                );
              }),
              const SizedBox(height: 6),
            ],
          );
        },
      ),
    );
  }
}
