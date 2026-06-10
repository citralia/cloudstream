import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/network/xtream_client.dart';
import '../../core/storage/watch_progress_store.dart';
import '../../core/storage/channel_sort_store.dart';
import '../providers/app_providers.dart';
import '../providers/player_controller_notifier.dart';
import '../widgets/quick_channel_overlay.dart';
import 'player_screen.dart';
import 'series_detail_screen.dart';
import 'vod_detail_screen.dart';

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

  /// V18: long-press a channel tile → action sheet with "Hide" / "Unhide".
  /// Hides are persisted via [ProfileStore.addHidden] and the
  /// [activeProfileHiddenProvider] is invalidated so the channel list
  /// rebuilds without the row. A snackbar with an UNDO action restores
  /// the visibility. Hidden channels are otherwise filtered out of the
  /// default view and accessible via the "Hidden" filter chip.
  Future<void> _openChannelActions(
    BuildContext context,
    WidgetRef ref,
    XtreamStream stream,
  ) async {
    final isHidden =
        ref.read(activeProfileHiddenProvider).contains(stream.streamId);
    final messenger = ScaffoldMessenger.of(context);
    final action = await showModalBottomSheet<_ChannelAction>(
      context: context,
      backgroundColor: context.appColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
                child: Text(
                  stream.name,
                  style: context.appTypography.h3,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  isHidden ? Icons.visibility : Icons.visibility_off,
                  color: context.appColors.primary,
                ),
                title: Text(isHidden ? 'Unhide channel' : 'Hide channel',
                    style: context.appTypography.body),
                onTap: () => Navigator.of(sheetContext).pop(
                    isHidden ? _ChannelAction.unhide : _ChannelAction.hide),
              ),
            ],
          ),
        );
      },
    );
    if (action == null) return;
    if (!context.mounted) return;

    if (action == _ChannelAction.hide) {
      await toggleHidden(ref, stream.streamId);
      // Switch out of hiddenOnly if the user hides the last visible
      // channel — avoids an empty list confusing the user. No-op when
      // the user wasn't viewing hidden-only.
      if (ref.read(hiddenOnlyProvider)) {
        ref.read(hiddenOnlyProvider.notifier).state = false;
      }
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Hidden — ${stream.name}'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () => toggleHidden(ref, stream.streamId),
          ),
        ),
      );
    } else {
      // Unhide — silent (the user just opened the action sheet on a
      // channel they already have access to, so the row is back the
      // moment they tap "Unhide"). Still a snackbar confirmation
      // because the row won't reappear until they leave hiddenOnly.
      await toggleHidden(ref, stream.streamId);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Unhidden — ${stream.name}'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// Open the sort-mode bottom sheet. The sheet lets the user pick
  /// between default (Xtream server order), name (A–Z), and number
  /// (provider-supplied channel number, fallback streamId). The
  /// choice is written through [channelSortProvider] — which the
  /// `filteredLiveStreamsProvider` watches — and persisted to
  /// [SharedPreferences] via [ChannelSortStore] so the choice
  /// survives across launches.
  void _openSortSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.appColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return _SortModeSheet(
          current: ref.read(channelSortProvider),
          onSelected: (mode) {
            ref.read(channelSortProvider.notifier).state = mode;
            // Persist so the choice survives a relaunch.
            ref.read(channelSortStoreProvider).save(mode);
            // Invalidate the filtered streams so the UI re-runs the
            // sort against the cached live-streams future.
            ref.invalidate(filteredLiveStreamsProvider);
            Navigator.of(sheetContext).pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCategoryId = ref.watch(selectedCategoryIdProvider);
    final streamsAsync = ref.watch(filteredLiveStreamsProvider);
    final playerState = ref.watch(playerControllerProvider);
    final recentChannels = ref.watch(recentChannelsProvider);
    final overlayVisible = ref.watch(quickSwitcherOverlayVisibleProvider);

    return Scaffold(
      backgroundColor: context.appColors.background,
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
            icon: const Icon(Icons.sort),
            tooltip: 'Sort channels',
            onPressed: _openSortSheet,
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
              // Most Watched row — top N most-played live channels for
              // the active profile, sorted by play count desc. Hidden
              // when no channels have been played yet. Only visible on
              // the "All" view (no category selected) so it doesn't
              // compete with the filtered channel list inside a single
              // category. Positioned above Continue Watching because
              // it's a stronger personalisation signal.
              if (selectedCategoryId == null) const _MostWatchedRow(),
              // Continue Watching row — shows up to 8 most-recently-played
              // VOD/series items with saved watch progress. Hidden when
              // nothing has been played yet. Only visible on the "All"
              // view (no category selected) so it doesn't compete with
              // the filtered channel list inside a single category.
              if (selectedCategoryId == null) const _ContinueWatchingRow(),
              const CategoryFilterChips(),
              Expanded(
                child: streamsAsync.when(
                  loading: () => Center(
                    child: CircularProgressIndicator(color: context.appColors.primary),
                  ),
                  error: (error, stack) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, color: context.appColors.error, size: 48),
                          const SizedBox(height: AppSpacing.lg),
                          Text('Failed to load channels', style: context.appTypography.h3),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            error.toString(),
                            style: context.appTypography.caption,
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
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.live_tv_outlined, color: context.appColors.textMuted, size: 64),
                            SizedBox(height: AppSpacing.lg),
                            Text('No channels found', style: context.appTypography.h3),
                            SizedBox(height: AppSpacing.sm),
                            Text(
                              'Check your Xtream credentials\nor refresh to try again.',
                              style: context.appTypography.caption,
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
                        onLongPress: (stream) => _openChannelActions(context, ref, stream),
                      );
                    } else {
                      return _GroupedChannelList(
                        streams: streams,
                        onTap: (stream) => _openPlayer(context, ref, stream),
                        onLongPress: (stream) => _openChannelActions(context, ref, stream),
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
            color: context.appColors.surfaceElevated,
            border: Border(top: BorderSide(color: context.appColors.textMuted, width: 0.5)),
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
                    color: context.appColors.surface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: state.currentStream?.logo != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            state.currentStream!.logo!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => _placeholder(context),
                          ),
                        )
                      : _placeholder(context),
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
                        style: context.appTypography.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _statusText,
                        style: context.appTypography.caption.copyWith(
                          color: _statusColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                // Status indicator
                SizedBox(
                  width: 20,
                  height: 20,
                  child: _statusWidget(context),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: context.appColors.textMuted,
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

  Color _statusColor(BuildContext context) {
    switch (state.status) {
      case PlayerStatus.initialising:
        return context.appColors.textMuted;
      case PlayerStatus.playing:
        return context.appColors.primary;
      case PlayerStatus.error:
        return context.appColors.error;
      case PlayerStatus.idle:
        return context.appColors.textMuted;
    }
  }

  Widget _statusWidget(BuildContext context) {
    switch (state.status) {
      case PlayerStatus.initialising:
        return SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: context.appColors.primary),
        );
      case PlayerStatus.playing:
        return Icon(Icons.play_arrow, color: context.appColors.primary, size: 18);
      case PlayerStatus.error:
        return Icon(Icons.error_outline, color: context.appColors.error, size: 18);
      case PlayerStatus.idle:
        return const SizedBox.shrink();
    }
  }

  Widget _placeholder(BuildContext context) {
    return Center(
      child: Text(
        (state.currentStream?.name.isNotEmpty ?? false)
            ? state.currentStream!.name[0].toUpperCase()
            : '?',
        style: TextStyle(fontSize: 14, color: context.appColors.primary),
      ),
    );
  }
}

// ── Channel list widgets (unchanged) ─────────────────────────────────────────

class _FlatChannelList extends StatelessWidget {
  final List<XtreamStream> streams;
  final void Function(XtreamStream) onTap;
  final void Function(XtreamStream)? onLongPress;

  const _FlatChannelList({
    required this.streams,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100), // above mini player
      itemCount: streams.length,
      itemBuilder: (context, index) => ChannelTile(
        stream: streams[index],
        onTap: () => onTap(streams[index]),
        onLongPress: onLongPress == null ? null : () => onLongPress!(streams[index]),
      ),
    );
  }
}

class _GroupedChannelList extends StatelessWidget {
  final List<XtreamStream> streams;
  final void Function(XtreamStream) onTap;
  final void Function(XtreamStream)? onLongPress;

  const _GroupedChannelList({
    required this.streams,
    required this.onTap,
    this.onLongPress,
  });

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
                style: context.appTypography.h3.copyWith(color: context.appColors.textSecondary),
              ),
            ),
            ...categoryStreams.map((stream) => ChannelTile(
              stream: stream,
              onTap: () => onTap(stream),
              onLongPress: onLongPress == null ? null : () => onLongPress!(stream),
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
    final favouritesOnly = ref.watch(favouritesOnlyProvider);
    final hiddenOnly = ref.watch(hiddenOnlyProvider);

    return SizedBox(
      height: 52,
      child: categoriesAsync.when(
        loading: () => Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: context.appColors.primary),
          ),
        ),
        error: (_, __) => const SizedBox.shrink(),
        data: (categories) {
          if (categories.isEmpty) return const SizedBox.shrink();
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            itemCount: categories.length + 3, // +3: All, ★ Favourites, ⊘ Hidden (V18)
            itemBuilder: (context, index) {
              if (index == 0) {
                return _FilterChip(
                  label: 'All',
                  isSelected: selectedCategoryId == null && !favouritesOnly && !hiddenOnly,
                  onTap: () {
                    ref.read(selectedCategoryIdProvider.notifier).state = null;
                    ref.read(favouritesOnlyProvider.notifier).state = false;
                    ref.read(hiddenOnlyProvider.notifier).state = false;
                  },
                );
              }
              if (index == 1) {
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: _FilterChip(
                    label: '★ Favourites',
                    isSelected: favouritesOnly,
                    onTap: () {
                      ref.read(favouritesOnlyProvider.notifier).state = !favouritesOnly;
                      if (ref.read(favouritesOnlyProvider)) {
                        // Favourites and hidden-only are mutually
                        // exclusive — switching into favourites clears
                        // hidden-only so the user doesn't end up with an
                        // empty intersection of "favourites ∩ hidden".
                        ref.read(hiddenOnlyProvider.notifier).state = false;
                      }
                    },
                  ),
                );
              }
              if (index == 2) {
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: _FilterChip(
                    label: '⊘ Hidden',
                    isSelected: hiddenOnly,
                    onTap: () {
                      ref.read(hiddenOnlyProvider.notifier).state = !hiddenOnly;
                      if (ref.read(hiddenOnlyProvider)) {
                        ref.read(favouritesOnlyProvider.notifier).state = false;
                      }
                    },
                  ),
                );
              }
              final category = categories[index - 3];
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
          color: isSelected ? context.appColors.primary.withOpacity(0.2) : context.appColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? context.appColors.primary : context.appColors.textMuted),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? context.appColors.primary : context.appColors.textMuted,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ── Channel tile (unchanged) ──────────────────────────────────────────────────

