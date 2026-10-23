import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../memories/domain/memory.dart';
import '../../reminders/domain/reminder.dart';
import '../../../core/format.dart';

/// FR-A11Y-04 — status is text + icon, never colour alone.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.icon,
    this.emphasized = false,
  });

  final String label;
  final IconData icon;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: AppLocalizations.of(context).a11yStatusChip(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: emphasized
              ? scheme.errorContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: emphasized
                  ? scheme.onErrorContainer
                  : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

ReminderStatusDisplay describeReminder(
  AppLocalizations l10n,
  Reminder? reminder,
  DateTime nowUtc,
) {
  if (reminder == null) {
    return ReminderStatusDisplay(
      label: l10n.reminderNone,
      icon: Icons.alarm_off_outlined,
      emphasized: false,
      overdue: false,
    );
  }
  if (reminder.isCompleted) {
    return ReminderStatusDisplay(
      label: l10n.reminderDone,
      icon: Icons.check_circle_outline,
      emphasized: false,
      overdue: false,
    );
  }
  if (reminder.isDue(nowUtc)) {
    return ReminderStatusDisplay(
      label: l10n.reminderOverdue,
      icon: Icons.error_outline,
      emphasized: true,
      overdue: true,
    );
  }
  return switch (reminder.schedulingStatus) {
    SchedulingStatus.scheduled => ReminderStatusDisplay(
      label: l10n.reminderScheduled,
      icon: Icons.alarm_on_outlined,
      emphasized: false,
      overdue: false,
    ),
    SchedulingStatus.deferred => ReminderStatusDisplay(
      label: l10n.reminderDeferred,
      icon: Icons.hourglass_empty,
      emphasized: false,
      overdue: false,
    ),
    SchedulingStatus.permissionNeeded => ReminderStatusDisplay(
      label: l10n.reminderPermissionNeeded,
      icon: Icons.notifications_off_outlined,
      emphasized: true,
      overdue: false,
    ),
    SchedulingStatus.schedulingFailed => ReminderStatusDisplay(
      label: l10n.reminderFailed,
      icon: Icons.error_outline,
      emphasized: true,
      overdue: false,
    ),
  };
}

class ReminderStatusDisplay {
  const ReminderStatusDisplay({
    required this.label,
    required this.icon,
    required this.emphasized,
    required this.overdue,
  });

  final String label;
  final IconData icon;
  final bool emphasized;
  final bool overdue;
}

class CategoryChips extends StatelessWidget {
  const CategoryChips({
    super.key,
    required this.selected,
    required this.onSelected,
    this.includeAll = false,
    this.allLabel,
    this.labelBuilder,
  });

  final MemoryCategory? selected;
  final ValueChanged<MemoryCategory?> onSelected;
  final bool includeAll;
  final String? allLabel;

  /// Field label for a category; falls back to the localized category name.
  final String Function(AppLocalizations l10n, MemoryCategory category)?
  labelBuilder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (includeAll)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(allLabel ?? l10n.categoryAll),
                selected: selected == null,
                onSelected: (_) => onSelected(null),
              ),
            ),
          for (final category in MemoryCategory.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(categoryLabel(l10n, category, labelBuilder)),
                selected: selected == category,
                onSelected: (_) => onSelected(category),
              ),
            ),
        ],
      ),
    );
  }
}

String categoryLabel(
  AppLocalizations l10n,
  MemoryCategory category,
  String Function(AppLocalizations l10n, MemoryCategory category)? builder,
) {
  if (builder != null) return builder(l10n, category);
  return switch (category) {
    MemoryCategory.general => l10n.categoryGeneral,
    MemoryCategory.lentItem => l10n.categoryLentItem,
    MemoryCategory.warranty => l10n.categoryWarranty,
    MemoryCategory.maintenance => l10n.categoryMaintenance,
  };
}

class ArchivedBadge extends StatelessWidget {
  const ArchivedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return StatusChip(
      label: l10n.memoriesArchivedBadge,
      icon: Icons.inventory_2_outlined,
    );
  }
}

/// §5.5 row: title (2 lines), body excerpt (1 line), category, reminder status.
class MemoryListTile extends StatelessWidget {
  const MemoryListTile({
    super.key,
    required this.memory,
    required this.reminder,
    required this.nowUtc,
    required this.zoneId,
    required this.onTap,
    this.showDueTime = false,
  });

  final Memory memory;
  final Reminder? reminder;
  final DateTime nowUtc;
  final String zoneId;
  final VoidCallback onTap;
  final bool showDueTime;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = describeReminder(l10n, reminder, nowUtc);
    final due = reminder;
    final dueLabel = due == null
        ? null
        : showDueTime
        ? DateFormats.dueLabel(due.dueAtUtc, nowUtc, zoneId)
        : DateFormats.date(due.dueAtUtc);

    return Semantics(
      button: true,
      label: l10n.a11yOpenMemory(memory.title),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      memory.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (dueLabel != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      dueLabel,
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.end,
                    ),
                  ],
                ],
              ),
              if (memory.bodyExcerpt.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  memory.bodyExcerpt,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
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
                  if (memory.isArchived) ArchivedBadge(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
