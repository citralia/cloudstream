import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/search/search_service.dart';
import '../../core/storage/reminder_store.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_extensions.dart';
import '../providers/app_providers.dart';
import 'epg_guide_screen.dart';
import 'player_screen.dart';
import 'series_detail_screen.dart';
import 'vod_detail_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  /// V27: debounces keystrokes before re-firing the EPG programme
  /// search — each run does N concurrent EPG network round-trips (one
  /// per loaded live channel), so we don't want one per character.
  /// 350ms is a Firestick-friendly default (well under the ~1s
  /// perceived-latency threshold). The unsynced [searchQueryProvider]
  /// still updates per keystroke for the instant in-memory
  /// live/VOD/series search results.
  Timer? _epgDebounce;
  static const Duration _epgDebounceDuration = Duration(milliseconds: 350);

  @override
  void initState() {
    super.initState();
    // Auto-focus the search field when screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _epgDebounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    ref.read(searchQueryProvider.notifier).state = query;
    // Schedule the debounced EPG re-run. The EPG provider is keyed on
    // the debounced query (not searchQueryProvider), so cancelling +
    // re-scheduling the timer effectively coalesces a burst of
    // keystrokes into a single provider re-fire.
    _epgDebounce?.cancel();
    _epgDebounce = Timer(_epgDebounceDuration, () {
      if (!mounted) return;
      ref.read(debouncedEpgQueryProvider.notifier).state = query;
    });
  }

  void _clear() {
    _controller.clear();
    _epgDebounce?.cancel();
    ref.read(searchQueryProvider.notifier).state = '';
    ref.read(debouncedEpgQueryProvider.notifier).state = '';
    _focusNode.requestFocus();
  }

  void _openStream(SearchResult result) {
    final stream = result.stream;
    switch (result.type) {
      case 'vod':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VodDetailScreen(stream: stream),
          ),
        );
        break;
      case 'series':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SeriesDetailScreen(stream: stream),
          ),
        );
        break;
      case 'live':
      default:
        // Live channel — play directly.
        ref.read(selectedStreamProvider.notifier).state = stream;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PlayerScreen(stream: stream)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final results = ref.watch(searchResultsProvider);
    final indexBuilt = ref.watch(searchIndexRebuilderProvider);
    // V27: EPG programme search — keyed on the debounced query so we
    // don't fire N EPG network round-trips per keystroke. When the
    // debounced query is empty the provider short-circuits to `[]`
    // synchronously, so this watch is cheap in the idle state.
    final debouncedEpgQuery = ref.watch(debouncedEpgQueryProvider);
    final epgAsync = ref.watch(programmeTitleSearchProvider(debouncedEpgQuery));

    return Scaffold(
      backgroundColor: context.appColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Search bar.
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                onChanged: _onQueryChanged,
                style: context.appTypography.body,
                cursorColor: context.appColors.primary,
                decoration: InputDecoration(
                  hintText: 'Search channels and VOD…',
                  prefixIcon: Icon(Icons.search, color: context.appColors.textMuted),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close, color: context.appColors.textMuted),
                          onPressed: _clear,
                        )
                      : null,
                ),
                textInputAction: TextInputAction.search,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(100),
                ],
              ),
            ),

            // Results.
            Expanded(
              child: _buildBody(query, results, indexBuilt, epgAsync),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    String query,
    List<SearchResult> results,
    AsyncValue<void> indexState,
    AsyncValue<List<EpgProgrammeHit>> epgAsync,
  ) {
    // Index not yet built (streams not loaded).
    if (query.isEmpty) {
      return const _EmptyState(
        icon: Icons.search,
        title: 'Search for something',
        subtitle: 'Channels and VOD will appear here',
      );
    }

    // Still building index.
    if (indexState.isLoading || indexState.hasError) {
      return Center(
        child: CircularProgressIndicator(color: context.appColors.primary),
      );
    }

    final epgHits = epgAsync.maybeWhen(
      data: (h) => h,
      orElse: () => const <EpgProgrammeHit>[],
    );

    if (results.isEmpty && epgHits.isEmpty && !epgAsync.isLoading) {
      return _EmptyState(
        icon: Icons.search_off,
        title: 'No results',
        subtitle: 'Nothing matches "$query"',
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      children: [
        if (results.isNotEmpty) ...[
          const _SectionHeader(label: 'Channels and VOD'),
          for (final result in results)
            _SearchResultTile(
              result: result,
              onTap: () => _openStream(result),
            ),
        ],
        if (epgHits.isNotEmpty) ...[
          if (results.isNotEmpty) const SizedBox(height: AppSpacing.lg),
          const _SectionHeader(label: 'EPG programmes'),
          for (final hit in epgHits)
            _EpgResultTile(
              hit: hit,
              onTap: () => _openEpgHit(hit),
            ),
        ],
        // EPG still loading while we already have in-memory results: show
        // an unobtrusive footer spinner so the user knows the EPG
        // section is in flight.
        if (epgAsync.isLoading && results.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: context.appColors.primary,
                  strokeWidth: 2,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _openEpgHit(EpgProgrammeHit hit) {
    // V27: open the EPG guide centred on the matched programme's start
    // time on the matched channel. The guide already filters the live
    // stream list via filteredLiveStreamsProvider, so the channel column
    // naturally includes the hit's parent channel (as long as it's
    // currently visible — i.e. not hidden / not filtered out by
    // category / not in favourites-only mode). The guide will scroll
    // its 6-hour window to the programme's start, surfacing the matched
    // block in the visible timeline.
    final startMs = hit.programme.start * 1000; // unix-s → epoch-ms
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EpgGuideScreen(initialProgrammeStartMs: startMs),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onTap;

  const _SearchResultTile({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final stream = result.stream;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                // Type badge.
                _TypeBadge(type: result.type),
                const SizedBox(width: AppSpacing.md),
                // Channel logo or initial.
                Container(
                  width: 48,
                  height: 36,
                  decoration: BoxDecoration(
                    color: context.appColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: stream.logo != null && stream.logo!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            stream.logo!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => _initial(context, stream.name),
                          ),
                        )
                      : _initial(context, stream.name),
                ),
                const SizedBox(width: AppSpacing.md),
                // Name.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stream.name,
                        style: context.appTypography.body.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        result.type == 'live'
                            ? 'Live TV'
                            : result.type == 'series'
                                ? 'Series'
                                : 'VOD',
                        style: context.appTypography.micro,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: context.appColors.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _initial(BuildContext context, String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: context.appColors.textMuted,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: context.appColors.textMuted, size: 56),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: context.appTypography.h3),
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle, style: context.appTypography.caption),
        ],
      ),
    );
  }
}

