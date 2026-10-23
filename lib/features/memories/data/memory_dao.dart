import 'package:sqflite/sqflite.dart';

import '../../../core/text.dart';
import '../../../core/time.dart';
import '../domain/memory.dart';
import 'memory_query.dart';

/// Row mapping and CRUD for `memories` (§7.3). No business rules here; the
/// repository owns validation and reminder coordination.
class MemoryDao {
  const MemoryDao(this._db);

  final Database _db;

  static const String table = 'memories';

  static const String createTableSql = '''
CREATE TABLE memories (
  id                TEXT PRIMARY KEY NOT NULL,
  title             TEXT NOT NULL,
  body              TEXT NOT NULL DEFAULT '',
  category          TEXT NOT NULL DEFAULT 'general'
                      CHECK (category IN ('general','lent_item','warranty','maintenance')),
  item_name         TEXT,
  person_name       TEXT,
  warranty_end_date TEXT,
  title_norm        TEXT NOT NULL,
  body_norm         TEXT NOT NULL,
  is_archived       INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0,1)),
  created_at_utc    TEXT NOT NULL,
  updated_at_utc    TEXT NOT NULL,
  CHECK (length(trim(title)) BETWEEN 1 AND 120),
  CHECK (length(body) <= 10000),
  CHECK (warranty_end_date IS NULL
         OR warranty_end_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'),
  CHECK (person_name IS NULL OR category = 'lent_item'),
  CHECK (item_name IS NULL
         OR category IN ('lent_item','warranty','maintenance')),
  CHECK (warranty_end_date IS NULL OR category = 'warranty')
)''';

  static const List<String> createIndexSql = [
    'CREATE INDEX idx_memories_list ON memories (is_archived, updated_at_utc DESC)',
    'CREATE INDEX idx_memories_cat ON memories (category, is_archived)',
  ];

  Future<void> insert(Memory memory, {DatabaseExecutor? executor}) {
    return (executor ?? _db).insert(table, toRow(memory));
  }

  Future<void> upsert(Memory memory, {DatabaseExecutor? executor}) {
    return (executor ?? _db).insert(
      table,
      toRow(memory),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(Memory memory, {DatabaseExecutor? executor}) {
    return (executor ?? _db).update(
      table,
      toRow(memory),
      where: 'id = ?',
      whereArgs: [memory.id],
    );
  }

  Future<void> delete(String id, {DatabaseExecutor? executor}) {
    return (executor ?? _db).delete(table, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAll({DatabaseExecutor? executor}) {
    return (executor ?? _db).delete(table);
  }

  Future<Memory?> findById(String id) async {
    final rows = await _db.query(
      table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : fromRow(rows.first);
  }

  Future<List<Memory>> list({
    MemoryCategory? category,
    bool archived = false,
    int limit = 50,
    int offset = 0,
  }) async {
    final rows = await _db.query(
      table,
      where: category == null
          ? 'is_archived = ?'
          : 'is_archived = ? AND category = ?',
      whereArgs: [archived ? 1 : 0, if (category != null) category.dbValue],
      orderBy: 'updated_at_utc DESC, id ASC',
      limit: limit,
      offset: offset,
    );
    return rows.map(fromRow).toList(growable: false);
  }

  Future<List<Memory>> search(MemoryQuery query) async {
    final rows = await _db.rawQuery(query.sql, query.args);
    return rows.map(fromRow).toList(growable: false);
  }

  Future<int> count({bool includeArchived = true}) async {
    final rows = await _db.rawQuery(
      includeArchived
          ? 'SELECT COUNT(*) AS c FROM $table'
          : 'SELECT COUNT(*) AS c FROM $table WHERE is_archived = 0',
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  static Map<String, Object?> toRow(Memory memory) => {
    'id': memory.id,
    'title': memory.title,
    'body': memory.body,
    'category': memory.category.dbValue,
    'item_name': memory.itemName,
    'person_name': memory.personName,
    'warranty_end_date': memory.warrantyEndDate,
    // Derived on every write; never edited elsewhere (§7.3).
    'title_norm': normalizeForSearch(memory.title),
    'body_norm': normalizeForSearch(memory.body),
    'is_archived': memory.isArchived ? 1 : 0,
    'created_at_utc': formatUtcIso(memory.createdAtUtc),
    'updated_at_utc': formatUtcIso(memory.updatedAtUtc),
  };

  /// Strict mapping for our own rows; returns a `general` fallback category only
  /// when a legacy row is unreadable, never on a write path.
  static Memory fromRow(Map<String, Object?> row) {
    return Memory(
      id: row['id']! as String,
      title: row['title']! as String,
      body: (row['body'] as String?) ?? '',
      category:
          MemoryCategory.tryParse(row['category'] as String?) ??
          MemoryCategory.general,
      itemName: row['item_name'] as String?,
      personName: row['person_name'] as String?,
      warrantyEndDate: row['warranty_end_date'] as String?,
      isArchived: ((row['is_archived'] as int?) ?? 0) == 1,
      createdAtUtc: parseUtcIso(row['created_at_utc']) ?? DateTime.utc(1970),
      updatedAtUtc: parseUtcIso(row['updated_at_utc']) ?? DateTime.utc(1970),
    );
  }
}
