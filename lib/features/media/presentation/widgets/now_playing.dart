import 'package:flutter/material.dart';

import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/features/media/presentation/widgets/modern_player_card.dart';

/// Full-size now-playing panel used in landscape mode. Displays a large hero
/// album art with ambient glow, title/artist, progress, and transport row
/// with the premium neon play button.
class NowPlaying extends StatelessWidget {
  const NowPlaying({
    super.key,
    required this.title,
    required this.artist,
    this.albumArt,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
    this.onSeek,
    this.shuffle = false,
    this.repeat = false,
    this.isFavorite = false,
    this.onShuffleToggle,
    this.onRepeatToggle,
    this.onFavoriteToggle,
  });

  final String title;
  final String artist;
  final ImageProvider? albumArt;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final ValueChanged<Duration>? onSeek;

  final bool shuffle;
  final bool repeat;
  final bool isFavorite;
  final VoidCallback? onShuffleToggle;
  final VoidCallback? onRepeatToggle;
  final VoidCallback? onFavoriteToggle;

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = duration.inMilliseconds;
    final progress = totalMs > 0 ? position.inMilliseconds / totalMs : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Hero album art with concentric neon glow
        SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer ambient glow
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withAlpha(50),
                      AppColors.primary.withAlpha(0),
                    ],
                  ),
                ),
              ),
              // Art container
              Container(
                width: 188,
                height: 188,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(22),
                  image: albumArt != null
                      ? DecorationImage(image: albumArt!, fit: BoxFit.cover)
                      : null,
                  border: Border.all(
                    color: AppColors.primary.withAlpha(90),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withAlpha(90),
                      blurRadius: 32,
                      spreadRadius: -4,
                    ),
                    const BoxShadow(
                      color: Colors.black54,
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: albumArt == null
                    ? Icon(Icons.music_note,
                        color: AppColors.textDisabled, size: 64)
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Title + favorite
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onFavoriteToggle != null) ...[
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onFavoriteToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFavorite
                        ? AppColors.error.withAlpha(26)
                        : Colors.transparent,
                    border: Border.all(
                      color: isFavorite
                          ? AppColors.error.withAlpha(120)
                          : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? AppColors.error : AppColors.textDisabled,
                    size: 20,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          artist,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 20),

        // Progress bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: AppColors.border,
                  thumbColor: AppColors.primary,
                  overlayColor: AppColors.primary.withAlpha(40),
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                    elevation: 2,
                  ),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 14),
                ),
                child: Slider(
                  value: progress.clamp(0.0, 1.0),
                  onChanged: totalMs > 0
                      ? (v) => onSeek?.call(Duration(
                          milliseconds: (v * totalMs).round()))
                      : null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(position),
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      _formatDuration(duration),
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Transport row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _SecondaryButton(
              icon: Icons.shuffle,
              active: shuffle,
              onTap: onShuffleToggle ?? () {},
            ),
            _SecondaryButton(
              icon: Icons.skip_previous,
              size: 32,
              onTap: onPrevious,
            ),
            NeonPlayButton(
              isPlaying: isPlaying,
              onTap: onPlayPause,
              size: 68,
            ),
            _SecondaryButton(
              icon: Icons.skip_next,
              size: 32,
              onTap: onNext,
            ),
            _SecondaryButton(
              icon: Icons.repeat,
              active: repeat,
              onTap: onRepeatToggle ?? () {},
            ),
          ],
        ),
      ],
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.icon,
    required this.onTap,
    this.active = false,
    this.size = 22,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.textPrimary;
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        splashColor: AppColors.primary.withAlpha(30),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? AppColors.primary.withAlpha(22) : Colors.transparent,
            border: Border.all(
              color: active
                  ? AppColors.primary.withAlpha(100)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Icon(icon, color: color, size: size),
        ),
      ),
    );
  }
}
