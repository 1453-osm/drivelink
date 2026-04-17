import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivelink/core/database/database.dart';
import 'package:drivelink/features/media/data/media_repository.dart';

/// All tracks in the media library.
final mediaTracksProvider = StreamProvider<List<MediaTrack>>((ref) {
  return ref.watch(mediaRepositoryProvider).watchAllTracks();
});

/// Favorite tracks only.
final favoritesProvider = StreamProvider<List<MediaTrack>>((ref) {
  return ref.watch(mediaRepositoryProvider).watchFavorites();
});

/// Recently played tracks.
final recentlyPlayedProvider = StreamProvider<List<MediaTrack>>((ref) {
  return ref.watch(mediaRepositoryProvider).watchRecentlyPlayed();
});

/// All user-created playlists.
final playlistsProvider = StreamProvider<List<MediaPlaylist>>((ref) {
  return ref.watch(mediaRepositoryProvider).watchPlaylists();
});

/// All albums.
final albumsProvider = StreamProvider<List<MediaAlbum>>((ref) {
  return ref.watch(mediaRepositoryProvider).watchAlbums();
});

/// Tracks belonging to a specific album.
final albumTracksProvider =
    StreamProvider.family<List<MediaTrack>, int>((ref, albumId) {
  return ref.watch(mediaRepositoryProvider).watchAlbumTracks(albumId);
});

/// Search query state.
final mediaSearchQueryProvider = StateProvider<String>((ref) => '');

/// Search results — reacts to search query changes.
final mediaSearchResultsProvider = FutureProvider<List<MediaTrack>>((ref) {
  final query = ref.watch(mediaSearchQueryProvider);
  if (query.trim().isEmpty) return Future.value([]);
  return ref.read(mediaRepositoryProvider).searchTracks(query);
});

/// Tracks for a specific playlist.
final playlistTracksProvider =
    StreamProvider.family<List<PlaylistTrackEntry>, int>((ref, playlistId) {
  return ref.watch(mediaRepositoryProvider).watchPlaylistTracks(playlistId);
});
