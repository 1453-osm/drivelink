import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

// ---------------------------------------------------------------------------
// Track info model
// ---------------------------------------------------------------------------
class TrackInfo {
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final Duration position;
  final String? artUri;

  const TrackInfo({
    this.title = 'Bilinmeyen Parca',
    this.artist = '',
    this.album = '',
    this.duration = Duration.zero,
    this.position = Duration.zero,
    this.artUri,
  });

  double get progress =>
      duration.inMilliseconds > 0
          ? position.inMilliseconds / duration.inMilliseconds
          : 0;

  String get durationFormatted => _fmt(duration);
  String get positionFormatted => _fmt(position);

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$m:$s';
    }
    return '$m:$s';
  }

  TrackInfo copyWith({
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    Duration? position,
    String? artUri,
  }) {
    return TrackInfo(
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      position: position ?? this.position,
      artUri: artUri ?? this.artUri,
    );
  }

  static const empty = TrackInfo();
}

// ---------------------------------------------------------------------------
// Playback state
// ---------------------------------------------------------------------------
enum PlaybackStatus {
  idle,
  loading,
  playing,
  paused,
  stopped,
  error,
}

class PlaybackState {
  final PlaybackStatus status;
  final TrackInfo track;
  final double volume;
  final bool shuffle;
  final bool repeat;
  final int currentIndex;

  const PlaybackState({
    this.status = PlaybackStatus.idle,
    this.track = TrackInfo.empty,
    this.volume = 1.0,
    this.shuffle = false,
    this.repeat = false,
    this.currentIndex = -1,
  });

  PlaybackState copyWith({
    PlaybackStatus? status,
    TrackInfo? track,
    double? volume,
    bool? shuffle,
    bool? repeat,
    int? currentIndex,
  }) {
    return PlaybackState(
      status: status ?? this.status,
      track: track ?? this.track,
      volume: volume ?? this.volume,
      shuffle: shuffle ?? this.shuffle,
      repeat: repeat ?? this.repeat,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }
}

// ---------------------------------------------------------------------------
// Audio handler for background playback (audio_service integration)
// ---------------------------------------------------------------------------
class DriveLinkAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player;

  DriveLinkAudioHandler(this._player) {
    _player.playbackEventStream.listen((event) {
      final playing = _player.playing;
      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: _mapProcessingState(_player.processingState),
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
      ));
    });
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> skipToNext() async {}
  @override
  Future<void> skipToPrevious() async {}
}

// ---------------------------------------------------------------------------
// Main audio service
// ---------------------------------------------------------------------------
class DriveAudioService {
  DriveAudioService();

  final AudioPlayer _player = AudioPlayer();
  DriveLinkAudioHandler? _audioHandler;
  bool _disposed = false;
  Completer<void>? _initCompleter;

  final _playbackController = StreamController<PlaybackState>.broadcast();
  final _trackController = StreamController<TrackInfo>.broadcast();

  PlaybackState _state = const PlaybackState();
  final List<String> _playlist = [];
  final List<TrackInfo> _trackInfos = [];
  int _currentIndex = -1;

  /// Called whenever the current track index changes (for persistence).
  void Function(int index)? onIndexChanged;

  // ---- Public streams ----

  Stream<PlaybackState> get playbackStream => _playbackController.stream;
  Stream<TrackInfo> get trackStream => _trackController.stream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  PlaybackState get currentState => _state;
  TrackInfo get currentTrack => _state.track;
  int get currentIndex => _currentIndex;
  Duration get position => _player.position;
  Duration get duration => _player.duration ?? Duration.zero;
  bool get isPlaying => _player.playing;

  // ---- Lifecycle ----

  /// Whether init() has completed successfully.
  bool get isInitialized => _initCompleter?.isCompleted ?? false;

  /// Wait for init() to complete. Safe to call multiple times.
  Future<void> ensureInitialized() async {
    if (_initCompleter != null) await _initCompleter!.future;
  }

