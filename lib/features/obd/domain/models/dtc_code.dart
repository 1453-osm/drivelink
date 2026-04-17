/// Severity of a diagnostic trouble code.
enum DtcSeverity {
  /// Informational — no immediate action required.
  info,

  /// Warning — service soon.
  warning,

  /// Critical — stop driving / immediate attention.
  critical,
}

/// A single OBD-II diagnostic trouble code.
class DtcCode {
  /// Standard code string, e.g. "P0301".
  final String code;

  /// Human-readable description.
  final String description;

  /// Estimated severity.
  final DtcSeverity severity;

  const DtcCode({
    required this.code,
    required this.description,
    this.severity = DtcSeverity.info,
  });

  /// Returns the first letter category.
  String get category => code.isNotEmpty ? code[0] : '?';

  /// "P" = Powertrain, "C" = Chassis, "B" = Body, "U" = Network.
  String get categoryName => switch (category) {
        'P' => 'Powertrain',
        'C' => 'Chassis',
        'B' => 'Body',
        'U' => 'Network',
        _ => 'Unknown',
      };

  @override
  String toString() => 'DtcCode($code: $description [$severity])';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DtcCode &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;
}
