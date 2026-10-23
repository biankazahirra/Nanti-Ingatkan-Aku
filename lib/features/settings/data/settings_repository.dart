import 'package:shared_preferences/shared_preferences.dart';

/// §7.9 — small non-secret settings only. No user text, ever.
class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String keyOnboardingComplete = 'onboarding_complete';
  static const String keyHideNotificationContent = 'hide_notification_content';
  static const String keyLastReconcileAtUtc = 'last_reconcile_at_utc';
  static const String keyLastKnownTimezone = 'last_known_timezone';
  static const String keyLastExportAtUtc = 'last_export_at_utc';
  static const String keyLastBackupNudgeAtUtc = 'last_backup_nudge_at_utc';

  bool get onboardingComplete => _prefs.getBool(keyOnboardingComplete) ?? false;

  Future<void> setOnboardingComplete(bool value) =>
      _prefs.setBool(keyOnboardingComplete, value);

  /// FR-SET-03 — default off.
  bool get hideNotificationContent =>
      _prefs.getBool(keyHideNotificationContent) ?? false;

  Future<void> setHideNotificationContent(bool value) =>
      _prefs.setBool(keyHideNotificationContent, value);

  DateTime? get lastReconcileAtUtc =>
      DateTime.tryParse(_prefs.getString(keyLastReconcileAtUtc) ?? '')?.toUtc();

  Future<void> setLastReconcileAtUtc(DateTime utc) =>
      _prefs.setString(keyLastReconcileAtUtc, utc.toUtc().toIso8601String());

  String? get lastKnownTimezone => _prefs.getString(keyLastKnownTimezone);

  Future<void> setLastKnownTimezone(String id) =>
      _prefs.setString(keyLastKnownTimezone, id);

  DateTime? get lastExportAtUtc =>
      DateTime.tryParse(_prefs.getString(keyLastExportAtUtc) ?? '')?.toUtc();

  Future<void> setLastExportAtUtc(DateTime utc) =>
      _prefs.setString(keyLastExportAtUtc, utc.toUtc().toIso8601String());

  DateTime? get lastBackupNudgeAtUtc =>
      DateTime.tryParse(_prefs.getString(keyLastBackupNudgeAtUtc) ?? '')
          ?.toUtc();

  Future<void> setLastBackupNudgeAtUtc(DateTime utc) =>
      _prefs.setString(keyLastBackupNudgeAtUtc, utc.toUtc().toIso8601String());

  /// FR-SET-04 — wipe every device-local setting.
  Future<void> clear() async {
    await _prefs.remove(keyOnboardingComplete);
    await _prefs.remove(keyHideNotificationContent);
    await _prefs.remove(keyLastReconcileAtUtc);
    await _prefs.remove(keyLastKnownTimezone);
    await _prefs.remove(keyLastExportAtUtc);
    await _prefs.remove(keyLastBackupNudgeAtUtc);
  }
}
