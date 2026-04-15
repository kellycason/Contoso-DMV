import { useState } from 'react'

const mockStats = {
  pendingRegistrations: 12,
  pendingTitles: 5,
  activeTempTags: 8,
  complianceScore: 97,
}

const mockRecentSubmissions = [
  { id: 'REG-2026-0891', vin: '1HGCM82633A004352', customer: 'John Smith', type: 'New Registration', date: '2026-04-14', status: 'Pending' },
  { id: 'REG-2026-0890', vin: '5YJSA1E26HF000316', customer: 'Jane Doe', type: 'Title Transfer', date: '2026-04-13', status: 'Approved' },
  { id: 'REG-2026-0889', vin: 'WBAJB0C51JB084460', customer: 'Mike Johnson', type: 'New Registration', date: '2026-04-12', status: 'Pending' },
  { id: 'TMP-2026-0234', vin: '3VWDX7AJ5BM123456', customer: 'Sarah Wilson', type: 'Temp Tag', date: '2026-04-12', status: 'Issued' },
  { id: 'REG-2026-0888', vin: '2T1BURHE2JC123456', customer: 'Robert Lee', type: 'Registration Renewal', date: '2026-04-11', status: 'Completed' },
]

const mockAlerts = [
  { id: 1, message: '3 registrations require insurance verification', urgency: 'high' },
  { id: 2, message: '2 temporary tags expire within 48 hours', urgency: 'medium' },
  { id: 3, message: 'Annual compliance audit due in 30 days', urgency: 'low' },
]

