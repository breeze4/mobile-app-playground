import { Router } from 'express';
import db from '../db.js';

const router = Router();

// GET /api/packages — list all packages with file counts and unassigned counts
router.get('/', (_req, res) => {
  const packages = db.prepare(`
    SELECT
      p.id, p.path, p.name,
      COUNT(DISTINCT f.id) as file_count,
      COUNT(DISTINCT f.id) - COUNT(DISTINCT a.file_id) as unassigned_count
    FROM packages p
    LEFT JOIN files f ON f.package_id = p.id
    LEFT JOIN file_slice_assignments a ON a.file_id = f.id
    GROUP BY p.id
    ORDER BY p.path
  `).all();
  res.json(packages);
});

// GET /api/packages/:id/files — list files in a package with their slice assignments
router.get('/:id/files', (req, res) => {
  const pkgId = req.params.id;

  const files = db.prepare(`
    SELECT id, path FROM files WHERE package_id = ? ORDER BY path
  `).all(pkgId) as { id: number; path: string }[];

  const getAssignments = db.prepare(`
    SELECT s.id as slice_id, s.name as slice_name, s.type as slice_type,
           a.confidence, a.status
    FROM file_slice_assignments a
    JOIN slices s ON s.id = a.slice_id
    WHERE a.file_id = ?
    ORDER BY a.confidence DESC
  `);

  const result = files.map(f => ({
    ...f,
    assignments: getAssignments.all(f.id),
  }));

  res.json(result);
});

export default router;
