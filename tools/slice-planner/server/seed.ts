import fs from 'fs';
import path from 'path';
import db from './db.js';

const SKIP_DIRS = new Set([
  'node_modules', '.git', '.gradle', 'build', 'dist', '.idea',
  '.vscode', '.beads', '.dolt', 'dolt', '.ralph',
]);

const SKIP_EXTENSIONS = new Set([
  '.apk', '.aab', '.jar', '.class', '.so', '.dylib', '.dll',
  '.png', '.jpg', '.jpeg', '.gif', '.ico', '.svg', '.webp',
  '.zip', '.tar', '.gz', '.bz2',
  '.db', '.sqlite', '.sqlite3',
  '.lock',
]);

function loadGitignorePatterns(projectRoot: string): string[] {
  const gitignorePath = path.join(projectRoot, '.gitignore');
  if (!fs.existsSync(gitignorePath)) return [];
  return fs.readFileSync(gitignorePath, 'utf-8')
    .split('\n')
    .map(l => l.trim())
    .filter(l => l && !l.startsWith('#'))
    .map(l => l.replace(/\/$/, '')); // strip trailing slashes
}

function shouldSkip(name: string, relativePath: string, gitignorePatterns: string[]): boolean {
  if (SKIP_DIRS.has(name)) return true;
  for (const pattern of gitignorePatterns) {
    // Simple pattern matching: exact name match or glob suffix
    if (name === pattern) return true;
    if (pattern.startsWith('*.') && name.endsWith(pattern.slice(1))) return true;
    if (relativePath === pattern || relativePath.startsWith(pattern + '/')) return true;
  }
  return false;
}

function isBinaryOrSkipped(filePath: string): boolean {
  const ext = path.extname(filePath).toLowerCase();
  return SKIP_EXTENSIONS.has(ext);
}

interface FileEntry {
  path: string; // relative to project root
}

interface PackageEntry {
  path: string; // relative to project root
  name: string;
  files: FileEntry[];
}

function walkDirectory(
  dir: string,
  projectRoot: string,
  gitignorePatterns: string[],
  packages: Map<string, PackageEntry>,
) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });

  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    const relativePath = path.relative(projectRoot, fullPath);

    if (shouldSkip(entry.name, relativePath, gitignorePatterns)) continue;

    if (entry.isDirectory()) {
      walkDirectory(fullPath, projectRoot, gitignorePatterns, packages);
    } else if (entry.isFile()) {
      if (isBinaryOrSkipped(fullPath)) continue;

      // Package = parent directory relative to project root
      const packagePath = path.relative(projectRoot, dir) || '.';
      const packageName = packagePath === '.' ? 'root' : packagePath.split(path.sep).pop()!;

      if (!packages.has(packagePath)) {
        packages.set(packagePath, { path: packagePath, name: packageName, files: [] });
      }
      packages.get(packagePath)!.files.push({ path: relativePath });
    }
  }
}

function seed(projectDir: string) {
  const projectRoot = path.resolve(projectDir);
  if (!fs.existsSync(projectRoot)) {
    console.error(`Directory not found: ${projectRoot}`);
    process.exit(1);
  }

  console.log(`Scanning: ${projectRoot}`);
  const gitignorePatterns = loadGitignorePatterns(projectRoot);
  const packages = new Map<string, PackageEntry>();

  walkDirectory(projectRoot, projectRoot, gitignorePatterns, packages);

  // Clear existing data
  db.exec('DELETE FROM file_slice_assignments');
  db.exec('DELETE FROM files');
  db.exec('DELETE FROM packages');

  const insertPkg = db.prepare('INSERT INTO packages (path, name) VALUES (?, ?)');
  const insertFile = db.prepare('INSERT INTO files (path, package_id) VALUES (?, ?)');

  let totalFiles = 0;

  const transaction = db.transaction(() => {
    for (const [, pkg] of packages) {
      const result = insertPkg.run(pkg.path, pkg.name);
      const pkgId = result.lastInsertRowid;

      for (const file of pkg.files) {
        insertFile.run(file.path, pkgId);
        totalFiles++;
      }
    }
  });

  transaction();

  console.log(`Seeded: ${packages.size} packages, ${totalFiles} files`);
}

// CLI entrypoint
const targetDir = process.argv[2];
if (!targetDir) {
  console.error('Usage: npm run seed -- /path/to/project');
  process.exit(1);
}

seed(targetDir);
