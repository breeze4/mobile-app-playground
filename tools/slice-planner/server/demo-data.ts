import db from './db.js';

// Generates a rich, realistic demo dataset for the Slice Planner UI.
// Does NOT depend on seeding a real project — creates everything from scratch.

// Clear all data
db.exec('DELETE FROM file_slice_assignments');
db.exec('DELETE FROM files');
db.exec('DELETE FROM packages');
db.exec('DELETE FROM slices');

const insertPkg = db.prepare('INSERT INTO packages (path, name) VALUES (?, ?)');
const insertFile = db.prepare('INSERT INTO files (path, package_id) VALUES (?, ?)');
const insertSlice = db.prepare('INSERT INTO slices (name, type, description) VALUES (?, ?, ?)');
const insertAssign = db.prepare(
  'INSERT INTO file_slice_assignments (file_id, slice_id, confidence, status) VALUES (?, ?, ?, ?)'
);

const transaction = db.transaction(() => {
  // ── Packages & Files ──────────────────────────────────────────────

  const packages: { name: string; path: string; files: string[] }[] = [
    {
      name: 'app',
      path: 'app/src/main/java/com/example/app',
      files: ['Application.kt', 'MainActivity.kt', 'AppModule.kt', 'DeepLinkHandler.kt'],
    },
    {
      name: 'auth',
      path: 'app/src/main/java/com/example/auth',
      files: ['LoginActivity.kt', 'LoginViewModel.kt', 'AuthRepository.kt', 'TokenManager.kt', 'SessionInterceptor.kt', 'BiometricHelper.kt'],
    },
    {
      name: 'camera',
      path: 'app/src/main/java/com/example/camera',
      files: ['CameraListFragment.kt', 'CameraListViewModel.kt', 'CameraAdapter.kt', 'CameraDetailFragment.kt', 'CameraDetailViewModel.kt', 'CameraRepository.kt', 'LiveStreamPlayer.kt', 'PTZControlView.kt'],
    },
    {
      name: 'map',
      path: 'app/src/main/java/com/example/map',
      files: ['MapFragment.kt', 'MapViewModel.kt', 'MarkerRenderer.kt', 'MarkerInterpolator.kt', 'ClusterManager.kt', 'GeoFenceManager.kt', 'MapStyleManager.kt'],
    },
    {
      name: 'incidents',
      path: 'app/src/main/java/com/example/incidents',
      files: ['IncidentListFragment.kt', 'IncidentListViewModel.kt', 'IncidentDetailFragment.kt', 'IncidentDetailViewModel.kt', 'IncidentRepository.kt', 'IncidentFilterDialog.kt'],
    },
    {
      name: 'tracking',
      path: 'app/src/main/java/com/example/tracking',
      files: ['TrackingService.kt', 'LocationProvider.kt', 'TrackingViewModel.kt', 'TrackingOverlay.kt', 'RouteRenderer.kt'],
    },
    {
      name: 'settings',
      path: 'app/src/main/java/com/example/settings',
      files: ['SettingsFragment.kt', 'SettingsViewModel.kt', 'NotificationPrefs.kt', 'ThemeManager.kt'],
    },
    {
      name: 'network',
      path: 'app/src/main/java/com/example/network',
      files: ['ApiClient.kt', 'ApiService.kt', 'AuthInterceptor.kt', 'RetryInterceptor.kt', 'WebSocketManager.kt', 'NetworkMonitor.kt'],
    },
    {
      name: 'database',
      path: 'app/src/main/java/com/example/database',
      files: ['AppDatabase.kt', 'CameraDao.kt', 'IncidentDao.kt', 'UserDao.kt', 'Migrations.kt'],
    },
    {
      name: 'ui-common',
      path: 'app/src/main/java/com/example/ui',
      files: ['Theme.kt', 'Colors.kt', 'Typography.kt', 'LoadingIndicator.kt', 'ErrorView.kt', 'SearchBar.kt', 'FilterChip.kt', 'EmptyState.kt'],
    },
    {
      name: 'analytics',
      path: 'app/src/main/java/com/example/analytics',
      files: ['AnalyticsTracker.kt', 'EventLogger.kt', 'CrashReporter.kt', 'PerformanceMonitor.kt'],
    },
    {
      name: 'notifications',
      path: 'app/src/main/java/com/example/notifications',
      files: ['PushService.kt', 'NotificationBuilder.kt', 'NotificationChannels.kt'],
    },
    {
      name: 'resources',
      path: 'app/src/main/res',
      files: ['values/strings.xml', 'values/colors.xml', 'values/themes.xml', 'layout/activity_main.xml', 'drawable/ic_launcher.xml', 'navigation/nav_graph.xml'],
    },
    {
      name: 'gradle-config',
      path: 'gradle',
      files: ['wrapper/gradle-wrapper.properties', 'libs.versions.toml'],
    },
    {
      name: 'root-config',
      path: '.',
      files: ['build.gradle.kts', 'settings.gradle.kts', 'gradle.properties', 'app/build.gradle.kts'],
    },
  ];

  const pkgIds: Record<string, number> = {};
  const fileIds: Record<string, number> = {};

  for (const pkg of packages) {
    const result = insertPkg.run(pkg.path, pkg.name);
    const pkgId = Number(result.lastInsertRowid);
    pkgIds[pkg.name] = pkgId;
    for (const f of pkg.files) {
      const filePath = pkg.path === '.' ? f : `${pkg.path}/${f}`;
      const r = insertFile.run(filePath, pkgId);
      fileIds[filePath] = Number(r.lastInsertRowid);
    }
  }

  // ── Slices ────────────────────────────────────────────────────────

  const sliceDefs = [
    // Vertical
    { name: 'authentication', type: 'vertical', description: 'User login, biometrics, session management, token lifecycle' },
    { name: 'camera-list', type: 'vertical', description: 'Camera directory with filtering, search, and thumbnail grid' },
    { name: 'camera-detail', type: 'vertical', description: 'Individual camera view with live stream and PTZ controls' },
    { name: 'map-view', type: 'vertical', description: 'Interactive map with camera markers, clusters, and geofences' },
    { name: 'incident-management', type: 'vertical', description: 'Incident creation, listing, filtering, and detail views' },
    { name: 'real-time-tracking', type: 'vertical', description: 'Live location tracking, route rendering, and tracking overlay' },
    { name: 'settings-prefs', type: 'vertical', description: 'User settings, notification preferences, and theme selection' },
    { name: 'push-notifications', type: 'vertical', description: 'Push notification handling, channels, and display' },
    // Horizontal
    { name: 'networking', type: 'horizontal', description: 'HTTP client, interceptors, WebSocket, and network monitoring' },
    { name: 'local-database', type: 'horizontal', description: 'Room database, DAOs, migrations, and offline caching' },
    { name: 'ui-design-system', type: 'horizontal', description: 'Shared theme, typography, colors, and reusable components' },
    { name: 'analytics-observability', type: 'horizontal', description: 'Event tracking, crash reporting, and performance monitoring' },
    { name: 'app-lifecycle', type: 'horizontal', description: 'Application startup, deep linking, and dependency injection' },
    { name: 'build-configuration', type: 'horizontal', description: 'Gradle config, dependency versions, and build variants' },
  ];

  const sliceIds: Record<string, number> = {};
  for (const s of sliceDefs) {
    const r = insertSlice.run(s.name, s.type, s.description);
    sliceIds[s.name] = Number(r.lastInsertRowid);
  }

  // ── Assignments ───────────────────────────────────────────────────
  // Deliberately varied: high/medium/low confidence, multi-assign, unassigned, mixed statuses

  const assign = (filePath: string, slice: string, confidence: number, status = 'unreviewed') => {
    const fid = fileIds[filePath];
    const sid = sliceIds[slice];
    if (fid && sid) insertAssign.run(fid, sid, confidence, status);
  };

  // app package
  assign('app/src/main/java/com/example/app/Application.kt', 'app-lifecycle', 0.95, 'confirmed');
  assign('app/src/main/java/com/example/app/MainActivity.kt', 'app-lifecycle', 0.90, 'confirmed');
  assign('app/src/main/java/com/example/app/MainActivity.kt', 'ui-design-system', 0.40, 'unreviewed');
  assign('app/src/main/java/com/example/app/AppModule.kt', 'app-lifecycle', 0.92, 'unreviewed');
  assign('app/src/main/java/com/example/app/DeepLinkHandler.kt', 'app-lifecycle', 0.85, 'unreviewed');

  // auth package — fully assigned, mostly confirmed
  assign('app/src/main/java/com/example/auth/LoginActivity.kt', 'authentication', 0.97, 'confirmed');
  assign('app/src/main/java/com/example/auth/LoginViewModel.kt', 'authentication', 0.95, 'confirmed');
  assign('app/src/main/java/com/example/auth/AuthRepository.kt', 'authentication', 0.93, 'confirmed');
  assign('app/src/main/java/com/example/auth/TokenManager.kt', 'authentication', 0.90, 'confirmed');
  assign('app/src/main/java/com/example/auth/TokenManager.kt', 'networking', 0.55, 'unreviewed');
  assign('app/src/main/java/com/example/auth/SessionInterceptor.kt', 'authentication', 0.80, 'unreviewed');
  assign('app/src/main/java/com/example/auth/SessionInterceptor.kt', 'networking', 0.75, 'unreviewed');
  assign('app/src/main/java/com/example/auth/BiometricHelper.kt', 'authentication', 0.88, 'unreviewed');

  // camera package — mixed confidence
  assign('app/src/main/java/com/example/camera/CameraListFragment.kt', 'camera-list', 0.95, 'confirmed');
  assign('app/src/main/java/com/example/camera/CameraListViewModel.kt', 'camera-list', 0.93, 'unreviewed');
  assign('app/src/main/java/com/example/camera/CameraAdapter.kt', 'camera-list', 0.90, 'unreviewed');
  assign('app/src/main/java/com/example/camera/CameraDetailFragment.kt', 'camera-detail', 0.95, 'confirmed');
  assign('app/src/main/java/com/example/camera/CameraDetailViewModel.kt', 'camera-detail', 0.92, 'unreviewed');
  assign('app/src/main/java/com/example/camera/CameraRepository.kt', 'camera-list', 0.60, 'unreviewed');
  assign('app/src/main/java/com/example/camera/CameraRepository.kt', 'camera-detail', 0.60, 'unreviewed');
  assign('app/src/main/java/com/example/camera/LiveStreamPlayer.kt', 'camera-detail', 0.88, 'unreviewed');
  assign('app/src/main/java/com/example/camera/PTZControlView.kt', 'camera-detail', 0.85, 'unreviewed');

  // map package — well-assigned
  assign('app/src/main/java/com/example/map/MapFragment.kt', 'map-view', 0.96, 'confirmed');
  assign('app/src/main/java/com/example/map/MapViewModel.kt', 'map-view', 0.94, 'unreviewed');
  assign('app/src/main/java/com/example/map/MarkerRenderer.kt', 'map-view', 0.90, 'unreviewed');
  assign('app/src/main/java/com/example/map/MarkerInterpolator.kt', 'map-view', 0.85, 'unreviewed');
  assign('app/src/main/java/com/example/map/MarkerInterpolator.kt', 'real-time-tracking', 0.45, 'unreviewed');
  assign('app/src/main/java/com/example/map/ClusterManager.kt', 'map-view', 0.88, 'unreviewed');
  assign('app/src/main/java/com/example/map/GeoFenceManager.kt', 'map-view', 0.70, 'unreviewed');
  assign('app/src/main/java/com/example/map/GeoFenceManager.kt', 'incident-management', 0.35, 'unreviewed');
  assign('app/src/main/java/com/example/map/MapStyleManager.kt', 'map-view', 0.82, 'unreviewed');
  assign('app/src/main/java/com/example/map/MapStyleManager.kt', 'ui-design-system', 0.30, 'rejected');

  // incidents — some low confidence
  assign('app/src/main/java/com/example/incidents/IncidentListFragment.kt', 'incident-management', 0.93, 'unreviewed');
  assign('app/src/main/java/com/example/incidents/IncidentListViewModel.kt', 'incident-management', 0.90, 'unreviewed');
  assign('app/src/main/java/com/example/incidents/IncidentDetailFragment.kt', 'incident-management', 0.92, 'unreviewed');
  assign('app/src/main/java/com/example/incidents/IncidentDetailViewModel.kt', 'incident-management', 0.88, 'unreviewed');
  assign('app/src/main/java/com/example/incidents/IncidentRepository.kt', 'incident-management', 0.85, 'unreviewed');
  assign('app/src/main/java/com/example/incidents/IncidentFilterDialog.kt', 'incident-management', 0.80, 'unreviewed');
  assign('app/src/main/java/com/example/incidents/IncidentFilterDialog.kt', 'ui-design-system', 0.35, 'unreviewed');

  // tracking
  assign('app/src/main/java/com/example/tracking/TrackingService.kt', 'real-time-tracking', 0.95, 'confirmed');
  assign('app/src/main/java/com/example/tracking/LocationProvider.kt', 'real-time-tracking', 0.90, 'unreviewed');
  assign('app/src/main/java/com/example/tracking/TrackingViewModel.kt', 'real-time-tracking', 0.88, 'unreviewed');
  assign('app/src/main/java/com/example/tracking/TrackingOverlay.kt', 'real-time-tracking', 0.85, 'unreviewed');
  assign('app/src/main/java/com/example/tracking/TrackingOverlay.kt', 'map-view', 0.50, 'unreviewed');
  assign('app/src/main/java/com/example/tracking/RouteRenderer.kt', 'real-time-tracking', 0.82, 'unreviewed');
  assign('app/src/main/java/com/example/tracking/RouteRenderer.kt', 'map-view', 0.55, 'unreviewed');

  // settings
  assign('app/src/main/java/com/example/settings/SettingsFragment.kt', 'settings-prefs', 0.95, 'unreviewed');
  assign('app/src/main/java/com/example/settings/SettingsViewModel.kt', 'settings-prefs', 0.90, 'unreviewed');
  assign('app/src/main/java/com/example/settings/NotificationPrefs.kt', 'settings-prefs', 0.75, 'unreviewed');
  assign('app/src/main/java/com/example/settings/NotificationPrefs.kt', 'push-notifications', 0.50, 'unreviewed');
  assign('app/src/main/java/com/example/settings/ThemeManager.kt', 'settings-prefs', 0.60, 'unreviewed');
  assign('app/src/main/java/com/example/settings/ThemeManager.kt', 'ui-design-system', 0.70, 'unreviewed');

  // network — horizontal, all assigned
  assign('app/src/main/java/com/example/network/ApiClient.kt', 'networking', 0.97, 'confirmed');
  assign('app/src/main/java/com/example/network/ApiService.kt', 'networking', 0.95, 'confirmed');
  assign('app/src/main/java/com/example/network/AuthInterceptor.kt', 'networking', 0.85, 'unreviewed');
  assign('app/src/main/java/com/example/network/AuthInterceptor.kt', 'authentication', 0.65, 'unreviewed');
  assign('app/src/main/java/com/example/network/RetryInterceptor.kt', 'networking', 0.90, 'unreviewed');
  assign('app/src/main/java/com/example/network/WebSocketManager.kt', 'networking', 0.88, 'unreviewed');
  assign('app/src/main/java/com/example/network/WebSocketManager.kt', 'real-time-tracking', 0.40, 'unreviewed');
  assign('app/src/main/java/com/example/network/NetworkMonitor.kt', 'networking', 0.92, 'unreviewed');

  // database — horizontal
  assign('app/src/main/java/com/example/database/AppDatabase.kt', 'local-database', 0.97, 'confirmed');
  assign('app/src/main/java/com/example/database/CameraDao.kt', 'local-database', 0.90, 'unreviewed');
  assign('app/src/main/java/com/example/database/CameraDao.kt', 'camera-list', 0.35, 'unreviewed');
  assign('app/src/main/java/com/example/database/IncidentDao.kt', 'local-database', 0.90, 'unreviewed');
  assign('app/src/main/java/com/example/database/IncidentDao.kt', 'incident-management', 0.35, 'unreviewed');
  assign('app/src/main/java/com/example/database/UserDao.kt', 'local-database', 0.88, 'unreviewed');
  assign('app/src/main/java/com/example/database/Migrations.kt', 'local-database', 0.85, 'unreviewed');

  // ui-common — horizontal
  assign('app/src/main/java/com/example/ui/Theme.kt', 'ui-design-system', 0.97, 'confirmed');
  assign('app/src/main/java/com/example/ui/Colors.kt', 'ui-design-system', 0.95, 'confirmed');
  assign('app/src/main/java/com/example/ui/Typography.kt', 'ui-design-system', 0.93, 'unreviewed');
  assign('app/src/main/java/com/example/ui/LoadingIndicator.kt', 'ui-design-system', 0.90, 'unreviewed');
  assign('app/src/main/java/com/example/ui/ErrorView.kt', 'ui-design-system', 0.88, 'unreviewed');
  assign('app/src/main/java/com/example/ui/SearchBar.kt', 'ui-design-system', 0.85, 'unreviewed');
  assign('app/src/main/java/com/example/ui/FilterChip.kt', 'ui-design-system', 0.83, 'unreviewed');
  assign('app/src/main/java/com/example/ui/EmptyState.kt', 'ui-design-system', 0.80, 'unreviewed');

  // analytics
  assign('app/src/main/java/com/example/analytics/AnalyticsTracker.kt', 'analytics-observability', 0.95, 'unreviewed');
  assign('app/src/main/java/com/example/analytics/EventLogger.kt', 'analytics-observability', 0.92, 'unreviewed');
  assign('app/src/main/java/com/example/analytics/CrashReporter.kt', 'analytics-observability', 0.90, 'unreviewed');
  assign('app/src/main/java/com/example/analytics/PerformanceMonitor.kt', 'analytics-observability', 0.85, 'unreviewed');

  // notifications
  assign('app/src/main/java/com/example/notifications/PushService.kt', 'push-notifications', 0.95, 'unreviewed');
  assign('app/src/main/java/com/example/notifications/NotificationBuilder.kt', 'push-notifications', 0.90, 'unreviewed');
  assign('app/src/main/java/com/example/notifications/NotificationChannels.kt', 'push-notifications', 0.88, 'unreviewed');

  // resources — deliberately UNASSIGNED (no clear single slice)
  // These will show in the coverage dashboard as needing attention

  // gradle/root config — assigned to build-configuration
  assign('gradle/wrapper/gradle-wrapper.properties', 'build-configuration', 0.95, 'confirmed');
  assign('gradle/libs.versions.toml', 'build-configuration', 0.92, 'unreviewed');
  assign('build.gradle.kts', 'build-configuration', 0.95, 'confirmed');
  assign('settings.gradle.kts', 'build-configuration', 0.90, 'unreviewed');
  assign('gradle.properties', 'build-configuration', 0.88, 'unreviewed');
  assign('app/build.gradle.kts', 'build-configuration', 0.90, 'unreviewed');
});

