import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanti_ingatkan_aku/app/providers.dart';
import 'package:nanti_ingatkan_aku/app/theme.dart';
import 'package:nanti_ingatkan_aku/core/app_database.dart';
import 'package:nanti_ingatkan_aku/l10n/app_localizations.dart';

import 'test_env.dart';

AppDependencies dependenciesFor(TestEnv env) => AppDependencies(
  database: env.database,
  clock: env.clock,
  settings: env.settings,
  memories: env.memories,
  reminders: env.reminders,
  reconcile: env.reconcile,
  backup: env.backup,
  notifications: env.scheduler,
  appVersion: '1.0.0+1',
  schemaVersion: AppDatabase.schemaVersion,
  onNotificationTap: (_) {},
  takeLaunchPayload: () => null,
);

/// Pumps a widget with the real Indonesian localizations, the real theme, and
/// the in-memory dependencies, so widget tests exercise production wiring.
Future<void> pumpApp(
  WidgetTester tester,
  TestEnv env,
  Widget home, {
  GlobalKey<NavigatorState>? navigatorKey,
  NotificationHealth? health,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        depsProvider.overrideWithValue(dependenciesFor(env)),
        notificationHealthProvider.overrideWith(
          (ref) async =>
              health ??
              const NotificationHealth(
                notificationsEnabled: true,
                exactAlarmAvailable: true,
                permissionNeeded: 0,
                schedulingFailed: 0,
                pendingCount: 0,
              ),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        locale: const Locale('id'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(),
        home: home,
      ),
    ),
  );
  await settleWithDatabase(tester);
}

/// Runs database work from inside a `testWidgets` body.
///
/// The body runs in the fake-async zone, which only drains when the test pumps.
/// A database future awaited directly there therefore never completes: the
/// reply arrives on the real event loop, from the `sqflite` isolate. `runAsync`
/// turns the real event loop for the duration of the call, so the reply lands.
///
/// Never await the database without this wrapper inside a widget test.
Future<T> withDatabase<T>(
  WidgetTester tester,
  Future<T> Function() action,
) async {
  final result = await tester.runAsync(action);
  return result as T;
}

/// Settles a tree whose widgets read from the database.
///
/// `sqflite_common_ffi` answers from a background isolate, and the fake-async
/// zone only drains when the test pumps, so a database future never completes
/// inside it. Each step therefore gives the real event loop a window for the
/// reply, then advances the fake clock so transitions keep moving.
///
/// `pumpAndSettle` is not used: a page that is still loading shows a spinner,
/// which schedules frames forever and would time the settle out.
Future<void> settleWithDatabase(WidgetTester tester) async {
  for (var step = 0; step < 10; step++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
  }
  await tester.pump();
}
