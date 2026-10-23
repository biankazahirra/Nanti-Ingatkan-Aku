import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/format.dart';
import '../../../core/time.dart';
import '../../../l10n/app_localizations.dart';

/// A reminder the user has chosen but not yet saved.
class PendingReminder {
  const PendingReminder({
    required this.dueAtUtc,
    required this.localFields,
    required this.zoneId,
    this.transition,
  });

  final DateTime dueAtUtc;

  /// The wall-clock time the user picked, kept verbatim for display and
  /// recovery (§7.3) — never the scheduling authority.
  final DateTime localFields;
  final String zoneId;
  final LocalTimeResolution? transition;

  bool get shifted => transition?.shifted ?? false;

  bool get ambiguous => transition?.ambiguous ?? false;

  String get scheduledLocalDatetime => formatLocalDateTimeFields(localFields);

  bool isFuture(DateTime nowUtc) => dueAtUtc.isAfter(nowUtc);
}

class ReminderPreset {
  const ReminderPreset({required this.labelKey, required this.resolve});

  final String labelKey;
  final DateTime Function(DateTime nowLocal) resolve;
}

DateTime _at(DateTime nowLocal, {int? dayOffset, int? hour, int? minute}) {
  final day = DateTime(
    nowLocal.year,
    nowLocal.month,
    nowLocal.day,
  ).add(Duration(days: dayOffset ?? 0));
  return DateTime(
    day.year,
    day.month,
    day.day,
    hour ?? nowLocal.hour,
    minute ?? nowLocal.minute,
  );
}

class ReminderComposer {
  const ReminderComposer({required this.zone, required this.nowUtc});

  final tz.Location zone;
  final DateTime nowUtc;

  DateTime get nowLocal => nowUtc.toLocal();

  /// FR-5.7 — four presets, computed from the injected clock.
  List<ReminderPreset> get presets => [
    ReminderPreset(
      labelKey: 'reminder.preset_1h',
      resolve: (nowLocal) => nowLocal.add(const Duration(hours: 1)),
    ),
    ReminderPreset(
      labelKey: 'reminder.preset_tonight',
      resolve: (nowLocal) {
        final tonight = _at(nowLocal, hour: 20, minute: 0);
        return tonight.isAfter(nowLocal)
            ? tonight
            : _at(nowLocal, dayOffset: 1, hour: 20, minute: 0);
      },
    ),
    ReminderPreset(
      labelKey: 'reminder.preset_tomorrow',
      resolve: (nowLocal) => _at(nowLocal, dayOffset: 1, hour: 9, minute: 0),
    ),
    ReminderPreset(
      labelKey: 'reminder.preset_week',
      resolve: (nowLocal) => nowLocal.add(const Duration(days: 7)),
    ),
  ];

  PendingReminder fromPreset(ReminderPreset preset) =>
      fromLocalFields(preset.resolve(nowLocal));

  /// §7.5 — DST gap shifts forward, overlap takes the earlier instant. Both
  /// outcomes are reported so the UI can tell the user before saving.
  PendingReminder fromLocalFields(DateTime localFields) {
    final resolution = resolveLocalToUtc(zone, localFields);
    return PendingReminder(
      dueAtUtc: resolution.utc,
      localFields: localFields,
      zoneId: zone.name,
      transition: resolution,
    );
  }

  PendingReminder fromStored({
    required DateTime dueAtUtc,
    required String scheduledLocalDatetime,
    required String zoneId,
  }) {
    final parsed = DateTime.tryParse(scheduledLocalDatetime);
    return PendingReminder(
      dueAtUtc: dueAtUtc,
      localFields: parsed ?? dueAtUtc.toLocal(),
      zoneId: zoneId,
    );
  }
}

/// `Ingatkan aku` section: switch, presets, picker, and honest notes.
class ReminderSection extends StatelessWidget {
  const ReminderSection({
    super.key,
    required this.composer,
    required this.enabled,
    required this.value,
    required this.onEnabledChanged,
    required this.onValueChanged,
    this.onError,
  });

  final ReminderComposer composer;
  final bool enabled;
  final PendingReminder? value;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<PendingReminder?> onValueChanged;

  /// Called with an ARB key when the picker returns a past time.
  final ValueChanged<String>? onError;

  Future<void> _pick(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final initial =
        value?.localFields ?? composer.nowLocal.add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(
        composer.nowLocal.year,
        composer.nowLocal.month,
        composer.nowLocal.day,
      ),
      lastDate: DateTime(composer.nowLocal.year + 20),
      helpText: l10n.reminderPick,
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: l10n.reminderPick,
    );
    if (time == null || !context.mounted) return;

    final fields = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    final pending = composer.fromLocalFields(fields);
    if (!pending.isFuture(composer.nowUtc)) {
      // FR-5.7 — past times are rejected, never silently moved.
      onError?.call('error.due_past');
      return;
    }
    onValueChanged(pending);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          value: enabled,
          onChanged: onEnabledChanged,
          title: Text(l10n.captureRemindMe),
          secondary: const Icon(Icons.alarm),
        ),
        if (enabled) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in composer.presets)
                  ActionChip(
                    label: Text(_presetLabel(l10n, preset.labelKey)),
                    onPressed: () =>
                        onValueChanged(composer.fromPreset(preset)),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.event, size: 18),
                  label: Text(l10n.reminderPick),
                  onPressed: () => _pick(context),
                ),
              ],
            ),
          ),
          if (value != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.reminderScheduledAt(
                            DateFormats.dateTime(value!.localFields),
                          ),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  if (value!.shifted)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        l10n.reminderShiftedNote(
                          value!.zoneId,
                          DateFormats.dateTime(value!.dueAtUtc.toLocal()),
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  if (value!.ambiguous)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        l10n.reminderAmbiguousNote(
                          value!.zoneId,
                          DateFormats.dateTime(value!.dueAtUtc.toLocal()),
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      l10n.reminderInexact,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

String _presetLabel(AppLocalizations l10n, String key) => switch (key) {
  'reminder.preset_1h' => l10n.reminderPreset1h,
  'reminder.preset_tonight' => l10n.reminderPresetTonight,
  'reminder.preset_tomorrow' => l10n.reminderPresetTomorrow,
  'reminder.preset_week' => l10n.reminderPresetWeek,
  _ => key,
};
