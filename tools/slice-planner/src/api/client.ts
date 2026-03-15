const BASE = '/api';

export interface Package {
  id: number;
  path: string;
  name: string;
  file_count: number;
  unassigned_count: number;
}

export interface Assignment {
  slice_id: number;
  slice_name: string;
  slice_type: string;
  confidence: number;
  status: string;
}

export interface FileWithAssignments {
  id: number;
  path: string;
  assignments: Assignment[];
}

export interface Slice {
  id: number;
  name: string;
  type: string;
  description: string;
}

export async function fetchPackages(): Promise<Package[]> {
  const res = await fetch(`${BASE}/packages`);
  return res.json();
}

export async function fetchPackageFiles(packageId: number): Promise<FileWithAssignments[]> {
  const res = await fetch(`${BASE}/packages/${packageId}/files`);
  return res.json();
}

export async function fetchFileAssignments(fileId: number): Promise<Assignment[]> {
  const res = await fetch(`${BASE}/files/${fileId}/assignments`);
  return res.json();
}

export async function updateFileAssignments(
  fileId: number,
  assignments: Array<{ slice_id: number; confidence: number; status?: string }>
): Promise<Assignment[]> {
  const res = await fetch(`${BASE}/files/${fileId}/assignments`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(assignments),
  });
  return res.json();
}

export async function bulkAssignPackage(
  packageId: number,
  sliceId: number,
  confidence: number
): Promise<{ assigned: number }> {
  const res = await fetch(`${BASE}/packages/${packageId}/assignments`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ slice_id: sliceId, confidence }),
  });
  return res.json();
}

export async function fetchSlices(type?: 'vertical' | 'horizontal'): Promise<Slice[]> {
  const params = type ? `?type=${type}` : '';
  const res = await fetch(`${BASE}/slices${params}`);
  return res.json();
}

export interface SliceFileEntry {
  id: number;
  path: string;
  confidence: number;
  status: string;
}

export interface SlicePackageGroup {
  id: number;
  path: string;
  name: string;
  files: SliceFileEntry[];
}

export interface SliceFilesResponse {
  slice: Slice;
  packages: SlicePackageGroup[];
}

export async function fetchSliceFiles(sliceId: number): Promise<SliceFilesResponse> {
  const res = await fetch(`${BASE}/slices/${sliceId}/files`);
  return res.json();
}

export async function deleteFileAssignment(fileId: number, sliceId: number): Promise<void> {
  await fetch(`${BASE}/files/${fileId}/assignments/${sliceId}`, { method: 'DELETE' });
}

export interface CoverageStats {
  total_files: number;
  assigned_files: number;
  unassigned_files: number;
  coverage_percent: number;
  low_confidence_count: number;
  low_confidence_threshold: number;
}

export async function fetchCoverage(): Promise<CoverageStats> {
  const res = await fetch(`${BASE}/coverage`);
  return res.json();
}

export interface UnassignedFile {
  id: number;
  path: string;
  package_path: string;
  package_name: string;
}

export async function fetchUnassignedFiles(): Promise<UnassignedFile[]> {
  const res = await fetch(`${BASE}/files/unassigned`);
  return res.json();
}

export interface LowConfidenceEntry {
  file_id: number;
  file_path: string;
  slice_id: number;
  slice_name: string;
  slice_type: string;
  confidence: number;
  status: string;
  package_path: string;
  package_name: string;
}

export async function fetchLowConfidenceFiles(threshold?: number): Promise<LowConfidenceEntry[]> {
  const params = threshold ? `?threshold=${threshold}` : '';
  const res = await fetch(`${BASE}/files/low-confidence${params}`);
  return res.json();
}

// Reports

export interface ReportListItem {
  slice_name: string;
  status: 'complete' | 'pending';
  slice_type?: 'vertical' | 'horizontal';
  description?: string;
  generated_at?: string;
}

export interface TestCase {
  name: string;
  given: string;
  when: string;
  then: string;
  assertions: string[];
}

export interface TestResult {
  flow_name: string;
  old_app: { passed: boolean; duration_ms: number };
  new_app: { passed: boolean; duration_ms: number };
}

export interface FlowArtifacts {
  video: string;
  screenshots: string[];
  results: string;
}

export interface StepTiming {
  step: string;
  start_seconds: number;
  duration_seconds: number;
}

export interface SliceReport {
  slice_name: string;
  slice_type: 'vertical' | 'horizontal';
  description: string;
  files: string[];
  test_cases: TestCase[];
  test_results: TestResult[];
  artifacts: {
    old_app: Record<string, FlowArtifacts>;
    new_app: Record<string, FlowArtifacts>;
  };
  step_timings: StepTiming[];
  video_offset_seconds: number;
  generated_at: string;
}

export async function fetchReports(): Promise<ReportListItem[]> {
  const res = await fetch(`${BASE}/reports`);
  return res.json();
}

export async function fetchReport(sliceName: string): Promise<SliceReport> {
  const res = await fetch(`${BASE}/reports/${encodeURIComponent(sliceName)}`);
  if (!res.ok) throw new Error(`Report not found: ${sliceName}`);
  return res.json();
}

export function reportArtifactUrl(sliceName: string, artifactPath: string): string {
  return `${BASE}/reports/${encodeURIComponent(sliceName)}/artifacts/${artifactPath}`;
}
