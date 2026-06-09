import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudstream_app/core/theme/app_theme.dart';
import 'package:cloudstream_app/data/datasources/credentials_store.dart';
import 'package:cloudstream_app/core/network/xtream_client.dart';
import 'package:cloudstream_app/core/storage/profile_store.dart';
import 'package:cloudstream_app/presentation/providers/app_providers.dart';
import 'package:cloudstream_app/presentation/screens/debug_logs_screen.dart';
import 'package:cloudstream_app/presentation/screens/profile_switcher_screen.dart';
import 'package:cloudstream_app/presentation/screens/reminders_list_screen.dart';
import 'package:cloudstream_app/presentation/screens/search_screen.dart';

/// V12 follow-on: brightness-aware migration chunk 2 covers
/// settings_screen + profile_switcher_screen + debug_logs_screen +
/// reminders_list_screen + search_screen. These tests verify that
/// each migrated screen (1) renders without throwing in dark and
/// light themes, and (2) the Scaffold background resolves to the
/// brightness-correct token (proving the migration is actually
/// pulling tokens via `context.appColors` and not the dark fallback).
///
/// Pattern note: V11's login_screen_test established one testWidgets
/// per (screen × theme) pair — NOT a loop within a single testWidgets.
/// A loop poisons the WidgetsBinding across the second `pumpWidget`,
/// so the light iteration keeps resolving to the dark theme even with
/// an explicit `themeMode: ThemeMode.light`. This file follows the
/// V11 pattern (separate testWidgets per pair) for that reason.
///
/// SettingsScreen is exercised by the existing `widget_test.dart`
/// smoke test (which pumps the full app) — the heavy auth-notifier
/// mock needed for a standalone Settings test belongs with the
/// auth test, not here.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  /// Wrap a screen in a ProviderScope with the minimum overrides
  /// needed to render it (no real auth / network), and a ThemeData
  /// of the chosen brightness. Explicit `themeMode` prevents the
  /// test environment's default platformBrightness (dark) from
  /// overriding our `theme` choice.
  Widget wrapScreen({required Widget child, required ThemeData theme}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        profileStoreProvider.overrideWithValue(ProfileStore(prefs)),
        credentialsStoreProvider.overrideWithValue(_FakeCredentialsStore()),
        xtreamClientProvider.overrideWithValue(_FakeXtreamClient()),
        authProvider.overrideWith((ref) {
          return _StubAuthNotifier(
            const AuthState(status: AuthStatus.unauthenticated),
          );
        }),
      ],
      child: MaterialApp(
        theme: theme,
        themeMode: theme.brightness == Brightness.light
            ? ThemeMode.light
            : ThemeMode.dark,
        home: child,
      ),
    );
  }

  void setTVSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  Future<void> pumpAndAssertBg(
    WidgetTester tester, {
    required Widget child,
    required ThemeData theme,
  }) async {
    await tester.pumpWidget(wrapScreen(child: child, theme: theme));
    await tester.pump();
    final bg = tester
        .widget<Scaffold>(find.byType(Scaffold))
        .backgroundColor;
    expect(bg, isNotNull,
        reason: '$theme scaffold should have a background colour');
    expect(bg, theme.brightness == Brightness.light
        ? LightAppColors.background
        : AppColors.background,
        reason: '$theme scaffold should pull from the brightness-correct '
            'token class — confirms the migration is live');
  }

  // ---- ProfileSwitcherScreen ----
  testWidgets('ProfileSwitcherScreen renders with dark theme tokens',
      (tester) async {
    setTVSize(tester);
    await pumpAndAssertBg(
      tester,
      child: const ProfileSwitcherScreen(),
      theme: AppTheme.dark,
    );
  });

  testWidgets('ProfileSwitcherScreen renders with light theme tokens',
      (tester) async {
    setTVSize(tester);
    await pumpAndAssertBg(
      tester,
      child: const ProfileSwitcherScreen(),
      theme: AppTheme.light,
    );
  });

  // ---- DebugLogsScreen ----
  testWidgets('DebugLogsScreen renders with dark theme tokens',
      (tester) async {
    setTVSize(tester);
    await pumpAndAssertBg(
      tester,
      child: const DebugLogsScreen(),
      theme: AppTheme.dark,
    );
  });

  testWidgets('DebugLogsScreen renders with light theme tokens',
      (tester) async {
    setTVSize(tester);
    await pumpAndAssertBg(
      tester,
      child: const DebugLogsScreen(),
      theme: AppTheme.light,
    );
  });

  // ---- RemindersListScreen ----
  testWidgets('RemindersListScreen renders with dark theme tokens',
      (tester) async {
    setTVSize(tester);
    await pumpAndAssertBg(
      tester,
      child: const RemindersListScreen(),
      theme: AppTheme.dark,
    );
  });

  testWidgets('RemindersListScreen renders with light theme tokens',
      (tester) async {
    setTVSize(tester);
    await pumpAndAssertBg(
      tester,
      child: const RemindersListScreen(),
      theme: AppTheme.light,
    );
  });

  // ---- SearchScreen ----
  testWidgets('SearchScreen renders with dark theme tokens', (tester) async {
    setTVSize(tester);
    await pumpAndAssertBg(
      tester,
      child: const SearchScreen(),
      theme: AppTheme.dark,
    );
  });

  testWidgets('SearchScreen renders with light theme tokens', (tester) async {
    setTVSize(tester);
    await pumpAndAssertBg(
      tester,
      child: const SearchScreen(),
      theme: AppTheme.light,
    );
  });
}

/// Stub AuthNotifier (mirrors the one in login_screen_test.dart).
class _StubAuthNotifier extends AuthNotifier {
  _StubAuthNotifier(AuthState stub)
      : super(
          _FakeXtreamClient(),
          _FakeCredentialsStore(),
          _NoopProfileStore(),
        ) {
    state = stub;
  }
}

class _FakeXtreamClient implements XtreamApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

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
  Future<void> setActiveConnection(String name) async {}
  @override
  Future<void> deleteConnection(String name) async {}
  @override
  Future<void> clearAll() async {}
}

class _NoopProfileStore implements ProfileStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
