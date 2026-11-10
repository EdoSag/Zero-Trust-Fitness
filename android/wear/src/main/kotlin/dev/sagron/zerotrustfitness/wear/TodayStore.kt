package dev.sagron.zerotrustfitness.wear

import android.content.Context
import android.content.SharedPreferences
import androidx.wear.tiles.TileService
import com.google.android.gms.wearable.DataMap
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Today's numbers as the phone last sent them, kept on the watch. */
data class Today(
    val connected: Boolean,
    val day: String,
    val steps: Long,
    val stepsGoal: Long,
    val heartPoints: Long,
    val heartPointsGoal: Long,
    val waterMl: Long,
    val waterGoalMl: Long,
    val glassMl: Long,
    val imperial: Boolean,
) {
    /** False when the numbers are from an earlier day. */
    val isCurrent: Boolean get() = day == TodayStore.todayKey()

    fun water(ml: Long): String =
        if (imperial) "${Math.round(ml / 29.5735)} oz"
        else if (ml >= 1000) String.format(Locale.getDefault(), "%.2f L", ml / 1000.0)
        else "$ml ml"

    fun glassLabel(): String = "+" + water(glassMl)

    fun fraction(value: Long, goal: Long): Float =
        if (goal <= 0) 0f else (value.toFloat() / goal).coerceIn(0f, 1f)
}

object TodayStore {
    private const val PREFS = "zt_today"
    private const val PENDING = "pendingWaterMl"

    fun todayKey(): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun read(context: Context): Today {
        val p = prefs(context)
        val current = p.getString("day", "") == todayKey()
        return Today(
            connected = p.getBoolean("connected", false),
            day = p.getString("day", "") ?: "",
            steps = if (current) p.getLong("steps", 0) else 0,
            stepsGoal = p.getLong("stepsGoal", 10000),
            heartPoints = if (current) p.getLong("heartPoints", 0) else 0,
            heartPointsGoal = p.getLong("heartPointsGoal", 21),
            waterMl = (if (current) p.getLong("waterMl", 0) else 0) + p.getLong(PENDING, 0),
            waterGoalMl = p.getLong("waterGoalMl", 2000),
            glassMl = p.getLong("glassMl", 250),
            imperial = p.getBoolean("imperial", false),
        )
    }

    /** Saves what the phone sent; "locked" means the person turned it off. */
    fun save(context: Context, map: DataMap) {
        val edit = prefs(context).edit().clear()
        if (!map.getBoolean("locked", false)) {
            edit.putBoolean("connected", true)
                .putString("day", map.getString("day", ""))
                .putLong("steps", map.getLong("steps"))
                .putLong("stepsGoal", map.getLong("stepsGoal"))
                .putLong("heartPoints", map.getLong("heartPoints"))
                .putLong("heartPointsGoal", map.getLong("heartPointsGoal"))
                .putLong("waterMl", map.getLong("waterMl"))
                .putLong("waterGoalMl", map.getLong("waterGoalMl"))
                .putLong("glassMl", map.getLong("glassMl", 250))
                .putBoolean("imperial", map.getBoolean("imperial", false))
        }
        edit.apply()
        refreshTiles(context)
    }

    /** Shows a glass added here until the phone sends the new total. */
    fun addPendingWater(context: Context, ml: Long) {
        val p = prefs(context)
        p.edit().putLong(PENDING, p.getLong(PENDING, 0) + ml).apply()
        refreshTiles(context)
    }

    fun refreshTiles(context: Context) {
        TileService.getUpdater(context).requestUpdate(HeartPointsTileService::class.java)
        TileService.getUpdater(context).requestUpdate(WaterTileService::class.java)
    }
}
