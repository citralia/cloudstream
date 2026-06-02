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
                      color: AppColors.primary.withOpacity(0.3),
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
/// Parent (TvSoftKeyboardState) owns focus grid so navigation is explicit.
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

  // Explicit focus grid — parent owns navigation
  int _focusRow = 0;
  int _focusCol = 0;
  late List<List<String>> _rows;

  // Focus nodes for every key
  late List<List<FocusNode>> _focusNodes;

  @override
  void initState() {
    super.initState();
    _text = widget.controller.text;
    _cursorPos = _text.length;
    _buildRowsAndNodes();
  }

  void _buildRowsAndNodes() {
    _rows = _getKeyboardRows();
    _focusNodes = List.generate(
      _rows.length,
      (r) => List.generate(_rows[r].length, (c) => FocusNode()),
    );
    // Auto-focus first key
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestFocus(0, 0);
    });
  }

  @override
  void dispose() {
    for (final row in _focusNodes) {
      for (final node in row) {
        node.dispose();
      }
    }
    super.dispose();
  }

  void _requestFocus(int row, int col) {
    final r = row.clamp(0, _rows.length - 1);
    final c = col.clamp(0, _rows[r].length - 1);
    _focusRow = r;
    _focusCol = c;
    _focusNodes[r][c].requestFocus();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;

    final key = event.logicalKey;
    final rows = _rows[_focusRow];
    final curKey = rows[_focusCol];

    if (key == LogicalKeyboardKey.arrowRight) {
      if (_focusCol < rows.length - 1) {
        _requestFocus(_focusRow, _focusCol + 1);
      }
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      if (_focusCol > 0) {
        _requestFocus(_focusRow, _focusCol - 1);
      }
    } else if (key == LogicalKeyboardKey.arrowDown) {
      if (_focusRow < _rows.length - 1) {
        final nextRowLen = _rows[_focusRow + 1].length;
        _requestFocus(_focusRow + 1, _focusCol.clamp(0, nextRowLen - 1));
      }
    } else if (key == LogicalKeyboardKey.arrowUp) {
      if (_focusRow > 0) {
        final prevRowLen = _rows[_focusRow - 1].length;
        _requestFocus(_focusRow - 1, _focusCol.clamp(0, prevRowLen - 1));
      }
    } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.gameButtonA) {
      _handleKey(curKey);
    }
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

  void _commit() {
    widget.controller.text = _text;
    widget.controller.selection = TextSelection.collapsed(offset: _text.length);
    widget.onDone();
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
          // refresh nodes for shift indicator
          _buildRowsAndNodes();
        });
        break;
      case '⬆':
        setState(() {
          _capsLock = !_capsLock;
          _buildRowsAndNodes();
        });
        break;
      case 'Done':
        _commit();
        break;
      case '123':
        setState(() {});
        break;
      case '.com':
        _insertChar('.com');
        break;
      default:
        _insertChar(key);
    }
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
                      _text.isEmpty ? (widget.hint ?? ' ') : _text,
                      style: AppTypography.body.copyWith(
                        color: _text.isEmpty ? AppColors.textMuted : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(width: 2, height: 20, color: AppColors.primary),
                ],
              ),
            ),
            // Keyboard — single Focus wraps all keys, parent handles navigation
            Focus(
              autofocus: true,
              onKeyEvent: (node, event) {
                _handleKeyEvent(event);
                return KeyEventResult.handled;
              },
              child: Column(
                children: [
                  for (int r = 0; r < _rows.length; r++) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (int c = 0; c < _rows[r].length; c++)
                            _KeyboardKey(
                              focusNode: _focusNodes[r][c],
                              label: _keyDisplay(_rows[r][c]),
                              isFocused: _focusRow == r && _focusCol == c,
                              isAction: _rows[r][c] == '←' ||
                                  _rows[r][c] == '⇧' ||
                                  _rows[r][c] == '⬆' ||
                                  _rows[r][c] == 'Done' ||
                                  _rows[r][c] == '123',
                              onTap: () => _handleKey(_rows[r][c]),
                            ),
                        ],
                      ),
                    ),
                    if (r < _rows.length - 1) const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

class _KeyboardKey extends StatelessWidget {
  final FocusNode focusNode;
  final String label;
  final bool isFocused;
  final bool isAction;
  final VoidCallback onTap;

  const _KeyboardKey({
    required this.focusNode,
    required this.label,
    required this.isFocused,
    required this.isAction,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: label.length > 2 ? 64 : 40,
          height: 48,
          decoration: BoxDecoration(
            color: isFocused
                ? AppColors.primary
                : isAction
                    ? AppColors.surface
                    : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isFocused ? AppColors.accent : AppColors.divider,
              width: isFocused ? 2 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTypography.body.copyWith(
              color: isFocused ? Colors.white : AppColors.textPrimary,
              fontWeight: isAction ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
