import '../../../core/constants.dart';
import '../domain/memory.dart';

/// FR-SRH-02/03/05 — one place builds every search statement, with escaping
/// tests for `%`, `_`, `\`, quotes, emoji, and 5-token input.
class MemoryQuery {
  MemoryQuery._({
    required this.tokens,
    required this.category,
    required this.archived,
    required this.limit,
    required this.offset,
  });

  factory MemoryQuery.build({
    String query = '',
    MemoryCategory? category,
    bool archived = false,
    int page = 0,
    int pageSize = Limits.pageSize,
  }) {
    return MemoryQuery._(
      tokens: tokenize(query),
      category: category,
      archived: archived,
      limit: pageSize,
      offset: page * pageSize,
    );
  }

  static const String _escapeChar = r'\';

  final List<String> tokens;
  final MemoryCategory? category;
  final bool archived;
  final int limit;
  final int offset;

  /// Escapes LIKE metacharacters; order matters (`\` first). FR-SRH-03.
  static String escapeLike(String value) => value
      .replaceAll(_escapeChar, '$_escapeChar$_escapeChar')
      .replaceAll('%', '$_escapeChar%')
      .replaceAll('_', '${_escapeChar}_');

  /// FR-SRH-02 — whitespace split, max 5 tokens, each at most 50 characters.
  static List<String> tokenize(String raw) {
    final result = <String>[];
    for (final part in raw.trim().split(RegExp(r'\s+'))) {
      if (part.isEmpty) continue;
      result.add(
        part.length <= Limits.queryTokenLengthMax
            ? part
            : part.substring(0, Limits.queryTokenLengthMax),
      );
      if (result.length == Limits.queryTokenMax) break;
    }
    return result;
  }

  String get whereClause {
    final parts = <String>['m.is_archived = ?'];
    if (category != null) parts.add('m.category = ?');
    for (var i = 0; i < tokens.length; i++) {
      parts.add(
        "(m.title_norm LIKE ? ESCAPE '$_escapeChar' "
        "OR m.body_norm LIKE ? ESCAPE '$_escapeChar')",
      );
    }
    return parts.join(' AND ');
  }

  /// Parameters for [whereClause], in order.
  List<Object?> get whereArgs {
    final args = <Object?>[archived ? 1 : 0];
    if (category != null) args.add(category!.dbValue);
    for (final token in tokens) {
      final pattern = '%${escapeLike(token)}%';
      args
        ..add(pattern)
        ..add(pattern);
    }
    return args;
  }

  /// FR-SRH-05 — title matches first, then newest, then id for determinism.
  String get orderByClause => tokens.isEmpty
      ? 'm.updated_at_utc DESC, m.id ASC'
      : "m.title_norm LIKE ? ESCAPE '$_escapeChar' DESC, "
            'm.updated_at_utc DESC, m.id ASC';

  /// Ordering parameters appended after [whereArgs].
  List<Object?> get orderArgs =>
      tokens.isEmpty ? const [] : ['%${escapeLike(tokens.first)}%'];

  /// Full statement with bound parameters only (NFR-SEC-02).
  String get sql =>
      'SELECT m.* FROM memories m WHERE $whereClause '
      'ORDER BY $orderByClause LIMIT ? OFFSET ?';

  /// Fetches one extra row so the caller can detect a next page.
  List<Object?> get args => [...whereArgs, ...orderArgs, limit + 1, offset];
}
