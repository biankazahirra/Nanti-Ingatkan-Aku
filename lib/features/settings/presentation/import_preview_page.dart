import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/failures.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/messages.dart';
import '../../backup/domain/backup_file.dart';

/// F9 / FR-IMP-02 — preview counts, require an explicit replace confirmation,
/// then import atomically. Nothing is written before the confirmation.
class ImportPreviewPage extends ConsumerStatefulWidget {
  const ImportPreviewPage({super.key, required this.file});

  final BackupFile file;

  @override
  ConsumerState<ImportPreviewPage> createState() => _ImportPreviewPageState();
}

class _ImportPreviewPageState extends ConsumerState<ImportPreviewPage> {
  bool _importing = false;
  String? _error;

  Future<void> _apply() async {
    final l10n = AppLocalizations.of(context);
    final deps = ref.read(depsProvider);
    setState(() {
      _importing = true;
      _error = null;
    });
    try {
      final outcome = await deps.backup.applyImport(widget.file);
      if (!mounted) return;
      Navigator.of(context).pop(outcome);
    } on Failure catch (failure) {
      // FR-IMP-02 / NFR-REL-03 — rollback happened; the old data is intact.
      setState(() {
        _importing = false;
        _error = messageForKey(l10n, failure.messageKey);
      });
    } on Object {
      setState(() {
        _importing = false;
        _error = l10n.importFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final file = widget.file;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.importPreviewTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.importReplaceBody(file.memories.length, file.reminders.length),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(l10n.importReplaceTitle),
          if (file.warnings.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (final warning in file.warnings)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  messageForKey(l10n, warning),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _importing ? null : _apply,
            child: Text(l10n.importConfirm),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _importing ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.importCancel),
          ),
          if (_importing)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
