import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/core/database/database.dart';
import 'package:drivelink/core/services/audio_service.dart';
import 'package:drivelink/features/media/data/media_repository.dart';
import 'package:drivelink/features/media/data/media_scanner.dart';
import 'package:drivelink/features/media/data/playlist_store.dart';
import 'package:drivelink/features/media/providers/media_providers.dart';
import 'package:drivelink/features/media/presentation/widgets/albums_tab.dart';
import 'package:drivelink/features/media/presentation/widgets/modern_player_card.dart';
import 'package:drivelink/features/media/presentation/widgets/volume_control.dart';
import 'package:drivelink/features/media/presentation/widgets/favorites_tab.dart';
import 'package:drivelink/features/media/presentation/widgets/playlists_tab.dart';
import 'package:drivelink/features/media/presentation/widgets/track_edit_dialog.dart';
import 'package:drivelink/features/media/presentation/widgets/track_tile.dart';

class MediaScreen extends ConsumerStatefulWidget {
  const MediaScreen({super.key});

  @override
  ConsumerState<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends ConsumerState<MediaScreen>
    with SingleTickerProviderStateMixin {
  static const _libraryTabIndex = 3;

  late final TabController _tabController;
  bool _scanning = false;
  bool _showNowPlaying = true;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _searchActive = false;

  // Current queue for playback (DB-backed tracks loaded into audio service)
  List<MediaTrack> _currentQueue = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    Future.microtask(_restoreSavedPlaylist);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Restore
  // ---------------------------------------------------------------------------

  Future<void> _restoreSavedPlaylist() async {
    final saved = await PlaylistStore.load();
    if (saved == null || !mounted) return;

    // Load ALL saved paths — don't filter out missing files.
    // Files that don't exist will still be in the queue but shown as unavailable.
    final repo = ref.read(mediaRepositoryProvider);
    final validPaths = <String>[];
    final validInfos = <TrackInfo>[];

    for (var i = 0; i < saved.paths.length; i++) {
      validPaths.add(saved.paths[i]);
      final info = i < saved.trackInfos.length
          ? saved.trackInfos[i]
          : TrackInfo(title: MediaScanner.titleFromPath(saved.paths[i]));
      validInfos.add(info);
    }

    if (validPaths.isEmpty || !mounted) return;

    // Find paths that actually exist for playback
    final playablePaths = <String>[];
    final playableInfos = <TrackInfo>[];
    for (var i = 0; i < validPaths.length; i++) {
      if (File(validPaths[i]).existsSync()) {
        playablePaths.add(validPaths[i]);
        playableInfos.add(validInfos[i]);
      }
    }

    if (playablePaths.isEmpty || !mounted) return;

    final audioService = ref.read(driveAudioServiceProvider);
    final adjustedIndex = saved.lastIndex.clamp(0, playablePaths.length - 1);
    audioService.loadPlaylist(
      playablePaths,
      trackInfos: playableInfos,
      startIndex: adjustedIndex,
    );

    audioService.onIndexChanged = (idx) {
      PlaylistStore.updateLastIndex(idx);
      // Mark as played in DB
      if (idx >= 0 && idx < _currentQueue.length) {
        repo.markPlayed(_currentQueue[idx].id);
      }
    };
  }

  // ---------------------------------------------------------------------------
  // Permission
  // ---------------------------------------------------------------------------

  Future<bool> _requestAudioPermission() async {
    final statuses = await [Permission.audio, Permission.storage].request();
    return statuses[Permission.audio]?.isGranted == true ||
        statuses[Permission.storage]?.isGranted == true;
  }

  // ---------------------------------------------------------------------------
  // Scan
  // ---------------------------------------------------------------------------

  Future<void> _scanForMusic() async {
    setState(() => _scanning = true);

    try {
      final granted = await _requestAudioPermission();
      if (!granted) {
        if (!mounted) return;
        setState(() => _scanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Depolama izni verilmedi. Ayarlardan izin verin.'),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      final result = await MediaScanner.scan();
      if (!mounted) return;

      if (result.hasM3u) {
        final choice = await _showPlaylistPicker(
          result.m3uFiles,
          result.trackCount,
        );
        if (!mounted) return;
        if (choice == null) {
          setState(() => _scanning = false);
          return;
        }
        if (choice is File) {
          await _loadM3uPlaylist(choice);
        } else {
          await _loadScannedTracks(result.tracks);
        }
      } else if (result.trackCount > 0) {
        await _loadScannedTracks(result.tracks);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Muzik dosyasi bulunamadi.')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Tarama hatasi: $e')));
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<Object?> _showPlaylistPicker(List<File> m3uFiles, int audioFileCount) {
    return showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: m3uFiles.length > 4 ? 0.74 : 0.5,
        minChildSize: 0.36,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Text(
                'Calma Listesi Sec',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  ...m3uFiles.map((f) {
                    final name = f.uri.pathSegments.last;
                    final displayName = name.contains('.')
                        ? name.substring(0, name.lastIndexOf('.'))
                        : name;
                    return ListTile(
                      leading: Icon(
                        Icons.queue_music,
                        color: AppColors.primary,
                      ),
                      title: Text(
                        displayName,
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                      subtitle: Text(
                        f.parent.path.replaceFirst('/storage/emulated/0/', ''),
                        style: TextStyle(
                          color: AppColors.textDisabled,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () => Navigator.of(ctx).pop(f),
                    );
                  }),
                  if (audioFileCount > 0)
                    ListTile(
                      leading: Icon(
                        Icons.library_music,
                        color: AppColors.textSecondary,
                      ),
                      title: Text(
                        'Tum Dosyalar ($audioFileCount)',
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                      onTap: () => Navigator.of(ctx).pop(true),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Load helpers
  // ---------------------------------------------------------------------------

  Future<void> _loadM3uPlaylist(File m3uFile) async {
    final scanned = await MediaScanner.parseM3u(m3uFile);
    if (!mounted) return;
    if (scanned.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Calma listesinde gecerli dosya bulunamadi.'),
        ),
      );
      return;
    }

    final repo = ref.read(mediaRepositoryProvider);
    final albumName = MediaScanner.albumNameFromM3u(m3uFile);
    final cover = MediaScanner.albumCoverFromM3u(m3uFile, scanned);

    // Reuse an existing album with the same name instead of duplicating.
    var existing = await repo.findAlbumByName(albumName);
    final int albumId;
    if (existing == null) {
      albumId = await repo.createAlbum(albumName, coverArt: cover);
    } else {
      albumId = existing.id;
      if (cover != null &&
          (existing.coverArt == null ||
              !File(existing.coverArt!).existsSync())) {
        await repo.updateAlbum(albumId, coverArt: cover);
      }
    }

    await _upsertAndPlay(scanned, albumId: albumId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"$albumName" albumune ${scanned.length} parca eklendi.',
          ),
        ),
      );
    }
  }

  Future<void> _loadScannedTracks(List<ScannedTrack> scanned) async {
    await _upsertAndPlay(scanned);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${scanned.length} muzik dosyasi bulundu.')),
      );
    }
  }

  /// Upsert scanned tracks into DB and start playing.
  Future<void> _upsertAndPlay(
    List<ScannedTrack> scanned, {
    int? albumId,
  }) async {
    final repo = ref.read(mediaRepositoryProvider);

    // Upsert all tracks into DB
    await repo.upsertTracks(scanned, albumId: albumId);

    // Fetch the DB records to get IDs
    final allTracks = await repo.getAllTracks();

    // Build playable queue from scanned paths
    final scannedPaths = scanned.map((s) => s.filePath).toSet();
    final queueTracks = allTracks
        .where((t) => scannedPaths.contains(t.filePath))
        .toList();

    _playTrackList(queueTracks, 0);
  }

  /// Play a list of MediaTrack objects via the audio service.
  void _playTrackList(List<MediaTrack> tracks, int startIndex) {
    final paths = <String>[];
    final infos = <TrackInfo>[];

    for (final track in tracks) {
      if (!File(track.filePath).existsSync()) continue;
      paths.add(track.filePath);
      infos.add(
        TrackInfo(
          title: track.title,
          artist: track.artist,
          artUri: track.artUri,
        ),
      );
    }

    if (paths.isEmpty) return;

    setState(() {
      _currentQueue = tracks;
      _showNowPlaying = true;
    });

    final audioService = ref.read(driveAudioServiceProvider);
    final repo = ref.read(mediaRepositoryProvider);

    audioService.setPlaylist(paths, trackInfos: infos, startIndex: startIndex);
    audioService.onIndexChanged = (idx) {
      PlaylistStore.updateLastIndex(idx);
      if (idx >= 0 && idx < _currentQueue.length) {
        repo.markPlayed(_currentQueue[idx].id);
      }
    };

    // Persist queue for next app launch
    PlaylistStore.save(paths: paths, trackInfos: infos, lastIndex: startIndex);
  }

  // ---------------------------------------------------------------------------
  // Add to playlist dialog
  // ---------------------------------------------------------------------------

  Future<void> _showTrackActionsDialog(MediaTrack track) async {
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                track.title,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Divider(height: 1, color: AppColors.divider),
            ListTile(
              leading: Icon(Icons.edit, color: AppColors.primary),
              title: Text(
                'Duzenle',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              subtitle: Text(
                'Isim, sanatci, album, kapak',
                style: TextStyle(color: AppColors.textDisabled, fontSize: 12),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                TrackEditDialog.show(context, track);
              },
            ),
            ListTile(
              leading: Icon(Icons.playlist_add, color: AppColors.primary),
              title: Text(
                'Listeye Ekle',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                _showAddToPlaylistDialog(track);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppColors.error),
              title: Text(
                'Kutuphaneden Sil',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () async {
                Navigator.of(ctx).pop();
                await ref.read(mediaRepositoryProvider).deleteTrack(track.id);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddToPlaylistDialog(MediaTrack track) async {
    final repo = ref.read(mediaRepositoryProvider);
    final playlistsAsync = ref.read(playlistsProvider);
    final playlists = playlistsAsync.valueOrNull ?? [];

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: playlists.length > 5 ? 0.72 : 0.44,
        minChildSize: 0.32,
        maxChildSize: 0.88,
        builder: (context, scrollController) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Text(
                '"${track.title}" listesine ekle',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: playlists.isEmpty
                  ? Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Henuz liste yok. Listeler sekmesinden olusturabilirsiniz.',
                        style: TextStyle(color: AppColors.textDisabled),
                      ),
                    )
                  : ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.only(bottom: 8),
                      children: [
                        ...playlists.map(
                          (p) => ListTile(
                            leading: Icon(
                              Icons.queue_music,
                              color: AppColors.primary,
                            ),
                            title: Text(
                              p.name,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                              ),
                            ),
                            onTap: () async {
                              await repo.addToPlaylist(p.id, track.id);
                              if (ctx.mounted) Navigator.of(ctx).pop();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '"${p.name}" listesine eklendi.',
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final audioService = ref.watch(driveAudioServiceProvider);
    final playbackAsync = ref.watch(playbackStateProvider);
    final playerStateAsync = ref.watch(audioPlayerStateProvider);
    final volume = ref.watch(volumeProvider);
    final currentIdx = ref.watch(currentTrackIndexProvider);

    final pbState = playbackAsync.valueOrNull;
    final track = pbState?.track ?? TrackInfo.empty;
    final shuffle = pbState?.shuffle ?? false;
    final repeat = pbState?.repeat ?? false;
    // Read live from just_audio so Play/Pause icon swaps immediately even
    // when the wrapped PlaybackState stream lags.
    final isPlaying = playerStateAsync.valueOrNull?.playing ?? false;

    // Album art
    ImageProvider? albumArt;
    final artPath = track.artUri;
    if (artPath != null && artPath.isNotEmpty) {
      final artFile = File(artPath);
      if (artFile.existsSync()) {
        albumArt = FileImage(artFile);
      }
    }

    // Check if current track is a favorite
    final currentTrackFavorite = _getCurrentTrackFavorite(currentIdx);
    final primary = Theme.of(context).colorScheme.primary;
    final primaryGlow = Color.lerp(primary, Colors.white, 0.18)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 4,
        toolbarHeight: 64,
        title: _searchActive
            ? _buildSearchField()
            : Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [primaryGlow, primary]),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withAlpha(120),
                          blurRadius: 14,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.graphic_eq,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Medya',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      SizedBox(height: 1),
                      Text(
                        'Muzik calar',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          tooltip: 'Geri',
          onPressed: () {
            if (_searchActive) {
              setState(() {
                _searchActive = false;
                _searchQuery = '';
                _searchController.clear();
              });
            } else {
              context.pop();
            }
          },
        ),
        actions: [
          _AppBarActionIcon(
            icon: _searchActive ? Icons.close : Icons.search,
            active: _searchActive,
            onTap: () {
              setState(() {
                _searchActive = !_searchActive;
                if (!_searchActive) {
                  _searchQuery = '';
                  _searchController.clear();
                } else {
                  _tabController.animateTo(_libraryTabIndex);
                }
              });
            },
          ),
          _AppBarActionIcon(
            active: _scanning,
            icon: Icons.upload_file_rounded,
            onTap: _scanning
                ? () {}
                : () {
                    _scanForMusic();
                  },
            child: _scanning
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primary,
                    ),
                  )
                : null,
          ),
          _AppBarActionIcon(
            icon: _showNowPlaying
                ? Icons.queue_music
                : Icons.queue_music_outlined,
            active: _showNowPlaying,
            onTap: () => setState(() => _showNowPlaying = !_showNowPlaying),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            height: 56,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: primary.withAlpha(25), width: 0.5),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicator: BoxDecoration(
                color: primary.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: primary.withAlpha(120), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: primary.withAlpha(60),
                    blurRadius: 12,
                    spreadRadius: -2,
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerHeight: 0,
              labelColor: primary,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              labelPadding: const EdgeInsets.symmetric(horizontal: 14),
              tabs: const [
                Tab(text: 'Albumler'),
                Tab(text: 'Favoriler'),
                Tab(text: 'Listeler'),
                Tab(text: 'Kutuphane'),
              ],
            ),
          ),
        ),
      ),
      body: _buildMediaLayout(
        audioService,
        track,
        albumArt,
        isPlaying,
        volume,
        currentIdx,
        shuffle,
        repeat,
        currentTrackFavorite,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Layouts
  // ---------------------------------------------------------------------------

  Widget _buildMediaLayout(
    DriveAudioService audioService,
    TrackInfo track,
    ImageProvider? albumArt,
    bool isPlaying,
    double volume,
    int currentIdx,
    bool shuffle,
    bool repeat,
    bool currentTrackFavorite,
  ) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Column(
      children: [
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              AlbumsTab(onPlayTracks: _playTrackList),
              FavoritesTab(onPlayTracks: _playTrackList),
              PlaylistsTab(onPlayTracks: _playTrackList),
              _buildLibraryTab(),
            ],
          ),
        ),
        if (_showNowPlaying)
          Padding(
            padding: EdgeInsets.fromLTRB(12, 6, 12, bottomPadding + 10),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: _buildCompactNowPlaying(
                  audioService,
                  track,
                  albumArt,
                  isPlaying,
                  volume,
                  currentIdx,
                  shuffle,
                  repeat,
                  currentTrackFavorite,
                ).animate().fadeIn(duration: 320.ms),
              ),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Compact now-playing (portrait mode)
  // ---------------------------------------------------------------------------

  Widget _buildCompactNowPlaying(
    DriveAudioService audioService,
    TrackInfo track,
    ImageProvider? albumArt,
    bool isPlaying,
    double volume,
    int currentIdx,
    bool shuffle,
    bool repeat,
    bool currentTrackFavorite,
  ) {
    final positionAsync = ref.watch(audioPositionProvider);
    final durationAsync = ref.watch(audioDurationProvider);
    final position = positionAsync.valueOrNull ?? track.position;
    final duration = durationAsync.valueOrNull ?? track.duration;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ModernPlayerCard(
          track: track,
          albumArt: albumArt,
          isPlaying: isPlaying,
          position: position,
          duration: duration,
          shuffle: shuffle,
          repeat: repeat,
          isFavorite: currentTrackFavorite,
          onPlayPause: () => audioService.togglePlayPause(),
          onNext: () => audioService.next(),
          onPrevious: () => audioService.previous(),
          onSeek: (d) => audioService.seek(d),
          onShuffleToggle: () => audioService.toggleShuffle(),
          onRepeatToggle: () => audioService.toggleRepeat(),
          onFavoriteToggle: () => _toggleCurrentFavorite(currentIdx),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: VolumeControl(
            volume: volume,
            isMuted: volume == 0,
            onChanged: (v) => audioService.setVolume(v),
            onMuteToggle: () {
              audioService.setVolume(volume > 0 ? 0 : 0.7);
            },
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tabs
  // ---------------------------------------------------------------------------

  Widget _buildLibraryTab() {
    final tracksAsync = ref.watch(mediaTracksProvider);
    final primary = Theme.of(context).colorScheme.primary;

    return tracksAsync.when(
      loading: () => Center(child: CircularProgressIndicator(color: primary)),
      error: (e, _) => Center(
        child: Text('Hata: $e', style: TextStyle(color: AppColors.error)),
      ),
      data: (tracks) {
        if (tracks.isEmpty) {
          return const _MediaEmptyState(
            icon: Icons.library_music,
            title: 'Kutuphane bos',
            subtitle:
                'Ust bardaki yukleme simgesiyle cihazinizdan muzik ekleyin',
          );
        }

        final filtered = _searchQuery.isEmpty
            ? tracks
            : tracks
                  .where(
                    (t) =>
                        t.title.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        ) ||
                        t.artist.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        ),
                  )
                  .toList();

        return Column(
          children: [
            _SectionHeader(
              title: _searchQuery.isEmpty
                  ? '${tracks.length} parca'
                  : '${filtered.length} / ${tracks.length} parca',
              onPlayAll: filtered.isEmpty
                  ? null
                  : () => _playTrackList(filtered, 0),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 2),
                itemBuilder: (context, index) {
                  final track = filtered[index];
                  return TrackTile(
                    track: track,
                    index: index,
                    onTap: () => _playTrackList(filtered, index),
                    onFavoriteToggle: () {
                      ref
                          .read(mediaRepositoryProvider)
                          .toggleFavorite(track.id);
                    },
                    onLongPress: () => _showTrackActionsDialog(track),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
      decoration: InputDecoration(
        hintText: 'Sarki veya sanatci ara...',
        hintStyle: TextStyle(color: AppColors.textDisabled),
        border: InputBorder.none,
      ),
      onChanged: (value) {
        setState(() => _searchQuery = value);
        _tabController.animateTo(_libraryTabIndex);
        // Also update the provider for other potential consumers
        ref.read(mediaSearchQueryProvider.notifier).state = value;
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  bool _getCurrentTrackFavorite(int currentIdx) {
    if (currentIdx < 0 || _currentQueue.isEmpty) return false;
    if (currentIdx >= _currentQueue.length) return false;
    return _currentQueue[currentIdx].isFavorite;
  }

  void _toggleCurrentFavorite(int currentIdx) {
    if (currentIdx < 0 || _currentQueue.isEmpty) return;
    if (currentIdx >= _currentQueue.length) return;
    final track = _currentQueue[currentIdx];
    ref.read(mediaRepositoryProvider).toggleFavorite(track.id);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.onPlayAll});

  final String title;
  final VoidCallback? onPlayAll;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final primaryGlow = Color.lerp(primary, Colors.white, 0.18)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 10),
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
            title,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          if (onPlayAll != null)
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: onPlayAll,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
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
                      Icon(Icons.play_arrow, size: 16, color: primary),
                      const SizedBox(width: 4),
                      Text(
                        'Tumunu Cal',
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
        ],
      ),
    );
  }
}

class _MediaEmptyState extends StatelessWidget {
  const _MediaEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

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
                colors: [primary.withAlpha(30), primary.withAlpha(6)],
              ),
              border: Border.all(color: primary.withAlpha(60), width: 1),
              boxShadow: [
                BoxShadow(
                  color: primary.withAlpha(40),
                  blurRadius: 24,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Icon(icon, size: 40, color: primary),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppBarActionIcon extends StatelessWidget {
  const _AppBarActionIcon({
    required this.icon,
    required this.onTap,
    this.active = false,
    this.child,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          splashColor: primary.withAlpha(30),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? primary.withAlpha(26) : AppColors.surface,
              border: Border.all(
                color: active ? primary.withAlpha(120) : AppColors.border,
                width: 0.5,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: primary.withAlpha(60),
                        blurRadius: 10,
                        spreadRadius: -2,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child:
                  child ??
                  Icon(
                    icon,
                    color: active ? primary : AppColors.textSecondary,
                    size: 20,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
