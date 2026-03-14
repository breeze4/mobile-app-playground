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

export async function fetchSlices(): Promise<Slice[]> {
  const res = await fetch(`${BASE}/slices`);
  return res.json();
}
