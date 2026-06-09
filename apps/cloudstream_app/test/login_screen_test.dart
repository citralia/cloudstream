import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudstream_app/core/theme/app_theme.dart';
import 'package:cloudstream_app/data/datasources/credentials_store.dart';
import 'package:cloudstream_app/core/network/xtream_client.dart';
import 'package:cloudstream_app/core/storage/profile_store.dart';
import 'package:cloudstream_app/presentation/providers/app_providers.dart';
import 'package:cloudstream_app/presentation/screens/login_screen.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  /// Build a ProviderScope + MaterialApp wrapping `child`, with a
  /// `ThemeData` of the given brightness and a stubbed `AuthProvider`
  /// that exposes a fixed `AuthState` (so we don't have to wait for
  /// the real AuthNotifier's _restoreSession to settle, and so we
  /// can feed in `error: "..."` for the validation-error test).
  Widget wrapLoginScreen({
    required Widget child,
    required ThemeData theme,
    String? errorMessage,
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        profileStoreProvider.overrideWithValue(ProfileStore(prefs)),
        credentialsStoreProvider.overrideWithValue(_FakeCredentialsStore()),
        xtreamClientProvider.overrideWithValue(_FakeXtreamClient()),
        authProvider.overrideWith((ref) {
          // The real AuthNotifier constructor calls _restoreSession
          // (async). _StubAuthNotifier overrides the `state` getter
          // so the stub always wins; the async restore runs in the
          // background and resolves to unauthenticated (which matches
          // the stub).
          return _StubAuthNotifier(
            AuthState(
              status: AuthStatus.unauthenticated,
              error: errorMessage,
            ),
          );
        }),
      ],
      child: MaterialApp(
        theme: theme,
        // Explicit themeMode so the test environment's default
        // platformBrightness (which is dark in widget tests) doesn't
        // override our theme choice.
        themeMode: theme.brightness == Brightness.light
            ? ThemeMode.light
            : ThemeMode.dark,
        home: child,
      ),
    );
  }

  testWidgets('LoginScreen renders with dark theme tokens', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(wrapLoginScreen(
      child: const LoginScreen(),
      theme: AppTheme.dark,
    ));
    // Let the auth notifier's _restoreSession settle (no creds →
    // unauthenticated). One pump is enough because the fake
    // credentials store resolves synchronously.
    await tester.pump();

    expect(find.text('CloudStream'), findsOneWidget);
    expect(find.text('Your TV. Everywhere.'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Profile name (optional)'), findsOneWidget);
    expect(find.text('Xtream server URL'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    // Scaffold background reads from context.appColors.background —
    // in dark mode that should equal AppColors.background.
    final bg = tester
        .widget<Scaffold>(find.byType(Scaffold))
        .backgroundColor;
    expect(bg, AppColors.background);
  });

  testWidgets('LoginScreen renders with light theme tokens', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(wrapLoginScreen(
      child: const LoginScreen(),
      theme: AppTheme.light,
    ));
    await tester.pump();

    expect(find.text('CloudStream'), findsOneWidget);
    expect(find.text('Your TV. Everywhere.'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Profile name (optional)'), findsOneWidget);
    expect(find.text('Xtream server URL'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    // In light mode Scaffold background should be LightAppColors.background.
    final bg = tester
        .widget<Scaffold>(find.byType(Scaffold))
        .backgroundColor;
    expect(bg, LightAppColors.background);
  });

  testWidgets('LoginScreen shows the auth error message', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    const errorMsg = 'Could not connect — check your network';
    await tester.pumpWidget(wrapLoginScreen(
      child: const LoginScreen(),
      theme: AppTheme.dark,
      errorMessage: errorMsg,
    ));
    await tester.pump();

    expect(find.text(errorMsg), findsOneWidget);
  });
}

/// Test-only `AuthNotifier` that exposes a fixed state to consumers.
/// We push the stub state through the real StateNotifier `state` setter
/// in the constructor so Riverpod's StateNotifierProvider picks it up
/// on first read. We DON'T call `super` with the real client/store/
/// profileStore — that would trigger `_restoreSession` in the parent
/// constructor, which (via `state = AuthState(unauthenticated)`) would
/// clobber our stub. Instead we pass no-op fakes AND override
/// `login` so any accidental call is a safe no-op.
class _StubAuthNotifier extends AuthNotifier {
  _StubAuthNotifier(
    AuthState stub,
  ) : super(
    _FakeXtreamClient(),
    _FakeCredentialsStore(),
    _NoopProfileStore(),
  ) {
    state = stub;
  }
}

/// Minimal `XtreamApiClient` — never called in these tests but
/// needed to construct the `AuthNotifier`.
class _FakeXtreamClient implements XtreamApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Minimal `CredentialsStore` that reports no active connection.
/// `loadActiveConnection` returns a Future that **never completes**
/// — this is intentional. The real AuthNotifier's constructor
/// calls `_restoreSession` (async) which awaits
/// `_store.loadActiveConnection`. If it returned null, the
/// notifier would set `state = AuthState(unauthenticated)`, which
/// would clobber the test stub. Hanging the future instead means
/// the parent constructor's async work never resolves, so the
/// stub state set after `super(...)` is what the test observes.
class _FakeCredentialsStore implements CredentialsStore {
  @override
  Future<List<XtreamCredentials>> listConnections() async => const [];

  @override
  Future<XtreamCredentials?> loadActiveConnection() {
    // Never resolves — see class doc above.
    return Completer<XtreamCredentials?>().future;
  }

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

/// `ProfileStore` is a concrete class — the real constructor
/// wants `SharedPreferences`. We don't need any of its methods
/// for these tests (the auth notifier's _restoreSession returns
/// early on no-creds, and LoginScreen doesn't read profile state
/// during render), so we use `noSuchMethod` to satisfy the type.
class _NoopProfileStore implements ProfileStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
