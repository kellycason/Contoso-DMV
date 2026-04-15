import { useEffect } from 'react'
import { Link } from 'react-router-dom'

const services = [
  {
    icon: '🪪',
    title: 'License Renewal',
    desc: 'Renew your driver\'s license online in minutes. No office visit required for most renewals.',
    to: '/license-renewal',
    cta: 'Renew License',
  },
  {
    icon: '🚗',
    title: 'Vehicle Registration',
    desc: 'Register a new vehicle or renew your existing registration quickly and securely.',
    to: '/vehicle-registration',
    cta: 'Register Vehicle',
  },
  {
    icon: '📅',
    title: 'Schedule Appointment',
    desc: 'Book an in-person appointment at your nearest DMV office for services requiring a visit.',
    to: '/appointments',
    cta: 'Book Appointment',
  },
  {
    icon: '📄',
    title: 'Upload Documents',
    desc: 'Securely submit required documents for license applications, registrations, and title transfers.',
    to: '/documents',
    cta: 'Upload Now',
  },
  {
    icon: '❓',
    title: 'Frequently Asked Questions',
    desc: 'Find answers to the most common questions about licenses, registrations, and DMV services.',
    to: '/faq',
    cta: 'Browse FAQ',
  },
  {
    icon: '📋',
    title: 'Check Application Status',
    desc: 'Track the status of your pending license application, title transfer, or registration.',
    to: '/faq',
    cta: 'Check Status',
  },
]

