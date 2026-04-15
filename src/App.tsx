import { Routes, Route } from 'react-router-dom'
import Layout from './components/Layout'
import Home from './pages/Home'
import LicenseRenewal from './pages/LicenseRenewal'
import VehicleRegistration from './pages/VehicleRegistration'
import Appointments from './pages/Appointments'
import Documents from './pages/Documents'
import FAQ from './pages/FAQ'
import MyDMV from './pages/MyDMV'
import RealID from './pages/RealID'
import DealerDashboard from './pages/DealerDashboard'
import ElectronicLienTitle from './pages/ElectronicLienTitle'
import BulkRegistration from './pages/BulkRegistration'
import TempTags from './pages/TempTags'

export default function App() {
  return (
    <Layout>
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
    </Layout>
  )
}

