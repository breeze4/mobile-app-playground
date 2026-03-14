import db from './db.js';

// Must run after seed so files/packages exist
const fileCount = db.prepare('SELECT COUNT(*) as count FROM files').get() as { count: number };
if (fileCount.count === 0) {
  console.error('No files in DB. Run seed first: npm run seed -- /path/to/project');
  process.exit(1);
}

// Clear existing slice data
db.exec('DELETE FROM file_slice_assignments');
db.exec('DELETE FROM slices');

const insertSlice = db.prepare('INSERT INTO slices (name, type, description) VALUES (?, ?, ?)');
const insertAssignment = db.prepare(
  'INSERT INTO file_slice_assignments (file_id, slice_id, confidence, status) VALUES (?, ?, ?, ?)'
);

const slices = [
  { name: 'hello-ui', type: 'vertical', description: 'Main activity with Compose-based hello world screen' },
  { name: 'video-player', type: 'vertical', description: 'Video player overlay with Media3 integration' },
  { name: 'map-ui', type: 'vertical', description: 'Base map UI with live marker rendering and interpolation' },
  { name: 'auth', type: 'vertical', description: 'User authentication and session management' },
  { name: 'settings', type: 'vertical', description: 'App settings and preferences screen' },
  { name: 'build-config', type: 'horizontal', description: 'Gradle build configuration, wrapper, and project settings' },
  { name: 'compose-foundation', type: 'horizontal', description: 'Jetpack Compose theming, navigation, and shared UI components' },
  { name: 'networking', type: 'horizontal', description: 'HTTP client, API definitions, and network utilities' },
  { name: 'analytics', type: 'horizontal', description: 'Event tracking and crash reporting infrastructure' },
];

const transaction = db.transaction(() => {
  const sliceIds: Record<string, number> = {};
  for (const s of slices) {
    const result = insertSlice.run(s.name, s.type, s.description);
    sliceIds[s.name] = Number(result.lastInsertRowid);
  }

  // Get all files
  const files = db.prepare('SELECT id, path FROM files').all() as { id: number; path: string }[];

  // Assignment patterns: varied confidence, some multi-assigned, some unassigned
  for (const file of files) {
    const p = file.path.toLowerCase();

    if (p.includes('mainactivity')) {
      // High confidence primary, medium secondary
      insertAssignment.run(file.id, sliceIds['hello-ui'], 0.95, 'confirmed');
      insertAssignment.run(file.id, sliceIds['compose-foundation'], 0.72, 'unreviewed');
    } else if (p.includes('manifest')) {
      // Medium confidence, multi-assigned
      insertAssignment.run(file.id, sliceIds['hello-ui'], 0.85, 'unreviewed');
      insertAssignment.run(file.id, sliceIds['build-config'], 0.6, 'unreviewed');
    } else if (p.includes('build.gradle')) {
      insertAssignment.run(file.id, sliceIds['build-config'], 0.95, 'unreviewed');
      insertAssignment.run(file.id, sliceIds['compose-foundation'], 0.45, 'rejected');
    }
    // Any remaining files are deliberately left unassigned
  }
});

transaction();

const stats = {
  slices: db.prepare('SELECT COUNT(*) as count FROM slices').get() as { count: number },
  assignments: db.prepare('SELECT COUNT(*) as count FROM file_slice_assignments').get() as { count: number },
  assignedFiles: db.prepare('SELECT COUNT(DISTINCT file_id) as count FROM file_slice_assignments').get() as { count: number },
  totalFiles: fileCount,
};

console.log(`Mock data created:`);
console.log(`  Slices: ${stats.slices.count}`);
console.log(`  Assignments: ${stats.assignments.count}`);
console.log(`  Files with assignments: ${stats.assignedFiles.count} / ${stats.totalFiles.count}`);
