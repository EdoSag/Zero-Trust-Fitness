import 'package:flutter/material.dart';

void showPrivacyInfoDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.shield_outlined),
          SizedBox(width: 8),
          Text('How Zero-Trust Works'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _PrivacyPoint(
              icon: Icons.storage_outlined,
              title: 'Local-first storage',
              body:
                  'All your health data is encrypted with SQLCipher and stored only on your device. Nothing is uploaded unless you explicitly sync.',
            ),
            const SizedBox(height: 12),
            _PrivacyPoint(
              icon: Icons.key_outlined,
              title: 'Your password, your data',
              body:
                  'Your master password derives the encryption key on-device using key stretching (PBKDF2). The password and key never leave your device.',
            ),
            const SizedBox(height: 12),
            _PrivacyPoint(
              icon: Icons.cloud_outlined,
              title: 'End-to-end encrypted backups',
              body:
                  'If you choose to sync, data is encrypted client-side before uploading. The server stores only an encrypted blob it cannot read.',
            ),
            const SizedBox(height: 12),
            _PrivacyPoint(
              icon: Icons.fingerprint,
              title: 'Biometric unlock',
              body:
                  'Biometric unlock stores only a reference to your passphrase in the OS secure enclave. Your actual health data is never accessible to the biometrics system.',
            ),
            const SizedBox(height: 12),
            _PrivacyPoint(
              icon: Icons.toggle_on_outlined,
              title: 'Opt-in permissions',
              body:
                  'Health Connect and location permissions are always opt-in and revocable. You control exactly which metrics are read.',
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Got it'),
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
