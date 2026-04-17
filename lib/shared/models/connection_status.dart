/// Connection state for serial adapters (ESP32 / ELM327).
enum ConnectionStatus {
  /// Adapter is connected and communicating normally.
  connected,

  /// A connection attempt is in progress.
  connecting,

  /// No adapter detected on the USB port.
  disconnected,

  /// Communication error (timeout, CRC mismatch, etc.).
  error;

  /// Human-readable label for the UI.
  String get label => switch (this) {
        ConnectionStatus.connected => 'Connected',
        ConnectionStatus.connecting => 'Connecting...',
        ConnectionStatus.disconnected => 'Disconnected',
        ConnectionStatus.error => 'Error',
      };

  /// Whether data from this adapter can be trusted right now.
  bool get isUsable => this == ConnectionStatus.connected;
}
