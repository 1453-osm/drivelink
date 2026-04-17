import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// Offline neural TTS engine using Sherpa-ONNX + Piper Turkish voice.
///
/// Model is bundled in assets/tts/fahrettin.tar.bz2 (~65MB).
/// Extracted to app storage on first run, then fully offline.
class SherpaTtsEngine {
  SherpaTtsEngine();

  sherpa.OfflineTts? _tts;
  bool _initialized = false;
  bool _extracting = false;
  String? _modelDir;

  static const String _assetPath = 'assets/tts/fahrettin.tar.bz2';
  static const String _modelDirName = 'vits-piper-tr_TR-fahrettin-medium';
  static const String _modelFileName = 'tr_TR-fahrettin-medium.onnx';
  static const String _tokensFileName = 'tokens.txt';
  static const String _dataDirName = 'espeak-ng-data';
  static const String _extractedMarker = '.extracted';

  bool get isAvailable => _initialized && _tts != null;
  bool get isExtracting => _extracting;

  /// Check if model is already extracted to app storage.
  Future<bool> isModelReady() async {
    final dir = await _getModelDirectory();
    return File(p.join(dir.path, _extractedMarker)).existsSync();
  }

  /// Extract model from bundled asset (first run only).
  Future<bool> extractModel({
    void Function(String status)? onStatus,
  }) async {
    if (_extracting) return false;

    final ready = await isModelReady();
    if (ready) return true;

    _extracting = true;

    try {
      final dir = await _getModelDirectory();

      // 1. Copy asset to temp file
      onStatus?.call('Hazirlaniyor...');
      final data = await rootBundle.load(_assetPath);
      final tempFile = File(p.join(dir.path, 'temp.tar.bz2'));
      await tempFile.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );

      // 2. Extract in background isolate
      onStatus?.call('Cikariliyor...');
      final ok = await compute(_doExtract, [tempFile.path, dir.path]);

      // 3. Cleanup temp
      try { tempFile.deleteSync(); } catch (_) {}

      if (ok) {
        // Mark as extracted
        File(p.join(dir.path, _extractedMarker)).writeAsStringSync('ok');
        onStatus?.call('Hazir!');
      }

      _extracting = false;
      return ok;
    } catch (e) {
      debugPrint('[SherpaTTS] Extract error: $e');
      _extracting = false;
      return false;
    }
  }

  /// Initialize the TTS engine.
  Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      final ready = await isModelReady();
      if (!ready) {
        // Auto-extract on first init
        final ok = await extractModel();
        if (!ok) return false;
      }

      final dir = await _getModelDirectory();
      _modelDir = dir.path;

      sherpa.initBindings();

      final config = sherpa.OfflineTtsConfig(
        model: sherpa.OfflineTtsModelConfig(
          vits: sherpa.OfflineTtsVitsModelConfig(
            model: p.join(_modelDir!, _modelFileName),
            tokens: p.join(_modelDir!, _tokensFileName),
            dataDir: p.join(_modelDir!, _dataDirName),
          ),
        ),
        maxNumSenetences: 2,
      );

      _tts = sherpa.OfflineTts(config);
      _initialized = true;
      debugPrint('[SherpaTTS] Initialized with fahrettin voice');
      return true;
    } catch (e) {
      debugPrint('[SherpaTTS] Init error: $e');
      _initialized = false;
      return false;
    }
  }

  /// Generate speech and save to a temporary WAV file.
  Future<String?> generateWav(String text, {double speed = 1.0}) async {
    if (!isAvailable || text.isEmpty) return null;

    try {
      final audio = _tts!.generate(text: text, sid: 0, speed: speed);
      if (audio.samples.isEmpty) return null;

      final dir = await getTemporaryDirectory();
      final wavPath = p.join(
          dir.path, 'tts_${DateTime.now().millisecondsSinceEpoch}.wav');

      sherpa.writeWave(
        filename: wavPath,
        samples: audio.samples,
        sampleRate: audio.sampleRate,
      );

      return wavPath;
    } catch (e) {
      debugPrint('[SherpaTTS] Generate error: $e');
      return null;
    }
  }

  void dispose() {
    _tts?.free();
    _tts = null;
    _initialized = false;
  }

  // ── Private ──────────────────────────────────────────────────────────

  Future<Directory> _getModelDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(appDir.path, 'tts', _modelDirName));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Extract tar.bz2 in isolate. Returns true on success.
  static bool _doExtract(List<String> args) {
    try {
      final archivePath = args[0];
      final outputDir = args[1];
      final bytes = File(archivePath).readAsBytesSync();

      // Decompress bzip2 → tar
      final decompressed = BZip2Decoder().decodeBytes(bytes);
      final archive = TarDecoder().decodeBytes(decompressed);

      for (final entry in archive) {
        var name = entry.name;

        // Strip leading directory prefix
        const prefix = 'vits-piper-tr_TR-fahrettin-medium/';
        if (name.startsWith(prefix)) {
          name = name.substring(prefix.length);
        }
        if (name.isEmpty || name == './') continue;

        final outPath = '$outputDir/$name';

        if (entry.isFile) {
          final f = File(outPath);
          f.createSync(recursive: true);
          f.writeAsBytesSync(entry.content as List<int>);
        } else {
          Directory(outPath).createSync(recursive: true);
        }
      }

      return true;
    } catch (_) {
      return false;
    }
  }
}
