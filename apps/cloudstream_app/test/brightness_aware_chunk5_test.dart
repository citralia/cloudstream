import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloudstream_app/core/theme/app_theme.dart';
import 'package:cloudstream_app/core/network/xtream_client.dart';
import 'package:cloudstream_app/presentation/widgets/quick_channel_overlay.dart';

/// V14 chunk 2: brightness-aware migration of the media-playback
/// surfaces. The full V14 scope (per the V13 next-pointer) is the
/// remaining un-migrated screens after V14 chunk 1; chunk 2 picks
/// the four media/playback surfaces:
///
///   - `widgets/quick_channel_overlay.dart` (QuickChannelOverlay +
///     ChannelNumberBar — the quick-switch chips + channel-number
///     bar shown on top of the player)
///   - `screens/player_gesture_overlay.dart` (seek/volume/brightness
///     labels — needs a real VideoPlayerController to mount)
///   - `screens/player_screen.dart` (the player itself — wraps
///     `chewie` and `video_player`, both of which need a real
///     network stream to fully initialise)
///   - `screens/epg_guide_screen.dart` (the full TV-grid EPG view)
///
/// Pattern matches V11/V12/V13/V14 chunk 1: one testWidgets per
/// (widget × theme) pair. A loop within a single testWidgets
/// poisons the WidgetsBinding across the second `pumpWidget`, so
/// the light iteration keeps resolving to dark even with an
/// explicit `themeMode: ThemeMode.light`. Stay explicit, per pair.
///
/// This chunk's test file is narrower than the chunk-1 file:
/// `PlayerGestureOverlay` needs a real `VideoPlayerController`
/// (chewie/video_player) and `PlayerScreen` wraps Chewie which
/// mounts the native video surface — both will fail to initialise
/// in a unit-test environment. `EpgGuideScreen` is testable but
/// needs overrides for `filteredLiveStreamsProvider`,
/// `recentChannelsProvider`, and `playerControllerProvider`; the
/// V14 chunk 1 helper for `xtreamClientProvider` /
/// `credentialsStoreProvider` already covers two of those. Same
/// scoping trade-off the V13 chunk made: prove the source
/// migration is wired (not falling back to dark constants) on the
/// self-contained widget (`QuickChannelOverlay` +
/// `ChannelNumberBar`), let the rest be covered by the source
/// change + analyze.
void main() {
  // ---- QuickChannelOverlay ----
  testWidgets('QuickChannelOverlay renders with dark theme tokens',
      (tester) async {
    setTVSize(tester);
    final stream = _stubStream;
    await tester.pumpWidget(
      _wrap(
        theme: AppTheme.dark,
        child: Stack(
          children: [
            QuickChannelOverlay(
              recentStreams: [stream],
              isVisible: true,
              onChannelSelected: (_) {},
              onDismiss: () {},
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    // The chip's stream-name text uses
    // `context.appColors.textSecondary` — in dark theme that's
    // `AppColors.textSecondary`. Proves the migration pulled the
    // brightness-correct token, not the dark constant baked into
    // the widget.
    final nameText = tester.widget<Text>(find.text('Test Channel'));
    expect(
      (nameText.style ?? const TextStyle()).color,
      AppColors.textSecondary,
      reason: 'QuickChannelOverlay stream-name text should pull from the '
          'dark appColors.textSecondary token',
    );
  });

  testWidgets('QuickChannelOverlay renders with light theme tokens',
      (tester) async {
    setTVSize(tester);
    final stream = _stubStream;
    await tester.pumpWidget(
      _wrap(
        theme: AppTheme.light,
        child: Stack(
          children: [
            QuickChannelOverlay(
              recentStreams: [stream],
              isVisible: true,
              onChannelSelected: (_) {},
              onDismiss: () {},
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    final nameText = tester.widget<Text>(find.text('Test Channel'));
    expect(
      (nameText.style ?? const TextStyle()).color,
      LightAppColors.textSecondary,
      reason: 'QuickChannelOverlay stream-name text should pull from the '
          'light appColors.textSecondary token',
    );
  });

  // ---- ChannelNumberBar ----
  testWidgets('ChannelNumberBar GO button uses dark primary in dark theme',
      (tester) async {
    setTVSize(tester);
    await tester.pumpWidget(
      _wrap(
        theme: AppTheme.dark,
        child: const Center(
          child: ChannelNumberBar(onSubmit: _noopSubmit),
        ),
      ),
    );
    await tester.pump();
    // Find the inner "GO" container — its background should be
    // `context.appColors.primary`, which resolves to
    // `AppColors.primary` in dark mode.
    final goContainer = tester.widget<Container>(
      find.ancestor(
        of: find.text('GO'),
        matching: find.byType(Container),
      ).first,
    );
    expect(
      goContainer.decoration is BoxDecoration
          ? (goContainer.decoration as BoxDecoration).color
          : null,
      AppColors.primary,
      reason: 'ChannelNumberBar GO button background should pull from the '
          'dark appColors.primary token',
    );
  });

  testWidgets('ChannelNumberBar GO button uses light primary in light theme',
      (tester) async {
    setTVSize(tester);
    await tester.pumpWidget(
      _wrap(
        theme: AppTheme.light,
        child: const Center(
          child: ChannelNumberBar(onSubmit: _noopSubmit),
        ),
      ),
    );
    await tester.pump();
    final goContainer = tester.widget<Container>(
      find.ancestor(
        of: find.text('GO'),
        matching: find.byType(Container),
      ).first,
    );
    expect(
      goContainer.decoration is BoxDecoration
          ? (goContainer.decoration as BoxDecoration).color
          : null,
      LightAppColors.primary,
      reason: 'ChannelNumberBar GO button background should pull from the '
          'light appColors.primary token',
    );
  });
}

void _noopSubmit(String _) {}

const _stubStream = XtreamStream(
  streamId: 1,
  name: 'Test Channel',
  logo: null,
  categoryId: 1,
  streamType: 'live',
);

Widget _wrap({required Widget child, required ThemeData theme}) {
  return ProviderScope(
    child: MaterialApp(
      theme: theme,
      themeMode: theme.brightness == Brightness.light
          ? ThemeMode.light
          : ThemeMode.dark,
      home: Scaffold(
        backgroundColor: theme.brightness == Brightness.light
            ? LightAppColors.background
            : AppColors.background,
        body: child,
      ),
    ),
  );
}

void setTVSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
}
