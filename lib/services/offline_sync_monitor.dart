import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Triggers synchronization when a network interface becomes available.
/// The upload remains the source of truth because connectivity alone does not
/// guarantee access to the internet.
class OfflineSyncMonitor {
  OfflineSyncMonitor({
    required Future<void> Function() onOnline,
    Connectivity? connectivity,
  })  : _onOnline = onOnline,
        _connectivity = connectivity ?? Connectivity();

  final Future<void> Function() _onOnline;
  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _running = false;

  Future<void> start() async {
    if (_subscription != null) return;
    _subscription = _connectivity.onConnectivityChanged.listen(_handle);
    _handle(await _connectivity.checkConnectivity());
  }

  void _handle(List<ConnectivityResult> results) {
    if (_running ||
        results.every((result) => result == ConnectivityResult.none)) {
      return;
    }
    _running = true;
    Future<void>.sync(_onOnline).whenComplete(() => _running = false);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
