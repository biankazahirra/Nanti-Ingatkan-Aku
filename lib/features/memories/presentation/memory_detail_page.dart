import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/constants.dart';
import '../../../core/format.dart';
import '../../../l10n/app_localizations.dart';
import '../../reminders/domain/reminder.dart';
import '../../reminders/domain/reminder_repository.dart';
import '../../reminders/presentation/reminder_editor.dart';
import '../domain/memory.dart';
import 'memory_form_page.dart';
import 'widgets.dart';

/// §5.6 / FR-MEM-02..05, FR-REM-08, FR-REM-10 — read and act on one memory.
class MemoryDetailPage extends ConsumerStatefulWidget {
  const MemoryDetailPage({
    super.key,
    required this.memoryId,
    this.savedConfirmation = false,
  });

  final String memoryId;

  /// F1 — confirms `Catatan tersimpan` right after a create.
  final bool savedConfirmation;

  @override
  ConsumerState<MemoryDetailPage> createState() => _MemoryDetailPageState();
}

class _MemoryDetailPageState extends ConsumerState<MemoryDetailPage> {
  @override
  void initState() {
    super.initState();
    if (widget.savedConfirmation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).captureSaved)),
        );
      });
    }
  }

  void _refresh() {
    ref.invalidate(memoryDetailProvider(widget.memoryId));
    ref.invalidate(todayProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final deps = ref.watch(depsProvider);
    final detail = ref.watch(memoryDetailProvider(widget.memoryId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navMemories),
        actions: [
          detail.maybeWhen(
            data: (value) => value == null
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: l10n.detailActionEdit,
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _edit(value.memory),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(l10n.errorGeneric)),
        data: (value) {
          if (value == null) {
            // FR-REM-10 — the target no longer exists.
            return _MissingMemory(onBack: () => Navigator.of(context).pop());
          }
          final memory = value.memory;
          final reminder = value.reminder;
          final status = describeReminder(l10n, reminder, deps.clock.nowUtc());
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  memory.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusChip(
                      label: categoryLabel(l10n, memory.category, null),
                      icon: Icons.label_outline,
                    ),
                    if (reminder != null)
                      StatusChip(
                        label: status.label,
                        icon: status.icon,
                        emphasized: status.emphasized,
                      ),
                    if (memory.isArchived) const ArchivedBadge(),
                  ],
                ),
              ),
              if (memory.body.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Text(memory.body),
                ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              _MetadataSection(memory: memory),
              const Divider(height: 1),
              _ReminderBlock(
                memory: memory,
                reminder: reminder,
                nowUtc: deps.clock.nowUtc(),
                currentZone: deps.clock.zone.name,
                onAction: _refresh,
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: Text(l10n.detailActionEdit),
                      onTap: () => _edit(memory),
                    ),
                    ListTile(
                      leading: Icon(
                        memory.isArchived
                            ? Icons.unarchive_outlined
                            : Icons.archive_outlined,
                      ),
                      title: Text(
                        memory.isArchived
                            ? l10n.detailActionUnarchive
                            : l10n.detailActionArchive,
                      ),
                      onTap: () => _toggleArchive(memory, reminder),
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: Text(l10n.detailActionDelete),
                      onTap: () => _delete(memory),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  '${l10n.detailCreated(DateFormats.timestamp(memory.createdAtUtc))}\n'
                  '${l10n.detailUpdated(DateFormats.timestamp(memory.updatedAtUtc))}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _edit(Memory memory) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => MemoryFormPage(memory: memory)),
    );
    _refresh();
  }

  Future<void> _toggleArchive(Memory memory, Reminder? reminder) async {
    final l10n = AppLocalizations.of(context);
    final deps = ref.read(depsProvider);
    final archiving = !memory.isArchived;

    if (archiving && reminder != null && reminder.isPending) {
      // FR-MEM-04 / DEC-08 — never silently cancel a reminder.
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.detailActionArchive),
          content: Text(l10n.archiveKeepsReminder),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.commonOk),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    await deps.memories.setArchived(memory.id, archiving);
    _refresh();
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          archiving ? l10n.detailArchiveSnack : l10n.detailUnarchiveSnack,
        ),
        duration: Limits.undoWindow,
        action: SnackBarAction(
          label: l10n.reminderUndo,
          onPressed: () async {
            // FR-MEM-10 — undo restores the previous listing.
            await deps.memories.setArchived(memory.id, !archiving);
            _refresh();
          },
        ),
      ),
    );
  }

  Future<void> _delete(Memory memory) async {
    final l10n = AppLocalizations.of(context);
    final deps = ref.read(depsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.detailActionDelete),
        // FR-MEM-05 — name the memory and warn about the reminder.
        content: Text(l10n.deleteConfirmNamed(memory.title)),
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
    if (confirmed != true) return;

    await deps.memories.delete(memory.id);
    ref.invalidate(todayProvider);
    if (!mounted) return;
    Navigator.of(context).pop();
  }
}

