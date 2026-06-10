import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/theme/app_theme.dart';
import '../../core/storage/watch_progress_store.dart';
import 'vod_detail_screen.dart';

class VodScreen extends ConsumerWidget {
  const VodScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(vodCategoriesProvider);
    final streamsAsync = ref.watch(filteredVodStreamsProvider);
    final selectedCategoryId = ref.watch(selectedVodCategoryIdProvider);
    final colors = context.appColors;
    final typo = context.appTypography;

    return Scaffold(
      backgroundColor: colors.background,
      body: Column(
        children: [
          // Category filter chips.
          SizedBox(
            height: 52,
            child: categoriesAsync.when(
              data: (categories) => ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  _CategoryChip(
                    label: 'All',
                    isSelected: selectedCategoryId == null,
                    onTap: () => ref.read(selectedVodCategoryIdProvider.notifier).state = null,
                  ),
                  ...categories.map((cat) => _CategoryChip(
                    label: cat.name,
                    isSelected: selectedCategoryId == cat.id,
                    onTap: () => ref.read(selectedVodCategoryIdProvider.notifier).state = cat.id,
                  )),
                ],
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
          Divider(color: colors.divider, height: 1),
          // V21: Continue Watching row — VOD entries only. Mirrors the
          // channel-list home row, narrowed to the VOD tab's audience
          // (movies with saved progress). Renders nothing when no
          // entries exist or when a category is selected (full grid
          // already narrows; adding the row on top would feel
          // redundant).
          if (selectedCategoryId == null) const _ContinueWatchingRow(),
          // VOD grid.
          Expanded(
            child: streamsAsync.when(
              data: (streams) {
                if (streams.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.movie_outlined, color: colors.textMuted, size: 64),
                        const SizedBox(height: 16),
                        Text('No VOD available', style: typo.h3),
                      ],
                    ),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    childAspectRatio: 2 / 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: streams.length,
                  itemBuilder: (context, index) {
                    final stream = streams[index];
                    return _VodCard(
                      stream: stream,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => VodDetailScreen(stream: stream),
                          ),
                        );
                      },
                    );
                  },
                );
              },
              loading: () => Center(child: CircularProgressIndicator(color: colors.primary)),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: colors.error, size: 48),
                    const SizedBox(height: 16),
                    Text('Failed to load VOD: $e', style: typo.body),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? colors.primary : colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? colors.primary : colors.divider,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : colors.textMuted,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class _VodCard extends StatelessWidget {
  final dynamic stream; // XtreamStream
  final VoidCallback onTap;

  const _VodCard({required this.stream, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.divider, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: stream.logo != null && stream.logo!.isNotEmpty
                  ? Image.network(
                      stream.logo!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _PlaceholderPoster(name: stream.name),
                    )
                  : _PlaceholderPoster(name: stream.name),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              color: colors.surface,
              child: Text(
                stream.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderPoster extends StatelessWidget {
  final String name;

  const _PlaceholderPoster({required this.name});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      color: colors.surfaceElevated,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            color: colors.textMuted,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// ── V21: Continue Watching row (VOD-only) ───────────────────────────────

/// V21: horizontal scroll of recently-watched VOD items on the VOD home
/// tab. Pulls data from [continueWatchingVodProvider] (which itself
/// filters [continueWatchingProvider] to `ContinueWatchingKind.vod`
/// entries) and renders a card per entry with a poster, progress bar,
/// title, and "Resume" affordance. Renders nothing while the provider
/// is still loading or has no entries.
///
/// Pattern mirrors the channel-list `_ContinueWatchingRow` (V03 + V17),
/// scoped to the VOD tab's audience: the same data, the same card
/// shape, the same long-press-to-remove + UNDO affordance — a user
/// who starts a movie on the VOD tab and switches to the Series tab
/// expects to come back to a "resume" affordance on the VOD tab.
///
/// Long-press behaviour is also a copy of the channel-list version: a
/// `clearProgress` + provider invalidate removes the entry, and a
/// snackbar with an UNDO action re-saves the same progress. The data
/// is the same `WatchProgressStore` key, so an UNDO from the VOD tab
/// would also re-surface the card on the channel-list and Series tabs
/// — by design, all three Continue Watching rows share the same data.
class _ContinueWatchingRow extends ConsumerWidget {
  const _ContinueWatchingRow();

  static const int _maxCards = 8;

  void _openResume(BuildContext context, ContinueWatchingEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VodDetailScreen(stream: entry.stream, autoResume: true),
      ),
    );
  }

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
    // Invalidate the source provider so all three rows (VOD, Series,
    // channel list) rebuild without the entry. The filter providers
    // (`continueWatchingVodProvider`, `continueWatchingSeriesProvider`)
    // re-read from `continueWatchingProvider` so a single invalidate
    // cascades through them.
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
    final entriesAsync = ref.watch(continueWatchingVodProvider);
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
                  onTap: () => _openResume(context, entry),
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
  /// signal "this was started" without claiming a percentage we don't
  /// have. 25% of the bar width for anything < 5 min in, growing to
  /// 75% for 2+ hour sessions. Clamped 0.15–0.75 so the bar is always
  /// visible and never claims "almost done" without a real duration
  /// source. Same trade-off the channel-list row makes.
  double _progressFraction(WatchProgress progress) {
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
