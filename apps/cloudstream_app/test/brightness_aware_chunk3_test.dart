import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudstream_app/core/theme/app_theme.dart';
import 'package:cloudstream_app/data/datasources/credentials_store.dart';
import 'package:cloudstream_app/core/network/xtream_client.dart';
import 'package:cloudstream_app/core/storage/profile_store.dart';
import 'package:cloudstream_app/presentation/providers/app_providers.dart';
import 'package:cloudstream_app/presentation/screens/channel_list_screen.dart';

/// V13 follow-on: brightness-aware migration chunk 3 covers
/// `main.dart`'s `_HomeScreen` + `_TvNavBar` (the bottom-nav shell) and
/// the `ChannelListScreen` mounted as its first tab. The bottom-nav
/// migration is a 4-site trivial change (divider, surface, primary
/// for selected, textMuted for unselected — see `main.dart` lines
/// 189–266) with no new logic; `flutter analyze` reports 0 new
/// issues on the source migration. The high-value migration is
/// `ChannelListScreen` — 50+ call sites across the home Scaffold,
/// the channel tile, the Continue Watching + Most Watched rows +
/// cards, the placeholder, the sort sheet, the mini-player bar.
/// That's what these tests cover.
///
/// The screen is rendered standalone (V12 pattern) — pumping
/// `HomeScreen` would also pump the other 5 tabs via `IndexedStack`
/// (EpgGuide, Search, VOD, Series, Settings), each of which needs
/// its own provider fixture. Standalone is sufficient to prove the
/// migration pulls brightness-correct tokens.
///
/// Pattern note: V11/V12 established one testWidgets per
/// (screen × theme) pair — NOT a loop within a single testWidgets.
/// A loop poisons the WidgetsBinding across the second `pumpWidget`,
/// so the light iteration keeps resolving to the dark theme even with
/// an explicit `themeMode: ThemeMode.light`. This file follows the
/// same pattern for that reason.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  /// Wrap ChannelListScreen in a ProviderScope with the minimum
  /// overrides needed to render it (no real auth / network). The
  /// streams / categories providers stay in their default `loading`
  /// state — we only need to verify the Scaffold renders and the
  /// background colour is theme-correct, not that the channel list
  /// data is fully populated. The "Failed to load" / "No channels
  /// found" branches are tested elsewhere (channel_list_screen_test
  /// covers the data path).
  Widget wrapChannelList({required ThemeData theme}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        profileStoreProvider.overrideWithValue(ProfileStore(prefs)),
        credentialsStoreProvider.overrideWithValue(_FakeCredentialsStore()),
        xtreamClientProvider.overrideWithValue(_FakeXtreamClient()),
        authProvider.overrideWith((ref) {
          return _StubAuthNotifier(
            const AuthState(status: AuthStatus.authenticated),
          );
        }),
      ],
      child: MaterialApp(
        theme: theme,
        themeMode: theme.brightness == Brightness.light
            ? ThemeMode.light
            : ThemeMode.dark,
        home: const ChannelListScreen(),
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
    required ThemeData theme,
  }) async {
    await tester.pumpWidget(wrapChannelList(theme: theme));
    await tester.pump();
    final bg = tester
        .widget<Scaffold>(find.byType(Scaffold))
        .backgroundColor;
    expect(bg, isNotNull,
        reason: '$theme channel-list scaffold should have a background '
            'colour (proves the V13 migration is wired)');
    expect(bg, theme.brightness == Brightness.light
        ? LightAppColors.background
        : AppColors.background,
        reason: '$theme channel-list scaffold should pull from the '
            'brightness-correct token class — confirms the migration '
            'is live');
  }

  // ---- ChannelListScreen ----
  testWidgets('ChannelListScreen renders with dark theme tokens',
      (tester) async {
    setTVSize(tester);
    await pumpAndAssertBg(tester, theme: AppTheme.dark);
  });

  testWidgets('ChannelListScreen renders with light theme tokens',
      (tester) async {
    setTVSize(tester);
    await pumpAndAssertBg(tester, theme: AppTheme.light);
  });
}

/// Stub AuthNotifier (mirrors the one in login_screen_test.dart /
/// brightness_aware_chunk2_test.dart). Authenticated state isn't
/// strictly needed here (we pump the screen directly, not through
/// AuthRouter) but the ChannelListScreen reads from providers that
/// may transitively want a non-throwing auth state.
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
