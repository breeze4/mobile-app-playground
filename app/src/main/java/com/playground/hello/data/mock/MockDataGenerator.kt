package com.playground.hello.data.mock

import com.playground.hello.data.model.Entity
import com.playground.hello.data.model.Layer

object MockDataGenerator {

    val layers: List<Layer> = listOf(
        Layer(id = "layer-drones", name = "Drones"),
        Layer(id = "layer-cameras", name = "Cameras"),
        Layer(id = "layer-vehicles", name = "Vehicles"),
    )

    val initialEntities: List<Entity> = listOf(
        // Drones — airborne units near downtown Austin
        Entity(
            id = "drone-1",
            name = "Falcon Alpha",
            lat = 30.2672,
            lng = -97.7431,
            speed = 12.0,
            layerId = "layer-drones",
        ),
        Entity(
            id = "drone-2",
            name = "Falcon Bravo",
            lat = 30.2750,
            lng = -97.7500,
            speed = 8.5,
            layerId = "layer-drones",
        ),
        // Cameras — fixed positions
        Entity(
            id = "cam-1",
            name = "Congress Bridge Cam",
            lat = 30.2614,
            lng = -97.7448,
            speed = 0.0,
            layerId = "layer-cameras",
            videoUri = "https://example.com/streams/congress-bridge",
        ),
        Entity(
            id = "cam-2",
            name = "Capitol Cam",
            lat = 30.2747,
            lng = -97.7404,
            speed = 0.0,
            layerId = "layer-cameras",
            videoUri = "https://example.com/streams/capitol",
        ),
        // Vehicles — patrol routes
        Entity(
            id = "vehicle-1",
            name = "Unit 7",
            lat = 30.2500,
            lng = -97.7500,
            speed = 5.0,
            layerId = "layer-vehicles",
        ),
        Entity(
            id = "vehicle-2",
            name = "Unit 12",
            lat = 30.2800,
            lng = -97.7350,
            speed = 6.5,
            layerId = "layer-vehicles",
        ),
    )
}
