import 'package:flutter_test/flutter_test.dart';
import 'package:nanti_ingatkan_aku/features/backup/domain/import_validator.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

/// §7.8 — a fresh, fully valid document. Every test mutates exactly one field so
/// a failure is attributable to that field.
Map<String, Object?> validDoc() => <String, Object?>{
  'app': 'nanti-ingatkan-aku',
  'schema_version': 1,
  'exported_at': '2026-10-23T09:12:31.000Z',
  'app_version': '1.0.0+1',
  'device_timezone': 'Asia/Jakarta',
  'counts': {'memories': 1, 'reminders': 1},
  'memories': [
    {
      'id': '3f1c8a2e-8b1d-4f0a-9a3e-5a7f0f2c9d11',
      'title': 'Garansi laptop',
      'body': 'Perpanjangan 1 tahun.',
      'category': 'warranty',
      'item_name': 'Laptop',
      'person_name': null,
      'warranty_end_date': '2027-12-12',
      'is_archived': false,
      'created_at_utc': '2026-10-20T02:11:00.000Z',
      'updated_at_utc': '2026-10-20T02:11:00.000Z',
    },
  ],
  'reminders': [
    // Annotated so tests can replace null with other types, e.g. an int.
    <String, Object?>{
      'id': 'a1b2c3d4-1111-4222-8333-444455556666',
      'memory_id': '3f1c8a2e-8b1d-4f0a-9a3e-5a7f0f2c9d11',
      'due_at_utc': '2027-12-12T13:00:00.000Z',
      'scheduled_local_datetime': '2027-12-12T20:00',
      'scheduled_timezone': 'Asia/Jakarta',
      'precision': 'exact',
      'status': 'pending',
      'completed_at_utc': null,
      'created_at_utc': '2026-10-20T02:11:00.000Z',
      'updated_at_utc': '2026-10-20T02:11:00.000Z',
    },
  ],
};

Map<String, Object?> memoryOf(Map<String, Object?> doc) =>
    (doc['memories']! as List).first as Map<String, Object?>;

Map<String, Object?> reminderOf(Map<String, Object?> doc) =>
    (doc['reminders']! as List).first as Map<String, Object?>;

