package dev.sagron.zerotrustfitness.wear

import android.content.Context
import androidx.wear.protolayout.ActionBuilders
import androidx.wear.protolayout.ColorBuilders.argb
import androidx.wear.protolayout.DeviceParametersBuilders.DeviceParameters
import androidx.wear.protolayout.LayoutElementBuilders
import androidx.wear.protolayout.ModifiersBuilders
import androidx.wear.protolayout.ResourceBuilders
import androidx.wear.protolayout.TimelineBuilders
import androidx.wear.protolayout.material.CircularProgressIndicator
import androidx.wear.protolayout.material.CompactChip
import androidx.wear.protolayout.material.ProgressIndicatorColors
import androidx.wear.protolayout.material.Text
import androidx.wear.protolayout.material.Typography
import androidx.wear.protolayout.material.layouts.EdgeContentLayout
import androidx.wear.tiles.RequestBuilders
import androidx.wear.tiles.TileBuilders
import androidx.wear.tiles.TileService
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture

private const val RESOURCES_VERSION = "1"
private const val GREY = 0xFFBDBDBD.toInt()

/** Shared tile plumbing: one progress ring around a few lines of text. */
abstract class TodayTileService : TileService() {
    abstract fun layout(context: Context, today: Today, device: DeviceParameters): LayoutElementBuilders.LayoutElement

    override fun onTileRequest(
        requestParams: RequestBuilders.TileRequest,
    ): ListenableFuture<TileBuilders.Tile> {
        val today = TodayStore.read(this)
        val root = layout(this, today, requestParams.deviceConfiguration)
        val tile = TileBuilders.Tile.Builder()
            .setResourcesVersion(RESOURCES_VERSION)
            // The phone pushes changes; this only catches a new day.
            .setFreshnessIntervalMillis(30 * 60 * 1000L)
            .setTileTimeline(TimelineBuilders.Timeline.fromLayoutElement(root))
            .build()
        return Futures.immediateFuture(tile)
    }

    override fun onTileResourcesRequest(
        requestParams: RequestBuilders.ResourcesRequest,
    ): ListenableFuture<ResourceBuilders.Resources> =
        Futures.immediateFuture(
            ResourceBuilders.Resources.Builder().setVersion(RESOURCES_VERSION).build(),
        )

    protected fun text(context: Context, value: String, typography: Int, color: Int) =
        Text.Builder(context, value).setTypography(typography).setColor(argb(color)).build()

    protected fun ring(fraction: Float, color: Int) =
        CircularProgressIndicator.Builder()
            .setProgress(fraction)
            .setCircularProgressIndicatorColors(ProgressIndicatorColors(color, 0x33FFFFFF))
            .build()

    protected fun openApp(context: Context, id: String, activity: Class<*>) =
        ModifiersBuilders.Clickable.Builder()
            .setId(id)
            .setOnClick(
                ActionBuilders.LaunchAction.Builder()
                    .setAndroidActivity(
                        ActionBuilders.AndroidActivity.Builder()
                            .setPackageName(context.packageName)
                            .setClassName(activity.name)
                            .build(),
                    )
                    .build(),
            )
            .build()

    protected fun notConnected(context: Context, device: DeviceParameters) =
        EdgeContentLayout.Builder(device)
            .setEdgeContent(ring(0f, GREY))
            .setPrimaryLabelTextContent(text(context, "ZT Fitness", Typography.TYPOGRAPHY_CAPTION1, GREY))
            .setContent(
                text(context, context.getString(R.string.tile_turn_on), Typography.TYPOGRAPHY_BODY2, 0xFFFFFFFF.toInt()),
            )
            .build()
}

/** Today's Heart Points against the daily goal, with steps underneath. */
class HeartPointsTileService : TodayTileService() {
    override fun layout(context: Context, today: Today, device: DeviceParameters): LayoutElementBuilders.LayoutElement {
        if (!today.connected) return notConnected(context, device)
        val content = LayoutElementBuilders.Box.Builder()
            .setModifiers(
                ModifiersBuilders.Modifiers.Builder()
                    .setClickable(openApp(context, "open", TodayActivity::class.java))
                    .build(),
            )
            .addContent(
                text(context, "${today.heartPoints}", Typography.TYPOGRAPHY_DISPLAY2, TodayActivity.HEART),
            )
            .build()
        return EdgeContentLayout.Builder(device)
            .setEdgeContent(ring(today.fraction(today.heartPoints, today.heartPointsGoal), TodayActivity.HEART))
            .setPrimaryLabelTextContent(text(context, context.getString(R.string.tile_heart_pts), Typography.TYPOGRAPHY_CAPTION1, GREY))
            .setContent(content)
            .setSecondaryLabelTextContent(
                text(
                    context,
                    if (today.isCurrent) context.getString(R.string.steps_count, today.steps) else context.getString(R.string.tile_not_updated),
                    Typography.TYPOGRAPHY_CAPTION1,
                    0xFFFFFFFF.toInt(),
                ),
            )
            .build()
    }
}

/** Water against the daily goal and a one-tap glass. */
class WaterTileService : TodayTileService() {
    override fun layout(context: Context, today: Today, device: DeviceParameters): LayoutElementBuilders.LayoutElement {
        if (!today.connected) return notConnected(context, device)
        val add = CompactChip.Builder(
            context,
            today.glassLabel(),
            openApp(context, "add_water", AddWaterActivity::class.java),
            device,
        ).build()
        val content = LayoutElementBuilders.Column.Builder()
            .addContent(text(context, today.water(today.waterMl), Typography.TYPOGRAPHY_TITLE1, TodayActivity.WATER))
            .addContent(
                text(context, context.getString(R.string.of_amount, today.water(today.waterGoalMl)), Typography.TYPOGRAPHY_CAPTION1, GREY),
            )
            .build()
        return EdgeContentLayout.Builder(device)
            .setEdgeContent(ring(today.fraction(today.waterMl, today.waterGoalMl), TodayActivity.WATER))
            .setPrimaryLabelTextContent(text(context, context.getString(R.string.tile_water), Typography.TYPOGRAPHY_CAPTION1, GREY))
            .setContent(content)
            .setSecondaryLabelTextContent(add)
            .build()
    }
}
