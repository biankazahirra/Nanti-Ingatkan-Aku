import '../../../l10n/app_localizations.dart';
import '../../memories/domain/memory.dart';
import '../../settings/data/settings_repository.dart';

class NotificationText {
  const NotificationText({required this.title, required this.body});

  final String title;
  final String body;
}

/// FR-SET-03 / FR-REM-10 — one place decides what a lock-screen notification may
/// reveal. Notification text is never persisted and never logged.
class NotificationContentPolicy {
  NotificationContentPolicy({required this._settings, required this._l10n});

  final SettingsRepository _settings;
  final AppLocalizations _l10n;

  Future<NotificationText> resolve(Memory memory) async {
    if (_settings.hideNotificationContent) {
      return NotificationText(
        title: _l10n.notifGenericTitle,
        body: _l10n.notifHiddenBody,
      );
    }
    return NotificationText(title: memory.title, body: memory.bodyExcerpt);
  }
}
