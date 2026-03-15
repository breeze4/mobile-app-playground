import { useState, useEffect } from 'react'
import type { ReportListItem } from '../api/client'
import { fetchReports } from '../api/client'
import ReportPage from './ReportPage'

type StatusFilter = 'all' | 'complete' | 'pending';
type TypeFilter = 'all' | 'vertical' | 'horizontal';

export default function ReportsView() {
  const [reports, setReports] = useState<ReportListItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedSlice, setSelectedSlice] = useState<string | null>(null);
  const [statusFilter, setStatusFilter] = useState<StatusFilter>('all');
  const [typeFilter, setTypeFilter] = useState<TypeFilter>('all');

  useEffect(() => {
    fetchReports()
      .then(setReports)
      .catch(() => setReports([]))
      .finally(() => setLoading(false));
  }, []);

  if (selectedSlice) {
    return <ReportPage sliceName={selectedSlice} onBack={() => setSelectedSlice(null)} />;
  }

  const filtered = reports.filter(r => {
    if (statusFilter !== 'all' && r.status !== statusFilter) return false;
    if (typeFilter !== 'all' && r.slice_type !== typeFilter) return false;
    return true;
  });

  return (
    <div className="reports-view">
      <div className="reports-header">
        <h2>Reports</h2>
        <div className="reports-filters">
          <div className="type-filter">
            {(['all', 'complete', 'pending'] as StatusFilter[]).map(s => (
              <button key={s} className={`filter-btn ${statusFilter === s ? 'active' : ''}`}
                onClick={() => setStatusFilter(s)}>
                {s.charAt(0).toUpperCase() + s.slice(1)}
              </button>
            ))}
          </div>
          <div className="type-filter">
            {(['all', 'vertical', 'horizontal'] as TypeFilter[]).map(t => (
              <button key={t} className={`filter-btn ${typeFilter === t ? 'active' : ''}`}
                onClick={() => setTypeFilter(t)}>
                {t.charAt(0).toUpperCase() + t.slice(1)}
              </button>
            ))}
          </div>
        </div>
      </div>

      {loading && <div className="reports-loading">Loading reports...</div>}

      {!loading && filtered.length === 0 && (
        <div className="reports-empty">No reports found.</div>
      )}

      {!loading && filtered.length > 0 && (
        <div className="reports-list">
          {filtered.map(r => (
            <div key={r.slice_name} className={`report-card report-status-${r.status}`}
              onClick={() => r.status === 'complete' ? setSelectedSlice(r.slice_name) : undefined}
              style={{ cursor: r.status === 'complete' ? 'pointer' : 'default' }}>
              <div className="report-card-header">
                <span className="report-card-name">{r.slice_name}</span>
                {r.slice_type && (
                  <span className={`type-badge type-${r.slice_type}`}>{r.slice_type}</span>
                )}
                <span className={`report-status-badge status-${r.status}`}>{r.status}</span>
              </div>
              {r.description && <div className="report-card-desc">{r.description}</div>}
              {r.generated_at && (
                <div className="report-card-date">
                  Generated: {new Date(r.generated_at).toLocaleString()}
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
