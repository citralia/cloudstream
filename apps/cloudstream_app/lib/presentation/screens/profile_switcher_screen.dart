import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_extensions.dart';
import '../../domain/entities/profile.dart';
import '../providers/app_providers.dart';
import '../widgets/tv_text_field.dart';

/// Full-screen profile switcher.
/// Accessible from Settings → switch icon in the profile header.
/// Allows add, rename, delete, and switching between profiles.
class ProfileSwitcherScreen extends ConsumerStatefulWidget {
  const ProfileSwitcherScreen({super.key});

  @override
  ConsumerState<ProfileSwitcherScreen> createState() => _ProfileSwitcherScreenState();
}

class _ProfileSwitcherScreenState extends ConsumerState<ProfileSwitcherScreen> {
  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(profilesProvider);
    final activeId = ref.watch(activeProfileIdProvider);

    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        title: const Text('Profiles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(context),
            tooltip: 'Add profile',
          ),
        ],
      ),
      body: profiles.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_outline, size: 64, color: context.appColors.textMuted),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'No profiles yet',
                    style: context.appTypography.h3.copyWith(color: context.appColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  ElevatedButton.icon(
                    onPressed: () => _showAddDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add profile'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              itemCount: profiles.length,
              itemBuilder: (context, index) {
                final profile = profiles[index];
                final isActive = profile.id == activeId;
                return _ProfileTile(
                  profile: profile,
                  isActive: isActive,
                  onTap: () => _switchTo(profile),
                  onRename: () => _showRenameDialog(context, profile),
                  onDelete: profiles.length > 1 ? () => _confirmDelete(context, profile) : null,
                );
              },
            ),
    );
  }

  Future<void> _switchTo(Profile profile) async {
    await switchToProfile(ref, profile.id);
    ref.invalidate(activeProfileFavouritesProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched to ${profile.name}'),
          backgroundColor: context.appColors.primary,
        ),
      );
    }
  }

  Future<void> _showAddDialog(BuildContext context) async {
    final result = await showDialog<({String name, int colorIndex})>(
      context: context,
      builder: (ctx) => const _ProfileFormSheet(),
    );

    if (result != null) {
      await ref.read(profilesProvider.notifier).add(
        name: result.name,
        colorIndex: result.colorIndex,
      );
    }
  }

  Future<void> _showRenameDialog(BuildContext context, Profile profile) async {
    final result = await showDialog<({String name, int colorIndex})>(
      context: context,
      builder: (ctx) => _ProfileFormSheet(existing: profile),
    );

    if (result != null) {
      await ref.read(profilesProvider.notifier).update(
        profile.copyWith(name: result.name, colorIndex: result.colorIndex),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, Profile profile) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appColors.surface,
        title: const Text('Delete profile?'),
        content: Text(
          'Remove "${profile.name}"? This will delete all favourites and watch progress for this profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: context.appColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(profilesProvider.notifier).delete(profile.id);
      // If we deleted the active profile, the store already switched to another.
      ref.invalidate(activeProfileFavouritesProvider);
    }
  }
}

class _ProfileTile extends StatelessWidget {
  final Profile profile;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback? onDelete;

  const _ProfileTile({
    required this.profile,
    required this.isActive,
    required this.onTap,
    required this.onRename,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(kProfileColors[profile.colorIndex % kProfileColors.length]);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Material(
        color: isActive ? color.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: isActive
                  ? Border.all(color: color.withOpacity(0.4), width: 1)
                  : null,
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?',
                      style: context.appTypography.h2.copyWith(color: color),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),

                // Name + meta
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            profile.name,
                            style: context.appTypography.h3.copyWith(
                              color: isActive ? color : context.appColors.textPrimary,
                            ),
                          ),
                          if (isActive) ...[
                            const SizedBox(width: AppSpacing.sm),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Active',
                                style: context.appTypography.micro.copyWith(color: color),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Created ${_formatDate(profile.createdAt)}',
                        style: context.appTypography.caption,
                      ),
                    ],
                  ),
                ),

                // Actions
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  color: context.appColors.textMuted,
                  onPressed: onRename,
                  tooltip: 'Rename',
                ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: context.appColors.error,
                    onPressed: onDelete,
                    tooltip: 'Delete',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

/// Bottom sheet for adding or renaming a profile.
class _ProfileFormSheet extends StatefulWidget {
  final Profile? existing;

  const _ProfileFormSheet({this.existing});

  @override
  State<_ProfileFormSheet> createState() => _ProfileFormSheetState();
}

class _ProfileFormSheetState extends State<_ProfileFormSheet> {
  late final TextEditingController _nameController;
  late int _selectedColorIndex;

  bool get isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _selectedColorIndex = widget.existing?.colorIndex ?? 0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile name is required'),
          backgroundColor: context.appColors.error,
        ),
      );
      return;
    }
    Navigator.pop(context, (name: name, colorIndex: _selectedColorIndex));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
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
                    color: context.appColors.textMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              Text(
                isEditing ? 'Edit profile' : 'New profile',
                style: context.appTypography.h3,
              ),
              const SizedBox(height: AppSpacing.lg),

              // Name
              TvTextField(
                label: 'Profile name',
                hint: 'e.g. Home, Kids, Work',
                prefixIcon: Icons.person_outline,
                controller: _nameController,
              ),
              const SizedBox(height: AppSpacing.lg),

              // Colour picker
              Text('Colour', style: context.appTypography.caption),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: List.generate(kProfileColors.length, (i) {
                  final color = Color(kProfileColors[i]);
                  final isSelected = i == _selectedColorIndex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColorIndex = i),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(10),
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: isSelected
                            ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }),
              ),
              const SizedBox(height: AppSpacing.xl),

              SizedBox(
                height: 56,
                child: _FormButton(
                  label: isEditing ? 'Save changes' : 'Create profile',
                  onPressed: _submit,
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

/// Reusable TV button for forms — matches LoginScreen style.
class _FormButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;

  const _FormButton({required this.label, this.onPressed});

  @override
  State<_FormButton> createState() => _FormButtonState();
}

class _FormButtonState extends State<_FormButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
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
            color: _isFocused ? context.appColors.primary : context.appColors.primary.withOpacity(0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isFocused ? context.appColors.accent : Colors.transparent,
              width: 2,
            ),
            boxShadow: _isFocused
                ? [BoxShadow(color: context.appColors.primary.withOpacity(0.4), blurRadius: 10)]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: context.appTypography.h3.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