  Future<void> init() async {
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<void>();

    try {
      _audioHandler = await AudioService.init(
        builder: () => DriveLinkAudioHandler(_player),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.drivelink.audio',
          androidNotificationChannelName: 'DriveLink Muzik',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
        ),
      );

      _player.playerStateStream.listen((playerState) {
        if (_disposed) return;
        _state = _state.copyWith(status: _mapStatus(playerState));
        _emit();
      });

      _player.positionStream.listen((position) {
        if (_disposed) return;
        _state = _state.copyWith(
          track: _state.track.copyWith(position: position),
        );
        _emit();
      });

      _player.durationStream.listen((duration) {
        if (_disposed || duration == null) return;
        _state = _state.copyWith(
          track: _state.track.copyWith(duration: duration),
        );
        _emit();
      });

      _player.processingStateStream.listen((state) {
        if (state == ProcessingState.completed) {
          next();
        }
      });

      _initCompleter!.complete();
    } catch (e) {
      _initCompleter!.completeError(e);
      _initCompleter = null; // Allow retry
      rethrow;
    }
  }

  // ---- Playback controls ----

  /// Play a single audio file. Track info is set BEFORE the file loads so
  /// intermediate stream events already carry the correct title / artist.
  Future<void> _playFile(String path, {TrackInfo? info}) async {
    try {
      // Set track info FIRST — avoids the race where player-state
      // listeners emit stale title/artist during file load.
      if (info != null) {
        _state = _state.copyWith(
          track: info.copyWith(duration: Duration.zero, position: Duration.zero),
          status: PlaybackStatus.loading,
        );
        _trackController.add(_state.track);
      } else {
        _state = _state.copyWith(status: PlaybackStatus.loading);
      }
      _emit();

      if (path.startsWith('http')) {
        await _player.setUrl(path);
      } else {
        await _player.setFilePath(path);
      }

      await _player.play();
    } catch (e) {
      _state = _state.copyWith(status: PlaybackStatus.error);
      _emit();
    }
  }

  /// Set a playlist and immediately start playing from [startIndex].
  Future<void> setPlaylist(
    List<String> paths, {
    int startIndex = 0,
    List<TrackInfo>? trackInfos,
  }) async {
    _playlist
      ..clear()
      ..addAll(paths);
    _trackInfos
      ..clear()
      ..addAll(trackInfos ?? []);
    _currentIndex = startIndex.clamp(0, paths.length - 1);

    _state = _state.copyWith(currentIndex: _currentIndex);
    _emit(); // Push index update immediately

    onIndexChanged?.call(_currentIndex);

    await _playFile(
      _playlist[_currentIndex],
      info: _trackInfoForIndex(_currentIndex),
    );
  }

  /// Load a playlist into memory and show track info WITHOUT starting
  /// playback. Used when restoring a saved playlist on app startup.
  void loadPlaylist(
    List<String> paths, {
    List<TrackInfo>? trackInfos,
    int startIndex = 0,
  }) {
    _playlist
      ..clear()
      ..addAll(paths);
    _trackInfos
      ..clear()
      ..addAll(trackInfos ?? []);
    _currentIndex = startIndex.clamp(0, paths.length - 1);

    final info = _trackInfoForIndex(_currentIndex);
    _state = _state.copyWith(
      currentIndex: _currentIndex,
      track: info,
      status: PlaybackStatus.idle,
    );
    _trackController.add(info);
    _emit();
  }

  /// Jump to a specific track index in the current playlist.
  /// Unlike [setPlaylist], this does NOT rebuild the playlist.
  Future<void> playAt(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    _currentIndex = index;
    _state = _state.copyWith(currentIndex: _currentIndex);
    _emit(); // Immediate UI feedback

    onIndexChanged?.call(_currentIndex);

    await _playFile(
      _playlist[_currentIndex],
      info: _trackInfoForIndex(_currentIndex),
    );
  }

  /// Whether a playlist is currently loaded.
  bool get hasPlaylist => _playlist.isNotEmpty;

  Future<void> play() async => _player.play();
  Future<void> pause() async => _player.pause();

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await pause();
    } else {
      // If playlist is loaded but nothing playing yet, start the current track
      if (_playlist.isNotEmpty &&
          _state.status != PlaybackStatus.playing &&
          _state.status != PlaybackStatus.loading) {
        await playAt(_currentIndex.clamp(0, _playlist.length - 1));
        return;
      }
      await play();
    }
  }

  Future<void> stop() async {
    await _player.stop();
    _state = _state.copyWith(status: PlaybackStatus.stopped);
    _emit();
  }

  Future<void> next() async {
    if (_playlist.isEmpty) return;

    if (_state.shuffle) {
      _currentIndex =
          (_currentIndex + 1 + (_playlist.length - 1)) % _playlist.length;
    } else {
      _currentIndex++;
    }

    if (_currentIndex >= _playlist.length) {
      if (_state.repeat) {
        _currentIndex = 0;
      } else {
        _currentIndex = _playlist.length - 1;
        await stop();
        return;
      }
    }

    _state = _state.copyWith(currentIndex: _currentIndex);
    onIndexChanged?.call(_currentIndex);

    await _playFile(
      _playlist[_currentIndex],
      info: _trackInfoForIndex(_currentIndex),
    );
  }

  Future<void> previous() async {
    if (_playlist.isEmpty) return;

    if (_player.position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    _currentIndex--;
    if (_currentIndex < 0) {
      _currentIndex = _state.repeat ? _playlist.length - 1 : 0;
    }

    _state = _state.copyWith(currentIndex: _currentIndex);
    onIndexChanged?.call(_currentIndex);

    await _playFile(
      _playlist[_currentIndex],
      info: _trackInfoForIndex(_currentIndex),
    );
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> seekRelative(Duration offset) async {
    final newPos = _player.position + offset;
    final clamped = Duration(
      milliseconds: newPos.inMilliseconds.clamp(
        0,
        _player.duration?.inMilliseconds ?? 0,
      ),
    );
    await _player.seek(clamped);
  }

  // ---- Volume ----

  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    await _player.setVolume(clamped);
    _state = _state.copyWith(volume: clamped);
    _emit();
  }

  Future<void> volumeUp({double step = 0.1}) async =>
      setVolume(_state.volume + step);
  Future<void> volumeDown({double step = 0.1}) async =>
      setVolume(_state.volume - step);

  // ---- Shuffle / Repeat ----

  void toggleShuffle() {
    _state = _state.copyWith(shuffle: !_state.shuffle);
    _emit();
  }

  void toggleRepeat() {
    _state = _state.copyWith(repeat: !_state.repeat);
    _emit();
  }

  // ---- Private helpers ----

  TrackInfo _trackInfoForIndex(int index) {
    if (index >= 0 && index < _trackInfos.length) {
      return _trackInfos[index];
    }
    final path = _playlist[index];
    final name = path.split('/').last;
    final dotIdx = name.lastIndexOf('.');
    final title = dotIdx > 0 ? name.substring(0, dotIdx) : name;
    return TrackInfo(title: title, artist: '');
  }

  PlaybackStatus _mapStatus(PlayerState ps) {
    if (ps.processingState == ProcessingState.loading ||
        ps.processingState == ProcessingState.buffering) {
      return PlaybackStatus.loading;
    }
    if (ps.processingState == ProcessingState.completed) {
      return PlaybackStatus.stopped;
    }
    if (ps.playing) return PlaybackStatus.playing;
    return PlaybackStatus.paused;
  }

  void _emit() {
    if (!_disposed) {
      _playbackController.add(_state);
    }
  }

  void dispose() {
    _disposed = true;
    _player.dispose();
    _playbackController.close();
    _trackController.close();
  }
}

