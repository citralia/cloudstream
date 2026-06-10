import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/network/xtream_client.dart';

/// Controls the shared VideoPlayerController lifecycle.
///
/// Call [setStream] to change channel — this disposes the old controller
/// and creates a new one in the background without blocking the UI.
class PlayerControllerNotifier extends StateNotifier<PlayerControllerState> {
  PlayerControllerNotifier() : super(PlayerControllerState.initial());

  /// Switch to a new stream. Completes when the new player is ready.
  Future<void> setStream(XtreamStream stream, String streamUrl) async {
    // If already playing this stream, do nothing.
    if (state.status == PlayerStatus.playing &&
        state.currentStreamId == stream.streamId) {
      return;
    }

    // Cancel any in-flight initialisation.
    if (state.status == PlayerStatus.initialising) {
      _cancelToken++;
    }
    final token = ++_cancelToken;

    state = PlayerControllerState(
      status: PlayerStatus.initialising,
      currentStream: stream,
      currentStreamId: stream.streamId,
      chewieController: state.chewieController,
      error: null,
    );

    try {
      // Dispose old player objects (but keep Chewie shell).
      await state.chewieController?.videoPlayerController.dispose();
      state = state.copyWith(status: PlayerStatus.initialising);

      final videoController = VideoPlayerController.networkUrl(Uri.parse(streamUrl));
      await videoController.initialize();

      // Check we haven't been superseded by a newer call.
      if (token != _cancelToken) {
        await videoController.dispose();
        return;
      }

      final chewieController = ChewieController(
        videoPlayerController: videoController,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        // ChewieProgressColors is built lazily inside the build path
        // — we don't have a BuildContext here, so fall back to the
        // dark tokens (the player always paints on top of a black
        // video surface, so theme brightness doesn't materially
        // affect this). This matches the V14 chunk 2 trade-off
        // documented in `presentation/screens/player_screen.dart`.
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.primary,
          handleColor: AppColors.accent,
          backgroundColor: AppColors.surface,
          bufferedColor: AppColors.textMuted,
        ),
        placeholder: const _LoadingPlaceholder(),
        errorBuilder: (context, errorMessage) => _ErrorDisplay(message: errorMessage),
      );

      if (token != _cancelToken) {
        chewieController.dispose();
        await videoController.dispose();
        return;
      }

      state = PlayerControllerState(
        status: PlayerStatus.playing,
        currentStream: stream,
        currentStreamId: stream.streamId,
        chewieController: chewieController,
        error: null,
      );
    } catch (e) {
      if (token != _cancelToken) return;
      state = state.copyWith(
        status: PlayerStatus.error,
        error: e.toString(),
      );
    }
  }

  /// Attempt to recover from an error state by re-initialising the current stream.
  Future<void> retry() async {
    if (state.currentStream == null) return;
    state = state.copyWith(status: PlayerStatus.initialising, error: null);
    // Re-trigger setStream logic by notifying listeners to re-call setStream.
    // Caller should watch the state and re-call setStream on status==initialising.
  }

  void reset() {
    state.chewieController?.videoPlayerController.dispose();
    state.chewieController?.dispose();
    state = PlayerControllerState.initial();
  }

  @override
  void dispose() {
    state.chewieController?.videoPlayerController.dispose();
    state.chewieController?.dispose();
    super.dispose();
  }

  int _cancelToken = 0;
}

// ── State types ───────────────────────────────────────────────────────────────

enum PlayerStatus { idle, initialising, playing, error }

class PlayerControllerState {
  final PlayerStatus status;
  final XtreamStream? currentStream;
  final int? currentStreamId;
  final ChewieController? chewieController;
  final String? error;

  const PlayerControllerState({
    required this.status,
    this.currentStream,
    this.currentStreamId,
    this.chewieController,
    this.error,
  });

  factory PlayerControllerState.initial() => const PlayerControllerState(
        status: PlayerStatus.idle,
        currentStream: null,
        currentStreamId: null,
        chewieController: null,
        error: null,
      );

  PlayerControllerState copyWith({
    PlayerStatus? status,
    XtreamStream? currentStream,
    int? currentStreamId,
    ChewieController? chewieController,
    String? error,
  }) {
    return PlayerControllerState(
      status: status ?? this.status,
      currentStream: currentStream ?? this.currentStream,
      currentStreamId: currentStreamId ?? this.currentStreamId,
      chewieController: chewieController ?? this.chewieController,
      error: error ?? this.error,
    );
  }
}

// ── Placeholder / error widgets ───────────────────────────────────────────────

class _LoadingPlaceholder extends StatelessWidget {
  const _LoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      color: Colors.black,
      child: Center(
        child: CircularProgressIndicator(color: colors.primary),
      ),
    );
  }
}

class _ErrorDisplay extends StatelessWidget {
  final String message;
  const _ErrorDisplay({required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final typo = context.appTypography;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: colors.error, size: 48),
          const SizedBox(height: 16),
          Text('Playback error', style: typo.h3),
          const SizedBox(height: 8),
          Text(
            message,
            style: typo.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
