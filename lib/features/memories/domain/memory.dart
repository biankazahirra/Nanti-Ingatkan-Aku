import '../../../core/text.dart';

/// FR-MEM-07 — the four allowed categories. `lentItem` means an item the user
/// lent to someone, never one they borrowed.
enum MemoryCategory {
  general('general'),
  lentItem('lent_item'),
  warranty('warranty'),
  maintenance('maintenance');

  const MemoryCategory(this.dbValue);

  final String dbValue;

  /// ARB key for the label.
  String get labelKey => switch (this) {
    MemoryCategory.general => 'category.general',
    MemoryCategory.lentItem => 'category.lent_item',
    MemoryCategory.warranty => 'category.warranty',
    MemoryCategory.maintenance => 'category.maintenance',
  };

  bool get supportsPersonName => this == MemoryCategory.lentItem;

  bool get supportsItemName => this != MemoryCategory.general;

  bool get supportsWarrantyEnd => this == MemoryCategory.warranty;

  static MemoryCategory? tryParse(String? value) {
    for (final category in MemoryCategory.values) {
      if (category.dbValue == value) return category;
    }
    return null;
  }
}

/// A stored fact. Reminders are a separate aggregate (FR-REM-01).
class Memory {
  const Memory({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.isArchived,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.itemName,
    this.personName,
    this.warrantyEndDate,
  });

  final String id;
  final String title;
  final String body;
  final MemoryCategory category;
  final String? itemName;
  final String? personName;

  /// ISO calendar date `YYYY-MM-DD`; never a timestamp.
  final String? warrantyEndDate;
  final bool isArchived;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  String get titleNorm => normalizeForSearch(title);

  String get bodyNorm => normalizeForSearch(body);

  /// First line of the body, for list rows (§5.5).
  String get bodyExcerpt {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return '';
    final firstBreak = trimmed.indexOf('\n');
    return firstBreak == -1 ? trimmed : trimmed.substring(0, firstBreak).trim();
  }

  Memory copyWith({
    String? title,
    String? body,
    MemoryCategory? category,
    String? itemName,
    String? personName,
    String? warrantyEndDate,
    bool? isArchived,
    DateTime? updatedAtUtc,
    bool clearItemName = false,
    bool clearPersonName = false,
    bool clearWarrantyEndDate = false,
  }) {
    return Memory(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      itemName: clearItemName ? null : (itemName ?? this.itemName),
      personName: clearPersonName ? null : (personName ?? this.personName),
      warrantyEndDate: clearWarrantyEndDate
          ? null
          : (warrantyEndDate ?? this.warrantyEndDate),
      isArchived: isArchived ?? this.isArchived,
      createdAtUtc: createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    );
  }
}
