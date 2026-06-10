import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/network/xtream_client.dart';
import '../../core/storage/reminder_store.dart';
import '../providers/app_providers.dart';
import '../providers/player_controller_notifier.dart';
import 'player_screen.dart';

/// P105 — Full EPG guide screen.
/// TV-style grid: channel column on the left, programme blocks on a timeline.
/// Accessible via the "Guide" tab in the bottom navigation bar.
class EpgGuideScreen extends ConsumerStatefulWidget {
  const EpgGuideScreen({super.key});

  @override
  ConsumerState<EpgGuideScreen> createState() => _EpgGuideScreenState();
}

class _EpgGuideScreenState extends ConsumerState<EpgGuideScreen> {
  late DateTime _windowStart;
  late DateTime _windowEnd;

  final Map<int, bool> _loadingChannels = {};
  final Map<int, List<XtreamEpgEntry>> _channelEpg = {};
  final Set<int> _loadedStreamIds = {};

  @override
  void initState() {
    super.initState();
    _initWindow();
  }

  void _initWindow() {
    final now = DateTime.now().toUtc();
    _windowStart = DateTime.utc(now.year, now.month, now.day, now.hour, now.minute >= 30 ? 30 : 0)
        .subtract(const Duration(minutes: 30));
    _windowEnd = _windowStart.add(const Duration(hours: 6));
  }

  double _timeToOffset(DateTime time) {
    final diff = time.difference(_windowStart);
    return diff.inMinutes * TimelineMetrics.pixelsPerMinute;
  }

  void _loadEpgForChannel(int streamId) async {
    if (_loadingChannels[streamId] == true) return;
    setState(() => _loadingChannels[streamId] = true);
    try {
      final entries = await ref.read(epgProvider(streamId).future);
      if (mounted) {
        setState(() {
          _channelEpg[streamId] = entries;
          _loadedStreamIds.add(streamId);
          _loadingChannels[streamId] = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingChannels[streamId] = false);
    }
  }

  void _ensureChannelsLoaded(List<XtreamStream> streams) {
    for (final stream in streams) {
      if (!_loadedStreamIds.contains(stream.streamId)) {
        _loadEpgForChannel(stream.streamId);
      }
    }
  }

  void _openChannel(XtreamStream stream, {XtreamEpgEntry? programme}) {
    ref.read(recentChannelsProvider.notifier).add(stream);

    // If programme is provided and is a past programme with catch-up, play from start.
    if (programme != null) {
      final now = DateTime.now().toUtc();
      if (now.isAfter(programme.endTime) &&
          programme.hasCatchup &&
          programme.isInCatchupWindow) {
        _playCatchup(stream, programme);
        return;
      }
    }

    final playerState = ref.read(playerControllerProvider);

    if (playerState.status == PlayerStatus.playing ||
        playerState.status == PlayerStatus.initialising) {
      final url = ref.read(streamUrlProvider(stream.streamId));
      ref.read(playerControllerProvider.notifier).setStream(stream, url);
      return;
    }

    ref.read(selectedStreamProvider.notifier).state = stream;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlayerScreen(stream: stream)),
    );
  }

