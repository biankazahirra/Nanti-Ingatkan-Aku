import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/memories/presentation/memory_detail_page.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../l10n/app_localizations.dart';
import 'home_shell.dart';
import 'providers.dart';
import 'theme.dart';

/// FR-REM-10 — a notification payload arriving before the UI exists is queued.
typedef PayloadHandler = void Function(String payload);

PayloadHandler? appNotificationHandler;
String? appPendingPayload;

void dispatchNotificationPayload(String payload) {
  final handler = appNotificationHandler;
  if (handler != null) {
    handler(payload);
  } else {
    appPendingPayload = payload;
  }
}

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class NantiIngatkanAkuApp extends ConsumerStatefulWidget {
  const NantiIngatkanAkuApp({super.key});

  @override
  ConsumerState<NantiIngatkanAkuApp> createState() =>
      _NantiIngatkanAkuAppState();
}

class _NantiIngatkanAkuAppState extends ConsumerState<NantiIngatkanAkuApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    appNotificationHandler = _openPayload;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final deps = ref.read(depsProvider);
      // Step 6 of the checklist: a cold start may carry a payload.
      final launch = deps.takeLaunchPayload();
      if (launch != null) _openPayload(launch);
      final pending = appPendingPayload;
      if (pending != null) {
        appPendingPayload = null;
        _openPayload(pending);
      }
      // FR-REM-12 — reconcile after the first frame.
      await deps.reconcile.reconcile();
      await deps.settings.setLastKnownTimezone(deps.clock.zone.name);
    });
  }

  @override
  void dispose() {
    appNotificationHandler = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final deps = ref.read(depsProvider);
    // §7.6 — resume reconciliation is throttled inside the service.
    deps.reconcile.reconcile();
    final known = deps.settings.lastKnownTimezone;
    final current = deps.clock.zone.name;
    if (known != null && known != current) {
      // §7.5 — due_at_utc is immutable; only the presentation changes.
      deps.reconcile.reconcile(force: true);
      deps.settings.setLastKnownTimezone(current);
    }
  }

  /// FR-REM-10 — open the memory detail, or explain that it is gone.
  void _openPayload(String payload) {
    const prefix = 'memory:';
    if (!payload.startsWith(prefix)) return;
    final memoryId = payload.substring(prefix.length);
    final navigator = appNavigatorKey.currentState;
    final deps = ref.read(depsProvider);
    if (navigator == null) {
      appPendingPayload = payload;
      return;
    }
    deps.memories.findById(memoryId).then((memory) {
      final current = appNavigatorKey.currentState;
      if (current == null) return;
      if (memory == null) {
        current.popUntil((route) => route.isFirst);
        appScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(
              lookupAppLocalizations(const Locale('id')).todayDeletedMemory,
            ),
          ),
        );
        return;
      }
      current.push(
        MaterialPageRoute<void>(
          builder: (_) => MemoryDetailPage(memoryId: memoryId),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsStateProvider);
    return MaterialApp(
      title: 'Nanti Ingatkan Aku',
      navigatorKey: appNavigatorKey,
      scaffoldMessengerKey: appScaffoldMessengerKey,
      // DEC-02 — Indonesian only in v1.0; ARB is ready for English later.
      locale: const Locale('id'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: settings.when(
        loading: () => const _Splash(),
        error: (error, _) => const _Splash(),
        data: (state) => state.onboardingComplete
            ? const HomeShell()
            : OnboardingPage(
                onDone: () => ref.invalidate(settingsStateProvider),
              ),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
