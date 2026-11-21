package com.tempolet.tempolet

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * Silently re-plans reminders after a system time or timezone change
 * (`v0.1.5 design` §8.10). A headless engine runs the Dart entry point; if the
 * engine cannot start, a dirty flag is recorded for the next app launch.
 */
class TimeChangeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED -> reschedule(context)
        }
    }

    private fun reschedule(context: Context) {
        try {
            val appContext = context.applicationContext
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(appContext)
            loader.ensureInitializationComplete(appContext, null)
            val engine = FlutterEngine(appContext)
            engine.dartExecutor.executeDartCallback(
                DartExecutor.DartCallback(
                    appContext.assets,
                    loader.findAppBundlePath(),
                    "notificationRescheduleEntrypoint"
                )
            )
        } catch (error: Exception) {
            // Flutter shared_preferences stores keys with a `flutter.` prefix
            // in its own file, so the next launch can consume this flag.
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .edit()
                .putBoolean("flutter.notification_reschedule_pending", true)
                .apply()
        }
    }
}
