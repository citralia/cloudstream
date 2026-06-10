import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/debug/debug_log_service.dart';
import '../../core/network/xtream_client.dart';
import '../../core/search/search_service.dart';
import '../../core/storage/profile_store.dart';
import '../../core/storage/play_count_store.dart';
import '../../core/storage/reminder_store.dart';
import '../../core/storage/watch_progress_store.dart';
import '../../core/storage/channel_sort_store.dart';
import '../../core/storage/theme_preferences_store.dart';
import '../../core/storage/lead_time_preferences_store.dart';
import '../../core/notifications/reminder_scheduler.dart';
import 'package:flutter/material.dart' show ThemeMode;
import '../../data/datasources/credentials_store.dart';
import '../../domain/entities/profile.dart';
import 'player_controller_notifier.dart';

// ── Core providers ─────────────────────────────────────────────────────────

final xtreamClientProvider = Provider<XtreamApiClient>((ref) {
  return XtreamApiClient();
});

final credentialsStoreProvider = Provider<CredentialsStore>((ref) {
  return CredentialsStore();
});

/// The active Xtream connection (or null if no connection is set).
/// Wraps `CredentialsStore.loadActiveConnection` in a provider so
/// tests can override it without needing a Flutter binding.
final activeCredentialsProvider = FutureProvider<XtreamCredentials?>((ref) async {
  final store = ref.watch(credentialsStoreProvider);
  return await store.loadActiveConnection();
});

