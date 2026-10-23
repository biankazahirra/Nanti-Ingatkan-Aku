import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/app_database.dart';
import 'core/clock.dart';
import 'core/failures.dart';
import 'core/ids.dart';
import 'core/timezone_service.dart';
import 'features/backup/data/backup_file_port.dart';
import 'features/backup/data/backup_service.dart';
import 'features/memories/data/memory_dao.dart';
import 'features/memories/data/memory_repository_impl.dart';
import 'features/reminders/data/reconcile_service.dart';
import 'features/reminders/data/reminder_dao.dart';
import 'features/reminders/data/reminder_repository_impl.dart';
import 'features/reminders/platform/local_notification_scheduler.dart';
import 'features/reminders/platform/notification_content_policy.dart';
import 'features/settings/data/settings_repository.dart';
import 'l10n/app_localizations.dart';

/// Single app version string, also written into exports (FR-EXP-01).
const String kAppVersion = '1.0.0+1';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // NFR-L10N-02 — Indonesian date/time formatting everywhere.
  Intl.defaultLocale = 'id_ID';
  await initializeDateFormatting('id_ID');

  final zone = await initializeDeviceTimezone();
  final l10n = lookupAppLocalizations(const Locale('id'));

  AppDatabase database;
  try {
    database = await AppDatabase.open(
      path: p.join(await getDatabasesPath(), 'nanti_ingatkan_aku.db'),
    );
  } on Failure catch (failure) {
    // NFR-REL-04 — a DB from a newer build must not crash the app.
    runApp(_StartupFailureApp(message: _startupMessage(l10n, failure)));
    return;
  } on Object {
    runApp(_StartupFailureApp(message: l10n.errorGeneric));
    return;
  }

  final settings = SettingsRepository(await SharedPreferences.getInstance());
  final notifications = LocalNotificationScheduler(
    channelName: l10n.notifChannelName,
    channelDescription: l10n.notifChannelDesc,
  );
  await notifications.initialize();

  final clock = SystemClock(zone.location);
  final contentPolicy = NotificationContentPolicy(
    settings: settings,
    l10n: l10n,
  );
  final memoryDao = MemoryDao(database.db);
  final reminderDao = ReminderDao(database.db);
  final idGenerator = const UuidIdGenerator();

  final reminders = ReminderRepositoryImpl(
    dao: reminderDao,
    memoryDao: memoryDao,
    scheduler: notifications,
    idGenerator: idGenerator,
    contentPolicy: contentPolicy,
    nowUtc: () => clock.nowUtc(),
  );
  final memories = MemoryRepositoryImpl(
    dao: memoryDao,
    reminders: reminders,
    idGenerator: idGenerator,
    nowUtc: () => clock.nowUtc(),
  );
  final reconcile = ReconcileService(
    dao: reminderDao,
    memoryDao: memoryDao,
    scheduler: notifications,
    settings: settings,
    contentPolicy: contentPolicy,
    nowUtc: () => clock.nowUtc(),
  );
  final backup = BackupService(
    database: database,
    memoryDao: memoryDao,
    reminderDao: reminderDao,
    scheduler: notifications,
    reconcileService: reconcile,
    settings: settings,
    filePort: const FilePickerBackupFilePort(),
    nowUtc: () => clock.nowUtc(),
    deviceTimezone: () => zone.identifier,
    appVersion: kAppVersion,
  );

  final deps = AppDependencies(
    database: database,
    clock: clock,
    settings: settings,
    memories: memories,
    reminders: reminders,
    reconcile: reconcile,
    backup: backup,
    notifications: notifications,
    appVersion: kAppVersion,
    schemaVersion: AppDatabase.schemaVersion,
    onNotificationTap: dispatchNotificationPayload,
    takeLaunchPayload: notifications.takeLaunchPayload,
  );

  runApp(
    ProviderScope(
      overrides: [depsProvider.overrideWithValue(deps)],
      child: const NantiIngatkanAkuApp(),
    ),
  );
}

String _startupMessage(AppLocalizations l10n, Failure failure) =>
    failure is DbVersionTooNewFailure ? l10n.errorDbNewer : l10n.errorGeneric;

/// NFR-REL-04 — the app opens and explains instead of crashing.
class _StartupFailureApp extends StatelessWidget {
  const _StartupFailureApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('id'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(message, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