/// V27: a small section header that sits between result groups in the
/// search list (e.g. "Channels and VOD" → "EPG programmes"). Renders as
/// a left-aligned h3-style label with muted text colour.
class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        label,
        style: context.appTypography.h3.copyWith(
          color: context.appColors.textSecondary,
        ),
      ),
    );
  }
}

/// V27: an EPG programme search result tile. Renders the matched
/// programme's title + a "{channel} · {start time}" subtitle, plus a
/// "Live TV" type badge and a chevron. Tap navigates to the EPG guide
/// centred on the programme's start time (see [_openEpgHit]).
///
/// V28: long-press schedules a reminder via `RemindersNotifier`
/// (composes the V07 reminders feature with the V27 search results —
/// no new provider). Mirrors the EPG guide's `_onLongPress` flow:
/// future-only guard (`hit.programme.startTime > now`); toggle via
/// `RemindersNotifier.add` / `.remove` keyed by
/// `ReminderStore.makeId(channelId, startTime)`; snackbar with the
/// fire time on add or "Reminder removed" on remove. When the
/// programme already has a reminder, a small `Icons.notifications_active`
/// indicator sits to the left of the chevron — mirrors the EPG
/// guide's badge so the two surfaces look like a matched pair.
class _EpgResultTile extends ConsumerWidget {
  final EpgProgrammeHit hit;
  final VoidCallback onTap;

