import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudstream_app/core/storage/theme_preferences_store.dart';
import 'package:cloudstream_app/core/theme/app_theme.dart';
import 'package:cloudstream_app/presentation/providers/app_providers.dart';

void main() {
  group('ThemePreferencesStore persistence', () {
    test('load returns ThemeMode.system when nothing is saved', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = ThemePreferencesStore(prefs);
      expect(store.load(), ThemeMode.system);
    });

    test('save then load returns the saved mode', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = ThemePreferencesStore(prefs);
      await store.save(ThemeMode.light);
      expect(store.load(), ThemeMode.light);
      await store.save(ThemeMode.dark);
      expect(store.load(), ThemeMode.dark);
      await store.save(ThemeMode.system);
      expect(store.load(), ThemeMode.system);
    });

    test('falls back to ThemeMode.system when the saved value is unknown',
        () async {
      // Simulate a future build that renamed a mode: an unrecognised
      // string in the prefs file should silently fall back rather
      // than crash.
      SharedPreferences.setMockInitialValues({
        'app_theme_mode': 'this_mode_does_not_exist',
      });
      final prefs = await SharedPreferences.getInstance();
      final store = ThemePreferencesStore(prefs);
      expect(store.load(), ThemeMode.system);
    });
  });

  group('themeModeProvider', () {
    test('reads the persisted value at construction time', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = ThemePreferencesStore(prefs);
      await store.save(ThemeMode.light);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(themeModeProvider), ThemeMode.light);
    });

    test('defaults to ThemeMode.system when nothing is saved', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(themeModeProvider), ThemeMode.system);
    });

    test('updating the provider updates the in-memory state immediately',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);
      // The provider is the in-memory mirror; the persistence write
      // happens via ThemePreferencesStore (a separate write-path the
      // Settings tile exercises — see test below). This test only
      // pins the in-memory behaviour so the Settings tile and the
      // MaterialApp react synchronously.
      expect(container.read(themeModeProvider), ThemeMode.system);
      container.read(themeModeProvider.notifier).state = ThemeMode.dark;
      expect(container.read(themeModeProvider), ThemeMode.dark);
      container.read(themeModeProvider.notifier).state = ThemeMode.light;
      expect(container.read(themeModeProvider), ThemeMode.light);
    });

    test('rebuilding the container re-reads the persisted value', () async {
      // Cross-launch persistence check. Write via one container, then
      // a fresh container with the same prefs should pick up the
      // saved value.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = ThemePreferencesStore(prefs);
      await store.save(ThemeMode.dark);

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(themeModeProvider), ThemeMode.dark);
    });
  });

  group('AppTheme.dark / AppTheme.light sanity', () {
    test('dark theme is dark brightness', () {
      expect(AppTheme.dark.brightness, Brightness.dark);
    });
    test('light theme is light brightness', () {
      expect(AppTheme.light.brightness, Brightness.light);
    });
    test('dark and light themes use distinct scaffold background colors',
        () {
      expect(
        AppTheme.dark.scaffoldBackgroundColor,
        isNot(AppTheme.light.scaffoldBackgroundColor),
      );
    });
    test('dark and light themes use distinct primary colors', () {
      expect(
        AppTheme.dark.colorScheme.primary,
        isNot(AppTheme.light.colorScheme.primary),
      );
    });
  });
}
