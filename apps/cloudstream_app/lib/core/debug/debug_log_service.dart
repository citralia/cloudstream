import 'dart:async';
import 'package:flutter/services.dart';

/// Singleton service that bridges Android logcat to Flutter via EventChannel.
///
/// Auto-starts on construction so logs are always available.
/// Controlled via [enabled] toggle.
class DebugLogService {
  DebugLogService._();

  static final DebugLogService instance = DebugLogService._();

  static const _channel = EventChannel('com.cloudstream.cloudstream_app/logs');

  final _controller = StreamController<String>.broadcast();
  bool _enabled = true;
  StreamSubscription? _subscription;

  /// Live stream of logcat lines.
  Stream<String> get stream => _controller.stream;

  /// Whether log collection is active.
  bool get enabled => _enabled;

  /// Toggle log collection on/off.
  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    if (_enabled) {
      _start();
    } else {
      _stop();
    }
  }

  void start() {
    if (!_enabled) return;
    _start();
  }

  void _start() {
    _subscription?.cancel();
    try {
      _subscription = _channel.receiveBroadcastStream().listen(
        (dynamic line) {
          if (line is String) _controller.add(line);
        },
        onError: (dynamic err) {
          _controller.addError(err);
        },
      );
    } catch (e) {
      // Channel not available (e.g. not on Android) — silently skip.
    }
  }

  void _stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  void dispose() {
    _stop();
    _controller.close();
  }
}