  void _playCatchup(XtreamStream stream, XtreamEpgEntry programme) {
    final catchupUrl = ref.read(xtreamClientProvider).buildCatchupStreamUrl(
      stream.streamId,
      programme.startTime,
    );
    final playerState = ref.read(playerControllerProvider);

    if (playerState.status == PlayerStatus.playing ||
        playerState.status == PlayerStatus.initialising) {
      ref.read(playerControllerProvider.notifier).setStream(stream, catchupUrl);
      return;
    }

    ref.read(selectedStreamProvider.notifier).state = stream;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(stream: stream, streamUrl: catchupUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final streamsAsync = ref.watch(filteredLiveStreamsProvider);

    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        title: const Text('Guide'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh EPG',
            onPressed: () {
              setState(() {
                _loadedStreamIds.clear();
                _channelEpg.clear();
              });
              ref.invalidate(filteredLiveStreamsProvider);
            },
          ),
        ],
      ),
      body: streamsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: context.appColors.primary),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: context.appColors.error, size: 48),
                const SizedBox(height: AppSpacing.lg),
                Text('Failed to load channels', style: context.appTypography.h3),
                const SizedBox(height: AppSpacing.sm),
                Text(error.toString(), style: context.appTypography.caption, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.xl),
                ElevatedButton(
                  onPressed: () => ref.invalidate(filteredLiveStreamsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (streams) {
          if (streams.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.menu_book_outlined, color: context.appColors.textMuted, size: 64),
                  const SizedBox(height: AppSpacing.lg),
                  Text('No channels', style: context.appTypography.h3),
                ],
              ),
            );
          }

          _ensureChannelsLoaded(streams);

          return _EpgGrid(
            streams: streams,
            channelEpg: _channelEpg,
            loadingChannels: _loadingChannels,
            windowStart: _windowStart,
            windowEnd: _windowEnd,
            timeToOffset: _timeToOffset,
            onProgrammeTap: (s, e) => _openChannel(s, programme: e),
            onChannelTap: (s) => _openChannel(s),
          );
        },
      ),
    );
  }
}

// ─── Timeline layout constants ─────────────────────────────────────────────

class TimelineMetrics {
  static const double pixelsPerMinute = 3.0;
  static const double channelColumnWidth = 120.0;
  static const double rowHeight = 64.0;
  static const double headerHeight = 40.0;

  static double timelineWidth(Duration window) =>
      window.inMinutes * pixelsPerMinute;
}

// ─── EPG Grid ─────────────────────────────────────────────────────────────

class _EpgGrid extends StatefulWidget {
  final List<XtreamStream> streams;
  final Map<int, List<XtreamEpgEntry>> channelEpg;
  final Map<int, bool> loadingChannels;
  final DateTime windowStart;
  final DateTime windowEnd;
  final double Function(DateTime) timeToOffset;
  final void Function(XtreamStream stream, XtreamEpgEntry entry) onProgrammeTap;
  final void Function(XtreamStream) onChannelTap;

  const _EpgGrid({
    required this.streams,
    required this.channelEpg,
    required this.loadingChannels,
    required this.windowStart,
    required this.windowEnd,
    required this.timeToOffset,
    required this.onProgrammeTap,
    required this.onChannelTap,
  });

  @override
  State<_EpgGrid> createState() => _EpgGridState();
}

class _EpgGridState extends State<_EpgGrid> {
  late ScrollController _horizontalController;
  late ScrollController _verticalController;

