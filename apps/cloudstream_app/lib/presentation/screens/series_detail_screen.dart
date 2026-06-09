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
  const SeriesDetailScreen({
    super.key,
    required this.stream,
    this.autoResumeEpisode,
    this.autoResumeSeason,
  });

  final XtreamStream stream;

  /// If set, the player will auto-open for this episode on first
  /// frame, with `startPosition` seeded from the saved watch progress.
  /// Used by the Continue Watching row to deep-link straight into a
  /// series episode resume. The corresponding season is selected
  /// before playback fires.
  final XtreamEpisode? autoResumeEpisode;

  /// Season number to select when [autoResumeEpisode] is provided.
  /// Defaults to the first available season if null.
  final int? autoResumeSeason;

  @override
  ConsumerState<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends ConsumerState<SeriesDetailScreen> {
  int? _selectedSeason;

  /// Episode the caller wants to auto-play on first frame (e.g. from
  /// the Continue Watching row). Set from `widget.autoResumeEpisode`
  /// before the build runs so the post-frame callback can use it.
  XtreamEpisode? _autoPlayEpisode;

  @override
  void initState() {
    super.initState();
    final auto = widget.autoResumeEpisode;
    if (auto != null) {
      _autoPlayEpisode = auto;
      _selectedSeason = widget.autoResumeSeason ?? 1;
    }
  }

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
            // Deep-link params — when set, _Body fires the auto-play
            // in a post-frame callback. One-shot: consumed (cleared)
            // after the first build so navigating back/forward doesn't
            // re-fire playback.
            autoResumeEpisode: _autoPlayEpisode,
            onAutoResumeConsumed: () => setState(() => _autoPlayEpisode = null),
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

class _Body extends ConsumerStatefulWidget {
  const _Body({
    required this.seriesInfo,
    required this.stream,
    required this.selectedSeason,
    required this.onSeasonSelected,
    this.autoResumeEpisode,
    this.onAutoResumeConsumed,
  });

  final XtreamSeriesInfo seriesInfo;
  final XtreamStream stream;
  final int selectedSeason;
  final ValueChanged<int> onSeasonSelected;
  final XtreamEpisode? autoResumeEpisode;
  final VoidCallback? onAutoResumeConsumed;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  XtreamSeason? _findSeason(int n) {
    for (final s in widget.seriesInfo.seasons) {
      if (s.seasonNumber == n) return s;
    }
    return widget.seriesInfo.seasons.isNotEmpty ? widget.seriesInfo.seasons.first : null;
  }

  @override
  void initState() {
    super.initState();
    // Schedule the deep-link auto-resume on the first frame so the
    // body is fully laid out before we try to navigate. We do this
    // in initState (not build) so it only fires once per screen
    // open, not on every rebuild while waiting for seriesInfoAsync.
    final ep = widget.autoResumeEpisode;
    if (ep != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _playEpisode(ep, resume: true);
        widget.onAutoResumeConsumed?.call();
      });
    }
  }

  void _playEpisode(XtreamEpisode episode, {bool resume = false}) async {
    // Build the Xtream series stream URL for this specific episode.
    // We synthesise an XtreamStream so PlayerScreen receives a stream reference
    // matching the existing API — streamId is the episode's stream_id, which
    // is what buildSeriesStreamUrl consumes.
    final url = ref.read(seriesStreamUrlProvider(episode.streamId));
    final episodeStream = XtreamStream(
      streamId: episode.streamId,
      name: 'S${widget.selectedSeason.toString().padLeft(2, '0')}E${episode.episodeNumber.toString().padLeft(2, '0')} — ${episode.title}',
      logo: widget.stream.logo,
      categoryId: widget.stream.categoryId,
      streamType: 'series',
      epgChannel: widget.stream.epgChannel,
    );

    // When resuming, look up the saved position so the player starts
    // where the user left off. Falls back to null (start from 0) on
    // any failure — matches the VOD resume behaviour in VodDetailScreen.
    Duration? startPosition;
    if (resume) {
      try {
        final creds = await ref.read(credentialsStoreProvider).loadActiveConnection();
        if (creds != null) {
          final store = ref.read(watchProgressStoreProvider);
          final progress = store.getProgress(
            profileId: creds.name,
            streamId: episode.streamId,
          );
          if (progress != null) {
            startPosition = progress.position;
          }
        }
      } catch (_) {
        // Non-fatal — start from the beginning.
      }
    }

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          stream: episodeStream,
          streamUrl: url,
          startPosition: startPosition,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentSeason = _findSeason(widget.selectedSeason);
    final seriesInfo = widget.seriesInfo;
    final stream = widget.stream;
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
              selected: widget.selectedSeason,
              onTap: widget.onSeasonSelected,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Episode list.
          Text(
            seriesInfo.seasons.length > 1
                ? 'Season ${widget.selectedSeason}'
                : 'Episodes',
            style: AppTypography.h3,
          ),
          const SizedBox(height: AppSpacing.sm),
          _EpisodeList(
            season: currentSeason,
            onPlay: (episode) => _playEpisode(episode),
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
