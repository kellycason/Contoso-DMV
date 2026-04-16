import { useEffect, useState } from 'react'
import { useAuth } from '../hooks/useAuth'
import { dvCreate, dvQuery, fmt } from '../hooks/useDataverse'

export default function TempTags() {
  const { isAuthenticated, userId } = useAuth()
  const [formData, setFormData] = useState({ vin: '', make: '', model: '', year: '', color: '', buyer: '', saleDate: '' })
  const [generated, setGenerated] = useState(false)
  const [submitting, setSubmitting] = useState(false)
  const [submitError, setSubmitError] = useState('')
  const [tagNumber, setTagNumber] = useState('')
  const [expiryDate, setExpiryDate] = useState('')
  const [activeTags, setActiveTags] = useState<Record<string, any>[]>([])
  const [loadingTags, setLoadingTags] = useState(true)

  useEffect(() => {
    if (isAuthenticated && userId) {
      dvQuery('dmv_temporarytags',
        `$filter=_dmv_generatedby_value eq ${userId}&$select=dmv_tagnumber,dmv_buyername,dmv_issuedate,dmv_expirationdate,dmv_tagstatus&$orderby=dmv_issuedate desc&$top=20`
      ).then(setActiveTags).catch(() => {}).finally(() => setLoadingTags(false))
    } else {
      setLoadingTags(false)
    }
  }, [isAuthenticated, userId])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setSubmitting(true)
    setSubmitError('')
    try {
      // Create the vehicle record
      const vehicleId = await dvCreate('dmv_vehicles', {
        dmv_vin: formData.vin,
        dmv_make: formData.make,
        dmv_model: formData.model,
        dmv_year: parseInt(formData.year),
        dmv_color: formData.color,
        dmv_platetype: 100000004, // Temporary
        ...(userId ? { 'dmv_ownercontactid@odata.bind': `/contacts(${userId})` } : {}),
      })

      const tag = `TMP-${new Date().getFullYear()}-${String(Math.floor(Math.random() * 9999)).padStart(4, '0')}`
      const expiry = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0]

      // Create the temp tag
      await dvCreate('dmv_temporarytags', {
        dmv_tagnumber: tag,
        dmv_buyername: formData.buyer,
        dmv_issuedate: new Date().toISOString().split('T')[0],
        dmv_expirationdate: expiry,
        dmv_tagstatus: 100000000, // Active
        dmv_saleprice: 0,
        dmv_printcount: 0,
        'dmv_vehicleid@odata.bind': `/dmv_vehicles(${vehicleId})`,
        ...(userId ? { 'dmv_generatedby@odata.bind': `/contacts(${userId})` } : {}),
      })

      // Log the transaction
      if (userId) {
        await dvCreate('dmv_transactionlogs', {
          dmv_transactionid: `TXN-${Math.floor(Math.random() * 9000000 + 1000000)}`,
          dmv_transactiontype: 100000003, // Tag Issued
          dmv_transactiondate: new Date().toISOString(),
          dmv_status: 100000001, // Completed
          dmv_channel: 100000002, // Dealer Portal
          'dmv_contactid@odata.bind': `/contacts(${userId})`,
        })
      }

      setTagNumber(tag)
      setExpiryDate(expiry)
      setGenerated(true)
    } catch (err) {
      setSubmitError(err instanceof Error ? err.message : 'Tag generation failed. Please try again.')
    } finally {
      setSubmitting(false)
    }
  }

  const tagStatusStyle = (val: string) => {
    if (val === 'Active') return { bg: '#d4edda', color: '#155724' }
    if (val === 'Expired' || val === 'Voided') return { bg: '#f8d7da', color: '#721c24' }
    if (val === 'Converted to Plate') return { bg: '#cce5ff', color: '#004085' }
    return { bg: '#fff3cd', color: '#856404' }
  }

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
              <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                <div style={styles.formGrid}>
                  <div style={styles.field}><label style={styles.label}>VIN</label><input style={styles.input} maxLength={17} placeholder="17-character VIN" required value={formData.vin} onChange={e => setFormData(p => ({ ...p, vin: e.target.value }))} /></div>
                  <div style={styles.field}><label style={styles.label}>Make</label><input style={styles.input} placeholder="e.g. Toyota" required value={formData.make} onChange={e => setFormData(p => ({ ...p, make: e.target.value }))} /></div>
                  <div style={styles.field}><label style={styles.label}>Model</label><input style={styles.input} placeholder="e.g. Camry" required value={formData.model} onChange={e => setFormData(p => ({ ...p, model: e.target.value }))} /></div>
                  <div style={styles.field}><label style={styles.label}>Year</label><input style={styles.input} type="number" min="1900" max="2027" required value={formData.year} onChange={e => setFormData(p => ({ ...p, year: e.target.value }))} /></div>
                  <div style={styles.field}><label style={styles.label}>Color</label><input style={styles.input} placeholder="e.g. Silver" required value={formData.color} onChange={e => setFormData(p => ({ ...p, color: e.target.value }))} /></div>
                  <div style={styles.field}><label style={styles.label}>Buyer Name</label><input style={styles.input} placeholder="Full legal name" required value={formData.buyer} onChange={e => setFormData(p => ({ ...p, buyer: e.target.value }))} /></div>
                  <div style={styles.field}><label style={styles.label}>Sale Date</label><input style={styles.input} type="date" required value={formData.saleDate} onChange={e => setFormData(p => ({ ...p, saleDate: e.target.value }))} /></div>
                </div>
                {submitError && <p style={{ color: '#E63946', fontSize: '14px', margin: 0 }}>{submitError}</p>}
                <button type="submit" className="btn btn-primary" disabled={submitting} style={{ alignSelf: 'flex-start', padding: '12px 32px' }}>
                  {submitting ? '⏳ Generating...' : '🏷️ Generate Temporary Tag'}
                </button>
              </form>
            </div>

            <div style={styles.card}>
              <h3 style={styles.cardTitle}>Active Temporary Tags</h3>
              {loadingTags ? (
                <p style={{ color: '#888', fontSize: '14px' }}>Loading tags...</p>
              ) : activeTags.length === 0 ? (
                <p style={{ color: '#888', fontSize: '14px' }}>No temporary tags issued yet.</p>
              ) : (
                activeTags.map(t => {
                  const status = fmt(t, 'dmv_tagstatus') || 'Active'
                  const sc = tagStatusStyle(status)
                  return (
                    <div key={t.dmv_temporarytagid} style={styles.tagRow}>
                      <div>
                        <strong style={{ fontFamily: 'var(--font-mono)' }}>{t.dmv_tagnumber}</strong>
                        <div style={{ fontSize: '12px', color: '#888' }}>{t.dmv_buyername}</div>
                      </div>
                      <div style={{ textAlign: 'right' as const }}>
                        <span style={{ ...styles.badge, background: sc.bg, color: sc.color }}>{status}</span>
                        <div style={{ fontSize: '11px', color: '#888', marginTop: '2px' }}>Exp: {fmt(t, 'dmv_expirationdate')}</div>
                      </div>
                    </div>
                  )
                })
              )}
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
              <button className="btn" style={{ border: '1px solid #ccc' }} onClick={() => { setGenerated(false); setSubmitError(''); setFormData({ vin: '', make: '', model: '', year: '', color: '', buyer: '', saleDate: '' }) }}>Generate Another</button>
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
