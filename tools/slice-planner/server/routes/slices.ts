import { Router } from 'express';
import db from '../db.js';

const router = Router();

// GET /api/slices — list all slices, optional ?type=vertical|horizontal filter
router.get('/', (req, res) => {
  const typeFilter = req.query.type as string | undefined;
  let sql = 'SELECT id, name, type, description FROM slices';
  const params: string[] = [];

  if (typeFilter === 'vertical' || typeFilter === 'horizontal') {
    sql += ' WHERE type = ?';
    params.push(typeFilter);
  }

  sql += ' ORDER BY name';
  const slices = db.prepare(sql).all(...params);
  res.json(slices);
});

// GET /api/slices/:id/files — list files assigned to a slice, grouped by package
router.get('/:id/files', (req, res) => {
  const sliceId = Number(req.params.id);

  // Get the slice itself
  const slice = db.prepare('SELECT id, name, type, description FROM slices WHERE id = ?').get(sliceId);
  if (!slice) {
    res.status(404).json({ error: 'Slice not found' });
    return;
  }

  // Get all files assigned to this slice with their package info
  const rows = db.prepare(`
    SELECT f.id as file_id, f.path as file_path,
           p.id as package_id, p.path as package_path, p.name as package_name,
           a.confidence, a.status
    FROM file_slice_assignments a
    JOIN files f ON f.id = a.file_id
    JOIN packages p ON p.id = f.package_id
    WHERE a.slice_id = ?
    ORDER BY p.path, f.path
  `).all(sliceId) as Array<{
    file_id: number;
    file_path: string;
    package_id: number;
    package_path: string;
    package_name: string;
    confidence: number;
    status: string;
  }>;

  // Group by package
  const packageMap = new Map<number, {
    id: number;
    path: string;
    name: string;
    files: Array<{ id: number; path: string; confidence: number; status: string }>;
  }>();

  for (const row of rows) {
    if (!packageMap.has(row.package_id)) {
      packageMap.set(row.package_id, {
        id: row.package_id,
        path: row.package_path,
        name: row.package_name,
        files: [],
      });
    }
    packageMap.get(row.package_id)!.files.push({
      id: row.file_id,
      path: row.file_path,
      confidence: row.confidence,
      status: row.status,
    });
  }

  res.json({
    slice,
    packages: Array.from(packageMap.values()),
  });
});

export default router;
