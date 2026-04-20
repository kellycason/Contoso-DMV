import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { dvCreate } from '../hooks/useDataverse'
import { useAuth } from '../hooks/useAuth'

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

const INITIAL_FORM: RenewalForm = {
  licenseNumber: '', dob: '', ssn4: '',
  firstName: '', lastName: '', email: '', phone: '',
  address: '', city: '', state: 'CA', zip: '',
  visionOk: '', seizures: '', consciousness: '', medConditions: '',
  payMethod: 'credit', cardName: '', cardNumber: '', cardExp: '', cardCvv: '',
}

export default function LicenseRenewal() {
  useEffect(() => { document.title = 'License Renewal — Contoso DMV' }, [])
  const { userId, isAuthenticated } = useAuth()

  const [step, setStep] = useState(0)
  const [form, setForm] = useState<RenewalForm>(INITIAL_FORM)
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
      const txnId = `TXN-${new Date().getFullYear()}-${String(Math.floor(Math.random() * 9999)).padStart(4, '0')}`
      await dvCreate('dmv_transactionlogs', {
        dmv_transactionid: txnId,
        dmv_transactiontype: 100000000, // License Renewal
        dmv_transactiondate: new Date().toISOString(),
        dmv_status: 100000000, // Pending
        dmv_amount: 45.00,
        dmv_channel: 100000000, // Online
        ...(userId ? { 'dmv_contactid@odata.bind': `/contacts(${userId})` } : {}),
      })
      setRefNumber(txnId)
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
          {/* ── Progress stepper ── */}
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
            <input type="radio" name="visionOk" value="yes" checked={form.visionOk === 'yes'} onChange={set} /> Yes
          </label>
          <label style={radioLabel}>
            <input type="radio" name="visionOk" value="no" checked={form.visionOk === 'no'} onChange={set} /> No
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
        <div style={warningBox}>
          <strong>Important:</strong> Based on your answers, you may be required to complete an
          in-person vision or medical evaluation. A DMV representative will contact you after submission.
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
          <input id="cardCvv" name="cardCvv" type="text" inputMode="numeric" maxLength={4} placeholder="•••" required value={form.cardCvv} onChange={set} aria-required="true" />
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
function StepConfirmation({ refNumber, form }: { refNumber: string; form: RenewalForm }) {
  return (
    <div style={{ textAlign: 'center', padding: 'var(--space-6) 0' }}>
      <div style={{ fontSize: 56, marginBottom: 12 }} aria-hidden="true">🎉</div>
      <h2 style={{ color: 'var(--color-success)', marginBottom: 8 }}>Renewal Complete!</h2>
      <p style={{ color: 'var(--color-text-muted)', fontSize: 15, marginBottom: 24, maxWidth: 480, margin: '0 auto 24px' }}>
        Your payment of <strong>$45.00</strong> has been processed. A temporary digital license
        is now active while your permanent card is printed and mailed.
      </p>

      {/* Temporary license card */}
      <div style={tempLicenseCard}>
        <div style={tempLicenseHeader}>
          <span style={{ fontWeight: 700, fontSize: 13, letterSpacing: 1, textTransform: 'uppercase' }}>Contoso County — Temporary Driver's License</span>
        </div>
        <div style={{ padding: '20px 24px', display: 'flex', flexDirection: 'column', gap: 10 }}>
          <div style={licenseRow}>
            <span style={licenseLabel}>Name</span>
            <span style={licenseValue}>{form.firstName} {form.lastName}</span>
          </div>
          <div style={licenseRow}>
            <span style={licenseLabel}>License #</span>
            <span style={{ ...licenseValue, fontFamily: 'var(--font-mono)', fontSize: 14 }}>{form.licenseNumber.toUpperCase()}</span>
          </div>
          <div style={licenseRow}>
            <span style={licenseLabel}>Valid Through</span>
            <span style={licenseValue}>{tempExpiry()}</span>
          </div>
          <div style={licenseRow}>
            <span style={licenseLabel}>Transaction</span>
            <span style={{ ...licenseValue, fontFamily: 'var(--font-mono)', fontSize: 13 }}>{refNumber}</span>
          </div>
        </div>
      </div>

      <p style={{ color: 'var(--color-text-muted)', fontSize: 13, marginTop: 20, marginBottom: 28 }}>
        Your permanent license will arrive by mail in 7–10 business days.
      </p>

      <div style={{ display: 'flex', gap: 16, justifyContent: 'center' }}>
        <Link to="/my-dmv" className="btn btn-primary">Go to My DMV</Link>
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
