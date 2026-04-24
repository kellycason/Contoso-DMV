import { useEffect, useState, useMemo } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { useAuth } from '../hooks/useAuth'
import { DEMO_DEALER } from '../hooks/usePersona'
import { dvCreate, dvQuery, dvUpdate, fmt } from '../hooks/useDataverse'

/* ══════════════════════════════════════════════════════════════════════
   Fake VIN decoder — realistic 1.5s "decoding" spinner then autofills.
   Deliberately tiny table of well-known VINs; anything else returns a
   generic "decoded but details not found — enter manually" state.
   ══════════════════════════════════════════════════════════════════════ */
const VIN_DB: Record<string, { year: string; make: string; model: string; bodyStyle: number; fuelType: number; msrp: number }> = {
  '1HGCM82633A123456': { year: '2024', make: 'Honda',    model: 'Civic',    bodyStyle: 100000000, fuelType: 100000000, msrp: 24500 },
  '5YJ3E1EA4PF000111': { year: '2024', make: 'Tesla',    model: 'Model 3',  bodyStyle: 100000000, fuelType: 100000002, msrp: 42990 },
  '1FTFW1E50NFA20198': { year: '2024', make: 'Ford',     model: 'F-150',    bodyStyle: 100000002, fuelType: 100000000, msrp: 48500 },
  'JTMBFREV7KD123456': { year: '2024', make: 'Toyota',   model: 'RAV4',     bodyStyle: 100000001, fuelType: 100000003, msrp: 32400 },
  '1GCUYEED5MZ201234': { year: '2024', make: 'Chevrolet',model: 'Silverado',bodyStyle: 100000002, fuelType: 100000000, msrp: 51200 },
  'WBA5A7C50KD123456': { year: '2024', make: 'BMW',      model: '3 Series', bodyStyle: 100000000, fuelType: 100000000, msrp: 46700 },
}

/* Choice option-set values — matches dataverse */
const BODY_STYLE_LABELS: Record<number, string> = {
  100000000: 'Sedan', 100000001: 'SUV', 100000002: 'Truck', 100000003: 'Van',
  100000004: 'Motorcycle', 100000005: 'RV', 100000006: 'Other',
}
const FUEL_LABELS: Record<number, string> = {
  100000000: 'Gasoline', 100000001: 'Diesel', 100000002: 'Electric', 100000003: 'Hybrid', 100000004: 'Hydrogen',
}
const PLATE_TYPES: { value: number; label: string; fee: number }[] = [
  { value: 100000000, label: 'Standard',     fee: 0 },
  { value: 100000001, label: 'Personalized', fee: 75 },
  { value: 100000002, label: 'Dealer',       fee: 25 },
  { value: 100000003, label: 'Exempt',       fee: 0 },
]
const REG_STATUS_LABELS: Record<number, string> = {
  100000000: 'Active', 100000001: 'Expired', 100000002: 'Pending Payment',
  100000003: 'Pending Inspection', 100000004: 'Suspended', 100000005: 'Cancelled',
  100000006: 'Submitted', 100000007: 'Under Review', 100000008: 'Rejected',
}
const REJECTION_LABELS: Record<number, string> = {
  100000000: 'Invalid VIN', 100000001: 'Insurance Lapsed', 100000002: 'Title Defect',
  100000003: 'Sales Tax Dispute', 100000004: 'Missing Documents', 100000005: 'Other',
}

/* Submission channel values */
const CHANNEL_DEALER = 100000000

/* Demo fee formula (flat, simple, explainable) */
function computeFees(_msrp: number, plateType: number) {
  const title = 33
  const base = 50.75
  const processing = 4.75
  const county = 11.50
  const plate = PLATE_TYPES.find(p => p.value === plateType)?.fee ?? 0
  const total = +(title + base + processing + county + plate).toFixed(2)
  return { title, base, processing, county, plate, total }
}

function pad4(n: number) { return n.toString().padStart(4, '0') }

interface DealerForm {
  vin: string
  year: string
  make: string
  model: string
  color: string
  bodyStyle: number
  fuelType: number
  msrp: string
  odometer: string
  customerFirst: string
  customerLast: string
  customerEmail: string
  customerPhone: string
  customerAddress: string
  customerCity: string
  customerState: string
  customerZip: string
  insCarrier: string
  insPolicy: string
  insExp: string
  plateType: number
  purchaseDate: string
  purchasePrice: string
}

const INITIAL_FORM: DealerForm = {
  vin: '', year: '', make: '', model: '', color: 'White',
  bodyStyle: 100000000, fuelType: 100000000, msrp: '', odometer: '15',
  // Demo autofill so the dealer flow is fast to walk through
  customerFirst: 'Sam', customerLast: 'Smith',
  customerEmail: 'kellycason+sam@microsoft.com', customerPhone: '(555) 314-1593',
  customerAddress: '4210 Magnolia Ln', customerCity: 'Contoso', customerState: 'TX', customerZip: '78704',
  insCarrier: 'Contoso Mutual Auto', insPolicy: 'POL-2026-00483',
  insExp: (() => { const d = new Date(); d.setFullYear(d.getFullYear() + 1); return d.toISOString().split('T')[0] })(),
  plateType: 100000000,
  purchaseDate: new Date().toISOString().split('T')[0],
  purchasePrice: '',
}

type View = 'form' | 'confirmation' | 'submissions' | 'detail'

