import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Address / geocoding result from Nominatim.
typedef GeocodingResult = ({String displayName, LatLng coordinate});

/// A place with bounding box — used for offline map downloads.
class NominatimPlace {
  final String displayName;
  final String type;
  final LatLng coordinate;
  final double north, south, east, west;

  const NominatimPlace({
    required this.displayName,
    required this.type,
    required this.coordinate,
    required this.north,
    required this.south,
    required this.east,
    required this.west,
  });
}

/// Geocoding data source backed by OpenStreetMap Nominatim.
///
/// Nominatim usage policy requires a custom User-Agent and max 1 req/s.
class NominatimSource {
  NominatimSource({
    this.baseUrl = 'https://nominatim.openstreetmap.org',
    this.userAgent = 'DriveLink/1.0 (car-infotainment)',
  });

  final String baseUrl;
  final String userAgent;

  /// Free-text address search.
  ///
  /// Returns up to [limit] results ordered by relevance.
  Future<List<GeocodingResult>> search(
    String query, {
    int limit = 8,
  }) async {
    if (query.trim().isEmpty) return [];

    final uri = Uri.parse('$baseUrl/search').replace(queryParameters: {
      'q': query,
      'format': 'json',
      'limit': limit.toString(),
      'addressdetails': '1',
    });

    try {
      final response = await http.get(
        uri,
        headers: {'User-Agent': userAgent},
      );

      if (response.statusCode != 200) {
        debugPrint('Nominatim error: ${response.statusCode}');
        return [];
      }

      final List<dynamic> data = json.decode(response.body);

      return data.map<GeocodingResult>((item) {
        final map = item as Map<String, dynamic>;
        return (
          displayName: map['display_name'] as String? ?? '',
          coordinate: LatLng(
            double.parse(map['lat'] as String),
            double.parse(map['lon'] as String),
          ),
        );
      }).toList();
    } catch (e) {
      debugPrint('NominatimSource.search error: $e');
      return [];
    }
  }

  /// Search for places with bounding boxes — used for offline map downloads.
  ///
  /// Returns places at country/state/city level with their bounding boxes.
  /// Prefers administrative boundaries (countries, states, cities) over
  /// individual POIs for more useful offline download regions.
  Future<List<NominatimPlace>> searchPlaces(
    String query, {
    int limit = 10,
    String? countrycodes,
  }) async {
    if (query.trim().isEmpty) return [];

    if (query.trim().length < 2) return [];

    final params = <String, String>{
      'q': query,
      'format': 'json',
      'limit': limit.toString(),
      'addressdetails': '1',
      'accept-language': 'tr,en',
    };

    if (countrycodes != null && countrycodes.isNotEmpty) {
      params['countrycodes'] = countrycodes;
    }

    final uri = Uri.parse('$baseUrl/search').replace(queryParameters: params);

    try {
      final response = await http.get(
        uri,
        headers: {'User-Agent': userAgent},
      );

      if (response.statusCode != 200) return [];

      final List<dynamic> data = json.decode(response.body);

      return data.map<NominatimPlace?>((item) {
        final map = item as Map<String, dynamic>;
        final bbox = map['boundingbox'] as List<dynamic>?;
        if (bbox == null || bbox.length < 4) return null;

        return NominatimPlace(
          displayName: map['display_name'] as String? ?? '',
          type: map['type'] as String? ?? '',
          coordinate: LatLng(
            double.parse(map['lat'] as String),
            double.parse(map['lon'] as String),
          ),
          south: double.parse(bbox[0] as String),
          north: double.parse(bbox[1] as String),
          west: double.parse(bbox[2] as String),
          east: double.parse(bbox[3] as String),
        );
      }).whereType<NominatimPlace>().toList();
    } catch (e) {
      debugPrint('NominatimSource.searchPlaces error: $e');
      return [];
    }
  }

