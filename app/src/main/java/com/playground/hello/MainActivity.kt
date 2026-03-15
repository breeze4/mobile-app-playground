package com.playground.hello

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.GoogleMap
import com.google.maps.android.compose.MapUiSettings
import com.google.maps.android.compose.rememberCameraPositionState
import com.playground.hello.ui.MainViewModel
import com.playground.hello.ui.VideoPlayerSheet
import com.playground.hello.ui.map.AnimatedEntityMarker

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
