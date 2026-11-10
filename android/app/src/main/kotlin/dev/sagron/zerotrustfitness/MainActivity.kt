package dev.sagron.zerotrustfitness

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val bridge = WearBridge(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WearBridge.CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pushToday" -> {
                        @Suppress("UNCHECKED_CAST")
                        val values = call.arguments as? Map<String, Any?> ?: emptyMap()
                        bridge.pushToday(values) { ok -> result.success(ok) }
                    }
                    "clear" -> bridge.clear { ok -> result.success(ok) }
                    "takePendingWater" -> result.success(bridge.takePendingWaterMl())
                    else -> result.notImplemented()
                }
            }
    }
}
