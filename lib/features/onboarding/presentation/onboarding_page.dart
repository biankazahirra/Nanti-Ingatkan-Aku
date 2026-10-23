import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../l10n/app_localizations.dart';

/// FR-ONB-01 — one screen, two exits. Never shown again unless data is wiped.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key, required this.onDone});

  /// Called after `Mulai` or after a successful restore.
  final VoidCallback onDone;

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  bool _busy = false;
  String? _message;

  Future<void> _start() async {
    final deps = ref.read(depsProvider);
    await deps.settings.setOnboardingComplete(true);
    if (!mounted) return;
    widget.onDone();
  }

  Future<void> _restore() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _message = null;
    });
    final deps = ref.read(depsProvider);
    final validation = await deps.backup.prepareImport(
      dialogTitle: l10n.importAction,
    );
    if (!mounted) return;

    if (!validation.isValid) {
      setState(() {
        _busy = false;
        _message = validation.failure?.messageKey == 'import.cancelled'
            ? null
            : l10n.importInvalid;
      });
      return;
    }

    final outcome = await deps.backup.applyImport(validation.file!);
    await deps.settings.setOnboardingComplete(true);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = l10n.importSuccess(outcome.memories, outcome.reminders);
    });
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 24),
            Icon(
              Icons.push_pin_outlined,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(l10n.appName, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(l10n.appTagline, style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            Text(l10n.onboardingBody),
            const SizedBox(height: 24),
            Text(l10n.onboardingPrivacy, style: theme.textTheme.bodySmall),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _busy ? null : _start,
              child: Text(l10n.onboardingStart),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy ? null : _restore,
              child: Text(l10n.onboardingRestore),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(_message!),
              ),
          ],
        ),
      ),
    );
  }
}
