import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { dvCreate, dvQuery } from '../hooks/useDataverse'
import { useAuth } from '../hooks/useAuth'

/* ── constants ── */
const plateTypeMap: Record<string, number> = {
  standard: 100000000, personalized: 100000001, veteran: 100000002, disability: 100000003,
}
const statusLabels: Record<number, string> = {
  100000000: 'Active', 100000001: 'Expired', 100000002: 'Pending Payment',
  100000003: 'Pending Inspection', 100000004: 'Suspended', 100000005: 'Cancelled',
}
const statusColors: Record<number, string> = {
  100000000: 'var(--color-success)', 100000001: 'var(--color-danger)',
  100000002: 'var(--color-warning)', 100000003: 'var(--color-warning)',
  100000004: 'var(--color-danger)', 100000005: 'var(--color-text-muted)',
}

type VehicleRow = {
  dmv_vehicleid: string; dmv_vin: string; dmv_make: string; dmv_model: string;
  dmv_year: number; dmv_color: string; dmv_platenumber: string;
  dmv_insurancecarrier: string; dmv_insurancepolicy: string;
}
type RegRow = {
  dmv_vehicleregistrationid: string; dmv_registrationid: string;
  dmv_regstatus: number; dmv_expirationdate: string; dmv_effectivedate: string;
  dmv_regyear: number; _dmv_vehicleid_value: string;
}
type VehicleWithReg = VehicleRow & { reg?: RegRow; daysLeft?: number }

