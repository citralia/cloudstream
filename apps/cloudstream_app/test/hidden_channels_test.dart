// V18 — "Hide channel" long-press + filter chip.
//
// Tests the V18 hidden-channels feature, which mirrors V05 favourites:
//   * ProfileStore.addHidden / removeHidden / toggleHidden persist per-profile
//   * The active profile's hidden set is excluded from the default channel
//     list (filteredLiveStreamsProvider)
//   * hiddenOnlyProvider reveals hidden channels and excludes everything else
//   * The hidden filter composes with category + favourites-only
//   * The toggle/UNDO round-trip preserves the original list state
//
// Test scope follows the V05 / V09 / V16 pattern: data-layer + Riverpod
// injection tests only (no widget pump). The ChannelTile.onLongPress →
// _openChannelActions sheet wiring is a thin Flutter idiom; the
// data-layer tests below prove the underlying store + provider behaviour.
//
// Test design parallels `favourites_test.dart` so reviewers can compare
// the two patterns side-by-side.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudstream_app/core/network/xtream_client.dart';
import 'package:cloudstream_app/core/storage/profile_store.dart';
import 'package:cloudstream_app/data/datasources/credentials_store.dart';
import 'package:cloudstream_app/domain/entities/profile.dart';
import 'package:cloudstream_app/presentation/providers/app_providers.dart';

// ─── Test doubles ──────────────────────────────────────────────────────

/// Fake Xtream API client that returns a fixed stream list.
class _FakeXtreamClient extends XtreamApiClient {
  _FakeXtreamClient(this._streams);

  final List<XtreamStream> _streams;

  @override
  Future<List<XtreamStream>> getLiveStreams({int? categoryId}) async {
    if (categoryId == null) return _streams;
    return _streams.where((s) => s.categoryId == categoryId).toList();
  }
}

/// In-memory [CredentialsStore] fake. Mirrors the helper in
/// `remove_from_continue_watching_test.dart` / `recently_played_sort_test.dart`.
class _FakeCredentialsStore implements CredentialsStore {
  @override
  Future<List<XtreamCredentials>> listConnections() async => const [];

  @override
  Future<XtreamCredentials?> loadActiveConnection() async => null;

  @override
  Future<void> saveConnection({
    required String name,
    required String serverUrl,
    required String username,
    required String password,
  }) async {}

  @override
  Future<void> deleteConnection(String name) async {}

  @override
  Future<void> setActiveConnection(String name) async {}

  @override
  Future<void> clearAll() async {}
}

