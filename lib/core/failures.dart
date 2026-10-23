/// Typed domain failures. The presentation layer maps [messageKey] to a
/// localized string; technical detail stays in diagnostics only.
sealed class Failure implements Exception {
  const Failure(this.code, this.messageKey);

  /// Stable technical code for diagnostics (never shown to the user).
  final String code;

  /// ARB key resolved at the presentation boundary.
  final String messageKey;

  @override
  String toString() => '$runtimeType($code)';
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.code, super.messageKey);
}

class StorageFailure extends Failure {
  const StorageFailure([String code = 'storage_error'])
    : super(code, 'error.save_failed');
}

class SchedulingFailure extends Failure {
  const SchedulingFailure([String code = 'schedule_error'])
    : super(code, 'reminder.failed');
}

class ImportFailure extends Failure {
  const ImportFailure(super.code, super.messageKey);
}

class BackupFailure extends Failure {
  const BackupFailure(super.code, super.messageKey);
}

/// The DB was written by a newer app build; never downgrade destructively.
class DbVersionTooNewFailure extends Failure {
  const DbVersionTooNewFailure()
    : super('db_version_too_new', 'error.db_newer');
}
