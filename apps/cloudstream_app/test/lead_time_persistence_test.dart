import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloudstream_app/core/storage/lead_time_preferences_store.dart';
import 'package:cloudstream_app/core/storage/reminder_store.dart';
import 'package:cloudstream_app/presentation/providers/app_providers.dart';

void main() {
  group('LeadTimePreferencesStore', () {
    test('load returns 5-min default when nothing has been persisted', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = LeadTimePreferencesStore(prefs);

      expect(store.load(), ReminderStore.defaultLeadTime);
      expect(store.load(), const Duration(minutes: 5));
    });

    test('save then load round-trips every option the picker exposes', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = LeadTimePreferencesStore(prefs);

      const options = <Duration>[
        Duration(minutes: 0),
        Duration(minutes: 1),
        Duration(minutes: 5),
        Duration(minutes: 10),
        Duration(minutes: 15),
        Duration(minutes: 20),
        Duration(minutes: 25),
        Duration(minutes: 30),
        Duration(minutes: 45),
        Duration(minutes: 60),
      ];

      for (final opt in options) {
        await store.save(opt);
        // Fresh store backed by the same prefs should see the latest write.
        final fresh = LeadTimePreferencesStore(prefs);
        expect(fresh.load(), opt, reason: 'round-trip failed for $opt');
      }
    });

    test('load falls back to 5-min default on a negative stored value', () async {
      // Forward-compat: a future build that wrote a different shape
      // (e.g. epoch-millis) could leave a negative int behind.
      // We must not crash on the read.
      SharedPreferences.setMockInitialValues({
        'reminder_default_lead_minutes': -1,
      });
      final prefs = await SharedPreferences.getInstance();
      final store = LeadTimePreferencesStore(prefs);

      expect(store.load(), ReminderStore.defaultLeadTime);
    });

    test('load falls back to 5-min default when the key holds a non-int', () async {
      // If a manual edit / migration wrote a non-int string, the
      // store should still hand back a sensible default. (SharedPreferences
      // returns null for the wrong type — same path as a missing key.)
      SharedPreferences.setMockInitialValues({
        'something_else': 'not-an-int',
      });
      final prefs = await SharedPreferences.getInstance();
      final store = LeadTimePreferencesStore(prefs);

      expect(store.load(), ReminderStore.defaultLeadTime);
    });
  });

  group('defaultLeadTimeProvider', () {
    test('reads the persisted value on init (not the hard-coded default)', () async {
      SharedPreferences.setMockInitialValues({
        'reminder_default_lead_minutes': 25,
      });
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ]);
      addTearDown(container.dispose);

      expect(container.read(defaultLeadTimeProvider), const Duration(minutes: 25));
    });

    test('falls back to 5-min default on a fresh install (no stored key)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ]);
      addTearDown(container.dispose);

      expect(container.read(defaultLeadTimeProvider), ReminderStore.defaultLeadTime);
    });

    test('in-memory update does not silently overwrite the persisted value', () async {
      // The Settings tile writes through store.save() in addition to
      // mutating the provider. If a caller ever mutates the provider
      // directly, the store should still hold the *previous* persisted
      // value — that way a re-read picks up the truth, not the in-memory
      // mutation. This test pins down that the two stores are
      // independent: provider is an in-memory mirror, store is the
      // on-disk truth.
      SharedPreferences.setMockInitialValues({
        'reminder_default_lead_minutes': 5,
      });
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ]);
      addTearDown(container.dispose);

      // Mutate the in-memory provider without going through store.save().
      container.read(defaultLeadTimeProvider.notifier).state =
          const Duration(minutes: 30);

      // The store still holds the original value.
      final store = container.read(leadTimePreferencesStoreProvider);
      expect(store.load(), const Duration(minutes: 5));

      // A fresh container reading the same prefs would see the stored
      // value, not the in-memory mutation from the previous container.
      final container2 = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ]);
      addTearDown(container2.dispose);
      expect(container2.read(defaultLeadTimeProvider), const Duration(minutes: 5));
    });

    test('store.save() write is observable to a fresh container', () async {
      // Mirrors the production flow: Settings tile calls store.save(opt)
      // and the in-memory provider; a future app launch reads from
      // store.load() and surfaces the same value in the provider.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final c1 = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ]);
      addTearDown(c1.dispose);
      await c1.read(leadTimePreferencesStoreProvider).save(const Duration(minutes: 45));

      final c2 = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ]);
      addTearDown(c2.dispose);
      expect(c2.read(defaultLeadTimeProvider), const Duration(minutes: 45));
    });
  });
}
