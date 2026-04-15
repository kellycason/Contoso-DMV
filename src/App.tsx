import { lazy, Suspense } from 'react'
import { Routes, Route } from 'react-router-dom'
import Layout from './components/Layout'

const Home = lazy(() => import('./pages/Home'))
const LicenseRenewal = lazy(() => import('./pages/LicenseRenewal'))
const VehicleRegistration = lazy(() => import('./pages/VehicleRegistration'))
const Appointments = lazy(() => import('./pages/Appointments'))
const Documents = lazy(() => import('./pages/Documents'))
const FAQ = lazy(() => import('./pages/FAQ'))
const MyDMV = lazy(() => import('./pages/MyDMV'))
const RealID = lazy(() => import('./pages/RealID'))
const DealerDashboard = lazy(() => import('./pages/DealerDashboard'))
const ElectronicLienTitle = lazy(() => import('./pages/ElectronicLienTitle'))
const BulkRegistration = lazy(() => import('./pages/BulkRegistration'))
const TempTags = lazy(() => import('./pages/TempTags'))

export default function App() {
  return (
    <Layout>
      <Suspense fallback={<div style={{ padding: '48px', textAlign: 'center' }}>Loading...</div>}>
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/my-dmv" element={<MyDMV />} />
          <Route path="/license-renewal" element={<LicenseRenewal />} />
          <Route path="/vehicle-registration" element={<VehicleRegistration />} />
          <Route path="/real-id" element={<RealID />} />
          <Route path="/appointments" element={<Appointments />} />
          <Route path="/documents" element={<Documents />} />
          <Route path="/faq" element={<FAQ />} />
          <Route path="/dealer" element={<DealerDashboard />} />
          <Route path="/dealer/elt" element={<ElectronicLienTitle />} />
          <Route path="/dealer/bulk" element={<BulkRegistration />} />
          <Route path="/dealer/temp-tags" element={<TempTags />} />
        </Routes>
      </Suspense>
    </Layout>
  )
}

