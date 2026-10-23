import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanti_ingatkan_aku/app/providers.dart';
import 'package:nanti_ingatkan_aku/features/settings/presentation/settings_page.dart';
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

  testWidgets('FR-SET-01: the app-settings button reaches the platform', (
    tester,
  ) async {
    await pumpApp(tester, env, const SettingsPage());

    expect(find.text(l10n.settingsBatteryGuidance), findsOneWidget);
    await tester.tap(find.text(l10n.settingsOpenAppSettings));
    await tester.pumpAndSettle();

    expect(env.scheduler.openAppSettingsCalls, 1);
  });

  testWidgets('FR-REM-07: an unavailable exact alarm offers the grant screen', (
    tester,
  ) async {
    await pumpApp(
      tester,
      env,
      const SettingsPage(),
      health: const NotificationHealth(
        notificationsEnabled: true,
        exactAlarmAvailable: false,
        permissionNeeded: 0,
        schedulingFailed: 0,
        pendingCount: 0,
      ),
    );

    expect(find.text(l10n.settingsUnavailable), findsWidgets);
    await tester.tap(find.text(l10n.settingsExactAlarm));
    await tester.pumpAndSettle();

    expect(env.scheduler.exactPermissionRequests, 1);
  });

  testWidgets('FR-SET-05: diagnostics stay reachable and carry no content', (
    tester,
  ) async {
    await pumpApp(tester, env, const SettingsPage());

    // The diagnostics section sits below the fold of the settings list, so it
    // is not built until it is scrolled into view.
    final scrollable = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    );
    final header = find.text(l10n.settingsSectionDiagnostics.toUpperCase());
    await tester.scrollUntilVisible(header, 300, scrollable: scrollable);
    expect(header, findsOneWidget);

    final link = find.text(l10n.settingsDiagnosticsLink);
    await tester.scrollUntilVisible(link, 300, scrollable: scrollable);
    await tester.tap(link);
    await settleWithDatabase(tester);

    expect(find.text(l10n.diagnosticsNoContentNotice), findsOneWidget);
  });
}
