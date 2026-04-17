import 'package:latlong2/latlong.dart';

import 'package:drivelink/features/navigation/domain/models/route_model.dart';
import 'package:drivelink/features/navigation/domain/models/turn_instruction.dart';

/// Contract for navigation data operations.
///
/// Implementations may use GraphHopper, OSRM, or an offline routing engine.
abstract class NavigationRepository {
  /// Calculate a driving route from [start] to [end].
  Future<RouteModel> calculateRoute(LatLng start, LatLng end);

  /// Search for an address / place by free-text [query].
  ///
  /// Returns a list of `(displayName, coordinate)` pairs.
  Future<List<({String displayName, LatLng coordinate})>> searchAddress(
      String query);

  /// Extract turn-by-turn instructions from a previously calculated [route].
  Future<List<TurnInstruction>> getTurnInstructions(RouteModel route);
}
