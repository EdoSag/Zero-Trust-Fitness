import 'package:flutter/material.dart';
import 'package:zerotrust_fitness/core/utils/error_messages.dart';

class ErrorStateWidget extends StatelessWidget {
  const ErrorStateWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.onOpenSettings,
  });

  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline,
                color: theme.colorScheme.error, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
            if (onOpenSettings != null) ...[
              const SizedBox(width: 4),
              TextButton(
                onPressed: onOpenSettings,
                child: const Text('Settings'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

void showActionableErrorSnackBar(
  BuildContext context, {
  required Object error,
  VoidCallback? onRetry,
}) {
  final message = friendlyErrorMessage(error);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      action: onRetry == null
          ? null
          : SnackBarAction(label: 'Retry', onPressed: onRetry),
    ),
  );
}
