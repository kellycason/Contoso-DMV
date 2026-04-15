import { useState } from 'react'

export default function BulkRegistration() {
  const [file, setFile] = useState<File | null>(null)
  const [uploading, setUploading] = useState(false)
  const [result, setResult] = useState<{ total: number; success: number; errors: number } | null>(null)

  const handleUpload = (e: React.FormEvent) => {
    e.preventDefault()
    if (!file) return
    setUploading(true)
    setTimeout(() => {
      setUploading(false)
      setResult({ total: 24, success: 22, errors: 2 })
    }, 2000)
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
            </form>

            {result && (
              <div style={styles.resultCard}>
                <h3 style={{ margin: '0 0 16px', fontSize: '16px' }}>Processing Complete</h3>
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
