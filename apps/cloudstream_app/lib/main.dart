import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/debug/debug_log_service.dart';
import 'core/notifications/reminder_scheduler.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_extensions.dart';
import 'presentation/providers/app_providers.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/channel_list_screen.dart';
import 'presentation/screens/epg_guide_screen.dart';
import 'presentation/screens/search_screen.dart';
import 'presentation/screens/vod_screen.dart';
import 'presentation/screens/series_screen.dart';
import 'presentation/screens/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final scheduler = LocalNotificationsReminderScheduler();
  await scheduler.init();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      reminderSchedulerProvider.overrideWithValue(scheduler),
    ],
  );
  // One-shot rehydrate at cold start: re-schedule every persisted
  // reminder for the active profile. This is the path the OS calls
  // indirectly via the boot receiver (the receiver re-uses the
  // alarm data, but we still re-sync here for the case where the
  // user installed a new APK or changed timezones).
  await container.read(remindersProvider.notifier).refresh();
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const CloudStreamApp(),
    ),
  );
}

class CloudStreamApp extends ConsumerWidget {
  const CloudStreamApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the persisted theme mode. When the user flips Dark /
    // Light / System in Settings, this rebuilds with the matching
    // pair of `theme` / `darkTheme` so Material widgets that don't
    // hardcode AppColors.* (tooltips, system dialogs, scrollbars)
    // pick up the chosen scheme. Existing screens still render with
    // dark tokens — a full per-screen migration is a separate task.
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'CloudStream',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: const AuthRouter(),
    );
  }
}

/// Routes to login or home based on auth state.
class AuthRouter extends ConsumerWidget {
  const AuthRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Start log collection after first frame to avoid startup crash.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DebugLogService.instance.start();
    });
    final authState = ref.watch(authProvider);

    return switch (authState.status) {
      AuthStatus.unknown => Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: context.appColors.primary),
        ),
      ),
      AuthStatus.authenticated => const HomeScreen(),
      AuthStatus.unauthenticated => const LoginScreen(),
    };
  }
}

/// Main app shell with bottom navigation.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    // Info key toggles quick channel switcher overlay.
    if (event.logicalKey == LogicalKeyboardKey.info) {
      final visible = ref.read(quickSwitcherOverlayVisibleProvider);
      ref.read(quickSwitcherOverlayVisibleProvider.notifier).state = !visible;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          _handleKeyEvent(event);
          // Don't consume the event — let children handle it too.
          return KeyEventResult.ignored;
        },
        child: IndexedStack(
          index: _currentIndex,
          children: const [
            ChannelListScreen(),
            EpgGuideScreen(),
            SearchScreen(),
            VodScreen(),
            SeriesScreen(),
            SettingsScreen(),
          ],
        ),
      ),
      bottomNavigationBar: const _TvNavBar(),
    );
  }
}

/// TV D-pad friendly bottom navigation bar.
/// Replaces BottomNavigationBar which does not handle DPad left/right on Android TV.
class _TvNavBar extends ConsumerStatefulWidget {
  const _TvNavBar();

  @override
  ConsumerState<_TvNavBar> createState() => _TvNavBarState();
}

class _TvNavBarState extends ConsumerState<_TvNavBar> {
  int _currentIndex = 0;

  static const _navItems = [
    (icon: Icons.live_tv_outlined, activeIcon: Icons.live_tv, label: 'Live TV'),
    (icon: Icons.menu_book_outlined, activeIcon: Icons.menu_book, label: 'Guide'),
    (icon: Icons.search_outlined, activeIcon: Icons.search, label: 'Search'),
    (icon: Icons.movie_outlined, activeIcon: Icons.movie, label: 'VOD'),
    (icon: Icons.tv_outlined, activeIcon: Icons.tv, label: 'Series'),
    (icon: Icons.settings_outlined, activeIcon: Icons.settings, label: 'Settings'),
  ];

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight) {
      setState(() => _currentIndex = (_currentIndex + 1) % _navItems.length);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      setState(() => _currentIndex = (_currentIndex - 1 + _navItems.length) % _navItems.length);
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.select) {
      _selectCurrent();
    }
  }

  void _selectCurrent() {
    // Navigate to the parent HomeScreen and switch tabs.
    // Walk up to HomeScreenState and update _currentIndex.
    final context = ref.context;
    final homeState = context.findAncestorStateOfType<ConsumerState>();
    if (homeState is _HomeScreenState) {
      homeState.setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        _handleKeyEvent(event);
        return KeyEventResult.handled;
      },
      child: Container(
        decoration: BoxDecoration(
          color: context.appColors.surface,
          border: Border(top: BorderSide(color: context.appColors.divider, width: 0.5)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 68,
            child: Row(
              children: List.generate(_navItems.length, (i) {
                final item = _navItems[i];
                final isSelected = _currentIndex == i;
                return Expanded(
                  child: _NavBarItem(
                    icon: isSelected ? item.activeIcon : item.icon,
                    label: item.label,
                    isSelected: isSelected,
                    onTap: () {
                      setState(() => _currentIndex = i);
                      // Also update HomeScreen's index.
                      final homeState =
                          context.findAncestorStateOfType<ConsumerState>();
                      if (homeState is _HomeScreenState) {
                        homeState._currentIndex = i;
                        homeState.setState(() {});
                      }
                    },
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          border: isSelected
              ? Border(top: BorderSide(color: context.appColors.primary, width: 3))
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? context.appColors.primary : context.appColors.textMuted,
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? context.appColors.primary : context.appColors.textMuted,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

