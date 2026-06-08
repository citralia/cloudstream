import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudstream_app/core/network/xtream_client.dart';
import 'package:cloudstream_app/core/storage/profile_store.dart';
import 'package:cloudstream_app/domain/entities/profile.dart';
import 'package:cloudstream_app/presentation/providers/app_providers.dart';

/// Test double for [XtreamApiClient] that returns a fixed stream list.
class _FakeXtreamClient extends XtreamApiClient {
  _FakeXtreamClient(this._streams);

  final List<XtreamStream> _streams;

  @override
  Future<List<XtreamStream>> getLiveStreams({int? categoryId}) async {
    if (categoryId == null) return _streams;
    return _streams.where((s) => s.categoryId == categoryId).toList();
  }
}

void main() {
  group('ProfileStore favourites persistence', () {
    late ProfileStore store;
    late Profile profile;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      store = ProfileStore(prefs);
      profile = await store.addProfile(name: 'Test');
    });

    test('starts with empty favourites', () {
      expect(store.getFavourites(profile.id), isEmpty);
    });

    test('addFavourite persists a stream ID', () async {
      await store.addFavourite(profile.id, 42);
      expect(store.getFavourites(profile.id), [42]);
    });

    test('addFavourite is idempotent', () async {
      await store.addFavourite(profile.id, 42);
      await store.addFavourite(profile.id, 42);
      expect(store.getFavourites(profile.id), [42]);
    });

    test('removeFavourite removes the stream ID', () async {
      await store.addFavourite(profile.id, 42);
      await store.addFavourite(profile.id, 99);
      await store.removeFavourite(profile.id, 42);
      expect(store.getFavourites(profile.id), [99]);
    });

    test('toggleFavourite returns true then false', () async {
      final first = await store.toggleFavourite(profile.id, 7);
      final second = await store.toggleFavourite(profile.id, 7);
      expect(first, isTrue);
      expect(second, isFalse);
      expect(store.getFavourites(profile.id), isEmpty);
    });

    test('favourites are isolated per profile', () async {
      final other = await store.addProfile(name: 'Other');
      await store.addFavourite(profile.id, 1);
      await store.addFavourite(other.id, 2);
      expect(store.getFavourites(profile.id), [1]);
      expect(store.getFavourites(other.id), [2]);
    });
  });

  group('favouritesOnlyProvider filter', () {
    final streams = const [
      XtreamStream(streamId: 1, name: 'BBC One', categoryId: 10, streamType: 'live'),
      XtreamStream(streamId: 2, name: 'ITV', categoryId: 10, streamType: 'live'),
      XtreamStream(streamId: 3, name: 'Sky News', categoryId: 20, streamType: 'live'),
      XtreamStream(streamId: 4, name: 'CNN', categoryId: 20, streamType: 'live'),
    ];

    Future<ProviderContainer> makeContainer({
      required List<int> favourites,
      bool favouritesOnly = false,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = ProfileStore(prefs);
      // Always create at least one profile so active profile resolves.
      final profile = await store.addProfile(name: 'Test');
      for (final id in favourites) {
        await store.addFavourite(profile.id, id);
      }
      return ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          profileStoreProvider.overrideWithValue(store),
          xtreamClientProvider.overrideWithValue(_FakeXtreamClient(streams)),
          if (favouritesOnly)
            favouritesOnlyProvider.overrideWith((ref) => true),
        ],
      );
    }

    test('returns all streams when favouritesOnly is false', () async {
      final container = await makeContainer(favourites: [1, 3]);
      addTearDown(container.dispose);
      final result = await container.read(filteredLiveStreamsProvider.future);
      expect(result.length, 4);
    });

    test('filters to favourites when favouritesOnly is true', () async {
      final container = await makeContainer(
        favourites: [1, 3],
        favouritesOnly: true,
      );
      addTearDown(container.dispose);
      final result = await container.read(filteredLiveStreamsProvider.future);
      expect(result.map((s) => s.streamId).toList(), [1, 3]);
    });

    test('returns empty list when no favourites set but filter is on', () async {
      final container = await makeContainer(
        favourites: const [],
        favouritesOnly: true,
      );
      addTearDown(container.dispose);
      final result = await container.read(filteredLiveStreamsProvider.future);
      expect(result, isEmpty);
    });

    test('combining category filter and favourites filter', () async {
      final container = await makeContainer(
        favourites: [1, 3],
        favouritesOnly: true,
      );
      addTearDown(container.dispose);
      // Apply category 10 — should intersect with favourites [1, 3] to give [1].
      container.read(selectedCategoryIdProvider.notifier).state = 10;
      final result = await container.read(filteredLiveStreamsProvider.future);
      expect(result.map((s) => s.streamId).toList(), [1]);
    });
  });
}
