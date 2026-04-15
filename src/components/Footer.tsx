import { Link } from 'react-router-dom'

const quickLinks = [
  { to: '/license-renewal',      label: 'Renew License' },
  { to: '/vehicle-registration', label: 'Register Vehicle' },
  { to: '/appointments',         label: 'Schedule Appointment' },
  { to: '/documents',            label: 'Upload Documents' },
  { to: '/faq',                  label: 'FAQ' },
]

export default function Footer() {
  return (
    <footer style={styles.footer} role="contentinfo">
      <div style={styles.top}>
        <div className="container" style={styles.topInner}>
          <div style={styles.brandCol}>
            <div style={styles.brandName}>Contoso DMV</div>
            <p style={styles.brandDesc}>
              Official Department of Motor Vehicles portal for Contoso County citizens.
              Providing fast, secure, and accessible government services online.
            </p>
            <p style={styles.adaNotice}>
              This site is committed to accessibility under the Americans with Disabilities Act (ADA).
              For assistance, call <a href="tel:+15551234567" style={styles.phoneLink}>1-555-123-4567</a>.
            </p>
          </div>

          <div style={styles.linksCol}>
            <h3 style={styles.colHeading}>Services</h3>
            <ul style={styles.linkList} role="list">
              {quickLinks.map(l => (
                <li key={l.to}>
                  <Link to={l.to} style={styles.link}>{l.label}</Link>
                </li>
              ))}
            </ul>
          </div>

          <div style={styles.linksCol}>
            <h3 style={styles.colHeading}>Contact</h3>
            <ul style={styles.contactList} role="list">
              <li><span style={styles.contactLabel}>Phone</span><br /><a href="tel:+15551234567" style={styles.link}>1-555-123-4567</a></li>
              <li><span style={styles.contactLabel}>Email</span><br /><a href="mailto:info@contosodmv.gov" style={styles.link}>info@contosodmv.gov</a></li>
              <li><span style={styles.contactLabel}>Hours</span><br /><span style={{ color: 'rgba(255,255,255,0.6)', fontSize: '13px' }}>Mon–Fri 8:00 AM – 5:00 PM</span></li>
              <li><span style={styles.contactLabel}>Address</span><br /><span style={{ color: 'rgba(255,255,255,0.6)', fontSize: '13px' }}>123 Civic Center Drive<br />Contoso, CA 90210</span></li>
            </ul>
          </div>
        </div>
      </div>

      <div style={styles.bottom}>
        <div className="container" style={styles.bottomInner}>
          <span>© {new Date().getFullYear()} Contoso Department of Motor Vehicles. All rights reserved.</span>
          <span style={styles.disclaimer}>
            An official government website.{' '}
            <Link to="/faq" style={{ color: 'rgba(255,255,255,0.75)', textDecoration: 'underline' }}>Privacy Policy</Link>
            {' · '}
            <Link to="/faq" style={{ color: 'rgba(255,255,255,0.75)', textDecoration: 'underline' }}>Accessibility</Link>
          </span>
        </div>
      </div>
    </footer>
  )
}

const styles: Record<string, React.CSSProperties> = {
  footer: {
    background: 'var(--color-primary)',
    color: 'rgba(255,255,255,0.75)',
    marginTop: 'auto',
  },
  top: {
    padding: '56px 0 48px',
    borderBottom: '1px solid rgba(255,255,255,0.08)',
  },
  topInner: {
    display: 'grid',
    gridTemplateColumns: '2fr 1fr 1fr',
    gap: '48px',
    alignItems: 'start',
  },
  brandCol: {},
  brandName: {
    fontFamily: 'var(--font-heading)',
    fontWeight: 600,
    fontSize: '20px',
    color: '#fff',
    marginBottom: '12px',
  },
  brandDesc: {
    fontSize: '14px',
    lineHeight: 1.6,
    marginBottom: '12px',
    color: 'rgba(255,255,255,0.6)',
  },
  adaNotice: {
    fontSize: '12px',
    color: 'rgba(255,255,255,0.65)',
    lineHeight: 1.5,
  },
  phoneLink: {
    color: 'rgba(255,255,255,0.85)',
    textDecoration: 'underline',
  },
  linksCol: {},
  colHeading: {
    fontFamily: 'var(--font-body)',
    fontWeight: 600,
    fontSize: '11px',
    letterSpacing: '0.1em',
    textTransform: 'uppercase',
    color: 'rgba(255,255,255,0.75)',
    marginBottom: '16px',
  },
  linkList: {
    listStyle: 'none',
    display: 'flex',
    flexDirection: 'column',
    gap: '8px',
  },
  contactList: {
    listStyle: 'none',
    display: 'flex',
    flexDirection: 'column',
    gap: '12px',
  },
  contactLabel: {
    fontSize: '11px',
    fontWeight: 600,
    letterSpacing: '0.06em',
    textTransform: 'uppercase',
    color: 'rgba(255,255,255,0.75)',
    fontFamily: 'var(--font-body)',
  },
  link: {
    color: 'rgba(255,255,255,0.65)',
    textDecoration: 'none',
    fontSize: '14px',
    transition: 'color 0.15s',
  },
  bottom: {
    padding: '16px 0',
    background: '#0F1E33',
  },
  bottomInner: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    fontSize: '12px',
    color: 'rgba(255,255,255,0.65)',
    gap: '16px',
    flexWrap: 'wrap',
  },
  disclaimer: {
    color: 'rgba(255,255,255,0.65)',
    fontSize: '12px',
  },
}