// ---------------------------------------------------------------------------
// Riverpod Providers
// ---------------------------------------------------------------------------

final driveAudioServiceProvider = Provider<DriveAudioService>((ref) {
  final service = DriveAudioService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Awaitable provider that ensures the audio service is fully initialized.
final audioServiceInitProvider = FutureProvider<DriveAudioService>((ref) async {
  final service = ref.watch(driveAudioServiceProvider);
  await service.init();
  return service;
});

final playbackStateProvider = StreamProvider<PlaybackState>((ref) {
  final service = ref.watch(driveAudioServiceProvider);
  return service.playbackStream;
});

final currentTrackProvider = StreamProvider<TrackInfo>((ref) {
  final service = ref.watch(driveAudioServiceProvider);
  return service.trackStream;
});

final isPlayingProvider = Provider<bool>((ref) {
  final pb = ref.watch(playbackStateProvider);
  return pb.whenOrNull(data: (s) => s.status == PlaybackStatus.playing) ??
      false;
});

final volumeProvider = Provider<double>((ref) {
  final pb = ref.watch(playbackStateProvider);
  return pb.whenOrNull(data: (s) => s.volume) ?? 1.0;
});

final currentTrackIndexProvider = Provider<int>((ref) {
  final pb = ref.watch(playbackStateProvider);
  return pb.whenOrNull(data: (s) => s.currentIndex) ?? -1;
});

/// Live position stream — updates continuously while playing.
final audioPositionProvider = StreamProvider<Duration>((ref) {
  final service = ref.watch(driveAudioServiceProvider);
  return service.positionStream;
});

/// Live duration stream — emits when the source changes.
final audioDurationProvider = StreamProvider<Duration?>((ref) {
  final service = ref.watch(driveAudioServiceProvider);
  return service.durationStream;
});

/// Live player state (playing/paused/loading) straight from just_audio.
final audioPlayerStateProvider = StreamProvider<PlayerState>((ref) {
  final service = ref.watch(driveAudioServiceProvider);
  return service.playerStateStream;
});
