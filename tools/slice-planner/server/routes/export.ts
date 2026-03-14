import { Router } from 'express';
import YAML from 'yaml';
import db from '../db.js';

const router = Router();

// GET /api/export — export YAML matching slice-mapping schema
router.get('/', (_req, res) => {
  // Get all slices
  const slices = db.prepare('SELECT name, type, description FROM slices ORDER BY name').all() as Array<{
    name: string;
    type: string;
    description: string;
  }>;

  // Get all packages
  const packages = db.prepare('SELECT path, name FROM packages ORDER BY path').all() as Array<{
    path: string;
    name: string;
  }>;

  // Get files with assignments — prefer confirmed, but include all if none confirmed
  const confirmedCount = (db.prepare(
    "SELECT COUNT(*) as count FROM file_slice_assignments WHERE status = 'confirmed'"
  ).get() as { count: number }).count;

  const statusFilter = confirmedCount > 0 ? "AND a.status = 'confirmed'" : '';

  const assignedRows = db.prepare(`
    SELECT f.path as file_path, p.path as package_path,
           s.name as slice_name, a.confidence
    FROM file_slice_assignments a
    JOIN files f ON f.id = a.file_id
    JOIN packages p ON p.id = f.package_id
    JOIN slices s ON s.id = a.slice_id
    WHERE 1=1 ${statusFilter}
    ORDER BY f.path, s.name
  `).all() as Array<{
    file_path: string;
    package_path: string;
    slice_name: string;
    confidence: number;
  }>;

  // Group assignments by file
  const fileMap = new Map<string, {
    path: string;
    package: string;
    assignments: Array<{ slice: string; confidence: number }>;
  }>();

  for (const row of assignedRows) {
    if (!fileMap.has(row.file_path)) {
      fileMap.set(row.file_path, {
        path: row.file_path,
        package: row.package_path,
        assignments: [],
      });
    }
    fileMap.get(row.file_path)!.assignments.push({
      slice: row.slice_name,
      confidence: row.confidence,
    });
  }

  const files = Array.from(fileMap.values());

  // Get files not in the exported set (either truly unassigned or only have non-confirmed assignments)
  const assignedPaths = new Set(fileMap.keys());
  const allFilesRows = db.prepare(`
    SELECT f.path, p.path as package_path
    FROM files f
    JOIN packages p ON p.id = f.package_id
    ORDER BY f.path
  `).all() as Array<{ path: string; package_path: string }>;

  const unassigned = allFilesRows
    .filter(f => !assignedPaths.has(f.path))
    .map(u => ({
      path: u.path,
      package: u.package_path,
      reason: 'Not assigned to any slice',
    }));

  // Compute summary
  const totalFiles = (db.prepare('SELECT COUNT(*) as count FROM files').get() as { count: number }).count;
  const assignedFileCount = fileMap.size;
  const unassignedFileCount = totalFiles - assignedFileCount;
  const coveragePercent = totalFiles > 0
    ? Math.round((assignedFileCount / totalFiles) * 1000) / 10
    : 0;
  const lowConfidenceCount = assignedRows.filter(r => r.confidence < 0.7).length;

  const exportData = {
    version: '1',
    kind: 'slice-mapping',
    generated_at: new Date().toISOString(),
    slices,
    packages,
    files,
    unassigned,
    summary: {
      total_files: totalFiles,
      assigned_files: assignedFileCount,
      unassigned_files: unassignedFileCount,
      coverage_percent: coveragePercent,
      low_confidence_count: lowConfidenceCount,
    },
  };

  const yamlStr = YAML.stringify(exportData);
  res.setHeader('Content-Type', 'application/x-yaml');
  res.setHeader('Content-Disposition', 'attachment; filename="slice-mapping.yaml"');
  res.send(yamlStr);
});

export default router;