export default function VehicleRegistration() {
  useEffect(() => { document.title = 'Vehicle Registration — Contoso DMV' }, [])
  const { userId, isAuthenticated } = useAuth()

  /* ── view state ── */
  const [view, setView] = useState<'list' | 'new' | 'renew' | 'success'>('list')
  const [vehicles, setVehicles] = useState<VehicleWithReg[]>([])
  const [loading, setLoading] = useState(true)
  const [renewTarget, setRenewTarget] = useState<VehicleWithReg | null>(null)

  /* ── form state (new registration) ── */
  const [submitting, setSubmitting] = useState(false)
  const [refNumber, setRefNumber] = useState('')
  const [submitError, setSubmitError] = useState('')
  const [form, setForm] = useState({
    vin: '', make: '', model: '', year: '', color: '', plateType: 'standard',
    insurer: '', policyNumber: '', policyExp: '',
  })

  const handle = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) =>
    setForm(f => ({ ...f, [e.target.name]: e.target.value }))

  /* ── load vehicles + registrations ── */
  const loadData = async () => {
    if (!userId) { setLoading(false); return }
    setLoading(true)
    try {
      const [vRows, rRows] = await Promise.all([
        dvQuery('dmv_vehicles', `$filter=_dmv_ownercontactid_value eq ${userId}&$select=dmv_vehicleid,dmv_vin,dmv_make,dmv_model,dmv_year,dmv_color,dmv_platenumber,dmv_insurancecarrier,dmv_insurancepolicy&$orderby=dmv_year desc`),
        dvQuery('dmv_vehicleregistrations', `$filter=_dmv_regcontactid_value eq ${userId}&$select=dmv_vehicleregistrationid,dmv_registrationid,dmv_regstatus,dmv_expirationdate,dmv_effectivedate,dmv_regyear,_dmv_vehicleid_value&$orderby=dmv_expirationdate desc`),
      ])
      const regByVehicle = new Map<string, RegRow>()
      for (const r of rRows as RegRow[]) {
        const vid = r._dmv_vehicleid_value
        if (vid && !regByVehicle.has(vid)) regByVehicle.set(vid, r)
      }
      const now = Date.now()
      const merged: VehicleWithReg[] = (vRows as VehicleRow[]).map(v => {
        const reg = regByVehicle.get(v.dmv_vehicleid)
        const daysLeft = reg?.dmv_expirationdate
          ? Math.ceil((new Date(reg.dmv_expirationdate).getTime() - now) / 86400000)
          : undefined
        return { ...v, reg, daysLeft }
      })
      setVehicles(merged)
    } catch { /* silently handle */ }
    setLoading(false)
  }
  useEffect(() => { loadData() }, [userId])

  /* ── new vehicle registration ── */
  const handleNewSubmit = async (e: React.FormEvent) => {
    e.preventDefault(); setSubmitting(true); setSubmitError('')
    try {
      const vehicleId = await dvCreate('dmv_vehicles', {
        dmv_vin: form.vin, dmv_make: form.make, dmv_model: form.model,
        dmv_year: parseInt(form.year), dmv_color: form.color,
        dmv_platetype: plateTypeMap[form.plateType] ?? 100000000,
        dmv_salvagetitle: false, dmv_outofstate: false,
        dmv_insurancestatus: 100000000,
        dmv_insurancecarrier: form.insurer, dmv_insurancepolicy: form.policyNumber,
        dmv_insuranceexp: form.policyExp ? `${form.policyExp}T00:00:00Z` : undefined,
        ...(userId ? { 'dmv_ownercontactid@odata.bind': `/contacts(${userId})` } : {}),
      })
      const regId = `REG-${new Date().getFullYear()}-${String(Math.floor(Math.random() * 99999)).padStart(5, '0')}`
      const today = new Date()
      const expDate = new Date(today); expDate.setFullYear(expDate.getFullYear() + 1)
      await dvCreate('dmv_vehicleregistrations', {
        dmv_registrationid: regId, dmv_regstatus: 100000002, dmv_regtype: 100000000,
        dmv_regyear: today.getFullYear(),
        dmv_effectivedate: today.toISOString().split('T')[0] + 'T00:00:00Z',
        dmv_expirationdate: expDate.toISOString().split('T')[0] + 'T00:00:00Z',
        dmv_onlineeligible: true, dmv_fee: 75.00, dmv_totaldue: 75.00,
        dmv_paymentstatus: 100000000,
        'dmv_vehicleid@odata.bind': `/dmv_vehicles(${vehicleId})`,
        ...(userId ? { 'dmv_regcontactid@odata.bind': `/contacts(${userId})` } : {}),
      })
      setRefNumber(regId); setView('success')
    } catch (err) {
      setSubmitError(err instanceof Error ? err.message : 'Submission failed.')
    } finally { setSubmitting(false) }
  }

  /* ── renewal ── */
  const handleRenew = async () => {
    if (!renewTarget) return; setSubmitting(true); setSubmitError('')
    try {
      const regId = `REG-${new Date().getFullYear()}-${String(Math.floor(Math.random() * 99999)).padStart(5, '0')}`
      const today = new Date()
      const expDate = new Date(today); expDate.setFullYear(expDate.getFullYear() + 1)
      await dvCreate('dmv_vehicleregistrations', {
        dmv_registrationid: regId, dmv_regstatus: 100000002, dmv_regtype: 100000001,
        dmv_regyear: today.getFullYear(),
        dmv_effectivedate: today.toISOString().split('T')[0] + 'T00:00:00Z',
        dmv_expirationdate: expDate.toISOString().split('T')[0] + 'T00:00:00Z',
        dmv_onlineeligible: true, dmv_fee: 50.00, dmv_totaldue: 50.00,
        dmv_paymentstatus: 100000000,
        'dmv_vehicleid@odata.bind': `/dmv_vehicles(${renewTarget.dmv_vehicleid})`,
        ...(userId ? { 'dmv_regcontactid@odata.bind': `/contacts(${userId})` } : {}),
      })
      setRefNumber(regId); setView('success')
    } catch (err) {
      setSubmitError(err instanceof Error ? err.message : 'Renewal failed.')
    } finally { setSubmitting(false) }
  }

  /* ── success screen ── */
  if (view === 'success') {
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
          <div style={{ display: 'flex', gap: '12px', justifyContent: 'center' }}>
            <button className="btn btn-primary" onClick={() => { setView('list'); loadData() }}>
              Back to My Vehicles
            </button>
            <Link to="/" className="btn btn-outline">Return to Home</Link>
          </div>
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
        <div className="container" style={{ maxWidth: '820px' }}>

          {/* ══ LIST VIEW ══ */}
          {view === 'list' && (
            <>
              {isAuthenticated && (
                <>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
                    <h2 style={{ ...sectionH, marginBottom: 0, paddingBottom: 0, borderBottom: 'none' }}>My Vehicles</h2>
                    <button className="btn btn-primary" onClick={() => setView('new')}>+ Register New Vehicle</button>
                  </div>

                  {loading && <p style={{ color: 'var(--color-text-muted)', padding: '24px 0' }}>Loading your vehicles...</p>}

                  {!loading && vehicles.length === 0 && (
                    <div style={{ ...infoBox, textAlign: 'center', padding: '40px 20px' }}>
                      <p style={{ fontSize: '16px', marginBottom: '16px' }}>You don't have any registered vehicles yet.</p>
                      <button className="btn btn-primary" onClick={() => setView('new')}>Register Your First Vehicle</button>
                    </div>
                  )}

                  {!loading && vehicles.length > 0 && (
                    <div style={{ display: 'grid', gap: '16px' }}>
                      {vehicles.map(v => {
                        const status = v.reg?.dmv_regstatus ?? -1
                        const expiring = v.daysLeft !== undefined && v.daysLeft <= 90 && v.daysLeft > 0
                        const expired = v.daysLeft !== undefined && v.daysLeft <= 0
                        return (
                          <div key={v.dmv_vehicleid} style={vehicleCard}>
                            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: '12px' }}>
                              <div>
                                <h3 style={{ margin: 0, fontSize: '1.05rem', color: 'var(--color-primary)' }}>
                                  {v.dmv_year} {v.dmv_make} {v.dmv_model}
                                </h3>
                                <p style={{ margin: '4px 0 0', fontSize: '13px', color: 'var(--color-text-muted)' }}>
                                  VIN: <span className="mono">{v.dmv_vin}</span>
                                  {v.dmv_color && <> &middot; {v.dmv_color}</>}
                                  {v.dmv_platenumber && <> &middot; Plate: <strong>{v.dmv_platenumber}</strong></>}
                                </p>
                              </div>
                              {v.reg && (
                                <span style={{ ...badge, background: statusColors[status] ?? 'var(--color-text-muted)' }}>
                                  {statusLabels[status] ?? 'Unknown'}
                                </span>
                              )}
                            </div>

                            {v.reg && (
                              <div style={{ marginTop: '12px', display: 'flex', gap: '24px', flexWrap: 'wrap', fontSize: '13px', color: 'var(--color-text-muted)' }}>
                                <span>Reg #: <strong>{v.reg.dmv_registrationid}</strong></span>
                                <span>Expires: <strong style={{ color: expired ? 'var(--color-danger)' : expiring ? 'var(--color-warning)' : 'inherit' }}>
                                  {new Date(v.reg.dmv_expirationdate).toLocaleDateString()}
                                </strong></span>
                                {v.daysLeft !== undefined && v.daysLeft > 0 && (
                                  <span>({v.daysLeft} day{v.daysLeft !== 1 ? 's' : ''} remaining)</span>
                                )}
                              </div>
                            )}

                            {/* actions */}
                            <div style={{ marginTop: '14px', display: 'flex', gap: '10px' }}>
                              {(expired || expiring || status === 100000001) && (
                                <button className="btn btn-primary" style={{ fontSize: '13px', padding: '6px 16px' }}
                                  onClick={() => { setRenewTarget(v); setSubmitError(''); setView('renew') }}>
                                  Renew Registration
                                </button>
                              )}
                              {!v.reg && (
                                <button className="btn btn-secondary" style={{ fontSize: '13px', padding: '6px 16px' }}
                                  onClick={() => { setRenewTarget(v); setSubmitError(''); setView('renew') }}>
                                  Register This Vehicle
                                </button>
                              )}
                            </div>
                          </div>
                        )
                      })}
                    </div>
                  )}
                </>
              )}

              {!isAuthenticated && (
                <div style={{ ...infoBox, textAlign: 'center', padding: '40px 20px' }}>
                  <p style={{ fontSize: '16px', marginBottom: '16px' }}>Sign in to view your vehicles and manage registrations.</p>
                  <p style={{ color: 'var(--color-text-muted)', marginBottom: '20px' }}>
                    Or register a new vehicle below without signing in.
                  </p>
                  <button className="btn btn-primary" onClick={() => setView('new')}>Register a New Vehicle</button>
                </div>
              )}
            </>
          )}

          {/* ══ RENEW VIEW ══ */}
          {view === 'renew' && renewTarget && (
            <section>
              <button className="btn btn-ghost" onClick={() => setView('list')} style={{ marginBottom: '16px' }}>← Back to My Vehicles</button>
              <div style={vehicleCard}>
                <h2 style={{ ...sectionH, marginBottom: '16px' }}>Renew Registration</h2>
                <div style={{ background: 'var(--color-surface-alt)', borderRadius: 'var(--radius-md)', padding: '16px', marginBottom: '20px' }}>
                  <h3 style={{ margin: 0, fontSize: '1rem', color: 'var(--color-primary)' }}>
                    {renewTarget.dmv_year} {renewTarget.dmv_make} {renewTarget.dmv_model}
                  </h3>
                  <p style={{ margin: '4px 0 0', fontSize: '13px', color: 'var(--color-text-muted)' }}>
                    VIN: <span className="mono">{renewTarget.dmv_vin}</span>
                    {renewTarget.reg && <> &middot; Current Reg: {renewTarget.reg.dmv_registrationid}</>}
                    {renewTarget.reg && <> &middot; Expires: {new Date(renewTarget.reg.dmv_expirationdate).toLocaleDateString()}</>}
                  </p>
                </div>
                <div style={{ fontSize: '14px', marginBottom: '20px' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 0', borderBottom: '1px solid var(--color-border)' }}>
                    <span>Registration Renewal Fee</span><strong>$50.00</strong>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 0', borderBottom: '1px solid var(--color-border)' }}>
                    <span>New Expiration</span><strong>{new Date(Date.now() + 365 * 86400000).toLocaleDateString()}</strong>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 0', fontWeight: 600, fontSize: '15px' }}>
                    <span>Total Due</span><span style={{ color: 'var(--color-primary)' }}>$50.00</span>
                  </div>
                </div>
                <div style={{ display: 'flex', gap: '12px' }}>
                  <button className="btn btn-primary" onClick={handleRenew} disabled={submitting}>
                    {submitting ? 'Processing...' : 'Confirm Renewal'}
                  </button>
                  <button className="btn btn-outline" onClick={() => setView('list')}>Cancel</button>
                </div>
                {submitError && <p style={{ color: 'var(--color-danger)', fontSize: '14px', marginTop: '12px' }}>{submitError}</p>}
              </div>
            </section>
          )}

          {/* ══ NEW REGISTRATION FORM ══ */}
          {view === 'new' && (
            <>
              <button className="btn btn-ghost" onClick={() => setView('list')} style={{ marginBottom: '16px' }}>← Back to My Vehicles</button>
              <div style={infoBox}>
                <strong>Required documents:</strong> Vehicle title, current proof of insurance, and payment information.
                All information must match the vehicle title exactly.
              </div>
              <form onSubmit={handleNewSubmit} noValidate aria-label="Vehicle registration form">
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
                    {submitting ? 'Submitting...' : 'Submit Registration — $75.00'}
                  </button>
                  <button type="button" className="btn btn-ghost" onClick={() => setView('list')}>Cancel</button>
                </div>
                {submitError && <p style={{ color: 'var(--color-danger)', fontSize: '14px', marginTop: '8px' }}>{submitError}</p>}
              </form>
            </>
          )}

        </div>
      </div>
    </>
  )
}

/* ── styles ── */
const infoBox: React.CSSProperties = {
  background: 'var(--color-info-bg)', border: '1px solid var(--color-border)',
  borderLeft: '4px solid var(--color-secondary)', borderRadius: 'var(--radius-md)',
  padding: '16px 20px', fontSize: '14px', lineHeight: 1.6, marginBottom: '32px',
}
const sectionH: React.CSSProperties = {
  fontFamily: 'var(--font-heading)', fontSize: '1.15rem', fontWeight: 600,
  color: 'var(--color-primary)', paddingBottom: '12px',
  borderBottom: '1px solid var(--color-border)', marginBottom: '24px',
}
const vehicleCard: React.CSSProperties = {
  background: 'var(--color-surface)', border: '1px solid var(--color-border)',
  borderRadius: 'var(--radius-lg)', padding: '20px 24px',
}
const badge: React.CSSProperties = {
  display: 'inline-block', fontSize: '11px', fontWeight: 600, color: '#fff',
  padding: '3px 10px', borderRadius: '12px', letterSpacing: '0.03em', textTransform: 'uppercase',
}
