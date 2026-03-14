import YAML from 'yaml';

// Types matching the slice-mapping YAML schema (Schema 3 from docs/schemas/slice-schemas.md)

export interface SliceMappingFile {
  version: string;
  kind: 'slice-mapping';
  generated_at: string;
  slices: SliceDefinition[];
  packages: PackageDefinition[];
  files: FileMappingEntry[];
  unassigned: UnassignedEntry[];
  summary: MappingSummary;
}

export interface SliceDefinition {
  name: string;
  type: 'vertical' | 'horizontal';
  description: string;
}

export interface PackageDefinition {
  path: string;
  name: string;
}

export interface FileAssignment {
  slice: string;
  confidence: number;
}

export interface FileMappingEntry {
  path: string;
  package: string;
  assignments: FileAssignment[];
}

export interface UnassignedEntry {
  path: string;
  package: string;
  reason: string;
}

export interface MappingSummary {
  total_files: number;
  assigned_files: number;
  unassigned_files: number;
  coverage_percent: number;
  low_confidence_count: number;
}

export interface ValidationError {
  field: string;
  message: string;
}

export function parseYaml(yamlString: string): unknown {
  return YAML.parse(yamlString);
}

export function validate(data: unknown): { valid: true; data: SliceMappingFile } | { valid: false; errors: ValidationError[] } {
  const errors: ValidationError[] = [];

  if (!data || typeof data !== 'object') {
    return { valid: false, errors: [{ field: 'root', message: 'Expected an object' }] };
  }

  const obj = data as Record<string, unknown>;

  // Check version
  if (obj.version !== '1') {
    errors.push({ field: 'version', message: `Expected "1", got "${obj.version}"` });
  }

  // Check kind
  if (obj.kind !== 'slice-mapping') {
    errors.push({ field: 'kind', message: `Expected "slice-mapping", got "${obj.kind}"` });
  }

  // Check generated_at
  if (!obj.generated_at || typeof obj.generated_at !== 'string') {
    errors.push({ field: 'generated_at', message: 'Required string field' });
  }

  // Check slices
  if (!Array.isArray(obj.slices)) {
    errors.push({ field: 'slices', message: 'Must be an array' });
  } else {
    for (let i = 0; i < obj.slices.length; i++) {
      const s = obj.slices[i] as Record<string, unknown>;
      if (!s.name || typeof s.name !== 'string') {
        errors.push({ field: `slices[${i}].name`, message: 'Required string' });
      }
      if (s.type !== 'vertical' && s.type !== 'horizontal') {
        errors.push({ field: `slices[${i}].type`, message: 'Must be "vertical" or "horizontal"' });
      }
      if (!s.description || typeof s.description !== 'string') {
        errors.push({ field: `slices[${i}].description`, message: 'Required string' });
      }
    }
  }

  // Check packages
  if (!Array.isArray(obj.packages)) {
    errors.push({ field: 'packages', message: 'Must be an array' });
  } else {
    for (let i = 0; i < obj.packages.length; i++) {
      const p = obj.packages[i] as Record<string, unknown>;
      if (!p.path || typeof p.path !== 'string') {
        errors.push({ field: `packages[${i}].path`, message: 'Required string' });
      }
      if (!p.name || typeof p.name !== 'string') {
        errors.push({ field: `packages[${i}].name`, message: 'Required string' });
      }
    }
  }

  // Check files
  if (!Array.isArray(obj.files)) {
    errors.push({ field: 'files', message: 'Must be an array' });
  } else {
    for (let i = 0; i < obj.files.length; i++) {
      const f = obj.files[i] as Record<string, unknown>;
      if (!f.path || typeof f.path !== 'string') {
        errors.push({ field: `files[${i}].path`, message: 'Required string' });
      }
      if (!f.package || typeof f.package !== 'string') {
        errors.push({ field: `files[${i}].package`, message: 'Required string' });
      }
      if (!Array.isArray(f.assignments)) {
        errors.push({ field: `files[${i}].assignments`, message: 'Must be an array' });
      }
    }
  }

  // Check unassigned
  if (!Array.isArray(obj.unassigned)) {
    errors.push({ field: 'unassigned', message: 'Must be an array' });
  }

  if (errors.length > 0) {
    return { valid: false, errors };
  }

  return { valid: true, data: data as SliceMappingFile };
}
