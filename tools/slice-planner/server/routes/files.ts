import { Router } from 'express';
import db from '../db.js';

const router = Router();

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

export default router;
