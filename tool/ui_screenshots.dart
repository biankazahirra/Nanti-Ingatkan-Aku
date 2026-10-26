// Renders the real pages with seeded data and writes PNGs, so the UI can be
// reviewed on a machine that cannot run an emulator or a device.
//
// Usage:  flutter test tool/ui_screenshots.dart
// Output: build/ui_preview/*.png
//
// This file lives outside `test/` on purpose. The images depend on the host's
// fonts and pixel ratio, so it must never join the `flutter test` run and
// nothing may compare them to a checked-in golden.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanti_ingatkan_aku/app/providers.dart';
import 'package:nanti_ingatkan_aku/app/theme.dart';
import 'package:nanti_ingatkan_aku/features/memories/domain/memory.dart';
import 'package:nanti_ingatkan_aku/features/memories/domain/memory_validation.dart';
import 'package:nanti_ingatkan_aku/features/memories/presentation/memories_page.dart';
import 'package:nanti_ingatkan_aku/features/memories/presentation/memory_detail_page.dart';
import 'package:nanti_ingatkan_aku/features/memories/presentation/memory_form_page.dart';
import 'package:nanti_ingatkan_aku/features/onboarding/presentation/onboarding_page.dart';
import 'package:nanti_ingatkan_aku/features/reminders/domain/reminder_repository.dart';
import 'package:nanti_ingatkan_aku/features/reminders/presentation/today_page.dart';
import 'package:nanti_ingatkan_aku/features/settings/presentation/diagnostics_page.dart';
import 'package:nanti_ingatkan_aku/features/settings/presentation/privacy_page.dart';
import 'package:nanti_ingatkan_aku/features/settings/presentation/settings_page.dart';
import 'package:nanti_ingatkan_aku/l10n/app_localizations.dart';

import '../test/support/test_env.dart';
import '../test/support/widget_env.dart';

const _outputDir = 'build/ui_preview';
const _boundaryKey = ValueKey('ui_screenshot_boundary');

void main() {
  late TestEnv env;

  setUpAll(() async {
    await _loadAppFonts();
  });

  setUp(() async {
    env = await createTestEnv();
  });

  tearDown(() async {
    await env.dispose();
  });

  testWidgets('onboarding', (tester) async {
    await _pump(tester, env, OnboardingPage(onDone: () {}));
    await _capture(tester, '01-onboarding');
  });

  testWidgets('today, empty', (tester) async {
    await _pump(tester, env, const TodayPage());
    await _capture(tester, '02-today-empty');
  });

  testWidgets('today, every bucket filled', (tester) async {
    await _seed(tester, env);
    await _pump(tester, env, const TodayPage());
    await _capture(tester, '03-today-filled');
  });

  testWidgets('memories list', (tester) async {
    await _seed(tester, env);
    await _pump(tester, env, const MemoriesPage());
    await _capture(tester, '04-memories');
  });

  testWidgets('memory detail', (tester) async {
    final id = await _seed(tester, env);
    await _pump(tester, env, MemoryDetailPage(memoryId: id));
    await _capture(tester, '05-memory-detail');
  });

  testWidgets('capture form', (tester) async {
    await _pump(tester, env, const MemoryFormPage());
    await _capture(tester, '06-capture-form');
  });

  testWidgets('capture form with the reminder section open', (tester) async {
    await _pump(tester, env, const MemoryFormPage());
    await tester.tap(find.byType(SwitchListTile));
    await settleWithDatabase(tester);
    await _capture(tester, '07-capture-form-reminder');
  });

  testWidgets('settings', (tester) async {
    await _pump(tester, env, const SettingsPage());
    await _capture(tester, '08-settings');
  });

  testWidgets('privacy', (tester) async {
    await _pump(tester, env, const PrivacyPage());
    await _capture(tester, '09-privacy');
  });

  testWidgets('diagnostics', (tester) async {
    await _pump(tester, env, const DiagnosticsPage());
    await _capture(tester, '10-diagnostics');
  });
}

