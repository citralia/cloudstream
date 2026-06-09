import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Brightness-aware accessors for the design tokens.
///
/// Before this file existed, screens hardcoded `AppColors.X` /
/// `AppTypography.X` references that always resolved to the **dark**
/// tokens, so picking Light in Settings flipped Material widgets
/// (tooltips, system dialogs, scrollbars) but left every custom screen
/// painted in dark colours. The V08 cron intentionally shipped that
/// scope and noted the per-screen migration as a follow-on.
///
/// This extension is the bridge for that follow-on: it reads
/// `Theme.of(context).brightness` and returns the matching token
/// class, so a single `AppColors` import at the top of a screen
/// file can be replaced with `context.appColors` /
/// `context.appTypography` references and the screen will render
/// correctly in **both** dark and light themes with no other changes.
///
/// Migrated files so far:
///   - `presentation/screens/login_screen.dart` (V11)
///   - `presentation/widgets/tv_text_field.dart` (V11; used by login + playlist)
///   - `presentation/screens/settings_screen.dart` (V12)
///   - `presentation/screens/profile_switcher_screen.dart` (V12)
///   - `presentation/screens/debug_logs_screen.dart` (V12)
///   - `presentation/screens/reminders_list_screen.dart` (V12)
///   - `presentation/screens/search_screen.dart` (V12)
///   - `main.dart` _HomeScreen + _TvNavBar (V13; bottom-nav shell)
///   - `presentation/screens/channel_list_screen.dart` (V13; home + most-watched +
///     continue-watching rows — the screen that anchors the home tab)
///
/// The `AppColors` / `LightAppColors` / `AppTypography` /
/// `LightAppTypography` constants stay exported for the many remaining
/// files that haven't been migrated yet — they continue to work exactly
/// as before, just with the dark theme baked in.
extension ThemeTokens on BuildContext {
  /// Token group matching the current theme brightness. Returns the
  /// dark token values in dark mode and the light token values in
  /// light mode, with no per-call-site branching required.
  AppColorTokens get appColors {
    return Theme.of(this).brightness == Brightness.light
        ? const _LightTokens()
        : const _DarkTokens();
  }

  /// Typography tokens matching the current theme brightness. Same
  /// sizing/weights as [AppTypography] but with the theme-correct
  /// foreground colour baked into each style.
  AppTypographyTokens get appTypography {
    return Theme.of(this).brightness == Brightness.light
        ? const _LightTypography()
        : const _DarkTypography();
  }
}

/// Grouped colour tokens (brightness-resolved). Returned by
/// [ThemeTokens.appColors]. The two implementations are private
/// singletons exposed only via [BuildContext.appColors].
class AppColorTokens {
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color primary;
  final Color accent;
  final Color error;
  final Color success;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color divider;

  const AppColorTokens({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.primary,
    required this.accent,
    required this.error,
    required this.success,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.divider,
  });
}

/// Grouped typography tokens (brightness-resolved). Returned by
/// [ThemeTokens.appTypography]. Each style already has the
/// theme-correct colour resolved into it, so call sites just write
/// `context.appTypography.body` (or `.copyWith(color: …)` to
/// override per-instance).
class AppTypographyTokens {
  final String fontFamily;
  final TextStyle display;
  final TextStyle h1;
  final TextStyle h2;
  final TextStyle h3;
  final TextStyle body;
  final TextStyle caption;
  final TextStyle micro;

  const AppTypographyTokens({
    required this.fontFamily,
    required this.display,
    required this.h1,
    required this.h2,
    required this.h3,
    required this.body,
    required this.caption,
    required this.micro,
  });
}

class _DarkTokens extends AppColorTokens {
  const _DarkTokens() : super(
    background: AppColors.background,
    surface: AppColors.surface,
    surfaceElevated: AppColors.surfaceElevated,
    primary: AppColors.primary,
    accent: AppColors.accent,
    error: AppColors.error,
    success: AppColors.success,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textMuted: AppColors.textMuted,
    divider: AppColors.divider,
  );
}

class _LightTokens extends AppColorTokens {
  const _LightTokens() : super(
    background: LightAppColors.background,
    surface: LightAppColors.surface,
    surfaceElevated: LightAppColors.surfaceElevated,
    primary: LightAppColors.primary,
    accent: LightAppColors.accent,
    error: LightAppColors.error,
    success: LightAppColors.success,
    textPrimary: LightAppColors.textPrimary,
    textSecondary: LightAppColors.textSecondary,
    textMuted: LightAppColors.textMuted,
    divider: LightAppColors.divider,
  );
}

class _DarkTypography extends AppTypographyTokens {
  const _DarkTypography() : super(
    fontFamily: AppTypography.fontFamily,
    display: AppTypography.display,
    h1: AppTypography.h1,
    h2: AppTypography.h2,
    h3: AppTypography.h3,
    body: AppTypography.body,
    caption: AppTypography.caption,
    micro: AppTypography.micro,
  );
}

class _LightTypography extends AppTypographyTokens {
  const _LightTypography() : super(
    fontFamily: LightAppTypography.fontFamily,
    display: LightAppTypography.display,
    h1: LightAppTypography.h1,
    h2: LightAppTypography.h2,
    h3: LightAppTypography.h3,
    body: LightAppTypography.body,
    caption: LightAppTypography.caption,
    micro: LightAppTypography.micro,
  );
}
