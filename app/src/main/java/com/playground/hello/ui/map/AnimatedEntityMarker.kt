package com.playground.hello.ui.map

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import com.google.android.gms.maps.model.BitmapDescriptorFactory
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.Marker
import com.google.maps.android.compose.rememberMarkerState
import com.playground.hello.data.model.Entity

/**
 * Marker hue by layer type. Drones are blue, cameras are red, vehicles are green.
 */
private fun markerHueForLayer(layerId: String): Float = when (layerId) {
    "layer-drones" -> BitmapDescriptorFactory.HUE_AZURE
    "layer-cameras" -> BitmapDescriptorFactory.HUE_RED
    "layer-vehicles" -> BitmapDescriptorFactory.HUE_GREEN
    else -> BitmapDescriptorFactory.HUE_YELLOW
}

/**
 * A map marker for an [Entity] that smoothly interpolates position changes
 * instead of teleporting. Uses a linear animation over 1.8 seconds (just under
 * the 2-second polling interval) so movement appears continuous.
 */
@Composable
fun AnimatedEntityMarker(entity: Entity) {
    val markerState = rememberMarkerState(
        key = entity.id,
        position = LatLng(entity.lat, entity.lng),
    )

    // Animate to new position whenever the entity's coordinates change
    LaunchedEffect(entity.id, entity.lat, entity.lng) {
        val start = markerState.position
        val targetLat = entity.lat
        val targetLng = entity.lng

        // Skip animation if this is the initial placement (no movement yet)
        if (start.latitude == targetLat && start.longitude == targetLng) return@LaunchedEffect

        val animatable = Animatable(0f)
        animatable.animateTo(
            targetValue = 1f,
            animationSpec = tween(durationMillis = 1800),
        ) {
            val lat = start.latitude + (targetLat - start.latitude) * value
            val lng = start.longitude + (targetLng - start.longitude) * value
            markerState.position = LatLng(lat, lng)
        }
    }

    val icon = remember(entity.layerId) {
        BitmapDescriptorFactory.defaultMarker(markerHueForLayer(entity.layerId))
    }

    Marker(
        state = markerState,
        title = entity.name,
        snippet = entity.id,
        icon = icon,
    )
}
