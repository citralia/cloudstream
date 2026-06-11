import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/network/xtream_client.dart';
import '../../data/datasources/credentials_store.dart';
import '../providers/app_providers.dart';
import '../widgets/tv_text_field.dart';

/// Screen for managing saved connection profiles.
/// Accessible from Settings, lists all Xtream servers.
/// Tap to switch active connection; long-press or swipe to delete.
class PlaylistScreen extends ConsumerStatefulWidget {
  const PlaylistScreen({super.key});

  @override
  ConsumerState<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends ConsumerState<PlaylistScreen> {
  Future<void> _addConnection() async {
    final colors = context.appColors;
    final result = await showModalBottomSheet<XtreamCredentials>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: const _ConnectionFormSheet(),
      ),
    );

    if (result != null) {
      final store = ref.read(credentialsStoreProvider);
      await store.saveConnection(
        name: result.name,
        serverUrl: result.serverUrl,
        username: result.username,
        password: result.password,
      );
      ref.invalidate(connectionsListProvider);
    }
  }

  Future<void> _switchTo(XtreamCredentials conn) async {
    final store = ref.read(credentialsStoreProvider);
    await store.setActiveConnection(conn.name);

    // Reconfigure the Xtream client and validate
    final client = ref.read(xtreamClientProvider);
    client.configure(
      serverUrl: conn.serverUrl,
      username: conn.username,
      password: conn.password,
    );

    try {
      final user = await client.login();
      ref.read(authProvider.notifier).setUser(user);
      ref.invalidate(connectionsListProvider);
      if (mounted) {
        final colors = context.appColors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Switched to ${conn.name}'),
            backgroundColor: colors.primary,
          ),
        );
        Navigator.pop(context); // return to previous screen
      }
    } on XtreamAuthException catch (e) {
      if (mounted) {
        final colors = context.appColors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auth failed: ${e.message}'),
            backgroundColor: colors.error,
          ),
        );
      }
    } on XtreamApiException catch (e) {
      if (mounted) {
        final colors = context.appColors;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: ${e.message}'),
            backgroundColor: colors.error,
          ),
        );
      }
    }
  }

  Future<void> _delete(XtreamCredentials conn) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = context.appColors;
        return AlertDialog(
          backgroundColor: colors.surface,
          title: const Text('Delete connection?'),
          content: Text('Remove "${conn.name}" from saved connections?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Delete', style: TextStyle(color: colors.error)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      final store = ref.read(credentialsStoreProvider);
      await store.deleteConnection(conn.name);
      ref.invalidate(connectionsListProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionsAsync = ref.watch(connectionsListProvider);
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Connections'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addConnection,
            tooltip: 'Add connection',
          ),
        ],
      ),
      body: connectionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Failed to load: $e',
              style: TextStyle(color: colors.error)),
        ),
        data: (connections) {
          if (connections.isEmpty) {
            final typo = context.appTypography;
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.dns_outlined, size: 64, color: colors.textMuted),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'No saved connections',
                    style: typo.h3.copyWith(color: colors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Add your first Xtream server',
                    style: typo.caption,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  ElevatedButton.icon(
                    onPressed: _addConnection,
                    icon: const Icon(Icons.add),
                    label: const Text('Add connection'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            itemCount: connections.length,
            itemBuilder: (context, index) {
              final conn = connections[index];
              return _ConnectionTile(
                credentials: conn,
                onTap: () => _switchTo(conn),
                onDelete: () => _delete(conn),
              );
            },
          );
        },
      ),
    );
  }
}

class _ConnectionTile extends StatelessWidget {
  final XtreamCredentials credentials;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ConnectionTile({
    required this.credentials,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final typo = context.appTypography;
    return Dismissible(
      key: Key(credentials.name),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false; // let onDelete handle everything
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        color: colors.error.withValues(alpha: 0.2),
        child: Icon(Icons.delete_outline, color: colors.error),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.dns_outlined, color: colors.primary),
        ),
        title: Text(
          credentials.name,
          style: typo.body.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${credentials.username} @ ${Uri.parse(credentials.serverUrl).host}',
          style: typo.caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(Icons.chevron_right, color: colors.textMuted),
      ),
    );
  }
}

/// Bottom sheet form for adding a new connection.
class _ConnectionFormSheet extends StatefulWidget {
  const _ConnectionFormSheet();

  @override
  State<_ConnectionFormSheet> createState() => _ConnectionFormSheetState();
}

class _ConnectionFormSheetState extends State<_ConnectionFormSheet> {
  final _nameController = TextEditingController();
  final _serverUrlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _validateRequired(String? val) {
    if (val == null || val.trim().isEmpty) return 'This field is required';
    return null;
  }

  String? _validateServerUrl(String? val) {
    if (val == null || val.trim().isEmpty) return 'Server URL is required';
    if (!val.trim().startsWith('http://') && !val.trim().startsWith('https://')) {
      return 'Must start with http:// or https://';
    }
    return null;
  }

  void _submit() {
    final nameError = _validateRequired(_nameController.text);
    final urlError = _validateServerUrl(_serverUrlController.text);
    final userError = _validateRequired(_usernameController.text);
    final passError = _validateRequired(_passwordController.text);

    if (nameError != null || urlError != null || userError != null || passError != null) {
      final colors = context.appColors;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nameError ?? urlError ?? userError ?? passError ?? 'Error'),
          backgroundColor: colors.error,
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      XtreamCredentials(
        name: _nameController.text.trim(),
        serverUrl: _serverUrlController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final typo = context.appTypography;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            Text('New Connection', style: typo.h3),
            const SizedBox(height: AppSpacing.lg),

            // Profile name
            TvTextField(
              label: 'Profile name',
              hint: 'e.g. Home, Work',
              prefixIcon: Icons.label_outline,
              controller: _nameController,
            ),
            const SizedBox(height: AppSpacing.md),

            // Server URL
            TvTextField(
              label: 'Xtream server URL',
              hint: 'http://1.2.3.4:8080',
              prefixIcon: Icons.dns_outlined,
              controller: _serverUrlController,
              keyboardType: TextInputType.url,
              validator: _validateServerUrl,
            ),
            const SizedBox(height: AppSpacing.md),

            // Username
            TvTextField(
              label: 'Username',
              prefixIcon: Icons.person_outline,
              controller: _usernameController,
              validator: _validateRequired,
            ),
            const SizedBox(height: AppSpacing.md),

            // Password
            TvTextField(
              label: 'Password',
              prefixIcon: Icons.lock_outline,
              controller: _passwordController,
              obscureText: true,
              validator: _validateRequired,
              onSubmitted: _submit,
            ),
            const SizedBox(height: AppSpacing.xl),

            SizedBox(
              height: 56,
              child: _TvButton(
                label: 'Save connection',
                onPressed: _submit,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

/// Reusable TV button for consistency across forms.
class _TvButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;

  const _TvButton({required this.label, this.onPressed});

  @override
  State<_TvButton> createState() => _TvButtonState();
}

class _TvButtonState extends State<_TvButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final typo = context.appTypography;
    return Focus(
      autofocus: true,
      onFocusChange: (v) => setState(() => _isFocused = v),
      onKeyEvent: (node, event) {
        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.gameButtonA) {
          widget.onPressed?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          decoration: BoxDecoration(
            color: _isFocused ? colors.primary : colors.primary.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isFocused ? colors.accent : Colors.transparent,
              width: 2,
            ),
            boxShadow: _isFocused
                ? [BoxShadow(color: colors.primary.withValues(alpha: 0.4), blurRadius: 10)]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: typo.h3.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
