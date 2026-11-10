package dev.sagron.zerotrustfitness.wear

import android.app.Activity
import android.content.SharedPreferences
import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.ScrollView
import android.widget.TextView

/** The watch app: today's numbers and a button for a glass of water. */
class TodayActivity : Activity() {
    private lateinit var heartPoints: TextView
    private lateinit var heartBar: ProgressBar
    private lateinit var steps: TextView
    private lateinit var water: TextView
    private lateinit var waterBar: ProgressBar
    private lateinit var addWater: Button
    private lateinit var status: TextView

    private val listener = SharedPreferences.OnSharedPreferenceChangeListener { _, _ ->
        runOnUiThread { render() }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val pad = (resources.displayMetrics.widthPixels * 0.12).toInt()
        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(pad, pad / 2, pad, pad)
        }
        fun text(size: Float, color: Int = Color.WHITE) = TextView(this).apply {
            textSize = size
            setTextColor(color)
            gravity = Gravity.CENTER
        }
        fun bar(color: Int) = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            max = 100
            progressTintList = android.content.res.ColorStateList.valueOf(color)
        }
        heartPoints = text(28f, HEART)
        heartBar = bar(HEART)
        steps = text(16f)
        water = text(18f, WATER)
        waterBar = bar(WATER)
        addWater = Button(this).apply {
            setOnClickListener {
                val today = TodayStore.read(this@TodayActivity)
                if (today.connected) AddWaterActivity.addGlass(this@TodayActivity, today.glassMl)
                render()
            }
        }
        status = text(12f, Color.LTGRAY)
        listOf(heartPoints, heartBar, steps, water, waterBar, addWater, status).forEach(column::addView)
        setContentView(ScrollView(this).apply { addView(column) })
    }

    override fun onResume() {
        super.onResume()
        getSharedPreferences("zt_today", MODE_PRIVATE).registerOnSharedPreferenceChangeListener(listener)
        render()
    }

    override fun onPause() {
        getSharedPreferences("zt_today", MODE_PRIVATE).unregisterOnSharedPreferenceChangeListener(listener)
        super.onPause()
    }

    private fun render() {
        val t = TodayStore.read(this)
        heartPoints.text = "${t.heartPoints} Heart Pts"
        heartBar.progress = (t.fraction(t.heartPoints, t.heartPointsGoal) * 100).toInt()
        steps.text = "%,d steps".format(t.steps)
        water.text = "${t.water(t.waterMl)} of ${t.water(t.waterGoalMl)}"
        waterBar.progress = (t.fraction(t.waterMl, t.waterGoalMl) * 100).toInt()
        addWater.text = t.glassLabel() + " water"
        addWater.isEnabled = t.connected
        status.text = when {
            !t.connected -> getString(R.string.not_connected)
            !t.isCurrent -> getString(R.string.stale)
            else -> ""
        }
    }

    companion object {
        val HEART = Color.parseColor("#22C55E")
        val WATER = Color.parseColor("#0EA5E9")
    }
}
