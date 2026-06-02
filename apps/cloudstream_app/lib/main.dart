import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/debug/debug_log_service.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/app_providers.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/channel_list_screen.dart';
import 'presentation/screens/epg_guide_screen.dart';
import 'presentation/screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: CloudStreamApp()));
}

class CloudStreamApp extends ConsumerWidget {
  const CloudStreamApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Shortcuts(
      // Android TV DPad center button sends LogicalKeyboardKey.select.
      // Map it to ActivateIntent so DPad select works throughout the app.
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.gameButtonA): const ActivateIntent(),
      },
      child: MaterialApp(
        title: 'CloudStream',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const AuthRouter(),
      ),
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
      AuthStatus.unknown => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
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
            _VodPlaceholder(),    // TODO: VOD screen
            SettingsScreen(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.live_tv_outlined),
            activeIcon: Icon(Icons.live_tv),
            label: 'Live TV',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book),
            label: 'Guide',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.movie_outlined),
            activeIcon: Icon(Icons.movie),
            label: 'VOD',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _GuidePlaceholder extends StatelessWidget {
  const _GuidePlaceholder();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book, color: AppColors.textMuted, size: 64),
            SizedBox(height: 16),
            Text('Guide — coming soon', style: AppTypography.h3),
          ],
        ),
      ),
    );
  }
}

class _VodPlaceholder extends StatelessWidget {
  const _VodPlaceholder();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.movie, color: AppColors.textMuted, size: 64),
            SizedBox(height: 16),
            Text('VOD — coming soon', style: AppTypography.h3),
          ],
        ),
      ),
    );
  }
}

