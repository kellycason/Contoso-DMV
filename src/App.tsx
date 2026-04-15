import { Routes, Route } from 'react-router-dom'
import Layout from './components/Layout'
import Home from './pages/Home'
import LicenseRenewal from './pages/LicenseRenewal'
import VehicleRegistration from './pages/VehicleRegistration'
import Appointments from './pages/Appointments'
import Documents from './pages/Documents'
import FAQ from './pages/FAQ'

export default function App() {
  return (
    <Layout>
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/license-renewal" element={<LicenseRenewal />} />
        <Route path="/vehicle-registration" element={<VehicleRegistration />} />
        <Route path="/appointments" element={<Appointments />} />
        <Route path="/documents" element={<Documents />} />
        <Route path="/faq" element={<FAQ />} />
      </Routes>
    </Layout>
  )
}