// ── Auth state ─────────────────────────────────────────────────────────────

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final XtreamLoginResult? user;
  final String? error;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.error,
  });

  AuthState copyWith({AuthStatus? status, XtreamLoginResult? user, String? error}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final XtreamApiClient _client;
  final CredentialsStore _store;
  final ProfileStore _profileStore;

  AuthNotifier(this._client, this._store, this._profileStore) : super(const AuthState()) {
    _restoreSession();
  }

  /// Restore session from secure storage on app startup.
  Future<void> _restoreSession() async {
    try {
      final creds = await _store.loadActiveConnection();
      if (creds == null) {
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }
      _client.configure(
        serverUrl: creds.serverUrl,
        username: creds.username,
        password: creds.password,
      );
      // Validate by logging in
      final user = await _client.login();
      // Ensure at least one profile exists
      await _ensureProfile(creds.name);
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      // Stored credentials are invalid — clear them
      await _store.clearAll();
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> _ensureProfile(String connectionName) async {
    final profiles = _profileStore.listProfiles();
    if (profiles.isEmpty) {
      await _profileStore.addProfile(name: connectionName.isEmpty ? 'Default' : connectionName);
    }
    // Ensure active profile is set
    final activeId = _profileStore.getActiveProfileId();
    if (activeId.isEmpty) {
      final first = _profileStore.listProfiles().first;
      await _profileStore.setActiveProfileId(first.id);
    }
  }

  /// Login with Xtream credentials.
  Future<void> login({
    required String name,
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.unknown, error: null);

    // Configure client
    _client.configure(
      serverUrl: serverUrl,
      username: username,
      password: password,
    );

    try {
      final user = await _client.login();
      // Save credentials as a named connection profile
      await _store.saveConnection(
        name: name,
        serverUrl: serverUrl,
        username: username,
        password: password,
      );
      // Ensure a profile exists for this login
      await _ensureProfile(name);
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } on XtreamAuthException catch (e) {
      state = state.copyWith(status: AuthStatus.unauthenticated, error: e.message);
    } on XtreamApiException catch (e) {
      state = state.copyWith(status: AuthStatus.unauthenticated, error: e.message);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: 'Connection failed — check your server URL',
      );
    }
  }

  /// Logout and clear stored credentials.
  Future<void> logout() async {
    await _store.clearAll();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Update auth state directly (used when switching connections).
  void setUser(XtreamLoginResult user) {
    state = AuthState(status: AuthStatus.authenticated, user: user);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(xtreamClientProvider),
    ref.watch(credentialsStoreProvider),
    ref.watch(profileStoreProvider),
  );
});

// ── Channels ───────────────────────────────────────────────────────────────

final liveStreamsProvider = FutureProvider<List<XtreamStream>>((ref) async {
  final client = ref.watch(xtreamClientProvider);
  return await client.getLiveStreams();
});

final selectedCategoryIdProvider = StateProvider<int?>((ref) => null);

/// When true, the channel list is filtered to favourites-only for the active profile.
final favouritesOnlyProvider = StateProvider<bool>((ref) => false);

final filteredLiveStreamsProvider = FutureProvider<List<XtreamStream>>((ref) async {
  final categoryId = ref.watch(selectedCategoryIdProvider);
  final favouritesOnly = ref.watch(favouritesOnlyProvider);
  final hiddenOnly = ref.watch(hiddenOnlyProvider);
  final client = ref.watch(xtreamClientProvider);
  final streams = await client.getLiveStreams(categoryId: categoryId);
  // V18: hidden channels are excluded from the default view, and are
  // only visible when the user has explicitly toggled the "Hidden"
  // filter chip. The three filter modes (All / Favourites / Hidden)
  // are mutually exclusive in the UI — see CategoryFilterChips in
  // channel_list_screen.dart. The branches below enforce that.
  final hiddenIds = ref.watch(activeProfileHiddenProvider).toSet();
  final filtered = hiddenOnly
      ? streams.where((s) => hiddenIds.contains(s.streamId)).toList()
      : favouritesOnly
          ? () {
              final favIds = ref.watch(activeProfileFavouritesProvider).toSet();
              return streams
                  .where((s) => favIds.contains(s.streamId) && !hiddenIds.contains(s.streamId))
                  .toList();
            }()
          : streams.where((s) => !hiddenIds.contains(s.streamId)).toList();
  final sort = ref.watch(channelSortProvider);
  if (sort == ChannelSortMode.mostWatched) {
    // Read play counts for the active profile, then sort the
    // filtered stream list by count desc, with unplayed streams
    // pushed to the bottom and sorted by name as a stable
    // secondary key. Wrapped in a try/catch so a missing/broken
    // PlayCountStore (e.g. before the user has played anything)
    // degrades to "default order" rather than throwing.
    final creds = await ref.watch(activeCredentialsProvider.future);
    if (creds == null) return _applyChannelSort(filtered, ChannelSortMode.defaultOrder);
    final store = ref.watch(playCountStoreProvider);
    final counts = <int, int>{
      for (final e in store.topEntries(creds.name)) e.streamId: e.count,
    };
    return _applyChannelSort(filtered, sort, playCounts: counts);
  }
  if (sort == ChannelSortMode.recentlyPlayed) {
    // Same play-count store as mostWatched, but the ranking key is
    // the per-stream last-played-at timestamp (V16). Streams
    // without a recorded play are pushed to the bottom and
    // sorted by name as a stable secondary key.
    final creds = await ref.watch(activeCredentialsProvider.future);
    if (creds == null) return _applyChannelSort(filtered, ChannelSortMode.defaultOrder);
    final store = ref.watch(playCountStoreProvider);
    final lastPlayed = <int, int>{
      for (final e in store.recentEntries(creds.name)) e.streamId: e.lastPlayedAtMs,
    };
    return _applyChannelSort(filtered, sort, lastPlayedAtMs: lastPlayed);
  }
  return _applyChannelSort(filtered, sort);
});

/// Sort [streams] by the current [ChannelSortMode]. The default mode
/// returns the input unchanged (preserves Xtream server order). Name
/// is case-insensitive ascending. Number falls back to streamId when
/// the provider's `num` field is missing. [mostWatched] requires
/// [playCounts] (streamId → count); streams not in the map are pushed
/// to the bottom and sorted by name as a stable secondary key.
/// [recentlyPlayed] requires [lastPlayedAtMs] (streamId → epoch ms);
/// streams not in the map are pushed to the bottom and sorted by name
/// as a stable secondary key. The two map args are mutually exclusive.
List<XtreamStream> _applyChannelSort(
  List<XtreamStream> streams,
  ChannelSortMode mode, {
  Map<int, int>? playCounts,
  Map<int, int>? lastPlayedAtMs,
}) {
  switch (mode) {
    case ChannelSortMode.defaultOrder:
      return streams;
    case ChannelSortMode.name:
      final sorted = [...streams];
      sorted.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return sorted;
    case ChannelSortMode.number:
      // Streams that have a provider-supplied number sort by it
      // (asc); streams missing `number` are pushed to the bottom and
      // sorted by `streamId` as a stable secondary key. This matches
      // the cable-box mental model — null-num entries don't crowd
      // out real channel numbers near the top.
      final withNumber = <XtreamStream>[];
      final withoutNumber = <XtreamStream>[];
      for (final s in streams) {
        if (s.number != null) {
          withNumber.add(s);
        } else {
          withoutNumber.add(s);
        }
      }
      withNumber.sort((a, b) {
        final byNum = a.number!.compareTo(b.number!);
        if (byNum != 0) return byNum;
        return a.streamId.compareTo(b.streamId);
      });
      withoutNumber.sort((a, b) => a.streamId.compareTo(b.streamId));
      return [...withNumber, ...withoutNumber];
    case ChannelSortMode.mostWatched:
      // Two buckets: streams with a recorded play count (sorted by
      // count desc, then name asc as a stable tie-breaker) and
      // streams with no record (pushed to the bottom, name asc).
      // The "name" secondary key is the same one the existing home
      // "Most Watched" row uses via `PlayCountStore.topEntries`
      // (which falls back to streamId asc — close enough; using
      // name here gives the unplayed-bucket a friendlier, less
      // random-looking order in the long tail).
      assert(playCounts != null,
          'mostWatched sort requires playCounts (read from PlayCountStore)');
      final counts = playCounts!;
      final played = <XtreamStream>[];
      final unplayed = <XtreamStream>[];
      for (final s in streams) {
        if (counts.containsKey(s.streamId)) {
          played.add(s);
        } else {
          unplayed.add(s);
        }
      }
      played.sort((a, b) {
        final byCount = counts[b.streamId]!.compareTo(counts[a.streamId]!);
        if (byCount != 0) return byCount;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      unplayed.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return [...played, ...unplayed];
    case ChannelSortMode.recentlyPlayed:
      // Mirror of mostWatched, keyed on the per-stream last-played-at
      // timestamp (epoch ms). Played bucket sorts by recency desc
      // (most-recently-played first), with streamId asc as a stable
      // tie-breaker. Unplayed bucket (no recorded play) is pushed to
      // the bottom and sorted by name asc. The bucket boundary uses
      // map membership rather than timestamp > 0 because legacy
      // v0.1.x–v0.1.48 installs can have a count entry but no
      // stamped last-play time — `recentEntries` treats those as
      // epoch-0 and they would otherwise compete with genuinely
      // recent plays; gating on membership is the conservative
      // call. (See `PlayCountStore.recentEntries`.)
      assert(lastPlayedAtMs != null,
          'recentlyPlayed sort requires lastPlayedAtMs (read from PlayCountStore)');
      final last = lastPlayedAtMs!;
      final played = <XtreamStream>[];
      final unplayed = <XtreamStream>[];
      for (final s in streams) {
        if (last.containsKey(s.streamId)) {
          played.add(s);
        } else {
          unplayed.add(s);
        }
      }
      played.sort((a, b) {
        final byTime = last[b.streamId]!.compareTo(last[a.streamId]!);
        if (byTime != 0) return byTime;
        return a.streamId.compareTo(b.streamId);
      });
      unplayed.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return [...played, ...unplayed];
  }
}

// ── Channel sort mode ────────────────────────────────────────────────────

/// Store for the user's chosen live-channel sort mode. Backed by
/// [SharedPreferences] via [ChannelSortStore] so the selection
/// survives across launches.
final channelSortStoreProvider = Provider<ChannelSortStore>((ref) {
  return ChannelSortStore(ref.watch(sharedPreferencesProvider));
});

/// Currently-selected sort mode for the live TV channel list. Defaults
/// to [ChannelSortMode.defaultOrder] on first launch (no saved
/// preference). The `AppBar` sort button reads this and writes back
/// via [channelSortProvider.notifier] — which also persists through
/// [channelSortStoreProvider].
final channelSortProvider = StateProvider<ChannelSortMode>((ref) {
  final store = ref.watch(channelSortStoreProvider);
  return store.load();
});

// ── Categories ────────────────────────────────────────────────────────────

final liveCategoriesProvider = FutureProvider<List<XtreamCategory>>((ref) async {
  final client = ref.watch(xtreamClientProvider);
  return await client.getLiveCategories();
});

// ── EPG ──────────────────────────────────────────────────────────────────

final epgProvider = FutureProvider.family<List<XtreamEpgEntry>, int>((ref, streamId) async {
  final client = ref.watch(xtreamClientProvider);
  return await client.getEpg(streamId);
});

// ── Stream URL builder ────────────────────────────────────────────────────

final streamUrlProvider = Provider.family<String, int>((ref, streamId) {
  final client = ref.watch(xtreamClientProvider);
  return client.buildLiveStreamUrl(streamId);
});

// ── Selected channel ─────────────────────────────────────────────────────

final selectedStreamProvider = StateProvider<XtreamStream?>((ref) => null);

// ── Recently watched channels (for quick switcher) ─────────────────────────

final recentChannelsProvider = StateNotifierProvider<RecentChannelsNotifier, List<XtreamStream>>((ref) {
  return RecentChannelsNotifier();
});

class RecentChannelsNotifier extends StateNotifier<List<XtreamStream>> {
  RecentChannelsNotifier() : super([]);

  static const int maxHistory = 10;

  void add(XtreamStream stream) {
    // Remove if already present, then prepend.
    final updated = [stream, ...state.where((s) => s.streamId != stream.streamId)];
    state = updated.length > maxHistory ? updated.sublist(0, maxHistory) : updated;
  }
}

// ── Persistent player controller ──────────────────────────────────────────

final playerControllerProvider = StateNotifierProvider<PlayerControllerNotifier, PlayerControllerState>((ref) {
  return PlayerControllerNotifier();
});

// ── Quick-switcher overlay visibility (remote: Info key) ─────────────────

final quickSwitcherOverlayVisibleProvider = StateProvider<bool>((ref) => false);

// ── Connections (Playlist) ────────────────────────────────────────────────

final connectionsListProvider = FutureProvider<List<XtreamCredentials>>((ref) async {
  final store = ref.watch(credentialsStoreProvider);
  return await store.listConnections();
});

final activeConnectionNameProvider = StateProvider<String?>((ref) => null);

// ── VOD ───────────────────────────────────────────────────────────────────

final vodCategoriesProvider = FutureProvider<List<XtreamCategory>>((ref) async {
  final client = ref.watch(xtreamClientProvider);
  return await client.getVodCategories();
});

final selectedVodCategoryIdProvider = StateProvider<int?>((ref) => null);

final vodStreamsProvider = FutureProvider<List<XtreamStream>>((ref) async {
  final client = ref.watch(xtreamClientProvider);
  return await client.getVodStreams();
});

final filteredVodStreamsProvider = FutureProvider<List<XtreamStream>>((ref) async {
  final categoryId = ref.watch(selectedVodCategoryIdProvider);
  final client = ref.watch(xtreamClientProvider);
  return await client.getVodStreams(categoryId: categoryId);
});

final selectedVodProvider = StateProvider<XtreamStream?>((ref) => null);

final vodStreamUrlProvider = Provider.family<String, int>((ref, streamId) {
  final client = ref.watch(xtreamClientProvider);
  return client.buildVodStreamUrl(streamId);
});

/// Full VOD info (plot, cast, director, rating, duration, cover) for a single VOD stream.
/// Used by VodDetailScreen to render real metadata instead of the placeholder synopsis.
final vodInfoProvider = FutureProvider.family<XtreamVodInfo, int>((ref, vodId) async {
  final client = ref.watch(xtreamClientProvider);
  return await client.getVodInfo(vodId);
});

// ── Series ────────────────────────────────────────────────────────────────

final seriesCategoriesProvider = FutureProvider<List<XtreamCategory>>((ref) async {
  final client = ref.watch(xtreamClientProvider);
  return await client.getSeriesCategories();
});

final selectedSeriesCategoryIdProvider = StateProvider<int?>((ref) => null);

final seriesStreamsProvider = FutureProvider<List<XtreamStream>>((ref) async {
  final client = ref.watch(xtreamClientProvider);
  return await client.getSeriesStreams();
});

final filteredSeriesStreamsProvider = FutureProvider<List<XtreamStream>>((ref) async {
  final categoryId = ref.watch(selectedSeriesCategoryIdProvider);
  final client = ref.watch(xtreamClientProvider);
  return await client.getSeriesStreams(categoryId: categoryId);
});

/// Full series info (plot, seasons, episodes) for a single series.
/// Used by SeriesDetailScreen to render the season/episode browser.
final seriesInfoProvider = FutureProvider.family<XtreamSeriesInfo, int>((ref, seriesId) async {
  final client = ref.watch(xtreamClientProvider);
  return await client.getSeriesInfo(seriesId);
});

/// Builds the stream URL for a specific series episode, keyed by episode stream_id.
final seriesStreamUrlProvider = Provider.family<String, int>((ref, episodeStreamId) {
  final client = ref.watch(xtreamClientProvider);
  return client.buildSeriesStreamUrl(episodeStreamId);
});

/// Lazily-cached [XtreamSeriesInfo] keyed by series id (the parent
/// series, not an episode id). Fetched on first read and held for the
/// life of the [ProviderContainer]. The Continue Watching joiner uses
/// this to resolve saved episode stream IDs back to their parent
/// series + season/episode.
///
/// Unlike `seriesInfoProvider` (which is `FutureProvider.family` and
/// re-fetches per dependent), this is a simple LRU-shaped cache:
/// `cache[id] ?? await fetch(id)` and the result is held in memory.
class SeriesInfoCache {
  SeriesInfoCache(this._client);
  final XtreamApiClient _client;
  final Map<int, XtreamSeriesInfo> _cache = {};

  Future<XtreamSeriesInfo> get(int seriesId) async {
    final cached = _cache[seriesId];
    if (cached != null) return cached;
    final info = await _client.getSeriesInfo(seriesId);
    _cache[seriesId] = info;
    return info;
  }

  /// Reverse-lookup: given an episode stream id, find the (parent
  /// series id, season number, episode) tuple — or null if the episode
  /// is not in any cached series. Iterates the cache only (does not
  /// trigger fetches), so callers must preload the series they want
  /// to scan via [load] / [loadAll].
  ContinueWatchingEpisodeHit? findEpisodeByStreamId(int episodeStreamId) {
    for (final entry in _cache.entries) {
      for (final season in entry.value.seasons) {
        for (final ep in season.episodes) {
          if (ep.streamId == episodeStreamId) {
            return ContinueWatchingEpisodeHit(
              seriesId: entry.key,
              series: entry.value,
              seasonNumber: season.seasonNumber,
              episode: ep,
            );
          }
        }
      }
    }
    return null;
  }

  /// Bulk-load a list of series ids into the cache. Used by the
  /// Continue Watching joiner to pre-warm all parent series at once.
  Future<void> loadAll(Iterable<int> seriesIds) async {
    for (final id in seriesIds) {
      if (_cache.containsKey(id)) continue;
      try {
        await get(id);
      } catch (_) {
        // Skip individual failures — the episode will just stay
        // orphan and be dropped from the Continue Watching row.
      }
    }
  }
}

final seriesInfoCacheProvider = Provider<SeriesInfoCache>((ref) {
  return SeriesInfoCache(ref.watch(xtreamClientProvider));
});

/// Result of resolving a saved episode stream id back to its parent
/// series + season/episode.
class ContinueWatchingEpisodeHit {
  final int seriesId;
  final XtreamSeriesInfo series;
  final int seasonNumber;
  final XtreamEpisode episode;

  const ContinueWatchingEpisodeHit({
    required this.seriesId,
    required this.series,
    required this.seasonNumber,
    required this.episode,
  });
}

// ── Watch Progress ─────────────────────────────────────────────────────────

/// Must be overridden at app startup with `SharedPreferences.instanceFor`.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override sharedPreferencesProvider at app startup');
});

/// VOD watch-progress store, backed by SharedPreferences.
final watchProgressStoreProvider = Provider<WatchProgressStore>((ref) {
  return WatchProgressStore(ref.watch(sharedPreferencesProvider));
});

/// Get saved watch progress for a given stream + active profile.
final watchProgressProvider = Provider.family<WatchProgress?, ({int streamId, String profileId})>((ref, params) {
  final store = ref.watch(watchProgressStoreProvider);
  return store.getProgress(profileId: params.profileId, streamId: params.streamId);
});

/// Per-profile play-count store, backed by SharedPreferences.
/// `PlayerScreen._saveProgress` calls `increment()` once per ~30s of
/// playback (and once on dispose), so the counter is effectively "how
/// many 30s-segments of this stream have I watched, ever."
final playCountStoreProvider = Provider<PlayCountStore>((ref) {
  return PlayCountStore(ref.watch(sharedPreferencesProvider));
});

// ── EPG Reminders ────────────────────────────────────────────────────────

/// Persists scheduled EPG reminders. Backed by SharedPreferences —
/// `ReminderStore` is the only thing that knows the on-disk format.
///
/// The actual OS-level notification scheduling is the responsibility
/// of the [ReminderScheduler] injected via [reminderSchedulerProvider]
/// — by default this is a `LocalNotificationsReminderScheduler`
/// wrapping `flutter_local_notifications`, but tests can swap in
/// any fake that implements the same interface.
final reminderStoreProvider = Provider<ReminderStore>((ref) {
  return ReminderStore(ref.watch(sharedPreferencesProvider));
});

/// SharedPreferences-backed [LeadTimePreferencesStore]. The
/// Settings → Reminders lead-time picker writes through this;
/// [defaultLeadTimeProvider] reads the in-memory mirror on cold
/// start.
final leadTimePreferencesStoreProvider = Provider<LeadTimePreferencesStore>((ref) {
  return LeadTimePreferencesStore(ref.watch(sharedPreferencesProvider));
});

/// The user's preferred "remind me X minutes before" lead time.
/// Persisted via [LeadTimePreferencesStore] under
/// `reminder_default_lead_minutes`; the initial value comes from
/// the store on first read (5 min default on a fresh install).
/// Overridable from the Settings → Reminders lead-time picker, and
/// read by [RemindersNotifier.add] when scheduling new reminders.
final defaultLeadTimeProvider = StateProvider<Duration>((ref) {
  return ref.watch(leadTimePreferencesStoreProvider).load();
});

/// Schedules OS-level notifications for reminders. Overridable so
/// tests can inject a no-op or recording fake — production code
/// reads the default `LocalNotificationsReminderScheduler`.
final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  throw UnimplementedError(
    'reminderSchedulerProvider must be overridden in main() (or in tests). '
    'Use LocalNotificationsReminderScheduler as the production impl.',
  );
});

