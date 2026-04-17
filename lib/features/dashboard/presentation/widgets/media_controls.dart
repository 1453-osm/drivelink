import 'package:flutter/material.dart';

import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/features/media/presentation/widgets/modern_player_card.dart';
import 'package:drivelink/shared/widgets/glass_panel.dart';

class MediaControls extends StatelessWidget {
  const MediaControls({
    super.key,
    this.songTitle = 'Sarki secilmedi',
    this.artist = '',
    this.albumArt,
    this.isPlaying = false,
    this.repeat = false,
    this.onPrevious,
    this.onPlayPause,
    this.onNext,
    this.onRepeatToggle,
    this.onExpand,
    this.compact = false,
  });

  final String songTitle;
  final String artist;
  final ImageProvider? albumArt;
  final bool isPlaying;
  final bool repeat;
  final VoidCallback? onPrevious;
  final VoidCallback? onPlayPause;
  final VoidCallback? onNext;
  final VoidCallback? onRepeatToggle;
  final VoidCallback? onExpand;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    if (compact) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 220;
          final artTiny = constraints.maxWidth < 190;

          return GlassPanel(
            borderRadius: 16,
            padding: EdgeInsets.fromLTRB(
              narrow ? 5 : 7,
              narrow ? 4 : 5,
              narrow ? 5 : 7,
              narrow ? 4 : 5,
            ),
            glowColor: primary,
            glowIntensity: 0.08,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _MiniArt(
                  image: albumArt,
                  primary: primary,
                  compact: true,
                  tiny: artTiny,
                ),
                SizedBox(width: narrow ? 6 : 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: onExpand,
                        behavior: HitTestBehavior.opaque,
                        child: Text(
                          songTitle,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: narrow ? 10.5 : 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(height: narrow ? 2 : 3),
                      Align(
                        alignment: Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _MiniAction(
                                icon: Icons.repeat_rounded,
                                primary: primary,
                                active: repeat,
                                compact: true,
                                tiny: true,
                                onTap: onRepeatToggle,
                              ),
                              const SizedBox(width: 2),
                              _MiniTransport(
                                icon: Icons.skip_previous_rounded,
                                onTap: onPrevious,
                                compact: true,
                                tiny: true,
                              ),
                              SizedBox(width: narrow ? 3 : 4),
                              NeonPlayButton(
                                isPlaying: isPlaying,
                                onTap: onPlayPause ?? () {},
                                size: narrow ? 28 : 30,
                              ),
                              SizedBox(width: narrow ? 3 : 4),
                              _MiniTransport(
                                icon: Icons.skip_next_rounded,
                                onTap: onNext,
                                compact: true,
                                tiny: true,
                              ),
                              const SizedBox(width: 2),
                              _MiniAction(
                                icon: Icons.open_in_full_rounded,
                                primary: primary,
                                compact: true,
                                tiny: true,
                                onTap: onExpand,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    return GlassPanel(
      borderRadius: 22,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      glowColor: primary,
      glowIntensity: 0.08,
      child: Row(
        children: [
          _MiniArt(
            image: albumArt,
            primary: primary,
            compact: false,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: onExpand,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    songTitle,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (artist.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      artist,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          _MiniAction(
            icon: Icons.repeat_rounded,
            primary: primary,
            active: repeat,
            onTap: onRepeatToggle,
          ),
          const SizedBox(width: 2),
          _MiniTransport(
            icon: Icons.skip_previous_rounded,
            onTap: onPrevious,
            compact: false,
          ),
          const SizedBox(width: 8),
          NeonPlayButton(
            isPlaying: isPlaying,
            onTap: onPlayPause ?? () {},
            size: 44,
          ),
          const SizedBox(width: 8),
          _MiniTransport(
            icon: Icons.skip_next_rounded,
            onTap: onNext,
            compact: false,
          ),
          const SizedBox(width: 2),
          _MiniAction(
            icon: Icons.open_in_full_rounded,
            primary: primary,
            onTap: onExpand,
          ),
        ],
      ),
    );
  }
}

class _MiniArt extends StatelessWidget {
  const _MiniArt({
    required this.image,
    required this.primary,
    required this.compact,
    this.tiny = false,
  });

  final ImageProvider? image;
  final Color primary;
  final bool compact;
  final bool tiny;

  @override
  Widget build(BuildContext context) {
    final size = tiny ? 40.0 : (compact ? 46.0 : 54.0);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tiny ? 10 : (compact ? 12 : 16)),
        gradient: image == null
            ? LinearGradient(
                colors: [
                  Color.lerp(primary, Colors.white, 0.18)!,
                  AppColors.surfaceVariant,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        image: image != null
            ? DecorationImage(image: image!, fit: BoxFit.cover)
            : null,
        border: Border.all(
          color: primary.withAlpha(60),
          width: 1,
        ),
      ),
      child: image == null
          ? Icon(
              Icons.music_note_rounded,
              color: primary,
              size: tiny ? 18 : (compact ? 20 : 24),
            )
          : null,
    );
  }
}

class _MiniTransport extends StatelessWidget {
  const _MiniTransport({
    required this.icon,
    this.onTap,
    required this.compact,
    this.tiny = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool compact;
  final bool tiny;

  @override
  Widget build(BuildContext context) {
    final size = tiny ? 22.0 : (compact ? 26.0 : 30.0);
    final iconSize = tiny ? 18.0 : (compact ? 22.0 : 26.0);

    return IconButton(
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(
        width: size,
        height: size,
      ),
      splashRadius: 18,
      icon: Icon(
        icon,
        color: AppColors.textPrimary,
        size: iconSize,
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.icon,
    required this.primary,
    this.active = false,
    this.compact = false,
    this.tiny = false,
    this.onTap,
  });

  final IconData icon;
  final Color primary;
  final bool active;
  final bool compact;
  final bool tiny;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final size = tiny ? 24.0 : (compact ? 30.0 : 34.0);
    final iconSize = tiny ? 14.0 : (compact ? 16.0 : 18.0);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? primary.withAlpha(24) : Colors.transparent,
        border: Border.all(
          color: active ? primary.withAlpha(90) : Colors.transparent,
          width: 1,
        ),
      ),
      child: IconButton(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tightFor(width: size, height: size),
        splashRadius: 18,
        icon: Icon(
          icon,
          color: active ? primary : AppColors.textSecondary,
          size: iconSize,
        ),
      ),
    );
  }
}
