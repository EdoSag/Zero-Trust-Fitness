package dev.sagron.zerotrustfitness

import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Channel `zt_fitness/links` holds challenge invite links
 * (https://zerotrust.bz/join/fitness#zt1.fitness.…) the app was opened with, until
 * the unlocked app takes them.
 */
class MainActivity : FlutterFragmentActivity() {
    private var links: MethodChannel? = null
    private val pendingLinks = mutableListOf<String>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        links = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zt_fitness/links").also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "takePending" -> {
                        val out = ArrayList(pendingLinks)
                        pendingLinks.clear()
                        result.success(out)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        handleLink(intent)
        val bridge = WearBridge(applicationContext)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WearBridge.CHANNEL)
        val main = Handler(Looper.getMainLooper())
        WearBridge.onPendingWater = { main.post { channel.invokeMethod("pendingWater", null) } }
        channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "pushToday" -> {
                        @Suppress("UNCHECKED_CAST")
                        val values = call.arguments as? Map<String, Any?> ?: emptyMap()
                        bridge.pushToday(values) { ok -> result.success(ok) }
                    }
                    "clear" -> bridge.clear { ok -> result.success(ok) }
                    "peekPendingWater" -> result.success(bridge.peekPendingWaterMl())
                    "ackPendingWater" -> {
                        bridge.ackPendingWaterMl((call.arguments as? Number)?.toInt() ?: 0)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleLink(intent)
    }

    private fun handleLink(intent: Intent?) {
        if (intent?.action != Intent.ACTION_VIEW) return
        val uri = intent.data ?: return
        if (uri.host != "zerotrust.bz" || uri.path?.startsWith("/join") != true) return
        // Taken once: rotating the screen must not open it again.
        intent.action = null
        pendingLinks.add(uri.toString())
        links?.invokeMethod("linksArrived", null)
    }

    override fun onDestroy() {
        WearBridge.onPendingWater = null
        super.onDestroy()
    }
}