// ── Theme preferences ──────────────────────────────────────────────────

/// SharedPreferences-backed [ThemePreferencesStore]. The Settings
/// → Theme tile writes through this; `MaterialApp.themeMode` reads
/// the in-memory mirror at [themeModeProvider].
final themePreferencesStoreProvider = Provider<ThemePreferencesStore>((ref) {
  return ThemePreferencesStore(ref.watch(sharedPreferencesProvider));
});

/// The user's preferred [ThemeMode]. Defaults to [ThemeMode.system]
/// on first launch (no saved preference). The Settings → Theme tile
/// reads this and writes back via [themeModeProvider.notifier] —
/// which also persists through [themePreferencesStoreProvider].
///
/// `MaterialApp.themeMode` (in `main.dart`) watches this provider
/// to flip between [AppTheme.dark] / [AppTheme.light] at runtime
/// without a restart.
final themeModeProvider = StateProvider<ThemeMode>((ref) {
  final store = ref.watch(themePreferencesStoreProvider);
  return store.load();
});

/// In-memory list of reminders for the active connection, exposed
/// to the UI as a [StateNotifier] so `add` / `remove` can trigger
/// rebuilds without re-reading the store on every watch.
///
/// Filters by the active profile's name (the same name used in
/// `Reminder.profileName`) and drops reminders for programmes that
/// have already ended. Sort: [Reminder.fireAt] ascending.
///
/// On every mutation, also talks to the injected
/// [ReminderScheduler] so the OS notification stays in sync with
/// the persisted list. On profile change, rehydrates the OS-side
/// schedule from the current on-disk list.
class RemindersNotifier extends StateNotifier<List<Reminder>> {
  RemindersNotifier(this._ref) : super(const []) {
    _load();
  }

