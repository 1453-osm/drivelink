import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reactive connectivity service — single source of truth for online/offline.
class ConnectivityService {
  ConnectivityService() {
    _subscription = Connectivity().onConnectivityChanged.listen(_onChanged);
    // Check initial state
    Connectivity().checkConnectivity().then(_onChanged);
  }

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final _controller = StreamController<bool>.broadcast();
  bool _isOnline = false;

  /// Current connectivity state (sync).
  bool get isOnline => _isOnline;

  /// Reactive stream — emits current value immediately on listen.
  Stream<bool> get onlineStream async* {
    yield _isOnline;
    yield* _controller.stream;
  }

  void _onChanged(List<ConnectivityResult> results) {
    final online = results.isNotEmpty &&
        !results.every((r) => r == ConnectivityResult.none);
    if (online != _isOnline) {
      _isOnline = online;
      if (!_controller.isClosed) _controller.add(online);
    }
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}

// ── Riverpod providers ─────────────────────────────────────────────────

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(() => service.dispose());
  return service;
});

final isOnlineProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.onlineStream;
});
