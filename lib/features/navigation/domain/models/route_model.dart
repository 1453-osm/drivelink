import 'package:latlong2/latlong.dart';

import 'package:drivelink/features/navigation/domain/models/turn_instruction.dart';

/// A calculated route between two points.
///
/// Contains the polyline for map rendering, total distance / duration,
/// and the ordered list of turn-by-turn instructions.
class RouteModel {
  const RouteModel({
    required this.polylinePoints,
    required this.distanceMetres,
    required this.durationSeconds,
    required this.turnInstructions,
  });

  /// Ordered list of coordinates that form the route polyline.
  final List<LatLng> polylinePoints;

  /// Total route distance in metres.
  final double distanceMetres;

  /// Estimated travel time in seconds.
  final double durationSeconds;

  /// Turn-by-turn manoeuvre instructions.
  final List<TurnInstruction> turnInstructions;

  // ── Convenience getters ───────────────────────────────────────────────

  /// Distance formatted as km (e.g. "12.3 km").
  String get formattedDistance {
    if (distanceMetres >= 1000) {
      return '${(distanceMetres / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceMetres.round()} m';
  }

  /// Duration formatted as "Xh Ym" or "Y min".
  String get formattedDuration {
    final totalMinutes = (durationSeconds / 60).round();
    if (totalMinutes >= 60) {
      final h = totalMinutes ~/ 60;
      final m = totalMinutes % 60;
      return '${h}h ${m}m';
    }
    return '$totalMinutes min';
  }

  /// Estimated arrival time from now.
  DateTime get estimatedArrival =>
      DateTime.now().add(Duration(seconds: durationSeconds.round()));

  RouteModel copyWith({
    List<LatLng>? polylinePoints,
    double? distanceMetres,
    double? durationSeconds,
    List<TurnInstruction>? turnInstructions,
  }) {
    return RouteModel(
      polylinePoints: polylinePoints ?? this.polylinePoints,
      distanceMetres: distanceMetres ?? this.distanceMetres,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      turnInstructions: turnInstructions ?? this.turnInstructions,
    );
  }

  @override
  String toString() =>
      'RouteModel(distance: $formattedDistance, duration: $formattedDuration, '
      'points: ${polylinePoints.length}, turns: ${turnInstructions.length})';
}
