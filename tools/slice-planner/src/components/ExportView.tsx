import { useState, useEffect } from 'react';
import { fetchCoverage } from '../api/client';
import type { CoverageStats } from '../api/client';

export default function ExportView() {
  const [stats, setStats] = useState<CoverageStats | null>(null);
  const [downloading, setDownloading] = useState(false);

  useEffect(() => {
    fetchCoverage().then(setStats);
  }, []);

  const handleDownload = async () => {
    setDownloading(true);
    try {
      const res = await fetch('/api/export');
      const blob = await res.blob();
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = 'slice-mapping.yaml';
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
    } finally {
      setDownloading(false);
    }
  };

  return (
    <div className="export-view">
      <h2>Export Slice Mapping</h2>

      {stats && (
        <div className="export-preview">
          <h3 style={{ margin: '0 0 12px', fontSize: '0.95rem', color: '#aaa' }}>Export Preview</h3>
          <div className="export-stats">
            <div className="export-stat-row">
              <span>Coverage:</span>
              <strong>{stats.coverage_percent}%</strong>
            </div>
            <div className="export-stat-row">
              <span>Total files:</span>
              <strong>{stats.total_files}</strong>
            </div>
            <div className="export-stat-row">
              <span>Assigned files:</span>
              <strong>{stats.assigned_files}</strong>
            </div>
            <div className="export-stat-row">
              <span>Unassigned files:</span>
              <strong style={{ color: stats.unassigned_files > 0 ? '#ef4444' : '#22c55e' }}>
                {stats.unassigned_files}
              </strong>
            </div>
            <div className="export-stat-row">
              <span>Low confidence assignments:</span>
              <strong style={{ color: stats.low_confidence_count > 0 ? '#eab308' : '#22c55e' }}>
                {stats.low_confidence_count}
              </strong>
            </div>
          </div>

          {stats.unassigned_files > 0 && (
            <div className="export-warning">
              {stats.unassigned_files} file{stats.unassigned_files !== 1 ? 's' : ''} will be exported
              as unassigned. Consider assigning them before exporting.
            </div>
          )}
        </div>
      )}

      <button
        className="export-btn"
        onClick={handleDownload}
        disabled={downloading}
      >
        {downloading ? 'Downloading...' : 'Download YAML'}
      </button>

      <p className="export-note">
        Exports a YAML file matching the <code>slice-mapping</code> schema.
        {stats && stats.assigned_files > 0 && ' Includes all assignments with their confidence scores.'}
      </p>
    </div>
  );
}
