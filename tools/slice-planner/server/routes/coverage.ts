import { Router } from 'express';
import db from '../db.js';

const router = Router();

// GET /api/coverage — coverage statistics
router.get('/', (_req, res) => {
  const totalFiles = (db.prepare('SELECT COUNT(*) as count FROM files').get() as { count: number }).count;
  const assignedFiles = (db.prepare(
    'SELECT COUNT(DISTINCT file_id) as count FROM file_slice_assignments'
  ).get() as { count: number }).count;
  const unassignedFiles = totalFiles - assignedFiles;
  const coveragePercent = totalFiles > 0 ? Math.round((assignedFiles / totalFiles) * 1000) / 10 : 0;

  const lowConfidenceThreshold = 0.7;
  const lowConfidenceCount = (db.prepare(
    'SELECT COUNT(*) as count FROM file_slice_assignments WHERE confidence < ?'
  ).get(lowConfidenceThreshold) as { count: number }).count;

  res.json({
    total_files: totalFiles,
    assigned_files: assignedFiles,
    unassigned_files: unassignedFiles,
    coverage_percent: coveragePercent,
    low_confidence_count: lowConfidenceCount,
    low_confidence_threshold: lowConfidenceThreshold,
  });
});

export default router;
