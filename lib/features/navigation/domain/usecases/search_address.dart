import 'package:latlong2/latlong.dart';

import 'package:drivelink/features/navigation/domain/repositories/navigation_repository.dart';

/// Searches for addresses / places via geocoding.
class SearchAddress {
  const SearchAddress(this._repository);

  final NavigationRepository _repository;

  /// Execute the use case.
  Future<List<({String displayName, LatLng coordinate})>> call(String query) {
    return _repository.searchAddress(query);
  }
}
