import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { dvCreate, dvQuery, dvUpdate } from '../hooks/useDataverse'
import { useAuth } from '../hooks/useAuth'
import { useMyDMVData } from '../hooks/useMyDMVData'

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
  dmv_year: string; dmv_color: string; dmv_platenumber: string;
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

/* ── Renewal wizard steps ── */
const RENEW_STEPS = ['Vehicle Info', 'Owner Details', 'Insurance', 'Pay Renewal Fee', 'Confirmation']

interface RenewForm {
  /* Step 1 – Vehicle (auto-filled) */
  plateNumber: string; vin: string; year: string; make: string; model: string; color: string
  /* Step 2 – Owner */
  firstName: string; lastName: string; email: string; phone: string
  address: string; city: string; state: string; zip: string
  /* Step 3 – Insurance */
  insurer: string; policyNumber: string; policyExp: string
  /* Step 4 – Payment */
  payMethod: string; cardName: string; cardNumber: string; cardExp: string; cardCvv: string
}

const DEMO_CARD = { cardName: 'Maria Jennings', cardNumber: '4111 1111 1111 1234', cardExp: '09 / 28', cardCvv: '427' }

const RENEW_INIT: RenewForm = {
  plateNumber: '', vin: '', year: '', make: '', model: '', color: '',
  firstName: '', lastName: '', email: '', phone: '', address: '', city: '', state: 'TX', zip: '',
  insurer: '', policyNumber: '', policyExp: '',
  payMethod: 'credit', ...DEMO_CARD,
}

