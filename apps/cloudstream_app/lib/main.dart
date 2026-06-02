import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/app_providers.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/channel_list_screen.dart';
import 'presentation/screens/settings_screen.dart';

void main() {
  runApp(const ProviderScope(child: CloudStreamApp()));
}

class CloudStreamApp extends ConsumerWidget {
  const CloudStreamApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'CloudStream',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const AuthRouter(),
    );
  }
}

/// Routes to login or home based on auth state.
class AuthRouter extends ConsumerWidget {
  const AuthRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            _GuidePlaceholder(),   // TODO: EPG guide screen
            _VodPlaceholder(),    // TODO: VOD screen
            const SettingsScreen(),
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

