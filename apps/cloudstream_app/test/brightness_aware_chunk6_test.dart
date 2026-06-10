import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudstream_app/core/theme/app_theme.dart';
import 'package:cloudstream_app/core/network/xtream_client.dart';
import 'package:cloudstream_app/data/datasources/credentials_store.dart';
import 'package:cloudstream_app/core/storage/profile_store.dart';
import 'package:cloudstream_app/presentation/providers/app_providers.dart';
import 'package:cloudstream_app/presentation/screens/playlist_screen.dart';

/// V15: brightness-aware migration chunk 3 — closes the V14
/// "should be 0 remaining AppColors refs" claim. The previous
/// cron's bookkeeping was off; the actual sweep found 32 refs
/// across 3 still-un-migrated files:
///
///   - `presentation/screens/playlist_screen.dart` (20 refs) —
///     the connection-management screen accessed from Settings.
///     The "No saved connections" empty state, the connection
///     tiles, the add-connection bottom sheet, the focused
///     button styling, and all the snack-bar colours are now
///     brightness-correct.
///   - `presentation/providers/player_controller_notifier.dart`
///     (6 refs) — the loading placeholder and error display
///     widgets are now brightness-aware. The Chewie progress
///     colours stay hardcoded to `AppColors.*` because the
///     notifier's `setStream` runs without a `BuildContext`
///     (it's a method on a non-Widget StateNotifier). The
///     progress bar lives on top of the black video surface,
///     so the brightness-correct tokens wouldn't be visible
///     anyway — same trade-off V14 chunk 2 made for
///     `player_screen.dart`.
///   - `presentation/players/xtream_stream_session.dart` (6
///     refs) — the errorBuilder callback now resolves
///     brightness-correct tokens via its `BuildContext`. The
///     `ChewieController` config block (progress colours +
///     placeholder spinner) still hardcodes dark tokens for
///     the same reason as the notifier file: `_initController`
///     is a method on a non-Widget class, no `BuildContext`
///     available there, and those colours paint on top of
///     the black video surface.
///
/// Pattern matches V11/V12/V13/V14: one testWidgets per
/// (screen × theme) pair, with shared
/// `pumpAndAssertBg` helper. Explicit `themeMode` to defeat
/// the test env's `platformBrightness` default.
///
/// Test scope for the player files is narrower than for
/// the playlist screen. `_LoadingPlaceholder` and
/// `_ErrorDisplay` are private widgets inside
/// `player_controller_notifier.dart` and are exercised
/// indirectly by the notifier's `setStream` path, which
/// needs a real `VideoPlayerController` (chewie/video_player)
/// and a real network stream. The `errorBuilder` callback in
/// `xtream_stream_session.dart` is the same — the Chewie
/// controller needs real network media to surface an error.
/// Both fall back to the V14 chunk 2 scoping trade-off: prove
/// the source migration is wired (and that the test file
/// compiles cleanly) on the self-contained PlaylistScreen,
/// let the player files be covered by the source change
/// + analyze.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

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

  // ---- PlaylistScreen ----
  testWidgets('PlaylistScreen renders with dark theme tokens',
      (tester) async {
    setTVSize(tester);
    await pumpAndAssertBg(
      tester,
      child: const PlaylistScreen(),
      theme: AppTheme.dark,
    );
  });

  testWidgets('PlaylistScreen renders with light theme tokens',
      (tester) async {
    setTVSize(tester);
    await pumpAndAssertBg(
      tester,
      child: const PlaylistScreen(),
      theme: AppTheme.light,
    );
  });
}

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
