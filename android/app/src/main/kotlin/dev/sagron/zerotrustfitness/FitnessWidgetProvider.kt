package dev.sagron.zerotrustfitness

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class FitnessWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.fitness_widget_layout).apply {

                val isLocked = widgetData.getBoolean("isLocked", true)

                if (isLocked) {
                    setTextViewText(R.id.widget_steps, "---")
                    setTextViewText(R.id.widget_points, "---")
                    setTextViewText(R.id.widget_status, "Vault Locked")
                    setTextViewText(R.id.widget_momentum, "---")
                    setTextViewText(R.id.widget_momentum_label, "")
                    setTextViewText(R.id.widget_target, "Unlock to view")
                    setProgressBar(R.id.widget_target_progress, 100, 0, false)
                    setInt(R.id.widget_status, "setTextColor", Color.parseColor("#F8FAFC"))
                } else {
                    val steps = widgetData.getInt("steps", 0)
                    val points = widgetData.getInt("heartPoints", 0)
                    val momentum = widgetData.getInt("momentum", 0)
                    val momentumLabel = widgetData.getString("momentumLabel", "") ?: ""
                    val target = widgetData.getInt("heartTarget", 0)

                    setTextViewText(R.id.widget_steps, steps.toString())
                    setTextViewText(R.id.widget_points, points.toString())
                    setTextViewText(R.id.widget_status, "Securely Synced")
                    setTextViewText(R.id.widget_momentum, momentum.toString())
                    setTextViewText(R.id.widget_momentum_label, momentumLabel)
                    if (target > 0) {
                        setTextViewText(R.id.widget_target, "$points / $target pts")
                        val progress = (points * 100 / target).coerceIn(0, 100)
                        setProgressBar(R.id.widget_target_progress, 100, progress, false)
                    } else {
                        setTextViewText(R.id.widget_target, "")
                        setProgressBar(R.id.widget_target_progress, 100, 0, false)
                    }
                    setInt(R.id.widget_status, "setTextColor", Color.parseColor("#D1FAE5"))
                }
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
