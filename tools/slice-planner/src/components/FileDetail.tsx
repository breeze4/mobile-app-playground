import { useState, useEffect } from 'react';
import { fetchSlices, updateFileAssignments } from '../api/client';
import type { FileWithAssignments, Slice, Assignment } from '../api/client';
import SliceBadge from './SliceBadge';

interface FileDetailProps {
  file: FileWithAssignments;
  onAssignmentChanged: () => void;
}

export default function FileDetail({ file, onAssignmentChanged }: FileDetailProps) {
  const [slices, setSlices] = useState<Slice[]>([]);
  const [selectedSliceId, setSelectedSliceId] = useState<number | ''>('');
  const [confidence, setConfidence] = useState(0.8);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    fetchSlices().then(setSlices);
  }, []);

  const assignedSliceIds = new Set(file.assignments.map(a => a.slice_id));
  const availableSlices = slices.filter(s => !assignedSliceIds.has(s.id));

  const handleAdd = async () => {
    if (!selectedSliceId) return;
    setSaving(true);

    const newAssignments = [
      ...file.assignments.map(a => ({
        slice_id: a.slice_id,
        confidence: a.confidence,
        status: a.status,
      })),
      { slice_id: Number(selectedSliceId), confidence, status: 'unreviewed' },
    ];

    await updateFileAssignments(file.id, newAssignments);
    setSelectedSliceId('');
    setConfidence(0.8);
    setSaving(false);
    onAssignmentChanged();
  };

  const handleRemove = async (sliceId: number) => {
    setSaving(true);
    const newAssignments = file.assignments
      .filter(a => a.slice_id !== sliceId)
      .map(a => ({
        slice_id: a.slice_id,
        confidence: a.confidence,
        status: a.status,
      }));

    await updateFileAssignments(file.id, newAssignments);
    setSaving(false);
    onAssignmentChanged();
  };

  return (
    <div className="file-detail">
      <h3>{file.path}</h3>

      <div className="current-assignments">
        <h4>Current Assignments</h4>
        {file.assignments.length === 0 ? (
          <p className="no-assignments">No slice assignments</p>
        ) : (
          <ul className="assignment-list">
            {file.assignments.map((a: Assignment) => (
              <li key={a.slice_id} className="assignment-item">
                <SliceBadge assignment={a} />
                <span className="confidence-value">{(a.confidence * 100).toFixed(0)}%</span>
                <span className="status-label">{a.status}</span>
                <button
                  className="remove-btn"
                  onClick={() => handleRemove(a.slice_id)}
                  disabled={saving}
                >
                  Remove
                </button>
              </li>
            ))}
          </ul>
        )}
      </div>

      <div className="add-assignment">
        <h4>Add Assignment</h4>
        <div className="add-form">
          <select
            value={selectedSliceId}
            onChange={e => setSelectedSliceId(e.target.value ? Number(e.target.value) : '')}
          >
            <option value="">Select a slice...</option>
            {availableSlices.map(s => (
              <option key={s.id} value={s.id}>
                {s.name} ({s.type})
              </option>
            ))}
          </select>
          <label>
            Confidence: {(confidence * 100).toFixed(0)}%
            <input
              type="range"
              min="0"
              max="1"
              step="0.05"
              value={confidence}
              onChange={e => setConfidence(Number(e.target.value))}
            />
          </label>
          <button onClick={handleAdd} disabled={!selectedSliceId || saving}>
            Assign
          </button>
        </div>
      </div>
    </div>
  );
}
