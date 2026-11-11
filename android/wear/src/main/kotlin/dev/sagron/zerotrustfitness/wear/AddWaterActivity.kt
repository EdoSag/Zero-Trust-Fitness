package dev.sagron.zerotrustfitness.wear

import android.app.Activity
import android.content.Context
import android.os.Bundle
import android.widget.Toast
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import java.util.UUID

/**
 * Adds one glass of water (the tile's button). The glass goes to the phone
 * as a Data Layer item, which is delivered when the phone is next in reach;
 * the phone app adds it to today the next time it is unlocked.
 */
class AddWaterActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val today = TodayStore.read(this)
        if (today.connected) {
            addGlass(this, today.glassMl)
            Toast.makeText(this, getString(R.string.add_water_amount, today.glassLabel()), Toast.LENGTH_SHORT).show()
        } else {
            Toast.makeText(this, R.string.not_connected, Toast.LENGTH_LONG).show()
        }
        finish()
    }

    companion object {
        fun addGlass(context: Context, ml: Long) {
            val request = PutDataMapRequest.create("/zt/add_water/" + UUID.randomUUID()).apply {
                dataMap.putInt("ml", ml.toInt())
                dataMap.putLong("at", System.currentTimeMillis())
            }.asPutDataRequest().setUrgent()
            Wearable.getDataClient(context).putDataItem(request)
            TodayStore.addPendingWater(context, ml)
        }
    }
}
