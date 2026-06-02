import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/xtream_client.dart';
import '../providers/app_providers.dart';
import '../providers/player_controller_notifier.dart';
import '../widgets/quick_channel_overlay.dart';
import 'player_screen.dart';

class ChannelListScreen extends ConsumerStatefulWidget {
  const ChannelListScreen({super.key});

  @override
  ConsumerState<ChannelListScreen> createState() => _ChannelListScreenState();
}

class _ChannelListScreenState extends ConsumerState<ChannelListScreen> {
  void _openPlayer(BuildContext context, WidgetRef ref, XtreamStream stream) {
    // Record in recent history.
    ref.read(recentChannelsProvider.notifier).add(stream);

    // If a channel is already playing, switch it instantly without pushing a new route.
    final playerState = ref.read(playerControllerProvider);
    if (playerState.status == PlayerStatus.playing ||
        playerState.status == PlayerStatus.initialising) {
      final url = ref.read(streamUrlProvider(stream.streamId));
      ref.read(playerControllerProvider.notifier).setStream(stream, url);
      ref.read(quickSwitcherOverlayVisibleProvider.notifier).state = false;
      return;
    }

    // No active player — push the full-screen player route.
    ref.read(selectedStreamProvider.notifier).state = stream;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlayerScreen(stream: stream)),
    );
  }

  void _switchToStream(XtreamStream stream) {
    ref.read(recentChannelsProvider.notifier).add(stream);
    final url = ref.read(streamUrlProvider(stream.streamId));
    ref.read(playerControllerProvider.notifier).setStream(stream, url);
    ref.read(quickSwitcherOverlayVisibleProvider.notifier).state = false;
  }

  void _openFullPlayer() {
    final state = ref.read(playerControllerProvider);
    if (state.currentStream != null) {
      ref.read(selectedStreamProvider.notifier).state = state.currentStream;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PlayerScreen(stream: state.currentStream!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCategoryId = ref.watch(selectedCategoryIdProvider);
    final streamsAsync = ref.watch(filteredLiveStreamsProvider);
    final playerState = ref.watch(playerControllerProvider);
    final recentChannels = ref.watch(recentChannelsProvider);
    final overlayVisible = ref.watch(quickSwitcherOverlayVisibleProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Live TV'),
        actions: [
          if (playerState.status != PlayerStatus.idle)
            IconButton(
              icon: const Icon(Icons.open_in_full),
              tooltip: 'Expand player',
              onPressed: _openFullPlayer,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(liveStreamsProvider);
              ref.invalidate(filteredLiveStreamsProvider);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              const CategoryFilterChips(),
              Expanded(
                child: streamsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                  error: (error, stack) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                          const SizedBox(height: AppSpacing.lg),
                          Text('Failed to load channels', style: AppTypography.h3),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            error.toString(),
                            style: AppTypography.caption,
                            textAlign: TextAlign.center,
                          ),
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
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.live_tv_outlined, color: AppColors.textMuted, size: 64),
                            SizedBox(height: AppSpacing.lg),
                            Text('No channels found', style: AppTypography.h3),
                            SizedBox(height: AppSpacing.sm),
                            Text(
                              'Check your Xtream credentials\nor refresh to try again.',
                              style: AppTypography.caption,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    if (selectedCategoryId != null) {
                      return _FlatChannelList(
                        streams: streams,
                        onTap: (stream) => _openPlayer(context, ref, stream),
                      );
                    } else {
                      return _GroupedChannelList(
                        streams: streams,
                        onTap: (stream) => _openPlayer(context, ref, stream),
                      );
                    }
                  },
                ),
              ),
            ],
          ),

          // Mini-player bar at the bottom when something is playing/loading.
          if (playerState.status != PlayerStatus.idle)
            _MiniPlayerBar(
              state: playerState,
              onTap: _openFullPlayer,
              onClose: () {
                ref.read(playerControllerProvider.notifier).dispose();
                ref.read(playerControllerProvider.notifier); // re-create fresh
              },
              onOverlayToggle: () => ref.read(quickSwitcherOverlayVisibleProvider.notifier).state =
                  !ref.read(quickSwitcherOverlayVisibleProvider),
            ),

          // Quick-channel switcher overlay.
          if (playerState.status != PlayerStatus.idle && recentChannels.isNotEmpty)
            QuickChannelOverlay(
              recentStreams: recentChannels,
              onChannelSelected: _switchToStream,
              isVisible: overlayVisible,
              onDismiss: () => ref.read(quickSwitcherOverlayVisibleProvider.notifier).state = false,
            ),
        ],
      ),
    );
  }
}

// ── Mini player bar ────────────────────────────────────────────────────────────

class _MiniPlayerBar extends StatelessWidget {
  final PlayerControllerState state;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final VoidCallback onOverlayToggle;

