/// Error Banner Widget
///
/// Colored banner for displaying error, warning, or info messages.
/// Used across all screens with form submission or API calls.

import 'package:flutter/material.dart';

enum ErrorType { error, warning, info }

class ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onDismiss;
  final ErrorType type;

  const ErrorBanner({
    super.key,
    required this.message,
    this.onDismiss,
    this.type = ErrorType.error,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _getColors();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.$2),
      ),
      child: Row(
        children: [
          Icon(colors.$3, color: colors.$2, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.$2, fontSize: 13),
            ),
          ),
          if (onDismiss != null)
            GestureDetector(
              onTap: onDismiss,
              child: Icon(Icons.close, color: colors.$2, size: 18),
            ),
        ],
      ),
    );
  }

  (Color, Color, IconData) _getColors() {
    switch (type) {
      case ErrorType.error:
        return (
          Colors.red.shade900.withOpacity(0.3),
          Colors.redAccent,
          Icons.error_outline,
        );
      case ErrorType.warning:
        return (
          Colors.orange.shade900.withOpacity(0.3),
          Colors.orangeAccent,
          Icons.warning_amber,
        );
      case ErrorType.info:
        return (
          Colors.blue.shade900.withOpacity(0.3),
          Colors.blueAccent,
          Icons.info_outline,
        );
    }
  }
}
