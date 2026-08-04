/// CTA button with optional icon, loading state, and press-scale micro-animation.
///
/// Replaces hand-rolled ElevatedButton + CircularProgressIndicator combos.

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../core/design/app_decoration.dart';
import '../../core/design/app_spacing.dart';

class NeonButton extends StatefulWidget {
  const NeonButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.fullWidth = true,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String label;
  final IconData? icon;

  /// Pass `null` to disable.
  final VoidCallback? onPressed;

  final bool isLoading;
  final bool fullWidth;

  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  State<NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends State<NeonButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _pressController.forward();
  void _onTapUp(TapUpDetails _) => _pressController.reverse();
  void _onTapCancel() => _pressController.reverse();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final effectiveOnPressed = widget.isLoading ? null : widget.onPressed;

    Widget child = widget.isLoading
        ? SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                widget.foregroundColor ?? scheme.onPrimary,
              ),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 18),
                const Gap(AppSpacing.s),
              ],
              Text(widget.label),
            ],
          );

    Widget button = ElevatedButton(
      onPressed: effectiveOnPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: widget.backgroundColor,
        foregroundColor: widget.foregroundColor,
        minimumSize: widget.fullWidth
            ? const Size(double.infinity, 52)
            : const Size(0, 44),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.borderMd),
      ),
      child: child,
    );

    return GestureDetector(
      onTapDown: effectiveOnPressed != null ? _onTapDown : null,
      onTapUp: effectiveOnPressed != null ? _onTapUp : null,
      onTapCancel: effectiveOnPressed != null ? _onTapCancel : null,
      child: ScaleTransition(scale: _scale, child: button),
    );
  }
}
