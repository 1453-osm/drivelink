import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Canonical filenames for the Turkey offline pack components.
const turkeyPmtilesFilename = 'turkey.pmtiles';
const turkeyGraphFilename = 'turkey.ghz';
const turkeyAddressesFilename = 'turkey_addresses.db';
const _packSubdir = 'turkey_pack';

/// Stages of the Turkey pack installation lifecycle.
enum TurkeyPackStatus {
  /// No pack present at all.
  notInstalled,

  /// Download in progress (see [TurkeyPackageService.downloadProgress]).
  downloading,

  /// Pack is fully installed and ready to use.
  installed,
}

/// Describes what's currently on disk.
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

/// Manages the single Turkey offline pack (pmtiles + routing graph + addresses).
///
/// This is the Faz 1 stub — disk-inspection only. Download/verify/remove
/// logic arrives in Faz 2.
class TurkeyPackageService {
  Directory? _packDir;

  /// Root directory of the installed pack (e.g. `.../files/turkey_pack/`).
  Future<Directory> _ensurePackDir() async {
    final cached = _packDir;
    if (cached != null) return cached;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, _packSubdir));
    if (!await dir.exists()) await dir.create(recursive: true);
    _packDir = dir;
    return dir;
  }

  /// Absolute path to the installed pmtiles file, or null if not yet present.
  Future<String?> installedPmtilesPath() async {
    final dir = await _ensurePackDir();
    final f = File(p.join(dir.path, turkeyPmtilesFilename));
    return await f.exists() ? f.path : null;
  }

  /// Absolute path to the installed routing graph file, or null.
  Future<String?> installedGraphPath() async {
    final dir = await _ensurePackDir();
    final f = File(p.join(dir.path, turkeyGraphFilename));
    return await f.exists() ? f.path : null;
  }

  /// Absolute path to the installed address database, or null.
  Future<String?> installedAddressesPath() async {
    final dir = await _ensurePackDir();
    final f = File(p.join(dir.path, turkeyAddressesFilename));
    return await f.exists() ? f.path : null;
  }

  /// Current installation info — sizes, status, timestamp.
  Future<TurkeyPackInfo> info() async {
    final pm = await installedPmtilesPath();
    final gh = await installedGraphPath();
    final ad = await installedAddressesPath();

    final pmSize = pm != null ? await File(pm).length() : 0;
    final ghSize = gh != null ? await File(gh).length() : 0;
    final adSize = ad != null ? await File(ad).length() : 0;

    final allPresent = pm != null && gh != null && ad != null;
    final status = allPresent
        ? TurkeyPackStatus.installed
        : TurkeyPackStatus.notInstalled;

    DateTime? installedAt;
    if (pm != null) {
      installedAt = await File(pm).lastModified();
    }

    return TurkeyPackInfo(
      status: status,
      pmtilesSize: pmSize,
      graphSize: ghSize,
      addressesSize: adSize,
      installedAt: installedAt,
      version: null,
    );
  }

  /// Convenience: true when all three pack files exist.
  Future<bool> isInstalled() async {
    final i = await info();
    return i.status == TurkeyPackStatus.installed;
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
}

final turkeyPackageServiceProvider = Provider<TurkeyPackageService>((_) {
  return TurkeyPackageService();
});

/// Async snapshot of the current pack status.
final turkeyPackInfoProvider = FutureProvider<TurkeyPackInfo>((ref) async {
  final svc = ref.watch(turkeyPackageServiceProvider);
  return svc.info();
});

/// Convenience: `true` when the full pack is installed.
final turkeyPackInstalledProvider = FutureProvider<bool>((ref) async {
  final svc = ref.watch(turkeyPackageServiceProvider);
  return svc.isInstalled();
});
