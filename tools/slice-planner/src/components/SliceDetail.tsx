import { useState, useEffect } from 'react';
import { fetchSliceFiles, deleteFileAssignment, fetchSlices, updateFileAssignments } from '../api/client';
import type { SliceFilesResponse, Slice } from '../api/client';

interface SliceDetailProps {
  sliceId: number;
  onChanged: () => void;
}

function confidenceColor(confidence: number): string {
  if (confidence >= 0.8) return '#22c55e';
  if (confidence >= 0.5) return '#eab308';
  return '#ef4444';
}

export default function SliceDetail({ sliceId, onChanged }: SliceDetailProps) {
  const [data, setData] = useState<SliceFilesResponse | null>(null);
  const [showAddDialog, setShowAddDialog] = useState(false);

  const loadData = () => {
    fetchSliceFiles(sliceId).then(setData);
  };

  useEffect(() => {
    loadData();
  }, [sliceId]);

  const handleRemoveFile = async (fileId: number) => {
    await deleteFileAssignment(fileId, sliceId);
    loadData();
    onChanged();
  };

  if (!data) return <div className="slice-detail-loading">Loading...</div>;

  const totalFiles = data.packages.reduce((sum, p) => sum + p.files.length, 0);

  return (
    <div className="slice-detail">
      <div className="slice-detail-summary">
        <span>{totalFiles} file{totalFiles !== 1 ? 's' : ''} across {data.packages.length} package{data.packages.length !== 1 ? 's' : ''}</span>
        <button className="add-file-btn" onClick={() => setShowAddDialog(true)}>
          + Add File
        </button>
      </div>

      {data.packages.map(pkg => (
        <div key={pkg.id} className="slice-package-group">
          <div className="slice-package-name">{pkg.path}</div>
          {pkg.files.map(f => (
            <div key={f.id} className="slice-file-row">
              <span className="slice-file-path">{f.path.split('/').pop()}</span>
              <span
                className="confidence-pill"
                style={{ backgroundColor: confidenceColor(f.confidence) }}
              >
                {(f.confidence * 100).toFixed(0)}%
              </span>
              <span className="slice-file-status">{f.status}</span>
              <button
                className="remove-btn"
                onClick={() => handleRemoveFile(f.id)}
              >
                Remove
              </button>
            </div>
          ))}
        </div>
      ))}

      {data.packages.length === 0 && (
        <p className="no-files-msg">No files assigned to this slice.</p>
      )}

      {showAddDialog && (
        <AddFileDialog
          sliceId={sliceId}
          onClose={() => setShowAddDialog(false)}
          onAdded={() => { loadData(); onChanged(); }}
        />
      )}
    </div>
  );
}

interface AddFileDialogProps {
  sliceId: number;
  onClose: () => void;
  onAdded: () => void;
}

function AddFileDialog({ sliceId, onClose, onAdded }: AddFileDialogProps) {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<Array<{ id: number; path: string }>>([]);
  const [confidence, setConfidence] = useState(0.8);
  const [allSlices, setAllSlices] = useState<Slice[]>([]);

  useEffect(() => {
    fetchSlices().then(setAllSlices);
  }, []);

  useEffect(() => {
    if (query.length < 2) { setResults([]); return; }
    // Search files via the packages endpoint (not ideal but works)
    fetch(`/api/packages`).then(r => r.json()).then(async (pkgs: Array<{ id: number }>) => {
      const allFiles: Array<{ id: number; path: string }> = [];
      for (const pkg of pkgs) {
        const files = await fetch(`/api/packages/${pkg.id}/files`).then(r => r.json());
        for (const f of files) {
          if (f.path.toLowerCase().includes(query.toLowerCase())) {
            allFiles.push({ id: f.id, path: f.path });
          }
        }
      }
      setResults(allFiles);
    });
  }, [query]);

  const handleAdd = async (fileId: number) => {
    // Get current assignments for this file, then add the new one
    const current = await fetch(`/api/files/${fileId}/assignments`).then(r => r.json());
    const newAssignments = [
      ...current.map((a: { slice_id: number; confidence: number; status: string }) => ({
        slice_id: a.slice_id,
        confidence: a.confidence,
        status: a.status,
      })),
      { slice_id: sliceId, confidence, status: 'unreviewed' },
    ];
    await updateFileAssignments(fileId, newAssignments);
    onAdded();
    onClose();
  };

  // suppress unused warning
  void allSlices;

  return (
    <div className="add-file-dialog-overlay" onClick={onClose}>
      <div className="add-file-dialog" onClick={e => e.stopPropagation()}>
        <h4>Add File to Slice</h4>
        <input
          type="text"
          placeholder="Search files..."
          value={query}
          onChange={e => setQuery(e.target.value)}
          autoFocus
        />
        <label className="confidence-label">
          Confidence: {(confidence * 100).toFixed(0)}%
          <input
            type="range"
            min="0" max="1" step="0.05"
            value={confidence}
            onChange={e => setConfidence(Number(e.target.value))}
          />
        </label>
        <div className="file-search-results">
          {results.map(f => (
            <div key={f.id} className="file-search-item" onClick={() => handleAdd(f.id)}>
              {f.path}
            </div>
          ))}
          {query.length >= 2 && results.length === 0 && (
            <p className="no-results">No matching files.</p>
          )}
        </div>
        <button className="dialog-close-btn" onClick={onClose}>Cancel</button>
      </div>
    </div>
  );
}
