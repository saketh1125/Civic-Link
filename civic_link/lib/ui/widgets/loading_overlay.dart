/// Loading Overlay Widget
///
/// Full-screen semi-transparent overlay with centered spinner and barrier.
/// Used across all screens with async operations.
library;

import 'package:flutter/material.dart';

import '../../core/design/app_decoration.dart';

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final String? message;
  final Widget child;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    this.message,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: ModalBarrier(
              color: scheme.surface.withValues(alpha: 0.75),
              dismissible: false,
            ),
          ),
        if (isLoading)
          Positioned.fill(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: scheme.primary),
                  if (message != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      message!,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
