import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:drivelink/features/navigation/data/datasources/route_cache.dart';
import 'package:drivelink/features/navigation/domain/models/route_model.dart';
import 'package:drivelink/features/navigation/domain/models/turn_instruction.dart';

/// Max polyline points — longer routes are downsampled.
const _maxPolylinePoints = 800;

class GraphHopperSource {
  GraphHopperSource({
    this.osrmBaseUrl = 'https://router.project-osrm.org',
  });

  final String osrmBaseUrl;

  final _cache = RouteCache();

  Future<RouteModel> calculateRoute(LatLng start, LatLng end) async {
    // Try online.
    if (await _hasInternet()) {
      try {
        debugPrint('OSRM: ${start.latitude},${start.longitude} → ${end.latitude},${end.longitude}');
        final route = await _fetch(start, end);
        debugPrint('OSRM: ${route.polylinePoints.length} pts, ${route.formattedDistance}');
        // Cache for offline use.
        _cache.save(start, end, route);
        return route;
      } catch (e, st) {
        debugPrint('OSRM failed: $e\n$st');
      }
    }

    // Try cached route.
    final cached = await _cache.findNearby(start, end);
    if (cached != null) {
      debugPrint('OSRM: using cached route (${cached.polylinePoints.length} pts)');
      return cached;
    }

    debugPrint('OSRM: offline, no cache — stub route');
    return _stubRoute(start, end);
  }

  Future<bool> _hasInternet() async {
    try {
      final r = await InternetAddress.lookup('router.project-osrm.org')
          .timeout(const Duration(seconds: 3));
      return r.isNotEmpty && r.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<RouteModel> _fetch(LatLng start, LatLng end) async {
    final coords =
        '${start.longitude},${start.latitude};${end.longitude},${end.latitude}';
    final url =
        '$osrmBaseUrl/route/v1/driving/$coords'
        '?overview=full&geometries=polyline&steps=true';

    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    // Parse in isolate to avoid jank on main thread.
    return compute(_parseResponse, response.body);
  }

  /// Top-level function for isolate — must not reference instance members.
  static RouteModel _parseResponse(String body) {
    final data = json.decode(body) as Map<String, dynamic>;

    if (data['code'] != 'Ok') {
      throw Exception('OSRM: ${data['code']} ${data['message'] ?? ''}');
    }

    final route = (data['routes'] as List).first as Map<String, dynamic>;
    final distance = (route['distance'] as num).toDouble();
    final duration = (route['duration'] as num).toDouble();

    // Decode encoded polyline (compact string → List<LatLng>).
    var polyline = _decodePolyline(route['geometry'] as String);

    // Downsample if too many points.
    if (polyline.length > _maxPolylinePoints) {
      polyline = _downsample(polyline, _maxPolylinePoints);
    }

    // Parse turn instructions from steps.
    final instructions = <TurnInstruction>[];
    for (final leg in route['legs'] as List) {
      for (final step in (leg as Map<String, dynamic>)['steps'] as List) {
        final s = step as Map<String, dynamic>;
        final m = s['maneuver'] as Map<String, dynamic>;
        final type = m['type'] as String? ?? '';
        if (type == 'depart') continue;

        final modifier = m['modifier'] as String? ?? '';
        instructions.add(TurnInstruction(
          type: _mapManeuver(type, modifier),
          distance: (s['distance'] as num).toDouble(),
          streetName: s['name'] as String? ?? '',
          exitNumber: (type == 'roundabout' || type == 'rotary')
              ? m['exit'] as int?
              : null,
        ));
      }
    }

    return RouteModel(
      polylinePoints: polyline,
      distanceMetres: distance,
      durationSeconds: duration,
      turnInstructions: instructions,
    );
  }

  static TurnType _mapManeuver(String type, String mod) {
    if (type == 'arrive') return TurnType.arrive;
    if (type == 'roundabout' || type == 'rotary') return TurnType.roundabout;
    if (type == 'turn' || type == 'end of road' || type == 'fork') {
      if (mod.contains('left')) return TurnType.turnLeft;
      if (mod.contains('right')) return TurnType.turnRight;
      if (mod.contains('uturn')) return TurnType.uturn;
    }
    if (type == 'merge') {
      if (mod.contains('left')) return TurnType.mergeLeft;
      if (mod.contains('right')) return TurnType.mergeRight;
    }
    return TurnType.continue_;
  }

  /// Decode Google-encoded polyline (precision 5).
  static List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int i = 0, lat = 0, lng = 0;
    while (i < encoded.length) {
      int shift = 0, result = 0, b;
      do { b = encoded.codeUnitAt(i++) - 63; result |= (b & 0x1F) << shift; shift += 5; } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      shift = 0; result = 0;
      do { b = encoded.codeUnitAt(i++) - 63; result |= (b & 0x1F) << shift; shift += 5; } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  /// Douglas-Peucker simplification — preserves corners/turns, removes
  /// points on straight segments. Adjusts epsilon until under [max] points.
  static List<LatLng> _downsample(List<LatLng> pts, int max) {
    if (pts.length <= max) return pts;

    double epsilon = 0.00005; // ~5m
    var result = _douglasPeucker(pts, epsilon);

    // Increase epsilon until we're under max.
    while (result.length > max && epsilon < 0.01) {
      epsilon *= 2;
      result = _douglasPeucker(pts, epsilon);
    }

    return result;
  }

  static List<LatLng> _douglasPeucker(List<LatLng> pts, double epsilon) {
    if (pts.length < 3) return pts;

    double maxDist = 0;
    int index = 0;
    final first = pts.first;
    final last = pts.last;

    for (int i = 1; i < pts.length - 1; i++) {
      final d = _perpDist(pts[i], first, last);
      if (d > maxDist) {
        maxDist = d;
        index = i;
      }
    }

    if (maxDist > epsilon) {
      final left = _douglasPeucker(pts.sublist(0, index + 1), epsilon);
      final right = _douglasPeucker(pts.sublist(index), epsilon);
      return [...left.sublist(0, left.length - 1), ...right];
    }

    return [first, last];
  }

  /// Perpendicular distance from point to line (first→last) in degrees.
  static double _perpDist(LatLng p, LatLng a, LatLng b) {
    final dx = b.longitude - a.longitude;
    final dy = b.latitude - a.latitude;
    if (dx == 0 && dy == 0) {
      final dlat = p.latitude - a.latitude;
      final dlng = p.longitude - a.longitude;
      return math.sqrt(dlat * dlat + dlng * dlng);
    }
    // Distance from point to line using cross product formula.
    final num = ((p.longitude - a.longitude) * dy - (p.latitude - a.latitude) * dx).abs();
    final den = math.sqrt(dx * dx + dy * dy);
    return num / den;
  }

  RouteModel _stubRoute(LatLng start, LatLng end) {
    final dist = const Distance().as(LengthUnit.Meter, start, end);
    return RouteModel(
      polylinePoints: [start, end],
      distanceMetres: dist,
      durationSeconds: dist / 13.9,
      turnInstructions: [
        TurnInstruction(type: TurnType.continue_, distance: dist, streetName: 'Rota hesaplanamadi'),
        const TurnInstruction(type: TurnType.arrive, distance: 0, streetName: 'Hedef'),
      ],
    );
  }
}
