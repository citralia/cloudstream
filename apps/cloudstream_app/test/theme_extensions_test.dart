import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudstream_app/core/theme/app_theme.dart';
import 'package:cloudstream_app/core/theme/theme_extensions.dart';

void main() {
  // Read appColors off a context mounted inside the given ThemeData.
  // Each testWidgets call is a fresh widget tree, so the only
  // "leak" between calls is the static token class references —
  // which is what we're actually testing.
  Future<AppColorTokens> colorsIn(WidgetTester tester, ThemeData theme) async {
    late AppColorTokens tokens;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        darkTheme: AppTheme.dark,
        themeMode: theme.brightness == Brightness.light
            ? ThemeMode.light
            : ThemeMode.dark,
        home: Builder(builder: (context) {
          tokens = context.appColors;
          return const SizedBox.shrink();
        }),
      ),
    );
    return tokens;
  }

  Future<AppTypographyTokens> typoIn(WidgetTester tester, ThemeData theme) async {
    late AppTypographyTokens tokens;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        themeMode: theme.brightness == Brightness.light
            ? ThemeMode.light
            : ThemeMode.dark,
        home: Builder(builder: (context) {
          tokens = context.appTypography;
          return const SizedBox.shrink();
        }),
      ),
    );
    return tokens;
  }

  group('context.appColors', () {
    testWidgets('returns dark tokens in dark theme', (tester) async {
      final dark = await colorsIn(tester, AppTheme.dark);
      expect(dark.background, AppColors.background);
      expect(dark.surface, AppColors.surface);
      expect(dark.primary, AppColors.primary);
      expect(dark.textPrimary, AppColors.textPrimary);
      expect(dark.textSecondary, AppColors.textSecondary);
      expect(dark.textMuted, AppColors.textMuted);
      expect(dark.divider, AppColors.divider);
      expect(dark.error, AppColors.error);
    });

    testWidgets('returns light tokens in light theme', (tester) async {
      final light = await colorsIn(tester, AppTheme.light);
      expect(light.background, LightAppColors.background);
      expect(light.surface, LightAppColors.surface);
      expect(light.primary, LightAppColors.primary);
      expect(light.textPrimary, LightAppColors.textPrimary);
      expect(light.textSecondary, LightAppColors.textSecondary);
      expect(light.textMuted, LightAppColors.textMuted);
      expect(light.divider, LightAppColors.divider);
      expect(light.error, LightAppColors.error);
    });

    test('dark and light background constants are distinct', () {
      // Static check that the source-of-truth constants differ —
      // proves the extension has distinct pools to draw from.
      expect(AppColors.background, isNot(LightAppColors.background));
      expect(AppColors.primary, isNot(LightAppColors.primary));
      expect(AppColors.textPrimary, isNot(LightAppColors.textPrimary));
      expect(AppColors.surface, isNot(LightAppColors.surface));
    });
  });

  group('context.appTypography', () {
    testWidgets('returns dark typography in dark theme', (tester) async {
      final dark = await typoIn(tester, AppTheme.dark);
      expect(dark.body.color, AppTypography.body.color);
      expect(dark.h1.color, AppTypography.h1.color);
      expect(dark.caption.color, AppTypography.caption.color);
    });

    testWidgets('returns light typography in light theme', (tester) async {
      final light = await typoIn(tester, AppTheme.light);
      expect(light.body.color, LightAppTypography.body.color);
      expect(light.h1.color, LightAppTypography.h1.color);
      expect(light.caption.color, LightAppTypography.caption.color);
    });

    test('dark and light body text colors are distinct (static)', () {
      expect(
        AppTypography.body.color,
        isNot(LightAppTypography.body.color),
      );
    });
  });
}
