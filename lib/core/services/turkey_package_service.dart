import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Canonical filenames for the Turkey offline pack components.
const turkeyPmtilesFilename = 'turkey.pmtiles';
const turkeyGraphFilename = 'turkey.ghz';
const turkeyAddressesFilename = 'turkey_addresses.db';
const turkeyManifestFilename = 'manifest.json';
const _packSubdir = 'turkey_pack';

/// URL of the remote manifest that describes the current Turkey pack version.
///
/// The manifest is a small JSON document published alongside the pack assets
/// on GitHub Releases. It enumerates each component with its download URL,
/// expected size and SHA-256 hash.
const turkeyManifestUrl =
    'https://github.com/1453-osm/drivelink/releases/latest/download/manifest.json';

/// Stages of the Turkey pack installation lifecycle.
enum TurkeyPackStatus {
  notInstalled,
  downloading,
  installed,
  failed,
}

/// A single downloadable component inside the pack (pmtiles / ghz / addresses).
@immutable
class TurkeyPackAsset {
  const TurkeyPackAsset({
    required this.name,
    required this.filename,
    required this.url,
    required this.sizeBytes,
    required this.sha256,
  });

  final String name;
  final String filename;
  final String url;
  final int sizeBytes;
  final String sha256;

  factory TurkeyPackAsset.fromJson(String name, Map<String, dynamic> json) =>
      TurkeyPackAsset(
        name: name,
        filename: json['filename'] as String,
        url: json['url'] as String,
        sizeBytes: (json['size'] as num).toInt(),
        sha256: json['sha256'] as String,
      );
}

/// Describes an available Turkey pack release.
@immutable
class TurkeyPackManifest {
  const TurkeyPackManifest({
    required this.version,
    required this.generatedAt,
    required this.pmtiles,
    required this.graph,
    required this.addresses,
  });

  final String version;
  final DateTime generatedAt;
  final TurkeyPackAsset pmtiles;
  final TurkeyPackAsset graph;
  final TurkeyPackAsset addresses;

  int get totalBytes =>
      pmtiles.sizeBytes + graph.sizeBytes + addresses.sizeBytes;

  List<TurkeyPackAsset> get assets => [pmtiles, graph, addresses];

  factory TurkeyPackManifest.fromJson(Map<String, dynamic> json) =>
      TurkeyPackManifest(
        version: json['version'] as String,
        generatedAt: DateTime.parse(json['generated_at'] as String),
        pmtiles: TurkeyPackAsset.fromJson(
          'pmtiles',
          json['assets']['pmtiles'] as Map<String, dynamic>,
        ),
        graph: TurkeyPackAsset.fromJson(
          'graph',
          json['assets']['graph'] as Map<String, dynamic>,
        ),
        addresses: TurkeyPackAsset.fromJson(
          'addresses',
          json['assets']['addresses'] as Map<String, dynamic>,
        ),
      );

  Map<String, dynamic> toJson() => {
        'version': version,
        'generated_at': generatedAt.toIso8601String(),
        'assets': {
          'pmtiles': {
            'filename': pmtiles.filename,
            'url': pmtiles.url,
            'size': pmtiles.sizeBytes,
            'sha256': pmtiles.sha256,
          },
          'graph': {
            'filename': graph.filename,
            'url': graph.url,
            'size': graph.sizeBytes,
            'sha256': graph.sha256,
          },
          'addresses': {
            'filename': addresses.filename,
            'url': addresses.url,
            'size': addresses.sizeBytes,
            'sha256': addresses.sha256,
          },
        },
      };
}

/// Describes what's currently on disk.
@immutable
class TurkeyPackInfo {
  const TurkeyPackInfo({
    required this.status,
    required this.pmtilesSize,
    required this.graphSize,
    required this.addressesSize,
    required this.installedAt,
    required this.version,
  });

  final TurkeyPackStatus status;
  final int pmtilesSize;
  final int graphSize;
  final int addressesSize;
  final DateTime? installedAt;
  final String? version;

  int get totalBytes => pmtilesSize + graphSize + addressesSize;

  static const empty = TurkeyPackInfo(
    status: TurkeyPackStatus.notInstalled,
    pmtilesSize: 0,
    graphSize: 0,
    addressesSize: 0,
    installedAt: null,
    version: null,
  );
}

/// Thrown when a download is cancelled by the user.
class DownloadCancelledException implements Exception {
  const DownloadCancelledException();
  @override
  String toString() => 'Download cancelled';
}

/// Thrown when an asset's SHA-256 hash doesn't match the manifest.
class DownloadVerificationException implements Exception {
  const DownloadVerificationException(this.assetName, this.expected, this.actual);
  final String assetName;
  final String expected;
  final String actual;
  @override
  String toString() =>
      'Checksum mismatch for $assetName (expected $expected, got $actual)';
}

