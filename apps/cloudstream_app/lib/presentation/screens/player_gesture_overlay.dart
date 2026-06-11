import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_extensions.dart';

/// Wraps a [VideoPlayerController] and exposes gesture-based controls:
///
/// - **Horizontal swipe**: seek ±seconds proportional to swipe distance
/// - **Vertical swipe on left third**: brightness (0–1)
/// - **Vertical swipe on right third**: volume (0–1)
/// - **Double tap left/right**: seek −10s / +10s
/// - **Single tap**: toggle controls visibility
///
/// The overlay shows brief indicator labels (e.g. "−30s", "🔇 50%") that
/// auto-fade after 800 ms.
class PlayerGestureOverlay extends StatefulWidget {
  final VideoPlayerController controller;
  final Widget child;
  final Duration seekStep;

  const PlayerGestureOverlay({
    super.key,
    required this.controller,
    required this.child,
    this.seekStep = const Duration(seconds: 10),
  });

  @override
  State<PlayerGestureOverlay> createState() => _PlayerGestureOverlayState();
}

class _PlayerGestureOverlayState extends State<PlayerGestureOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  String? _label;
  IconData? _labelIcon;

  Offset? _dragStart;
  double _dragAccumulatedDx = 0;
  bool _isVerticalLeft = false; // true = left third (brightness), false = right third (volume)
  double _dragStartValue = 0; // 0.0–1.0

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _label = null);
        }
      });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _showLabel(String label, {IconData? icon}) {
    setState(() {
      _label = label;
      _labelIcon = icon;
    });
    _fadeController.reset();
    _fadeController.forward();
  }

  void _onDoubleTap(TapDownDetails details, BoxConstraints constraints) {
    final screenWidth = constraints.maxWidth;
    final dx = details.localPosition.dx;
    if (dx < screenWidth / 2) {
      _seekRelative(-widget.seekStep);
      _showLabel('−${widget.seekStep.inSeconds}s');
    } else {
      _seekRelative(widget.seekStep);
      _showLabel('+${widget.seekStep.inSeconds}s');
    }
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _dragStart = details.localPosition;
    _dragAccumulatedDx = 0;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_dragStart == null) return;
    _dragAccumulatedDx += details.delta.dx;
    // Show seek preview
    final seconds = (_dragAccumulatedDx / 5).round(); // 5px per second
    if (seconds != 0) {
      final prefix = seconds > 0 ? '+' : '';
      _showLabel('$prefix${seconds}s');
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_dragStart != null && _dragAccumulatedDx.abs() > 10) {
      final seekSeconds = (_dragAccumulatedDx / 5).round();
      _seekRelative(Duration(seconds: seekSeconds));
    }
    _dragStart = null;
    _dragAccumulatedDx = 0;
  }

  void _seekRelative(Duration delta) {
    if (!widget.controller.value.isInitialized) return;
    final position = widget.controller.value.position;
    final duration = widget.controller.value.duration;
    var newPosition = position + delta;
    if (newPosition < Duration.zero) newPosition = Duration.zero;
    if (newPosition > duration) newPosition = duration;
    widget.controller.seekTo(newPosition);
  }

  void _onVerticalDragStart(DragStartDetails details, BoxConstraints constraints) {
    _dragStart = details.localPosition;
    final screenWidth = constraints.maxWidth;
    final dx = details.localPosition.dx;
    _isVerticalLeft = dx < screenWidth / 3;
    _dragStartValue = _isVerticalLeft ? 1.0 : widget.controller.value.volume;
  }

  void _onVerticalDragUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (_dragStart == null) return;
    final screenHeight = constraints.maxHeight;
    final dy = details.delta.dy;
    // Dragging up = increase, down = decrease
    final delta = -dy / screenHeight;
    if (_isVerticalLeft) {
      final newVal = (_dragStartValue + delta).clamp(0.0, 1.0);
      _showLabel('☀️ ${(newVal * 100).round()}%', icon: Icons.brightness_6);
    } else {
      final newVol = (_dragStartValue + delta).clamp(0.0, 1.0);
      widget.controller.setVolume(newVol);
      _showLabel(
        newVol == 0 ? '🔇' : '🔊 ${(newVol * 100).round()}%',
        icon: newVol == 0 ? Icons.volume_off : Icons.volume_up,
      );
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    _dragStart = null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTap: () {}, // consume tap to prevent player controls from hiding
          onDoubleTapDown: (details) => _onDoubleTap(details, constraints),
          onHorizontalDragStart: _onHorizontalDragStart,
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          onVerticalDragStart: (details) => _onVerticalDragStart(details, constraints),
          onVerticalDragUpdate: (details) => _onVerticalDragUpdate(details, constraints),
          onVerticalDragEnd: _onVerticalDragEnd,
          behavior: HitTestBehavior.translucent,
          child: Stack(
            children: [
              widget.child,
              if (_label != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _fadeController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: 1 - _fadeController.value,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                                vertical: AppSpacing.md,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_labelIcon != null) ...[
                                    Icon(_labelIcon, color: Colors.white, size: 28),
                                    const SizedBox(width: AppSpacing.sm),
                                  ],
                                  Text(
                                    _label!,
                                    style: context.appTypography.h2.copyWith(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
