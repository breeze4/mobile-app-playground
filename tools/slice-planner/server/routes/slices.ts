import { Router } from 'express';
import db from '../db.js';

const router = Router();

// GET /api/slices — list all slices
router.get('/', (_req, res) => {
  const slices = db.prepare('SELECT id, name, type, description FROM slices ORDER BY name').all();
  res.json(slices);
});

export default router;
