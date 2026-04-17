/// Response from the AI assistant pipeline.
class AiResponse {
  /// Text to speak via TTS and show on screen.
  final String text;

  /// The user's original query that triggered this response.
  final String? userQuery;

  /// Optional route to navigate to after response.
  final String? navigateTo;

  /// Whether this response triggers an action (vs. just informational).
  final bool actionExecuted;

  /// The intent that generated this response.
  final String intentAction;

  /// Timestamp of the response.
  final DateTime timestamp;

  AiResponse({
    required this.text,
    this.userQuery,
    this.navigateTo,
    this.actionExecuted = false,
    this.intentAction = '',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  AiResponse copyWith({
    String? text,
    String? userQuery,
    String? navigateTo,
    bool? actionExecuted,
    String? intentAction,
  }) {
    return AiResponse(
      text: text ?? this.text,
      userQuery: userQuery ?? this.userQuery,
      navigateTo: navigateTo ?? this.navigateTo,
      actionExecuted: actionExecuted ?? this.actionExecuted,
      intentAction: intentAction ?? this.intentAction,
      timestamp: timestamp,
    );
  }

  factory AiResponse.error(String message) => AiResponse(
        text: message,
        intentAction: 'ERROR',
      );

  factory AiResponse.empty() => AiResponse(
        text: '',
        intentAction: 'NONE',
      );

  @override
  String toString() => 'AiResponse($intentAction: "$text")';
}
