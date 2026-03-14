import type { Assignment } from '../api/client';

interface SliceBadgeProps {
  assignment: Assignment;
}

function confidenceColor(confidence: number): string {
  if (confidence >= 0.8) return '#22c55e'; // green
  if (confidence >= 0.5) return '#eab308'; // yellow
  return '#ef4444'; // red
}

export default function SliceBadge({ assignment }: SliceBadgeProps) {
  const bg = confidenceColor(assignment.confidence);
  const textColor = assignment.confidence >= 0.5 ? '#000' : '#fff';

  return (
    <span
      className="slice-badge"
      style={{ backgroundColor: bg, color: textColor }}
      title={`${assignment.slice_name} (${(assignment.confidence * 100).toFixed(0)}%) - ${assignment.status}`}
    >
      {assignment.slice_name}
    </span>
  );
}
