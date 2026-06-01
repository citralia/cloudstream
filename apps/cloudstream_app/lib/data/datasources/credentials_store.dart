import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores Xtream credentials securely in iOS Keychain / Android Keystore.
class CredentialsStore {
  static const _serverUrlKey = 'xtream_server_url';
  static const _usernameKey = 'xtream_username';
  static const _passwordKey = 'xtream_password';
  static const _activeConnectionKey = 'xtream_active_connection';

  final FlutterSecureStorage _storage;

  CredentialsStore() : _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// Save a connection profile.
  Future<void> saveConnection({
    required String name,
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    await _storage.write(key: _serverUrlKey, value: serverUrl);
    await _storage.write(key: _usernameKey, value: username);
    await _storage.write(key: _passwordKey, value: password);
    await _storage.write(key: _activeConnectionKey, value: name);
  }

  /// Load stored credentials. Returns null if none saved.
  Future<XtreamCredentials?> loadCredentials() async {
    final serverUrl = await _storage.read(key: _serverUrlKey);
    final username = await _storage.read(key: _usernameKey);
    final password = await _storage.read(key: _passwordKey);

    if (serverUrl == null || username == null || password == null) {
      return null;
    }

    return XtreamCredentials(
      serverUrl: serverUrl,
      username: username,
      password: password,
      name: await _storage.read(key: _activeConnectionKey),
    );
  }

  /// Delete stored credentials (on logout).
  Future<void> clearCredentials() async {
    await _storage.delete(key: _serverUrlKey);
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _passwordKey);
    await _storage.delete(key: _activeConnectionKey);
  }

  /// Returns true if credentials are stored.
  Future<bool> hasCredentials() async {
    final serverUrl = await _storage.read(key: _serverUrlKey);
    return serverUrl != null;
  }
}

class XtreamCredentials {
  final String serverUrl;
  final String username;
  final String password;
  final String? name;

  const XtreamCredentials({
    required this.serverUrl,
    required this.username,
    required this.password,
    this.name,
  });
}