  final Ref _ref;

  void _load() {
    final creds = _ref.read(activeCredentialsProvider).valueOrNull;
    if (creds == null) {
      state = const [];
      return;
    }
    final store = _ref.read(reminderStoreProvider);
    state = store.activeForProfile(creds.name);
  }

  /// Re-read the store from disk and re-schedule every active
  /// reminder. Useful when the active profile changes — the
  /// bottom-nav `Live TV` tab calls this on focus, and `main()`
  /// calls it once on cold start.
  Future<void> refresh() async {
    _load();
    final scheduler = _safeScheduler();
    if (scheduler != null) {
      await scheduler.rehydrate(state);
    }
  }

  /// Schedule a reminder for a programme. The caller passes the full
  /// programme details because the EPG data is already loaded; we
  /// just persist it with a stable id and the user's current default
  /// lead time (from [defaultLeadTimeProvider]).
  ///
  /// Returns the stored [Reminder] (the caller uses it to show a
  /// confirmation snackbar with the actual fire time).
  Future<Reminder> add({
    required int channelId,
    required String channelName,
    required String programmeTitle,
    required DateTime startTime,
    required DateTime endTime,
    Duration? leadTime,
  }) async {
    final creds = _ref.read(activeCredentialsProvider).valueOrNull;
    final profileName = creds?.name ?? '';
    final defaultLead = _ref.read(defaultLeadTimeProvider);
    final effectiveLead = leadTime ?? defaultLead;
    final reminder = Reminder(
      id: ReminderStore.makeId(channelId: channelId, startTime: startTime),
      channelId: channelId,
      channelName: channelName,
      programmeTitle: programmeTitle,
      startTime: startTime,
      endTime: endTime,
      leadTime: effectiveLead,
      profileName: profileName,
    );
    await _ref.read(reminderStoreProvider).add(reminder);
    final scheduler = _safeScheduler();
    if (scheduler != null) {
      // Best-effort: if the user has never granted POST_NOTIFICATIONS
      // we still save the reminder (it'll fire once permission is
      // granted and the next rehydrate runs). The first call to
      // requestPermission surfaces the OS dialog to the user.
      await scheduler.requestPermission();
      await scheduler.schedule(reminder);
    }
    _load();
    return reminder;
  }

  Future<void> remove(String id) async {
    await _ref.read(reminderStoreProvider).remove(id);
    final scheduler = _safeScheduler();
    if (scheduler != null) {
      await scheduler.cancel(id);
    }
    _load();
  }

  /// Returns the scheduler if it's been wired in, else null. We
  /// tolerate a missing scheduler so widgets that watch
  /// [remindersProvider] still function in the test harness
  /// (`reminders_list_screen_test.dart` doesn't override the
  /// scheduler — it just exercises the data path).
  ReminderScheduler? _safeScheduler() {
    try {
      return _ref.read(reminderSchedulerProvider);
    } on UnimplementedError {
      return null;
    }
  }
}

final remindersProvider =
    StateNotifierProvider<RemindersNotifier, List<Reminder>>((ref) {
  return RemindersNotifier(ref);
});

/// Discriminator for the kind of item a [ContinueWatchingEntry] represents.
/// A saved watch-progress id can resolve to either a VOD/series-level
/// stream (the VOD case), a series episode (resolved against the
/// [SeriesInfoCache] by episode stream id), or — V24 — a live TV
/// channel the user has been watching for >30s.
enum ContinueWatchingKind { vod, seriesEpisode, liveChannel }

/// One "Continue Watching" entry: the resolved stream + its saved progress.
class ContinueWatchingEntry {
  final XtreamStream stream;
  final WatchProgress progress;
  final ContinueWatchingKind kind;

