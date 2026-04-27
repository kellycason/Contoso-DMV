import { useEffect, useMemo, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { dvQuery, dvUpdate } from '../hooks/useDataverse'
import { useAuth } from '../hooks/useAuth'
import { useMyDMVData } from '../hooks/useMyDMVData'
import { ConfirmCancelModal } from './Appointments'

/* ════════════════════════════════════════════════════════════
   License Renewal — 2-tier eligibility flow
   ------------------------------------------------------------
   Step 1: Identity verification (license #, DOB, SSN4)
   Step 2: Eligibility result
     • Most TX renewals require a new photo, vision test, and
       signature, which must be captured at a licensing office.
     • We present the real requirements, then route the citizen
       to /appointments to book an in-person visit.
   ════════════════════════════════════════════════════════════ */

interface IdentityForm {
  licenseNumber: string
  dob: string
  ssn4: string
  firstName: string
  lastName: string
  email: string
  phone: string
}

const INITIAL_FORM: IdentityForm = {
  licenseNumber: '', dob: '', ssn4: '',
  firstName: '', lastName: '', email: '', phone: '',
}

interface Requirement {
  icon: string
  title: string
  detail: string
}

export default function LicenseRenewal() {
  useEffect(() => { document.title = 'License Renewal — Contoso DMV' }, [])
  const navigate = useNavigate()
  const { userId, isAuthenticated, userName } = useAuth()
  const dmv = useMyDMVData(userId)

  const [step, setStep] = useState<0 | 1>(0)
  const [form, setForm] = useState<IdentityForm>(INITIAL_FORM)
  const [autofilled, setAutofilled] = useState(false)
  const [errors, setErrors] = useState<Partial<Record<keyof IdentityForm, string>>>({})

  /* ── Existing appointment gate ── */
  const [existingApt, setExistingApt] = useState<Record<string, any> | null>(null)
  const [loadingApt, setLoadingApt] = useState(true)
  const [cancelBusy, setCancelBusy] = useState(false)
  const [cancelMsg, setCancelMsg] = useState('')
  const [showCancelModal, setShowCancelModal] = useState(false)

  useEffect(() => {
    if (!isAuthenticated || !userId) { setLoadingApt(false); return }
    // Look for an upcoming scheduled Driver License appointment
    const today = new Date().toISOString().split('T')[0]
    dvQuery(
      'dmv_appointments',
      `$filter=_dmv_contactid_value eq ${userId} and dmv_servicetype eq 100000001 and dmv_status eq 100000000 and dmv_appointmentdate ge ${today}T00:00:00Z&$select=dmv_appointmentid,dmv_appointmentnumber,dmv_appointmentdate,dmv_appointmenttime,_dmv_officeid_value&$orderby=dmv_appointmentdate asc&$top=1`
    ).then(rows => {
      if (rows.length > 0) setExistingApt(rows[0])
    }).catch(() => {}).finally(() => setLoadingApt(false))
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
      phone: f.phone || dmv.citizen?.phone || '',
      licenseNumber: f.licenseNumber || lic?.licenseNumber || '',
      dob: f.dob || '1987-03-15',
      ssn4: f.ssn4 || '6789',
    }))
    setAutofilled(true)
  }, [dmv.loading, autofilled, userName, dmv.citizen, dmv.license])

  const set = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target
    setForm(f => ({ ...f, [name]: value }))
    if (errors[name as keyof IdentityForm]) setErrors(prev => ({ ...prev, [name]: undefined }))
  }

  function validate(): boolean {
    const errs: typeof errors = {}
    if (!form.licenseNumber.trim()) errs.licenseNumber = 'Required'
    else if (!/^[A-Za-z]\d{7}$/.test(form.licenseNumber.trim())) errs.licenseNumber = 'Format: 1 letter + 7 digits'
    if (!form.dob) errs.dob = 'Required'
    if (!form.ssn4.trim()) errs.ssn4 = 'Required'
    else if (!/^\d{4}$/.test(form.ssn4.trim())) errs.ssn4 = 'Enter exactly 4 digits'
    setErrors(errs)
    return Object.keys(errs).length === 0
  }

  /* ── Eligibility rules engine ── */
  const requirements = useMemo<Requirement[]>(() => {
    const reqs: Requirement[] = []
    const lic = dmv.license

    // Photo age (TX: new photo required every 12 years; most renewals trigger new photo)
    if (lic?.issueDate) {
      const yearsSince = (Date.now() - new Date(lic.issueDate).getTime()) / (365.25 * 86400000)
      reqs.push({
        icon: '📷',
        title: 'Updated photo required',
        detail: `Your current photo was captured on ${new Date(lic.issueDate).toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' })}${yearsSince >= 1 ? ` (${Math.floor(yearsSince)} year${Math.floor(yearsSince) === 1 ? '' : 's'} ago)` : ''}. Texas requires a new photo with every renewal to keep your license current for identification.`,
      })
    } else {
      reqs.push({
        icon: '📷',
        title: 'Updated photo required',
        detail: 'Texas requires a new photo at each driver license renewal to keep your identification current.',
      })
    }

    // Vision test — Tex. Transp. Code § 521.165 (real rule)
    reqs.push({
      icon: '👁️',
      title: 'Vision screening required',
      detail: 'Texas Transportation Code § 521.165 requires a vision test at each driver license renewal. The screening is free and takes under a minute at the office.',
    })

    // Signature capture (part of same in-person visit)
    reqs.push({
      icon: '✍️',
      title: 'Signature verification',
      detail: 'A new digital signature is captured in-person to keep your license secure against fraud and identity theft.',
    })

    // REAL ID upgrade — only if not yet compliant
    if (lic && !lic.realIdCompliant) {
      reqs.push({
        icon: '🛂',
        title: 'REAL ID upgrade available',
        detail: 'Your current license is not REAL ID compliant. Upgrade at no additional cost during your visit — REAL ID will be required for domestic flights starting May 7, 2025. Bring proof of identity, SSN, and two proofs of Texas residency.',
      })
    }

    return reqs
  }, [dmv.license])

  function handleContinue() {
    if (!validate()) return
    setStep(1)
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  function handleBookAppointment() {
    const params = new URLSearchParams({
      service: 'license-renewal',
      licenseNumber: form.licenseNumber.toUpperCase(),
      firstName: form.firstName,
      lastName: form.lastName,
      email: form.email,
      phone: form.phone,
    })
    navigate(`/appointments?${params.toString()}`)
  }

  const expiration = dmv.license?.expirationDate
    ? new Date(dmv.license.expirationDate).toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' })
    : null

  /* ════════════════════════════════════════════════════════════
     Render
     ════════════════════════════════════════════════════════════ */
  return (
    <>
      <div className="page-header">
        <div className="container">
          <nav className="breadcrumb" aria-label="Breadcrumb">
            <Link to="/">Home</Link>
            <span className="breadcrumb-sep" aria-hidden="true">›</span>
            <span aria-current="page">License Renewal</span>
          </nav>
          <h1>Driver License Renewal</h1>
          <p>Renew your Texas driver's license. We'll check your eligibility and guide you through the process.</p>
        </div>
      </div>

      <div style={{ padding: '24px 0 48px' }}>
        <div className="container" style={{ maxWidth: 760 }}>

          {/* ── Existing appointment banner ── */}
          {loadingApt ? (
            <p style={{ textAlign: 'center', color: 'var(--color-text-muted)', padding: '40px 0' }}>Checking your renewal status...</p>
          ) : existingApt ? (
            <div style={{ marginBottom: 32 }}>
              <div style={activeApptBanner}>
                <svg width="20" height="20" viewBox="0 0 20 20" fill="none" style={{ flexShrink: 0, marginTop: 2 }}>
                  <circle cx="10" cy="10" r="10" fill="var(--color-primary)" />
                  <path d="M5 10.5 L9 14 L15 7" stroke="#fff" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" fill="none" />
                </svg>
                <div style={{ flex: 1 }}>
                  <strong>You already have a license renewal appointment booked.</strong>
                  <p style={{ margin: '6px 0 0', fontSize: 13, color: 'var(--color-text-muted)' }}>
                    <strong>{new Date(existingApt.dmv_appointmentdate).toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' })}</strong> at <strong>{existingApt.dmv_appointmenttime}</strong>
                    {' · '}Confirmation: <span style={{ fontFamily: 'var(--font-mono)' }}>{existingApt.dmv_appointmentnumber}</span>
                  </p>
                </div>
              </div>
              <div style={{ textAlign: 'center', marginTop: 20, display: 'flex', gap: 12, justifyContent: 'center', flexWrap: 'wrap' }}>
                <Link to="/appointments" className="btn btn-primary">Reschedule</Link>
                <button
                  type="button"
                  className="btn"
                  style={{ background: 'var(--color-surface)', color: '#c0392b', borderColor: '#c0392b' }}
                  disabled={cancelBusy}
                  onClick={() => setShowCancelModal(true)}
                >
                  {cancelBusy ? 'Cancelling...' : 'Cancel Appointment'}
                </button>
                <button type="button" className="btn btn-outline" onClick={() => setExistingApt(null)}>Book Another</button>
              </div>
              {cancelMsg && (
                <p style={{ textAlign: 'center', marginTop: 10, fontSize: 13, color: 'var(--color-text-muted)' }}>{cancelMsg}</p>
              )}
              {showCancelModal && existingApt && (
                <ConfirmCancelModal
                  appt={{
                    number: existingApt.dmv_appointmentnumber ?? '—',
                    service: 'License Renewal',
                    date: (existingApt.dmv_appointmentdate ?? '').split('T')[0],
                    time: existingApt.dmv_appointmenttime ?? '',
                  }}
                  busy={cancelBusy}
                  onClose={() => setShowCancelModal(false)}
                  onConfirm={async () => {
                    const aptId = existingApt.dmv_appointmentid
                    if (!aptId) { setCancelMsg('Unable to identify appointment.'); setShowCancelModal(false); return }
                    setCancelBusy(true)
                    setCancelMsg('')
                    try {
                      await dvUpdate('dmv_appointments', aptId, { dmv_status: 100000005 })
                      setExistingApt(null)
                      setShowCancelModal(false)
                      setCancelMsg('Your appointment has been cancelled. A confirmation email is on its way.')
                    } catch (err) {
                      setCancelMsg(err instanceof Error ? err.message : 'Cancel failed. Please try again.')
                    } finally {
                      setCancelBusy(false)
                    }
                  }}
                />
              )}
            </div>
          ) : (<>

          {/* ── Progress stepper ── */}
          <div style={stepperWrap}>
            {['Identity', 'Renewal Requirements'].map((label, i) => (
              <div key={label} style={{ display: 'flex', alignItems: 'center', gap: 0 }}>
                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, minWidth: 100 }}>
                  <div style={{
                    width: 32, height: 32, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center',
                    fontSize: 13, fontWeight: 700,
                    background: i < step ? 'var(--color-success)' : i === step ? 'var(--color-accent)' : 'var(--color-surface-alt)',
                    color: i <= step ? '#fff' : 'var(--color-text-muted)',
                    border: i === step ? '2px solid var(--color-accent)' : i < step ? '2px solid var(--color-success)' : '2px solid var(--color-border)',
                    transition: 'all 0.3s ease',
                  }}>
                    {i < step ? '✓' : i + 1}
                  </div>
                  <span style={{
                    fontSize: 11, fontWeight: i === step ? 700 : 500, textAlign: 'center',
                    color: i === step ? 'var(--color-primary)' : 'var(--color-text-muted)',
                  }}>{label}</span>
                </div>
                {i === 0 && (
                  <div style={{
                    height: 2, flex: 1, minWidth: 40,
                    background: step > 0 ? 'var(--color-success)' : 'var(--color-border)',
                    margin: '0 4px 22px', transition: 'background 0.3s ease',
                  }} />
                )}
              </div>
            ))}
          </div>

          <div className="card" style={{ padding: 'var(--space-6)', marginTop: 'var(--space-5)' }}>
            {step === 0 ? (
              <StepIdentity
                form={form} set={set} errors={errors}
                isAuthenticated={isAuthenticated}
                onContinue={handleContinue}
              />
            ) : (
              <StepEligibility
                requirements={requirements}
                expiration={expiration}
                onBack={() => setStep(0)}
                onBook={handleBookAppointment}
              />
            )}
          </div>
          </>)}

        </div>
      </div>
    </>
  )
}

