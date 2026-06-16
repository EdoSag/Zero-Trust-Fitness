import 'package:flutter/material.dart';

class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  factory EmptyStateWidget.noData(String metricName, {Widget? action}) {
    return EmptyStateWidget(
      icon: Icons.bar_chart_outlined,
      title: 'No $metricName data',
      subtitle: 'Sync from Health Connect or log an entry manually.',
      action: action,
    );
  }

  factory EmptyStateWidget.permissionRequired(
    String metricName, {
    VoidCallback? onGrant,
  }) {
    return EmptyStateWidget(
      icon: Icons.lock_outline,
      title: 'Permission required',
      subtitle:
          '$metricName access is not granted. Enable it in Permissions.',
      action: onGrant == null
          ? null
          : TextButton.icon(
              onPressed: onGrant,
              icon: const Icon(Icons.settings_outlined, size: 16),
              label: const Text('Grant permission'),
            ),
    );
  }

  factory EmptyStateWidget.notTracked(String metricName) {
    return EmptyStateWidget(
      icon: Icons.device_unknown_outlined,
      title: 'Not tracked',
      subtitle: '$metricName is not supported on this device.',
    );
  }

  factory EmptyStateWidget.vaultLocked({VoidCallback? onUnlock}) {
    return EmptyStateWidget(
      icon: Icons.lock_outline,
      title: 'Vault locked',
      subtitle: 'Unlock your vault to see health data.',
      action: onUnlock == null
          ? null
          : FilledButton.icon(
              onPressed: onUnlock,
              icon: const Icon(Icons.fingerprint),
              label: const Text('Unlock'),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor:
                  theme.colorScheme.secondary.withValues(alpha: 0.1),
              child: Icon(icon, color: theme.colorScheme.secondary),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style:
                    theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 12),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
