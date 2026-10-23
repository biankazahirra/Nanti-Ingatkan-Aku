import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../memories/presentation/memory_detail_page.dart';
import '../../memories/presentation/memory_form_page.dart';
import '../../memories/presentation/widgets.dart';
import '../domain/due_state.dart';

/// §5.4 / FR-TODAY-01..06 — what is due, computed from the injected clock.
class TodayPage extends ConsumerStatefulWidget {
  const TodayPage({super.key});

  @override
  ConsumerState<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends ConsumerState<TodayPage>
    with WidgetsBindingObserver {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(Limits.todayTick, (_) {
      if (mounted) ref.invalidate(todayProvider);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // FR-TODAY-04 — recompute on resume (reconcile is throttled separately).
      ref.invalidate(todayProvider);
      ref.invalidate(notificationHealthProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final deps = ref.watch(depsProvider);
    final groups = ref.watch(todayProvider);
    final health = ref.watch(notificationHealthProvider);
    final nowUtc = deps.clock.nowUtc();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.todayTitle)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(todayProvider);
          await ref.read(todayProvider.future);
        },
        child: groups.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              _TodayError(onRetry: () => ref.invalidate(todayProvider)),
          data: (data) {
            final showBanner = health.maybeWhen(
              data: (value) =>
                  value.permissionNeeded > 0 || value.schedulingFailed > 0,
              orElse: () => false,
            );
            return ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                if (showBanner) const _PermissionBanner(),
                if (data.isEmpty)
                  _TodayEmpty(onCapture: () => _openCapture(context))
                else ...[
                  ..._group(
                    context,
                    l10n.todaySectionOverdue,
                    data.overdue,
                    nowUtc,
                    deps.clock.zone.name,
                  ),
                  ..._group(
                    context,
                    l10n.todaySectionToday,
                    data.today,
                    nowUtc,
                    deps.clock.zone.name,
                  ),
                  ..._group(
                    context,
                    l10n.todaySectionUpcoming,
                    data.upcoming,
                    nowUtc,
                    deps.clock.zone.name,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _group(
    BuildContext context,
    String title,
    List<TodayEntry> entries,
    DateTime nowUtc,
    String zoneId,
  ) {
    if (entries.isEmpty) return const [];
    final l10n = AppLocalizations.of(context);
    // FR-TODAY-06 — never load an unbounded list into one scroll view.
    final visible = entries
        .take(Limits.todayGroupLimit)
        .toList(growable: false);
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ),
      for (final entry in visible)
        MemoryListTile(
          memory: entry.memory,
          reminder: entry.reminder,
          nowUtc: nowUtc,
          zoneId: zoneId,
          showDueTime: true,
          onTap: () => openMemoryDetail(context, entry.memory.id),
        ),
      if (entries.length > visible.length)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TodayGroupPage(title: title, entries: entries),
              ),
            ),
            child: Text(l10n.todaySeeAll),
          ),
        ),
    ];
  }
}

Future<void> _openCapture(BuildContext context) async {
  await Navigator.of(
    context,
  ).push<void>(MaterialPageRoute<void>(builder: (_) => const MemoryFormPage()));
}

class TodayGroupPage extends ConsumerWidget {
  const TodayGroupPage({super.key, required this.title, required this.entries});

  final String title;
  final List<TodayEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deps = ref.watch(depsProvider);
    final nowUtc = deps.clock.nowUtc();
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.separated(
        itemCount: entries.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return MemoryListTile(
            memory: entry.memory,
            reminder: entry.reminder,
            nowUtc: nowUtc,
            zoneId: deps.clock.zone.name,
            showDueTime: false,
            onTap: () => openMemoryDetail(context, entry.memory.id),
          );
        },
      ),
    );
  }
}

class _TodayEmpty extends StatelessWidget {
  const _TodayEmpty({required this.onCapture});

  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Icon(
            Icons.checklist_rtl,
            size: 40,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(l10n.todayEmpty, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          // FR-TODAY-05 — the empty state must not imply nothing exists.
          Text(l10n.todayCoach, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onCapture,
            icon: const Icon(Icons.add),
            label: Text(l10n.todayEmptyCta),
          ),
        ],
      ),
    );
  }
}

/// FR-REM-06 — the banner states the fact and offers the one step the app
/// cannot take for the user: the OS settings screen.
class _PermissionBanner extends ConsumerWidget {
  const _PermissionBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_off_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.permissionDeniedBanner,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () =>
                  ref.read(depsProvider).notifications.openAppSettings(),
              child: Text(l10n.reminderOpenSettings),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayError extends StatelessWidget {
  const _TodayError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.errorGeneric),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
        ],
      ),
    );
  }
}

/// Shared helper: keep deep links in one place (FR-REM-10).
Future<void> openMemoryDetail(BuildContext context, String memoryId) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => MemoryDetailPage(memoryId: memoryId),
    ),
  );
}
