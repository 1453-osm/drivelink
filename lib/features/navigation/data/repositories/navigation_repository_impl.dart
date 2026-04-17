import 'package:latlong2/latlong.dart';

import 'package:drivelink/features/navigation/domain/models/route_model.dart';
import 'package:drivelink/features/navigation/domain/models/turn_instruction.dart';
import 'package:drivelink/features/navigation/domain/repositories/navigation_repository.dart';
import 'package:drivelink/features/navigation/data/datasources/graphhopper_source.dart';
import 'package:drivelink/features/navigation/data/datasources/nominatim_source.dart';

/// Concrete [NavigationRepository] wiring GraphHopper routing + Nominatim geocoding.
class NavigationRepositoryImpl implements NavigationRepository {
  NavigationRepositoryImpl({
    required this.graphHopper,
    required this.nominatim,
  });

  final GraphHopperSource graphHopper;
  final NominatimSource nominatim;

  @override
  Future<RouteModel> calculateRoute(LatLng start, LatLng end) {
    return graphHopper.calculateRoute(start, end);
  }

  @override
  Future<List<({String displayName, LatLng coordinate})>> searchAddress(
      String query) {
    return nominatim.search(query);
  }

  @override
  Future<List<TurnInstruction>> getTurnInstructions(RouteModel route) async {
    // Instructions are already embedded in RouteModel from GraphHopper.
    return route.turnInstructions;
  }
}
