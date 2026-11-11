import 'package:flutter/material.dart';
import 'package:zerotrust_fitness/l10n/l10n.dart';

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
      title: currentL10n.noMetricData(metricName),
      subtitle: currentL10n.syncFromHealthConnectOr,
      action: action,
    );
  }

  factory EmptyStateWidget.permissionRequired(
    String metricName, {
    VoidCallback? onGrant,
  }) {
    return EmptyStateWidget(
      icon: Icons.lock_outline,
      title: currentL10n.permissionRequired,
      subtitle:
          currentL10n.metricAccessNotGranted(metricName),
      action: onGrant == null
          ? null
          : TextButton.icon(
              onPressed: onGrant,
              icon: const Icon(Icons.settings_outlined, size: 16),
              label: Text(currentL10n.grantPermission),
            ),
    );
  }

  factory EmptyStateWidget.notTracked(String metricName) {
    return EmptyStateWidget(
      icon: Icons.device_unknown_outlined,
      title: currentL10n.notTracked,
      subtitle: currentL10n.metricNotSupported(metricName),
    );
  }

  factory EmptyStateWidget.vaultLocked({VoidCallback? onUnlock}) {
    return EmptyStateWidget(
      icon: Icons.lock_outline,
      title: currentL10n.vaultLocked,
      subtitle: currentL10n.unlockYourVaultToSee,
      action: onUnlock == null
          ? null
          : FilledButton.icon(
              onPressed: onUnlock,
              icon: const Icon(Icons.fingerprint),
              label: Text(currentL10n.unlock),
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
