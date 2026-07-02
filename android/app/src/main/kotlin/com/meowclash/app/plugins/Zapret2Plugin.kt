package com.meowclash.app.plugins

import com.google.gson.Gson
import com.meowclash.app.core.Core
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

class Zapret2Plugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "zapret2")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> result.success(true)
            "apply" -> result.success(apply(call))
            "clear" -> {
                Core.zapret2Clear()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun apply(call: MethodCall): Boolean {
        val strategy = call.argument<String>("strategyId") ?: return false
        val args = call.argument<List<String>>("args") ?: emptyList()
        val targets = call.argument<String>("targets") ?: "[]"
        val hosts = mutableListOf<String>()
        val parsedTargets = JSONArray(targets)
        for (i in 0 until parsedTargets.length()) {
            val host = parsedTargets.optJSONObject(i)?.optString("host").orEmpty()
            if (host.isNotEmpty()) hosts.add(host)
        }
        return Core.zapret2Apply(strategy, Gson().toJson(args), Gson().toJson(hosts))
    }
}
