package com.follow.clashx.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import androidx.lifecycle.Observer
import com.follow.clashx.GlobalState
import com.follow.clashx.R
import com.follow.clashx.RunState

/**
 * Home-screen widget: three mode buttons (Rule/Global/Direct) and a
 * toggle button showing the app logo (colored when the tunnel is up,
 * monochrome otherwise). When the current subscription disables global
 * mode (`meowclash-globalmode: false`), the mode column is hidden and a
 * start/stop label appears under the logo.
 *
 * Widget redraws are driven by LiveData in GlobalState; observers are
 * attached lazily on the first widget event and live with the process.
 */
class ModeWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "ModeWidgetProvider"

        const val ACTION_TOGGLE = "com.follow.clashx.widget.ACTION_TOGGLE"
        const val ACTION_MODE_RULE = "com.follow.clashx.widget.ACTION_MODE_RULE"
        const val ACTION_MODE_GLOBAL = "com.follow.clashx.widget.ACTION_MODE_GLOBAL"
        const val ACTION_MODE_DIRECT = "com.follow.clashx.widget.ACTION_MODE_DIRECT"

        @Volatile
        private var observersAttached = false

        private val runStateObserver = Observer<RunState> { _ ->
            GlobalState.flutterEngine?.let { /* no-op, just to hint dependency */ }
            refreshAll()
        }
        private val modeObserver = Observer<String> { _ -> refreshAll() }
        private val globalModeEnabledObserver = Observer<Boolean> { _ -> refreshAll() }

        /**
         * Ensure the widget redraws whenever the app's runState or mode
         * changes. observeForever is cheap and lives until process death;
         * we guard so we only wire it once.
         */
        fun ensureObservers() {
            if (observersAttached) return
            synchronized(this) {
                if (observersAttached) return
                GlobalState.runState.observeForever(runStateObserver)
                GlobalState.currentMode.observeForever(modeObserver)
                GlobalState.globalModeEnabled.observeForever(globalModeEnabledObserver)
                observersAttached = true
            }
        }

        private fun refreshAll() {
            val ctx = com.follow.clashx.MeowClashApplication.getAppContext() ?: return
            val mgr = AppWidgetManager.getInstance(ctx) ?: return
            val component = ComponentName(ctx, ModeWidgetProvider::class.java)
            val ids = mgr.getAppWidgetIds(component)
            if (ids == null || ids.isEmpty()) return
            for (id in ids) {
                render(ctx, mgr, id)
            }
        }

        private fun render(context: Context, mgr: AppWidgetManager, widgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.widget_mode)
            val runState = GlobalState.runState.value ?: RunState.STOP
            val mode = GlobalState.currentMode.value ?: "rule"

            // Mode buttons — highlight active one, wire click intents.
            applyMode(views, mode)
            views.setOnClickPendingIntent(R.id.widget_btn_rule, pending(context, ACTION_MODE_RULE))
            views.setOnClickPendingIntent(R.id.widget_btn_global, pending(context, ACTION_MODE_GLOBAL))
            views.setOnClickPendingIntent(R.id.widget_btn_direct, pending(context, ACTION_MODE_DIRECT))

            // When subscription disables global mode we drop the whole mode
            // column and leave just the logo toggle.
            val globalEnabled = GlobalState.globalModeEnabled.value ?: true
            views.setViewVisibility(
                R.id.widget_mode_col,
                if (globalEnabled) View.VISIBLE else View.GONE,
            )

            // Toggle — colored logo when tunnel is up, monochrome otherwise.
            val logo = if (runState == RunState.START) R.drawable.widget_logo_color else R.drawable.widget_logo_mono
            views.setImageViewResource(R.id.widget_toggle, logo)
            views.setOnClickPendingIntent(R.id.widget_toggle, pending(context, ACTION_TOGGLE))

            mgr.updateAppWidget(widgetId, views)
        }

        private fun applyMode(views: RemoteViews, mode: String) {
            views.setInt(
                R.id.widget_btn_rule,
                "setBackgroundResource",
                if (mode == "rule") R.drawable.widget_mode_btn_active else R.drawable.widget_mode_btn_inactive,
            )
            views.setInt(
                R.id.widget_btn_global,
                "setBackgroundResource",
                if (mode == "global") R.drawable.widget_mode_btn_active else R.drawable.widget_mode_btn_inactive,
            )
            views.setInt(
                R.id.widget_btn_direct,
                "setBackgroundResource",
                if (mode == "direct") R.drawable.widget_mode_btn_active else R.drawable.widget_mode_btn_inactive,
            )
            val activeTxt = 0xFF000000.toInt()
            val inactiveTxt = 0xFFFFFFFF.toInt()
            views.setTextColor(R.id.widget_btn_rule, if (mode == "rule") activeTxt else inactiveTxt)
            views.setTextColor(R.id.widget_btn_global, if (mode == "global") activeTxt else inactiveTxt)
            views.setTextColor(R.id.widget_btn_direct, if (mode == "direct") activeTxt else inactiveTxt)
        }

        private fun pending(context: Context, action: String): PendingIntent {
            val intent = Intent(context, ModeWidgetProvider::class.java).apply {
                this.action = action
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            return PendingIntent.getBroadcast(context, action.hashCode(), intent, flags)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        Log.d(TAG, "onUpdate: ${appWidgetIds.joinToString()}")
        ensureObservers()
        GlobalState.syncStatus()
        for (id in appWidgetIds) {
            render(context, appWidgetManager, id)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        Log.d(TAG, "onReceive: ${intent.action}")
        ensureObservers()
        when (intent.action) {
            ACTION_TOGGLE -> GlobalState.handleToggle()
            ACTION_MODE_RULE -> GlobalState.handleChangeMode("rule")
            ACTION_MODE_GLOBAL -> GlobalState.handleChangeMode("global")
            ACTION_MODE_DIRECT -> GlobalState.handleChangeMode("direct")
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        Log.d(TAG, "onEnabled")
        ensureObservers()
        GlobalState.syncStatus()
    }
}
