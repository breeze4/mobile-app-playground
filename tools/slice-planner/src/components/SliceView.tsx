import { useState, useEffect } from 'react';
import { fetchSlices } from '../api/client';
import type { Slice } from '../api/client';
import SliceDetail from './SliceDetail';

type TypeFilter = 'all' | 'vertical' | 'horizontal';

export default function SliceView() {
  const [slices, setSlices] = useState<Slice[]>([]);
  const [filter, setFilter] = useState<TypeFilter>('all');
  const [expandedId, setExpandedId] = useState<number | null>(null);
  const [refreshKey, setRefreshKey] = useState(0);

  useEffect(() => {
    const type = filter === 'all' ? undefined : filter;
    fetchSlices(type).then(setSlices);
  }, [filter, refreshKey]);

  const handleToggle = (id: number) => {
    setExpandedId(prev => (prev === id ? null : id));
  };

  const handleChanged = () => {
    setRefreshKey(k => k + 1);
  };

  return (
    <div className="slice-view">
      <div className="slice-view-header">
        <h2>Slices</h2>
        <div className="type-filter">
          {(['all', 'vertical', 'horizontal'] as TypeFilter[]).map(t => (
            <button
              key={t}
              className={`filter-btn ${filter === t ? 'active' : ''}`}
              onClick={() => setFilter(t)}
            >
              {t.charAt(0).toUpperCase() + t.slice(1)}
            </button>
          ))}
        </div>
      </div>
      <div className="slice-list">
        {slices.map(s => (
          <div key={s.id} className="slice-card">
            <div className="slice-card-header" onClick={() => handleToggle(s.id)}>
              <span className="expand-icon">
                {expandedId === s.id ? '\u25BC' : '\u25B6'}
              </span>
              <span className="slice-card-name">{s.name}</span>
              <span className={`type-badge type-${s.type}`}>{s.type}</span>
              <span className="slice-card-desc">{s.description}</span>
            </div>
            {expandedId === s.id && (
              <SliceDetail sliceId={s.id} onChanged={handleChanged} />
            )}
          </div>
        ))}
        {slices.length === 0 && (
          <div className="empty-state">
            <p>No slices found.</p>
          </div>
        )}
      </div>
    </div>
  );
}
