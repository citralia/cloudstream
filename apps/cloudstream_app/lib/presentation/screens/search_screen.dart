import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/search/search_service.dart';
import '../../core/storage/reminder_store.dart';
import '../../core/storage/search_type_filter_preferences_store.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_extensions.dart';
import '../providers/app_providers.dart';
import 'epg_guide_screen.dart';
import 'player_screen.dart';
import 'series_detail_screen.dart';
import 'vod_detail_screen.dart';

/// V32: the currently selected search-result type filter. **Re-exported
/// from `core/storage/search_type_filter_preferences_store.dart` in
/// V35** so the value can be persisted across app launches via
/// [SearchTypeFilterPreferencesStore]. The chip row's `onTap` writes
/// through to both the in-memory provider AND the store. Defaults to
/// [SearchResultTypeFilter.all] on a fresh install (no stored
/// preference) — preserves pre-V35 first-open behaviour.
export '../../core/storage/search_type_filter_preferences_store.dart'
    show SearchResultTypeFilter;

/// V32: pure function that partitions the in-memory result list and
/// the EPG hits into the pair to render, given a [filter]. Lives at
/// module scope so the V32 test file can drive it directly without
/// pumping the search screen widget (which depends on a real
/// `xtreamClientProvider` for the search index rebuilder). The
/// 'all' filter is the identity — returns both lists unchanged,
/// matching the pre-V32 behaviour. Any single-type filter returns an
/// empty list for the other side. Filters that match the kind
/// (`'live' | 'vod' | 'series'`) drop results whose `result.type`
/// doesn't match; the EPG filter drops all in-memory results
/// regardless of type. An unknown filter falls through to the 'all'
/// path (forward-compat).
({List<SearchResult> inMemory, List<EpgProgrammeHit> epg})
    filterSearchResults({
  required SearchResultTypeFilter filter,
  required List<SearchResult> inMemory,
  required List<EpgProgrammeHit> epg,
}) {
  switch (filter) {
    case SearchResultTypeFilter.all:
      return (inMemory: inMemory, epg: epg);
    case SearchResultTypeFilter.live:
      return (
        inMemory: inMemory.where((r) => r.type == 'live').toList(),
        epg: const <EpgProgrammeHit>[],
      );
    case SearchResultTypeFilter.vod:
      return (
        inMemory: inMemory.where((r) => r.type == 'vod').toList(),
        epg: const <EpgProgrammeHit>[],
      );
    case SearchResultTypeFilter.series:
      return (
        inMemory: inMemory.where((r) => r.type == 'series').toList(),
        epg: const <EpgProgrammeHit>[],
      );
    case SearchResultTypeFilter.epg:
      return (
        inMemory: const <SearchResult>[],
        epg: epg,
      );
  }
}

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

            // V32: type filter chips. Only shown while the user has
            // typed something — the empty-query idle state shows the
            // "Search for something" empty state below, and a chip
            // row in front of it would be pointless. The chip row
            // also renders nothing when there are zero results
            // across all types (an empty state takes over below).
            if (query.isNotEmpty) const _SearchTypeChips(key: Key('searchTypeChips')),

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

    final allEpgHits = epgAsync.maybeWhen(
      data: (h) => h,
      orElse: () => const <EpgProgrammeHit>[],
    );

    // V32: apply the selected type filter (default `all` → identity,
    // matches pre-V32 behaviour). The chip row above drives the
    // selection; this is a single switch over a 5-value enum so the
    // cost is one O(n) partition per build.
    final filter = ref.watch(searchTypeFilterProvider);
    final filtered = filterSearchResults(
      filter: filter,
      inMemory: results,
      epg: allEpgHits,
    );
    final epgHits = filtered.epg;
    final filteredResults = filtered.inMemory;

    if (filteredResults.isEmpty && epgHits.isEmpty && !epgAsync.isLoading) {
      return _EmptyState(
        icon: Icons.search_off,
        title: 'No results',
        subtitle: 'Nothing matches "$query"',
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      children: [
        if (filteredResults.isNotEmpty) ...[
          // V32: when a non-'all' filter is active the section header
          // is the singular type name (e.g. "Live TV", "VOD movies",
          // "Series") so the user sees what scope the result list
          // represents. With 'all' the original "Channels and VOD"
          // copy is preserved.
          _SectionHeader(
            label: switch (filter) {
              SearchResultTypeFilter.live => 'Live TV',
              SearchResultTypeFilter.vod => 'VOD',
              SearchResultTypeFilter.series => 'Series',
              SearchResultTypeFilter.epg => 'EPG programmes',
              SearchResultTypeFilter.all => 'Channels and VOD',
            },
          ),
          for (final result in filteredResults)
            _SearchResultTile(
              result: result,
              onTap: () => _openStream(result),
            ),
        ],
        if (epgHits.isNotEmpty) ...[
          if (filteredResults.isNotEmpty) const SizedBox(height: AppSpacing.lg),
          // V32: hide the EPG section header when the filter is
          // already `epg` — the single-section header above already
          // says "EPG programmes", and a duplicate would be visual
          // noise.
          if (filter != SearchResultTypeFilter.epg)
            const _SectionHeader(label: 'EPG programmes'),
          for (final hit in epgHits)
            _EpgResultTile(
              hit: hit,
              onTap: () => _openEpgHit(hit),
            ),
        ],
        // EPG still loading while we already have in-memory results: show
        // an unobtrusive footer spinner so the user knows the EPG
        // section is in flight. V32: also show it when the user has
        // selected the `epg` filter and the EPG provider is still
        // loading (the in-memory list is then empty by design, but
        // the EPG column is what the user is waiting for).
        if (epgAsync.isLoading &&
            (results.isNotEmpty || filter == SearchResultTypeFilter.epg)) ...[
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
    if (!context.mounted) return;
    final fire = reminder.fireAt.toLocal();
    final hh = fire.hour.toString().padLeft(2, '0');
    final mm = fire.minute.toString().padLeft(2, '0');
    // V29: after scheduling the reminder for THIS airing, the snackbar
    // exposes a "Any channel" action that schedules reminders for
    // every other future airing of the same programme title on any
    // other channel. Same data layer (RemindersNotifier.add) — the V07
    // storage id is `(channelId, startTime)`, naturally per-airing, so
    // one add() per airing. We capture the messenger before the await
    // so the `context.mounted` check on the action callback is cheap.
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          "Will remind you at $hh:$mm — ${programme.title}",
        ),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Any channel',
          onPressed: () => _scheduleOnAnyChannel(
            context: context,
            ref: ref,
            messenger: messenger,
            excludeChannelId: stream.streamId,
            excludeStartTime: programme.startTime,
            title: programme.title,
          ),
        ),
      ),
    );
  }

  /// V29: schedule a reminder for every OTHER future airing of [title]
  /// across all loaded channels' EPG (excluding the airing the user
  /// just long-pressed). Schedules nothing if there are no other
  /// airings. On success shows a confirmation snackbar with an UNDO
  /// action that removes all the newly-scheduled reminders.
  Future<void> _scheduleOnAnyChannel({
    required BuildContext context,
    required WidgetRef ref,
    required ScaffoldMessengerState messenger,
    required int excludeChannelId,
    required DateTime excludeStartTime,
    required String title,
  }) async {
    final results = await ref.read(
      programmeAiringsAcrossChannelsProvider(title).future,
    );
    // Filter out the source airing (which already has a V28 reminder).
    final others = results
        .where(
          (h) =>
              h.channel.streamId != excludeChannelId ||
              h.programme.startTime != excludeStartTime,
        )
        .toList();
    if (others.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No other airings of this programme'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final notifier = ref.read(remindersProvider.notifier);
    final addedIds = <String>[];
    for (final h in others) {
      final r = await notifier.add(
        channelId: h.channel.streamId,
        channelName: h.channel.name,
        programmeTitle: h.programme.title,
        startTime: h.programme.startTime,
        endTime: h.programme.endTime,
      );
      addedIds.add(r.id);
    }
    if (addedIds.isEmpty) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Set ${addedIds.length} more reminder'
              '${addedIds.length == 1 ? '' : 's'} for $title',
        ),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () async {
            for (final id in addedIds) {
              await ref.read(remindersProvider.notifier).remove(id);
            }
          },
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
        bg = context.appColors.primary.withValues(alpha: 0.2);
        fg = context.appColors.primary;
        icon = Icons.tv;
        break;
      case 'vod':
        bg = context.appColors.accent.withValues(alpha: 0.2);
        fg = context.appColors.accent;
        icon = Icons.movie;
        break;
      case 'live':
      default:
        bg = context.appColors.primary.withValues(alpha: 0.2);
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

/// V32: horizontal row of 5 type filter chips (All / Live / VOD /
/// Series / EPG) above the search results. Tapping a chip updates
/// [searchTypeFilterProvider] — the build method watches the same
/// provider and re-runs `filterSearchResults` to hide the other
/// sections.
///
/// The chip row is the `Expanded`-sibling of the results list, so
/// it gets a fixed height (`_chipRowHeight`) to match the
/// channel-list `CategoryFilterChips` row at 52pt — a Firestick-
/// friendly tap target that doesn't crowd the search bar above or
/// the result list below. Renders nothing when the underlying
/// `searchResultsProvider` and `programmeTitleSearchProvider` are
/// both empty (the body shows the "No results" empty state in that
/// case, and a chip row in front of "No results" would be visual
/// noise).
class _SearchTypeChips extends ConsumerWidget {
  const _SearchTypeChips({super.key});

  static const double _chipRowHeight = 52;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(searchTypeFilterProvider);
    final inMemoryResults = ref.watch(searchResultsProvider);
    // Watch the EPG query state without forcing a re-run — the chip
    // row only needs to know "is the EPG section empty", not what
    // it contains. Watching the debounced provider is sufficient
    // for the cap check; the actual `programmeTitleSearchProvider`
    // is still watched by the body's `build` for the result list.
    final debouncedEpgQuery = ref.watch(debouncedEpgQueryProvider);
    final epgAsync = ref.watch(
      programmeTitleSearchProvider(debouncedEpgQuery),
    );
    final epgHits = epgAsync.maybeWhen(
      data: (h) => h,
      orElse: () => const <EpgProgrammeHit>[],
    );

    // Per-type counts drive the badge suffix on each chip so the
    // user can see at a glance which filters would yield a result
    // (e.g. a 3 on VOD vs 0 on Series makes the choice obvious).
    final counts = <SearchResultTypeFilter, int>{
      SearchResultTypeFilter.live: inMemoryResults
          .where((r) => r.type == 'live')
          .length,
      SearchResultTypeFilter.vod: inMemoryResults
          .where((r) => r.type == 'vod')
          .length,
      SearchResultTypeFilter.series: inMemoryResults
          .where((r) => r.type == 'series')
          .length,
      SearchResultTypeFilter.epg: epgHits.length,
    };
    // 'all' is the sum of the others — pre-filter total.
    final total =
        counts[SearchResultTypeFilter.live]! +
        counts[SearchResultTypeFilter.vod]! +
        counts[SearchResultTypeFilter.series]! +
        counts[SearchResultTypeFilter.epg]!;
    counts[SearchResultTypeFilter.all] = total;

    // Hide the row entirely when there's nothing to filter — saves
    // a row of dead space and avoids the user tapping a chip that
    // produces no visible result.
    if (total == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: SizedBox(
        height: _chipRowHeight,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          children: [
            for (final entry in _chipOrder)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: _SearchTypeChip(
                  label: entry.label,
                  icon: entry.icon,
                  count: counts[entry.filter]!,
                  isSelected: selected == entry.filter,
                  // V35: write through to the store so the chip
                  // selection survives app restarts. The in-memory
                  // provider mutation still drives the immediate
                  // UI rebuild via Riverpod's normal watcher
                  // invalidation; the store call is a side-effect
                  // that the next cold start will read back.
                  onTap: () async {
                    ref.read(searchTypeFilterProvider.notifier).state =
                        entry.filter;
                    await ref
                        .read(searchTypeFilterPreferencesStoreProvider)
                        .save(entry.filter);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Display order + label/icon for the chip row. `all` first so
  /// the "no filter" default is the leftmost / default-tap position.
  static const List<_ChipSpec> _chipOrder = [
    _ChipSpec(
      filter: SearchResultTypeFilter.all,
      label: 'All',
      icon: Icons.all_inclusive,
    ),
    _ChipSpec(
      filter: SearchResultTypeFilter.live,
      label: 'Live TV',
      icon: Icons.live_tv,
    ),
    _ChipSpec(
      filter: SearchResultTypeFilter.vod,
      label: 'VOD',
      icon: Icons.movie,
    ),
    _ChipSpec(
      filter: SearchResultTypeFilter.series,
      label: 'Series',
      icon: Icons.tv,
    ),
    _ChipSpec(
      filter: SearchResultTypeFilter.epg,
      label: 'EPG',
      icon: Icons.event_note,
    ),
  ];
}

class _ChipSpec {
  final SearchResultTypeFilter filter;
  final String label;
  final IconData icon;
  const _ChipSpec({
    required this.filter,
    required this.label,
    required this.icon,
  });
}

/// V32: a single chip in the [_SearchTypeChips] row. Mirrors the
/// channel-list `_FilterChip` (V18) visual language — pill shape,
/// primary-tint background + border when selected, surfaceElevated +
/// muted text when not — but adds a count suffix ("Live TV 12") so
/// the user can see at a glance how many results each filter would
/// yield.
class _SearchTypeChip extends StatelessWidget {
  const _SearchTypeChip({
    required this.label,
    required this.icon,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? context.appColors.primary.withValues(alpha: 0.2)
              : context.appColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? context.appColors.primary
                : context.appColors.textMuted,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? context.appColors.primary
                  : context.appColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? context.appColors.primary
                    : context.appColors.textMuted,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                color: isSelected
                    ? context.appColors.primary
                    : context.appColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
