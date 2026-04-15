import { useState } from 'react'
import { NavLink, Link } from 'react-router-dom'

const navLinks = [
  { to: '/my-dmv',                label: 'MyDMV' },
  { to: '/license-renewal',       label: 'License Renewal' },
  { to: '/vehicle-registration',  label: 'Vehicle Registration' },
  { to: '/real-id',               label: 'REAL ID' },
  { to: '/appointments',          label: 'Appointments' },
  { to: '/documents',             label: 'Documents' },
  { to: '/dealer',                label: 'Dealer Portal' },
  { to: '/faq',                   label: 'FAQ' },
]

export default function Header() {
  const [menuOpen, setMenuOpen] = useState(false)

  return (
    <header style={styles.header}>
      <div style={styles.topBar}>
        <div className="container" style={styles.topBarInner}>
          <span>Official Contoso DMV Government Portal</span>
          <span>Mon–Fri 8:00 AM – 5:00 PM</span>
        </div>
      </div>

      <nav style={styles.nav} aria-label="Main navigation">
        <div className="container" style={styles.navInner}>
          <Link to="/" style={styles.brand} aria-label="Contoso DMV Home">
            <svg style={styles.seal} viewBox="0 0 40 40" fill="none" aria-hidden="true">
              <circle cx="20" cy="20" r="19" stroke="#E63946" strokeWidth="2" fill="#1D3557" />
              <circle cx="20" cy="20" r="14" stroke="rgba(255,255,255,0.25)" strokeWidth="1" fill="none" />
              <polygon points="20,8 22.5,16.5 31,16.5 24,21.5 26.5,30 20,25 13.5,30 16,21.5 9,16.5 17.5,16.5"
                fill="rgba(255,255,255,0.9)" />
            </svg>
            <div style={styles.brandText}>
              <span style={styles.brandName}>Contoso DMV</span>
              <span style={styles.brandSub}>Department of Motor Vehicles</span>
            </div>
          </Link>

          <ul style={{ ...styles.navList, ...(menuOpen ? styles.navListOpen : {}) }} role="list">
            {navLinks.map(link => (
              <li key={link.to}>
                <NavLink
                  to={link.to}
                  style={({ isActive }) => ({
                    ...styles.navLink,
                    ...(isActive ? styles.navLinkActive : {}),
                  })}
                  onClick={() => setMenuOpen(false)}
                >
                  {link.label}
                </NavLink>
              </li>
            ))}
          </ul>

          <div style={styles.navActions}>
            <Link to="/appointments" className="btn btn-primary" style={{ fontSize: '13px', padding: '8px 18px' }}>
              Schedule Appointment
            </Link>
            <button
              style={styles.menuBtn}
              onClick={() => setMenuOpen(v => !v)}
              aria-expanded={menuOpen}
              aria-label="Toggle navigation menu"
            >
              <span style={styles.menuIcon}>{menuOpen ? '✕' : '☰'}</span>
            </button>
          </div>
        </div>
      </nav>
    </header>
  )
}

const styles: Record<string, React.CSSProperties> = {
  header: {
    position: 'sticky',
    top: 0,
    zIndex: 100,
    boxShadow: '0 2px 12px rgba(29,53,87,0.12)',
  },
  topBar: {
    background: '#152844',
    color: 'rgba(255,255,255,0.85)',
    fontSize: '11px',
    fontFamily: 'var(--font-body)',
    letterSpacing: '0.04em',
    padding: '6px 0',
  },
  topBarInner: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  nav: {
    background: 'var(--color-primary)',
    padding: '0',
  },
  navInner: {
    display: 'flex',
    alignItems: 'center',
    gap: '16px',
    height: '68px',
  },
  brand: {
    display: 'flex',
    alignItems: 'center',
    gap: '12px',
    textDecoration: 'none',
    flexShrink: 0,
  },
  seal: {
    width: '40px',
    height: '40px',
    flexShrink: 0,
  },
  brandText: {
    display: 'flex',
    flexDirection: 'column' as const,
    gap: '1px',
  },
  brandName: {
    color: '#fff',
    fontFamily: 'var(--font-heading)',
    fontWeight: 600,
    fontSize: '17px',
    lineHeight: 1.2,
    letterSpacing: '-0.01em',
  },
  brandSub: {
    color: 'rgba(255,255,255,0.55)',
    fontSize: '10px',
    fontFamily: 'var(--font-body)',
    letterSpacing: '0.06em',
    textTransform: 'uppercase',
  },
  navList: {
    display: 'flex',
    alignItems: 'center',
    gap: '0px',
    listStyle: 'none',
    margin: '0 auto',
    padding: 0,
    flexWrap: 'nowrap' as const,
    whiteSpace: 'nowrap' as const,
  },
  navListOpen: {},
  navLink: {
    display: 'block',
    padding: '8px 10px',
    color: 'rgba(255,255,255,0.75)',
    fontFamily: 'var(--font-body)',
    fontSize: '12.5px',
    fontWeight: 400,
    letterSpacing: '0.01em',
    borderRadius: '4px',
    textDecoration: 'none',
    transition: 'color 0.15s, background 0.15s',
  },
  navLinkActive: {
    color: '#fff',
    background: 'rgba(255,255,255,0.1)',
  },
  navActions: {
    display: 'flex',
    alignItems: 'center',
    gap: '12px',
    flexShrink: 0,
  },
  menuBtn: {
    display: 'none',
    background: 'transparent',
    border: 'none',
    cursor: 'pointer',
    padding: '6px',
    borderRadius: '4px',
  },
  menuIcon: {
    color: '#fff',
    fontSize: '18px',
  },
}