/// Thrown when no Turkey pack has been published to GitHub Releases yet.
class ManifestNotPublishedException implements Exception {
  const ManifestNotPublishedException();
  @override
  String toString() =>
      'Henüz yayınlanmış Türkiye paketi yok — GitHub Release oluşturulmalı';
}

/// Manages the single Turkey offline pack: manifest fetch, download, verify,
/// install, uninstall.
class TurkeyPackageService {
  TurkeyPackageService({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;
  Directory? _packDir;
  bool _cancelled = false;

  Future<Directory> _ensurePackDir() async {
    final cached = _packDir;
    if (cached != null) return cached;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, _packSubdir));
    if (!await dir.exists()) await dir.create(recursive: true);
    _packDir = dir;
    return dir;
  }

  Future<String?> installedPmtilesPath() async {
    final dir = await _ensurePackDir();
    final f = File(p.join(dir.path, turkeyPmtilesFilename));
    return await f.exists() ? f.path : null;
  }

  Future<String?> installedGraphPath() async {
    final dir = await _ensurePackDir();
    final f = File(p.join(dir.path, turkeyGraphFilename));
    return await f.exists() ? f.path : null;
  }

  /// Directory where the GraphHopper `.ghz` archive has been extracted.
  /// Returns null if the archive isn't installed yet.
  Future<String?> installedGraphDir() async {
    final dir = await _ensurePackDir();
    final graphDir = Directory(p.join(dir.path, 'graph'));
    final marker = File(p.join(graphDir.path, '.extracted_v1'));
    return await marker.exists() ? graphDir.path : null;
  }

  /// Extract `turkey.ghz` into `graph/` (idempotent). Returns the absolute
  /// path to the extracted graph directory, or null if the archive isn't
  /// installed yet.
  Future<String?> ensureGraphExtracted() async {
    final archivePath = await installedGraphPath();
    if (archivePath == null) return null;

    final packDir = await _ensurePackDir();
    final graphDir = Directory(p.join(packDir.path, 'graph'));
    final marker = File(p.join(graphDir.path, '.extracted_v1'));
    if (await marker.exists()) return graphDir.path;

    // Wipe any partial extraction before retrying.
    if (await graphDir.exists()) {
      await graphDir.delete(recursive: true);
    }
    await graphDir.create(recursive: true);

    try {
      await _extractZip(File(archivePath), graphDir);
      await marker.create();
      debugPrint('TurkeyPackageService: graph extracted to ${graphDir.path}');
      return graphDir.path;
    } catch (e) {
      debugPrint('TurkeyPackageService.ensureGraphExtracted error: $e');
      if (await graphDir.exists()) {
        try { await graphDir.delete(recursive: true); } catch (_) {}
      }
      rethrow;
    }
  }

  Future<void> _extractZip(File archive, Directory out) async {
    final bytes = await archive.readAsBytes();
    final zip = ZipDecoder().decodeBytes(bytes);
    for (final entry in zip) {
      final path = p.join(out.path, entry.name);
      if (entry.isFile) {
        final f = File(path);
        await f.parent.create(recursive: true);
        await f.writeAsBytes(entry.content as List<int>);
      } else {
        await Directory(path).create(recursive: true);
      }
    }
  }

  Future<String?> installedAddressesPath() async {
    final dir = await _ensurePackDir();
    final f = File(p.join(dir.path, turkeyAddressesFilename));
    return await f.exists() ? f.path : null;
  }

  /// Current installation info from disk.
  Future<TurkeyPackInfo> info() async {
    final dir = await _ensurePackDir();
    final pm = File(p.join(dir.path, turkeyPmtilesFilename));
    final gh = File(p.join(dir.path, turkeyGraphFilename));
    final ad = File(p.join(dir.path, turkeyAddressesFilename));
    final mf = File(p.join(dir.path, turkeyManifestFilename));

    final pmExists = await pm.exists();
    final ghExists = await gh.exists();
    final adExists = await ad.exists();

    final pmSize = pmExists ? await pm.length() : 0;
    final ghSize = ghExists ? await gh.length() : 0;
    final adSize = adExists ? await ad.length() : 0;

    final allPresent = pmExists && ghExists && adExists;
    final status = allPresent
        ? TurkeyPackStatus.installed
        : TurkeyPackStatus.notInstalled;

    DateTime? installedAt;
    String? version;
    if (pmExists) installedAt = await pm.lastModified();
    if (await mf.exists()) {
      try {
        final json = jsonDecode(await mf.readAsString()) as Map<String, dynamic>;
        version = json['version'] as String?;
      } catch (_) {}
    }

    return TurkeyPackInfo(
      status: status,
      pmtilesSize: pmSize,
      graphSize: ghSize,
      addressesSize: adSize,
      installedAt: installedAt,
      version: version,
    );
  }