  /// For [ContinueWatchingKind.seriesEpisode] entries: the parent
  /// series info and the resolved episode. Null for VOD entries.
  final XtreamSeriesInfo? parentSeries;
  final XtreamSeason? parentSeason;
  final XtreamEpisode? episode;

  /// V23: The id of the parent series, copied from the
  /// [ContinueWatchingEpisodeHit] used to build the entry. Distinct
  /// from [stream] when the parent series stream is missing from the
  /// loaded catalogue (the synthesised episode stream is used as a
  /// fallback in that case — see `continueWatchingProvider` step 2).
  /// Always non-null for [ContinueWatchingKind.seriesEpisode]
  /// entries; always null for VOD entries. The V23 dedupe groups
  /// series-episode entries by this id so a user with progress on
  /// multiple episodes of the same series gets one card.
  final int? parentSeriesId;

  const ContinueWatchingEntry({
    required this.stream,
    required this.progress,
    this.kind = ContinueWatchingKind.vod,
    this.parentSeries,
    this.parentSeason,
    this.episode,
    this.parentSeriesId,
  });
}

/// "Continue Watching" row data for the active connection.
///
/// Resolves every saved watch-progress streamId against the loaded VOD
/// list, the series stream list (for series-level entries), the
/// [SeriesInfoCache] (which maps each episode stream id back to its
/// parent series + season/episode), AND — V24 — the live TV channel
/// list (a user watching a live channel for >30s has watch progress
/// saved just like a VOD — closing the V03 follow-on gap where live
/// channels never appeared in the Continue Watching row). Stream IDs
/// that no longer exist in any of these sources are dropped silently.
///
/// Keyed by the active connection's `name` to match the writer
/// (`PlayerScreen._saveProgress` saves with `creds.name`).
final continueWatchingProvider = FutureProvider<List<ContinueWatchingEntry>>((ref) async {
  // Use the same override path as other providers so tests can swap it
  // out for a fake that doesn't need a Flutter binding.
  final creds = await ref.watch(activeCredentialsProvider.future);
  if (creds == null) return [];
  final store = ref.watch(watchProgressStoreProvider);
  final savedIds = store.savedStreamIds(creds.name);
  if (savedIds.isEmpty) return [];

  // Wait for the source lists to fully load. `valueOrNull` would
  // miss the data on the first read when the provider is still
  // resolving — `await ... .future` ensures we get the real value.
  final vod = await ref.watch(vodStreamsProvider.future);
  final series = await ref.watch(seriesStreamsProvider.future).catchError(
        (_) => const <XtreamStream>[],
      );
  // V24: also wait for live streams so we can resolve saved progress
  // for live channels. Tolerate failures (e.g. server down on a
  // reconnect) — the provider still surfaces VOD + series entries,
  // the live ones just get dropped this tick.
  final live = await ref.watch(liveStreamsProvider.future).catchError(
        (_) => const <XtreamStream>[],
      );

  // Pre-load the series-info cache for every series in the catalogue.
  // Then we can do a reverse-lookup from any saved episode stream id
  // back to its parent series in O(1) per cache entry. Skipped when
  // the series list is empty (nothing to resolve against).
  final cache = ref.watch(seriesInfoCacheProvider);
  if (series.isNotEmpty) {
    await cache.loadAll(series.map((s) => s.streamId));
  }

  // Build a single lookup over VOD + series (for series-level entries).
  // V24: live channels are a separate lookup so we can tag the
  // resulting entries with ContinueWatchingKind.liveChannel without
  // accidentally mis-tagging a series-level entry that happens to
  // also exist in the live catalogue (rare but possible — a series
  // stream that doubles as a live channel).
  final byId = <int, XtreamStream>{};
  for (final s in vod) {
    byId[s.streamId] = s;
  }
  for (final s in series) {
    byId[s.streamId] = s;
  }
  final liveById = <int, XtreamStream>{
    for (final s in live) s.streamId: s,
  };

  final entries = <ContinueWatchingEntry>[];
  for (final id in savedIds) {
    final progress = store.getProgress(profileId: creds.name, streamId: id);
    if (progress == null) continue;

    // 1) Direct match in VOD or series-level list.
    final direct = byId[id];
    if (direct != null) {
      entries.add(ContinueWatchingEntry(
        stream: direct,
        progress: progress,
        kind: ContinueWatchingKind.vod,
      ));
      continue;
    }

    // 2) Reverse-lookup: is `id` a series episode we have cached?
    final hit = cache.findEpisodeByStreamId(id);
    if (hit != null) {
      // Synthesise a stream for the episode so the card can render
      // its name + logo in the Continue Watching row. The parent
      // series is the cover/logo source.
      final ep = hit.episode;
      final parent = hit.series;
      final episodeStream = XtreamStream(
        streamId: ep.streamId,
        name: 'S${hit.seasonNumber.toString().padLeft(2, '0')}E${ep.episodeNumber.toString().padLeft(2, '0')} — ${ep.title.isNotEmpty ? ep.title : parent.name}',
        logo: parent.cover,
        categoryId: 0,
        streamType: 'series',
      );
      // Find the parent stream (for name + logo consistency).
      XtreamStream parentStream = byId[hit.seriesId] ?? episodeStream;
      final parentSeason = parent.seasons.firstWhere(
        (s) => s.seasonNumber == hit.seasonNumber,
        orElse: () => parent.seasons.isNotEmpty
            ? parent.seasons.first
            : const XtreamSeason(seasonNumber: 1, episodes: []),
      );
      entries.add(ContinueWatchingEntry(
        stream: parentStream,
        progress: progress,
        kind: ContinueWatchingKind.seriesEpisode,
        parentSeries: parent,
        parentSeason: parentSeason,
        episode: ep,
        parentSeriesId: hit.seriesId,
      ));
      continue;
    }

    // 3) V24: Direct match in the live TV channel catalogue. A
    // user watching a live channel for >30s has watch progress
    // saved by PlayerScreen._saveProgress. The "Resume" tap on the
    // resulting Continue Watching card opens the live player
    // directly (no resume position — live streams don't seek;
    // it's an "I was watching this" affordance, not a true
    // resume). A live channel is a single item, not a container
    // of sub-items, so the V23 group-by-parent dedupe doesn't
    // apply (mirrors how VOD entries are handled).
    final liveStream = liveById[id];
    if (liveStream != null) {
      entries.add(ContinueWatchingEntry(
        stream: liveStream,
        progress: progress,
        kind: ContinueWatchingKind.liveChannel,
      ));
      continue;
    }
    // else: orphan — drop silently.
  }

  // V23: Group series-episode entries by parent series id and keep
  // the most recently updated episode per series. A user who has
  // progress on 3 episodes of "Breaking Bad" should see ONE
  // "Continue Watching — Breaking Bad" card (showing the most
  // recent episode's S/E/title badge), not three duplicate parent
  // cards. VOD entries are unaffected — a movie is a single item,
  // not a container of sub-items, so there's no "group" to dedupe.
  //
  // V24: live-channel entries are also passed through unchanged
  // (a live channel is a single item, not a container of
  // sub-items — same rationale as VOD). They live in the
  // "everything except seriesEpisode" bucket alongside VOD
  // entries, so the existing V23 partition + dedupe logic
  // handles them correctly with no changes.
  //
  // The dedupe is stable: ties on `updatedAt` resolve by streamId
  // asc (matches the V05 / V09 / V16 tie-breaker convention). The
  // representative's `stream` is the synthesised episode stream
  // from step 2 (so the S/E/title badge renders), and
  // `parentSeries` / `parentSeason` / `episode` are set, so the
  // resume tap on the card still opens [SeriesDetailScreen] with
  // the right episode pre-selected.
  final seriesEpisodes = <ContinueWatchingEntry>[];
  final vodEntries = <ContinueWatchingEntry>[];
  for (final entry in entries) {
    if (entry.kind == ContinueWatchingKind.seriesEpisode) {
      seriesEpisodes.add(entry);
    } else {
      vodEntries.add(entry);
    }
  }
  final dedupedEpisodes = <int, ContinueWatchingEntry>{};
  for (final entry in seriesEpisodes) {
    final seriesId = entry.parentSeriesId!;
    final existing = dedupedEpisodes[seriesId];
    if (existing == null ||
        entry.progress.updatedAt.isAfter(existing.progress.updatedAt) ||
        (entry.progress.updatedAt.isAtSameMomentAs(existing.progress.updatedAt) &&
            entry.episode!.streamId < existing.episode!.streamId)) {
      dedupedEpisodes[seriesId] = entry;
    }
  }
  final deduped = <ContinueWatchingEntry>[
    ...vodEntries,
    ...dedupedEpisodes.values,
  ];
  deduped.sort((a, b) => b.progress.updatedAt.compareTo(a.progress.updatedAt));

  // V25: dedupe live-channel entries against the Recently Played
  // row. The user is currently watching BBC One for >30s — that
  // saves watch progress (V24 branch below already handles that) AND
  // a recency stamp via PlayCountStore.increment (called from
  // PlayerScreen._saveProgress every 30s). Both rows would then
  // surface a card for the same channel with the same tap target
  // (play BBC One) — the same "two rows showing the same channel"
  // problem V22 fixed for Most Watched. Drop any live-channel entry
  // whose streamId is in the recency-top-N set.
  //
  // VOD and series-episode entries are NOT deduped here:
  // `recentlyPlayedProvider` is live-only (it joins against
  // `liveStreamsProvider` exclusively, per V20's implementation), so
  // the recency set can never contain a VOD or series streamId.
  // Movies + series episodes always remain in Continue Watching
  // even if the user recently watched them.
  //
  // Awaiting `.future` rather than reading `valueOrNull` makes the
  // dedupe deterministic (same first-tick-null-trap avoidance V22
  // uses for `mostWatchedProvider`). If recency is still loading,
  // we don't ship a half-loaded Continue Watching row.
  final recent = await ref.watch(recentlyPlayedProvider.future);
  final excludeIds = <int>{
    for (final r in recent.take(kPersonalisationRowCap)) r.stream.streamId,
  };
  return deduped
      .where((e) =>
          e.kind != ContinueWatchingKind.liveChannel ||
          !excludeIds.contains(e.stream.streamId))
      .toList();
});

