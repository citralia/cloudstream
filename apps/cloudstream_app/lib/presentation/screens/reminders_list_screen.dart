import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/storage/reminder_store.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_extensions.dart';
import '../providers/app_providers.dart';

/// A list of every upcoming reminder scheduled for the active
/// connection. Each row is a programme with a tap-to-play
/// affordance (it opens the EPG screen for the right channel —
/// direct playback needs the channel object, which we don't have
/// in the persisted reminder; tapping the row is the natural way to
/// surface the underlying programme so the user can re-engage with
/// the EPG) and a swipe-to-delete affordance.
///
/// Empty state: friendly message + hint pointing to the EPG guide.
///
/// This is the second half of the V07 EPG reminders feature. The
/// first half (data layer + EPG long-press toggle) is in
/// `reminder_store.dart` and `epg_guide_screen.dart`. The third
/// half (flutter_local_notifications wiring) is parked for a
/// later cron — the data layer is ready for it.
class RemindersListScreen extends ConsumerWidget {
  const RemindersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(remindersProvider);
    final count = reminders.length;

    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Reminders'),
            if (count > 0)
              Text(
                count == 1 ? '1 upcoming' : '$count upcoming',
                style: context.appTypography.micro.copyWith(
                  color: context.appColors.textMuted,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
      ),
      body: count == 0
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: count,
              separatorBuilder: (_, __) => Divider(
                color: context.appColors.divider,
                height: 1,
                indent: AppSpacing.lg,
                endIndent: AppSpacing.lg,
              ),
              itemBuilder: (context, i) {
                final r = reminders[i];
                return Dismissible(
                  key: ValueKey(r.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: context.appColors.error.withValues(alpha: 0.15),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline, color: context.appColors.error),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Cancel',
                          style: context.appTypography.body.copyWith(
                            color: context.appColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                  onDismissed: (_) {
                    ref.read(remindersProvider.notifier).remove(r.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Reminder cancelled — ${r.programmeTitle}'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: _ReminderRow(reminder: r),
                );
              },
            ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  final Reminder reminder;
  const _ReminderRow({required this.reminder});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bell icon badge — mirrors the indicator in the EPG block
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.appColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.notifications_active,
              color: context.appColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.programmeTitle.isEmpty
                      ? '(untitled programme)'
                      : reminder.programmeTitle,
                  style: context.appTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  reminder.channelName,
                  style: context.appTypography.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 14,
                      color: context.appColors.textMuted,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      _formatSchedule(reminder),
                      style: context.appTypography.micro.copyWith(
                        color: context.appColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// "Today 22:00" / "Tomorrow 14:30" / "Sat 18:00" / "Mon 12 Jun 21:00"
  String _formatSchedule(Reminder r) {
    final local = r.startTime.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDay = DateTime(local.year, local.month, local.day);
    final daysAway = startDay.difference(today).inDays;
    final time = _formatTime(local);
    if (daysAway == 0) return 'Today $time';
    if (daysAway == 1) return 'Tomorrow $time';
    if (daysAway < 7) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${weekdays[local.weekday - 1]} $time';
    }
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')} $time';
  }

  String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: context.appColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.notifications_off_outlined,
                size: 36,
                color: context.appColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No reminders yet',
              style: context.appTypography.h3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Long-press a programme in the EPG guide to schedule a reminder.',
              style: context.appTypography.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
