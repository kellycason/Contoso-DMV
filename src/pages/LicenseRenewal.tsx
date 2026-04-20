import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { dvCreate, dvQuery } from '../hooks/useDataverse'
import { useAuth } from '../hooks/useAuth'
import { useMyDMVData } from '../hooks/useMyDMVData'

/* ── Step labels for the progress bar ── */
const STEPS = [
  'Identity Verification',
  'Confirm Details',
  'Medical Questionnaire',
  'Pay Renewal Fee',
  'Confirmation',
]

/* ── Form state shared across steps ── */
interface RenewalForm {
  /* Step 1 – Identity */
  licenseNumber: string
  dob: string
  ssn4: string
  /* Step 2 – Details */
  firstName: string
  lastName: string
  email: string
  phone: string
  address: string
  city: string
  state: string
  zip: string
  /* Step 3 – Medical */
  visionOk: string
  seizures: string
  consciousness: string
  medConditions: string
  /* Step 4 – Payment */
  payMethod: string
  cardName: string
  cardNumber: string
  cardExp: string
  cardCvv: string
}

const DEMO_CARD = {
  cardName: 'Maria Jennings',
  cardNumber: '4111 1111 1111 1234',
  cardExp: '09 / 28',
  cardCvv: '427',
}

const INITIAL_FORM: RenewalForm = {
  licenseNumber: '', dob: '', ssn4: '',
  firstName: '', lastName: '', email: '', phone: '',
  address: '', city: '', state: 'CA', zip: '',
  visionOk: '', seizures: '', consciousness: '', medConditions: '',
  payMethod: 'credit', ...DEMO_CARD,
}

