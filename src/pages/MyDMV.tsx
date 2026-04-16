import { useState } from 'react'
import { Link } from 'react-router-dom'
import { useAuth } from '../hooks/useAuth'
import { useMyDMVData } from '../hooks/useMyDMVData'

export default function MyDMV() {
  const { isAuthenticated, userName, userId } = useAuth()
  const { loading, error, citizen, license, vehicles, transactions, actions } = useMyDMVData(userId)
  const [activeTab, setActiveTab] = useState<'overview' | 'vehicles' | 'history'>('overview')
  const firstName = userName?.split(' ')[0] ?? 'there'

  if (!isAuthenticated) {
    return (
      <div style={{ textAlign: 'center', padding: '80px 24px' }}>
        <div style={{ fontSize: '48px', marginBottom: '16px' }}>🪪</div>
        <h2 style={{ color: '#1D3557', marginBottom: '12px' }}>Sign In Required</h2>
        <p style={{ color: '#666', marginBottom: '24px' }}>Please sign in to access your DMV dashboard.</p>
        <a href="/Account/Login/ExternalLogin" className="btn btn-primary" style={{ display: 'inline-block' }}>Sign In</a>
      </div>
    )
  }

  if (loading) {
    return (
      <div style={{ textAlign: 'center', padding: '80px 24px' }}>
        <div style={{ fontSize: '32px', marginBottom: '16px', animation: 'spin 1s linear infinite' }}>⏳</div>
        <p style={{ color: '#666', fontSize: '16px' }}>Loading your dashboard...</p>
      </div>
    )
  }

  if (error) {
    const diag = (window as any).__DMV_DIAG__
    return (
      <div style={{ textAlign: 'center', padding: '80px 24px' }}>
        <div style={{ fontSize: '32px', marginBottom: '16px' }}>⚠️</div>
        <h2 style={{ color: '#1D3557', marginBottom: '12px' }}>Unable to Load Dashboard</h2>
        <p style={{ color: '#666' }}>{error}</p>
        {diag && <pre style={{ marginTop: '24px', fontSize: '12px', color: '#999', textAlign: 'left', maxWidth: '600px', margin: '24px auto 0' }}>{JSON.stringify(diag, null, 2)}</pre>}
      </div>
    )
  }

  return (
    <div>
      <section style={styles.hero}>
        <div className="container">
          <div style={styles.heroContent}>
            <div>
              <h1 style={styles.heroTitle}>Welcome back, {firstName}</h1>
              <p style={styles.heroSub}>Manage your licenses, vehicles, and DMV services from your personal dashboard.</p>
            </div>
            {license && (
              <div style={styles.licenseCard}>
                <div style={styles.licenseHeader}>
                  <span style={styles.licenseIcon}>🪪</span>
                  <span style={styles.licenseLabel}>Driver License</span>
                </div>
                <div style={styles.licenseNumber}>{license.licenseNumber}</div>
                <div style={styles.licenseRow}>
                  <span>Status: <strong style={{ color: '#2a9d8f' }}>{license.status}</strong></span>
                  <span>Expires: {license.expirationDate}</span>
                </div>
                {license.realIdCompliant && <span style={styles.realIdBadge}>★ REAL ID</span>}
              </div>
            )}
          </div>
        </div>
      </section>

      {actions.length > 0 && (
        <section style={styles.alertBanner}>
          <div className="container">
            <h3 style={{ margin: '0 0 12px', fontSize: '15px' }}>⚠️ Action Required ({actions.length})</h3>
            <div style={styles.alertGrid}>
              {actions.map(a => (
                <div key={a.id} style={{ ...styles.alertCard, borderLeftColor: a.urgency === 'high' ? '#E63946' : '#E9C46A' }}>
                  <strong>{a.type}</strong>
                  <span style={{ fontSize: '13px', color: '#555' }}>{a.detail}</span>
                  <span style={{ fontSize: '12px', color: a.urgency === 'high' ? '#E63946' : '#888' }}>Due: {a.due}</span>
                </div>
              ))}
            </div>
          </div>
        </section>
      )}

      <section className="container" style={{ padding: '40px 24px' }}>
        <div style={styles.tabs}>
          {(['overview', 'vehicles', 'history'] as const).map(tab => (
            <button key={tab} onClick={() => setActiveTab(tab)}
              style={{ ...styles.tab, ...(activeTab === tab ? styles.tabActive : {}) }}>
              {tab === 'overview' ? '📊 Overview' : tab === 'vehicles' ? '🚗 My Vehicles' : '📜 Transaction History'}
            </button>
          ))}
        </div>

        {activeTab === 'overview' && (
          <div style={styles.grid}>
            <div style={styles.card}>
              <h3 style={styles.cardTitle}>Quick Services</h3>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                <Link to="/license-renewal" className="btn btn-primary" style={styles.quickBtn}>Renew License</Link>
                <Link to="/vehicle-registration" className="btn btn-primary" style={styles.quickBtn}>Renew Registration</Link>
                <Link to="/documents" className="btn btn-primary" style={styles.quickBtn}>Upload Documents</Link>
                <Link to="/appointments" className="btn btn-primary" style={styles.quickBtn}>Book Appointment</Link>
                <Link to="/real-id" className="btn btn-primary" style={styles.quickBtn}>REAL ID Check</Link>
              </div>
            </div>
            <div style={styles.card}>
              <h3 style={styles.cardTitle}>License Summary</h3>
              {license ? (
                <>
                  <div style={styles.infoRow}><span>Name</span><strong>{citizen?.fullName}</strong></div>
                  <div style={styles.infoRow}><span>License #</span><strong>{license.licenseNumber}</strong></div>
                  <div style={styles.infoRow}><span>Status</span><strong style={{ color: '#2a9d8f' }}>{license.status}</strong></div>
                  <div style={styles.infoRow}><span>Expires</span><strong>{license.expirationDate}</strong></div>
                  <div style={styles.infoRow}><span>REAL ID</span><strong>{license.realIdCompliant ? '✅ Yes' : '❌ No'}</strong></div>
                  <div style={styles.infoRow}><span>Address</span><strong style={{ fontSize: '12px' }}>{citizen?.address}</strong></div>
                </>
              ) : (
                <p style={{ color: '#888', fontSize: '14px' }}>No license on file.</p>
              )}
            </div>
            <div style={styles.card}>
              <h3 style={styles.cardTitle}>Registered Vehicles</h3>
              {vehicles.length > 0 ? vehicles.map(v => (
                <div key={v.id} style={styles.vehicleMini}>
                  <div><strong>{v.year} {v.make} {v.model}</strong></div>
                  <div style={{ fontSize: '12px', color: '#666' }}>Plate: {v.plateNumber} · Reg: {v.registration?.expirationDate ?? 'N/A'}</div>
                  <span style={{ ...styles.statusBadge, background: v.registration?.status === 'Active' ? '#d4edda' : '#fff3cd', color: v.registration?.status === 'Active' ? '#155724' : '#856404' }}>
                    {v.registration?.status ?? 'Unknown'}
                  </span>
                </div>
              )) : (
                <p style={{ color: '#888', fontSize: '14px' }}>No vehicles registered.</p>
              )}
            </div>
          </div>
        )}

        {activeTab === 'vehicles' && (
          <div>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
              <h2 style={{ margin: 0 }}>Virtual Garage</h2>
              <Link to="/vehicle-registration" className="btn btn-primary">+ Add Vehicle</Link>
            </div>
            {vehicles.length > 0 ? (
              <div style={styles.vehicleGrid}>
                {vehicles.map(v => (
                  <div key={v.id} style={styles.vehicleCard}>
                    <div style={styles.vehicleCardHeader}>
                      <span style={{ fontSize: '28px' }}>🚗</span>
                      <div>
                        <h3 style={{ margin: 0, fontSize: '18px' }}>{v.year} {v.make} {v.model}</h3>
                        <span style={{ fontSize: '13px', color: '#888' }}>VIN: {v.vin}</span>
                      </div>
                    </div>
                    <div style={styles.vehicleDetails}>
                      <div style={styles.infoRow}><span>Plate</span><strong>{v.plateNumber}</strong></div>
                      <div style={styles.infoRow}><span>Registration</span><strong style={{ color: v.registration?.status === 'Active' ? '#2a9d8f' : '#E9C46A' }}>{v.registration?.status ?? 'Unknown'}</strong></div>
                      <div style={styles.infoRow}><span>Reg. Expires</span><strong>{v.registration?.expirationDate ?? 'N/A'}</strong></div>
                      <div style={styles.infoRow}><span>Insurance</span><strong>{v.insuranceStatus === 'Verified' ? '✅ Verified' : '❌ ' + (v.insuranceStatus || 'Unverified')}</strong></div>
                    </div>
                    <div style={{ display: 'flex', gap: '8px', marginTop: '16px' }}>
                      <Link to="/vehicle-registration" className="btn btn-primary" style={{ flex: 1, textAlign: 'center', fontSize: '13px' }}>Renew Registration</Link>
                      <Link to="/documents" className="btn" style={{ flex: 1, textAlign: 'center', fontSize: '13px', border: '1px solid #ccc' }}>Upload Docs</Link>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <p style={{ color: '#888', textAlign: 'center', padding: '40px' }}>No vehicles found. Add your first vehicle to get started.</p>
            )}
          </div>
        )}

        {activeTab === 'history' && (
          <div>
            <h2 style={{ marginBottom: '24px' }}>Transaction History</h2>
            {transactions.length > 0 ? (
              <table style={styles.table}>
                <thead>
                  <tr>
                    <th style={styles.th}>Transaction ID</th>
                    <th style={styles.th}>Type</th>
                    <th style={styles.th}>Date</th>
                    <th style={styles.th}>Status</th>
                    <th style={styles.th}>Amount</th>
                  </tr>
                </thead>
                <tbody>
                  {transactions.map(t => (
                    <tr key={t.id}>
                      <td style={styles.td}><code style={{ fontFamily: 'var(--font-mono)' }}>{t.transactionId}</code></td>
                      <td style={styles.td}>{t.type}</td>
                      <td style={styles.td}>{t.date}</td>
                      <td style={styles.td}><span style={styles.statusBadge}>{t.status}</span></td>
                      <td style={styles.td}>{t.amount}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            ) : (
              <p style={{ color: '#888', textAlign: 'center', padding: '40px' }}>No transactions yet.</p>
            )}
          </div>
        )}
      </section>
    </div>
  )
}

const styles: Record<string, React.CSSProperties> = {
  hero: { background: 'linear-gradient(135deg, #1D3557 0%, #264674 100%)', color: '#fff', padding: '48px 0 40px' },
  heroContent: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '32px', flexWrap: 'wrap' },
  heroTitle: { fontSize: '32px', fontFamily: 'var(--font-heading)', margin: '0 0 8px' },
  heroSub: { fontSize: '16px', opacity: 0.85, margin: 0 },
  licenseCard: { background: 'rgba(255,255,255,0.1)', borderRadius: '12px', padding: '20px 24px', minWidth: '280px', backdropFilter: 'blur(8px)', border: '1px solid rgba(255,255,255,0.15)' },
  licenseHeader: { display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '8px' },
  licenseIcon: { fontSize: '20px' },
  licenseLabel: { fontSize: '12px', textTransform: 'uppercase' as const, letterSpacing: '0.08em', opacity: 0.8 },
  licenseNumber: { fontSize: '26px', fontFamily: 'var(--font-mono)', fontWeight: 600, marginBottom: '8px' },
  licenseRow: { display: 'flex', justifyContent: 'space-between', fontSize: '13px', opacity: 0.9 },
  realIdBadge: { display: 'inline-block', marginTop: '8px', background: '#E63946', color: '#fff', padding: '2px 10px', borderRadius: '4px', fontSize: '11px', fontWeight: 600, letterSpacing: '0.05em' },
  alertBanner: { background: '#FFF9E6', borderBottom: '1px solid #E9C46A', padding: '20px 0' },
  alertGrid: { display: 'flex', gap: '12px', flexWrap: 'wrap' as const },
  alertCard: { background: '#fff', borderRadius: '8px', padding: '12px 16px', borderLeft: '4px solid', display: 'flex', flexDirection: 'column' as const, gap: '4px', flex: '1 1 240px', boxShadow: '0 1px 4px rgba(0,0,0,0.06)' },
  tabs: { display: 'flex', gap: '4px', borderBottom: '2px solid #eee', marginBottom: '32px' },
  tab: { padding: '12px 20px', border: 'none', background: 'none', cursor: 'pointer', fontSize: '14px', fontWeight: 500, color: '#666', borderBottom: '2px solid transparent', marginBottom: '-2px', transition: 'all 0.2s' },
  tabActive: { color: '#1D3557', borderBottomColor: '#1D3557', fontWeight: 600 },
  grid: { display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: '24px' },
  card: { background: '#fff', borderRadius: '12px', padding: '24px', border: '1px solid #e8e8e8', boxShadow: '0 2px 8px rgba(0,0,0,0.04)' },
  cardTitle: { fontSize: '16px', fontWeight: 600, color: '#1D3557', margin: '0 0 16px', paddingBottom: '12px', borderBottom: '1px solid #eee' },
  quickBtn: { fontSize: '13px', padding: '10px 16px', textAlign: 'center' as const },
  infoRow: { display: 'flex', justifyContent: 'space-between', padding: '8px 0', borderBottom: '1px solid #f0f0f0', fontSize: '14px', color: '#555' },
  vehicleMini: { padding: '12px 0', borderBottom: '1px solid #f0f0f0' },
  statusBadge: { display: 'inline-block', padding: '2px 10px', borderRadius: '12px', fontSize: '11px', fontWeight: 600, background: '#d4edda', color: '#155724' },
  vehicleGrid: { display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(340px, 1fr))', gap: '24px' },
  vehicleCard: { background: '#fff', borderRadius: '12px', padding: '24px', border: '1px solid #e8e8e8', boxShadow: '0 2px 8px rgba(0,0,0,0.04)' },
  vehicleCardHeader: { display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '16px', paddingBottom: '16px', borderBottom: '1px solid #f0f0f0' },
  vehicleDetails: {},
  table: { width: '100%', borderCollapse: 'collapse' as const, background: '#fff', borderRadius: '8px', overflow: 'hidden', boxShadow: '0 1px 4px rgba(0,0,0,0.06)' },
  th: { textAlign: 'left' as const, padding: '14px 16px', background: '#f8f9fa', fontWeight: 600, fontSize: '13px', color: '#1D3557', borderBottom: '2px solid #e8e8e8' },
  td: { padding: '12px 16px', borderBottom: '1px solid #f0f0f0', fontSize: '14px' },
}
