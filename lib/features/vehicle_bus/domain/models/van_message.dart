/// A single message received from the VAN bus via the ESP32 gateway.
class VanMessage {
  /// The message type identifier (e.g. "TEMP", "DOORS", "PARKING", "STEERING").
  final String type;

  /// Key-value payload decoded from the message.
  final Map<String, dynamic> data;

  /// When the message was received on the Flutter side.
  final DateTime timestamp;

  const VanMessage({
    required this.type,
    required this.data,
    required this.timestamp,
  });

  VanMessage copyWith({
    String? type,
    Map<String, dynamic>? data,
    DateTime? timestamp,
  }) {
    return VanMessage(
      type: type ?? this.type,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() =>
      'VanMessage(type: $type, data: $data, timestamp: $timestamp)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VanMessage &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          timestamp == other.timestamp;

  @override
  int get hashCode => type.hashCode ^ timestamp.hashCode;
}
