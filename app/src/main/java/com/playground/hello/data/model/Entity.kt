package com.playground.hello.data.model

data class Entity(
    val id: String,
    val name: String,
    val lat: Double,
    val lng: Double,
    val speed: Double,
    val layerId: String,
    val videoUri: String? = null,
)
