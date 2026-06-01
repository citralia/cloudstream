import 'package:dio/dio.dart';
import '../constants/api_config.dart';

/// HTTP client configured for the CloudStream API.
class ApiClient {
  late final Dio _dio;
  String? _authToken;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: Duration(seconds: ApiConfig.timeoutSeconds),
      receiveTimeout: Duration(seconds: ApiConfig.timeoutSeconds),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
  }

  /// Set the Bearer token after login.
  void setAuthToken(String token) {
    _authToken = token;
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Clear the token (on logout).
  void clearAuthToken() {
    _authToken = null;
    _dio.options.headers.remove('Authorization');
  }

  bool get hasAuthToken => _authToken != null;

  // ── Auth ────────────────────────────────────────────────

  Future<Response> login({
    required String serverUrl,
    required String username,
    required String password,
  }) {
    return _dio.post('/api/auth/login', data: {
      'server_url': serverUrl,
      'username': username,
      'password': password,
    });
  }

  Future<Response> logout() => _dio.post('/api/auth/logout');

  Future<Response> getMe() => _dio.get('/api/auth/me');

  // ── Channels ─────────────────────────────────────────────

  Future<Response> getChannels({int? categoryId}) {
    return _dio.get('/api/channels', queryParameters: {
      if (categoryId != null) 'category_id': categoryId,
    });
  }

  Future<Response> getChannel(int channelId) {
    return _dio.get('/api/channels/$channelId');
  }

  // ── Categories ───────────────────────────────────────────

  Future<Response> getCategories() => _dio.get('/api/categories');

  // ── EPG ────────────────────────────────────────────────

  Future<Response> getEpg({int? channelId, int hours = 24}) {
    return _dio.get('/api/epg', queryParameters: {
      if (channelId != null) 'channel_id': channelId,
      'hours': hours,
    });
  }

  Future<Response> refreshEpg({int? channelId}) {
    return _dio.post('/api/epg/refresh', queryParameters: {
      if (channelId != null) 'channel_id': channelId,
    });
  }

  // ── Stream ──────────────────────────────────────────────

  /// Returns the redirect URL to the m3u8 stream.
  Future<Response> getStreamUrl(int channelId) {
    return _dio.get('/api/stream/$channelId');
  }

  /// Returns the manifest URL for HLS playback.
  Future<Response> getStreamManifest(int channelId) {
    return _dio.get('/api/stream/$channelId/manifest');
  }
}
