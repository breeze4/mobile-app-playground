import { useState, useEffect } from 'react';
import { fetchPackages, fetchPackageFiles } from '../api/client';
import type { Package, FileWithAssignments } from '../api/client';
import SliceBadge from './SliceBadge';

interface PackageTreeProps {
  onFileSelect: (file: FileWithAssignments) => void;
  selectedFileId: number | null;
  refreshKey: number;
}

export default function PackageTree({ onFileSelect, selectedFileId, refreshKey }: PackageTreeProps) {
  const [packages, setPackages] = useState<Package[]>([]);
  const [expandedPkgs, setExpandedPkgs] = useState<Set<number>>(new Set());
  const [pkgFiles, setPkgFiles] = useState<Record<number, FileWithAssignments[]>>({});

  useEffect(() => {
    fetchPackages().then(setPackages);
  }, [refreshKey]);

  const togglePackage = async (pkg: Package) => {
    const next = new Set(expandedPkgs);
    if (next.has(pkg.id)) {
      next.delete(pkg.id);
    } else {
      next.add(pkg.id);
      if (!pkgFiles[pkg.id]) {
        const files = await fetchPackageFiles(pkg.id);
        setPkgFiles(prev => ({ ...prev, [pkg.id]: files }));
      }
    }
    setExpandedPkgs(next);
  };

  // Refresh files for expanded packages when refreshKey changes
  useEffect(() => {
    for (const pkgId of expandedPkgs) {
      fetchPackageFiles(pkgId).then(files => {
        setPkgFiles(prev => ({ ...prev, [pkgId]: files }));
      });
    }
  }, [refreshKey]);

  return (
    <div className="package-tree">
      <h2>Packages</h2>
      {packages.map(pkg => (
        <div key={pkg.id} className="package-node">
          <div
            className="package-header"
            onClick={() => togglePackage(pkg)}
          >
            <span className="expand-icon">
              {expandedPkgs.has(pkg.id) ? '\u25BC' : '\u25B6'}
            </span>
            <span className="package-name">{pkg.path}</span>
            <span className="file-count">{pkg.file_count} files</span>
            {pkg.unassigned_count > 0 && (
              <span className="unassigned-badge">{pkg.unassigned_count} unassigned</span>
            )}
          </div>
          {expandedPkgs.has(pkg.id) && pkgFiles[pkg.id] && (
            <div className="file-list">
              {pkgFiles[pkg.id].map(file => {
                const fileName = file.path.split('/').pop() || file.path;
                const isUnassigned = file.assignments.length === 0;
                const isSelected = file.id === selectedFileId;
                return (
                  <div
                    key={file.id}
                    className={`file-item ${isUnassigned ? 'unassigned' : ''} ${isSelected ? 'selected' : ''}`}
                    onClick={() => onFileSelect(file)}
                  >
                    <span className="file-name">{fileName}</span>
                    <div className="file-badges">
                      {file.assignments.map(a => (
                        <SliceBadge key={a.slice_id} assignment={a} />
                      ))}
                      {isUnassigned && (
                        <span className="no-assignment-indicator">No slice</span>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      ))}
    </div>
  );
}
