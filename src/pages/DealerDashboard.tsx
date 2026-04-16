import { useEffect, useState } from 'react'
import { useAuth } from '../hooks/useAuth'
import { dvQuery, fmt } from '../hooks/useDataverse'

export default function DealerDashboard() {
  const { isAuthenticated, userName, userId } = useAuth()
  const [activeTab, setActiveTab] = useState<'overview' | 'submissions' | 'compliance'>('overview')
  const [loading, setLoading] = useState(true)
  const [transactions, setTransactions] = useState<Record<string, any>[]>([])
  const [registrations, setRegistrations] = useState<Record<string, any>[]>([])
  const [tempTags, setTempTags] = useState<Record<string, any>[]>([])
  const [titles, setTitles] = useState<Record<string, any>[]>([])

  useEffect(() => {
    if (!isAuthenticated || !userId) { setLoading(false); return }
    Promise.all([
      dvQuery('dmv_transactionlogs', `$select=dmv_transactionid,dmv_transactiontype,dmv_transactiondate,dmv_status,dmv_amount,dmv_channel&$orderby=dmv_transactiondate desc&$top=50`).catch(() => []),
      dvQuery('dmv_vehicleregistrations', `$select=dmv_registrationid,dmv_regstatus,dmv_regtype,dmv_expirationdate,dmv_totaldue,dmv_paymentstatus&$orderby=dmv_expirationdate desc&$top=50`).catch(() => []),
      dvQuery('dmv_temporarytags', `$select=dmv_tagnumber,dmv_buyername,dmv_tagstatus,dmv_issuedate,dmv_expirationdate&$orderby=dmv_issuedate desc&$top=50`).catch(() => []),
      dvQuery('dmv_vehicletitles', `$select=dmv_titlenumber,dmv_titlestatus,dmv_titletype,dmv_issuedate,dmv_processingstatus&$orderby=dmv_issuedate desc&$top=50`).catch(() => []),
    ]).then(([txn, reg, tags, ttl]) => {
      setTransactions(txn)
      setRegistrations(reg)
      setTempTags(tags)
      setTitles(ttl)
    }).finally(() => setLoading(false))
  }, [isAuthenticated, userId])

  const pendingRegs = registrations.filter(r => fmt(r, 'dmv_regstatus').includes('Pending')).length
  const pendingTitles = titles.filter(t => fmt(t, 'dmv_processingstatus').includes('Pending')).length
  const activeTagCount = tempTags.filter(t => fmt(t, 'dmv_tagstatus') === 'Active').length
  const totalRecords = registrations.length + titles.length + tempTags.length
  const completedRecords = registrations.filter(r => fmt(r, 'dmv_regstatus') === 'Active').length +
    titles.filter(t => fmt(t, 'dmv_titlestatus') === 'Active').length
  const complianceScore = totalRecords > 0 ? Math.round((completedRecords / totalRecords) * 100) : 100

  // Build unified submissions list from transactions
  const recentSubmissions = transactions.slice(0, 10).map(t => ({
    id: t.dmv_transactionid,
    type: fmt(t, 'dmv_transactiontype'),
    date: fmt(t, 'dmv_transactiondate'),
    status: fmt(t, 'dmv_status'),
    amount: t.dmv_amount,
    channel: fmt(t, 'dmv_channel'),
  }))

  // Build alerts from real data
  const alerts: { id: number; message: string; urgency: string }[] = []
  const expiringTags = tempTags.filter(t => {
    const exp = t.dmv_expirationdate
    if (!exp) return false
    const d = new Date(exp).getTime() - Date.now()
    return d > 0 && d < 48 * 60 * 60 * 1000
  })
  if (pendingRegs > 0) alerts.push({ id: 1, message: `${pendingRegs} registration(s) pending review`, urgency: 'medium' })
  if (expiringTags.length > 0) alerts.push({ id: 2, message: `${expiringTags.length} temporary tag(s) expire within 48 hours`, urgency: 'high' })
  if (pendingTitles > 0) alerts.push({ id: 3, message: `${pendingTitles} title(s) pending processing`, urgency: 'low' })

  if (!isAuthenticated) {
    return (
      <div style={{ textAlign: 'center', padding: '80px 24px' }}>
        <div style={{ fontSize: '48px', marginBottom: '16px' }}>🏢</div>
        <h2 style={{ color: '#1D3557', marginBottom: '12px' }}>Sign In Required</h2>
        <p style={{ color: '#666', marginBottom: '24px' }}>Please sign in to access the Dealer Portal.</p>
        <a href="/Account/Login/ExternalLogin" className="btn btn-primary">Sign In</a>
      </div>
    )
  }

  if (loading) {
    return (
      <div style={{ textAlign: 'center', padding: '80px 24px' }}>
        <div style={{ fontSize: '32px', marginBottom: '16px' }}>⏳</div>
        <p style={{ color: '#666' }}>Loading dealer dashboard...</p>
      </div>
    )
  }

  const statusColor = (s: string) => {
    if (s === 'Pending' || s === 'Initiated') return { bg: '#fff3cd', color: '#856404' }
    if (s === 'Approved' || s === 'Completed' || s === 'Active') return { bg: '#d4edda', color: '#155724' }
    if (s === 'Issued' || s === 'Submitted') return { bg: '#cce5ff', color: '#004085' }
    if (s === 'Failed' || s === 'Reversed') return { bg: '#f8d7da', color: '#721c24' }
    return { bg: '#f0f0f0', color: '#666' }
  }

  return (
    <div>
      <section style={styles.hero}>
        <div className="container">
          <div style={styles.heroContent}>
            <div>
              <span style={styles.dealerBadge}>🏢 Dealer Portal</span>
              <h1 style={styles.heroTitle}>{userName || 'Dealer Dashboard'}</h1>
              <p style={styles.heroSub}>Dealer Operations · {transactions.length} total transactions</p>
            </div>
            <div style={styles.statGrid}>
              <div style={styles.statCard}><div style={styles.statValue}>{pendingRegs}</div><div style={styles.statLabel}>Pending Registrations</div></div>
              <div style={styles.statCard}><div style={styles.statValue}>{pendingTitles}</div><div style={styles.statLabel}>Pending Titles</div></div>
              <div style={styles.statCard}><div style={styles.statValue}>{activeTagCount}</div><div style={styles.statLabel}>Active Temp Tags</div></div>
              <div style={styles.statCard}><div style={{ ...styles.statValue, color: '#2a9d8f' }}>{complianceScore}%</div><div style={styles.statLabel}>Compliance Score</div></div>
            </div>
          </div>
        </div>
      </section>

      {alerts.length > 0 && (
        <section style={styles.alertBanner}>
          <div className="container">
            <h3 style={{ margin: '0 0 12px', fontSize: '15px' }}>⚠️ Alerts ({alerts.length})</h3>
            <div style={{ display: 'flex', gap: '12px', flexWrap: 'wrap' as const }}>
              {alerts.map(a => (
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
              {recentSubmissions.length === 0 ? (
                <p style={{ color: '#888', fontSize: '14px' }}>No submissions yet.</p>
              ) : (
              <table style={styles.table}>
                <thead>
                  <tr>
                    <th style={styles.th}>ID</th>
                    <th style={styles.th}>Type</th>
                    <th style={styles.th}>Channel</th>
                    <th style={styles.th}>Date</th>
                    <th style={styles.th}>Status</th>
                  </tr>
                </thead>
                <tbody>
                  {recentSubmissions.slice(0, 5).map(s => {
                    const sc = statusColor(s.status)
                    return (
                      <tr key={s.id}>
                        <td style={styles.td}><code style={{ fontFamily: 'var(--font-mono)', fontSize: '12px' }}>{s.id}</code></td>
                        <td style={styles.td}>{s.type}</td>
                        <td style={styles.td}>{s.channel}</td>
                        <td style={styles.td}>{s.date}</td>
                        <td style={styles.td}><span style={{ ...styles.statusBadge, background: sc.bg, color: sc.color }}>{s.status}</span></td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
              )}
            </div>
          </div>
        )}

        {activeTab === 'submissions' && (
          <div>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
              <h2 style={{ margin: 0 }}>All Submissions</h2>
              <div style={{ display: 'flex', gap: '8px' }}>
                <a href="/vehicle-registration" className="btn btn-primary">+ New Registration</a>
                <a href="/dealer/bulk" className="btn" style={{ border: '1px solid #ccc' }}>📁 Bulk Upload</a>
              </div>
            </div>
            {recentSubmissions.length === 0 ? (
              <p style={{ color: '#888', fontSize: '14px', textAlign: 'center', padding: '40px' }}>No submissions yet. Create your first registration or transaction to get started.</p>
            ) : (
            <table style={styles.table}>
              <thead>
                <tr>
                  <th style={styles.th}>ID</th>
                  <th style={styles.th}>Type</th>
                  <th style={styles.th}>Channel</th>
                  <th style={styles.th}>Date</th>
                  <th style={styles.th}>Amount</th>
                  <th style={styles.th}>Status</th>
                </tr>
              </thead>
              <tbody>
                {recentSubmissions.map(s => {
                  const sc = statusColor(s.status)
                  return (
                    <tr key={s.id}>
                      <td style={styles.td}><code style={{ fontFamily: 'var(--font-mono)', fontSize: '12px' }}>{s.id}</code></td>
                      <td style={styles.td}>{s.type}</td>
                      <td style={styles.td}>{s.channel}</td>
                      <td style={styles.td}>{s.date}</td>
                      <td style={styles.td}>{s.amount ? `$${Number(s.amount).toFixed(2)}` : '—'}</td>
                      <td style={styles.td}><span style={{ ...styles.statusBadge, background: sc.bg, color: sc.color }}>{s.status}</span></td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
            )}
          </div>
        )}

        {activeTab === 'compliance' && (
          <div style={styles.grid}>
            <div style={styles.card}>
              <h3 style={styles.cardTitle}>Compliance Score</h3>
              <div style={styles.scoreCircle}>
                <span style={{ fontSize: '42px', fontWeight: 700, color: '#2a9d8f' }}>{complianceScore}%</span>
              </div>
              <p style={{ textAlign: 'center', color: '#666', fontSize: '14px' }}>
                {complianceScore >= 90 ? 'Your dealership is in good standing.' : complianceScore >= 70 ? 'Some items need attention.' : 'Action required on multiple items.'}
              </p>
            </div>
            <div style={{ ...styles.card, gridColumn: 'span 2' }}>
              <h3 style={styles.cardTitle}>Operations Summary</h3>
              {[
                { item: 'Active Registrations', count: registrations.filter(r => fmt(r, 'dmv_regstatus') === 'Active').length, total: registrations.length },
                { item: 'Active Vehicle Titles', count: titles.filter(t => fmt(t, 'dmv_titlestatus') === 'Active').length, total: titles.length },
                { item: 'Active Temporary Tags', count: activeTagCount, total: tempTags.length },
                { item: 'Completed Transactions', count: transactions.filter(t => fmt(t, 'dmv_status') === 'Completed').length, total: transactions.length },
              ].map(c => (
                <div key={c.item} style={{ display: 'flex', justifyContent: 'space-between', padding: '12px 0', borderBottom: '1px solid #f0f0f0' }}>
                  <span>{c.item}</span>
                  <span style={{ fontWeight: 600, fontFamily: 'var(--font-mono)', color: '#1D3557' }}>{c.count} / {c.total}</span>
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
