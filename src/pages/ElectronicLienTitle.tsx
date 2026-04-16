import { useEffect, useState } from 'react'
import { useAuth } from '../hooks/useAuth'
import { dvCreate, dvQuery, dvUpdate, fmt } from '../hooks/useDataverse'

export default function ElectronicLienTitle() {
  const { isAuthenticated, userId } = useAuth()
  const [activeView, setActiveView] = useState<'liens' | 'newLien' | 'newTitle'>('liens')
  const [formData, setFormData] = useState({ vin: '', owner: '', lienHolder: '', amount: '', titleNumber: '', make: '', model: '', year: '' })
  const [submitted, setSubmitted] = useState(false)
  const [submitting, setSubmitting] = useState(false)
  const [submitError, setSubmitError] = useState('')
  const [liens, setLiens] = useState<Record<string, any>[]>([])
  const [loading, setLoading] = useState(true)

  const loadData = () => {
    if (!isAuthenticated || !userId) { setLoading(false); return }
    dvQuery('dmv_liens',
      `$select=dmv_lienreference,dmv_lienstatus,dmv_lienholdername,dmv_liendate,dmv_loanamount,dmv_releasedate&$expand=dmv_vehicleid($select=dmv_vin)&$orderby=dmv_liendate desc&$top=50`
    ).catch(() =>
      dvQuery('dmv_liens',
        `$select=dmv_lienreference,dmv_lienstatus,dmv_lienholdername,dmv_liendate,dmv_loanamount,dmv_releasedate&$orderby=dmv_liendate desc&$top=50`
      ).catch(() => [])
    ).then(setLiens).finally(() => setLoading(false))
  }

  useEffect(() => { loadData() }, [isAuthenticated, userId])

  const statusStyle = (s: string) => {
    switch (s) {
      case 'Active': return { bg: '#cce5ff', color: '#004085' }
      case 'Released': return { bg: '#d4edda', color: '#155724' }
      case 'Pending': return { bg: '#fff3cd', color: '#856404' }
      default: return { bg: '#f0f0f0', color: '#666' }
    }
  }

  const handleNewLien = async (e: React.FormEvent) => {
    e.preventDefault()
    setSubmitting(true)
    setSubmitError('')
    try {
      // Create vehicle record
      const vehicleId = await dvCreate('dmv_vehicles', {
        dmv_vin: formData.vin,
        dmv_make: formData.make || 'Unknown',
        dmv_model: formData.model || 'Unknown',
        dmv_year: parseInt(formData.year) || new Date().getFullYear(),
        ...(userId ? { 'dmv_ownercontactid@odata.bind': `/contacts(${userId})` } : {}),
      })

      // Create title record
      const titleNum = `TTL-${new Date().getFullYear()}-${String(Math.floor(Math.random() * 9999)).padStart(4, '0')}`
      const titleId = await dvCreate('dmv_vehicletitles', {
        dmv_titlenumber: titleNum,
        dmv_titlestatus: 100000004, // Electronic (ELT)
        dmv_titletype: 100000000, // Clean
        dmv_issuedate: new Date().toISOString().split('T')[0],
        dmv_eltenabled: true,
        dmv_lienholdername: formData.lienHolder,
        dmv_liendate: new Date().toISOString().split('T')[0],
        dmv_processingstatus: 100000000, // Pending Review
        'dmv_vehicleid@odata.bind': `/dmv_vehicles(${vehicleId})`,
        ...(userId ? { 'dmv_ownercontactid@odata.bind': `/contacts(${userId})` } : {}),
      })

      // Create lien record
      const lienRef = `LIEN-${String(Math.floor(Math.random() * 9999)).padStart(4, '0')}`
      await dvCreate('dmv_liens', {
        dmv_lienreference: lienRef,
        dmv_lienstatus: 100000000, // Active
        dmv_lienholdername: formData.lienHolder,
        dmv_liendate: new Date().toISOString().split('T')[0],
        dmv_loanamount: parseFloat(formData.amount) || 0,
        'dmv_vehicleid@odata.bind': `/dmv_vehicles(${vehicleId})`,
        'dmv_titleid@odata.bind': `/dmv_vehicletitles(${titleId})`,
      })

      // Log transaction
      if (userId) {
        await dvCreate('dmv_transactionlogs', {
          dmv_transactionid: `TXN-${Math.floor(Math.random() * 9000000 + 1000000)}`,
          dmv_transactiontype: 100000002, // Title Transfer (closest to lien filing)
          dmv_transactiondate: new Date().toISOString(),
          dmv_status: 100000001, // Completed
          dmv_amount: parseFloat(formData.amount) || 0,
          dmv_channel: 100000002, // Dealer Portal
          'dmv_contactid@odata.bind': `/contacts(${userId})`,
        })
      }

      setSubmitted(true)
    } catch (err) {
      setSubmitError(err instanceof Error ? err.message : 'Submission failed. Please try again.')
    } finally {
      setSubmitting(false)
    }
  }

  const handleTitleTransfer = async (e: React.FormEvent) => {
    e.preventDefault()
    setSubmitting(true)
    setSubmitError('')
    try {
      // Create vehicle record for the transfer
      const vehicleId = await dvCreate('dmv_vehicles', {
        dmv_vin: formData.vin,
        dmv_make: formData.make || 'Unknown',
        dmv_model: formData.model || 'Unknown',
        dmv_year: parseInt(formData.year) || new Date().getFullYear(),
        ...(userId ? { 'dmv_ownercontactid@odata.bind': `/contacts(${userId})` } : {}),
      })

      // Create new title record
      const titleNum = `TTL-${new Date().getFullYear()}-${String(Math.floor(Math.random() * 9999)).padStart(4, '0')}`
      await dvCreate('dmv_vehicletitles', {
        dmv_titlenumber: titleNum,
        dmv_titlestatus: 100000005, // Pending
        dmv_titletype: 100000000, // Clean
        dmv_issuedate: new Date().toISOString().split('T')[0],
        dmv_prevtitlenumber: formData.titleNumber,
        dmv_transferdate: new Date().toISOString().split('T')[0],
        dmv_processingstatus: 100000000, // Pending Review
        'dmv_vehicleid@odata.bind': `/dmv_vehicles(${vehicleId})`,
        ...(userId ? { 'dmv_ownercontactid@odata.bind': `/contacts(${userId})` } : {}),
      })

      // Log transaction
      if (userId) {
        await dvCreate('dmv_transactionlogs', {
          dmv_transactionid: `TXN-${Math.floor(Math.random() * 9000000 + 1000000)}`,
          dmv_transactiontype: 100000002, // Title Transfer
          dmv_transactiondate: new Date().toISOString(),
          dmv_status: 100000001, // Completed
          dmv_channel: 100000002, // Dealer Portal
          'dmv_contactid@odata.bind': `/contacts(${userId})`,
        })
      }

      setSubmitted(true)
    } catch (err) {
      setSubmitError(err instanceof Error ? err.message : 'Submission failed. Please try again.')
    } finally {
      setSubmitting(false)
    }
  }

  const handleRelease = async (lienId: string) => {
    try {
      await dvUpdate('dmv_liens', lienId, {
        dmv_lienstatus: 100000001, // Released
        dmv_releasedate: new Date().toISOString().split('T')[0],
        dmv_releasemethod: 100000000, // Payoff
      })
      // Refresh data
      setLoading(true)
      loadData()
    } catch (err) {
      alert(err instanceof Error ? err.message : 'Release failed')
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
            {loading ? (
              <p style={{ color: '#666', textAlign: 'center', padding: '40px' }}>Loading lien records...</p>
            ) : liens.length === 0 ? (
              <p style={{ color: '#888', textAlign: 'center', padding: '40px' }}>No lien records found. File a new lien to get started.</p>
            ) : (
            <table style={styles.table}>
              <thead>
                <tr>
                  <th style={styles.th}>Lien ID</th>
                  <th style={styles.th}>Lien Holder</th>
                  <th style={styles.th}>Filed</th>
                  <th style={styles.th}>Amount</th>
                  <th style={styles.th}>Status</th>
                  <th style={styles.th}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {liens.map(l => {
                  const status = fmt(l, 'dmv_lienstatus') || 'Active'
                  const sc = statusStyle(status)
                  return (
                    <tr key={l.dmv_lienid}>
                      <td style={styles.td}><code style={{ fontFamily: 'var(--font-mono)', fontSize: '12px' }}>{l.dmv_lienreference}</code></td>
                      <td style={styles.td}>{l.dmv_lienholdername}</td>
                      <td style={styles.td}>{fmt(l, 'dmv_liendate')}</td>
                      <td style={styles.td}>{l.dmv_loanamount ? `$${Number(l.dmv_loanamount).toFixed(2)}` : '—'}</td>
                      <td style={styles.td}><span style={{ ...styles.badge, background: sc.bg, color: sc.color }}>{status}</span></td>
                      <td style={styles.td}>
                        {status === 'Active' && <button className="btn" style={{ fontSize: '12px', padding: '4px 12px', border: '1px solid #ccc' }} onClick={() => handleRelease(l.dmv_lienid)}>Release</button>}
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
            )}
          </div>
        )}

        {(activeView === 'newLien' || activeView === 'newTitle') && !submitted && (
          <div style={styles.card}>
            <h2 style={styles.cardTitle}>{activeView === 'newLien' ? 'File New Lien' : 'Request Title Transfer'}</h2>
            <form onSubmit={activeView === 'newLien' ? handleNewLien : handleTitleTransfer} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div style={styles.formGrid}>
                <div style={styles.field}>
                  <label style={styles.label}>VIN</label>
                  <input style={styles.input} placeholder="17-character VIN" maxLength={17} value={formData.vin} onChange={e => setFormData(p => ({ ...p, vin: e.target.value }))} required />
                </div>
                <div style={styles.field}>
                  <label style={styles.label}>Vehicle Owner</label>
                  <input style={styles.input} placeholder="Full legal name" value={formData.owner} onChange={e => setFormData(p => ({ ...p, owner: e.target.value }))} required />
                </div>
                <div style={styles.field}>
                  <label style={styles.label}>Make</label>
                  <input style={styles.input} placeholder="e.g. Toyota" value={formData.make} onChange={e => setFormData(p => ({ ...p, make: e.target.value }))} />
                </div>
                <div style={styles.field}>
                  <label style={styles.label}>Model</label>
                  <input style={styles.input} placeholder="e.g. Camry" value={formData.model} onChange={e => setFormData(p => ({ ...p, model: e.target.value }))} />
                </div>
                <div style={styles.field}>
                  <label style={styles.label}>Year</label>
                  <input style={styles.input} type="number" min="1900" max="2030" value={formData.year} onChange={e => setFormData(p => ({ ...p, year: e.target.value }))} />
                </div>
                {activeView === 'newLien' && (
                  <>
                    <div style={styles.field}>
                      <label style={styles.label}>Lien Holder</label>
                      <input style={styles.input} placeholder="Financial institution" value={formData.lienHolder} onChange={e => setFormData(p => ({ ...p, lienHolder: e.target.value }))} required />
                    </div>
                    <div style={styles.field}>
                      <label style={styles.label}>Lien Amount</label>
                      <input style={styles.input} type="number" placeholder="0.00" step="0.01" value={formData.amount} onChange={e => setFormData(p => ({ ...p, amount: e.target.value }))} required />
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
              {submitError && <p style={{ color: '#E63946', fontSize: '14px', margin: 0 }}>{submitError}</p>}
              <button type="submit" className="btn btn-primary" disabled={submitting} style={{ alignSelf: 'flex-start', padding: '12px 32px' }}>
                {submitting ? 'Submitting...' : activeView === 'newLien' ? 'Submit Lien Filing' : 'Submit Title Transfer'}
              </button>
            </form>
          </div>
        )}

        {submitted && (
          <div style={{ ...styles.card, textAlign: 'center', padding: '48px' }}>
            <span style={{ fontSize: '48px' }}>✅</span>
            <h2 style={{ margin: '16px 0 8px' }}>{activeView === 'newLien' ? 'Lien Filed' : 'Title Transfer Submitted'}</h2>
            <p style={{ color: '#666' }}>Your submission has been received and is being processed.</p>
            <button onClick={() => { setActiveView('liens'); setSubmitted(false); setSubmitError(''); setFormData({ vin: '', owner: '', lienHolder: '', amount: '', titleNumber: '', make: '', model: '', year: '' }); setLoading(true); loadData() }} className="btn btn-primary" style={{ marginTop: '16px' }}>
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
