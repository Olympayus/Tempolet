package com.tempolet.tempolet

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "tempolet/android_capabilities"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "notificationPermission" -> {
                        val manager = getSystemService(
                            Context.NOTIFICATION_SERVICE
                        ) as NotificationManager
                        val enabled = manager.areNotificationsEnabled()
                        if (enabled) {
                            result.success("granted")
                        } else {
                            val requested = getSharedPreferences(
                                "tempolet",
                                Context.MODE_PRIVATE
                            ).getBoolean("notification_permission_requested", false)
                            val permanentlyDenied =
                                requested &&
                                    Build.VERSION.SDK_INT >=
                                    Build.VERSION_CODES.TIRAMISU &&
                                    !shouldShowRequestPermissionRationale(
                                        Manifest.permission.POST_NOTIFICATIONS
                                    )
                            result.success(
                                if (permanentlyDenied) "permanentlyDenied" else "denied"
                            )
                        }
                    }
                    "markNotificationPermissionRequested" -> {
                        getSharedPreferences("tempolet", Context.MODE_PRIVATE)
                            .edit()
                            .putBoolean("notification_permission_requested", true)
                            .apply()
                        result.success(null)
                    }
                    "canScheduleExactAlarms" -> {
                        val alarmManager =
                            getSystemService(Context.ALARM_SERVICE) as AlarmManager
                        val canSchedule = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            alarmManager.canScheduleExactAlarms()
                        } else {
                            true
                        }
                        result.success(canSchedule)
                    }
                    "openNotificationSettings" -> {
                        startActivity(
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        )
                        result.success(null)
                    }
                    "openExactAlarmSettings" -> {
                        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            Intent(
                                Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                                Uri.parse("package:$packageName")
                            )
                        } else {
                            Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.parse("package:$packageName")
                            )
                        }
                        startActivity(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
