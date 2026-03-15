import { useState } from 'react'
import PackageView from './components/PackageView'
import SliceView from './components/SliceView'
import CoverageDashboard from './components/CoverageDashboard'
import ExportView from './components/ExportView'
import ReportsView from './components/ReportsView'
import './App.css'

type Tab = 'packages' | 'slices' | 'coverage' | 'export' | 'reports';

function App() {
  const [activeTab, setActiveTab] = useState<Tab>('packages');

  return (
    <div className="app">
      <header className="app-header">
        <h1>Slice Planner</h1>
        <nav className="app-nav">
          {([
            ['packages', 'Packages'],
            ['slices', 'Slices'],
            ['coverage', 'Coverage'],
            ['export', 'Export'],
            ['reports', 'Reports'],
          ] as [Tab, string][]).map(([key, label]) => (
            <button
              key={key}
              className={`nav-btn ${activeTab === key ? 'active' : ''}`}
              onClick={() => setActiveTab(key)}
            >
              {label}
            </button>
          ))}
        </nav>
      </header>
      {activeTab === 'packages' && <PackageView />}
      {activeTab === 'slices' && <SliceView />}
      {activeTab === 'coverage' && <CoverageDashboard />}
      {activeTab === 'export' && <ExportView />}
      {activeTab === 'reports' && <ReportsView />}
    </div>
  )
}

export default App
