import 'package:flutter/material.dart';
import 'package:zerotrust_fitness/l10n/l10n.dart';

void showPrivacyInfoDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.shield_outlined),
          SizedBox(width: 8),
          Text(context.l10n.howZeroTrustWorks),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _PrivacyPoint(
              icon: Icons.storage_outlined,
              title: context.l10n.localFirstStorage,
              body:
                  context.l10n.allYourHealthDataIs,
            ),
            const SizedBox(height: 12),
            _PrivacyPoint(
              icon: Icons.key_outlined,
              title: context.l10n.yourPasswordYourData,
              body:
                  context.l10n.yourMasterPasswordDerivesThe,
            ),
            const SizedBox(height: 12),
            _PrivacyPoint(
              icon: Icons.cloud_outlined,
              title: context.l10n.endToEndEncryptedBackups,
              body:
                  context.l10n.ifYouChooseToSync,
            ),
            const SizedBox(height: 12),
            _PrivacyPoint(
              icon: Icons.fingerprint,
              title: context.l10n.biometricUnlock,
              body:
                  context.l10n.biometricUnlockStoresOnlyA,
            ),
            const SizedBox(height: 12),
            _PrivacyPoint(
              icon: Icons.toggle_on_outlined,
              title: context.l10n.optInPermissions,
              body:
                  context.l10n.healthConnectAndLocationPermissions,
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.gotIt),
        ),
      ],
    ),
  );
}

class _PrivacyPoint extends StatelessWidget {
  const _PrivacyPoint({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(body, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