class _MetadataSection extends StatelessWidget {
  const _MetadataSection({required this.memory});

  final Memory memory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rows = <Widget>[];
    if (memory.personName != null) {
      rows.add(_row(context, l10n.fieldLentTo, memory.personName!));
    }
    if (memory.itemName != null) {
      rows.add(_row(context, l10n.fieldItemName, memory.itemName!));
    }
    if (memory.warrantyEndDate != null) {
      final parsed = DateTime.tryParse(memory.warrantyEndDate!);
      rows.add(
        _row(
          context,
          l10n.fieldWarrantyEnd,
          parsed == null ? memory.warrantyEndDate! : DateFormats.date(parsed),
        ),
      );
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class _ReminderBlock extends ConsumerWidget {
  const _ReminderBlock({
    required this.memory,
    required this.reminder,
    required this.nowUtc,
    required this.currentZone,
    required this.onAction,
  });

  final Memory memory;
  final Reminder? reminder;
  final DateTime nowUtc;
  final String currentZone;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final deps = ref.watch(depsProvider);

    final header = _SectionHeader(title: l10n.reminderSectionTitle);

    if (reminder == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          ListTile(
            leading: const Icon(Icons.alarm_off_outlined),
            title: Text(l10n.reminderNone),
            trailing: TextButton(
              onPressed: () => _createOrChange(context, ref),
              child: Text(l10n.reminderCreate),
            ),
          ),
        ],
      );
    }

    final value = reminder!;
    final overdue = value.isDue(nowUtc);
    final when = DateFormats.dateTime(value.dueAtUtc.toLocal());

    String label;
    Widget? trailing;
    if (value.isCompleted) {
      label = l10n.reminderDoneAt(
        DateFormats.timestamp(value.completedAtUtc ?? value.dueAtUtc),
      );
      // FR-REM-01 — the only path back to pending, with a new due time.
      trailing = TextButton(
        onPressed: () => _createOrChange(context, ref),
        child: Text(l10n.reminderNew),
      );
    } else if (overdue) {
      label = l10n.reminderOverdueSince(when);
    } else {
      label = switch (value.schedulingStatus) {
        SchedulingStatus.scheduled => l10n.reminderScheduledAt(when),
        SchedulingStatus.deferred => l10n.reminderDeferred,
        SchedulingStatus.permissionNeeded => l10n.reminderPermissionNeeded,
        SchedulingStatus.schedulingFailed => l10n.reminderFailed,
      };
      if (value.schedulingStatus == SchedulingStatus.schedulingFailed) {
        trailing = TextButton(
          onPressed: () async {
            await deps.reconcile.reconcile(force: true);
            onAction();
          },
          child: Text(l10n.reminderRetry),
        );
      }
    }