class ChannelTile extends ConsumerWidget {
  final XtreamStream stream;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const ChannelTile({
    super.key,
    required this.stream,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favIds = ref.watch(activeProfileFavouritesProvider);
    final isFavourite = favIds.contains(stream.streamId);
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
            onLongPress: onLongPress, // V18: long-press for hide/unhide
            focusColor: context.appColors.primary.withOpacity(0.1),
            child: Container(
              decoration: BoxDecoration(
                border: isFocused
                    ? Border.all(color: context.appColors.primary, width: 2)
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
                      color: context.appColors.surfaceElevated,
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
                              errorBuilder: (_, __, ___) => _placeholderLogo(context),
                            ),
                          )
                        : _placeholderLogo(context),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(stream.name, style: context.appTypography.body,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (stream.epgChannel != null) ...[
                          const SizedBox(height: 2),
                          Text(stream.epgChannel!, style: context.appTypography.caption,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ],
                    ),
                  ),
                  // Favourite toggle — tap does not trigger row play.
                  _FavouriteButton(
                    isFavourite: isFavourite,
                    onToggle: () => toggleFavourite(ref, stream.streamId),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.play_arrow, color: context.appColors.textMuted),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _placeholderLogo(BuildContext context) {
    return Center(
      child: Text(
        stream.name.isNotEmpty ? stream.name[0].toUpperCase() : '?',
        style: context.appTypography.h2.copyWith(color: context.appColors.primary),
      ),
    );
  }
}

/// Star button shown on each channel tile.
/// Tapping it toggles favourite state for the active profile without
/// triggering the row's play action.
class _FavouriteButton extends StatelessWidget {
  final bool isFavourite;
  final VoidCallback onToggle;

  const _FavouriteButton({required this.isFavourite, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        isFavourite ? Icons.star : Icons.star_border,
        color: isFavourite ? context.appColors.accent : context.appColors.textMuted,
      ),
      tooltip: isFavourite ? 'Remove from favourites' : 'Add to favourites',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      onPressed: onToggle,
    );
  }
}

// ── Continue Watching row ─────────────────────────────────────────────────────

/// Horizontal scroll of recently-watched VOD/series items. Pulls data
/// from [continueWatchingProvider] and renders a card per entry with a
/// progress bar, title, and "resume" affordance. Renders nothing while
/// the provider is still loading or has no entries.
///
/// Resumes a Continue Watching card. VOD entries (movies, live) go
/// through [VodDetailScreen] with `autoResume: true`. Series-episode
/// entries (resolved via [SeriesInfoCache]) open
/// [SeriesDetailScreen] with the matched episode pre-selected, the
/// right season focused, and the player auto-started in resume mode.
class _ContinueWatchingRow extends ConsumerWidget {
  const _ContinueWatchingRow();

