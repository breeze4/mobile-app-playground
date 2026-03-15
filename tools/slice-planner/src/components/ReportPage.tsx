import { useState, useEffect } from 'react'
import type { SliceReport } from '../api/client'
import { fetchReport } from '../api/client'
import VideoPlayer from './VideoPlayer'
import ScreenshotsGallery from './ScreenshotsGallery'

interface ReportPageProps {
  sliceName: string;
  onBack: () => void;
}

export default function ReportPage({ sliceName, onBack }: ReportPageProps) {
  const [report, setReport] = useState<SliceReport | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetchReport(sliceName)
      .then(setReport)
      .catch(e => setError(e.message))
      .finally(() => setLoading(false));
  }, [sliceName]);

  if (loading) return <div className="report-page"><div className="reports-loading">Loading report...</div></div>;
  if (error) return <div className="report-page"><div className="report-error">{error}</div></div>;
  if (!report) return null;

  const flowNames = Array.from(new Set([
    ...Object.keys(report.artifacts.old_app || {}),
    ...Object.keys(report.artifacts.new_app || {}),
  ]));

  return (
    <div className="report-page">
      <button className="report-back-btn" onClick={onBack}>Back to Reports</button>

      <div className="report-header">
        <h2>{report.slice_name}</h2>
        <span className={`type-badge type-${report.slice_type}`}>{report.slice_type}</span>
        <span className="report-status-badge status-complete">complete</span>
      </div>
      <p className="report-description">{report.description}</p>
      <div className="report-meta">Generated: {new Date(report.generated_at).toLocaleString()}</div>

      {/* Files section */}
      <section className="report-section">
        <h3>Files ({report.files.length})</h3>
        <div className="report-file-list">
          {report.files.map(f => (
            <div key={f} className="report-file-item">{f}</div>
          ))}
        </div>
      </section>

      {/* Test cases section */}
      <section className="report-section">
        <h3>Test Cases ({report.test_cases.length})</h3>
        {report.test_cases.map((tc, i) => (
          <div key={i} className="test-case-card">
            <div className="test-case-name">{tc.name}</div>
            <div className="gwt-section">
              <div className="gwt-row"><span className="gwt-label">Given</span> {tc.given}</div>
              <div className="gwt-row"><span className="gwt-label">When</span> {tc.when}</div>
              <div className="gwt-row"><span className="gwt-label">Then</span> {tc.then}</div>
            </div>
            {tc.assertions.length > 0 && (
              <div className="test-assertions">
                <span className="assertions-label">Assertions:</span>
                <ul>
                  {tc.assertions.map((a, j) => <li key={j}>{a}</li>)}
                </ul>
              </div>
            )}
          </div>
        ))}
      </section>

      {/* Test results table */}
      <section className="report-section">
        <h3>Test Results</h3>
        <table className="results-table">
          <thead>
            <tr>
              <th>Flow</th>
              <th>Old App</th>
              <th>Duration</th>
              <th>New App</th>
              <th>Duration</th>
            </tr>
          </thead>
          <tbody>
            {report.test_results.map((tr, i) => (
              <tr key={i}>
                <td>{tr.flow_name}</td>
                <td className={tr.old_app.passed ? 'result-pass' : 'result-fail'}>
                  {tr.old_app.passed ? 'PASS' : 'FAIL'}
                </td>
                <td className="result-duration">{tr.old_app.duration_ms}ms</td>
                <td className={tr.new_app.passed ? 'result-pass' : 'result-fail'}>
                  {tr.new_app.passed ? 'PASS' : 'FAIL'}
                </td>
                <td className="result-duration">{tr.new_app.duration_ms}ms</td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>

      {/* Video players per flow */}
      {flowNames.length > 0 && (
        <section className="report-section">
          <h3>Video Recordings</h3>
          {flowNames.map(flow => (
            <div key={flow} className="flow-videos">
              <h4 className="flow-name">{flow}</h4>
              <div className="video-comparison">
                <div className="video-side">
                  <div className="video-side-label">Old App</div>
                  <VideoPlayer
                    sliceName={sliceName}
                    videoPath={report.artifacts.old_app[flow]?.video}
                    stepTimings={report.step_timings}
                    videoOffsetSeconds={report.video_offset_seconds}
                  />
                </div>
                <div className="video-side">
                  <div className="video-side-label">New App</div>
                  <VideoPlayer
                    sliceName={sliceName}
                    videoPath={report.artifacts.new_app[flow]?.video}
                    stepTimings={report.step_timings}
                    videoOffsetSeconds={report.video_offset_seconds}
                  />
                </div>
              </div>
            </div>
          ))}
        </section>
      )}

      {/* Screenshots gallery per flow */}
      {flowNames.length > 0 && (
        <section className="report-section">
          <h3>Screenshots</h3>
          {flowNames.map(flow => (
            <ScreenshotsGallery
              key={flow}
              flowName={flow}
              sliceName={sliceName}
              oldScreenshots={report.artifacts.old_app[flow]?.screenshots || []}
              newScreenshots={report.artifacts.new_app[flow]?.screenshots || []}
            />
          ))}
        </section>
      )}
    </div>
  );
}
