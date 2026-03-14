# Mobile App Playground

Android app development workspace using a WSL2 + Windows split architecture. The primary project is a **Live Map Tracker** — a real-time map application that renders moving entities with smooth interpolation, layer filtering, and video overlays.

## Architecture

- **WSL2**: Source code, build tools (JDK 17, Gradle, Node.js)
- **Windows**: Android SDK, Android Studio, emulator, ADB server
- **Bridge**: Wrapper scripts so WSL2 CLI tools transparently call Windows-side SDK binaries

## Live Map Tracker MVP

A Kotlin/Compose Android app built on MVVM with centralized state management.

### Features

- **Core MVVM Architecture** — Central `Repository` exposing state via `StateFlow`/`SharedFlow`, with `Entity` and `Layer` data models as the single source of truth
- **Mock Backend & Polling** — Coroutine-based polling engine that simulates entity movement, with configurable intervals and proper lifecycle scoping
- **Map Integration** — Google Maps Compose surface with standard zoom/compass controls
- **Live Marker Rendering** — Custom markers for entity types (drones, cameras) with coordinate interpolation for smooth movement (no teleporting)
- **Layer Filtering** — Floating overlay to toggle entity visibility by layer, with immediate map and list updates
- **Entity List & Search** — `LazyColumn` with real-time text search by name/ID; tapping an entity pans the map to its location
- **Video Player Overlay** — Media3 (ExoPlayer) in a modal bottom sheet with a single shared player instance to prevent OOM errors
- **Integration Testing** — Edge case coverage for state desyncs, configuration changes, resource exhaustion, and lifecycle events

## Dev Environment Setup

1. Install JDK 17 in WSL2
2. Install Android Studio on Windows
3. Install Android SDK components (API 34+, build tools, emulator, system image)
4. Configure `ANDROID_HOME` and wrapper scripts in WSL2
5. Enable WSL2 mirrored networking for localhost connectivity
6. Verify end-to-end: build in WSL2, deploy to Windows emulator