  /// Reverse geocode a coordinate to an address string.
  Future<String?> reverseGeocode(LatLng point) async {
    final uri = Uri.parse('$baseUrl/reverse').replace(queryParameters: {
      'lat': point.latitude.toString(),
      'lon': point.longitude.toString(),
      'format': 'json',
    });

    try {
      final response = await http.get(
        uri,
        headers: {'User-Agent': userAgent},
      );

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      return data['display_name'] as String?;
    } catch (e) {
      debugPrint('NominatimSource.reverseGeocode error: $e');
      return null;
    }
  }

  /// Reverse geocode at region/state level (OsmAnd-style).
  ///
  /// Uses addressdetails to extract the region/state name, then searches
  /// for that region to get its proper bounding box.
  ///
  /// Priority: address.region > address.state > display_name parsing
  Future<NominatimPlace?> reverseGeocodeRegion(LatLng point) async {
    try {
      // Step 1: reverse geocode with addressdetails.
      final revUri = Uri.parse('$baseUrl/reverse').replace(queryParameters: {
        'lat': point.latitude.toString(),
        'lon': point.longitude.toString(),
        'format': 'json',
        'zoom': '5',
        'addressdetails': '1',
        'accept-language': 'tr,en',
      });

      final revResponse = await http.get(
        revUri, headers: {'User-Agent': userAgent},
      );
      if (revResponse.statusCode != 200) return null;

      final revData = json.decode(revResponse.body) as Map<String, dynamic>;
      final address = revData['address'] as Map<String, dynamic>? ?? {};

      // Extract region name from structured address.
      // Turkey: address.region = "Marmara Bölgesi"
      // France: address.state = "Île-de-France"
      // USA: address.state = "California"
      final regionName = address['region'] as String? ??
          address['state'] as String? ??
          address['province'] as String?;
      final country = address['country'] as String?;

      debugPrint('reverseGeocodeRegion: region=$regionName, country=$country');

      if (regionName == null || regionName.isEmpty) {
        // Fallback to zoom=5 bbox (il/province level).
        return _parsePlaceFromReverse(revData);
      }

      // Step 2: search for the region name to get its real bbox.
      final searchQuery = country != null
          ? '$regionName, $country'
          : regionName;

      final searchUri = Uri.parse('$baseUrl/search').replace(queryParameters: {
        'q': searchQuery,
        'format': 'json',
        'limit': '1',
        'accept-language': 'tr,en',
      });

      final searchResponse = await http.get(
        searchUri, headers: {'User-Agent': userAgent},
      );

      if (searchResponse.statusCode == 200) {
        final results = json.decode(searchResponse.body) as List<dynamic>;
        if (results.isNotEmpty) {
          final r = results.first as Map<String, dynamic>;
          final bbox = r['boundingbox'] as List<dynamic>?;
          if (bbox != null && bbox.length >= 4) {
            final place = NominatimPlace(
              displayName: r['display_name'] as String? ?? regionName,
              type: 'region',
              coordinate: LatLng(
                double.parse(r['lat'] as String),
                double.parse(r['lon'] as String),
              ),
              south: double.parse(bbox[0] as String),
              north: double.parse(bbox[1] as String),
              west: double.parse(bbox[2] as String),
              east: double.parse(bbox[3] as String),
            );
            debugPrint('reverseGeocodeRegion: found $regionName '
                'N${place.north} S${place.south} E${place.east} W${place.west}');
            return place;
          }
        }
      }

      // Fallback to reverse geocode bbox.
      return _parsePlaceFromReverse(revData);
    } catch (e) {
      debugPrint('reverseGeocodeRegion error: $e');
      return null;
    }
  }

  NominatimPlace? _parsePlaceFromReverse(Map<String, dynamic> data) {
    final bbox = data['boundingbox'] as List<dynamic>?;
    if (bbox == null || bbox.length < 4) return null;
    return NominatimPlace(
      displayName: data['display_name'] as String? ?? '',
      type: 'state',
      coordinate: LatLng(
        double.parse(data['lat'] as String),
        double.parse(data['lon'] as String),
      ),
      south: double.parse(bbox[0] as String),
      north: double.parse(bbox[1] as String),
      west: double.parse(bbox[2] as String),
      east: double.parse(bbox[3] as String),
    );
  }
}
