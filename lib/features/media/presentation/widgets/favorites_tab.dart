import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/core/database/database.dart';
import 'package:drivelink/features/media/data/media_repository.dart';
import 'package:drivelink/features/media/providers/media_providers.dart';
import 'package:drivelink/features/media/presentation/widgets/track_tile.dart';

/// Tab showing all favorited tracks.
class FavoritesTab extends ConsumerWidget {
  const FavoritesTab({
    super.key,
    this.onPlayTracks,
  });

  /// Called when user wants to play a list of tracks starting from an index.
  final void Function(List<MediaTrack> tracks, int startIndex)? onPlayTracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoritesProvider);
    final primary = Theme.of(context).colorScheme.primary;

    return favoritesAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: primary),
      ),
      error: (e, _) => Center(
        child: Text('Hata: $e',
            style: TextStyle(color: AppColors.error)),
      ),
      data: (favorites) {
        if (favorites.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.favorite_border,
                    size: 48, color: AppColors.textDisabled.withAlpha(100)),
                const SizedBox(height: 12),
                Text(
                  'Henuz favori eklenmedi',
                  style: TextStyle(color: AppColors.textDisabled, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sarkilardaki kalp ikonuna dokunun',
                  style: TextStyle(color: AppColors.textDisabled, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Play all favorites button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Text(
                    '${favorites.length} favori',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: favorites.isEmpty
                        ? null
                        : () => onPlayTracks?.call(favorites, 0),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Tumunu Cal'),
                    style: TextButton.styleFrom(
                      foregroundColor: primary,
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: ListView.separated(
                itemCount: favorites.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: AppColors.divider),
                itemBuilder: (context, index) {
                  final track = favorites[index];
                  return TrackTile(
                    track: track,
                    index: index,
                    isCurrent: false,
                    onTap: () => onPlayTracks?.call(favorites, index),
                    onFavoriteToggle: () {
                      ref
                          .read(mediaRepositoryProvider)
                          .toggleFavorite(track.id);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
