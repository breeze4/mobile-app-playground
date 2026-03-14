import express from 'express';
import cors from 'cors';
import path from 'path';
import { fileURLToPath } from 'url';
import db from './db.js';
import importRoutes from './routes/import.js';
import packageRoutes from './routes/packages.js';
import sliceRoutes from './routes/slices.js';
import fileRoutes from './routes/files.js';
import coverageRoutes from './routes/coverage.js';
import exportRoutes from './routes/export.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const app = express();
const PORT = parseInt(process.env.PORT || '3051');

app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.text({ type: 'application/x-yaml', limit: '10mb' }));

// Health check
app.get('/api/health', (_req, res) => {
  res.json({ status: 'ok' });
});

// API routes
app.use('/api/import', importRoutes);
app.use('/api/packages', packageRoutes);
app.use('/api/slices', sliceRoutes);
app.use('/api/files', fileRoutes);
app.use('/api/coverage', coverageRoutes);
app.use('/api/export', exportRoutes);

// In production, serve the Vite build
const distPath = path.join(__dirname, '..', 'dist');
app.use(express.static(distPath));
app.get('/{*splat}', (req, res) => {
  // Don't serve index.html for API routes
  if (req.path.startsWith('/api/')) {
    res.status(404).json({ error: 'Not found' });
    return;
  }
  res.sendFile(path.join(distPath, 'index.html'));
});

app.listen(PORT, () => {
  console.log(`Slice Planner server running on http://localhost:${PORT}`);
});

export { app, db };
