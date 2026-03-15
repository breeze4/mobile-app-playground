import { Router } from 'express';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const router = Router();

function getReportsDir(): string {
  return process.env.REPORTS_DIR || path.join(__dirname, '..', '..', 'reports');
}

interface SliceReport {
  slice_name: string;
  slice_type: 'vertical' | 'horizontal';
  description: string;
  generated_at: string;
}

interface ReportListItem {
  slice_name: string;
  status: 'complete' | 'pending';
  slice_type?: 'vertical' | 'horizontal';
  description?: string;
  generated_at?: string;
}

// GET /api/reports — list all slices with report status
router.get('/', (_req, res) => {
  const reportsDir = getReportsDir();

  if (!fs.existsSync(reportsDir)) {
    res.json([]);
    return;
  }

  const entries = fs.readdirSync(reportsDir, { withFileTypes: true });
  const reports: ReportListItem[] = [];

  for (const entry of entries) {
    if (!entry.isDirectory()) continue;

    const reportPath = path.join(reportsDir, entry.name, 'report.json');
    if (fs.existsSync(reportPath)) {
      try {
        const data = JSON.parse(fs.readFileSync(reportPath, 'utf-8')) as SliceReport;
        reports.push({
          slice_name: data.slice_name || entry.name,
          status: 'complete',
          slice_type: data.slice_type,
          description: data.description,
          generated_at: data.generated_at,
        });
      } catch {
        reports.push({ slice_name: entry.name, status: 'pending' });
      }
    } else {
      reports.push({ slice_name: entry.name, status: 'pending' });
    }
  }

  res.json(reports);
});

// GET /api/reports/:sliceName — get full report for a slice
router.get('/:sliceName', (req, res) => {
  const reportsDir = getReportsDir();
  const sliceName = req.params.sliceName;
  const reportPath = path.join(reportsDir, sliceName, 'report.json');

  try {
    const data = JSON.parse(fs.readFileSync(reportPath, 'utf-8'));
    res.json(data);
  } catch (err) {
    const code = (err as NodeJS.ErrnoException).code;
    if (code === 'ENOENT') {
      res.status(404).json({ error: `Report not found for slice: ${sliceName}` });
    } else {
      res.status(500).json({ error: 'Failed to parse report.json' });
    }
  }
});

// GET /api/reports/:sliceName/artifacts/* — serve artifact files
router.get('/:sliceName/artifacts/{*artifactPath}', (req, res) => {
  const reportsDir = getReportsDir();
  const sliceName = req.params.sliceName;
  const artifactPath = (req.params as Record<string, string>).artifactPath || '';

  // Prevent directory traversal
  const resolved = path.resolve(reportsDir, sliceName, artifactPath);
  const expectedBase = path.resolve(reportsDir, sliceName);
  if (!resolved.startsWith(expectedBase)) {
    res.status(403).json({ error: 'Forbidden' });
    return;
  }

  res.sendFile(resolved, (err) => {
    if (err && !res.headersSent) {
      res.status(404).json({ error: 'Artifact not found' });
    }
  });
});

export default router;
