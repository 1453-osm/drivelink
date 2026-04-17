/// Predefined vehicle profiles for DriveLink.
///
/// Covers PSA vehicles that use VAN bus (older Peugeot/Citroen),
/// CAN bus (newer models), and a generic OBD-only fallback.

// ---------------------------------------------------------------------------
// Bus types
// ---------------------------------------------------------------------------
enum BusType {
  van,
  can,
  obdOnly,
}

// ---------------------------------------------------------------------------
// Message definition
// ---------------------------------------------------------------------------
class BusMessageDef {
  /// Bus identifier (hex).
  final int id;

  /// Human-readable label.
  final String label;

  /// Byte length of the payload.
  final int length;

  /// Decode description / notes.
  final String description;

  const BusMessageDef({
    required this.id,
    required this.label,
    this.length = 0,
    this.description = '',
  });

  String get idHex => '0x${id.toRadixString(16).toUpperCase().padLeft(3, '0')}';
}

// ---------------------------------------------------------------------------
// Vehicle profile
// ---------------------------------------------------------------------------
class VehicleProfile {
  final String id;
  final String name;
  final String manufacturer;
  final String model;
  final String years;
  final BusType busType;
  final int busSpeedKbps;
  final List<BusMessageDef> messages;
  final bool supportsObd;
  final String notes;

  const VehicleProfile({
    required this.id,
    required this.name,
    required this.manufacturer,
    required this.model,
    this.years = '',
    required this.busType,
    required this.busSpeedKbps,
    this.messages = const [],
    this.supportsObd = true,
    this.notes = '',
  });

  String get displayName => '$manufacturer $model';

  bool get isVanBus => busType == BusType.van;
  bool get isCanBus => busType == BusType.can;
  bool get isObdOnly => busType == BusType.obdOnly;
}

// ---------------------------------------------------------------------------
// Common VAN bus message definitions (PSA)
// ---------------------------------------------------------------------------
const _vanDashboardMessages = [
  BusMessageDef(
    id: 0x8A4,
    label: 'Dashboard',
    length: 7,
    description: 'Engine RPM, coolant temp, fuel level, warning lights',
  ),
  BusMessageDef(
    id: 0x4FC,
    label: 'Door Status',
    length: 5,
    description: 'Door open/closed, boot, bonnet status',
  ),
  BusMessageDef(
    id: 0x450,
    label: 'Lighting',
    length: 5,
    description: 'Headlights, indicators, fog lights, interior lights',
  ),
  BusMessageDef(
    id: 0x4D4,
    label: 'Radio',
    length: 14,
    description: 'Radio source, frequency, volume, track info',
  ),
  BusMessageDef(
    id: 0x4EC,
    label: 'CD Changer',
    length: 7,
    description: 'CD track number, play status, disc number',
  ),
  BusMessageDef(
    id: 0x8C4,
    label: 'Parking Sensors',
    length: 6,
    description: 'Front and rear parking sensor distances',
  ),
  BusMessageDef(
    id: 0xE24,
    label: 'Mileage / VIN',
    length: 11,
    description: 'Total mileage, VIN segments',
  ),
  BusMessageDef(
    id: 0x564,
    label: 'Trip Computer',
    length: 14,
    description: 'Average speed, fuel consumption, range',
  ),
  BusMessageDef(
    id: 0x524,
    label: 'Ext Temperature',
    length: 2,
    description: 'Outside temperature sensor',
  ),
  BusMessageDef(
    id: 0x4DC,
    label: 'Steering Wheel',
    length: 2,
    description: 'Steering wheel remote buttons',
  ),
];

