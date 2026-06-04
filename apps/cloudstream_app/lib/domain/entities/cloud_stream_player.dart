/// Stream mode determines position semantics and UI treatment.
enum StreamMode {
  /// Live TV — no seeking, position = live edge.
  live,
  /// Catch-up — seekable within the catch-up window.
  catchup,
  /// VOD — fully seekable, stores watch progress.
  vod,
}

/// Platform capability flags for the current device.
class PlatformCapabilities {
  final bool supportsPiP;
  final bool supportsBackgroundAudio;
  final bool supportsAirPlay;
  final bool supportsCast;
  final bool supportsExternalPlayback;

  const PlatformCapabilities({
    this.supportsPiP = false,
    this.supportsBackgroundAudio = false,
    this.supportsAirPlay = false,
    this.supportsCast = false,
    this.supportsExternalPlayback = false,
  });
}

/// A unified player session that handles live TV, catch-up, and VOD
/// as seek positions on a single transport layer.
///
/// Phase 1: wraps Chewie + VideoPlayerController
/// Phase 4+: swapped per-provider (Xtream → M3U → Stalker)
abstract class CloudStreamPlayer {
  /// Current stream mode.
  StreamMode get mode;

  /// Platform capabilities.
  PlatformCapabilities get capabilities;

  /// Play a live channel.
  Future<void> playLive(int streamId);

  /// Play a VOD item.
  Future<void> playVod(int streamId);

  /// Play from a specific catch-up position (EPG entry start time).
  Future<void> playCatchup(int streamId, DateTime startTime, {Duration? duration});

  /// Pause playback.
  Future<void> pause();

  /// Resume playback.
  Future<void> resume();

  /// Seek to a position (not available on live).
  Future<void> seekTo(Duration position);

  /// Stop playback and release resources.
  Future<void> stop();

  /// Current playback position.
  Duration get position;

  /// Total stream duration (null for live/catchup without known duration).
  Duration? get duration;

  /// Buffered position.
  Duration? get bufferedPosition;

  /// Is the player currently playing.
  bool get isPlaying;

  /// Stream volume (0.0 – 1.0).
  double get volume;

  /// Set stream volume.
  Future<void> setVolume(double volume);

  /// Enter picture-in-picture.
  Future<void> enterPiP();

  /// Exit picture-in-picture.
  Future<void> exitPiP();

  /// Dispose the player session.
  void dispose();
}
