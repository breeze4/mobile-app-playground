package com.playground.hello.data.repository

import com.playground.hello.data.model.Entity
import com.playground.hello.data.model.Layer
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

class AppRepository {

    private val _entities = MutableStateFlow<List<Entity>>(emptyList())
    val entities: StateFlow<List<Entity>> = _entities.asStateFlow()

    private val _layers = MutableStateFlow<List<Layer>>(emptyList())
    val layers: StateFlow<List<Layer>> = _layers.asStateFlow()

    fun addEntity(entity: Entity) {
        _entities.update { it + entity }
    }

    fun removeEntity(id: String) {
        _entities.update { list -> list.filter { it.id != id } }
    }

    fun updateEntity(entity: Entity) {
        _entities.update { list -> list.map { if (it.id == entity.id) entity else it } }
    }

    fun addLayer(layer: Layer) {
        _layers.update { it + layer }
    }

    fun removeLayer(id: String) {
        _layers.update { list -> list.filter { it.id != id } }
    }

    fun setLayerVisibility(layerId: String, visible: Boolean) {
        _layers.update { list ->
            list.map { if (it.id == layerId) it.copy(isVisible = visible) else it }
        }
    }
}
