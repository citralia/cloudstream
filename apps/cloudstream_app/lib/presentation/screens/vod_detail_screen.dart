import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/xtream_client.dart';
import '../../core/theme/app_theme.dart';
import '../providers/app_providers.dart';
import 'player_screen.dart';

/// VOD detail screen — shown before playback.
/// Displays plot, cast, rating, and offers resume or start-from-beginning.
class VodDetailScreen extends ConsumerWidget {
  const VodDetailScreen({super.key, required this.stream});

  final XtreamStream stream;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(stream.name, style: AppTypography.h3),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover / poster
            if (stream.logo != null && stream.logo!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  stream.logo!,
                  height: 300,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _PlaceholderCover(name: stream.name),
                ),
              )
            else
              _PlaceholderCover(name: stream.name),

            const SizedBox(height: AppSpacing.lg),

            // Title
            Text(stream.name, style: AppTypography.h1),

            const SizedBox(height: AppSpacing.sm),

            // Metadata row
            const Wrap(
              spacing: AppSpacing.md,
              children: [
                _MetaChip(icon: Icons.movie, label: 'VOD'),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // Synopsis (placeholder)
            Text('Synopsis', style: AppTypography.h3),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Tap play to start watching.',
              style: AppTypography.body,
            ),

            const SizedBox(height: AppSpacing.xl),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: _WatchButton(
                    label: 'Resume',
                    icon: Icons.play_arrow,
                    isPrimary: true,
                    onTap: () => _playVod(context, ref, resume: true),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _WatchButton(
                    label: 'Start Over',
                    icon: Icons.replay,
                    isPrimary: false,
                    onTap: () => _playVod(context, ref, resume: false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _playVod(BuildContext context, WidgetRef ref, {required bool resume}) async {
    final url = ref.read(vodStreamUrlProvider(stream.streamId));

    Duration? startPosition;
    if (resume) {
      try {
        final creds = await ref.read(credentialsStoreProvider).loadActiveConnection();
        if (creds != null) {
          final store = ref.read(watchProgressStoreProvider);
          final progress = store.getProgress(
            profileId: creds.name,
            streamId: stream.streamId,
          );
          if (progress != null) {
            startPosition = progress.position;
          }
        }
      } catch (_) {
        // Non-fatal — start from beginning
      }
    }

    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          stream: stream,
          streamUrl: url,
          startPosition: startPosition,
        ),
      ),
    );
  }
}

class _PlaceholderCover extends StatelessWidget {
  const _PlaceholderCover({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 64,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(label, style: AppTypography.caption),
      ],
    );
  }
}

class _WatchButton extends StatelessWidget {
  const _WatchButton({
    required this.label,
    required this.icon,
    required this.isPrimary,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: isPrimary ? null : Border.all(color: AppColors.divider),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isPrimary ? Colors.white : AppColors.textPrimary,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: TextStyle(
                color: isPrimary ? Colors.white : AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
