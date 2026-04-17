import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/features/navigation/presentation/widgets/map_widget.dart';

/// Compact map widget embedded in the dashboard.
///
/// Auto-centres on [currentPosition] and shows a heading indicator.
/// Tapping invokes [onTap] to open full-screen navigation.
class MiniMap extends StatefulWidget {
  const MiniMap({
    super.key,
    required this.currentPosition,
    this.heading = 0,
    this.nextTurnInstruction,
    this.onTap,
  });

  final ml.LatLng currentPosition;
  final double heading;
  final String? nextTurnInstruction;
  final VoidCallback? onTap;

  @override
  State<MiniMap> createState() => _MiniMapState();
}

class _MiniMapState extends State<MiniMap> {
  ml.MapLibreMapController? _controller;
  ml.Circle? _positionCircle;

  @override
  void didUpdateWidget(covariant MiniMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPosition != widget.currentPosition) {
      _updatePosition();
    }
  }

  void _onMapCreated(ml.MapLibreMapController controller) {
    _controller = controller;
  }

  void _onStyleLoaded() {
    _addPositionMarker();
  }

  Future<void> _addPositionMarker() async {
    final c = _controller;
    if (c == null) return;

    _positionCircle = await c.addCircle(ml.CircleOptions(
      geometry: widget.currentPosition,
      circleRadius: 7,
      circleColor: '#2196F3',
      circleStrokeColor: '#FFFFFF',
      circleStrokeWidth: 2.5,
    ));
  }

  void _updatePosition() {
    final c = _controller;
    if (c == null) return;

    c.animateCamera(
      ml.CameraUpdate.newLatLng(widget.currentPosition),
      duration: const Duration(milliseconds: 500),
    );

    if (_positionCircle != null) {
      c.updateCircle(
        _positionCircle!,
        ml.CircleOptions(geometry: widget.currentPosition),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            MapWidget(
              center: widget.currentPosition,
              zoom: 15,
              interactive: false,
              onMapCreated: _onMapCreated,
              onStyleLoaded: _onStyleLoaded,
            ),

            // Border overlay.
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border, width: 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            // Turn instruction.
            if (widget.nextTurnInstruction != null)
              Positioned(
                top: 6, left: 6, right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withAlpha(210),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.turn_right,
                          color: AppColors.primary, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.nextTurnInstruction!,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Expand hint.
            Positioned(
              bottom: 6, right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surface.withAlpha(180),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fullscreen,
                        color: AppColors.textSecondary, size: 13),
                    SizedBox(width: 3),
                    Text('Haritayi Ac',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 9)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
