import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/xtream_client.dart';
import '../providers/app_providers.dart';
import 'player_screen.dart';

class ChannelListScreen extends ConsumerWidget {
  const ChannelListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategoryId = ref.watch(selectedCategoryIdProvider);
    final streamsAsync = ref.watch(filteredLiveStreamsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Live TV'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(liveStreamsProvider);
              ref.invalidate(filteredLiveStreamsProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Category filter chips
          const CategoryFilterChips(),
          // Channel list
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

                // When filtered: show flat list by category. When not filtered: group by category.
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
    );
  }

  void _openPlayer(BuildContext context, WidgetRef ref, XtreamStream stream) {
    ref.read(selectedStreamProvider.notifier).state = stream;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlayerScreen(stream: stream)),
    );
  }
}

/// Flat list when a category is selected.
class _FlatChannelList extends StatelessWidget {
  final List<XtreamStream> streams;
  final void Function(XtreamStream) onTap;

  const _FlatChannelList({required this.streams, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: streams.length,
      itemBuilder: (context, index) => ChannelTile(
        stream: streams[index],
        onTap: () => onTap(streams[index]),
      ),
    );
  }
}

/// Grouped list when no category is selected (shows all channels grouped by category).
class _GroupedChannelList extends StatelessWidget {
  final List<XtreamStream> streams;
  final void Function(XtreamStream) onTap;

  const _GroupedChannelList({required this.streams, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Group by category_id
    final grouped = <int, List<XtreamStream>>{};
    for (final stream in streams) {
      grouped.putIfAbsent(stream.categoryId, () => []).add(stream);
    }

    final sortedKeys = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final categoryId = sortedKeys[index];
        final categoryStreams = grouped[categoryId]!;
        final categoryName = categoryStreams.first.name; // fallback

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm,
              ),
              child: Text(
                categoryName.isNotEmpty ? categoryName : 'All Channels',
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

/// Category filter chip bar.
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
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            itemCount: categories.length + 1, // +1 for "All" chip
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
                  onTap: () {
                    ref.read(selectedCategoryIdProvider.notifier).state =
                        isSelected ? null : category.id;
                  },
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

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.textMuted,
          ),
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

/// Single channel tile.
class ChannelTile extends StatelessWidget {
  final XtreamStream stream;
  final VoidCallback onTap;

  const ChannelTile({super.key, required this.stream, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            // Channel logo
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
            // Channel name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stream.name,
                    style: AppTypography.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (stream.epgChannel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      stream.epgChannel!,
                      style: AppTypography.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.play_arrow, color: AppColors.textMuted),
          ],
        ),
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
