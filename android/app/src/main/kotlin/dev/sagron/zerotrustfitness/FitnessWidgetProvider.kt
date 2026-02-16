package dev.sagron.zerotrustfitness

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class FitnessWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.fitness_widget_layout).apply {
                
                // Check the Zero-Trust Lock State
                val isLocked = widgetData.getBoolean("isLocked", true)
                
                if (isLocked) {
                    setTextViewText(R.id.widget_steps, "---")
                    setTextViewText(R.id.widget_points, "---")
                    setTextViewText(R.id.widget_status, "Vault Locked 🔒")
                } else {
                    val steps = widgetData.getInt("steps", 0)
                    val points = widgetData.getInt("heartPoints", 0)
                    
                    setTextViewText(R.id.widget_steps, steps.toString())
                    setTextViewText(R.id.widget_points, points.toString())
                    setTextViewText(R.id.widget_status, "Securely Synced")
                }
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}