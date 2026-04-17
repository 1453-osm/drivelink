/// App-wide constants for DriveLink.
abstract final class AppConstants {
  // ---- App info ----
  static const appName = 'DriveLink';
  static const appVersion = '1.0.0';
  static const appBuild = 1;
  static const appTagline = 'Eski aracini akilli yap';

  // ---- USB Serial baud rates ----
  static const esp32BaudRate = 115200;
  static const elm327BaudRate = 38400;
  static const vanBusBaudRate = 125000; // VAN bus raw

  // ---- Timeouts (milliseconds) ----
  static const usbReadTimeoutMs = 2000;
  static const usbWriteTimeoutMs = 1000;
  static const obdResponseTimeoutMs = 3000;
  static const vanBusResponseTimeoutMs = 1000;
  static const reconnectIntervalMs = 5000;
  static const gpsUpdateIntervalMs = 500;
  static const ttsQueueTimeoutMs = 10000;

  // ---- Timeouts (Duration) ----
  static const usbReadTimeout = Duration(milliseconds: usbReadTimeoutMs);
  static const usbWriteTimeout = Duration(milliseconds: usbWriteTimeoutMs);
  static const obdResponseTimeout =
      Duration(milliseconds: obdResponseTimeoutMs);
  static const reconnectInterval =
      Duration(milliseconds: reconnectIntervalMs);

  // ---- OBD-II PID codes (Mode 01) ----
  static const pidEngineRpm = '010C';
  static const pidVehicleSpeed = '010D';
  static const pidCoolantTemp = '0105';
  static const pidIntakeAirTemp = '010F';
  static const pidEngineLoad = '0104';
  static const pidThrottlePosition = '0111';
  static const pidFuelPressure = '010A';
  static const pidTimingAdvance = '010E';
  static const pidMafAirFlow = '0110';
  static const pidFuelSystemStatus = '0103';
  static const pidShortTermFuelTrim = '0106';
  static const pidLongTermFuelTrim = '0107';
  static const pidOxygenSensorVoltage = '0114';
  static const pidFuelLevel = '012F';
  static const pidBarometricPressure = '0133';
  static const pidControlModuleVoltage = '0142';
  static const pidAmbientAirTemp = '0146';
  static const pidOilTemp = '015C';
  static const pidRuntimeSinceStart = '011F';
  static const pidDistWithMil = '0121';

  // ---- OBD-II Mode codes ----
  static const obdModeCurrentData = '01';
  static const obdModeFreezeFrame = '02';
  static const obdModeDtc = '03';
  static const obdModeClearDtc = '04';
  static const obdModeVehicleInfo = '09';

  // ---- ELM327 AT commands ----
  static const elm327Reset = 'ATZ';
  static const elm327EchoOff = 'ATE0';
  static const elm327LinefeedOff = 'ATL0';
  static const elm327HeadersOn = 'ATH1';
  static const elm327HeadersOff = 'ATH0';
  static const elm327AutoProtocol = 'ATSP0';
  static const elm327DescribeProtocol = 'ATDP';
  static const elm327ReadVoltage = 'ATRV';
  static const elm327AdaptiveTiming = 'ATAT1';
  static const elm327SetTimeout = 'ATST'; // + hex value

  // ---- VAN Bus identifiers (common for PSA vehicles) ----
  static const vanIdDashboard = 0x8A4;
  static const vanIdRadio = 0x4D4;
  static const vanIdCdChanger = 0x4EC;
  static const vanIdDoorStatus = 0x4FC;
  static const vanIdLighting = 0x450;
  static const vanIdParkingSensors = 0x8C4;
  static const vanIdTemperature = 0x8A4;
  static const vanIdMileage = 0xE24;
  static const vanIdVin = 0xE24;

  // ---- Map & Navigation ----
  static const defaultMapZoom = 15.0;
  static const navigationMapZoom = 17.0;
  static const maxOffRouteDistanceM = 50.0;
  static const rerouteThresholdM = 100.0;
  static const speedWarningThresholdKmh = 5; // warn when exceeding limit + this

  // ---- UI ----
  static const dashboardUpdateHz = 10; // 10 FPS gauge updates
  static const animationDurationMs = 300;
  static const splashDurationMs = 2000;

  // ---- Storage keys ----
  static const keyLastVehicleProfile = 'last_vehicle_profile';
  static const keyThemeMode = 'theme_mode';
  static const keyAutoConnect = 'auto_connect';
  static const keyNavVolume = 'nav_volume';
  static const keyMusicVolume = 'music_volume';
  static const keyMapTileSource = 'map_tile_source';
  static const keyOfflineMapsEnabled = 'offline_maps_enabled';
}
