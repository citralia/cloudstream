import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/profile.dart';

/// Persists Profile objects and the active profile ID via SharedPreferences.
class ProfileStore {
  ProfileStore(this._prefs);

  final SharedPreferences _prefs;

  static const _profilesKey = 'profiles';
  static const _activeIdKey = 'active_profile_id';

  // ── CRUD ──────────────────────────────────────────────────────────────────

  /// All stored profiles.
  List<Profile> listProfiles() {
    final raw = _prefs.getString(_profilesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Profile.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Persist the full profiles list.
  Future<void> _saveAll(List<Profile> profiles) async {
    final raw = jsonEncode(profiles.map((p) => p.toJson()).toList());
    await _prefs.setString(_profilesKey, raw);
  }

  /// Add a new profile.
  Future<Profile> addProfile({required String name, int colorIndex = 0}) async {
    final profiles = listProfiles();
    final profile = Profile(
      id: Profile.generateId(),
      name: name,
      colorIndex: colorIndex % kProfileColors.length,
      createdAt: DateTime.now(),
    );
    profiles.add(profile);
    await _saveAll(profiles);
    // Auto-activate if first profile.
    if (profiles.length == 1) {
      await setActiveProfileId(profile.id);
    }
    return profile;
  }

  /// Update an existing profile's name / colour.
  Future<void> updateProfile(Profile updated) async {
    final profiles = listProfiles();
    final idx = profiles.indexWhere((p) => p.id == updated.id);
    if (idx < 0) return;
    profiles[idx] = updated;
    await _saveAll(profiles);
  }

  /// Delete a profile by ID.
  Future<void> deleteProfile(String id) async {
    final profiles = listProfiles();
    profiles.removeWhere((p) => p.id == id);
    await _saveAll(profiles);
    // If we deleted the active one, activate the first remaining.
    if (getActiveProfileId() == id) {
      await setActiveProfileId(profiles.isNotEmpty ? profiles.first.id : '');
    }
  }

  // ── Active profile ────────────────────────────────────────────────────────

  /// ID of the currently active profile (empty string = none).
  String getActiveProfileId() {
    return _prefs.getString(_activeIdKey) ?? '';
  }

  Future<void> setActiveProfileId(String id) async {
    await _prefs.setString(_activeIdKey, id);
  }

  /// The active Profile object, or null.
  Profile? getActiveProfile() {
    final id = getActiveProfileId();
    if (id.isEmpty) return null;
    try {
      return listProfiles().firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── Per-profile state ─────────────────────────────────────────────────────

  /// Keys for a profile's isolated state live under:
  ///   profile_{id}_{suffix}
  /// where suffix is one of: 'favourites', 'recent_channels', 'hidden_channels'.

  static String _profileKey(String profileId, String suffix) =>
      'profile_${profileId}_$suffix';

  /// Get favourite stream IDs for a profile.
  List<int> getFavourites(String profileId) {
    final raw = _prefs.getString(_profileKey(profileId, 'favourites'));
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>).cast<int>();
    } catch (_) {
      return [];
    }
  }

  Future<void> setFavourites(String profileId, List<int> streamIds) async {
    await _prefs.setString(_profileKey(profileId, 'favourites'), jsonEncode(streamIds));
  }

  /// Add a stream ID to favourites for a profile.
  Future<void> addFavourite(String profileId, int streamId) async {
    final favs = getFavourites(profileId);
    if (!favs.contains(streamId)) {
      favs.add(streamId);
      await setFavourites(profileId, favs);
    }
  }

  /// Remove a stream ID from favourites for a profile.
  Future<void> removeFavourite(String profileId, int streamId) async {
    final favs = getFavourites(profileId);
    favs.remove(streamId);
    await setFavourites(profileId, favs);
  }

  /// Toggle a stream ID in/out of favourites for a profile.
  Future<bool> toggleFavourite(String profileId, int streamId) async {
    final favs = getFavourites(profileId);
    if (favs.contains(streamId)) {
      favs.remove(streamId);
      await setFavourites(profileId, favs);
      return false;
    } else {
      favs.add(streamId);
      await setFavourites(profileId, favs);
      return true;
    }
  }

  // ── Hidden channels (V18) ─────────────────────────────────────────────────

  /// Get hidden stream IDs for a profile.
  /// Hidden channels are filtered out of the live TV channel list by default
  /// (and are accessible via the "Hidden" filter chip).
  List<int> getHidden(String profileId) {
    final raw = _prefs.getString(_profileKey(profileId, 'hidden_channels'));
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>).cast<int>();
    } catch (_) {
      return [];
    }
  }

  Future<void> setHidden(String profileId, List<int> streamIds) async {
    await _prefs.setString(
        _profileKey(profileId, 'hidden_channels'), jsonEncode(streamIds));
  }

  /// Add a stream ID to the hidden set for a profile (no-op if already hidden).
  Future<void> addHidden(String profileId, int streamId) async {
    final hidden = getHidden(profileId);
    if (!hidden.contains(streamId)) {
      hidden.add(streamId);
      await setHidden(profileId, hidden);
    }
  }

  /// Remove a stream ID from the hidden set for a profile (no-op if not hidden).
  Future<void> removeHidden(String profileId, int streamId) async {
    final hidden = getHidden(profileId);
    if (hidden.remove(streamId)) {
      await setHidden(profileId, hidden);
    }
  }

  /// Toggle a stream ID in/out of the hidden set for a profile.
  /// Returns the new is-hidden boolean.
  Future<bool> toggleHidden(String profileId, int streamId) async {
    final hidden = getHidden(profileId);
    if (hidden.contains(streamId)) {
      hidden.remove(streamId);
      await setHidden(profileId, hidden);
      return false;
    } else {
      hidden.add(streamId);
      await setHidden(profileId, hidden);
      return true;
    }
  }
}
