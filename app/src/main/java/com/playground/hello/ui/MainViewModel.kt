package com.playground.hello.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import androidx.media3.common.MediaItem
import androidx.media3.exoplayer.ExoPlayer
import com.playground.hello.data.model.Entity
import com.playground.hello.data.model.Layer
import com.playground.hello.data.mock.MockDataGenerator
import com.playground.hello.data.mock.PollingEngine
import com.playground.hello.data.repository.AppRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.SharingStarted

data class MainUiState(
    val entities: List<Entity> = emptyList(),
    val layers: List<Layer> = emptyList(),
    val visibleEntities: List<Entity> = emptyList(),
    val filteredEntities: List<Entity> = emptyList(),
    val selectedEntity: Entity? = null,
    val searchQuery: String = "",
)

class MainViewModel(
    application: Application,
) : AndroidViewModel(application) {

    private val repository: AppRepository = AppRepository()
    private val pollingEngine = PollingEngine(repository)
    private val _selectedEntity = MutableStateFlow<Entity?>(null)
    private val _searchQuery = MutableStateFlow("")

    val player: ExoPlayer = ExoPlayer.Builder(application).build()

    init {
        MockDataGenerator.layers.forEach { repository.addLayer(it) }
        MockDataGenerator.initialEntities.forEach { repository.addEntity(it) }
        pollingEngine.start(viewModelScope)
    }

    val uiState: StateFlow<MainUiState> = combine(
        repository.entities,
        repository.layers,
        _selectedEntity,
        _searchQuery,
    ) { entities, layers, selected, query ->
        val visibleLayerIds = layers.filter { it.isVisible }.map { it.id }.toSet()
        val visibleEntities = entities.filter { it.layerId in visibleLayerIds }
        val filtered = if (query.isBlank()) {
            visibleEntities
        } else {
            val lowerQuery = query.lowercase()
            visibleEntities.filter {
                it.name.lowercase().contains(lowerQuery) ||
                    it.id.lowercase().contains(lowerQuery)
            }
        }
        // Clear selection if the selected entity's layer was hidden
        val effectiveSelected = selected?.takeIf { it.layerId in visibleLayerIds }
        if (selected != null && effectiveSelected == null) {
            _selectedEntity.value = null
            player.stop()
            player.clearMediaItems()
        }
        MainUiState(
            entities = entities,
            layers = layers,
            visibleEntities = visibleEntities,
            filteredEntities = filtered,
            selectedEntity = effectiveSelected,
            searchQuery = query,
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), MainUiState())

    fun selectEntity(entity: Entity) {
        if (_selectedEntity.value?.id == entity.id) return
        _selectedEntity.value = entity
        entity.videoUri?.let { uri ->
            player.setMediaItem(MediaItem.fromUri(uri))
            player.prepare()
            player.play()
        } ?: run {
            player.stop()
            player.clearMediaItems()
        }
    }

    fun clearSelection() {
        _selectedEntity.value = null
        player.stop()
        player.clearMediaItems()
    }

    fun addEntity(entity: Entity) = repository.addEntity(entity)

    fun removeEntity(id: String) = repository.removeEntity(id)

    fun updateEntity(entity: Entity) = repository.updateEntity(entity)

    fun addLayer(layer: Layer) = repository.addLayer(layer)

    fun removeLayer(id: String) = repository.removeLayer(id)

    fun setSearchQuery(query: String) {
        _searchQuery.value = query
    }

    fun toggleLayerVisibility(layerId: String) {
        val current = repository.layers.value.find { it.id == layerId } ?: return
        repository.setLayerVisibility(layerId, !current.isVisible)
    }

    override fun onCleared() {
        super.onCleared()
        pollingEngine.stop()
        player.release()
    }
}