// ---------------------------------------------------------------------------
// Common CAN bus message definitions (PSA)
// ---------------------------------------------------------------------------
const _canDashboardMessages = [
  BusMessageDef(
    id: 0x036,
    label: 'Engine RPM',
    length: 8,
    description: 'Engine speed and status',
  ),
  BusMessageDef(
    id: 0x0B6,
    label: 'Vehicle Speed',
    length: 8,
    description: 'Wheel speed, odometer',
  ),
  BusMessageDef(
    id: 0x0F6,
    label: 'Engine Temp',
    length: 8,
    description: 'Coolant and oil temperature',
  ),
  BusMessageDef(
    id: 0x128,
    label: 'Doors / Lights',
    length: 8,
    description: 'Door status, headlights, indicators',
  ),
  BusMessageDef(
    id: 0x161,
    label: 'Dashboard',
    length: 7,
    description: 'Fuel level, range, warnings',
  ),
  BusMessageDef(
    id: 0x1A1,
    label: 'Trip Computer',
    length: 8,
    description: 'Average consumption, distance',
  ),
  BusMessageDef(
    id: 0x21F,
    label: 'Parking Sensors',
    length: 8,
    description: 'Front and rear parking distances',
  ),
  BusMessageDef(
    id: 0x1E1,
    label: 'Steering Buttons',
    length: 3,
    description: 'Steering wheel remote control buttons',
  ),
  BusMessageDef(
    id: 0x0E6,
    label: 'Ext Temperature',
    length: 8,
    description: 'Outside temperature',
  ),
  BusMessageDef(
    id: 0x1E5,
    label: 'Radio',
    length: 8,
    description: 'Radio source, volume, station info',
  ),
];

// ---------------------------------------------------------------------------
// Vehicle profiles
// ---------------------------------------------------------------------------
class VehicleProfiles {
  VehicleProfiles._();

  // ---- Peugeot ----

  static const peugeot206 = VehicleProfile(
    id: 'peugeot_206',
    name: 'Peugeot 206 (VAN)',
    manufacturer: 'Peugeot',
    model: '206',
    years: '1998-2012',
    busType: BusType.van,
    busSpeedKbps: 125,
    messages: _vanDashboardMessages,
    notes: 'VAN bus on comfort network. '
        'ISO 11519-3 compatible. '
        'Some late models (206+) may use CAN.',
  );

  static const peugeot307 = VehicleProfile(
    id: 'peugeot_307',
    name: 'Peugeot 307 (VAN)',
    manufacturer: 'Peugeot',
    model: '307',
    years: '2001-2008',
    busType: BusType.van,
    busSpeedKbps: 125,
    messages: _vanDashboardMessages,
    notes: 'VAN bus for body/comfort. '
        'Some data also available on CAN diagnostic port.',
  );

  static const peugeot407 = VehicleProfile(
    id: 'peugeot_407',
    name: 'Peugeot 407 (CAN)',
    manufacturer: 'Peugeot',
    model: '407',
    years: '2004-2011',
    busType: BusType.can,
    busSpeedKbps: 500,
    messages: _canDashboardMessages,
    notes: 'Full CAN bus. '
        'Comfort CAN at 125 kbps, powertrain CAN at 500 kbps.',
  );

  // ---- Citroen ----

  static const citroenC3 = VehicleProfile(
    id: 'citroen_c3',
    name: 'Citroen C3 (VAN)',
    manufacturer: 'Citroen',
    model: 'C3',
    years: '2002-2009',
    busType: BusType.van,
    busSpeedKbps: 125,
    messages: _vanDashboardMessages,
    notes: 'First generation C3 uses VAN bus. '
        'Second generation (2009+) uses CAN.',
  );

  static const citroenC4 = VehicleProfile(
    id: 'citroen_c4',
    name: 'Citroen C4 (CAN)',
    manufacturer: 'Citroen',
    model: 'C4',
    years: '2004-2018',
    busType: BusType.can,
    busSpeedKbps: 500,
    messages: _canDashboardMessages,
    notes: 'CAN bus vehicle. '
        'Comfort CAN at 125 kbps, powertrain at 500 kbps. '
        'C4 Picasso uses same bus layout.',
  );

  // ---- Generic ----

  static const genericObd = VehicleProfile(
    id: 'generic_obd',
    name: 'Genel OBD-II',
    manufacturer: 'Genel',
    model: 'OBD-II',
    years: '1996+',
    busType: BusType.obdOnly,
    busSpeedKbps: 0,
    messages: [],
    supportsObd: true,
    notes: 'Generic OBD-II only profile. '
        'Works with any OBD-II compliant vehicle. '
        'No vehicle-specific bus messages — only standard PIDs.',
  );

  // ---- All profiles ----

  static const all = [
    peugeot206,
    peugeot307,
    peugeot407,
    citroenC3,
    citroenC4,
    genericObd,
  ];

  /// Look up a profile by its [id].
  static VehicleProfile? byId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// All VAN bus profiles.
  static List<VehicleProfile> get vanProfiles =>
      all.where((p) => p.isVanBus).toList();

  /// All CAN bus profiles.
  static List<VehicleProfile> get canProfiles =>
      all.where((p) => p.isCanBus).toList();
}