  @override
  void initState() {
    super.initState();
    _horizontalController = ScrollController();
    _verticalController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nowOffset = widget.timeToOffset(DateTime.now().toUtc());
      final screenWidth = MediaQuery.of(context).size.width;
      final target = nowOffset - (screenWidth / 2) + (TimelineMetrics.channelColumnWidth / 2);
      if (_horizontalController.hasClients) {
        _horizontalController.jumpTo(target.clamp(
          0.0,
          _horizontalController.position.maxScrollExtent,
        ));
      }
    });
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalWidth = TimelineMetrics.timelineWidth(
      widget.windowEnd.difference(widget.windowStart),
    );

    return Column(
      children: [
        // Header: time ruler.
        SizedBox(
          height: TimelineMetrics.headerHeight,
          child: Row(
            children: [
              Container(
                width: TimelineMetrics.channelColumnWidth,
                color: context.appColors.surface,
                alignment: Alignment.center,
                child: Text('CHANNEL', style: context.appTypography.caption),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _horizontalController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: totalWidth,
                    height: TimelineMetrics.headerHeight,
                    child: CustomPaint(
                      painter: _TimeRulerPainter(
                        windowStart: widget.windowStart,
                        windowEnd: widget.windowEnd,
                        pixelsPerMinute: TimelineMetrics.pixelsPerMinute,
                        lineColor: context.appColors.surfaceElevated,
                        textColor: context.appColors.textMuted,
                        halfLineColor: context.appColors.textMuted.withOpacity(0.3),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Body: channel rows.
        Expanded(
          child: Row(
            children: [
              // Fixed channel name column.
              SizedBox(
                width: TimelineMetrics.channelColumnWidth,
                child: ListView.builder(
                  controller: _verticalController,
                  itemCount: widget.streams.length,
                  itemBuilder: (context, index) {
                    final stream = widget.streams[index];
                    return _ChannelLabelCell(
                      stream: stream,
                      onTap: () => widget.onChannelTap(stream),
                    );
                  },
                ),
              ),

              // Scrollable programme grid.
              Expanded(
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      controller: _verticalController,
                      child: SizedBox(
                        height: widget.streams.length * TimelineMetrics.rowHeight,
                        child: ListView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: widget.streams.length,
                          itemBuilder: (context, index) {
                            final stream = widget.streams[index];
                            final entries = widget.channelEpg[stream.streamId] ?? [];
                            final isLoading = widget.loadingChannels[stream.streamId] ?? false;
                            return _ProgrammeRow(
                              stream: stream,
                              entries: entries,
                              isLoading: isLoading,
                              windowStart: widget.windowStart,
                              windowEnd: widget.windowEnd,
                              timeToOffset: widget.timeToOffset,
                              onProgrammeTap: (s, e) => widget.onProgrammeTap(s, e),
                            );
                          },
                        ),
                      ),
                    ),

                    _NowLine(
                      windowStart: widget.windowStart,
                      windowEnd: widget.windowEnd,
                      timeToOffset: widget.timeToOffset,
                      horizontalController: _horizontalController,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Channel label cell ────────────────────────────────────────────────────

class _ChannelLabelCell extends StatelessWidget {
  final XtreamStream stream;
  final VoidCallback onTap;

  const _ChannelLabelCell({required this.stream, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: TimelineMetrics.rowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.appColors.surfaceElevated, width: 1)),
        ),
        child: Row(
          children: [
            if (stream.logo != null && stream.logo!.isNotEmpty)
              SizedBox(
                width: 32,
                height: 32,
                child: Image.network(
                  stream.logo!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => _initial(context),
                ),
              )
            else
              _initial(context),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                stream.name,
                style: TextStyle(fontSize: 12, color: context.appColors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _initial(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: context.appColors.surfaceElevated,
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Text(
        stream.name.isNotEmpty ? stream.name[0].toUpperCase() : '?',
        style: TextStyle(fontSize: 14, color: context.appColors.primary, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ─── Programme row ─────────────────────────────────────────────────────────

class _ProgrammeRow extends StatelessWidget {
  final XtreamStream stream;
  final List<XtreamEpgEntry> entries;
  final bool isLoading;
  final DateTime windowStart;
  final DateTime windowEnd;
  final double Function(DateTime) timeToOffset;
  final void Function(XtreamStream stream, XtreamEpgEntry entry) onProgrammeTap;

  const _ProgrammeRow({
    required this.stream,
    required this.entries,
    required this.isLoading,
    required this.windowStart,
    required this.windowEnd,
    required this.timeToOffset,
    required this.onProgrammeTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        height: TimelineMetrics.rowHeight,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.appColors.surfaceElevated, width: 1)),
        ),
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: context.appColors.primary),
          ),
        ),
      );
    }

    final visible = entries.where((e) {
      final start = e.startTime;
      final end = e.endTime;
      return end.isAfter(windowStart) && start.isBefore(windowEnd);
    }).toList();

    if (visible.isEmpty) {
      return Container(
        height: TimelineMetrics.rowHeight,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.appColors.surfaceElevated, width: 1)),
        ),
      );
    }

    return SizedBox(
      height: TimelineMetrics.rowHeight,
      child: Stack(
        children: visible.map((entry) => _ProgrammeBlock(
          entry: entry,
          stream: stream,
          windowStart: windowStart,
          windowEnd: windowEnd,
          timeToOffset: timeToOffset,
          onTap: (s, e) => onProgrammeTap(s, e),
        )).toList(),
      ),
    );
  }
}

// ─── Programme block ──────────────────────────────────────────────────────

class _ProgrammeBlock extends ConsumerWidget {
  final XtreamEpgEntry entry;
  final XtreamStream stream;
  final DateTime windowStart;
  final DateTime windowEnd;
  final double Function(DateTime) timeToOffset;
  final void Function(XtreamStream stream, XtreamEpgEntry entry) onTap;

  const _ProgrammeBlock({
    required this.entry,
    required this.stream,
    required this.windowStart,
    required this.windowEnd,
    required this.timeToOffset,
    required this.onTap,
  });

  Future<void> _onLongPress(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now().toUtc();
    // Don't let the user "remind" themselves about something that's
    // already on air or past — the menu shouldn't even appear in
    // those cases (we hide it in build), but guard at the handler
    // level too in case the timing flips between build and tap.
    if (!now.isBefore(entry.startTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Can't remind you about a programme that's already started"),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final existing = ref.read(remindersProvider).any(
          (r) => r.id == ReminderStore.makeId(
            channelId: stream.streamId,
            startTime: entry.startTime,
          ),
        );
    if (existing) {
      // Toggle off: long-press on an already-reminded programme
      // cancels the reminder. This is the standard TV-guide UX.
      await ref.read(remindersProvider.notifier).remove(
            ReminderStore.makeId(
              channelId: stream.streamId,
              startTime: entry.startTime,
            ),
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reminder removed: ${entry.title}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final reminder = await ref.read(remindersProvider.notifier).add(
          channelId: stream.streamId,
          channelName: stream.name,
          programmeTitle: entry.title,
          startTime: entry.startTime,
          endTime: entry.endTime,
        );
    if (context.mounted) {
      final fire = reminder.fireAt.toLocal();
      final hh = fire.hour.toString().padLeft(2, '0');
      final mm = fire.minute.toString().padLeft(2, '0');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Will remind you at $hh:$mm — ${entry.title}",
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final start = entry.startTime.isBefore(windowStart) ? windowStart : entry.startTime;
    final end = entry.endTime.isAfter(windowEnd) ? windowEnd : entry.endTime;
    final left = timeToOffset(start);
    final right = timeToOffset(end);
    final width = right - left;

    if (width <= 0) return const SizedBox.shrink();

    final now = DateTime.now().toUtc();
    final isOnNow = now.isAfter(entry.startTime) && now.isBefore(entry.endTime);
    final isPast = now.isAfter(entry.endTime);
    final showCatchupBadge = isPast && entry.hasCatchup && entry.isInCatchupWindow;
    // Future programmes can be reminded. On-now / past programmes
    // can't (the notification time would be in the past, or
    // meaningless).
    final isFuture = now.isBefore(entry.startTime);

    // Did the user already schedule a reminder for this programme?
    final reminderId = ReminderStore.makeId(
      channelId: stream.streamId,
      startTime: entry.startTime,
    );
    final hasReminder = ref.watch(
      remindersProvider.select((list) => list.any((r) => r.id == reminderId)),
    );

    return Positioned(
      left: left,
      top: 4,
      bottom: 4,
      width: width,
      child: GestureDetector(
        onTap: () => onTap(stream, entry),
        onLongPress: isFuture ? () => _onLongPress(context, ref) : null,
        child: Container(
          decoration: BoxDecoration(
            color: isOnNow
                ? context.appColors.primary.withOpacity(0.85)
                : context.appColors.surfaceElevated,
            borderRadius: BorderRadius.circular(4),
            border: isOnNow
                ? Border.all(color: context.appColors.primary, width: 2)
                : Border.all(color: context.appColors.textMuted.withOpacity(0.3)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              if (showCatchupBadge) ...[
                Icon(Icons.replay, size: 10, color: context.appColors.accent),
                const SizedBox(width: 3),
              ],
              if (hasReminder) ...[
                Icon(
                  Icons.notifications_active,
                  size: 10,
                  color: isOnNow ? Colors.white : context.appColors.primary,
                ),
                const SizedBox(width: 3),
              ],
              Expanded(
                child: width > 60
                    ? Text(
                        entry.title,
                        style: TextStyle(
                          fontSize: 11,
                          color: isOnNow ? Colors.white : context.appColors.textSecondary,
                          fontWeight: isOnNow ? FontWeight.w600 : FontWeight.normal,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Now-line ─────────────────────────────────────────────────────────────

class _NowLine extends StatefulWidget {
  final DateTime windowStart;
  final DateTime windowEnd;
  final double Function(DateTime) timeToOffset;
  final ScrollController horizontalController;

  const _NowLine({
    required this.windowStart,
    required this.windowEnd,
    required this.timeToOffset,
    required this.horizontalController,
  });

  @override
  State<_NowLine> createState() => _NowLineState();
}

class _NowLineState extends State<_NowLine> {
  double _scrollPixels = 0;

  @override
  void initState() {
    super.initState();
    _scrollPixels = widget.horizontalController.position.pixels;
    widget.horizontalController.addListener(_onScroll);
  }

  void _onScroll() {
    setState(() {
      _scrollPixels = widget.horizontalController.position.pixels;
    });
  }

  @override
  void dispose() {
    widget.horizontalController.removeListener(_onScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    if (now.isBefore(widget.windowStart) || now.isAfter(widget.windowEnd)) {
      return const SizedBox.shrink();
    }

    final rawOffset = widget.timeToOffset(now);
    final visibleOffset = rawOffset - _scrollPixels;

    if (visibleOffset < -2 || visibleOffset > MediaQuery.of(context).size.width) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: visibleOffset,
      top: 0,
      bottom: 0,
      child: Container(width: 2, color: context.appColors.error),
    );
  }
}

// ─── Time ruler painter ───────────────────────────────────────────────────

class _TimeRulerPainter extends CustomPainter {
  final DateTime windowStart;
  final DateTime windowEnd;
  final double pixelsPerMinute;
  final Color lineColor;
  final Color textColor;
  final Color halfLineColor;

  _TimeRulerPainter({
    required this.windowStart,
    required this.windowEnd,
    required this.pixelsPerMinute,
    required this.lineColor,
    required this.textColor,
    required this.halfLineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;

    final textStyle = TextStyle(
      color: textColor,
      fontSize: 10,
    );

    var cursor = DateTime(windowStart.year, windowStart.month, windowStart.day, windowStart.hour);
    if (cursor.isBefore(windowStart)) {
      cursor = cursor.add(const Duration(hours: 1));
    }

    while (cursor.isBefore(windowEnd)) {
      final offset = cursor.difference(windowStart).inMinutes * pixelsPerMinute;

      canvas.drawLine(Offset(offset, 0), Offset(offset, size.height), paint);

      final label = '${cursor.hour.toString().padLeft(2, '0')}:00';
      final textSpan = TextSpan(text: label, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(offset + 4, (size.height - textPainter.height) / 2));

      final halfOffset = offset + (30 * pixelsPerMinute);
      if (halfOffset < size.width) {
        final halfPaint = Paint()
          ..color = halfLineColor
          ..strokeWidth = 1;
        canvas.drawLine(
          Offset(halfOffset, size.height * 0.6),
          Offset(halfOffset, size.height),
          halfPaint,
        );
      }

      cursor = cursor.add(const Duration(hours: 1));
    }
  }

  @override
  bool shouldRepaint(_TimeRulerPainter old) =>
      windowStart != old.windowStart ||
      windowEnd != old.windowEnd ||
      pixelsPerMinute != old.pixelsPerMinute ||
      lineColor != old.lineColor ||
      textColor != old.textColor ||
      halfLineColor != old.halfLineColor;
}
