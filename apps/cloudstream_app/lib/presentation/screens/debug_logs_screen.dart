import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_extensions.dart';
import '../providers/app_providers.dart';

class DebugLogsScreen extends ConsumerStatefulWidget {
  const DebugLogsScreen({super.key});

  @override
  ConsumerState<DebugLogsScreen> createState() => _DebugLogsScreenState();
}

class _DebugLogsScreenState extends ConsumerState<DebugLogsScreen> {
  final _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final logState = ref.watch(debugLogProvider);

    // Auto-scroll when new lines arrive.
    ref.listen<DebugLogState>(debugLogProvider, (_, next) {
      if (_autoScroll) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        title: const Text('Debug Logs'),
        actions: [
          // Auto-scroll toggle.
          IconButton(
            icon: Icon(
              _autoScroll ? Icons.vertical_align_bottom : Icons.vertical_align_center,
              color: _autoScroll ? context.appColors.primary : context.appColors.textMuted,
            ),
            tooltip: 'Auto-scroll',
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
          ),
          // Clear.
          IconButton(
            icon: Icon(Icons.delete_outline, color: context.appColors.textMuted),
            tooltip: 'Clear',
            onPressed: () => ref.read(debugLogProvider.notifier).clear(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Toggle bar.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            color: context.appColors.surface,
            child: Row(
              children: [
                Icon(Icons.bug_report, size: 18, color: context.appColors.textSecondary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Log collection',
                  style: context.appTypography.body.copyWith(color: context.appColors.textPrimary),
                ),
                const Spacer(),
                Switch(
                  value: logState.enabled,
                  activeThumbColor: context.appColors.primary,
                  onChanged: (v) => ref.read(debugLogProvider.notifier).setEnabled(v),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.appColors.surface),
          // Log viewer.
          Expanded(
            child: logState.lines.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          logState.enabled ? Icons.article_outlined : Icons.pause_circle_outline,
                          size: 48,
                          color: context.appColors.textMuted,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          logState.enabled ? 'No logs yet — waiting for output…' : 'Log collection paused',
                          style: context.appTypography.body.copyWith(color: context.appColors.textMuted),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    itemCount: logState.lines.length,
                    itemBuilder: (context, index) {
                      return _LogLine(line: logState.lines[index]);
                    },
                  ),
          ),
          // Status bar.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
            color: context.appColors.surface,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: logState.enabled ? Colors.green : context.appColors.textMuted,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  logState.enabled
                      ? '${logState.lines.length} lines collected'
                      : 'Paused — ${logState.lines.length} lines',
                  style: context.appTypography.caption.copyWith(color: context.appColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogLine extends StatelessWidget {
  final String line;
  const _LogLine({required this.line});

  @override
  Widget build(BuildContext context) {
    final color = _lineColor(context, line);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(
        line,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          color: color,
          height: 1.4,
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Color _lineColor(BuildContext context, String line) {
    if (line.contains(' E/') || line.contains(' ERROR')) return context.appColors.error;
    if (line.contains(' W/') || line.contains(' WARN')) return Colors.orange;
    if (line.contains(' I/')) return Colors.blue.shade300;
    if (line.contains(' D/')) return context.appColors.textMuted;
    return context.appColors.textSecondary;
  }
}
