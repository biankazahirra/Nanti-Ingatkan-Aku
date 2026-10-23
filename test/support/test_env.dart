import 'dart:ui' show Locale;

import 'package:nanti_ingatkan_aku/core/app_database.dart';
import 'package:nanti_ingatkan_aku/core/clock.dart';
import 'package:nanti_ingatkan_aku/core/ids.dart';
import 'package:nanti_ingatkan_aku/features/backup/data/backup_file_port.dart';
import 'package:nanti_ingatkan_aku/features/backup/data/backup_service.dart';
import 'package:nanti_ingatkan_aku/features/memories/data/memory_dao.dart';
import 'package:nanti_ingatkan_aku/features/memories/data/memory_repository_impl.dart';
import 'package:nanti_ingatkan_aku/features/memories/domain/memory_repository.dart';
import 'package:nanti_ingatkan_aku/features/reminders/data/reconcile_service.dart';
import 'package:nanti_ingatkan_aku/features/reminders/data/reminder_dao.dart';
import 'package:nanti_ingatkan_aku/features/reminders/data/reminder_repository_impl.dart';
import 'package:nanti_ingatkan_aku/features/reminders/domain/reminder_repository.dart';
import 'package:nanti_ingatkan_aku/features/reminders/domain/reminder_scheduler.dart';
import 'package:nanti_ingatkan_aku/features/reminders/platform/notification_content_policy.dart';
import 'package:nanti_ingatkan_aku/features/settings/data/settings_repository.dart';
import 'package:nanti_ingatkan_aku/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Settable clock (PRD §9.2).
class FakeClock implements Clock {
  FakeClock({required DateTime nowUtc, required this.zone}) : _now = nowUtc;

  DateTime _now;
  @override
  final tz.Location zone;

  @override
  DateTime nowUtc() => _now;

  void setNow(DateTime value) => _now = value.toUtc();

  void advance(Duration duration) => _now = _now.add(duration);
}

