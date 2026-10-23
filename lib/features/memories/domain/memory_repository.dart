import 'memory.dart';
import 'memory_validation.dart';

/// FR-MEM-02 / FR-SRH-06 — paging contract shared by list and search.
class MemoryPage {
  const MemoryPage({required this.items, required this.hasMore});

  final List<Memory> items;
  final bool hasMore;
}

abstract class MemoryRepository {
  Future<Memory> create(MemoryDraft draft, {String? id});

  Future<Memory> update(String id, MemoryDraft draft);

  Future<void> setArchived(String id, bool archived);

  /// Hard delete; the reminder cascade happens in one transaction (FR-MEM-05).
  Future<void> delete(String id);

  Future<Memory?> findById(String id);

  Future<MemoryPage> list({
    MemoryCategory? category,
    bool archived = false,
    int page = 0,
  });

  /// FR-SRH-01..06.
  Future<MemoryPage> search({
    required String query,
    MemoryCategory? category,
    bool archived = false,
    int page = 0,
  });

  Future<int> count({bool includeArchived = true});
}
