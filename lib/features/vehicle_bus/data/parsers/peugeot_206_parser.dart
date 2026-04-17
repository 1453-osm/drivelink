import 'package:drivelink/features/vehicle_bus/domain/models/steering_button.dart';
import 'package:drivelink/features/vehicle_bus/domain/models/van_message.dart';
import 'package:drivelink/features/vehicle_bus/domain/models/vehicle_state.dart';

/// Maps VAN bus messages from a Peugeot 206 into [VehicleState] fields.
///
/// ESP32 firmware message types:
/// - `SPEED`     — `{ "kmh": 60, "rpm": 2500 }`
/// - `TEMP`      — `{ "external": 22.5 }`
/// - `DOORS`     — `{ "fl": true, "fr": false, "rl": false, "rr": false, "trunk": false }`
/// - `PARKING`   — `{ "left": 120, "center": 80, "right": 200 }`
/// - `STEERING`  — `{ "button": "volUp", "action": "press" }`
/// - `CLIMATE`   — `{ "temp_set": 22.0, "ac": true, "fan": 3 }`
/// - `VIN`       — `{ "vin": "VF32B8HZAAD007531" }`
/// - `DASHBOARD` — `{ "hex": "00000D24FFFF", "len": 6 }`
/// - `RADIO`     — `{ "hex": "020000...", "len": 14 }`
/// - `RAW`       — `{ "id": "0x9C4", "hex": "0080", "len": 2, "crc": true }`
class Peugeot206Parser {
  Peugeot206Parser._();

  static const int _maxRawMessages = 200;

  static VehicleState apply(VehicleState current, VanMessage message) {
    final updatedRaw = [message, ...current.rawMessages];
    if (updatedRaw.length > _maxRawMessages) {
      updatedRaw.removeRange(_maxRawMessages, updatedRaw.length);
    }

    switch (message.type) {
      case 'TEMP':
        return current.copyWith(
          externalTemp: _toDouble(message.data['external']),
          rawMessages: updatedRaw,
        );

      case 'SPEED':
        return current.copyWith(
          speed: _toDouble(message.data['kmh']),
          rpm: _toDouble(message.data['rpm']),
          rawMessages: updatedRaw,
        );

      case 'DOORS':
        return current.copyWith(
          doorStatus: DoorStatus(
            frontLeft: message.data['fl'] == true,
            frontRight: message.data['fr'] == true,
            rearLeft: message.data['rl'] == true,
            rearRight: message.data['rr'] == true,
            trunk: message.data['trunk'] == true,
          ),
          rawMessages: updatedRaw,
        );

      case 'PARKING':
        return current.copyWith(
          parkingSensors: ParkingSensors(
            leftCm: _toInt(message.data['left'], fallback: 255),
            centerCm: _toInt(message.data['center'], fallback: 255),
            rightCm: _toInt(message.data['right'], fallback: 255),
          ),
          rawMessages: updatedRaw,
        );

      case 'STEERING':
        final event = _parseSteeringEvent(message.data);
        if (event == null) {
          return current.copyWith(rawMessages: updatedRaw);
        }
        final buttons = [event, ...current.steeringButtons];
        if (buttons.length > 20) buttons.removeRange(20, buttons.length);
        return current.copyWith(
          steeringButtons: buttons,
          rawMessages: updatedRaw,
        );

      case 'CLIMATE':
        return current.copyWith(
          climate: ClimateState(
            tempSet: _toDouble(message.data['temp_set']) ?? 0,
            acOn: message.data['ac'] == true,
            fanSpeed: _toInt(message.data['fan']),
          ),
          rawMessages: updatedRaw,
        );

      case 'VIN':
        return current.copyWith(
          vin: message.data['vin'] as String?,
          rawMessages: updatedRaw,
        );

      case 'DASHBOARD':
      case 'RADIO':
      case 'RAW':
        return current.copyWith(rawMessages: updatedRaw);

      default:
        return current.copyWith(rawMessages: updatedRaw);
    }
  }

  static double? _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static SteeringEvent? _parseSteeringEvent(Map<String, dynamic> data) {
    final buttonName = data['button'] as String?;
    final actionName = data['action'] as String?;
    if (buttonName == null || actionName == null) return null;

    final button = _buttonFromString(buttonName);
    final action = _actionFromString(actionName);
    if (button == null || action == null) return null;

    return SteeringEvent(
      button: button,
      action: action,
      timestamp: DateTime.now(),
    );
  }

  static SteeringButton? _buttonFromString(String name) {
    return switch (name) {
      'volUp' => SteeringButton.volUp,
      'volDown' => SteeringButton.volDown,
      'next' => SteeringButton.next,
      'prev' => SteeringButton.prev,
      'src' => SteeringButton.src,
      'phone' => SteeringButton.phone,
      'scrollUp' => SteeringButton.scrollUp,
      'scrollDown' => SteeringButton.scrollDown,
      _ => null,
    };
  }

  static SteeringAction? _actionFromString(String name) {
    return switch (name) {
      'press' => SteeringAction.press,
      'release' => SteeringAction.release,
      _ => null,
    };
  }
}