export default function Home() {
  useEffect(() => {
    document.title = 'Contoso DMV'
  }, [])

  return (
    <>
      {/* Alert Banner */}
      <div role="alert" aria-live="polite" style={styles.alertBanner}>
        <div className="container" style={styles.alertInner}>
          <span style={styles.alertBadge}>Notice</span>
          <span>
            DMV offices will be closed on Memorial Day, May 26. Online services remain available 24/7.
          </span>
          <Link to="/faq" style={styles.alertLink}>Learn more →</Link>
        </div>
      </div>

      {/* Hero */}
      <section style={styles.hero} aria-label="Welcome section">
        <div style={styles.heroOverlay} aria-hidden="true" />
        <div className="container" style={styles.heroContent}>
          <p style={styles.heroEyebrow}>Official Government Portal</p>
          <h1 style={styles.heroTitle}>
            Contoso County<br />
            <em style={styles.heroTitleItalic}>Department of Motor Vehicles</em>
          </h1>
          <p style={styles.heroSubtitle}>
            Fast, secure, and accessible government services — available online 24/7
            so you spend less time at the office and more time on the road.
          </p>
          <div style={styles.heroActions}>
            <Link to="/appointments" className="btn btn-primary" style={{ fontSize: '15px', padding: '13px 28px' }}>
              Schedule an Appointment
            </Link>
            <Link to="/faq" className="btn btn-outline" style={{ fontSize: '15px', padding: '13px 28px', borderColor: 'rgba(255,255,255,0.5)', color: '#fff' }}>
              Learn More
            </Link>
          </div>
        </div>
      </section>

      {/* Quick Status Bar */}
      <div style={styles.statusBar} aria-label="Service status">
        <div className="container" style={styles.statusBarInner}>
          {[
            { label: 'Online Services', status: 'All Operational', color: '#197A6F' },
            { label: 'Processing Time', status: '2–3 Business Days', color: 'var(--color-secondary)' },
            { label: 'Wait Time (In-Person)', status: 'Approx. 45 min', color: 'var(--color-text-muted)' },
          ].map(item => (
            <div key={item.label} style={styles.statusItem}>
              <span style={styles.statusDot(item.color)} aria-hidden="true" />
              <span style={styles.statusLabel}>{item.label}:</span>
              <span style={{ ...styles.statusValue, color: item.color }}>{item.status}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Services Grid */}
      <section style={styles.servicesSection} aria-labelledby="services-heading">
        <div className="container">
          <div className="section-header">
            <h2 id="services-heading">Online Services</h2>
            <p>Complete your DMV transactions from home — no waiting in line.</p>
          </div>
          <ul style={styles.servicesGrid} role="list">
            {services.map((svc, i) => (
              <li key={svc.title} className="animate-in" style={{ animationDelay: `${i * 0.07}s` }}>
                <article className="card" style={styles.serviceCard}>
                  <span style={styles.serviceIcon} aria-hidden="true">{svc.icon}</span>
                  <h3 style={styles.serviceTitle}>{svc.title}</h3>
                  <p style={styles.serviceDesc}>{svc.desc}</p>
                  <Link to={svc.to} className="btn btn-ghost" style={styles.serviceCta}>
                    {svc.cta} →
                  </Link>
                </article>
              </li>
            ))}
          </ul>
        </div>
      </section>

      {/* How It Works */}
      <section style={styles.howSection} aria-labelledby="how-heading">
        <div className="container">
          <div className="section-header">
            <h2 id="how-heading" style={{ color: '#fff' }}>How It Works</h2>
            <p style={{ color: 'rgba(255,255,255,0.8)' }}>Most DMV transactions can be completed in three simple steps.</p>
          </div>
          <ol style={styles.stepsGrid} role="list">
            {[
              { step: '01', title: 'Select a Service', desc: 'Choose the service you need from our online portal — license renewal, registration, appointments, and more.' },
              { step: '02', title: 'Provide Information', desc: 'Fill out the required information and upload any necessary documents securely through our encrypted portal.' },
              { step: '03', title: 'Submit & Confirm', desc: 'Review and submit your request. You\'ll receive a confirmation email with your reference number and next steps.' },
            ].map(step => (
              <li key={step.step} className="animate-in" style={styles.step}>
                <span style={styles.stepNumber} aria-hidden="true">{step.step}</span>
                <h3 style={styles.stepTitle}>{step.title}</h3>
                <p style={styles.stepDesc}>{step.desc}</p>
              </li>
            ))}
          </ol>
        </div>
      </section>

      {/* Important Notices */}
      <section style={styles.noticesSection} aria-labelledby="notices-heading">
        <div className="container">
          <h2 id="notices-heading" style={{ marginBottom: '24px' }}>Important Notices</h2>
          <div style={styles.noticesGrid}>
            <div style={styles.noticeCard} role="article">
              <span style={styles.noticeBadge('var(--color-warning)', '#4D3200')}>Update</span>
              <h4 style={styles.noticeTitle}>REAL ID Compliance Deadline</h4>
              <p style={styles.noticeDesc}>
                Beginning May 7, 2025, a REAL ID-compliant card will be required to board domestic flights
                and access federal facilities. Visit us to upgrade your license.
              </p>
            </div>
            <div style={styles.noticeCard} role="article">
              <span style={styles.noticeBadge('var(--color-info-bg)', 'var(--color-primary)')}>Info</span>
              <h4 style={styles.noticeTitle}>Extended Online Services</h4>
              <p style={styles.noticeDesc}>
                You can now complete vehicle title transfers and duplicate license requests entirely online.
                No office visit needed.
              </p>
            </div>
            <div style={styles.noticeCard} role="article">
              <span style={styles.noticeBadge('#E8F5E9', '#14491E')}>New</span>
              <h4 style={styles.noticeTitle}>Digital Driver's License Pilot</h4>
              <p style={styles.noticeDesc}>
                Contoso County is piloting a mobile digital driver's license. Eligible residents can apply
                through the Contoso DMV app, available on iOS and Android.
              </p>
            </div>
          </div>
        </div>
      </section>
    </>
  )
}

type StyleValue = React.CSSProperties

const styles: Record<string, StyleValue | ((...args: string[]) => StyleValue)> = {
  alertBanner: {
    background: '#1A2B42',
    borderBottom: '3px solid var(--color-accent)',
    color: 'rgba(255,255,255,0.85)',
    fontSize: '13px',
    padding: '10px 0',
  },
  alertInner: {
    display: 'flex',
    alignItems: 'center',
    gap: '12px',
    flexWrap: 'wrap',
  },
  alertBadge: {
    background: 'var(--color-accent)',
    color: '#fff',
    fontWeight: 600,
    fontSize: '11px',
    padding: '2px 8px',
    borderRadius: '3px',
    letterSpacing: '0.05em',
    textTransform: 'uppercase',
    flexShrink: 0,
  },
  alertLink: {
    color: 'rgba(255,255,255,0.6)',
    fontSize: '13px',
    marginLeft: 'auto',
    textDecoration: 'underline',
  },
  hero: {
    position: 'relative',
    background: 'linear-gradient(135deg, #0F1E33 0%, #1D3557 50%, #2E4A6B 100%)',
    color: '#fff',
    padding: '80px 0 72px',
    overflow: 'hidden',
  },
  heroOverlay: {
    position: 'absolute',
    inset: 0,
    background: `url(https://images.unsplash.com/photo-1624417963912-8532660d9de8?w=1600&h=700&fit=crop) center/cover no-repeat`,
    opacity: 0.08,
    zIndex: 0,
  },
  heroContent: {
    position: 'relative',
    zIndex: 1,
    maxWidth: '680px',
  },
  heroEyebrow: {
    fontFamily: 'var(--font-body)',
    fontSize: '11px',
    fontWeight: 500,
    letterSpacing: '0.14em',
    textTransform: 'uppercase',
    color: 'rgba(255,255,255,0.5)',
    marginBottom: '16px',
  },
  heroTitle: {
    fontFamily: 'var(--font-heading)',
    fontWeight: 600,
    fontSize: 'clamp(2.2rem, 5vw, 3.5rem)',
    lineHeight: 1.15,
    color: '#fff',
    marginBottom: '20px',
  },
  heroTitleItalic: {
    fontStyle: 'italic',
    fontWeight: 300,
    color: 'rgba(255,255,255,0.8)',
  },
  heroSubtitle: {
    fontSize: '17px',
    lineHeight: 1.65,
    color: 'rgba(255,255,255,0.7)',
    marginBottom: '36px',
    maxWidth: '580px',
  },
  heroActions: {
    display: 'flex',
    gap: '16px',
    flexWrap: 'wrap',
  },
  statusBar: {
    background: 'var(--color-surface)',
    borderBottom: '1px solid var(--color-border)',
    padding: '12px 0',
  },
  statusBarInner: {
    display: 'flex',
    gap: '32px',
    flexWrap: 'wrap',
    alignItems: 'center',
  },
  statusItem: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
    fontSize: '13px',
  },
  statusDot: (color: string) => ({
    width: '8px',
    height: '8px',
    borderRadius: '50%',
    background: color,
    flexShrink: 0,
  }),
  statusLabel: {
    color: 'var(--color-text-muted)',
    fontSize: '13px',
  },
  statusValue: {
    fontWeight: 500,
    fontSize: '13px',
  },
  servicesSection: {
    padding: '80px 0',
  },
  servicesGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))',
    gap: '20px',
    listStyle: 'none',
  },
  serviceCard: {
    height: '100%',
    display: 'flex',
    flexDirection: 'column',
  },
  serviceIcon: {
    fontSize: '32px',
    marginBottom: '16px',
    display: 'block',
  },
  serviceTitle: {
    fontFamily: 'var(--font-heading)',
    fontWeight: 600,
    fontSize: '1.1rem',
    color: 'var(--color-primary)',
    marginBottom: '8px',
  },
  serviceDesc: {
    fontSize: '14px',
    color: 'var(--color-text-muted)',
    lineHeight: 1.6,
    flex: 1,
    marginBottom: '20px',
  },
  serviceCta: {
    fontSize: '14px',
    fontWeight: 500,
    color: 'var(--color-accent)',
    padding: '0',
    marginTop: 'auto',
  },
  howSection: {
    background: 'var(--color-primary)',
    padding: '80px 0',
    color: '#fff',
  },
  stepsGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))',
    gap: '40px',
    listStyle: 'none',
  },
  step: {
    position: 'relative',
  },
  stepNumber: {
    display: 'block',
    fontFamily: 'var(--font-mono)',
    fontSize: '48px',
    fontWeight: 400,
    color: 'rgba(255,255,255,0.42)',
    lineHeight: 1,
    marginBottom: '12px',
    letterSpacing: '-0.02em',
  },
  stepTitle: {
    fontFamily: 'var(--font-heading)',
    fontWeight: 600,
    fontSize: '1.2rem',
    color: '#fff',
    marginBottom: '10px',
  },
  stepDesc: {
    fontSize: '14px',
    color: 'rgba(255,255,255,0.65)',
    lineHeight: 1.65,
  },
  noticesSection: {
    padding: '64px 0 80px',
    background: 'var(--color-surface-alt)',
  },
  noticesGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))',
    gap: '20px',
  },
  noticeCard: {
    background: 'var(--color-surface)',
    border: '1px solid var(--color-border)',
    borderRadius: 'var(--radius-lg)',
    padding: '24px',
  },
  noticeBadge: (bg: string, color: string) => ({
    display: 'inline-block',
    background: bg,
    color,
    fontSize: '11px',
    fontWeight: 700,
    letterSpacing: '0.06em',
    textTransform: 'uppercase',
    padding: '3px 10px',
    borderRadius: '3px',
    marginBottom: '12px',
  }),
  noticeTitle: {
    fontFamily: 'var(--font-heading)',
    fontWeight: 600,
    color: 'var(--color-primary)',
    fontSize: '1rem',
    marginBottom: '8px',
  },
  noticeDesc: {
    fontSize: '14px',
    color: 'var(--color-text-muted)',
    lineHeight: 1.6,
  },
}

