/// Parsed user intent from voice command or text input.
class Intent {
  /// Action identifier (e.g. 'NAV_HOME', 'MEDIA_PLAY', 'AI_CHAT').
  final String action;

  /// Extracted parameters (e.g. {'destination': 'Ankara'}).
  final Map<String, String> params;

  /// Confidence score (0.0 – 1.0).
  final double confidence;

  /// Which parser resolved this intent ('rule_based' or 'llm').
  final String source;

  /// Original transcript text.
  final String transcript;

  const Intent({
    required this.action,
    this.params = const {},
    this.confidence = 1.0,
    this.source = 'rule_based',
    this.transcript = '',
  });

  bool get isNavigation => action.startsWith('NAV_');
  bool get isVehicle => action.startsWith('VEHICLE_');
  bool get isMedia => action.startsWith('MEDIA_');
  bool get isSystem => action.startsWith('SYSTEM_');
  bool get isChat => action == 'AI_CHAT';
  bool get isUnknown => action == 'UNKNOWN';

  @override
  String toString() =>
      'Intent($action, confidence: ${confidence.toStringAsFixed(2)}, '
      'source: $source, params: $params)';
}
