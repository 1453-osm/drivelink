import 'package:usb_serial/usb_serial.dart';

/// USB adapter role used to route a device to the right serial source.
enum UsbAdapterRole { esp32VanBus, elm327Obd }

/// Known USB VID:PID pairs mapped to an adapter role.
///
/// Some VID/PID combinations (e.g. CP2102 10C4:EA60) are used by both
/// ESP32 boards and OBD adapters — for those we fall back to product name
/// hints in [UsbDeviceMatcher.match].
class _UsbIdEntry {
  const _UsbIdEntry(this.vid, this.pid, this.role);
  final int vid;
  final int pid;
  final UsbAdapterRole role;
}

const List<_UsbIdEntry> _knownIds = [
  // CH340 / CH340C — DFRobot Beetle ESP32, common ESP32 clones.
  _UsbIdEntry(0x1A86, 0x7523, UsbAdapterRole.esp32VanBus),
  _UsbIdEntry(0x1A86, 0x55D4, UsbAdapterRole.esp32VanBus),
  // Silicon Labs CP2102 — used by both ESP32 and some OBD adapters.
  // Default to ESP32; product name disambiguation runs afterwards.
  _UsbIdEntry(0x10C4, 0xEA60, UsbAdapterRole.esp32VanBus),
  // FTDI FT232R — overwhelmingly OBD clones.
  _UsbIdEntry(0x0403, 0x6001, UsbAdapterRole.elm327Obd),
  _UsbIdEntry(0x0403, 0x6015, UsbAdapterRole.elm327Obd),
  // Prolific PL2303 — OBD cables.
  _UsbIdEntry(0x067B, 0x2303, UsbAdapterRole.elm327Obd),
];

/// Matches a [UsbDevice] to an [UsbAdapterRole] based on VID/PID and
/// product-name hints.
abstract final class UsbDeviceMatcher {
  /// Returns the role for [device], or null when nothing matches.
  static UsbAdapterRole? match(UsbDevice device) {
    final name = (device.productName ?? '').toLowerCase();
    final manufacturer = (device.manufacturerName ?? '').toLowerCase();
    final combined = '$manufacturer $name';

    // Strong name hints override ambiguous VID/PID mappings.
    if (combined.contains('elm') || combined.contains('obd')) {
      return UsbAdapterRole.elm327Obd;
    }
    if (combined.contains('esp') || combined.contains('van')) {
      return UsbAdapterRole.esp32VanBus;
    }

    for (final entry in _knownIds) {
      if (device.vid == entry.vid && device.pid == entry.pid) {
        return entry.role;
      }
    }
    return null;
  }

  /// Returns the first device matching [role] from [devices].
  ///
  /// When multiple devices match, devices with an unambiguous name hint
  /// (ELM/OBD/ESP/VAN in product name) win over pure VID/PID matches.
  static UsbDevice? pick(List<UsbDevice> devices, UsbAdapterRole role) {
    UsbDevice? vidPidMatch;
    for (final device in devices) {
      final matched = match(device);
      if (matched != role) continue;

      final name = '${device.manufacturerName ?? ''} ${device.productName ?? ''}'
          .toLowerCase();
      final hasStrongHint = role == UsbAdapterRole.elm327Obd
          ? (name.contains('elm') || name.contains('obd'))
          : (name.contains('esp') || name.contains('van'));

      if (hasStrongHint) return device;
      vidPidMatch ??= device;
    }
    return vidPidMatch;
  }
}
