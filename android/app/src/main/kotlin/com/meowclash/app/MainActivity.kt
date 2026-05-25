package com.meowclash.app

import android.content.Context
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.Display
import androidx.appcompat.app.AppCompatDelegate
import com.meowclash.app.plugins.AppPlugin
import com.meowclash.app.plugins.CryptoPlugin
import com.meowclash.app.plugins.ServicePlugin
import com.meowclash.app.plugins.TilePlugin
import com.meowclash.app.plugins.VpnPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Apply app theme before creating the activity to fix splash screen theme
        applyAppTheme()

        super.onCreate(savedInstanceState)

        applyHighestRefreshRate()
    }

    override fun onResume() {
        super.onResume()
        // Re-apply the highest refresh rate every time the activity becomes
        // foreground. Some OEMs (Pixel/Realme/etc.) drop the preferred display
        // mode back to the default when the window is hidden and restored.
        applyHighestRefreshRate()
    }

    private fun applyHighestRefreshRate() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return
        }
        val modeId = getHighestRefreshRateDisplayMode()
        if (modeId == 0) {
            return
        }
        // IMPORTANT: mutate a local copy of `window.attributes` and assign the
        // result back. Mutating the live `LayoutParams` instance in place
        // does not propagate to the WindowManager on many devices (notably
        // Pixel), so the preferred display mode silently has no effect and
        // the screen stays at 60 Hz. Reassigning the field forces an
        // updateViewLayout(), which is also why this no longer kicks the
        // "Show refresh rate" developer overlay off on startup.
        val attrs = window.attributes
        if (attrs.preferredDisplayModeId != modeId) {
            attrs.preferredDisplayModeId = modeId
            window.attributes = attrs
        }
    }

    @Suppress("DEPRECATION")
    private fun activeDisplay(): Display? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            display
        } else {
            windowManager.defaultDisplay
        }
    }

    private fun getHighestRefreshRateDisplayMode(): Int {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return 0
        }
        val display = activeDisplay() ?: return 0
        val current = display.mode
        val modes = display.supportedModes

        var bestModeId = current.modeId
        var bestRefreshRate = current.refreshRate

        // Only consider modes with the same physical resolution as the
        // current one. Switching to a mode with a different resolution can
        // trigger an unwanted reconfiguration on some devices.
        for (mode in modes) {
            if (mode.physicalWidth != current.physicalWidth ||
                mode.physicalHeight != current.physicalHeight
            ) {
                continue
            }
            if (mode.refreshRate > bestRefreshRate) {
                bestRefreshRate = mode.refreshRate
                bestModeId = mode.modeId
            }
        }
        return bestModeId
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Platform Channel for getting Android ID
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.meowclash.app/device_id")
            .setMethodCallHandler { call, result ->
                if (call.method == "getAndroidId") {
                    try {
                        val androidId = Settings.Secure.getString(
                            contentResolver,
                            Settings.Secure.ANDROID_ID
                        )
                        result.success(androidId)
                    } catch (e: Exception) {
                        result.error("ANDROID_ID_ERROR", "Failed to get Android ID: ${e.message}", null)
                    }
                } else {
                    result.notImplemented()
                }
            }
        
        flutterEngine.plugins.add(AppPlugin())
        flutterEngine.plugins.add(CryptoPlugin())
        flutterEngine.plugins.add(ServicePlugin)
        flutterEngine.plugins.add(TilePlugin())
        flutterEngine.plugins.add(VpnPlugin)
        GlobalState.flutterEngine = flutterEngine
        
        // Sync VPN status when app opens - this ensures UI reflects actual VPN state
        // especially important when VPN was started via Tile while app was not in memory
        GlobalState.syncStatus()
    }

    override fun onDestroy() {
        GlobalState.flutterEngine = null
        // Don't reset runState here - VPN might still be running via serviceEngine
        // The runState is managed by VpnPlugin.handleStart/handleStop
        super.onDestroy()
    }

    private fun applyAppTheme() {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val configJson = prefs.getString("flutter.config", null)
            
            if (configJson != null) {
                val config = JSONObject(configJson)
                val themeProps = config.optJSONObject("themeProps")
                val themeMode = themeProps?.optString("themeMode", "ThemeMode.system") ?: "ThemeMode.system"
                
                when {
                    themeMode.contains("light", ignoreCase = true) -> {
                        AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_NO)
                    }
                    themeMode.contains("dark", ignoreCase = true) -> {
                        AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_YES)
                    }
                    else -> {
                        AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM)
                    }
                }
            } else {
                // Default to system theme if config not found
                AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM)
            }
        } catch (e: Exception) {
            // Fallback to system theme on error
            AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM)
        }
    }
}
