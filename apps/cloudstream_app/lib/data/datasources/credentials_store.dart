import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores Xtream credentials securely in iOS Keychain / Android Keystore.
/// Supports multiple named connection profiles.
class CredentialsStore {
  static const _connectionsKey = 'xtream_connections';
  static const _activeIndexKey = 'xtream_active_index';

  final FlutterSecureStorage _storage;

  CredentialsStore() : _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// Save a connection profile (add or update by name).
  Future<void> saveConnection({
    required String name,
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    final connections = await _listConnections();
    final idx = connections.indexWhere((c) => c.name == name);
    final entry = XtreamCredentials(
      name: name,
      serverUrl: serverUrl,
      username: username,
      password: password,
    );
    if (idx >= 0) {
      connections[idx] = entry;
    } else {
      connections.add(entry);
    }
    await _saveAll(connections);
    // If this is the first connection, set it as active
    if (await _loadActiveIndex() == null) {
      await _storage.write(key: _activeIndexKey, value: '0');
    }
  }

  /// Load all stored connections.
  Future<List<XtreamCredentials>> listConnections() async {
    return _listConnections();
  }

  /// Load the active connection (null if none).
  Future<XtreamCredentials?> loadActiveConnection() async {
    final connections = await _listConnections();
    if (connections.isEmpty) return null;
    final idx = await _loadActiveIndex() ?? 0;
    if (idx < 0 || idx >= connections.length) return connections.first;
    return connections[idx];
  }

  /// Set a connection as the active one by name.
  Future<void> setActiveConnection(String name) async {
    final connections = await _listConnections();
    final idx = connections.indexWhere((c) => c.name == name);
    if (idx < 0) return;
    await _storage.write(key: _activeIndexKey, value: idx.toString());
  }

  /// Delete a connection by name.
  Future<void> deleteConnection(String name) async {
    final connections = await _listConnections();
    connections.removeWhere((c) => c.name == name);
    await _saveAll(connections);
    // If we deleted the active one, reset to first available
    final activeIdx = await _loadActiveIndex();
    if (activeIdx != null && activeIdx >= connections.length) {
      await _storage.write(
        key: _activeIndexKey,
        value: connections.isEmpty ? '' : '0',
      );
    }
  }

  /// Delete all stored credentials.
  Future<void> clearAll() async {
    await _storage.delete(key: _connectionsKey);
    await _storage.delete(key: _activeIndexKey);
  }

  // ── Private helpers ─────────────────────────────────────────────────────

  Future<List<XtreamCredentials>> _listConnections() async {
    final raw = await _storage.read(key: _connectionsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => XtreamCredentials.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveAll(List<XtreamCredentials> connections) async {
    final raw = jsonEncode(connections.map((c) => c.toJson()).toList());
    await _storage.write(key: _connectionsKey, value: raw);
  }

  Future<int?> _loadActiveIndex() async {
    final val = await _storage.read(key: _activeIndexKey);
    if (val == null || val.isEmpty) return null;
    return int.tryParse(val);
  }
}

/// A named Xtream connection profile.
class XtreamCredentials {
  final String name;
  final String serverUrl;
  final String username;
  final String password;

  const XtreamCredentials({
    required this.name,
    required this.serverUrl,
    required this.username,
    required this.password,
  });

  XtreamCredentials copyWith({
    String? name,
    String? serverUrl,
    String? username,
    String? password,
  }) {
    return XtreamCredentials(
      name: name ?? this.name,
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'serverUrl': serverUrl,
    'username': username,
    'password': password,
  };

  factory XtreamCredentials.fromJson(Map<String, dynamic> json) {
    return XtreamCredentials(
      name: json['name'] as String? ?? '',
      serverUrl: json['serverUrl'] as String? ?? '',
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
    );
  }
}
