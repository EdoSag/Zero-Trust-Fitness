import 'package:flutter/material.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_fitness/components/privacy_info_dialog.dart';
import 'package:zerotrust_fitness/l10n/l10n.dart';

/// The welcome page, shown once on a new install before sign-in.
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onGetStarted});

  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: ZtSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const ZtBrandMark(app: ZtSuite.fitness, size: 96),
              const SizedBox(height: ZtSpacing.xl),
              Text(
                ZtSuite.fitness.fullName,
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: ZtSpacing.md),
              Text(
                context.l10n.yourDataYourKeysYour,
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 64),
              FilledButton(
                onPressed: onGetStarted,
                child: Text(context.l10n.getStarted),
              ),
              const SizedBox(height: ZtSpacing.md),
              TextButton(
                onPressed: () => showPrivacyInfoDialog(context),
                child: Text(context.l10n.learnMoreAboutZeroTrust),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