void main() {
  const validator = ImportValidator();

  setUpAll(tzdata.initializeTimeZones);

  ImportValidation validate(Map<String, Object?> doc) =>
      validator.validate(doc);

  String codeOf(ImportValidation result) => result.failure!.code;

  test('a valid document passes and is typed', () {
    final result = validate(validDoc());

    expect(result.isValid, isTrue);
    expect(result.failure, isNull);
    expect(result.file!.memories.single.title, 'Garansi laptop');
    expect(
      result.file!.reminders.single.memoryId,
      result.file!.memories.single.id,
    );
    expect(result.file!.warnings, isEmpty);
    expect(result.file!.exportedAt, DateTime.utc(2026, 10, 23, 9, 12, 31));
  });

  group('envelope', () {
    test('a foreign app id is rejected before anything else', () {
      final doc = validDoc()..['app'] = 'other-app';
      final result = validate(doc);
      expect(result.isValid, isFalse);
      expect(codeOf(result), 'wrong_app');
      expect(result.failure!.messageKey, 'import.not_this_app');
    });

    test('a non-integer schema_version is rejected', () {
      final doc = validDoc()..['schema_version'] = '1';
      expect(codeOf(validate(doc)), 'bad_envelope');
    });

    test('a newer schema version is rejected, never migrated blindly', () {
      final doc = validDoc()..['schema_version'] = 2;
      final result = validate(doc);
      expect(codeOf(result), 'version_unsupported');
      expect(result.failure!.messageKey, 'import.version_unsupported');
    });
  });

  group('counts and rows', () {
    test('counts that disagree with the arrays are rejected', () {
      final doc = validDoc()..['counts'] = {'memories': 5, 'reminders': 1};
      expect(codeOf(validate(doc)), 'counts_mismatch');
    });

    test('a missing counts block is tolerated', () {
      final doc = validDoc()..remove('counts');
      expect(validate(doc).isValid, isTrue);
    });

    test('more rows than the cap are rejected', () {
      final template = memoryOf(validDoc());
      final doc = validDoc();
      doc['memories'] = [
        for (var i = 0; i <= 20000; i++) {...template, 'id': 'id-$i'},
      ];
      doc['reminders'] = <Object?>[];
      doc['counts'] = {'memories': 20001, 'reminders': 0};
      expect(codeOf(validate(doc)), 'too_many_rows');
    });

    test('a memories array of the wrong type is rejected', () {
      final doc = validDoc()..['memories'] = 'nope';
      expect(codeOf(validate(doc)), 'bad_memories');
    });
  });

  group('memory fields', () {
    test('a blank title is rejected', () {
      final doc = validDoc();
      memoryOf(doc)['title'] = '   ';
      expect(codeOf(validate(doc)), 'bad_title');
    });

    test('a title longer than 120 characters is rejected', () {
      final doc = validDoc();
      memoryOf(doc)['title'] = 'a' * 121;
      expect(codeOf(validate(doc)), 'bad_title');
    });

    test('a body longer than 10,000 characters is rejected', () {
      final doc = validDoc();
      memoryOf(doc)['body'] = 'a' * 10001;
      expect(codeOf(validate(doc)), 'bad_body');
    });

    test('an unknown category is rejected', () {
      final doc = validDoc();
      memoryOf(doc)['category'] = 'misc';
      expect(codeOf(validate(doc)), 'bad_category');
    });

    test('is_archived must be a real boolean', () {
      final doc = validDoc();
      memoryOf(doc)['is_archived'] = 0;
      expect(codeOf(validate(doc)), 'bad_archived');
    });

    test('a missing timestamp is rejected', () {
      final doc = validDoc();
      memoryOf(doc)['created_at_utc'] = null;
      expect(codeOf(validate(doc)), 'bad_memory_timestamp');
    });

    test('an unparsable timestamp is rejected', () {
      final doc = validDoc();
      memoryOf(doc)['updated_at_utc'] = 'kemarin';
      expect(codeOf(validate(doc)), 'bad_memory_timestamp');
    });
  });

  group('metadata rules (§7.8)', () {
    test('person_name on a non lent_item memory is rejected', () {
      final doc = validDoc();
      memoryOf(doc)['person_name'] = 'Rina';
      expect(codeOf(validate(doc)), 'bad_person_name');
    });

    test('person_name is accepted for lent_item', () {
      final doc = validDoc();
      final memory = memoryOf(doc);
      memory
        ..['category'] = 'lent_item'
        ..['item_name'] = 'Buku'
        ..['person_name'] = 'Rina'
        ..['warranty_end_date'] = null;
      expect(validate(doc).isValid, isTrue);
    });

    test('item_name on a general memory is rejected', () {
      final doc = validDoc();
      final memory = memoryOf(doc);
      memory
        ..['category'] = 'general'
        ..['warranty_end_date'] = null;
      expect(codeOf(validate(doc)), 'bad_item_name');
    });

    test('warranty_end_date on a non warranty memory is rejected', () {
      final doc = validDoc();
      memoryOf(doc)['category'] = 'maintenance';
      expect(codeOf(validate(doc)), 'bad_warranty_category');
    });

    test('an impossible calendar date is rejected', () {
      final doc = validDoc();
      memoryOf(doc)['warranty_end_date'] = '2027-02-30';
      final result = validate(doc);
      expect(codeOf(result), 'bad_warranty_date');
      expect(result.failure!.messageKey, 'import.bad_date');
    });

    test('a timestamp where a date belongs is rejected', () {
      final doc = validDoc();
      memoryOf(doc)['warranty_end_date'] = '2027-12-12T00:00:00Z';
      expect(codeOf(validate(doc)), 'bad_warranty_date');
    });
  });

  group('uniqueness and references', () {
    test('duplicate memory ids are rejected', () {
      final doc = validDoc();
      doc['memories'] = [memoryOf(doc), memoryOf(doc)];
      doc['counts'] = {'memories': 2, 'reminders': 1};
      expect(codeOf(validate(doc)), 'duplicate_memory_id');
    });

    test('duplicate reminder ids are rejected', () {
      final doc = validDoc();
      final reminder = reminderOf(doc);
      final memory = memoryOf(doc);
      doc['memories'] = [
        memory,
        {...memory, 'id': 'second-memory'},
      ];
      doc['reminders'] = [
        reminder,
        {...reminder, 'memory_id': 'second-memory'},
      ];
      doc['counts'] = {'memories': 2, 'reminders': 2};
      expect(codeOf(validate(doc)), 'duplicate_reminder_id');
    });

    test('two reminders for one memory are rejected', () {
      final doc = validDoc();
      final reminder = reminderOf(doc);
      doc['reminders'] = [
        reminder,
        {...reminder, 'id': 'second-reminder'},
      ];
      doc['counts'] = {'memories': 1, 'reminders': 2};
      expect(codeOf(validate(doc)), 'duplicate_reminder_memory');
    });

    test('a reminder pointing at a missing memory is rejected', () {
      final doc = validDoc();
      reminderOf(doc)['memory_id'] = 'ghost';
      final result = validate(doc);
      expect(codeOf(result), 'orphan_reminder');
      expect(result.failure!.messageKey, 'import.bad_reference');
    });

    test('an absurdly long id is rejected', () {
      final doc = validDoc();
      memoryOf(doc)['id'] = 'x' * 65;
      expect(codeOf(validate(doc)), 'bad_memory.id');
    });
  });

  group('reminder fields', () {
    test('an unknown status is rejected', () {
      final doc = validDoc();
      reminderOf(doc)['status'] = 'snoozed';
      expect(codeOf(validate(doc)), 'bad_status');
    });

    test('an unknown precision is rejected', () {
      final doc = validDoc();
      reminderOf(doc)['precision'] = 'roughly';
      expect(codeOf(validate(doc)), 'bad_precision');
    });

    test('an unparsable due_at_utc is rejected', () {
      final doc = validDoc();
      reminderOf(doc)['due_at_utc'] = 'besok';
      expect(codeOf(validate(doc)), 'bad_due_at');
    });

    test('completed without completed_at_utc is rejected', () {
      final doc = validDoc();
      reminderOf(doc)['status'] = 'completed';
      expect(codeOf(validate(doc)), 'missing_completed_at');
    });

    test('completed with completed_at_utc is accepted', () {
      final doc = validDoc();
      final reminder = reminderOf(doc);
      reminder
        ..['status'] = 'completed'
        ..['completed_at_utc'] = '2027-12-12T14:00:00.000Z';
      final result = validate(doc);
      expect(result.isValid, isTrue);
      expect(result.file!.reminders.single.completedAtUtc, isNotNull);
    });

    test('a present but invalid scheduling_status is rejected (§7.8)', () {
      final doc = validDoc();
      reminderOf(doc)['scheduling_status'] = 'broken';
      expect(codeOf(validate(doc)), 'bad_scheduling_status');
    });

    test('an omitted scheduling_status is accepted', () {
      final doc = validDoc();
      reminderOf(doc).remove('scheduling_status');
      expect(validate(doc).isValid, isTrue);
    });

    test('exported delivery facts are ignored, not trusted', () {
      final doc = validDoc();
      reminderOf(doc)
        ..['notification_id'] = 42
        ..['schedule_error_code'] = 'platform:exact_alarm_not_permitted';
      final result = validate(doc);
      expect(result.isValid, isTrue);
    });
  });

  group('warnings are never fatal', () {
    test('an unknown timezone warns and resolves to a real location', () {
      final doc = validDoc();
      reminderOf(doc)['scheduled_timezone'] = 'Mars/Olympus';
      final result = validate(doc);
      expect(result.isValid, isTrue);
      expect(result.file!.warnings, contains('import.warn_timezone'));
    });

    test('a vendor alias resolves without a warning', () {
      final doc = validDoc();
      reminderOf(doc)['scheduled_timezone'] = 'Asia/Calcutta';
      final result = validate(doc);
      expect(result.isValid, isTrue);
      expect(result.file!.warnings, isEmpty);
    });

    test('an unreadable local datetime warns but imports', () {
      final doc = validDoc();
      reminderOf(doc)['scheduled_local_datetime'] = '12/12/2027 20:00';
      final result = validate(doc);
      expect(result.isValid, isTrue);
      expect(result.file!.warnings, contains('import.warn_local_datetime'));
    });

    test('an empty local datetime does not warn', () {
      final doc = validDoc();
      reminderOf(doc)['scheduled_local_datetime'] = '';
      final result = validate(doc);
      expect(result.isValid, isTrue);
      expect(result.file!.warnings, isEmpty);
    });
  });

  group('hostile input', () {
    test('a nested object where a string belongs is rejected, not crashed', () {
      final doc = validDoc();
      memoryOf(doc)['title'] = {'nested': true};
      expect(codeOf(validate(doc)), 'bad_memory.title');
    });

    test('a null list entry is rejected, not crashed', () {
      final doc = validDoc();
      doc['memories'] = [null];
      expect(codeOf(validate(doc)), 'bad_memory');
    });

    test('SQL-ish content is data, never a statement', () {
      final doc = validDoc();
      memoryOf(doc)['title'] = "'; DROP TABLE memories; --";
      final result = validate(doc);
      expect(result.isValid, isTrue);
      expect(result.file!.memories.single.title, "'; DROP TABLE memories; --");
    });

    test('a huge row count fails fast instead of building every model', () {
      final doc = validDoc();
      doc['memories'] = List<Object?>.filled(20001, const <String, Object?>{});
      doc['reminders'] = <Object?>[];
      doc['counts'] = {'memories': 20001, 'reminders': 0};
      expect(codeOf(validate(doc)), 'too_many_rows');
    });
  });

  test('isResolvableZone reports the timezone database truthfully', () {
    expect(isResolvableZone('Asia/Jakarta'), isTrue);
    expect(isResolvableZone('Asia/Nowhere'), isFalse);
  });
}
