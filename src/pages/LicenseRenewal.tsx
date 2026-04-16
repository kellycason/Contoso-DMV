import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { dvCreate } from '../hooks/useDataverse'
import { useAuth } from '../hooks/useAuth'

export default function LicenseRenewal() {
  useEffect(() => { document.title = 'License Renewal — Contoso DMV' }, [])
  const { userId } = useAuth()

  const [form, setForm] = useState({
    licenseNumber: '',
    dob: '',
    ssn4: '',
    email: '',
    phone: '',
    address: '',
    city: '',
    state: 'CA',
    zip: '',
  })
  const [submitted, setSubmitted] = useState(false)
  const [submitting, setSubmitting] = useState(false)
  const [refNumber, setRefNumber] = useState('')
  const [submitError, setSubmitError] = useState('')

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    setForm(f => ({ ...f, [e.target.name]: e.target.value }))
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
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
        <div className="page-header">
          <div className="container"><h1>License Renewal</h1></div>
        </div>
        <div className="container" style={{ padding: '64px 24px', maxWidth: '600px', textAlign: 'center' }}>
          <div style={{ fontSize: '48px', marginBottom: '16px' }} aria-hidden="true">✅</div>
          <h2 style={{ marginBottom: '12px', color: 'var(--color-success)' }}>Renewal Submitted!</h2>
          <p style={{ color: 'var(--color-text-muted)', marginBottom: '8px' }}>
            Your license renewal request has been received. You will receive a confirmation email within 24 hours.
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
            <span aria-current="page">License Renewal</span>
          </nav>
          <h1>License Renewal</h1>
          <p>Renew your Contoso County driver's license online — no office visit required for most renewals.</p>
        </div>
      </div>

      <div className="section-sm">
        <div className="container" style={{ maxWidth: '720px' }}>
          <div style={infoBox}>
            <strong>Before you begin:</strong> Have your current driver's license, date of birth, and last 4 digits
            of your Social Security Number ready. Renewals are processed within 2–3 business days.
          </div>

          <form onSubmit={handleSubmit} noValidate aria-label="License renewal form">
            <section aria-labelledby="license-info-heading">
              <h2 id="license-info-heading" style={sectionHeading}>License Information</h2>

              <div className="form-group">
                <label htmlFor="licenseNumber">Driver's License Number *</label>
                <input
                  id="licenseNumber" name="licenseNumber" type="text"
                  placeholder="e.g. D1234567" required
                  value={form.licenseNumber} onChange={handleChange}
                  aria-required="true"
                />
                <p className="field-hint">Found on the front of your current license (1 letter + 7 digits)</p>
              </div>

              <div className="form-row">
                <div className="form-group">
                  <label htmlFor="dob">Date of Birth *</label>
                  <input id="dob" name="dob" type="date" required value={form.dob} onChange={handleChange} aria-required="true" />
                </div>
                <div className="form-group">
                  <label htmlFor="ssn4">Last 4 Digits of SSN *</label>
                  <input
                    id="ssn4" name="ssn4" type="text" inputMode="numeric"
                    maxLength={4} placeholder="XXXX" required
                    value={form.ssn4} onChange={handleChange} aria-required="true"
                  />
                </div>
              </div>
            </section>

            <section aria-labelledby="contact-info-heading" style={{ marginTop: '32px' }}>
              <h2 id="contact-info-heading" style={sectionHeading}>Contact Information</h2>

              <div className="form-row">
                <div className="form-group">
                  <label htmlFor="email">Email Address *</label>
                  <input id="email" name="email" type="email" required value={form.email} onChange={handleChange} aria-required="true" />
                </div>
                <div className="form-group">
                  <label htmlFor="phone">Phone Number</label>
                  <input id="phone" name="phone" type="tel" placeholder="(555) 000-0000" value={form.phone} onChange={handleChange} />
                </div>
              </div>
            </section>

            <section aria-labelledby="address-heading" style={{ marginTop: '32px' }}>
              <h2 id="address-heading" style={sectionHeading}>Mailing Address</h2>
              <p style={{ color: 'var(--color-text-muted)', fontSize: '14px', marginBottom: '16px' }}>
                Your renewed license will be mailed to this address.
              </p>

              <div className="form-group">
                <label htmlFor="address">Street Address *</label>
                <input id="address" name="address" type="text" required value={form.address} onChange={handleChange} aria-required="true" />
              </div>

              <div className="form-row">
                <div className="form-group">
                  <label htmlFor="city">City *</label>
                  <input id="city" name="city" type="text" required value={form.city} onChange={handleChange} aria-required="true" />
                </div>
                <div className="form-group">
                  <label htmlFor="zip">ZIP Code *</label>
                  <input id="zip" name="zip" type="text" inputMode="numeric" maxLength={5} required value={form.zip} onChange={handleChange} aria-required="true" />
                </div>
              </div>
            </section>

            <div style={{ marginTop: '40px', display: 'flex', gap: '16px', alignItems: 'center' }}>
              <button type="submit" className="btn btn-primary" style={{ fontSize: '15px', padding: '12px 28px' }} disabled={submitting}>
                {submitting ? 'Submitting...' : 'Submit Renewal Request'}
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

const sectionHeading: React.CSSProperties = {
  fontFamily: 'var(--font-heading)',
  fontSize: '1.15rem',
  fontWeight: 600,
  color: 'var(--color-primary)',
  paddingBottom: '12px',
  borderBottom: '1px solid var(--color-border)',
  marginBottom: '24px',
}
