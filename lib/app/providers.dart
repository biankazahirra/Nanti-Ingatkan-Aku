import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/app_database.dart';
import '../core/clock.dart';
import '../features/backup/data/backup_service.dart';
import '../features/memories/domain/memory.dart';
import '../features/memories/domain/memory_repository.dart';
import '../features/reminders/data/reconcile_service.dart';
import '../features/reminders/domain/due_state.dart';
import '../features/reminders/domain/reminder.dart';
import '../features/reminders/domain/reminder_repository.dart';
import '../features/reminders/domain/reminder_scheduler.dart';
import '../features/settings/data/settings_repository.dart';

/// Everything the app needs, assembled once in `main.dart`. Tests override
/// [depsProvider] with fakes instead of touching platform plugins.
class AppDependencies {
  const AppDependencies({
    required this.database,
    required this.clock,
    required this.settings,
    required this.memories,
    required this.reminders,
    required this.reconcile,
    required this.backup,
    required this.notifications,
    required this.appVersion,
    required this.schemaVersion,
    required this.onNotificationTap,
    required this.takeLaunchPayload,
  });

  final AppDatabase database;
  final Clock clock;
  final SettingsRepository settings;
  final MemoryRepository memories;
  final ReminderRepository reminders;
  final ReconcileService reconcile;
  final BackupService backup;

  /// The port, never the plugin: widget tests substitute a fake and never
  /// touch a platform channel.
  final ReminderScheduler notifications;
  final String appVersion;
  final int schemaVersion;

  /// Wired by the shell so a notification tap opens the right screen.
  final void Function(String payload) onNotificationTap;
  final String? Function() takeLaunchPayload;
}

final depsProvider = Provider<AppDependencies>(
  (ref) => throw StateError('depsProvider must be overridden in main()'),
);

/// Stable feature-local request objects used as family keys.
class MemoryListRequest {
  const MemoryListRequest({
    this.query = '',
    this.category,
    this.archived = false,
    this.page = 0,
  });

  final String query;
  final MemoryCategory? category;
  final bool archived;
  final int page;

