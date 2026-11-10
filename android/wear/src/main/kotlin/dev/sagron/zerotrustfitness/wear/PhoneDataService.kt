package dev.sagron.zerotrustfitness.wear

import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.WearableListenerService

/** Receives today's numbers from the phone, even while the app is closed. */
class PhoneDataService : WearableListenerService() {
    override fun onDataChanged(events: DataEventBuffer) {
        for (event in events) {
            if (event.type != DataEvent.TYPE_CHANGED) continue
            if (event.dataItem.uri.path != TODAY_PATH) continue
            TodayStore.save(this, DataMapItem.fromDataItem(event.dataItem).dataMap)
        }
    }

    companion object {
        const val TODAY_PATH = "/zt/today"
    }
}
