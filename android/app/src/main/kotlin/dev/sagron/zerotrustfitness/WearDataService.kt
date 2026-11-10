package dev.sagron.zerotrustfitness

import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.Wearable
import com.google.android.gms.wearable.WearableListenerService

/**
 * Receives glasses of water added on the watch, even while the app is
 * closed. The vault is locked then, so they are kept until the app opens
 * (see WearBridge.takePendingWaterMl), and the watch's item is deleted.
 */
class WearDataService : WearableListenerService() {
    override fun onDataChanged(events: DataEventBuffer) {
        for (event in events) {
            if (event.type != DataEvent.TYPE_CHANGED) continue
            val item = event.dataItem
            if (item.uri.path?.startsWith(WearBridge.WATER_PATH_PREFIX) != true) continue
            val ml = DataMapItem.fromDataItem(item).dataMap.getInt("ml", 0)
            if (ml in 1..3000) WearBridge.addPendingWater(this, ml)
            Wearable.getDataClient(this).deleteDataItems(item.uri)
        }
    }
}
