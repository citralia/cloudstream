import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/network/xtream_client.dart';

/// An overlay shown at the bottom of the player that lists recent channels
/// and lets the user tap to switch instantly.
///
/// Hidden by default; revealed by tapping the screen or pressing OK/Enter.
class QuickChannelOverlay extends ConsumerStatefulWidget {
  final List<XtreamStream> recentStreams;
  final void Function(XtreamStream) onChannelSelected;
  final bool isVisible;
  final VoidCallback onDismiss;

  const QuickChannelOverlay({
    super.key,
    required this.recentStreams,
    required this.onChannelSelected,
    required this.isVisible,
    required this.onDismiss,
  });

  @override
  ConsumerState<QuickChannelOverlay> createState() => _QuickChannelOverlayState();
}

class _QuickChannelOverlayState extends ConsumerState<QuickChannelOverlay> {
  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible || widget.recentStreams.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: GestureDetector(
        onTap: widget.onDismiss,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.9),
                Colors.black.withValues(alpha: 0.0),
              ],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz, color: context.appColors.primary, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Quick Switch',
                      style: context.appTypography.caption.copyWith(
                        color: context.appColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.recentStreams.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final stream = widget.recentStreams[index];
                    return _RecentChannelChip(
                      stream: stream,
                      onTap: () {
                        widget.onDismiss();
                        widget.onChannelSelected(stream);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal chip for one recently-watched channel.
class _RecentChannelChip extends StatelessWidget {
  final XtreamStream stream;
  final VoidCallback onTap;

  const _RecentChannelChip({required this.stream, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        decoration: BoxDecoration(
          color: context.appColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.appColors.textMuted.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (stream.logo != null && stream.logo!.isNotEmpty)
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                  child: Image.network(
                    stream.logo!,
                    fit: BoxFit.contain,
                    width: 60,
                    errorBuilder: (_, __, ___) => _initial(context),
                  ),
                ),
              )
            else
              _initial(context),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                stream.name,
                style: TextStyle(fontSize: 11, color: context.appColors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _initial(BuildContext context) {
    return Center(
      child: Text(
        stream.name.isNotEmpty ? stream.name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: 20,
          color: context.appColors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Keyboard entry for channel number — shown when user types 0–9 on a remote.
class ChannelNumberBar extends StatefulWidget {
  final void Function(String digits) onSubmit;

  const ChannelNumberBar({super.key, required this.onSubmit});

  @override
  State<ChannelNumberBar> createState() => _ChannelNumberBarState();
}

class _ChannelNumberBarState extends State<ChannelNumberBar> {
  String _digits = '';

  void addDigit(String d) {
    if (_digits.length >= 4) return;
    setState(() => _digits += d);
  }

  void backspace() {
    if (_digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  void submit() {
    if (_digits.isEmpty) return;
    widget.onSubmit(_digits);
    setState(() => _digits = '');
  }

  void clear() => setState(() => _digits = '');

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.dialpad, color: context.appColors.primary, size: 18),
          const SizedBox(width: 8),
          Text(
            _digits.isEmpty ? '—' : _digits,
            style: const TextStyle(
              fontSize: 22,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: backspace,
            child: Icon(Icons.backspace_outlined, color: context.appColors.textMuted, size: 18),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: clear,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Text('CLR', style: TextStyle(fontSize: 11, color: context.appColors.textMuted)),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: submit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: context.appColors.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('GO', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
