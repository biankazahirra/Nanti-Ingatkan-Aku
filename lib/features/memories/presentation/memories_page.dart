import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../reminders/domain/reminder.dart';
import 'memory_detail_page.dart';
import 'memory_form_page.dart';
import 'widgets.dart';

/// §5.5 / FR-SRH-01..06 — recent list, search, filters, archive toggle.
class MemoriesPage extends ConsumerStatefulWidget {
  const MemoriesPage({super.key});

  @override
  ConsumerState<MemoriesPage> createState() => _MemoriesPageState();
}

class _MemoriesPageState extends ConsumerState<MemoriesPage> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  MemoryListRequest _request = const MemoryListRequest();

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    // FR-SRH-06 — debounce 150 ms, cancel stale work.
    _debounce?.cancel();
    _debounce = Timer(Limits.searchDebounce, () {
      if (!mounted) return;
      setState(() {
        _request = _request.copyWith(query: value, page: 0);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final deps = ref.watch(depsProvider);
    final page = ref.watch(memoryListProvider(_request));
    final nowUtc = deps.clock.nowUtc();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.memoriesTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _controller,
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.memoriesSearchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: l10n.a11yClearSearch,
                        onPressed: () {
                          _controller.clear();
                          _onQueryChanged('');
                        },
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CategoryChips(
              includeAll: true,
              selected: _request.category,
              onSelected: (category) => setState(() {
                _request = _request.copyWith(
                  category: category,
                  clearCategory: category == null,
                  page: 0,
                );
              }),
            ),
          ),
          SwitchListTile(
            value: _request.archived,
            onChanged: (value) => setState(() {
              _request = _request.copyWith(archived: value, page: 0);
            }),
            title: Text(l10n.memoriesArchivedToggle),
            secondary: const Icon(Icons.inventory_2_outlined),
          ),
          const Divider(height: 1),
          Expanded(
            child: page.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(memoryListProvider(_request)),
                  child: Text(l10n.commonRetry),
                ),
              ),
              data: (data) {
                final reminders = ref.watch(
                  reminderLookupProvider(
                    data.items
                        .map((memory) => memory.id)
                        .toList(growable: false),
                  ),
                );
                if (data.items.isEmpty) {
                  return _EmptyState(message: _emptyMessage(l10n));
                }
                return reminders.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => const SizedBox.shrink(),
                  data: (lookup) => ListView.separated(
                    itemCount: data.items.length + (data.hasMore ? 1 : 0),
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      if (index == data.items.length) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: FilledButton.tonal(
                              onPressed: () => setState(() {
                                _request = _request.copyWith(
                                  page: _request.page + 1,
                                );
                              }),
                              child: Text(l10n.memoriesLoadMore),
                            ),
                          ),
                        );
                      }
                      final memory = data.items[index];
                      return MemoryListTile(
                        memory: memory,
                        reminder: lookup[memory.id],
                        nowUtc: nowUtc,
                        zoneId: deps.clock.zone.name,
                        onTap: () async {
                          await Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  MemoryDetailPage(memoryId: memory.id),
                            ),
                          );
                          if (mounted) {
                            ref.invalidate(memoryListProvider(_request));
                          }
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => const MemoryFormPage()),
          );
          if (mounted) ref.invalidate(memoryListProvider(_request));
        },
        icon: const Icon(Icons.add),
        label: Text(AppLocalizations.of(context).captureNewTitle),
      ),
    );
  }

  String _emptyMessage(AppLocalizations l10n) {
    if (_request.query.trim().isNotEmpty) {
      // The query is echoed as data, never as markup (FR-MEM-06).
      return l10n.memoriesNoResults(_request.query.trim());
    }
    return _request.archived ? l10n.memoriesArchiveEmpty : l10n.memoriesEmpty;
  }
}

/// Batches reminder lookups for a page of memories (FR-MEM-02 metadata).
final reminderLookupProvider =
    FutureProvider.family<Map<String, Reminder>, List<String>>((ref, ids) {
      if (ids.isEmpty) return Future.value(const {});
      return ref.watch(depsProvider).reminders.byMemoryIds(ids);
    });

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
