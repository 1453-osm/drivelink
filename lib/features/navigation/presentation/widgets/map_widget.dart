import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/features/navigation/data/map_style_loader.dart';

/// Reusable MapLibre GL map widget — fully offline.
///
/// Resolves the correct local style (dark/light/satellite) at build time
/// via [MapStyleLoader], injecting file:// URLs for glyphs, sprite and the
/// Turkey pmtiles pack. No network calls at render time.
class MapWidget extends ConsumerStatefulWidget {
  const MapWidget({
    super.key,
    this.center,
    this.zoom = 13,
    this.interactive = true,
    this.isDark,
    this.style,
    this.onMapCreated,
    this.onStyleLoaded,
    this.onCameraIdle,
  });

  final ml.LatLng? center;
  final double zoom;
  final bool interactive;
  final bool? isDark;

  /// Explicit style override. If null, derived from [isDark] / theme.
  final MapStyle? style;

  final void Function(ml.MapLibreMapController)? onMapCreated;
  final VoidCallback? onStyleLoaded;
  final VoidCallback? onCameraIdle;

  @override
  ConsumerState<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends ConsumerState<MapWidget> {
  String? _styleJson;
  Object? _loadError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadStyleIfNeeded();
  }

  @override
  void didUpdateWidget(covariant MapWidget old) {
    super.didUpdateWidget(old);
    if (old.style != widget.style || old.isDark != widget.isDark) {
      setState(() => _styleJson = null);
      _loadStyleIfNeeded();
    }
  }

  MapStyle _resolveStyle() {
    if (widget.style != null) return widget.style!;
    final dark = widget.isDark ?? Theme.of(context).brightness == Brightness.dark;
    return dark ? MapStyle.dark : MapStyle.light;
  }

  Future<void> _loadStyleIfNeeded() async {
    if (_styleJson != null) return;
    try {
      final loader = ref.read(mapStyleLoaderProvider);
      final json = await loader.load(_resolveStyle());
      if (!mounted) return;
      setState(() => _styleJson = json);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return ColoredBox(
        color: AppColors.background,
        child: Center(
          child: Text(
            'Harita yüklenemedi',
            style: TextStyle(color: AppColors.error, fontSize: 13),
          ),
        ),
      );
    }
    if (_styleJson == null) {
      return ColoredBox(
        color: AppColors.background,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }

    final center = widget.center ?? const ml.LatLng(39.9, 32.8);

    return ml.MapLibreMap(
      key: ValueKey(_resolveStyle()),
      styleString: _styleJson!,
      initialCameraPosition: ml.CameraPosition(
        target: center,
        zoom: widget.zoom,
      ),
      myLocationEnabled: false,
      compassEnabled: false,
      rotateGesturesEnabled: widget.interactive,
      scrollGesturesEnabled: widget.interactive,
      zoomGesturesEnabled: widget.interactive,
      tiltGesturesEnabled: false,
      onMapCreated: widget.onMapCreated,
      onStyleLoadedCallback: widget.onStyleLoaded,
      onCameraIdle: widget.onCameraIdle,
      attributionButtonMargins: null,
    );
  }
}