/// V21: VOD-only Continue Watching — filters [continueWatchingProvider] to
/// entries where the saved watch progress resolved to a VOD stream
/// (`ContinueWatchingKind.vod`). Drives the new Continue Watching row on
/// the VOD home tab ([VodScreen]). Series-episode entries are routed
/// through [continueWatchingSeriesProvider] instead. Live-channel
/// entries (V24) are routed through [continueWatchingLiveProvider] —
/// they belong on the channel list, not the VOD tab, since "I was
/// watching this live channel" doesn't fit a VOD-browsing context.
///
/// Defers to [continueWatchingProvider]'s own null-degrade paths (no
/// creds → [], no saved ids → [], no live catalogue → []) — the filter
/// just narrows further. Returns `[]` on the provider's loading /
/// error state so a render on the VOD tab never crashes on a partial
/// provider state.
final continueWatchingVodProvider =
    FutureProvider<List<ContinueWatchingEntry>>((ref) async {
  // Must `await` the source future, not just `ref.watch` — the source
  // is a `FutureProvider` whose first read is an unresolved
  // `AsyncValue<List<...>>`. Watching the AsyncValue and calling
  // `maybeWhen` on it returns `[]` for the loading state and never
  // re-runs when the source future resolves (Riverpod can't re-run
  // this provider based on an inner async state change without an
  // explicit `await`). Awaiting the `.future` blocks here, then the
  // filter runs once with the resolved data.
  final all = await ref.watch(continueWatchingProvider.future);
  return all.where((e) => e.kind == ContinueWatchingKind.vod).toList();
});

/// V21: Series-episode-only Continue Watching — filters
/// [continueWatchingProvider] to entries where the saved watch progress
/// resolved to a series episode via the [SeriesInfoCache]
/// (`ContinueWatchingKind.seriesEpisode`). Drives the new Continue
/// Watching row on the Series home tab ([SeriesScreen]). VOD entries
/// are routed through [continueWatchingVodProvider] instead. Live
/// entries (V24) are routed through [continueWatchingLiveProvider].
///
/// Same null-degrade contract as [continueWatchingVodProvider].
final continueWatchingSeriesProvider =
    FutureProvider<List<ContinueWatchingEntry>>((ref) async {
  // See [continueWatchingVodProvider] for why we `await` the source
  // future rather than watching the AsyncValue.
  final all = await ref.watch(continueWatchingProvider.future);
  return all
      .where((e) => e.kind == ContinueWatchingKind.seriesEpisode)
      .toList();
});

/// V24: Live-channel-only Continue Watching — filters
/// [continueWatchingProvider] to entries where the saved watch progress
/// resolved to a live TV channel (`ContinueWatchingKind.liveChannel`).
///
/// A user watching a live channel for >30s has watch progress saved
/// by `PlayerScreen._saveProgress` (the save cadence is the same as
/// for VOD/series). The resulting Continue Watching card lives on the
/// Live TV home tab — same place as the channel list — and tap-routes
/// to the live player (no resume position; live streams don't seek).
///
/// The V21 split put VOD + Series Continue Watching on their own
/// tabs. Live channels have no dedicated tab (the Live TV tab IS the
/// channel list), so [continueWatchingLiveProvider] is only consumed
/// by the channel-list `_ContinueWatchingRow` — but exposed as a
/// provider for symmetry with the V21 split, and to make it easy to
/// add a "Live TV resume" badge in the future without touching the
/// main joiner.
///
/// Same null-degrade contract as [continueWatchingVodProvider] /
/// [continueWatchingSeriesProvider].
final continueWatchingLiveProvider =
    FutureProvider<List<ContinueWatchingEntry>>((ref) async {
  // See [continueWatchingVodProvider] for why we `await` the source
  // future rather than watching the AsyncValue.
  final all = await ref.watch(continueWatchingProvider.future);
  return all
      .where((e) => e.kind == ContinueWatchingKind.liveChannel)
      .toList();
});

// ── Profile Store ───────────────────────────────────────────────────────────

