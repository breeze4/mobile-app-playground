import { useState, useEffect } from 'react';
import {
  fetchCoverage,
  fetchUnassignedFiles,
  fetchLowConfidenceFiles,
  fetchSlices,
  updateFileAssignments,
} from '../api/client';
import type {
  CoverageStats,
  UnassignedFile,
  LowConfidenceEntry,
  Slice,
} from '../api/client';

export default function CoverageDashboard() {
  const [stats, setStats] = useState<CoverageStats | null>(null);
  const [unassigned, setUnassigned] = useState<UnassignedFile[]>([]);
  const [lowConf, setLowConf] = useState<LowConfidenceEntry[]>([]);
  const [showUnassigned, setShowUnassigned] = useState(false);
  const [showLowConf, setShowLowConf] = useState(false);
  const [slices, setSlices] = useState<Slice[]>([]);
  const [assigningFileId, setAssigningFileId] = useState<number | null>(null);
  const [selectedSliceId, setSelectedSliceId] = useState<number | ''>('');
  const [confidence, setConfidence] = useState(0.8);

  const loadAll = () => {
    fetchCoverage().then(setStats);
    fetchSlices().then(setSlices);
  };

  useEffect(() => {
    loadAll();
  }, []);

  useEffect(() => {
    if (showUnassigned) fetchUnassignedFiles().then(setUnassigned);
  }, [showUnassigned]);

  useEffect(() => {
    if (showLowConf) fetchLowConfidenceFiles().then(setLowConf);
  }, [showLowConf]);

  const handleAssign = async (fileId: number) => {
    if (!selectedSliceId) return;
    await updateFileAssignments(fileId, [
      { slice_id: Number(selectedSliceId), confidence, status: 'unreviewed' },
    ]);
    setAssigningFileId(null);
    setSelectedSliceId('');
    setConfidence(0.8);
    // Reload everything
    loadAll();
    if (showUnassigned) fetchUnassignedFiles().then(setUnassigned);
    if (showLowConf) fetchLowConfidenceFiles().then(setLowConf);
  };

  if (!stats) return <div className="coverage-dashboard"><p>Loading...</p></div>;

  return (
    <div className="coverage-dashboard">
      <div className="coverage-header">
        <h2>Coverage Dashboard</h2>
      </div>

      <div className="coverage-bar-container">
        <div
          className="coverage-bar-fill"
          style={{ width: `${Math.max(stats.coverage_percent, 5)}%` }}
        >
          {stats.coverage_percent}%
        </div>
      </div>

      <div className="stats-cards">
        <div className="stat-card">
          <span className="stat-value">{stats.total_files}</span>
          <span className="stat-label">Total Files</span>
        </div>
        <div className="stat-card">
          <span className="stat-value">{stats.assigned_files}</span>
          <span className="stat-label">Assigned</span>
        </div>
        <div className="stat-card">
          <span className="stat-value" style={{ color: stats.unassigned_files > 0 ? '#ef4444' : '#22c55e' }}>
            {stats.unassigned_files}
          </span>
          <span className="stat-label">Unassigned</span>
        </div>
        <div className="stat-card">
          <span className="stat-value" style={{ color: stats.low_confidence_count > 0 ? '#eab308' : '#22c55e' }}>
            {stats.low_confidence_count}
          </span>
          <span className="stat-label">Low Confidence</span>
        </div>
      </div>

      <div className="dashboard-section">
        <h3>
          Unassigned Files
          <button
            className={`toggle-btn ${showUnassigned ? 'active' : ''}`}
            onClick={() => setShowUnassigned(!showUnassigned)}
          >
            {showUnassigned ? 'Hide' : 'Show'}
          </button>
        </h3>
        {showUnassigned && (
          <div className="dashboard-file-list">
            {unassigned.length === 0 ? (
              <div className="dashboard-file-row">
                <span style={{ color: '#22c55e' }}>All files are assigned.</span>
              </div>
            ) : (
              unassigned.map(f => (
                <div key={f.id} className="dashboard-file-row">
                  <span className="dashboard-file-path">{f.path}</span>
                  <span className="dashboard-file-pkg">{f.package_path}</span>
                  {assigningFileId === f.id ? (
                    <div className="inline-assign">
                      <select
                        value={selectedSliceId}
                        onChange={e => setSelectedSliceId(e.target.value ? Number(e.target.value) : '')}
                      >
                        <option value="">Select slice...</option>
                        {slices.map(s => (
                          <option key={s.id} value={s.id}>{s.name}</option>
                        ))}
                      </select>
                      <button onClick={() => handleAssign(f.id)} disabled={!selectedSliceId}>
                        Assign
                      </button>
                      <button onClick={() => setAssigningFileId(null)}>Cancel</button>
                    </div>
                  ) : (
                    <button className="assign-btn" onClick={() => setAssigningFileId(f.id)}>
                      Assign
                    </button>
                  )}
                </div>
              ))
            )}
          </div>
        )}
      </div>

      <div className="dashboard-section">
        <h3>
          Low Confidence Assignments (below {(stats.low_confidence_threshold * 100).toFixed(0)}%)
          <button
            className={`toggle-btn ${showLowConf ? 'active' : ''}`}
            onClick={() => setShowLowConf(!showLowConf)}
          >
            {showLowConf ? 'Hide' : 'Show'}
          </button>
        </h3>
        {showLowConf && (
          <div className="dashboard-file-list">
            {lowConf.length === 0 ? (
              <div className="dashboard-file-row">
                <span style={{ color: '#22c55e' }}>No low-confidence assignments.</span>
              </div>
            ) : (
              lowConf.map((entry, i) => (
                <div key={`${entry.file_id}-${entry.slice_id}-${i}`} className="dashboard-file-row">
                  <span className="dashboard-file-path">{entry.file_path}</span>
                  <span className="slice-badge" style={{
                    backgroundColor: entry.slice_type === 'vertical' ? '#1e3a5f' : '#3b1f5e',
                    color: entry.slice_type === 'vertical' ? '#93c5fd' : '#c4b5fd',
                  }}>
                    {entry.slice_name}
                  </span>
                  <span className="confidence-pill" style={{
                    backgroundColor: entry.confidence >= 0.5 ? '#eab308' : '#ef4444',
                    color: '#000',
                  }}>
                    {(entry.confidence * 100).toFixed(0)}%
                  </span>
                  <span className="slice-file-status">{entry.status}</span>
                </div>
              ))
            )}
          </div>
        )}
      </div>
    </div>
  );
}
