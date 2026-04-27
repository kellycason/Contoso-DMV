import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { dvCreate, dvQuery, dvUpdate, fmt } from '../hooks/useDataverse'
import { useAuth } from '../hooks/useAuth'
import { useMyDMVData } from '../hooks/useMyDMVData'

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

interface OfficeInfo {
  id: string
  name: string
  address1?: string
  city?: string
  state?: string
  zip?: string
  phone?: string
  lat?: number
  lng?: number
  hours?: string
  currentWait?: number
  distance?: number
}

// Haversine distance in miles
function distanceMiles(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const toRad = (n: number) => (n * Math.PI) / 180
  const R = 3958.8
  const dLat = toRad(lat2 - lat1)
  const dLng = toRad(lng2 - lng1)
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2
  return 2 * R * Math.asin(Math.sqrt(a))
}

// Approximate Dallas-area ZIP → lat/lng for proximity estimation (demo-grade)
const DALLAS_ZIP_COORDS: Record<string, [number, number]> = {
  '75201': [32.7883, -96.7989], '75202': [32.7812, -96.8050], '75203': [32.7452, -96.8243],
  '75204': [32.8013, -96.7884], '75205': [32.8346, -96.7857], '75206': [32.8327, -96.7697],
  '75207': [32.7895, -96.8167], '75208': [32.7480, -96.8368], '75209': [32.8464, -96.8186],
  '75210': [32.7760, -96.7374], '75211': [32.7358, -96.8836], '75212': [32.7810, -96.8666],
  '75214': [32.8363, -96.7620], '75215': [32.7529, -96.7779], '75216': [32.7136, -96.7946],
  '75217': [32.7372, -96.6796], '75218': [32.8518, -96.7206], '75219': [32.8131, -96.8123],
  '75220': [32.8640, -96.8561], '75223': [32.8086, -96.7512], '75224': [32.7192, -96.8411],
  '75225': [32.8696, -96.7876], '75226': [32.7836, -96.7691], '75227': [32.7794, -96.7048],
  '75228': [32.8182, -96.6942], '75229': [32.8834, -96.8406], '75230': [32.9022, -96.7809],
  '75231': [32.8769, -96.7501], '75232': [32.6833, -96.8428], '75233': [32.6991, -96.8560],
  '75234': [32.9227, -96.8843], '75235': [32.8261, -96.8367], '75236': [32.6784, -96.8898],
  '75237': [32.6606, -96.8620], '75238': [32.8844, -96.7176], '75240': [32.9321, -96.7754],
  '75241': [32.6827, -96.7673], '75243': [32.9087, -96.7315], '75244': [32.9280, -96.8242],
  '75246': [32.7987, -96.7762], '75247': [32.8176, -96.8556], '75248': [32.9552, -96.7912],
  '75249': [32.6610, -96.9366], '75251': [32.9173, -96.7671], '75252': [32.9878, -96.7738],
  '75253': [32.7007, -96.6275], '75254': [32.9383, -96.8010],
}

function citizenLatLng(address?: string, city?: string, zip?: string): [number, number] | null {
  if (zip && DALLAS_ZIP_COORDS[zip]) return DALLAS_ZIP_COORDS[zip]
  // Lightweight fallback: if city contains "Dallas", use downtown
  if (city && /dallas/i.test(city)) return [32.7767, -96.7970]
  return null
}

