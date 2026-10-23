import 'package:characters/characters.dart';

import '../../../core/constants.dart';
import 'memory.dart';

/// Fields that can carry a validation error, so the UI can focus the offender.
enum MemoryField { title, body, personName, itemName, warrantyEndDate }

class FieldError {
  const FieldError(this.field, this.messageKey);

  final MemoryField field;

  /// ARB key, resolved at the presentation boundary.
  final String messageKey;
}

/// Raw user input before validation.
class MemoryDraft {
  const MemoryDraft({
    this.title = '',
    this.body = '',
    this.category = MemoryCategory.general,
    this.personName,
    this.itemName,
    this.warrantyEndDate,
  });

  final String title;
  final String body;
  final MemoryCategory category;
  final String? personName;
  final String? itemName;
  final String? warrantyEndDate;

  static MemoryDraft fromMemory(Memory memory) => MemoryDraft(
    title: memory.title,
    body: memory.body,
    category: memory.category,
    personName: memory.personName,
    itemName: memory.itemName,
    warrantyEndDate: memory.warrantyEndDate,
  );
}

/// Grapheme-aware length (FR-MEM-01) — emoji and combining marks count once.
int graphemeLength(String value) => value.characters.length;

bool isBlank(String value) => value.trim().isEmpty;

/// Text that will actually be persisted for a draft.
MemoryDraft sanitizeDraft(MemoryDraft draft) {
  final category = draft.category;
  return MemoryDraft(
    title: draft.title.trim(),
    body: draft.body,
    category: category,
    personName: category.supportsPersonName
        ? _nullIfBlank(draft.personName)
        : null,
    itemName: category.supportsItemName ? _nullIfBlank(draft.itemName) : null,
    warrantyEndDate: category.supportsWarrantyEnd
        ? _nullIfBlank(draft.warrantyEndDate)
        : null,
  );
}

String? _nullIfBlank(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// FR-MEM-01 / FR-MEM-03 / FR-REM-02 — all input rules in one testable place.
/// Mirrors the DB CHECK constraints in §7.3.
List<FieldError> validateDraft(MemoryDraft draft) {
  final errors = <FieldError>[];
  final sanitized = sanitizeDraft(draft);

  if (isBlank(sanitized.title)) {
    errors.add(const FieldError(MemoryField.title, 'error.title_empty'));
  } else if (graphemeLength(sanitized.title) > Limits.titleMax) {
    errors.add(const FieldError(MemoryField.title, 'error.title_too_long'));
  }

  if (graphemeLength(sanitized.body) > Limits.bodyMax) {
    errors.add(const FieldError(MemoryField.body, 'error.body_too_long'));
  }

  final person = sanitized.personName;
  if (person != null && graphemeLength(person) > Limits.personNameMax) {
    errors.add(
      const FieldError(MemoryField.personName, 'error.person_too_long'),
    );
  }

  final item = sanitized.itemName;
  if (item != null && graphemeLength(item) > Limits.itemNameMax) {
    errors.add(const FieldError(MemoryField.itemName, 'error.item_too_long'));
  }

  final warrantyEnd = sanitized.warrantyEndDate;
  if (warrantyEnd != null && !isRealCalendarDate(warrantyEnd)) {
    errors.add(
      const FieldError(MemoryField.warrantyEndDate, 'error.date_invalid'),
    );
  }

  return errors;
}

/// Rejects `2027-02-30` and similar (FR-IMP-01 date rule).
bool isRealCalendarDate(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) return false;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  if (month < 1 || month > 12 || day < 1) return false;
  final maxDay = DateTime.utc(year, month + 1, 0).day;
  return day <= maxDay;
}
