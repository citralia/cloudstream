import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../models/channel_model.dart';
import '../models/category_model.dart';
import '../models/programme_model.dart';
import '../models/user_model.dart';

/// Thrown when API returns an auth error.
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override String toString() => 'AuthException: $message';
}

/// Thrown when the API returns an error.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, {this.statusCode});
  @override String toString() => 'ApiException($statusCode): $message';
}

/// Handles all API communication. Throws typed exceptions on failure.
class CloudStreamRemoteDataSource {
  final ApiClient _client;

  CloudStreamRemoteDataSource(this._client);

  // ── Auth ────────────────────────────────────────────────

  Future<UserModel> login({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    try {
      final resp = await _client.login(
        serverUrl: serverUrl,
        username: username,
        password: password,
      );
      final data = resp.data as Map<String, dynamic>;
      _client.setAuthToken(data['token'] as String);
      return UserModel.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const AuthException('Invalid credentials');
      }
      throw ApiException(
        e.message ?? 'Login failed',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<void> logout() async {
    try {
      await _client.logout();
    } finally {
      _client.clearAuthToken();
    }
  }

  // ── Channels ─────────────────────────────────────────────

  Future<List<ChannelModel>> getChannels({int? categoryId}) async {
    _requireAuth();
    try {
      final resp = await _client.getChannels(categoryId: categoryId);
      final data = resp.data as Map<String, dynamic>;
      final channels = (data['channels'] as List<dynamic>)
          .map((c) => ChannelModel.fromJson(c as Map<String, dynamic>))
          .toList();
      return channels;
    } on DioException catch (e) {
      throw ApiException(
        e.message ?? 'Failed to fetch channels',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ChannelModel> getChannel(int channelId) async {
    _requireAuth();
    try {
      final resp = await _client.getChannel(channelId);
      return ChannelModel.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const ApiException('Channel not found', statusCode: 404);
      }
      throw ApiException(
        e.message ?? 'Failed to fetch channel',
        statusCode: e.response?.statusCode,
      );
    }
  }

  // ── Categories ─────────────────────────────────────────

  Future<CategoryListResult> getCategories() async {
    _requireAuth();
    try {
      final resp = await _client.getCategories();
      final data = resp.data as Map<String, dynamic>;
      return CategoryListResult(
        live: (data['live'] as List<dynamic>)
            .map((c) => CategoryModel.fromJson(c as Map<String, dynamic>))
            .toList(),
        vod: (data['vod'] as List<dynamic>)
            .map((c) => CategoryModel.fromJson(c as Map<String, dynamic>))
            .toList(),
        series: (data['series'] as List<dynamic>)
            .map((c) => CategoryModel.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
    } on DioException catch (e) {
      throw ApiException(
        e.message ?? 'Failed to fetch categories',
        statusCode: e.response?.statusCode,
      );
    }
  }

  // ── EPG ────────────────────────────────────────────────

  Future<List<EpgChannelModel>> getEpg({int? channelId, int hours = 24}) async {
    _requireAuth();
    try {
      final resp = await _client.getEpg(channelId: channelId, hours: hours);
      final data = resp.data as Map<String, dynamic>;
      return (data['channels'] as List<dynamic>)
          .map((c) => EpgChannelModel.fromJson(c as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException(
        e.message ?? 'Failed to fetch EPG',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<int> refreshEpg({int? channelId}) async {
    _requireAuth();
    try {
      final resp = await _client.refreshEpg(channelId: channelId);
      final data = resp.data as Map<String, dynamic>;
      return data['programmes_cached'] as int? ?? 0;
    } on DioException catch (e) {
      throw ApiException(
        e.message ?? 'Failed to refresh EPG',
        statusCode: e.response?.statusCode,
      );
    }
  }

  // ── Stream ──────────────────────────────────────────────

  Future<String> getStreamManifest(int channelId) async {
    _requireAuth();
    try {
      final resp = await _client.getStreamManifest(channelId);
      final data = resp.data as Map<String, dynamic>;
      return data['manifest_url'] as String;
    } on DioException catch (e) {
      throw ApiException(
        e.message ?? 'Failed to get stream URL',
        statusCode: e.response?.statusCode,
      );
    }
  }

  void _requireAuth() {
    if (!_client.hasAuthToken) {
      throw const AuthException('Not authenticated');
    }
  }
}


class CategoryListResult {
  final List<CategoryModel> live;
  final List<CategoryModel> vod;
  final List<CategoryModel> series;

  const CategoryListResult({
    required this.live,
    required this.vod,
    required this.series,
  });
}

// Dio re-export for use in error handling
