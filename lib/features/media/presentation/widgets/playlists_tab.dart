import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/core/database/database.dart';
import 'package:drivelink/features/media/data/media_repository.dart';
import 'package:drivelink/features/media/providers/media_providers.dart';
import 'package:drivelink/features/media/presentation/widgets/track_tile.dart';

/// Tab showing user-created playlists and their management.
class PlaylistsTab extends ConsumerStatefulWidget {
  const PlaylistsTab({
    super.key,
    this.onPlayTracks,
  });

  final void Function(List<MediaTrack> tracks, int startIndex)? onPlayTracks;

  @override
  ConsumerState<PlaylistsTab> createState() => _PlaylistsTabState();
}

class _PlaylistsTabState extends ConsumerState<PlaylistsTab> {
  int? _expandedPlaylistId;

  @override
  Widget build(BuildContext context) {
    final playlistsAsync = ref.watch(playlistsProvider);
    final primary = Theme.of(context).colorScheme.primary;

    return playlistsAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: primary),
      ),
      error: (e, _) => Center(
        child: Text('Hata: $e',
            style: TextStyle(color: AppColors.error)),
      ),
      data: (playlists) {
        return Column(
          children: [
            // Header with create button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
              child: Row(
                children: [
                  Text(
                    '${playlists.length} liste',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.add_rounded, color: primary, size: 22),
                    onPressed: () => _showCreateDialog(context),
                    splashRadius: 20,
                    tooltip: 'Yeni Liste',
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: playlists.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.queue_music,
                              size: 48,
                              color:
                                  AppColors.textDisabled.withAlpha(100)),
                          const SizedBox(height: 12),
                          Text(
                            'Henuz liste olusturulmadi',
                            style: TextStyle(
                                color: AppColors.textDisabled, fontSize: 14),
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: () => _showCreateDialog(context),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Yeni Liste Olustur'),
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: playlists.length,
                      itemBuilder: (context, index) {
                        final playlist = playlists[index];
                        final isExpanded =
                            _expandedPlaylistId == playlist.id;
                        return _PlaylistCard(
                          playlist: playlist,
                          isExpanded: isExpanded,
                          onToggleExpand: () {
                            setState(() {
                              _expandedPlaylistId =
                                  isExpanded ? null : playlist.id;
                            });
                          },
                          onDelete: () => _confirmDelete(context, playlist),
                          onRename: () =>
                              _showRenameDialog(context, playlist),
                          onPlayTracks: widget.onPlayTracks,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final primary = Theme.of(context).colorScheme.primary;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Yeni Liste',
            style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Liste adi',
            hintStyle: TextStyle(color: AppColors.textDisabled),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.divider),
            ),
            focusedBorder:
                UnderlineInputBorder(borderSide: BorderSide(color: primary)),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Iptal',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text('Olustur', style: TextStyle(color: primary)),
          ),
        ],
      ),
    );

    if (name != null && name.trim().isNotEmpty) {
      await ref.read(mediaRepositoryProvider).createPlaylist(name.trim());
    }
  }

  Future<void> _showRenameDialog(
      BuildContext context, MediaPlaylist playlist) async {
    final primary = Theme.of(context).colorScheme.primary;
    final controller = TextEditingController(text: playlist.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Listeyi Yeniden Adlandir',
            style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.divider),
            ),
            focusedBorder:
                UnderlineInputBorder(borderSide: BorderSide(color: primary)),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Iptal',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text('Kaydet', style: TextStyle(color: primary)),
          ),
        ],
      ),
    );

    if (name != null && name.trim().isNotEmpty) {
      await ref
          .read(mediaRepositoryProvider)
          .renamePlaylist(playlist.id, name.trim());
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, MediaPlaylist playlist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Listeyi Sil',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          '"${playlist.name}" listesi silinecek. Sarkilar kutuphaneden silinmez.',
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

    if (confirmed == true) {
      await ref.read(mediaRepositoryProvider).deletePlaylist(playlist.id);
      if (_expandedPlaylistId == playlist.id) {
        setState(() => _expandedPlaylistId = null);
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Playlist card with expandable track list
// ---------------------------------------------------------------------------

class _PlaylistCard extends ConsumerWidget {
  const _PlaylistCard({
    required this.playlist,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onDelete,
    required this.onRename,
    this.onPlayTracks,
  });

  final MediaPlaylist playlist;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onDelete;
  final VoidCallback onRename;
  final void Function(List<MediaTrack> tracks, int startIndex)? onPlayTracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      children: [
        ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: primary.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.queue_music, color: primary, size: 22),
          ),
          title: Text(
            playlist.name,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isExpanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                color: AppColors.textSecondary,
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert,
                    color: AppColors.textSecondary, size: 20),
                color: AppColors.surface,
                onSelected: (value) {
                  if (value == 'rename') onRename();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'rename',
                    child: Text('Yeniden Adlandir',
                        style: TextStyle(color: AppColors.textPrimary)),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Sil',
                        style: TextStyle(color: AppColors.error)),
                  ),
                ],
              ),
            ],
          ),
          onTap: onToggleExpand,
          contentPadding: const EdgeInsets.only(left: 16, right: 4),
        ),
        if (isExpanded) _PlaylistTrackList(
          playlistId: playlist.id,
          onPlayTracks: onPlayTracks,
        ),
        Divider(height: 1, color: AppColors.divider),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Expanded track list for a playlist
// ---------------------------------------------------------------------------

class _PlaylistTrackList extends ConsumerWidget {
  const _PlaylistTrackList({
    required this.playlistId,
    this.onPlayTracks,
  });

  final int playlistId;
  final void Function(List<MediaTrack> tracks, int startIndex)? onPlayTracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracksAsync = ref.watch(playlistTracksProvider(playlistId));
    final primary = Theme.of(context).colorScheme.primary;

    return tracksAsync.when(
      loading: () => Padding(
        padding: EdgeInsets.all(16),
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
      data: (entries) {
        if (entries.isEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'Bu liste bos',
                style: TextStyle(color: AppColors.textDisabled, fontSize: 13),
              ),
            ),
          );
        }

        final tracks = entries.map((e) => e.track).toList();

        return Container(
          color: AppColors.background,
          child: Column(
            children: [
              // Play all button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      '${entries.length} parca',
                      style: TextStyle(
                          color: AppColors.textDisabled, fontSize: 12),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => onPlayTracks?.call(tracks, 0),
                      icon: const Icon(Icons.play_arrow_rounded, size: 16),
                      label: const Text('Cal'),
                      style: TextButton.styleFrom(
                        foregroundColor: primary,
                        textStyle: const TextStyle(fontSize: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),
              ),
              ...entries.map((entry) {
                final idx = entries.indexOf(entry);
                return TrackTile(
                  track: entry.track,
                  index: idx,
                  onTap: () => onPlayTracks?.call(tracks, idx),
                  onLongPress: () {
                    // Remove from playlist
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColors.surface,
                        title: Text('Listeden Cikar',
                            style: TextStyle(color: AppColors.textPrimary)),
                        content: Text(
                          '"${entry.track.title}" listeden cikarilsin mi?',
                          style:
                              TextStyle(color: AppColors.textSecondary),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: Text('Iptal',
                                style: TextStyle(
                                    color: AppColors.textSecondary)),
                          ),
                          TextButton(
                            onPressed: () {
                              ref
                                  .read(mediaRepositoryProvider)
                                  .removeFromPlaylist(entry.entry.id);
                              Navigator.of(ctx).pop();
                            },
                            child: Text('Cikar',
                                style: TextStyle(color: AppColors.error)),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
