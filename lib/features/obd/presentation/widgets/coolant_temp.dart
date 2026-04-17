import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import 'package:drivelink/app/theme/colors.dart';

/// Coolant temperature gauge with cold/normal/hot zones.
class CoolantTempWidget extends StatelessWidget {
  const CoolantTempWidget({super.key, required this.temp});

  /// Coolant temperature in °C (null = no data).
  final double? temp;

  @override
  Widget build(BuildContext context) {
    final value = temp ?? 0;
    final color = _zoneColor(temp);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Coolant',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 110,
            child: SfRadialGauge(
              axes: <RadialAxis>[
                RadialAxis(
                  minimum: -40,
                  maximum: 130,
                  startAngle: 180,
                  endAngle: 0,
                  showLabels: false,
                  showTicks: false,
                  radiusFactor: 0.9,
                  axisLineStyle: AxisLineStyle(
                    thickness: 10,
                    color: AppColors.gaugeTrack,
                  ),
                  ranges: <GaugeRange>[
                    GaugeRange(
                      startValue: -40,
                      endValue: 60,
                      color: AppColors.info,
                      startWidth: 10,
                      endWidth: 10,
                    ),
                    GaugeRange(
                      startValue: 60,
                      endValue: 100,
                      color: AppColors.gaugeNormal,
                      startWidth: 10,
                      endWidth: 10,
                    ),
                    GaugeRange(
                      startValue: 100,
                      endValue: 130,
                      color: AppColors.gaugeDanger,
                      startWidth: 10,
                      endWidth: 10,
                    ),
                  ],
                  pointers: <GaugePointer>[
                    NeedlePointer(
                      value: value.clamp(-40, 130).toDouble(),
                      needleLength: 0.6,
                      needleStartWidth: 1,
                      needleEndWidth: 2.5,
                      needleColor: AppColors.textPrimary,
                      knobStyle: KnobStyle(
                        knobRadius: 4,
                        sizeUnit: GaugeSizeUnit.logicalPixel,
                        color: AppColors.primary,
                      ),
                      enableAnimation: true,
                      animationDuration: 400,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            temp != null ? '${temp!.toStringAsFixed(0)}°C' : '--°C',
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _zoneColor(double? t) {
    if (t == null) return AppColors.textDisabled;
    if (t < 60) return AppColors.info; // cold
    if (t <= 100) return AppColors.gaugeNormal; // normal
    return AppColors.gaugeDanger; // overheating
  }
}
