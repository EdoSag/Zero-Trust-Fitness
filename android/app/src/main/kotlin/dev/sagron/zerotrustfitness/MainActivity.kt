package dev.sagron.zerotrustfitness

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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

    override fun onDestroy() {
        WearBridge.onPendingWater = null
        super.onDestroy()
    }
}
