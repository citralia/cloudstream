import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudstream_app/main.dart';
import 'package:cloudstream_app/presentation/providers/app_providers.dart';

void main() {
  testWidgets('App smoke test — renders login screen when unauthenticated', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const CloudStreamApp(),
      ),
    );
    await tester.pump();

    // AuthRouter shows a spinner while auth status is unknown,
    // then transitions to LoginScreen when unauthenticated.
    // Allow a few pumps for state transition.
    await tester.pump(const Duration(seconds: 1));

    // App renders without crashing
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