    final showChange = value.isPending;
    final showComplete = value.isPending;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        ListTile(
          leading: Icon(
            overdue ? Icons.error_outline : Icons.alarm_on_outlined,
          ),
          title: Text(label),
          subtitle:
              value.isPending &&
                  value.precision == ReminderPrecision.inexact &&
                  !overdue
              ? Text(l10n.reminderInexact)
              : null,
          trailing: trailing,
        ),
        if (value.isPending && value.zoneDiffersFrom(currentZone))
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              l10n.reminderZoneNote(value.scheduledTimezone, currentZone),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Wrap(
            spacing: 8,
            children: [
              if (showChange)
                TextButton.icon(
                  onPressed: () => _createOrChange(context, ref),
                  icon: const Icon(Icons.edit_calendar),
                  label: Text(l10n.reminderChange),
                ),
              if (showComplete)
                TextButton.icon(
                  onPressed: () => _complete(context, ref),
                  icon: const Icon(Icons.check),
                  label: Text(l10n.reminderMarkDone),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _complete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final deps = ref.read(depsProvider);
    final value = reminder;
    if (value == null) return;

    await deps.reminders.complete(memory.id);
    onAction();
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.reminderDoneSnack),
        duration: Limits.undoWindow,
        action: SnackBarAction(
          label: l10n.reminderUndo,
          onPressed: () async {
            // F4 — undo restores pending with the same due time and reschedules.
            await deps.reminders.reopen(
              memory.id,
              ReminderRequest(
                memoryId: memory.id,
                dueAtUtc: value.dueAtUtc,
                scheduledLocalDatetime: value.scheduledLocalDatetime,
                scheduledTimezone: value.scheduledTimezone,
              ),
            );
            onAction();
          },
        ),
      ),
    );
  }

  Future<void> _createOrChange(BuildContext context, WidgetRef ref) async {
    final deps = ref.read(depsProvider);
    final l10n = AppLocalizations.of(context);
    final composer = ReminderComposer(
      zone: deps.clock.zone,
      nowUtc: deps.clock.nowUtc(),
    );
    final current = reminder;
    final pending = current == null || current.isCompleted
        ? null
        : composer.fromStored(
            dueAtUtc: current.dueAtUtc,
            scheduledLocalDatetime: current.scheduledLocalDatetime,
            zoneId: current.scheduledTimezone,
          );

    final result = await showModalBottomSheet<PendingReminder>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _ReminderSheet(
        composer: composer,
        initial: pending,
        title: current == null || current.isCompleted
            ? l10n.reminderCreate
            : l10n.reminderChange,
      ),
    );
    if (result == null) return;

    final request = ReminderRequest(
      memoryId: memory.id,
      dueAtUtc: result.dueAtUtc,
      scheduledLocalDatetime: result.scheduledLocalDatetime,
      scheduledTimezone: result.zoneId,
    );
    if (current == null) {
      await deps.reminders.save(request);
    } else if (current.isCompleted) {
      await deps.reminders.reopen(memory.id, request);
    } else {
      // F5 — same notification id replaces the previous schedule.
      await deps.reminders.save(request);
    }
    onAction();
  }
}

class _ReminderSheet extends StatefulWidget {
  const _ReminderSheet({
    required this.composer,
    required this.title,
    this.initial,
  });

  final ReminderComposer composer;
  final String title;
  final PendingReminder? initial;

  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  PendingReminder? _value;
  String? _error;

  @override
  void initState() {
    super.initState();
    _value = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(
                widget.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ReminderSection(
              composer: widget.composer,
              enabled: true,
              value: _value,
              onEnabledChanged: (_) {},
              onValueChanged: (value) => setState(() {
                _value = value;
                _error = null;
              }),
              onError: (key) => setState(() => _error = key),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  switch (_error) {
                    'error.due_past' => l10n.errorDuePast,
                    _ => l10n.errorGeneric,
                  },
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: _value == null
                    ? null
                    : () => Navigator.of(context).pop(_value),
                child: Text(l10n.captureSave),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissingMemory extends StatelessWidget {
  const _MissingMemory({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.todayDeletedMemory),
            const SizedBox(height: 16),
            FilledButton(onPressed: onBack, child: Text(l10n.commonClose)),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}
