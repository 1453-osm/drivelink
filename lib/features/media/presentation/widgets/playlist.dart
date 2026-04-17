import 'package:flutter/material.dart';

import 'package:drivelink/app/theme/colors.dart';

/// A single track entry in the playlist.
class PlaylistItem {
  const PlaylistItem({
    required this.title,
    required this.artist,
    this.duration = Duration.zero,
    this.isFavorite = false,
    this.isAvailable = true,
    this.trackId,
  });

  final String title;
  final String artist;
  final Duration duration;
  final bool isFavorite;
  final bool isAvailable;
  final int? trackId;
}

/// Scrollable playlist / queue view.
///
/// Highlights the currently playing track and calls [onSelect] when the user
/// taps a different track.
class Playlist extends StatelessWidget {
  const Playlist({
    super.key,
    required this.items,
    this.currentIndex = 0,
    this.onSelect,
    this.onFavoriteToggle,
    this.onLongPress,
  });

  final List<PlaylistItem> items;
  final int currentIndex;
  final ValueChanged<int>? onSelect;
  final ValueChanged<int>? onFavoriteToggle;
  final ValueChanged<int>? onLongPress;

  String _formatDuration(Duration d) {
    if (d == Duration.zero) return '';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Calma listesi bos',
          style: TextStyle(color: AppColors.textDisabled),
        ),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: AppColors.divider),
      itemBuilder: (context, index) {
        final item = items[index];
        final isCurrent = index == currentIndex;
        final available = item.isAvailable;

        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: !available
                  ? AppColors.error.withAlpha(20)
                  : isCurrent
                      ? AppColors.primary.withAlpha(30)
                      : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: !available
                  ? Icon(Icons.error_outline,
                      color: AppColors.error, size: 18)
                  : isCurrent
                      ? Icon(Icons.equalizer,
                          color: AppColors.primary, size: 20)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: AppColors.textDisabled,
                            fontSize: 14,
                          ),
                        ),
            ),
          ),
          title: Text(
            item.title,
            style: TextStyle(
              color: !available
                  ? AppColors.textDisabled
                  : isCurrent
                      ? AppColors.primary
                      : AppColors.textPrimary,
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            available
                ? item.artist
                : 'Dosya bulunamadi',
            style: TextStyle(
              color: !available
                  ? AppColors.error.withAlpha(150)
                  : AppColors.textDisabled,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_formatDuration(item.duration).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    _formatDuration(item.duration),
                    style: TextStyle(
                        color: AppColors.textDisabled, fontSize: 12),
                  ),
                ),
              if (onFavoriteToggle != null)
                GestureDetector(
                  onTap: () => onFavoriteToggle?.call(index),
                  child: Icon(
                    item.isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: item.isFavorite
                        ? AppColors.error
                        : AppColors.textDisabled,
                    size: 18,
                  ),
                ),
            ],
          ),
          onTap: available
              ? () => onSelect?.call(index)
              : null,
          onLongPress: () => onLongPress?.call(index),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        );
      },
    );
  }
}
