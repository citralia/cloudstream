import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/xtream_client.dart';
import '../../core/theme/app_theme.dart';
import '../providers/app_providers.dart';
import 'player_screen.dart';

/// Series detail screen — shown when a series card is tapped.
/// Displays cover, plot, season selector, and the episode list for the
/// selected season. Tapping an episode opens the player.
class SeriesDetailScreen extends ConsumerStatefulWidget {
  const SeriesDetailScreen({super.key, required this.stream});

  final XtreamStream stream;

  @override
  ConsumerState<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends ConsumerState<SeriesDetailScreen> {
  int? _selectedSeason;

  @override
  Widget build(BuildContext context) {
    final seriesInfoAsync = ref.watch(seriesInfoProvider(widget.stream.streamId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.stream.name, style: AppTypography.h3, overflow: TextOverflow.ellipsis),
      ),
      body: seriesInfoAsync.when(
        data: (info) {
          // Default to the first season when data arrives.
          if (_selectedSeason == null && info.seasons.isNotEmpty) {
            _selectedSeason = info.seasons.first.seasonNumber;
          }
          return _Body(
            seriesInfo: info,
            stream: widget.stream,
            selectedSeason: _selectedSeason ?? 1,
            onSeasonSelected: (n) => setState(() => _selectedSeason = n),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                const SizedBox(height: AppSpacing.md),
                Text('Failed to load series: $e',
                    style: AppTypography.body, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.seriesInfo,
    required this.stream,
    required this.selectedSeason,
    required this.onSeasonSelected,
  });

  final XtreamSeriesInfo seriesInfo;
  final XtreamStream stream;
  final int selectedSeason;
  final ValueChanged<int> onSeasonSelected;

  XtreamSeason? _findSeason(int n) {
    for (final s in seriesInfo.seasons) {
      if (s.seasonNumber == n) return s;
    }
    return seriesInfo.seasons.isNotEmpty ? seriesInfo.seasons.first : null;
  }

  void _playEpisode(BuildContext context, WidgetRef ref, XtreamEpisode episode) {
    // Build the Xtream series stream URL for this specific episode.
    // We synthesise an XtreamStream so PlayerScreen receives a stream reference
    // matching the existing API — streamId is the episode's stream_id, which
    // is what buildSeriesStreamUrl consumes.
    final url = ref.read(seriesStreamUrlProvider(episode.streamId));
    final episodeStream = XtreamStream(
      streamId: episode.streamId,
      name: 'S${selectedSeason.toString().padLeft(2, '0')}E${episode.episodeNumber.toString().padLeft(2, '0')} — ${episode.title}',
      logo: stream.logo,
      categoryId: stream.categoryId,
      streamType: 'series',
      epgChannel: stream.epgChannel,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          stream: episodeStream,
          streamUrl: url,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSeason = _findSeason(selectedSeason);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover.
          _Cover(stream: stream, cover: seriesInfo.cover, name: seriesInfo.name),
          const SizedBox(height: AppSpacing.lg),

          // Title.
          Text(seriesInfo.name.isNotEmpty ? seriesInfo.name : stream.name,
              style: AppTypography.h1),

          const SizedBox(height: AppSpacing.sm),

          // Metadata row.
          _MetadataRow(info: seriesInfo),

          const SizedBox(height: AppSpacing.lg),

          // Plot.
          if (seriesInfo.plot != null && seriesInfo.plot!.trim().isNotEmpty) ...[
            Text('Plot', style: AppTypography.h3),
            const SizedBox(height: AppSpacing.sm),
            Text(seriesInfo.plot!, style: AppTypography.body),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Cast (sometimes returned by Xtream for series).
          if (seriesInfo.cast != null && seriesInfo.cast!.trim().isNotEmpty) ...[
            Text('Cast', style: AppTypography.h3),
            const SizedBox(height: AppSpacing.sm),
            Text(seriesInfo.cast!, style: AppTypography.body),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Season selector.
          if (seriesInfo.seasons.length > 1) ...[
            Text('Seasons', style: AppTypography.h3),
            const SizedBox(height: AppSpacing.sm),
            _SeasonChips(
              seasons: seriesInfo.seasons,
              selected: selectedSeason,
              onTap: onSeasonSelected,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Episode list.
          Text(
            seriesInfo.seasons.length > 1
                ? 'Season $selectedSeason'
                : 'Episodes',
            style: AppTypography.h3,
          ),
          const SizedBox(height: AppSpacing.sm),
          _EpisodeList(
            season: currentSeason,
            onPlay: (episode) => _playEpisode(context, ref, episode),
          ),
        ],
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.stream, required this.cover, required this.name});

  final XtreamStream stream;
  final String? cover;
  final String name;

  @override
  Widget build(BuildContext context) {
    final coverUrl = (cover != null && cover!.isNotEmpty) ? cover : stream.logo;
    if (coverUrl != null && coverUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          coverUrl,
          height: 300,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _PlaceholderCover(name: name),
        ),
      );
    }
    return _PlaceholderCover(name: name);
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

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.info});

  final XtreamSeriesInfo info;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    final rating = double.tryParse(info.rating ?? '');
    if (rating != null && rating > 0) {
      chips.add(_MetaChip(icon: Icons.star, label: rating.toStringAsFixed(1)));
    }
    if (info.releaseDate != null && info.releaseDate!.isNotEmpty) {
      final m = RegExp(r'(\d{4})').firstMatch(info.releaseDate!);
      if (m != null) chips.add(_MetaChip(icon: Icons.calendar_today, label: m.group(1)!));
    }
    if (info.director != null && info.director!.isNotEmpty) {
      chips.add(_MetaChip(icon: Icons.person, label: info.director!));
    }
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      children: [
        const _MetaChip(icon: Icons.tv, label: 'Series'),
        ...chips,
      ],
    );
  }
}

class _SeasonChips extends StatelessWidget {
  const _SeasonChips({
    required this.seasons,
    required this.selected,
    required this.onTap,
  });

  final List<XtreamSeason> seasons;
  final int selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: seasons.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final s = seasons[i];
          final isSelected = s.seasonNumber == selected;
          return GestureDetector(
            onTap: () => onTap(s.seasonNumber),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.divider,
                ),
              ),
              child: Text(
                'Season ${s.seasonNumber}',
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EpisodeList extends StatelessWidget {
  const _EpisodeList({required this.season, required this.onPlay});

  final XtreamSeason? season;
  final void Function(XtreamEpisode) onPlay;

  @override
  Widget build(BuildContext context) {
    final episodes = season?.episodes ?? const [];
    if (episodes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text(
          'No episodes available for this season.',
          style: AppTypography.caption.copyWith(color: AppColors.textMuted),
        ),
      );
    }
    return Column(
      children: episodes
          .map((e) => _EpisodeRow(episode: e, onTap: () => onPlay(e)))
          .toList(),
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({required this.episode, required this.onTap});

  final XtreamEpisode episode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider, width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Center(
                  child: Icon(Icons.play_arrow, color: AppColors.primary, size: 22),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Episode ${episode.episodeNumber}',
                      style: AppTypography.micro.copyWith(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      episode.title.isNotEmpty
                          ? episode.title
                          : 'Episode ${episode.episodeNumber}',
                      style: AppTypography.body.copyWith(fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (episode.description != null &&
                        episode.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        episode.description!,
                        style: AppTypography.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (episode.duration > 0) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(_formatDuration(episode.duration),
                    style: AppTypography.micro.copyWith(color: AppColors.textMuted)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDuration(int seconds) {
    if (seconds <= 0) return '';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}