export default function DealerNewRegistration() {
  const { isAuthenticated } = useAuth()
  const [searchParams] = useSearchParams()
  const initialView = (searchParams.get('view') as View) || 'form'
  const [view, setView] = useState<View>(initialView)
  const [form, setForm] = useState<DealerForm>(INITIAL_FORM)

  // VIN decoding state
  const [decoding, setDecoding] = useState(false)
  const [vinStatus, setVinStatus] = useState<'' | 'found' | 'unknown'>('')

  // Submission state
  const [submitting, setSubmitting] = useState(false)
  const [submitError, setSubmitError] = useState('')

  // Last confirmation payload
  const [confirmation, setConfirmation] = useState<{
    regRef: string; regId: string; tagNumber: string; tagExp: Date; total: number
  } | null>(null)

  // Dealer submission list
  const [submissions, setSubmissions] = useState<Record<string, any>[]>([])
  const [loadingSubs, setLoadingSubs] = useState(true)
  const [selectedId, setSelectedId] = useState<string | null>(null)

  const fees = useMemo(() => computeFees(parseFloat(form.msrp) || 0, form.plateType), [form.msrp, form.plateType])

  const loadSubs = async () => {
    setLoadingSubs(true)
    try {
      const recs = await dvQuery('dmv_vehicleregistrations',
        `$filter=_dmv_dealeracctid_value eq ${DEMO_DEALER.accountId}` +
        `&$select=dmv_vehicleregistrationid,dmv_registrationid,dmv_regstatus,dmv_submitteddate,dmv_totaldue,` +
        `dmv_rejectionreason,dmv_rejectionnotes,dmv_insuranceverified,_dmv_vehicleid_value,_dmv_regcontactid_value` +
        `&$expand=dmv_vehicleid($select=dmv_vin,dmv_make,dmv_model,dmv_year,dmv_color,dmv_platenumber)` +
        `,dmv_regcontactid($select=firstname,lastname)` +
        `&$orderby=dmv_submitteddate desc&$top=50`
      )
      setSubmissions(recs)
    } catch (e) {
      console.error('[Dealer] load submissions', e)
    } finally {
      setLoadingSubs(false)
    }
  }

  useEffect(() => { loadSubs() }, [])

  /* ────── VIN decoder ────── */
  const triggerDecode = (vin: string) => {
    setDecoding(true); setVinStatus('')
    const clean = vin.trim().toUpperCase()
    setTimeout(() => {
      const hit = VIN_DB[clean]
      if (hit) {
        setForm(f => ({
          ...f,
          vin: clean,
          year: hit.year, make: hit.make, model: hit.model,
          bodyStyle: hit.bodyStyle, fuelType: hit.fuelType,
          msrp: String(hit.msrp),
          purchasePrice: f.purchasePrice || String(hit.msrp),
        }))
        setVinStatus('found')
      } else {
        setVinStatus('unknown')
      }
      setDecoding(false)
    }, 1500)
  }

  const handle = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const { name, value } = e.target
    if (name === 'bodyStyle' || name === 'fuelType' || name === 'plateType') {
      setForm(f => ({ ...f, [name]: parseInt(value, 10) }))
    } else {
      setForm(f => ({ ...f, [name]: value }))
    }
  }

  const handleVinBlur = () => {
    const clean = form.vin.trim().toUpperCase()
    if (clean && clean.length >= 11 && clean !== form.vin) setForm(f => ({ ...f, vin: clean }))
    if (clean.length >= 11 && vinStatus === '') triggerDecode(clean)
  }

  /* ────── Submit new registration ────── */
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setSubmitting(true); setSubmitError('')
    let step = 'init'
    try {
      const today = new Date()
      const expDate = new Date(today); expDate.setFullYear(expDate.getFullYear() + 1)
      const tagExp = new Date(today); tagExp.setDate(tagExp.getDate() + 30)

      // 1a. Find-or-create the citizen contact (match by email, fallback by name)
      let contactId: string | undefined
      const email = form.customerEmail.trim()
      if (email) {
        step = 'find-contact'
        const hits = await dvQuery(
          'contacts',
          `$filter=emailaddress1 eq '${email.replace(/'/g, "''")}'&$select=contactid&$top=1`
        )
        contactId = hits[0]?.contactid
      }
      if (!contactId) {
        step = 'create-contact'
        contactId = await dvCreate('contacts', {
          firstname: form.customerFirst,
          lastname:  form.customerLast,
          emailaddress1: email || undefined,
          telephone1: form.customerPhone || undefined,
          address1_line1: form.customerAddress || undefined,
          address1_city: form.customerCity || undefined,
          address1_stateorprovince: form.customerState || undefined,
          address1_postalcode: form.customerZip || undefined,
        })
      }

      // 1. Create vehicle
      step = 'create-vehicle'
      const vehicleId = await dvCreate('dmv_vehicles', {
        dmv_vin: form.vin,
        dmv_year: form.year,
        dmv_make: form.make,
        dmv_model: form.model,
        dmv_color: form.color,
        dmv_bodystyle: form.bodyStyle,
        dmv_fueltype: form.fuelType,
        dmv_odometer: parseInt(form.odometer, 10) || 0,
        dmv_msrp: parseFloat(form.msrp) || 0,
        dmv_platetype: form.plateType,
        dmv_platestate: form.customerState || 'TX',
        dmv_outofstate: false,
        dmv_salvagetitle: false,
        dmv_insurancestatus: 100000000,
        dmv_insurancecarrier: form.insCarrier,
        dmv_insurancepolicy: form.insPolicy,
        dmv_insuranceexp: form.insExp ? `${form.insExp}T00:00:00Z` : undefined,
      })

      // 2. Create registration (status=Submitted, channel=Dealer)
      step = 'create-registration'
      const regId = await dvCreate('dmv_vehicleregistrations', {
        dmv_regstatus: 100000006,                      // Submitted
        dmv_regtype: 100000000,                        // New (assumed option 0)
        dmv_regyear: today.getFullYear(),
        dmv_submissionchannel: CHANNEL_DEALER,
        dmv_submitteddate: today.toISOString(),
        dmv_effectivedate: today.toISOString().split('T')[0] + 'T00:00:00Z',
        dmv_expirationdate: expDate.toISOString().split('T')[0] + 'T00:00:00Z',
        dmv_fee: fees.base,
        dmv_totaldue: fees.total,
        dmv_paymentstatus: 100000001,                  // Paid (dealer pays at sale)
        dmv_paymentdate: today.toISOString(),
        dmv_paymentmethod: 100000000,                  // Credit Card
        dmv_insuranceverified: false,                  // flow will flip this
        'dmv_vehicleid@odata.bind': `/dmv_vehicles(${vehicleId})`,
        'dmv_dealeracctid@odata.bind': `/accounts(${DEMO_DEALER.accountId})`,
        'dmv_regcontactid@odata.bind': `/contacts(${contactId})`,
      })

      // 3. Issue temporary tag (Pending — becomes Active on DMV approval; only then visible on citizen portal)
      step = 'create-temp-tag'
      const tagNumber = `TMP-${today.getFullYear()}-${pad4(Math.floor(Math.random() * 10000))}`
      await dvCreate('dmv_temporarytags', {
        dmv_tagnumber: tagNumber,
        dmv_buyername: `${form.customerFirst} ${form.customerLast}`.trim(),
        dmv_issuedate: today.toISOString().split('T')[0] + 'T00:00:00Z',
        dmv_expirationdate: tagExp.toISOString().split('T')[0] + 'T00:00:00Z',
        dmv_tagstatus: 100000004,                      // Pending (flow flips to Active on approval)
        dmv_saleprice: parseFloat(form.purchasePrice) || parseFloat(form.msrp) || 0,
        dmv_printcount: 0,
        'dmv_vehicleid@odata.bind': `/dmv_vehicles(${vehicleId})`,
        'dmv_dealeracctid@odata.bind': `/accounts(${DEMO_DEALER.accountId})`,
        'dmv_generatedby@odata.bind': `/contacts(${contactId})`, // citizen — lets portal filter find it
      })

      // 4. Fetch autonumber reg id
      const created = await dvQuery('dmv_vehicleregistrations',
        `$filter=dmv_vehicleregistrationid eq ${regId}&$select=dmv_registrationid`
      )
      const regRef = created[0]?.dmv_registrationid || regId

      setConfirmation({ regRef, regId, tagNumber, tagExp, total: fees.total })
      setView('confirmation')
      loadSubs()
    } catch (err) {
      setSubmitError(`[${step}] ${err instanceof Error ? err.message : 'Submission failed.'}`)
    } finally {
      setSubmitting(false)
    }
  }

  const newForm = () => { setForm(INITIAL_FORM); setVinStatus(''); setConfirmation(null); setView('form') }

  /* ────── Gatekeeping ────── */
  if (!isAuthenticated) {
    return (
      <div className="section-sm">
        <div className="container" style={{ maxWidth: 620, textAlign: 'center', padding: '48px 24px' }}>
          <div style={{ fontSize: 48, marginBottom: 16 }}>🏢</div>
          <h2 style={{ color: 'var(--color-primary)', marginBottom: 12 }}>Dealer Sign-In Required</h2>
          <p style={{ color: 'var(--color-text-muted)', marginBottom: 24 }}>
            Please sign in with your authorized dealer rep account to submit new vehicle registrations.
          </p>
          <a href="/Account/Login/ExternalLogin" className="btn btn-primary">Sign In</a>
        </div>
      </div>
    )
  }

  /* ══════════════════════════════════════════════════════════════════════
     HEADER (common across views)
     ══════════════════════════════════════════════════════════════════════ */
  return (
    <>
      <div className="page-header">
        <div className="container">
          <nav className="breadcrumb" aria-label="Breadcrumb">
            <Link to="/">Home</Link>
            <span className="breadcrumb-sep" aria-hidden="true">›</span>
            <Link to="/dealer">Dealer Portal</Link>
            <span className="breadcrumb-sep" aria-hidden="true">›</span>
            <span aria-current="page">New Registration</span>
          </nav>
          <h1>New Vehicle Registration</h1>
          <p>
            Submit new vehicle registrations on behalf of <strong>{DEMO_DEALER.accountName}</strong>.
            Temporary tags issue at submission; plates mail to the customer once DMV approves.
          </p>
        </div>
      </div>

      <div className="section-sm">
        <div className="container" style={{ maxWidth: 1100 }}>
          {/* Tab row: Form | My Submissions */}
          <div style={S.tabBar}>
            <button
              className={`tab ${view === 'form' || view === 'confirmation' ? 'tab-active' : ''}`}
              style={view === 'form' || view === 'confirmation' ? S.tabActive : S.tab}
              onClick={() => { if (view !== 'form') newForm() }}
            >
              + New Registration
            </button>
            <button
              className={`tab ${view === 'submissions' || view === 'detail' ? 'tab-active' : ''}`}
              style={view === 'submissions' || view === 'detail' ? S.tabActive : S.tab}
              onClick={() => { setView('submissions'); setSelectedId(null) }}
            >
              My Submissions {submissions.length > 0 && <span style={S.tabBadge}>{submissions.length}</span>}
            </button>
          </div>

          {/* ══════════════ FORM VIEW ══════════════ */}
          {view === 'form' && (
            <>
              {/* Dealer info chip — above both columns so the cards align flush */}
              <div style={S.chip}>
                <span aria-hidden="true">🏢</span>
                <span>Submitting as <strong>{DEMO_DEALER.contactName}</strong> · {DEMO_DEALER.accountName} · {DEMO_DEALER.jobTitle}</span>
              </div>

              <form onSubmit={handleSubmit} style={{ display: 'grid', gridTemplateColumns: 'minmax(0,1fr) 320px', gap: 24, alignItems: 'start' }}>
                <div style={{ minWidth: 0 }}>
                  {/* VIN section */}
                  <section style={S.card}>
                    <h2 style={S.h2}>Vehicle Information</h2>
                    <p style={S.muted}>Enter the VIN first — we'll auto-decode make, model, year, and MSRP.</p>

                    <div style={S.grid1}>
                      <div className="form-group" style={{ position: 'relative' }}>
                        <label htmlFor="vin">VIN *</label>
                        <input
                          id="vin" name="vin" type="text" required maxLength={17}
                          value={form.vin} onChange={handle} onBlur={handleVinBlur}
                          style={{ fontFamily: 'var(--font-mono)', letterSpacing: '0.05em', textTransform: 'uppercase' }}
                          placeholder="1HGCM82633A123456"
                        />
                        {decoding && (
                          <div style={S.vinBadge}>
                            <span style={S.spinner} aria-hidden="true" /> Decoding VIN…
                          </div>
                        )}
                        {!decoding && vinStatus === 'found' && (
                          <div style={{ ...S.vinBadge, background: '#e8f5e9', color: '#1b5e20' }}>✓ VIN decoded</div>
                        )}
                        {!decoding && vinStatus === 'unknown' && (
                          <div style={{ ...S.vinBadge, background: '#fff3cd', color: '#856404' }}>⚠ Not in decoder DB — enter manually</div>
                        )}
                      </div>
                    </div>

                    <details style={{ marginTop: -4, marginBottom: 16 }}>
                      <summary style={{ cursor: 'pointer', fontSize: 12, color: 'var(--color-text-muted)' }}>
                        Demo VINs you can try
                      </summary>
                      <ul style={{ margin: '8px 0', padding: '0 0 0 20px', fontSize: 12, fontFamily: 'var(--font-mono)', color: 'var(--color-text-muted)', lineHeight: 1.7 }}>
                        {Object.entries(VIN_DB).map(([v, d]) => (
                          <li key={v}>
                            <button type="button" onClick={() => { setForm(f => ({ ...f, vin: v })); triggerDecode(v) }}
                              style={{ background: 'none', border: 'none', color: 'var(--color-accent)', cursor: 'pointer', padding: 0, fontFamily: 'inherit', fontSize: 'inherit' }}>
                              {v}
                            </button> — {d.year} {d.make} {d.model}
                          </li>
                        ))}
                      </ul>
                    </details>

                    <div style={S.grid3}>
                      <div className="form-group"><label htmlFor="year">Year *</label><input id="year" name="year" type="text" required value={form.year} onChange={handle} /></div>
                      <div className="form-group"><label htmlFor="make">Make *</label><input id="make" name="make" type="text" required value={form.make} onChange={handle} /></div>
                      <div className="form-group"><label htmlFor="model">Model *</label><input id="model" name="model" type="text" required value={form.model} onChange={handle} /></div>
                    </div>
                    <div style={S.grid3}>
                      <div className="form-group"><label htmlFor="color">Color</label><input id="color" name="color" type="text" value={form.color} onChange={handle} /></div>
                      <div className="form-group">
                        <label htmlFor="bodyStyle">Body Style</label>
                        <select id="bodyStyle" name="bodyStyle" value={form.bodyStyle} onChange={handle}>
                          {Object.entries(BODY_STYLE_LABELS).map(([v, l]) => <option key={v} value={v}>{l}</option>)}
                        </select>
                      </div>
                      <div className="form-group">
                        <label htmlFor="fuelType">Fuel</label>
                        <select id="fuelType" name="fuelType" value={form.fuelType} onChange={handle}>
                          {Object.entries(FUEL_LABELS).map(([v, l]) => <option key={v} value={v}>{l}</option>)}
                        </select>
                      </div>
                    </div>
                    <div style={S.grid4}>
                      <div className="form-group"><label htmlFor="odometer">Odometer (mi)</label><input id="odometer" name="odometer" type="number" value={form.odometer} onChange={handle} /></div>
                      <div className="form-group"><label htmlFor="msrp">MSRP *</label><input id="msrp" name="msrp" type="number" step="0.01" required value={form.msrp} onChange={handle} /></div>
                      <div className="form-group"><label htmlFor="purchasePrice">Purchase Price *</label><input id="purchasePrice" name="purchasePrice" type="number" step="0.01" required value={form.purchasePrice} onChange={handle} /></div>
                      <div className="form-group"><label htmlFor="purchaseDate">Purchase Date *</label><input id="purchaseDate" name="purchaseDate" type="date" required value={form.purchaseDate} onChange={handle} /></div>
                    </div>
                  </section>

                  {/* Customer section */}
                  <section style={S.card}>
                    <h2 style={S.h2}>Customer Information</h2>
                    <p style={S.muted}>Prefilled with demo data — edit as needed.</p>
                    <div style={S.grid2}>
                      <div className="form-group"><label htmlFor="cf">First Name *</label><input id="cf" name="customerFirst" type="text" required value={form.customerFirst} onChange={handle} /></div>
                      <div className="form-group"><label htmlFor="cl">Last Name *</label><input id="cl" name="customerLast" type="text" required value={form.customerLast} onChange={handle} /></div>
                    </div>
                    <div style={S.grid2}>
                      <div className="form-group"><label htmlFor="ce">Email *</label><input id="ce" name="customerEmail" type="email" required value={form.customerEmail} onChange={handle} /></div>
                      <div className="form-group"><label htmlFor="cp">Phone *</label><input id="cp" name="customerPhone" type="tel" required value={form.customerPhone} onChange={handle} /></div>
                    </div>
                    <div style={S.gridAddress}>
                      <div className="form-group"><label htmlFor="ca">Street Address *</label><input id="ca" name="customerAddress" type="text" required value={form.customerAddress} onChange={handle} /></div>
                      <div className="form-group"><label htmlFor="cc">City</label><input id="cc" name="customerCity" type="text" value={form.customerCity} onChange={handle} /></div>
                      <div className="form-group"><label htmlFor="cs">State</label><input id="cs" name="customerState" type="text" value={form.customerState} onChange={handle} /></div>
                      <div className="form-group"><label htmlFor="cz">ZIP</label><input id="cz" name="customerZip" type="text" value={form.customerZip} onChange={handle} /></div>
                    </div>
                  </section>

                  {/* Insurance section */}
                  <section style={S.card}>
                    <h2 style={S.h2}>Insurance</h2>
                    <p style={S.muted}>Prefilled with demo carrier — edit as needed.</p>
                    <div style={S.grid3}>
                      <div className="form-group"><label htmlFor="ic">Carrier *</label><input id="ic" name="insCarrier" type="text" required value={form.insCarrier} onChange={handle} /></div>
                      <div className="form-group"><label htmlFor="ip">Policy # *</label><input id="ip" name="insPolicy" type="text" required value={form.insPolicy} onChange={handle} placeholder="POL-2026-00123" /></div>
                      <div className="form-group"><label htmlFor="ie">Expiration *</label><input id="ie" name="insExp" type="date" required value={form.insExp} onChange={handle} /></div>
                    </div>
                  </section>

                  {/* Plate + submit */}
                  <section style={S.card}>
                    <h2 style={S.h2}>Plate Type</h2>
                    <div style={S.grid3}>
                      <div className="form-group">
                        <label htmlFor="pt">Plate Type *</label>
                        <select id="pt" name="plateType" value={form.plateType} onChange={handle}>
                          {PLATE_TYPES.map(p => <option key={p.value} value={p.value}>{p.label}</option>)}
                        </select>
                      </div>
                      <div />
                      <div />
                    </div>
                  </section>

                  {submitError && (
                    <div style={S.errBox}>
                      <strong>Submission error:</strong> {submitError}
                    </div>
                  )}

                  <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 12, marginTop: 20 }}>
                    <button type="button" className="btn btn-ghost" onClick={newForm}>Reset</button>
                    <button type="submit" className="btn btn-primary" disabled={submitting}>
                      {submitting ? 'Submitting to DMV…' : `Submit & Issue Temp Tag · $${fees.total.toFixed(2)}`}
                    </button>
                  </div>
                </div>

                {/* Right column: live fee panel */}
                <aside style={S.feePanel}>
                  <div style={S.feePanelHeader}>Live Fee Summary</div>
                  <div style={S.feeRow}><span>Title Application Fee</span><span>${fees.title.toFixed(2)}</span></div>
                  <div style={S.feeRow}><span>Registration Fee</span><span>${fees.base.toFixed(2)}</span></div>
                  <div style={S.feeRow}><span>Processing &amp; Handling</span><span>${fees.processing.toFixed(2)}</span></div>
                  <div style={S.feeRow}><span>County Fee</span><span>${fees.county.toFixed(2)}</span></div>
                  {fees.plate > 0 && (
                    <div style={S.feeRow}><span>{PLATE_TYPES.find(p => p.value === form.plateType)?.label} Plate</span><span>${fees.plate.toFixed(2)}</span></div>
                  )}
                  <div style={{ ...S.feeRow, ...S.feeTotal }}><span>Total Due</span><span>${fees.total.toFixed(2)}</span></div>
                  <div style={S.feeNote}>
                    Dealer remits with monthly DMV settlement. Customer receives:
                    <ul style={{ margin: '6px 0 0', paddingLeft: 18 }}>
                      <li>30-day temp tag (at submission)</li>
                      <li>Metal plates (DMV mails after approval)</li>
                      <li>Registration sticker</li>
                    </ul>
                  </div>
                </aside>
              </form>
            </>
          )}

          {/* ══════════════ CONFIRMATION VIEW ══════════════ */}
          {view === 'confirmation' && confirmation && (
            <div style={S.card}>
              <div style={{ textAlign: 'center', marginBottom: 24 }}>
                <div style={{ fontSize: 64, marginBottom: 8 }}>✅</div>
                <h2 style={{ margin: 0, color: 'var(--color-primary)' }}>Registration Submitted</h2>
                <p style={{ color: 'var(--color-text-muted)', margin: '6px 0 0' }}>
                  DMV will review and issue the temporary tag on approval. You'll be notified by email.
                </p>
              </div>

              <div style={S.confGrid}>
                <div style={S.confTile}>
                  <div style={S.confLabel}>Registration Reference</div>
                  <div style={S.confValue}>{confirmation.regRef}</div>
                  <div style={S.confSub}>Status: <strong>Submitted</strong></div>
                </div>
                <div style={S.confTile}>
                  <div style={S.confLabel}>Temporary Tag</div>
                  <div style={{ ...S.confValue, color: 'var(--color-text-muted)', fontSize: 18 }}>Pending Approval</div>
                  <div style={S.confSub}>Available once DMV approves</div>
                </div>
                <div style={S.confTile}>
                  <div style={S.confLabel}>Amount Paid</div>
                  <div style={S.confValue}>${confirmation.total.toFixed(2)}</div>
                  <div style={S.confSub}>Dealer remittance</div>
                </div>
              </div>

              <div style={S.nextSteps}>
                <h3 style={{ margin: '0 0 8px', fontSize: 15, color: 'var(--color-primary)' }}>What happens next</h3>
                <ol style={{ margin: 0, paddingLeft: 22, lineHeight: 1.7, fontSize: 13, color: 'var(--color-text)' }}>
                  <li>Our system verifies the customer's insurance (~30 sec automated).</li>
                  <li>DMV staff review for title defects and tax compliance (typically same day).</li>
                  <li>On approval, metal plates + registration sticker are mailed to the customer within 5–10 business days.</li>
                  <li>You and the customer receive email notification at each step.</li>
                </ol>
              </div>

              <div style={{ display: 'flex', flexWrap: 'wrap', justifyContent: 'center', gap: 12, marginTop: 24 }}>
                <button className="btn btn-primary" onClick={() => setView('submissions')}>View My Submissions</button>
                <button className="btn btn-ghost" onClick={newForm}>+ Register Another Vehicle</button>
              </div>
            </div>
          )}

          {/* ══════════════ SUBMISSIONS LIST VIEW ══════════════ */}
          {view === 'submissions' && (
            <div>
              {loadingSubs && <p style={{ color: 'var(--color-text-muted)', padding: 24 }}>Loading submissions…</p>}
              {!loadingSubs && submissions.length === 0 && (
                <div style={{ ...S.card, textAlign: 'center', padding: '48px 20px' }}>
                  <div style={{ fontSize: 48, marginBottom: 12 }}>📋</div>
                  <p style={{ marginBottom: 16 }}>No submissions yet for {DEMO_DEALER.accountName}.</p>
                  <button className="btn btn-primary" onClick={newForm}>+ Submit First Registration</button>
                </div>
              )}
              {!loadingSubs && submissions.length > 0 && (
                <div style={S.card}>
                  <h2 style={S.h2}>All Submissions</h2>
                  <table style={S.table}>
                    <thead>
                      <tr>
                        <th style={S.th}>Reg #</th>
                        <th style={S.th}>Customer</th>
                        <th style={S.th}>Vehicle</th>
                        <th style={S.th}>Submitted</th>
                        <th style={S.th}>Status</th>
                        <th style={S.th} align="right">Total</th>
                      </tr>
                    </thead>
                    <tbody>
                      {submissions.map(r => {
                        const status = r.dmv_regstatus as number
                        const statusLabel = REG_STATUS_LABELS[status] ?? fmt(r, 'dmv_regstatus')
                        const v = r.dmv_vehicleid || {}
                        const c = r.dmv_regcontactid || {}
                        return (
                          <tr key={r.dmv_vehicleregistrationid} style={{ cursor: 'pointer' }}
                              onClick={() => { setSelectedId(r.dmv_vehicleregistrationid); setView('detail') }}>
                            <td style={S.td}><span className="mono">{r.dmv_registrationid}</span></td>
                            <td style={S.td}>{c.firstname || ''} {c.lastname || ''}</td>
                            <td style={S.td}>{v.dmv_year} {v.dmv_make} {v.dmv_model}</td>
                            <td style={S.td}>{r.dmv_submitteddate ? new Date(r.dmv_submitteddate).toLocaleDateString() : '—'}</td>
                            <td style={S.td}><StatusPill status={statusLabel} /></td>
                            <td style={S.td} align="right">${(r.dmv_totaldue ?? 0).toFixed(2)}</td>
                          </tr>
                        )
                      })}
                    </tbody>
                  </table>
                </div>
              )}
            </div>
          )}

          {/* ══════════════ DETAIL VIEW ══════════════ */}
          {view === 'detail' && selectedId && (
            <DealerSubmissionDetail
              record={submissions.find(r => r.dmv_vehicleregistrationid === selectedId)}
              onBack={() => { setView('submissions'); setSelectedId(null) }}
              onResubmit={async (origId) => {
                // clone: set status back to Submitted, clear rejection info
                await dvUpdate('dmv_vehicleregistrations', origId, {
                  dmv_regstatus: 100000006,                 // Submitted
                  dmv_rejectionreason: null,
                  dmv_rejectionnotes: null,
                  dmv_submitteddate: new Date().toISOString(),
                })
                await loadSubs()
                setView('submissions')
              }}
            />
          )}
        </div>
      </div>
    </>
  )
}