export default function VehicleRegistration() {
  useEffect(() => { document.title = 'Vehicle Registration — Contoso DMV' }, [])
  const { userId, isAuthenticated, userName } = useAuth()
  const dmv = useMyDMVData(userId)

  /* ── view state ── */
  const [view, setView] = useState<'list' | 'new' | 'renew' | 'success'>('list')
  const [vehicles, setVehicles] = useState<VehicleWithReg[]>([])
  const [loading, setLoading] = useState(true)
  const [renewTarget, setRenewTarget] = useState<VehicleWithReg | null>(null)

  /* ── renewal wizard state ── */
  const [rnStep, setRnStep] = useState(0)
  const [rnForm, setRnForm] = useState<RenewForm>(RENEW_INIT)
  const [rnAutofilled, setRnAutofilled] = useState(false)
  const [rnRefNumber, setRnRefNumber] = useState('')

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
        dvQuery('dmv_vehicles', `$filter=_dmv_ownercontactid_value eq ${userId}&$select=dmv_vehicleid,dmv_vin,dmv_make,dmv_model,dmv_year,dmv_color,dmv_platenumber,dmv_insurancecarrier,dmv_insurancepolicy&$orderby=dmv_make asc`),
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

  /* ── auto-start renewal from ?renew=<vehicleId> query param ── */
  useEffect(() => {
    if (loading || view !== 'list' || !vehicles.length) return
    const params = new URLSearchParams(window.location.search)
    const renewId = params.get('renew')
    if (!renewId) return
    const requestedStep = params.get('step')
    const requestedPayMethod = params.get('pay')
    const target = vehicles.find(v => v.dmv_vehicleid === renewId)
    if (target) {
      const payMethod = ['credit', 'debit', 'cash', 'echeck'].includes(requestedPayMethod || '')
        ? requestedPayMethod!
        : RENEW_INIT.payMethod
      setRnForm({ ...RENEW_INIT, payMethod })
      setRnStep(requestedStep === 'payment' ? 3 : 0)
      setRnAutofilled(false)
      setRenewTarget(target); setSubmitError(''); setView('renew')
      // Clear param so refresh/back doesn't re-trigger
      window.history.replaceState({}, '', '/vehicle-registration')
    }
  }, [loading, vehicles, view])

  /* ── new vehicle registration ── */
  const handleNewSubmit = async (e: React.FormEvent) => {
    e.preventDefault(); setSubmitting(true); setSubmitError('')
    try {
      // 1. Create vehicle
      const vehicleId = await dvCreate('dmv_vehicles', {
        dmv_vin: form.vin, dmv_make: form.make, dmv_model: form.model,
        dmv_year: (form.year || '').toString().trim(), dmv_color: form.color,
        dmv_platetype: plateTypeMap[form.plateType] ?? 100000000,
        dmv_salvagetitle: false, dmv_outofstate: false,
        dmv_insurancestatus: 100000000,
        dmv_insurancecarrier: form.insurer, dmv_insurancepolicy: form.policyNumber,
        dmv_insuranceexp: form.policyExp ? `${form.policyExp}T00:00:00Z` : undefined,
        ...(userId ? { 'dmv_ownercontactid@odata.bind': `/contacts(${userId})` } : {}),
      })
      // 2. Create parent registration (dmv_registrationid is autonumbered by Dataverse)
      const registrationId = await dvCreate('dmv_vehicleregistrations', {
        dmv_regstatus: 100000002, // Pending Payment
        'dmv_vehicleid@odata.bind': `/dmv_vehicles(${vehicleId})`,
        ...(userId ? { 'dmv_regcontactid@odata.bind': `/contacts(${userId})` } : {}),
      })
      // 3. Create first term (dmv_termnumber is autonumbered)
      const today = new Date()
      const expDate = new Date(today); expDate.setFullYear(expDate.getFullYear() + 1)
      const termId = await dvCreate('dmv_registrationterms', {
        dmv_termtype: 100000000,   // New
        dmv_termstatus: 100000001, // Pending
        dmv_startdate: today.toISOString().split('T')[0] + 'T00:00:00Z',
        dmv_enddate: expDate.toISOString().split('T')[0] + 'T00:00:00Z',
        dmv_issuedate: today.toISOString().split('T')[0] + 'T00:00:00Z',
        'dmv_vehicleregistrationid@odata.bind': `/dmv_vehicleregistrations(${registrationId})`,
      })
      // 4. Create payment (demo: auto-settle as Paid; dmv_paymentref is autonumbered)
      await dvCreate('dmv_registrationpayments', {
        dmv_amount: 75.00, dmv_total: 75.00,
        dmv_paymentstatus: 100000001, // Paid
        'dmv_registrationtermid@odata.bind': `/dmv_registrationterms(${termId})`,
      })
      // 5. Point parent to current term
      await dvUpdate('dmv_vehicleregistrations', registrationId, {
        'dmv_currenttermid@odata.bind': `/dmv_registrationterms(${termId})`,
      })
      // 6. Fetch the autonumber-assigned registration ref for the success screen
      const created = await dvQuery(
        'dmv_vehicleregistrations',
        `$filter=dmv_vehicleregistrationid eq ${registrationId}&$select=dmv_registrationid`
      )
      setRefNumber(created[0]?.dmv_registrationid || registrationId); setView('success')
    } catch (err) {
      setSubmitError(err instanceof Error ? err.message : 'Submission failed.')
    } finally { setSubmitting(false) }
  }

  /* ── autofill renewal form when target or profile changes ── */
  useEffect(() => {
    if (!renewTarget || rnAutofilled || dmv.loading) return
    const parts = (userName ?? '').split(' ')
    setRnForm(f => ({
      ...f,
      plateNumber: f.plateNumber || renewTarget.dmv_platenumber || '',
      vin: f.vin || renewTarget.dmv_vin || '',
      year: f.year || String(renewTarget.dmv_year || ''),
      make: f.make || renewTarget.dmv_make || '',
      model: f.model || renewTarget.dmv_model || '',
      color: f.color || renewTarget.dmv_color || '',
      firstName: f.firstName || parts[0] || '',
      lastName: f.lastName || parts.slice(1).join(' ') || '',
      email: f.email || dmv.citizen?.email || '',
      phone: f.phone || dmv.citizen?.phone || '',
      address: f.address || dmv.citizen?.address || '',
      city: f.city || dmv.citizen?.city || '',
      state: f.state || dmv.citizen?.state || 'TX',
      zip: f.zip || dmv.citizen?.zip || '',
      insurer: f.insurer || renewTarget.dmv_insurancecarrier || 'Contoso Insurance',
      policyNumber: f.policyNumber || renewTarget.dmv_insurancepolicy || 'POL-2024-88712',
      policyExp: f.policyExp || '2027-06-30',
    }))
    setRnAutofilled(true)
  }, [renewTarget, dmv.loading, dmv.citizen, userName])

  const rnHandle = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) =>
    setRnForm(f => ({ ...f, [e.target.name]: e.target.value }))

  /* ── renewal wizard submit ── */
  const handleRenew = async () => {
    setSubmitting(true); setSubmitError('')
    try {
      // dmv_renewalid is autonumbered by Dataverse; payment confirmation is separate
      const payConf = `PAY-${Date.now().toString(36).toUpperCase()}`
      const renewalId = await dvCreate('dmv_registrationrenewals', {
        dmv_renewalstatus: 100000000, // Submitted
        dmv_platenumber: rnForm.plateNumber,
        dmv_vin: rnForm.vin,
        dmv_vehicleyear: rnForm.year || '',
        dmv_vehiclemake: rnForm.make,
        dmv_vehiclemodel: rnForm.model,
        dmv_vehiclecolor: rnForm.color,
        dmv_firstname: rnForm.firstName,
        dmv_lastname: rnForm.lastName,
        dmv_email: rnForm.email,
        dmv_phone: rnForm.phone,
        dmv_streetaddress: rnForm.address,
        dmv_city: rnForm.city,
        dmv_state: rnForm.state,
        dmv_zipcode: rnForm.zip,
        dmv_insurancecarrier: rnForm.insurer,
        dmv_insurancepolicy: rnForm.policyNumber,
        dmv_insuranceexpiration: rnForm.policyExp ? `${rnForm.policyExp}T00:00:00Z` : undefined,
        dmv_renewalfee: 50.00,
        dmv_paymentmethod: rnForm.payMethod === 'credit' ? 100000000 : rnForm.payMethod === 'debit' ? 100000001 : 100000002,
        dmv_paymentconfirmation: payConf,
        dmv_submitteddate: new Date().toISOString(),
        dmv_channel: 100000000, // Online Portal
        ...(userId ? { 'dmv_contactid@odata.bind': `/contacts(${userId})` } : {}),
        ...(renewTarget?.dmv_vehicleid ? { 'dmv_vehicleid@odata.bind': `/dmv_vehicles(${renewTarget.dmv_vehicleid})` } : {}),
        ...(renewTarget?.reg?.dmv_vehicleregistrationid ? { 'dmv_registrationid@odata.bind': `/dmv_vehicleregistrations(${renewTarget.reg.dmv_vehicleregistrationid})` } : {}),
      })
      // Create a paid payment record linked to the renewal (and to the
      // vehicle registration's current term, if known).
      if (renewalId) {
        const currentTermId = renewTarget?.reg?._dmv_currenttermid_value
        await dvCreate('dmv_registrationpayments', {
          dmv_amount: 50.00, dmv_total: 50.00,
          dmv_paymentstatus: 100000001, // Paid
          'dmv_RenewalId@odata.bind': `/dmv_registrationrenewals(${renewalId})`,
          ...(currentTermId ? { 'dmv_registrationtermid@odata.bind': `/dmv_registrationterms(${currentTermId})` } : {}),
        }).catch(() => {})
      }
      // Also log transaction
      if (userId) {
        await dvCreate('dmv_transactionlogs', {
          dmv_transactionid: `TXN-${Math.floor(Math.random() * 9000000 + 1000000)}`,
          dmv_transactiontype: 100000001, // Registration Renewal
          dmv_transactiondate: new Date().toISOString(),
          dmv_status: 100000001, // Completed
          dmv_channel: 100000000,
          'dmv_contactid@odata.bind': `/contacts(${userId})`,
        }).catch(() => {})
      }
      // Fetch the autonumber-assigned renewal ref for the confirmation screen
      const createdRenewal = await dvQuery(
        'dmv_registrationrenewals',
        `$filter=dmv_registrationrenewalid eq ${renewalId}&$select=dmv_renewalid`
      )
      setRnRefNumber(createdRenewal[0]?.dmv_renewalid || renewalId)
      setRnStep(4) // move to confirmation
    } catch (err) {
      setSubmitError(err instanceof Error ? err.message : 'Submission failed.')
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
                                  onClick={() => { setRnForm(RENEW_INIT); setRnStep(0); setRnAutofilled(false); setRenewTarget(v); setSubmitError(''); setView('renew') }}>
                                  Renew
                                </button>
                              )}
                              {!v.reg && (
                                <button className="btn btn-secondary" style={{ fontSize: '12px', padding: '5px 14px' }}
                                  onClick={() => { setRnForm(RENEW_INIT); setRnStep(0); setRnAutofilled(false); setRenewTarget(v); setSubmitError(''); setView('renew') }}>
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

          {/* ══ RENEW VIEW — Multi-step wizard ══ */}
          {view === 'renew' && renewTarget && (
            <section>

              {/* ── Circular stepper (matches License Renewal) ── */}
              <div style={rnStepperWrap}>
                {RENEW_STEPS.map((label, i) => (
                  <div key={label} style={{ display: 'flex', alignItems: 'center', gap: 0 }}>
                    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '6px', minWidth: '80px' }}>
                      <div style={{
                        width: 32, height: 32, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center',
                        fontSize: '13px', fontWeight: 700,
                        background: i < rnStep ? 'var(--color-success)' : i === rnStep ? 'var(--color-accent)' : 'var(--color-surface-alt)',
                        color: i <= rnStep ? '#fff' : 'var(--color-text-muted)',
                        border: i === rnStep ? '2px solid var(--color-accent)' : i < rnStep ? '2px solid var(--color-success)' : '2px solid var(--color-border)',
                        transition: 'all 0.3s ease',
                      }}>
                        {i < rnStep ? '✓' : i + 1}
                      </div>
                      <span style={{
                        fontSize: '11px', fontWeight: i === rnStep ? 700 : 500, textAlign: 'center',
                        color: i === rnStep ? 'var(--color-primary)' : 'var(--color-text-muted)',
                      }}>{label}</span>
                    </div>
                    {i < RENEW_STEPS.length - 1 && (
                      <div style={{
                        height: 2, flex: 1, minWidth: 24,
                        background: i < rnStep ? 'var(--color-success)' : 'var(--color-border)',
                        margin: '0 4px', marginBottom: '22px',
                        transition: 'background 0.3s ease',
                      }} />
                    )}
                  </div>
                ))}
              </div>

              {/* ── Step content card ── */}
              <div className="card" style={{ padding: 'var(--space-6)', marginTop: 'var(--space-5)' }}>

                {/* Step 0: Vehicle Info */}
                {rnStep === 0 && (<>
                  <h2 style={rnStepTitle}>Step 1: Vehicle Information</h2>
                  <p style={rnStepDesc}>
                    Confirm the details for the vehicle you'd like to renew. This information is pre-filled from your registration records.
                  </p>
                  <div style={{ background: 'var(--color-surface-alt)', borderRadius: 'var(--radius-md)', padding: '16px 20px', marginBottom: 28 }}>
                    <h3 style={{ margin: 0, fontSize: '1rem', color: 'var(--color-primary)' }}>
                      {renewTarget.dmv_year} {renewTarget.dmv_make} {renewTarget.dmv_model}
                    </h3>
                    <p style={{ margin: '4px 0 0', fontSize: '13px', color: 'var(--color-text-muted)' }}>
                      VIN: <span className="mono">{renewTarget.dmv_vin}</span>
                      {renewTarget.reg && <> &middot; Reg #: {renewTarget.reg.dmv_registrationid}</>}
                    </p>
                  </div>
                  <div className="form-row">
                    <div className="form-group"><label htmlFor="rn-plate">Plate Number *</label><input id="rn-plate" name="plateNumber" type="text" value={rnForm.plateNumber} onChange={rnHandle} required /></div>
                    <div className="form-group"><label htmlFor="rn-vin">VIN</label><input id="rn-vin" name="vin" type="text" value={rnForm.vin} onChange={rnHandle} style={{ fontFamily: 'var(--font-mono)', letterSpacing: '0.05em' }} /></div>
                  </div>
                  <div className="form-row">
                    <div className="form-group"><label htmlFor="rn-year">Year</label><input id="rn-year" name="year" type="text" value={rnForm.year} onChange={rnHandle} /></div>
                    <div className="form-group"><label htmlFor="rn-make">Make</label><input id="rn-make" name="make" type="text" value={rnForm.make} onChange={rnHandle} /></div>
                    <div className="form-group"><label htmlFor="rn-model">Model</label><input id="rn-model" name="model" type="text" value={rnForm.model} onChange={rnHandle} /></div>
                    <div className="form-group"><label htmlFor="rn-color">Color</label><input id="rn-color" name="color" type="text" value={rnForm.color} onChange={rnHandle} /></div>
                  </div>
                </>)}

                {/* Step 1: Owner Details */}
                {rnStep === 1 && (<>
                  <h2 style={rnStepTitle}>Step 2: Owner Details</h2>
                  <p style={rnStepDesc}>
                    Confirm your contact information. This will appear on your registration documents.
                  </p>
                  <div className="form-row">
                    <div className="form-group"><label htmlFor="rn-fn">First Name *</label><input id="rn-fn" name="firstName" type="text" value={rnForm.firstName} onChange={rnHandle} required /></div>
                    <div className="form-group"><label htmlFor="rn-ln">Last Name *</label><input id="rn-ln" name="lastName" type="text" value={rnForm.lastName} onChange={rnHandle} required /></div>
                  </div>
                  <div className="form-row">
                    <div className="form-group"><label htmlFor="rn-email">Email</label><input id="rn-email" name="email" type="email" value={rnForm.email} onChange={rnHandle} /></div>
                    <div className="form-group"><label htmlFor="rn-phone">Phone</label><input id="rn-phone" name="phone" type="tel" value={rnForm.phone} onChange={rnHandle} /></div>
                  </div>
                  <div className="form-group"><label htmlFor="rn-addr">Street Address</label><input id="rn-addr" name="address" type="text" value={rnForm.address} onChange={rnHandle} /></div>
                  <div className="form-row" style={{ gridTemplateColumns: '1fr 80px 1fr' }}>
                    <div className="form-group"><label htmlFor="rn-city">City</label><input id="rn-city" name="city" type="text" value={rnForm.city} onChange={rnHandle} /></div>
                    <div className="form-group"><label htmlFor="rn-state">State</label><input id="rn-state" name="state" type="text" value={rnForm.state} onChange={rnHandle} maxLength={2} /></div>
                    <div className="form-group"><label htmlFor="rn-zip">ZIP</label><input id="rn-zip" name="zip" type="text" value={rnForm.zip} onChange={rnHandle} /></div>
                  </div>
                </>)}

                {/* Step 2: Insurance */}
                {rnStep === 2 && (<>
                  <h2 style={rnStepTitle}>Step 3: Insurance Verification</h2>
                  <p style={rnStepDesc}>
                    Your insurance must be current and valid for the full registration period.
                  </p>
                  <div className="form-row">
                    <div className="form-group"><label htmlFor="rn-ins">Insurance Company *</label><input id="rn-ins" name="insurer" type="text" value={rnForm.insurer} onChange={rnHandle} required /></div>
                    <div className="form-group"><label htmlFor="rn-pol">Policy Number *</label><input id="rn-pol" name="policyNumber" type="text" value={rnForm.policyNumber} onChange={rnHandle} required /></div>
                  </div>
                  <div className="form-group" style={{ maxWidth: '240px' }}>
                    <label htmlFor="rn-pexp">Policy Expiration Date *</label>
                    <input id="rn-pexp" name="policyExp" type="date" value={rnForm.policyExp} onChange={rnHandle} required />
                  </div>
                </>)}

                {/* Step 3: Payment */}
                {rnStep === 3 && (<>
                  <h2 style={rnStepTitle}>Step 4: Pay Renewal Fee</h2>
                  <p style={rnStepDesc}>
                    The renewal fee is <strong>$50.00</strong>. Payment is processed securely.
                    Your renewal confirmation will be available once your request is approved.
                  </p>

                  <div style={rnFeeSummary}>
                    <div style={rnFeeRow}><span>Registration renewal fee</span><span>$50.00</span></div>
                    <div style={rnFeeRow}><span>Technology fee</span><span>$0.00</span></div>
                    <div style={{ ...rnFeeRow, fontWeight: 700, borderTop: '2px solid var(--color-border)', paddingTop: '12px', marginTop: '8px' }}>
                      <span>Total due</span><span style={{ fontSize: '18px', color: 'var(--color-primary)' }}>$50.00</span>
                    </div>
                  </div>

                  <h3 style={rnSubHeading}>Payment Method</h3>
                  <div className="form-group">
                    <select name="payMethod" value={rnForm.payMethod} onChange={rnHandle}>
                      <option value="credit">Credit Card</option>
                      <option value="debit">Debit Card</option>
                      <option value="cash">Cash</option>
                      <option value="echeck">eCheck / ACH</option>
                    </select>
                  </div>

                  <div className="form-group">
                    <label htmlFor="rn-cn">Name on Card *</label>
                    <input id="rn-cn" name="cardName" type="text" value={rnForm.cardName} onChange={rnHandle} required />
                  </div>

                  <div className="form-group">
                    <label htmlFor="rn-cc">Card Number *</label>
                    <input id="rn-cc" name="cardNumber" type="text" inputMode="numeric" placeholder="•••• •••• •••• ••••" value={rnForm.cardNumber} onChange={rnHandle} required />
                  </div>

                  <div className="form-row">
                    <div className="form-group">
                      <label htmlFor="rn-ce">Expiration *</label>
                      <input id="rn-ce" name="cardExp" type="text" placeholder="MM / YY" value={rnForm.cardExp} onChange={rnHandle} required />
                    </div>
                    <div className="form-group">
                      <label htmlFor="rn-cv">CVV *</label>
                      <input id="rn-cv" name="cardCvv" type="text" inputMode="numeric" maxLength={4} placeholder="•••" value={rnForm.cardCvv} onChange={rnHandle} required style={{ WebkitTextSecurity: 'disc' } as React.CSSProperties} />
                    </div>
                  </div>

                  <div style={rnSecureNote}>
                    <svg width="16" height="16" viewBox="0 0 16 16" fill="none" style={{ flexShrink: 0 }}>
                      <path d="M8 1C6.343 1 5 2.343 5 4v2H4a1 1 0 00-1 1v7a1 1 0 001 1h8a1 1 0 001-1V7a1 1 0 00-1-1h-1V4c0-1.657-1.343-3-3-3zm2 5H6V4a2 2 0 114 0v2z" fill="var(--color-success)" />
                    </svg>
                    <span>Your payment information is encrypted and transmitted securely.</span>
                  </div>

                  {submitError && <p style={{ color: 'var(--color-accent)', fontSize: '14px', marginTop: '12px' }}>{submitError}</p>}
                </>)}

                {/* Step 4: Confirmation */}
                {rnStep === 4 && (
                  <div style={{ textAlign: 'center', padding: 'var(--space-6) 0' }}>
                    <div style={{ fontSize: 56, marginBottom: 12 }} aria-hidden="true">✅</div>
                    <h2 style={{ color: 'var(--color-success)', marginBottom: 8 }}>Renewal Request Submitted</h2>
                    <p style={{ color: 'var(--color-text-muted)', fontSize: 15, maxWidth: 520, margin: '0 auto 24px' }}>
                      Your payment of <strong>$50.00</strong> has been processed and your registration renewal request
                      is now under review. A DMV representative will evaluate your application.
                    </p>

                    {/* Receipt card */}
                    <div style={rnReceiptCard}>
                      <div style={rnReceiptHeader}>
                        <span style={{ fontWeight: 700, fontSize: 13, letterSpacing: 1, textTransform: 'uppercase' }}>Renewal Receipt</span>
                      </div>
                      <div style={{ padding: '20px 24px', display: 'flex', flexDirection: 'column', gap: 10 }}>
                        <div style={rnReceiptRow}>
                          <span style={rnReceiptLabel}>Reference</span>
                          <span style={{ ...rnReceiptValue, fontFamily: 'var(--font-mono)', fontSize: 14 }}>{rnRefNumber}</span>
                        </div>
                        <div style={rnReceiptRow}>
                          <span style={rnReceiptLabel}>Vehicle</span>
                          <span style={rnReceiptValue}>{renewTarget.dmv_year} {renewTarget.dmv_make} {renewTarget.dmv_model}</span>
                        </div>
                        <div style={rnReceiptRow}>
                          <span style={rnReceiptLabel}>Plate #</span>
                          <span style={{ ...rnReceiptValue, fontFamily: 'var(--font-mono)', fontSize: 14 }}>{rnForm.plateNumber.toUpperCase()}</span>
                        </div>
                        <div style={rnReceiptRow}>
                          <span style={rnReceiptLabel}>Status</span>
                          <span style={{ ...rnReceiptValue, color: 'var(--color-warning)' }}>Under Review</span>
                        </div>
                        <div style={rnReceiptRow}>
                          <span style={rnReceiptLabel}>Amount Paid</span>
                          <span style={rnReceiptValue}>$50.00</span>
                        </div>
                      </div>
                    </div>

                    <div style={{ background: 'var(--color-info-bg)', border: '1px solid var(--color-border)', borderRadius: 'var(--radius-md)', padding: '14px 18px', fontSize: 13, color: 'var(--color-text-muted)', maxWidth: 520, margin: '20px auto 28px', textAlign: 'left', lineHeight: 1.6 }}>
                      <strong style={{ color: 'var(--color-primary)' }}>What happens next?</strong>
                      <ol style={{ margin: '8px 0 0 18px', padding: 0 }}>
                        <li>A DMV agent will review your renewal request (typically 1–3 business days).</li>
                        <li>Once approved, your renewal confirmation will be available in your <Link to="/documents" style={{ color: 'var(--color-secondary)', fontWeight: 600 }}>Documents</Link>.</li>
                        <li>Your new registration sticker will arrive by mail in 7–10 business days.</li>
                      </ol>
                    </div>

                    <div style={{ display: 'flex', gap: 16, justifyContent: 'center', flexWrap: 'wrap' }}>
                      <button className="btn btn-primary" onClick={() => { setView('list'); setRnStep(0); setRnForm(RENEW_INIT); setRnAutofilled(false); loadData() }}>
                        Back to My Vehicles
                      </button>
                      <Link to="/documents" className="btn btn-outline">View Documents</Link>
                      <Link to="/" className="btn btn-outline">Return Home</Link>
                    </div>
                  </div>
                )}

                {/* ── Navigation buttons (steps 0–3) ── */}
                {rnStep < 4 && (
                  <div style={{ marginTop: 'var(--space-6)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <div>
                      {rnStep > 0 ? (
                        <button type="button" className="btn btn-ghost" onClick={() => setRnStep(s => s - 1)}>← Back</button>
                      ) : (
                        <button type="button" className="btn btn-ghost" onClick={() => { setView('list'); setRnStep(0); setRnForm(RENEW_INIT); setRnAutofilled(false) }}>← Back to My Vehicles</button>
                      )}
                    </div>
                    <button
                      type="button"
                      className="btn btn-primary"
                      style={{ fontSize: '15px', padding: '12px 32px' }}
                      onClick={() => {
                        if (rnStep === 3) handleRenew()
                        else { setRnStep(s => s + 1); window.scrollTo({ top: 0, behavior: 'smooth' }) }
                      }}
                      disabled={submitting || (rnStep === 0 && !rnForm.plateNumber) || (rnStep === 1 && (!rnForm.firstName || !rnForm.lastName)) || (rnStep === 2 && (!rnForm.insurer || !rnForm.policyNumber))}
                    >
                      {submitting ? 'Processing...' : rnStep === 3 ? 'Pay $50.00 & Submit' : 'Continue →'}
                    </button>
                  </div>
                )}

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

/* ── Renewal wizard styles (matching LicenseRenewal) ── */
const rnStepperWrap: React.CSSProperties = {
  display: 'flex', alignItems: 'flex-start', justifyContent: 'center', gap: 0,
  padding: '24px 0 0',
}
const rnStepTitle: React.CSSProperties = {
  fontFamily: 'var(--font-heading)', fontSize: '1.25rem', fontWeight: 600,
  color: 'var(--color-primary)', marginBottom: 8,
}
const rnStepDesc: React.CSSProperties = {
  color: 'var(--color-text-muted)', fontSize: 14, lineHeight: 1.6,
  marginBottom: 28,
}
const rnSubHeading: React.CSSProperties = {
  fontFamily: 'var(--font-heading)', fontSize: '1rem', fontWeight: 600,
  color: 'var(--color-primary)', marginBottom: 16,
}
const rnFeeSummary: React.CSSProperties = {
  background: 'var(--color-surface-alt)', borderRadius: 'var(--radius-md)',
  padding: '20px 24px', marginBottom: 28,
}
const rnFeeRow: React.CSSProperties = {
  display: 'flex', justifyContent: 'space-between', fontSize: 14,
  padding: '6px 0', color: 'var(--color-text)',
}
const rnSecureNote: React.CSSProperties = {
  display: 'flex', alignItems: 'center', gap: 8,
  fontSize: 13, color: 'var(--color-success)', marginTop: 12,
}
const rnReceiptCard: React.CSSProperties = {
  maxWidth: 420, margin: '0 auto', border: '2px solid var(--color-primary)',
  borderRadius: 'var(--radius-lg)', overflow: 'hidden', textAlign: 'left',
  background: 'var(--color-surface)',
}
const rnReceiptHeader: React.CSSProperties = {
  background: 'var(--color-primary)', color: '#fff', padding: '12px 24px',
}
const rnReceiptRow: React.CSSProperties = {
  display: 'flex', justifyContent: 'space-between', alignItems: 'center',
  padding: '4px 0', borderBottom: '1px solid var(--color-surface-alt)',
}
const rnReceiptLabel: React.CSSProperties = {
  fontSize: 12, fontWeight: 500, color: 'var(--color-text-muted)', textTransform: 'uppercase', letterSpacing: 0.5,
}
const rnReceiptValue: React.CSSProperties = {
  fontSize: 14, fontWeight: 600, color: 'var(--color-text)',
}
