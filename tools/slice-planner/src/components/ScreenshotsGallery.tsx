import { useState } from 'react'
import { reportArtifactUrl } from '../api/client'

interface ScreenshotsGalleryProps {
  flowName: string;
  sliceName: string;
  oldScreenshots: string[];
  newScreenshots: string[];
}

export default function ScreenshotsGallery({ flowName, sliceName, oldScreenshots, newScreenshots }: ScreenshotsGalleryProps) {
  const [expandedImg, setExpandedImg] = useState<string | null>(null);
  const [compareMode, setCompareMode] = useState(false);
  const [failedImages, setFailedImages] = useState<Set<string>>(new Set());

  const handleImageError = (path: string) => {
    setFailedImages(prev => new Set(prev).add(path));
  };

  const labelFromPath = (p: string) => {
    const name = p.split('/').pop() || p;
    return name.replace(/\.[^.]+$/, '').replace(/[-_]/g, ' ');
  };

  if (oldScreenshots.length === 0 && newScreenshots.length === 0) {
    return null;
  }

  const maxLen = Math.max(oldScreenshots.length, newScreenshots.length);

  return (
    <div className="screenshots-gallery">
      <div className="gallery-header">
        <h4 className="flow-name">{flowName}</h4>
        <button className={`filter-btn ${compareMode ? 'active' : ''}`}
          onClick={() => setCompareMode(!compareMode)}>
          Side-by-side
        </button>
      </div>

      {compareMode ? (
        <div className="comparison-grid">
          {Array.from({ length: maxLen }, (_, i) => (
            <div key={i} className="comparison-row">
              <div className="comparison-cell">
                <div className="comparison-label">Old App</div>
                {oldScreenshots[i] && !failedImages.has(oldScreenshots[i]) ? (
                  <img
                    src={reportArtifactUrl(sliceName, oldScreenshots[i])}
                    alt={labelFromPath(oldScreenshots[i])}
                    className="screenshot-thumb"
                    onClick={() => setExpandedImg(reportArtifactUrl(sliceName, oldScreenshots[i]))}
                    onError={() => handleImageError(oldScreenshots[i])}
                  />
                ) : (
                  <div className="screenshot-missing">No screenshot</div>
                )}
                {oldScreenshots[i] && <div className="screenshot-label">{labelFromPath(oldScreenshots[i])}</div>}
              </div>
              <div className="comparison-cell">
                <div className="comparison-label">New App</div>
                {newScreenshots[i] && !failedImages.has(newScreenshots[i]) ? (
                  <img
                    src={reportArtifactUrl(sliceName, newScreenshots[i])}
                    alt={labelFromPath(newScreenshots[i])}
                    className="screenshot-thumb"
                    onClick={() => setExpandedImg(reportArtifactUrl(sliceName, newScreenshots[i]))}
                    onError={() => handleImageError(newScreenshots[i])}
                  />
                ) : (
                  <div className="screenshot-missing">No screenshot</div>
                )}
                {newScreenshots[i] && <div className="screenshot-label">{labelFromPath(newScreenshots[i])}</div>}
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="screenshot-grid">
          {[...oldScreenshots.map(s => ({ path: s, label: 'old' })), ...newScreenshots.map(s => ({ path: s, label: 'new' }))].map(({ path, label }) => (
            !failedImages.has(path) ? (
              <div key={`${label}-${path}`} className="screenshot-item">
                <img
                  src={reportArtifactUrl(sliceName, path)}
                  alt={labelFromPath(path)}
                  className="screenshot-thumb"
                  onClick={() => setExpandedImg(reportArtifactUrl(sliceName, path))}
                  onError={() => handleImageError(path)}
                />
                <div className="screenshot-label">
                  <span className={`screenshot-app-badge ${label === 'old' ? 'badge-old' : 'badge-new'}`}>{label}</span>
                  {labelFromPath(path)}
                </div>
              </div>
            ) : null
          ))}
        </div>
      )}

      {expandedImg && (
        <div className="lightbox-overlay" onClick={() => setExpandedImg(null)}>
          <div className="lightbox-content" onClick={e => e.stopPropagation()}>
            <img src={expandedImg} alt="Expanded screenshot" className="lightbox-img" />
            <button className="lightbox-close" onClick={() => setExpandedImg(null)}>Close</button>
          </div>
        </div>
      )}
    </div>
  );
}