/// Requires sharedPreferencesProvider to be overridden at app startup.
final profileStoreProvider = Provider<ProfileStore>((ref) {
  return ProfileStore(ref.watch(sharedPreferencesProvider));
});

// ── Profiles ────────────────────────────────────────────────────────────────

/// All local profiles.
final profilesProvider = StateNotifierProvider<ProfilesNotifier, List<Profile>>((ref) {
  final store = ref.watch(profileStoreProvider);
  return ProfilesNotifier(store);
});

class ProfilesNotifier extends StateNotifier<List<Profile>> {
  final ProfileStore _store;
  ProfilesNotifier(this._store) : super(_store.listProfiles());

  Future<void> add({required String name, int colorIndex = 0}) async {
    await _store.addProfile(name: name, colorIndex: colorIndex);
    state = _store.listProfiles();
  }

  Future<void> update(Profile profile) async {
    await _store.updateProfile(profile);
    state = _store.listProfiles();
  }

  Future<void> delete(String id) async {
    await _store.deleteProfile(id);
    state = _store.listProfiles();
  }

  void refresh() {
    state = _store.listProfiles();
  }
}

/// The currently active profile ID.
final activeProfileIdProvider = StateProvider<String>((ref) {
  final store = ref.watch(profileStoreProvider);
  return store.getActiveProfileId();
});

/// The currently active Profile object (derived).
final activeProfileProvider = Provider<Profile?>((ref) {
  final id = ref.watch(activeProfileIdProvider);
  if (id.isEmpty) return null;
  final profiles = ref.watch(profilesProvider);
  try {
    return profiles.firstWhere((p) => p.id == id);
  } catch (_) {
    return null;
  }
});

/// Switch to a different profile.
Future<void> switchToProfile(WidgetRef ref, String profileId) async {
  final store = ref.read(profileStoreProvider);
  await store.setActiveProfileId(profileId);
  ref.read(activeProfileIdProvider.notifier).state = profileId;
}

// ── Per-profile state ──────────────────────────────────────────────────────

/// Favourite stream IDs for a given profile.
final profileFavouritesProvider = Provider.family<List<int>, String>((ref, profileId) {
  final store = ref.watch(profileStoreProvider);
  return store.getFavourites(profileId);
});

/// Favourite stream IDs for the active profile.
final activeProfileFavouritesProvider = Provider<List<int>>((ref) {
  final activeProfile = ref.watch(activeProfileProvider);
  if (activeProfile == null) return [];
  return ref.watch(profileFavouritesProvider(activeProfile.id));
});

/// Toggle a stream in/out of the active profile's favourites.
/// Returns the new is-favourite boolean.
Future<bool> toggleFavourite(WidgetRef ref, int streamId) async {
  final activeProfile = ref.read(activeProfileProvider);
  if (activeProfile == null) return false;
  final store = ref.read(profileStoreProvider);
  final result = await store.toggleFavourite(activeProfile.id, streamId);
  // Force provider refresh.
  ref.invalidate(profileFavouritesProvider(activeProfile.id));
  return result;
}

/// Hidden stream IDs for a given profile (V18).
final profileHiddenProvider = Provider.family<List<int>, String>((ref, profileId) {
  final store = ref.watch(profileStoreProvider);
  return store.getHidden(profileId);
});

/// Hidden stream IDs for the active profile (V18).
final activeProfileHiddenProvider = Provider<List<int>>((ref) {
  final activeProfile = ref.watch(activeProfileProvider);
  if (activeProfile == null) return [];
  return ref.watch(profileHiddenProvider(activeProfile.id));
});

/// Toggle a stream in/out of the active profile's hidden set (V18).
/// Returns the new is-hidden boolean.
Future<bool> toggleHidden(WidgetRef ref, int streamId) async {
  final activeProfile = ref.read(activeProfileProvider);
  if (activeProfile == null) return false;
  final store = ref.read(profileStoreProvider);
  final result = await store.toggleHidden(activeProfile.id, streamId);
  // Force provider refresh.
  ref.invalidate(profileHiddenProvider(activeProfile.id));
  return result;
}

/// When true, the channel list is filtered to show only hidden channels for
/// the active profile (V18). Mirrors `favouritesOnlyProvider`. Hidden
/// channels are otherwise filtered OUT of the channel list by default.
final hiddenOnlyProvider = StateProvider<bool>((ref) => false);

/// V19: Resolved hidden-channel metadata for the active profile.
///
/// Joins the active profile's hidden stream IDs (from
/// [activeProfileHiddenProvider]) against the loaded
/// [liveStreamsProvider] so the "Manage hidden" sheet can render each
/// hidden channel's name + logo. Stream IDs that no longer exist in
/// the live catalogue (e.g. the provider removed them) are dropped
/// silently. Resolves to an empty list when there's no active
/// connection, no live streams, or no hidden set.
///
/// Sorted by channel name (case-insensitive asc) so the sheet is
/// stable when the user unhides channels one at a time — same UX as
/// the "Name (A–Z)" sort mode for the visible channel list.
final hiddenChannelsStreamProvider =
    FutureProvider<List<XtreamStream>>((ref) async {
  final hiddenIds = ref.watch(activeProfileHiddenProvider).toSet();
  if (hiddenIds.isEmpty) return const <XtreamStream>[];
  final live = await ref.watch(liveStreamsProvider.future).catchError(
        (_) => const <XtreamStream>[],
      );
  if (live.isEmpty) return const <XtreamStream>[];
  final filtered = live.where((s) => hiddenIds.contains(s.streamId)).toList()
    ..sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
  return filtered;
});

/// V19: Bulk-unhide helper for the "Manage hidden" sheet. Removes
/// every hidden stream ID for the active profile, persists the empty
/// list via [ProfileStore.setHidden], and invalidates the hidden
/// family provider so the channel list and the sheet both rebuild.
/// Returns the number of channels that were unhidden.
Future<int> unhideAll(WidgetRef ref) async {
  final activeProfile = ref.read(activeProfileProvider);
  if (activeProfile == null) return 0;
  final store = ref.read(profileStoreProvider);
  final current = store.getHidden(activeProfile.id);
  if (current.isEmpty) return 0;
  await store.setHidden(activeProfile.id, const <int>[]);
  ref.invalidate(profileHiddenProvider(activeProfile.id));
  return current.length;
}

/// Recent channels, isolated per profile.
final recentChannelsPerProfileProvider =
    StateNotifierProvider.family<RecentChannelsNotifier, List<XtreamStream>, String>(
  (ref, profileId) => RecentChannelsNotifier(),
);

/// Shorthand for the active profile's recent channels.
final activeRecentChannelsProvider = Provider<List<XtreamStream>>((ref) {
  final activeProfile = ref.watch(activeProfileProvider);
  if (activeProfile == null) return [];
  return ref.watch(recentChannelsPerProfileProvider(activeProfile.id));
});

// ── Debug logs ─────────────────────────────────────────────────────────────

class DebugLogState {
  final bool enabled;
  final List<String> lines;
  const DebugLogState({this.enabled = true, this.lines = const []});
  DebugLogState copyWith({bool? enabled, List<String>? lines}) =>
      DebugLogState(enabled: enabled ?? this.enabled, lines: lines ?? this.lines);
}