/* ════════════════════════════════════════════════════════════════════════
   Sub-component: detail view with status tracker
   ════════════════════════════════════════════════════════════════════════ */
function DealerSubmissionDetail({ record, onBack, onResubmit }: { record?: Record<string, any>, onBack: () => void, onResubmit: (id: string) => void }) {
  if (!record) return <p>Record not found. <button className="btn btn-ghost" onClick={onBack}>Back</button></p>
  const status = record.dmv_regstatus as number
  const v = record.dmv_vehicleid || {}
  const c = record.dmv_regcontactid || {}
  const vehicleId = record._dmv_vehicleid_value
  const [tag, setTag] = useState<Record<string, any> | null>(null)

  useEffect(() => {
    // Only fetch the approved (Active) temp tag once DMV has approved the registration
    if (status !== 100000000 || !vehicleId) return
    dvQuery('dmv_temporarytags',
      `$filter=_dmv_vehicleid_value eq ${vehicleId} and dmv_tagstatus eq 100000000` +
      `&$select=dmv_tagnumber,dmv_buyername,dmv_issuedate,dmv_expirationdate` +
      `&$orderby=dmv_issuedate desc&$top=1`
    ).then(rows => { if (rows[0]) setTag(rows[0]) }).catch(() => {})
  }, [status, vehicleId])

  const steps = [
    { key: 'submitted',   label: 'Submitted',          active: status >= 100000006 },
    { key: 'insurance',   label: 'Insurance Verified', active: !!record.dmv_insuranceverified || status >= 100000007 },
    { key: 'review',      label: 'Under DMV Review',   active: status === 100000007 || status === 100000000 || status === 100000008 },
    { key: 'decision',    label: status === 100000008 ? 'Rejected' : 'Approved',
      active: status === 100000000 || status === 100000008,
      bad: status === 100000008 },
  ]

  return (
    <div>
      <button className="btn btn-ghost" onClick={onBack} style={{ marginBottom: 12 }}>← Back to Submissions</button>
      <div style={S.card}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: 12 }}>
          <div>
            <h2 style={{ ...S.h2, marginBottom: 4 }}>
              {v.dmv_year} {v.dmv_make} {v.dmv_model}
            </h2>
            <p style={{ color: 'var(--color-text-muted)', margin: 0 }}>
              Reg: <span className="mono">{record.dmv_registrationid}</span>
              {' · '}Customer: {c.firstname} {c.lastname}
              {' · '}VIN: <span className="mono">{v.dmv_vin}</span>
            </p>
          </div>
          <StatusPill status={REG_STATUS_LABELS[status] ?? fmt(record, 'dmv_regstatus')} />
        </div>

        {/* Status tracker */}
        <div style={S.tracker}>
          {steps.map((s, i) => (
            <div key={s.key} style={{ display: 'flex', alignItems: 'center', flex: 1 }}>
              <div style={{
                width: 32, height: 32, borderRadius: '50%',
                background: s.bad ? '#e53935' : s.active ? 'var(--color-success)' : 'var(--color-surface-alt)',
                color: s.active || s.bad ? '#fff' : 'var(--color-text-muted)',
                border: s.active || s.bad ? 'none' : '2px solid var(--color-border)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontSize: 14, fontWeight: 700, flexShrink: 0,
              }}>{s.bad ? '✕' : s.active ? '✓' : i + 1}</div>
              <div style={{ marginLeft: 8, flex: 1 }}>
                <div style={{ fontSize: 12, fontWeight: 600, color: s.active || s.bad ? 'var(--color-primary)' : 'var(--color-text-muted)' }}>
                  {s.label}
                </div>
              </div>
              {i < steps.length - 1 && (
                <div style={{ height: 2, flex: 1, background: steps[i + 1].active || steps[i + 1].bad ? 'var(--color-success)' : 'var(--color-border)' }} />
              )}
            </div>
          ))}
        </div>

        {/* Rejection block */}
        {status === 100000008 && (
          <div style={S.rejectBlock}>
            <h3 style={{ margin: '0 0 6px', fontSize: 14, color: '#b71c1c' }}>
              Rejected — {REJECTION_LABELS[record.dmv_rejectionreason] ?? 'See notes'}
            </h3>
            {record.dmv_rejectionnotes && (
              <p style={{ margin: 0, fontSize: 13, color: '#5f1515', whiteSpace: 'pre-wrap' }}>
                {record.dmv_rejectionnotes}
              </p>
            )}
            <div style={{ marginTop: 12, display: 'flex', gap: 10 }}>
              <button className="btn btn-primary" onClick={() => onResubmit(record.dmv_vehicleregistrationid)}>
                Resubmit for Review
              </button>
            </div>
          </div>
        )}

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: 16, marginTop: 24 }}>
          <div>
            <h4 style={S.detailHeader}>Vehicle</h4>
            <Row label="VIN" value={v.dmv_vin} mono />
            <Row label="Color" value={v.dmv_color} />
            <Row label="Plate Assigned" value={v.dmv_platenumber || '— pending —'} mono />
          </div>
          <div>
            <h4 style={S.detailHeader}>Customer</h4>
            <Row label="Name" value={`${c.firstname || ''} ${c.lastname || ''}`.trim()} />
          </div>
          <div>
            <h4 style={S.detailHeader}>Fees</h4>
            <Row label="Total Due" value={`$${(record.dmv_totaldue ?? 0).toFixed(2)}`} />
            <Row label="Payment" value={fmt(record, 'dmv_paymentstatus')} />
          </div>
        </div>
      </div>

      {/* Approved temp tag (only shown when registration is Active) */}
      {status === 100000000 && tag && (
        <div style={{ ...S.card, marginTop: 16 }} className="no-print-container">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12, flexWrap: 'wrap', gap: 8 }}>
            <h3 style={{ margin: 0, color: 'var(--color-primary)' }}>Temporary Tag — Approved</h3>
            <button className="btn btn-primary no-print" onClick={() => window.print()}>🖨️ Print Tag</button>
          </div>
          <TempTagCard tag={tag} vehicle={v} />
        </div>
      )}
    </div>
  )
}

