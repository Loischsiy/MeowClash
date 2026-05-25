package com.meowclash.app.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.RemoteViews
import androidx.lifecycle.Observer
import com.meowclash.app.GlobalState
import com.meowclash.app.R
import com.meowclash.app.RunState

/**
 * Minimal 1x1 home-screen widget: a single tap target showing the app
 * logo (colored when the tunnel is up, monochrome otherwise). Tap
 * toggles the tunnel. Separate from ModeWidgetProvider so users can
 * pick the compact variant without the mode column.
 */
class OnOffWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "OnOffWidgetProvider"

        const val ACTION_TOGGLE = "com.meowclash.app.widget.ACTION_ONOFF_TOGGLE"

        @Volatile
        private var observersAttached = false

        private val runStateObserver = Observer<RunState> { _ -> refreshAll() }

        fun ensureObservers() {
            if (observersAttached) return
            synchronized(this) {
                if (observersAttached) return
                GlobalState.runState.observeForever(runStateObserver)
                observersAttached = true
            }
        }

        private fun refreshAll() {
            val ctx = com.meowclash.app.MeowClashApplication.getAppContext() ?: return
            val mgr = AppWidgetManager.getInstance(ctx) ?: return
            val component = ComponentName(ctx, OnOffWidgetProvider::class.java)
            val ids = mgr.getAppWidgetIds(component)
            if (ids == null || ids.isEmpty()) return
            for (id in ids) {
                render(ctx, mgr, id)
            }
        }

        private fun render(context: Context, mgr: AppWidgetManager, widgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.widget_on_off)
            val runState = GlobalState.runState.value ?: RunState.STOP
            val logo = if (runState == RunState.START) R.drawable.widget_logo_color else R.drawable.widget_logo_mono
            views.setImageViewResource(R.id.widget_on_off, logo)
            views.setOnClickPendingIntent(R.id.widget_on_off, pending(context, ACTION_TOGGLE))
            mgr.updateAppWidget(widgetId, views)
        }

        private fun pending(context: Context, action: String): PendingIntent {
            val intent = Intent(context, OnOffWidgetProvider::class.java).apply {
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
        if (intent.action == ACTION_TOGGLE) {
            GlobalState.handleToggle()
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        Log.d(TAG, "onEnabled")
        ensureObservers()
        GlobalState.syncStatus()
    }
}
