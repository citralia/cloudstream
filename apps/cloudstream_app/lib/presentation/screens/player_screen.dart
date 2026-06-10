import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/network/xtream_client.dart';
import '../../core/pip/pip_service.dart';
import '../providers/app_providers.dart';
import 'player_gesture_overlay.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final XtreamStream stream;
  final String? streamUrl; // Optional: pass VOD URL directly
  final Duration? startPosition; // Optional: resume from position

  const PlayerScreen({
    super.key,
    required this.stream,
    this.streamUrl,
    this.startPosition,
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _error;
  XtreamEpgEntry? _currentProgramme;
  final PipService _pipService = PipService();

  // Watch progress
  static const _progressSaveInterval = Duration(seconds: 30);
  DateTime _lastSaveTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _enterFullScreen();
  }

  void _enterFullScreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
  }

  Future<void> _enterPip() async {
    await _pipService.enter();
  }

  @override
  void dispose() {
    _saveProgress();
    _chewieController?.dispose();
    _videoController?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _onPositionChanged() {
    final now = DateTime.now();
    if (now.difference(_lastSaveTime) >= _progressSaveInterval) {
      _lastSaveTime = now;
      _saveProgress();
    }
  }

  Future<void> _saveProgress() async {
    if (_videoController == null) return;
    final position = _videoController!.value.position.inMilliseconds;
    if (position <= 0) return;
    try {
      final creds = await ref.read(credentialsStoreProvider).loadActiveConnection();
      if (creds == null) return;
      final store = ref.read(watchProgressStoreProvider);
      await store.saveProgress(
        profileId: creds.name,
        streamId: widget.stream.streamId,
        positionMs: position,
      );
      // Bump the per-profile play count for the "Most Watched" home row.
      // Fire-and-forget — a failure here must never block progress save
      // or disrupt playback.
      unawaited(
        ref.read(playCountStoreProvider).increment(
              profileId: creds.name,
              streamId: widget.stream.streamId,
            ),
      );
    } catch (_) {
      // Non-fatal
    }
  }

  Future<void> _initializePlayer() async {
    try {
      // Build stream URL: use explicit VOD URL if provided, otherwise construct from stream ID
      final streamUrl = widget.streamUrl ??
          ref.read(streamUrlProvider(widget.stream.streamId));

      // Capture theme tokens before any await — these are the tokens
      // the player's `errorBuilder` and `placeholder` will read once
      // the controller finishes initialising. Chewie invokes those
      // builders long after the await, so reading `context.appColors`
      // inside them would trip the `use_build_context_synchronously`
      // lint and risk a stale `context` (State.dispose can race).
      final colors = context.appColors;
      final typo = context.appTypography;

      // Initialise video player with the HLS manifest
      _videoController = VideoPlayerController.networkUrl(Uri.parse(streamUrl!));
      _videoController!.addListener(_onPositionChanged);
      await _videoController!.initialize();

      // Seek to startPosition if provided (resume)
      if (widget.startPosition != null) {
        await _videoController!.seekTo(widget.startPosition!);
      }

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: colors.primary,
          handleColor: colors.accent,
          backgroundColor: colors.surface,
          bufferedColor: colors.textMuted,
        ),
        placeholder: Container(
          color: Colors.black,
          child: Center(
            child: CircularProgressIndicator(color: colors.primary),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: colors.error, size: 48),
                const SizedBox(height: 16),
                Text('Playback error', style: typo.h3),
                const SizedBox(height: 8),
                Text(
                  errorMessage,
                  style: typo.caption,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      );

      // Load EPG for this channel
      _loadEpg();

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } on XtreamApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to play stream: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadEpg() async {
    try {
      final entries = await ref.read(epgProvider(widget.stream.streamId).future);
      if (entries.isEmpty) return;

      final now = DateTime.now();
      for (final entry in entries) {
        final start = entry.startTime;
        final end = entry.endTime;
        if (now.isAfter(start) && now.isBefore(end)) {
          if (mounted) setState(() => _currentProgramme = entry);
          break;
        }
      }
    } catch (_) {
      // EPG failure is non-fatal
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Video player
            Positioned.fill(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: context.appColors.primary),
                    )
                  : _error != null
                      ? _ErrorView(
                          error: _error!,
                          onRetry: () {
                            setState(() {
                              _isLoading = true;
                              _error = null;
                            });
                            _initializePlayer();
                          },
                        )
                      : _chewieController != null
                          ? PlayerGestureOverlay(
                              controller: _chewieController!.videoPlayerController,
                              child: Chewie(controller: _chewieController!),
                            )
                          : const SizedBox.expand(),
            ),

            // Top bar — channel info
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: _isLoading || _error != null ? 0 : 1,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton(
                        icon: const Icon(Icons.picture_in_picture_alt, color: Colors.white),
                        onPressed: _enterPip,
                        tooltip: 'Picture in Picture',
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.stream.name,
                              style: context.appTypography.h3.copyWith(color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_currentProgramme != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                _currentProgramme!.title,
                                style: context.appTypography.caption.copyWith(color: Colors.white70),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: context.appColors.error, size: 64),
            const SizedBox(height: AppSpacing.lg),
            Text('Playback failed', style: context.appTypography.h2),
            const SizedBox(height: AppSpacing.sm),
            Text(
              error,
              style: context.appTypography.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
