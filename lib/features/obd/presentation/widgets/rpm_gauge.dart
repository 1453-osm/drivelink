import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import 'package:drivelink/app/theme/colors.dart';

/// Radial RPM gauge 0 – 8 000 RPM with a red-zone above 6 500.
class RpmGauge extends StatelessWidget {
  const RpmGauge({super.key, required this.rpm});

  final double rpm;

  @override
  Widget build(BuildContext context) {
    return SfRadialGauge(
      axes: <RadialAxis>[
        RadialAxis(
          minimum: 0,
          maximum: 8000,
          interval: 1000,
          startAngle: 150,
          endAngle: 30,
          radiusFactor: 0.95,
          showLastLabel: true,
          axisLabelStyle: GaugeTextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
          majorTickStyle: MajorTickStyle(
            length: 12,
            thickness: 2,
            color: AppColors.textSecondary,
          ),
          minorTickStyle: MinorTickStyle(
            length: 6,
            thickness: 1,
            color: AppColors.textDisabled,
          ),
          axisLineStyle: AxisLineStyle(
            thickness: 8,
            color: AppColors.gaugeTrack,
          ),
          ranges: <GaugeRange>[
            GaugeRange(
              startValue: 0,
              endValue: 5000,
              color: AppColors.gaugeNormal,
              startWidth: 8,
              endWidth: 8,
            ),
            GaugeRange(
              startValue: 5000,
              endValue: 6500,
              color: AppColors.gaugeWarning,
              startWidth: 8,
              endWidth: 8,
            ),
            GaugeRange(
              startValue: 6500,
              endValue: 8000,
              color: AppColors.gaugeDanger,
              startWidth: 8,
              endWidth: 8,
            ),
          ],
          pointers: <GaugePointer>[
            NeedlePointer(
              value: rpm.clamp(0, 8000),
              needleLength: 0.7,
              needleStartWidth: 1,
              needleEndWidth: 3,
              needleColor: AppColors.textPrimary,
              knobStyle: KnobStyle(
                knobRadius: 6,
                sizeUnit: GaugeSizeUnit.logicalPixel,
                color: AppColors.primary,
              ),
              enableAnimation: true,
              animationDuration: 300,
              animationType: AnimationType.ease,
            ),
          ],
          annotations: <GaugeAnnotation>[
            GaugeAnnotation(
              widget: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    rpm.toInt().toString(),
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'RPM',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              angle: 90,
              positionFactor: 0.6,
            ),
          ],
        ),
      ],
    );
  }
}
