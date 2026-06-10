import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../../core/theme/theme_extensions.dart';
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
