import 'package:latlong2/latlong.dart';

import 'package:drivelink/features/navigation/domain/models/route_model.dart';
import 'package:drivelink/features/navigation/domain/repositories/navigation_repository.dart';

/// Calculates a driving route between two geographic points.
class CalculateRoute {
  const CalculateRoute(this._repository);

  final NavigationRepository _repository;

  /// Execute the use case.
  Future<RouteModel> call(LatLng start, LatLng end) {
    return _repository.calculateRoute(start, end);
  }
}
