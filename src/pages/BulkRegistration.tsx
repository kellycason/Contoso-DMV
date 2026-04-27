import { useEffect, useState } from 'react'
import { useAuth } from '../hooks/useAuth'
import { DEMO_DEALER } from '../hooks/usePersona'
import { dvCreate, dvQuery, dvUpdate, fmt } from '../hooks/useDataverse'

/* ══════════════════════════════════════════════════════════════════════
   CSV template — 5 pre-populated vehicles for a clean demo flow.
   Column order MUST match parseCsv() below.
   ══════════════════════════════════════════════════════════════════════ */
const CSV_HEADERS = [
  'VIN', 'Year', 'Make', 'Model', 'Color', 'MSRP',
  'CustomerFirst', 'CustomerLast', 'CustomerEmail', 'CustomerPhone',
  'CustomerAddress', 'CustomerCity', 'CustomerState', 'CustomerZip',
  'InsuranceCarrier', 'InsurancePolicy',
] as const

const CSV_SAMPLE_ROWS: string[][] = [
  ['1HGCM82633A004352', '2024', 'Honda', 'Civic',    'Silver', '28500', 'Alice',   'Nguyen',  'alice.nguyen@example.com',  '(555) 201-4411', '842 Oak St',       'Contoso', 'TX', '78704', 'Contoso Mutual Auto', 'POL-2026-10001'],
  ['5YJ3E1EA4KF000316', '2024', 'Tesla',  'Model 3',  'White',  '48500', 'Brian',   'Patel',   'brian.patel@example.com',   '(555) 201-4412', '112 Elm Ave',      'Contoso', 'TX', '78704', 'Statewide Insurance', 'POL-2026-10002'],
  ['1FTFW1E87MFA12345', '2024', 'Ford',   'F-150',    'Black',  '52000', 'Carmen',  'Ortiz',   'carmen.ortiz@example.com',  '(555) 201-4413', '2203 Pinewood Dr', 'Contoso', 'TX', '78704', 'Contoso Mutual Auto', 'POL-2026-10003'],
  ['2T1BURHE7JC100987', '2024', 'Toyota', 'Corolla',  'Blue',   '25000', 'Derek',   'Johnson', 'derek.johnson@example.com', '(555) 201-4414', '55 Maple Ct',      'Contoso', 'TX', '78704', 'Riverside Mutual',    'POL-2026-10004'],
  ['KNDPM3AC5N7012345', '2024', 'Kia',    'Sportage', 'Red',    '32500', 'Eliana',  'Rivera',  'eliana.rivera@example.com', '(555) 201-4415', '913 Cedar Ln',     'Contoso', 'TX', '78704', 'Contoso Mutual Auto', 'POL-2026-10005'],
]