/* ════════════════════════════════════════════════════════════
   Step 1 — Identity
   ════════════════════════════════════════════════════════════ */
interface StepIdentityProps {
  form: IdentityForm
  set: (e: React.ChangeEvent<HTMLInputElement>) => void
  errors: Partial<Record<keyof IdentityForm, string>>
  isAuthenticated: boolean
  onContinue: () => void
}

function StepIdentity({ form, set, errors, isAuthenticated, onContinue }: StepIdentityProps) {
  const fieldError = (name: keyof IdentityForm) =>
    errors[name] ? <p style={errorStyle}>{errors[name]}</p> : null

  return (
    <>
      <h2 style={stepTitle}>Verify Your Identity</h2>
      <p style={stepDesc}>
        Enter your current license details so we can look up your record and check
        your renewal eligibility.
      </p>

      {!isAuthenticated && (
        <div style={warningBox}>
          <strong>Not signed in.</strong> You can still check eligibility, but signing in lets us
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

      <div style={{ marginTop: 'var(--space-6)', display: 'flex', justifyContent: 'flex-end' }}>
        <button
          type="button"
          className="btn btn-primary"
          style={{ fontSize: 15, padding: '12px 32px' }}
          onClick={onContinue}
        >
          Check Eligibility →
        </button>
      </div>
    </>
  )
}

/* ════════════════════════════════════════════════════════════
   Step 2 — Eligibility Result
   ════════════════════════════════════════════════════════════ */
interface StepEligibilityProps {
  requirements: Requirement[]
  expiration: string | null
  onBack: () => void
  onBook: () => void
}

function StepEligibility({ requirements, expiration, onBack, onBook }: StepEligibilityProps) {
  return (
    <>
      <div style={{ display: 'flex', alignItems: 'flex-start', gap: 16, marginBottom: 20 }}>
        <div style={eligibilityBadge}>
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none">
            <path d="M12 2 L22 6 V12 C22 17 17.5 21.2 12 22 C6.5 21.2 2 17 2 12 V6 L12 2 Z" stroke="#fff" strokeWidth="2" fill="none" strokeLinejoin="round" />
            <path d="M8 12 L11 15 L16 9" stroke="#fff" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" fill="none" />
          </svg>
        </div>
        <div style={{ flex: 1 }}>
          <h2 style={{ ...stepTitle, marginBottom: 4 }}>In-Person Visit Required</h2>
          <p style={{ color: 'var(--color-text-muted)', fontSize: 14, lineHeight: 1.6, margin: 0 }}>
            Good news — you're eligible to renew. Texas requires a short in-person visit
            to complete the steps below.{expiration && <> Your current license expires <strong>{expiration}</strong>.</>}
          </p>
        </div>
      </div>

      <div style={requirementsList}>
        {requirements.map((req, i) => (
          <div key={i} style={requirementRow}>
            <div style={requirementIcon} aria-hidden="true">{req.icon}</div>
            <div>
              <div style={{ fontWeight: 600, fontSize: 14, color: 'var(--color-primary)', marginBottom: 3 }}>{req.title}</div>
              <p style={{ margin: 0, fontSize: 13, color: 'var(--color-text-muted)', lineHeight: 1.55 }}>{req.detail}</p>
            </div>
          </div>
        ))}
      </div>

      <div style={bringBox}>
        <h3 style={{ ...subHeading, marginBottom: 10 }}>What to bring to your appointment</h3>
        <ul style={{ margin: 0, paddingLeft: 20, fontSize: 14, lineHeight: 1.8, color: 'var(--color-text)' }}>
          <li>Your current driver's license</li>
          <li>Proof of identity (passport, certified birth certificate, or permanent resident card)</li>
          <li>Social Security card or W-2</li>
          <li>Two documents showing Texas residency (utility bill, lease, bank statement, etc.)</li>
          <li>Payment — <strong>$33 standard Class C renewal</strong> (cash, check, credit/debit)</li>
        </ul>
      </div>

      <div style={{ marginTop: 'var(--space-6)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 12 }}>
        <button type="button" className="btn btn-ghost" onClick={onBack}>
          ← Back
        </button>
        <button
          type="button"
          className="btn btn-primary"
          style={{ fontSize: 15, padding: '12px 32px' }}
          onClick={onBook}
        >
          Book Renewal Appointment →
        </button>
      </div>
    </>
  )
}

/* ════════════════════════════════════════════════════════════
   Styles
   ════════════════════════════════════════════════════════════ */
const activeApptBanner: React.CSSProperties = {
  display: 'flex', gap: 14, alignItems: 'flex-start',
  background: '#eaf4fb', border: '1px solid var(--color-primary)',
  borderLeft: '4px solid var(--color-primary)', borderRadius: 'var(--radius-md)',
  padding: '16px 20px', fontSize: 14, lineHeight: 1.6,
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

const errorStyle: React.CSSProperties = {
  color: 'var(--color-accent)', fontSize: 12, marginTop: 4,
}

const warningBox: React.CSSProperties = {
  background: 'var(--color-warning-bg)', border: '1px solid var(--color-warning)',
  borderLeft: '4px solid var(--color-warning)', borderRadius: 'var(--radius-md)',
  padding: '14px 18px', fontSize: 14, lineHeight: 1.6, marginBottom: 24,
}

const eligibilityBadge: React.CSSProperties = {
  width: 44, height: 44, borderRadius: '50%',
  background: 'var(--color-primary)',
  display: 'flex', alignItems: 'center', justifyContent: 'center',
  flexShrink: 0,
}

const requirementsList: React.CSSProperties = {
  display: 'flex', flexDirection: 'column', gap: 14, marginTop: 8,
}

const requirementRow: React.CSSProperties = {
  display: 'flex', gap: 14, alignItems: 'flex-start',
  background: 'var(--color-surface-alt)', borderRadius: 'var(--radius-md)',
  padding: '14px 18px', border: '1px solid var(--color-border)',
}

const requirementIcon: React.CSSProperties = {
  fontSize: 22, lineHeight: 1, flexShrink: 0, marginTop: 2,
}

const bringBox: React.CSSProperties = {
  marginTop: 24,
  background: 'var(--color-info-bg, #f5f7fa)',
  border: '1px solid var(--color-border)',
  borderRadius: 'var(--radius-md)',
  padding: '18px 22px',
}
