import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/format.dart';
import '../../../l10n/app_localizations.dart';

/// FR-SET-05 — support without PII. Titles, bodies, and notification text never
/// appear here, only counts, versions, and error codes.
class DiagnosticsPage extends ConsumerWidget {
  const DiagnosticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final diagnostics = ref.watch(diagnosticsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.diagnosticsTitle)),
      body: diagnostics.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(l10n.errorGeneric)),
        data: (value) => ListView(
          children: [
            ListTile(
              title: Text(
                l10n.diagnosticsCounts(value.memories, value.reminders),
              ),
            ),
            ListTile(title: Text(l10n.diagnosticsPending(value.pending))),
            ListTile(title: Text(l10n.diagnosticsSchema(value.schemaVersion))),
            ListTile(title: Text(l10n.diagnosticsTimezone(value.timezone))),
            ListTile(
              title: Text(
                l10n.diagnosticsLastReconcile(
                  value.lastReconcileAtUtc == null
                      ? l10n.diagnosticsNone
                      : DateFormats.timestamp(value.lastReconcileAtUtc!),
                ),
              ),
            ),
            ListTile(
              title: Text(
                value.lastErrorCode == null
                    ? l10n.diagnosticsNone
                    : l10n.diagnosticsLastErrorCode(value.lastErrorCode!),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.diagnosticsNoContentNotice,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
