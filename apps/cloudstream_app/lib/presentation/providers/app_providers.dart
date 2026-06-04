import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/debug/debug_log_service.dart';
import '../../core/network/xtream_client.dart';
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

final filteredLiveStreamsProvider = FutureProvider<List<XtreamStream>>((ref) async {
  final categoryId = ref.watch(selectedCategoryIdProvider);
  final client = ref.watch(xtreamClientProvider);
  return await client.getLiveStreams(categoryId: categoryId);
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