transaction();

// Stats
const stats = db.prepare(`
  SELECT
    (SELECT COUNT(*) FROM packages) as packages,
    (SELECT COUNT(*) FROM files) as files,
    (SELECT COUNT(*) FROM slices) as slices,
    (SELECT COUNT(*) FROM file_slice_assignments) as assignments,
    (SELECT COUNT(DISTINCT file_id) FROM file_slice_assignments) as assigned_files
`).get() as any;

const unassigned = stats.files - stats.assigned_files;
const coverage = ((stats.assigned_files / stats.files) * 100).toFixed(1);
const lowConf = db.prepare('SELECT COUNT(*) as c FROM file_slice_assignments WHERE confidence < 0.7').get() as any;
const confirmed = db.prepare("SELECT COUNT(*) as c FROM file_slice_assignments WHERE status = 'confirmed'").get() as any;
const rejected = db.prepare("SELECT COUNT(*) as c FROM file_slice_assignments WHERE status = 'rejected'").get() as any;

console.log(`Demo data created:`);
console.log(`  Packages:       ${stats.packages}`);
console.log(`  Files:          ${stats.files}`);
console.log(`  Slices:         ${stats.slices} (${db.prepare("SELECT COUNT(*) as c FROM slices WHERE type='vertical'").get()?.c} vertical, ${db.prepare("SELECT COUNT(*) as c FROM slices WHERE type='horizontal'").get()?.c} horizontal)`);
console.log(`  Assignments:    ${stats.assignments}`);
console.log(`  Coverage:       ${stats.assigned_files}/${stats.files} (${coverage}%)`);
console.log(`  Unassigned:     ${unassigned} files`);
console.log(`  Low confidence: ${lowConf.c} assignments (<0.7)`);
console.log(`  Confirmed:      ${confirmed.c}`);
console.log(`  Rejected:       ${rejected.c}`);
