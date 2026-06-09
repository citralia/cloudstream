import 'package:dio/dio.dart';

/// Direct Xtream Codes API client.
/// All methods call the user's Xtream server directly — no backend relay.
class XtreamApiClient {
  late Dio _dio;
  String? _serverUrl;
  String? _username;
  String? _password;

  XtreamApiClient();

  /// Configure the client with the user's Xtream credentials.
  /// Call this after login and when restoring a stored session.
  void configure({
    required String serverUrl,
    required String username,
    required String password,
  }) {
    // Normalise: strip trailing slash
    _serverUrl = serverUrl.replaceAll(RegExp(r'/$'), '');
    _username = username;
    _password = password;

    _dio = Dio(BaseOptions(
      baseUrl: _serverUrl!,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Accept': 'application/json'},
    ));
  }

  bool get isConfigured => _serverUrl != null && _username != null && _password != null;

  // ── Auth ───────────────────────────────────────────────────────────────

  /// Login to Xtream server.
  /// Throws [XtreamAuthException] on bad credentials.
  /// Returns user info on success.
  Future<XtreamLoginResult> login() async {
    _requireConfigured();
    try {
      final resp = await _dio.get('/player_api.php', queryParameters: {
        'username': _username,
        'password': _password,
      });

      final data = resp.data as Map<String, dynamic>;

      // Check for auth failure
      final userInfo = data['user_info'] as Map<String, dynamic>?;
      if (userInfo == null || userInfo['auth'] == 0) {
        throw XtreamAuthException(
          userInfo?['message'] as String? ?? 'Invalid credentials',
        );
      }

      // Check account status
      final status = userInfo['status'] as String?;
      if (status != 'Active') {
        throw XtreamAuthException('Account is $status');
      }

      return XtreamLoginResult.fromJson(data);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw const XtreamApiException('Connection timed out — check the server URL');
      }
      if (e.response?.statusCode == 404) {
        throw const XtreamApiException('Server not found — check the URL');
      }
      throw XtreamApiException('Connection failed: ${e.message}');
    }
  }

  // ── Live TV ────────────────────────────────────────────────────────────

  /// Fetch all live categories.
  Future<List<XtreamCategory>> getLiveCategories() async {
    _requireConfigured();
    try {
      final resp = await _dio.get('/player_api.php', queryParameters: {
        'username': _username,
        'password': _password,
        'action': 'get_live_categories',
      });
      return (resp.data as List<dynamic>)
          .map((j) => XtreamCategory.fromJson(j as Map<String, dynamic>, type: 'live'))
          .toList();
    } on DioException catch (e) {
      throw XtreamApiException('Failed to fetch categories: ${e.message}');
    }
  }

  /// Fetch live streams, optionally filtered by category.
  Future<List<XtreamStream>> getLiveStreams({int? categoryId}) async {
    _requireConfigured();
    try {
      final params = <String, dynamic>{
        'username': _username,
        'password': _password,
        'action': 'get_live_streams',
      };
      if (categoryId != null) params['category_id'] = categoryId;

      final resp = await _dio.get('/player_api.php', queryParameters: params);
      return (resp.data as List<dynamic>)
          .map((j) => XtreamStream.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw XtreamApiException('Failed to fetch channels: ${e.message}');
    }
  }

  // ── VOD ────────────────────────────────────────────────────────────────

  /// Fetch all VOD categories.
  Future<List<XtreamCategory>> getVodCategories() async {
    _requireConfigured();
    try {
      final resp = await _dio.get('/player_api.php', queryParameters: {
        'username': _username,
        'password': _password,
        'action': 'get_vod_categories',
      });
      return (resp.data as List<dynamic>)
          .map((j) => XtreamCategory.fromJson(j as Map<String, dynamic>, type: 'vod'))
          .toList();
    } on DioException catch (e) {
      throw XtreamApiException('Failed to fetch VOD categories: ${e.message}');
    }
  }

  /// Fetch VOD streams, optionally filtered by category.
  Future<List<XtreamStream>> getVodStreams({int? categoryId}) async {
    _requireConfigured();
    try {
      final params = <String, dynamic>{
        'username': _username,
        'password': _password,
        'action': 'get_vod_streams',
      };
      if (categoryId != null) params['category_id'] = categoryId;

      final resp = await _dio.get('/player_api.php', queryParameters: params);
      return (resp.data as List<dynamic>)
          .map((j) => XtreamStream.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw XtreamApiException('Failed to fetch VOD: ${e.message}');
    }
  }

  /// Fetch single VOD info (includes episodes for series).
  Future<XtreamVodInfo> getVodInfo(int vodId) async {
    _requireConfigured();
    try {
      final resp = await _dio.get('/player_api.php', queryParameters: {
        'username': _username,
        'password': _password,
        'action': 'get_vod_info',
        'vod_id': vodId,
      });
      return XtreamVodInfo.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw XtreamApiException('Failed to fetch VOD info: ${e.message}');
    }
  }

  // ── Series ─────────────────────────────────────────────────────────────

  /// Fetch all series categories.
  Future<List<XtreamCategory>> getSeriesCategories() async {
    _requireConfigured();
    try {
      final resp = await _dio.get('/player_api.php', queryParameters: {
        'username': _username,
        'password': _password,
        'action': 'get_series_categories',
      });
      return (resp.data as List<dynamic>)
          .map((j) => XtreamCategory.fromJson(j as Map<String, dynamic>, type: 'series'))
          .toList();
    } on DioException catch (e) {
      throw XtreamApiException('Failed to fetch series categories: ${e.message}');
    }
  }

  /// Fetch series streams, optionally filtered by category.
  ///
  /// Xtream returns the catalogue of series for the active playlist — each
  /// item is an [XtreamStream] with `stream_type == 'series'` and a
  /// `series_id` (encoded into [XtreamStream.streamId] since both fields are
  /// numeric identifiers in the Xtream catalogue).
  Future<List<XtreamStream>> getSeriesStreams({int? categoryId}) async {
    _requireConfigured();
    try {
      final params = <String, dynamic>{
        'username': _username,
        'password': _password,
        'action': 'get_series',
      };
      if (categoryId != null) params['category_id'] = categoryId;

      final resp = await _dio.get('/player_api.php', queryParameters: params);
      return (resp.data as List<dynamic>)
          .map((j) => XtreamStream.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw XtreamApiException('Failed to fetch series: ${e.message}');
    }
  }

  /// Fetch series info (includes seasons + episodes).
  Future<XtreamSeriesInfo> getSeriesInfo(int seriesId) async {
    _requireConfigured();
    try {
      final resp = await _dio.get('/player_api.php', queryParameters: {
        'username': _username,
        'password': _password,
        'action': 'get_series_info',
        'series_id': seriesId,
      });
      return XtreamSeriesInfo.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw XtreamApiException('Failed to fetch series info: ${e.message}');
    }
  }

  // ── EPG ───────────────────────────────────────────────────────────────

  /// Fetch EPG for a specific stream.
  Future<List<XtreamEpgEntry>> getEpg(int streamId) async {
    _requireConfigured();
    try {
      final resp = await _dio.get('/player_api.php', queryParameters: {
        'username': _username,
        'password': _password,
        'action': 'get_epg',
        'stream_id': streamId,
      });
      final data = resp.data as Map<String, dynamic>;
      final listings = data['epg_listings'] as List<dynamic>? ?? [];
      return listings
          .map((j) => XtreamEpgEntry.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw XtreamApiException('Failed to fetch EPG: ${e.message}');
    }
  }

  // ── Stream URLs ───────────────────────────────────────────────────────

  /// Build the live stream URL for a given stream_id.
  String buildLiveStreamUrl(int streamId) {
    _requireConfigured();
    return '${_serverUrl!}/live/${_username}/${_password}/$streamId.m3u8';
  }

  /// Build the VOD stream URL.
  String buildVodStreamUrl(int streamId) {
    _requireConfigured();
    return '${_serverUrl!}/movie/${_username}/${_password}/$streamId.m3u8';
  }

  /// Build the series episode stream URL.
  String buildSeriesStreamUrl(int episodeStreamId) {
    _requireConfigured();
    return '${_serverUrl!}/series/${_username}/${_password}/$episodeStreamId.m3u8';
  }

  /// Build a catch-up stream URL for a given stream and start timestamp.
  ///
  /// The [startTime] should be the programme's scheduled start time (from EPG).
  /// The server will serve the HLS stream from that point.
  String buildCatchupStreamUrl(int streamId, DateTime startTime) {
    _requireConfigured();
    final startEpoch = startTime.millisecondsSinceEpoch ~/ 1000;
    return '${_serverUrl!}/live/${_username}/${_password}/$streamId.m3u8?start=$startEpoch';
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  void _requireConfigured() {
    if (!isConfigured) {
      throw const XtreamApiException('Not configured — call configure() first');
    }
  }
}

// ── Data models ────────────────────────────────────────────────────────────

class XtreamLoginResult {
  final String username;
  final String status;
  final String expiryDate;
  final bool isTrial;
  final int activeConnections;
  final int maxConnections;
  final List<String> allowedOutputFormats;
  final String authToken;

  const XtreamLoginResult({
    required this.username,
    required this.status,
    required this.expiryDate,
    required this.isTrial,
    required this.activeConnections,
    required this.maxConnections,
    required this.allowedOutputFormats,
    required this.authToken,
  });

  factory XtreamLoginResult.fromJson(Map<String, dynamic> json) {
    final userInfo = json['user_info'] as Map<String, dynamic>;
    final authToken = (json['user_auth'] as Map<String, dynamic>?)?['auth_token'] as String? ?? '';

    return XtreamLoginResult(
      username: userInfo['username'] as String? ?? '',
      status: userInfo['status'] as String? ?? 'Unknown',
      expiryDate: userInfo['exp_date'] is int
          ? DateTime.fromMillisecondsSinceEpoch(
              (userInfo['exp_date'] as int) * 1000,
            ).toIso8601String()
          : userInfo['exp_date'] as String? ?? '',
      isTrial: (userInfo['trial'] as int? ?? 0) == 1,
      activeConnections: userInfo['active_cons'] as int? ?? 0,
      maxConnections: userInfo['max_connections'] as int? ?? 1,
      allowedOutputFormats: (userInfo['allowed_output_formats'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['m3u8'],
      authToken: authToken,
    );
  }
}

class XtreamCategory {
  final int id;
  final String name;
  final String type; // 'live', 'vod', 'series'

  const XtreamCategory({
    required this.id,
    required this.name,
    required this.type,
  });

  factory XtreamCategory.fromJson(Map<String, dynamic> json, {required String type}) {
    return XtreamCategory(
      id: int.tryParse(json['category_id']?.toString() ?? '') ?? 0,
      name: json['category_name'] as String? ?? '',
      type: type,
    );
  }
}

class XtreamStream {
  final int streamId;
  final String name;
  final String? logo;
  final int categoryId;
  final String streamType; // 'live', 'movie', 'series'
  final String? epgChannel; // for live: maps to EPG
  /// Optional channel number as supplied by the provider (Xtream's
  /// `num` field on the live-streams JSON). Many providers populate
  /// this with the playlist's channel number; when null we fall back
  /// to [streamId] for sorting. Defaults to null so the change is
  /// source-compatible with existing call sites and tests.
  ///
  /// Named `number` rather than `num` to avoid shadowing the Dart
  /// built-in `num` type, which would make `num`-typed expressions
  /// like `json['num'] is num` ambiguous in the constructor below.
  final int? number;

  const XtreamStream({
    required this.streamId,
    required this.name,
    this.logo,
    required this.categoryId,
    required this.streamType,
    this.epgChannel,
    this.number,
  });

  factory XtreamStream.fromJson(Map<String, dynamic> json) {
    return XtreamStream(
      streamId: json['stream_id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Unknown',
      logo: json['stream_icon'] as String? ?? json['logo'] as String?,
      categoryId: int.tryParse(json['category_id']?.toString() ?? '') ?? 0,
      streamType: json['stream_type'] as String? ?? 'live',
      epgChannel: json['epg_channel'] as String?,
      number: json['num'] is num
          ? (json['num'] as num).toInt()
          : int.tryParse(json['num']?.toString() ?? ''),
    );
  }
}

class XtreamVodInfo {
  final String name;
  final String? plot;
  final String? cover;
  final String? cast;
  final String? director;
  final String? releaseDate;
  final String? rating;
  final String? duration;
  final List<XtreamSeason> seasons;

  const XtreamVodInfo({
    required this.name,
    this.plot,
    this.cover,
    this.cast,
    this.director,
    this.releaseDate,
    this.rating,
    this.duration,
    this.seasons = const [],
  });

  factory XtreamVodInfo.fromJson(Map<String, dynamic> json) {
    final info = json['info'] as Map<String, dynamic>? ?? {};
    final seasonsData = info['seasons'] as List<dynamic>? ?? [];
    return XtreamVodInfo(
      name: info['name'] as String? ?? json['name'] as String? ?? '',
      plot: info['plot'] as String?,
      cover: info['cover'] as String?,
      cast: info['cast'] as String?,
      director: info['director'] as String?,
      releaseDate: info['releaseDate'] as String?,
      rating: info['rating'] as String?,
      duration: info['duration'] as String?,
      seasons: seasonsData.map((s) => XtreamSeason.fromJson(s as Map<String, dynamic>)).toList(),
    );
  }
}

class XtreamSeason {
  final int seasonNumber;
  final List<XtreamEpisode> episodes;

  const XtreamSeason({required this.seasonNumber, required this.episodes});

  factory XtreamSeason.fromJson(Map<String, dynamic> json) {
    final episodesData = json['episodes'] as List<dynamic>? ?? [];
    return XtreamSeason(
      seasonNumber: json['season_number'] as int? ?? 1,
      episodes: episodesData.map((e) => XtreamEpisode.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class XtreamEpisode {
  final int episodeNumber;
  final String title;
  final String? description;
  final int streamId;
  final int duration;

  const XtreamEpisode({
    required this.episodeNumber,
    required this.title,
    this.description,
    required this.streamId,
    required this.duration,
  });

  factory XtreamEpisode.fromJson(Map<String, dynamic> json) {
    return XtreamEpisode(
      episodeNumber: json['episode_num'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      streamId: json['stream_id'] as int? ?? 0,
      duration: int.tryParse(json['duration']?.toString() ?? '') ?? 0,
    );
  }
}

class XtreamSeriesInfo {
  final String name;
  final String? plot;
  final String? cover;
  final String? cast;
  final String? director;
  final String? releaseDate;
  final String? rating;
  final List<XtreamSeason> seasons;

  const XtreamSeriesInfo({
    required this.name,
    this.plot,
    this.cover,
    this.cast,
    this.director,
    this.releaseDate,
    this.rating,
    this.seasons = const [],
  });

  factory XtreamSeriesInfo.fromJson(Map<String, dynamic> json) {
    final info = json['info'] as Map<String, dynamic>? ?? {};
    final seasonsData = info['seasons'] as List<dynamic>? ?? [];
    return XtreamSeriesInfo(
      name: info['name'] as String? ?? json['name'] as String? ?? '',
      plot: info['plot'] as String?,
      cover: info['cover'] as String?,
      cast: info['cast'] as String?,
      director: info['director'] as String?,
      releaseDate: info['releaseDate'] as String?,
      rating: info['rating'] as String?,
      seasons: seasonsData.map((s) => XtreamSeason.fromJson(s as Map<String, dynamic>)).toList(),
    );
  }
}

class XtreamEpgEntry {
  final String channelId;
  final int start; // unix timestamp
  final int end; // unix timestamp
  final String title;
  final String? description;
  final String? category;
  final String? icon;
  final bool hasCatchup; // true if server allows catch-up for this programme

  const XtreamEpgEntry({
    required this.channelId,
    required this.start,
    required this.end,
    required this.title,
    this.description,
    this.category,
    this.icon,
    this.hasCatchup = false,
  });

  factory XtreamEpgEntry.fromJson(Map<String, dynamic> json) {
    return XtreamEpgEntry(
      channelId: json['channel_id'] as String? ?? '',
      start: int.tryParse(json['start']?.toString() ?? '') ?? 0,
      end: int.tryParse(json['end']?.toString() ?? '') ?? 0,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      category: json['category'] as String?,
      icon: json['icon'] as String?,
      hasCatchup: json['has_catchup'] == 1 || json['has_catchup'] == true,
    );
  }

  DateTime get startTime => DateTime.fromMillisecondsSinceEpoch(start * 1000);
  DateTime get endTime => DateTime.fromMillisecondsSinceEpoch(end * 1000);

  /// True if this programme is currently on air or recently ended (within catch-up window).
  bool get isInCatchupWindow {
    final now = DateTime.now().toUtc();
    return now.isAfter(startTime) && now.isBefore(endTime.add(const Duration(hours: 3)));
  }
}

// ── Exceptions ─────────────────────────────────────────────────────────────

class XtreamAuthException implements Exception {
  final String message;
  const XtreamAuthException(this.message);
  @override String toString() => message;
}

class XtreamApiException implements Exception {
  final String message;
  const XtreamApiException(this.message);
  @override String toString() => message;
}
