import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/xtream_client.dart';
import '../../core/theme/theme_extensions.dart';
import '../providers/app_providers.dart';
import 'series_detail_screen.dart';

/// Series browser — a category-filtered grid of series.
/// Mirrors [VodScreen] for visual consistency.
class SeriesScreen extends ConsumerWidget {
  const SeriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(seriesCategoriesProvider);
    final streamsAsync = ref.watch(filteredSeriesStreamsProvider);
    final selectedCategoryId = ref.watch(selectedSeriesCategoryIdProvider);
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
                    onTap: () =>
                        ref.read(selectedSeriesCategoryIdProvider.notifier).state = null,
                  ),
                  ...categories.map((cat) => _CategoryChip(
                        label: cat.name,
                        isSelected: selectedCategoryId == cat.id,
                        onTap: () => ref
                            .read(selectedSeriesCategoryIdProvider.notifier)
                            .state = cat.id,
                      )),
                ],
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
          Divider(color: colors.divider, height: 1),
          // Series grid.
          Expanded(
            child: streamsAsync.when(
              data: (streams) {
                if (streams.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.tv_outlined, color: colors.textMuted, size: 64),
                        const SizedBox(height: 16),
                        Text('No series available', style: typo.h3),
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
                    return _SeriesCard(
                      stream: stream,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SeriesDetailScreen(stream: stream),
                          ),
                        );
                      },
                    );
                  },
                );
              },
              loading: () =>
                  Center(child: CircularProgressIndicator(color: colors.primary)),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: colors.error, size: 48),
                    const SizedBox(height: 16),
                    Text('Failed to load series: $e', style: typo.body),
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

class _SeriesCard extends StatelessWidget {
  final XtreamStream stream;
  final VoidCallback onTap;

  const _SeriesCard({required this.stream, required this.onTap});

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