  MemoryListRequest copyWith({
    String? query,
    MemoryCategory? category,
    bool clearCategory = false,
    bool? archived,
    int? page,
  }) {
    return MemoryListRequest(
      query: query ?? this.query,
      category: clearCategory ? null : (category ?? this.category),
      archived: archived ?? this.archived,
      page: page ?? this.page,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MemoryListRequest &&
      other.query == query &&
      other.category == category &&
      other.archived == archived &&
      other.page == page;

  @override
  int get hashCode => Object.hash(query, category, archived, page);
}

final memoryListProvider = FutureProvider.family<MemoryPage, MemoryListRequest>(
  (ref, request) async {
    final repo = ref.watch(depsProvider).memories;
    if (request.query.trim().isEmpty) {
      return repo.list(
        category: request.category,
        archived: request.archived,
        page: request.page,
      );
    }
    return repo.search(
      query: request.query,
      category: request.category,
      archived: request.archived,
      page: request.page,
    );
  },
);

class MemoryDetail {
  const MemoryDetail({required this.memory, required this.reminder});

  final Memory memory;
  final Reminder? reminder;
}

final memoryDetailProvider = FutureProvider.family<MemoryDetail?, String>((
  ref,
  id,
) async {
  final deps = ref.watch(depsProvider);
  final memory = await deps.memories.findById(id);
  if (memory == null) return null;
  final reminder = await deps.reminders.findByMemory(id);
  return MemoryDetail(memory: memory, reminder: reminder);
});

final todayProvider = FutureProvider<DueGroups>((ref) async {
  final deps = ref.watch(depsProvider);
  final entries = await deps.reminders.pendingEntries();
  return groupDueItems(
    entries: entries,
    nowUtc: deps.clock.nowUtc(),
    zone: deps.clock.zone,
  );
});

/// FR-SET-01 — everything the health section needs, no content.
class NotificationHealth {
  const NotificationHealth({
    required this.notificationsEnabled,
    required this.exactAlarmAvailable,
    required this.permissionNeeded,
    required this.schedulingFailed,
    required this.pendingCount,
  });

  final bool notificationsEnabled;
  final bool exactAlarmAvailable;
  final int permissionNeeded;
  final int schedulingFailed;
  final int pendingCount;
}

final notificationHealthProvider = FutureProvider<NotificationHealth>((
  ref,
) async {
  final deps = ref.watch(depsProvider);
  return NotificationHealth(
    notificationsEnabled: await deps.notifications.notificationsEnabled(),
    exactAlarmAvailable: await deps.notifications.canScheduleExact(),
    permissionNeeded: await _countScheduling(
      deps,
      SchedulingStatus.permissionNeeded,
    ),
    schedulingFailed: await _countScheduling(
      deps,
      SchedulingStatus.schedulingFailed,
    ),
    pendingCount: await deps.reminders.pendingCount(),
  );
});

Future<int> _countScheduling(
  AppDependencies deps,
  SchedulingStatus status,
) async {
  final rows = await deps.reminders.all();
  return rows.where((r) => r.isPending && r.schedulingStatus == status).length;
}

/// FR-REM-06 — read before the pre-permission rationale, so the dialog only
/// appears when there is still something for the OS to ask.
final notificationPermissionProvider = FutureProvider<bool>(
  (ref) => ref.watch(depsProvider).notifications.notificationsEnabled(),
);

/// FR-SET-05 — counts, versions, codes. Never titles or bodies.
class Diagnostics {
  const Diagnostics({
    required this.memories,
    required this.reminders,
    required this.pending,
    required this.schemaVersion,
    required this.timezone,
    required this.timezoneUnknown,
    required this.lastReconcileAtUtc,
    required this.lastErrorCode,
    required this.appVersion,
  });

  final int memories;
  final int reminders;
  final int pending;
  final int schemaVersion;
  final String timezone;
  final bool timezoneUnknown;
  final DateTime? lastReconcileAtUtc;
  final String? lastErrorCode;
  final String appVersion;
}

final diagnosticsProvider = FutureProvider<Diagnostics>((ref) async {
  final deps = ref.watch(depsProvider);
  final reminders = await deps.reminders.all();
  String? lastErrorCode;
  for (final reminder in reminders) {
    if (reminder.scheduleErrorCode != null) {
      lastErrorCode = reminder.scheduleErrorCode;
      break;
    }
  }
  return Diagnostics(
    memories: await deps.memories.count(),
    reminders: reminders.length,
    pending: reminders.where((r) => r.isPending).length,
    schemaVersion: deps.schemaVersion,
    timezone: deps.clock.zone.name,
    timezoneUnknown: false,
    lastReconcileAtUtc: deps.settings.lastReconcileAtUtc,
    lastErrorCode: lastErrorCode,
    appVersion: deps.appVersion,
  );
});

/// Device-local settings that widgets must observe after a write.
class SettingsState {
  const SettingsState({
    required this.onboardingComplete,
    required this.hideNotificationContent,
    required this.lastExportAtUtc,
    required this.memoryCount,
  });

  final bool onboardingComplete;
  final bool hideNotificationContent;
  final DateTime? lastExportAtUtc;
  final int memoryCount;
}

final settingsStateProvider = FutureProvider<SettingsState>((ref) async {
  final deps = ref.watch(depsProvider);
  return SettingsState(
    onboardingComplete: deps.settings.onboardingComplete,
    hideNotificationContent: deps.settings.hideNotificationContent,
    lastExportAtUtc: deps.settings.lastExportAtUtc,
    memoryCount: await deps.memories.count(),
  );
});

final deviceZoneProvider = Provider<tz.Location>(
  (ref) => ref.watch(depsProvider).clock.zone,
);
