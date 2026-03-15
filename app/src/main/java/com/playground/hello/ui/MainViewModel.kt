package com.playground.hello.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.playground.hello.data.model.Entity
import com.playground.hello.data.model.Layer
import com.playground.hello.data.repository.AppRepository
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.SharingStarted

data class MainUiState(
    val entities: List<Entity> = emptyList(),
    val layers: List<Layer> = emptyList(),
    val visibleEntities: List<Entity> = emptyList(),
)

class MainViewModel(
    private val repository: AppRepository = AppRepository(),
) : ViewModel() {

    val uiState: StateFlow<MainUiState> = combine(
        repository.entities,
        repository.layers,
    ) { entities, layers ->
        val visibleLayerIds = layers.filter { it.isVisible }.map { it.id }.toSet()
        MainUiState(
            entities = entities,
            layers = layers,
            visibleEntities = entities.filter { it.layerId in visibleLayerIds },
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), MainUiState())

    fun addEntity(entity: Entity) = repository.addEntity(entity)

    fun removeEntity(id: String) = repository.removeEntity(id)

    fun updateEntity(entity: Entity) = repository.updateEntity(entity)

    fun addLayer(layer: Layer) = repository.addLayer(layer)

    fun removeLayer(id: String) = repository.removeLayer(id)

    fun toggleLayerVisibility(layerId: String) {
        val current = uiState.value.layers.find { it.id == layerId } ?: return
        repository.setLayerVisibility(layerId, !current.isVisible)
    }
}
