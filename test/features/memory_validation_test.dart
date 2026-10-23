import 'package:flutter_test/flutter_test.dart';
import 'package:nanti_ingatkan_aku/core/text.dart';
import 'package:nanti_ingatkan_aku/features/memories/domain/memory.dart';
import 'package:nanti_ingatkan_aku/features/memories/domain/memory_validation.dart';

void main() {
  MemoryDraft draft({
    String title = 'Servis AC',
    String body = '',
    MemoryCategory category = MemoryCategory.general,
    String? personName,
    String? itemName,
    String? warrantyEndDate,
  }) {
    return MemoryDraft(
      title: title,
      body: body,
      category: category,
      personName: personName,
      itemName: itemName,
      warrantyEndDate: warrantyEndDate,
    );
  }

  group('title rules (FR-MEM-01)', () {
    test('blank title is rejected', () {
      final errors = validateDraft(draft(title: '   '));
      expect(errors.single.field, MemoryField.title);
      expect(errors.single.messageKey, 'error.title_empty');
    });

    test('a single character is enough', () {
      expect(validateDraft(draft(title: 'a')), isEmpty);
    });

    test('120 characters pass, 121 fail', () {
      expect(validateDraft(draft(title: 'a' * 120)), isEmpty);
      final tooLong = validateDraft(draft(title: 'a' * 121));
      expect(tooLong.single.messageKey, 'error.title_too_long');
    });

    test('emoji count as one user-perceived character', () {
      // 120 emoji = 120 graphemes even though the code units are many more.
      expect(validateDraft(draft(title: '😀' * 120)), isEmpty);
      expect(
        validateDraft(draft(title: '😀' * 121)).single.messageKey,
        'error.title_too_long',
      );
    });
  });

  group('body rules', () {
    test('body over 10,000 characters is rejected', () {
      expect(validateDraft(draft(body: 'x' * 10000)), isEmpty);
      expect(
        validateDraft(draft(body: 'x' * 10001)).single.messageKey,
        'error.body_too_long',
      );
    });
  });

  group('metadata rules (FR-MEM-07/08)', () {
    test('person name is only kept for lent items', () {
      final sanitized = sanitizeDraft(
        draft(
          category: MemoryCategory.warranty,
          personName: 'Rina',
          itemName: 'Laptop',
        ),
      );
      expect(sanitized.personName, isNull);
      expect(sanitized.itemName, 'Laptop');
    });

    test('item name is dropped for the general category', () {
      final sanitized = sanitizeDraft(draft(itemName: 'Laptop'));
      expect(sanitized.itemName, isNull);
    });

    test('person name is kept for lent items', () {
      final sanitized = sanitizeDraft(
        draft(category: MemoryCategory.lentItem, personName: 'Rina'),
      );
      expect(sanitized.personName, 'Rina');
    });

    test('blank metadata becomes null rather than an empty string', () {
      final sanitized = sanitizeDraft(
        draft(
          category: MemoryCategory.lentItem,
          personName: '  ',
          itemName: '',
        ),
      );
      expect(sanitized.personName, isNull);
      expect(sanitized.itemName, isNull);
    });

    test('warranty end is only kept for warranty', () {
      expect(
        sanitizeDraft(draft(warrantyEndDate: '2027-12-12')).warrantyEndDate,
        isNull,
      );
      expect(
        sanitizeDraft(
          draft(
            category: MemoryCategory.warranty,
            warrantyEndDate: '2027-12-12',
          ),
        ).warrantyEndDate,
        '2027-12-12',
      );
    });
  });

  group('calendar dates (FR-IMP-01)', () {
    test('a real date passes', () {
      expect(isRealCalendarDate('2027-12-12'), isTrue);
      expect(isRealCalendarDate('2028-02-29'), isTrue);
    });

    test('an impossible date fails', () {
      expect(isRealCalendarDate('2027-02-30'), isFalse);
      expect(isRealCalendarDate('2027-13-01'), isFalse);
      expect(isRealCalendarDate('2027-00-10'), isFalse);
      expect(isRealCalendarDate('12-12-2027'), isFalse);
      expect(isRealCalendarDate('2027/12/12'), isFalse);
    });

    test('an invalid warranty end surfaces as a field error', () {
      final errors = validateDraft(
        draft(category: MemoryCategory.warranty, warrantyEndDate: '2027-02-30'),
      );
      expect(errors.single.field, MemoryField.warrantyEndDate);
      expect(errors.single.messageKey, 'error.date_invalid');
    });
  });

  group('normalization (FR-SRH-01)', () {
    test('trims, lowercases, and collapses whitespace', () {
      expect(
        normalizeForSearch('  Buku   Rina\n\n  Dipinjam '),
        'buku rina dipinjam',
      );
    });

    test('lowercases non-ASCII', () {
      expect(normalizeForSearch('GARANSI TÉLÉ'), 'garansi télé');
    });
  });

  group('body excerpt', () {
    test('takes the first non-empty line', () {
      final memory = Memory(
        id: 'm1',
        title: 't',
        body: 'baris pertama\nbaris kedua',
        category: MemoryCategory.general,
        isArchived: false,
        createdAtUtc: DateTime.utc(2026),
        updatedAtUtc: DateTime.utc(2026),
      );
      expect(memory.bodyExcerpt, 'baris pertama');
    });
  });
}