  Future<bool> isInstalled() async {
    final i = await info();
    return i.status == TurkeyPackStatus.installed;
  }

  /// Fetch the remote manifest describing the latest pack.
  Future<TurkeyPackManifest> fetchManifest() async {
    final resp = await _http.get(Uri.parse(turkeyManifestUrl));
    // GitHub redirects `releases/latest/download/...` to the asset URL.
    // When no release exists yet, it returns 404.
    if (resp.statusCode == 404) {
      throw const ManifestNotPublishedException();
    }
    if (resp.statusCode != 200) {
      throw HttpException(
        'Manifest fetch failed: HTTP ${resp.statusCode}',
      );
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return TurkeyPackManifest.fromJson(json);
  }

  /// Downloads and verifies all pack components.
  ///
  /// Emits a monotonically non-decreasing progress value in [0.0, 1.0].
  /// Throws [DownloadCancelledException] if [cancel] is invoked.
  /// Throws [DownloadVerificationException] on hash mismatch.
  Stream<double> download(TurkeyPackManifest manifest) {
    _cancelled = false;
    final controller = StreamController<double>();

    () async {
      try {
        final dir = await _ensurePackDir();
        final totalBytes = manifest.totalBytes;
        var bytesBefore = 0;

        for (final asset in manifest.assets) {
          if (_cancelled) throw const DownloadCancelledException();

          final partFile = File(p.join(dir.path, '${asset.filename}.part'));
          if (await partFile.exists()) await partFile.delete();

          await _downloadAssetTo(
            asset,
            partFile,
            onReceived: (received) {
              if (totalBytes > 0) {
                final done = (bytesBefore + received) / totalBytes;
                controller.add(done.clamp(0.0, 0.99));
              }
            },
          );

          if (_cancelled) {
            await partFile.delete().catchError((_) => partFile);
            throw const DownloadCancelledException();
          }

          // Verify SHA-256.
          final actualHash = await _sha256(partFile);
          if (actualHash.toLowerCase() != asset.sha256.toLowerCase()) {
            await partFile.delete().catchError((_) => partFile);
            throw DownloadVerificationException(
              asset.name,
              asset.sha256,
              actualHash,
            );
          }

          // Atomic rename .part → final.
          final finalFile = File(p.join(dir.path, asset.filename));
          if (await finalFile.exists()) await finalFile.delete();
          await partFile.rename(finalFile.path);

          bytesBefore += asset.sizeBytes;
        }

        // Persist manifest for version tracking + provenance.
        await File(p.join(dir.path, turkeyManifestFilename))
            .writeAsString(jsonEncode(manifest.toJson()));

        controller.add(1.0);
      } catch (e, st) {
        debugPrint('TurkeyPackageService.download error: $e\n$st');
        controller.addError(e);
      } finally {
        await controller.close();
      }
    }();

    return controller.stream;
  }

  /// Streams a single asset's bytes to [out], reporting cumulative received
  /// bytes via [onReceived]. Checks [_cancelled] between chunks.
  Future<void> _downloadAssetTo(
    TurkeyPackAsset asset,
    File out, {
    required void Function(int) onReceived,
  }) async {
    final req = http.Request('GET', Uri.parse(asset.url));
    final resp = await _http.send(req);
    if (resp.statusCode != 200) {
      throw HttpException(
        '${asset.name} download failed: HTTP ${resp.statusCode}',
      );
    }

    final sink = out.openWrite();
    var received = 0;
    try {
      await for (final chunk in resp.stream) {
        if (_cancelled) break;
        sink.add(chunk);
        received += chunk.length;
        onReceived(received);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  /// Cancel an in-progress download. Safe to call at any time.
  void cancel() {
    _cancelled = true;
  }

  /// Remove all pack files from disk.
  Future<void> uninstall() async {
    try {
      final dir = await _ensurePackDir();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      _packDir = null;
    } catch (e) {
      debugPrint('TurkeyPackageService.uninstall error: $e');
    }
  }

  /// Compute SHA-256 of a file by streaming its contents.
  Future<String> _sha256(File f) async {
    final digest = await f.openRead().transform(sha256).first;
    return digest.toString();
  }
}

final turkeyPackageServiceProvider = Provider<TurkeyPackageService>((_) {
  return TurkeyPackageService();
});

/// Async snapshot of the current pack status on disk.
final turkeyPackInfoProvider = FutureProvider<TurkeyPackInfo>((ref) async {
  final svc = ref.watch(turkeyPackageServiceProvider);
  return svc.info();
});

/// Convenience: `true` when the full pack is installed.
final turkeyPackInstalledProvider = FutureProvider<bool>((ref) async {
  final svc = ref.watch(turkeyPackageServiceProvider);
  return svc.isInstalled();
});