export default function DealerDashboard() {
  const [activeTab, setActiveTab] = useState<'overview' | 'submissions' | 'compliance'>('overview')

  const statusColor = (s: string) => {
    switch (s) {
      case 'Pending': return { bg: '#fff3cd', color: '#856404' }
      case 'Approved': case 'Completed': return { bg: '#d4edda', color: '#155724' }
      case 'Issued': return { bg: '#cce5ff', color: '#004085' }
      default: return { bg: '#f0f0f0', color: '#666' }
    }
  }

  return (
    <div>
      <section style={styles.hero}>
        <div className="container">
          <div style={styles.heroContent}>
            <div>
              <span style={styles.dealerBadge}>🏢 Dealer Portal</span>
              <h1 style={styles.heroTitle}>Contoso Auto Group</h1>
              <p style={styles.heroSub}>Dealer #DLR-2024-0156 · License Active</p>
            </div>
            <div style={styles.statGrid}>
              <div style={styles.statCard}><div style={styles.statValue}>{mockStats.pendingRegistrations}</div><div style={styles.statLabel}>Pending Registrations</div></div>
              <div style={styles.statCard}><div style={styles.statValue}>{mockStats.pendingTitles}</div><div style={styles.statLabel}>Pending Titles</div></div>
              <div style={styles.statCard}><div style={styles.statValue}>{mockStats.activeTempTags}</div><div style={styles.statLabel}>Active Temp Tags</div></div>
              <div style={styles.statCard}><div style={{ ...styles.statValue, color: '#2a9d8f' }}>{mockStats.complianceScore}%</div><div style={styles.statLabel}>Compliance Score</div></div>
            </div>
          </div>
        </div>
      </section>

      {mockAlerts.length > 0 && (
        <section style={styles.alertBanner}>
          <div className="container">
            <h3 style={{ margin: '0 0 12px', fontSize: '15px' }}>⚠️ Alerts ({mockAlerts.length})</h3>
            <div style={{ display: 'flex', gap: '12px', flexWrap: 'wrap' as const }}>
              {mockAlerts.map(a => (
                <div key={a.id} style={{ ...styles.alertCard, borderLeftColor: a.urgency === 'high' ? '#E63946' : a.urgency === 'medium' ? '#E9C46A' : '#457B9D' }}>
                  {a.message}
                </div>
              ))}
            </div>
          </div>
        </section>
      )}

      <section className="container" style={{ padding: '40px 24px' }}>
        <div style={styles.tabs}>
          {(['overview', 'submissions', 'compliance'] as const).map(tab => (
            <button key={tab} onClick={() => setActiveTab(tab)}
              style={{ ...styles.tab, ...(activeTab === tab ? styles.tabActive : {}) }}>
              {tab === 'overview' ? '📊 Dashboard' : tab === 'submissions' ? '📋 Submissions' : '✅ Compliance'}
            </button>
          ))}
        </div>

        {activeTab === 'overview' && (
          <div style={styles.grid}>
            <div style={styles.card}>
              <h3 style={styles.cardTitle}>Quick Actions</h3>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                <a href="/dealer/registration" className="btn btn-primary" style={styles.quickBtn}>Submit New Registration</a>
                <a href="/dealer/elt" className="btn btn-primary" style={styles.quickBtn}>File Lien / Title</a>
                <a href="/dealer/bulk" className="btn btn-primary" style={styles.quickBtn}>Bulk Registration Upload</a>
                <a href="/dealer/temp-tags" className="btn btn-primary" style={styles.quickBtn}>Generate Temp Tag</a>
              </div>
            </div>
            <div style={{ ...styles.card, gridColumn: 'span 2' }}>
              <h3 style={styles.cardTitle}>Recent Submissions</h3>
              <table style={styles.table}>
                <thead>
                  <tr>
                    <th style={styles.th}>ID</th>
                    <th style={styles.th}>Type</th>
                    <th style={styles.th}>Customer</th>
                    <th style={styles.th}>Date</th>
                    <th style={styles.th}>Status</th>
                  </tr>
                </thead>
                <tbody>
                  {mockRecentSubmissions.slice(0, 5).map(s => {
                    const sc = statusColor(s.status)
                    return (
                      <tr key={s.id}>
                        <td style={styles.td}><code style={{ fontFamily: 'var(--font-mono)', fontSize: '12px' }}>{s.id}</code></td>
                        <td style={styles.td}>{s.type}</td>
                        <td style={styles.td}>{s.customer}</td>
                        <td style={styles.td}>{s.date}</td>
                        <td style={styles.td}><span style={{ ...styles.statusBadge, background: sc.bg, color: sc.color }}>{s.status}</span></td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {activeTab === 'submissions' && (
          <div>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
              <h2 style={{ margin: 0 }}>All Submissions</h2>
              <div style={{ display: 'flex', gap: '8px' }}>
                <a href="/dealer/registration" className="btn btn-primary">+ New Registration</a>
                <a href="/dealer/bulk" className="btn" style={{ border: '1px solid #ccc' }}>📁 Bulk Upload</a>
              </div>
            </div>
            <table style={styles.table}>
              <thead>
                <tr>
                  <th style={styles.th}>ID</th>
                  <th style={styles.th}>VIN</th>
                  <th style={styles.th}>Type</th>
                  <th style={styles.th}>Customer</th>
                  <th style={styles.th}>Date</th>
                  <th style={styles.th}>Status</th>
                </tr>
              </thead>
              <tbody>
                {mockRecentSubmissions.map(s => {
                  const sc = statusColor(s.status)
                  return (
                    <tr key={s.id}>
                      <td style={styles.td}><code style={{ fontFamily: 'var(--font-mono)', fontSize: '12px' }}>{s.id}</code></td>
                      <td style={styles.td}><code style={{ fontFamily: 'var(--font-mono)', fontSize: '11px' }}>{s.vin}</code></td>
                      <td style={styles.td}>{s.type}</td>
                      <td style={styles.td}>{s.customer}</td>
                      <td style={styles.td}>{s.date}</td>
                      <td style={styles.td}><span style={{ ...styles.statusBadge, background: sc.bg, color: sc.color }}>{s.status}</span></td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}

        {activeTab === 'compliance' && (
          <div style={styles.grid}>
            <div style={styles.card}>
              <h3 style={styles.cardTitle}>Compliance Score</h3>
              <div style={styles.scoreCircle}>
                <span style={{ fontSize: '42px', fontWeight: 700, color: '#2a9d8f' }}>{mockStats.complianceScore}%</span>
              </div>
              <p style={{ textAlign: 'center', color: '#666', fontSize: '14px' }}>Your dealership is in good standing.</p>
            </div>
            <div style={{ ...styles.card, gridColumn: 'span 2' }}>
              <h3 style={styles.cardTitle}>Compliance Checklist</h3>
              {[
                { item: 'Business License Current', status: true },
                { item: 'Insurance Bond Active', status: true },
                { item: 'VIN Verification Records Complete', status: true },
                { item: 'Temporary Tag Audit (Quarterly)', status: true },
                { item: 'Annual Compliance Audit', status: false },
                { item: 'Staff Certification Current', status: true },
              ].map(c => (
                <div key={c.item} style={{ display: 'flex', justifyContent: 'space-between', padding: '12px 0', borderBottom: '1px solid #f0f0f0' }}>
                  <span>{c.item}</span>
                  <span style={{ ...styles.statusBadge, background: c.status ? '#d4edda' : '#fff3cd', color: c.status ? '#155724' : '#856404' }}>
                    {c.status ? '✅ Complete' : '⏳ Pending'}
                  </span>
                </div>
              ))}
            </div>
          </div>
        )}
      </section>
    </div>
  )
}

const styles: Record<string, React.CSSProperties> = {
  hero: { background: 'linear-gradient(135deg, #264653 0%, #1D3557 100%)', color: '#fff', padding: '48px 0 40px' },
  heroContent: { display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: '32px', flexWrap: 'wrap' as const },
  heroTitle: { fontSize: '32px', fontFamily: 'var(--font-heading)', margin: '0 0 4px' },
  heroSub: { fontSize: '14px', opacity: 0.7, margin: 0 },
  dealerBadge: { display: 'inline-block', background: 'rgba(255,255,255,0.15)', padding: '4px 12px', borderRadius: '4px', fontSize: '12px', marginBottom: '8px', letterSpacing: '0.05em' },
  statGrid: { display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: '12px' },
  statCard: { background: 'rgba(255,255,255,0.1)', borderRadius: '8px', padding: '16px 20px', textAlign: 'center' as const, backdropFilter: 'blur(8px)', border: '1px solid rgba(255,255,255,0.1)', minWidth: '130px' },
  statValue: { fontSize: '28px', fontWeight: 700, fontFamily: 'var(--font-mono)' },
  statLabel: { fontSize: '11px', opacity: 0.7, marginTop: '4px', textTransform: 'uppercase' as const, letterSpacing: '0.05em' },
  alertBanner: { background: '#FFF9E6', borderBottom: '1px solid #E9C46A', padding: '20px 0' },
  alertCard: { background: '#fff', borderRadius: '8px', padding: '12px 16px', borderLeft: '4px solid', fontSize: '14px', flex: '1 1 280px', boxShadow: '0 1px 4px rgba(0,0,0,0.06)' },
  tabs: { display: 'flex', gap: '4px', borderBottom: '2px solid #eee', marginBottom: '32px' },
  tab: { padding: '12px 20px', border: 'none', background: 'none', cursor: 'pointer', fontSize: '14px', fontWeight: 500, color: '#666', borderBottom: '2px solid transparent', marginBottom: '-2px', transition: 'all 0.2s' },
  tabActive: { color: '#1D3557', borderBottomColor: '#1D3557', fontWeight: 600 },
  grid: { display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '24px' },
  card: { background: '#fff', borderRadius: '12px', padding: '24px', border: '1px solid #e8e8e8', boxShadow: '0 2px 8px rgba(0,0,0,0.04)' },
  cardTitle: { fontSize: '16px', fontWeight: 600, color: '#1D3557', margin: '0 0 16px', paddingBottom: '12px', borderBottom: '1px solid #eee' },
  quickBtn: { fontSize: '13px', padding: '10px 16px', textAlign: 'center' as const },
  table: { width: '100%', borderCollapse: 'collapse' as const, background: '#fff', borderRadius: '8px', overflow: 'hidden', boxShadow: '0 1px 4px rgba(0,0,0,0.06)' },
  th: { textAlign: 'left' as const, padding: '14px 16px', background: '#f8f9fa', fontWeight: 600, fontSize: '13px', color: '#1D3557', borderBottom: '2px solid #e8e8e8' },
  td: { padding: '12px 16px', borderBottom: '1px solid #f0f0f0', fontSize: '14px' },
  statusBadge: { display: 'inline-block', padding: '2px 10px', borderRadius: '12px', fontSize: '11px', fontWeight: 600 },
  scoreCircle: { display: 'flex', alignItems: 'center', justifyContent: 'center', width: '140px', height: '140px', borderRadius: '50%', border: '6px solid #2a9d8f', margin: '20px auto' },
}
