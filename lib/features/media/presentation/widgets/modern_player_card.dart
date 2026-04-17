import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/core/services/audio_service.dart';
import 'package:drivelink/shared/widgets/glass_panel.dart';

/// Compact player used on the media screen.
class ModernPlayerCard extends StatelessWidget {
  const ModernPlayerCard({
    super.key,
    required this.track,
    required this.albumArt,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.shuffle,
    required this.repeat,
    required this.isFavorite,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
    required this.onSeek,
    required this.onShuffleToggle,
    required this.onRepeatToggle,
    required this.onFavoriteToggle,
  });

  final TrackInfo track;
  final ImageProvider? albumArt;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final bool shuffle;
  final bool repeat;
  final bool isFavorite;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onShuffleToggle;
  final VoidCallback onRepeatToggle;
  final VoidCallback onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;

        return GlassPanel(
          borderRadius: compact ? 18 : 20,
          glowIntensity: 0.08,
          padding: EdgeInsets.fromLTRB(
            compact ? 14 : 16,
            compact ? 12 : 14,
            compact ? 14 : 16,
            compact ? 10 : 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HeaderRow(
                track: track,
                albumArt: albumArt,
                isFavorite: isFavorite,
                compact: compact,
                onFavoriteToggle: onFavoriteToggle,
              ),
              SizedBox(height: compact ? 10 : 12),
              _ProgressBar(
                position: position,
                duration: duration,
                compact: compact,
                onSeek: onSeek,
              ),
              SizedBox(height: compact ? 8 : 10),
              _TransportRow(
                isPlaying: isPlaying,
                shuffle: shuffle,
                repeat: repeat,
                compact: compact,
                onPlayPause: onPlayPause,
                onNext: onNext,
                onPrevious: onPrevious,
                onShuffleToggle: onShuffleToggle,
                onRepeatToggle: onRepeatToggle,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.track,
    required this.albumArt,
    required this.isFavorite,
    required this.compact,
    required this.onFavoriteToggle,
  });

  final TrackInfo track;
  final ImageProvider? albumArt;
  final bool isFavorite;
  final bool compact;
  final VoidCallback onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _HeroArt(
          image: albumArt,
          size: compact ? 52 : 58,
          radius: compact ? 14 : 16,
        ),
        SizedBox(width: compact ? 12 : 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                track.title,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: compact ? 15 : 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                  height: 1.15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (track.artist.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  track.artist,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: compact ? 11.5 : 12.5,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        _IconPill(
          icon: isFavorite ? Icons.favorite : Icons.favorite_border,
          color: isFavorite ? AppColors.error : AppColors.textSecondary,
          active: isFavorite,
          activeColor: AppColors.error,
          compact: compact,
          onTap: onFavoriteToggle,
        ),
      ],
    );
  }
}

class _HeroArt extends StatelessWidget {
  const _HeroArt({
    required this.image,
    required this.size,
    required this.radius,
  });

