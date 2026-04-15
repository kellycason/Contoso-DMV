import { useState } from 'react'

type LienRecord = {
  id: string
  titleNumber: string
  vin: string
  owner: string
  lienHolder: string
  status: 'Active' | 'Released' | 'Pending'
  filedDate: string
}

const mockLiens: LienRecord[] = [
  { id: 'LIEN-001', titleNumber: 'TTL-2026-4521', vin: '1HGCM82633A004352', owner: 'John Smith', lienHolder: 'First National Bank', status: 'Active', filedDate: '2026-01-15' },
  { id: 'LIEN-002', titleNumber: 'TTL-2026-4520', vin: '5YJSA1E26HF000316', owner: 'Jane Doe', lienHolder: 'Credit Union Auto Finance', status: 'Released', filedDate: '2025-11-20' },
  { id: 'LIEN-003', titleNumber: 'TTL-2026-4519', vin: 'WBAJB0C51JB084460', owner: 'Mike Johnson', lienHolder: 'Auto Capital LLC', status: 'Pending', filedDate: '2026-04-10' },
]

export default function ElectronicLienTitle() {
  const [activeView, setActiveView] = useState<'liens' | 'newLien' | 'newTitle'>('liens')
  const [formData, setFormData] = useState({ vin: '', owner: '', lienHolder: '', amount: '', titleNumber: '' })
  const [submitted, setSubmitted] = useState(false)

  const statusStyle = (s: string) => {
    switch (s) {
      case 'Active': return { bg: '#cce5ff', color: '#004085' }
      case 'Released': return { bg: '#d4edda', color: '#155724' }
      case 'Pending': return { bg: '#fff3cd', color: '#856404' }
      default: return { bg: '#f0f0f0', color: '#666' }
    }
  }

  return (
    <div>
      <section style={styles.hero}>
        <div className="container">
          <h1 style={styles.heroTitle}>Electronic Lien & Titling (ELT)</h1>
          <p style={styles.heroSub}>Digitally manage vehicle liens and titles. File new liens, release existing ones, and transfer titles electronically.</p>
        </div>
      </section>

      <section className="container" style={{ padding: '40px 24px' }}>
        <div style={styles.tabs}>
          <button onClick={() => { setActiveView('liens'); setSubmitted(false) }} style={{ ...styles.tab, ...(activeView === 'liens' ? styles.tabActive : {}) }}>📋 Lien Records</button>
          <button onClick={() => { setActiveView('newLien'); setSubmitted(false) }} style={{ ...styles.tab, ...(activeView === 'newLien' ? styles.tabActive : {}) }}>+ New Lien</button>
          <button onClick={() => { setActiveView('newTitle'); setSubmitted(false) }} style={{ ...styles.tab, ...(activeView === 'newTitle' ? styles.tabActive : {}) }}>📄 Title Transfer</button>
        </div>

        {activeView === 'liens' && (
          <div>
            <table style={styles.table}>
              <thead>
                <tr>
                  <th style={styles.th}>Lien ID</th>
                  <th style={styles.th}>Title #</th>
                  <th style={styles.th}>VIN</th>
                  <th style={styles.th}>Owner</th>
                  <th style={styles.th}>Lien Holder</th>
                  <th style={styles.th}>Filed</th>
                  <th style={styles.th}>Status</th>
                  <th style={styles.th}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {mockLiens.map(l => {
                  const sc = statusStyle(l.status)
                  return (
                    <tr key={l.id}>
                      <td style={styles.td}><code style={{ fontFamily: 'var(--font-mono)', fontSize: '12px' }}>{l.id}</code></td>
                      <td style={styles.td}><code style={{ fontFamily: 'var(--font-mono)', fontSize: '12px' }}>{l.titleNumber}</code></td>
                      <td style={styles.td}><code style={{ fontFamily: 'var(--font-mono)', fontSize: '11px' }}>{l.vin}</code></td>
                      <td style={styles.td}>{l.owner}</td>
                      <td style={styles.td}>{l.lienHolder}</td>
                      <td style={styles.td}>{l.filedDate}</td>
                      <td style={styles.td}><span style={{ ...styles.badge, background: sc.bg, color: sc.color }}>{l.status}</span></td>
                      <td style={styles.td}>
                        {l.status === 'Active' && <button className="btn" style={{ fontSize: '12px', padding: '4px 12px', border: '1px solid #ccc' }}>Release</button>}
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}

        {(activeView === 'newLien' || activeView === 'newTitle') && !submitted && (
          <div style={styles.card}>
            <h2 style={styles.cardTitle}>{activeView === 'newLien' ? 'File New Lien' : 'Request Title Transfer'}</h2>
            <form onSubmit={e => { e.preventDefault(); setSubmitted(true) }} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div style={styles.formGrid}>
                <div style={styles.field}>
                  <label style={styles.label}>VIN</label>
                  <input style={styles.input} placeholder="17-character VIN" maxLength={17} value={formData.vin} onChange={e => setFormData(p => ({ ...p, vin: e.target.value }))} required />
                </div>
                <div style={styles.field}>
                  <label style={styles.label}>Vehicle Owner</label>
                  <input style={styles.input} placeholder="Full legal name" value={formData.owner} onChange={e => setFormData(p => ({ ...p, owner: e.target.value }))} required />
                </div>
                {activeView === 'newLien' && (
                  <>
                    <div style={styles.field}>
                      <label style={styles.label}>Lien Holder</label>
                      <input style={styles.input} placeholder="Financial institution" value={formData.lienHolder} onChange={e => setFormData(p => ({ ...p, lienHolder: e.target.value }))} required />
                    </div>
                    <div style={styles.field}>
                      <label style={styles.label}>Lien Amount</label>
                      <input style={styles.input} type="number" placeholder="0.00" value={formData.amount} onChange={e => setFormData(p => ({ ...p, amount: e.target.value }))} required />
                    </div>
                  </>
                )}
                {activeView === 'newTitle' && (
                  <div style={styles.field}>
                    <label style={styles.label}>Existing Title Number</label>
                    <input style={styles.input} placeholder="TTL-XXXX-XXXX" value={formData.titleNumber} onChange={e => setFormData(p => ({ ...p, titleNumber: e.target.value }))} required />
                  </div>
                )}
              </div>
              <button type="submit" className="btn btn-primary" style={{ alignSelf: 'flex-start', padding: '12px 32px' }}>
                {activeView === 'newLien' ? 'Submit Lien Filing' : 'Submit Title Transfer'}
              </button>
            </form>
          </div>
        )}

        {submitted && (
          <div style={{ ...styles.card, textAlign: 'center', padding: '48px' }}>
            <span style={{ fontSize: '48px' }}>✅</span>
            <h2 style={{ margin: '16px 0 8px' }}>{activeView === 'newLien' ? 'Lien Filed' : 'Title Transfer Submitted'}</h2>
            <p style={{ color: '#666' }}>Your submission has been received and is being processed.</p>
            <button onClick={() => { setActiveView('liens'); setSubmitted(false) }} className="btn btn-primary" style={{ marginTop: '16px' }}>
              View All Records
            </button>
          </div>
        )}
      </section>
    </div>
  )
}

const styles: Record<string, React.CSSProperties> = {
  hero: { background: 'linear-gradient(135deg, #264653 0%, #1D3557 100%)', color: '#fff', padding: '48px 0 40px' },
  heroTitle: { fontSize: '32px', fontFamily: 'var(--font-heading)', margin: '0 0 12px' },
  heroSub: { fontSize: '16px', opacity: 0.85, margin: 0, maxWidth: '600px' },
  tabs: { display: 'flex', gap: '4px', borderBottom: '2px solid #eee', marginBottom: '32px' },
  tab: { padding: '12px 20px', border: 'none', background: 'none', cursor: 'pointer', fontSize: '14px', fontWeight: 500, color: '#666', borderBottom: '2px solid transparent', marginBottom: '-2px', transition: 'all 0.2s' },
  tabActive: { color: '#1D3557', borderBottomColor: '#1D3557', fontWeight: 600 },
  card: { background: '#fff', borderRadius: '12px', padding: '24px', border: '1px solid #e8e8e8', boxShadow: '0 2px 8px rgba(0,0,0,0.04)' },
  cardTitle: { fontSize: '18px', fontWeight: 600, color: '#1D3557', margin: '0 0 20px', paddingBottom: '12px', borderBottom: '1px solid #eee' },
  table: { width: '100%', borderCollapse: 'collapse' as const, background: '#fff', borderRadius: '8px', overflow: 'hidden', boxShadow: '0 1px 4px rgba(0,0,0,0.06)' },
  th: { textAlign: 'left' as const, padding: '14px 16px', background: '#f8f9fa', fontWeight: 600, fontSize: '13px', color: '#1D3557', borderBottom: '2px solid #e8e8e8' },
  td: { padding: '12px 16px', borderBottom: '1px solid #f0f0f0', fontSize: '14px' },
  badge: { display: 'inline-block', padding: '2px 10px', borderRadius: '12px', fontSize: '11px', fontWeight: 600 },
  formGrid: { display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))', gap: '16px' },
  field: { display: 'flex', flexDirection: 'column' as const, gap: '6px' },
  label: { fontSize: '13px', fontWeight: 600, color: '#1D3557' },
  input: { padding: '10px 14px', border: '1px solid #d0d5dd', borderRadius: '6px', fontSize: '14px' },
}
