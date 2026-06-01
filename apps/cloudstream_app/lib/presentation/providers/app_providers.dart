import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../data/datasources/remote_data_source.dart';
import '../../domain/entities/channel_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../data/models/programme_model.dart';

// ── Core providers ─────────────────────────────────────────

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

final remoteDataSourceProvider = Provider<CloudStreamRemoteDataSource>((ref) {
  return CloudStreamRemoteDataSource(ref.watch(apiClientProvider));
});

// ── Auth state ─────────────────────────────────────────────

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final UserEntity? user;
  final String? error;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.error,
  });

  AuthState copyWith({AuthStatus? status, UserEntity? user, String? error}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final CloudStreamRemoteDataSource _ds;

  AuthNotifier(this._ds) : super(const AuthState());

  Future<void> login({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.unauthenticated, error: null);
    try {
      final user = await _ds.login(
        serverUrl: serverUrl,
        username: username,
        password: password,
      );
      state = AuthState(status: AuthStatus.authenticated, user: user.toEntity());
    } on AuthException catch (e) {
      state = state.copyWith(status: AuthStatus.unauthenticated, error: e.message);
    } on ApiException catch (e) {
      state = state.copyWith(status: AuthStatus.unauthenticated, error: e.message);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: 'Connection error — is the backend running?',
      );
    }
  }

  Future<void> logout() async {
    try {
      await _ds.logout();
    } catch (_) {}
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(remoteDataSourceProvider));
});

// ── Channels ─────────────────────────────────────────────

final channelsProvider = FutureProvider.family<List<ChannelEntity>, int?>((ref, categoryId) async {
  final ds = ref.watch(remoteDataSourceProvider);
  final channels = await ds.getChannels(categoryId: categoryId);
  return channels.map((c) => c.toEntity()).toList();
});

final selectedCategoryProvider = StateProvider<int?>((ref) => null);

// ── Categories ─────────────────────────────────────────────

final categoriesProvider = FutureProvider<CategoryListResult>((ref) async {
  final ds = ref.watch(remoteDataSourceProvider);
  return await ds.getCategories();
});

// ── EPG ───────────────────────────────────────────────

final epgProvider = FutureProvider.family<List<EpgChannelModel>, int?>((ref, channelId) async {
  final ds = ref.watch(remoteDataSourceProvider);
  return await ds.getEpg(channelId: channelId, hours: 24);
});

// ── Stream ─────────────────────────────────────────────

final streamManifestProvider = FutureProvider.family<String, int>((ref, channelId) async {
  final ds = ref.watch(remoteDataSourceProvider);
  return await ds.getStreamManifest(channelId);
});

// ── Selected channel ─────────────────────────────────────────

final selectedChannelProvider = StateProvider<ChannelEntity?>((ref) => null);
