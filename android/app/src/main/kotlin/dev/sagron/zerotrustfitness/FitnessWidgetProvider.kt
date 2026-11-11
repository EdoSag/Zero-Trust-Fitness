package dev.sagron.zerotrustfitness

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.NumberFormat

/**
 * Today's Heart Points and steps as two rings (Heart Points outside, steps
 * inside), like the Today screen. The widget is resizable from 1x1 to any
 * size and picks one of four layouts for the space it has:
 *
 * - small: rings only, Heart Points in the middle (1x1)
 * - row: small rings next to both numbers (one row tall, 2x1 and wider)
 * - medium: big rings with Heart Points inside and steps below (about 2x2)
 * - large: header, rings, both numbers with their goals and Momentum (3x2+)
 *
 * While the vault is locked the app writes zeros and isLocked = true, so the
 * widget shows empty rings and a lock and never any numbers.
 * Tapping anywhere opens the app.
 */
class FitnessWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(
                id,
                build(context, widgetData, appWidgetManager.getAppWidgetOptions(id)),
            )
        }
    }

    /** Resizing changes the layout, so draw again for the new size. */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        val prefs = context.getSharedPreferences(HOME_WIDGET_PREFS, Context.MODE_PRIVATE)
        appWidgetManager.updateAppWidget(appWidgetId, build(context, prefs, newOptions))
    }

    private fun build(context: Context, data: SharedPreferences, options: Bundle?): RemoteViews {
        // Portrait size: the launcher's narrowest width and tallest height.
        val widthDp = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0) ?: 0
        val heightDp = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0) ?: 0
        val size = WidgetSize.of(widthDp, heightDp)
        val views = RemoteViews(context.packageName, size.layout)

        val locked = data.getBoolean("isLocked", true)
        val steps = data.int("steps")
        val points = data.int("heartPoints")
        val pointsGoal = data.int("heartTarget").takeIf { it > 0 } ?: DEFAULT_POINTS_GOAL
        val stepsGoal = data.int("stepsGoal").takeIf { it > 0 } ?: DEFAULT_STEPS_GOAL
        val momentum = data.int("momentum")
        val momentumLabel = data.getString("momentumLabel", "") ?: ""

        val heartColor = context.getColor(R.color.widget_heart)
        val stepsColor = context.getColor(R.color.widget_steps)
        val ring = if (locked) {
            val track = context.getColor(R.color.widget_locked_track)
            drawRings(0f, 0f, track, track, locked = true)
        } else {
            drawRings(
                points.toFloat() / pointsGoal,
                steps.toFloat() / stepsGoal,
                heartColor,
                stepsColor,
                locked = false,
            )
        }
        views.setImageViewBitmap(R.id.widget_ring, ring)

        val fmt = NumberFormat.getIntegerInstance()
        // Texts in the language picked in the app (see WidgetText).
        fun t(key: String, res: Int) = WidgetText.get(context, data, key, res)
        val shown = if (locked) View.GONE else View.VISIBLE
        val hidden = if (locked) View.VISIBLE else View.GONE

        // Lock in the middle of the rings replaces the numbers.
        views.setViewVisibility(R.id.widget_ring_lock, hidden)
        if (size.hasRingValue) {
            views.setViewVisibility(R.id.widget_ring_value, shown)
            views.setTextViewText(R.id.widget_ring_value, fmt.format(points))
        }
        if (size == WidgetSize.MEDIUM) {
            views.setViewVisibility(R.id.widget_ring_caption, shown)
            views.setTextViewText(R.id.widget_ring_caption, t("heart_points", R.string.widget_heart_points))
            views.setTextViewText(R.id.widget_locked_msg, t("locked_short", R.string.widget_locked_short))
        }
        if (size == WidgetSize.ROW || size == WidgetSize.LARGE) {
            views.setTextViewText(R.id.widget_locked_msg, t("locked", R.string.widget_locked))
        }
        if (size == WidgetSize.LARGE) {
            views.setTextViewText(R.id.widget_today, t("today", R.string.widget_today))
        }
        if (size != WidgetSize.SMALL) {
            views.setViewVisibility(R.id.widget_stats, shown)
            views.setViewVisibility(R.id.widget_locked_msg, hidden)
            views.setTextViewText(R.id.widget_steps_value, fmt.format(steps))
        }
        if (size == WidgetSize.ROW || size == WidgetSize.LARGE) {
            views.setTextViewText(R.id.widget_hp_value, fmt.format(points))
            views.setTextViewText(R.id.widget_hp_goal, t("hp_goal", R.string.widget_hp_goal).format(fmt.format(pointsGoal)))
            views.setTextViewText(R.id.widget_steps_goal, t("steps_goal", R.string.widget_steps_goal).format(fmt.format(stepsGoal)))
        }
        if (size == WidgetSize.ROW) {
            // 2x1 has room for one number: Heart Points, which the rings lead with.
            views.setViewVisibility(
                R.id.widget_steps_block,
                if (widthDp in 1 until ROW_BOTH_MIN_DP) View.GONE else View.VISIBLE,
            )
        }
        if (size == WidgetSize.LARGE) {
            val showMomentum = !locked && momentum > 0
            views.setViewVisibility(
                R.id.widget_momentum_row,
                if (showMomentum) View.VISIBLE else View.GONE,
            )
            val base = t("momentum", R.string.widget_momentum).format(fmt.format(momentum))
            val text = if (momentumLabel.isBlank()) base else "$base · $momentumLabel"
            views.setTextViewText(R.id.widget_momentum, text)
        }

        views.setContentDescription(
            android.R.id.background,
            if (locked) {
                t("locked", R.string.widget_locked)
            } else {
                t("summary", R.string.widget_summary).format(
                    fmt.format(points),
                    fmt.format(pointsGoal),
                    fmt.format(steps),
                    fmt.format(stepsGoal),
                )
            },
        )
        views.setOnClickPendingIntent(android.R.id.background, openApp(context))
        return views
    }

    private fun openApp(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java)
            .setAction(Intent.ACTION_MAIN)
            .addCategory(Intent.CATEGORY_LAUNCHER)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
        return PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    companion object {
        /** The SharedPreferences file home_widget writes to. */
        private const val HOME_WIDGET_PREFS = "HomeWidgetPreferences"
        private const val DEFAULT_POINTS_GOAL = 21 // 150 a week, as on the watch
        private const val DEFAULT_STEPS_GOAL = 10_000

        /** Narrower one-row widgets show Heart Points only. */
        private const val ROW_BOTH_MIN_DP = 230

        /** Bitmap side in pixels; ImageView scales it to fit. */
        private const val RING_PX = 288

        private fun SharedPreferences.int(key: String): Int = when (val v = all[key]) {
            is Int -> v
            is Long -> v.toInt()
            is Float -> v.toInt()
            else -> 0
        }

        /**
         * Heart Points ring outside, steps ring inside, each on a faint track
         * of its own colour, starting at 12 o'clock with round ends. Past the
         * goal a ring stays full.
         */
        internal fun drawRings(
            outer: Float,
            inner: Float,
            outerColor: Int,
            innerColor: Int,
            locked: Boolean,
        ): Bitmap {
            val bmp = Bitmap.createBitmap(RING_PX, RING_PX, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            val stroke = RING_PX * 0.09f
            val gap = RING_PX * 0.03f
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = stroke
                strokeCap = Paint.Cap.ROUND
            }
            fun ring(inset: Float, fraction: Float, color: Int) {
                val box = RectF(inset, inset, RING_PX - inset, RING_PX - inset)
                paint.color = if (locked) color else (color and 0x00FFFFFF) or 0x33000000
                canvas.drawArc(box, 0f, 360f, false, paint)
                val f = fraction.coerceIn(0f, 1f)
                if (!locked && f > 0f) {
                    paint.color = color
                    // A tiny value still shows as a dot, like Google Fit.
                    canvas.drawArc(box, -90f, maxOf(f * 360f, 1f), false, paint)
                }
            }
            ring(stroke / 2, outer, outerColor)
            ring(stroke * 1.5f + gap, inner, innerColor)
            return bmp
        }
    }
}

/** Which layout fits the widget's size on the home screen (sizes in dp). */
internal enum class WidgetSize(val layout: Int, val hasRingValue: Boolean) {
    SMALL(R.layout.fitness_widget_small, true),
    ROW(R.layout.fitness_widget_row, false),
    MEDIUM(R.layout.fitness_widget_medium, true),
    LARGE(R.layout.fitness_widget_large, false);

    companion object {
        fun of(widthDp: Int, heightDp: Int): WidgetSize = when {
            // Older launchers that don't report a size: the default 2x2.
            widthDp <= 0 || heightDp <= 0 -> MEDIUM
            heightDp < 100 -> if (widthDp >= 150) ROW else SMALL
            widthDp < 100 -> SMALL
            widthDp >= 220 && heightDp >= 120 -> LARGE
            else -> MEDIUM
        }
    }
}