function Row({ label, value, mono }: { label: string, value: string, mono?: boolean }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', padding: '4px 0', fontSize: 13, borderBottom: '1px dotted var(--color-border)' }}>
      <span style={{ color: 'var(--color-text-muted)' }}>{label}</span>
      <span className={mono ? 'mono' : undefined}>{value || '—'}</span>
    </div>
  )
}

function StatusPill({ status }: { status: string }) {
  const bg = status === 'Active' ? '#d4edda' :
             status === 'Rejected' ? '#f8d7da' :
             status === 'Submitted' ? '#e3f2fd' :
             status === 'Under Review' ? '#fff3cd' : '#eceff1'
  const col = status === 'Active' ? '#155724' :
              status === 'Rejected' ? '#b71c1c' :
              status === 'Submitted' ? '#0d47a1' :
              status === 'Under Review' ? '#856404' : '#455a64'
  return (
    <span style={{
      display: 'inline-block', padding: '3px 10px', borderRadius: 20,
      fontSize: 11, fontWeight: 700, background: bg, color: col,
      textTransform: 'uppercase', letterSpacing: 0.3, whiteSpace: 'nowrap',
    }}>
      {status}
    </span>
  )
}

function TempTagCard({ tag, vehicle }: { tag: Record<string, any>, vehicle: Record<string, any> }) {
  const veh = `${vehicle?.dmv_year || ''} ${vehicle?.dmv_make || ''} ${vehicle?.dmv_model || ''}`.trim() || '—'
  const TAG = {
    card: { background: '#1D3557', color: '#fff', borderRadius: 12, padding: 32, border: '3px solid #E63946', maxWidth: 640, margin: '0 auto' } as React.CSSProperties,
    header: { fontSize: 14, letterSpacing: '0.15em', fontWeight: 600, opacity: 0.7, textAlign: 'center' as const },
    num: { fontSize: 42, fontFamily: 'var(--font-mono)', fontWeight: 700, margin: '12px 0 24px', letterSpacing: '0.05em', textAlign: 'center' as const },
    grid: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14, textAlign: 'left' as const, fontSize: 14 },
    label: { display: 'block', fontSize: 10, textTransform: 'uppercase' as const, letterSpacing: '0.08em', opacity: 0.6, marginBottom: 2 },
    footer: { marginTop: 24, paddingTop: 16, borderTop: '1px solid rgba(255,255,255,0.2)', fontSize: 11, opacity: 0.6, textAlign: 'center' as const },
  }
  return (
    <>
      <div id="temp-tag" style={TAG.card}>
        <div style={TAG.header}>TEMPORARY REGISTRATION PERMIT</div>
        <div style={TAG.num}>{tag.dmv_tagnumber}</div>
        <div style={TAG.grid}>
          <div><span style={TAG.label}>VIN</span><span>{vehicle?.dmv_vin || '—'}</span></div>
          <div><span style={TAG.label}>Vehicle</span><span>{veh}</span></div>
          <div><span style={TAG.label}>Color</span><span>{vehicle?.dmv_color || '—'}</span></div>
          <div><span style={TAG.label}>Registrant</span><span>{tag.dmv_buyername || '—'}</span></div>
          <div><span style={TAG.label}>Issued</span><span>{fmt(tag, 'dmv_issuedate')}</span></div>
          <div><span style={TAG.label}>Expires</span><span style={{ color: '#E63946', fontWeight: 600 }}>{fmt(tag, 'dmv_expirationdate')}</span></div>
        </div>
        <div style={TAG.footer}>Contoso DMV · Department of Motor Vehicles · Display in lower-right corner of rear windshield</div>
      </div>
      <style>{`@media print { .no-print { display: none !important; } body { background: #fff !important; } }`}</style>
    </>
  )
}

