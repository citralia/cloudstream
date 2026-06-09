import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/profile.dart';
import '../providers/app_providers.dart';
import 'playlist_screen.dart';
import 'debug_logs_screen.dart';
import 'profile_switcher_screen.dart';
import 'reminders_list_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const SizedBox(height: AppSpacing.md),

          // ── Account ───────────────────────────────────────
          _SectionHeader(title: 'Account'),
          _InfoTile(
            icon: Icons.person_outline,
            label: 'Username',
            value: authState.user?.username ?? '—',
          ),
          _InfoTile(
            icon: Icons.dns_outlined,
            label: 'Server',
            value: ref.watch(xtreamClientProvider).isConfigured ? 'Connected' : '—',
          ),
          if (authState.user != null)
            _InfoTile(
              icon: Icons.calendar_today_outlined,
              label: 'Expires',
              value: authState.user!.expiryDate.isNotEmpty
                  ? authState.user!.expiryDate.substring(0, 10)
                  : '—',
            ),

          const SizedBox(height: AppSpacing.xl),

          // ── Profile ───────────────────────────────────────
          _SectionHeader(title: 'Profile'),
          _ActiveProfileTile(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileSwitcherScreen()),
              );
            },
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Playback ─────────────────────────────────────
          _SectionHeader(title: 'Playback'),
          _SettingsTile(
            icon: Icons.picture_in_picture_outlined,
            title: 'Picture in Picture',
            subtitle: 'Coming soon',
            trailing: const _ComingSoonBadge(),
            onTap: null,
          ),
          _SettingsTile(
            icon: Icons.speed,
            title: 'Quick channel switch',
            subtitle: 'Switch channels without returning to the list',
            trailing: const _ComingSoonBadge(),
            onTap: null,
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Appearance ─────────────────────────────────
          _SectionHeader(title: 'Appearance'),
          _ThemeTile(),

          const SizedBox(height: AppSpacing.xl),

          // ── Reminders ───────────────────────────────────
          _SectionHeader(title: 'Reminders'),
          _RemindersTile(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RemindersListScreen()),
              );
            },
          ),
          _LeadTimeTile(),

          const SizedBox(height: AppSpacing.xl),

          // ── Debug ────────────────────────────────────────
          _SectionHeader(title: 'Debug'),
          _SettingsTile(
            icon: Icons.bug_report_outlined,
            title: 'Debug logs',
            subtitle: 'View live logcat output from the app',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ref.watch(debugLogProvider).enabled ? Colors.green : AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DebugLogsScreen()),
              );
            },
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── About ────────────────────────────────────────
          _SectionHeader(title: 'About'),
          const _InfoTile(
            icon: Icons.info_outline,
            label: 'Version',
            value: '0.1.0',
          ),
          _SettingsTile(
            icon: Icons.article_outlined,
            title: 'Open source',
            subtitle: 'View on GitHub',
            trailing: const Icon(Icons.open_in_new, color: AppColors.textMuted, size: 18),
            onTap: () {}, // TODO: url_launcher
          ),

          // ── Connections ───────────────────────────────────
          _SectionHeader(title: 'Connections'),
          _SettingsTile(
            icon: Icons.dns_outlined,
            title: 'Manage connections',
            subtitle: 'Add, edit, or remove Xtream servers',
            trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PlaylistScreen()),
              );
            },
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Sign out ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => _confirmLogout(context, ref),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error.withOpacity(0.15),
                  foregroundColor: AppColors.error,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AppColors.error.withOpacity(0.3)),
                  ),
                ),
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Sign out?'),
        content: const Text('You will need your Xtream credentials to sign back in.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
            },
            child: Text('Sign out', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
      child: Text(
        title.toUpperCase(),
        style: AppTypography.micro.copyWith(color: AppColors.primary, letterSpacing: 1.2),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.caption),
                const SizedBox(height: 2),
                Text(value, style: AppTypography.body, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, color: isDisabled ? AppColors.textMuted.withOpacity(0.5) : AppColors.textMuted, size: 20),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.body.copyWith(
                      color: isDisabled ? AppColors.textMuted.withOpacity(0.5) : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.caption.copyWith(
                      color: isDisabled ? AppColors.textMuted.withOpacity(0.5) : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _ComingSoonBadge extends StatelessWidget {
  const _ComingSoonBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text('Soon', style: AppTypography.micro.copyWith(color: AppColors.primary)),
    );
  }
}

class _ActiveProfileTile extends ConsumerWidget {
  final VoidCallback onTap;

  const _ActiveProfileTile({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(activeProfileProvider);
    final color = profile != null
        ? Color(kProfileColors[profile.colorIndex % kProfileColors.length])
        : AppColors.primary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  profile?.name.isNotEmpty == true ? profile!.name[0].toUpperCase() : '?',
                  style: AppTypography.h3.copyWith(color: color),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile?.name ?? 'No profile',
                    style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    profile != null ? 'Tap to switch profiles' : 'Create your first profile',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Settings → Reminders → opens the [RemindersListScreen]. The
/// trailing badge shows the count of upcoming reminders for the
/// active connection (refreshes live as the user adds/cancels
/// reminders elsewhere).
class _RemindersTile extends ConsumerWidget {
  final VoidCallback onTap;

  const _RemindersTile({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(remindersProvider).length;
    return _SettingsTile(
      icon: Icons.notifications_active_outlined,
      title: 'Scheduled reminders',
      subtitle: count == 0
          ? 'None scheduled'
          : (count == 1 ? '1 upcoming' : '$count upcoming'),
      trailing: Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
      onTap: onTap,
    );
  }
}

/// Settings → Reminders → lead-time picker. The picker writes to
/// [defaultLeadTimeProvider]; new reminders scheduled from the EPG
/// pick up the new value via [RemindersNotifier.add]. Existing
/// reminders keep their lead time (set at scheduling) — that
/// matches user expectation: "I scheduled 30 min ahead, you don't
/// get to silently change it later."
class _LeadTimeTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lead = ref.watch(defaultLeadTimeProvider);
    return _SettingsTile(
      icon: Icons.schedule,
      title: 'Default lead time',
      subtitle: _formatLeadTime(lead),
      trailing: Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
      onTap: () => _showLeadTimePicker(context, ref, lead),
    );
  }

  static String _formatLeadTime(Duration d) {
    if (d.inMinutes == 0) return 'At start time';
    if (d.inMinutes == 1) return '1 minute before';
    if (d.inMinutes < 60) return '${d.inMinutes} minutes before';
    if (d.inHours == 1 && d.inMinutes == 0) return '1 hour before';
    if (d.inMinutes % 60 == 0) return '${d.inHours} hours before';
    return '${d.inHours}h ${d.inMinutes % 60}m before';
  }

  static void _showLeadTimePicker(BuildContext context, WidgetRef ref, Duration current) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        // Five-minute steps from 0 to 30, then 15-min steps to 60.
        const options = <Duration>[
          Duration(minutes: 0),
          Duration(minutes: 1),
          Duration(minutes: 5),
          Duration(minutes: 10),
          Duration(minutes: 15),
          Duration(minutes: 20),
          Duration(minutes: 25),
          Duration(minutes: 30),
          Duration(minutes: 45),
          Duration(minutes: 60),
        ];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpacing.md),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Remind me…',
                style: AppTypography.h3,
              ),
              const SizedBox(height: AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  'New reminders will use this lead time. Existing reminders are unaffected.',
                  style: AppTypography.caption,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (_, i) {
                    final opt = options[i];
                    final selected = opt == current;
                    return ListTile(
                      title: Text(
                        _formatLeadTime(opt),
                        style: AppTypography.body.copyWith(
                          color: selected ? AppColors.primary : AppColors.textPrimary,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      trailing: selected
                          ? Icon(Icons.check, color: AppColors.primary)
                          : null,
                      onTap: () {
                        ref.read(defaultLeadTimeProvider.notifier).state = opt;
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        );
      },
    );
  }
}

/// Settings → Appearance → opens a bottom sheet with three
/// [ThemeMode] options (Dark / Light / System) and writes the
/// choice through to [themeModeProvider]. The selection is
/// persisted via [ThemePreferencesStore] inside the provider, so
/// the choice survives across launches. The `MaterialApp` in
/// `main.dart` watches the same provider and rebuilds with
/// [AppTheme.dark] / [AppTheme.light] / system without an app
/// restart.
class _ThemeTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return _SettingsTile(
      icon: Icons.brightness_6_outlined,
      title: 'Theme',
      subtitle: _formatMode(mode),
      trailing: Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
      onTap: () => _showThemePicker(context, ref, mode),
    );
  }

  static String _formatMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark: return 'Dark';
      case ThemeMode.light: return 'Light';
      case ThemeMode.system: return 'Follow system';
    }
  }

  static void _showThemePicker(BuildContext context, WidgetRef ref, ThemeMode current) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        const options = <ThemeMode>[
          ThemeMode.dark,
          ThemeMode.light,
          ThemeMode.system,
        ];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpacing.md),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Choose a theme',
                style: AppTypography.h3,
              ),
              const SizedBox(height: AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  'Switches the app between dark and light surfaces. Existing screens still render with dark text by default — a full per-screen migration is on the way.',
                  style: AppTypography.caption,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (_, i) {
                    final opt = options[i];
                    final selected = opt == current;
                    return ListTile(
                      leading: Icon(
                        _iconFor(opt),
                        color: selected ? AppColors.primary : AppColors.textMuted,
                      ),
                      title: Text(
                        _formatMode(opt),
                        style: AppTypography.body.copyWith(
                          color: selected ? AppColors.primary : AppColors.textPrimary,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      trailing: selected
                          ? Icon(Icons.check, color: AppColors.primary)
                          : null,
                      onTap: () {
                        ref.read(themeModeProvider.notifier).state = opt;
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        );
      },
    );
  }

  static IconData _iconFor(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark: return Icons.dark_mode_outlined;
      case ThemeMode.light: return Icons.light_mode_outlined;
      case ThemeMode.system: return Icons.brightness_auto_outlined;
    }
  }
}