export default function LicenseRenewal() {
  useEffect(() => { document.title = 'License Renewal — Contoso DMV' }, [])
  const { userId, isAuthenticated, userName } = useAuth()
  const dmv = useMyDMVData(userId)

  const [step, setStep] = useState(0)
  const [form, setForm] = useState<RenewalForm>(INITIAL_FORM)
  const [autofilled, setAutofilled] = useState(false)

  /* ── Active renewal check ── */
  const [activeRenewals, setActiveRenewals] = useState<Record<string, any>[]>([])
  const [loadingRenewals, setLoadingRenewals] = useState(true)
  const [showForm, setShowForm] = useState(false)

  useEffect(() => {
    if (!isAuthenticated || !userId) { setLoadingRenewals(false); return }
    dvQuery('dmv_licenserenewals',
      `$filter=_dmv_contactid_value eq ${userId} and (dmv_renewalstatus eq 100000000 or dmv_renewalstatus eq 100000001)&$select=dmv_renewalid,dmv_renewalstatus,dmv_submitteddate,dmv_licensenumber,dmv_firstname,dmv_lastname&$orderby=dmv_submitteddate desc&$top=10`
    ).then(rows => {
      setActiveRenewals(rows)
      if (rows.length === 0) setShowForm(true)
    }).catch(() => setShowForm(true)).finally(() => setLoadingRenewals(false))
  }, [isAuthenticated, userId])

  /* ── Autofill from portal user data ── */
  useEffect(() => {
    if (autofilled || dmv.loading) return
    const parts = (userName ?? '').split(' ')
    const firstName = parts[0] ?? ''
    const lastName = parts.slice(1).join(' ') ?? ''
    const lic = dmv.license
    setForm(f => ({
      ...f,
      firstName: f.firstName || firstName,
      lastName: f.lastName || lastName,
      email: f.email || dmv.citizen?.email || '',
      phone: f.phone || dmv.citizen?.phone || '(555) 867-5309',
      address: f.address || dmv.citizen?.address || '742 Evergreen Terrace',
      city: f.city || 'Contoso',
      zip: f.zip || '90210',
      licenseNumber: f.licenseNumber || lic?.licenseNumber || '',
      dob: f.dob || '1987-03-15',
      ssn4: f.ssn4 || '6789',
      ...DEMO_CARD,
    }))
    setAutofilled(true)
  }, [dmv.loading, autofilled, userName, dmv.citizen, dmv.license])
  const [errors, setErrors] = useState<Partial<Record<keyof RenewalForm, string>>>({})
  const [submitting, setSubmitting] = useState(false)
  const [refNumber, setRefNumber] = useState('')
  const [submitError, setSubmitError] = useState('')

  const set = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target
    setForm(f => ({ ...f, [name]: value }))
    if (errors[name as keyof RenewalForm]) setErrors(prev => ({ ...prev, [name]: undefined }))
  }

  /* ── Step validation ── */
  function validate(): boolean {
    const errs: typeof errors = {}
    if (step === 0) {
      if (!form.licenseNumber.trim()) errs.licenseNumber = 'Required'
      else if (!/^[A-Za-z]\d{7}$/.test(form.licenseNumber.trim())) errs.licenseNumber = 'Format: 1 letter + 7 digits'
      if (!form.dob) errs.dob = 'Required'
      if (!form.ssn4.trim()) errs.ssn4 = 'Required'
      else if (!/^\d{4}$/.test(form.ssn4.trim())) errs.ssn4 = 'Enter exactly 4 digits'
    } else if (step === 1) {
      if (!form.firstName.trim()) errs.firstName = 'Required'
      if (!form.lastName.trim()) errs.lastName = 'Required'
      if (!form.email.trim()) errs.email = 'Required'
      if (!form.address.trim()) errs.address = 'Required'
      if (!form.city.trim()) errs.city = 'Required'
      if (!form.zip.trim()) errs.zip = 'Required'
      else if (!/^\d{5}$/.test(form.zip.trim())) errs.zip = '5-digit ZIP'
    } else if (step === 2) {
      if (!form.visionOk) errs.visionOk = 'Required'
      if (!form.seizures) errs.seizures = 'Required'
      if (!form.consciousness) errs.consciousness = 'Required'
      if (form.visionOk === 'no' || form.seizures === 'yes' || form.consciousness === 'yes') {
        errs.visionOk = errs.visionOk || 'Not eligible for online renewal'
      }
    } else if (step === 3) {
      if (!form.cardName.trim()) errs.cardName = 'Required'
      if (!form.cardNumber.trim()) errs.cardNumber = 'Required'
      else if (form.cardNumber.replace(/\s/g, '').length < 15) errs.cardNumber = 'Invalid card number'
      if (!form.cardExp.trim()) errs.cardExp = 'Required'
      if (!form.cardCvv.trim()) errs.cardCvv = 'Required'
      else if (!/^\d{3,4}$/.test(form.cardCvv.trim())) errs.cardCvv = '3 or 4 digits'
    }
    setErrors(errs)
    return Object.keys(errs).length === 0
  }

  function next() {
    if (!validate()) return
    if (step === 3) {
      handleSubmit()
    } else {
      setStep(s => s + 1)
      window.scrollTo({ top: 0, behavior: 'smooth' })
    }
  }

  function back() {
    setStep(s => Math.max(0, s - 1))
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  async function handleSubmit() {
    setSubmitting(true)
    setSubmitError('')
    try {
      const renewalId = `RNW-${new Date().getFullYear()}-${String(Math.floor(Math.random() * 9999)).padStart(4, '0')}`

      // Look up the driver license record by license number
      let licenseBind: Record<string, string> = {}
      try {
        const licenses = await dvQuery('dmv_driverlicenses',
          `$filter=dmv_licensenumber eq '${form.licenseNumber}'&$select=dmv_driverlicenseid&$top=1`)
        if (licenses.length > 0) {
          licenseBind = { 'dmv_licenseid@odata.bind': `/dmv_driverlicenses(${licenses[0].dmv_driverlicenseid})` }
        }
      } catch { /* non-blocking */ }

      // Create the license renewal record
      await dvCreate('dmv_licenserenewals', {
        dmv_renewalid: renewalId,
        dmv_renewalstatus: 100000000, // Submitted
        dmv_licensenumber: form.licenseNumber,
        dmv_dateofbirth: form.dob ? new Date(form.dob).toISOString() : undefined,
        dmv_ssn4: form.ssn4,
        dmv_firstname: form.firstName,
        dmv_lastname: form.lastName,
        dmv_email: form.email,
        dmv_phone: form.phone,
        dmv_streetaddress: form.address,
        dmv_city: form.city,
        dmv_state: form.state,
        dmv_zipcode: form.zip,
        dmv_visionok: form.visionOk === 'yes',
        dmv_seizures: form.seizures === 'yes',
        dmv_lossofconsciousness: form.consciousness === 'yes',
        dmv_medicalconditions: form.medConditions || undefined,
        dmv_renewalfee: 45.00,
        dmv_paymentmethod: form.payMethod === 'credit' ? 100000000 : form.payMethod === 'debit' ? 100000001 : 100000002,
        dmv_paymentconfirmation: `PAY-${Date.now().toString(36).toUpperCase()}`,
        dmv_submitteddate: new Date().toISOString(),
        dmv_channel: 100000000, // Online Portal
        ...(userId ? { 'dmv_contactid@odata.bind': `/contacts(${userId})` } : {}),
        ...licenseBind,
      })

      // Also log a transaction
      await dvCreate('dmv_transactionlogs', {
        dmv_transactionid: renewalId,
        dmv_transactiontype: 100000000, // License Renewal
        dmv_transactiondate: new Date().toISOString(),
        dmv_status: 100000000, // Pending
        dmv_amount: 45.00,
        dmv_channel: 100000000, // Online
        ...(userId ? { 'dmv_contactid@odata.bind': `/contacts(${userId})` } : {}),
      })

      // Upload temp license record to document uploads table
      try {
        await dvCreate('dmv_documentuploads', {
          dmv_documentname: `Temp-License-${form.licenseNumber.toUpperCase()}-${renewalId}.pdf`,
          dmv_documenttype: 100000000, // Proof of Identity
          dmv_uploaddate: new Date().toISOString(),
          dmv_verificationstatus: 100000001, // Accepted
          dmv_filesize: 12,
          dmv_filetype: 'pdf',
          ...(userId ? { 'dmv_contactid@odata.bind': `/contacts(${userId})` } : {}),
        })
      } catch { /* non-blocking */ }

      setRefNumber(renewalId)
      setStep(4)
    } catch (err) {
      setSubmitError(err instanceof Error ? err.message : 'Payment failed. Please try again.')
    } finally {
      setSubmitting(false)
    }
  }

  /* ── Render helpers ── */
  const fieldError = (name: keyof RenewalForm) =>
    errors[name] ? <p style={errorStyle}>{errors[name]}</p> : null

  return (
    <>
      <div className="page-header">
        <div className="container">
          <nav className="breadcrumb" aria-label="Breadcrumb">
            <Link to="/">Home</Link>
            <span className="breadcrumb-sep" aria-hidden="true">›</span>
            <span aria-current="page">License Renewal</span>
          </nav>
          <h1>License Renewal</h1>
          <p>Renew your Contoso County driver's license online — no office visit required.</p>
        </div>
      </div>

      <div style={{ padding: '24px 0 48px' }}>
        <div className="container" style={{ maxWidth: '760px' }}>

          {/* ── Active renewals gate ── */}
          {!showForm && step < 4 && (
            <div style={{ marginBottom: 32 }}>
              {loadingRenewals ? (
                <p style={{ textAlign: 'center', color: 'var(--color-text-muted)', padding: '40px 0' }}>Checking for active renewals...</p>
              ) : activeRenewals.length > 0 ? (
                <>
                  <div style={activeRenewalBanner}>
                    <svg width="20" height="20" viewBox="0 0 20 20" fill="none" style={{ flexShrink: 0, marginTop: 2 }}>
                      <circle cx="10" cy="10" r="10" fill="var(--color-warning)" />
                      <text x="10" y="14.5" textAnchor="middle" fontSize="13" fontWeight="700" fill="#fff">!</text>
                    </svg>
                    <div>
                      <strong>You have {activeRenewals.length} active renewal{activeRenewals.length > 1 ? 's' : ''} in progress.</strong>
                      <p style={{ margin: '4px 0 0', fontSize: 13, color: 'var(--color-text-muted)' }}>
                        A new renewal can only be submitted once existing requests are completed.
                      </p>
                    </div>
                  </div>

                  <div style={{ display: 'flex', flexDirection: 'column', gap: 12, marginTop: 20 }}>
                    {activeRenewals.map(r => (
                      <div key={r.dmv_licenserenewallid || r.dmv_renewalid} style={renewalCard}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
                          <span style={{ fontFamily: 'var(--font-mono)', fontSize: 13, fontWeight: 600, color: 'var(--color-primary)' }}>{r.dmv_renewalid}</span>
                          <span style={{
                            ...statusPill,
                            background: r.dmv_renewalstatus === 100000001 ? 'var(--color-primary)' : '#e8f4fd',
                            color: r.dmv_renewalstatus === 100000001 ? '#fff' : 'var(--color-primary)',
                          }}>
                            {r.dmv_renewalstatus === 100000000 ? 'Submitted' : 'Under Review'}
                          </span>
                        </div>
                        <div style={{ display: 'flex', gap: 24, fontSize: 13, color: 'var(--color-text-muted)' }}>
                          <span><strong>Name:</strong> {r.dmv_firstname} {r.dmv_lastname}</span>
                          <span><strong>License:</strong> {r.dmv_licensenumber}</span>
                          {r.dmv_submitteddate && <span><strong>Submitted:</strong> {new Date(r.dmv_submitteddate).toLocaleDateString()}</span>}
                        </div>
                      </div>
                    ))}
                  </div>

                  <div style={{ textAlign: 'center', marginTop: 28 }}>
                    <button className="btn btn-outline" onClick={() => setShowForm(true)}>Start New Renewal Anyway</button>
                  </div>
                </>
              ) : null}
            </div>
          )}

          {/* ── Progress stepper ── */}
          {(showForm || step === 4) && (<>
          <div style={stepperWrap}>
            {STEPS.map((label, i) => (
              <div key={label} style={{ display: 'flex', alignItems: 'center', gap: 0 }}>
                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '6px', minWidth: '80px' }}>
                  <div style={{
                    width: 32, height: 32, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center',
                    fontSize: '13px', fontWeight: 700,
                    background: i < step ? 'var(--color-success)' : i === step ? 'var(--color-accent)' : 'var(--color-surface-alt)',
                    color: i <= step ? '#fff' : 'var(--color-text-muted)',
                    border: i === step ? '2px solid var(--color-accent)' : i < step ? '2px solid var(--color-success)' : '2px solid var(--color-border)',
                    transition: 'all 0.3s ease',
                  }}>
                    {i < step ? '✓' : i + 1}
                  </div>
                  <span style={{
                    fontSize: '11px', fontWeight: i === step ? 700 : 500, textAlign: 'center',
                    color: i === step ? 'var(--color-primary)' : 'var(--color-text-muted)',
                  }}>{label}</span>
                </div>
                {i < STEPS.length - 1 && (
                  <div style={{
                    height: 2, flex: 1, minWidth: 24,
                    background: i < step ? 'var(--color-success)' : 'var(--color-border)',
                    margin: '0 4px', marginBottom: '22px',
                    transition: 'background 0.3s ease',
                  }} />
                )}
              </div>
            ))}
          </div>

          {/* ── Step content ── */}
          <div className="card" style={{ padding: 'var(--space-6)', marginTop: 'var(--space-5)' }}>
            {step === 0 && (
              <StepIdentity form={form} set={set} errors={errors} fieldError={fieldError} isAuthenticated={isAuthenticated} />
            )}
            {step === 1 && (
              <StepDetails form={form} set={set} errors={errors} fieldError={fieldError} />
            )}
            {step === 2 && (
              <StepMedical form={form} set={set} errors={errors} fieldError={fieldError} />
            )}
            {step === 3 && (
              <StepPayment form={form} set={set} errors={errors} fieldError={fieldError} submitError={submitError} />
            )}
            {step === 4 && (
              <StepConfirmation refNumber={refNumber} form={form} />
            )}

            {/* ── Navigation buttons ── */}
            {step < 4 && (
              <div style={{ marginTop: 'var(--space-6)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <div>
                  {step > 0 && (
                    <button type="button" className="btn btn-ghost" onClick={back}>
                      ← Back
                    </button>
                  )}
                </div>
                <button
                  type="button"
                  className="btn btn-primary"
                  style={{ fontSize: '15px', padding: '12px 32px' }}
                  onClick={next}
                  disabled={submitting}
                >
                  {submitting ? 'Processing...' : step === 3 ? 'Pay $45.00 & Submit' : 'Continue →'}
                </button>
              </div>
            )}
          </div>
          </>)}
        </div>
      </div>
    </>
  )
}