  final ImageProvider? image;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: image == null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.surfaceBright, AppColors.surface],
              )
            : null,
        color: image != null ? AppColors.surfaceVariant : null,
        borderRadius: BorderRadius.circular(radius),
        image: image != null
            ? DecorationImage(image: image!, fit: BoxFit.cover)
            : null,
        border: Border.all(color: primary.withAlpha(56), width: 1),
        boxShadow: [
          BoxShadow(
            color: primary.withAlpha(52),
            blurRadius: 18,
            spreadRadius: -4,
            offset: const Offset(0, 4),
          ),
          const BoxShadow(
            color: Colors.black54,
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: image == null
          ? Icon(
              Icons.music_note_rounded,
              color: AppColors.textDisabled,
              size: size * 0.42,
            )
          : null,
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.position,
    required this.duration,
    required this.compact,
    required this.onSeek,
  });

  final Duration position;
  final Duration duration;
  final bool compact;
  final ValueChanged<Duration> onSeek;

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final totalMs = duration.inMilliseconds;
    final progress = totalMs > 0 ? position.inMilliseconds / totalMs : 0.0;

    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: primary,
            inactiveTrackColor: AppColors.border,
            thumbColor: primary,
            overlayColor: primary.withAlpha(36),
            trackHeight: 2.5,
            thumbShape: RoundSliderThumbShape(
              enabledThumbRadius: compact ? 5 : 5.5,
              elevation: 2,
            ),
            overlayShape: RoundSliderOverlayShape(
              overlayRadius: compact ? 11 : 13,
            ),
            trackShape: const RoundedRectSliderTrackShape(),
          ),
          child: Slider(
            min: 0,
            max: 1,
            value: progress.clamp(0.0, 1.0),
            onChanged: totalMs > 0
                ? (v) => onSeek(Duration(milliseconds: (v * totalMs).round()))
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fmt(position),
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: compact ? 10 : 10.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.4,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                _fmt(duration),
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: compact ? 10 : 10.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.4,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TransportRow extends StatelessWidget {
  const _TransportRow({
    required this.isPlaying,
    required this.shuffle,
    required this.repeat,
    required this.compact,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
    required this.onShuffleToggle,
    required this.onRepeatToggle,
  });

  final bool isPlaying;
  final bool shuffle;
  final bool repeat;
  final bool compact;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onShuffleToggle;
  final VoidCallback onRepeatToggle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _IconPill(
          icon: Icons.shuffle_rounded,
          color: AppColors.textSecondary,
          active: shuffle,
          compact: compact,
          onTap: onShuffleToggle,
        ),
        _SecondaryTransport(
          icon: Icons.skip_previous_rounded,
          compact: compact,
          onTap: onPrevious,
        ),
        NeonPlayButton(
          isPlaying: isPlaying,
          onTap: onPlayPause,
          size: compact ? 46 : 48,
        ),
        _SecondaryTransport(
          icon: Icons.skip_next_rounded,
          compact: compact,
          onTap: onNext,
        ),
        _IconPill(
          icon: Icons.repeat_rounded,
          color: AppColors.textSecondary,
          active: repeat,
          compact: compact,
          onTap: onRepeatToggle,
        ),
      ],
    );
  }
}

class _SecondaryTransport extends StatelessWidget {
  const _SecondaryTransport({
    required this.icon,
    required this.compact,
    required this.onTap,
  });

  final IconData icon;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        splashColor: primary.withAlpha(30),
        child: Padding(
          padding: EdgeInsets.all(compact ? 6 : 7),
          child: Icon(
            icon,
            color: AppColors.textPrimary,
            size: compact ? 24 : 26,
          ),
        ),
      ),
    );
  }
}

class _IconPill extends StatelessWidget {
  const _IconPill({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.compact,
    this.active = false,
    this.activeColor,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool compact;
  final bool active;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final tint = active
        ? (activeColor ?? Theme.of(context).colorScheme.primary)
        : color;

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        splashColor: tint.withAlpha(30),
        child: Container(
          padding: EdgeInsets.all(compact ? 6 : 7),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? tint.withAlpha(22) : Colors.transparent,
            border: Border.all(
              color: active ? tint.withAlpha(90) : Colors.transparent,
              width: 1,
            ),
          ),
          child: Icon(icon, color: tint, size: compact ? 16 : 17),
        ),
      ),
    );
  }
}

class NeonPlayButton extends StatelessWidget {
  const NeonPlayButton({
    super.key,
    required this.isPlaying,
    required this.onTap,
    this.size = 48,
  });

  final bool isPlaying;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final primaryGlow = Color.lerp(primary, Colors.white, 0.2)!;
    final primaryDeep = Color.lerp(primary, AppColors.background, 0.4)!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [primaryGlow, primary, primaryDeep],
          ),
          boxShadow: [
            BoxShadow(
              color: primary.withAlpha(120),
              blurRadius: 18,
              spreadRadius: -2,
            ),
            BoxShadow(
              color: primary.withAlpha(48),
              blurRadius: 28,
              spreadRadius: 1,
            ),
          ],
          border: Border.all(color: Colors.white.withAlpha(40), width: 1.3),
        ),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: size * 0.5,
        ),
      ),
    );
  }
}
