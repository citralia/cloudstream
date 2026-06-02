import 'package:flutter/services.dart';

/// Service for entering and exiting Android Picture-in-Picture mode.
///
/// Uses a platform channel defined in MainActivity.kt.
class PipService {
  static const _channel = MethodChannel('com.cloudstream.cloudstream_app/pip');

  /// Returns true if the device supports PiP.
  Future<bool> isSupported() async {
    final result = await _channel.invokeMethod<bool>('isSupported');
    return result ?? false;
  }

  /// Enter PiP mode. Returns true on success.
  Future<bool> enter() async {
    final result = await _channel.invokeMethod<bool>('enterPictureInPicture');
    return result ?? false;
  }

  /// Returns true if currently in PiP mode.
  Future<bool> isInPipMode() async {
    final result = await _channel.invokeMethod<bool>('isInPictureInPictureMode');
    return result ?? false;
  }

  /// Listen for PiP mode changes. Call with a callback to receive
  /// `true` when entering PiP and `false` when exiting.
  void onPipModeChanged(void Function(bool) callback) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPictureInPictureModeChanged') {
        callback(call.arguments as bool);
      }
    });
  }
}