  const _MiniPlayerBar({
    required this.state,
    required this.onTap,
    required this.onClose,
    required this.onOverlayToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: GestureDetector(
        onTap: onOverlayToggle,
        onVerticalDragEnd: (_) => onTap(),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            border: const Border(top: BorderSide(color: AppColors.textMuted, width: 0.5)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                // Thumbnail / logo
                Container(
                  width: 52,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: state.currentStream?.logo != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            state.currentStream!.logo!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => _placeholder(),
                          ),
                        )
                      : _placeholder(),
                ),
                const SizedBox(width: 10),
                // Channel name + status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        state.currentStream?.name ?? '...',
                        style: AppTypography.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _statusText,
                        style: AppTypography.caption.copyWith(
                          color: _statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status indicator
                SizedBox(
                  width: 20,
                  height: 20,
                  child: _statusWidget,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: AppColors.textMuted,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _statusText {
    switch (state.status) {
      case PlayerStatus.initialising:
        return 'Loading...';
      case PlayerStatus.playing:
        return 'Playing';
      case PlayerStatus.error:
        return 'Error';
      case PlayerStatus.idle:
        return '';
    }
  }

  Color get _statusColor {
    switch (state.status) {
      case PlayerStatus.initialising:
        return AppColors.textMuted;
      case PlayerStatus.playing:
        return AppColors.primary;
      case PlayerStatus.error:
        return AppColors.error;
      case PlayerStatus.idle:
        return AppColors.textMuted;
    }
  }

  Widget get _statusWidget {
    switch (state.status) {
      case PlayerStatus.initialising:
        return const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
        );
      case PlayerStatus.playing:
        return const Icon(Icons.play_arrow, color: AppColors.primary, size: 18);
      case PlayerStatus.error:
        return const Icon(Icons.error_outline, color: AppColors.error, size: 18);
      case PlayerStatus.idle:
        return const SizedBox.shrink();
    }
  }

  Widget _placeholder() {
    return Center(
      child: Text(
        (state.currentStream?.name.isNotEmpty ?? false)
            ? state.currentStream!.name[0].toUpperCase()
            : '?',
        style: const TextStyle(fontSize: 14, color: AppColors.primary),
      ),
    );
  }
}

// ── Channel list widgets (unchanged) ─────────────────────────────────────────

class _FlatChannelList extends StatelessWidget {
  final List<XtreamStream> streams;
  final void Function(XtreamStream) onTap;

  const _FlatChannelList({required this.streams, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100), // above mini player
      itemCount: streams.length,
      itemBuilder: (context, index) => ChannelTile(
        stream: streams[index],
        onTap: () => onTap(streams[index]),
      ),
    );
  }
}

class _GroupedChannelList extends StatelessWidget {
  final List<XtreamStream> streams;
  final void Function(XtreamStream) onTap;

  const _GroupedChannelList({required this.streams, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final grouped = <int, List<XtreamStream>>{};
    for (final stream in streams) {
      grouped.putIfAbsent(stream.categoryId, () => []).add(stream);
    }
    final sortedKeys = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final categoryId = sortedKeys[index];
        final categoryStreams = grouped[categoryId]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm,
              ),
              child: Text(
                categoryStreams.first.name.isNotEmpty ? categoryStreams.first.name : 'All Channels',
                style: AppTypography.h3.copyWith(color: AppColors.textSecondary),
              ),
            ),
            ...categoryStreams.map((stream) => ChannelTile(
              stream: stream,
              onTap: () => onTap(stream),
            )),
            const Divider(height: 1),
          ],
        );
      },
    );
  }
}

// ── Category chips (unchanged) ────────────────────────────────────────────────

class CategoryFilterChips extends ConsumerWidget {
  const CategoryFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(liveCategoriesProvider);
    final selectedCategoryId = ref.watch(selectedCategoryIdProvider);

    return SizedBox(
      height: 52,
      child: categoriesAsync.when(
        loading: () => const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
          ),
        ),
        error: (_, __) => const SizedBox.shrink(),
        data: (categories) {
          if (categories.isEmpty) return const SizedBox.shrink();
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            itemCount: categories.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _FilterChip(
                  label: 'All',
                  isSelected: selectedCategoryId == null,
                  onTap: () => ref.read(selectedCategoryIdProvider.notifier).state = null,
                );
              }
              final category = categories[index - 1];
              final isSelected = selectedCategoryId == category.id;
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: _FilterChip(
                  label: category.name,
                  isSelected: isSelected,
                  onTap: () => ref.read(selectedCategoryIdProvider.notifier).state =
                      isSelected ? null : category.id,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.2) : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.textMuted),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textMuted,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ── Channel tile (unchanged) ──────────────────────────────────────────────────

class ChannelTile extends StatelessWidget {
  final XtreamStream stream;
  final VoidCallback onTap;

  const ChannelTile({super.key, required this.stream, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA ||
                event.logicalKey == LogicalKeyboardKey.select)) {
          onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          return InkWell(
            onTap: onTap,
            focusColor: AppColors.primary.withOpacity(0.1),
            child: Container(
              decoration: BoxDecoration(
                border: isFocused
                    ? Border.all(color: AppColors.primary, width: 2)
                    : null,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: stream.logo != null && stream.logo!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              stream.logo!,
                              width: 52,
                              height: 52,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => _placeholderLogo(),
                            ),
                          )
                        : _placeholderLogo(),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(stream.name, style: AppTypography.body,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (stream.epgChannel != null) ...[
                          const SizedBox(height: 2),
                          Text(stream.epgChannel!, style: AppTypography.caption,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.play_arrow, color: AppColors.textMuted),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _placeholderLogo() {
    return Center(
      child: Text(
        stream.name.isNotEmpty ? stream.name[0].toUpperCase() : '?',
        style: AppTypography.h2.copyWith(color: AppColors.primary),
      ),
    );
  }
}
