import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import 'package:drivelink/app/theme/colors.dart';

class SpeedGauge extends StatelessWidget {
  const SpeedGauge({super.key, required this.speed});

  final double speed;

  Color _glowColor() {
    if (speed > 180) return AppColors.gaugeDanger;
    if (speed > 120) return AppColors.gaugeWarning;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isCompact = constraints.maxHeight < 160;
      final valueFontSize = isCompact ? 26.0 : 36.0;
      final unitFontSize = isCompact ? 10.0 : 12.0;
      final labelFontSize = isCompact ? 8.0 : 10.0;
      final axisThickness = isCompact ? 7.0 : 10.0;
      final glow = _glowColor();

      return Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: glow.withAlpha(20),
              blurRadius: 40,
            ),
          ],
        ),
        child: SfRadialGauge(
        axes: <RadialAxis>[
          RadialAxis(
            minimum: 0,
            maximum: 240,
            startAngle: 135,
            endAngle: 45,
            showLabels: !isCompact,
            showTicks: true,
            labelOffset: 12,
            interval: isCompact ? 40 : 20,
            axisLabelStyle: GaugeTextStyle(
              color: AppColors.textSecondary,
              fontSize: labelFontSize,
              fontWeight: FontWeight.w500,
            ),
            majorTickStyle: MajorTickStyle(
              length: isCompact ? 6 : 10,
              thickness: 1.5,
              color: AppColors.textSecondary,
            ),
            minorTickStyle: MinorTickStyle(
              length: isCompact ? 3 : 5,
              thickness: 1,
              color: AppColors.surfaceBright,
            ),
            minorTicksPerInterval: isCompact ? 1 : 3,
            axisLineStyle: AxisLineStyle(
              thickness: axisThickness,
              color: AppColors.gaugeTrack,
              cornerStyle: CornerStyle.bothCurve,
            ),
            ranges: <GaugeRange>[
              GaugeRange(
                startValue: 0,
                endValue: 240,
                startWidth: axisThickness,
                endWidth: axisThickness,
                gradient: SweepGradient(
                  colors: <Color>[
                    AppColors.gaugeNormal,
                    AppColors.gaugeWarning,
                    AppColors.gaugeDanger,
                  ],
                  stops: <double>[0.0, 0.55, 1.0],
                ),
              ),
            ],
            pointers: <GaugePointer>[
              NeedlePointer(
                value: speed.clamp(0, 240),
                needleLength: 0.65,
                needleStartWidth: 1,
                needleEndWidth: isCompact ? 2 : 3,
                needleColor: AppColors.textPrimary,
                knobStyle: KnobStyle(
                  knobRadius: isCompact ? 4 : 6,
                  sizeUnit: GaugeSizeUnit.logicalPixel,
                  color: AppColors.primary,
                  borderWidth: 2,
                  borderColor: AppColors.textPrimary,
                ),
              ),
            ],
            annotations: <GaugeAnnotation>[
              GaugeAnnotation(
                widget: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      speed.toStringAsFixed(0),
                      style: GoogleFonts.jetBrainsMono(
                        color: AppColors.textPrimary,
                        fontSize: valueFontSize,
                        fontWeight: FontWeight.w700,
                        height: 1,
                        shadows: [
                          Shadow(
                            color: glow.withAlpha(60),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'km/h',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: unitFontSize,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
                angle: 90,
                positionFactor: 0.0,
              ),
            ],
          ),
        ],
      ),
      );
    });
  }
}

class RpmGauge extends StatelessWidget {
  const RpmGauge({super.key, required this.rpm});

  final double rpm;

  Color _glowColor() {
    if (rpm > 6500) return AppColors.gaugeDanger;
    if (rpm > 5000) return AppColors.gaugeWarning;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isCompact = constraints.maxHeight < 160;
      final valueFontSize = isCompact ? 20.0 : 28.0;
      final unitFontSize = isCompact ? 9.0 : 11.0;
      final labelFontSize = isCompact ? 7.0 : 9.0;
      final axisThickness = isCompact ? 6.0 : 8.0;
      final glow = _glowColor();

      return Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: glow.withAlpha(15),
              blurRadius: 32,
            ),
          ],
        ),
        child: SfRadialGauge(
        axes: <RadialAxis>[
          RadialAxis(
            minimum: 0,
            maximum: 8000,
            startAngle: 135,
            endAngle: 45,
            showLabels: !isCompact,
            showTicks: true,
            labelOffset: 12,
            interval: isCompact ? 2000 : 1000,
            labelFormat: '{value}',
            axisLabelStyle: GaugeTextStyle(
              color: AppColors.textSecondary,
              fontSize: labelFontSize,
              fontWeight: FontWeight.w500,
            ),
            majorTickStyle: MajorTickStyle(
              length: isCompact ? 5 : 8,
              thickness: 1.5,
              color: AppColors.textSecondary,
            ),
            minorTickStyle: MinorTickStyle(
              length: isCompact ? 3 : 4,
              thickness: 1,
              color: AppColors.surfaceBright,
            ),
            minorTicksPerInterval: isCompact ? 1 : 4,
            axisLineStyle: AxisLineStyle(
              thickness: axisThickness,
              color: AppColors.gaugeTrack,
              cornerStyle: CornerStyle.bothCurve,
            ),
            ranges: <GaugeRange>[
              GaugeRange(
                startValue: 0,
                endValue: 8000,
                startWidth: axisThickness,
                endWidth: axisThickness,
                gradient: SweepGradient(
                  colors: <Color>[
                    AppColors.gaugeNormal,
                    AppColors.gaugeWarning,
                    AppColors.gaugeDanger,
                  ],
                  stops: <double>[0.0, 0.65, 1.0],
                ),
              ),
            ],
            pointers: <GaugePointer>[
              NeedlePointer(
                value: rpm.clamp(0, 8000),
                needleLength: 0.6,
                needleStartWidth: 1,
                needleEndWidth: isCompact ? 2 : 2.5,
                needleColor: AppColors.textPrimary,
                knobStyle: KnobStyle(
                  knobRadius: isCompact ? 3.5 : 5,
                  sizeUnit: GaugeSizeUnit.logicalPixel,
                  color: AppColors.primary,
                  borderWidth: 2,
                  borderColor: AppColors.textPrimary,
                ),
              ),
            ],
            annotations: <GaugeAnnotation>[
              GaugeAnnotation(
                widget: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      rpm.toStringAsFixed(0),
                      style: GoogleFonts.jetBrainsMono(
                        color: AppColors.textPrimary,
                        fontSize: valueFontSize,
                        fontWeight: FontWeight.w700,
                        height: 1,
                        shadows: [
                          Shadow(
                            color: glow.withAlpha(50),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'RPM',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: unitFontSize,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
                angle: 90,
                positionFactor: 0.0,
              ),
            ],
          ),
        ],
      ),
      );
    });
  }
}