function buildCsvTemplate(): string {
  const esc = (v: string) => (/[",\n]/.test(v) ? `"${v.replace(/"/g, '""')}"` : v)
  const lines = [CSV_HEADERS.join(',')]
  for (const row of CSV_SAMPLE_ROWS) lines.push(row.map(esc).join(','))
  return lines.join('\n')
}

function downloadTemplate() {
  const csv = buildCsvTemplate()
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = 'bulk-registration-template.csv'
  document.body.appendChild(a); a.click()
  document.body.removeChild(a); URL.revokeObjectURL(url)
}

/* Minimal RFC-4180-ish CSV parser — handles quoted fields with commas */
function parseCsv(text: string): string[][] {
  const rows: string[][] = []
  let cur: string[] = []
  let field = ''
  let inQuotes = false
  for (let i = 0; i < text.length; i++) {
    const ch = text[i]
    if (inQuotes) {
      if (ch === '"') {
        if (text[i + 1] === '"') { field += '"'; i++ } else { inQuotes = false }
      } else { field += ch }
    } else {
      if (ch === '"') inQuotes = true
      else if (ch === ',') { cur.push(field); field = '' }
      else if (ch === '\n' || ch === '\r') {
        if (ch === '\r' && text[i + 1] === '\n') i++
        cur.push(field); field = ''
        if (cur.some(c => c.trim() !== '')) rows.push(cur)
        cur = []
      } else { field += ch }
    }
  }
  if (field !== '' || cur.length) { cur.push(field); if (cur.some(c => c.trim() !== '')) rows.push(cur) }
  return rows
}

interface Row {
  vin: string; year: string; make: string; model: string; color: string; msrp: string
  customerFirst: string; customerLast: string; customerEmail: string; customerPhone: string
  customerAddress: string; customerCity: string; customerState: string; customerZip: string
  insCarrier: string; insPolicy: string
}

function rowsFromCsv(text: string): Row[] {
  const table = parseCsv(text)
  if (table.length < 2) return []
  const [, ...dataRows] = table
  return dataRows.map(r => ({
    vin: r[0] || '',   year: r[1] || '',   make: r[2] || '',   model: r[3] || '',   color: r[4] || '',   msrp: r[5] || '0',
    customerFirst: r[6] || '', customerLast: r[7] || '', customerEmail: r[8] || '', customerPhone: r[9] || '',
    customerAddress: r[10] || '', customerCity: r[11] || '', customerState: r[12] || '', customerZip: r[13] || '',
    insCarrier: r[14] || '', insPolicy: r[15] || '',
  }))
}

/* Demo flat fee (matches single-registration path) */
const FLAT_FEE = 33 + 50.75 + 4.75 + 11.50 // $100.00

interface ProcessingLine { row: Row; status: 'pending' | 'ok' | 'error'; message?: string }

export default function BulkRegistration() {
  const { isAuthenticated, userId } = useAuth()
  const [file, setFile] = useState<File | null>(null)
  const [fileText, setFileText] = useState<string>('')
  const [previewRows, setPreviewRows] = useState<Row[]>([])
  const [lines, setLines] = useState<ProcessingLine[]>([])
  const [uploading, setUploading] = useState(false)
  const [uploadError, setUploadError] = useState('')
  const [result, setResult] = useState<{ total: number; success: number; errors: number; batchId: string } | null>(null)
  const [submissions, setSubmissions] = useState<Record<string, any>[]>([])
  const [loadingSubs, setLoadingSubs] = useState(true)

  const loadHistory = () => {
    if (!isAuthenticated) { setLoadingSubs(false); return }
    dvQuery('dmv_bulksubmissions',
      `$filter=_dmv_dealeracctid_value eq ${DEMO_DEALER.accountId}` +
      `&$select=dmv_batchid,dmv_submissiondate,dmv_batchstatus,dmv_totalrecords,dmv_processedrecords,dmv_failedrecords,dmv_totalfees,dmv_paymentstatus&$orderby=dmv_submissiondate desc&$top=20`
    ).then(setSubmissions).catch(() => {}).finally(() => setLoadingSubs(false))
  }

  useEffect(() => { loadHistory() }, [isAuthenticated, userId])

  const handleFilePicked = async (f: File) => {
    setFile(f); setResult(null); setUploadError('')
    try {
      const text = await f.text()
      setFileText(text)
      setPreviewRows(rowsFromCsv(text))
    } catch {
      setUploadError('Could not read file. Please upload a UTF-8 CSV.')
    }
  }

  const pad4 = (n: number) => n.toString().padStart(4, '0')

  const processBatch = async () => {
    if (!fileText || previewRows.length === 0) return
    setUploading(true); setUploadError('')
    const today = new Date()
    const expDate = new Date(today); expDate.setFullYear(expDate.getFullYear() + 1)
    const tagExp = new Date(today); tagExp.setDate(tagExp.getDate() + 30)
    const batchId = `BLK-${today.getFullYear()}-${pad4(Math.floor(Math.random() * 10000))}`

    const working: ProcessingLine[] = previewRows.map(r => ({ row: r, status: 'pending' }))
    setLines(working)

    let success = 0, errors = 0

    for (let i = 0; i < previewRows.length; i++) {
      const r = previewRows[i]
      try {
        // 1. Contact (find-or-create by email)
        let contactId: string | undefined
        const email = r.customerEmail.trim()
        if (email) {
          const hits = await dvQuery('contacts',
            `$filter=emailaddress1 eq '${email.replace(/'/g, "''")}'&$select=contactid&$top=1`)
          contactId = hits[0]?.contactid
        }
        if (!contactId) {
          contactId = await dvCreate('contacts', {
            firstname: r.customerFirst, lastname: r.customerLast,
            emailaddress1: email || undefined, telephone1: r.customerPhone || undefined,
            address1_line1: r.customerAddress || undefined, address1_city: r.customerCity || undefined,
            address1_stateorprovince: r.customerState || undefined, address1_postalcode: r.customerZip || undefined,
          })
        }

        // 2. Vehicle — upsert by VIN
        const vinClean = r.vin.trim().toUpperCase()
        const vehicleFields = {
          dmv_vin: vinClean,
          dmv_year: r.year, dmv_make: r.make, dmv_model: r.model, dmv_color: r.color,
          dmv_msrp: parseFloat(r.msrp) || 0,
          dmv_odometer: 15, dmv_bodystyle: 100000000, dmv_fueltype: 100000000,
          'dmv_ownercontactid@odata.bind': `/contacts(${contactId})`,
          dmv_insurancecarrier: r.insCarrier, dmv_insurancepolicy: r.insPolicy,
        }
        const existingVeh = await dvQuery('dmv_vehicles',
          `$filter=dmv_vin eq '${vinClean.replace(/'/g, "''")}'&$select=dmv_vehicleid&$top=1`)
        let vehicleId: string
        if (existingVeh[0]?.dmv_vehicleid) {
          vehicleId = existingVeh[0].dmv_vehicleid
          await dvUpdate('dmv_vehicles', vehicleId, vehicleFields)
        } else {
          vehicleId = await dvCreate('dmv_vehicles', vehicleFields)
        }

        // 3. Registration (Submitted + dealer channel)
        const regId = await dvCreate('dmv_vehicleregistrations', {
          dmv_regstatus: 100000006, dmv_regtype: 100000000,
          dmv_regyear: today.getFullYear(),
          dmv_submissionchannel: 100000000, // Dealer
          dmv_submitteddate: today.toISOString(),
          dmv_effectivedate: today.toISOString().split('T')[0] + 'T00:00:00Z',
          dmv_expirationdate: expDate.toISOString().split('T')[0] + 'T00:00:00Z',
          dmv_fee: 50.75, dmv_totaldue: FLAT_FEE,
          dmv_county: 'Travis',
          dmv_paymentstatus: 100000001, dmv_paymentdate: today.toISOString(),
          dmv_paymentmethod: 100000000, dmv_insuranceverified: false,
          'dmv_vehicleid@odata.bind': `/dmv_vehicles(${vehicleId})`,
          'dmv_dealeracctid@odata.bind': `/accounts(${DEMO_DEALER.accountId})`,
          'dmv_regcontactid@odata.bind': `/contacts(${contactId})`,
        })

        // 3b. Registration term (+ link as current term)
        const termId = await dvCreate('dmv_registrationterms', {
          dmv_termtype: 100000000,   // New
          dmv_termstatus: 100000001, // Pending
          dmv_startdate: today.toISOString().split('T')[0] + 'T00:00:00Z',
          dmv_enddate: expDate.toISOString().split('T')[0] + 'T00:00:00Z',
          dmv_issuedate: today.toISOString().split('T')[0] + 'T00:00:00Z',
          'dmv_vehicleregistrationid@odata.bind': `/dmv_vehicleregistrations(${regId})`,
        })
        await dvUpdate('dmv_vehicleregistrations', regId, {
          'dmv_currenttermid@odata.bind': `/dmv_registrationterms(${termId})`,
        })

        // 4. Temp tag (Pending — flow flips to Active on approval)
        const tagNumber = `TMP-${today.getFullYear()}-${pad4(Math.floor(Math.random() * 10000))}`
        await dvCreate('dmv_temporarytags', {
          dmv_tagnumber: tagNumber,
          dmv_buyername: `${r.customerFirst} ${r.customerLast}`.trim(),
          dmv_issuedate: today.toISOString().split('T')[0] + 'T00:00:00Z',
          dmv_expirationdate: tagExp.toISOString().split('T')[0] + 'T00:00:00Z',
          dmv_tagstatus: 100000004, dmv_saleprice: parseFloat(r.msrp) || 0, dmv_printcount: 0,
          'dmv_vehicleid@odata.bind': `/dmv_vehicles(${vehicleId})`,
          'dmv_dealeracctid@odata.bind': `/accounts(${DEMO_DEALER.accountId})`,
          'dmv_generatedby@odata.bind': `/contacts(${contactId})`,
        })

        working[i] = { row: r, status: 'ok' }
        success++
      } catch (err) {
        working[i] = { row: r, status: 'error', message: err instanceof Error ? err.message : 'Failed' }
        errors++
      }
      setLines([...working])
    }

    // Batch summary record
    try {
      await dvCreate('dmv_bulksubmissions', {
        dmv_batchid: batchId,
        dmv_submissiondate: today.toISOString(),
        dmv_batchstatus: errors === 0 ? 100000001 : 100000000, // Completed / Submitted
        dmv_totalrecords: previewRows.length,
        dmv_processedrecords: success,
        dmv_failedrecords: errors,
        dmv_totalfees: success * FLAT_FEE,
        dmv_paymentstatus: 100000001,
        'dmv_dealeracctid@odata.bind': `/accounts(${DEMO_DEALER.accountId})`,
        ...(userId ? { 'dmv_submittedby@odata.bind': `/contacts(${userId})` } : {}),
      })
    } catch (e) {
      console.error('[Bulk] batch summary failed', e)
    }

    setResult({ total: previewRows.length, success, errors, batchId })
    setUploading(false)
    loadHistory()
  }

  const resetAll = () => {
    setFile(null); setFileText(''); setPreviewRows([]); setLines([]); setResult(null); setUploadError('')
  }

  return (
    <div>
      <section style={styles.hero}>
        <div className="container">
          <h1 style={styles.heroTitle}>Bulk Registration Submission</h1>
          <p style={styles.heroSub}>Upload a CSV to submit multiple vehicle registrations at once. Perfect for dealer lot intake.</p>
        </div>
      </section>

      <section className="container" style={{ padding: '40px 24px' }}>
        <div style={styles.grid}>
          <div style={styles.card}>
            <h2 style={styles.cardTitle}>📁 Upload Registration File</h2>

            {!previewRows.length && (
              <div style={styles.dropZone}
                onDragOver={e => e.preventDefault()}
                onDrop={e => { e.preventDefault(); if (e.dataTransfer.files[0]) handleFilePicked(e.dataTransfer.files[0]) }}>
                <span style={{ fontSize: '36px' }}>📄</span>
                <p style={{ margin: '12px 0 4px', fontWeight: 500 }}>Drop your CSV here or click to browse</p>
                <p style={{ fontSize: '13px', color: '#888', margin: 0 }}>Accepts .csv (max 10MB)</p>
                <input type="file" accept=".csv" style={{ position: 'absolute', inset: 0, opacity: 0, cursor: 'pointer' }}
                  onChange={e => { if (e.target.files?.[0]) handleFilePicked(e.target.files[0]) }} />
              </div>
            )}

            {file && previewRows.length > 0 && (
              <>
                <div style={styles.fileInfo}>
                  <span>📎 {file.name} · {previewRows.length} rows parsed</span>
                  <button type="button" onClick={resetAll} style={{ border: 'none', background: 'none', color: '#E63946', cursor: 'pointer', fontWeight: 600 }}>✕ Clear</button>
                </div>

                <div style={{ overflowX: 'auto', marginTop: 16, maxHeight: 420 }}>
                  <table style={styles.table}>
                    <thead><tr>
                      <th style={styles.th}>#</th><th style={styles.th}>VIN</th>
                      <th style={styles.th}>Vehicle</th><th style={styles.th}>Customer</th><th style={styles.th}>Fee</th><th style={styles.th}>Status</th>
                    </tr></thead>
                    <tbody>
                      {previewRows.map((r, i) => {
                        const line = lines[i]
                        const sPill = !line ? { bg: '#eceff1', fg: '#546e7a', text: 'Ready' } :
                          line.status === 'ok'    ? { bg: '#d4edda', fg: '#155724', text: '✓ Submitted' } :
                          line.status === 'error' ? { bg: '#f8d7da', fg: '#721c24', text: '✕ Error' } :
                                                    { bg: '#fff3cd', fg: '#856404', text: '⏳ Processing…' }
                        return (
                          <tr key={i}>
                            <td style={styles.td}>{i + 1}</td>
                            <td style={styles.td}><code style={{ fontFamily: 'var(--font-mono)', fontSize: 12 }}>{r.vin}</code></td>
                            <td style={styles.td}>{r.year} {r.make} {r.model}</td>
                            <td style={styles.td}>{r.customerFirst} {r.customerLast}</td>
                            <td style={styles.td}>${FLAT_FEE.toFixed(2)}</td>
                            <td style={styles.td}>
                              <span style={{ display: 'inline-block', padding: '2px 10px', borderRadius: 12, fontSize: 11, fontWeight: 600, whiteSpace: 'nowrap' as const, background: sPill.bg, color: sPill.fg }}>{sPill.text}</span>
                              {line?.status === 'error' && line.message && (
                                <div style={{ marginTop: 4, fontSize: 11, color: '#721c24', whiteSpace: 'pre-wrap' as const, wordBreak: 'break-word' as const, maxWidth: 320 }}>{line.message}</div>
                              )}
                            </td>
                          </tr>
                        )
                      })}
                    </tbody>
                  </table>
                </div>

                {!result && (
                  <>
                    {/* Fee summary — what the dealer remits to DMV */}
                    <div style={styles.feeSummary}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 14, color: '#666' }}>
                        <span>{previewRows.length} registrations × ${FLAT_FEE.toFixed(2)}</span>
                        <span>${(previewRows.length * FLAT_FEE).toFixed(2)}</span>
                      </div>
                      <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 10, paddingTop: 10, borderTop: '1px solid #e0e0e0', fontSize: 16, fontWeight: 700, color: '#1D3557' }}>
                        <span>Total Dealer Remittance</span>
                        <span>${(previewRows.length * FLAT_FEE).toFixed(2)}</span>
                      </div>
                      <p style={{ margin: '8px 0 0', fontSize: 12, color: '#888' }}>Billed to dealer account on monthly DMV settlement.</p>
                    </div>

                    <button type="button" className="btn btn-primary" disabled={uploading} onClick={processBatch}
                      style={{ marginTop: '16px', padding: '12px 32px' }}>
                      {uploading ? '⏳ Processing…' : `🚀 Submit ${previewRows.length} Registrations · $${(previewRows.length * FLAT_FEE).toFixed(2)}`}
                    </button>
                  </>
                )}
              </>
            )}

            {uploadError && <p style={{ color: '#E63946', fontSize: '14px', marginTop: '8px' }}>{uploadError}</p>}

            {result && (
              <div style={styles.resultCard}>
                <h3 style={{ margin: '0 0 8px', fontSize: '16px' }}>Processing Complete</h3>
                <p style={{ fontSize: '13px', color: '#888', margin: '0 0 16px' }}>Batch ID: <code style={{ fontFamily: 'var(--font-mono)' }}>{result.batchId}</code></p>
                <div style={{ display: 'flex', gap: '24px' }}>
                  <div style={styles.resultStat}>
                    <span style={{ fontSize: '28px', fontWeight: 700, fontFamily: 'var(--font-mono)' }}>{result.total}</span>
                    <span style={{ fontSize: '12px', color: '#888' }}>Total Records</span>
                  </div>
                  <div style={styles.resultStat}>
                    <span style={{ fontSize: '28px', fontWeight: 700, color: '#2a9d8f', fontFamily: 'var(--font-mono)' }}>{result.success}</span>
                    <span style={{ fontSize: '12px', color: '#888' }}>Successful</span>
                  </div>
                  <div style={styles.resultStat}>
                    <span style={{ fontSize: '28px', fontWeight: 700, color: '#E63946', fontFamily: 'var(--font-mono)' }}>{result.errors}</span>
                    <span style={{ fontSize: '12px', color: '#888' }}>Errors</span>
                  </div>
                </div>
                <div style={{ marginTop: 16, display: 'flex', gap: 12 }}>
                  <button type="button" className="btn btn-primary" onClick={resetAll}>Upload Another Batch</button>
                  <a href="/dealer/new-registration?view=submissions" className="btn" style={{ border: '1px solid #ccc' }}>View in Submissions</a>
                </div>
              </div>
            )}
          </div>

          <div style={styles.card}>
            <h3 style={styles.cardTitle}>📋 File Format</h3>
            <p style={{ fontSize: '14px', color: '#666', marginBottom: '12px' }}>
              Download the template — it includes 5 pre-populated sample vehicles you can submit as-is for a clean demo.
            </p>
            <button type="button" className="btn btn-primary" onClick={downloadTemplate}
              style={{ width: '100%', marginBottom: 16 }}>
              📥 Download CSV Template
            </button>

            <div style={{ overflowX: 'auto' }}>
              <table style={styles.table}>
                <thead>
                  <tr>
                    <th style={styles.th}>#</th>
                    <th style={styles.th}>Column</th>
                  </tr>
                </thead>
                <tbody>
                  {CSV_HEADERS.map((h, i) => (
                    <tr key={h}>
                      <td style={styles.td}>{i + 1}</td>
                      <td style={styles.td}><code style={{ fontFamily: 'var(--font-mono)', fontSize: '12px' }}>{h}</code></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>

        {/* Submission History */}
        {isAuthenticated && (
          <div style={{ marginTop: '32px' }}>
            <h2 style={{ fontSize: '20px', fontWeight: 600, color: '#1D3557', marginBottom: '16px' }}>Submission History</h2>
            {loadingSubs ? (
              <p style={{ color: '#888', fontSize: '14px' }}>Loading submissions...</p>
            ) : submissions.length === 0 ? (
              <p style={{ color: '#888', fontSize: '14px' }}>No bulk submissions yet.</p>
            ) : (
              <div style={{ overflowX: 'auto' }}>
                <table style={styles.table}>
                  <thead>
                    <tr>
                      <th style={styles.th}>Batch ID</th>
                      <th style={styles.th}>Submitted</th>
                      <th style={styles.th}>Records</th>
                      <th style={styles.th}>Processed</th>
                      <th style={styles.th}>Failed</th>
                      <th style={styles.th}>Fees</th>
                      <th style={styles.th}>Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    {submissions.map(s => {
                      const status = fmt(s, 'dmv_batchstatus') || 'Submitted'
                      const statusBg = status === 'Completed' ? '#d4edda' : status === 'Failed' ? '#f8d7da' : '#fff3cd'
                      const statusFg = status === 'Completed' ? '#155724' : status === 'Failed' ? '#721c24' : '#856404'
                      return (
                        <tr key={s.dmv_bulksubmissionid}>
                          <td style={styles.td}><code style={{ fontFamily: 'var(--font-mono)', fontSize: '12px' }}>{s.dmv_batchid}</code></td>
                          <td style={styles.td}>{fmt(s, 'dmv_submissiondate')}</td>
                          <td style={styles.td}>{s.dmv_totalrecords ?? '—'}</td>
                          <td style={styles.td}>{s.dmv_processedrecords ?? '—'}</td>
                          <td style={styles.td}>{s.dmv_failedrecords ?? '—'}</td>
                          <td style={styles.td}>{s.dmv_totalfees ? `$${Number(s.dmv_totalfees).toFixed(2)}` : '—'}</td>
                          <td style={styles.td}>
                            <span style={{ display: 'inline-block', padding: '2px 10px', borderRadius: '12px', fontSize: '11px', fontWeight: 600, background: statusBg, color: statusFg }}>{status}</span>
                          </td>
                        </tr>
                      )
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        )}
      </section>
    </div>
  )
}

const styles: Record<string, React.CSSProperties> = {
  hero: { background: 'linear-gradient(135deg, #1D3557 0%, #264674 100%)', color: '#fff', padding: '48px 0 40px' },
  heroTitle: { fontSize: '32px', fontFamily: 'var(--font-heading)', margin: '0 0 12px', color: '#fff' },
  heroSub: { fontSize: '16px', opacity: 0.85, margin: 0, maxWidth: '600px' },
  grid: { display: 'grid', gridTemplateColumns: '1.5fr 1fr', gap: '24px' },
  card: { background: '#fff', borderRadius: '12px', padding: '24px', border: '1px solid #e8e8e8', boxShadow: '0 2px 8px rgba(0,0,0,0.04)' },
  cardTitle: { fontSize: '18px', fontWeight: 600, color: '#1D3557', margin: '0 0 16px', paddingBottom: '12px', borderBottom: '1px solid #eee' },
  dropZone: { position: 'relative' as const, border: '2px dashed #d0d5dd', borderRadius: '12px', padding: '40px 20px', textAlign: 'center' as const, background: '#fafbfc', transition: 'all 0.2s' },
  fileInfo: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '12px 16px', background: '#f0f7ff', borderRadius: '8px', marginTop: '12px', fontSize: '14px' },
  resultCard: { marginTop: '24px', padding: '20px', background: '#f8f9fa', borderRadius: '8px', border: '1px solid #e8e8e8' },
  resultStat: { display: 'flex', flexDirection: 'column' as const, alignItems: 'center', gap: '4px' },
  feeSummary: { marginTop: 16, padding: 16, background: '#f0f7ff', borderRadius: 8, border: '1px solid #d0e3f7' },
  table: { width: '100%', borderCollapse: 'collapse' as const, fontSize: '13px' },
  th: { textAlign: 'left' as const, padding: '10px 12px', background: '#f8f9fa', fontWeight: 600, fontSize: '12px', color: '#1D3557', borderBottom: '2px solid #e8e8e8' },
  td: { padding: '8px 12px', borderBottom: '1px solid #f0f0f0' },
}
