import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudstream_app/core/theme/app_theme.dart';
import 'package:cloudstream_app/data/datasources/credentials_store.dart';
import 'package:cloudstream_app/core/network/xtream_client.dart';
import 'package:cloudstream_app/core/storage/profile_store.dart';
import 'package:cloudstream_app/presentation/providers/app_providers.dart';
import 'package:cloudstream_app/presentation/screens/vod_screen.dart';
import 'package:cloudstream_app/presentation/screens/series_screen.dart';
import 'package:cloudstream_app/presentation/screens/vod_detail_screen.dart';
import 'package:cloudstream_app/presentation/screens/series_detail_screen.dart';

/// V14 chunk 1: brightness-aware migration of the VOD/series browsing
/// surfaces. The full V14 scope (per the V13 next-pointer) is the
/// remaining un-migrated screens after V13; chunk 1 picks the four
/// uniform list/detail screens that mirror the already-migrated
/// `ChannelListScreen` and don't interact with video / gesture
/// surfaces (those remain for chunk 2):
///
///   - `vod_screen.dart` (category chips + VOD grid)
///   - `series_screen.dart` (category chips + series grid)
///   - `vod_detail_screen.dart` (cover, metadata, synopsis, watch buttons)
///   - `series_detail_screen.dart` (cover, metadata, season chips, episode list)
///
/// Pattern matches V11/V12/V13: one testWidgets per (screen × theme)
/// pair. A loop within a single testWidgets poisons the
/// WidgetsBinding across the second `pumpWidget`, so the light
/// iteration keeps resolving to dark even with an explicit
/// `themeMode: ThemeMode.light`. Stay explicit, per pair.
///
/// VOD / series detail screens take an `XtreamStream` constructor
/// arg. We pass a stub stream — the V14 migration is about the
/// scaffold background + the helper widgets rendering, not the data
/// path. The data-path tests (vod_info, series_info) live in
/// `test/vod_info_test.dart` and `test/series_info_test.dart`.
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
            const AuthState(status: AuthStatus.authenticated),
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
            'token class — confirms the V14 chunk 1 migration is live');
  }

  // ---- VodScreen ----
  testWidgets('VodScreen renders with dark theme tokens', (tester) async {
    setTVSize(tester);
    await pumpAndAssertBg(
      tester,
      child: const VodScreen(),
      theme: AppTheme.dark,
    );
  });

  testWidgets('VodScreen renders with light theme tokens', (tester) async {
    setTVSize(tester);
    await pumpAndAssertBg(
      tester,
      child: const VodScreen(),
      theme: AppTheme.light,
    );
  });

  // ---- SeriesScreen ----
  testWidgets('SeriesScreen renders with dark theme tokens', (tester) async {
    setTVSize(tester);
    await pumpAndAssertBg(
      tester,
      child: const SeriesScreen(),
      theme: AppTheme.dark,
    );
  });

  testWidgets('SeriesScreen renders with light theme tokens', (tester) async {
    setTVSize(tester);
    await pumpAndAssertBg(
      tester,
      child: const SeriesScreen(),
      theme: AppTheme.light,
    );
  });

  // ---- VodDetailScreen ----
  testWidgets('VodDetailScreen renders with dark theme tokens',
      (tester) async {
    setTVSize(tester);
    await pumpAndAssertBg(
      tester,
      child: VodDetailScreen(stream: _stubVodStream),
      theme: AppTheme.dark,
    );
  });

  testWidgets('VodDetailScreen renders with light theme tokens',
      (tester) async {
    setTVSize(tester);
    await pumpAndAssertBg(
      tester,
      child: VodDetailScreen(stream: _stubVodStream),
      theme: AppTheme.light,
    );
  });

  // ---- SeriesDetailScreen ----
  testWidgets('SeriesDetailScreen renders with dark theme tokens',
      (tester) async {
    setTVSize(tester);
    await pumpAndAssertBg(
      tester,
      child: SeriesDetailScreen(stream: _stubVodStream),
      theme: AppTheme.dark,
    );
  });

  testWidgets('SeriesDetailScreen renders with light theme tokens',
      (tester) async {
    setTVSize(tester);
    await pumpAndAssertBg(
      tester,
      child: SeriesDetailScreen(stream: _stubVodStream),
      theme: AppTheme.light,
    );
  });
}

const _stubVodStream = XtreamStream(
  streamId: 101,
  name: 'Test VOD',
  logo: null,
  categoryId: 1,
  streamType: 'movie',
);

/// Stub AuthNotifier (mirrors the one in chunk2 / chunk3 tests).
/// Authenticated state isn't strictly needed here (we pump the
/// screen directly, not through AuthRouter) but the VOD / series
/// detail screens read `credentialsStoreProvider` via their play
/// paths — keeping auth stubbed avoids that bridge.
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
