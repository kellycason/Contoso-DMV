import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { dvCreate, dvQuery, dvUpdate } from '../hooks/useDataverse'
import { useAuth } from '../hooks/useAuth'

/* ── constants ── */
const plateTypeMap: Record<string, number> = {
  standard: 100000000, personalized: 100000001, veteran: 100000002, disability: 100000003,
}
const regStatusLabels: Record<number, string> = {
  100000000: 'Active', 100000001: 'Expired', 100000002: 'Pending Payment',
  100000003: 'Pending Inspection', 100000004: 'Suspended', 100000005: 'Cancelled',
}
const regStatusColors: Record<number, string> = {
  100000000: 'var(--color-success)', 100000001: 'var(--color-danger)',
  100000002: 'var(--color-warning)', 100000003: 'var(--color-warning)',
  100000004: 'var(--color-danger)', 100000005: 'var(--color-text-muted)',
}
const termStatusLabels: Record<number, string> = {
  100000000: 'Active', 100000001: 'Pending', 100000002: 'Expired',
}
const termStatusColors: Record<number, string> = {
  100000000: 'var(--color-success)', 100000001: 'var(--color-warning)', 100000002: 'var(--color-danger)',
}

type VehicleRow = {
  dmv_vehicleid: string; dmv_vin: string; dmv_make: string; dmv_model: string;
  dmv_year: number; dmv_color: string; dmv_platenumber: string;
  dmv_insurancecarrier: string; dmv_insurancepolicy: string;
}
type RegRow = {
  dmv_vehicleregistrationid: string; dmv_registrationid: string;
  dmv_regstatus: number; _dmv_vehicleid_value: string;
  _dmv_currenttermid_value?: string;
  dmv_currenttermid?: TermRow; // populated via $expand
}
type TermRow = {
  dmv_registrationtermid: string; dmv_termnumber: string;
  dmv_termtype: number; dmv_termstatus: number;
  dmv_startdate: string; dmv_enddate: string;
  _dmv_vehicleregistrationid_value: string;
}
type VehicleWithReg = VehicleRow & { reg?: RegRow; term?: TermRow; daysLeft?: number }

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

  /* ── load vehicles + registrations + terms ── */
  const loadData = async () => {
    if (!userId) { setLoading(false); return }
    setLoading(true)
    try {
      // Server-injected registrations include expirationDate directly
      const dmvData = (window as any).__DMV_DATA__
      type InjectedReg = { id: string; regId: string; status: number; vehicleId: string; expirationDate: string }
      const injectedRegs: InjectedReg[] = dmvData?.registrations ?? []
      // Map injected reg expiration by regId
      const injExpByRegId = new Map<string, string>()
      for (const ir of injectedRegs) {
        if (ir.id && ir.expirationDate) injExpByRegId.set(ir.id, ir.expirationDate)
      }
      console.log('[DMV] Injected regs:', injectedRegs.length, 'with expiration:', injExpByRegId.size)

      const [vRows, rRows] = await Promise.all([
        dvQuery('dmv_vehicles', `$filter=_dmv_ownercontactid_value eq ${userId}&$select=dmv_vehicleid,dmv_vin,dmv_make,dmv_model,dmv_year,dmv_color,dmv_platenumber,dmv_insurancecarrier,dmv_insurancepolicy&$orderby=dmv_year desc`),
        dvQuery('dmv_vehicleregistrations', `$filter=_dmv_regcontactid_value eq ${userId}&$select=dmv_vehicleregistrationid,dmv_registrationid,dmv_regstatus,_dmv_vehicleid_value,_dmv_currenttermid_value,dmv_expirationdate`),
      ])

      // Index: vehicleId → reg
      const regByVehicle = new Map<string, RegRow>()
      for (const r of rRows as RegRow[]) {
        const vid = r._dmv_vehicleid_value
        if (vid && !regByVehicle.has(vid)) regByVehicle.set(vid, r)
      }
      const now = Date.now()
      const merged: VehicleWithReg[] = (vRows as VehicleRow[]).map(v => {
        const reg = regByVehicle.get(v.dmv_vehicleid)
        // Get expiration from Web API registration, fall back to injected data
        const expDate = (reg as any)?.dmv_expirationdate
          || (reg ? injExpByRegId.get(reg.dmv_vehicleregistrationid) : undefined)
        // Build a minimal term object for display compatibility
        const term: TermRow | undefined = expDate ? {
          dmv_registrationtermid: reg?._dmv_currenttermid_value || '',
          dmv_termnumber: '', dmv_termtype: 0, dmv_termstatus: 100000000,
          dmv_startdate: '', dmv_enddate: expDate,
          _dmv_vehicleregistrationid_value: reg?.dmv_vehicleregistrationid || '',
        } : undefined
        const daysLeft = expDate
          ? Math.ceil((new Date(expDate).getTime() - now) / 86400000)
          : undefined
        return { ...v, reg, term, daysLeft }
      })
      setVehicles(merged)
    } catch (e) { console.error('[DMV] loadData failed:', e) }
    setLoading(false)
  }
  useEffect(() => { loadData() }, [userId])

  /* ── new vehicle registration ── */
  const handleNewSubmit = async (e: React.FormEvent) => {
    e.preventDefault(); setSubmitting(true); setSubmitError('')
    try {
      // 1. Create vehicle
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
      // 2. Create parent registration
      const regId = `REG-${new Date().getFullYear()}-${String(Math.floor(Math.random() * 99999)).padStart(5, '0')}`
      const registrationId = await dvCreate('dmv_vehicleregistrations', {
        dmv_registrationid: regId,
        dmv_regstatus: 100000002, // Pending Payment
        'dmv_vehicleid@odata.bind': `/dmv_vehicles(${vehicleId})`,
        ...(userId ? { 'dmv_regcontactid@odata.bind': `/contacts(${userId})` } : {}),
      })
      // 3. Create first term
      const today = new Date()
      const expDate = new Date(today); expDate.setFullYear(expDate.getFullYear() + 1)
      const termNum = `TERM-${today.getFullYear()}-${String(Math.floor(Math.random() * 99999)).padStart(5, '0')}`
      const termId = await dvCreate('dmv_registrationterms', {
        dmv_termnumber: termNum,
        dmv_termtype: 100000000,   // New
        dmv_termstatus: 100000001, // Pending
        dmv_startdate: today.toISOString().split('T')[0] + 'T00:00:00Z',
        dmv_enddate: expDate.toISOString().split('T')[0] + 'T00:00:00Z',
        dmv_issuedate: today.toISOString().split('T')[0] + 'T00:00:00Z',
        'dmv_vehicleregistrationid@odata.bind': `/dmv_vehicleregistrations(${registrationId})`,
      })
      // 4. Create payment
      const payRef = `PAY-${today.getFullYear()}-${String(Math.floor(Math.random() * 99999)).padStart(5, '0')}`
      await dvCreate('dmv_registrationpayments', {
        dmv_paymentref: payRef,
        dmv_amount: 75.00, dmv_total: 75.00,
        dmv_paymentstatus: 100000000, // Unpaid
        'dmv_registrationtermid@odata.bind': `/dmv_registrationterms(${termId})`,
      })
      // 5. Point parent to current term
      await dvUpdate('dmv_vehicleregistrations', registrationId, {
        'dmv_currenttermid@odata.bind': `/dmv_registrationterms(${termId})`,
      })
      setRefNumber(regId); setView('success')
    } catch (err) {
      setSubmitError(err instanceof Error ? err.message : 'Submission failed.')
    } finally { setSubmitting(false) }
  }

  /* ── renewal ── */
  const handleRenew = async () => {
    if (!renewTarget?.reg) return; setSubmitting(true); setSubmitError('')
    try {
      const today = new Date()
      const expDate = new Date(today); expDate.setFullYear(expDate.getFullYear() + 1)
      const regId = renewTarget.reg.dmv_vehicleregistrationid

      // 1. Create new term (Renewal)
      const termNum = `TERM-${today.getFullYear()}-${String(Math.floor(Math.random() * 99999)).padStart(5, '0')}`
      const termId = await dvCreate('dmv_registrationterms', {
        dmv_termnumber: termNum,
        dmv_termtype: 100000001,   // Renewal
        dmv_termstatus: 100000001, // Pending
        dmv_startdate: today.toISOString().split('T')[0] + 'T00:00:00Z',
        dmv_enddate: expDate.toISOString().split('T')[0] + 'T00:00:00Z',
        dmv_issuedate: today.toISOString().split('T')[0] + 'T00:00:00Z',
        'dmv_vehicleregistrationid@odata.bind': `/dmv_vehicleregistrations(${regId})`,
      })

      // 2. Create payment for the new term
      const payRef = `PAY-${today.getFullYear()}-${String(Math.floor(Math.random() * 99999)).padStart(5, '0')}`
      await dvCreate('dmv_registrationpayments', {
        dmv_paymentref: payRef,
        dmv_amount: 50.00, dmv_total: 50.00,
        dmv_paymentstatus: 100000000, // Unpaid
        'dmv_registrationtermid@odata.bind': `/dmv_registrationterms(${termId})`,
      })

      // 3. Mark old term as Expired (if exists)
      if (renewTarget.term) {
        await dvUpdate('dmv_registrationterms', renewTarget.term.dmv_registrationtermid, {
          dmv_termstatus: 100000002, // Expired
        })
      }

      // 4. Update parent: point to new term + mark active
      await dvUpdate('dmv_vehicleregistrations', regId, {
        'dmv_currenttermid@odata.bind': `/dmv_registrationterms(${termId})`,
        dmv_regstatus: 100000000, // Active
      })

      setRefNumber(renewTarget.reg.dmv_registrationid); setView('success')
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
                    <div style={{ display: 'grid', gap: '0' }}>
                      {/* header row */}
                      <div style={cardHeader}>
                        <span style={{ flex: '1 1 0' }}>Vehicle</span>
                        <span style={{ width: '140px', textAlign: 'center' }}>Status</span>
                        <span style={{ width: '160px', textAlign: 'right' }}>Registration Expires</span>
                        <span style={{ width: '140px', textAlign: 'right' }}>Action</span>
                      </div>
                      {vehicles.map((v, i) => {
                        const status = v.reg?.dmv_regstatus ?? -1
                        const expiring = v.daysLeft !== undefined && v.daysLeft <= 90 && v.daysLeft > 0
                        const expired = v.daysLeft !== undefined && v.daysLeft <= 0
                        return (
                          <div key={v.dmv_vehicleid} style={{ ...cardRow, ...(i % 2 === 0 ? {} : cardRowAlt) }}>
                            {/* icon + details */}
                            <div style={{ flex: '1 1 0', display: 'flex', gap: '16px', alignItems: 'center', minWidth: 0 }}>
                              <div style={vehicleIcon} aria-hidden="true">
                                <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
                                  <path d="M5 17h14M5 17a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2h1l2-3h8l2 3h1a2 2 0 0 1 2 2v6a2 2 0 0 1-2 2M7 17v1a1 1 0 0 0 1 1h1a1 1 0 0 0 1-1v-1m6 0v1a1 1 0 0 0 1 1h1a1 1 0 0 0 1-1v-1" />
                                  <circle cx="7.5" cy="13" r="1.5" /><circle cx="16.5" cy="13" r="1.5" />
                                </svg>
                              </div>
                              <div style={{ minWidth: 0 }}>
                                <div style={{ fontWeight: 600, fontSize: '14px', color: 'var(--color-text)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                                  {v.dmv_year} {v.dmv_make} {v.dmv_model}
                                </div>
                                <div style={{ fontSize: '12px', color: 'var(--color-text-muted)', marginTop: '2px' }}>
                                  VIN: <span className="mono">{v.dmv_vin}</span>
                                </div>
                                <div style={{ fontSize: '12px', color: 'var(--color-text-muted)', marginTop: '1px', display: 'flex', gap: '12px', flexWrap: 'wrap' }}>
                                  {v.dmv_color && <span>{v.dmv_color}</span>}
                                  {v.dmv_platenumber && <span>Plate: <strong>{v.dmv_platenumber}</strong></span>}
                                  {v.reg && <span>Reg #: {v.reg.dmv_registrationid}</span>}
                                </div>
                              </div>
                            </div>

                            {/* status column */}
                            <div style={{ width: '140px', textAlign: 'center', flexShrink: 0 }}>
                              <div style={{ fontSize: '11px', color: 'var(--color-text-muted)', marginBottom: '4px', textTransform: 'uppercase', letterSpacing: '0.04em' }}>Status</div>
                              {v.term ? (
                                <span style={{ fontWeight: 600, fontSize: '13px', color: termStatusColors[v.term.dmv_termstatus] ?? 'var(--color-text-muted)' }}>
                                  {termStatusLabels[v.term.dmv_termstatus] ?? 'Unknown'}
                                </span>
                              ) : v.reg ? (
                                <span style={{ fontWeight: 600, fontSize: '13px', color: regStatusColors[status] ?? 'var(--color-text-muted)' }}>
                                  {regStatusLabels[status] ?? 'Unknown'}
                                </span>
                              ) : (
                                <span style={{ fontWeight: 600, fontSize: '13px', color: 'var(--color-text-muted)' }}>Unregistered</span>
                              )}
                            </div>

                            {/* expiration column */}
                            <div style={{ width: '160px', textAlign: 'right', flexShrink: 0 }}>
                              <div style={{ fontSize: '11px', color: 'var(--color-text-muted)', marginBottom: '4px', textTransform: 'uppercase', letterSpacing: '0.04em' }}>Expires</div>
                              {v.term?.dmv_enddate ? (
                                <>
                                  <div style={{ fontWeight: 600, fontSize: '13px', color: expired ? 'var(--color-danger)' : expiring ? '#b45309' : 'var(--color-text)' }}>
                                    {new Date(v.term.dmv_enddate).toLocaleDateString('en-US', { day: 'numeric', month: 'short', year: 'numeric' })}
                                  </div>
                                  {v.daysLeft !== undefined && v.daysLeft > 0 && (
                                    <div style={{ fontSize: '11px', color: expiring ? '#b45309' : 'var(--color-text-muted)', marginTop: '2px' }}>
                                      {v.daysLeft} day{v.daysLeft !== 1 ? 's' : ''} left
                                    </div>
                                  )}
                                  {expired && <div style={{ fontSize: '11px', color: 'var(--color-danger)', marginTop: '2px' }}>Overdue</div>}
                                </>
                              ) : (
                                <span style={{ fontSize: '13px', color: 'var(--color-text-muted)' }}>—</span>
                              )}
                            </div>

                            {/* action column */}
                            <div style={{ width: '140px', textAlign: 'right', flexShrink: 0 }}>
                              {(expired || expiring || status === 100000001 || (v.term && v.term.dmv_termstatus === 100000002)) && (
                                <button className="btn btn-primary" style={{ fontSize: '12px', padding: '5px 14px' }}
                                  onClick={() => { setRenewTarget(v); setSubmitError(''); setView('renew') }}>
                                  Renew
                                </button>
                              )}
                              {!v.reg && (
                                <button className="btn btn-secondary" style={{ fontSize: '12px', padding: '5px 14px' }}
                                  onClick={() => { setRenewTarget(v); setSubmitError(''); setView('renew') }}>
                                  Register
                                </button>
                              )}
                              {v.reg && !expired && !expiring && status !== 100000001 && (
                                <span style={{ fontSize: '12px', color: 'var(--color-text-muted)' }}>Up to date</span>
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
                    {renewTarget.reg && <> &middot; Reg #: {renewTarget.reg.dmv_registrationid}</>}
                    {renewTarget.term?.dmv_enddate && <> &middot; Current term expires: {new Date(renewTarget.term.dmv_enddate).toLocaleDateString()}</>}
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
const cardHeader: React.CSSProperties = {
  display: 'flex', alignItems: 'center', gap: '16px', padding: '10px 20px',
  fontSize: '11px', fontWeight: 600, color: 'var(--color-text-muted)',
  textTransform: 'uppercase', letterSpacing: '0.05em',
  borderBottom: '2px solid var(--color-border)', background: 'var(--color-surface-alt)',
  borderRadius: 'var(--radius-lg) var(--radius-lg) 0 0',
}
const cardRow: React.CSSProperties = {
  display: 'flex', alignItems: 'center', gap: '16px', padding: '16px 20px',
  borderBottom: '1px solid var(--color-border)', background: 'var(--color-surface)',
  transition: 'background 0.1s',
}
const cardRowAlt: React.CSSProperties = {
  background: 'var(--color-surface-alt, #fafbfc)',
}
const vehicleIcon: React.CSSProperties = {
  width: '52px', height: '52px', borderRadius: 'var(--radius-md)',
  background: 'var(--color-info-bg)', display: 'flex', alignItems: 'center',
  justifyContent: 'center', color: 'var(--color-secondary)', flexShrink: 0,
}
