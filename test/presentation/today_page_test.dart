import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanti_ingatkan_aku/app/providers.dart';
import 'package:nanti_ingatkan_aku/features/memories/domain/memory_validation.dart';
import 'package:nanti_ingatkan_aku/features/reminders/domain/reminder_repository.dart';
import 'package:nanti_ingatkan_aku/features/reminders/presentation/today_page.dart';
import 'package:nanti_ingatkan_aku/l10n/app_localizations.dart';

import '../support/test_env.dart';
import '../support/widget_env.dart';

void main() {
  late TestEnv env;
  final l10n = lookupAppLocalizations(const Locale('id'));

  setUp(() async {
    env = await createTestEnv();
  });

  tearDown(() async {
    await env.dispose();
  });

  Future<void> seedReminder(
    WidgetTester tester,
    String title,
    Duration fromNow, {
    String local = '2026-10-25T09:00',
  }) async {
    await withDatabase(tester, () async {
      final memory = await env.memories.create(MemoryDraft(title: title));
      await env.reminders.save(
        ReminderRequest(
          memoryId: memory.id,
          dueAtUtc: env.clock.nowUtc().add(fromNow),
          scheduledLocalDatetime: local,
          scheduledTimezone: 'Asia/Jakarta',
        ),
      );
    });
  }

  testWidgets('FR-TODAY-05: an empty day explains itself and offers capture', (
    tester,
  ) async {
    await pumpApp(tester, env, const TodayPage());

    expect(find.text(l10n.todayTitle), findsOneWidget);
    expect(find.text(l10n.todayEmpty), findsOneWidget);
    expect(find.text(l10n.todayCoach), findsOneWidget);
    expect(find.text(l10n.todayEmptyCta), findsOneWidget);
  });

  testWidgets('group headers and titles render for each bucket', (
    tester,
  ) async {
    await seedReminder(tester, 'Bayar listrik', const Duration(hours: -3));
    await seedReminder(
      tester,
      'Ambil paket',
      const Duration(hours: 4),
      local: '2026-10-23T16:12',
    );
    await seedReminder(
      tester,
      'Servis motor',
      const Duration(days: 3),
      local: '2026-10-26T16:12',
    );

    await pumpApp(tester, env, const TodayPage());

    expect(find.text(l10n.todaySectionOverdue.toUpperCase()), findsOneWidget);
    expect(find.text(l10n.todaySectionToday.toUpperCase()), findsOneWidget);
    expect(find.text(l10n.todaySectionUpcoming.toUpperCase()), findsOneWidget);
    expect(find.text('Bayar listrik'), findsOneWidget);
    expect(find.text('Ambil paket'), findsOneWidget);
    expect(find.text('Servis motor'), findsOneWidget);
    expect(find.text(l10n.todayEmpty), findsNothing);
  });

  testWidgets('a completed reminder disappears from today', (tester) async {
    await seedReminder(tester, 'Sudah selesai', const Duration(hours: 2));
    await withDatabase(tester, () async {
      final reminder = await env.reminders.all();
      await env.reminders.complete(reminder.single.memoryId);
    });

    await pumpApp(tester, env, const TodayPage());

    expect(find.text('Sudah selesai'), findsNothing);
    expect(find.text(l10n.todayEmpty), findsOneWidget);
  });

  testWidgets('a permission problem raises the banner without hiding data', (
    tester,
  ) async {
    await seedReminder(tester, 'Tetap terlihat', const Duration(days: 2));

    await pumpApp(
      tester,
      env,
      const TodayPage(),
      health: const NotificationHealth(
        notificationsEnabled: false,
        exactAlarmAvailable: false,
        permissionNeeded: 1,
        schedulingFailed: 0,
        pendingCount: 1,
      ),
    );

    expect(find.text(l10n.permissionDeniedBanner), findsOneWidget);
    expect(find.text('Tetap terlihat'), findsOneWidget);
  });

  testWidgets('FR-REM-06: the banner offers the OS settings screen', (
    tester,
  ) async {
    await pumpApp(
      tester,
      env,
      const TodayPage(),
      health: const NotificationHealth(
        notificationsEnabled: false,
        exactAlarmAvailable: false,
        permissionNeeded: 1,
        schedulingFailed: 0,
        pendingCount: 1,
      ),
    );

    await tester.tap(find.text(l10n.reminderOpenSettings));
    await tester.pumpAndSettle();

    expect(env.scheduler.openAppSettingsCalls, 1);
  });

  testWidgets('the group cap offers "see all" only when rows are hidden', (
    tester,
  ) async {
    for (var i = 0; i < 21; i++) {
      await seedReminder(
        tester,
        'Catatan $i',
        Duration(days: 2, hours: i),
        local: '2026-10-25T09:00',
      );
    }

    await pumpApp(tester, env, const TodayPage());

    // The button sits below twenty tiles, so the lazy list has not built it.
    final seeAll = find.text(l10n.todaySeeAll);
    await tester.scrollUntilVisible(
      seeAll,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Catatan 19'), findsOneWidget);
    expect(find.text('Catatan 20'), findsNothing);
    expect(seeAll, findsOneWidget);
  });
}
