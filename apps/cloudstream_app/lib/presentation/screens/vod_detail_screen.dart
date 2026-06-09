import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/xtream_client.dart';
import '../../core/theme/app_theme.dart';
import '../providers/app_providers.dart';
import 'player_screen.dart';

/// VOD detail screen — shown before playback.
/// Displays plot, cast, rating, and offers resume or start-from-beginning.
class VodDetailScreen extends ConsumerWidget {
  const VodDetailScreen({super.key, required this.stream, this.autoResume = false});

  final XtreamStream stream;

  /// When true, the player opens immediately with resume-from-saved-position
  /// (or from beginning if no progress is saved). Used by the
  /// "Continue Watching" row on the home screen — one tap → straight into
  /// the video, skipping the intermediate synopsis screen.
  final bool autoResume;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vodInfoAsync = ref.watch(vodInfoProvider(stream.streamId));

    // Auto-resume path: kick off playback on first frame, then render
    // the normal screen behind the player route. The detail screen stays
    // mounted so the user can pop back to the home/continue-watching row.
    if (autoResume) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        _playVod(context, ref, resume: true);
      });
    }

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
            // Cover / poster — prefer the higher-res cover from VOD info, fall back to stream.logo.
            vodInfoAsync.maybeWhen(
              data: (info) {
                final cover = (info.cover != null && info.cover!.isNotEmpty)
                    ? info.cover
                    : stream.logo;
                if (cover != null && cover.isNotEmpty) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      cover,
                      height: 300,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _PlaceholderCover(name: stream.name),
                    ),
                  );
                }
                return _PlaceholderCover(name: stream.name);
              },
              orElse: () {
                if (stream.logo != null && stream.logo!.isNotEmpty) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      stream.logo!,
                      height: 300,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _PlaceholderCover(name: stream.name),
                    ),
                  );
                }
                return _PlaceholderCover(name: stream.name);
              },
            ),

            const SizedBox(height: AppSpacing.lg),

            // Title
            Text(stream.name, style: AppTypography.h1),

            const SizedBox(height: AppSpacing.sm),

            // Metadata row — show real chips from VOD info when available.
            _MetadataRow(vodInfoAsync: vodInfoAsync),

            const SizedBox(height: AppSpacing.lg),

            // Synopsis — real plot from VOD info, loading shimmer, or fallback.
            _Synopsis(vodInfoAsync: vodInfoAsync),

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

/// Metadata chips row — shows rating, duration, release year when the VOD
/// info call has returned; otherwise shows just the "VOD" badge.
class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.vodInfoAsync});

  final AsyncValue<XtreamVodInfo> vodInfoAsync;

  @override
  Widget build(BuildContext context) {
    return vodInfoAsync.maybeWhen(
      data: (info) {
        final chips = <Widget>[];
        // Rating — only show if numeric and > 0.
        final rating = double.tryParse(info.rating ?? '');
        if (rating != null && rating > 0) {
          chips.add(_MetaChip(icon: Icons.star, label: rating.toStringAsFixed(1)));
        }
        // Duration — "1h 45m" or "45m" from raw "105 min" style.
        if (info.duration != null && info.duration!.isNotEmpty) {
          final label = _formatDuration(info.duration!);
          if (label.isNotEmpty) {
            chips.add(_MetaChip(icon: Icons.schedule, label: label));
          }
        }
        // Release year — extract 4-digit year from releaseDate (typically "2023-05-12" or "2023").
        if (info.releaseDate != null && info.releaseDate!.isNotEmpty) {
          final year = _extractYear(info.releaseDate!);
          if (year != null) chips.add(_MetaChip(icon: Icons.calendar_today, label: year));
        }
        // Director — only if present.
        if (info.director != null && info.director!.isNotEmpty) {
          chips.add(_MetaChip(icon: Icons.person, label: info.director!));
        }
        // Always show the VOD tag at the front.
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          children: [
            const _MetaChip(icon: Icons.movie, label: 'VOD'),
            ...chips,
          ],
        );
      },
      orElse: () => const Wrap(
        spacing: AppSpacing.md,
        children: [_MetaChip(icon: Icons.movie, label: 'VOD')],
      ),
    );
  }

  static String _formatDuration(String raw) {
    // Common Xtream formats: "105 min", "1h 45m", "1:45:00", "5400" (seconds).
    final minMatch = RegExp(r'(\d+)\s*min').firstMatch(raw);
    if (minMatch != null) {
      final total = int.tryParse(minMatch.group(1) ?? '') ?? 0;
      if (total <= 0) return '';
      final h = total ~/ 60;
      final m = total % 60;
      return h > 0 ? '${h}h ${m}m' : '${m}m';
    }
    final hmsMatch = RegExp(r'(\d+):(\d+)(?::(\d+))?').firstMatch(raw);
    if (hmsMatch != null) {
      final h = int.tryParse(hmsMatch.group(1) ?? '') ?? 0;
      final m = int.tryParse(hmsMatch.group(2) ?? '') ?? 0;
      if (h == 0 && m == 0) return '';
      return h > 0 ? '${h}h ${m}m' : '${m}m';
    }
    // Pure seconds: "5400".
    final secs = int.tryParse(raw.trim());
    if (secs != null && secs > 60) {
      final h = secs ~/ 3600;
      final m = (secs % 3600) ~/ 60;
      return h > 0 ? '${h}h ${m}m' : '${m}m';
    }
    return raw;
  }

  static String? _extractYear(String raw) {
    final m = RegExp(r'(\d{4})').firstMatch(raw);
    return m?.group(1);
  }
}

/// Synopsis block — renders the real plot, a loading shimmer, or a fallback.
class _Synopsis extends StatelessWidget {
  const _Synopsis({required this.vodInfoAsync});

  final AsyncValue<XtreamVodInfo> vodInfoAsync;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Synopsis', style: AppTypography.h3),
        const SizedBox(height: AppSpacing.sm),
        vodInfoAsync.when(
          data: (info) {
            final plot = info.plot?.trim() ?? '';
            if (plot.isNotEmpty) {
              return Text(plot, style: AppTypography.body);
            }
            return Text(
              'No synopsis available.',
              style: AppTypography.caption.copyWith(
                color: AppColors.textMuted,
                fontStyle: FontStyle.italic,
              ),
            );
          },
          loading: () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(4, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                height: 12,
                width: i == 3 ? 180 : double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            )),
          ),
          error: (_, __) => Text(
            'Could not load details — tap play to start watching.',
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
        ),
        if (vodInfoAsync.valueOrNull?.cast != null &&
            vodInfoAsync.valueOrNull!.cast!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('Cast', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.sm),
          Text(
            vodInfoAsync.valueOrNull!.cast!.trim(),
            style: AppTypography.body,
          ),
        ],
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
