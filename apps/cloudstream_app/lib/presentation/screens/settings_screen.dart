import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../providers/app_providers.dart';
import 'playlist_screen.dart';

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
                  backgroundColor: AppColors.error.withValues(alpha: 0.15),
                  foregroundColor: AppColors.error,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
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
            Icon(icon, color: isDisabled ? AppColors.textMuted.withValues(alpha: 0.5) : AppColors.textMuted, size: 20),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.body.copyWith(
                      color: isDisabled ? AppColors.textMuted.withValues(alpha: 0.5) : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.caption.copyWith(
                      color: isDisabled ? AppColors.textMuted.withValues(alpha: 0.5) : AppColors.textSecondary,
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
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text('Soon', style: AppTypography.micro.copyWith(color: AppColors.primary)),
    );
  }
}
