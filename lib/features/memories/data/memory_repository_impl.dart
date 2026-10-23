import '../../../core/constants.dart';
import '../../../core/failures.dart';
import '../../../core/ids.dart';
import '../../reminders/domain/reminder_repository.dart';
import '../domain/memory.dart';
import '../domain/memory_repository.dart';
import '../domain/memory_validation.dart';
import 'memory_dao.dart';
import 'memory_query.dart';

/// FR-MEM-01..05 — validation, persistence, and reminder coordination for
/// memories. The DB is the truth; reminders are a channel (principle 3).
class MemoryRepositoryImpl implements MemoryRepository {
  MemoryRepositoryImpl({
    required this._dao,
    required this._reminders,
    required this._idGenerator,
    required this._nowUtc,
  });

  final MemoryDao _dao;
  final ReminderRepository _reminders;
  final IdGenerator _idGenerator;
  final DateTime Function() _nowUtc;

  @override
  Future<Memory> create(MemoryDraft draft, {String? id}) async {
    final sanitized = sanitizeDraft(draft);
    _assertValid(sanitized);

    final now = _nowUtc().toUtc();
    final memory = Memory(
      id: id ?? _idGenerator.newId(),
      title: sanitized.title,
      body: sanitized.body,
      category: sanitized.category,
      itemName: sanitized.itemName,
      personName: sanitized.personName,
      warrantyEndDate: sanitized.warrantyEndDate,
      isArchived: false,
      createdAtUtc: now,
      updatedAtUtc: now,
    );
    await _dao.insert(memory);
    return memory;
  }

  @override
  Future<Memory> update(String id, MemoryDraft draft) async {
    final sanitized = sanitizeDraft(draft);
    _assertValid(sanitized);

    final existing = await _dao.findById(id);
    if (existing == null) {
      throw const StorageFailure('memory_not_found');
    }

    final updated = existing.copyWith(
      title: sanitized.title,
      body: sanitized.body,
      category: sanitized.category,
      itemName: sanitized.itemName,
      personName: sanitized.personName,
      warrantyEndDate: sanitized.warrantyEndDate,
      clearItemName: sanitized.itemName == null,
      clearPersonName: sanitized.personName == null,
      clearWarrantyEndDate: sanitized.warrantyEndDate == null,
      updatedAtUtc: _nowUtc().toUtc(),
    );
    await _dao.update(updated);
    return updated;
  }

  @override
  Future<void> setArchived(String id, bool archived) async {
    final existing = await _dao.findById(id);
    if (existing == null) {
      throw const StorageFailure('memory_not_found');
    }
    // FR-MEM-04 / DEC-08 — archiving never cancels a reminder.
    await _dao.update(
      existing.copyWith(isArchived: archived, updatedAtUtc: _nowUtc().toUtc()),
    );
  }

  @override
  Future<void> delete(String id) async {
    final reminder = await _reminders.findByMemory(id);
    // The FK cascade removes the reminder in the same statement (FR-MEM-05).
    await _dao.delete(id);
    if (reminder != null) {
      await _reminders.cancelNotification(reminder.notificationId);
    }
  }

  @override
  Future<Memory?> findById(String id) => _dao.findById(id);

  @override
  Future<MemoryPage> list({
    MemoryCategory? category,
    bool archived = false,
    int page = 0,
  }) async {
    final rows = await _dao.list(
      category: category,
      archived: archived,
      limit: Limits.pageSize + 1,
      offset: page * Limits.pageSize,
    );
    return _toPage(rows);
  }

  @override
  Future<MemoryPage> search({
    required String query,
    MemoryCategory? category,
    bool archived = false,
    int page = 0,
  }) async {
    final built = MemoryQuery.build(
      query: query,
      category: category,
      archived: archived,
      page: page,
    );
    final rows = await _dao.search(built);
    return _toPage(rows);
  }

  @override
  Future<int> count({bool includeArchived = true}) =>
      _dao.count(includeArchived: includeArchived);

  MemoryPage _toPage(List<Memory> rows) {
    final hasMore = rows.length > Limits.pageSize;
    return MemoryPage(
      items: hasMore ? rows.sublist(0, Limits.pageSize) : rows,
      hasMore: hasMore,
    );
  }

  void _assertValid(MemoryDraft draft) {
    final errors = validateDraft(draft);
    if (errors.isNotEmpty) {
      throw ValidationFailure('validation_failed', errors.first.messageKey);
    }
  }
}
