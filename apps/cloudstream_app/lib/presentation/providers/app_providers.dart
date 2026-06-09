import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/debug/debug_log_service.dart';
import '../../core/network/xtream_client.dart';
import '../../core/search/search_service.dart';
import '../../core/storage/profile_store.dart';
import '../../core/storage/watch_progress_store.dart';
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
  final client = ref.watch(xtreamClientProvider);
  final streams = await client.getLiveStreams(categoryId: categoryId);
  if (!favouritesOnly) return streams;
  final favIds = ref.watch(activeProfileFavouritesProvider).toSet();
  return streams.where((s) => favIds.contains(s.streamId)).toList();
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

/// Discriminator for the kind of item a [ContinueWatchingEntry] represents.
/// A saved watch-progress id can resolve to either a VOD/series-level
/// stream (the VOD case) or a series episode (resolved against the
/// [SeriesInfoCache] by episode stream id).
enum ContinueWatchingKind { vod, seriesEpisode }

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

  const ContinueWatchingEntry({
    required this.stream,
    required this.progress,
    this.kind = ContinueWatchingKind.vod,
    this.parentSeries,
    this.parentSeason,
    this.episode,
  });
}

/// "Continue Watching" row data for the active connection.
///
/// Resolves every saved watch-progress streamId against the loaded VOD
/// list, the series stream list (for series-level entries), AND the
/// [SeriesInfoCache] (which maps each episode stream id back to its
/// parent series + season/episode). Stream IDs that no longer exist in
/// any of these sources are dropped silently.
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

  // Pre-load the series-info cache for every series in the catalogue.
  // Then we can do a reverse-lookup from any saved episode stream id
  // back to its parent series in O(1) per cache entry. Skipped when
  // the series list is empty (nothing to resolve against).
  final cache = ref.watch(seriesInfoCacheProvider);
  if (series.isNotEmpty) {
    await cache.loadAll(series.map((s) => s.streamId));
  }

  // Build a single lookup over VOD + series (for series-level entries).
  final byId = <int, XtreamStream>{};
  for (final s in vod) {
    byId[s.streamId] = s;
  }
  for (final s in series) {
    byId[s.streamId] = s;
  }

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
      ));
    }
    // else: orphan — drop silently.
  }
  entries.sort((a, b) => b.progress.updatedAt.compareTo(a.progress.updatedAt));
  return entries;
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

/// Search results derived from query + index.
/// Depends on searchIndexRebuilderProvider to ensure index is built first.
final searchResultsProvider = Provider<List<SearchResult>>((ref) {
  // Depend on the index builder to ensure it's been built.
  ref.watch(searchIndexRebuilderProvider);
  final query = ref.watch(searchQueryProvider);
  final index = ref.read(searchServiceProvider);
  return index.search(query);
});
