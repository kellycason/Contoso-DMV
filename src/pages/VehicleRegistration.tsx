import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { dvCreate } from '../hooks/useDataverse'
import { useAuth } from '../hooks/useAuth'

const plateTypeMap: Record<string, number> = {
  standard: 100000000, personalized: 100000001, veteran: 100000002, disability: 100000003,
}

export default function VehicleRegistration() {
  useEffect(() => { document.title = 'Vehicle Registration — Contoso DMV' }, [])
  const { userId } = useAuth()

  const [submitted, setSubmitted] = useState(false)
  const [submitting, setSubmitting] = useState(false)
  const [refNumber, setRefNumber] = useState('')
  const [submitError, setSubmitError] = useState('')
  const [form, setForm] = useState({
    vin: '',
    make: '',
    model: '',
    year: '',
    color: '',
    plateType: 'standard',
    firstName: '',
    lastName: '',
    email: '',
    phone: '',
    address: '',
    city: '',
    zip: '',
    insurer: '',
    policyNumber: '',
    policyExp: '',
  })

  const handle = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) =>
    setForm(f => ({ ...f, [e.target.name]: e.target.value }))

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setSubmitting(true)
    setSubmitError('')
    try {
      // 1. Create vehicle
      const vehicleId = await dvCreate('dmv_vehicles', {
        dmv_vin: form.vin,
        dmv_make: form.make,
        dmv_model: form.model,
        dmv_year: parseInt(form.year),
        dmv_color: form.color,
        dmv_platetype: plateTypeMap[form.plateType] ?? 100000000,
        dmv_salvagetitle: false,
        dmv_outofstate: false,
        dmv_insurancestatus: 100000000, // Verified
        dmv_insurancecarrier: form.insurer,
        dmv_insurancepolicy: form.policyNumber,
        dmv_insuranceexp: form.policyExp,
        ...(userId ? { 'dmv_ownercontactid@odata.bind': `/contacts(${userId})` } : {}),
      })
      // 2. Create registration
      const regId = `REG-${new Date().getFullYear()}-${String(Math.floor(Math.random() * 99999)).padStart(5, '0')}`
      await dvCreate('dmv_vehicleregistrations', {
        dmv_registrationid: regId,
        dmv_regstatus: 100000000, // Active
        dmv_regtype: 100000000, // New
        dmv_regyear: new Date().getFullYear(),
        dmv_effectivedate: new Date().toISOString().split('T')[0],
        dmv_expirationdate: `${new Date().getFullYear() + 1}-${String(new Date().getMonth() + 1).padStart(2, '0')}-${String(new Date().getDate()).padStart(2, '0')}`,
        dmv_onlineeligible: true,
        dmv_fee: 75.00,
        dmv_totaldue: 75.00,
        dmv_paymentstatus: 100000000, // Unpaid
        'dmv_vehicleid@odata.bind': `/dmv_vehicles(${vehicleId})`,
        ...(userId ? { 'dmv_regcontactid@odata.bind': `/contacts(${userId})` } : {}),
      })
      setRefNumber(regId)
      setSubmitted(true)
    } catch (err) {
      setSubmitError(err instanceof Error ? err.message : 'Submission failed. Please try again.')
    } finally {
      setSubmitting(false)
    }
  }

  if (submitted) {
    return (
      <>
        <div className="page-header"><div className="container"><h1>Vehicle Registration</h1></div></div>
        <div className="container" style={{ padding: '64px 24px', maxWidth: '600px', textAlign: 'center' }}>
          <div style={{ fontSize: '48px', marginBottom: '16px' }} aria-hidden="true">🚗</div>
          <h2 style={{ marginBottom: '12px', color: 'var(--color-success)' }}>Registration Submitted!</h2>
          <p style={{ color: 'var(--color-text-muted)', marginBottom: '8px' }}>
            Your vehicle registration request has been received and is being processed.
          </p>
          <p style={{ marginBottom: '32px' }}>
            Reference number: <span className="mono">{refNumber}</span>
          </p>
          <Link to="/" className="btn btn-primary">Return to Home</Link>
        </div>
      </>
    )
  }

  return (
    <>
      <div className="page-header">
        <div className="container">
          <nav className="breadcrumb" aria-label="Breadcrumb">
            <Link to="/">Home</Link>
            <span className="breadcrumb-sep" aria-hidden="true">›</span>
            <span aria-current="page">Vehicle Registration</span>
          </nav>
          <h1>Vehicle Registration</h1>
          <p>Register a new vehicle or renew your existing registration online.</p>
        </div>
      </div>

      <div className="section-sm">
        <div className="container" style={{ maxWidth: '720px' }}>
          <div style={infoBox}>
            <strong>Required documents:</strong> Vehicle title, current proof of insurance, and payment information.
            All information must match the vehicle title exactly.
          </div>

          <form onSubmit={handleSubmit} noValidate aria-label="Vehicle registration form">
            {/* Vehicle Info */}
            <section aria-labelledby="vehicle-heading">
              <h2 id="vehicle-heading" style={sectionH}>Vehicle Information</h2>
              <div className="form-group">
                <label htmlFor="vin">Vehicle Identification Number (VIN) *</label>
                <input id="vin" name="vin" type="text" maxLength={17} placeholder="17-character VIN"
                  required value={form.vin} onChange={handle} aria-required="true"
                  style={{ fontFamily: 'var(--font-mono)', letterSpacing: '0.05em' }} />
                <p className="field-hint">Found on your dashboard (driver's side), door jamb, or vehicle title.</p>
              </div>
              <div className="form-row">
                <div className="form-group">
                  <label htmlFor="make">Make *</label>
                  <input id="make" name="make" type="text" placeholder="e.g. Toyota" required value={form.make} onChange={handle} aria-required="true" />
                </div>
                <div className="form-group">
                  <label htmlFor="model">Model *</label>
                  <input id="model" name="model" type="text" placeholder="e.g. Camry" required value={form.model} onChange={handle} aria-required="true" />
                </div>
              </div>
              <div className="form-row">
                <div className="form-group">
                  <label htmlFor="year">Year *</label>
                  <input id="year" name="year" type="number" min={1900} max={new Date().getFullYear() + 1}
                    placeholder="YYYY" required value={form.year} onChange={handle} aria-required="true" />
                </div>
                <div className="form-group">
                  <label htmlFor="color">Color *</label>
                  <input id="color" name="color" type="text" placeholder="e.g. Silver" required value={form.color} onChange={handle} aria-required="true" />
                </div>
              </div>
              <div className="form-group">
                <label htmlFor="plateType">License Plate Type</label>
                <select id="plateType" name="plateType" value={form.plateType} onChange={handle}>
                  <option value="standard">Standard</option>
                  <option value="personalized">Personalized</option>
                  <option value="veteran">Veteran</option>
                  <option value="disability">Disability</option>
                </select>
              </div>
            </section>

            {/* Owner Info */}
            <section aria-labelledby="owner-heading" style={{ marginTop: '32px' }}>
              <h2 id="owner-heading" style={sectionH}>Owner Information</h2>
              <div className="form-row">
                <div className="form-group">
                  <label htmlFor="firstName">First Name *</label>
                  <input id="firstName" name="firstName" type="text" required value={form.firstName} onChange={handle} aria-required="true" />
                </div>
                <div className="form-group">
                  <label htmlFor="lastName">Last Name *</label>
                  <input id="lastName" name="lastName" type="text" required value={form.lastName} onChange={handle} aria-required="true" />
                </div>
              </div>
              <div className="form-row">
                <div className="form-group">
                  <label htmlFor="email">Email Address *</label>
                  <input id="email" name="email" type="email" required value={form.email} onChange={handle} aria-required="true" />
                </div>
                <div className="form-group">
                  <label htmlFor="phone">Phone Number</label>
                  <input id="phone" name="phone" type="tel" placeholder="(555) 000-0000" value={form.phone} onChange={handle} />
                </div>
              </div>
              <div className="form-group">
                <label htmlFor="address">Street Address *</label>
                <input id="address" name="address" type="text" required value={form.address} onChange={handle} aria-required="true" />
              </div>
              <div className="form-row">
                <div className="form-group">
                  <label htmlFor="city">City *</label>
                  <input id="city" name="city" type="text" required value={form.city} onChange={handle} aria-required="true" />
                </div>
                <div className="form-group">
                  <label htmlFor="zip">ZIP Code *</label>
                  <input id="zip" name="zip" type="text" inputMode="numeric" maxLength={5} required value={form.zip} onChange={handle} aria-required="true" />
                </div>
              </div>
            </section>

            {/* Insurance Info */}
            <section aria-labelledby="insurance-heading" style={{ marginTop: '32px' }}>
              <h2 id="insurance-heading" style={sectionH}>Insurance Information</h2>
              <div className="form-row">
                <div className="form-group">
                  <label htmlFor="insurer">Insurance Company *</label>
                  <input id="insurer" name="insurer" type="text" required value={form.insurer} onChange={handle} aria-required="true" />
                </div>
                <div className="form-group">
                  <label htmlFor="policyNumber">Policy Number *</label>
                  <input id="policyNumber" name="policyNumber" type="text" required value={form.policyNumber} onChange={handle} aria-required="true" />
                </div>
              </div>
              <div className="form-group" style={{ maxWidth: '240px' }}>
                <label htmlFor="policyExp">Policy Expiration Date *</label>
                <input id="policyExp" name="policyExp" type="date" required value={form.policyExp} onChange={handle} aria-required="true" />
              </div>
            </section>

            <div style={{ marginTop: '40px', display: 'flex', gap: '16px', alignItems: 'center' }}>
              <button type="submit" className="btn btn-primary" style={{ fontSize: '15px', padding: '12px 28px' }} disabled={submitting}>
                {submitting ? 'Submitting...' : 'Submit Registration'}
              </button>
              <Link to="/" className="btn btn-ghost">Cancel</Link>
              {submitError && <p style={{ color: 'var(--color-danger)', fontSize: '14px', marginTop: '8px' }}>{submitError}</p>}
            </div>
          </form>
        </div>
      </div>
    </>
  )
}

const infoBox: React.CSSProperties = {
  background: 'var(--color-info-bg)',
  border: '1px solid var(--color-border)',
  borderLeft: '4px solid var(--color-secondary)',
  borderRadius: 'var(--radius-md)',
  padding: '16px 20px',
  fontSize: '14px',
  lineHeight: 1.6,
  marginBottom: '32px',
}

const sectionH: React.CSSProperties = {
  fontFamily: 'var(--font-heading)',
  fontSize: '1.15rem',
  fontWeight: 600,
  color: 'var(--color-primary)',
  paddingBottom: '12px',
  borderBottom: '1px solid var(--color-border)',
  marginBottom: '24px',
}
