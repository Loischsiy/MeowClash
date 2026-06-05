package com.meowclash.app

import android.app.Activity
import android.os.Bundle
import com.meowclash.app.extensions.wrapAction

class TempActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        when (intent.action) {
            wrapAction("START") -> {
                GlobalState.handleStart()
            }

            wrapAction("STOP") -> {
                // Force the stop: the notification action can be delivered to a
                // freshly recreated process whose in-memory runState is no
                // longer START, which would otherwise be ignored.
                GlobalState.handleStop(force = true)
            }

            wrapAction("CHANGE") -> {
                GlobalState.handleToggle()
            }
        }
        finishAndRemoveTask()
    }
}