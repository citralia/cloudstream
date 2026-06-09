import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudstream_app/core/network/xtream_client.dart';
import 'package:cloudstream_app/core/storage/channel_sort_store.dart';
import 'package:cloudstream_app/core/storage/profile_store.dart';
import 'package:cloudstream_app/presentation/providers/app_providers.dart';

/// Test double for [XtreamApiClient] that returns a fixed stream list
/// regardless of category filter.
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
  group('ChannelSortStore persistence', () {
    test('load returns defaultOrder when nothing is saved', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = ChannelSortStore(prefs);
      expect(store.load(), ChannelSortMode.defaultOrder);
    });

    test('save then load returns the saved mode', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = ChannelSortStore(prefs);
      await store.save(ChannelSortMode.name);
      expect(store.load(), ChannelSortMode.name);
      await store.save(ChannelSortMode.number);
      expect(store.load(), ChannelSortMode.number);
    });

    test('falls back to defaultOrder when the saved value is unknown', () async {
      // Simulate a future build that removed a mode: an unrecognised
      // string in the prefs file should silently fall back rather
      // than crash.
      SharedPreferences.setMockInitialValues({
        'channel_sort_mode': 'this_mode_does_not_exist',
      });
      final prefs = await SharedPreferences.getInstance();
      final store = ChannelSortStore(prefs);
      expect(store.load(), ChannelSortMode.defaultOrder);
    });
  });

  group('channelSortProvider', () {
    test('reads the persisted value at construction time', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = ChannelSortStore(prefs);
      await store.save(ChannelSortMode.name);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(channelSortProvider), ChannelSortMode.name);
    });
  });

  group('filteredLiveStreamsProvider sort', () {
    // A deliberately unsorted, mixed-number stream fixture.
    final streams = const [
      XtreamStream(streamId: 1, name: 'BBC One', categoryId: 10,
          streamType: 'live', number: 101),
      XtreamStream(streamId: 2, name: 'CNN', categoryId: 20,
          streamType: 'live', number: 200),
      XtreamStream(streamId: 3, name: 'Zulu TV', categoryId: 20,
          streamType: 'live', number: 50),
      XtreamStream(streamId: 4, name: 'Al Jazeera', categoryId: 10,
          streamType: 'live', number: 77),
      XtreamStream(streamId: 5, name: 'Sky News', categoryId: 20,
          streamType: 'live'), // number == null
    ];

    Future<ProviderContainer> makeContainer({
      ChannelSortMode sort = ChannelSortMode.defaultOrder,
      int? categoryId,
      List<int> favourites = const [],
      bool favouritesOnly = false,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = ChannelSortStore(prefs);
      await store.save(sort);
      final profileStore = ProfileStore(prefs);
      final profile = await profileStore.addProfile(name: 'Test');
      for (final id in favourites) {
        await profileStore.addFavourite(profile.id, id);
      }
      return ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          profileStoreProvider.overrideWithValue(profileStore),
          xtreamClientProvider.overrideWithValue(_FakeXtreamClient(streams)),
          if (categoryId != null)
            selectedCategoryIdProvider.overrideWith((ref) => categoryId),
          if (favouritesOnly)
            favouritesOnlyProvider.overrideWith((ref) => true),
        ],
      );
    }

    test('defaultOrder preserves the Xtream server order', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);
      final result = await container.read(filteredLiveStreamsProvider.future);
      expect(
        result.map((s) => s.streamId).toList(),
        [1, 2, 3, 4, 5],
      );
    });

    test('name mode sorts alphabetically (case-insensitive)', () async {
      final container = await makeContainer(sort: ChannelSortMode.name);
      addTearDown(container.dispose);
      final result = await container.read(filteredLiveStreamsProvider.future);
      expect(
        result.map((s) => s.name).toList(),
        ['Al Jazeera', 'BBC One', 'CNN', 'Sky News', 'Zulu TV'],
      );
    });

    test('number mode sorts by num, null-num entries pushed to bottom',
        () async {
      final container = await makeContainer(sort: ChannelSortMode.number);
      addTearDown(container.dispose);
      final result = await container.read(filteredLiveStreamsProvider.future);
      // Streams with a `number` come first (50, 77, 101, 200);
      // the null-num stream (Sky News, id=5) is pushed to the
      // bottom and sorted by streamId.
      expect(
        result.map((s) => s.streamId).toList(),
        [3, 4, 1, 2, 5],
      );
    });

    test('sort composes with category + favourites filters', () async {
      final container = await makeContainer(
        sort: ChannelSortMode.name,
        categoryId: 20, // CNN (2), Zulu TV (3), Sky News (5)
        favourites: [3, 5],
        favouritesOnly: true,
      );
      addTearDown(container.dispose);
      final result = await container.read(filteredLiveStreamsProvider.future);
      // Intersection is [3, 5]; sorted A–Z is Sky News (5), Zulu TV (3).
      expect(
        result.map((s) => s.streamId).toList(),
        [5, 3],
      );
    });

    test('changing the sort at runtime re-sorts the same streams', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);
      // Initial: default order.
      final initial = await container.read(filteredLiveStreamsProvider.future);
      expect(initial.map((s) => s.streamId).toList(), [1, 2, 3, 4, 5]);
      // Switch to name sort.
      container.read(channelSortProvider.notifier).state = ChannelSortMode.name;
      final resorted = await container.read(filteredLiveStreamsProvider.future);
      expect(
        resorted.map((s) => s.name).toList(),
        ['Al Jazeera', 'BBC One', 'CNN', 'Sky News', 'Zulu TV'],
      );
    });
  });

  group('XtreamStream.fromJson number parsing', () {
    test('parses num as int', () {
      final s = XtreamStream.fromJson({
        'stream_id': 1, 'name': 'Foo', 'category_id': '1',
        'stream_type': 'live', 'num': 42,
      });
      expect(s.number, 42);
    });

    test('parses num as string', () {
      final s = XtreamStream.fromJson({
        'stream_id': 1, 'name': 'Foo', 'category_id': '1',
        'stream_type': 'live', 'num': '101',
      });
      expect(s.number, 101);
    });

    test('null num leaves the field null', () {
      final s = XtreamStream.fromJson({
        'stream_id': 1, 'name': 'Foo', 'category_id': '1',
        'stream_type': 'live',
      });
      expect(s.number, isNull);
    });
  });
}
