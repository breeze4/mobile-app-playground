package com.playground.hello.data.mock

import com.playground.hello.data.model.Entity
import com.playground.hello.data.repository.AppRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlin.math.cos
import kotlin.random.Random

/**
 * Coroutine-based polling engine that simulates entity movement by periodically
 * updating entity positions in the repository. Must be started with a
 * [CoroutineScope] (typically viewModelScope) to ensure proper cancellation.
 */
class PollingEngine(
    private val repository: AppRepository,
    private val intervalMs: Long = 2_000L,
) {
    private var pollingJob: Job? = null

    /**
     * Start the polling loop in the given scope. The loop will cancel
     * automatically when the scope is cancelled (e.g., ViewModel cleared).
     * Calling start again while already running is a no-op.
     */
    fun start(scope: CoroutineScope) {
        if (pollingJob?.isActive == true) return
        pollingJob = scope.launch {
            while (isActive) {
                delay(intervalMs)
                simulateMovement()
            }
        }
    }

    fun stop() {
        pollingJob?.cancel()
        pollingJob = null
    }

    private fun simulateMovement() {
        val currentEntities = repository.entities.value
        for (entity in currentEntities) {
            if (entity.speed <= 0.0) continue // stationary entities don't move
            val updated = moveEntity(entity)
            repository.updateEntity(updated)
        }
    }

    companion object {
        // Rough meters-per-degree at Austin's latitude
        private const val METERS_PER_DEG_LAT = 111_320.0
        private const val AUSTIN_LAT_RAD = 0.5283 // ~30.27° in radians

        /**
         * Move an entity by a small random offset proportional to its speed.
         * Speed is treated as meters/second; each tick moves by speed * 2s worth
         * of distance with a random bearing.
         */
        fun moveEntity(entity: Entity): Entity {
            val metersPerDegLng = METERS_PER_DEG_LAT * cos(AUSTIN_LAT_RAD)
            val distanceMeters = entity.speed * 2.0 // 2-second tick
            val angle = Random.nextDouble(0.0, 2 * Math.PI)

            val dLat = (distanceMeters * cos(angle)) / METERS_PER_DEG_LAT
            val dLng = (distanceMeters * kotlin.math.sin(angle)) / metersPerDegLng

            return entity.copy(
                lat = entity.lat + dLat,
                lng = entity.lng + dLng,
            )
        }
    }
}
