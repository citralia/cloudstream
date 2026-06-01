import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';

/// TV/Firestick-friendly text input.
/// - Does NOT trigger the system keyboard on focus.
/// - Shows visual focus indicator (border glow).
/// - Tap Select to open the soft keyboard overlay.
/// - DPad navigable between fields without keyboard appearing.
class TvTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;
  final String? Function(String?)? validator;

  const TvTextField({
    super.key,
    required this.label,
    this.hint,
    this.prefixIcon,
    required this.controller,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.onChanged,
    this.onSubmitted,
    this.validator,
  });

  @override
  State<TvTextField> createState() => _TvTextFieldState();
}

class _TvTextFieldState extends State<TvTextField> {
  final _focusNode = FocusNode();
  bool _isFocused = false;
  bool _hasError = false;
  String? _errorText;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    widget.controller.removeListener(_onTextChange);
    super.dispose();
  }

  void _onFocusChange() {
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  void _onTextChange() {
    if (widget.validator != null) {
      final error = widget.validator!(widget.controller.text);
      setState(() {
        _hasError = error != null;
        _errorText = error;
      });
    }
  }

  void _openKeyboard() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => TvSoftKeyboard(
        controller: widget.controller,
        label: widget.label,
        hint: widget.hint,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        onDone: () {
          widget.onSubmitted?.call();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        // Select (OK) button opens soft keyboard
        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.gameButtonA) {
          _openKeyboard();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: _openKeyboard,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hasError
                  ? AppColors.error
                  : _isFocused
                      ? AppColors.primary
                      : AppColors.divider,
              width: _isFocused || _hasError ? 2 : 1,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 0,
                    )
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.md,
                  top: AppSpacing.sm,
                ),
                child: Text(
                  widget.label,
                  style: AppTypography.micro.copyWith(
                    color: _isFocused ? AppColors.primary : AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // Input display
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  bottom: AppSpacing.sm,
                  top: 2,
                ),
                child: Row(
                  children: [
                    if (widget.prefixIcon != null) ...[
                      Icon(
                        widget.prefixIcon,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Expanded(
                      child: Text(
                        _displayText,
                        style: AppTypography.body.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.obscureText)
                      IconButton(
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ),
              // Error message
              if (_hasError && _errorText != null)
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.md,
                    bottom: AppSpacing.xs,
                  ),
                  child: Text(
                    _errorText!,
                    style: AppTypography.micro.copyWith(color: AppColors.error),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String get _displayText {
    final text = widget.controller.text;
    if (text.isEmpty) return widget.hint ?? '';
    if (widget.obscureText && !_showPassword) {
      return '•' * text.length;
    }
    return text;
  }
}

/// Full-screen TV soft keyboard overlay.
/// DPad-navigable character grid + action row.
class TvSoftKeyboard extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final TextInputType keyboardType;
  final VoidCallback onDone;

  const TvSoftKeyboard({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    required this.onDone,
  });

  @override
  State<TvSoftKeyboard> createState() => _TvSoftKeyboardState();
}

class _TvSoftKeyboardState extends State<TvSoftKeyboard> {
  late String _text;
  int _cursorPos = 0;
  bool _shift = false;
  bool _capsLock = false;

  @override
  void initState() {
    super.initState();
    _text = widget.controller.text;
    _cursorPos = _text.length;
  }

  void _insertChar(String char) {
    final c = (_shift || _capsLock) ? char.toUpperCase() : char;
    setState(() {
      _text = _text.substring(0, _cursorPos) + c + _text.substring(_cursorPos);
      _cursorPos++;
      if (_shift && !_capsLock) _shift = false;
    });
  }

  void _backspace() {
    if (_cursorPos > 0) {
      setState(() {
        _text = _text.substring(0, _cursorPos - 1) + _text.substring(_cursorPos);
        _cursorPos--;
      });
    }
  }

  void _moveCursor(int delta) {
    setState(() {
      _cursorPos = (_cursorPos + delta).clamp(0, _text.length);
    });
  }

  void _commit() {
    widget.controller.text = _text;
    widget.controller.selection = TextSelection.collapsed(offset: _text.length);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Text(
                    widget.label,
                    style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.divider, height: 1),
            // Input display
            Container(
              margin: const EdgeInsets.all(AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _text.isEmpty
                          ? (widget.hint ?? ' ')
                          : _text,
                      style: AppTypography.body.copyWith(
                        color: _text.isEmpty
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 20,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
            // Keyboard
            _buildKeyboard(),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyboard() {
    final rows = _getKeyboardRows();
    return Column(
      children: [
        for (int r = 0; r < rows.length; r++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: rows[r]
                  .map((key) => _buildKey(key))
                  .toList(),
            ),
          ),
          if (r < rows.length - 1) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }

  List<List<String>> _getKeyboardRows() {
    if (widget.keyboardType == TextInputType.url) {
      return [
        ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
        ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'],
        ['z', 'x', 'c', 'v', 'b', 'n', 'm', '←'],
        ['⇧', '.', '/', ':', '-', '_', '@', 'Done'],
      ];
    }
    return [
      ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
      ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'],
      [_shift || _capsLock ? '⬆' : '⇧', 'z', 'x', 'c', 'v', 'b', 'n', 'm', '←'],
      ['123', '.', '/', '-', '@', '.com', 'Done'],
    ];
  }

  Widget _buildKey(String key) {
    final isAction = key == '←' || key == '⇧' || key == '⬆' || key == 'Done' || key == '123';
    final display = _keyDisplay(key);

    return Padding(
      padding: const EdgeInsets.all(2),
      child: _TvKey(
        label: display,
        isAction: isAction,
        onTap: () => _handleKey(key),
      ),
    );
  }

  String _keyDisplay(String key) {
    switch (key) {
      case '←': return '⌫';
      case '⇧': return '⇧';
      case '⬆': return '⬆';
      case 'Done': return 'Done';
      case '123': return '123';
      case '.com': return '.com';
      default: return key;
    }
  }

  void _handleKey(String key) {
    switch (key) {
      case '←':
        _backspace();
        break;
      case '⇧':
        setState(() {
          if (_capsLock) {
            _capsLock = false;
            _shift = false;
          } else {
            _shift = !_shift;
          }
        });
        break;
      case '⬆':
        setState(() => _capsLock = !_capsLock);
        break;
      case 'Done':
        _commit();
        break;
      case '123':
        // Switch to numeric — simplified, toggle via state if needed
        setState(() {});
        break;
      case '.com':
        _insertChar('.com');
        break;
      default:
        _insertChar(key);
    }
  }
}

class _TvKey extends StatefulWidget {
  final String label;
  final bool isAction;
  final VoidCallback onTap;

  const _TvKey({
    required this.label,
    required this.isAction,
    required this.onTap,
  });

  @override
  State<_TvKey> createState() => _TvKeyState();
}

class _TvKeyState extends State<_TvKey> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.gameButtonA) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _focusNext();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _focusPrev();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _focusDown();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _focusUp();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (ctx) {
          return GestureDetector(
            onTap: widget.onTap,
            child: Focus(
              onFocusChange: (focused) => setState(() => _isFocused = focused),
              child: Container(
                width: widget.label.length > 2 ? 64 : 40,
                height: 48,
                decoration: BoxDecoration(
                  color: _isFocused
                      ? AppColors.primary
                      : widget.isAction
                          ? AppColors.surface
                          : AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _isFocused ? AppColors.accent : AppColors.divider,
                    width: _isFocused ? 2 : 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.label,
                  style: AppTypography.body.copyWith(
                    color: _isFocused ? Colors.white : AppColors.textPrimary,
                    fontWeight: widget.isAction ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _focusNext() {
    Focus.of(context).nextFocus();
  }

  void _focusPrev() {
    Focus.of(context).previousFocus();
  }

  void _focusDown() {
    // Find next row — handled by Focus traversal
    Focus.of(context).nextFocus();
  }

  void _focusUp() {
    Focus.of(context).previousFocus();
  }
}
