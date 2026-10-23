/// FR-SRH-01 — `trim → lowercase (Unicode) → collapse whitespace`.
///
/// This replaces naive SQLite `LIKE`, which is only case-insensitive for ASCII.
String normalizeForSearch(String input) =>
    input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
