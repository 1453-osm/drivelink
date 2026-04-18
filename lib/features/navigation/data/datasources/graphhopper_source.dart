import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:drivelink/core/services/turkey_package_service.dart';
import 'package:drivelink/features/navigation/domain/models/route_model.dart';
import 'package:drivelink/features/navigation/domain/models/turn_instruction.dart';

const _channel = MethodChannel('drivelink/graphhopper');

/// Offline routing source backed by GraphHopper running natively on Android.
///
/// The heavy lifting (graph parsing, Dijkstra/CH) happens in
/// `GraphHopperBridge.kt` — this Dart class only marshals requests and
/// parses responses.
///
/// Lifecycle:
///   * [ensureLoaded] — idempotent; unpacks `turkey.ghz` if needed, then
///     calls the native `load` method. Safe to call repeatedly.
///   * [calculateRoute] — routes between two points; returns a stub
///     straight-line [RouteModel] if the graph isn't installed so the UI
///     can still render a "no pack" state.
///   * [close] — releases native resources (called when the pack is
///     uninstalled).
/// Describes why the last routing attempt fell back to a straight-line stub,
/// so the UI can surface a useful error message to the user.
enum RoutingFallbackReason {
  /// Everything is fine — returned by the normal path.
  none,

  /// The Turkey pack isn't installed yet (or the .ghz hasn't been unpacked).
  graphNotInstalled,

  /// Native GraphHopper failed to load the graph (error detail in message).
  graphLoadFailed,

  /// `route()` itself threw (e.g. no path between the two points).
  routeFailed,
}

class RoutingFallback {
  const RoutingFallback(this.reason, [this.message]);
  final RoutingFallbackReason reason;
  final String? message;

  @override
  String toString() => message ?? reason.name;

  static const none = RoutingFallback(RoutingFallbackReason.none);
}

class GraphHopperSource {
  GraphHopperSource(this._pack);

  final TurkeyPackageService _pack;

  bool _loaded = false;
  Future<void>? _loadFuture;

  /// Why the most recent call fell back to a stub. Read by the UI to
  /// show the user a meaningful error instead of "no internet".
  RoutingFallback lastFallback = RoutingFallback.none;

  Future<bool> ensureLoaded() async {
    if (_loaded) return true;
    _loadFuture ??= _load();
    try {
      await _loadFuture;
      return _loaded;
    } finally {
      _loadFuture = null;
    }
  }

  Future<void> _load() async {
    final graphDir = await _pack.ensureGraphExtracted();
    if (graphDir == null) {
      lastFallback = const RoutingFallback(
        RoutingFallbackReason.graphNotInstalled,
        'Türkiye paketi yüklü değil — önce indir',
      );
      debugPrint('GraphHopperSource: graph not installed — skipping load');
      return;
    }
    try {
      await _channel.invokeMethod<void>('load', {
        'graphPath': graphDir,
        'profile': 'car',
      });
      _loaded = true;
      lastFallback = RoutingFallback.none;
      debugPrint('GraphHopperSource: loaded $graphDir');
    } on PlatformException catch (e) {
      final details = e.details is String ? e.details as String : '';
      final msg = [e.message, if (details.isNotEmpty) details.split('\n').first]
          .whereType<String>()
          .join(' — ');
      lastFallback = RoutingFallback(
        RoutingFallbackReason.graphLoadFailed,
        'Rota motoru yüklenemedi: $msg',
      );
      debugPrint('GraphHopperSource load error: ${e.code} ${e.message}\n${e.details}');
    }
  }

  Future<RouteModel> calculateRoute(LatLng start, LatLng end) async {
    final ok = await ensureLoaded();
    if (!ok) {
      debugPrint('GraphHopperSource: no graph — returning stub (${lastFallback.reason})');
      return _stubRoute(start, end);
    }

    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('route', {
        'fromLat': start.latitude,
        'fromLng': start.longitude,
        'toLat': end.latitude,
        'toLng': end.longitude,
        'profile': 'car',
      });
      if (raw == null) {
        lastFallback = const RoutingFallback(
          RoutingFallbackReason.routeFailed,
          'Rota bulunamadı',
        );
        return _stubRoute(start, end);
      }
      lastFallback = RoutingFallback.none;
      return _parseRoute(raw);
    } on PlatformException catch (e) {
      final msg = e.message ?? e.code;
      lastFallback = RoutingFallback(
        RoutingFallbackReason.routeFailed,
        'Rota hesaplanamadı: $msg',
      );
      debugPrint('GraphHopperSource route error: ${e.code} ${e.message}\n${e.details}');
      return _stubRoute(start, end);
    }
  }

  Future<void> close() async {
    try {
      await _channel.invokeMethod<void>('close');
    } on PlatformException catch (e) {
      debugPrint('GraphHopperSource close error: ${e.message}');
    }
    _loaded = false;
  }

  // ── Parsing ──────────────────────────────────────────────────────────

  RouteModel _parseRoute(Map<String, dynamic> raw) {
    final distance = (raw['distanceMetres'] as num).toDouble();
    final duration = (raw['durationSeconds'] as num).toDouble();
    final flat = (raw['polyline'] as List).cast<num>();
    final points = <LatLng>[];
    for (var i = 0; i + 1 < flat.length; i += 2) {
      points.add(LatLng(flat[i].toDouble(), flat[i + 1].toDouble()));
    }
    final instructionsRaw = (raw['instructions'] as List?) ?? const [];
    final instructions = instructionsRaw
        .cast<Map<Object?, Object?>>()
        .map(_parseInstruction)
        .toList();

    return RouteModel(
      polylinePoints: points,
      distanceMetres: distance,
      durationSeconds: duration,
      turnInstructions: instructions,
    );
  }

  TurnInstruction _parseInstruction(Map<Object?, Object?> m) {
    final sign = (m['sign'] as num?)?.toInt() ?? 0;
    final name = (m['name'] as String?) ?? '';
    final dist = (m['distanceMetres'] as num?)?.toDouble() ?? 0;
    return TurnInstruction(
      type: _turnTypeFromSign(sign),
      distance: dist,
      streetName: name,
    );
  }

  /// GraphHopper instruction sign codes → our [TurnType] enum.
  /// Reference: https://github.com/graphhopper/graphhopper/blob/master/api/src/main/java/com/graphhopper/util/Instruction.java
  TurnType _turnTypeFromSign(int sign) {
    return switch (sign) {
      -3 || -2 || -1 => TurnType.turnLeft,
      1 || 2 || 3 => TurnType.turnRight,
      0 => TurnType.continue_,
      4 => TurnType.arrive,
      6 => TurnType.roundabout,
      -7 => TurnType.mergeLeft,
      7 => TurnType.mergeRight,
      -98 || -8 || 8 => TurnType.uturn,
      _ => TurnType.continue_,
    };
  }

  // ── Stub ─────────────────────────────────────────────────────────────

  RouteModel _stubRoute(LatLng from, LatLng to) {
    final dist = const Distance().as(LengthUnit.Meter, from, to);
    return RouteModel(
      polylinePoints: [from, to],
      distanceMetres: dist,
      durationSeconds: dist / 13.9, // ~50 km/h fallback estimate
      turnInstructions: const [],
    );
  }
}

final graphHopperSourceProvider = Provider<GraphHopperSource>((ref) {
  return GraphHopperSource(ref.watch(turkeyPackageServiceProvider));
});