class ScheduleCall {
  ScheduleCall({
    required this.notificationId,
    required this.dueAtUtc,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int notificationId;
  final DateTime dueAtUtc;
  final String title;
  final String body;
  final String payload;
}

/// Records every scheduling interaction and can inject failures/permissions.
class FakeScheduler implements ReminderScheduler {
  PermissionState permission = PermissionState.granted;
  bool exactAvailable = true;
  bool notificationsOn = true;
  String? failWithCode;

  /// Mirrors a platform that cannot report its own queue.
  bool failEnumeration = false;
  Set<int> pending = <int>{};

  final List<ScheduleCall> scheduled = [];
  final List<int> cancelled = [];
  int cancelAllCalls = 0;
  int permissionRequests = 0;
  int openAppSettingsCalls = 0;
  int exactPermissionRequests = 0;
  bool exactRequestResult = true;

  @override
  Future<PermissionState> ensurePermission() async {
    permissionRequests++;
    return permission;
  }

  @override
  Future<bool> notificationsEnabled() async => notificationsOn;

  @override
  Future<bool> canScheduleExact() async => exactAvailable;

  @override
  Future<bool> requestExactAlarmsPermission() async {
    exactPermissionRequests++;
    return exactRequestResult;
  }

  @override
  Future<ScheduleOutcome> schedule({
    required int notificationId,
    required DateTime dueAtUtc,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (permission != PermissionState.granted) {
      return const ScheduleOutcome.permissionNeeded();
    }
    final failure = failWithCode;
    if (failure != null) {
      return ScheduleOutcome.failed(failure);
    }
    scheduled.add(
      ScheduleCall(
        notificationId: notificationId,
        dueAtUtc: dueAtUtc,
        title: title,
        body: body,
        payload: payload,
      ),
    );
    pending.add(notificationId);
    return ScheduleOutcome.scheduled(exact: exactAvailable);
  }

  @override
  Future<void> cancel(int notificationId) async {
    cancelled.add(notificationId);
    pending.remove(notificationId);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCalls++;
    pending.clear();
  }

  @override
  Future<Set<int>> pendingNotificationIds() async {
    if (failEnumeration) throw StateError('enumeration unavailable');
    return {...pending};
  }

  @override
  Future<void> openAppSettings() async {
    openAppSettingsCalls++;
  }
}

class FakeFilePort implements BackupFilePort {
  String? exportTarget = '/tmp/backup.json';
  String? importSource;
  String? written;
  String? writtenFileName;
  bool failWrite = false;

  @override
  Future<String?> saveJson({
    required String fileName,
    required String content,
    required String dialogTitle,
  }) async {
    if (failWrite) throw StateError('write failed');
    if (exportTarget == null) return null;
    written = content;
    writtenFileName = fileName;
    return exportTarget;
  }

  @override
  Future<String?> pickJsonFile({required String dialogTitle}) async =>
      importSource;

  @override
  Future<int> sizeOf(String path) async => written?.length ?? 0;

  @override
  Future<String> readText(String path, {required int maxBytes}) async {
    final text = importSource == null ? '' : written ?? '';
    if (text.length > maxBytes) throw const BackupFileTooLarge();
    return text;
  }
}

/// In-memory app wired with fakes: the same code paths as production.
class TestEnv {
  TestEnv({
    required this.database,
    required this.memoryDao,
    required this.reminderDao,
    required this.memories,
    required this.reminders,
    required this.reconcile,
    required this.backup,
    required this.scheduler,
    required this.clock,
    required this.settings,
    required this.filePort,
  });

  final AppDatabase database;
  final MemoryDao memoryDao;
  final ReminderDao reminderDao;
  final MemoryRepository memories;
  final ReminderRepository reminders;
  final ReconcileService reconcile;
  final BackupService backup;
  final FakeScheduler scheduler;
  final FakeClock clock;
  final SettingsRepository settings;
  final FakeFilePort filePort;

  Future<void> dispose() => database.close();
}

Future<TestEnv> createTestEnv({
  DateTime? nowUtc,
  String zoneId = 'Asia/Jakarta',
  PermissionState permission = PermissionState.granted,
  bool exactAvailable = true,
  void Function(int processed)? failureHook,
  FakeFilePort? filePort,
}) async {
  tzdata.initializeTimeZones();
  sqfliteFfiInit();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  final database = await AppDatabase.open(
    path: inMemoryDatabasePath,
    factory: databaseFactoryFfi,
    enablePreMigrationBackup: false,
  );

  final memoryDao = MemoryDao(database.db);
  final reminderDao = ReminderDao(database.db);
  final clock = FakeClock(
    nowUtc: (nowUtc ?? DateTime.utc(2026, 10, 23, 9, 12)).toUtc(),
    zone: tz.getLocation(zoneId),
  );
  final scheduler = FakeScheduler()
    ..permission = permission
    ..exactAvailable = exactAvailable;
  final settings = SettingsRepository(await SharedPreferences.getInstance());
  final l10n = lookupAppLocalizations(const Locale('id'));
  final policy = NotificationContentPolicy(settings: settings, l10n: l10n);

  final reminders = ReminderRepositoryImpl(
    dao: reminderDao,
    memoryDao: memoryDao,
    scheduler: scheduler,
    idGenerator: const UuidIdGenerator(),
    contentPolicy: policy,
    nowUtc: clock.nowUtc,
  );
  final memories = MemoryRepositoryImpl(
    dao: memoryDao,
    reminders: reminders,
    idGenerator: const UuidIdGenerator(),
    nowUtc: clock.nowUtc,
  );
  final reconcile = ReconcileService(
    dao: reminderDao,
    memoryDao: memoryDao,
    scheduler: scheduler,
    settings: settings,
    contentPolicy: policy,
    nowUtc: clock.nowUtc,
  );
  final port = filePort ?? FakeFilePort();
  final backup = BackupService(
    database: database,
    memoryDao: memoryDao,
    reminderDao: reminderDao,
    scheduler: scheduler,
    reconcileService: reconcile,
    settings: settings,
    filePort: port,
    nowUtc: clock.nowUtc,
    deviceTimezone: () => zoneId,
    appVersion: '1.0.0+1',
    debugFailureHook: failureHook,
  );

  return TestEnv(
    database: database,
    memoryDao: memoryDao,
    reminderDao: reminderDao,
    memories: memories,
    reminders: reminders,
    reconcile: reconcile,
    backup: backup,
    scheduler: scheduler,
    clock: clock,
    settings: settings,
    filePort: port,
  );
}
