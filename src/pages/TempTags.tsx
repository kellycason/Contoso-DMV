import { useState } from 'react'

export default function TempTags() {
  const [formData, setFormData] = useState({ vin: '', make: '', model: '', year: '', color: '', buyer: '', saleDate: '' })
  const [generated, setGenerated] = useState(false)
  const tagNumber = `TMP-${new Date().getFullYear()}-${String(Math.floor(Math.random() * 9999)).padStart(4, '0')}`
  const expiryDate = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0]

  const mockActive = [
    { tag: 'TMP-2026-0234', vin: '3VWDX7AJ5BM123456', buyer: 'Sarah Wilson', issued: '2026-04-12', expires: '2026-05-12', status: 'Active' },
    { tag: 'TMP-2026-0220', vin: '2T1BURHE2JC789012', buyer: 'David Brown', issued: '2026-04-08', expires: '2026-05-08', status: 'Active' },
    { tag: 'TMP-2026-0198', vin: 'WBAJB0C51JB345678', buyer: 'Emily Chen', issued: '2026-03-28', expires: '2026-04-27', status: 'Expiring' },
  ]

  return (
    <div>
      <section style={styles.hero}>
        <div className="container">
          <h1 style={styles.heroTitle}>Temporary Tag Generation</h1>
          <p style={styles.heroSub}>Generate instant printable temporary tags for newly sold vehicles. Tags are valid for 30 days.</p>
        </div>
      </section>

      <section className="container" style={{ padding: '40px 24px' }}>
        {!generated ? (
          <div style={styles.grid}>
            <div style={styles.card}>
              <h2 style={styles.cardTitle}>Generate New Temp Tag</h2>
              <form onSubmit={e => { e.preventDefault(); setGenerated(true) }} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                <div style={styles.formGrid}>
                  <div style={styles.field}><label style={styles.label}>VIN</label><input style={styles.input} maxLength={17} placeholder="17-character VIN" required value={formData.vin} onChange={e => setFormData(p => ({ ...p, vin: e.target.value }))} /></div>
                  <div style={styles.field}><label style={styles.label}>Make</label><input style={styles.input} placeholder="e.g. Toyota" required value={formData.make} onChange={e => setFormData(p => ({ ...p, make: e.target.value }))} /></div>
                  <div style={styles.field}><label style={styles.label}>Model</label><input style={styles.input} placeholder="e.g. Camry" required value={formData.model} onChange={e => setFormData(p => ({ ...p, model: e.target.value }))} /></div>
                  <div style={styles.field}><label style={styles.label}>Year</label><input style={styles.input} type="number" min="1900" max="2027" required value={formData.year} onChange={e => setFormData(p => ({ ...p, year: e.target.value }))} /></div>
                  <div style={styles.field}><label style={styles.label}>Color</label><input style={styles.input} placeholder="e.g. Silver" required value={formData.color} onChange={e => setFormData(p => ({ ...p, color: e.target.value }))} /></div>
                  <div style={styles.field}><label style={styles.label}>Buyer Name</label><input style={styles.input} placeholder="Full legal name" required value={formData.buyer} onChange={e => setFormData(p => ({ ...p, buyer: e.target.value }))} /></div>
                  <div style={styles.field}><label style={styles.label}>Sale Date</label><input style={styles.input} type="date" required value={formData.saleDate} onChange={e => setFormData(p => ({ ...p, saleDate: e.target.value }))} /></div>
                </div>
                <button type="submit" className="btn btn-primary" style={{ alignSelf: 'flex-start', padding: '12px 32px' }}>🏷️ Generate Temporary Tag</button>
              </form>
            </div>

            <div style={styles.card}>
              <h3 style={styles.cardTitle}>Active Temporary Tags</h3>
              {mockActive.map(t => (
                <div key={t.tag} style={styles.tagRow}>
                  <div>
                    <strong style={{ fontFamily: 'var(--font-mono)' }}>{t.tag}</strong>
                    <div style={{ fontSize: '12px', color: '#888' }}>{t.buyer} · VIN: {t.vin.slice(0, 8)}...</div>
                  </div>
                  <div style={{ textAlign: 'right' as const }}>
                    <span style={{ ...styles.badge, background: t.status === 'Active' ? '#d4edda' : '#fff3cd', color: t.status === 'Active' ? '#155724' : '#856404' }}>
                      {t.status}
                    </span>
                    <div style={{ fontSize: '11px', color: '#888', marginTop: '2px' }}>Exp: {t.expires}</div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        ) : (
          <div style={{ ...styles.card, textAlign: 'center', maxWidth: '600px', margin: '0 auto' }}>
            <div style={styles.tagPreview}>
              <div style={styles.tagHeader}>TEMPORARY TAG</div>
              <div style={styles.tagNum}>{tagNumber}</div>
              <div style={styles.tagGrid}>
                <div><span style={styles.tagLabel}>VIN</span><span>{formData.vin || 'N/A'}</span></div>
                <div><span style={styles.tagLabel}>Vehicle</span><span>{formData.year} {formData.make} {formData.model}</span></div>
                <div><span style={styles.tagLabel}>Color</span><span>{formData.color || 'N/A'}</span></div>
                <div><span style={styles.tagLabel}>Buyer</span><span>{formData.buyer || 'N/A'}</span></div>
                <div><span style={styles.tagLabel}>Sale Date</span><span>{formData.saleDate || 'N/A'}</span></div>
                <div><span style={styles.tagLabel}>Expires</span><span style={{ color: '#E63946', fontWeight: 600 }}>{expiryDate}</span></div>
              </div>
              <div style={styles.tagFooter}>Contoso DMV · Department of Motor Vehicles · Dealer #DLR-2024-0156</div>
            </div>
            <div style={{ display: 'flex', gap: '12px', justifyContent: 'center', marginTop: '24px' }}>
              <button className="btn btn-primary">🖨️ Print Tag</button>
              <button className="btn" style={{ border: '1px solid #ccc' }} onClick={() => { setGenerated(false); setFormData({ vin: '', make: '', model: '', year: '', color: '', buyer: '', saleDate: '' }) }}>Generate Another</button>
            </div>
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
  grid: { display: 'grid', gridTemplateColumns: '1.5fr 1fr', gap: '24px' },
  card: { background: '#fff', borderRadius: '12px', padding: '24px', border: '1px solid #e8e8e8', boxShadow: '0 2px 8px rgba(0,0,0,0.04)' },
  cardTitle: { fontSize: '18px', fontWeight: 600, color: '#1D3557', margin: '0 0 16px', paddingBottom: '12px', borderBottom: '1px solid #eee' },
  formGrid: { display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '16px' },
  field: { display: 'flex', flexDirection: 'column' as const, gap: '6px' },
  label: { fontSize: '13px', fontWeight: 600, color: '#1D3557' },
  input: { padding: '10px 14px', border: '1px solid #d0d5dd', borderRadius: '6px', fontSize: '14px' },
  tagRow: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '14px 0', borderBottom: '1px solid #f0f0f0' },
  badge: { display: 'inline-block', padding: '2px 10px', borderRadius: '12px', fontSize: '11px', fontWeight: 600 },
  tagPreview: { background: '#1D3557', color: '#fff', borderRadius: '12px', padding: '32px', border: '3px solid #E63946' },
  tagHeader: { fontSize: '14px', letterSpacing: '0.15em', fontWeight: 600, opacity: 0.7 },
  tagNum: { fontSize: '36px', fontFamily: 'var(--font-mono)', fontWeight: 700, margin: '8px 0 20px', letterSpacing: '0.05em' },
  tagGrid: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', textAlign: 'left' as const, fontSize: '14px' },
  tagLabel: { display: 'block', fontSize: '10px', textTransform: 'uppercase' as const, letterSpacing: '0.08em', opacity: 0.6, marginBottom: '2px' },
  tagFooter: { marginTop: '20px', paddingTop: '12px', borderTop: '1px solid rgba(255,255,255,0.2)', fontSize: '11px', opacity: 0.5 },
}