  const _EpgResultTile({required this.hit, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = hit.channel;
    final programme = hit.programme;
    final startTime = programme.startTime.toLocal();
    final hh = startTime.hour.toString().padLeft(2, '0');
    final mm = startTime.minute.toString().padLeft(2, '0');
    final dayLabel = _formatDay(startTime);
    final subtitle = '${stream.name} · $dayLabel $hh:$mm';

    // V28: did the user already schedule a reminder for this programme?
    // The EPG guide uses the same id shape — (channelId, startTime) —
    // so a reminder set from either surface is reflected here. We
    // `.select` on the list to avoid rebuilding the whole row on any
    // unrelated reminder change (e.g. setting a reminder on a different
    // programme).
    final reminderId = ReminderStore.makeId(
      channelId: stream.streamId,
      startTime: programme.startTime,
    );
    final hasReminder = ref.watch(
      remindersProvider.select((list) => list.any((r) => r.id == reminderId)),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          onLongPress: () => _onLongPress(context, ref),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                const _TypeBadge(type: 'live'),
                const SizedBox(width: AppSpacing.md),
                // Channel logo or initial.
                Container(
                  width: 48,
                  height: 36,
                  decoration: BoxDecoration(
                    color: context.appColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: stream.logo != null && stream.logo!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            stream.logo!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                _initial(context, stream.name),
                          ),
                        )
                      : _initial(context, stream.name),
                ),
                const SizedBox(width: AppSpacing.md),
                // Title + subtitle.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        programme.title,
                        style: context.appTypography.body.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: context.appTypography.micro,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (hasReminder) ...[
                  Icon(
                    Icons.notifications_active,
                    size: 16,
                    color: context.appColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Icon(
                  Icons.chevron_right,
                  color: context.appColors.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// V28: mirror of `EpgGuideScreen._ProgrammeBlock._onLongPress`.
  /// Toggles the reminder for this programme. Future-only — the
  /// snackbar's "Can't remind you about a programme that's already
  /// started" message is the same copy the EPG guide uses, so the two
  /// surfaces feel consistent if a user long-presses the same
  /// programme in both places.
  Future<void> _onLongPress(BuildContext context, WidgetRef ref) async {
    final programme = hit.programme;
    final stream = hit.channel;
    final now = DateTime.now().toUtc();
    if (!now.isBefore(programme.startTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Can't remind you about a programme that's already started",
          ),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final reminderId = ReminderStore.makeId(
      channelId: stream.streamId,
      startTime: programme.startTime,
    );
    final existing = ref
        .read(remindersProvider)
        .any((r) => r.id == reminderId);
    if (existing) {
      await ref.read(remindersProvider.notifier).remove(reminderId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reminder removed: ${programme.title}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final reminder = await ref.read(remindersProvider.notifier).add(
          channelId: stream.streamId,
          channelName: stream.name,
          programmeTitle: programme.title,
          startTime: programme.startTime,
          endTime: programme.endTime,
        );
    if (context.mounted) {
      final fire = reminder.fireAt.toLocal();
      final hh = fire.hour.toString().padLeft(2, '0');
      final mm = fire.minute.toString().padLeft(2, '0');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Will remind you at $hh:$mm — ${programme.title}",
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _initial(BuildContext context, String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: context.appColors.textMuted,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static String _formatDay(DateTime local) {
    final now = DateTime.now();
    final isToday = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    if (isToday) return 'Today';
    final tomorrow = now.add(const Duration(days: 1));
    final isTomorrow = local.year == tomorrow.year &&
        local.month == tomorrow.month &&
        local.day == tomorrow.day;
    if (isTomorrow) return 'Tomorrow';
    // Compact "Mon 9 Jun" — locale-independent for predictability.
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final wd = weekdays[local.weekday - 1];
    final mn = months[local.month - 1];
    return '$wd $local.day $mn';
  }
}

/// Type-tinted badge shown next to each search result.
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final IconData icon;
    switch (type) {
      case 'series':
        bg = context.appColors.primary.withOpacity(0.2);
        fg = context.appColors.primary;
        icon = Icons.tv;
        break;
      case 'vod':
        bg = context.appColors.accent.withOpacity(0.2);
        fg = context.appColors.accent;
        icon = Icons.movie;
        break;
      case 'live':
      default:
        bg = context.appColors.primary.withOpacity(0.2);
        fg = context.appColors.primary;
        icon = Icons.live_tv;
        break;
    }
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: fg, size: 18),
    );
  }
}
