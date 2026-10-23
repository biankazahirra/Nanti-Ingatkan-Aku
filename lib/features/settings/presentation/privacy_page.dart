import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../l10n/app_localizations.dart';

/// FR-SET-02 / NFR-SEC-05 / NFR-SEC-08 — the honest privacy statement.
class PrivacyPage extends ConsumerWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(settingsStateProvider);
    final deps = ref.watch(depsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.privacyTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.privacyStatement),
          const SizedBox(height: 16),
          Text(l10n.privacyBackupDisabled),
          const SizedBox(height: 16),
          Text(l10n.privacyExportUnencrypted),
          const SizedBox(height: 24),
          state.maybeWhen(
            data: (value) => SwitchListTile(
              value: value.hideNotificationContent,
              title: Text(l10n.privacyHideContent),
              subtitle: Text(l10n.privacyHideContentDesc),
              onChanged: (enabled) async {
                await deps.settings.setHideNotificationContent(enabled);
                ref.invalidate(settingsStateProvider);
              },
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          const Divider(),
          state.maybeWhen(
            data: (value) => ListTile(
              leading: Icon(
                Icons.delete_forever,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(l10n.privacyDeleteAll),
              onTap: () => _deleteAll(context, ref, value.memoryCount),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  /// FR-SET-04 — double confirmation, irreversible.
  Future<void> _deleteAll(
    BuildContext context,
    WidgetRef ref,
    int memoryCount,
  ) async {
    final l10n = AppLocalizations.of(context);
    final deps = ref.read(depsProvider);

    final first = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.privacyDeleteAll),
        content: Text(l10n.deleteAllConfirmCount(memoryCount)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (first != true || !context.mounted) return;

    final second = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.privacyDeleteAll),
        content: Text(l10n.deleteAllConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (second != true) return;

    await deps.backup.deleteAllData();
    ref.invalidate(settingsStateProvider);
    ref.invalidate(todayProvider);
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }
}
