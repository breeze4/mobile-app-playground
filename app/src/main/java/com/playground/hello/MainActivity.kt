package com.playground.hello

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.GoogleMap
import com.google.maps.android.compose.MapUiSettings
import com.google.maps.android.compose.rememberCameraPositionState
import com.playground.hello.ui.EntityListSheet
import com.playground.hello.ui.LayerFilterOverlay
import com.playground.hello.ui.MainViewModel
import com.playground.hello.ui.VideoPlayerSheet
import com.playground.hello.ui.map.AnimatedEntityMarker
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            val viewModel: MainViewModel = viewModel()
            val uiState by viewModel.uiState.collectAsState()

            MaterialTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    val defaultPosition = LatLng(30.2672, -97.7431) // Austin, TX
                    val cameraPositionState = rememberCameraPositionState {
                        position = CameraPosition.fromLatLngZoom(defaultPosition, 12f)
                    }
                    val coroutineScope = rememberCoroutineScope()
                    var showEntityList by remember { mutableStateOf(false) }

                    Box(modifier = Modifier.fillMaxSize()) {
                        GoogleMap(
                            modifier = Modifier.fillMaxSize(),
                            cameraPositionState = cameraPositionState,
                            uiSettings = MapUiSettings(
                                zoomControlsEnabled = true,
                                compassEnabled = true,
                            ),
                        ) {
                            uiState.visibleEntities.forEach { entity ->
                                AnimatedEntityMarker(
                                    entity = entity,
                                    onMarkerClick = { viewModel.selectEntity(it) },
                                )
                            }
                        }

                        LayerFilterOverlay(
                            layers = uiState.layers,
                            onToggleLayer = { viewModel.toggleLayerVisibility(it) },
                        )

                        FloatingActionButton(
                            onClick = { showEntityList = true },
                            modifier = Modifier
                                .align(Alignment.BottomStart)
                                .padding(16.dp),
                        ) {
                            Icon(Icons.AutoMirrored.Filled.List, contentDescription = "Entity list")
                        }
                    }

                    if (showEntityList) {
                        EntityListSheet(
                            entities = uiState.filteredEntities,
                            searchQuery = uiState.searchQuery,
                            onSearchQueryChange = { viewModel.setSearchQuery(it) },
                            onEntityTap = { entity ->
                                showEntityList = false
                                viewModel.setSearchQuery("")
                                coroutineScope.launch {
                                    cameraPositionState.animate(
                                        CameraUpdateFactory.newLatLngZoom(
                                            LatLng(entity.lat, entity.lng),
                                            15f,
                                        ),
                                    )
                                }
                            },
                            onDismiss = {
                                showEntityList = false
                                viewModel.setSearchQuery("")
                            },
                        )
                    }

                    uiState.selectedEntity?.let { entity ->
                        VideoPlayerSheet(
                            entity = entity,
                            player = viewModel.player,
                            onDismiss = { viewModel.clearSelection() },
                        )
                    }
                }
            }
        }
    }
}
