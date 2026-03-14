import Database from 'better-sqlite3';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DB_PATH = path.join(__dirname, '..', 'slice-planner.db');

const db = new Database(DB_PATH);
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

// Initialize schema
db.exec(`
  CREATE TABLE IF NOT EXISTS slices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,
    type TEXT NOT NULL CHECK(type IN ('vertical', 'horizontal')),
    description TEXT
  );

  CREATE TABLE IF NOT EXISTS packages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    path TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS files (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    path TEXT UNIQUE NOT NULL,
    package_id INTEGER NOT NULL REFERENCES packages(id)
  );

  CREATE TABLE IF NOT EXISTS file_slice_assignments (
    file_id INTEGER NOT NULL REFERENCES files(id),
    slice_id INTEGER NOT NULL REFERENCES slices(id),
    confidence REAL NOT NULL DEFAULT 0.0,
    status TEXT NOT NULL DEFAULT 'unreviewed' CHECK(status IN ('unreviewed', 'confirmed', 'rejected')),
    PRIMARY KEY (file_id, slice_id)
  );
`);

export default db;