void main() {
  group('ProfileStore hidden channels persistence', () {
    late ProfileStore store;
    late Profile profile;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      store = ProfileStore(prefs);
      profile = await store.addProfile(name: 'Test');
    });

    test('starts with empty hidden set', () {
      expect(store.getHidden(profile.id), isEmpty);
    });

    test('addHidden persists a stream ID', () async {
      await store.addHidden(profile.id, 42);
      expect(store.getHidden(profile.id), [42]);
    });

    test('addHidden is idempotent', () async {
      await store.addHidden(profile.id, 42);
      await store.addHidden(profile.id, 42);
      expect(store.getHidden(profile.id), [42]);
    });

    test('removeHidden removes the stream ID', () async {
      await store.addHidden(profile.id, 42);
      await store.addHidden(profile.id, 99);
      await store.removeHidden(profile.id, 42);
      expect(store.getHidden(profile.id), [99]);
    });

    test('removeHidden on a missing ID is a no-op', () async {
      await store.removeHidden(profile.id, 999);
      expect(store.getHidden(profile.id), isEmpty);
    });

    test('toggleHidden returns true then false', () async {
      final first = await store.toggleHidden(profile.id, 7);
      final second = await store.toggleHidden(profile.id, 7);
      expect(first, isTrue);
      expect(second, isFalse);
      expect(store.getHidden(profile.id), isEmpty);
    });

    test('hidden set is isolated per profile', () async {
      final other = await store.addProfile(name: 'Other');
      await store.addHidden(profile.id, 1);
      await store.addHidden(other.id, 2);
      expect(store.getHidden(profile.id), [1]);
      expect(store.getHidden(other.id), [2]);
    });

    test('hidden set survives ProfileStore rehydration', () async {
      await store.addHidden(profile.id, 11);
      await store.addHidden(profile.id, 22);
      // Re-instantiate from the same SharedPreferences to simulate an
      // app restart. The hidden set must round-trip.
      final prefs = await SharedPreferences.getInstance();
      final store2 = ProfileStore(prefs);
      expect(store2.getHidden(profile.id), [11, 22]);
    });
  });

  group('filteredLiveStreamsProvider hidden filtering', () {
    final streams = const [
      XtreamStream(streamId: 1, name: 'BBC One', categoryId: 10, streamType: 'live'),
      XtreamStream(streamId: 2, name: 'ITV', categoryId: 10, streamType: 'live'),
      XtreamStream(streamId: 3, name: 'Sky News', categoryId: 20, streamType: 'live'),
      XtreamStream(streamId: 4, name: 'CNN', categoryId: 20, streamType: 'live'),
    ];

    Future<ProviderContainer> makeContainer({
      required List<int> hidden,
      List<int> favourites = const [],
      bool favouritesOnly = false,
      bool hiddenOnly = false,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = ProfileStore(prefs);
      final profile = await store.addProfile(name: 'Test');
      for (final id in hidden) {
        await store.addHidden(profile.id, id);
      }
      for (final id in favourites) {
        await store.addFavourite(profile.id, id);
      }
      return ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          profileStoreProvider.overrideWithValue(store),
          credentialsStoreProvider.overrideWithValue(_FakeCredentialsStore()),
          xtreamClientProvider.overrideWithValue(_FakeXtreamClient(streams)),
          if (favouritesOnly)
            favouritesOnlyProvider.overrideWith((ref) => true),
          if (hiddenOnly)
            hiddenOnlyProvider.overrideWith((ref) => true),
        ],
      );
    }

    test('excludes hidden channels by default', () async {
      final container = await makeContainer(hidden: [1, 3]);
      addTearDown(container.dispose);
      final result = await container.read(filteredLiveStreamsProvider.future);
      expect(result.map((s) => s.streamId).toList(), [2, 4]);
    });

    test('returns all streams when nothing is hidden', () async {
      final container = await makeContainer(hidden: const []);
      addTearDown(container.dispose);
      final result = await container.read(filteredLiveStreamsProvider.future);
      expect(result.length, 4);
    });

    test('hiddenOnly reveals the hidden set only', () async {
      final container = await makeContainer(hidden: [1, 3], hiddenOnly: true);
      addTearDown(container.dispose);
      final result = await container.read(filteredLiveStreamsProvider.future);
      expect(result.map((s) => s.streamId).toList(), [1, 3]);
    });

    test('hiddenOnly with empty hidden set returns empty', () async {
      final container = await makeContainer(hidden: const [], hiddenOnly: true);
      addTearDown(container.dispose);
      final result = await container.read(filteredLiveStreamsProvider.future);
      expect(result, isEmpty);
    });

    test('composes with category filter', () async {
      final container = await makeContainer(hidden: [1, 3]);
      addTearDown(container.dispose);
      // Category 10 should intersect with "not hidden" to give [2].
      container.read(selectedCategoryIdProvider.notifier).state = 10;
      final result = await container.read(filteredLiveStreamsProvider.future);
      expect(result.map((s) => s.streamId).toList(), [2]);
    });

    test('hiddenOnly composes with category filter', () async {
      final container =
          await makeContainer(hidden: [1, 3, 4], hiddenOnly: true);
      addTearDown(container.dispose);
      // Category 10 should intersect with hidden [1, 3, 4] to give [1].
      container.read(selectedCategoryIdProvider.notifier).state = 10;
      final result = await container.read(filteredLiveStreamsProvider.future);
      expect(result.map((s) => s.streamId).toList(), [1]);
    });

    test('favourites + hidden: favourites only includes not-hidden', () async {
      final container = await makeContainer(
        favourites: [1, 3],
        hidden: [3], // 1 is a favourite, 3 is favourite but hidden
        favouritesOnly: true,
      );
      addTearDown(container.dispose);
      final result = await container.read(filteredLiveStreamsProvider.future);
      expect(result.map((s) => s.streamId).toList(), [1]);
    });

    test('toggling hidden filter on the provider rebuilds the list', () async {
      final container = await makeContainer(hidden: [1, 3]);
      addTearDown(container.dispose);
      // Initial: hidden channels are filtered out.
      final initial = await container.read(filteredLiveStreamsProvider.future);
      expect(initial.map((s) => s.streamId).toList(), [2, 4]);
      // Flip hiddenOnly on — hidden set is revealed.
      container.read(hiddenOnlyProvider.notifier).state = true;
      final revealed = await container.read(filteredLiveStreamsProvider.future);
      expect(revealed.map((s) => s.streamId).toList(), [1, 3]);
      // Flip back off — default view returns.
      container.read(hiddenOnlyProvider.notifier).state = false;
      final restored = await container.read(filteredLiveStreamsProvider.future);
      expect(restored.map((s) => s.streamId).toList(), [2, 4]);
    });
  });

  group('toggleHidden helper round-trip', () {
    // Mirrors the UNDO flow in _openChannelActions: hide → toggle →
    // toggle (via UNDO) → list returns to its original state.
    test('hide then UNDO restores the visible list', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = ProfileStore(prefs);
      final profile = await store.addProfile(name: 'Test');

      // First toggle: hide stream 1.
      final first = await store.toggleHidden(profile.id, 1);
      expect(first, isTrue);
      expect(store.getHidden(profile.id), [1]);

      // UNDO: toggle again to unhide.
      final second = await store.toggleHidden(profile.id, 1);
      expect(second, isFalse);
      expect(store.getHidden(profile.id), isEmpty);
    });
  });
}
