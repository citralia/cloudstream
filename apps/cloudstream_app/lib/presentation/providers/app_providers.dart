import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/debug/debug_log_service.dart';
import '../../core/network/xtream_client.dart';
import '../../data/datasources/credentials_store.dart';
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

  AuthNotifier(this._client, this._store) : super(const AuthState()) {
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
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      // Stored credentials are invalid — clear them
      await _store.clearAll();
      state = const AuthState(status: AuthStatus.unauthenticated);
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
