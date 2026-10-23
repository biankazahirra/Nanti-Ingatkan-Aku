import 'package:flutter_test/flutter_test.dart';
import 'package:nanti_ingatkan_aku/core/constants.dart';
import 'package:nanti_ingatkan_aku/core/failures.dart';
import 'package:nanti_ingatkan_aku/features/memories/domain/memory.dart';
import 'package:nanti_ingatkan_aku/features/memories/domain/memory_validation.dart';
import 'package:nanti_ingatkan_aku/features/reminders/domain/reminder.dart';
import 'package:nanti_ingatkan_aku/features/reminders/domain/reminder_repository.dart';
import 'package:sqflite/sqflite.dart';

import '../support/test_env.dart';

void main() {
  late TestEnv env;

  setUp(() async {
    env = await createTestEnv();
  });

  tearDown(() async {
    await env.dispose();
  });

  group('create (FR-MEM-01/03)', () {
    test('trims the title and stamps both timestamps from the clock', () async {
      final memory = await env.memories.create(
        const MemoryDraft(title: '  Ambil paket  ', body: 'Di pos keamanan.'),
      );

      expect(memory.title, 'Ambil paket');
      expect(memory.body, 'Di pos keamanan.');
      expect(memory.isArchived, isFalse);
      expect(memory.createdAtUtc, env.clock.nowUtc());
      expect(memory.updatedAtUtc, env.clock.nowUtc());
    });

    test('a blank title is refused before it reaches SQLite', () async {
      await expectLater(
        env.memories.create(const MemoryDraft(title: '   ')),
        throwsA(isA<ValidationFailure>()),
      );
      expect(await env.memories.count(), 0);
    });

    test('an emoji-only title counts as one grapheme per emoji', () async {
      final memory = await env.memories.create(
        MemoryDraft(title: '🎁' * Limits.titleMax),
      );
      expect(graphemeLength(memory.title), Limits.titleMax);
    });

    test('a title one grapheme over the cap is refused', () async {
      await expectLater(
        env.memories.create(MemoryDraft(title: 'a' * (Limits.titleMax + 1))),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('metadata for another category is dropped, never stored', () async {
      final memory = await env.memories.create(
        const MemoryDraft(
          title: 'Buku',
          category: MemoryCategory.general,
          personName: 'Rina',
          itemName: 'Buku',
          warrantyEndDate: '2027-01-01',
        ),
      );

      expect(memory.personName, isNull);
      expect(memory.itemName, isNull);
      expect(memory.warrantyEndDate, isNull);
    });

    test('an impossible warranty date is refused', () async {
      await expectLater(
        env.memories.create(
          const MemoryDraft(
            title: 'Kulkas',
            category: MemoryCategory.warranty,
            warrantyEndDate: '2027-02-30',
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });

  group('update and archive', () {
    test('update replaces fields and refreshes updated_at_utc', () async {
      final memory = await env.memories.create(
        const MemoryDraft(title: 'Awal'),
      );
      env.clock.advance(const Duration(minutes: 5));

      final updated = await env.memories.update(
        memory.id,
        const MemoryDraft(title: 'Diubah', body: 'baru'),
      );

      expect(updated.title, 'Diubah');
      expect(updated.body, 'baru');
      expect(updated.createdAtUtc, memory.createdAtUtc);
      expect(updated.updatedAtUtc, env.clock.nowUtc());
      expect((await env.memories.findById(memory.id))!.title, 'Diubah');
    });

    test(
      'changing category clears metadata the new category cannot hold',
      () async {
        final memory = await env.memories.create(
          const MemoryDraft(
            title: 'Buku',
            category: MemoryCategory.lentItem,
            personName: 'Rina',
            itemName: 'Buku',
          ),
        );

        final updated = await env.memories.update(
          memory.id,
          const MemoryDraft(title: 'Buku', category: MemoryCategory.general),
        );

        expect(updated.personName, isNull);
        expect(updated.itemName, isNull);
      },
    );

    test('updating a memory that does not exist fails loudly', () async {
      await expectLater(
        env.memories.update('missing', const MemoryDraft(title: 'x')),
        throwsA(isA<StorageFailure>()),
      );
    });

    test(
      'FR-MEM-04 / DEC-08: archiving keeps the reminder scheduled',
      () async {
        final memory = await env.memories.create(
          const MemoryDraft(title: 'Garansi'),
        );
        final reminder = await env.reminders.save(
          ReminderRequest(
            memoryId: memory.id,
            dueAtUtc: env.clock.nowUtc().add(const Duration(days: 2)),
            scheduledLocalDatetime: '2026-10-25T16:12',
            scheduledTimezone: 'Asia/Jakarta',
          ),
        );
        env.scheduler.cancelled.clear();

        await env.memories.setArchived(memory.id, true);

        expect((await env.memories.findById(memory.id))!.isArchived, isTrue);
        expect(env.scheduler.cancelled, isEmpty);
        expect(await env.reminders.pendingCount(), 1);

        await env.memories.setArchived(memory.id, false);
        expect((await env.memories.findById(memory.id))!.isArchived, isFalse);
        expect((await env.reminders.findByMemory(memory.id))!.id, reminder.id);
      },
    );
  });

  group('list and paging (FR-MEM-02)', () {
    test('scopes to the archive flag and orders newest first', () async {
      final first = await env.memories.create(const MemoryDraft(title: 'Satu'));
      env.clock.advance(const Duration(minutes: 1));
      final second = await env.memories.create(const MemoryDraft(title: 'Dua'));
      env.clock.advance(const Duration(minutes: 1));
      final third = await env.memories.create(const MemoryDraft(title: 'Tiga'));
      await env.memories.setArchived(second.id, true);

      final active = await env.memories.list();
      final archived = await env.memories.list(archived: true);

      expect(active.items.map((m) => m.id), [third.id, first.id]);
      expect(archived.items.map((m) => m.id), [second.id]);
    });

    test('filters by category without mixing categories', () async {
      await env.memories.create(const MemoryDraft(title: 'Umum'));
      await env.memories.create(
        const MemoryDraft(title: 'Garansi', category: MemoryCategory.warranty),
      );

      final page = await env.memories.list(category: MemoryCategory.warranty);

      expect(page.items.single.title, 'Garansi');
      expect(page.hasMore, isFalse);
    });

    test(
      '50 rows per page, and hasMore only when a row is left over',
      () async {
        for (var i = 0; i < Limits.pageSize + 1; i++) {
          await env.memories.create(MemoryDraft(title: 'Catatan $i'));
          env.clock.advance(const Duration(seconds: 1));
        }

        final first = await env.memories.list();
        final second = await env.memories.list(page: 1);

        expect(first.items, hasLength(Limits.pageSize));
        expect(first.hasMore, isTrue);
        expect(second.items, hasLength(1));
        expect(second.hasMore, isFalse);
        // Pages never overlap.
        expect(
          first.items
              .map((m) => m.id)
              .toSet()
              .intersection(second.items.map((m) => m.id).toSet()),
          isEmpty,
        );
      },
    );

    test('count includes archived rows by default (FR-MEM-08)', () async {
      final memory = await env.memories.create(const MemoryDraft(title: 'A'));
      await env.memories.setArchived(memory.id, true);

      expect(await env.memories.count(), 1);
      expect(await env.memories.count(includeArchived: false), 0);
    });
  });

  group('search (FR-SRH-01..06)', () {
    setUp(() async {
      await env.memories.create(
        const MemoryDraft(title: 'Buku pinjaman Rina', body: 'Dipinjam Senin.'),
      );
      env.clock.advance(const Duration(minutes: 1));
      await env.memories.create(
        const MemoryDraft(
          title: 'Garansi laptop',
          body: 'Buku servis di laci.',
        ),
      );
      env.clock.advance(const Duration(minutes: 1));
      await env.memories.create(
        const MemoryDraft(title: 'Kunci motor', body: 'Di tas hitam.'),
      );
    });

    test('a title hit ranks above a body hit (FR-SRH-05)', () async {
      final page = await env.memories.search(query: 'buku');
      expect(page.items.map((m) => m.title), [
        'Buku pinjaman Rina',
        'Garansi laptop',
      ]);
    });

    test('matching is case-insensitive and whitespace-tolerant', () async {
      final page = await env.memories.search(query: '  BUKU   ');
      expect(page.items, hasLength(2));
    });

    test('every token must match (AND semantics)', () async {
      final page = await env.memories.search(query: 'buku rina');
      expect(page.items.single.title, 'Buku pinjaman Rina');
      expect(
        (await env.memories.search(query: 'buku tidakada')).items,
        isEmpty,
      );
    });

    test('diacritics and non-ASCII stay searchable', () async {
      await env.memories.create(const MemoryDraft(title: 'Kopi Éthiopia'));
      final page = await env.memories.search(query: 'éthiopia');
      expect(page.items.single.title, 'Kopi Éthiopia');
    });

    test('emoji inside a query is treated as text, not a wildcard', () async {
      await env.memories.create(
        const MemoryDraft(title: 'Hadiah 🎁 untuk ibu'),
      );
      expect((await env.memories.search(query: '🎁')).items, hasLength(1));
      expect((await env.memories.search(query: '🎈')).items, isEmpty);
    });

    test('LIKE metacharacters are matched literally (FR-SRH-03)', () async {
      await env.memories.create(const MemoryDraft(title: 'Diskon 50% saja'));
      expect((await env.memories.search(query: '50%')).items, hasLength(1));
      // A bare wildcard matches only the literal character, never every row.
      expect((await env.memories.search(query: '%')).items, hasLength(1));
      expect((await env.memories.search(query: '_')).items, isEmpty);
      expect((await env.memories.search(query: r'\')).items, isEmpty);
    });

    test('search respects the archive and category filters', () async {
      final archived = await env.memories.search(query: 'buku', archived: true);
      expect(archived.items, isEmpty);
      expect(
        (await env.memories.search(
          query: 'buku',
          category: MemoryCategory.general,
        )).items,
        hasLength(2),
      );
    });

    test('an empty query behaves as a plain list', () async {
      final page = await env.memories.search(query: '   ');
      expect(page.items, hasLength(3));
    });
  });

  group('database-level guarantees (§7.3)', () {
    test('the DDL refuses a title longer than 120 characters', () async {
      final memory = Memory(
        id: 'raw-1',
        title: 'a' * (Limits.titleMax + 1),
        body: '',
        category: MemoryCategory.general,
        isArchived: false,
        createdAtUtc: env.clock.nowUtc(),
        updatedAtUtc: env.clock.nowUtc(),
      );

      await expectLater(
        env.memoryDao.insert(memory),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('the DDL refuses metadata that contradicts the category', () async {
      final memory = Memory(
        id: 'raw-2',
        title: 'Tanpa kategori',
        body: '',
        category: MemoryCategory.general,
        personName: 'Rina',
        isArchived: false,
        createdAtUtc: env.clock.nowUtc(),
        updatedAtUtc: env.clock.nowUtc(),
      );

      await expectLater(
        env.memoryDao.insert(memory),
        throwsA(isA<DatabaseException>()),
      );
    });

    test(
      'the reminders DDL refuses a completed row without a timestamp',
      () async {
        final memory = await env.memories.create(const MemoryDraft(title: 'A'));
        final reminder = (await env.reminders.save(
          ReminderRequest(
            memoryId: memory.id,
            dueAtUtc: env.clock.nowUtc().add(const Duration(days: 1)),
            scheduledLocalDatetime: '2026-10-24T16:12',
            scheduledTimezone: 'Asia/Jakarta',
          ),
        )).copyWith(status: ReminderStatus.completed);

        await expectLater(
          env.reminderDao.upsert(reminder),
          throwsA(isA<DatabaseException>()),
        );
      },
    );

    test('deleting a memory cascades to its reminder row', () async {
      final memory = await env.memories.create(const MemoryDraft(title: 'A'));
      await env.reminders.save(
        ReminderRequest(
          memoryId: memory.id,
          dueAtUtc: env.clock.nowUtc().add(const Duration(days: 1)),
          scheduledLocalDatetime: '2026-10-24T16:12',
          scheduledTimezone: 'Asia/Jakarta',
        ),
      );
      expect(await env.reminderDao.count(), 1);

      await env.memoryDao.delete(memory.id);

      expect(await env.reminderDao.count(), 0);
    });
  });
}
