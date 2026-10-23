import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanti_ingatkan_aku/features/memories/domain/memory.dart';
import 'package:nanti_ingatkan_aku/features/memories/domain/memory_validation.dart';
import 'package:nanti_ingatkan_aku/features/memories/presentation/memory_detail_page.dart';
import 'package:nanti_ingatkan_aku/features/memories/presentation/memory_form_page.dart';
import 'package:nanti_ingatkan_aku/features/reminders/domain/reminder_scheduler.dart';
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

  Finder titleField() => find.byType(TextField).first;

  testWidgets('an empty title is refused with inline copy, not a crash', (
    tester,
  ) async {
    await pumpApp(tester, env, const MemoryFormPage());

    await tester.tap(find.text(l10n.captureSave).last);
    await tester.pumpAndSettle();

    expect(find.text(l10n.errorTitleEmpty), findsOneWidget);
    expect(await withDatabase(tester, env.memories.count), 0);
    expect(find.byType(MemoryFormPage), findsOneWidget);
  });

  testWidgets('saving a valid note stores exactly one memory and opens it', (
    tester,
  ) async {
    await pumpApp(tester, env, const MemoryFormPage());

    await tester.enterText(titleField(), '  Ambil paket  ');
    await tester.pump();
    await tester.tap(find.text(l10n.captureSave).last);
    await settleWithDatabase(tester);

    expect(await withDatabase(tester, env.memories.count), 1);
    final saved = (await withDatabase(tester, env.memories.list)).items.single;
    expect(saved.title, 'Ambil paket');
    // The save pushes the detail page, which loads the memory itself.
    await settleWithDatabase(tester);
    expect(find.byType(MemoryDetailPage), findsOneWidget);
  });

  testWidgets('the character counter only appears past the threshold', (
    tester,
  ) async {
    await pumpApp(tester, env, const MemoryFormPage());

    await tester.enterText(titleField(), 'a' * 101);
    await tester.pumpAndSettle();

    expect(find.text('101/120'), findsOneWidget);

    await tester.enterText(titleField(), 'a' * 99);
    await tester.pumpAndSettle();

    expect(find.text('99/120'), findsNothing);
  });

  testWidgets('a category without lent metadata hides the person field', (
    tester,
  ) async {
    await pumpApp(tester, env, const MemoryFormPage());

    expect(find.text(l10n.fieldLentTo), findsNothing);
    expect(find.text(l10n.fieldItemName), findsNothing);

    await tester.tap(find.text(l10n.categoryLentItem));
    await tester.pumpAndSettle();

    expect(find.text(l10n.fieldLentTo), findsOneWidget);
    expect(find.text(l10n.fieldItemName), findsOneWidget);
  });

  testWidgets('switching category with metadata asks before clearing it', (
    tester,
  ) async {
    await pumpApp(tester, env, const MemoryFormPage());

    await tester.tap(find.text(l10n.categoryLentItem));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, l10n.fieldLentTo),
      'Rina',
    );
    await tester.pump();

    await tester.tap(find.text(l10n.categoryGeneral));
    await tester.pumpAndSettle();

    expect(find.text(l10n.categoryChangeTitle), findsOneWidget);
    await tester.tap(find.text(l10n.commonCancel));
    await tester.pumpAndSettle();

    // Cancelling keeps both the category and the metadata.
    expect(find.text(l10n.fieldLentTo), findsOneWidget);
    expect(find.text('Rina'), findsOneWidget);
  });

  testWidgets('the reminder section is offered while creating', (tester) async {
    await pumpApp(tester, env, const MemoryFormPage());

    expect(find.text(l10n.captureRemindMe), findsOneWidget);
    expect(find.byType(SwitchListTile), findsOneWidget);
    // Presets stay hidden until the switch is on.
    expect(find.text(l10n.reminderPreset1h), findsNothing);
  });

  testWidgets('FR-REM-06: the reminder switch asks why before the OS prompt', (
    tester,
  ) async {
    env.scheduler.notificationsOn = false;
    await pumpApp(tester, env, const MemoryFormPage());

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(find.text(l10n.permissionRationale), findsOneWidget);

    // `Nanti saja` leaves the switch off: nothing is armed by accident.
    await tester.tap(find.text(l10n.permissionRationaleCancel));
    await tester.pumpAndSettle();

    expect(find.text(l10n.reminderPreset1h), findsNothing);
    expect(env.scheduler.permissionRequests, 0);
  });

  testWidgets(
    'FR-REM-06: continuing the rationale arms the switch and prompts',
    (tester) async {
      env.scheduler.notificationsOn = false;
      env.scheduler.permission = PermissionState.denied;
      await pumpApp(tester, env, const MemoryFormPage());

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.permissionRationaleContinue));
      await tester.pumpAndSettle();

      expect(env.scheduler.permissionRequests, 1);
      expect(find.text(l10n.reminderPreset1h), findsOneWidget);
    },
  );

  testWidgets('editing an existing memory pre-fills every field', (
    tester,
  ) async {
    final memory = await withDatabase(
      tester,
      () => env.memories.create(
        const MemoryDraft(
          title: 'Garansi kulkas',
          body: 'Tiga tahun.',
          category: MemoryCategory.warranty,
          itemName: 'Kulkas',
          warrantyEndDate: '2029-01-31',
        ),
      ),
    );

    await pumpApp(tester, env, MemoryFormPage(memory: memory));

    expect(find.text(l10n.captureEditTitle), findsOneWidget);
    expect(find.text('Garansi kulkas'), findsOneWidget);
    expect(find.text('Tiga tahun.'), findsOneWidget);
    expect(find.text('Kulkas'), findsOneWidget);
    // FR-REM-01: the reminder section belongs to creation only.
    expect(find.text(l10n.captureRemindMe), findsNothing);
    expect(find.text(l10n.fieldWarrantyEnd), findsOneWidget);
  });

  testWidgets('leaving a dirty draft asks before discarding it', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await pumpApp(
      tester,
      env,
      const SizedBox.shrink(),
      navigatorKey: navigatorKey,
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const MemoryFormPage()),
    );
    await tester.pumpAndSettle();

    await tester.enterText(titleField(), 'Setengah jadi');
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text(l10n.draftDiscardTitle), findsOneWidget);
    await tester.tap(find.text(l10n.draftDiscard));
    await tester.pumpAndSettle();

    expect(find.byType(MemoryFormPage), findsNothing);
    expect(await withDatabase(tester, env.memories.count), 0);
  });

  testWidgets('keeping the draft returns to the form with the text intact', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await pumpApp(
      tester,
      env,
      const SizedBox.shrink(),
      navigatorKey: navigatorKey,
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const MemoryFormPage()),
    );
    await tester.pumpAndSettle();

    await tester.enterText(titleField(), 'Jangan buang');
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.draftKeep));
    await tester.pumpAndSettle();

    expect(find.byType(MemoryFormPage), findsOneWidget);
    expect(find.text('Jangan buang'), findsOneWidget);
  });
}
