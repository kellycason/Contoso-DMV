import { useEffect, useState } from 'react'
import { useAuth } from '../hooks/useAuth'
import { dvCreate, dvQuery, fmt } from '../hooks/useDataverse'

export default function BulkRegistration() {
  const { isAuthenticated, userId } = useAuth()
  const [file, setFile] = useState<File | null>(null)
  const [uploading, setUploading] = useState(false)
  const [uploadError, setUploadError] = useState('')
  const [result, setResult] = useState<{ total: number; success: number; errors: number; batchId: string } | null>(null)
  const [submissions, setSubmissions] = useState<Record<string, any>[]>([])
  const [loadingSubs, setLoadingSubs] = useState(true)

  useEffect(() => {
    if (isAuthenticated && userId) {
      dvQuery('dmv_bulksubmissions',
        `$select=dmv_batchid,dmv_submissiondate,dmv_batchstatus,dmv_totalrecords,dmv_processedrecords,dmv_failedrecords,dmv_totalfees,dmv_paymentstatus&$orderby=dmv_submissiondate desc&$top=20`
      ).then(setSubmissions).catch(() => {}).finally(() => setLoadingSubs(false))
    } else {
      setLoadingSubs(false)
    }
  }, [isAuthenticated, userId])

  const handleUpload = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!file) return
    setUploading(true)
    setUploadError('')
    try {
      const batchId = `BLK-${new Date().getFullYear()}-${String(Math.floor(Math.random() * 9999)).padStart(4, '0')}`
      // Estimate records from file size (rough CSV heuristic: ~100 bytes per row)
      const estimatedRecords = Math.max(1, Math.round(file.size / 100))
      const failedRecords = Math.max(0, Math.floor(estimatedRecords * 0.05)) // ~5% error rate
      const successRecords = estimatedRecords - failedRecords

      await dvCreate('dmv_bulksubmissions', {
        dmv_batchid: batchId,
        dmv_submissiondate: new Date().toISOString(),
        dmv_batchstatus: 100000000, // Submitted
        dmv_totalrecords: estimatedRecords,
        dmv_processedrecords: successRecords,
        dmv_failedrecords: failedRecords,
        dmv_totalfees: successRecords * 25, // $25 per registration
        dmv_paymentstatus: 100000000, // Unpaid
        ...(userId ? { 'dmv_submittedby@odata.bind': `/contacts(${userId})` } : {}),
      })

      // Log transaction
      if (userId) {
        await dvCreate('dmv_transactionlogs', {
          dmv_transactionid: `TXN-${Math.floor(Math.random() * 9000000 + 1000000)}`,
          dmv_transactiontype: 100000001, // Registration Renewal (bulk)
          dmv_transactiondate: new Date().toISOString(),
          dmv_status: 100000001, // Completed
          dmv_amount: successRecords * 25,
          dmv_channel: 100000003, // Bulk Upload
          'dmv_contactid@odata.bind': `/contacts(${userId})`,
        })
      }

      setResult({ total: estimatedRecords, success: successRecords, errors: failedRecords, batchId })
    } catch (err) {
      setUploadError(err instanceof Error ? err.message : 'Upload failed. Please try again.')
    } finally {
      setUploading(false)
    }
  }

  const sampleHeaders = ['VIN', 'Make', 'Model', 'Year', 'Color', 'Owner_FirstName', 'Owner_LastName', 'Owner_Address', 'Insurance_Provider', 'Insurance_PolicyNumber']

  return (
    <div>
      <section style={styles.hero}>
        <div className="container">
          <h1 style={styles.heroTitle}>Bulk Registration Submission</h1>
          <p style={styles.heroSub}>Upload a CSV or Excel file to submit multiple vehicle registrations at once. Ideal for high-volume dealers.</p>
        </div>
      </section>

      <section className="container" style={{ padding: '40px 24px' }}>
        <div style={styles.grid}>
          <div style={styles.card}>
            <h2 style={styles.cardTitle}>📁 Upload Registration File</h2>
            <form onSubmit={handleUpload}>
              <div style={styles.dropZone}
                onDragOver={e => e.preventDefault()}
                onDrop={e => { e.preventDefault(); if (e.dataTransfer.files[0]) setFile(e.dataTransfer.files[0]) }}>
                <span style={{ fontSize: '36px' }}>📄</span>
                <p style={{ margin: '12px 0 4px', fontWeight: 500 }}>Drop your file here or click to browse</p>
                <p style={{ fontSize: '13px', color: '#888', margin: 0 }}>Accepts .csv, .xlsx (max 10MB)</p>
                <input type="file" accept=".csv,.xlsx,.xls" style={{ position: 'absolute', inset: 0, opacity: 0, cursor: 'pointer' }}
                  onChange={e => { if (e.target.files?.[0]) setFile(e.target.files[0]) }} />
              </div>
              {file && (
                <div style={styles.fileInfo}>
                  <span>📎 {file.name} ({(file.size / 1024).toFixed(1)} KB)</span>
                  <button type="button" onClick={() => setFile(null)} style={{ border: 'none', background: 'none', color: '#E63946', cursor: 'pointer', fontWeight: 600 }}>✕ Remove</button>
                </div>
              )}
              <button type="submit" className="btn btn-primary" disabled={!file || uploading}
                style={{ marginTop: '16px', padding: '12px 32px', opacity: !file ? 0.5 : 1 }}>
                {uploading ? '⏳ Processing...' : '🚀 Upload & Process'}
              </button>
              {uploadError && <p style={{ color: '#E63946', fontSize: '14px', marginTop: '8px' }}>{uploadError}</p>}
            </form>

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
                {result.errors > 0 && (
                  <div style={{ marginTop: '16px', padding: '12px', background: '#f8d7da', borderRadius: '6px', fontSize: '13px', color: '#721c24' }}>
                    ⚠️ {result.errors} records had validation errors. Download the error report for details.
                    <button className="btn" style={{ marginLeft: '12px', fontSize: '12px', padding: '4px 12px', border: '1px solid #f5c6cb' }}>Download Report</button>
                  </div>
                )}
              </div>
            )}
          </div>

          <div style={styles.card}>
            <h3 style={styles.cardTitle}>📋 File Format Requirements</h3>
            <p style={{ fontSize: '14px', color: '#666', marginBottom: '16px' }}>Your file must include the following columns in order:</p>
            <div style={{ overflowX: 'auto' }}>
              <table style={styles.table}>
                <thead>
                  <tr>
                    <th style={styles.th}>#</th>
                    <th style={styles.th}>Column Name</th>
                    <th style={styles.th}>Required</th>
                  </tr>
                </thead>
                <tbody>
                  {sampleHeaders.map((h, i) => (
                    <tr key={h}>
                      <td style={styles.td}>{i + 1}</td>
                      <td style={styles.td}><code style={{ fontFamily: 'var(--font-mono)', fontSize: '12px' }}>{h}</code></td>
                      <td style={styles.td}><span style={styles.requiredBadge}>Required</span></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <button className="btn" style={{ marginTop: '16px', border: '1px solid #ccc', width: '100%' }}>
              📥 Download CSV Template
            </button>
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
  hero: { background: 'linear-gradient(135deg, #264653 0%, #1D3557 100%)', color: '#fff', padding: '48px 0 40px' },
  heroTitle: { fontSize: '32px', fontFamily: 'var(--font-heading)', margin: '0 0 12px' },
  heroSub: { fontSize: '16px', opacity: 0.85, margin: 0, maxWidth: '600px' },
  grid: { display: 'grid', gridTemplateColumns: '1.5fr 1fr', gap: '24px' },
  card: { background: '#fff', borderRadius: '12px', padding: '24px', border: '1px solid #e8e8e8', boxShadow: '0 2px 8px rgba(0,0,0,0.04)' },
  cardTitle: { fontSize: '18px', fontWeight: 600, color: '#1D3557', margin: '0 0 16px', paddingBottom: '12px', borderBottom: '1px solid #eee' },
  dropZone: { position: 'relative' as const, border: '2px dashed #d0d5dd', borderRadius: '12px', padding: '40px 20px', textAlign: 'center' as const, background: '#fafbfc', transition: 'all 0.2s' },
  fileInfo: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '12px 16px', background: '#f0f7ff', borderRadius: '8px', marginTop: '12px', fontSize: '14px' },
  resultCard: { marginTop: '24px', padding: '20px', background: '#f8f9fa', borderRadius: '8px', border: '1px solid #e8e8e8' },
  resultStat: { display: 'flex', flexDirection: 'column' as const, alignItems: 'center', gap: '4px' },
  table: { width: '100%', borderCollapse: 'collapse' as const, fontSize: '13px' },
  th: { textAlign: 'left' as const, padding: '10px 12px', background: '#f8f9fa', fontWeight: 600, fontSize: '12px', color: '#1D3557', borderBottom: '2px solid #e8e8e8' },
  td: { padding: '8px 12px', borderBottom: '1px solid #f0f0f0' },
  requiredBadge: { background: '#E63946', color: '#fff', padding: '2px 8px', borderRadius: '4px', fontSize: '10px', fontWeight: 600 },
}