/* ════════════════════════════════════════════════════════════════════════
   Temp permit PDF (paper-tag style)
   ════════════════════════════════════════════════════════════════════════ */
async function downloadTempPermit(c: { regRef: string; tagNumber: string; tagExp: Date }, f: DealerForm) {
  const { jsPDF } = await import('jspdf')
  // 680x420 landscape — approximates a real paper temp-tag window card
  const W = 680, H = 420
  const doc = new jsPDF({ orientation: 'landscape', unit: 'pt', format: [W, H] })

  // Palette
  const green: [number, number, number] = [26, 61, 43]
  const gold: [number, number, number] = [232, 200, 75]
  const bg: [number, number, number] = [249, 247, 240]
  const textDark: [number, number, number] = [26, 26, 24]
  const muted: [number, number, number] = [122, 138, 125]

  // Background
  doc.setFillColor(...bg); doc.rect(0, 0, W, H, 'F')
  // Gold top bar
  doc.setFillColor(...gold); doc.rect(0, 0, W, 8, 'F')
  // Green banner
  doc.setFillColor(...green); doc.rect(0, 8, W, 72, 'F')
  doc.setTextColor(255, 255, 255)
  doc.setFont('helvetica', 'bold'); doc.setFontSize(11)
  doc.text('CONTOSO DEPARTMENT OF MOTOR VEHICLES', 32, 36)
  doc.setFont('helvetica', 'normal'); doc.setFontSize(9)
  doc.text('30-DAY TEMPORARY OPERATING PERMIT', 32, 54)
  doc.setFontSize(7); doc.setTextColor(255, 255, 255, 0.8 as any)
  doc.text('Display in rear window or bumper. Valid until expiration shown below.', 32, 68)

  // Seal (simplified)
  doc.setFillColor(...gold); doc.circle(W - 50, 44, 22, 'F')
  doc.setFillColor(...green); doc.circle(W - 50, 44, 18, 'F')
  doc.setTextColor(...gold); doc.setFont('helvetica', 'bold'); doc.setFontSize(8)
  doc.text('DMV', W - 50, 46, { align: 'center' })

  // Big tag number
  doc.setTextColor(...textDark)
  doc.setFont('helvetica', 'bold'); doc.setFontSize(52)
  doc.text(c.tagNumber, W / 2, 170, { align: 'center' })
  doc.setFont('helvetica', 'normal'); doc.setFontSize(10); doc.setTextColor(...muted)
  doc.text('TEMPORARY TAG NUMBER', W / 2, 190, { align: 'center' })

  // Expiration large
  doc.setFontSize(9); doc.setTextColor(...muted)
  doc.text('VALID UNTIL', W / 2, 222, { align: 'center' })
  doc.setTextColor(...textDark); doc.setFont('helvetica', 'bold'); doc.setFontSize(22)
  doc.text(
    c.tagExp.toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' }),
    W / 2, 250, { align: 'center' }
  )

  // Details row
  doc.setDrawColor(220, 220, 215); doc.setLineWidth(0.5)
  doc.line(48, 280, W - 48, 280)

  const labelY = 302, valueY = 322
  const col1 = 48, col2 = 220, col3 = 420
  doc.setFont('helvetica', 'normal'); doc.setFontSize(8); doc.setTextColor(...muted)
  doc.text('VEHICLE', col1, labelY)
  doc.text('VIN', col2, labelY)
  doc.text('CUSTOMER', col3, labelY)

  doc.setFont('helvetica', 'bold'); doc.setFontSize(11); doc.setTextColor(...textDark)
  doc.text(`${f.year} ${f.make} ${f.model}`.trim(), col1, valueY)
  doc.setFont('courier', 'bold'); doc.text(f.vin.substring(0, 17), col2, valueY)
  doc.setFont('helvetica', 'bold'); doc.text(`${f.customerFirst} ${f.customerLast}`.trim(), col3, valueY)

  // Dealer attribution
  doc.line(48, 350, W - 48, 350)
  doc.setFont('helvetica', 'normal'); doc.setFontSize(8); doc.setTextColor(...muted)
  doc.text('ISSUED BY', col1, 366)
  doc.text('REGISTRATION REF', col3, 366)
  doc.setFont('helvetica', 'bold'); doc.setFontSize(10); doc.setTextColor(...textDark)
  doc.text(`${DEMO_DEALER.accountName} · ${DEMO_DEALER.contactName}`, col1, 384)
  doc.setFont('courier', 'bold'); doc.text(c.regRef, col3, 384)

  // Footer
  doc.setFont('helvetica', 'normal'); doc.setFontSize(7); doc.setTextColor(...muted)
  doc.text(
    'This permit authorizes operation of the above vehicle on public roadways. Display prominently. ' +
    'Permanent plates will arrive by mail within 5–10 business days of DMV approval.',
    W / 2, 410, { align: 'center', maxWidth: W - 80 }
  )

  doc.save(`TempPermit_${c.tagNumber}.pdf`)
}

