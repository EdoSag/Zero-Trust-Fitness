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
                    setTextViewText(R.id.widget_hint, "Unlock in app to reveal your latest stats.")
                    setInt(R.id.widget_status, "setTextColor", Color.parseColor("#F8FAFC"))
                    setInt(R.id.widget_hint, "setTextColor", Color.parseColor("#CBD5E1"))
                } else {
                    val steps = widgetData.getInt("steps", 0)
                    val points = widgetData.getInt("heartPoints", 0)

                    setTextViewText(R.id.widget_steps, steps.toString())
                    setTextViewText(R.id.widget_points, points.toString())
                    setTextViewText(R.id.widget_status, "Securely Synced")
                    setTextViewText(R.id.widget_hint, "Encrypted sync is active.")
                    setInt(R.id.widget_status, "setTextColor", Color.parseColor("#D1FAE5"))
                    setInt(R.id.widget_hint, "setTextColor", Color.parseColor("#E2E8F0"))
                }
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
