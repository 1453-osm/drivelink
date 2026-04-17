import 'dart:io';

import 'package:flutter/material.dart';

import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/core/database/database.dart';

/// Modern reusable track row with optional album art thumbnail, favorite
/// toggle and availability indicator.
class TrackTile extends StatelessWidget {
  const TrackTile({
    super.key,
    required this.track,
    this.index,
    this.isCurrent = false,
    this.onTap,
    this.onFavoriteToggle,
    this.onLongPress,
    this.trailing,
  });

  final MediaTrack track;
  final int? index;
  final bool isCurrent;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onLongPress;
  final Widget? trailing;

  bool get _fileExists => File(track.filePath).existsSync();

  @override
  Widget build(BuildContext context) {
    final available = _fileExists;
    final primary = Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: available ? onTap : () => _showUnavailableSnackbar(context),
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(14),
        splashColor: primary.withAlpha(20),
        highlightColor: primary.withAlpha(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _buildLeading(available, primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      style: TextStyle(
                        color: !available
                            ? AppColors.textDisabled
                            : isCurrent
                                ? primary
                                : AppColors.textPrimary,
                        fontWeight:
                            isCurrent ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 14.5,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!available)
                      Text(
                        'Dosya bulunamadi',
                        style: TextStyle(
                          color: AppColors.error.withAlpha(170),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    else if (track.artist.isNotEmpty)
                      const SizedBox(height: 3)
                    else
                      const SizedBox.shrink(),
                    if (available && track.artist.isNotEmpty)
                      Text(
                        track.artist,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ?? _buildTrailing(primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeading(bool available, Color primary) {
    if (!available) {
      return Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppColors.error.withAlpha(24),
          borderRadius: BorderRadius.circular(12),
        ),
        child:
            Icon(Icons.error_outline, color: AppColors.error, size: 22),
      );
    }

    // Try to show album art thumbnail
    final artPath = track.artUri;
    if (artPath != null && artPath.isNotEmpty && File(artPath).existsSync()) {
      return Stack(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: FileImage(File(artPath)),
                fit: BoxFit.cover,
              ),
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: primary.withAlpha(120),
                        blurRadius: 10,
                        spreadRadius: -2,
                      ),
                    ]
                  : null,
              border: isCurrent
                  ? Border.all(color: primary, width: 1.5)
                  : null,
            ),
          ),
          if (isCurrent)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(90),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.equalizer,
                    color: Colors.white, size: 22),
              ),
            ),
        ],
      );
    }

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isCurrent
              ? [
                  primary.withAlpha(60),
                  primary.withAlpha(20),
                ]
              : [
                  AppColors.surfaceBright,
                  AppColors.surfaceVariant,
                ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent
              ? primary.withAlpha(150)
              : AppColors.border,
          width: isCurrent ? 1.5 : 0.5,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: primary.withAlpha(100),
                  blurRadius: 10,
                  spreadRadius: -2,
                ),
              ]
            : null,
      ),
      child: Center(
        child: isCurrent
            ? Icon(Icons.equalizer, color: primary, size: 22)
            : (index != null
                ? Text(
                    '${index! + 1}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : Icon(Icons.music_note,
                    color: AppColors.textDisabled, size: 20)),
      ),
    );
  }

  Widget _buildTrailing(Color primary) {
    if (onFavoriteToggle == null) return const SizedBox.shrink();

    return IconButton(
      icon: Icon(
        track.isFavorite ? Icons.favorite : Icons.favorite_border,
        color: track.isFavorite ? AppColors.error : primary.withAlpha(130),
        size: 20,
      ),
      onPressed: onFavoriteToggle,
      splashRadius: 20,
    );
  }

  void _showUnavailableSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dosya bulunamadi. Depolama alanini kontrol edin.'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
