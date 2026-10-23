import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/logging.dart';
import '../domain/reminder_scheduler.dart';

/// §7.6 — the only place that talks to `flutter_local_notifications`.
///
/// Channel ID `reminders` is stable and must never be renamed after release
/// (FR-REM-11).
class LocalNotificationScheduler implements ReminderScheduler {
  LocalNotificationScheduler({
    required this._channelName,
    required this._channelDescription,
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final String _channelName;
  final String _channelDescription;

  static const String channelId = 'reminders';
  static const String _channelDescriptionFallback = 'Pengingat dari catatanmu.';

  /// Answered by `MainActivity.kt`.
  static const MethodChannel _platform = MethodChannel(
    'nanti_ingatkan_aku/platform',
  );

  void Function(String payload)? onNotificationTap;

  String? _launchPayload;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// FR-REM-10 — payload from the launch that started the app, if any.
  String? takeLaunchPayload() {
    final payload = _launchPayload;
    _launchPayload = null;
    return payload;
  }

  Future<void> initialize() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null) return;
        final handler = onNotificationTap;
        if (handler != null) {
          handler(payload);
        } else {
          _launchPayload = payload;
        }
      },
    );

    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      _launchPayload = launch?.notificationResponse?.payload;
    }

    await _android?.createNotificationChannel(
      AndroidNotificationChannel(
        channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
        enableVibration: true,
      ),
    );
  }

  @override
  Future<PermissionState> ensurePermission() async {
    final android = _android;
    if (android == null) return PermissionState.granted;
    try {
      final granted = await android.requestNotificationsPermission();
      // `null` means the platform predates the runtime permission (API < 33).
      return (granted ?? true)
          ? PermissionState.granted
          : PermissionState.permanentlyDenied;
    } on PlatformException catch (error) {
      logEvent(LogCodes.permissionNeeded, detail: error.code);
      return PermissionState.denied;
    }
  }

  @override
  Future<bool> notificationsEnabled() async {
    final android = _android;
    if (android == null) return false;
    try {
      return await android.areNotificationsEnabled() ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// FR-REM-07 — false is a normal outcome on Android 14+, never an error.
  @override
  Future<bool> canScheduleExact() async {
    final android = _android;
    if (android == null) return false;
    try {
      return await android.canScheduleExactNotifications() ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Opens the system exact-alarm grant screen when the user asks for it.
  @override
  Future<bool> requestExactAlarmsPermission() async {
    final android = _android;
    if (android == null) return false;
    try {
      return await android.requestExactAlarmsPermission() ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<ScheduleOutcome> schedule({
    required int notificationId,
    required DateTime dueAtUtc,
    required String title,
    required String body,
    required String payload,
  }) async {
    final permission = await ensurePermission();
    if (permission != PermissionState.granted) {
      return const ScheduleOutcome.permissionNeeded();
    }
    final exact = await canScheduleExact();
    final mode = exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    try {
      await _plugin.zonedSchedule(
        id: notificationId,
        title: title.isEmpty ? null : title,
        body: body.isEmpty ? null : body,
        scheduledDate: tz.TZDateTime.from(dueAtUtc.toUtc(), tz.local),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            _channelName,
            channelDescription: _channelDescription.isEmpty
                ? _channelDescriptionFallback
                : _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            enableVibration: true,
            category: AndroidNotificationCategory.reminder,
          ),
        ),
        androidScheduleMode: mode,
        payload: payload,
      );
      return ScheduleOutcome.scheduled(exact: exact);
    } on PlatformException catch (error) {
      return ScheduleOutcome.failed(normalizedErrorCode(error));
    } on Object catch (error) {
      return ScheduleOutcome.failed(normalizedErrorCode(error));
    }
  }

  @override
  Future<void> cancel(int notificationId) => _plugin.cancel(id: notificationId);

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  @override
  Future<Set<int>> pendingNotificationIds() async {
    final pending = await _plugin.pendingNotificationRequests();
    return pending.map((request) => request.id).toSet();
  }

  /// FR-SET-01 / FR-REM-06 — `flutter_local_notifications` stops at its own
  /// grant screens, so the Android shell answers this one for us.
  @override
  Future<void> openAppSettings() async {
    try {
      await _platform.invokeMethod<void>('openAppSettings');
    } on PlatformException catch (error) {
      logEvent(LogCodes.permissionNeeded, detail: error.code);
    } on MissingPluginException {
      // Tests and non-Android hosts have no shell to ask.
    }
  }

  @visibleForTesting
  FlutterLocalNotificationsPlugin get plugin => _plugin;
}

/// Keeps only the error class and code, never message text (NFR-SEC-04).
String normalizedErrorCode(Object error) {
  if (error is PlatformException) {
    return 'platform:${error.code}';
  }
  return error.runtimeType.toString();
}
