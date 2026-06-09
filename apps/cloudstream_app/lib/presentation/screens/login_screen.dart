import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_extensions.dart';
import '../providers/app_providers.dart';
import '../widgets/tv_text_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _nameController = TextEditingController();
  final _serverUrlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _serverUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateServerUrl(String? val) {
    if (val == null || val.trim().isEmpty) return 'Server URL is required';
    if (!val.trim().startsWith('http://') && !val.trim().startsWith('https://')) {
      return 'URL must start with http:// or https://';
    }
    return null;
  }

  String? _validateRequired(String? val) {
    if (val == null || val.trim().isEmpty) return 'This field is required';
    return null;
  }

  Future<void> _onLogin() async {
    // Validate manually since we can't use FormField with TvTextField easily
    final serverError = _validateServerUrl(_serverUrlController.text);
    final usernameError = _validateRequired(_usernameController.text);
    final passwordError = _validateRequired(_passwordController.text);

    if (serverError != null || usernameError != null || passwordError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(serverError ?? usernameError ?? passwordError ?? 'Validation error'),
          backgroundColor: context.appColors.error,
        ),
      );
      return;
    }

    final profileName = _nameController.text.trim().isEmpty
        ? Uri.parse(_serverUrlController.text.trim()).host
        : _nameController.text.trim();

    await ref.read(authProvider.notifier).login(
      name: profileName,
      serverUrl: _serverUrlController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthStatus.unknown;
    final colors = context.appColors;
    final typo = context.appTypography;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo + tagline
                Icon(
                  Icons.live_tv_rounded,
                  size: 72,
                  color: colors.primary,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'CloudStream',
                  style: typo.h1.copyWith(color: colors.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Your TV. Everywhere.',
                  style: typo.caption,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xxxl),

                // Profile name (optional)
                Focus(
                  autofocus: true,
                  child: TvTextField(
                    label: 'Profile name (optional)',
                    hint: 'e.g. Home, Work',
                    prefixIcon: Icons.label_outline,
                    controller: _nameController,
                  ),
                ),

                // Server URL
                TvTextField(
                  label: 'Xtream server URL',
                  hint: 'http://1.2.3.4:8080',
                  prefixIcon: Icons.dns_outlined,
                  controller: _serverUrlController,
                  keyboardType: TextInputType.url,
                  validator: _validateServerUrl,
                ),
                const SizedBox(height: AppSpacing.lg),

                // Username
                TvTextField(
                  label: 'Username',
                  prefixIcon: Icons.person_outline,
                  controller: _usernameController,
                  validator: _validateRequired,
                ),
                const SizedBox(height: AppSpacing.lg),

                // Password
                TvTextField(
                  label: 'Password',
                  prefixIcon: Icons.lock_outline,
                  controller: _passwordController,
                  obscureText: true,
                  validator: _validateRequired,
                  onSubmitted: _onLogin,
                ),

                // Error message
                if (authState.error != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: colors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.error.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: colors.error, size: 20),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            authState.error!,
                            style: typo.caption.copyWith(color: colors.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.xl),

                // Login button — TV-friendly, large touch target
                SizedBox(
                  height: 60,
                  child: _TvButton(
                    label: isLoading ? 'Signing in…' : 'Sign in',
                    isLoading: isLoading,
                    onPressed: isLoading ? null : _onLogin,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// TV-friendly button with DPad support and focus glow.
class _TvButton extends StatefulWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _TvButton({
    required this.label,
    this.isLoading = false,
    this.onPressed,
  });

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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: widget.isLoading
                ? colors.primary.withOpacity(0.5)
                : _isFocused
                    ? colors.primary
                    : colors.primary.withOpacity(0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isFocused ? colors.accent : Colors.transparent,
              width: 2,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: colors.primary.withOpacity(0.5),
                      blurRadius: 12,
                      spreadRadius: 0,
                    )
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.textPrimary,
                  ),
                )
              : Text(
                  widget.label,
                  // Primary button text is always the "on" colour
                  // — on a `primary`-coloured background, the right
                  // token is whichever side reads as the "surface"
                  // colour in the active theme.
                  style: typo.h3.copyWith(color: colors.surface),
                ),
        ),
      ),
    );
  }
}
