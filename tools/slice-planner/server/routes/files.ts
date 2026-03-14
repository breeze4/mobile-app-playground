import { Router } from 'express';
import db from '../db.js';

const router = Router();

// GET /api/files/unassigned — list files with no slice assignments
// NOTE: must be before /:id routes to avoid matching "unassigned" as an id
router.get('/unassigned', (_req, res) => {
  const files = db.prepare(`
    SELECT f.id, f.path, p.path as package_path, p.name as package_name
    FROM files f
    JOIN packages p ON p.id = f.package_id
    LEFT JOIN file_slice_assignments a ON a.file_id = f.id
    WHERE a.file_id IS NULL
    ORDER BY f.path
  `).all();

  res.json(files);
});

// GET /api/files/low-confidence — list assignments below a threshold
router.get('/low-confidence', (req, res) => {
  const threshold = Number(req.query.threshold) || 0.7;

  const rows = db.prepare(`
    SELECT f.id as file_id, f.path as file_path,
           s.id as slice_id, s.name as slice_name, s.type as slice_type,
           a.confidence, a.status,
           p.path as package_path, p.name as package_name
    FROM file_slice_assignments a
    JOIN files f ON f.id = a.file_id
    JOIN slices s ON s.id = a.slice_id
    JOIN packages p ON p.id = f.package_id
    WHERE a.confidence < ?
    ORDER BY a.confidence ASC
  `).all(threshold);

  res.json(rows);
});

// GET /api/files/:id/assignments — get assignments for a specific file
router.get('/:id/assignments', (req, res) => {
  const fileId = req.params.id;

  const assignments = db.prepare(`
    SELECT s.id as slice_id, s.name as slice_name, s.type as slice_type,
           a.confidence, a.status
    FROM file_slice_assignments a
    JOIN slices s ON s.id = a.slice_id
    WHERE a.file_id = ?
    ORDER BY a.confidence DESC
  `).all(fileId);

  res.json(assignments);
});

// PUT /api/files/:id/assignments — update assignments for a file
router.put('/:id/assignments', (req, res) => {
  const fileId = Number(req.params.id);
  const assignments = req.body as Array<{
    slice_id: number;
    confidence: number;
    status?: string;
  }>;

  if (!Array.isArray(assignments)) {
    res.status(400).json({ error: 'Body must be an array of assignments' });
    return;
  }

  const deleteAll = db.prepare('DELETE FROM file_slice_assignments WHERE file_id = ?');
  const insert = db.prepare(
    'INSERT INTO file_slice_assignments (file_id, slice_id, confidence, status) VALUES (?, ?, ?, ?)'
  );

  const transaction = db.transaction(() => {
    deleteAll.run(fileId);
    for (const a of assignments) {
      insert.run(fileId, a.slice_id, a.confidence, a.status || 'unreviewed');
    }
  });

  try {
    transaction();
    // Return updated assignments
    const updated = db.prepare(`
      SELECT s.id as slice_id, s.name as slice_name, s.type as slice_type,
             a.confidence, a.status
      FROM file_slice_assignments a
      JOIN slices s ON s.id = a.slice_id
      WHERE a.file_id = ?
      ORDER BY a.confidence DESC
    `).all(fileId);
    res.json(updated);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    res.status(500).json({ error: message });
  }
});

// DELETE /api/files/:fileId/assignments/:sliceId — remove a specific assignment
router.delete('/:fileId/assignments/:sliceId', (req, res) => {
  const fileId = Number(req.params.fileId);
  const sliceId = Number(req.params.sliceId);

  const result = db.prepare(
    'DELETE FROM file_slice_assignments WHERE file_id = ? AND slice_id = ?'
  ).run(fileId, sliceId);

  if (result.changes === 0) {
    res.status(404).json({ error: 'Assignment not found' });
    return;
  }

  res.json({ success: true });
});

export default router;
