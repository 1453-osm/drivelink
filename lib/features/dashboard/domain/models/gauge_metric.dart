import 'package:flutter/material.dart';

import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/features/dashboard/domain/models/dashboard_state.dart';
import 'package:drivelink/features/obd/domain/models/obd_data.dart';

/// All metrics that can be displayed on a configurable dashboard gauge.
enum GaugeMetric {
  speed,
  rpm,
  coolantTemp,
  fuelConsumption,
  batteryVoltage,
  engineLoad,
  throttle,
  externalTemp,
  intakeTemp,
  intakePressure,
}

extension GaugeMetricExt on GaugeMetric {
  String get label => switch (this) {
        GaugeMetric.speed => 'Hiz',
        GaugeMetric.rpm => 'Devir',
        GaugeMetric.coolantTemp => 'Motor Sicakligi',
        GaugeMetric.fuelConsumption => 'Yakit Tuketimi',
        GaugeMetric.batteryVoltage => 'Aku Voltaji',
        GaugeMetric.engineLoad => 'Motor Yuku',
        GaugeMetric.throttle => 'Gaz Pozisyonu',
        GaugeMetric.externalTemp => 'Dis Sicaklik',
        GaugeMetric.intakeTemp => 'Emme Sicakligi',
        GaugeMetric.intakePressure => 'Emme Basinci',
      };

  String get unit => switch (this) {
        GaugeMetric.speed => 'km/h',
        GaugeMetric.rpm => 'RPM',
        GaugeMetric.coolantTemp => '°C',
        GaugeMetric.fuelConsumption => 'L/100',
        GaugeMetric.batteryVoltage => 'V',
        GaugeMetric.engineLoad => '%',
        GaugeMetric.throttle => '%',
        GaugeMetric.externalTemp => '°C',
        GaugeMetric.intakeTemp => '°C',
        GaugeMetric.intakePressure => 'kPa',
      };

  IconData get icon => switch (this) {
        GaugeMetric.speed => Icons.speed,
        GaugeMetric.rpm => Icons.rotate_right_rounded,
        GaugeMetric.coolantTemp => Icons.thermostat_rounded,
        GaugeMetric.fuelConsumption => Icons.local_gas_station_rounded,
        GaugeMetric.batteryVoltage => Icons.battery_std_rounded,
        GaugeMetric.engineLoad => Icons.engineering_rounded,
        GaugeMetric.throttle => Icons.tune_rounded,
        GaugeMetric.externalTemp => Icons.ac_unit_rounded,
        GaugeMetric.intakeTemp => Icons.air_rounded,
        GaugeMetric.intakePressure => Icons.compress_rounded,
      };

  double get minValue => switch (this) {
        GaugeMetric.speed => 0,
        GaugeMetric.rpm => 0,
        GaugeMetric.coolantTemp => 0,
        GaugeMetric.fuelConsumption => 0,
        GaugeMetric.batteryVoltage => 10,
        GaugeMetric.engineLoad => 0,
        GaugeMetric.throttle => 0,
        GaugeMetric.externalTemp => -20,
        GaugeMetric.intakeTemp => -20,
        GaugeMetric.intakePressure => 0,
      };

  double get maxValue => switch (this) {
        GaugeMetric.speed => 240,
        GaugeMetric.rpm => 8000,
        GaugeMetric.coolantTemp => 130,
        GaugeMetric.fuelConsumption => 30,
        GaugeMetric.batteryVoltage => 16,
        GaugeMetric.engineLoad => 100,
        GaugeMetric.throttle => 100,
        GaugeMetric.externalTemp => 50,
        GaugeMetric.intakeTemp => 80,
        GaugeMetric.intakePressure => 255,
      };

  double get warningValue => switch (this) {
        GaugeMetric.speed => 130,
        GaugeMetric.rpm => 5000,
        GaugeMetric.coolantTemp => 95,
        GaugeMetric.fuelConsumption => 12,
        GaugeMetric.batteryVoltage => 11.5,
        GaugeMetric.engineLoad => 75,
        GaugeMetric.throttle => 80,
        GaugeMetric.externalTemp => 35,
        GaugeMetric.intakeTemp => 50,
        GaugeMetric.intakePressure => 200,
      };

  double get dangerValue => switch (this) {
        GaugeMetric.speed => 180,
        GaugeMetric.rpm => 6500,
        GaugeMetric.coolantTemp => 105,
        GaugeMetric.fuelConsumption => 20,
        GaugeMetric.batteryVoltage => 10.5,
        GaugeMetric.engineLoad => 90,
        GaugeMetric.throttle => 95,
        GaugeMetric.externalTemp => 42,
        GaugeMetric.intakeTemp => 65,
        GaugeMetric.intakePressure => 240,
      };

  double get interval => switch (this) {
        GaugeMetric.speed => 20,
        GaugeMetric.rpm => 1000,
        GaugeMetric.coolantTemp => 20,
        GaugeMetric.fuelConsumption => 5,
        GaugeMetric.batteryVoltage => 1,
        GaugeMetric.engineLoad => 20,
        GaugeMetric.throttle => 20,
        GaugeMetric.externalTemp => 10,
        GaugeMetric.intakeTemp => 10,
        GaugeMetric.intakePressure => 50,
      };

  /// Normalized position (0..1) of the warning zone on the arc.
  double get warnStop =>
      ((warningValue - minValue) / (maxValue - minValue)).clamp(0.1, 0.95);

  int get fractionDigits => switch (this) {
        GaugeMetric.batteryVoltage || GaugeMetric.fuelConsumption => 1,
        _ => 0,
      };

  /// Read the live value from the merged dashboard state + raw OBD data.
  double getValue(DashboardState state, ObdData? obd) => switch (this) {
        GaugeMetric.speed => state.speed,
        GaugeMetric.rpm => state.rpm,
        GaugeMetric.coolantTemp => state.coolantTemp,
        GaugeMetric.fuelConsumption => state.fuelConsumption,
        GaugeMetric.batteryVoltage => state.batteryVoltage,
        GaugeMetric.engineLoad => obd?.engineLoad ?? 0,
        GaugeMetric.throttle => obd?.throttle ?? 0,
        GaugeMetric.externalTemp => state.externalTemp,
        GaugeMetric.intakeTemp => obd?.intakeTemp ?? 0,
        GaugeMetric.intakePressure => obd?.intakePressure ?? 0,
      };

  /// Glow color based on current value zone.
  Color glowColor(double value) {
    if (value >= dangerValue) return AppColors.gaugeDanger;
    if (value >= warningValue) return AppColors.gaugeWarning;
    return AppColors.primary;
  }
}
