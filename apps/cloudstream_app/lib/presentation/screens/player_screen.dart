import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/xtream_client.dart';
import '../../core/pip/pip_service.dart';
import '../providers/app_providers.dart';
import 'player_gesture_overlay.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final XtreamStream stream;

  const PlayerScreen({super.key, required this.stream});

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
    _chewieController?.dispose();
    _videoController?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    try {
      // Build stream URL directly from stored credentials
      final streamUrl = ref.read(streamUrlProvider(widget.stream.streamId));

      // Initialise video player with the HLS manifest
      _videoController = VideoPlayerController.networkUrl(Uri.parse(streamUrl));
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
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                const SizedBox(height: 16),
                Text('Playback error', style: AppTypography.h3),
                const SizedBox(height: 8),
                Text(
                  errorMessage,
                  style: AppTypography.caption,
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
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
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
                              style: AppTypography.h3.copyWith(color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_currentProgramme != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                _currentProgramme!.title,
                                style: AppTypography.caption.copyWith(color: Colors.white70),
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
            const Icon(Icons.error_outline, color: AppColors.error, size: 64),
            const SizedBox(height: AppSpacing.lg),
            Text('Playback failed', style: AppTypography.h2),
            const SizedBox(height: AppSpacing.sm),
            Text(
              error,
              style: AppTypography.caption,
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
