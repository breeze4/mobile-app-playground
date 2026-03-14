import { Router } from 'express';
import db from '../db.js';
import { parseYaml, validate } from '../import.js';
import type { SliceMappingFile } from '../import.js';

const router = Router();

interface ImportSummary {
  slices: { created: number; existing: number };
  packages: { created: number; existing: number };
  files: { created: number; existing: number };
  assignments: { created: number; updated: number; skipped: number };
}

function importMapping(data: SliceMappingFile): ImportSummary {
  const summary: ImportSummary = {
    slices: { created: 0, existing: 0 },
    packages: { created: 0, existing: 0 },
    files: { created: 0, existing: 0 },
    assignments: { created: 0, updated: 0, skipped: 0 },
  };

  const getSlice = db.prepare('SELECT id FROM slices WHERE name = ?');
  const insertSlice = db.prepare('INSERT INTO slices (name, type, description) VALUES (?, ?, ?)');

  const getPkg = db.prepare('SELECT id FROM packages WHERE path = ?');
  const insertPkg = db.prepare('INSERT INTO packages (path, name) VALUES (?, ?)');

  const getFile = db.prepare('SELECT id FROM files WHERE path = ?');
  const insertFile = db.prepare('INSERT INTO files (path, package_id) VALUES (?, ?)');

  const getAssignment = db.prepare('SELECT status, confidence FROM file_slice_assignments WHERE file_id = ? AND slice_id = ?');
  const insertAssignment = db.prepare(
    'INSERT INTO file_slice_assignments (file_id, slice_id, confidence, status) VALUES (?, ?, ?, ?)'
  );
  const updateAssignment = db.prepare(
    'UPDATE file_slice_assignments SET confidence = ? WHERE file_id = ? AND slice_id = ?'
  );

  const transaction = db.transaction(() => {
    // Create slices
    const sliceIds: Record<string, number> = {};
    for (const s of data.slices) {
      const existing = getSlice.get(s.name) as { id: number } | undefined;
      if (existing) {
        sliceIds[s.name] = existing.id;
        summary.slices.existing++;
      } else {
        const result = insertSlice.run(s.name, s.type, s.description);
        sliceIds[s.name] = Number(result.lastInsertRowid);
        summary.slices.created++;
      }
    }

    // Create packages
    const pkgIds: Record<string, number> = {};
    for (const p of data.packages) {
      const existing = getPkg.get(p.path) as { id: number } | undefined;
      if (existing) {
        pkgIds[p.path] = existing.id;
        summary.packages.existing++;
      } else {
        const result = insertPkg.run(p.path, p.name);
        pkgIds[p.path] = Number(result.lastInsertRowid);
        summary.packages.created++;
      }
    }

    // Create files and assignments
    const allFiles = [...data.files, ...data.unassigned.map(u => ({ path: u.path, package: u.package, assignments: [] }))];

    for (const f of allFiles) {
      // Ensure package exists
      let pkgId = pkgIds[f.package];
      if (!pkgId) {
        const existing = getPkg.get(f.package) as { id: number } | undefined;
        if (existing) {
          pkgId = existing.id;
        } else {
          const pkgName = f.package === '.' ? 'root' : f.package.split('/').pop()!;
          const result = insertPkg.run(f.package, pkgName);
          pkgId = Number(result.lastInsertRowid);
          pkgIds[f.package] = pkgId;
          summary.packages.created++;
        }
      }

      // Ensure file exists
      let fileId: number;
      const existingFile = getFile.get(f.path) as { id: number } | undefined;
      if (existingFile) {
        fileId = existingFile.id;
        summary.files.existing++;
      } else {
        const result = insertFile.run(f.path, pkgId);
        fileId = Number(result.lastInsertRowid);
        summary.files.created++;
      }

      // Create assignments
      for (const a of f.assignments) {
        const sliceId = sliceIds[a.slice];
        if (!sliceId) continue; // skip unknown slices

        const existingAssignment = getAssignment.get(fileId, sliceId) as { status: string; confidence: number } | undefined;
        if (existingAssignment) {
          if (existingAssignment.status === 'confirmed' || existingAssignment.status === 'rejected') {
            summary.assignments.skipped++;
          } else {
            updateAssignment.run(a.confidence, fileId, sliceId);
            summary.assignments.updated++;
          }
        } else {
          insertAssignment.run(fileId, sliceId, a.confidence, 'unreviewed');
          summary.assignments.created++;
        }
      }
    }
  });

  transaction();
  return summary;
}

router.post('/', (req, res) => {
  try {
    let data: unknown;

    // Accept YAML string in body or JSON
    if (typeof req.body === 'string') {
      data = parseYaml(req.body);
    } else if (req.body.yaml && typeof req.body.yaml === 'string') {
      data = parseYaml(req.body.yaml);
    } else {
      data = req.body;
    }

    const result = validate(data);
    if (!result.valid) {
      res.status(400).json({ errors: result.errors });
      return;
    }

    const summary = importMapping(result.data);
    res.json({ success: true, summary });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    res.status(500).json({ error: message });
  }
});

export default router;
