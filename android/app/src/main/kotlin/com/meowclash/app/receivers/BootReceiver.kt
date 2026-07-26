package com.meowclash.app.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.VpnService
import android.util.Log
import com.meowclash.app.GlobalState
import org.json.JSONObject

class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "BootReceiver"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val CONFIG_KEY = "flutter.config"
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            // BOOT_COMPLETED: normal reboot. MY_PACKAGE_REPLACED: an app update
            // kills the running VPN — restart it so the user doesn't silently
            // stay unprotected. QUICKBOOT_POWERON: Xiaomi/HTC "fast boot"
            // restarts that don't always emit BOOT_COMPLETED.
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON" -> Unit

            else -> return
        }

        runCatching {
            val config = readConfig(context)
            val autoRun = config
                ?.optJSONObject("appSetting")
                ?.optBoolean("autoRun", false) ?: false
            // opt() (not optString()) — JSONObject.optString() returns the
            // literal string "null" for an explicit JSON null, which Dart's
            // json.encode writes for an unset profile.
            val profileId = config?.opt("currentProfileId")
            val hasProfile = profileId is String && profileId.isNotEmpty()
            Log.d(TAG, "${intent.action}: autoRun=$autoRun hasProfile=$hasProfile")
            if (!autoRun || !hasProfile) return

            if (isVpnAlreadyActive(context)) {
                Log.d(TAG, "VPN already active (system Always-On), skipping")
                return
            }

            // In VPN (TUN) mode the permission dialog can't be shown from the
            // background; without the grant the headless start would only fail
            // later and deeper, so bail out early instead.
            val vpnEnabled = config
                ?.optJSONObject("vpnProps")
                ?.optBoolean("enable", true) ?: true
            if (vpnEnabled && VpnService.prepare(context) != null) {
                Log.d(TAG, "VPN permission not granted, skipping background start")
                return
            }

            // Same headless path the quick-settings tile uses when the app is
            // closed: queues a START action and spins up the background service
            // engine, which starts the (foreground) VPN service once Dart is
            // ready.
            GlobalState.handleStart()
        }.onFailure { Log.e(TAG, "Error in BootReceiver", it) }
    }

    private fun readConfig(context: Context): JSONObject? {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val configJson = prefs.getString(CONFIG_KEY, null) ?: return null
        return runCatching { JSONObject(configJson) }.getOrNull()
    }

    private fun isVpnAlreadyActive(context: Context): Boolean {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            ?: return false
        val activeNetwork = cm.activeNetwork ?: return false
        val caps = cm.getNetworkCapabilities(activeNetwork) ?: return false
        return caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)
    }
}
