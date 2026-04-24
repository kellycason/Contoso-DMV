import { useEffect, useState } from 'react'
import { useAuth } from '../hooks/useAuth'
import { dvQuery, fmt } from '../hooks/useDataverse'

interface TagRow {
  dmv_temporarytagid: string
  dmv_tagnumber: string
  dmv_buyername: string
  dmv_issuedate: string
  dmv_expirationdate: string
  dmv_tagstatus?: number
  dmv_vehicleid?: {
    dmv_vin?: string
    dmv_year?: string
    dmv_make?: string
    dmv_model?: string
    dmv_color?: string
  }
}

export default function TempTags() {
  const { isAuthenticated } = useAuth()
  const [tags, setTags] = useState<TagRow[]>([])
  const [loading, setLoading] = useState(true)
  const [selected, setSelected] = useState<TagRow | null>(null)

  useEffect(() => {
    if (!isAuthenticated) { setLoading(false); return }
    // Demo: show tags issued to "Sam Smith" (the demo buyer persona)
    const buyerName = 'Sam Smith'
    dvQuery('dmv_temporarytags',
      `$filter=dmv_buyername eq '${buyerName}' and dmv_tagstatus eq 100000000` +
      `&$select=dmv_temporarytagid,dmv_tagnumber,dmv_buyername,dmv_issuedate,dmv_expirationdate,dmv_tagstatus` +
      `&$expand=dmv_vehicleid($select=dmv_vin,dmv_year,dmv_make,dmv_model,dmv_color)` +
      `&$orderby=dmv_issuedate desc&$top=20`
    )
      .then((rows: TagRow[]) => setTags(rows))
      .catch(() => {})
      .finally(() => setLoading(false))
  }, [isAuthenticated, userName])

  const handlePrint = () => window.print()

  if (!isAuthenticated) {
    return (
      <div className="section-sm">
        <div className="container" style={{ maxWidth: 620, textAlign: 'center', padding: '48px 24px' }}>
          <div style={{ fontSize: 48, marginBottom: 16 }}>🏷️</div>
          <h2 style={{ color: 'var(--color-primary)', marginBottom: 12 }}>Sign In Required</h2>
          <p style={{ color: 'var(--color-text-muted)', marginBottom: 24 }}>
            Please sign in to view your temporary tags.
          </p>
          <a href="/Account/Login/ExternalLogin" className="btn btn-primary">Sign In</a>
        </div>
      </div>
    )
  }

  return (
    <div>
      <section style={styles.hero}>
        <div className="container">
          <h1 style={styles.heroTitle}>My Temporary Tags</h1>
          <p style={styles.heroSub}>
            Active temporary tags issued through your dealer registrations. Tags appear here
            once the DMV has approved your new registration and are valid for 30 days from issue date.
          </p>
        </div>
      </section>

      <section className="container" style={{ padding: '40px 24px' }}>
        {loading ? (
          <p style={{ color: '#888' }}>Loading your temporary tags…</p>
        ) : tags.length === 0 ? (
          <div style={{ ...styles.card, textAlign: 'center', padding: '48px 24px' }}>
            <div style={{ fontSize: 48, marginBottom: 16 }}>🏷️</div>
            <h3 style={{ color: 'var(--color-primary)', margin: '0 0 8px' }}>No active temporary tags</h3>
            <p style={{ color: '#666', margin: 0 }}>
              When a dealer submits a new registration for you and the DMV approves it,
              your temporary tag will appear here for download &amp; printing.
            </p>
          </div>
        ) : selected ? (
          <TagPreview tag={selected} onBack={() => setSelected(null)} onPrint={handlePrint} />
        ) : (
          <div style={styles.listCard}>
            <h2 style={styles.cardTitle}>Approved Tags ({tags.length})</h2>
            {tags.map(t => {
              const v = t.dmv_vehicleid
              const vehicle = v ? `${v.dmv_year || ''} ${v.dmv_make || ''} ${v.dmv_model || ''}`.trim() : '—'
              return (
                <div key={t.dmv_temporarytagid} style={styles.tagRow}>
                  <div style={{ flex: 1 }}>
                    <strong style={{ fontFamily: 'var(--font-mono)', fontSize: 15 }}>{t.dmv_tagnumber}</strong>
                    <div style={{ fontSize: 13, color: '#555', marginTop: 2 }}>{vehicle}</div>
                    <div style={{ fontSize: 12, color: '#888', marginTop: 2 }}>
                      Issued {fmt(t, 'dmv_issuedate')} · Expires {fmt(t, 'dmv_expirationdate')}
                    </div>
                  </div>
                  <button className="btn btn-primary" onClick={() => setSelected(t)} style={{ padding: '8px 16px' }}>
                    View &amp; Print
                  </button>
                </div>
              )
            })}
          </div>
        )}
      </section>
    </div>
  )
}

