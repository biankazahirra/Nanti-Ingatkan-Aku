import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/constants.dart';
import '../../../core/format.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/messages.dart';
import '../../backup/data/backup_service.dart';
import 'diagnostics_page.dart';
import 'import_preview_page.dart';
import 'privacy_page.dart';

/// FR-SET-01..07 — health, portability, privacy. Never required for the core
/// loop, and never claims guaranteed delivery.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(settingsStateProvider);
    final health = ref.watch(notificationHealthProvider);
    final deps = ref.watch(depsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          _SectionHeader(title: l10n.settingsSectionNotifications),
          health.when(
            loading: () => const ListTile(title: LinearProgressIndicator()),
            error: (error, _) => ListTile(title: Text(l10n.errorGeneric)),
            data: (value) => Column(
              children: [
                _StatusTile(
                  icon: Icons.notifications_active_outlined,
                  label: l10n.settingsNotificationsEnabled,
                  value: value.notificationsEnabled
                      ? l10n.settingsEnabled
                      : l10n.settingsDisabled,
                ),
                _StatusTile(
                  icon: Icons.alarm,
                  label: l10n.settingsExactAlarm,
                  value: value.exactAlarmAvailable
                      ? l10n.settingsEnabled
                      : l10n.settingsUnavailable,
                  // FR-REM-07 — the grant screen, offered rather than demanded.
                  onTap: value.exactAlarmAvailable
                      ? null
                      : () async {
                          await deps.notifications
                              .requestExactAlarmsPermission();
                          ref.invalidate(notificationHealthProvider);
                        },
                ),
                _StatusTile(
                  icon: Icons.campaign_outlined,
                  label: l10n.settingsChannelEnabled,
                  value: value.notificationsEnabled
                      ? l10n.settingsEnabled
                      : l10n.settingsDisabled,
                ),
                if (value.permissionNeeded > 0)
                  ListTile(
                    leading: const Icon(Icons.notifications_off_outlined),
                    title: Text(
                      l10n.settingsPermissionNeededCount(
                        value.permissionNeeded,
                      ),
                    ),
                  ),
                if (value.schedulingFailed > 0)
                  ListTile(
                    leading: const Icon(Icons.error_outline),
                    title: Text(
                      l10n.settingsSchedulingFailedCount(
                        value.schedulingFailed,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.battery_saver_outlined),
            // `isThreeLine` requires a subtitle, so the long guidance stays a
            // plain wrapping title instead.
            title: Text(l10n.settingsBatteryGuidance),
          ),
          ListTile(
            leading: const Icon(Icons.settings_applications_outlined),
            title: Text(l10n.settingsOpenAppSettings),
            onTap: () => deps.notifications.openAppSettings(),
          ),
          const Divider(),
          _SectionHeader(title: l10n.settingsSectionBackup),
          if (state.maybeWhen(
            data: (value) =>
                _shouldNudge(value.memoryCount, value.lastExportAtUtc),
            orElse: () => false,
          ))
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: const Icon(Icons.backup_outlined),
                title: Text(l10n.settingsBackupNudge),
                trailing: TextButton(
                  onPressed: () async {
                    // FR-SET-07 — record only the timestamp, never nag more
                    // than once per interval.
                    await deps.settings.setLastBackupNudgeAtUtc(
                      DateTime.now().toUtc(),
                    );
                    ref.invalidate(settingsStateProvider);
                  },
                  child: Text(l10n.settingsBackupNudgeDismiss),
                ),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: Text(l10n.exportAction),
            onTap: () => _export(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text(l10n.importAction),
            onTap: () => _import(context, ref),
          ),
          const Divider(),
          _SectionHeader(title: l10n.settingsSectionPrivacy),
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
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l10n.settingsPrivacyLink),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const PrivacyPage()),
            ),
          ),
          const Divider(),
          _SectionHeader(title: l10n.settingsSectionAbout),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.settingsVersion(deps.appVersion)),
            subtitle: Text(l10n.settingsAboutLimitations),
            isThreeLine: true,
          ),
          const Divider(),
          _SectionHeader(title: l10n.settingsSectionDiagnostics),
          ListTile(
            leading: const Icon(Icons.insights_outlined),
            title: Text(l10n.settingsDiagnosticsLink),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const DiagnosticsPage()),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static bool _shouldNudge(int memoryCount, DateTime? lastExportAtUtc) {
    if (memoryCount < Limits.backupNudgeMemoryCount) return false;
    if (lastExportAtUtc == null) return true;
    return DateTime.now().toUtc().difference(lastExportAtUtc) >
        Limits.backupNudgeInterval;
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final deps = ref.read(depsProvider);
    final messenger = ScaffoldMessenger.of(context);

    // FR-EXP-03 — the warning comes before anything is written.
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.exportAction),
        content: Text(l10n.exportWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.exportContinue),
          ),
        ],
      ),
    );
    if (proceed != true) return;

    final result = await deps.backup.export(dialogTitle: l10n.exportAction);
    ref.invalidate(settingsStateProvider);
    messenger.showSnackBar(
      SnackBar(
        content: Text(switch (result.status) {
          ExportResultStatus.saved => l10n.exportDone(result.fileName ?? ''),
          ExportResultStatus.cancelled => l10n.exportCancelled,
          ExportResultStatus.failed => messageForKey(
            l10n,
            result.failure?.messageKey ?? 'export.failed',
          ),
        }),
      ),
    );
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final deps = ref.read(depsProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final validation = await deps.backup.prepareImport(
      dialogTitle: l10n.importAction,
    );
    if (!validation.isValid) {
      final key = validation.failure?.messageKey;
      if (key == 'import.cancelled') return;
      messenger.showSnackBar(
        SnackBar(content: Text(messageForKey(l10n, key ?? 'import.invalid'))),
      );
      return;
    }

    final file = validation.file!;
    final outcome = await navigator.push<ImportOutcome>(
      MaterialPageRoute<ImportOutcome>(
        builder: (_) => ImportPreviewPage(file: file),
      ),
    );
    if (outcome == null) return;

    ref.invalidate(todayProvider);
    ref.invalidate(settingsStateProvider);
    ref.invalidate(memoryListProvider);
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.importSuccess(outcome.memories, outcome.reminders)),
      ),
    );
    if (outcome.schedulingWarnings.isNotEmpty) {
      // FR-IMP-03 — scheduling problems are reported separately.
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${l10n.importSchedulingWarningTitle}: '
            '${outcome.schedulingWarnings.map((key) => messageForKey(l10n, key)).join(', ')}',
          ),
        ),
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: Text(value),
      onTap: onTap,
    );
  }
}

/// FR-EXP-01 helper used by diagnostics too.
String formatExportTimestamp(DateTime utc) => DateFormats.timestamp(utc);
