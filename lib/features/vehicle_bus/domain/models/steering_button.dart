/// Physical buttons on the steering wheel that the VAN bus reports.
enum SteeringButton {
  volUp,
  volDown,
  next,
  prev,
  src,
  phone,
  scrollUp,
  scrollDown,
}

/// Whether the button was pressed or released.
enum SteeringAction {
  press,
  release,
}

/// A single steering-wheel button event.
class SteeringEvent {
  final SteeringButton button;
  final SteeringAction action;
  final DateTime timestamp;

  const SteeringEvent({
    required this.button,
    required this.action,
    required this.timestamp,
  });

  @override
  String toString() =>
      'SteeringEvent(button: ${button.name}, action: ${action.name})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SteeringEvent &&
          runtimeType == other.runtimeType &&
          button == other.button &&
          action == other.action &&
          timestamp == other.timestamp;

  @override
  int get hashCode =>
      button.hashCode ^ action.hashCode ^ timestamp.hashCode;
}
