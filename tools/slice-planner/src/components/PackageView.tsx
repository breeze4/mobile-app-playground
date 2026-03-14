import { useState } from 'react';
import PackageTree from './PackageTree';
import FileDetail from './FileDetail';
import type { FileWithAssignments } from '../api/client';

export default function PackageView() {
  const [selectedFile, setSelectedFile] = useState<FileWithAssignments | null>(null);
  const [refreshKey, setRefreshKey] = useState(0);

  const handleAssignmentChanged = () => {
    setRefreshKey(k => k + 1);
    // Clear selection so it refreshes from API
    if (selectedFile) {
      setSelectedFile(null);
    }
  };

  return (
    <div className="package-view">
      <div className="sidebar">
        <PackageTree
          onFileSelect={setSelectedFile}
          selectedFileId={selectedFile?.id ?? null}
          refreshKey={refreshKey}
          onRefresh={handleAssignmentChanged}
        />
      </div>
      <div className="main-content">
        {selectedFile ? (
          <FileDetail
            file={selectedFile}
            onAssignmentChanged={handleAssignmentChanged}
          />
        ) : (
          <div className="empty-state">
            <p>Select a file from the package tree to view and edit assignments.</p>
          </div>
        )}
      </div>
    </div>
  );
}