/* ════════════════════════════════════════════════════════════
   Step 1 — Identity Verification
   ════════════════════════════════════════════════════════════ */
interface StepProps {
  form: RenewalForm
  set: (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => void
  errors: Partial<Record<keyof RenewalForm, string>>
  fieldError: (name: keyof RenewalForm) => React.ReactNode
}

function StepIdentity({ form, set, fieldError, isAuthenticated }: StepProps & { isAuthenticated: boolean }) {
  return (
    <>
      <h2 style={stepTitle}>Step 1: Identity Verification</h2>
      <p style={stepDesc}>
        Enter your license details so we can look up your record. This information must match
        what's on file with the DMV.
      </p>

      {!isAuthenticated && (
        <div style={warningBox}>
          <strong>Not signed in.</strong> You can still start a renewal, but signing in lets us
          pre-fill your information. <Link to="/my-dmv" style={{ color: 'var(--color-secondary)', fontWeight: 600 }}>Sign in →</Link>
        </div>
      )}

      <div className="form-group">
        <label htmlFor="licenseNumber">Driver's License Number *</label>
        <input
          id="licenseNumber" name="licenseNumber" type="text"
          placeholder="e.g. D1234567" required
          value={form.licenseNumber} onChange={set}
          aria-required="true"
        />
        <p className="field-hint">Found on the front of your current license (1 letter + 7 digits)</p>
        {fieldError('licenseNumber')}
      </div>

      <div className="form-row">
        <div className="form-group">
          <label htmlFor="dob">Date of Birth *</label>
          <input id="dob" name="dob" type="date" required value={form.dob} onChange={set} aria-required="true" />
          {fieldError('dob')}
        </div>
        <div className="form-group">
          <label htmlFor="ssn4">Last 4 of SSN *</label>
          <input
            id="ssn4" name="ssn4" type="text" inputMode="numeric"
            maxLength={4} placeholder="XXXX" required
            value={form.ssn4} onChange={set} aria-required="true"
            style={{ WebkitTextSecurity: 'disc' } as React.CSSProperties}
          />
          {fieldError('ssn4')}
        </div>
      </div>
    </>
  )
}

/* ════════════════════════════════════════════════════════════
   Step 2 — Confirm Address & Personal Details
   ════════════════════════════════════════════════════════════ */
function StepDetails({ form, set, fieldError }: StepProps) {
  return (
    <>
      <h2 style={stepTitle}>Step 2: Confirm Your Details</h2>
      <p style={stepDesc}>
        Please verify your name, contact information, and mailing address.
        Your renewed license will be mailed to the address below.
      </p>

      <div className="form-row">
        <div className="form-group">
          <label htmlFor="firstName">First Name *</label>
          <input id="firstName" name="firstName" type="text" required value={form.firstName} onChange={set} aria-required="true" />
          {fieldError('firstName')}
        </div>
        <div className="form-group">
          <label htmlFor="lastName">Last Name *</label>
          <input id="lastName" name="lastName" type="text" required value={form.lastName} onChange={set} aria-required="true" />
          {fieldError('lastName')}
        </div>
      </div>

      <div className="form-row">
        <div className="form-group">
          <label htmlFor="email">Email Address *</label>
          <input id="email" name="email" type="email" required value={form.email} onChange={set} aria-required="true" />
          {fieldError('email')}
        </div>
        <div className="form-group">
          <label htmlFor="phone">Phone Number</label>
          <input id="phone" name="phone" type="tel" placeholder="(555) 000-0000" value={form.phone} onChange={set} />
        </div>
      </div>

      <hr style={divider} />

      <h3 style={subHeading}>Mailing Address</h3>

      <div className="form-group">
        <label htmlFor="address">Street Address *</label>
        <input id="address" name="address" type="text" required value={form.address} onChange={set} aria-required="true" />
        {fieldError('address')}
      </div>

      <div className="form-row" style={{ gridTemplateColumns: '1fr 80px 1fr' }}>
        <div className="form-group">
          <label htmlFor="city">City *</label>
          <input id="city" name="city" type="text" required value={form.city} onChange={set} aria-required="true" />
          {fieldError('city')}
        </div>
        <div className="form-group">
          <label htmlFor="state">State</label>
          <input id="state" name="state" type="text" value={form.state} onChange={set} maxLength={2} />
        </div>
        <div className="form-group">
          <label htmlFor="zip">ZIP Code *</label>
          <input id="zip" name="zip" type="text" inputMode="numeric" maxLength={5} required value={form.zip} onChange={set} aria-required="true" />
          {fieldError('zip')}
        </div>
      </div>
    </>
  )
}

/* ════════════════════════════════════════════════════════════
   Step 3 — Medical / Vision Questionnaire
   ════════════════════════════════════════════════════════════ */
function StepMedical({ form, set, fieldError }: StepProps) {
  return (
    <>
      <h2 style={stepTitle}>Step 3: Medical Questionnaire</h2>
      <p style={stepDesc}>
        California law requires all renewal applicants to answer the following questions
        about their vision and medical fitness to operate a motor vehicle.
      </p>

      <div style={questionCard}>
        <p style={questionText}>1. Can you read a standard road sign at a distance of 100 feet with or without corrective lenses?</p>
        <div style={radioRow}>
          <label style={radioLabel}>
            <input type="radio" name="visionOk" value="no" checked={form.visionOk === 'no'} onChange={set} /> No
          </label>
          <label style={radioLabel}>
            <input type="radio" name="visionOk" value="yes" checked={form.visionOk === 'yes'} onChange={set} /> Yes
          </label>
        </div>
        {fieldError('visionOk')}
      </div>

      <div style={questionCard}>
        <p style={questionText}>2. Have you had any seizures or epileptic episodes in the past 3 years?</p>
        <div style={radioRow}>
          <label style={radioLabel}>
            <input type="radio" name="seizures" value="no" checked={form.seizures === 'no'} onChange={set} /> No
          </label>
          <label style={radioLabel}>
            <input type="radio" name="seizures" value="yes" checked={form.seizures === 'yes'} onChange={set} /> Yes
          </label>
        </div>
        {fieldError('seizures')}
      </div>

      <div style={questionCard}>
        <p style={questionText}>3. Have you experienced any unexplained loss of consciousness in the past 5 years?</p>
        <div style={radioRow}>
          <label style={radioLabel}>
            <input type="radio" name="consciousness" value="no" checked={form.consciousness === 'no'} onChange={set} /> No
          </label>
          <label style={radioLabel}>
            <input type="radio" name="consciousness" value="yes" checked={form.consciousness === 'yes'} onChange={set} /> Yes
          </label>
        </div>
        {fieldError('consciousness')}
      </div>

      <div className="form-group" style={{ marginTop: 'var(--space-4)' }}>
        <label htmlFor="medConditions">Additional medical conditions or notes (optional)</label>
        <textarea
          id="medConditions" name="medConditions" rows={3}
          placeholder="List any conditions that may affect your ability to drive safely..."
          value={form.medConditions} onChange={set}
          style={{ width: '100%', padding: '10px 14px', border: '1.5px solid var(--color-border)', borderRadius: 'var(--radius-sm)', fontFamily: 'var(--font-body)', fontSize: '15px', color: 'var(--color-text)', background: 'var(--color-surface)', resize: 'vertical' }}
        />
      </div>

      {(form.visionOk === 'no' || form.seizures === 'yes' || form.consciousness === 'yes') && (
        <div style={{ ...warningBox, background: '#fff0f0', borderColor: 'var(--color-accent)', borderLeftColor: 'var(--color-accent)' }}>
          <strong>Not eligible for online renewal.</strong> Based on your answers, you are required
          to complete an in-person evaluation at a DMV office. Please schedule an appointment.
          <div style={{ marginTop: 12 }}>
            <Link to="/appointments" className="btn btn-primary" style={{ fontSize: 14, padding: '8px 20px' }}>Schedule an Appointment</Link>
          </div>
        </div>
      )}
    </>
  )
}

/* ════════════════════════════════════════════════════════════
   Step 4 — Payment
   ════════════════════════════════════════════════════════════ */
function StepPayment({ form, set, fieldError, submitError }: StepProps & { submitError: string }) {
  return (
    <>
      <h2 style={stepTitle}>Step 4: Pay Renewal Fee</h2>
      <p style={stepDesc}>
        The renewal fee is <strong>$45.00</strong>. Payment is processed securely.
        Your temporary license will be available immediately after payment.
      </p>

      {/* Fee summary */}
      <div style={feeSummary}>
        <div style={feeRow}><span>License renewal fee</span><span>$45.00</span></div>
        <div style={feeRow}><span>Technology fee</span><span>$0.00</span></div>
        <div style={{ ...feeRow, fontWeight: 700, borderTop: '2px solid var(--color-border)', paddingTop: '12px', marginTop: '8px' }}>
          <span>Total due</span><span style={{ fontSize: '18px', color: 'var(--color-primary)' }}>$45.00</span>
        </div>
      </div>

      <h3 style={subHeading}>Payment Method</h3>
      <div className="form-group">
        <select name="payMethod" value={form.payMethod} onChange={set}>
          <option value="credit">Credit Card</option>
          <option value="debit">Debit Card</option>
          <option value="echeck">eCheck / ACH</option>
        </select>
      </div>

      <div className="form-group">
        <label htmlFor="cardName">Name on Card *</label>
        <input id="cardName" name="cardName" type="text" required value={form.cardName} onChange={set} aria-required="true" />
        {fieldError('cardName')}
      </div>

      <div className="form-group">
        <label htmlFor="cardNumber">Card Number *</label>
        <input id="cardNumber" name="cardNumber" type="text" inputMode="numeric" placeholder="•••• •••• •••• ••••" required value={form.cardNumber} onChange={set} aria-required="true" />
        {fieldError('cardNumber')}
      </div>

      <div className="form-row">
        <div className="form-group">
          <label htmlFor="cardExp">Expiration *</label>
          <input id="cardExp" name="cardExp" type="text" placeholder="MM / YY" required value={form.cardExp} onChange={set} aria-required="true" />
          {fieldError('cardExp')}
        </div>
        <div className="form-group">
          <label htmlFor="cardCvv">CVV *</label>
          <input id="cardCvv" name="cardCvv" type="text" inputMode="numeric" maxLength={4} placeholder="•••" required value={form.cardCvv} onChange={set} aria-required="true" style={{ WebkitTextSecurity: 'disc' } as React.CSSProperties} />
          {fieldError('cardCvv')}
        </div>
      </div>

      <div style={secureNote}>
        <svg width="16" height="16" viewBox="0 0 16 16" fill="none" style={{ flexShrink: 0 }}>
          <path d="M8 1C6.343 1 5 2.343 5 4v2H4a1 1 0 00-1 1v7a1 1 0 001 1h8a1 1 0 001-1V7a1 1 0 00-1-1h-1V4c0-1.657-1.343-3-3-3zm2 5H6V4a2 2 0 114 0v2z" fill="var(--color-success)" />
        </svg>
        <span>Your payment information is encrypted and transmitted securely.</span>
      </div>

      {submitError && <p style={{ color: 'var(--color-accent)', fontSize: '14px', marginTop: '12px' }}>{submitError}</p>}
    </>
  )
}

/* ════════════════════════════════════════════════════════════
   Step 5 — Confirmation / Temporary License
   ════════════════════════════════════════════════════════════ */
async function downloadTempLicense(form: RenewalForm, refNumber: string, userId?: string) {
  const { jsPDF } = await import('jspdf')
  const expiry = tempExpiry()
  const issued = new Date().toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' })
  const dob = form.dob
    ? new Date(form.dob + 'T00:00:00').toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' })
    : form.dob

  const W = 760, H = 546
  const doc = new jsPDF({ orientation: 'landscape', unit: 'pt', format: [W, H] })

  // ── Try to fetch entity image ──
  let photoDataUrl: string | null = null
  if (userId) {
    try {
      // Try JSON property first
      const resp = await fetch(`/_api/contacts(${userId})?$select=entityimage`)
      if (resp.ok) {
        const data = await resp.json()
        if (data.entityimage) photoDataUrl = 'data:image/jpeg;base64,' + data.entityimage
      }
    } catch { /* ignore */ }
    if (!photoDataUrl) {
      try {
        // Fallback: binary stream endpoint
        const resp = await fetch(`/_api/contacts(${userId})/entityimage/$value`)
        if (resp.ok && resp.headers.get('content-type')?.startsWith('image')) {
          const blob = await resp.blob()
          photoDataUrl = await new Promise<string>((resolve) => {
            const reader = new FileReader()
            reader.onloadend = () => resolve(reader.result as string)
            reader.readAsDataURL(blob)
          })
        }
      } catch { /* no photo available */ }
    }
  }

  // ── Background ──
  doc.setFillColor(245, 243, 239)
  doc.rect(0, 0, W, H, 'F')

  // ── Watermark ──
  doc.setFontSize(80)
  doc.setFont('helvetica', 'bold')
  doc.setTextColor(235, 233, 229)
  doc.text('TEMPORARY', W / 2, H / 2, { align: 'center', angle: 25 })

  // ── Header ──
  const headerH = 68
  doc.setFillColor(200, 168, 75)  // gold accent
  doc.rect(0, 0, 8, headerH, 'F')
  doc.setFillColor(15, 39, 68)    // navy
  doc.rect(8, 0, W - 8, headerH, 'F')

  doc.setFontSize(9)
  doc.setFont('helvetica', 'bold')
  doc.setTextColor(200, 168, 75)
  doc.text('CONTOSO COUNTY \u2014 DEPARTMENT OF MOTOR VEHICLES', 40, 28)

  doc.setFontSize(26)
  doc.setFont('helvetica', 'bold')
  doc.setTextColor(255, 255, 255)
  doc.text('TEMPORARY DRIVER LICENSE', 40, 52)

  // Badge
  const bx = 620, by = 14, bw = 106, bh = 40
  doc.setFillColor(30, 50, 75)
  doc.setDrawColor(200, 168, 75)
  doc.roundedRect(bx, by, bw, bh, 4, 4, 'FD')
  doc.setFontSize(8)
  doc.setTextColor(200, 168, 75)
  doc.setFont('helvetica', 'normal')
  doc.text('VALID FOR', bx + bw / 2, by + 15, { align: 'center' })
  doc.setFontSize(20)
  doc.setFont('helvetica', 'bold')
  doc.setTextColor(255, 255, 255)
  doc.text('90 DAYS', bx + bw / 2, by + 34, { align: 'center' })

  // ── Status strip ──
  const stripY = headerH, stripH = 20
  doc.setFillColor(200, 168, 75)
  doc.rect(0, stripY, W, stripH, 'F')
  doc.setFillColor(15, 39, 68)
  doc.circle(40, stripY + stripH / 2, 3, 'F')
  doc.setFontSize(8)
  doc.setFont('helvetica', 'bold')
  doc.setTextColor(15, 39, 68)
  doc.text('OFFICIAL DOCUMENT \u2014 CARRY WITH VALID PHOTO ID', 50, stripY + 13)

  // ── Body fields ──
  const bodyY = stripY + stripH + 32
  const fieldX = 40, valueX = 188, rightX = 528
  const fields = [
    { label: 'FULL NAME', value: `${form.firstName} ${form.lastName}`, large: true },
    { label: 'LICENSE NO.', value: form.licenseNumber.toUpperCase(), mono: true },
    { label: 'DATE OF BIRTH', value: dob },
    { label: 'ADDRESS', value: `${form.address}\n${form.city}, ${form.state} ${form.zip}` },
    { label: 'VALID THROUGH', value: expiry },
    { label: 'ISSUED', value: issued },
    { label: 'TRANSACTION', value: refNumber, mono: true },
  ]

  let fy = bodyY
  const rowH = 38
  for (const f of fields) {
    if (fy > bodyY) {
      doc.setDrawColor(230, 228, 222)
      doc.setLineWidth(0.4)
      doc.line(fieldX, fy, rightX - 16, fy)
    }
    doc.setFontSize(8)
    doc.setFont('helvetica', 'bold')
    doc.setTextColor(138, 138, 130)
    doc.text(f.label, fieldX, fy + 18)

    if (f.large) { doc.setFontSize(16); doc.setFont('helvetica', 'bold') }
    else if (f.mono) { doc.setFontSize(12); doc.setFont('courier', 'bold') }
    else { doc.setFontSize(13); doc.setFont('helvetica', 'normal') }
    doc.setTextColor(26, 26, 24)

    if (f.value.includes('\n')) {
      const lines = f.value.split('\n')
      doc.text(lines[0], valueX, fy + 17)
      doc.text(lines[1], valueX, fy + 30)
      fy += rowH + 14
    } else {
      doc.text(f.value, valueX, fy + 18)
      fy += rowH
    }
  }

  // ── Photo panel (square crop) ──
  const photoX = rightX, photoY = bodyY - 4, photoW = 192, photoH = 192
  if (photoDataUrl) {
    try {
      // Center-crop to 1:1 using an offscreen canvas
      const croppedUrl = await cropToSquare(photoDataUrl)
      doc.addImage(croppedUrl, 'JPEG', photoX, photoY, photoW, photoH)
      doc.setDrawColor(200, 200, 195)
      doc.setLineWidth(1)
      doc.roundedRect(photoX, photoY, photoW, photoH, 8, 8, 'S')
    } catch {
      drawLicensePhotoPlaceholder(doc, photoX, photoY, photoW, photoH)
    }
  } else {
    drawLicensePhotoPlaceholder(doc, photoX, photoY, photoW, photoH)
  }

  // Restrictions box
  const rY = photoY + photoH + 14
  doc.setFillColor(255, 248, 232)
  doc.setDrawColor(232, 216, 154)
  doc.roundedRect(photoX, rY, photoW, 50, 6, 6, 'FD')
  doc.setFontSize(7)
  doc.setFont('helvetica', 'bold')
  doc.setTextColor(160, 124, 32)
  doc.text('CLASS & RESTRICTIONS', photoX + 10, rY + 16)
  doc.setFontSize(9)
  doc.setFont('helvetica', 'normal')
  doc.setTextColor(90, 74, 26)
  doc.text('Class C \u2014 Standard', photoX + 10, rY + 30)
  doc.text('No restrictions', photoX + 10, rY + 42)

  // ── Footer ──
  const footerY = H - 56
  doc.setDrawColor(220, 218, 212)
  doc.setLineWidth(0.5)
  doc.line(40, footerY, W - 40, footerY)

  doc.setFontSize(8.5)
  doc.setFont('helvetica', 'normal')
  doc.setTextColor(138, 138, 130)
  doc.text('This document serves as a valid temporary license for 90 days from the date of issue.', 40, footerY + 18)
  doc.text('Must be carried alongside a valid government-issued photo ID.', 40, footerY + 32)

  // Decorative barcode
  const bcX = W - 140, bcY = footerY + 8
  const bars = [2,1,3,1,2,1,1,2,3,1,2,1,1,3,2,1,1,2,3,1]
  const barH = [24,19,24,14,24,22,24,17,24,19,24,12,24,22,24,16,24,19,24,24]
  let bcOff = bcX
  doc.setFillColor(26, 26, 24)
  for (let i = 0; i < bars.length; i++) {
    doc.rect(bcOff, bcY + (24 - barH[i]), bars[i], barH[i], 'F')
    bcOff += bars[i] + 2
  }
  doc.setFontSize(7)
  doc.setFont('courier', 'normal')
  doc.setTextColor(138, 138, 130)
  doc.text(`${form.licenseNumber.toUpperCase()} \u00b7 ${refNumber}`, bcX, bcY + 38)

  doc.save(`Temp-License-${form.licenseNumber.toUpperCase()}-${refNumber}.pdf`)
}

function drawLicensePhotoPlaceholder(doc: ReturnType<typeof import('jspdf').jsPDF.prototype.constructor>, x: number, y: number, w: number, h: number) {
  doc.setFillColor(226, 224, 218)
  doc.setDrawColor(184, 181, 174)
  doc.setLineWidth(1)
  doc.roundedRect(x, y, w, h, 8, 8, 'FD')
  const cx = x + w / 2, cy = y + h / 2 - 10
  doc.setDrawColor(160, 158, 150)
  doc.setLineWidth(1.5)
  doc.circle(cx, cy - 12, 14, 'S')
  doc.line(cx - 24, cy + 20, cx - 12, cy + 10)
  doc.line(cx + 12, cy + 10, cx + 24, cy + 20)
  doc.setFontSize(8)
  doc.setFont('helvetica', 'bold')
  doc.setTextColor(138, 138, 130)
  doc.text('PHOTO ID', cx, cy + 40, { align: 'center' })
}

function cropToSquare(dataUrl: string): Promise<string> {
  return new Promise((resolve) => {
    const img = new Image()
    img.onload = () => {
      const size = Math.min(img.width, img.height)
      const sx = (img.width - size) / 2
      const sy = (img.height - size) / 2
      const canvas = document.createElement('canvas')
      canvas.width = size
      canvas.height = size
      const ctx = canvas.getContext('2d')!
      ctx.drawImage(img, sx, sy, size, size, 0, 0, size, size)
      resolve(canvas.toDataURL('image/jpeg', 0.92))
    }
    img.onerror = () => resolve(dataUrl) // fallback to original
    img.src = dataUrl
  })
}

function StepConfirmation({ refNumber, form }: { refNumber: string; form: RenewalForm }) {
  return (
    <div style={{ textAlign: 'center', padding: 'var(--space-6) 0' }}>
      <div style={{ fontSize: 56, marginBottom: 12 }} aria-hidden="true">✅</div>
      <h2 style={{ color: 'var(--color-success)', marginBottom: 8 }}>Renewal Request Submitted</h2>
      <p style={{ color: 'var(--color-text-muted)', fontSize: 15, maxWidth: 520, margin: '0 auto 24px' }}>
        Your payment of <strong>$45.00</strong> has been processed and your renewal request
        is now under review. A DMV representative will evaluate your application.
      </p>

      {/* Receipt card */}
      <div style={tempLicenseCard}>
        <div style={tempLicenseHeader}>
          <span style={{ fontWeight: 700, fontSize: 13, letterSpacing: 1, textTransform: 'uppercase' }}>Renewal Receipt</span>
        </div>
        <div style={{ padding: '20px 24px', display: 'flex', flexDirection: 'column', gap: 10 }}>
          <div style={licenseRow}>
            <span style={licenseLabel}>Reference</span>
            <span style={{ ...licenseValue, fontFamily: 'var(--font-mono)', fontSize: 14 }}>{refNumber}</span>
          </div>
          <div style={licenseRow}>
            <span style={licenseLabel}>Name</span>
            <span style={licenseValue}>{form.firstName} {form.lastName}</span>
          </div>
          <div style={licenseRow}>
            <span style={licenseLabel}>License #</span>
            <span style={{ ...licenseValue, fontFamily: 'var(--font-mono)', fontSize: 14 }}>{form.licenseNumber.toUpperCase()}</span>
          </div>
          <div style={licenseRow}>
            <span style={licenseLabel}>Status</span>
            <span style={{ ...licenseValue, color: 'var(--color-warning)' }}>Under Review</span>
          </div>
          <div style={licenseRow}>
            <span style={licenseLabel}>Amount Paid</span>
            <span style={licenseValue}>$45.00</span>
          </div>
        </div>
      </div>

      <div style={{ background: 'var(--color-info-bg)', border: '1px solid var(--color-border)', borderRadius: 'var(--radius-md)', padding: '14px 18px', fontSize: 13, color: 'var(--color-text-muted)', maxWidth: 520, margin: '20px auto 28px', textAlign: 'left', lineHeight: 1.6 }}>
        <strong style={{ color: 'var(--color-primary)' }}>What happens next?</strong>
        <ol style={{ margin: '8px 0 0 18px', padding: 0 }}>
          <li>A DMV agent will review your renewal request (typically 1–2 business days).</li>
          <li>Once approved, your temporary license will be available in your <Link to="/documents" style={{ color: 'var(--color-secondary)', fontWeight: 600 }}>Documents</Link> and emailed to you.</li>
          <li>Your permanent license will arrive by mail in 7–10 business days.</li>
        </ol>
      </div>

      <div style={{ display: 'flex', gap: 16, justifyContent: 'center', flexWrap: 'wrap' }}>
        <Link to="/my-dmv" className="btn btn-primary">Go to My DMV</Link>
        <Link to="/documents" className="btn btn-outline">View Documents</Link>
        <Link to="/" className="btn btn-outline">Return Home</Link>
      </div>
    </div>
  )
}

/* ── Helpers ── */
function tempExpiry() {
  const d = new Date()
  d.setDate(d.getDate() + 90)
  return d.toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' })
}

/* ════════════════════════════════════════════════════════════
   Inline Styles
   ════════════════════════════════════════════════════════════ */
const activeRenewalBanner: React.CSSProperties = {
  display: 'flex', gap: 14, alignItems: 'flex-start',
  background: 'var(--color-warning-bg)', border: '1px solid var(--color-warning)',
  borderLeft: '4px solid var(--color-warning)', borderRadius: 'var(--radius-md)',
  padding: '16px 20px', fontSize: 14, lineHeight: 1.6,
}

const renewalCard: React.CSSProperties = {
  background: 'var(--color-surface)', border: '1px solid var(--color-border)',
  borderRadius: 'var(--radius-md)', padding: '16px 20px',
}

const statusPill: React.CSSProperties = {
  fontSize: 11, fontWeight: 700, padding: '3px 10px',
  borderRadius: 20, letterSpacing: 0.3, textTransform: 'uppercase',
}

const stepperWrap: React.CSSProperties = {
  display: 'flex', alignItems: 'flex-start', justifyContent: 'center', gap: 0,
  padding: '24px 0 0',
}

const stepTitle: React.CSSProperties = {
  fontFamily: 'var(--font-heading)', fontSize: '1.25rem', fontWeight: 600,
  color: 'var(--color-primary)', marginBottom: 8,
}

const stepDesc: React.CSSProperties = {
  color: 'var(--color-text-muted)', fontSize: 14, lineHeight: 1.6,
  marginBottom: 28,
}

const subHeading: React.CSSProperties = {
  fontFamily: 'var(--font-heading)', fontSize: '1rem', fontWeight: 600,
  color: 'var(--color-primary)', marginBottom: 16,
}

const divider: React.CSSProperties = {
  border: 'none', borderTop: '1px solid var(--color-border)', margin: '28px 0',
}

const errorStyle: React.CSSProperties = {
  color: 'var(--color-accent)', fontSize: 12, marginTop: 4,
}

const warningBox: React.CSSProperties = {
  background: 'var(--color-warning-bg)', border: '1px solid var(--color-warning)',
  borderLeft: '4px solid var(--color-warning)', borderRadius: 'var(--radius-md)',
  padding: '14px 18px', fontSize: 14, lineHeight: 1.6, marginBottom: 24,
}

const questionCard: React.CSSProperties = {
  background: 'var(--color-surface-alt)', borderRadius: 'var(--radius-md)',
  padding: '18px 20px', marginBottom: 16,
}

const questionText: React.CSSProperties = {
  fontWeight: 500, fontSize: 14, marginBottom: 12, lineHeight: 1.5,
}

const radioRow: React.CSSProperties = {
  display: 'flex', gap: 24,
}

const radioLabel: React.CSSProperties = {
  display: 'inline-flex', alignItems: 'center', gap: 6,
  fontSize: 14, cursor: 'pointer', fontWeight: 400,
}

const feeSummary: React.CSSProperties = {
  background: 'var(--color-surface-alt)', borderRadius: 'var(--radius-md)',
  padding: '20px 24px', marginBottom: 28,
}

const feeRow: React.CSSProperties = {
  display: 'flex', justifyContent: 'space-between', fontSize: 14,
  padding: '6px 0', color: 'var(--color-text)',
}

const secureNote: React.CSSProperties = {
  display: 'flex', alignItems: 'center', gap: 8,
  fontSize: 13, color: 'var(--color-success)', marginTop: 12,
}

const tempLicenseCard: React.CSSProperties = {
  maxWidth: 420, margin: '0 auto', border: '2px solid var(--color-primary)',
  borderRadius: 'var(--radius-lg)', overflow: 'hidden', textAlign: 'left',
  background: 'var(--color-surface)',
}

const tempLicenseHeader: React.CSSProperties = {
  background: 'var(--color-primary)', color: '#fff', padding: '12px 24px',
}

const licenseRow: React.CSSProperties = {
  display: 'flex', justifyContent: 'space-between', alignItems: 'center',
  padding: '4px 0', borderBottom: '1px solid var(--color-surface-alt)',
}

const licenseLabel: React.CSSProperties = {
  fontSize: 12, fontWeight: 500, color: 'var(--color-text-muted)', textTransform: 'uppercase', letterSpacing: 0.5,
}

const licenseValue: React.CSSProperties = {
  fontSize: 14, fontWeight: 600, color: 'var(--color-text)',
}
