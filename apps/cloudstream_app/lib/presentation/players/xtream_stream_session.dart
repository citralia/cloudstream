import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/xtream_client.dart';
import '../../core/pip/pip_service.dart';
import '../../domain/entities/cloud_stream_player.dart';

/// Xtream-specific implementation of [CloudStreamPlayer].
///
/// One instance per playback session. Lives inside a Provider so it
/// persists across quick channel switches (Phase 1 P101).
class XtreamStreamSession implements CloudStreamPlayer {
  XtreamStreamSession({required this.xtreamClient});

  final XtreamApiClient xtreamClient;
  final PipService _pipService = PipService();

  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  StreamMode _mode = StreamMode.live;
  Duration _position = Duration.zero;
  Duration? _duration;
  Duration? _bufferedPosition;
  double _volume = 1.0;
  bool _isPlaying = false;

  String _buildCatchupUrl(int streamId, DateTime startTime, Duration duration) {
    final base = xtreamClient.buildLiveStreamUrl(streamId);
    final startEpoch = startTime.millisecondsSinceEpoch ~/ 1000;
    return '$base?start=$startEpoch&duration=${duration.inSeconds}';
  }

  @override
  StreamMode get mode => _mode;

  @override
  PlatformCapabilities get capabilities => const PlatformCapabilities(
        supportsPiP: true,
        supportsBackgroundAudio: true,
        supportsExternalPlayback: true,
      );

  @override
  Duration get position => _videoController?.value.position ?? _position;

  @override
  Duration? get duration => _duration;

  @override
  Duration? get bufferedPosition => _bufferedPosition;

  @override
  bool get isPlaying => _isPlaying;

  @override
  double get volume => _volume;

  void _syncPosition() {
    if (_videoController != null) {
      _position = _videoController!.value.position;
      _duration = _videoController!.value.duration.inMilliseconds > 0
          ? _videoController!.value.duration
          : null;
      _bufferedPosition = _videoController!.value.buffered.isNotEmpty
          ? _videoController!.value.buffered.last.end
          : null;
    }
  }

  Future<void> _initController(String url) async {
    await _disposeControllers();

    _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
    _videoController!.addListener(_syncPosition);

    await _videoController!.initialize();

    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: true,
      looping: false,
      allowFullScreen: true,
      allowMuting: true,
      showControls: true,
      materialProgressColors: ChewieProgressColors(
        playedColor: AppColors.primary,
        handleColor: AppColors.accent,
        backgroundColor: AppColors.surface,
        bufferedColor: AppColors.textMuted,
      ),
      placeholder: Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      errorBuilder: (context, msg) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            Text('Playback error', style: AppTypography.h3),
            const SizedBox(height: 8),
            Text(msg, style: AppTypography.caption, textAlign: TextAlign.center),
          ],
        ),
      ),
    );

    _volume = _videoController!.value.volume;
    _isPlaying = _videoController!.value.isPlaying;
  }

  Future<void> _disposeControllers() async {
    _videoController?.removeListener(_syncPosition);
    _chewieController?.dispose();
    _videoController?.dispose();
    _chewieController = null;
    _videoController = null;
  }

  @override
  Future<void> playLive(int streamId) async {
    _mode = StreamMode.live;
    await _initController(xtreamClient.buildLiveStreamUrl(streamId));
    _isPlaying = true;
  }

  @override
  Future<void> playVod(int streamId) async {
    _mode = StreamMode.vod;
    await _initController(xtreamClient.buildVodStreamUrl(streamId));
    _isPlaying = true;
  }

  @override
  Future<void> playCatchup(int streamId, DateTime startTime, {Duration? duration}) async {
    _mode = StreamMode.catchup;
    final dur = duration ?? const Duration(hours: 3);
    await _initController(_buildCatchupUrl(streamId, startTime, dur));
    _isPlaying = true;
  }

  @override
  Future<void> pause() async {
    await _videoController?.pause();
    _isPlaying = false;
  }

  @override
  Future<void> resume() async {
    await _videoController?.play();
    _isPlaying = true;
  }

  @override
  Future<void> seekTo(Duration position) async {
    await _videoController?.seekTo(position);
    _position = position;
  }

  @override
  Future<void> stop() async {
    await _disposeControllers();
    _position = Duration.zero;
    _isPlaying = false;
  }

  @override
  Future<void> setVolume(double volume) async {
    await _videoController?.setVolume(volume);
    _volume = volume;
  }

  @override
  Future<void> enterPiP() async {
    await _pipService.enter();
  }

  @override
  Future<void> exitPiP() async {
    // Android PiP exits via system gesture or app lifecycle — no explicit API.
  }

  @override
  void dispose() {
    _disposeControllers();
  }
}