/* ──────────────────────────────────────────────────────────
   Printable tag preview. The markup inside #temp-tag can be
   copy-pasted into an email template or reused for a Power
   Automate "convert to PDF" action.
   ────────────────────────────────────────────────────────── */
function TagPreview({ tag, onBack, onPrint }: { tag: TagRow; onBack: () => void; onPrint: () => void }) {
  const v = tag.dmv_vehicleid
  return (
    <div>
      <div style={{ display: 'flex', gap: 12, marginBottom: 16 }} className="no-print">
        <button className="btn" style={{ border: '1px solid #ccc' }} onClick={onBack}>← Back to list</button>
        <button className="btn btn-primary" onClick={onPrint}>🖨️ Print Tag</button>
      </div>

      <div id="temp-tag" style={styles.tagPreview}>
        <div style={styles.tagHeader}>TEMPORARY REGISTRATION PERMIT</div>
        <div style={styles.tagNum}>{tag.dmv_tagnumber}</div>
        <div style={styles.tagGrid}>
          <div><span style={styles.tagLabel}>VIN</span><span>{v?.dmv_vin || '—'}</span></div>
          <div><span style={styles.tagLabel}>Vehicle</span><span>{`${v?.dmv_year || ''} ${v?.dmv_make || ''} ${v?.dmv_model || ''}`.trim() || '—'}</span></div>
          <div><span style={styles.tagLabel}>Color</span><span>{v?.dmv_color || '—'}</span></div>
          <div><span style={styles.tagLabel}>Registrant</span><span>{tag.dmv_buyername || '—'}</span></div>
          <div><span style={styles.tagLabel}>Issued</span><span>{fmt(tag, 'dmv_issuedate')}</span></div>
          <div><span style={styles.tagLabel}>Expires</span><span style={{ color: '#E63946', fontWeight: 600 }}>{fmt(tag, 'dmv_expirationdate')}</span></div>
        </div>
        <div style={styles.tagFooter}>Contoso DMV · Department of Motor Vehicles · Display in lower-right corner of rear windshield</div>
      </div>

      <style>{`@media print { .no-print { display: none !important; } body { background: #fff !important; } }`}</style>
    </div>
  )
}

const styles: Record<string, React.CSSProperties> = {
  hero: { background: 'linear-gradient(135deg, #1D3557 0%, #264674 100%)', color: '#fff', padding: '48px 0 40px' },
  heroTitle: { fontSize: '32px', fontFamily: 'var(--font-heading)', margin: '0 0 12px', color: '#fff' },
  heroSub: { fontSize: '16px', opacity: 0.85, margin: 0, maxWidth: '680px', lineHeight: 1.5 },
  card: { background: '#fff', borderRadius: '12px', padding: '24px', border: '1px solid #e8e8e8', boxShadow: '0 2px 8px rgba(0,0,0,0.04)' },
  listCard: { background: '#fff', borderRadius: '12px', padding: '24px', border: '1px solid #e8e8e8', boxShadow: '0 2px 8px rgba(0,0,0,0.04)', maxWidth: 760 },
  cardTitle: { fontSize: '18px', fontWeight: 600, color: '#1D3557', margin: '0 0 16px', paddingBottom: '12px', borderBottom: '1px solid #eee' },
  tagRow: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 16, padding: '16px 0', borderBottom: '1px solid #f0f0f0' },
  tagPreview: { background: '#1D3557', color: '#fff', borderRadius: '12px', padding: '32px', border: '3px solid #E63946', maxWidth: 640, margin: '0 auto' },
  tagHeader: { fontSize: '14px', letterSpacing: '0.15em', fontWeight: 600, opacity: 0.7, textAlign: 'center' as const },
  tagNum: { fontSize: '42px', fontFamily: 'var(--font-mono)', fontWeight: 700, margin: '12px 0 24px', letterSpacing: '0.05em', textAlign: 'center' as const },
  tagGrid: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px', textAlign: 'left' as const, fontSize: '14px' },
  tagLabel: { display: 'block', fontSize: '10px', textTransform: 'uppercase' as const, letterSpacing: '0.08em', opacity: 0.6, marginBottom: '2px' },
  tagFooter: { marginTop: '24px', paddingTop: '16px', borderTop: '1px solid rgba(255,255,255,0.2)', fontSize: '11px', opacity: 0.6, textAlign: 'center' as const },
}