  static const int _maxCards = 8;

  void _openResume(BuildContext context, WidgetRef ref, ContinueWatchingEntry entry) {
    if (entry.kind == ContinueWatchingKind.seriesEpisode &&
        entry.parentSeries != null &&
        entry.episode != null &&
        entry.parentSeason != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SeriesDetailScreen(
            stream: entry.stream,
            autoResumeEpisode: entry.episode,
            autoResumeSeason: entry.parentSeason!.seasonNumber,
          ),
        ),
      );
      return;
    }
    final stream = entry.stream;
    if (stream.streamType == 'movie' || stream.streamType == 'live') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VodDetailScreen(stream: stream, autoResume: true),
        ),
      );
    }
  }

  /// Long-press a Continue Watching card to remove the entry. The
  /// removal is persisted (clears the watch-progress key in
  /// [WatchProgressStore]) and the [continueWatchingProvider] is
  /// invalidated so the row rebuilds without the entry. A snackbar
  /// with an UNDO action re-saves the same progress and re-invalidates
  /// to restore the card within the snackbar's timeout — standard
  /// streaming-app pattern (Netflix / YouTube / Prime).
  Future<void> _openDismiss(
    BuildContext context,
    WidgetRef ref,
    ContinueWatchingEntry entry,
  ) async {
    final creds = ref.read(activeCredentialsProvider).valueOrNull;
    if (creds == null) return;
    final store = ref.read(watchProgressStoreProvider);
    final progress = entry.progress;
    final streamName = entry.stream.name;
    final streamId = entry.stream.streamId;
    final profileId = creds.name;
    final messenger = ScaffoldMessenger.of(context);

    await store.clearProgress(profileId: profileId, streamId: streamId);
    // Invalidate so the row rebuilds without the entry. The provider
    // is a `FutureProvider` (not autoDispose) — invalidate is the
    // correct way to force a re-fetch.
    ref.invalidate(continueWatchingProvider);

    if (!context.mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Removed from Continue Watching — $streamName'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () async {
            await store.saveProgress(
              profileId: profileId,
              streamId: streamId,
              positionMs: progress.positionMs,
            );
            ref.invalidate(continueWatchingProvider);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(continueWatchingProvider);
    final entries = entriesAsync.maybeWhen(
      data: (list) => list.take(_maxCards).toList(),
      orElse: () => const <ContinueWatchingEntry>[],
    );
    if (entries.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, size: 18, color: context.appColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Text('Continue Watching', style: context.appTypography.h3),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _ContinueWatchingCard(
                  entry: entry,
                  onTap: () => _openResume(context, ref, entry),
                  onLongPress: () => _openDismiss(context, ref, entry),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueWatchingCard extends StatelessWidget {
  final ContinueWatchingEntry entry;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ContinueWatchingCard({
    required this.entry,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final stream = entry.stream;
    final hasLogo = stream.logo != null && stream.logo!.isNotEmpty;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.appColors.divider, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster with progress bar overlay.
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: hasLogo
                      ? Image.network(
                          stream.logo!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _PosterPlaceholder(name: stream.name),
                        )
                      : _PosterPlaceholder(name: stream.name),
                ),
                Positioned(
                  top: AppSpacing.xs,
                  left: AppSpacing.xs,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: context.appColors.primary.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Resume',
                      style: context.appTypography.micro.copyWith(
                        color: context.appColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 3,
                    color: context.appColors.surface.withValues(alpha: 0.5),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _progressFraction(entry.progress),
                      child: Container(color: context.appColors.primary),
                    ),
                  ),
                ),
              ],
            ),
            // Title + saved-time.
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stream.name,
                    style: context.appTypography.body.copyWith(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _savedAgo(entry.progress.updatedAt),
                    style: context.appTypography.micro,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Indeterminate by default — we don't persist the total duration, so
  /// we can't show a real fraction. A small, non-zero fill is enough to
  /// signal "this was started" without claiming a percentage we don't have.
  double _progressFraction(WatchProgress progress) {
    // 25% of the bar width for anything < 5 min in, growing to 75% for
    // 2+ hour sessions. Clamped 0.15–0.75 so the bar is always visible
    // and never claims "almost done" without a real duration source.
    final mins = progress.position.inMinutes;
    if (mins <= 5) return 0.15;
    if (mins >= 120) return 0.75;
    return 0.15 + ((mins - 5) / 115) * 0.60;
  }

  String _savedAgo(DateTime updatedAt) {
    final diff = DateTime.now().difference(updatedAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}

class _PosterPlaceholder extends StatelessWidget {
  final String name;
  const _PosterPlaceholder({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.appColors.surfaceElevated,
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: context.appTypography.h1.copyWith(color: context.appColors.textMuted),
      ),
    );
  }
}

/// "Most Watched" horizontal row — surfaces the live channels the active
/// profile plays most often, sorted by play count desc. Renders nothing
/// while the provider is still loading or has no entries. Tapping a card
/// plays the channel (same path as a regular channel-list tap).
class _MostWatchedRow extends ConsumerWidget {
  const _MostWatchedRow();

  static const int _maxCards = 8;

  void _openStream(BuildContext context, WidgetRef ref, XtreamStream stream) {
    ref.read(selectedStreamProvider.notifier).state = stream;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlayerScreen(stream: stream)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(mostWatchedProvider);
    final entries = entriesAsync.maybeWhen(
      data: (list) => list.take(_maxCards).toList(),
      orElse: () => const <MostWatchedEntry>[],
    );
    if (entries.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, size: 18, color: context.appColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Text('Most Watched', style: context.appTypography.h3),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _MostWatchedCard(
                  entry: entry,
                  onTap: () => _openStream(context, ref, entry.stream),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A single Most Watched card: square channel logo (or first-letter
/// placeholder) with the play count badge and channel name. Tapping
/// the card plays the channel.
class _MostWatchedCard extends StatelessWidget {
  final MostWatchedEntry entry;
  final VoidCallback onTap;

  const _MostWatchedCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final stream = entry.stream;
    return SizedBox(
      width: 96,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 96,
                    height: 64,
                    child: stream.logo != null && stream.logo!.isNotEmpty
                        ? Image.network(
                            stream.logo!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _PosterPlaceholder(name: stream.name),
                          )
                        : _PosterPlaceholder(name: stream.name),
                  ),
                ),
                Positioned(
                  top: AppSpacing.xs,
                  right: AppSpacing.xs,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: context.appColors.accent.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${entry.count}×',
                      style: context.appTypography.micro.copyWith(
                        color: context.appColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              stream.name,
              style: context.appTypography.body.copyWith(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sort mode picker ─────────────────────────────────────────────────────────

/// Modal bottom sheet for picking a live-channel sort mode. Renders
/// the [ChannelSortMode] options as a tappable radio list. The
/// "selected" indicator mirrors the current [channelSortProvider]
/// value, so opening the sheet and dismissing it is a no-op.
class _SortModeSheet extends StatelessWidget {
  const _SortModeSheet({required this.current, required this.onSelected});

  final ChannelSortMode current;
  final void Function(ChannelSortMode) onSelected;

  static const _options = <(ChannelSortMode, String, String, IconData)>[
    (
      ChannelSortMode.defaultOrder,
      'Default',
      'Channels in the order your provider sends them',
      Icons.list,
    ),
    (
      ChannelSortMode.name,
      'Name (A–Z)',
      'Alphabetical by channel name',
      Icons.sort_by_alpha,
    ),
    (
      ChannelSortMode.number,
      'Number',
      'Provider channel number; channels without a number go to the bottom',
      Icons.numbers,
    ),
    (
      ChannelSortMode.mostWatched,
      'Most Watched',
      'Your most-played channels first; channels you have never played go to the bottom',
      Icons.trending_up,
    ),
    (
      ChannelSortMode.recentlyPlayed,
      'Recently Played',
      'Most-recently-played channels first; channels you have never played go to the bottom',
      Icons.history,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, AppSpacing.md,
              ),
              child: Text(
                'Sort channels by',
                style: context.appTypography.h3,
              ),
            ),
            for (final opt in _options)
              _SortModeRow(
                icon: opt.$4,
                title: opt.$2,
                subtitle: opt.$3,
                isSelected: current == opt.$1,
                onTap: () => onSelected(opt.$1),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

class _SortModeRow extends StatelessWidget {
  const _SortModeRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? context.appColors.primary : context.appColors.textSecondary,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.appTypography.body.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? context.appColors.primary
                          : context.appColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: context.appTypography.caption.copyWith(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? context.appColors.primary : context.appColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

/// V18: actions exposed by the long-press channel sheet.
enum _ChannelAction { hide, unhide }
