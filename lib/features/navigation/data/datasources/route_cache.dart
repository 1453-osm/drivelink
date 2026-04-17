import 'dart:convert';
import 'dart:io';

import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

import 'package:drivelink/features/navigation/domain/models/route_model.dart';
import 'package:drivelink/features/navigation/domain/models/turn_instruction.dart';

class RouteCache {
  static Future<Directory> _dir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/route_cache');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  static String _key(LatLng s, LatLng e) {
    final sLat = (s.latitude * 500).round();
    final sLng = (s.longitude * 500).round();
    final eLat = (e.latitude * 500).round();
    final eLng = (e.longitude * 500).round();
    return '${sLat}_${sLng}_${eLat}_$eLng';
  }

  Future<void> save(LatLng start, LatLng end, RouteModel route) async {
    try {
      final dir = await _dir();
      final file = File('${dir.path}/${_key(start, end)}.json');
      await file.writeAsString(jsonEncode({
        'd': route.distanceMetres,
        't': route.durationSeconds,
        'p': route.polylinePoints.map((p) => [p.latitude, p.longitude]).toList(),
        'i': route.turnInstructions.map((i) => {
          'ty': i.type.index,
          'd': i.distance,
          's': i.streetName,
          'e': i.exitNumber,
        }).toList(),
        'at': DateTime.now().toIso8601String(),
      }));
    } catch (_) {}
  }

  Future<RouteModel?> load(LatLng start, LatLng end) async {
    try {
      final dir = await _dir();
      final file = File('${dir.path}/${_key(start, end)}.json');
      if (!file.existsSync()) return null;

      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final savedAt = DateTime.parse(data['at'] as String);
      if (DateTime.now().difference(savedAt).inDays > 7) {
        await file.delete();
        return null;
      }

      return RouteModel(
        distanceMetres: (data['d'] as num).toDouble(),
        durationSeconds: (data['t'] as num).toDouble(),
        polylinePoints: (data['p'] as List)
            .map((p) => LatLng((p as List)[0] as double, p[1] as double))
            .toList(),
        turnInstructions: (data['i'] as List).map((i) {
          final m = i as Map<String, dynamic>;
          return TurnInstruction(
            type: TurnType.values[m['ty'] as int],
            distance: (m['d'] as num).toDouble(),
            streetName: m['s'] as String? ?? '',
            exitNumber: m['e'] as int?,
          );
        }).toList(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<RouteModel?> findNearby(LatLng start, LatLng end) async {
    final exact = await load(start, end);
    if (exact != null) return exact;

    final sLat = (start.latitude * 500).round();
    final sLng = (start.longitude * 500).round();
    final eLat = (end.latitude * 500).round();
    final eLng = (end.longitude * 500).round();

    final dir = await _dir();
    for (int ds = -1; ds <= 1; ds++) {
      for (int de = -1; de <= 1; de++) {
        final key = '${sLat + ds}_${sLng}_${eLat + de}_$eLng';
        final file = File('${dir.path}/$key.json');
        if (file.existsSync()) {
          try {
            final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
            final savedAt = DateTime.parse(data['at'] as String);
            if (DateTime.now().difference(savedAt).inDays > 7) continue;
            return RouteModel(
              distanceMetres: (data['d'] as num).toDouble(),
              durationSeconds: (data['t'] as num).toDouble(),
              polylinePoints: (data['p'] as List)
                  .map((p) => LatLng((p as List)[0] as double, p[1] as double))
                  .toList(),
              turnInstructions: (data['i'] as List).map((i) {
                final m = i as Map<String, dynamic>;
                return TurnInstruction(
                  type: TurnType.values[m['ty'] as int],
                  distance: (m['d'] as num).toDouble(),
                  streetName: m['s'] as String? ?? '',
                  exitNumber: m['e'] as int?,
                );
              }).toList(),
            );
          } catch (_) {}
        }
      }
    }
    return null;
  }
}