/// Seeds notes across every category and a reminder in each bucket.
///
/// Returns the id of a lent note, for the detail screenshot.
Future<String> _seed(WidgetTester tester, TestEnv env) async {
  final now = env.clock.nowUtc();
  late String lentId;
  await withDatabase(tester, () async {
    Future<String> note(MemoryDraft draft) async =>
        (await env.memories.create(draft)).id;

    lentId = await note(
      const MemoryDraft(
        title: 'Payung Rina',
        body: 'Dipinjam sejak acara kantor.',
        category: MemoryCategory.lentItem,
        personName: 'Rina',
        itemName: 'Payung hitam',
      ),
    );
    final warrantyId = await note(
      const MemoryDraft(
        title: 'Garansi kulkas',
        body: 'Kartu garansi di laci dapur.',
        category: MemoryCategory.warranty,
        itemName: 'Kulkas Samsung',
        warrantyEndDate: '2029-01-31',
      ),
    );
    final serviceId = await note(
      const MemoryDraft(
        title: 'Servis motor',
        category: MemoryCategory.maintenance,
        itemName: 'Vario',
      ),
    );
    final generalId = await note(
      const MemoryDraft(title: 'Bayar listrik', body: 'Nomor pelanggan 5523'),
    );
    final packageId = await note(const MemoryDraft(title: 'Ambil paket'));

    Future<void> due(String memoryId, Duration fromNow) => env.reminders.save(
      ReminderRequest(
        memoryId: memoryId,
        dueAtUtc: now.add(fromNow),
        scheduledLocalDatetime: '2026-10-25T09:00',
        scheduledTimezone: 'Asia/Jakarta',
      ),
    );

    await due(generalId, const Duration(hours: -3)); // overdue
    await due(packageId, const Duration(hours: 4)); // today
    await due(serviceId, const Duration(days: 3)); // upcoming
    await due(warrantyId, const Duration(days: 40));
  });
  return lentId;
}

/// Pumps a page inside a repaint boundary, so the frame can be written out.
Future<void> _pump(WidgetTester tester, TestEnv env, Widget home) async {
  // A phone-shaped surface: 360 x 760 logical pixels at 3x.
  tester.view.physicalSize = const Size(1080, 2280);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundaryKey,
      child: ProviderScope(
        overrides: [
          depsProvider.overrideWithValue(dependenciesFor(env)),
          notificationHealthProvider.overrideWith(
            (ref) async => const NotificationHealth(
              notificationsEnabled: true,
              exactAlarmAvailable: true,
              permissionNeeded: 0,
              schedulingFailed: 0,
              pendingCount: 3,
            ),
          ),
        ],
        child: MaterialApp(
          // The ribbon is debug-only noise in a screenshot.
          debugShowCheckedModeBanner: false,
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
    ),
  );
  await settleWithDatabase(tester);
}

Future<void> _capture(WidgetTester tester, String name) async {
  final directory = Directory(_outputDir)..createSync(recursive: true);
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundaryKey),
  );
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  });
  final file = File('${directory.path}${Platform.pathSeparator}$name.png');
  file.writeAsBytesSync(bytes!);
  debugPrint('wrote ${file.path} (${bytes.length} bytes)');
}

/// Registers the real Roboto and Material Icons faces.
///
/// Without this every glyph renders as a filled box: `flutter test` installs a
/// placeholder font as the default so that layout tests stay host-independent.
Future<void> _loadAppFonts() async {
  final fonts = _materialFontsDir();
  if (fonts == null) {
    debugPrint(
      'material_fonts not found next to this Dart SDK: text will be '
      'drawn as boxes',
    );
    return;
  }
  await _loadFont('Roboto', [
    _join(fonts, 'roboto-regular.ttf'),
    _join(fonts, 'roboto-medium.ttf'),
    _join(fonts, 'roboto-bold.ttf'),
  ]);
  await _loadFont('MaterialIcons', [_join(fonts, 'materialicons-regular.otf')]);
}

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  var loaded = 0;
  for (final path in paths) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final bytes = file.readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
    loaded++;
  }
  if (loaded == 0) return;
  await loader.load();
  debugPrint('loaded $loaded face(s) as "$family"');
}

/// Locates `<flutter>/bin/cache/artifacts/material_fonts`.
///
/// The depth differs by runner: under `flutter test` the executable is the
/// engine's `flutter_tester.exe` under `artifacts/engine/<arch>/`, while plain
/// `dart` sits at `dart-sdk/bin/`. Walk up rather than count parents.
Directory? _materialFontsDir() {
  var dir = File(Platform.resolvedExecutable).parent;
  while (true) {
    final fonts = Directory(
      _join(dir, 'artifacts${Platform.pathSeparator}material_fonts'),
    );
    if (fonts.existsSync()) return fonts;
    final parent = dir.parent;
    if (parent.path == dir.path) return null;
    dir = parent;
  }
}

String _join(Directory directory, String name) =>
    '${directory.path}${Platform.pathSeparator}$name';
