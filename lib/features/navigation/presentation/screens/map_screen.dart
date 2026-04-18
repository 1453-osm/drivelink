import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/core/services/location_service.dart';
import 'package:drivelink/core/services/region_coverage_service.dart';
import 'package:drivelink/core/services/tts_service.dart';
import 'package:drivelink/core/services/turkey_package_service.dart';
import 'package:drivelink/features/navigation/data/datasources/graphhopper_source.dart';
import 'package:drivelink/features/navigation/data/datasources/local_poi_source.dart';
import 'package:drivelink/features/navigation/domain/models/route_model.dart';
import 'package:drivelink/features/navigation/domain/models/turn_instruction.dart';
import 'package:drivelink/features/navigation/data/map_style_loader.dart';
import 'package:drivelink/features/navigation/presentation/widgets/turn_instruction_widget.dart';
import 'package:drivelink/features/navigation/presentation/widgets/route_info_bar.dart';
import 'package:drivelink/features/navigation/presentation/screens/route_search_screen.dart';


/// Navigation states:
///   idle        — no route, free map browsing
///   calculating — route request in progress
///   preview     — route shown on map, waiting for user to start
///   navigating  — active turn-by-turn guidance
enum _NavState { idle, calculating, preview, navigating }

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  ml.MapLibreMapController? _controller;

  late ll.LatLng _currentPosition;
  double _currentHeading = 0;
  double _currentSpeedKmh = 0;
  bool _gotFirstFix = false;
  bool _mapReady = false;

  // Map style state (initialized in didChangeDependencies from theme brightness).
  MapStyle _mapStyle = MapStyle.dark;
  String? _currentStyleJson;
  bool _styleLoading = false;
  bool _styleInitialized = false;

  _NavState _navState = _NavState.idle;
  RouteModel? _activeRoute;
  String _destinationName = '';
  bool _isFollowing = false;

  // Map objects
  ml.Circle? _posCircle;
  ml.Circle? _destCircle;
  ml.Line? _routeLine;
  final List<ml.Fill> _turkeyFills = [];
  final List<ml.Line> _turkeyOutlines = [];
  bool _turkeyOverlayDrawn = false;

  List<List<ml.LatLng>>? _turkeyRings;

  // Route tracking (only active during _NavState.navigating)
  int _currentInstructionIndex = 0;
  double _remainingDistanceM = 0;
  double _remainingDurationS = 0;
  int _lastSpokenInstructionIndex = -1;
  int _nearestPolylineIndex = 0;

  // POI state
  Set<String> _activePois = {};
  List<PoiResult> _poiResults = [];
  List<ml.Circle> _poiCircles = [];
  bool _poiLoading = false;

  bool _showMapDownloadBanner = false;

  @override
  void initState() {
    super.initState();
    _currentPosition = defaultMapCenter;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final knownPos = ref.read(lastKnownPositionProvider);
      if (knownPos != null) {
        _currentPosition = knownPos;
        _gotFirstFix = true;
      } else {
        _currentPosition = ref.read(defaultMapPositionProvider);
      }
      final installed =
          ref.read(turkeyPackInstalledProvider).valueOrNull ?? false;
      if (!installed) _showMapDownloadBanner = true;
      setState(() {});
    });
    _loadTurkeyRings();
  }

  Future<void> _loadTurkeyRings() async {
    try {
      final raw = await rootBundle.loadString('assets/geo/turkey.geojson');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final feature = (json['features'] as List).first as Map<String, dynamic>;
      final geom = feature['geometry'] as Map<String, dynamic>;
      final type = geom['type'] as String;
      final coords = geom['coordinates'] as List;

      final rings = <List<ml.LatLng>>[];
      if (type == 'MultiPolygon') {
        for (final poly in coords) {
          final outer = (poly as List).first as List;
          rings.add([
            for (final pt in outer)
              ml.LatLng(
              ((pt as List)[1] as num).toDouble(),
              (pt[0] as num).toDouble(),
            ),
          ]);
        }
      } else if (type == 'Polygon') {
        final outer = coords.first as List;
        rings.add([
          for (final pt in outer)
            ml.LatLng(
              ((pt as List)[1] as num).toDouble(),
              (pt[0] as num).toDouble(),
            ),
        ]);
      }
      _turkeyRings = rings;
      if (_mapReady && !_turkeyOverlayDrawn) _drawTurkeyOverlay();
    } catch (e) {
      debugPrint('MapScreen: Turkey GeoJSON load failed: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_styleInitialized) return;
    final brightness = Theme.of(context).brightness;
    _mapStyle = brightness == Brightness.light ? MapStyle.light : MapStyle.dark;
    _styleInitialized = true;
    _loadInitialStyle();
  }

  Future<void> _loadInitialStyle() async {
    try {
      final json = await ref.read(mapStyleLoaderProvider).load(_mapStyle);
      if (!mounted) return;
      setState(() => _currentStyleJson = json);
    } catch (e) {
      debugPrint('MapScreen: initial style load failed: $e');
    }
  }

  void _onMapCreated(ml.MapLibreMapController controller) {
    _controller = controller;
  }

  void _onStyleLoaded() async {
    _mapReady = true;
    _turkeyOverlayDrawn = false;
    if (_gotFirstFix) {
      _controller?.animateCamera(
        ml.CameraUpdate.newLatLngZoom(_toMl(_currentPosition), 15),
      );
    }
    _updatePositionCircle();
    await _drawTurkeyOverlay();
    // Restore route if active.
    if (_activeRoute != null) {
      _setRoutePolyline(_activeRoute!.polylinePoints);
      if (_activeRoute!.polylinePoints.length >= 2) {
        _updateDestinationCircle(_activeRoute!.polylinePoints.last);
      }
    }
  }

  /// Draws the Türkiye polygon as a translucent green fill + outline when
  /// the offline pack is installed. When it isn't, draws only the outline
  /// as a hint of what the user will get after downloading.
  Future<void> _drawTurkeyOverlay() async {
    final c = _controller;
    if (c == null || !_mapReady || _turkeyOverlayDrawn) return;
    final rings = _turkeyRings;
    if (rings == null || rings.isEmpty) return;

    // Remove old objects first.
    for (final f in _turkeyFills) {
      try { await c.removeFill(f); } catch (_) {}
    }
    for (final l in _turkeyOutlines) {
      try { await c.removeLine(l); } catch (_) {}
    }
    _turkeyFills.clear();
    _turkeyOutlines.clear();

    final installed =
        ref.read(turkeyPackInstalledProvider).valueOrNull ?? false;

    for (final ring in rings) {
      try {
        if (installed) {
          final fill = await c.addFill(ml.FillOptions(
            geometry: [ring],
            fillColor: '#4CAF50',
            fillOpacity: 0.12,
          ));
          _turkeyFills.add(fill);
        }
        final outline = await c.addLine(ml.LineOptions(
          geometry: ring,
          lineColor: '#4CAF50',
          lineWidth: 2.0,
          lineOpacity: installed ? 0.7 : 0.4,
        ));
        _turkeyOutlines.add(outline);
      } catch (e) {
        debugPrint('drawTurkeyOverlay error: $e');
      }
    }
    _turkeyOverlayDrawn = true;
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ── Conversion helpers ──────────────────────────────────────────

  ml.LatLng _toMl(ll.LatLng p) => ml.LatLng(p.latitude, p.longitude);
  ll.LatLng _toLl(ml.LatLng p) => ll.LatLng(p.latitude, p.longitude);

  // ── Map object management ───────────────────────────────────────

  Future<void> _updatePositionCircle() async {
    final c = _controller;
    if (c == null || !_mapReady) return;

    final pos = _toMl(_currentPosition);
    if (_posCircle != null) {
      await c.updateCircle(_posCircle!, ml.CircleOptions(geometry: pos));
    } else {
      _posCircle = await c.addCircle(ml.CircleOptions(
        geometry: pos,
        circleRadius: 8,
        circleColor: '#2196F3',
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 3,
      ));
    }
  }

  Future<void> _updateDestinationCircle(ll.LatLng? dest) async {
    final c = _controller;
    if (c == null || !_mapReady) return;

    if (dest == null) {
      if (_destCircle != null) {
        await c.removeCircle(_destCircle!);
        _destCircle = null;
      }
      return;
    }

    final pos = _toMl(dest);
    if (_destCircle != null) {
      await c.updateCircle(_destCircle!, ml.CircleOptions(geometry: pos));
    } else {
      _destCircle = await c.addCircle(ml.CircleOptions(
        geometry: pos,
        circleRadius: 10,
        circleColor: '#F44336',
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 2,
      ));
    }
  }

  Future<void> _setRoutePolyline(List<ll.LatLng> points) async {
    final c = _controller;
    if (c == null || !_mapReady || points.isEmpty) return;

    try {
      final mlPoints = points
          .map((p) => ml.LatLng(p.latitude, p.longitude))
          .toList();

      if (_routeLine != null) {
        await c.updateLine(
          _routeLine!,
          ml.LineOptions(geometry: mlPoints),
        );
      } else {
        _routeLine = await c.addLine(ml.LineOptions(
          geometry: mlPoints,
          lineColor: '#2196F3',
          lineWidth: 6.0,
          lineJoin: 'round',
        ));
      }
    } catch (e) {
      debugPrint('setRoutePolyline error: $e');
    }
  }

  Future<void> _clearRoutePolyline() async {
    final c = _controller;
    if (c == null || !_mapReady || _routeLine == null) return;

    try {
      await c.removeLine(_routeLine!);
    } catch (e) {
      debugPrint('clearRoutePolyline error: $e');
    }
    _routeLine = null;
  }

  // ── POI management ──────────────────────────────────────────────────

  ll.LatLng? _lastPoiFetchCenter;
  int _poiFetchSeq = 0; // sequence to discard stale responses

  void _togglePoi(String categoryId) {
    setState(() {
      if (_activePois.contains(categoryId)) {
        _activePois.remove(categoryId);
      } else {
        _activePois.add(categoryId);
      }
    });

    if (_activePois.isEmpty) {
      _clearPoiCircles();
      setState(() {
        _poiResults = [];
        _poiLoading = false;
      });
    } else {
      _fetchAndShowPois();
    }
  }

  Future<void> _fetchAndShowPois() async {
    if (_activePois.isEmpty) return;

    final seq = ++_poiFetchSeq;
    setState(() => _poiLoading = true);
    _lastPoiFetchCenter = _currentPosition;

    final poiSrc = ref.read(localPoiSourceProvider);
    final results = await poiSrc.fetchPois(
      center: _currentPosition,
      categoryIds: _activePois.toList(),
    );

    // Discard if a newer fetch started while we were waiting.
    if (!mounted || seq != _poiFetchSeq) return;

    setState(() {
      _poiResults = results;
      _poiLoading = false;
    });

    await _syncPoiCircles();
  }

  /// Sync map circles to match _poiResults without full clear+redraw.
  Future<void> _syncPoiCircles() async {
    final c = _controller;
    if (c == null || !_mapReady) return;

    // Remove all existing circles first (batch).
    if (_poiCircles.isNotEmpty) {
      try { await c.clearCircles(); } catch (_) {}
      _poiCircles.clear();
    }

    // Re-add position circle (clearCircles removes it too).
    _posCircle = null;
    _destCircle = null;
    await _updatePositionCircle();
    if (_activeRoute != null && _activeRoute!.polylinePoints.length >= 2) {
      await _updateDestinationCircle(_activeRoute!.polylinePoints.last);
    }

    // Batch-add POI circles.
    if (_poiResults.isEmpty) return;

    final options = <ml.CircleOptions>[];
    for (final poi in _poiResults) {
      final cat = poiCategories.firstWhere(
        (c) => c.id == poi.categoryId,
        orElse: () => poiCategories.first,
      );
      options.add(ml.CircleOptions(
        geometry: ml.LatLng(poi.position.latitude, poi.position.longitude),
        circleRadius: 7,
        circleColor: cat.color,
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 1.5,
      ));
    }

    try {
      final circles = await c.addCircles(options);
      _poiCircles.addAll(circles);
    } catch (e) {
      debugPrint('addCircles error: $e');
    }
  }

  Future<void> _clearPoiCircles() async {
    if (_poiCircles.isEmpty) return;
    final c = _controller;
    if (c == null || !_mapReady) return;
    try {
      for (final circle in _poiCircles) {
        await c.removeCircle(circle);
      }
    } catch (_) {}
    _poiCircles.clear();
  }

  void _onPoiCircleTapped(int index) {
    if (index < 0 || index >= _poiResults.length) return;
    final poi = _poiResults[index];
    final cat = poiCategories.firstWhere(
      (c) => c.id == poi.categoryId,
      orElse: () => poiCategories.first,
    );
    final name = poi.name.isNotEmpty ? poi.name : cat.label;
    final details = <String>[name];
    if (poi.address != null && poi.address!.isNotEmpty) details.add(poi.address!);
    if (poi.openingHours != null && poi.openingHours!.isNotEmpty) details.add(poi.openingHours!);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(details.join(' • ')),
        duration: const Duration(seconds: 3),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onCameraIdle() {
    if (_activePois.isEmpty) return;
    if (_lastPoiFetchCenter != null) {
      final dist = _distanceM(_currentPosition, _lastPoiFetchCenter!);
      if (dist < 500) return;
    }
    _fetchAndShowPois();
  }

  // ── Search & route creation ───────────────────────────────────────

  void _openSearch() async {
    // Don't allow new search while navigating — user must cancel first.
    if (_navState == _NavState.navigating) return;

    final destination = await Navigator.of(context).push<ll.LatLng>(
      MaterialPageRoute(builder: (_) => const RouteSearchScreen()),
    );
    if (destination == null || !mounted) return;

    setState(() => _navState = _NavState.calculating);

    try {
      final graphHopper = ref.read(graphHopperSourceProvider);
      final route =
          await graphHopper.calculateRoute(_currentPosition, destination);
      if (!mounted) return;

      setState(() {
        _activeRoute = route;
        _navState = _NavState.preview;
        _remainingDistanceM = route.distanceMetres;
        _remainingDurationS = route.durationSeconds;
      });

      if (route.polylinePoints.length <= 2 && mounted) {
        final fallback = graphHopper.lastFallback;
        final reason = fallback.message ?? 'Rota motoru hazır değil';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$reason — düz çizgi gösteriliyor'),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 5),
          ),
        );
      }

      await _setRoutePolyline(route.polylinePoints);
      if (route.polylinePoints.length >= 2) {
        await _updateDestinationCircle(route.polylinePoints.last);
      }

      if (route.polylinePoints.length >= 2) {
        double south = 90, north = -90, west = 180, east = -180;
        for (final p in route.polylinePoints) {
          if (p.latitude < south) south = p.latitude;
          if (p.latitude > north) north = p.latitude;
          if (p.longitude < west) west = p.longitude;
          if (p.longitude > east) east = p.longitude;
        }
        _controller?.animateCamera(
          ml.CameraUpdate.newLatLngBounds(
            ml.LatLngBounds(
              southwest: ml.LatLng(south, west),
              northeast: ml.LatLng(north, east),
            ),
          left: 60,
          right: 60,
          top: 60,
          bottom: 60,
        ),
      );
    }
    } catch (e) {
      debugPrint('Route calculation error: $e');
      if (mounted) {
        setState(() => _navState = _NavState.idle);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rota hesaplanamadi: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// User tapped "Navigasyonu Baslat" — enter turn-by-turn mode.
  void _startNavigation() {
    if (_activeRoute == null) return;

    setState(() {
      _navState = _NavState.navigating;
      _isFollowing = true;
      _currentInstructionIndex = 0;
      _lastSpokenInstructionIndex = -1;
      _nearestPolylineIndex = 0;
    });

    // Zoom to user and speak first instruction.
    _controller?.animateCamera(
      ml.CameraUpdate.newLatLngZoom(_toMl(_currentPosition), 16),
    );

    if (_activeRoute!.turnInstructions.isNotEmpty) {
      _speakInstruction(0, _activeRoute!.turnInstructions.first.distance);
    }

    ref.read(ttsServiceProvider).speakNavInstruction(
          NavInstruction.goStraight,
          distanceMeters: _activeRoute!.distanceMetres.round(),
        );
  }

  /// Cancel route (from preview or navigation).
  void _cancelRoute() {
    ref.read(ttsServiceProvider).stopAll();
    _clearRoutePolyline();
    _updateDestinationCircle(null);
    setState(() {
      _activeRoute = null;
      _navState = _NavState.idle;
      _destinationName = '';
      _currentInstructionIndex = 0;
      _lastSpokenInstructionIndex = -1;
    });
  }

  void _recenter() {
    _controller?.animateCamera(
      ml.CameraUpdate.newLatLngZoom(_toMl(_currentPosition), 16),
    );
    setState(() => _isFollowing = true);
  }

  /// Cycle map style: dark -> light -> satellite -> dark.
  void _cycleMapStyle() async {
    final next = nextMapStyle(_mapStyle);
    setState(() => _styleLoading = true);

    try {
      final style = await ref.read(mapStyleLoaderProvider).load(next);
      if (!mounted) return;

      setState(() {
        _mapStyle = next;
        _currentStyleJson = style;
        _styleLoading = false;
        // Reset map state — new style will trigger _onStyleLoaded.
        _mapReady = false;
        _posCircle = null;
        _destCircle = null;
        _routeLine = null;
        _poiCircles.clear();
        _turkeyFills.clear();
        _turkeyOutlines.clear();
        _turkeyOverlayDrawn = false;
      });
    } catch (e) {
      debugPrint('MapScreen: style cycle failed: $e');
      if (mounted) setState(() => _styleLoading = false);
    }
  }

  // ── GPS update handler ────────────────────────────────────────────

  void _onLocationUpdate(LocationData loc) {
    final newPos = ll.LatLng(loc.latitude, loc.longitude);
    final wasFirstFix = !_gotFirstFix;

    setState(() {
      _currentPosition = newPos;
      _currentHeading = loc.heading;
      _currentSpeedKmh = loc.speedKmh;
      _gotFirstFix = true;
    });

    if (!_mapReady) return;

    _updatePositionCircle();

    if (wasFirstFix) {
      // First GPS fix — jump to position.
      _controller?.animateCamera(
        ml.CameraUpdate.newLatLngZoom(_toMl(newPos), 15),
      );
    } else if (_isFollowing) {
      _controller?.animateCamera(
        ml.CameraUpdate.newLatLng(_toMl(newPos)),
      );
    }

    // Only track route in navigating state.
    if (_navState == _NavState.navigating && _activeRoute != null) {
      _updateRouteTracking(newPos);
    }
  }

  // ── Real-time route tracking ──────────────────────────────────────

  int _lastPolylineUpdateIdx = 0;

  void _updateRouteTracking(ll.LatLng pos) {
    final route = _activeRoute!;
    final points = route.polylinePoints;
    if (points.length < 2) return;

    double minDist = double.infinity;
    int nearestIdx = _nearestPolylineIndex;

    final searchStart = math.max(0, _nearestPolylineIndex - 3);
    final searchEnd = math.min(points.length - 1, _nearestPolylineIndex + 50);

    for (int i = searchStart; i <= searchEnd; i++) {
      final d = _distanceM(pos, points[i]);
      if (d < minDist) {
        minDist = d;
        nearestIdx = i;
      }
    }
    _nearestPolylineIndex = nearestIdx;

    // Update polyline only every 10 index changes to avoid overloading MapLibre.
    if (nearestIdx > 0 && (nearestIdx - _lastPolylineUpdateIdx).abs() >= 10) {
      _lastPolylineUpdateIdx = nearestIdx;
      _setRoutePolyline(points.sublist(nearestIdx));
    }

    double remaining = 0;
    for (int i = nearestIdx; i < points.length - 1; i++) {
      remaining += _distanceM(points[i], points[i + 1]);
    }

    final totalDist = route.distanceMetres;
    final fraction = totalDist > 0 ? remaining / totalDist : 0.0;

    setState(() {
      _remainingDistanceM = remaining;
      _remainingDurationS = route.durationSeconds * fraction;
    });

    _updateCurrentInstruction(route);

    if (remaining < 30) {
      _onArrived();
    }
  }

  void _updateCurrentInstruction(RouteModel route) {
    if (route.turnInstructions.isEmpty) return;

    double accumulated = 0;
    for (int i = 0; i < route.turnInstructions.length; i++) {
      accumulated += route.turnInstructions[i].distance;
      final distCurrent =
          _distanceAlongPolyline(route.polylinePoints, _nearestPolylineIndex);
      final distToInstruction = accumulated - distCurrent;

      if (distToInstruction > -50) {
        if (i != _currentInstructionIndex) {
          setState(() => _currentInstructionIndex = i);
        }

        if (i > _lastSpokenInstructionIndex) {
          if (distToInstruction <= 300 && distToInstruction > 80) {
            _speakInstruction(i, distToInstruction);
          } else if (distToInstruction <= 80) {
            _speakInstruction(i, distToInstruction);
          }
        }
        break;
      }
    }
  }

  double _distanceAlongPolyline(List<ll.LatLng> points, int upToIndex) {
    double d = 0;
    for (int i = 0; i < upToIndex && i < points.length - 1; i++) {
      d += _distanceM(points[i], points[i + 1]);
    }
    return d;
  }

  void _speakInstruction(int index, double distanceM) {
    _lastSpokenInstructionIndex = index;
    final instruction = _activeRoute!.turnInstructions[index];
    final navInst = _turnTypeToNavInstruction(instruction.type);
    if (navInst != null) {
      ref.read(ttsServiceProvider).speakNavInstruction(
            navInst,
            distanceMeters: distanceM.round(),
            streetName: instruction.streetName,
          );
    }
  }

  void _onArrived() {
    ref.read(ttsServiceProvider).speakNavInstruction(
          NavInstruction.arrivedDestination,
          distanceMeters: 0,
        );
    _clearRoutePolyline();
    _updateDestinationCircle(null);
    setState(() => _navState = _NavState.idle);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _activeRoute = null);
      }
    });
  }

  NavInstruction? _turnTypeToNavInstruction(TurnType type) => switch (type) {
        TurnType.turnRight => NavInstruction.turnRight,
        TurnType.turnLeft => NavInstruction.turnLeft,
        TurnType.roundabout => NavInstruction.roundabout,
        TurnType.continue_ => NavInstruction.goStraight,
        TurnType.arrive => NavInstruction.arrivedDestination,
        TurnType.uturn => NavInstruction.uTurn,
        TurnType.mergeLeft => NavInstruction.mergeLeft,
        TurnType.mergeRight => NavInstruction.mergeRight,
      };

  static double _distanceM(ll.LatLng a, ll.LatLng b) {
    const d = ll.Distance();
    return d.as(ll.LengthUnit.Meter, a, b);
  }

  /// Simplify a polyline to max [maxPoints] by keeping every nth point.
  static List<ll.LatLng> _simplifyPolyline(List<ll.LatLng> points, {int maxPoints = 500}) {
    if (points.length <= maxPoints) return points;
    final step = points.length / maxPoints;
    final result = <ll.LatLng>[];
    for (double i = 0; i < points.length; i += step) {
      result.add(points[i.floor()]);
    }
    if (result.last != points.last) result.add(points.last);
    return result;
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<LocationData>>(locationStreamProvider, (_, next) {
      next.whenData(_onLocationUpdate);
    });

    final isNavigating = _navState == _NavState.navigating;
    final isPreview = _navState == _NavState.preview;
    final hasRoute = _activeRoute != null;
    final isLocationCovered = ref.watch(isCurrentLocationCoveredProvider);

    // Keep the download banner in sync with pack installation state.
    ref.listen<AsyncValue<bool>>(turkeyPackInstalledProvider, (_, next) {
      next.whenData((installed) {
        if (installed && _showMapDownloadBanner) {
          setState(() => _showMapDownloadBanner = false);
        }
      });
    });

    final displayRoute = hasRoute
        ? _activeRoute!.copyWith(
            distanceMetres: _remainingDistanceM,
            durationSeconds: _remainingDurationS,
          )
        : null;

    final currentInstruction = isNavigating &&
            hasRoute &&
            _currentInstructionIndex < _activeRoute!.turnInstructions.length
        ? _activeRoute!.turnInstructions[_currentInstructionIndex]
        : null;

    return Scaffold(
      body: Stack(
        children: [
          // ── Map ────────────────────────────────────────────────
          Positioned.fill(
            child: (_styleLoading || _currentStyleJson == null)
                ? ColoredBox(
                    color: Color(0xFF14141A),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  )
                : ml.MapLibreMap(
                    key: ValueKey(_mapStyle),
                    styleString: _currentStyleJson!,
                    initialCameraPosition: ml.CameraPosition(
                      target: _toMl(_currentPosition),
                      zoom: 15,
                    ),
                    myLocationEnabled: false,
                    compassEnabled: false,
                    rotateGesturesEnabled: true,
                    scrollGesturesEnabled: true,
                    zoomGesturesEnabled: true,
                    tiltGesturesEnabled: false,
                    onMapCreated: _onMapCreated,
                    onStyleLoadedCallback: _onStyleLoaded,
                    onCameraIdle: _onCameraIdle,
                    onMapClick: (point, latLng) {
                      // Disable following when user interacts with map.
                      if (_isFollowing && _navState != _NavState.navigating) {
                        setState(() => _isFollowing = false);
                      }
                      // POI tap detection.
                      if (_poiResults.isEmpty) return;
                      final tapPos = ll.LatLng(latLng.latitude, latLng.longitude);
                      double minDist = double.infinity;
                      int closest = -1;
                      for (int i = 0; i < _poiResults.length; i++) {
                        final d = _distanceM(tapPos, _poiResults[i].position);
                        if (d < minDist) { minDist = d; closest = i; }
                      }
                      if (closest >= 0 && minDist < 100) {
                        _onPoiCircleTapped(closest);
                      }
                    },
                    attributionButtonMargins: null,
                  ),
          ),

          // ── Map download banner ─────────────────────────────────
          if (_showMapDownloadBanner)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12,
              right: 12,
              child: GestureDetector(
                onTap: () {
                  context.push('/dashboard/map-download');
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.download, color: Colors.black87, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Offline harita indirilmedi. Dokunarak indir.',
                          style: TextStyle(color: Colors.black87, fontSize: 13),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _showMapDownloadBanner = false),
                        child: const Icon(Icons.close, color: Colors.black54, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── GPS waiting ────────────────────────────────────────
          if (!_gotFirstFix)
            _topBanner(
              color: AppColors.surface.withAlpha(230),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  ),
                  SizedBox(width: 10),
                  Text('GPS konumu bekleniyor...',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 14)),
                ],
              ),
            ),

          // ── Calculating indicator ──────────────────────────────
          if (_navState == _NavState.calculating)
            _topBanner(
              color: AppColors.primary.withAlpha(220),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  ),
                  SizedBox(width: 10),
                  Text('Rota hesaplaniyor...',
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
            ),

          // ── Turn instruction (navigating only) ─────────────────
          if (currentInstruction != null)
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                child: TurnInstructionWidget(instruction: currentInstruction)
                    .animate()
                    .fadeIn(duration: 300.ms)
                    .slideY(begin: -1, end: 0, duration: 300.ms),
              ),
            ),

          // ── Route info bar (navigating only) ───────────────────
          if (isNavigating && displayRoute != null)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: RouteInfoBar(
                route: displayRoute,
                currentSpeedKmh: _currentSpeedKmh,
              ),
            ),

          // ── Route preview card (preview state) ─────────────────
          if (isPreview && _activeRoute != null)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _RoutePreviewCard(
                route: _activeRoute!,
                onStart: _startNavigation,
                onCancel: _cancelRoute,
              ).animate().slideY(
                    begin: 1, end: 0, duration: 300.ms,
                    curve: Curves.easeOut),
            ),

          // ── POI panel ─────────────────────────────────────────
          _buildPoiPanel(),

          // ── Coverage warning (GPS outside Turkey coverage) ───
          if (!isNavigating && !isLocationCovered && _gotFirstFix)
            Positioned(
              top: 60,
              left: 12,
              right: 12,
              child: SafeArea(
                child: Material(
                  color: AppColors.warning.withAlpha(230),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Konumunuz offline harita kapsama alanı dışında',
                            style: TextStyle(
                                color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── Back button ────────────────────────────────────────
          Positioned(
            top: 12, left: 12,
            child: SafeArea(
              child: _MapButton(
                icon: Icons.arrow_back,
                tooltip: 'Geri',
                onPressed: () {
                  if (isNavigating) {
                    _cancelRoute();
                  } else if (isPreview) {
                    _cancelRoute();
                  } else {
                    context.pop();
                  }
                },
              ),
            ),
          ),

          // ── Top-right controls (search + style) ──────────────────
          Positioned(
            top: 12, right: 12,
            child: SafeArea(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_navState == _NavState.idle)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _MapButton(
                        icon: Icons.search,
                        tooltip: 'Hedef ara',
                        onPressed: _openSearch,
                      ),
                    ),
                  _MapButton(
                    icon: mapStyleIcon(_mapStyle),
                    tooltip: 'Harita stili',
                    onPressed: _cycleMapStyle,
                  ),
                ],
              ),
            ),
          ),

          // ── Right-bottom controls (location + cancel) ──────────
          Positioned(
            right: 12,
            bottom: isNavigating
                ? 80
                : isPreview
                    ? 160
                    : 20,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MapButton(
                    icon: _isFollowing ? Icons.my_location : Icons.location_searching,
                    tooltip: 'Konumuma don',
                    onPressed: _recenter,
                  ),
                  if (isNavigating) ...[
                    const SizedBox(height: 8),
                    _MapButton(
                      icon: Icons.close,
                      tooltip: 'Navigasyonu bitir',
                      onPressed: _cancelRoute,
                      color: AppColors.error,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoiPanel() {
    final bottomOffset = _navState == _NavState.navigating
        ? 80.0
        : _navState == _NavState.preview
            ? 160.0
            : 16.0;
    return Positioned(
      bottom: bottomOffset,
      left: 12,
      right: 70, // leave space for map buttons on the right
      child: SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: poiCategories.map((cat) {
            final active = _activePois.contains(cat.id);
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _PoiChip(
                category: cat,
                active: active,
                onTap: () => _togglePoi(cat.id),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _topBanner({required Color color, required Widget child}) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─── Route Preview Card ──────────────────────────────────────────────────

class _RoutePreviewCard extends StatelessWidget {
  const _RoutePreviewCard({
    required this.route,
    required this.onStart,
    required this.onCancel,
  });

  final RouteModel route;
  final VoidCallback onStart;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle ─────────────────────────────────
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textDisabled,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 12),

            // ── Route summary ───────────────────────────────
            Row(
              children: [
                Icon(Icons.route, color: AppColors.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route.formattedDistance,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${route.formattedDuration} - '
                        '${route.turnInstructions.length} donus',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Action buttons ──────────────────────────────
            Row(
              children: [
                // Cancel
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Iptal'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Start navigation
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.navigation, size: 20),
                    label: const Text(
                      'Navigasyonu Baslat',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Map Button ──────────────────────────────────────────────────────────

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.onPressed,
    this.color,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: AppColors.surface.withAlpha(220),
      shape: CircleBorder(
        side: BorderSide(color: AppColors.border),
      ),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: color ?? AppColors.textPrimary, size: 24),
        ),
      ),
    );
    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

// ─── POI Chip ─────────────────────────────────────────────────────────────

/// Map of POI icon name strings to Material icons.
const _poiIconMap = <String, IconData>{
  'local_gas_station': Icons.local_gas_station,
  'local_parking': Icons.local_parking,
  'local_hospital': Icons.local_hospital,
  'pharmacy': Icons.local_pharmacy,
  'restaurant': Icons.restaurant,
  'local_cafe': Icons.local_cafe,
  'atm': Icons.atm,
  'ev_station': Icons.ev_station,
  'local_police': Icons.local_police,
  'shopping_cart': Icons.shopping_cart,
};

class _PoiChip extends StatelessWidget {
  const _PoiChip({
    required this.category,
    required this.active,
    required this.onTap,
  });

  final PoiCategory category;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final catColor = _hexToColor(category.color);
    final iconData = _poiIconMap[category.icon] ?? Icons.place;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? catColor.withAlpha(200) : AppColors.surface.withAlpha(200),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? catColor : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              iconData,
              size: 16,
              color: active ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              category.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: active ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _hexToColor(String hex) {
    final hexCode = hex.replaceFirst('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }
}
