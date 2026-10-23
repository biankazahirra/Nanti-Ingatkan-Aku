import 'package:flutter_test/flutter_test.dart';
import 'package:nanti_ingatkan_aku/features/memories/data/memory_query.dart';
import 'package:nanti_ingatkan_aku/features/memories/domain/memory.dart';

void main() {
  group('escaping (FR-SRH-03)', () {
    test('escapes the escape character first', () {
      expect(MemoryQuery.escapeLike(r'a\b'), r'a\\b');
    });

    test('escapes percent and underscore', () {
      expect(MemoryQuery.escapeLike('50%_off'), r'50\%\_off');
    });

    test('a wildcard-only query becomes a literal search', () {
      final query = MemoryQuery.build(query: '%');
      expect(query.whereArgs.contains(r'%\%%'), isTrue);
    });

    test('quotes and emoji are bound parameters, never SQL', () {
      final query = MemoryQuery.build(query: "O'Reilly \"x\" 😀");
      expect(query.sql.contains("O'Reilly"), isFalse);
      expect(query.sql.contains('😀'), isFalse);
      expect(
        query.args.whereType<String>().any((a) => a.contains("O'Reilly")),
        isTrue,
      );
      expect(
        query.args.whereType<String>().any((a) => a.contains('😀')),
        isTrue,
      );
    });
  });

  group('token semantics (FR-SRH-02)', () {
    test('splits on whitespace and ANDs tokens', () {
      final query = MemoryQuery.build(query: 'buku  rina');
      expect(query.tokens, ['buku', 'rina']);
      expect(query.whereClause.split('OR').length, greaterThan(2));
    });

    test('caps at five tokens', () {
      final query = MemoryQuery.build(query: 'a b c d e f g');
      expect(query.tokens.length, 5);
      expect(query.tokens, ['a', 'b', 'c', 'd', 'e']);
    });

    test('truncates a token longer than 50 characters', () {
      final query = MemoryQuery.build(query: 'x' * 80);
      expect(query.tokens.single.length, 50);
    });

    test('an empty query has no tokens and no LIKE clause', () {
      final query = MemoryQuery.build(query: '   ');
      expect(query.tokens, isEmpty);
      expect(query.whereClause.contains('LIKE'), isFalse);
      expect(query.orderByClause, 'm.updated_at_utc DESC, m.id ASC');
    });
  });

  group('statement shape', () {
    test('filters by archive flag and category with bound parameters', () {
      final query = MemoryQuery.build(
        query: 'ac',
        category: MemoryCategory.maintenance,
        archived: true,
      );
      expect(query.whereClause.startsWith('m.is_archived = ?'), isTrue);
      expect(query.whereClause.contains('m.category = ?'), isTrue);
      expect(query.whereArgs.first, 1);
      expect(query.whereArgs[1], 'maintenance');
    });

    test('orders title matches first, then newest, then id (FR-SRH-05)', () {
      final query = MemoryQuery.build(query: 'buku');
      expect(
        query.orderByClause.startsWith('m.title_norm LIKE ? ESCAPE'),
        isTrue,
      );
      expect(query.orderByClause.contains('m.updated_at_utc DESC'), isTrue);
      expect(query.orderByClause.contains('m.id ASC'), isTrue);
    });

    test('fetches one extra row for paging and applies limit/offset', () {
      final query = MemoryQuery.build(page: 2);
      expect(query.args[query.args.length - 2], 51);
      expect(query.args.last, 100);
    });

    test('escaper is applied inside the LIKE pattern, not the SQL text', () {
      final query = MemoryQuery.build(query: 'a_b');
      expect(query.sql.contains('a_b'), isFalse);
      expect(query.args.whereType<String>().any((a) => a == r'%a\_b%'), isTrue);
    });

    test('every parameter is positional: no string interpolation in SQL', () {
      final query = MemoryQuery.build(query: "'; DROP TABLE memories; --");
      expect(query.sql.contains('DROP'), isFalse);
      expect(query.sql.contains('memories;'), isFalse);
      // The payload is split on whitespace, so each token is its own parameter;
      // every token binds one pattern for the title and one for the body.
      final bound = query.whereArgs.whereType<String>().toList();
      expect(bound, hasLength(10));
      expect(bound.toSet(), hasLength(5));
      expect(bound.any((a) => a.contains('DROP')), isTrue);
      expect(bound.any((a) => a.contains('memories;')), isTrue);
    });
  });
}