class DebugLogNotifier extends StateNotifier<DebugLogState> {
  DebugLogNotifier() : super(const DebugLogState()) {
    _subscribe();
  }

  void _subscribe() {
    DebugLogService.instance.stream.listen((line) {
      // Keep last 500 lines to prevent memory growth.
      final updated = [...state.lines.take(499), line];
      state = state.copyWith(lines: updated);
    });
  }

  void setEnabled(bool value) {
    DebugLogService.instance.enabled = value;
    state = state.copyWith(enabled: value);
  }

  void clear() {
    state = state.copyWith(lines: []);
  }
}

final debugLogProvider = StateNotifierProvider<DebugLogNotifier, DebugLogState>((ref) {
  return DebugLogNotifier();
});

// ── Search ─────────────────────────────────────────────────────────────────

/// Singleton search index shared across the app.
final searchServiceProvider = Provider<SearchService>((ref) {
  return SearchService();
});

/// Query string for search.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Triggers rebuild when live or VOD streams change.
final searchIndexRebuilderProvider = FutureProvider<void>((ref) async {
  // Watch all three providers so we re-index when any of them change.
  final liveAsync = ref.watch(liveStreamsProvider);
  final vodAsync = ref.watch(vodStreamsProvider);
  final seriesAsync = ref.watch(seriesStreamsProvider);

  final live = liveAsync.valueOrNull ?? [];
  final vod = vodAsync.valueOrNull ?? [];
  final series = seriesAsync.valueOrNull ?? [];

  final index = ref.read(searchServiceProvider);
  index.rebuild(live: live, vod: vod, series: series);
});

/// One "Most Watched" entry: the resolved stream + its play count.
class MostWatchedEntry {
  final XtreamStream stream;
  final int count;
  const MostWatchedEntry({required this.stream, required this.count});
}

/// Maximum number of cards surfaced in each home personalisation row
/// (Recently Played + Most Watched + Continue Watching). Kept in one
/// place so V22's recency-vs-frequency dedupe stays in sync with the
/// row widget caps — `mostWatchedProvider` reads the same N to compute
/// the overlap-exclusion set, so changing the cap here updates both
/// rows in lockstep.
const int kPersonalisationRowCap = 8;

/// Top N most-watched live channels for the active profile, ordered by
/// play count desc. Resolves each top streamId against the loaded live
/// streams list — drops orphans (e.g. items removed from the server).
/// Keyed by the active connection's `name` so each profile has its own
/// ranking.
///
/// V22: also watches [recentlyPlayedProvider] and excludes any stream
/// that already appears in the top [kPersonalisationRowCap] recency
/// entries. The recency row is the "fresher" personalisation signal
/// (a user who just played CNN 30 seconds ago wants CNN in Recently
/// Played, not duplicated into Most Watched). If a channel is not in
/// the recency set it still surfaces in Most Watched; if the recency
/// row already covers ≥ N unique channels the Most Watched row hides
/// entirely (it would only contain duplicates of channels the user
/// just saw). Awaiting both providers' `.future` means the dedupe is
/// deterministic — both rows can't be in a half-loaded state where
/// one has data and the other doesn't.
final mostWatchedProvider = FutureProvider<List<MostWatchedEntry>>((ref) async {
  final creds = await ref.watch(activeCredentialsProvider.future);
  if (creds == null) return const [];
  final store = ref.watch(playCountStoreProvider);
  final raw = store.topEntries(creds.name);
  if (raw.isEmpty) return const [];

  // Await live streams rather than reading `valueOrNull` — the latter
  // would be null on the first tick before the future completes and
  // we'd silently return an empty list.
  final live = await ref.watch(liveStreamsProvider.future);
  if (live.isEmpty) return const [];
  final byId = {for (final s in live) s.streamId: s};

  // V22: compute the recency-overlap exclusion set. Watching the
  // recency provider here means mostWatchedProvider re-runs when
  // recency changes (e.g. after a new play) — Riverpod's default
  // auto-dispose would re-watch on every build, but since both
  // providers are keepAlive-decorated upstream the dependency is
  // stable.
  final recent = await ref.watch(recentlyPlayedProvider.future);
  final excludeIds = <int>{
    for (final r in recent.take(kPersonalisationRowCap)) r.stream.streamId,
  };

  final out = <MostWatchedEntry>[];
  for (final e in raw) {
    final s = byId[e.streamId];
    if (s == null) continue; // dropped: not a live channel any more
    if (excludeIds.contains(e.streamId)) continue; // V22: recency row already shows it
    out.add(MostWatchedEntry(stream: s, count: e.count));
    if (out.length >= kPersonalisationRowCap) break;
  }
  return out;
});

/// V20: One "Recently Played" entry: the resolved stream + its last-played
/// epoch-ms timestamp. Pairs with [recentlyPlayedProvider] (the home row
/// counterpart to [mostWatchedProvider]). Timestamp is the wall-clock ms
/// recorded by [PlayCountStore.increment] on every 30s progress save +
/// player dispose.
class RecentlyPlayedEntry {
  final XtreamStream stream;
  final int lastPlayedAtMs;
  const RecentlyPlayedEntry({
    required this.stream,
    required this.lastPlayedAtMs,
  });
}

/// V20: Up to N most-recently-played live channels for the active profile,
/// ordered by recency desc (ties broken by streamId asc via
/// [PlayCountStore.recentEntries]). Resolves each streamId against the
/// loaded live streams list — drops orphans (e.g. items removed from the
/// server). Keyed by the active connection's `name` so each profile has
/// its own recency list.
///
/// Mirrors the [mostWatchedProvider] shape but ordered by recency, not
/// lifetime count — a casual viewer flipping between a few channels wants
/// recency; a power user with hundreds of plays wants the lifetime
/// leaderboard. Both rows coexist on the home screen.
final recentlyPlayedProvider =
    FutureProvider<List<RecentlyPlayedEntry>>((ref) async {
  final creds = await ref.watch(activeCredentialsProvider.future);
  if (creds == null) return const [];
  final store = ref.watch(playCountStoreProvider);
  final raw = store.recentEntries(creds.name);
  if (raw.isEmpty) return const [];

  // Await live streams rather than reading `valueOrNull` — the latter
  // would be null on the first tick before the future completes and
  // we'd silently return an empty list.
  final live = await ref.watch(liveStreamsProvider.future);
  if (live.isEmpty) return const [];
  final byId = {for (final s in live) s.streamId: s};

  final out = <RecentlyPlayedEntry>[];
  for (final e in raw) {
    final s = byId[e.streamId];
    if (s == null) continue; // dropped: not a live channel any more
    out.add(RecentlyPlayedEntry(stream: s, lastPlayedAtMs: e.lastPlayedAtMs));
  }
  return out;
});

/// Search results derived from query + index.
/// Depends on searchIndexRebuilderProvider to ensure index is built first.
final searchResultsProvider = Provider<List<SearchResult>>((ref) {
  // Depend on the index builder to ensure it's been built.
  ref.watch(searchIndexRebuilderProvider);
  final query = ref.watch(searchQueryProvider);
  final index = ref.read(searchServiceProvider);
  return index.search(query);
});
