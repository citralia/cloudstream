import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/xtream_client.dart';
import '../../data/datasources/credentials_store.dart';
import '../providers/app_providers.dart';

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
    final result = await showModalBottomSheet<XtreamCredentials>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Switched to ${conn.name}'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context); // return to previous screen
      }
    } on XtreamAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auth failed: ${e.message}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } on XtreamApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: ${e.message}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _delete(XtreamCredentials conn) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete connection?'),
        content: Text('Remove "${conn.name}" from saved connections?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
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

    return Scaffold(
      backgroundColor: AppColors.background,
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
          child: Text('Failed to load: $e', style: TextStyle(color: AppColors.error)),
        ),
        data: (connections) {
          if (connections.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.dns_outlined, size: 64, color: AppColors.textMuted),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'No saved connections',
                    style: AppTypography.h3.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Add your first Xtream server',
                    style: AppTypography.caption,
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
        color: AppColors.error.withValues(alpha: 0.2),
        child: const Icon(Icons.delete_outline, color: AppColors.error),
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
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.dns_outlined, color: AppColors.primary),
        ),
        title: Text(
          credentials.name,
          style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${credentials.username} @ ${Uri.parse(credentials.serverUrl).host}',
          style: AppTypography.caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
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
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _serverUrlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _serverUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
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
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
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
                    color: AppColors.textMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              Text('New Connection', style: AppTypography.h3),
              const SizedBox(height: AppSpacing.lg),

              // Profile name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Profile name',
                  hintText: 'e.g. Home, Work, Parent\'s house',
                  prefixIcon: Icon(Icons.label_outline, color: AppColors.textMuted),
                ),
                textInputAction: TextInputAction.next,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Name is required';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Server URL
              TextFormField(
                controller: _serverUrlController,
                decoration: const InputDecoration(
                  labelText: 'Xtream server URL',
                  hintText: 'http://1.2.3.4:8080',
                  prefixIcon: Icon(Icons.dns_outlined, color: AppColors.textMuted),
                ),
                keyboardType: TextInputType.url,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Server URL is required';
                  if (!val.startsWith('http://') && !val.startsWith('https://')) {
                    return 'Must start with http:// or https://';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Username
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.person_outline, color: AppColors.textMuted),
                ),
                textInputAction: TextInputAction.next,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Username is required';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Password
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textMuted),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.textMuted,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Password is required';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.xl),

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Save connection'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}