export default function Appointments() {
  useEffect(() => { document.title = 'Schedule Appointment — Contoso DMV' }, [])

  const [searchParams] = useSearchParams()
  const [step, setStep] = useState(1)
  const [serviceType, setServiceType] = useState('')
  const [officeId, setOfficeId] = useState('')
  const [offices, setOffices] = useState<OfficeInfo[]>([])
  const [date, setDate] = useState('')
  const [time, setTime] = useState('')
  const [form, setForm] = useState({ firstName: '', lastName: '', email: '', phone: '' })
  const [submitted, setSubmitted] = useState(false)
  const [submitting, setSubmitting] = useState(false)
  const [confirmNum, setConfirmNum] = useState('')
  const [submitError, setSubmitError] = useState('')
  const [prefillNote, setPrefillNote] = useState('')
  const [myApptRefresh, setMyApptRefresh] = useState(0)
  const { userId } = useAuth()
  const dmv = useMyDMVData(userId)

  useEffect(() => {
    dvQuery('dmv_dmvoffices', '$select=dmv_officename,dmv_dmvofficeid,dmv_address1,dmv_city,dmv_state,dmv_zipcode,dmv_phone,dmv_latitude,dmv_longitude,dmv_hours,dmv_currentwait&$orderby=dmv_officename')
      .then(rows => setOffices(rows.map(r => ({
        id: r.dmv_dmvofficeid,
        name: r.dmv_officename,
        address1: r.dmv_address1,
        city: r.dmv_city,
        state: r.dmv_state,
        zip: r.dmv_zipcode,
        phone: r.dmv_phone,
        lat: r.dmv_latitude,
        lng: r.dmv_longitude,
        hours: r.dmv_hours,
        currentWait: r.dmv_currentwait,
      }))))
      .catch(() => {})
  }, [])

  // ── Deep-link pre-fill (e.g. from License Renewal flow) ──
  useEffect(() => {
    const svc = searchParams.get('service')
    if (svc === 'license-renewal') {
      setServiceType('Driver License (New/Renewal)')
      setPrefillNote('We\'ve pre-selected Driver License Renewal for you. Pick a location, date, and time to finish booking.')
    } else if (svc === 'vehicle-registration') {
      setServiceType('Vehicle Registration')
    } else if (svc === 'title-transfer') {
      setServiceType('Title Transfer')
    } else if (svc === 'real-id') {
      setServiceType('REAL ID Application')
    }
    const firstName = searchParams.get('firstName') ?? ''
    const lastName = searchParams.get('lastName') ?? ''
    const email = searchParams.get('email') ?? ''
    const phone = searchParams.get('phone') ?? ''
    if (firstName || lastName || email || phone) {
      setForm(f => ({
        firstName: f.firstName || firstName,
        lastName: f.lastName || lastName,
        email: f.email || email,
        phone: f.phone || phone,
      }))
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const handle = (e: React.ChangeEvent<HTMLInputElement>) =>
    setForm(f => ({ ...f, [e.target.name]: e.target.value }))

  // ── Compute citizen location + sort offices by distance ──
  const citizenCoords = useMemo(() => {
    const c = dmv.citizen
    if (!c) return null
    return citizenLatLng(c.address, c.city, c.zip)
  }, [dmv.citizen])

  const sortedOffices = useMemo<OfficeInfo[]>(() => {
    if (!citizenCoords) return offices
    const [cLat, cLng] = citizenCoords
    return offices
      .map(o => ({
        ...o,
        distance: (o.lat != null && o.lng != null) ? distanceMiles(cLat, cLng, o.lat, o.lng) : undefined,
      }))
      .sort((a, b) => {
        if (a.distance == null) return 1
        if (b.distance == null) return -1
        return a.distance - b.distance
      })
  }, [offices, citizenCoords])

  // Auto-pre-fill contact from logged-in profile if not already deep-linked
  useEffect(() => {
    if (dmv.loading || !dmv.citizen) return
    const [first, ...rest] = (dmv.citizen.fullName ?? '').split(' ')
    setForm(f => ({
      firstName: f.firstName || first || '',
      lastName: f.lastName || rest.join(' ') || '',
      email: f.email || dmv.citizen!.email || '',
      phone: f.phone || dmv.citizen!.phone || '',
    }))
  }, [dmv.loading, dmv.citizen])

  const serviceTypeMap: Record<string, number> = {
    'Driver License (New/Renewal)': 100000001,
    'Vehicle Registration': 100000002,
    'Title Transfer': 100000004,
    'REAL ID Application': 100000000,
    'Name/Address Change': 100000005,
    'Duplicate License': 100000001,
    'Commercial License (CDL)': 100000003,
    'Other': 100000005,
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setSubmitting(true)
    setSubmitError('')
    try {
      const aptNum = `APT-${Math.floor(Math.random() * 9000000 + 1000000)}`
      await dvCreate('dmv_appointments', {
        dmv_appointmentnumber: aptNum,
        dmv_servicetype: serviceTypeMap[serviceType] ?? 100000005,
        dmv_appointmentdate: `${date}T00:00:00Z`,
        dmv_appointmenttime: time,
        dmv_status: 100000000, // Scheduled
        dmv_confirmationsent: false,
        dmv_remindersent: false,
        'dmv_officeid@odata.bind': `/dmv_dmvoffices(${officeId})`,
        ...(userId ? { 'dmv_contactid@odata.bind': `/contacts(${userId})` } : {}),
      })
      setConfirmNum(aptNum)
      setSubmitted(true)
      setMyApptRefresh(x => x + 1)
    } catch (err) {
      setSubmitError(err instanceof Error ? err.message : 'Booking failed. Please try again.')
    } finally {
      setSubmitting(false)
    }
  }

  if (submitted) {
    return (
      <>
        <div className="page-header"><div className="container"><h1>Schedule Appointment</h1></div></div>
        <div className="container" style={{ padding: '64px 24px', maxWidth: '600px', textAlign: 'center' }}>
          <div style={{ fontSize: '48px', marginBottom: '16px' }} aria-hidden="true">📅</div>
          <h2 style={{ marginBottom: '12px', color: 'var(--color-success)' }}>Appointment Confirmed!</h2>
          <div style={confirmCard}>
            <div style={confirmRow}><span style={confirmLabel}>Service:</span><span>{serviceType}</span></div>
            <div style={confirmRow}><span style={confirmLabel}>Location:</span><span>{offices.find(o => o.id === officeId)?.name}</span></div>
            <div style={confirmRow}><span style={confirmLabel}>Date:</span><span>{new Date(date + 'T12:00:00').toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}</span></div>
            <div style={confirmRow}><span style={confirmLabel}>Time:</span><span>{time}</span></div>
            <div style={confirmRow}><span style={confirmLabel}>Name:</span><span>{form.firstName} {form.lastName}</span></div>
            <div style={confirmRow}><span style={confirmLabel}>Confirmation:</span><span className="mono">{confirmNum}</span></div>
          </div>
          <p style={{ color: 'var(--color-text-muted)', fontSize: '14px', marginBottom: '24px' }}>
            A confirmation email has been sent to <strong>{form.email}</strong>.
            Please arrive 10 minutes early with your confirmation number and required documents.
          </p>
          <div style={{ display: 'flex', gap: 12, justifyContent: 'center', flexWrap: 'wrap' }}>
            <Link to="/appointments" className="btn btn-primary"
                  onClick={() => { setSubmitted(false); setStep(1); setServiceType(''); setOfficeId(''); setDate(''); setTime(''); setConfirmNum(''); }}>
              View My Appointments
            </Link>
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
            <span aria-current="page">Schedule Appointment</span>
          </nav>
          <h1>Schedule an Appointment</h1>
          <p>Book an in-person visit at your nearest Contoso DMV office.</p>
        </div>
      </div>

      {/* My upcoming appointments (manage / cancel / reschedule) */}
      <MyAppointments
        userId={userId}
        offices={sortedOffices}
        refreshKey={myApptRefresh}
        onChange={() => setMyApptRefresh(x => x + 1)}
      />

      {/* Progress steps */}
      <div style={stepBarWrap} aria-label="Appointment booking progress">
        <div className="container" style={stepBarInner}>
          {[{ n: 1, label: 'Service' }, { n: 2, label: 'Location' }, { n: 3, label: 'Date & Time' }, { n: 4, label: 'Your Info' }].map(s => (
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
              {prefillNote && (
                <div style={{
                  display: 'flex', gap: 12, alignItems: 'flex-start',
                  background: '#eaf4fb', border: '1px solid var(--color-primary)',
                  borderLeft: '4px solid var(--color-primary)',
                  borderRadius: 'var(--radius-md)',
                  padding: '12px 16px', fontSize: 14, lineHeight: 1.5,
                  marginBottom: 20,
                }}>
                  <span aria-hidden="true" style={{ fontSize: 18, lineHeight: 1 }}>ℹ️</span>
                  <span>{prefillNote}</span>
                </div>
              )}
              <div style={{ listStyle: 'none', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }} role="radiogroup" aria-label="Service type">
                {services.map(svc => (
                  <div key={svc} role="none">
                    <label style={{ ...serviceOption, ...(serviceType === svc ? serviceOptionActive : {}) }}>
                      <input type="radio" name="service" value={svc}
                        checked={serviceType === svc} onChange={() => setServiceType(svc)}
                        style={{ position: 'absolute', opacity: 0, width: 0, height: 0 }}
                        aria-label={svc} />
                      {svc}
                    </label>
                  </div>
                ))}
              </div>
              <button className="btn btn-primary" style={{ marginTop: '28px' }}
                onClick={() => setStep(2)} disabled={!serviceType}>
                Continue →
              </button>
            </section>
          )}

          {/* Step 2: Location */}
          {step === 2 && (
            <section aria-labelledby="location-heading">
              <h2 id="location-heading" style={stepHeading}>Select a Location</h2>
              {sortedOffices.length > 0 && citizenCoords && (
                <p style={{ fontSize: 13, color: 'var(--color-text-muted)', margin: '0 0 14px' }}>
                  Sorted by distance from your address on file ({dmv.citizen?.city}{dmv.citizen?.zip ? `, ${dmv.citizen?.zip}` : ''}).
                </p>
              )}
              <div style={{ display: 'grid', gap: '10px' }} role="radiogroup" aria-label="Office location">
                {sortedOffices.map(o => {
                  const selected = officeId === o.id
                  const waitColor = (o.currentWait ?? 0) <= 15 ? 'var(--color-success)' : (o.currentWait ?? 0) <= 30 ? 'var(--color-warning)' : 'var(--color-accent)'
                  return (
                    <label key={o.id} style={{
                      ...officeCard, ...(selected ? officeCardActive : {}),
                    }}>
                      <input type="radio" name="office" value={o.id}
                        checked={selected} onChange={() => setOfficeId(o.id)}
                        style={{ position: 'absolute', opacity: 0, width: 0, height: 0 }}
                        aria-label={o.name} />
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 12 }}>
                        <div style={{ flex: 1 }}>
                          <div style={{ fontWeight: 700, fontSize: 15, color: 'var(--color-primary)', marginBottom: 4 }}>{o.name}</div>
                          {o.address1 && (
                            <div style={{ fontSize: 13, color: 'var(--color-text)', lineHeight: 1.5 }}>
                              {o.address1}<br />
                              {o.city}, {o.state} {o.zip}
                            </div>
                          )}
                          {o.phone && (
                            <div style={{ fontSize: 12, color: 'var(--color-text-muted)', marginTop: 6 }}>
                              📞 {o.phone}
                            </div>
                          )}
                        </div>
                        <div style={{ textAlign: 'right', flexShrink: 0 }}>
                          {o.distance !== undefined && (
                            <div style={{ fontSize: 13, fontWeight: 700, color: 'var(--color-secondary)', marginBottom: 4 }}>
                              📍 {o.distance.toFixed(1)} mi
                            </div>
                          )}
                          {o.currentWait !== undefined && o.currentWait !== null && (
                            <div style={{ fontSize: 11, color: waitColor, fontWeight: 600 }}>
                              {o.currentWait} min wait
                            </div>
                          )}
                        </div>
                      </div>
                    </label>
                  )
                })}
                {offices.length === 0 && <p style={{ color: 'var(--color-text-muted)' }}>Loading locations...</p>}
              </div>
              <div style={{ display: 'flex', gap: '12px', marginTop: '28px' }}>
                <button type="button" className="btn btn-outline" onClick={() => setStep(1)}>← Back</button>
                <button className="btn btn-primary" onClick={() => setStep(3)} disabled={!officeId}>
                  Continue →
                </button>
              </div>
            </section>
          )}

          {/* Step 3: Date & Time */}
          {step === 3 && (
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
                <button type="button" className="btn btn-outline" onClick={() => setStep(2)}>← Back</button>
                <button className="btn btn-primary" onClick={() => setStep(4)} disabled={!date || !time}>
                  Continue →
                </button>
              </div>
            </section>
          )}

          {/* Step 4: Personal Info */}
          {step === 4 && (
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
                  <button type="button" className="btn btn-outline" onClick={() => setStep(3)}>← Back</button>
                  <button type="submit" className="btn btn-primary"
                    disabled={!form.firstName || !form.lastName || !form.email || submitting}>
                    {submitting ? 'Booking...' : 'Confirm Appointment'}
                  </button>
                  {submitError && <p style={{ color: '#c0392b', fontSize: '14px', marginTop: '8px' }}>{submitError}</p>}
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
const officeCard: React.CSSProperties = { display: 'block', padding: '14px 18px', border: '1.5px solid var(--color-border)', borderRadius: 'var(--radius-md)', cursor: 'pointer', background: 'var(--color-surface)', transition: 'border-color 0.15s, background 0.15s', userSelect: 'none', position: 'relative' }
const officeCardActive: React.CSSProperties = { borderColor: 'var(--color-primary)', background: 'var(--color-info-bg, #eaf4fb)', boxShadow: '0 0 0 1px var(--color-primary)' }
const timeGrid: React.CSSProperties = { display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '8px' }
const timeSlot: React.CSSProperties = { padding: '10px 4px', border: '1.5px solid var(--color-border)', borderRadius: 'var(--radius-sm)', fontSize: '13px', fontFamily: 'var(--font-body)', cursor: 'pointer', background: 'var(--color-surface)', color: 'var(--color-text)', transition: 'border-color 0.15s, background 0.15s' }
const timeSlotActive: React.CSSProperties = { borderColor: 'var(--color-primary)', background: 'var(--color-primary)', color: '#fff' }
const timeSlotUnavail: React.CSSProperties = { opacity: 0.38, cursor: 'not-allowed', background: 'var(--color-surface-alt)' }
const summaryBox: React.CSSProperties = { background: 'var(--color-info-bg)', border: '1px solid var(--color-border)', borderRadius: 'var(--radius-md)', padding: '14px 18px', fontSize: '14px', marginBottom: '24px' }
const confirmCard: React.CSSProperties = { background: 'var(--color-surface)', border: '1px solid var(--color-border)', borderRadius: 'var(--radius-lg)', padding: '24px', margin: '24px 0', textAlign: 'left' }
const confirmRow: React.CSSProperties = { display: 'flex', justifyContent: 'space-between', padding: '8px 0', borderBottom: '1px solid var(--color-border)', fontSize: '14px' }
const confirmLabel: React.CSSProperties = { color: 'var(--color-text-muted)', fontWeight: 500 }

// ──────────────────────────────────────────────────────────────────────────────
// My Appointments — manage upcoming (Cancel / Reschedule)
// ──────────────────────────────────────────────────────────────────────────────

const TIME_SLOTS = ['8:00 AM', '8:30 AM', '9:00 AM', '9:30 AM', '10:00 AM', '10:30 AM',
                    '11:00 AM', '11:30 AM', '1:00 PM', '1:30 PM', '2:00 PM', '2:30 PM',
                    '3:00 PM', '3:30 PM', '4:00 PM', '4:30 PM']
const UNAVAILABLE = new Set(['9:00 AM', '10:30 AM', '1:30 PM', '3:00 PM'])

interface MyAppt {
  id: string
  number: string
  service: string
  date: string            // yyyy-MM-dd
  time: string
  status: string
  statusCode: number
  officeId: string
  officeName: string
}

interface MyAppointmentsProps {
  userId: string | null
  offices: OfficeInfo[]
  refreshKey: number
  onChange: () => void
}

function MyAppointments({ userId, offices, refreshKey, onChange }: MyAppointmentsProps) {
  const [appts, setAppts] = useState<MyAppt[]>([])
  const [loading, setLoading] = useState(true)
  const [busyId, setBusyId] = useState<string | null>(null)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')
  const [editing, setEditing] = useState<MyAppt | null>(null)
  const [cancelling, setCancelling] = useState<MyAppt | null>(null)

  const officeNameById = useMemo(() => {
    const m: Record<string, string> = {}
    offices.forEach(o => { m[o.id] = o.name })
    return m
  }, [offices])

  const load = useCallback(async () => {
    if (!userId) { setLoading(false); return }
    setLoading(true)
    setError('')
    try {
      const today = new Date().toISOString().split('T')[0]
      const rows = await dvQuery(
        'dmv_appointments',
        `$filter=_dmv_contactid_value eq ${userId} and dmv_status ne 100000005 and dmv_status ne 100000003 and dmv_appointmentdate ge ${today}T00:00:00Z` +
        `&$select=dmv_appointmentid,dmv_appointmentnumber,dmv_servicetype,dmv_appointmentdate,dmv_appointmenttime,dmv_status,_dmv_officeid_value` +
        `&$orderby=dmv_appointmentdate asc`
      )
      setAppts(rows.map(r => ({
        id: r.dmv_appointmentid,
        number: r.dmv_appointmentnumber ?? '—',
        service: fmt(r, 'dmv_servicetype'),
        date: (r.dmv_appointmentdate ?? '').split('T')[0],
        time: r.dmv_appointmenttime ?? '',
        status: fmt(r, 'dmv_status'),
        statusCode: r.dmv_status,
        officeId: r._dmv_officeid_value ?? '',
        officeName: fmt(r, '_dmv_officeid_value') || r['_dmv_officeid_value@OData.Community.Display.V1.FormattedValue'] || '',
      })))
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load your appointments.')
    } finally {
      setLoading(false)
    }
  }, [userId])

  useEffect(() => { load() }, [load, refreshKey])

  const handleCancel = async (a: MyAppt) => {
    setCancelling(null)
    setBusyId(a.id)
    setError('')
    setNotice('')
    try {
      await dvUpdate('dmv_appointments', a.id, { dmv_status: 100000005 })
      setNotice(`Appointment ${a.number} cancelled. A confirmation email is on its way.`)
      await load()
      onChange()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Cancel failed. Please try again.')
    } finally {
      setBusyId(null)
    }
  }

  if (!userId) return null
  if (loading) return null

  return (
    <div style={{ background: 'var(--color-surface)', borderBottom: '1px solid var(--color-border)' }}>
      <div className="container" style={{ maxWidth: 900, padding: '28px 24px 8px' }}>
        <h2 style={{ fontSize: '1.2rem', fontFamily: 'var(--font-heading)', color: 'var(--color-primary)', margin: '0 0 4px' }}>
          My Upcoming Appointments
        </h2>
        {notice && (
          <div style={{ background: '#e8f5ec', border: '1px solid var(--color-success)', borderLeft: '4px solid var(--color-success)', borderRadius: 'var(--radius-md)', padding: '10px 14px', fontSize: 13, color: '#1a5c33', margin: '12px 0' }}>
            ✓ {notice}
          </div>
        )}
        {error && (
          <div style={{ background: '#fde8e8', border: '1px solid #c0392b', borderLeft: '4px solid #c0392b', borderRadius: 'var(--radius-md)', padding: '10px 14px', fontSize: 13, color: '#7a1d1d', margin: '12px 0' }}>
            {error}
          </div>
        )}

        {appts.length === 0 ? (
          <p style={{ fontSize: 13, color: 'var(--color-text-muted)', margin: '8px 0 20px' }}>
            You don't have any upcoming appointments. Book one below.
          </p>
        ) : (
          <div style={{ display: 'grid', gap: 12, margin: '16px 0 20px' }}>
            {appts.map(a => {
              const d = new Date(a.date + 'T12:00:00')
              const officeDisplay = officeNameById[a.officeId] || a.officeName || 'DMV Office'
              return (
                <div key={a.id} style={apptCard}>
                  <div style={{ display: 'flex', gap: 16, flexWrap: 'wrap', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                    <div style={{ flex: '1 1 280px', minWidth: 0 }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 6, flexWrap: 'wrap' }}>
                        <span style={{ fontWeight: 700, fontSize: 15, color: 'var(--color-primary)' }}>{a.service}</span>
                        <span style={apptStatusBadge(a.statusCode)}>{a.status || 'Scheduled'}</span>
                      </div>
                      <div style={{ fontSize: 14, color: 'var(--color-text)', marginBottom: 2 }}>
                        <strong>{d.toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' })}</strong> at <strong>{a.time}</strong>
                      </div>
                      <div style={{ fontSize: 13, color: 'var(--color-text-muted)', marginBottom: 2 }}>
                        📍 {officeDisplay}
                      </div>
                      <div style={{ fontSize: 12, color: 'var(--color-text-muted)' }}>
                        Confirmation: <span className="mono" style={{ fontWeight: 600 }}>{a.number}</span>
                      </div>
                    </div>
                    <div style={{ display: 'flex', gap: 8, flexShrink: 0 }}>
                      <button className="btn btn-outline"
                        style={{ fontSize: 13, padding: '8px 14px' }}
                        onClick={() => setEditing(a)}
                        disabled={busyId === a.id}>
                        Reschedule
                      </button>
                      <button className="btn"
                        style={{ fontSize: 13, padding: '8px 14px', background: 'var(--color-surface)', color: '#c0392b', borderColor: '#c0392b' }}
                        onClick={() => setCancelling(a)}
                        disabled={busyId === a.id}>
                        {busyId === a.id ? 'Cancelling...' : 'Cancel'}
                      </button>
                    </div>
                  </div>
                </div>
              )
            })}
          </div>
        )}
      </div>

      {editing && (
        <RescheduleModal
          appt={editing}
          offices={offices}
          onClose={() => setEditing(null)}
          onSaved={async () => {
            setEditing(null)
            setNotice('Appointment updated.')
            await load()
            onChange()
          }}
        />
      )}
      {cancelling && (
        <ConfirmCancelModal
          appt={cancelling}
          busy={busyId === cancelling.id}
          onClose={() => setCancelling(null)}
          onConfirm={() => handleCancel(cancelling)}
        />
      )}
    </div>
  )
}

function apptStatusBadge(code: number): React.CSSProperties {
  // 0=Scheduled, 1=Confirmed, 2=Checked In, 4=No-Show
  const base: React.CSSProperties = {
    fontSize: 10, fontWeight: 700, letterSpacing: '0.08em', textTransform: 'uppercase',
    padding: '3px 8px', borderRadius: 4,
  }
  if (code === 100000001) return { ...base, background: '#e8f5ec', color: '#1a5c33' }   // Confirmed
  if (code === 100000002) return { ...base, background: '#eaf4fb', color: '#0b4a7a' }   // Checked In
  return { ...base, background: '#fdf7e0', color: '#5a4a00' }                           // Scheduled / default
}

// ── Cancel confirmation modal ──
interface ConfirmCancelProps {
  appt: { number: string; service: string; date: string; time: string }
  busy?: boolean
  onClose: () => void
  onConfirm: () => void
}

export function ConfirmCancelModal({ appt, busy, onClose, onConfirm }: ConfirmCancelProps) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape' && !busy) onClose() }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [onClose, busy])

  const d = new Date(appt.date + 'T12:00:00')

  return (
    <div role="dialog" aria-modal="true" aria-labelledby="cancel-title"
         style={modalOverlay} onClick={busy ? undefined : onClose}>
      <div style={{ ...modalCard, maxWidth: 480 }} onClick={e => e.stopPropagation()}>
        <div style={{ display: 'flex', alignItems: 'flex-start', gap: 14, marginBottom: 18 }}>
          <div aria-hidden="true" style={{
            flexShrink: 0, width: 44, height: 44, borderRadius: '50%',
            background: '#fde8e8', display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontSize: 22, color: '#c0392b', fontWeight: 700,
          }}>!</div>
          <div style={{ flex: 1 }}>
            <h3 id="cancel-title" style={{ margin: '0 0 6px', fontFamily: 'var(--font-heading)', fontSize: '1.15rem', color: 'var(--color-primary)' }}>
              Cancel this appointment?
            </h3>
            <p style={{ margin: 0, fontSize: 13, color: 'var(--color-text-muted)', lineHeight: 1.5 }}>
              This action cannot be undone. You'll need to book a new appointment if you change your mind.
            </p>
          </div>
        </div>

        <div style={{
          background: 'var(--color-surface-alt, #f7f7f7)',
          border: '1px solid var(--color-border)',
          borderRadius: 'var(--radius-md)',
          padding: '14px 16px', marginBottom: 18, fontSize: 13.5,
        }}>
          <div style={{ marginBottom: 6 }}>
            <span style={{ color: 'var(--color-text-muted)', marginRight: 6 }}>Confirmation:</span>
            <span className="mono" style={{ fontWeight: 600 }}>{appt.number}</span>
          </div>
          <div style={{ marginBottom: 4, fontWeight: 600, color: 'var(--color-primary)' }}>
            {appt.service}
          </div>
          <div style={{ color: 'var(--color-text)' }}>
            {d.toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' })} at {appt.time}
          </div>
        </div>

        <div style={{ display: 'flex', gap: 10, justifyContent: 'flex-end', flexWrap: 'wrap' }}>
          <button type="button" className="btn btn-outline" onClick={onClose} disabled={busy}>
            Keep Appointment
          </button>
          <button type="button" className="btn"
                  onClick={onConfirm} disabled={busy}
                  style={{ background: '#c0392b', color: '#fff', borderColor: '#c0392b' }}>
            {busy ? 'Cancelling...' : 'Yes, Cancel Appointment'}
          </button>
        </div>
      </div>
    </div>
  )
}

// ── Reschedule modal ──
interface RescheduleModalProps {
  appt: MyAppt
  offices: OfficeInfo[]
  onClose: () => void
  onSaved: () => void
}

function RescheduleModal({ appt, offices, onClose, onSaved }: RescheduleModalProps) {
  const [officeId, setOfficeId] = useState(appt.officeId)
  const [date, setDate] = useState(appt.date)
  const [time, setTime] = useState(appt.time)
  const [saving, setSaving] = useState(false)
  const [err, setErr] = useState('')

  const minDate = useMemo(() => {
    const d = new Date(); d.setDate(d.getDate() + 1)
    return d.toISOString().split('T')[0]
  }, [])

  const changed = officeId !== appt.officeId || date !== appt.date || time !== appt.time

  const save = async () => {
    if (!changed) { onClose(); return }
    setSaving(true)
    setErr('')
    try {
      const patch: Record<string, unknown> = {}
      if (date !== appt.date) patch.dmv_appointmentdate = `${date}T00:00:00Z`
      if (time !== appt.time) patch.dmv_appointmenttime = time
      if (officeId !== appt.officeId) {
        patch['dmv_officeid@odata.bind'] = `/dmv_dmvoffices(${officeId})`
      }
      // Note: do NOT reset dmv_confirmationsent — the reschedule flow handles
      // the updated email. Resetting it would let the confirmation flow re-fire.
      await dvUpdate('dmv_appointments', appt.id, patch)
      onSaved()
    } catch (e) {
      setErr(e instanceof Error ? e.message : 'Update failed. Please try again.')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div role="dialog" aria-modal="true" aria-labelledby="reschedule-title"
         style={modalOverlay} onClick={onClose}>
      <div style={modalCard} onClick={e => e.stopPropagation()}>
        <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 16, marginBottom: 18 }}>
          <div>
            <h3 id="reschedule-title" style={{ margin: '0 0 4px', fontFamily: 'var(--font-heading)', fontSize: '1.2rem', color: 'var(--color-primary)' }}>
              Reschedule Appointment
            </h3>
            <p style={{ margin: 0, fontSize: 13, color: 'var(--color-text-muted)' }}>
              {appt.service} • <span className="mono">{appt.number}</span>
            </p>
          </div>
          <button onClick={onClose} aria-label="Close"
                  style={{ background: 'none', border: 'none', fontSize: 24, lineHeight: 1, cursor: 'pointer', color: 'var(--color-text-muted)', padding: 0 }}>
            ×
          </button>
        </div>

        <div className="form-group">
          <label htmlFor="resch-office">Location</label>
          <select id="resch-office" value={officeId} onChange={e => setOfficeId(e.target.value)}
                  style={{ width: '100%' }}>
            {offices.map(o => (
              <option key={o.id} value={o.id}>
                {o.name}{o.city ? ` — ${o.city}` : ''}
              </option>
            ))}
          </select>
        </div>

        <div className="form-group">
          <label htmlFor="resch-date">Date</label>
          <input id="resch-date" type="date" min={minDate} value={date}
                 onChange={e => { setDate(e.target.value) }}
                 style={{ maxWidth: 240 }} />
        </div>

        <fieldset style={{ border: 'none', padding: 0, margin: '4px 0 0' }}>
          <legend style={{ fontSize: 13, color: 'var(--color-text-muted)', fontWeight: 500, marginBottom: 8 }}>
            Available Times
          </legend>
          <div style={timeGrid}>
            {TIME_SLOTS.map(t => {
              const unavail = UNAVAILABLE.has(t) && t !== appt.time
              return (
                <button key={t} type="button" disabled={unavail}
                        onClick={() => setTime(t)}
                        style={{ ...timeSlot, ...(time === t ? timeSlotActive : {}), ...(unavail ? timeSlotUnavail : {}) }}
                        aria-pressed={time === t}>
                  {t}
                </button>
              )
            })}
          </div>
        </fieldset>

        {err && (
          <p style={{ color: '#c0392b', fontSize: 13, marginTop: 14 }}>{err}</p>
        )}

        <div style={{ display: 'flex', gap: 10, justifyContent: 'flex-end', marginTop: 24, flexWrap: 'wrap' }}>
          <button type="button" className="btn btn-outline" onClick={onClose} disabled={saving}>
            Cancel
          </button>
          <button type="button" className="btn btn-primary" onClick={save} disabled={saving || !changed}>
            {saving ? 'Saving...' : 'Save Changes'}
          </button>
        </div>
      </div>
    </div>
  )
}

const apptCard: React.CSSProperties = {
  background: 'var(--color-surface)',
  border: '1px solid var(--color-border)',
  borderLeft: '4px solid var(--color-primary)',
  borderRadius: 'var(--radius-md)',
  padding: '16px 18px',
}
const modalOverlay: React.CSSProperties = {
  position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.45)',
  display: 'flex', alignItems: 'flex-start', justifyContent: 'center',
  padding: '60px 16px', zIndex: 1000, overflowY: 'auto',
}
const modalCard: React.CSSProperties = {
  background: 'var(--color-surface)', borderRadius: 'var(--radius-lg)',
  padding: '24px 28px', width: '100%', maxWidth: 560,
  boxShadow: '0 16px 48px rgba(0,0,0,0.25)',
}