/* ════════════════════════════════════════════════════════════════════════
   Styles
   ════════════════════════════════════════════════════════════════════════ */
const S: Record<string, React.CSSProperties> = {
  tabBar: { display: 'flex', gap: 4, borderBottom: '1px solid var(--color-border)', marginBottom: 24 },
  grid1: { display: 'grid', gridTemplateColumns: '1fr', gap: 'var(--space-4)' },
  grid2: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 'var(--space-4)' },
  grid3: { display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 'var(--space-4)' },
  grid4: { display: 'grid', gridTemplateColumns: '1fr 1fr 1fr 1fr', gap: 'var(--space-4)' },
  gridAddress: { display: 'grid', gridTemplateColumns: '2fr 1fr 100px 120px', gap: 'var(--space-4)' },
  tab: {
    padding: '10px 18px', background: 'transparent', border: 'none', borderBottom: '2px solid transparent',
    color: 'var(--color-text-muted)', fontSize: 14, fontWeight: 500, cursor: 'pointer',
  },
  tabActive: {
    padding: '10px 18px', background: 'transparent', border: 'none', borderBottom: '2px solid var(--color-accent)',
    color: 'var(--color-primary)', fontSize: 14, fontWeight: 700, cursor: 'pointer',
  },
  tabBadge: {
    display: 'inline-block', marginLeft: 6, padding: '1px 8px', fontSize: 11,
    background: 'var(--color-primary)', color: '#fff', borderRadius: 10, fontWeight: 700,
  },
  chip: {
    display: 'inline-flex', alignItems: 'center', gap: 8, marginBottom: 16,
    padding: '6px 14px', background: '#eef5f0', borderRadius: 999,
    fontSize: 12, color: 'var(--color-primary)', fontWeight: 500,
  },
  card: {
    background: 'var(--color-surface)', border: '1px solid var(--color-border)',
    borderRadius: 'var(--radius-md)', padding: 24, marginBottom: 16,
  },
  h2: { margin: '0 0 14px', fontSize: 18, color: 'var(--color-primary)' },
  muted: { color: 'var(--color-text-muted)', fontSize: 13, marginTop: -6, marginBottom: 16 },
  errBox: {
    background: '#fdecea', border: '1px solid #f5c6cb', color: '#721c24',
    padding: 12, borderRadius: 6, fontSize: 13, marginBottom: 16,
  },
  vinBadge: {
    position: 'absolute', right: 12, top: 36, fontSize: 11, padding: '4px 10px',
    borderRadius: 4, background: '#eef5f0', color: 'var(--color-primary)',
    display: 'inline-flex', alignItems: 'center', gap: 6,
  },
  spinner: {
    display: 'inline-block', width: 12, height: 12,
    border: '2px solid currentColor', borderTopColor: 'transparent',
    borderRadius: '50%', animation: 'spin 0.8s linear infinite',
  },
  feePanel: {
    position: 'sticky', top: 80, alignSelf: 'start',
    background: 'var(--color-surface)', border: '1px solid var(--color-border)',
    borderRadius: 'var(--radius-md)', padding: 20,
  },
  feePanelHeader: {
    fontSize: 12, fontWeight: 700, textTransform: 'uppercase' as const, letterSpacing: 0.08,
    color: 'var(--color-text-muted)', marginBottom: 12, paddingBottom: 8,
    borderBottom: '1px solid var(--color-border)',
  },
  feeRow: { display: 'flex', justifyContent: 'space-between', padding: '6px 0', fontSize: 13 },
  feeTotal: {
    marginTop: 10, paddingTop: 12, borderTop: '2px solid var(--color-primary)',
    fontWeight: 700, fontSize: 16, color: 'var(--color-primary)',
  },
  feeNote: { marginTop: 14, fontSize: 11, color: 'var(--color-text-muted)', lineHeight: 1.5 },
  confGrid: {
    display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
    gap: 16, marginBottom: 24,
  },
  confTile: {
    background: 'var(--color-surface-alt)', padding: 20, borderRadius: 8,
    border: '1px solid var(--color-border)', textAlign: 'center' as const,
  },
  confLabel: { fontSize: 11, textTransform: 'uppercase' as const, letterSpacing: 0.1, color: 'var(--color-text-muted)', fontWeight: 600, marginBottom: 6 },
  confValue: { fontSize: 22, fontWeight: 700, color: 'var(--color-primary)', fontFamily: 'var(--font-mono)' },
  confSub: { fontSize: 11, color: 'var(--color-text-muted)', marginTop: 4 },
  nextSteps: {
    background: '#f8f9fa', borderLeft: '3px solid var(--color-accent)',
    padding: '14px 18px', borderRadius: 4,
  },
  table: { width: '100%', borderCollapse: 'collapse' as const },
  th: {
    textAlign: 'left' as const, padding: '10px 12px', fontSize: 12, fontWeight: 700,
    color: 'var(--color-text-muted)', textTransform: 'uppercase' as const, letterSpacing: 0.05,
    borderBottom: '2px solid var(--color-border)',
  },
  td: {
    padding: '12px', fontSize: 13, borderBottom: '1px solid var(--color-border)',
    color: 'var(--color-text)',
  },
  tracker: {
    display: 'flex', alignItems: 'center', margin: '24px 0',
    padding: '18px', background: 'var(--color-surface-alt)', borderRadius: 6,
    gap: 0,
  },
  rejectBlock: {
    background: '#fdecea', border: '1px solid #f5c6cb', borderRadius: 6,
    padding: 16, marginTop: 16,
  },
  detailHeader: {
    fontSize: 11, textTransform: 'uppercase' as const, letterSpacing: 0.1,
    color: 'var(--color-text-muted)', margin: '0 0 8px',
  },
}

// Spinner keyframes (inject once)
if (typeof document !== 'undefined' && !document.getElementById('dealer-spin-kf')) {
  const s = document.createElement('style')
  s.id = 'dealer-spin-kf'
  s.textContent = '@keyframes spin { from {transform:rotate(0)} to {transform:rotate(360deg)} }'
  document.head.appendChild(s)
}
