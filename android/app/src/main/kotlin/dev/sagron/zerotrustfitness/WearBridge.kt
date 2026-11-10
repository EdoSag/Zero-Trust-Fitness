package dev.sagron.zerotrustfitness

import android.content.Context
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable

/**
 * The phone's side of the Wear OS companion. While the vault is unlocked the
 * app sends today's totals to the paired watch over the Wear OS Data Layer
 * (an encrypted link between the paired devices; nothing goes through the
 * Zero-Trust servers). Glasses of water added on the watch come back the
 * same way and wait in [PENDING_PREFS] until the app is unlocked.
 */
class WearBridge(private val context: Context) {
    companion object {
        const val CHANNEL = "zt.fitness/wear"
        const val TODAY_PATH = "/zt/today"
        const val WATER_PATH_PREFIX = "/zt/add_water"
        const val PENDING_PREFS = "zt_wear_pending"
        const val PENDING_WATER_KEY = "water_ml"

        /** Set by the running app, so water from the watch is added at once. */
        @Volatile
        var onPendingWater: (() -> Unit)? = null

        fun addPendingWater(context: Context, ml: Int) {
            val prefs = context.getSharedPreferences(PENDING_PREFS, Context.MODE_PRIVATE)
            synchronized(this) {
                prefs.edit().putInt(PENDING_WATER_KEY, prefs.getInt(PENDING_WATER_KEY, 0) + ml).commit()
            }
            onPendingWater?.invoke()
        }
    }

    fun pushToday(values: Map<String, Any?>, done: (Boolean) -> Unit) {
        val request = PutDataMapRequest.create(TODAY_PATH).apply {
            dataMap.putBoolean("locked", false)
            dataMap.putLong("steps", (values["steps"] as? Number)?.toLong() ?: 0L)
            dataMap.putLong("stepsGoal", (values["stepsGoal"] as? Number)?.toLong() ?: 0L)
            dataMap.putLong("heartPoints", (values["heartPoints"] as? Number)?.toLong() ?: 0L)
            dataMap.putLong("heartPointsGoal", (values["heartPointsGoal"] as? Number)?.toLong() ?: 0L)
            dataMap.putLong("waterMl", (values["waterMl"] as? Number)?.toLong() ?: 0L)
            dataMap.putLong("waterGoalMl", (values["waterGoalMl"] as? Number)?.toLong() ?: 0L)
            dataMap.putLong("glassMl", (values["glassMl"] as? Number)?.toLong() ?: 250L)
            dataMap.putBoolean("imperial", values["imperial"] as? Boolean ?: false)
            dataMap.putString("day", values["day"] as? String ?: "")
            dataMap.putLong("updatedAt", System.currentTimeMillis())
        }.asPutDataRequest().setUrgent()
        Wearable.getDataClient(context).putDataItem(request)
            .addOnSuccessListener { done(true) }
            .addOnFailureListener { done(false) }
    }

    /** Takes today's numbers off the watch (the switch was turned off). */
    fun clear(done: (Boolean) -> Unit) {
        val request = PutDataMapRequest.create(TODAY_PATH).apply {
            dataMap.putBoolean("locked", true)
            dataMap.putLong("updatedAt", System.currentTimeMillis())
        }.asPutDataRequest().setUrgent()
        Wearable.getDataClient(context).putDataItem(request)
            .addOnSuccessListener { done(true) }
            .addOnFailureListener { done(false) }
    }

    fun peekPendingWaterMl(): Int =
        context.getSharedPreferences(PENDING_PREFS, Context.MODE_PRIVATE)
            .getInt(PENDING_WATER_KEY, 0)

    /** Removes [ml] once the app has saved it, keeping anything that came since. */
    fun ackPendingWaterMl(ml: Int) {
        val prefs = context.getSharedPreferences(PENDING_PREFS, Context.MODE_PRIVATE)
        synchronized(Companion) {
            val left = prefs.getInt(PENDING_WATER_KEY, 0) - ml
            prefs.edit().apply {
                if (left > 0) putInt(PENDING_WATER_KEY, left) else remove(PENDING_WATER_KEY)
            }.commit()
        }
    }
}
