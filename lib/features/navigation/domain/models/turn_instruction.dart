/// Type of manoeuvre at a turn point.
enum TurnType {
  turnRight,
  turnLeft,
  roundabout,
  continue_,
  arrive,
  uturn,
  mergeLeft,
  mergeRight;

  /// A human-readable label used in the UI.
  String get label => switch (this) {
        TurnType.turnRight => 'Saga don',
        TurnType.turnLeft => 'Sola don',
        TurnType.roundabout => 'Donel kavsak',
        TurnType.continue_ => 'Devam et',
        TurnType.arrive => 'Hedefe vardiniz',
        TurnType.uturn => 'U donusu yap',
        TurnType.mergeLeft => 'Sola katil',
        TurnType.mergeRight => 'Saga katil',
      };

  /// Icon data for the turn arrow displayed on the HUD card.
  String get iconAsset => switch (this) {
        TurnType.turnRight => 'turn_right',
        TurnType.turnLeft => 'turn_left',
        TurnType.roundabout => 'roundabout',
        TurnType.continue_ => 'straight',
        TurnType.arrive => 'arrive',
        TurnType.uturn => 'uturn',
        TurnType.mergeLeft => 'merge_left',
        TurnType.mergeRight => 'merge_right',
      };
}

/// A single manoeuvre instruction along a calculated route.
class TurnInstruction {
  const TurnInstruction({
    required this.type,
    required this.distance,
    required this.streetName,
    this.exitNumber,
  });

  /// Kind of manoeuvre.
  final TurnType type;

  /// Distance in metres from the previous instruction (or route start).
  final double distance;

  /// Name of the street to follow after this manoeuvre.
  final String streetName;

  /// Roundabout exit number (only meaningful when [type] is [TurnType.roundabout]).
  final int? exitNumber;

  /// Formatted distance string for display (m / km).
  String get formattedDistance {
    if (distance >= 1000) {
      return '${(distance / 1000).toStringAsFixed(1)} km';
    }
    return '${distance.round()} m';
  }

  TurnInstruction copyWith({
    TurnType? type,
    double? distance,
    String? streetName,
    int? exitNumber,
  }) {
    return TurnInstruction(
      type: type ?? this.type,
      distance: distance ?? this.distance,
      streetName: streetName ?? this.streetName,
      exitNumber: exitNumber ?? this.exitNumber,
    );
  }

  @override
  String toString() =>
      'TurnInstruction(${type.label}, $formattedDistance, "$streetName")';
}
