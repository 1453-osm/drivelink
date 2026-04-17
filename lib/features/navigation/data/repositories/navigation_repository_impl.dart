import 'package:latlong2/latlong.dart';

import 'package:drivelink/features/navigation/domain/models/route_model.dart';
import 'package:drivelink/features/navigation/domain/models/turn_instruction.dart';
import 'package:drivelink/features/navigation/domain/repositories/navigation_repository.dart';
import 'package:drivelink/features/navigation/data/datasources/graphhopper_source.dart';
import 'package:drivelink/features/navigation/data/datasources/local_geocoding_source.dart';

/// Concrete [NavigationRepository] wiring GraphHopper routing + offline
/// geocoding.
class NavigationRepositoryImpl implements NavigationRepository {
  NavigationRepositoryImpl({
    required this.graphHopper,
    required this.geocoder,
  });

  final GraphHopperSource graphHopper;
  final LocalGeocodingSource geocoder;

  @override
  Future<RouteModel> calculateRoute(LatLng start, LatLng end) {
    return graphHopper.calculateRoute(start, end);
  }

  @override
  Future<List<({String displayName, LatLng coordinate})>> searchAddress(
      String query) {
    return geocoder.search(query);
  }

  @override
  Future<List<TurnInstruction>> getTurnInstructions(RouteModel route) async {
    // Instructions are already embedded in RouteModel from the routing source.
    return route.turnInstructions;
  }
}
