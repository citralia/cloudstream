import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/channel_entity.dart';
import '../providers/app_providers.dart';
import 'player_screen.dart';

class ChannelListScreen extends ConsumerWidget {
  const ChannelListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channelsAsync = ref.watch(channelsProvider(null));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Live TV'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(channelsProvider(null)),
          ),
        ],
      ),
      body: channelsAsync.when(
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
                Text(
                  'Failed to load channels',
                  style: AppTypography.h3,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  error.toString(),
                  style: AppTypography.caption,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                ElevatedButton(
                  onPressed: () => ref.invalidate(channelsProvider(null)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (channels) {
          if (channels.isEmpty) {
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

          // Group channels by category
          final grouped = <int, List<ChannelEntity>>{};
          for (final ch in channels) {
            grouped.putIfAbsent(ch.categoryId, () => []).add(ch);
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: grouped.length,
            itemBuilder: (context, index) {
              final categoryId = grouped.keys.elementAt(index);
              final categoryChannels = grouped[categoryId]!;
              final categoryName = categoryChannels.first.categoryName;

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
                  ...categoryChannels.map((channel) => ChannelTile(
                    channel: channel,
                    onTap: () => _openPlayer(context, ref, channel),
                  )),
                  const Divider(height: 1),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _openPlayer(BuildContext context, WidgetRef ref, ChannelEntity channel) {
    ref.read(selectedChannelProvider.notifier).state = channel;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlayerScreen(channel: channel)),
    );
  }
}


class ChannelTile extends StatelessWidget {
  final ChannelEntity channel;
  final VoidCallback onTap;

  const ChannelTile({super.key, required this.channel, required this.onTap});

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
              child: channel.logo != null && channel.logo!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        channel.logo!,
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
                    channel.name,
                    style: AppTypography.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    channel.categoryName,
                    style: AppTypography.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Play indicator
            const Icon(Icons.play_arrow, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _placeholderLogo() {
    return Center(
      child: Text(
        channel.name.isNotEmpty ? channel.name[0].toUpperCase() : '?',
        style: AppTypography.h2.copyWith(color: AppColors.primary),
      ),
    );
  }
}
