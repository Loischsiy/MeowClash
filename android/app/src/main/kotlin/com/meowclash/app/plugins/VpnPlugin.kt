package com.meowclash.app.plugins

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.BroadcastReceiver
import android.content.ServiceConnection
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.core.content.getSystemService
import com.meowclash.app.MeowClashApplication
import com.meowclash.app.GlobalState
import com.meowclash.app.RunState
import com.meowclash.app.core.Core
import com.meowclash.app.extensions.awaitResult
import com.meowclash.app.extensions.resolveDns
import com.meowclash.app.models.StartForegroundParams
import com.meowclash.app.models.VpnOptions
import com.meowclash.app.services.BaseServiceInterface
import com.meowclash.app.services.MeowClashService
import com.meowclash.app.services.MeowClashVpnService
import com.google.gson.Gson
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.net.InetSocketAddress
import kotlin.concurrent.withLock

data object VpnPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var flutterMethodChannel: MethodChannel
    // Method channel bound to the background SERVICE engine specifically. The
    // foreground-notification loop uses THIS channel (not the shared
    // `flutterMethodChannel`) so it can keep fetching live up/down traffic even
    // after the main UI engine is destroyed — e.g. when the app is swiped away
    // from recents. Because VpnPlugin is a singleton attached to BOTH the main
    // engine and the service engine, the main engine (which attaches last once
    // the app is opened) used to clobber `flutterMethodChannel`; once the main
    // engine died, the notification could no longer reach a live isolate and the
    // traffic counters froze/dropped to "0 0".
    private var foregroundChannel: MethodChannel? = null
    // Set by GlobalState around the service engine's plugin registration so we
    // can tell which onAttachedToEngine call corresponds to the service engine.
    @Volatile
    var attachingServiceEngine: Boolean = false
    private var flClashXService: BaseServiceInterface? = null
    private var options: VpnOptions? = null
    private var isBind: Boolean = false
    private lateinit var scope: CoroutineScope
    private var lastStartForegroundParams: StartForegroundParams? = null
    private var timerJob: Job? = null
    private var attachedEngines = 0
    private var screenReceiver: BroadcastReceiver? = null
    private val uidPageNameMap = mutableMapOf<Int, String>()

    private val connectivity by lazy {
        MeowClashApplication.getAppContext().getSystemService<ConnectivityManager>()
    }

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(className: ComponentName, service: IBinder) {
            isBind = true
            flClashXService = when (service) {
                is MeowClashVpnService.LocalBinder -> service.getService()
                is MeowClashService.LocalBinder -> service.getService()
                else -> throw Exception("invalid binder")
            }
            handleStartService()
        }

        override fun onServiceDisconnected(arg: ComponentName) {
            isBind = false
            flClashXService = null
        }
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        scope = CoroutineScope(Dispatchers.Default)
        // VpnPlugin is shared by the UI and service engines. Register the
        // network callback once and keep it while any engine is attached.
        attachedEngines++
        if (attachedEngines == 1) {
            scope.launch {
                registerNetworkCallback()
            }
        }
        flutterMethodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "vpn")
        flutterMethodChannel.setMethodCallHandler(this)
        // Remember the service engine's channel for the foreground-notification
        // loop. It owns the core (direct FFI traffic) and stays alive while the
        // VPN runs, so the notification keeps showing real up/down even when the
        // app is closed from recents.
        if (attachingServiceEngine) {
            foregroundChannel = flutterMethodChannel
        }
    }

    // Called by GlobalState when the background service engine is torn down so we
    // don't keep a reference to a destroyed channel.
    fun onServiceEngineDestroyed() {
        foregroundChannel = null
    }

    override fun onDetachedFromEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        // Closing the UI must not stop network/DNS updates for the service
        // engine that keeps the core running.
        attachedEngines = (attachedEngines - 1).coerceAtLeast(0)
        if (attachedEngines == 0) {
            unRegisterNetworkCallback()
        }
        // Clear the handler for the engine that is ACTUALLY detaching — not for
        // whatever `flutterMethodChannel` happens to point at. VpnPlugin is a
        // singleton attached to BOTH the main UI engine and the background
        // service engine, and `flutterMethodChannel` holds whichever attached
        // LAST. When the VPN is started from the open app, the service engine
        // attaches last, so the field points at the SERVICE channel. The old code
        // (`flutterMethodChannel.setMethodCallHandler(null)`) therefore wiped the
        // SERVICE engine's "vpn" handler when the MAIN engine detached (app swiped
        // from recents) — afterwards the service isolate's vpn.stop() failed with
        // MissingPluginException and the VPN never actually stopped.
        MethodChannel(flutterPluginBinding.binaryMessenger, "vpn").setMethodCallHandler(null)
        // Keep the shared channel pointed at a still-live engine (the service
        // engine, if any) so later Kotlin->Dart invokes don't target a dead engine.
        foregroundChannel?.let { flutterMethodChannel = it }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                val data = call.argument<String>("data")
                result.success(handleStart(Gson().fromJson(data, VpnOptions::class.java)))
            }

            "stop" -> {
                handleStop()
                result.success(true)
            }

            "showSubscriptionNotification" -> {
                val title = call.argument<String>("title") ?: ""
                val message = call.argument<String>("message") ?: ""
                val actionLabel = call.argument<String>("actionLabel") ?: ""
                val actionUrl = call.argument<String>("actionUrl") ?: ""
                showSubscriptionNotification(title, message, actionLabel, actionUrl)
                result.success(true)
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    fun handleStart(options: VpnOptions): Boolean {
        onUpdateNetwork();
        if (options.enable != this.options?.enable) {
            this.flClashXService = null
        }
        this.options = options
        when (options.enable) {
            true -> handleStartVpn()
            false -> handleStartService()
        }
        return true
    }

    private fun handleStartVpn() {
        GlobalState.getCurrentAppPlugin()?.requestVpnPermission {
            handleStartService()
        }
    }

    fun requestGc() {
        flutterMethodChannel.invokeMethod("gc", null)
    }

    val networks = mutableSetOf<Network>()

    fun onUpdateNetwork() {
        val dns = networks.flatMap { network ->
            connectivity?.resolveDns(network) ?: emptyList()
        }.toSet().joinToString(",")
        scope.launch {
            withContext(Dispatchers.Main) {
                flutterMethodChannel.invokeMethod("dnsChanged", dns)
            }
        }
    }

    private val callback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            networks.add(network)
            onUpdateNetwork()
        }

        override fun onLost(network: Network) {
            networks.remove(network)
            onUpdateNetwork()
        }
    }

    private val request = NetworkRequest.Builder().apply {
        addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
        addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED)
    }.build()

    private fun registerNetworkCallback() {
        networks.clear()
        runCatching { connectivity?.registerNetworkCallback(request, callback) }
    }

    private fun unRegisterNetworkCallback() {
        runCatching { connectivity?.unregisterNetworkCallback(callback) }
        networks.clear()
        onUpdateNetwork()
    }

    private suspend fun startForeground() {
        GlobalState.runLock.lock()
        try {
            if (GlobalState.runState.value != RunState.START) return
            // Always query the SERVICE engine's channel for notification params.
            // It owns the core (live FFI traffic) and outlives the main UI engine,
            // which may already be gone if the app was swiped from recents. Fall
            // back to the shared channel only if the service channel isn't set yet.
            val channel = foregroundChannel ?: flutterMethodChannel
            val data = channel.awaitResult<String>("getStartForegroundParams")
            val startForegroundParams = if (data != null) Gson().fromJson(
                data, StartForegroundParams::class.java
            ) else StartForegroundParams(
                title = "", server = "", content = ""
            )
            if (lastStartForegroundParams != startForegroundParams) {
                lastStartForegroundParams = startForegroundParams
                flClashXService?.startForeground(
                    startForegroundParams.title,
                    startForegroundParams.server,
                    startForegroundParams.content,
                )
            }
        } finally {
            GlobalState.runLock.unlock()
        }
    }

    private fun startForegroundJob() {
        registerScreenReceiver()
        startNotificationLoop()
    }

    // The notification shows live traffic, so it is refreshed every second:
    // a call into the service isolate plus a notification update. Nobody can
    // see it with the screen off, so the loop pauses until the screen is on.
    private fun startNotificationLoop() {
        stopNotificationLoop()
        val power = MeowClashApplication.getAppContext().getSystemService<PowerManager>()
        timerJob = CoroutineScope(Dispatchers.Main).launch {
            while (isActive) {
                // The first pass always runs: it promotes the service to the
                // foreground even when the VPN starts with the screen off.
                startForeground()
                if (power?.isInteractive == false) break
                delay(1000)
            }
        }
    }

    private fun stopNotificationLoop() {
        timerJob?.cancel()
        timerJob = null
    }

    private fun registerScreenReceiver() {
        if (screenReceiver != null) return
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                when (intent.action) {
                    Intent.ACTION_SCREEN_OFF -> stopNotificationLoop()
                    Intent.ACTION_SCREEN_ON -> {
                        if (GlobalState.runState.value == RunState.START) {
                            startNotificationLoop()
                        }
                    }
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
        }
        runCatching {
            ContextCompat.registerReceiver(
                MeowClashApplication.getAppContext(),
                receiver,
                filter,
                ContextCompat.RECEIVER_NOT_EXPORTED,
            )
            screenReceiver = receiver
        }
    }

    private fun unregisterScreenReceiver() {
        val receiver = screenReceiver ?: return
        screenReceiver = null
        runCatching { MeowClashApplication.getAppContext().unregisterReceiver(receiver) }
    }

    private fun stopForegroundJob() {
        unregisterScreenReceiver()
        stopNotificationLoop()
    }


    suspend fun getStatus(): Boolean? {
        return withContext(Dispatchers.Default) {
            flutterMethodChannel.awaitResult<Boolean>("status", null)
        }
    }

    private fun handleStartService() {
        if (flClashXService == null) {
            bindService()
            return
        }
        GlobalState.runLock.withLock {
            if (GlobalState.runState.value == RunState.START) return
            GlobalState.runState.value = RunState.START
            val fd = flClashXService?.start(options!!)
            Core.startTun(
                fd = fd ?: 0,
                protect = this::protect,
                resolverProcess = this::resolverProcess,
            )
            startForegroundJob()
        }
    }

    private fun protect(fd: Int): Boolean {
        return (flClashXService as? MeowClashVpnService)?.protect(fd) == true
    }

    private fun resolverProcess(
        protocol: Int,
        source: InetSocketAddress,
        target: InetSocketAddress,
        uid: Int,
    ): String {
        val nextUid = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            connectivity?.getConnectionOwnerUid(protocol, source, target) ?: -1
        } else {
            uid
        }
        if (nextUid == -1) {
            return ""
        }
        if (!uidPageNameMap.containsKey(nextUid)) {
            uidPageNameMap[nextUid] =
                MeowClashApplication.getAppContext().packageManager?.getPackagesForUid(nextUid)
                    ?.firstOrNull() ?: ""
        }
        return uidPageNameMap[nextUid] ?: ""
    }

    fun handleStop() {
        GlobalState.runLock.withLock {
            if (GlobalState.runState.value == RunState.STOP) return
            GlobalState.runState.value = RunState.STOP
            flClashXService?.stop()
            stopForegroundJob()
            Core.stopTun()
            GlobalState.handleTryDestroy()
        }
    }

    private fun bindService() {
        if (isBind) {
            MeowClashApplication.getAppContext().unbindService(connection)
        }
        val intent = when (options?.enable == true) {
            true -> Intent(MeowClashApplication.getAppContext(), MeowClashVpnService::class.java)
            false -> Intent(MeowClashApplication.getAppContext(), MeowClashService::class.java)
        }
        MeowClashApplication.getAppContext().bindService(intent, connection, Context.BIND_AUTO_CREATE)
    }

    private fun showSubscriptionNotification(title: String, message: String, actionLabel: String, actionUrl: String) {
        val context = MeowClashApplication.getAppContext()
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Create notification channel for subscription alerts (Android O+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                GlobalState.SUBSCRIPTION_NOTIFICATION_CHANNEL,
                "Subscription Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications about subscription expiration"
                enableVibration(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        // Create intent for action button (open URL)
        val actionIntent = Intent(Intent.ACTION_VIEW, Uri.parse(actionUrl))
        val actionPendingIntent = PendingIntent.getActivity(
            context,
            0,
            actionIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Create intent to open app when notification is tapped
        val openAppIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val openAppPendingIntent = PendingIntent.getActivity(
            context,
            1,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, GlobalState.SUBSCRIPTION_NOTIFICATION_CHANNEL)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle(title)
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(openAppPendingIntent)
        
        // Only add action button if actionLabel is not empty
        if (actionLabel.isNotEmpty() && actionUrl.isNotEmpty()) {
            builder.addAction(0, actionLabel, actionPendingIntent)
        }

        notificationManager.notify(GlobalState.SUBSCRIPTION_NOTIFICATION_ID, builder.build())
    }
}