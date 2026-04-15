import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'

const services = [
  'Driver License (New/Renewal)',
  'Vehicle Registration',
  'Title Transfer',
  'REAL ID Application',
  'Name/Address Change',
  'Duplicate License',
  'Commercial License (CDL)',
  'Other',
]

const times = ['8:00 AM', '8:30 AM', '9:00 AM', '9:30 AM', '10:00 AM', '10:30 AM',
                '11:00 AM', '11:30 AM', '1:00 PM', '1:30 PM', '2:00 PM', '2:30 PM',
                '3:00 PM', '3:30 PM', '4:00 PM', '4:30 PM']

const unavailable = new Set(['9:00 AM', '10:30 AM', '1:30 PM', '3:00 PM'])

function getMinDate() {
  const d = new Date()
  d.setDate(d.getDate() + 1)
  return d.toISOString().split('T')[0]
}

export default function Appointments() {
  useEffect(() => { document.title = 'Schedule Appointment — Contoso DMV' }, [])

  const [step, setStep] = useState(1)
  const [serviceType, setServiceType] = useState('')
  const [date, setDate] = useState('')
  const [time, setTime] = useState('')
  const [form, setForm] = useState({ firstName: '', lastName: '', email: '', phone: '' })
  const [submitted, setSubmitted] = useState(false)

  const handle = (e: React.ChangeEvent<HTMLInputElement>) =>
    setForm(f => ({ ...f, [e.target.name]: e.target.value }))

  const handleSubmit = (e: React.FormEvent) => { e.preventDefault(); setSubmitted(true) }

  if (submitted) {
    return (
      <>
        <div className="page-header"><div className="container"><h1>Schedule Appointment</h1></div></div>
        <div className="container" style={{ padding: '64px 24px', maxWidth: '600px', textAlign: 'center' }}>
          <div style={{ fontSize: '48px', marginBottom: '16px' }} aria-hidden="true">📅</div>
          <h2 style={{ marginBottom: '12px', color: 'var(--color-success)' }}>Appointment Confirmed!</h2>
          <div style={confirmCard}>
            <div style={confirmRow}><span style={confirmLabel}>Service:</span><span>{serviceType}</span></div>
            <div style={confirmRow}><span style={confirmLabel}>Date:</span><span>{new Date(date + 'T12:00:00').toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}</span></div>
            <div style={confirmRow}><span style={confirmLabel}>Time:</span><span>{time}</span></div>
            <div style={confirmRow}><span style={confirmLabel}>Name:</span><span>{form.firstName} {form.lastName}</span></div>
            <div style={confirmRow}><span style={confirmLabel}>Confirmation:</span><span className="mono">APT-{Math.floor(Math.random() * 9000000 + 1000000)}</span></div>
          </div>
          <p style={{ color: 'var(--color-text-muted)', fontSize: '14px', marginBottom: '24px' }}>
            A confirmation email has been sent to <strong>{form.email}</strong>.
            Please arrive 10 minutes early with your confirmation number and required documents.
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
            <span aria-current="page">Schedule Appointment</span>
          </nav>
          <h1>Schedule an Appointment</h1>
          <p>Book an in-person visit at your nearest Contoso DMV office.</p>
        </div>
      </div>

      {/* Progress steps */}
      <div style={stepBarWrap} aria-label="Appointment booking progress">
        <div className="container" style={stepBarInner}>
          {[{ n: 1, label: 'Service' }, { n: 2, label: 'Date & Time' }, { n: 3, label: 'Your Info' }].map(s => (
            <div key={s.n} style={stepItem}>
              <div style={{ ...stepCircle, ...(step >= s.n ? stepCircleActive : {}) }}
                aria-current={step === s.n ? 'step' : undefined}>
                {step > s.n ? '✓' : s.n}
              </div>
              <span style={{ ...stepLabelStyle, ...(step >= s.n ? { color: 'var(--color-primary)' } : {}) }}>
                {s.label}
              </span>
            </div>
          ))}
        </div>
      </div>

      <div className="section-sm">
        <div className="container" style={{ maxWidth: '680px' }}>

          {/* Step 1: Service Type */}
          {step === 1 && (
            <section aria-labelledby="service-heading">
              <h2 id="service-heading" style={stepHeading}>Select a Service Type</h2>
              <ul style={{ listStyle: 'none', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }} role="radiogroup" aria-label="Service type">
                {services.map(svc => (
                  <li key={svc}>
                    <label style={{ ...serviceOption, ...(serviceType === svc ? serviceOptionActive : {}) }}>
                      <input type="radio" name="service" value={svc}
                        checked={serviceType === svc} onChange={() => setServiceType(svc)}
                        style={{ position: 'absolute', opacity: 0, width: 0, height: 0 }}
                        aria-label={svc} />
                      {svc}
                    </label>
                  </li>
                ))}
              </ul>
              <button className="btn btn-primary" style={{ marginTop: '28px' }}
                onClick={() => setStep(2)} disabled={!serviceType}>
                Continue →
              </button>
            </section>
          )}

          {/* Step 2: Date & Time */}
          {step === 2 && (
            <section aria-labelledby="datetime-heading">
              <h2 id="datetime-heading" style={stepHeading}>Choose a Date &amp; Time</h2>
              <div className="form-group">
                <label htmlFor="apptDate">Preferred Date *</label>
                <input id="apptDate" type="date" min={getMinDate()} value={date}
                  onChange={e => { setDate(e.target.value); setTime('') }}
                  aria-required="true" style={{ maxWidth: '240px' }} />
              </div>
              {date && (
                <fieldset style={{ border: 'none', padding: 0, marginTop: '24px' }}>
                  <legend style={{ ...stepHeading, fontSize: '1rem', marginBottom: '16px' }}>
                    Available Times for {new Date(date + 'T12:00:00').toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' })}
                  </legend>
                  <div style={timeGrid} role="group" aria-label="Available appointment times">
                    {times.map(t => (
                      <button key={t}
                        type="button"
                        disabled={unavailable.has(t)}
                        onClick={() => setTime(t)}
                        style={{ ...timeSlot, ...(time === t ? timeSlotActive : {}), ...(unavailable.has(t) ? timeSlotUnavail : {}) }}
                        aria-pressed={time === t}
                        aria-label={`${t}${unavailable.has(t) ? ' — unavailable' : ''}`}>
                        {t}
                      </button>
                    ))}
                  </div>
                  <p style={{ fontSize: '12px', color: 'var(--color-text-muted)', marginTop: '12px' }}>
                    Grayed slots are unavailable. Each appointment is 30 minutes.
                  </p>
                </fieldset>
              )}
              <div style={{ display: 'flex', gap: '12px', marginTop: '28px' }}>
                <button type="button" className="btn btn-outline" onClick={() => setStep(1)}>← Back</button>
                <button className="btn btn-primary" onClick={() => setStep(3)} disabled={!date || !time}>
                  Continue →
                </button>
              </div>
            </section>
          )}

          {/* Step 3: Personal Info */}
          {step === 3 && (
            <section aria-labelledby="personal-heading">
              <div style={summaryBox}>
                <strong>Your appointment:</strong> {serviceType} on{' '}
                {new Date(date + 'T12:00:00').toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' })} at {time}
              </div>
              <h2 id="personal-heading" style={stepHeading}>Your Contact Information</h2>
              <form onSubmit={handleSubmit} noValidate aria-label="Appointment contact form">
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
                    <p className="field-hint">Confirmation will be sent to this email.</p>
                  </div>
                  <div className="form-group">
                    <label htmlFor="phone">Phone Number</label>
                    <input id="phone" name="phone" type="tel" placeholder="(555) 000-0000" value={form.phone} onChange={handle} />
                  </div>
                </div>
                <div style={{ display: 'flex', gap: '12px', marginTop: '28px' }}>
                  <button type="button" className="btn btn-outline" onClick={() => setStep(2)}>← Back</button>
                  <button type="submit" className="btn btn-primary"
                    disabled={!form.firstName || !form.lastName || !form.email}>
                    Confirm Appointment
                  </button>
                </div>
              </form>
            </section>
          )}
        </div>
      </div>
    </>
  )
}

const stepBarWrap: React.CSSProperties = { background: 'var(--color-surface)', borderBottom: '1px solid var(--color-border)', padding: '16px 0' }
const stepBarInner: React.CSSProperties = { display: 'flex', gap: '32px', alignItems: 'center' }
const stepItem: React.CSSProperties = { display: 'flex', alignItems: 'center', gap: '10px' }
const stepCircle: React.CSSProperties = { width: '28px', height: '28px', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '13px', fontWeight: 600, background: 'var(--color-border)', color: 'var(--color-text-muted)', flexShrink: 0 }
const stepCircleActive: React.CSSProperties = { background: 'var(--color-primary)', color: '#fff' }
const stepLabelStyle: React.CSSProperties = { fontSize: '13px', color: 'var(--color-text-muted)' }
const stepHeading: React.CSSProperties = { fontFamily: 'var(--font-heading)', fontSize: '1.3rem', fontWeight: 600, color: 'var(--color-primary)', marginBottom: '24px', paddingBottom: '12px', borderBottom: '1px solid var(--color-border)' }
const serviceOption: React.CSSProperties = { display: 'flex', alignItems: 'center', padding: '12px 16px', border: '1.5px solid var(--color-border)', borderRadius: 'var(--radius-md)', cursor: 'pointer', fontSize: '14px', fontFamily: 'var(--font-body)', color: 'var(--color-text)', transition: 'border-color 0.15s, background 0.15s', userSelect: 'none' }
const serviceOptionActive: React.CSSProperties = { borderColor: 'var(--color-primary)', background: 'var(--color-info-bg)', color: 'var(--color-primary)', fontWeight: 500 }
const timeGrid: React.CSSProperties = { display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '8px' }
const timeSlot: React.CSSProperties = { padding: '10px 4px', border: '1.5px solid var(--color-border)', borderRadius: 'var(--radius-sm)', fontSize: '13px', fontFamily: 'var(--font-body)', cursor: 'pointer', background: 'var(--color-surface)', color: 'var(--color-text)', transition: 'border-color 0.15s, background 0.15s' }
const timeSlotActive: React.CSSProperties = { borderColor: 'var(--color-primary)', background: 'var(--color-primary)', color: '#fff' }
const timeSlotUnavail: React.CSSProperties = { opacity: 0.38, cursor: 'not-allowed', background: 'var(--color-surface-alt)' }
const summaryBox: React.CSSProperties = { background: 'var(--color-info-bg)', border: '1px solid var(--color-border)', borderRadius: 'var(--radius-md)', padding: '14px 18px', fontSize: '14px', marginBottom: '24px' }
const confirmCard: React.CSSProperties = { background: 'var(--color-surface)', border: '1px solid var(--color-border)', borderRadius: 'var(--radius-lg)', padding: '24px', margin: '24px 0', textAlign: 'left' }
const confirmRow: React.CSSProperties = { display: 'flex', justifyContent: 'space-between', padding: '8px 0', borderBottom: '1px solid var(--color-border)', fontSize: '14px' }
const confirmLabel: React.CSSProperties = { color: 'var(--color-text-muted)', fontWeight: 500 }
