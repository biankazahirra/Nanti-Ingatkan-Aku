package com.nantiingatkanaku.nanti_ingatkan_aku

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * FR-SET-01 — `flutter_local_notifications` can open its own permission and
 * exact-alarm screens, but not the per-app settings page, and no dependency in
 * the stack provides an Intent. This answers the one method Dart asks for.
 *
 * Channel: `nanti_ingatkan_aku/platform`, see
 * `lib/features/reminders/platform/local_notification_scheduler.dart`.
 */
class MainActivity : FlutterActivity() {
    private val platformChannel = "nanti_ingatkan_aku/platform"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, platformChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openAppSettings" -> {
                        try {
                            val intent = Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.fromParts("package", packageName, null),
                            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("app_settings_unavailable", error.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
